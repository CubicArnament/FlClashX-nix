import 'dart:io';

import 'package:path/path.dart' show join;

enum _ProxyType { http, https, socks }

class LinuxProxy {
  static const _host = '127.0.0.1';

  Future<bool> startProxy(int port, List<String> bypassDomains) async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return false;
      final configDir = join(home, '.config');
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'] ?? '';
      final isKde = desktop.toUpperCase().contains('KDE');
      final commands = <List<String>>[];

      if (isKde) {
        commands.addAll([
          _kdeCommand(configDir, 'ProxyType', '1'),
          _kdeCommand(configDir, 'NoProxyFor', bypassDomains.join(',')),
        ]);
      } else {
        commands.addAll([
          ['gsettings', 'set', 'org.gnome.system.proxy', 'mode', 'manual'],
          [
            'gsettings',
            'set',
            'org.gnome.system.proxy',
            'ignore-hosts',
            "['${bypassDomains.join("', '")}']",
          ],
        ]);
      }

      for (final type in _ProxyType.values) {
        if (isKde) {
          commands.add(
            _kdeCommand(
              configDir,
              '${type.name}Proxy',
              '${type.name}://$_host:$port',
            ),
          );
        } else {
          commands.addAll([
            [
              'gsettings',
              'set',
              'org.gnome.system.proxy.${type.name}',
              'host',
              _host,
            ],
            [
              'gsettings',
              'set',
              'org.gnome.system.proxy.${type.name}',
              'port',
              '$port',
            ],
          ]);
        }
      }
      return _run(commands);
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopProxy() async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return false;
      final configDir = join(home, '.config');
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'] ?? '';
      final isKde = desktop.toUpperCase().contains('KDE');
      return _run([
        if (isKde)
          _kdeCommand(configDir, 'ProxyType', '0')
        else
          ['gsettings', 'set', 'org.gnome.system.proxy', 'mode', 'none'],
      ]);
    } catch (_) {
      return false;
    }
  }

  List<String> _kdeCommand(String configDir, String key, String value) => [
        'kwriteconfig5',
        '--file',
        join(configDir, 'kioslaverc'),
        '--group',
        'Proxy Settings',
        '--key',
        key,
        value,
      ];

  Future<bool> _run(List<List<String>> commands) async {
    for (final command in commands) {
      final result = await Process.run(command.first, command.sublist(1));
      if (result.exitCode != 0) return false;
    }
    return true;
  }
}

final proxy = Platform.isLinux ? LinuxProxy() : null;
