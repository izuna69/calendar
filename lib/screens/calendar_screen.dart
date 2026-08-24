import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/schedule_event.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/tray_and_window_service.dart';
import '../widgets/event_dialog.dart';
import '../widgets/event_list_item.dart';
import '../widgets/settings_dialog.dart';

enum EventFilter { all, pending, completed }

class CalendarScreen extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;

  const CalendarScreen({super.key, this.onThemeChanged});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<ScheduleEvent> _allEvents = [];
  EventFilter _currentFilter = EventFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvents();

    // トレイメニューからの予定追加リクエスト
    TrayAndWindowService.instance.onQuickAddRequested = () {
      _showAddEventDialog();
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadEvents() {
    final loaded = StorageService.loadEvents();
    setState(() {
      _allEvents = loaded;
    });
  }

  List<ScheduleEvent> _getEventsForDay(DateTime day) {
    return _allEvents.where((e) => isSameDay(e.date, day)).toList();
  }

  List<ScheduleEvent> _getFilteredEventsForSelectedDay() {
    var dayEvents = _getEventsForDay(_selectedDay);

    // フィルタリング
    if (_currentFilter == EventFilter.pending) {
      dayEvents = dayEvents.where((e) => !e.isCompleted).toList();
    } else if (_currentFilter == EventFilter.completed) {
      dayEvents = dayEvents.where((e) => e.isCompleted).toList();
    }

    // 検索クエリ
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      dayEvents = dayEvents.where((e) {
        return e.title.toLowerCase().contains(query) ||
            e.description.toLowerCase().contains(query);
      }).toList();
    }

    // ソート: 時間指定優先、次に作成順
    dayEvents.sort((a, b) {
      if (a.hasTime && b.hasTime) {
        final aTime = a.hour * 60 + a.minute;
        final bTime = b.hour * 60 + b.minute;
        return aTime.compareTo(bTime);
      } else if (a.hasTime) {
        return -1;
      } else if (b.hasTime) {
        return 1;
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    return dayEvents;
  }

  Future<void> _showAddEventDialog([DateTime? date]) async {
    final result = await showDialog<ScheduleEvent>(
      context: context,
      builder: (ctx) => EventDialog(
        initialDate: date ?? _selectedDay,
      ),
    );

    if (result != null) {
      await StorageService.addEvent(result);
      _loadEvents();
      NotificationService.checkAndTriggerNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${result.title}」を追加しました。'),
            backgroundColor: result.color,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showEditEventDialog(ScheduleEvent event) async {
    final result = await showDialog<ScheduleEvent>(
      context: context,
      builder: (ctx) => EventDialog(
        event: event,
      ),
    );

    if (result != null) {
      await StorageService.updateEvent(result);
      _loadEvents();
      NotificationService.checkAndTriggerNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('予定を更新しました。'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent(String id) async {
    await StorageService.deleteEvent(id);
    _loadEvents();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('予定を削除しました。'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleComplete(String id) async {
    final updated = await StorageService.toggleComplete(id);
    _loadEvents();

    if (mounted && updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isCompleted
                ? '✅ 「${updated.title}」を完了にしました。'
                : '🔄 「${updated.title}」を進行中に戻しました。',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => SettingsDialog(
        onThemeChanged: widget.onThemeChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dayEvents = _getEventsForDay(_selectedDay);
    final totalCount = dayEvents.length;
    final completedCount = dayEvents.where((e) => e.isCompleted).length;
    final pendingCount = totalCount - completedCount;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'スケジュール＆カレンダー',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 12),
            // Background notification active badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'バックグラウンド通知 有効',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Today button
          TextButton.icon(
            icon: const Icon(Icons.today, size: 18),
            label: const Text('今日'),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
          const SizedBox(width: 6),

          // Add Event button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('予定を追加'),
            onPressed: () => _showAddEventDialog(_selectedDay),
          ),
          const SizedBox(width: 6),

          // Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: _showSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;

          if (isWide) {
            return Row(
              children: [
                // Left: Calendar View
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: _buildCalendarCard(colorScheme),
                  ),
                ),

                // Vertical Divider
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),

                // Right: Schedule List Panel
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: _buildSchedulePanel(
                      colorScheme,
                      totalCount,
                      completedCount,
                      pendingCount,
                      isExpanded: true,
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Narrow screen (vertical stack)
            return SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildCalendarCard(colorScheme),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildSchedulePanel(
                      colorScheme,
                      totalCount,
                      completedCount,
                      pendingCount,
                      isExpanded: false,
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildCalendarCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TableCalendar<ScheduleEvent>(
              locale: 'ja_JP',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay)  {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                titleTextStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: const TextStyle(color: Color(0xFFEF4444)),
                holidayTextStyle: const TextStyle(color: Color(0xFFEF4444)),
                selectedDecoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 1.5),
                ),
                todayTextStyle: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;

                  return Positioned(
                    bottom: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...events.take(4).map((event) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 6.5,
                            height: 6.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: event.isCompleted
                                  ? event.color.withValues(alpha: 0.4)
                                  : event.color,
                              boxShadow: [
                                BoxShadow(
                                  color: event.color.withValues(alpha: 0.4),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (events.length > 4)
                          Container(
                            margin: const EdgeInsets.only(left: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${events.length - 4}',
                              style: const TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Quick legend / helper
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '日付をクリックすると、その日の予定を管理できます。',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulePanel(
    ColorScheme colorScheme,
    int totalCount,
    int completedCount,
    int pendingCount, {
    required bool isExpanded,
  }) {
    final filteredEvents = _getFilteredEventsForSelectedDay();
    final dateFormat = DateFormat('yyyy年M月d日 (E)', 'ja_JP');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // Date Title & Add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  () {
                    try {
                      return dateFormat.format(_selectedDay);
                    } catch (_) {
                      return '${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}';
                    }
                  }(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSameDay(_selectedDay, DateTime.now()) ? '今日の予定' : '選択した日の予定',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSameDay(_selectedDay, DateTime.now())
                        ? colorScheme.primary
                        : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              tooltip: 'この日に予定を追加',
              onPressed: () => _showAddEventDialog(_selectedDay),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Stats Card (Total, Pending, Completed)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('全体', '$totalCount', colorScheme.onSurface),
              Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.2)),
              _buildStatItem('進行中', '$pendingCount', Colors.orange.shade700),
              Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.2)),
              _buildStatItem('完了', '$completedCount', Colors.green.shade600),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search Bar & Filter Chips
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '予定を検索...',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter Chips (All, Pending, Completed)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('すべて', EventFilter.all),
              const SizedBox(width: 6),
              _buildFilterChip('進行中', EventFilter.pending),
              const SizedBox(width: 6),
              _buildFilterChip('完了', EventFilter.completed),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Event List or Empty State
        if (isExpanded)
          Expanded(
            child: filteredEvents.isEmpty
                ? _buildEmptyState(colorScheme)
                : ListView.builder(
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return EventListItem(
                        key: ValueKey(event.id),
                        event: event,
                        onToggleComplete: (val) => _toggleComplete(event.id),
                        onEdit: () => _showEditEventDialog(event),
                        onDelete: () => _deleteEvent(event.id),
                      );
                    },
                  ),
          )
        else
          filteredEvents.isEmpty
              ? _buildEmptyState(colorScheme)
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return EventListItem(
                      key: ValueKey(event.id),
                      event: event,
                      onToggleComplete: (val) => _toggleComplete(event.id),
                      onEdit: () => _showEditEventDialog(event),
                      onDelete: () => _deleteEvent(event.id),
                    );
                  },
                ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, EventFilter filter) {
    final isSelected = _currentFilter == filter;
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: colorScheme.primaryContainer,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _currentFilter = filter;
          });
        }
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note,
                size: 40,
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? '検索結果に一致する予定がありません。'
                  : '登録された予定がありません。',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? '検索キーワードを変更してください。'
                  : '新しい予定を追加して通知を設定してみましょう！',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新しい予定を追加'),
              onPressed: () => _showAddEventDialog(_selectedDay),
            ),
          ],
        ),
      ),
    );
  }
}
