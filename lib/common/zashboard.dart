import 'package:flclashx/state.dart';

// Public zashboard instance, used when the profile doesn't self-host one (no
// external-ui set). Change this to point at a different hosted dashboard.
const publicZashboardBase = 'https://board.zash.run.place';

/// Builds the zashboard URL pointed at this client's external-controller:
/// .../#/setup?hostname=host&port=port&secret=secret&http=1 — host/port and
/// secret are taken from the active profile's external-controller config.
/// Returns null when external-controller is not set.
String? buildZashboardUrl() {
  final ec = globalState.effectiveExternalController.value.trim();
  if (ec.isEmpty) return null;
  final idx = ec.lastIndexOf(':');
  var host = idx > 0 ? ec.substring(0, idx).trim() : '';
  final port = idx >= 0 ? ec.substring(idx + 1).trim() : ec.trim();
  // 0.0.0.0/empty bind addresses aren't browser-reachable; assume same device.
  if (host.isEmpty || host == '0.0.0.0' || host == '::') {
    host = '127.0.0.1';
  }
  final secret = globalState.effectiveSecret.value.trim();
  // `http=1` forces zashboard's backend protocol to plain HTTP. Without it,
  // getBackendFromUrl falls back to the page's own protocol — and the public
  // instance is served over HTTPS, so it would probe https://host:port and the
  // auto-verify fails ("Backend configuration failed") even though the core
  // only speaks HTTP. The value must be non-empty (JS treats "" as falsy).
  final query =
      'hostname=$host&port=$port&secret=${Uri.encodeQueryComponent(secret)}&http=1';
  // Self-hosted: the core serves zashboard at external-ui (e.g. /ui/). When no
  // external-ui is set, fall back to the public instance so users who don't host
  // their own dashboard still get a working link.
  final ui = globalState.effectiveExternalUi.value
      .trim()
      .replaceAll(RegExp(r'^/+|/+$'), '');
  if (ui.isEmpty) {
    return '$publicZashboardBase/#/setup?$query';
  }
  return 'http://$host:$port/$ui/#/setup?$query';
}
