import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens zashboard pointed at this client's external-controller: in the
/// built-in webview when [inApp] is set and the platform has a webview
/// implementation, otherwise in the external browser.
Future<void> openZashboard(BuildContext context, {required bool inApp}) async {
  final url = buildZashboardUrl();
  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('external-controller is not set')),
    );
    return;
  }
  if (inApp && ZashboardWebViewPage.supported) {
    await BaseNavigator.push(context, ZashboardWebViewPage(url: url));
    return;
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// In-app zashboard panel. The [WebViewController] — and with it the native
/// webview holding the loaded page, cookies and localStorage — is cached in a
/// static across openings, so only the first open pays the page load; closing
/// and reopening reattaches the live page instantly (Clash Mi Board-style).
/// The cache is rebuilt when the URL changes (profile/secret/port switch).
class ZashboardWebViewPage extends StatefulWidget {
  const ZashboardWebViewPage({super.key, required this.url});

  final String url;

  /// webview_flutter ships no Windows/Linux implementation — callers fall back
  /// to the external browser there.
  static bool get supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  State<ZashboardWebViewPage> createState() => _ZashboardWebViewPageState();
}

class _ZashboardWebViewPageState extends State<ZashboardWebViewPage> {
  static WebViewController? _cachedController;
  static String? _cachedUrl;

  late final WebViewController _controller;
  final _progress = ValueNotifier<int>(100);

  @override
  void initState() {
    super.initState();
    final cached = _cachedController;
    if (cached != null && _cachedUrl == widget.url) {
      _controller = cached;
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // Transparent so the scaffold surface shows through while the page
        // paints — avoids a white flash in dark theme.
        ..setBackgroundColor(const Color(0x00000000))
        ..loadRequest(Uri.parse(widget.url));
      _cachedController = _controller;
      _cachedUrl = widget.url;
      _progress.value = 0;
    }
    // The delegate is rebound on every open: it captures this State's progress
    // notifier, and the cached controller still holds the previous State's.
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (progress) => _progress.value = progress,
        onPageFinished: (_) => _progress.value = 100,
      ),
    );
  }

  @override
  void dispose() {
    // The controller is intentionally NOT disposed — it stays cached so the
    // next open is instant.
    _progress.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBack();
        },
        child: CommonScaffold(
          title: 'zashboard',
          actions: [
            IconButton(
              tooltip: appLocalizations.update,
              icon: const Icon(Icons.refresh),
              onPressed: _controller.reload,
            ),
            IconButton(
              tooltip: appLocalizations.externalLink,
              icon: const Icon(Icons.open_in_browser),
              onPressed: () {
                launchUrl(
                  Uri.parse(widget.url),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
          body: Stack(
            children: [
              WebViewWidget(controller: _controller),
              ValueListenableBuilder<int>(
                valueListenable: _progress,
                builder: (_, progress, __) {
                  if (progress >= 100) {
                    return const SizedBox.shrink();
                  }
                  return LinearProgressIndicator(
                    value: progress == 0 ? null : progress / 100,
                    minHeight: 2,
                  );
                },
              ),
            ],
          ),
        ),
      );
}
