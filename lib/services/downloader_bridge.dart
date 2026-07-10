import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the DownloaderBridge singleton.
final downloaderBridgeProvider = Provider<DownloaderBridge>((ref) => DownloaderBridge());

/// Communicates with the native Swift download engine via MethodChannel and EventChannel.
class DownloaderBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.dirxplorerakib.pro/downloader');
  static const EventChannel _progressChannel =
      EventChannel('com.dirxplorerakib.pro/downloader/progress');

  /// Start downloading a URL to a destination path.
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

  /// Pause a running download by its task ID.
  Future<void> pauseDownload(String taskId) async {
    await _methodChannel.invokeMethod('pauseDownload', {'taskId': taskId});
  }

  /// Resume a paused download by its task ID.
  Future<void> resumeDownload(String taskId) async {
    await _methodChannel.invokeMethod('resumeDownload', {'taskId': taskId});
  }

  /// Cancel a download by its task ID.
  Future<void> cancelDownload(String taskId) async {
    await _methodChannel.invokeMethod('cancelDownload', {'taskId': taskId});
  }

  /// Retrieve all persisted download tasks (survives app relaunch).
  Future<List<Map<String, dynamic>>> getActiveTasks() async {
    final result =
        await _methodChannel.invokeMethod<List<dynamic>>('getActiveTasks');
    return result
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  /// Stream of progress events from native layer.
  /// Each event is a Map with keys: taskId, progress, speed, eta, status.
  Stream<Map<String, dynamic>> get progressStream {
    return _progressChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
  }
}
