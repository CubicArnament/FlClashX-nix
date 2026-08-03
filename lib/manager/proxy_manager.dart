import 'package:flclashx/common/proxy.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  const ProxyManager({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProxyManager> createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  Future<void> _updateProxy(ProxyState state) async {
    if (state.isStart && state.systemProxy) {
      await proxy?.startProxy(state.port, state.bassDomain);
    } else {
      await proxy?.stopProxy();
    }
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      proxyStateProvider,
      (previous, next) {
        if (previous != next) _updateProxy(next);
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
