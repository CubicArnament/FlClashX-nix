import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';

class CoreUpdater {
  factory CoreUpdater() {
    _instance ??= CoreUpdater._internal();
    return _instance!;
  }

  CoreUpdater._internal();

  static CoreUpdater? _instance;

  String? _cachedHash;
  DateTime? _cachedMtime;
  int? _cachedSize;

  /// SHA-256 of the core binary currently on disk. Cached by mtime+size so
  /// repeated helper pings don't rehash the file.
  Future<String?> calcCoreSha256() async {
    try {
      final file = File(appPath.corePath);
      final stat = await file.stat();
      if (_cachedHash != null &&
          stat.modified == _cachedMtime &&
          stat.size == _cachedSize) {
        return _cachedHash;
      }
      final digest = await sha256.bind(file.openRead()).first;
      _cachedMtime = stat.modified;
      _cachedSize = stat.size;
      _cachedHash = digest.toString();
      return _cachedHash;
    } catch (e) {
      commonPrint.log("calcCoreSha256 failed: $e");
      return null;
    }
  }

  /// Swap the core for a downloaded `.pending` binary. Must run before any core
  /// process is spawned so the whole session uses the new core.
  Future<void> applyPending() async {
    final pending = File(appPath.corePendingPath);
    if (!await pending.exists()) {
      return;
    }
    commonPrint.log("Applying pending core update...");
    try {
      final target = File(appPath.corePath);
      if (await target.exists()) {
        for (var i = 0; i < 10; i++) {
          try {
            await target.delete();
            break;
          } catch (_) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      await pending.rename(appPath.corePath);
      await Process.run('chmod', ['+x', appPath.corePath]);
      commonPrint.log("Pending core update applied successfully");
    } catch (e) {
      commonPrint.log("Failed to apply pending core update: $e");
    }
  }

}

final coreUpdater = CoreUpdater();
