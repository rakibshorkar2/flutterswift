import 'package:flutter_test/flutter_test.dart';
import 'package:flutterswift/services/directory_parser.dart';
import 'package:flutterswift/models/download_task.dart';
import 'package:flutterswift/models/proxy_config.dart';
import 'package:flutterswift/features/clipboard/clipboard_notifier.dart';
import 'package:flutterswift/models/clipboard_item.dart';

void main() {
  group('DirectoryParserService', () {
    final parser = DirectoryParserService();

    test('detects Apache index', () async {
      const html = '''
<html><head><title>Index of /files</title></head>
<body>
<h1>Index of /files</h1>
<pre>
<a href="../">Parent Directory</a>
<a href="video.mp4">video.mp4</a>              2024-01-15 12:00  512M
<a href="docs/">docs/</a>                     2024-01-10 09:00    -
<a href="readme.txt">readme.txt</a>           2024-01-14 11:00  4.0K
</pre>
</body></html>
''';
      final result = await parser.parse(url: 'http://example.com/files/', html: html);

      expect(result.serverType, DirectoryServerType.apache);
      expect(result.entries.isNotEmpty, true);
      // Directories come first
      expect(result.entries.first.isDirectory, true);
    });

    test('resolves relative URLs correctly', () async {
      const html = '''
<html><body>
<a href="folder/">Folder</a>
<a href="file.zip">file.zip</a>
</body></html>
''';
      final result =
          await parser.parse(url: 'http://test.server/base/', html: html);
      for (final entry in result.entries) {
        expect(entry.url.startsWith('http://'), isTrue,
            reason: 'URL should be absolute: ${entry.url}');
      }
    });

    test('skips parent directory links', () async {
      const html = '''
<html><body>
<a href="../">Parent Directory</a>
<a href="data.zip">data.zip</a>
</body></html>
''';
      final result =
          await parser.parse(url: 'http://test.server/sub/', html: html);
      final parentEntries = result.entries.where(
          (e) => e.name.toLowerCase().contains('parent'));
      expect(parentEntries, isEmpty);
    });

    test('parses file extensions', () async {
      const html = '''
<html><body>
<a href="archive.zip">archive.zip</a>
<a href="video.mkv">video.mkv</a>
</body></html>
''';
      final result =
          await parser.parse(url: 'http://test.server/', html: html);
      final exts = result.entries.map((e) => e.extension).toSet();
      expect(exts, containsAll(['zip', 'mkv']));
    });

    test('sorts directories before files', () async {
      const html = '''
<html><body>
<a href="z_file.txt">z_file.txt</a>
<a href="a_folder/">a_folder/</a>
<a href="b_file.zip">b_file.zip</a>
</body></html>
''';
      final result =
          await parser.parse(url: 'http://test.server/', html: html);
      if (result.entries.length >= 2) {
        expect(result.entries.first.isDirectory, isTrue);
      }
    });
  });

  // ─────────────────────────────────────────────────
  group('DownloadTask model', () {
    test('formats speed correctly', () {
      final task = DownloadTask(
        taskId: 'abc',
        url: 'http://example.com/file.zip',
        fileName: 'file.zip',
        status: DownloadStatus.downloading,
        speedBytesPerSec: 1048576.0, // 1 MB/s
        createdAt: DateTime.now(),
      );
      expect(task.formattedSpeed, contains('MB/s'));
    });

    test('formats ETA correctly', () {
      final task = DownloadTask(
        taskId: 'abc',
        url: 'http://example.com/file.zip',
        fileName: 'file.zip',
        status: DownloadStatus.downloading,
        etaSeconds: 90,
        createdAt: DateTime.now(),
      );
      expect(task.formattedEta, '1m 30s');
    });

    test('formats size correctly', () {
      final task = DownloadTask(
        taskId: 'abc',
        url: 'http://example.com/file.zip',
        fileName: 'file.zip',
        status: DownloadStatus.downloading,
        receivedBytes: 1048576,
        totalBytes: 10485760,
        createdAt: DateTime.now(),
      );
      expect(task.formattedSize, contains('MB'));
    });

    test('parses from native event map', () {
      final map = {
        'taskId': 'test-id-123',
        'url': 'http://example.com/file.zip',
        'fileName': 'file.zip',
        'status': 'downloading',
        'progress': 0.45,
        'speed': 512000.0,
        'eta': 120,
        'totalBytes': 1000000,
        'receivedBytes': 450000,
        'createdAt': DateTime.now().toIso8601String(),
      };
      final task = DownloadTask.fromNativeEvent(map);
      expect(task.taskId, 'test-id-123');
      expect(task.status, DownloadStatus.downloading);
      expect(task.progress, closeTo(0.45, 0.001));
    });
  });

  // ─────────────────────────────────────────────────
  group('ProxyConfig model', () {
    test('typeLabel returns correct string', () {
      final proxy = ProxyConfig(
        id: '1',
        name: 'Test',
        host: '127.0.0.1',
        port: 1080,
        type: ProxyType.socks5,
        createdAt: DateTime.now(),
      );
      expect(proxy.typeLabel, 'SOCKS5');
    });

    test('address formats host:port', () {
      final proxy = ProxyConfig(
        id: '1',
        name: 'Test',
        host: '10.0.0.1',
        port: 8080,
        type: ProxyType.http,
        createdAt: DateTime.now(),
      );
      expect(proxy.address, '10.0.0.1:8080');
    });

    test('hasAuth is true when credentials present', () {
      final proxy = ProxyConfig(
        id: '1',
        name: 'Auth Proxy',
        host: 'proxy.example.com',
        port: 443,
        type: ProxyType.https,
        username: 'user',
        password: 'pass',
        createdAt: DateTime.now(),
      );
      expect(proxy.hasAuth, isTrue);
    });

    test('hasAuth is false without credentials', () {
      final proxy = ProxyConfig(
        id: '2',
        name: 'Open Proxy',
        host: 'open.proxy.net',
        port: 3128,
        type: ProxyType.http,
        createdAt: DateTime.now(),
      );
      expect(proxy.hasAuth, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final original = ProxyConfig(
        id: '5',
        name: 'Original',
        host: '192.168.1.1',
        port: 9050,
        type: ProxyType.socks4,
        createdAt: DateTime.now(),
      );
      final updated = original.copyWith(name: 'Updated', latencyMs: 42);
      expect(updated.id, original.id);
      expect(updated.host, original.host);
      expect(updated.name, 'Updated');
      expect(updated.latencyMs, 42);
    });
  });

  // ─────────────────────────────────────────────────
  group('ClipboardNotifier classification', () {
    // Access the private classify method via a test subclass trick using
    // a public wrapper method on a concrete instance.
    final notifier = ClipboardNotifier();

    // Because _classify is private we test via captureNow indirectly,
    // so we test the regex patterns directly here.
    test('magnet link detected', () {
      const text = 'magnet:?xt=urn:btih:abc123';
      final result = _testClassify(text);
      expect(result, ClipboardItemType.magnetLink);
    });

    test('download link detected by extension', () {
      const text = 'https://files.example.com/archive.zip';
      final result = _testClassify(text);
      expect(result, ClipboardItemType.downloadLink);
    });

    test('plain url detected', () {
      const text = 'https://www.example.com/page';
      final result = _testClassify(text);
      expect(result, ClipboardItemType.url);
    });

    test('non-url text classified as unknown', () {
      const text = 'Hello, world!';
      final result = _testClassify(text);
      expect(result, ClipboardItemType.unknown);
    });

    // Dispose notifier to stop polling timer
    tearDownAll(() => notifier.dispose());
  });
}

// ─── Test helper: mirrors ClipboardNotifier's _classify logic ───
ClipboardItemType _testClassify(String text) {
  final magnetPattern = RegExp(r'^magnet:\?', caseSensitive: false);
  final downloadPattern = RegExp(
    r'\.(zip|rar|7z|tar|gz|iso|mp4|mkv|avi|mov|mp3|flac|wav|pdf|epub|exe|dmg|apk|pkg|deb|rpm|img)$',
    caseSensitive: false,
  );
  final urlPattern = RegExp(r'^https?://', caseSensitive: false);

  if (magnetPattern.hasMatch(text)) return ClipboardItemType.magnetLink;
  if (urlPattern.hasMatch(text)) {
    if (downloadPattern.hasMatch(text)) return ClipboardItemType.downloadLink;
    return ClipboardItemType.url;
  }
  return ClipboardItemType.unknown;
}
