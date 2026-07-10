import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/core/theme.dart';
import 'package:flutterswift/features/downloader/downloads_notifier.dart';
import 'package:flutterswift/models/download_task.dart';

class DownloaderScreen extends ConsumerWidget {
  const DownloaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final tasks = ref.watch(downloadsProvider);

    final active = tasks.where((t) =>
        t.status == DownloadStatus.downloading ||
        t.status == DownloadStatus.paused ||
        t.status == DownloadStatus.queued).toList();
    final completed = tasks.where((t) =>
        t.status == DownloadStatus.completed).toList();
    final failed = tasks.where((t) =>
        t.status == DownloadStatus.failed ||
        t.status == DownloadStatus.cancelled).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Downloads',
              style: AppTypography.title1(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
            ),
            actions: [
              CupertinoButton(
                child: const Icon(CupertinoIcons.plus_circle),
                onPressed: () => _showAddDownloadSheet(context, ref),
              ),
            ],
          ),
          if (active.isEmpty && completed.isEmpty && failed.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(isDark: isDark),
            )
          else ...[
            if (active.isNotEmpty) ...[
              _SectionHeader(title: 'Active (${active.length})', isDark: isDark),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DownloadRow(task: active[i], isDark: isDark)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: 0.05, end: 0, duration: 300.ms),
                  childCount: active.length,
                ),
              ),
            ],
            if (completed.isNotEmpty) ...[
              _SectionHeader(title: 'Completed (${completed.length})', isDark: isDark),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DownloadRow(task: completed[i], isDark: isDark),
                  childCount: completed.length,
                ),
              ),
            ],
            if (failed.isNotEmpty) ...[
              _SectionHeader(title: 'Failed / Cancelled', isDark: isDark),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DownloadRow(task: failed[i], isDark: isDark),
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

  void _showAddDownloadSheet(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDownloadSheet(
        urlController: urlController,
        onAdd: (url) {
          final fileName = url.split('/').last.isNotEmpty
              ? url.split('/').last
              : 'download_${DateTime.now().millisecondsSinceEpoch}';
          ref.read(downloadsProvider.notifier).addDownload(
                url: url,
                fileName: fileName,
              );
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          title.toUpperCase(),
          style: AppTypography.footnote(
            context,
            color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.arrow_down_circle,
            size: 72,
            color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
          const SizedBox(height: 16),
          Text(
            'No Downloads',
            style: AppTypography.headline(
              context,
              color: isDark ? AppColors.darkLabel : AppColors.lightLabel,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a download or intercept\nlinks from the browser.',
            textAlign: TextAlign.center,
            style: AppTypography.footnote(
              context,
              color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadRow extends ConsumerWidget {
  final DownloadTask task;
  final bool isDark;

  const _DownloadRow({required this.task, required this.isDark});

  Color _statusColor() {
    switch (task.status) {
      case DownloadStatus.downloading:
        return AppColors.darkAccentBlue;
      case DownloadStatus.completed:
        return AppColors.systemGreen;
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return AppColors.systemRed;
      case DownloadStatus.paused:
        return AppColors.systemOrange;
      default:
        return AppColors.darkSecondaryLabel;
    }
  }

  IconData _statusIcon() {
    switch (task.status) {
      case DownloadStatus.downloading:
        return CupertinoIcons.arrow_down_circle_fill;
      case DownloadStatus.completed:
        return CupertinoIcons.checkmark_circle_fill;
      case DownloadStatus.failed:
        return CupertinoIcons.xmark_circle_fill;
      case DownloadStatus.cancelled:
        return CupertinoIcons.minus_circle_fill;
      case DownloadStatus.paused:
        return CupertinoIcons.pause_circle_fill;
      case DownloadStatus.queued:
        return CupertinoIcons.clock_fill;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground;
    final notifier = ref.read(downloadsProvider.notifier);

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
                Row(
                  children: [
                    Icon(_statusIcon(), color: _statusColor(), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          color: isDark ? AppColors.darkLabel : AppColors.lightLabel,
                        ),
                      ),
                    ),
                    if (task.status == DownloadStatus.downloading)
                      _ActionButton(
                        icon: CupertinoIcons.pause_fill,
                        color: AppColors.systemOrange,
                        onTap: () => notifier.pauseDownload(task.taskId),
                      ),
                    if (task.status == DownloadStatus.paused)
                      _ActionButton(
                        icon: CupertinoIcons.play_fill,
                        color: AppColors.darkAccentBlue,
                        onTap: () => notifier.resumeDownload(task.taskId),
                      ),
                    if (task.status != DownloadStatus.completed)
                      _ActionButton(
                        icon: CupertinoIcons.xmark,
                        color: AppColors.systemRed,
                        onTap: () => notifier.cancelDownload(task.taskId),
                      ),
                  ],
                ),
                if (task.status == DownloadStatus.downloading ||
                    task.status == DownloadStatus.paused) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor:
                        isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(_statusColor()),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 5,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        task.formattedSize,
                        style: AppTypography.footnote(
                          context,
                          color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
                        ),
                      ),
                      Text(
                        '${task.formattedSpeed}  •  ETA ${task.formattedEta}',
                        style: AppTypography.footnote(
                          context,
                          color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel,
                        ),
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

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

class _AddDownloadSheet extends StatelessWidget {
  final TextEditingController urlController;
  final void Function(String url) onAdd;

  const _AddDownloadSheet({required this.urlController, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Download',
                  style: AppTypography.headline(
                    context,
                    color: isDark ? AppColors.darkLabel : AppColors.lightLabel,
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: urlController,
                  placeholder: 'Paste URL...',
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkTertiaryBackground : AppColors.lightTertiaryBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  style: AppTypography.body(
                    context,
                    color: isDark ? AppColors.darkLabel : AppColors.lightLabel,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: () {
                      final url = urlController.text.trim();
                      if (url.isNotEmpty) onAdd(url);
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
