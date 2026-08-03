import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/plugins/app.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/input.dart';
import 'package:flutter/services.dart';

class System {

  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  System._internal();
  static System? _instance;
  bool get isDesktop => Platform.isLinux;

  bool get isMobile => Platform.isAndroid;

  Future<bool> get isAndroidTV async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.systemFeatures.contains('android.software.leanback');
  }

  Future<int> get version async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    return switch (Platform.operatingSystem) {
      "android" => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      String() => 0
    };
  }

  Future<bool> checkIsAdmin() async {
    final corePath = appPath.corePath.replaceAll(' ', r'\\ ');
    if (Platform.isLinux) {
      final result = await Process.run('stat', ['-c', '%U:%G %A', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:') && output.contains('rws')) {
        return true;
      }
      return false;
    }
    return true;
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (Platform.isAndroid) {
      return AuthorizeCode.error;
    }

    final corePath = appPath.corePath.replaceAll(' ', r'\\ ');
    final isAdmin = await checkIsAdmin();
    if (isAdmin) {
      return AuthorizeCode.none;
    }

    if (Platform.isLinux) {
      final password = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.pleaseInputAdminPassword,
          value: '',
        ),
      );
      if (password == null) return AuthorizeCode.error;
      final proc = await Process.start('sudo', [
        '-S', 'sh', '-c',
        'chown root:root "\$1" && chmod +sx "\$1"',
        'sh', corePath,
      ]);
      proc.stdin.writeln(password);
      await proc.stdin.close();
      final exitCode = await proc.exitCode;
      if (exitCode != 0) {
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    }
    return AuthorizeCode.error;
  }

  Future<void> back() async {
    await app?.moveTaskToBack();
    await window?.hide();
  }

  Future<void> exit() async {
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    }
    await window?.close();
  }
}

final system = System();
