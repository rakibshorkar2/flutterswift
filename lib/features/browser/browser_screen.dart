import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutterswift/core/theme.dart';
import 'package:flutterswift/features/browser/browser_notifier.dart';
import 'package:flutterswift/features/downloader/downloads_notifier.dart';
import 'package:flutterswift/models/browser_models.dart';

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final Map<String, WebViewController> _controllers = {};
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  bool _isAddressFocused = false;

  static const _desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

  static const _mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  bool _desktopMode = false;

  @override
  void initState() {
    super.initState();
    _addressFocus.addListener(() {
      setState(() => _isAddressFocused = _addressFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  WebViewController _controllerForTab(BrowserTab tab) {
    if (_controllers.containsKey(tab.id)) return _controllers[tab.id]!;

    final notifier = ref.read(browserProvider.notifier);
    final downloadsNotifier = ref.read(downloadsProvider.notifier);

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopMode ? _desktopUserAgent : _mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            // Intercept downloadable file extensions.
            final downloadExts = [
              '.zip', '.rar', '.7z', '.tar', '.gz', '.iso',
              '.mp4', '.mkv', '.avi', '.mov',
              '.mp3', '.flac', '.wav',
              '.pdf', '.epub',
              '.exe', '.dmg', '.apk',
            ];
            if (downloadExts.any((ext) => url.toLowerCase().endsWith(ext))) {
              final fileName = url.split('/').last;
              downloadsNotifier.addDownload(url: url, fileName: fileName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloading: $fileName'),
                  backgroundColor: AppColors.darkAccentBlue,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            notifier.updateActiveTab(url: url, isLoading: true, loadingProgress: 0.1);
            _addressController.text = url;
          },
          onProgress: (p) {
            notifier.updateActiveTab(loadingProgress: p / 100.0);
          },
          onPageFinished: (url) async {
            final title = await _controllers[tab.id]
                ?.getTitle() ?? url;
            notifier.updateActiveTab(
              url: url,
              title: title,
              isLoading: false,
              loadingProgress: 1.0,
            );
            notifier.addToHistory(url, title);
            _addressController.text = url;
          },
        ),
      )
      ..loadRequest(Uri.parse(tab.url));

    _controllers[tab.id] = controller;
    return controller;
  }

  void _navigate(String input) {
    final url = input.startsWith('http://') || input.startsWith('https://')
        ? input
        : input.contains('.')
            ? 'https://$input'
            : 'https://www.google.com/search?q=${Uri.encodeComponent(input)}';
    _controllers[ref.read(browserProvider).activeTab.id]
        ?.loadRequest(Uri.parse(url));
    _addressFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final browserState = ref.watch(browserProvider);
    final activeTab = browserState.activeTab;
    final controller = _controllerForTab(activeTab);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Column(
        children: [
          // Status bar spacer
          SizedBox(height: MediaQuery.of(context).padding.top),

          // Address / toolbar area
          _AddressBar(
            controller: _addressController,
            focusNode: _addressFocus,
            isFocused: _isAddressFocused,
            isDark: isDark,
            isLoading: activeTab.isLoading,
            loadingProgress: activeTab.loadingProgress,
            isIncognito: activeTab.isIncognito,
            isBookmarked: ref.read(browserProvider.notifier).isBookmarked(activeTab.url),
            tabCount: browserState.tabs.length,
            onNavigate: _navigate,
            onBack: () => _controllers[activeTab.id]?.goBack(),
            onForward: () => _controllers[activeTab.id]?.goForward(),
            onRefresh: () => _controllers[activeTab.id]?.reload(),
            onBookmark: () {
              ref.read(browserProvider.notifier)
                  .addBookmark(activeTab.url, activeTab.title);
            },
            onNewTab: () => ref.read(browserProvider.notifier).openNewTab(),
            onNewIncognitoTab: () =>
                ref.read(browserProvider.notifier).openNewTab(incognito: true),
            onToggleDesktop: () {
              setState(() => _desktopMode = !_desktopMode);
              controller.setUserAgent(
                  _desktopMode ? _desktopUserAgent : _mobileUserAgent);
              controller.reload();
            },
            onShowBookmarks: () =>
                ref.read(browserProvider.notifier).toggleBookmarks(),
            onShowHistory: () =>
                ref.read(browserProvider.notifier).toggleHistory(),
          ),

          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: controller),

                // Bookmarks overlay
                if (browserState.showBookmarks)
                  _PanelOverlay(
                    isDark: isDark,
                    title: 'Bookmarks',
                    onClose: () =>
                        ref.read(browserProvider.notifier).toggleBookmarks(),
                    child: _BookmarksList(
                      bookmarks: browserState.bookmarks,
                      isDark: isDark,
                      onTap: (url) {
                        _navigate(url);
                        ref.read(browserProvider.notifier).toggleBookmarks();
                      },
                      onDelete: (id) =>
                          ref.read(browserProvider.notifier).removeBookmark(id),
                    ),
                  ),

                // History overlay
                if (browserState.showHistory)
                  _PanelOverlay(
                    isDark: isDark,
                    title: 'History',
                    onClose: () =>
                        ref.read(browserProvider.notifier).toggleHistory(),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Clear'),
                      onPressed: () =>
                          ref.read(browserProvider.notifier).clearHistory(),
                    ),
                    child: _HistoryList(
                      history: browserState.history,
                      isDark: isDark,
                      onTap: (url) {
                        _navigate(url);
                        ref.read(browserProvider.notifier).toggleHistory();
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Tab bar strip
          if (browserState.tabs.length > 1)
            _TabStrip(
              tabs: browserState.tabs,
              activeIndex: browserState.activeTabIndex,
              isDark: isDark,
              onSwitch: (i) => ref.read(browserProvider.notifier).switchTab(i),
              onClose: (id) => ref.read(browserProvider.notifier).closeTab(id),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Address Bar
// ─────────────────────────────────────────────────────────

class _AddressBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final bool isDark;
  final bool isLoading;
  final double loadingProgress;
  final bool isIncognito;
  final bool isBookmarked;
  final int tabCount;
  final void Function(String) onNavigate;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onBookmark;
  final VoidCallback onNewTab;
  final VoidCallback onNewIncognitoTab;
  final VoidCallback onToggleDesktop;
  final VoidCallback onShowBookmarks;
  final VoidCallback onShowHistory;

  const _AddressBar({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.isDark,
    required this.isLoading,
    required this.loadingProgress,
    required this.isIncognito,
    required this.isBookmarked,
    required this.tabCount,
    required this.onNavigate,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onBookmark,
    required this.onNewTab,
    required this.onNewIncognitoTab,
    required this.onToggleDesktop,
    required this.onShowBookmarks,
    required this.onShowHistory,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(CupertinoIcons.chevron_left),
                iconSize: 20,
                color: isDark ? AppColors.darkLabel : AppColors.lightLabel,
                onPressed: onBack,
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.chevron_right),
                iconSize: 20,
                color: isDark ? AppColors.darkLabel : AppColors.lightLabel,
                onPressed: onForward,
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground,
                    child: Row(
                      children: [
                        if (isIncognito)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(CupertinoIcons.eye_slash, size: 16, color: AppColors.systemOrange),
                          ),
                        Expanded(
                          child: CupertinoTextField(
                            controller: controller,
                            focusNode: focusNode,
                            placeholder: 'Search or enter URL',
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: const BoxDecoration(),
                            style: AppTypography.footnote(
                              context,
                              color: isDark ? AppColors.darkLabel : AppColors.lightLabel,
                            ),
                            onSubmitted: onNavigate,
                            textInputAction: TextInputAction.go,
                          ),
                        ),
                        if (isLoading)
                          CupertinoButton(
                            padding: const EdgeInsets.only(right: 6),
                            onPressed: null,
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                value: loadingProgress,
                                strokeWidth: 2,
                                color: isDark ? AppColors.darkAccentBlue : AppColors.lightAccentBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(isLoading
                    ? CupertinoIcons.xmark
                    : CupertinoIcons.arrow_counterclockwise),
                iconSize: 20,
                color: isDark ? AppColors.darkLabel : AppColors.lightLabel,
                onPressed: onRefresh,
              ),
              // More menu
              PopupMenuButton<String>(
                icon: Icon(CupertinoIcons.ellipsis_circle,
                    size: 20,
                    color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground,
                onSelected: (val) {
                  switch (val) {
                    case 'bookmark':
                      onBookmark();
                    case 'new_tab':
                      onNewTab();
                    case 'incognito':
                      onNewIncognitoTab();
                    case 'desktop':
                      onToggleDesktop();
                    case 'bookmarks':
                      onShowBookmarks();
                    case 'history':
                      onShowHistory();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'bookmark', child: _MenuRow(icon: isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark, label: isBookmarked ? 'Bookmarked' : 'Bookmark')),
                  PopupMenuItem(value: 'bookmarks', child: _MenuRow(icon: CupertinoIcons.book, label: 'Bookmarks')),
                  PopupMenuItem(value: 'history', child: _MenuRow(icon: CupertinoIcons.clock, label: 'History')),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'new_tab', child: _MenuRow(icon: CupertinoIcons.add, label: 'New Tab')),
                  PopupMenuItem(value: 'incognito', child: _MenuRow(icon: CupertinoIcons.eye_slash, label: 'Incognito Tab')),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'desktop', child: _MenuRow(icon: CupertinoIcons.desktopcomputer, label: 'Desktop Site')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Panel Overlay (Bookmarks / History)
// ─────────────────────────────────────────────────────────

class _PanelOverlay extends StatelessWidget {
  final bool isDark;
  final String title;
  final VoidCallback onClose;
  final Widget? trailing;
  final Widget child;

  const _PanelOverlay({
    required this.isDark,
    required this.title,
    required this.onClose,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark ? const Color(0xE6000000) : const Color(0xE6F2F2F7),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 8, 0),
                  child: Row(
                    children: [
                      Text(title, style: AppTypography.headline(context,
                          color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
                      const Spacer(),
                      ?trailing,
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: onClose,
                        child: const Icon(CupertinoIcons.xmark_circle_fill),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0, duration: 200.ms);
  }
}

// ─────────────────────────────────────────────────────────
// Bookmarks List
// ─────────────────────────────────────────────────────────

class _BookmarksList extends StatelessWidget {
  final List<BrowserBookmark> bookmarks;
  final bool isDark;
  final void Function(String url) onTap;
  final void Function(String id) onDelete;

  const _BookmarksList({
    required this.bookmarks,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return Center(
        child: Text('No bookmarks yet',
            style: AppTypography.body(context,
                color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      separatorBuilder: (context, index) => Divider(
          color: isDark ? AppColors.darkSeparator : AppColors.lightSeparator,
          height: 1),
      itemBuilder: (_, i) {
        final b = bookmarks[i];
        return ListTile(
          leading: const Icon(CupertinoIcons.bookmark_fill, color: AppColors.darkAccentBlue, size: 20),
          title: Text(b.title,
              style: AppTypography.body(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Text(b.url,
              style: AppTypography.footnote(context,
                  color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.trash, size: 18, color: AppColors.systemRed),
            onPressed: () => onDelete(b.id),
          ),
          onTap: () => onTap(b.url),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// History List
// ─────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<HistoryEntry> history;
  final bool isDark;
  final void Function(String url) onTap;

  const _HistoryList({
    required this.history,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Text('No history',
            style: AppTypography.body(context,
                color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (context, index) => Divider(
          color: isDark ? AppColors.darkSeparator : AppColors.lightSeparator,
          height: 1),
      itemBuilder: (_, i) {
        final h = history[i];
        return ListTile(
          leading: const Icon(CupertinoIcons.clock, size: 20),
          title: Text(h.title,
              style: AppTypography.body(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Text(h.url,
              style: AppTypography.footnote(context,
                  color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          onTap: () => onTap(h.url),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Tab Strip
// ─────────────────────────────────────────────────────────

class _TabStrip extends StatelessWidget {
  final List<BrowserTab> tabs;
  final int activeIndex;
  final bool isDark;
  final void Function(int) onSwitch;
  final void Function(String) onClose;

  const _TabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.isDark,
    required this.onSwitch,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final isActive = i == activeIndex;
          return GestureDetector(
            onTap: () => onSwitch(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: AppSprings.interactiveSpring,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tab.isIncognito)
                    const Icon(CupertinoIcons.eye_slash, size: 12, color: AppColors.systemOrange),
                  if (tab.isIncognito) const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(
                      tab.title.isNotEmpty ? tab.title : tab.url,
                      style: AppTypography.footnote(context,
                          color: isActive
                              ? (isDark ? AppColors.darkLabel : AppColors.lightLabel)
                              : (isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => onClose(tab.id),
                    child: Icon(CupertinoIcons.xmark,
                        size: 12,
                        color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
