import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens zashboard pointed at this client's external-controller: in the built-in
/// webview when [inApp] is set and the platform has a webview implementation,
/// otherwise in the external browser.
///
/// When the external-controller is off, the in-app panel turns it on for the
/// session and back off when the page closes. Only the in-app webview is
/// auto-managed — we can't detect when the external browser is closed, so there
/// the controller is left as the user set it.
Future<void> openZashboard(BuildContext context, {required bool inApp}) async {
  // The core self-hosts the dashboard when external-ui is set — then the panel
  // is a plain-http URL on the loopback controller (see buildZashboardUrl). The
  // public fallback is https.
  final isLocalPanel = globalState.effectiveExternalUi.value.trim().isNotEmpty;
  // In-app webview on Android. Linux opens it in the external
  // browser (the loopback-http URL works there too).
  final canWebView = Platform.isAndroid;
  final useWebView = inApp && canWebView;
  final controllerWasOff =
      globalState.effectiveExternalController.value.trim().isEmpty;
  final manageController = useWebView && controllerWasOff;

  if (manageController) {
    try {
      await globalState.appController.setExternalControllerEnabled(true);
    } catch (_) {
      // If enabling failed the URL will still be empty below and we bail out.
    }
  }

  // Local panel: the core serves the dashboard from the external-ui dir, so make
  // sure it's downloaded before we open it (first use only, then cached).
  if (isLocalPanel && !await isZashboardUiReady()) {
    if (context.mounted) {
      globalState.showNotifier(appLocalizations.downloadingZashboard);
    }
    final ok = await ensureZashboardUi();
    if (!ok) {
      if (manageController) {
        await globalState.appController.setExternalControllerEnabled(false);
      }
      return;
    }
  }

  final url = buildZashboardUrl();
  if (url == null) {
    if (manageController) {
      await globalState.appController.setExternalControllerEnabled(false);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('external-controller is not set')),
      );
    }
    return;
  }

  if (!context.mounted) {
    if (manageController) {
      await globalState.appController.setExternalControllerEnabled(false);
    }
    return;
  }

  if (useWebView) {
    await BaseNavigator.push(
      context,
      ZashboardWebViewPage(
        url: url,
        disableControllerOnClose: manageController,
      ),
    );
    return;
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// In-app zashboard panel. The webview is created per open and released when the
/// page closes — the native view is torn down with the widget, so it doesn't
/// keep polling the core or holding memory in the background (no static cache).
/// When this page is the one that turned the external-controller on, it turns it
/// back off on close.
class ZashboardWebViewPage extends StatefulWidget {
  const ZashboardWebViewPage({
    super.key,
    required this.url,
    this.disableControllerOnClose = false,
  });

  final String url;
  final bool disableControllerOnClose;

  @override
  State<ZashboardWebViewPage> createState() => _ZashboardWebViewPageState();
}

class _ZashboardWebViewPageState extends State<ZashboardWebViewPage> {
  late final WebViewController _controller;
  final _progress = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller.setBackgroundColor(const Color(0x00000000));
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (progress) => _progress.value = progress,
        onPageFinished: (_) => _progress.value = 100,
        onWebResourceError: (error) {
          _progress.value = 100;
          commonPrint.log(
            'zashboard webview error: ${error.errorCode} ${error.description}',
          );
        },
      ),
    );
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _progress.dispose();
    if (widget.disableControllerOnClose) {
      // Fire-and-forget (dispose can't await): turn the external-controller back
      // off now that the panel we opened it for is gone.
      globalState.appController.setExternalControllerEnabled(false);
    }
    super.dispose();
  }

  Widget _progressBar() => ValueListenableBuilder<int>(
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
      );

  void _openExternally() => launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) => CommonScaffold(
        // Android only. No PopScope: the app-bar back arrow pops the route,
        // so "back" always
        // closes the panel (we never walk the webview history).
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
            onPressed: _openExternally,
          ),
        ],
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            _progressBar(),
          ],
        ),
      );
}
