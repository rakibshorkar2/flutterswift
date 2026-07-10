import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final downloaderBridgeProvider = Provider<DownloaderBridge>((ref) => DownloaderBridge());

/// Communicates with the native Swift download engine via MethodChannel and EventChannel.
class DownloaderBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.dirxplorerakib.pro/downloader');
  static const EventChannel _progressChannel =
      EventChannel('com.dirxplorerakib.pro/downloader/progress');

  Future<String> startDownload({
    required String url,
    required String fileName,
    String? destinationPath,
    Map<String, String>? headers,
  }) async {
    final args = <String, Object?>{
      'url': url,
      'fileName': fileName,
      'destinationPath': destinationPath,
      'headers': headers,
    };
    final taskId = await _methodChannel.invokeMethod<String>('startDownload', args);
    return taskId ?? '';
  }

  Future<void> pauseDownload(String taskId) async {
    await _methodChannel.invokeMethod('pauseDownload', {'taskId': taskId});
  }

  Future<void> resumeDownload(String taskId) async {
    await _methodChannel.invokeMethod('resumeDownload', {'taskId': taskId});
  }

  Future<void> cancelDownload(String taskId) async {
    await _methodChannel.invokeMethod('cancelDownload', {'taskId': taskId});
  }

  Future<List<Map<String, dynamic>>> getActiveTasks() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>('getActiveTasks');
    return result?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// Perform a HEAD request to analyze a URL before downloading.
  Future<Map<String, dynamic>> analyzeURL({
    required String url,
    Map<String, String>? headers,
  }) async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('analyzeURL', {
      'url': url,
      'headers': headers,
    });
    return result?.cast<String, dynamic>() ?? {};
  }

  /// Retry a failed download.
  Future<void> retryDownload(String taskId) async {
    await _methodChannel.invokeMethod('retryDownload', {'taskId': taskId});
  }

  /// Refresh an expired download with a new URL.
  Future<bool> refreshDownload(String taskId, String newURL) async {
    final result = await _methodChannel.invokeMethod<bool>('refreshDownload', {
      'taskId': taskId,
      'newURL': newURL,
    });
    return result ?? false;
  }

  /// Get download history from persistence.
  Future<List<Map<String, dynamic>>> getHistory() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>('getHistory');
    return result?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// Clear download history.
  Future<void> clearHistory({bool deleteFiles = false}) async {
    await _methodChannel.invokeMethod('clearHistory', {'deleteFiles': deleteFiles});
  }

  /// Get max concurrent downloads setting.
  Future<int> getMaxConcurrent() async {
    final result = await _methodChannel.invokeMethod<int>('getMaxConcurrent');
    return result ?? 2;
  }

  /// Set max concurrent downloads.
  Future<void> setMaxConcurrent(int count) async {
    await _methodChannel.invokeMethod('setMaxConcurrent', {'count': count});
  }

  /// List all task IDs.
  Future<List<String>> allTaskIds() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>('allTaskIds');
    return result?.cast<String>() ?? [];
  }

  Stream<Map<String, dynamic>> get progressStream {
    return _progressChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
  }
}
