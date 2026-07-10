import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterswift/models/download_task.dart';
import 'package:flutterswift/services/downloader_bridge.dart';
import 'package:flutterswift/services/live_activity_bridge.dart';

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadTask>>(
  (ref) => DownloadsNotifier(
    ref.read(downloaderBridgeProvider),
    ref.read(liveActivityBridgeProvider),
  ),
);

/// Filter options for the download list.
enum DownloadFilter {
  all, active, completed, failed, video, audio, archive, document, image, app
}

/// Sort options for the download list.
enum DownloadSort {
  newest, oldest, largest, smallest, name, status
}

/// Manages the full download list with filtering, sorting, history, and search.
class DownloadsNotifier extends StateNotifier<List<DownloadTask>> {
  final DownloaderBridge _bridge;
  final LiveActivityBridge _liveActivity;
  StreamSubscription<Map<String, dynamic>>? _progressSub;

  List<DownloadTask> _history = [];
  String _searchQuery = '';
  DownloadFilter _filter = DownloadFilter.all;
  DownloadSort _sort = DownloadSort.newest;
  int _maxConcurrent = 2;

  DownloadsNotifier(this._bridge, this._liveActivity) : super([]) {
    _init();
  }

  // --- Computed views ---

  List<DownloadTask> get activeTasks =>
      state.where((t) => t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.paused ||
          t.status == DownloadStatus.queued ||
          t.status == DownloadStatus.connecting ||
          t.status == DownloadStatus.retrying ||
          t.status == DownloadStatus.waiting ||
          t.status == DownloadStatus.verifying ||
          t.status == DownloadStatus.merging).toList();

  List<DownloadTask> get completedTasks =>
      state.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get failedTasks =>
      state.where((t) => t.status == DownloadStatus.failed ||
          t.status == DownloadStatus.cancelled ||
          t.status == DownloadStatus.expired).toList();

  String get searchQuery => _searchQuery;
  DownloadFilter get filter => _filter;
  DownloadSort get sort => _sort;
  int get maxConcurrent => _maxConcurrent;

  /// Filtered + sorted + searched view of all tasks.
  List<DownloadTask> get filteredTasks {
    var items = [...state, ..._history.where((h) =>
        !state.any((s) => s.taskId == h.taskId))];

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((t) =>
          t.fileName.toLowerCase().contains(q) ||
          t.fileExtension.toLowerCase().contains(q) ||
          t.sourceDomain.toLowerCase().contains(q) ||
          t.url.toLowerCase().contains(q)).toList();
    }

    // Apply filter
    switch (_filter) {
      case DownloadFilter.all: break;
      case DownloadFilter.active:
        items = items.where((t) => t.status != DownloadStatus.completed &&
            t.status != DownloadStatus.failed &&
            t.status != DownloadStatus.cancelled).toList();
      case DownloadFilter.completed:
        items = items.where((t) => t.status == DownloadStatus.completed).toList();
      case DownloadFilter.failed:
        items = items.where((t) => t.status == DownloadStatus.failed ||
            t.status == DownloadStatus.cancelled).toList();
      case DownloadFilter.video:
        items = items.where((t) => t.category == 'video').toList();
      case DownloadFilter.audio:
        items = items.where((t) => t.category == 'audio').toList();
      case DownloadFilter.archive:
        items = items.where((t) => t.category == 'archive').toList();
      case DownloadFilter.document:
        items = items.where((t) => t.category == 'document').toList();
      case DownloadFilter.image:
        items = items.where((t) => t.category == 'image').toList();
      case DownloadFilter.app:
        items = items.where((t) => t.category == 'app').toList();
    }

    // Apply sort
    switch (_sort) {
      case DownloadSort.newest:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case DownloadSort.oldest:
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case DownloadSort.largest:
        items.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
      case DownloadSort.smallest:
        items.sort((a, b) => a.totalBytes.compareTo(b.totalBytes));
      case DownloadSort.name:
        items.sort((a, b) => a.fileName.compareTo(b.fileName));
      case DownloadSort.status:
        items.sort((a, b) => a.status.index.compareTo(b.status.index));
    }

