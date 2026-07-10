/// Supported proxy protocol types.
enum ProxyType { http, https, socks4, socks5 }

/// Represents a single proxy configuration.
class ProxyConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final ProxyType type;
  final String? username;
  final String? password;
  final bool isActive;
  final int? latencyMs; // null = untested
  final DateTime createdAt;

  const ProxyConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.type,
    this.username,
    this.password,
    this.isActive = false,
    this.latencyMs,
    required this.createdAt,
  });

  ProxyConfig copyWith({
    String? name,
    String? host,
    int? port,
    ProxyType? type,
    String? username,
    String? password,
    bool? isActive,
    int? latencyMs,
  }) {
    return ProxyConfig(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      type: type ?? this.type,
      username: username ?? this.username,
      password: password ?? this.password,
      isActive: isActive ?? this.isActive,
      latencyMs: latencyMs ?? this.latencyMs,
      createdAt: createdAt,
    );
  }

  String get typeLabel {
    switch (type) {
      case ProxyType.http:
        return 'HTTP';
      case ProxyType.https:
        return 'HTTPS';
      case ProxyType.socks4:
        return 'SOCKS4';
      case ProxyType.socks5:
        return 'SOCKS5';
    }
  }

  String get address => '$host:$port';

  bool get hasAuth => username != null && username!.isNotEmpty;

  String get latencyLabel {
    if (latencyMs == null) return 'Not tested';
    if (latencyMs! < 100) return '${latencyMs}ms ⚡';
    if (latencyMs! < 500) return '${latencyMs}ms';
    return '${latencyMs}ms 🐢';
  }
}
