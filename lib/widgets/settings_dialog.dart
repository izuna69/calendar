import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/tray_and_window_service.dart';

class SettingsDialog extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;

  const SettingsDialog({super.key, this.onThemeChanged});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late bool _autoStart;
  late bool _minimizeToTray;
  late bool _darkMode;

  @override
  void initState() {
    super.initState();
    _autoStart = StorageService.getAutoStart();
    _minimizeToTray = StorageService.getMinimizeToTray();
    _darkMode = StorageService.getDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '環境設定',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Auto-start on boot
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.power_settings_new),
              title: const Text(
                'PC起動時に自動起動',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
              subtitle: const Text(
                'パソコン起動時にバックグラウンド（トレイ）で起動し、通知を待機します。',
                style: TextStyle(fontSize: 12),
              ),
              value: _autoStart,
              onChanged: (val) async {
                setState(() {
                  _autoStart = val;
                });
                await TrayAndWindowService.instance.toggleAutoStart(val);
              },
            ),
            const Divider(height: 20),

            // 2. Minimize to tray on close
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.archive_outlined),
              title: const Text(
                'ウィンドウを閉じた時にトレイへ最小化',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
              subtitle: const Text(
                '×ボタンを押してもアプリを終了せず、トレイに常駐して通知を維持します。',
                style: TextStyle(fontSize: 12),
              ),
              value: _minimizeToTray,
              onChanged: (val) async {
                setState(() {
                  _minimizeToTray = val;
                });
                await StorageService.setMinimizeToTray(val);
              },
            ),
            const Divider(height: 20),

            // 3. Dark mode
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text(
                'ダークモード',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
              subtitle: const Text(
                'ダークテーマに切り替えます。',
                style: TextStyle(fontSize: 12),
              ),
              value: _darkMode,
              onChanged: (val) async {
                setState(() {
                  _darkMode = val;
                });
                await StorageService.setDarkMode(val);
                widget.onThemeChanged?.call(val);
              },
            ),
            const Divider(height: 20),

            // 4. Test Notification Button
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text(
                'Windows通知テスト',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
              subtitle: const Text(
                'Windowsのトースト通知が正常に表示されるか確認します。',
                style: TextStyle(fontSize: 12),
              ),
              trailing: FilledButton.tonal(
                onPressed: () {
                  NotificationService.showTestNotification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('テスト通知を送信しました。'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('通知テスト'),
              ),
            ),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
