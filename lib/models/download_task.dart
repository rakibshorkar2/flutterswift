/// Status of a download task.
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Represents a single download task managed by the native Swift engine.
class DownloadTask {
  final String taskId;
  final String url;
  final String fileName;
  final String? destinationPath;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final double speedBytesPerSec;
  final int etaSeconds;
  final int totalBytes;
  final int receivedBytes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;

  const DownloadTask({
    required this.taskId,
    required this.url,
    required this.fileName,
    this.destinationPath,
    required this.status,
    this.progress = 0.0,
    this.speedBytesPerSec = 0.0,
    this.etaSeconds = 0,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    double? speedBytesPerSec,
    int? etaSeconds,
    int? totalBytes,
    int? receivedBytes,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return DownloadTask(
      taskId: taskId,
      url: url,
      fileName: fileName,
      destinationPath: destinationPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Parse from native bridge event map.
  factory DownloadTask.fromNativeEvent(Map<String, dynamic> map) {
    return DownloadTask(
      taskId: map['taskId'] as String,
      url: map['url'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'Unknown',
      destinationPath: map['destinationPath'] as String?,
      status: parseStatus(map['status'] as String?),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      speedBytesPerSec: (map['speed'] as num?)?.toDouble() ?? 0.0,
      etaSeconds: (map['eta'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      receivedBytes: (map['receivedBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  /// Parse status string from native layer. Public for use by notifiers.
  static DownloadStatus parseStatus(String? status) {
    switch (status) {
      case 'queued':
        return DownloadStatus.queued;
      case 'downloading':
        return DownloadStatus.downloading;
      case 'paused':
        return DownloadStatus.paused;
      case 'completed':
        return DownloadStatus.completed;
      case 'failed':
        return DownloadStatus.failed;
      case 'cancelled':
        return DownloadStatus.cancelled;
      default:
        return DownloadStatus.queued;
    }
  }

  /// Human-readable formatted speed string.
  String get formattedSpeed {
    if (speedBytesPerSec < 1024) return '${speedBytesPerSec.toStringAsFixed(0)} B/s';
    if (speedBytesPerSec < 1048576) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBytesPerSec / 1048576).toStringAsFixed(1)} MB/s';
  }

  /// Human-readable ETA string.
  String get formattedEta {
    if (etaSeconds <= 0) return '--';
    if (etaSeconds < 60) return '${etaSeconds}s';
    if (etaSeconds < 3600) return '${etaSeconds ~/ 60}m ${etaSeconds % 60}s';
    return '${etaSeconds ~/ 3600}h ${(etaSeconds % 3600) ~/ 60}m';
  }

  /// Human-readable file size string for received/total.
  String get formattedSize {
    String fmt(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    }

    return '${fmt(receivedBytes)} / ${fmt(totalBytes)}';
  }
}
