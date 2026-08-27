import 'dart:async';
import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:uuid/uuid.dart';
import '../models/schedule_event.dart';
import 'google_auth_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class GoogleCalendarService {
  static final GoogleCalendarService instance = GoogleCalendarService._();
  GoogleCalendarService._();

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> syncError = ValueNotifier<String?>(null);

  void init() {
    lastSyncTime.value = StorageService.getGoogleLastSyncTime();
  }

  /// Google Calendar API インスタンス取得
  Future<gcal.CalendarApi?> _getCalendarApi() async {
    final client = await GoogleAuthService.instance.getAuthenticatedClient();
    if (client == null) return null;
    return gcal.CalendarApi(client);
  }

  // ==========================================
  // 1. 単一予定のプッシュ (Insert / Update)
  // ==========================================
  Future<ScheduleEvent> pushEvent(ScheduleEvent event) async {
    final api = await _getCalendarApi();
    if (api == null) return event;

    try {
      final gEvent = _toGoogleEvent(event);

      if (event.googleEventId == null || event.googleEventId!.isEmpty) {
        // 🆕 新規登録 (Insert)
        debugPrint('[GoogleCalendarService] Inserting event to Google Calendar: ${event.title}');
        final created = await api.events.insert(gEvent, 'primary');

        final updatedEvent = event.copyWith(
          googleEventId: created.id,
          etag: created.etag,
          syncStatus: 'synced',
        );
        await StorageService.updateEvent(updatedEvent);
        return updatedEvent;
      } else {
        // 🔄 既存予定の更新 (Update)
        debugPrint('[GoogleCalendarService] Updating event in Google Calendar: ${event.title}');
        final updated = await api.events.update(gEvent, 'primary', event.googleEventId!);

        final updatedEvent = event.copyWith(
          etag: updated.etag,
          syncStatus: 'synced',
        );
        await StorageService.updateEvent(updatedEvent);
        return updatedEvent;
      }
    } catch (e) {
      debugPrint('[GoogleCalendarService] Error pushing event: $e');
      // エラー時は pending 状態で保持し、次回同期で再試行
      final pendingEvent = event.copyWith(
        syncStatus: event.googleEventId == null ? 'pendingUpload' : 'pendingUpdate',
      );
      await StorageService.updateEvent(pendingEvent);
      return pendingEvent;
    }
  }

  // ==========================================
  // 2. 単一予定の削除 (Delete)
  // ==========================================
  Future<void> deleteEvent(ScheduleEvent event) async {
    final api = await _getCalendarApi();
    if (api == null || event.googleEventId == null || event.googleEventId!.isEmpty) {
      await StorageService.purgeEvent(event.id);
      return;
    }

    try {
      debugPrint('[GoogleCalendarService] Deleting event from Google Calendar: ${event.title}');
      await api.events.delete('primary', event.googleEventId!);
      await StorageService.purgeEvent(event.id);
    } catch (e) {
      debugPrint('[GoogleCalendarService] Error deleting event: $e');
      // 404 (既に削除済み) の場合もローカルから完全削除
      if (e.toString().contains('404')) {
        await StorageService.purgeEvent(event.id);
      }
    }
  }

  // ==========================================
  // 3. 全体双方向同期 (Two-Way Sync)
  // ==========================================
  Future<bool> syncAll() async {
    if (isSyncing.value) return false;
    final api = await _getCalendarApi();
    if (api == null) {
      debugPrint('[GoogleCalendarService] Cannot sync: not authenticated');
      return false;
    }

    isSyncing.value = true;
    syncError.value = null;

    try {
      debugPrint('[GoogleCalendarService] Starting two-way sync...');

      // 1. ローカルで削除待機 (Tombstone) 中の予定を先に Google カレンダーから削除
      final allLocalEvents = StorageService.loadEvents(includeDeleted: true);
      final pendingDeletes = allLocalEvents.where((e) => e.isDeletedLocally).toList();
      for (final delEvent in pendingDeletes) {
        await deleteEvent(delEvent);
      }

      // 2. Google Calendar から直近1年〜今後2年の予定を取得
      final now = DateTime.now();
      final timeMin = now.subtract(const Duration(days: 365)).toUtc();
      final timeMax = now.add(const Duration(days: 730)).toUtc();

      final gcal.Events googleEventsList = await api.events.list(
        'primary',
        timeMin: timeMin,
        timeMax: timeMax,
        singleEvents: true,
        maxResults: 250,
      );

      final List<gcal.Event> remoteEvents = googleEventsList.items ?? [];
      final localEvents = StorageService.loadEvents(includeDeleted: false);

      final Map<String, ScheduleEvent> localByGoogleId = {
        for (var e in localEvents)
          if (e.googleEventId != null) e.googleEventId!: e,
      };

      final Map<String, ScheduleEvent> localByLocalId = {
        for (var e in localEvents) e.id: e,
      };

      final Set<String> processedGoogleIds = {};

      // 3. Google カレンダーの予定 -> ローカル反映
      for (final rEvent in remoteEvents) {
        if (rEvent.id == null || rEvent.status == 'cancelled') continue;
        processedGoogleIds.add(rEvent.id!);

        final localMatch = localByGoogleId[rEvent.id] ??
            (rEvent.extendedProperties?.private?['localId'] != null
                ? localByLocalId[rEvent.extendedProperties!.private!['localId']]
                : null);

        if (localMatch != null) {
          // ローカルとリモート両方に存在 -> 最終更新日時を比較
          final rUpdated = rEvent.updated ?? DateTime.now();
          if (rUpdated.isAfter(localMatch.updatedAt)) {
            // Google の方が新しい -> ローカル更新
            final updatedFromRemote = _fromGoogleEvent(rEvent, existingLocalId: localMatch.id);
            await StorageService.updateEvent(updatedFromRemote);
          } else if (localMatch.syncStatus == 'pendingUpdate') {
            // ローカル修正の方が新しい -> Google にアップロード
            await pushEvent(localMatch);
          }
        } else {
          // Google にのみ存在 -> ローカルに新規追加
          final newLocalEvent = _fromGoogleEvent(rEvent);
          await StorageService.addEvent(newLocalEvent);
        }
      }

      // 4. ローカルにのみ存在する予定 -> Google カレンダーにアップロード
      final freshLocalEvents = StorageService.loadEvents(includeDeleted: false);
      for (final lEvent in freshLocalEvents) {
        if (lEvent.googleEventId == null || !processedGoogleIds.contains(lEvent.googleEventId)) {
          if (lEvent.syncStatus != 'localOnly') {
            await pushEvent(lEvent);
          }
        }
      }

      // 同期完了日時の記録
      final finishTime = DateTime.now();
      lastSyncTime.value = finishTime;
      await StorageService.setGoogleLastSyncTime(finishTime);

      // 通知スケジューラー更新
      NotificationService.checkAndTriggerNotifications();

      debugPrint('[GoogleCalendarService] Two-way sync completed successfully at $finishTime');
      return true;
    } catch (e) {
      debugPrint('[GoogleCalendarService] Two-way sync failed: $e');
      syncError.value = '同期エラー: $e';
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  // ==========================================
  // 4. モデル変換 (ScheduleEvent <-> gcal.Event)
  // ==========================================
  gcal.Event _toGoogleEvent(ScheduleEvent event) {
    final gEvent = gcal.Event();
    gEvent.summary = event.title;
    gEvent.description = event.description.isNotEmpty ? event.description : null;

    if (event.hasTime) {
      final startDt = event.scheduledDateTime.toUtc();
      final endDt = startDt.add(const Duration(hours: 1)); // デフォルト1時間
      gEvent.start = gcal.EventDateTime(dateTime: startDt);
      gEvent.end = gcal.EventDateTime(dateTime: endDt);
    } else {
      // 終日予定 (All-day)
      final dateStr =
          "${event.date.year.toString().padLeft(4, '0')}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}";
      final nextDay = event.date.add(const Duration(days: 1));
      final nextDayStr =
          "${nextDay.year.toString().padLeft(4, '0')}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}";

      gEvent.start = gcal.EventDateTime(date: DateTime.parse(dateStr));
      gEvent.end = gcal.EventDateTime(date: DateTime.parse(nextDayStr));
    }

    // カラーマッピング
    gEvent.colorId = _argbToGoogleColorId(event.colorValue);

    // リマインダー通知マッピング
    if (event.enableNotification) {
      gEvent.reminders = gcal.EventReminders(
        useDefault: false,
        overrides: [
          gcal.EventReminder(
            method: 'popup',
            minutes: event.notificationOffsetMinutes,
          ),
        ],
      );
    } else {
      gEvent.reminders = gcal.EventReminders(
        useDefault: false,
        overrides: [],
      );
    }

    // Extended Properties (ローカル ID および完了フラグマッピング)
    gEvent.extendedProperties = gcal.EventExtendedProperties(
      private: {
        'localId': event.id,
        'isCompleted': event.isCompleted.toString(),
      },
    );

    return gEvent;
  }

  ScheduleEvent _fromGoogleEvent(gcal.Event gEvent, {String? existingLocalId}) {
    final String id = existingLocalId ??
        gEvent.extendedProperties?.private?['localId'] ??
        const Uuid().v4();

    final title = gEvent.summary?.isNotEmpty == true ? gEvent.summary! : '無題の予定';
    final description = gEvent.description ?? '';
    final isCompleted = gEvent.extendedProperties?.private?['isCompleted'] == 'true';

    bool hasTime = false;
    DateTime eventDate = DateTime.now();
    int hour = 9;
    int minute = 0;

    if (gEvent.start?.dateTime != null) {
      hasTime = true;
      final localDt = gEvent.start!.dateTime!.toLocal();
      eventDate = DateTime(localDt.year, localDt.month, localDt.day);
      hour = localDt.hour;
      minute = localDt.minute;
    } else if (gEvent.start?.date != null) {
      hasTime = false;
      eventDate = gEvent.start!.date!;
      hour = 9;
      minute = 0;
    }

    final int colorValue = _googleColorIdToArgb(gEvent.colorId);

    bool enableNotification = true;
    int notificationOffsetMinutes = 0;

    if (gEvent.reminders?.overrides != null && gEvent.reminders!.overrides!.isNotEmpty) {
      enableNotification = true;
      notificationOffsetMinutes = gEvent.reminders!.overrides!.first.minutes ?? 0;
    } else if (gEvent.reminders?.useDefault == false &&
        (gEvent.reminders?.overrides == null || gEvent.reminders!.overrides!.isEmpty)) {
      enableNotification = false;
    }

    return ScheduleEvent(
      id: id,
      title: title,
      description: description,
      date: eventDate,
      hasTime: hasTime,
      hour: hour,
      minute: minute,
      colorValue: colorValue,
      isCompleted: isCompleted,
      enableNotification: enableNotification,
      notificationOffsetMinutes: notificationOffsetMinutes,
      googleEventId: gEvent.id,
      etag: gEvent.etag,
      syncStatus: 'synced',
      createdAt: gEvent.created?.toLocal() ?? DateTime.now(),
      updatedAt: gEvent.updated?.toLocal() ?? DateTime.now(),
    );
  }

  // ==========================================
  // 5. 색상 변환 헬퍼 (ARGB <-> Google ColorId)
  // ==========================================
  static String _argbToGoogleColorId(int argb) {
    // 0xFF3B82F6 (Blue) -> 9 (Blueberry) or 7 (Peacock)
    // 0xFF10B981 (Green) -> 2 (Sage) or 10 (Basil)
    // 0xFFEF4444 (Red) -> 11 (Tomato)
    // 0xFFF59E0B (Amber) -> 6 (Tangerine) or 5 (Banana)
    // 0xFF8B5CF6 (Purple) -> 3 (Grape)
    // 0xFFEC4899 (Pink) -> 4 (Flamingo)
    // 0xFF6B7280 (Gray) -> 8 (Graphite)
    // 0xFF06B6D4 (Cyan) -> 7 (Peacock)
    switch (argb) {
      case 0xFF3B82F6:
        return '9'; // Blueberry
      case 0xFF10B981:
        return '10'; // Basil
      case 0xFFEF4444:
        return '11'; // Tomato
      case 0xFFF59E0B:
        return '6'; // Tangerine
      case 0xFF8B5CF6:
        return '3'; // Grape
      case 0xFFEC4899:
        return '4'; // Flamingo
      case 0xFF6B7280:
        return '8'; // Graphite
      case 0xFF06B6D4:
        return '7'; // Peacock
      default:
        return '9'; // Default Blue
    }
  }

  static int _googleColorIdToArgb(String? colorId) {
    switch (colorId) {
      case '1': // Lavender
        return 0xFF818CF8;
      case '2': // Sage
        return 0xFF34D399;
      case '3': // Grape
        return 0xFF8B5CF6;
      case '4': // Flamingo
        return 0xFFEC4899;
      case '5': // Banana
        return 0xFFFBBF24;
      case '6': // Tangerine
        return 0xFFF59E0B;
      case '7': // Peacock
        return 0xFF06B6D4;
      case '8': // Graphite
        return 0xFF6B7280;
      case '9': // Blueberry
        return 0xFF3B82F6;
      case '10': // Basil
        return 0xFF10B981;
      case '11': // Tomato
        return 0xFFEF4444;
      default:
        return 0xFF3B82F6; // Default Blue
    }
  }
}
