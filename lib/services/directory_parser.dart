import 'dart:async';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single parsed entry from a directory index.
class DirectoryEntry {
  final String name;
  final String url;
  final bool isDirectory;
  final int? sizeBytes;
  final DateTime? lastModified;
  final String? extension;

  const DirectoryEntry({
    required this.name,
    required this.url,
    required this.isDirectory,
    this.sizeBytes,
    this.lastModified,
    this.extension,
  });

  String get formattedSize {
    if (sizeBytes == null) return '-';
    final s = sizeBytes!;
    if (s < 1024) return '$s B';
    if (s < 1048576) return '${(s / 1024).toStringAsFixed(1)} KB';
    if (s < 1073741824) return '${(s / 1048576).toStringAsFixed(1)} MB';
    return '${(s / 1073741824).toStringAsFixed(2)} GB';
  }
}

/// Detected server type for a directory page.
enum DirectoryServerType { apache, nginx, autoIndex, lighttpd, ftp, unknown }

/// Result of parsing a directory page.
class DirectoryParseResult {
  final String url;
  final List<DirectoryEntry> entries;
  final DirectoryServerType serverType;
  final String? parentUrl;

  const DirectoryParseResult({
    required this.url,
    required this.entries,
    required this.serverType,
    this.parentUrl,
  });
}

/// Provider for the directory parser service.
final directoryParserProvider = Provider<DirectoryParserService>(
  (_) => DirectoryParserService(),
);

/// Parses directory index HTML pages from Apache, Nginx, AutoIndex, Lighttpd, and FTP servers.
/// All heavy work runs on an Isolate to avoid UI jank.
class DirectoryParserService {
  /// Parse the raw HTML of a directory page at [url].
  /// Returns [DirectoryParseResult] asynchronously on a background isolate.
  Future<DirectoryParseResult> parse({
    required String url,
    required String html,
  }) async {
    final result = await Isolate.run<Map<String, dynamic>>(
      () => _parseWorker({'url': url, 'html': html}),
    );
    return _resultFromMap(url, result);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Worker — executes on a background isolate
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _parseWorker(Map<String, dynamic> args) {
    final url = args['url'] as String;
    final html = args['html'] as String;

    final serverType = _detectServerType(html);
    final entries = _extractEntries(html, baseUrl: url);
    final parentUrl = _extractParent(html, baseUrl: url);

    return {
      'serverType': serverType.index,
      'parentUrl': parentUrl,
      'entries': entries
          .map((e) => {
                'name': e.name,
                'url': e.url,
                'isDirectory': e.isDirectory,
                'sizeBytes': e.sizeBytes,
                'lastModified': e.lastModified?.toIso8601String(),
                'extension': e.extension,
              })
          .toList(),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detection helpers
  // ─────────────────────────────────────────────────────────────────────────

  static DirectoryServerType _detectServerType(String html) {
    final lower = html.toLowerCase();
    if (lower.contains('apache') || lower.contains('index of /')) {
      return DirectoryServerType.apache;
    }
    if (lower.contains('nginx')) return DirectoryServerType.nginx;
    if (lower.contains('autoindex') || lower.contains('fancy indexes')) {
      return DirectoryServerType.autoIndex;
    }
    if (lower.contains('lighttpd')) return DirectoryServerType.lighttpd;
    if (lower.contains('ftp') && lower.contains('directory listing')) {
      return DirectoryServerType.ftp;
    }
    return DirectoryServerType.unknown;
  }

  static String? _extractParent(String html, {required String baseUrl}) {
    // Look for common "Parent Directory" link patterns.
    final patterns = [
      RegExp(r'href="(\.\./)"', caseSensitive: false),
      RegExp(r'href="(\.\.)"', caseSensitive: false),
      RegExp(r'Parent Directory.*?href="([^"]+)"', caseSensitive: false),
    ];
    for (final pat in patterns) {
      final m = pat.firstMatch(html);
      if (m != null) {
        return _resolveUrl(m.group(1) ?? '', baseUrl);
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Entry extraction — handles multiple server formats
  // ─────────────────────────────────────────────────────────────────────────

  static List<DirectoryEntry> _extractEntries(String html, {required String baseUrl}) {
    final entries = <DirectoryEntry>[];
    final seen = <String>{};

    // Match all anchor tags with href attributes.
    final hrefPattern = RegExp(
      r'<a\s[^>]*href="([^"?#][^"]*)"[^>]*>([^<]*)<\/a>',
      caseSensitive: false,
    );

    for (final m in hrefPattern.allMatches(html)) {
      final href = m.group(1)?.trim() ?? '';
      final name = m.group(2)?.trim() ?? '';
      if (href.isEmpty || name.isEmpty || name.toLowerCase() == 'parent directory' || href == '../') continue;
      if (seen.contains(href)) continue;
      seen.add(href);

      final resolvedUrl = _resolveUrl(href, baseUrl);
      final isDir = href.endsWith('/') || name.endsWith('/');
      final ext = isDir ? null : _extension(name);
      final sizeBytes = _parseSize(null);
      final lastModified = _parseDate(null);

      entries.add(DirectoryEntry(
        name: name.isEmpty ? href : name,
        url: resolvedUrl,
        isDirectory: isDir,
        sizeBytes: sizeBytes,
        lastModified: lastModified,
        extension: ext,
      ));
    }

    // Sort: directories first, then files by name
    entries.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  static String _resolveUrl(String href, String baseUrl) {
    if (href.startsWith('http://') || href.startsWith('https://')) return href;
    final base = Uri.tryParse(baseUrl);
    if (base == null) return href;
    try {
      return base.resolve(href).toString();
    } catch (_) {
      return href;
    }
  }

  static String? _extension(String name) {
    final idx = name.lastIndexOf('.');
    if (idx < 0 || idx == name.length - 1) return null;
    return name.substring(idx + 1).toLowerCase();
  }

  static int? _parseSize(String? raw) {
    if (raw == null || raw == '-' || raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    final num = double.tryParse(lower.replaceAll(RegExp(r'[kmg]'), ''));
    if (num == null) return null;
    if (lower.contains('k')) return (num * 1024).round();
    if (lower.contains('m')) return (num * 1048576).round();
    if (lower.contains('g')) return (num * 1073741824).round();
    return num.round();
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Deserialise result
  // ─────────────────────────────────────────────────────────────────────────

  static DirectoryParseResult _resultFromMap(String url, Map<String, dynamic> map) {
    final serverType = DirectoryServerType.values[map['serverType'] as int];
    final parentUrl = map['parentUrl'] as String?;
    final entriesList = map['entries'] as List<dynamic>;

    final entries = entriesList.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return DirectoryEntry(
        name: m['name'] as String,
        url: m['url'] as String,
        isDirectory: m['isDirectory'] as bool,
        sizeBytes: m['sizeBytes'] as int?,
        lastModified: m['lastModified'] != null
            ? DateTime.tryParse(m['lastModified'] as String)
            : null,
        extension: m['extension'] as String?,
      );
    }).toList();

    return DirectoryParseResult(
      url: url,
      entries: entries,
      serverType: serverType,
      parentUrl: parentUrl,
    );
  }
}
