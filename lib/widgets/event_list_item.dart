import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_event.dart';

class EventListItem extends StatelessWidget {
  final ScheduleEvent event;
  final ValueChanged<bool?> onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EventListItem({
    super.key,
    required this.event,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onDelete,
  });

  String _getReminderLabel(int minutes) {
    if (minutes == 0) return '時間ちょうど';
    if (minutes < 60) return '$minutes分前';
    if (minutes == 60) return '1時間前';
    return '${(minutes / 1440).round()}日前';
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = NumberFormat('00');
    final isDone = event.isCompleted;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDone ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone
                ? Colors.grey.withValues(alpha: 0.2)
                : event.color.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Color accent bar
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: event.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Checkbox
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Checkbox(
                  value: event.isCompleted,
                  activeColor: event.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: onToggleComplete,
                ),
              ),

              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title & Badges
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: isDone
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Description
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          event.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Tags/Badges: Time, Notification
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Time tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: event.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_filled,
                                  size: 12,
                                  color: event.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  event.hasTime
                                      ? '${timeFormat.format(event.hour)}:${timeFormat.format(event.minute)}'
                                      : '終日',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: event.color,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Notification tag
                          if (event.enableNotification)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.notifications_active,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getReminderLabel(event.notificationOffsetMinutes),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Google Sync tag
                          if (event.isGoogleSynced)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cloud_done,
                                    size: 11,
                                    color: Color(0xFF4285F4),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Google',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons: Edit, Delete
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: '予定を編集',
                    splashRadius: 18,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    tooltip: '予定を削除',
                    splashRadius: 18,
                    onPressed: () => _confirmDelete(context),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('予定の削除'),
            ],
          ),
          content: Text('「${event.title}」を本当に削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete();
              },
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }
}
