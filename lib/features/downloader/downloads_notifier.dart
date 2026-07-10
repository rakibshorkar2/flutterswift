import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/models/download_task.dart';
import 'package:flutterswift/services/downloader_bridge.dart';
import 'package:flutterswift/services/live_activity_bridge.dart';

/// Provider exposing the download notifier.
final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadTask>>(
  (ref) => DownloadsNotifier(
    ref.read(downloaderBridgeProvider),
    ref.read(liveActivityBridgeProvider),
  ),
);

/// Manages the list of download tasks in-state, subscribing to native progress events.
class DownloadsNotifier extends StateNotifier<List<DownloadTask>> {
  final DownloaderBridge _bridge;
  final LiveActivityBridge _liveActivity;
  StreamSubscription<Map<String, dynamic>>? _progressSub;

  DownloadsNotifier(this._bridge, this._liveActivity) : super([]) {
    _init();
  }

  Future<void> _init() async {
    // Load any persisted tasks from native layer.
    final tasks = await _bridge.getActiveTasks();
    state = tasks.map(DownloadTask.fromNativeEvent).toList();

    // Subscribe to real-time progress events.
    _progressSub = _bridge.progressStream.listen(_onProgressEvent);
  }

  void _onProgressEvent(Map<String, dynamic> event) {
    final taskId = event['taskId'] as String?;
    if (taskId == null) return;

    final updatedStatus = DownloadTask.parseStatus(event['status'] as String?);
    state = [
      for (final task in state)
        if (task.taskId == taskId)
          task.copyWith(
            progress: (event['progress'] as num?)?.toDouble() ?? task.progress,
            speedBytesPerSec:
                (event['speed'] as num?)?.toDouble() ?? task.speedBytesPerSec,
            etaSeconds: (event['eta'] as num?)?.toInt() ?? task.etaSeconds,
            totalBytes:
                (event['totalBytes'] as num?)?.toInt() ?? task.totalBytes,
            receivedBytes:
                (event['receivedBytes'] as num?)?.toInt() ?? task.receivedBytes,
            status: updatedStatus,
            completedAt: updatedStatus == DownloadStatus.completed
                ? DateTime.now()
                : task.completedAt,
          )
        else
          task,
    ];

    // Update Live Activity for active downloads.
    final updated = state.firstWhere(
      (t) => t.taskId == taskId,
      orElse: () => DownloadTask(
        taskId: taskId,
        url: '',
        fileName: '',
        status: DownloadStatus.failed,
        createdAt: DateTime.now(),
      ),
    );

    if (updated.status == DownloadStatus.downloading) {
      _liveActivity.updateActivity(
        taskId: taskId,
        progress: updated.progress,
        speedBytesPerSec: updated.speedBytesPerSec,
        etaSeconds: updated.etaSeconds,
        status: 'downloading',
      );
    } else if (updated.status == DownloadStatus.completed ||
        updated.status == DownloadStatus.failed ||
        updated.status == DownloadStatus.cancelled) {
      _liveActivity.endActivity(taskId);
    }
  }

  /// Enqueue a new download.
  Future<void> addDownload({
    required String url,
    required String fileName,
    String? destinationPath,
    Map<String, String>? headers,
  }) async {
    final taskId = await _bridge.startDownload(
      url: url,
      fileName: fileName,
      destinationPath: destinationPath,
      headers: headers,
    );

    final task = DownloadTask(
      taskId: taskId,
      url: url,
      fileName: fileName,
      destinationPath: destinationPath,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
    );

    state = [...state, task];

    // Start Live Activity.
    await _liveActivity.startActivity(
      taskId: taskId,
      fileName: fileName,
      progress: 0,
      speedBytesPerSec: 0,
      etaSeconds: 0,
    );
  }

  Future<void> pauseDownload(String taskId) async {
    await _bridge.pauseDownload(taskId);
    _updateStatus(taskId, DownloadStatus.paused);
    await _liveActivity.updateActivity(
      taskId: taskId,
      progress: _taskById(taskId)?.progress ?? 0,
      speedBytesPerSec: 0,
      etaSeconds: 0,
      status: 'paused',
    );
  }

  Future<void> resumeDownload(String taskId) async {
    await _bridge.resumeDownload(taskId);
    _updateStatus(taskId, DownloadStatus.downloading);
  }

  Future<void> cancelDownload(String taskId) async {
    await _bridge.cancelDownload(taskId);
    _updateStatus(taskId, DownloadStatus.cancelled);
    await _liveActivity.endActivity(taskId);
    state = state.where((t) => t.taskId != taskId).toList();
  }

  void _updateStatus(String taskId, DownloadStatus status) {
    state = [
      for (final t in state)
        if (t.taskId == taskId) t.copyWith(status: status) else t,
    ];
  }

  DownloadTask? _taskById(String taskId) {
    try {
      return state.firstWhere((t) => t.taskId == taskId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}
