import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fileBridgeProvider = Provider<FileBridge>((ref) => FileBridge());

/// Communicates with the native StorageManager and file operations via MethodChannel.
class FileBridge {
  static const MethodChannel _fileChannel =
      MethodChannel('com.dirxplorerakib.pro/files');
  static const MethodChannel _storageChannel =
      MethodChannel('com.dirxplorerakib.pro/storage');
  static const EventChannel _fileEventChannel =
      EventChannel('com.dirxplorerakib.pro/files/events');

  // MARK: - File Listing

  Future<List<Map<String, dynamic>>> listFiles() async {
    final result = await _fileChannel.invokeMethod<List<dynamic>>('listFiles');
    return _decodeList(result);
  }

  Future<List<Map<String, dynamic>>> listFilesInCategory(String category) async {
    final result = await _fileChannel.invokeMethod<List<dynamic>>(
        'listFilesInCategory', {'category': category});
    return _decodeList(result);
  }

  Future<Map<String, List<Map<String, dynamic>>>> filesByCategory() async {
    final result = await _fileChannel.invokeMethod<Map<dynamic, dynamic>>('filesByCategory');
    if (result == null) return {};
    return result.map((k, v) => MapEntry(k as String, _decodeList(v as List<dynamic>?)));
  }

  Future<List<Map<String, dynamic>>> searchFiles(String query) async {
    final result = await _fileChannel.invokeMethod<List<dynamic>>('searchFiles', {'query': query});
    return _decodeList(result);
  }

  // MARK: - File Operations

  Future<bool> deleteFile(String path) async {
    final result = await _fileChannel.invokeMethod<bool>('deleteFile', {'path': path});
    return result ?? false;
  }

  Future<String?> renameFile(String path, String newName) async {
    return await _fileChannel.invokeMethod<String>('renameFile', {
      'path': path,
      'newName': newName,
    });
  }

  Future<String?> moveFile(String path, String category) async {
    return await _fileChannel.invokeMethod<String>('moveFile', {
      'path': path,
      'category': category,
    });
  }

  Future<String?> importFile(String sourcePath) async {
    return await _fileChannel.invokeMethod<String>('importFile', {
      'sourcePath': sourcePath,
    });
  }

  Future<void> openDocumentPicker() async {
    await _fileChannel.invokeMethod('openDocumentPicker');
  }

  // MARK: - Storage Info

  Future<Map<String, dynamic>> getStorageInfo() async {
    final result = await _storageChannel.invokeMethod<Map<dynamic, dynamic>>('getStorageInfo');
    return result?.cast<String, dynamic>() ?? {};
  }

  Future<String> getDownloadsDirectory() async {
    final result = await _storageChannel.invokeMethod<String>('getDownloadsDirectory');
    return result ?? '';
  }

  Future<String> getRootDirectory() async {
    final result = await _storageChannel.invokeMethod<String>('getRootDirectory');
    return result ?? '';
  }

  // MARK: - Migration

  Future<bool> needsMigration() async {
    final result = await _fileChannel.invokeMethod<bool>('needsMigration');
    return result ?? false;
  }

  Future<int> runMigration() async {
    final result = await _fileChannel.invokeMethod<int>('runMigration');
    return result ?? 0;
  }

  // MARK: - Events

  Stream<Map<String, dynamic>> get fileEvents {
    return _fileEventChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
  }

  // MARK: - Helpers

  List<Map<String, dynamic>> _decodeList(List<dynamic>? list) {
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }
}

// MARK: - FileInfo Model (mirrors Swift struct)

class FileInfo {
  final String name;
  final String path;
  final String relativePath;
  final String extension;
  final int size;
  final String formattedSize;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String category;
  final bool isDirectory;

  FileInfo({
    required this.name,
    required this.path,
    required this.relativePath,
    required this.extension,
    required this.size,
    required this.formattedSize,
    required this.createdAt,
    required this.modifiedAt,
    required this.category,
    this.isDirectory = false,
  });

  factory FileInfo.fromMap(Map<String, dynamic> map) {
    return FileInfo(
      name: map['name'] as String? ?? '',
      path: map['path'] as String? ?? '',
      relativePath: map['relativePath'] as String? ?? '',
      extension: map['extension'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      formattedSize: map['formattedSize'] as String? ?? '0 B',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      modifiedAt: DateTime.tryParse(map['modifiedAt'] as String? ?? '') ?? DateTime.now(),
      category: map['category'] as String? ?? 'Other',
      isDirectory: map['isDirectory'] as bool? ?? false,
    );
  }

  /// Category icon name (maps to CupertinoIcons)
  String get categoryIcon {
    switch (category) {
      case 'Movies': return 'film_fill';
      case 'TV Shows': return 'tv_fill';
      case 'Music': return 'music_note_2';
      case 'Images': return 'photo_fill';
      case 'Documents': return 'doc_text_fill';
      case 'Archives': return 'archivebox_fill';
      case 'Applications': return 'square_grid_3x3_fill';
      default: return 'doc_fill';
    }
  }
}
