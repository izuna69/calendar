import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class TrayAndWindowService with WindowListener, TrayListener {
  static final TrayAndWindowService instance = TrayAndWindowService._();
  TrayAndWindowService._();

  VoidCallback? onQuickAddRequested;

  Future<void> init({bool isAutoStartLaunch = false}) async {
    // 1. Window Manager 初期化
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1080, 780),
      minimumSize: Size(880, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'スケジュール＆カレンダー',
    );

    windowManager.addListener(this);

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
      if (!isAutoStartLaunch) {
        await windowManager.show();
        await windowManager.focus();
      } else {
        // PC起動時はバックグラウンド(トレイ)で待機
        await windowManager.hide();
      }
    });

    // 2. Launch At Startup (PC起動時自動起動) 設定
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        LaunchAtStartup.instance.setup(
          appName: 'ScheduleCalendarApp',
          appPath: Platform.resolvedExecutable,
          args: ['--autostart'],
        );

        final shouldAutoStart = StorageService.getAutoStart();
        final isCurrentlyEnabled = await LaunchAtStartup.instance.isEnabled();
        if (shouldAutoStart && !isCurrentlyEnabled) {
          await LaunchAtStartup.instance.enable();
        } else if (!shouldAutoStart && isCurrentlyEnabled) {
          await LaunchAtStartup.instance.disable();
        }
      } catch (e) {
        debugPrint('[TrayAndWindowService] LaunchAtStartup setup error: $e');
      }
    }

    // 3. Tray Manager 初期化
    try {
      trayManager.addListener(this);
      await _setupTray();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Tray setup error: $e');
    }
  }

  Future<void> _setupTray() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        await trayManager.setIcon('assets/app_icon.ico');
        await trayManager.setToolTip('スケジュール＆カレンダー');
      }
      await updateTrayMenu();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error setting up tray icon/menu: $e');
    }
  }

  Future<void> updateTrayMenu() async {
    try {
      final isAutoStart = await LaunchAtStartup.instance.isEnabled();
      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_app',
            label: 'カレンダーを開く',
          ),
          MenuItem(
            key: 'quick_add',
            label: '新しい予定を追加',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'test_notification',
            label: '通知テスト',
          ),
          MenuItem.checkbox(
            key: 'toggle_auto_start',
            label: 'PC起動時に自動起動',
            checked: isAutoStart,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'アプリを終了',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error updating tray menu: $e');
    }
  }

  Future<void> showAppWindow() async {
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.focus();
  }

  Future<void> hideToTray() async {
    await windowManager.hide();
  }

  Future<void> exitApp() async {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    NotificationService.stopScheduler();
    try {
      await trayManager.destroy();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Tray destroy error: $e');
    }
    await windowManager.destroy();
    exit(0);
  }

  Future<void> toggleAutoStart(bool enable) async {
    try {
      if (enable) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
      await StorageService.setAutoStart(enable);

      await updateTrayMenu();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Error toggling auto-start: $e');
    }
  }



  // WindowListener Callbacks
  @override
  void onWindowClose() async {
    final minimizeToTray = StorageService.getMinimizeToTray();
    if (minimizeToTray) {
      // ウィンドウを閉じるとトレイへ隠す
      await hideToTray();
    } else {
      await exitApp();
    }
  }
  // TrayListener Callbacks



  @override
  void onTrayIconMouseDown() async {
    await showAppWindow();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }




  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_app':
        await showAppWindow();
        break;
      case 'quick_add':
        await showAppWindow();
        onQuickAddRequested?.call();
        break;
      case 'test_notification':
        await NotificationService.showTestNotification();
        break;
      case 'toggle_auto_start':
        final current = await LaunchAtStartup.instance.isEnabled();
        await toggleAutoStart(!current);
        break;
      case 'exit_app':
        await exitApp();
        break;
    }
  }
}
