import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/core/theme.dart';
import 'package:flutterswift/features/clipboard/clipboard_notifier.dart';
import 'package:flutterswift/features/downloader/downloads_notifier.dart';
import 'package:flutterswift/models/clipboard_item.dart';

class ClipboardScreen extends ConsumerWidget {
  const ClipboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final items = ref.watch(clipboardProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Clipboard',
              style: AppTypography.title1(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
            ),
            actions: [
              if (items.isNotEmpty)
                CupertinoButton(
                  child: const Text('Clear All',
                      style: TextStyle(color: AppColors.systemRed)),
                  onPressed: () =>
                      ref.read(clipboardProvider.notifier).clearAll(),
                ),
              CupertinoButton(
                child: const Icon(CupertinoIcons.arrow_clockwise),
                onPressed: () =>
                    ref.read(clipboardProvider.notifier).captureNow(),
              ),
            ],
          ),
          if (items.isEmpty)
            SliverFillRemaining(child: _EmptyClipboard(isDark: isDark))
          else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ClipboardItemRow(
                  item: items[i],
                  isDark: isDark,
                  onCopy: () => _copy(context, items[i].content),
                  onDownload: items[i].type == ClipboardItemType.downloadLink ||
                          items[i].type == ClipboardItemType.url
                      ? () => _download(context, ref, items[i])
                      : null,
                  onDelete: () =>
                      ref.read(clipboardProvider.notifier).removeItem(items[i].id),
                ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.04, end: 0),
                childCount: items.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }

  void _copy(BuildContext context, String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        backgroundColor: AppColors.darkAccentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _download(BuildContext context, WidgetRef ref, ClipboardItem item) {
    final fileName = item.content.split('/').last.isNotEmpty
        ? item.content.split('/').last
        : 'download_${DateTime.now().millisecondsSinceEpoch}';
    ref.read(downloadsProvider.notifier).addDownload(
          url: item.content,
          fileName: fileName,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued: $fileName'),
        backgroundColor: AppColors.systemGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _EmptyClipboard extends StatelessWidget {
  final bool isDark;
  const _EmptyClipboard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.doc_on_clipboard,
              size: 72,
              color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)
              .animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
          const SizedBox(height: 16),
          Text('Nothing Copied Yet',
              style: AppTypography.headline(context,
                  color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
          const SizedBox(height: 8),
          Text('Automatically monitors clipboard for\nURLs, downloads, and magnet links.',
              textAlign: TextAlign.center,
              style: AppTypography.footnote(context,
                  color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
        ],
      ),
    );
  }
}

class _ClipboardItemRow extends StatelessWidget {
  final ClipboardItem item;
  final bool isDark;
  final VoidCallback onCopy;
  final VoidCallback? onDownload;
  final VoidCallback onDelete;

  const _ClipboardItemRow({
    required this.item,
    required this.isDark,
    required this.onCopy,
    required this.onDownload,
    required this.onDelete,
  });

  Color _typeColor() {
    switch (item.type) {
      case ClipboardItemType.downloadLink:
        return AppColors.darkAccentBlue;
      case ClipboardItemType.magnetLink:
        return AppColors.systemOrange;
      case ClipboardItemType.directoryLink:
        return AppColors.systemGreen;
      case ClipboardItemType.url:
        return AppColors.darkAccentBlue;
      default:
        return AppColors.darkSecondaryLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground)
                  .withAlpha(200),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _typeColor().withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item.typeLabel,
                          style: AppTypography.footnote(context, color: _typeColor())),
                    ),
                    const Spacer(),
                    Text(
                      _timeAgo(item.capturedAt),
                      style: AppTypography.footnote(context,
                          color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footnote(context,
                      color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ChipButton(label: 'Copy', icon: CupertinoIcons.doc_on_clipboard, onTap: onCopy),
                    if (onDownload != null) ...[
                      const SizedBox(width: 8),
                      _ChipButton(
                          label: 'Download',
                          icon: CupertinoIcons.arrow_down_circle,
                          onTap: onDownload!,
                          accent: true),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(CupertinoIcons.trash, size: 18, color: AppColors.systemRed),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _ChipButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.darkAccentBlue : AppColors.darkSecondaryLabel;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(accent ? 30 : 20),
          border: Border.all(color: color.withAlpha(80), width: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: AppTypography.footnote(context, color: color)),
          ],
        ),
      ),
    );
  }
}
