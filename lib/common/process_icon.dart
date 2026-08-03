import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

/// connectionId -> originating process exe path, captured from the raw getConnections
/// JSON (mihomo sends `metadata.processPath`, which the Connection model drops). Used
/// to extract the app icon on desktop. Rebuilt on every getConnections poll.
final Map<String, String> connectionProcessPaths = {};

// Best-effort app icon for a Linux process: map the exe/process to its .desktop
// entry, read Icon=, then resolve that through the standard freedesktop icon
// dirs to a PNG. SVG-only apps and sandboxed Flatpak/Snap paths won't resolve
// and fall back to the generic icon (same as before) — so this only ever adds
// icons, never removes them.
final Map<String, Future<ImageProvider?>?> _linuxIconCache = {};
// binary basename (and StartupWMClass) -> Icon= name, built once from the
// applications dirs.
Future<Map<String, String>>? _desktopIndex;

Future<ImageProvider?>? linuxProcessIcon(String connectionId, String process) {
  final path = connectionProcessPaths[connectionId] ?? '';
  final base = path.isNotEmpty ? p.basename(path) : process;
  if (base.isEmpty) return null;
  return _linuxIconCache.putIfAbsent(base, () => _resolveLinuxIcon(base, process));
}
Future<ImageProvider?> _resolveLinuxIcon(String binary, String process) async {
  final index = await (_desktopIndex ??= _buildDesktopIndex());
  final iconName = index[binary] ??
      index[process.toLowerCase()] ??
      // No .desktop match — try the binary name itself as an icon name, which
      // works for a surprising number of apps (firefox, telegram, code, …).
      binary;
  if (iconName.isEmpty) return null;
  if (iconName.startsWith('/')) {
    final f = File(iconName);
    return await f.exists() ? FileImage(f) : null;
  }
  final file = await _findIconFile(iconName);
  return file == null ? null : FileImage(file);
}

Future<Map<String, String>> _buildDesktopIndex() async {
  final index = <String, String>{};
  final home = Platform.environment['HOME'] ?? '';
  final dirs = <String>[
    if (home.isNotEmpty) '$home/.local/share/applications',
    if (home.isNotEmpty) '$home/.local/share/flatpak/exports/share/applications',
    '/usr/local/share/applications',
    '/usr/share/applications',
    '/var/lib/flatpak/exports/share/applications',
  ];
  for (final d in dirs) {
    final dir = Directory(d);
    if (!await dir.exists()) continue;
    try {
      await for (final entry in dir.list()) {
        if (entry is! File || !entry.path.endsWith('.desktop')) continue;
        try {
          String? exec, icon, wmClass;
          for (final line in await entry.readAsLines()) {
            if (icon == null && line.startsWith('Icon=')) {
              icon = line.substring(5).trim();
            } else if (exec == null && line.startsWith('Exec=')) {
              exec = line.substring(5).trim();
            } else if (wmClass == null && line.startsWith('StartupWMClass=')) {
              wmClass = line.substring(15).trim();
            }
          }
          if (icon == null || icon.isEmpty) continue;
          final bin = exec == null ? '' : _execBinary(exec);
          // Earlier dirs (user/local) win over system ones.
          if (bin.isNotEmpty) index.putIfAbsent(bin, () => icon!);
          if (wmClass != null && wmClass.isNotEmpty) {
            index.putIfAbsent(wmClass.toLowerCase(), () => icon!);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
  return index;
}

// First whitespace token of Exec, minus quotes and %-field-codes, as a basename.
String _execBinary(String exec) {
  for (final token in exec.split(RegExp(r'\s+'))) {
    final t = token.replaceAll('"', '');
    if (t.isEmpty || t.startsWith('%') || t.contains('=')) continue;
    return p.basename(t);
  }
  return '';
}

Future<File?> _findIconFile(String name) async {
  final home = Platform.environment['HOME'] ?? '';
  final roots = <String>[
    if (home.isNotEmpty) '$home/.local/share/icons',
    '/usr/local/share/icons',
    '/usr/share/icons',
  ];
  const themes = ['hicolor', 'Adwaita', 'breeze', 'gnome'];
  const sizes = [
    '512x512',
    '256x256',
    '128x128',
    '96x96',
    '64x64',
    '48x48',
  ];
  for (final root in roots) {
    for (final theme in themes) {
      for (final size in sizes) {
        final f = File('$root/$theme/$size/apps/$name.png');
        if (await f.exists()) return f;
      }
    }
  }
  for (final dir in ['/usr/share/pixmaps', '/usr/local/share/pixmaps']) {
    final f = File('$dir/$name.png');
    if (await f.exists()) return f;
  }
  return null;
}