    return items;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    state = [...state];
  }

  void setFilter(DownloadFilter f) {
    _filter = f;
    state = [...state];
  }

  void setSort(DownloadSort s) {
    _sort = s;
    state = [...state];
  }

  // --- Init ---

  Future<void> _init() async {
    final tasks = await _bridge.getActiveTasks();
    state = tasks.map(DownloadTask.fromNativeEvent).toList();
    _progressSub = _bridge.progressStream.listen(_onProgressEvent);
    _maxConcurrent = await _bridge.getMaxConcurrent();
    _history = (await _bridge.getHistory())
        .map(DownloadTask.fromNativeEvent)
        .toList();
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
            speedBytesPerSec: (event['speed'] as num?)?.toDouble() ?? task.speedBytesPerSec,
            etaSeconds: (event['eta'] as num?)?.toInt() ?? task.etaSeconds,
            totalBytes: (event['totalBytes'] as num?)?.toInt() ?? task.totalBytes,
            receivedBytes: (event['receivedBytes'] as num?)?.toInt() ?? task.receivedBytes,
            status: updatedStatus,
            completedAt: updatedStatus == DownloadStatus.completed
                ? DateTime.now()
                : task.completedAt,
            mimeType: event['mimeType'] as String? ?? task.mimeType,
            server: event['server'] as String? ?? task.server,
            supportsResume: event['supportsResume'] as bool? ?? task.supportsResume,
            retryCount: (event['retryCount'] as num?)?.toInt() ?? task.retryCount,
            category: event['category'] as String? ?? task.category,
          )
        else
          task,
    ];

    // If completed, move to history
    if (updatedStatus == DownloadStatus.completed) {
      final completed = state.firstWhere(
        (t) => t.taskId == taskId,
        orElse: () => DownloadTask(
          taskId: taskId, url: '', fileName: '', status: DownloadStatus.completed,
          createdAt: DateTime.now(),
        ),
      );
      _history.removeWhere((h) => h.taskId == taskId);
      _history.insert(0, completed);

      _liveActivity.endActivity(taskId);
    } else {
      final updated = state.firstWhere(
        (t) => t.taskId == taskId,
        orElse: () => DownloadTask(
          taskId: taskId, url: '', fileName: '', status: DownloadStatus.failed,
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
      } else if (updated.status == DownloadStatus.failed ||
          updated.status == DownloadStatus.cancelled) {
        _liveActivity.endActivity(taskId);
      }
    }
  }

  // --- Add / Analyze ---

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
      sourceDomain: Uri.tryParse(url)?.host ?? '',
      fileExtension: fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '',
    );

    state = [...state, task];

    await _liveActivity.startActivity(
      taskId: taskId,
      fileName: fileName,
      progress: 0,
      speedBytesPerSec: 0,
      etaSeconds: 0,
    );
  }

  /// Analyze a URL before downloading (HEAD request).
  Future<Map<String, dynamic>> analyzeURL(String url, {Map<String, String>? headers}) async {
    return await _bridge.analyzeURL(url: url, headers: headers);
  }

  // --- Pause / Resume / Cancel ---

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

  // --- Retry / Refresh ---

  Future<void> retryDownload(String taskId) async {
    await _bridge.retryDownload(taskId);
    _updateStatus(taskId, DownloadStatus.retrying);
  }

  Future<bool> refreshDownload(String taskId, String newURL) async {
    final success = await _bridge.refreshDownload(taskId, newURL);
    if (success) _updateStatus(taskId, DownloadStatus.connecting);
    return success;
  }

  // --- Max concurrent ---

  Future<void> setMaxConcurrent(int count) async {
    _maxConcurrent = count;
    await _bridge.setMaxConcurrent(count);
  }

  // --- History ---

  Future<void> loadHistory() async {
    _history = (await _bridge.getHistory())
        .map(DownloadTask.fromNativeEvent)
        .toList();
    state = [...state];
  }

  Future<void> clearHistory({bool deleteFiles = false}) async {
    await _bridge.clearHistory(deleteFiles: deleteFiles);
    _history = [];
    state = [...state];
  }

  // --- Helpers ---

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
