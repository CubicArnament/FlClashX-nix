import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:window_manager/window_manager.dart';

// ===========================================================================
// Standalone config-editor window (macOS).
//
// macOS runs entirely from the tray popover — far too cramped to edit a config.
// desktop_multi_window spawns a second Flutter engine in a real resizable
// window that hosts re_editor (syntax highlighting + line numbers). That engine
// is a separate isolate with no access to app state or the core, so "Save"
// round-trips the text to the main engine over [_editorChannel]; the main engine
// owns the core, validates + persists, and replies with null (ok → close) or an
// error string (shown in the window).
// ===========================================================================

/// Cross-engine channel the editor window uses to reach the main engine.
/// Unidirectional: the main engine registers the handler, the sub-window
/// invokes it.
const _editorChannel =
    WindowMethodChannel('flclashx_editor', mode: ChannelMode.unidirectional);

// ---------------------------------------------------------------------------
// Sub-window side — runs in its own engine/isolate.
// ---------------------------------------------------------------------------

/// Entry point for the editor sub-window. desktop_multi_window launches the app
/// binary with dartEntrypointArguments `['multi_window', <windowId>, <json>]`;
/// main() routes here so none of the normal app boot (core/state/UI) runs.
Future<void> runEditorSubWindow(List<String> args) async {
  final argument = args.length > 2 && args[2].isNotEmpty
      ? jsonDecode(args[2]) as Map<String, dynamic>
      : const <String, dynamic>{};
  final title = (argument['title'] as String?) ?? '';

  await windowManager.ensureInitialized();
  unawaited(
    windowManager.waitUntilReadyToShow(
      WindowOptions(size: const Size(1000, 720), center: true, title: title),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    ),
  );

  runApp(
    _EditorWindowApp(
      title: title,
      content: (argument['content'] as String?) ?? '',
      isDark: argument['isDark'] == true,
      saveLabel: (argument['saveLabel'] as String?) ?? 'Save',
    ),
  );
}

class _EditorWindowApp extends StatelessWidget {
  const _EditorWindowApp({
    required this.title,
    required this.content,
    required this.isDark,
    required this.saveLabel,
  });

  final String title;
  final String content;
  final bool isDark;
  final String saveLabel;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          useMaterial3: true,
        ),
        home: _EditorWindow(
          title: title,
          content: content,
          isDark: isDark,
          saveLabel: saveLabel,
        ),
      );
}

class _EditorWindow extends StatefulWidget {
  const _EditorWindow({
    required this.title,
    required this.content,
    required this.isDark,
    required this.saveLabel,
  });

  final String title;
  final String content;
  final bool isDark;
  final String saveLabel;

  @override
  State<_EditorWindow> createState() => _EditorWindowState();
}

class _EditorWindowState extends State<_EditorWindow> {
  late final CodeLineEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText(widget.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // The main engine owns the core — it validates + persists and returns an
      // error message, or null on success.
      final error =
          await _editorChannel.invokeMethod<String>('saveConfig', _controller.text);
      if (error != null && error.isNotEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }
      await windowManager.close();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(widget.saveLabel),
              ),
            ),
          ],
        ),
        body: CodeEditor(
          controller: _controller,
          autocompleteSymbols: true,
          indicatorBuilder:
              (context, editingController, chunkController, notifier) => Row(
            children: [
              DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
              ),
              DefaultCodeChunkIndicator(
                width: 20,
                controller: chunkController,
                notifier: notifier,
              ),
            ],
          ),
          shortcutsActivatorsBuilder:
              const DefaultCodeShortcutsActivatorsBuilder(),
          style: CodeEditorStyle(
            fontSize: 14,
            fontFamily: 'JetBrainsMono',
            codeTheme: CodeHighlightTheme(
              languages: {'yaml': CodeHighlightThemeMode(mode: langYaml)},
              theme: widget.isDark ? atomOneDarkTheme : atomOneLightTheme,
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Main-window side — runs in the app's main engine/isolate.
// ---------------------------------------------------------------------------

/// Validates + persists [content], returning null on success or an error
/// message to show in the editor window.
typedef EditorSaveHandler = Future<String?> Function(String content);

class EditorWindowBridge {
  EditorWindowBridge._();

  static bool _handlerReady = false;
  static EditorSaveHandler? _onSave;

  static void _ensureHandler() {
    if (_handlerReady) return;
    _handlerReady = true;
    _editorChannel.setMethodCallHandler((call) async {
      if (call.method == 'saveConfig') {
        final onSave = _onSave;
        if (onSave == null) return 'no active editor';
        return onSave(call.arguments as String);
      }
      return null;
    });
  }

  /// Opens the config editor in a standalone native window. [onSave] runs here
  /// in the main isolate (it has the core) when the window's Save is pressed.
  static Future<void> open({
    required String title,
    required String content,
    required bool isDark,
    required String saveLabel,
    required EditorSaveHandler onSave,
  }) async {
    _ensureHandler();
    _onSave = onSave;
    await WindowController.create(
      WindowConfiguration(
        arguments: jsonEncode({
          'title': title,
          'content': content,
          'isDark': isDark,
          'saveLabel': saveLabel,
        }),
      ),
    );
  }
}
