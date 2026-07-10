import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/core/theme.dart';
import 'package:flutterswift/features/downloader/downloads_notifier.dart';
import 'package:flutterswift/models/download_task.dart';

class DownloaderScreen extends ConsumerStatefulWidget {
  const DownloaderScreen({super.key});

  @override
  ConsumerState<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends ConsumerState<DownloaderScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final notifier = ref.read(downloadsProvider.notifier);
    final tasks = ref.watch(downloadsProvider);
    final filtered = notifier.filteredTasks;

    final active = tasks.where((t) =>
        t.status == DownloadStatus.downloading ||
        t.status == DownloadStatus.paused ||
        t.status == DownloadStatus.queued ||
        t.status == DownloadStatus.connecting ||
        t.status == DownloadStatus.retrying ||
        t.status == DownloadStatus.merging ||
        t.status == DownloadStatus.verifying).toList();
    final completed = tasks.where((t) =>
        t.status == DownloadStatus.completed).toList();
    final failed = tasks.where((t) =>
        t.status == DownloadStatus.failed ||
        t.status == DownloadStatus.cancelled ||
        t.status == DownloadStatus.expired).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          // --- App Bar ---
          SliverAppBar.large(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: _showSearch
                ? CupertinoSearchTextField(
                    controller: _searchController,
                    onChanged: (v) => notifier.setSearchQuery(v),
                    onClear: () => notifier.setSearchQuery(''),
                    style: AppTypography.body(context,
                        color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
                  )
                : Text('Downloads',
                    style: AppTypography.title1(context,
                        color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
            actions: [
              CupertinoButton(
                child: Icon(_showSearch ? CupertinoIcons.xmark_circle : CupertinoIcons.search),
                onPressed: () => setState(() => _showSearch = !_showSearch),
              ),
              CupertinoButton(
                child: const Icon(CupertinoIcons.slider_horizontal_3),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              CupertinoButton(
                child: const Icon(CupertinoIcons.plus_circle),
                onPressed: () => _showAddDownloadSheet(context, ref),
              ),
            ],
          ),
          // --- Filter Chips ---
          if (_showFilters)
            SliverToBoxAdapter(
              child: _FilterBar(
                filter: notifier.filter,
                sort: notifier.sort,
                onFilterChanged: (f) => notifier.setFilter(f),
                onSortChanged: (s) => notifier.setSort(s),
              ),
            ),
          // --- Empty State ---
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(isDark: isDark),
            )
          else ...[
            if (active.isNotEmpty) ...[
              _SectionHeader(
                title: 'Active (${active.length})',
                count: active.length,
                isDark: isDark,
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DownloadRow(
                    task: active[i],
                    isDark: isDark,
                    onRetry: () => notifier.retryDownload(active[i].taskId),
                    onRefresh: (newUrl) => notifier.refreshDownload(active[i].taskId, newUrl),
                  ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0, duration: 300.ms),
                  childCount: active.length,
                ),
              ),
            ],
            if (completed.isNotEmpty) ...[
              _SectionHeader(title: 'Completed (${completed.length})', count: completed.length, isDark: isDark),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DownloadRow(task: completed[i], isDark: isDark),
                  childCount: completed.length,
                ),
              ),
            ],
            if (failed.isNotEmpty) ...[
              _SectionHeader(title: 'Failed / Cancelled', count: failed.length, isDark: isDark),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DownloadRow(
                    task: failed[i],
                    isDark: isDark,
                    onRetry: () => notifier.retryDownload(failed[i].taskId),
                    onRefresh: (newUrl) => notifier.refreshDownload(failed[i].taskId, newUrl),
                  ),
                  childCount: failed.length,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }

  // MARK: - Add Download Sheet (Batch Support)

  void _showAddDownloadSheet(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _AddDownloadSheet(
          urlController: urlController,
          scrollController: scrollController,
          onAdd: (urls) {
            for (final url in urls) {
              if (url.trim().isEmpty) continue;
              final fileName = _extractFileName(url);
              ref.read(downloadsProvider.notifier).addDownload(
                    url: url.trim(),
                    fileName: fileName,
                  );
            }
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  static String _extractFileName(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'download_${DateTime.now().millisecondsSinceEpoch}';

    final filenameParam = uri.queryParameters['filename'];
    if (filenameParam != null && filenameParam.isNotEmpty) return filenameParam;

    final disposition = uri.queryParameters['response-content-disposition'];
    if (disposition != null) {
      final match = RegExp(r'''filename\*?=(?:UTF-8'')?["']?([^"';]+)["']?''')
          .firstMatch(disposition);
      if (match != null) return match.group(1)!;
    }

    final path = uri.path;
    if (path.isNotEmpty) {
      final segments = path.split('/');
      final last = segments.where((s) => s.isNotEmpty).lastOrNull;
      if (last != null && last.contains('.')) {
        return Uri.decodeComponent(last);
      }
    }

    return 'download_${DateTime.now().millisecondsSinceEpoch}';
  }
}

// MARK: - Link Inspector Sheet

void _showLinkInspector(BuildContext context, Map<String, dynamic> meta) {
  showCupertinoModalPopup(
    context: context,
    builder: (_) => CupertinoActionSheet(
      title: Text('Link Info'),
      message: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _infoRow('Filename', meta['fileName'] ?? '--'),
          _infoRow('Size', _formatBytes(meta['fileSize'] as int? ?? 0)),
          _infoRow('Type', meta['mimeType'] ?? '--'),
          _infoRow('Server', meta['server'] ?? '--'),
          _infoRow('Resume', (meta['supportsResume'] == true) ? 'Yes' : 'No'),
          _infoRow('Accept-Ranges', meta['acceptRanges'] ?? '--'),
          _infoRow('ETag', meta['etag'] ?? '--'),
          _infoRow('Status', '${meta['statusCode'] ?? '--'}'),
        ].map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: w)).toList(),
      ),
      actions: [
        CupertinoActionSheetAction(child: const Text('Close'), onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}

// MARK: - Filter Bar

class _FilterBar extends StatelessWidget {
  final DownloadFilter filter;
  final DownloadSort sort;
  final ValueChanged<DownloadFilter> onFilterChanged;
  final ValueChanged<DownloadSort> onSortChanged;

  const _FilterBar({
    required this.filter, required this.sort,
    required this.onFilterChanged, required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All', DownloadFilter.all, isDark),
                _filterChip('Active', DownloadFilter.active, isDark),
                _filterChip('Completed', DownloadFilter.completed, isDark),
                _filterChip('Video', DownloadFilter.video, isDark),
                _filterChip('Audio', DownloadFilter.audio, isDark),
                _filterChip('Archive', DownloadFilter.archive, isDark),
                _filterChip('Doc', DownloadFilter.document, isDark),
                _filterChip('Image', DownloadFilter.image, isDark),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _sortChip('Newest', DownloadSort.newest, isDark),
                _sortChip('Oldest', DownloadSort.oldest, isDark),
                _sortChip('Largest', DownloadSort.largest, isDark),
                _sortChip('Name', DownloadSort.name, isDark),
                _sortChip('Status', DownloadSort.status, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, DownloadFilter value, bool isDark) {
    final selected = filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onFilterChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.darkAccentBlue
                : (isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : (isDark ? AppColors.darkLabel : AppColors.lightLabel),
          )),
        ),
      ),
    );
  }

  Widget _sortChip(String label, DownloadSort value, bool isDark) {
    final selected = sort == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSortChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.systemOrange
                : (isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : (isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
          )),
        ),
      ),
    );
  }
}

