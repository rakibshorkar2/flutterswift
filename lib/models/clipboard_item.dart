/// Represents a clipboard history item with detected type.
enum ClipboardItemType { url, downloadLink, magnetLink, directoryLink, unknown }

class ClipboardItem {
  final String id;
  final String content;
  final ClipboardItemType type;
  final DateTime capturedAt;

  const ClipboardItem({
    required this.id,
    required this.content,
    required this.type,
    required this.capturedAt,
  });

  String get typeLabel {
    switch (type) {
      case ClipboardItemType.url:
        return 'URL';
      case ClipboardItemType.downloadLink:
        return 'Download';
      case ClipboardItemType.magnetLink:
        return 'Magnet';
      case ClipboardItemType.directoryLink:
        return 'Directory';
      case ClipboardItemType.unknown:
        return 'Text';
    }
  }
}
