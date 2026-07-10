/// Represents an open browser tab.
class BrowserTab {
  final String id;
  final String url;
  final String title;
  final bool isLoading;
  final double loadingProgress;
  final bool isIncognito;

  const BrowserTab({
    required this.id,
    required this.url,
    required this.title,
    this.isLoading = false,
    this.loadingProgress = 0.0,
    this.isIncognito = false,
  });

  BrowserTab copyWith({
    String? url,
    String? title,
    bool? isLoading,
    double? loadingProgress,
    bool? isIncognito,
  }) {
    return BrowserTab(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      isLoading: isLoading ?? this.isLoading,
      loadingProgress: loadingProgress ?? this.loadingProgress,
      isIncognito: isIncognito ?? this.isIncognito,
    );
  }
}

/// Represents a browser bookmark.
class BrowserBookmark {
  final String id;
  final String url;
  final String title;
  final DateTime createdAt;

  const BrowserBookmark({
    required this.id,
    required this.url,
    required this.title,
    required this.createdAt,
  });
}

/// Represents a browser history entry.
class HistoryEntry {
  final String url;
  final String title;
  final DateTime visitedAt;

  const HistoryEntry({
    required this.url,
    required this.title,
    required this.visitedAt,
  });
}