// MARK: - Section Header

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isDark;
  const _SectionHeader({required this.title, this.count = 0, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          title.toUpperCase(),
          style: AppTypography.footnote(context,
              color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
        ),
      ),
    );
  }
}

// MARK: - Empty State

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.arrow_down_circle, size: 72,
              color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)
              .animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
          const SizedBox(height: 16),
          Text('No Downloads',
            style: AppTypography.headline(context,
                color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
          const SizedBox(height: 8),
          Text('Tap + to add a download or intercept\nlinks from the browser.',
            textAlign: TextAlign.center,
            style: AppTypography.footnote(context,
                color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
        ],
      ),
    );
  }
}

// MARK: - Download Row

class _DownloadRow extends ConsumerWidget {
  final DownloadTask task;
  final bool isDark;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onRefresh;

  const _DownloadRow({
    required this.task,
    required this.isDark,
    this.onRetry,
    this.onRefresh,
  });

  Color _statusColor() {
    switch (task.status) {
      case DownloadStatus.downloading: return AppColors.darkAccentBlue;
      case DownloadStatus.completed: return AppColors.systemGreen;
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
      case DownloadStatus.expired: return AppColors.systemRed;
      case DownloadStatus.paused: return AppColors.systemOrange;
      case DownloadStatus.queued:
      case DownloadStatus.waiting: return AppColors.darkSecondaryLabel;
      case DownloadStatus.connecting:
      case DownloadStatus.fetchingHeaders: return AppColors.darkAccentBlue;
      case DownloadStatus.retrying: return AppColors.systemOrange;
      case DownloadStatus.verifying: return AppColors.darkAccentBlue;
      case DownloadStatus.merging: return AppColors.systemOrange;
      case DownloadStatus.idle: return AppColors.darkSecondaryLabel;
    }
  }

