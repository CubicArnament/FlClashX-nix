import 'package:flclashx/common/common.dart';
import 'package:flclashx/providers/state.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayManager extends ConsumerStatefulWidget {
  const TrayManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<TrayManager> createState() => _TrayContainerState();
}

class _TrayContainerState extends ConsumerState<TrayManager> with TrayListener, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      trayStateProvider,
      (prev, next) {
        if (prev != next) {
          globalState.appController.updateTray();
        }
      },
    );
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.updateTray();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      globalState.appController.updateTray();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    render?.active();
    super.onTrayMenuItemClick(menuItem);
  }

  @override
  void onTrayIconMouseDown() {
    window?.show();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    trayManager.removeListener(this);
    super.dispose();
  }
}
