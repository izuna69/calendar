import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import '../models/schedule_event.dart';
import 'storage_service.dart';

class NotificationService {
  static Timer? _checkTimer;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      await localNotifier.setup(
        appName: 'スケジュール管理',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _isInitialized = true;
      startScheduler();
      debugPrint('[NotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  static void startScheduler() {
    _checkTimer?.cancel();
    // 30秒ごとに予定された通知を確認
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      checkAndTriggerNotifications();
    });
    // 起動時に即時1回チェック
    checkAndTriggerNotifications();
  }

  static void stopScheduler() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  static Future<void> checkAndTriggerNotifications() async {
    try {
      final now = DateTime.now();
      final events = StorageService.loadEvents();

      for (final event in events) {
        if (!event.enableNotification || event.isCompleted || event.isNotified) {
          continue;
        }

        final notifyTime = event.notificationDateTime;
        final difference = now.difference(notifyTime);

        // 通知時間が過ぎたか、直近10分以内の未通知の予定
        if (difference.inSeconds >= 0 && difference.inMinutes <= 10) {
          await showEventNotification(event);
          await StorageService.markNotified(event.id);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error checking notifications: $e');
    }
  }

  static Future<void> showEventNotification(ScheduleEvent event) async {
    try {
      String timeStr = '';
      if (event.hasTime) {
        final timeFormat = NumberFormat('00');
        timeStr = ' [${timeFormat.format(event.hour)}:${timeFormat.format(event.minute)}]';
      }

      String reminderText = '';
      if (event.notificationOffsetMinutes == 0) {
        reminderText = '予定の開始時間になりました。';
      } else if (event.notificationOffsetMinutes < 60) {
        reminderText = '${event.notificationOffsetMinutes}分後の予定です。';
      } else if (event.notificationOffsetMinutes == 60) {
        reminderText = '1時間後の予定です。';
      } else {
        reminderText = '${(event.notificationOffsetMinutes / 1440).round()}日後の予定です。';
      }

      final body = event.description.isNotEmpty
          ? '${event.description}\n$reminderText'
          : reminderText;

      final notification = LocalNotification(
        identifier: event.id,
        title: '🔔 予定の通知: ${event.title}$timeStr',
        body: body,
      );

      notification.onClick = () async {
        try {
          if (!await windowManager.isVisible()) {
            await windowManager.show();
          }
          await windowManager.focus();
        } catch (e) {
          debugPrint('[NotificationService] Window show error on click: $e');
        }
      };

      await notification.show();
    } catch (e) {
      debugPrint('[NotificationService] Error showing notification: $e');
    }
  }

  static Future<void> showTestNotification() async {
    final notification = LocalNotification(
      identifier: 'test_notification_${DateTime.now().millisecondsSinceEpoch}',
      title: '🔔 スケジュール通知テスト',
      body: '通知機能は正常に動作しています。バックグラウンドでも通知を受信できます。',
    );

    notification.onClick = () async {
      if (!await windowManager.isVisible()) {
        await windowManager.show();
      }
      await windowManager.focus();
    };

    await notification.show();
  }
}