  IconData _statusIcon() {
    switch (task.status) {
      case DownloadStatus.downloading: return CupertinoIcons.arrow_down_circle_fill;
      case DownloadStatus.completed: return CupertinoIcons.checkmark_circle_fill;
      case DownloadStatus.failed:
      case DownloadStatus.expired: return CupertinoIcons.xmark_circle_fill;
      case DownloadStatus.cancelled: return CupertinoIcons.minus_circle_fill;
      case DownloadStatus.paused: return CupertinoIcons.pause_circle_fill;
      case DownloadStatus.queued:
      case DownloadStatus.waiting: return CupertinoIcons.clock_fill;
      case DownloadStatus.connecting:
      case DownloadStatus.fetchingHeaders: return CupertinoIcons.arrow_down_circle;
      case DownloadStatus.retrying: return CupertinoIcons.arrow_clockwise_circle_fill;
      case DownloadStatus.verifying: return CupertinoIcons.checkmark_seal_fill;
      case DownloadStatus.merging: return CupertinoIcons.doc_on_doc_fill;
      case DownloadStatus.idle: return CupertinoIcons.circle;
    }
  }

  String _statusLabel() {
    switch (task.status) {
      case DownloadStatus.downloading: return 'Downloading';
      case DownloadStatus.completed: return 'Completed';
      case DownloadStatus.failed: return task.errorMessage ?? 'Failed';
      case DownloadStatus.cancelled: return 'Cancelled';
      case DownloadStatus.paused: return 'Paused';
      case DownloadStatus.queued: return 'Queued';
      case DownloadStatus.connecting: return 'Connecting...';
      case DownloadStatus.fetchingHeaders: return 'Fetching headers...';
      case DownloadStatus.retrying: return 'Retrying (${task.retryCount})...';
      case DownloadStatus.expired: return 'Link expired';
      case DownloadStatus.waiting: return 'Waiting...';
      case DownloadStatus.verifying: return 'Verifying...';
      case DownloadStatus.merging: return 'Merging chunks...';
      case DownloadStatus.idle: return 'Idle';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground;
    final notifier = ref.read(downloadsProvider.notifier);
    final categoryIcon = _categoryIcon();
    final isActive = task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.connecting ||
        task.status == DownloadStatus.retrying ||
        task.status == DownloadStatus.verifying ||
        task.status == DownloadStatus.merging;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor.withAlpha(200),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Top row: icon + filename + actions ---
                Row(
                  children: [
                    Icon(categoryIcon, color: _statusColor(), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(context,
                                color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
                          ),
                          Text(
                            '${task.sourceDomain.isNotEmpty ? '${task.sourceDomain}  •  ' : ''}$_statusLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (task.status == DownloadStatus.failed ||
                        task.status == DownloadStatus.expired) ...[
                      if (onRetry != null)
                        _ActionButton(icon: CupertinoIcons.arrow_clockwise, color: AppColors.systemOrange, onTap: onRetry!),
                      if (onRefresh != null)
                        _ActionButton(icon: CupertinoIcons.refresh, color: AppColors.darkAccentBlue, onTap: () => _showRefreshSheet(context, notifier, task)),
                    ],
                    if (task.status == DownloadStatus.downloading)
                      _ActionButton(icon: CupertinoIcons.pause_fill, color: AppColors.systemOrange, onTap: () => notifier.pauseDownload(task.taskId)),
                    if (task.status == DownloadStatus.paused ||
                        task.status == DownloadStatus.queued)
                      _ActionButton(icon: CupertinoIcons.play_fill, color: AppColors.darkAccentBlue, onTap: () => notifier.resumeDownload(task.taskId)),
                    if (task.status == DownloadStatus.retrying)
                      _ActionButton(icon: CupertinoIcons.xmark, color: AppColors.systemRed, onTap: () => notifier.cancelDownload(task.taskId)),
                    if (task.status != DownloadStatus.completed &&
                        task.status != DownloadStatus.downloading &&
                        task.status != DownloadStatus.connecting &&
                        task.status != DownloadStatus.verifying &&
                        task.status != DownloadStatus.merging)
                      _ActionButton(icon: CupertinoIcons.xmark, color: AppColors.systemRed, onTap: () => notifier.cancelDownload(task.taskId)),
                  ],
                ),
                // --- Progress bar ---
                if (isActive) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(_statusColor()),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 5,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(task.formattedSize,
                            style: AppTypography.footnote(context,
                                color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
                          if (task.supportsResume)
                            const SizedBox(width: 6),
                          if (task.supportsResume)
                            Icon(CupertinoIcons.arrow_up_arrow_down_circle, size: 12,
                                color: AppColors.systemGreen),
                        ],
                      ),
                      Text(
                        '${task.formattedSpeed}  •  ETA ${task.formattedEta}',
                        style: AppTypography.footnote(context,
                            color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon() {
    switch (task.category) {
      case 'video': return CupertinoIcons.film_fill;
      case 'audio': return CupertinoIcons.music_note_2;
      case 'archive': return CupertinoIcons.archivebox_fill;
      case 'document': return CupertinoIcons.doc_text_fill;
      case 'image': return CupertinoIcons.photo_fill;
      case 'app': return CupertinoIcons.square_grid_3x3_fill;
      default: return CupertinoIcons.doc_fill;
    }
  }

  void _showRefreshSheet(BuildContext context, DownloadsNotifier notifier, DownloadTask task) {
    final controller = TextEditingController(text: task.url);
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Refresh Link'),
        message: Column(
          children: [
            const Text('Paste a new URL for this download:'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoTextField(
                controller: controller,
                placeholder: 'New URL...',
              ),
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Apply'),
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                notifier.refreshDownload(task.taskId, url);
              }
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// MARK: - Action Button

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// MARK: - Add Download Sheet (Batch)

class _AddDownloadSheet extends StatelessWidget {
  final TextEditingController urlController;
  final ScrollController? scrollController;
  final void Function(List<String> urls) onAdd;

  const _AddDownloadSheet({
    required this.urlController,
    this.scrollController,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.glassBgDark : AppColors.glassBgLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                width: 1.0,
              ),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Add Download',
                  style: AppTypography.headline(context,
                      color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
                const SizedBox(height: 4),
                Text('Paste one or more URLs (one per line)',
                  style: AppTypography.footnote(context,
                      color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: urlController,
                  placeholder: 'Paste URL...\nSupports multiple URLs (one per line)',
                  maxLines: 5,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  style: AppTypography.body(context,
                      color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: () {
                      final text = urlController.text.trim();
                      if (text.isEmpty) return;
                      final urls = text
                          .split(RegExp(r'[\n,]'))
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty && Uri.tryParse(s)?.hasScheme == true)
                          .toList();
                      if (urls.isNotEmpty) onAdd(urls);
                    },
                    child: const Text('Download'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
