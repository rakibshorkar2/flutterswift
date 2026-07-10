import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/models/browser_models.dart';

/// State class for the browser feature.
class BrowserState {
  final List<BrowserTab> tabs;
  final int activeTabIndex;
  final List<BrowserBookmark> bookmarks;
  final List<HistoryEntry> history;
  final bool showBookmarks;
  final bool showHistory;

  const BrowserState({
    required this.tabs,
    required this.activeTabIndex,
    required this.bookmarks,
    required this.history,
    this.showBookmarks = false,
    this.showHistory = false,
  });

  BrowserTab get activeTab => tabs[activeTabIndex];

  BrowserState copyWith({
    List<BrowserTab>? tabs,
    int? activeTabIndex,
    List<BrowserBookmark>? bookmarks,
    List<HistoryEntry>? history,
    bool? showBookmarks,
    bool? showHistory,
  }) {
    return BrowserState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      bookmarks: bookmarks ?? this.bookmarks,
      history: history ?? this.history,
      showBookmarks: showBookmarks ?? this.showBookmarks,
      showHistory: showHistory ?? this.showHistory,
    );
  }
}

/// Provider for the BrowserNotifier.
final browserProvider =
    StateNotifierProvider<BrowserNotifier, BrowserState>((ref) {
  return BrowserNotifier();
});

class BrowserNotifier extends StateNotifier<BrowserState> {
  BrowserNotifier()
      : super(BrowserState(
          tabs: [
            BrowserTab(
              id: 'default',
              url: 'https://www.google.com',
              title: 'Google',
            ),
          ],
          activeTabIndex: 0,
          bookmarks: [],
          history: [],
        ));

  void openNewTab({String url = 'https://www.google.com', bool incognito = false}) {
    final newTab = BrowserTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      title: url,
      isIncognito: incognito,
    );
    state = state.copyWith(
      tabs: [...state.tabs, newTab],
      activeTabIndex: state.tabs.length,
    );
  }

  void closeTab(String id) {
    if (state.tabs.length == 1) return; // Keep at least one tab
    final idx = state.tabs.indexWhere((t) => t.id == id);
    final newTabs = state.tabs.where((t) => t.id != id).toList();
    final newActiveIndex = state.activeTabIndex >= newTabs.length
        ? newTabs.length - 1
        : (idx <= state.activeTabIndex && state.activeTabIndex > 0)
            ? state.activeTabIndex - 1
            : state.activeTabIndex;
    state = state.copyWith(tabs: newTabs, activeTabIndex: newActiveIndex);
  }

  void switchTab(int index) {
    state = state.copyWith(activeTabIndex: index);
  }

  void updateActiveTab({
    String? url,
    String? title,
    bool? isLoading,
    double? loadingProgress,
  }) {
    final updated = state.tabs.asMap().entries.map((e) {
      if (e.key == state.activeTabIndex) {
        return e.value.copyWith(
          url: url,
          title: title,
          isLoading: isLoading,
          loadingProgress: loadingProgress,
        );
      }
      return e.value;
    }).toList();
    state = state.copyWith(tabs: updated);
  }

  void addToHistory(String url, String title) {
    if (state.activeTab.isIncognito) return;
    final entry = HistoryEntry(url: url, title: title, visitedAt: DateTime.now());
    state = state.copyWith(history: [entry, ...state.history]);
  }

  void addBookmark(String url, String title) {
    if (state.bookmarks.any((b) => b.url == url)) return;
    final bookmark = BrowserBookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      title: title,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(bookmarks: [...state.bookmarks, bookmark]);
  }

  void removeBookmark(String id) {
    state = state.copyWith(
      bookmarks: state.bookmarks.where((b) => b.id != id).toList(),
    );
  }

  void toggleBookmarks() {
    state = state.copyWith(
      showBookmarks: !state.showBookmarks,
      showHistory: false,
    );
  }

  void toggleHistory() {
    state = state.copyWith(
      showHistory: !state.showHistory,
      showBookmarks: false,
    );
  }

  void clearHistory() {
    state = state.copyWith(history: []);
  }

  bool isBookmarked(String url) => state.bookmarks.any((b) => b.url == url);
}
