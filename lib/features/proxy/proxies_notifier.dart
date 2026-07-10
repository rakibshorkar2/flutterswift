import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/models/proxy_config.dart';

/// Provider exposing the proxy list notifier.
final proxiesProvider =
    StateNotifierProvider<ProxiesNotifier, List<ProxyConfig>>(
  (ref) => ProxiesNotifier(),
);

/// Manages proxy configurations in-state. No persistence layer wired yet
/// (will be connected to Isar in a later phase).
class ProxiesNotifier extends StateNotifier<List<ProxyConfig>> {
  ProxiesNotifier() : super([]);

  void addProxy(ProxyConfig proxy) {
    state = [...state, proxy];
  }

  void removeProxy(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updateProxy(ProxyConfig updated) {
    state = [
      for (final p in state) p.id == updated.id ? updated : p,
    ];
  }

  /// Activate a single proxy and deactivate all others.
  void activateProxy(String id) {
    state = [
      for (final p in state) p.copyWith(isActive: p.id == id),
    ];
  }

  void deactivateAll() {
    state = [for (final p in state) p.copyWith(isActive: false)];
  }

  /// Test the latency of a proxy by attempting a TCP connection.
  Future<void> testProxy(String id) async {
    final proxy = state.firstWhere((p) => p.id == id);
    final sw = Stopwatch()..start();
    int? latency;
    try {
      final sock = await Socket.connect(
        proxy.host,
        proxy.port,
        timeout: const Duration(seconds: 5),
      );
      sw.stop();
      latency = sw.elapsedMilliseconds;
      await sock.close();
    } catch (_) {
      sw.stop();
      latency = null;
    }
    updateProxy(proxy.copyWith(latencyMs: latency));
  }

  ProxyConfig? get activeProxy {
    try {
      return state.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }
}
