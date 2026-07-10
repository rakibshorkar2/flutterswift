import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/models/clipboard_item.dart';

/// Provider exposing the clipboard notifier.
final clipboardProvider =
    StateNotifierProvider<ClipboardNotifier, List<ClipboardItem>>(
  (ref) => ClipboardNotifier(),
);

/// Polls the system clipboard every 2 seconds and classifies detected content.
class ClipboardNotifier extends StateNotifier<List<ClipboardItem>> {
  Timer? _timer;
  String _lastSeen = '';

  // File extension patterns for download detection.
  static final _downloadPattern = RegExp(
    r'\.(zip|rar|7z|tar|gz|iso|mp4|mkv|avi|mov|mp3|flac|wav|pdf|epub|exe|dmg|apk|pkg|deb|rpm|img)$',
    caseSensitive: false,
  );

  // Apache/Nginx directory index patterns.
  static final _directoryPattern = RegExp(
    r'(index of|parent directory|directory listing)',
    caseSensitive: false,
  );

  static final _magnetPattern = RegExp(r'^magnet:\?', caseSensitive: false);

  static final _urlPattern = RegExp(
    r'^https?://',
    caseSensitive: false,
  );

  ClipboardNotifier() : super([]) {
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkClipboard());
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || text == _lastSeen) return;
    _lastSeen = text;

    final type = _classify(text);
    final item = ClipboardItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      type: type,
      capturedAt: DateTime.now(),
    );

    // Deduplicate by content.
    if (!state.any((i) => i.content == text)) {
      state = [item, ...state];
    }
  }

  ClipboardItemType _classify(String text) {
    if (_magnetPattern.hasMatch(text)) return ClipboardItemType.magnetLink;
    if (_urlPattern.hasMatch(text)) {
      if (_downloadPattern.hasMatch(text)) return ClipboardItemType.downloadLink;
      if (_directoryPattern.hasMatch(text)) return ClipboardItemType.directoryLink;
      return ClipboardItemType.url;
    }
    return ClipboardItemType.unknown;
  }

  /// Manually capture the current clipboard.
  Future<void> captureNow() => _checkClipboard();

  void removeItem(String id) {
    state = state.where((i) => i.id != id).toList();
  }

  void clearAll() {
    state = [];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
