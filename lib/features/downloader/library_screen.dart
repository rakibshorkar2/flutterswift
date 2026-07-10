import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/core/theme.dart';
import 'package:flutterswift/features/downloader/files_notifier.dart';
import 'package:flutterswift/services/file_bridge.dart';

/// File library screen — browses the Documents/DirXplore Pro/Downloads folder
/// with categories, search, sort, rename, delete, and import.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  bool _showSearch = false;
  bool _showCategories = false;
  bool _showOptions = false;
  String? _confirmDeletePath;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final library = ref.watch(fileLibraryProvider);
    final bridge = ref.read(fileBridgeProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar.large(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: _showSearch
                ? CupertinoSearchTextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    onClear: () => _onSearch(''),
                    style: AppTypography.body(context,
                        color: isDark ? AppColors.darkLabel : AppColors.lightLabel),
                  )
                : Text('Library',
                    style: AppTypography.title1(context,
                        color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
            actions: [
              CupertinoButton(
                child: Icon(_showSearch ? CupertinoIcons.xmark_circle : CupertinoIcons.search),
                onPressed: () => setState(() => _showSearch = !_showSearch),
              ),
              CupertinoButton(
                child: const Icon(CupertinoIcons.folder),
                onPressed: () => setState(() => _showCategories = !_showCategories),
              ),
              CupertinoButton(
                child: const Icon(CupertinoIcons.plus_square_on_square),
                onPressed: () => bridge.openDocumentPicker(),
              ),
            ],
          ),
          // Category chips
          if (_showCategories)
            SliverToBoxAdapter(child: _CategoryChips(
              selected: _selectedCategory,
              isDark: isDark,
              onSelected: (c) {
                _selectedCategory = c;
                ref.read(fileLibraryProvider.notifier).refresh();
                setState(() {});
              },
            )),
          // Content
          library.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.exclamationmark_triangle, size: 48,
                        color: AppColors.systemRed),
                    const SizedBox(height: 12),
                    Text('Failed to load files',
                        style: AppTypography.body(context,
                            color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
                  ],
                ),
              ),
            ),
            data: (files) {
              final filtered = _applyFilter(files);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.tray_empty, size: 72,
                            color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel),
                        const SizedBox(height: 16),
                        Text('No files found',
                            style: AppTypography.headline(context,
                                color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
                        const SizedBox(height: 8),
                        Text('Download files or tap + to import from Files.',
                            textAlign: TextAlign.center,
                            style: AppTypography.footnote(context,
                                color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _FileRow(
                    file: filtered[i],
                    isDark: isDark,
                    isConfirmDelete: _confirmDeletePath == filtered[i].path,
                    onTap: () => _showFileOptions(context, filtered[i], isDark),
                    onDelete: () => _handleDelete(filtered[i].path, bridge),
                  ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.04, end: 0),
                  childCount: filtered.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  List<FileInfo> _applyFilter(List<FileInfo> files) {
    var result = files;
    if (_selectedCategory != 'All') {
      result = result.where((f) => f.category == _selectedCategory).toList();
    }
    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      result = result.where((f) =>
          f.name.toLowerCase().contains(q) ||
          f.extension.toLowerCase().contains(q)).toList();
    }
    // Sort by date descending
    result.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return result;
  }

  void _onSearch(String query) {
    ref.read(fileLibraryProvider.notifier).refresh();
    setState(() {});
  }

  void _handleDelete(String path, FileBridge bridge) {
    if (_confirmDeletePath == path) {
      ref.read(fileLibraryProvider.notifier).deleteFile(path);
      setState(() => _confirmDeletePath = null);
    } else {
      setState(() => _confirmDeletePath = path);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _confirmDeletePath = null);
      });
    }
  }

  void _showFileOptions(BuildContext context, FileInfo file, bool isDark) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        message: Text('${file.formattedSize}  •  ${file.category}'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Share'),
            onPressed: () {
              Navigator.pop(context);
              _shareFile(file);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Rename'),
            onPressed: () {
              Navigator.pop(context);
              _showRenameDialog(context, file, isDark);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Move to Category'),
            onPressed: () {
              Navigator.pop(context);
              _showMoveCategoryDialog(context, file);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              ref.read(fileLibraryProvider.notifier).deleteFile(file.path);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _shareFile(FileInfo file) {
    // Use QuickLook bridge to present share sheet
    ref.read(fileBridgeProvider).openDocumentPicker();
  }

  void _showRenameDialog(BuildContext context, FileInfo file, bool isDark) {
    final ctrl = TextEditingController(text: file.name);
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Rename File'),
        content: CupertinoTextField(
          controller: ctrl,
          autofocus: true,
        ),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('Rename'),
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                ref.read(fileLibraryProvider.notifier).renameFile(file.path, newName);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showMoveCategoryDialog(BuildContext context, FileInfo file) {
    final categories = ['Movies', 'TV Shows', 'Music', 'Images', 'Documents', 'Archives', 'Applications', 'Other'];
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Move to Category'),
        actions: [
          for (final cat in categories.where((c) => c != file.category))
            CupertinoActionSheetAction(
              child: Text(cat),
              onPressed: () {
                ref.read(fileLibraryProvider.notifier).moveFile(file.path, cat);
                Navigator.pop(context);
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// MARK: - Category Chips

class _CategoryChips extends StatelessWidget {
  final String selected;
  final bool isDark;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.selected, required this.isDark, required this.onSelected,
  });

  static const categories = [
    'All', 'Movies', 'TV Shows', 'Music', 'Images',
    'Documents', 'Archives', 'Applications', 'Other'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: categories.map((cat) {
            final sel = selected == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelected(cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.darkAccentBlue
                        : (isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(cat, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: sel ? Colors.white
                        : (isDark ? AppColors.darkLabel : AppColors.lightLabel),
                  )),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// MARK: - File Row

class _FileRow extends StatelessWidget {
  final FileInfo file;
  final bool isDark;
  final bool isConfirmDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FileRow({
    required this.file, required this.isDark,
    this.isConfirmDelete = false,
    required this.onTap, required this.onDelete,
  });

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Movies': return CupertinoIcons.film_fill;
      case 'TV Shows': return CupertinoIcons.tv_fill;
      case 'Music': return CupertinoIcons.music_note_2;
      case 'Images': return CupertinoIcons.photo_fill;
      case 'Documents': return CupertinoIcons.doc_text_fill;
      case 'Archives': return CupertinoIcons.archivebox_fill;
      case 'Applications': return CupertinoIcons.square_grid_3x3_fill;
      default: return CupertinoIcons.doc_fill;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Movies': case 'TV Shows': return AppColors.darkAccentBlue;
      case 'Music': return AppColors.systemGreen;
      case 'Images': return AppColors.systemOrange;
      case 'Documents': return AppColors.darkAccentBlue;
      case 'Archives': return AppColors.systemOrange;
      case 'Applications': return AppColors.systemGreen;
      default: return AppColors.darkSecondaryLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground;
    final catColor = _categoryColor(file.category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onTap,
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
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_categoryIcon(file.category), color: catColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(context,
                                color: isDark ? AppColors.darkLabel : AppColors.lightLabel)),
                        const SizedBox(height: 2),
                        Text('${file.formattedSize}  •  ${file.category}',
                            style: AppTypography.footnote(context,
                                color: isDark ? AppColors.darkSecondaryLabel : AppColors.lightSecondaryLabel)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isConfirmDelete ? AppColors.systemRed.withAlpha(30) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isConfirmDelete ? CupertinoIcons.trash_fill : CupertinoIcons.trash,
                            size: 18,
                            color: isConfirmDelete ? AppColors.systemRed : AppColors.darkSecondaryLabel,
                          ),
                          if (isConfirmDelete) ...[
                            const SizedBox(width: 4),
                            Text('Confirm', style: AppTypography.footnote(context, color: AppColors.systemRed)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
