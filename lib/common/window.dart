import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  Future<void> init(int version) async {
    final props = globalState.config.windowProps;
    final acquire = await singleInstanceLock.acquire();
    if (!acquire) {
      exit(0);
    }
    await windowManager.ensureInitialized();
    final windowOptions = WindowOptions(
      size: Size(props.width, props.height),
      // Lock the minimum window size to 380×600 so it can't be shrunk below that
      // in either dimension — only grown.
      minimumSize: const Size(380, 600),
    );
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    final left = props.left ?? 0;
    final top = props.top ?? 0;
    final right = left + props.width;
    final bottom = top + props.height;
    if (left == 0 && top == 0) {
      await windowManager.setAlignment(Alignment.center);
    } else {
      final displays = await screenRetriever.getAllDisplays();
      final isPositionValid = displays.any(
        (display) {
          final displayBounds = Rect.fromLTWH(
            display.visiblePosition!.dx,
            display.visiblePosition!.dy,
            display.size.width,
            display.size.height,
          );
          return displayBounds.contains(Offset(left, top)) ||
              displayBounds.contains(Offset(right, bottom));
        },
      );
      if (isPositionValid) {
        await windowManager.setPosition(Offset(left, top));
      }
    }
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
    });
  }

  Future<void> show() async {
    render?.resume();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
  }

  Future<bool> get isVisible async {
    final value = await windowManager.isVisible();
    commonPrint.log("window visible check: $value");
    return value;
  }

  Future<void> close() async {
    exit(0);
  }

  Future<void> hide() async {
    render?.pause();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}

final window = system.isDesktop ? Window() : null;
