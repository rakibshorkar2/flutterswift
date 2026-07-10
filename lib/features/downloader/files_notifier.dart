import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/services/file_bridge.dart';

final fileBridgeProvider = Provider<FileBridge>((ref) => FileBridge());

/// Manages the file library — indexed files in the Documents directory.
final fileLibraryProvider =
    StateNotifierProvider<FileLibraryNotifier, AsyncValue<List<FileInfo>>>(
  (ref) => FileLibraryNotifier(ref.read(fileBridgeProvider)),
);

/// Search query for file library.
final fileSearchProvider = StateProvider<String>((ref) => '');

/// Category filter for file library.
final fileCategoryFilterProvider = StateProvider<String>((ref) => 'All');

/// Manages the file library state with search, filtering, and monitoring.
class FileLibraryNotifier extends StateNotifier<AsyncValue<List<FileInfo>>> {
  final FileBridge _bridge;
  StreamSubscription<Map<String, dynamic>>? _eventSub;

  FileLibraryNotifier(this._bridge) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    await refresh();
    // Listen for file system change events
    _eventSub = _bridge.fileEvents.listen((_) => refresh());
  }

  /// Refresh the file list from native storage.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final files = await _bridge.listFiles();
      state = AsyncValue.data(files.map(FileInfo.fromMap).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Get files filtered by category.
  Future<List<FileInfo>> getFilesByCategory(String category) async {
    try {
      if (category == 'All' || category.isEmpty) {
        final files = await _bridge.listFiles();
        return files.map(FileInfo.fromMap).toList();
      }
      final files = await _bridge.listFilesInCategory(category);
      return files.map(FileInfo.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  /// Search files by name.
  Future<List<FileInfo>> search(String query) async {
    if (query.isEmpty) {
      return state.value ?? [];
    }
    try {
      final files = await _bridge.searchFiles(query);
      return files.map(FileInfo.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a file and refresh.
  Future<bool> deleteFile(String path) async {
    final success = await _bridge.deleteFile(path);
    if (success) await refresh();
    return success;
  }

  /// Rename a file and refresh.
  Future<String?> renameFile(String path, String newName) async {
    final newPath = await _bridge.renameFile(path, newName);
    if (newPath != null) await refresh();
    return newPath;
  }

  /// Move file to category and refresh.
  Future<String?> moveFile(String path, String category) async {
    final newPath = await _bridge.moveFile(path, category);
    if (newPath != null) await refresh();
    return newPath;
  }

  /// Open document picker for importing files.
  Future<void> importFile() async {
    await _bridge.openDocumentPicker();
    // Refresh after a short delay to pick up the new file
    await Future.delayed(const Duration(seconds: 1));
    await refresh();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}

/// Storage information provider.
final storageInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final bridge = ref.read(fileBridgeProvider);
  return await bridge.getStorageInfo();
});
