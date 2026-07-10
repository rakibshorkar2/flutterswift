/// Extended status for the professional download engine.
enum DownloadStatus {
  idle,
  connecting,
  fetchingHeaders,
  downloading,
  paused,
  queued,
  completed,
  failed,
  retrying,
  expired,
  waiting,
  verifying,
  merging,
  cancelled,
}

/// Represents a single download task managed by the native Swift engine.
class DownloadTask {
  final String taskId;
  final String url;
  final String fileName;
  final String? destinationPath;
  final DownloadStatus status;
  final double progress;
  final double speedBytesPerSec;
  final int etaSeconds;
  final int totalBytes;
  final int receivedBytes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String mimeType;
  final String fileExtension;
  final String server;
  final String etag;
  final bool supportsResume;
  final int retryCount;
  final String category;
  final String sourceDomain;

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
    this.mimeType = '',
    this.fileExtension = '',
    this.server = '',
    this.etag = '',
    this.supportsResume = false,
    this.retryCount = 0,
    this.category = 'other',
    this.sourceDomain = '',
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
    String? fileName,
    String? mimeType,
    String? server,
    String? etag,
    bool? supportsResume,
    int? retryCount,
    String? category,
  }) {
    return DownloadTask(
      taskId: taskId,
      url: url,
      fileName: fileName ?? this.fileName,
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
      mimeType: mimeType ?? this.mimeType,
      fileExtension: fileExtension,
      server: server ?? this.server,
      etag: etag ?? this.etag,
      supportsResume: supportsResume ?? this.supportsResume,
      retryCount: retryCount ?? this.retryCount,
      category: category ?? this.category,
      sourceDomain: sourceDomain,
    );
  }

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
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'] as String) : null,
      errorMessage: map['errorMessage'] as String?,
      mimeType: map['mimeType'] as String? ?? '',
      fileExtension: map['fileExtension'] as String? ?? '',
      server: map['server'] as String? ?? '',
      etag: map['etag'] as String? ?? '',
      supportsResume: map['supportsResume'] as bool? ?? false,
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? 'other',
      sourceDomain: map['sourceDomain'] as String? ?? '',
    );
  }

  static DownloadStatus parseStatus(String? status) {
    switch (status) {
      case 'idle': return DownloadStatus.idle;
      case 'connecting': return DownloadStatus.connecting;
      case 'fetchingHeaders': return DownloadStatus.fetchingHeaders;
      case 'downloading': return DownloadStatus.downloading;
      case 'paused': return DownloadStatus.paused;
      case 'queued': return DownloadStatus.queued;
      case 'completed': return DownloadStatus.completed;
      case 'failed': return DownloadStatus.failed;
      case 'retrying': return DownloadStatus.retrying;
      case 'expired': return DownloadStatus.expired;
      case 'waiting': return DownloadStatus.waiting;
      case 'verifying': return DownloadStatus.verifying;
      case 'merging': return DownloadStatus.merging;
      case 'cancelled': return DownloadStatus.cancelled;
      default: return DownloadStatus.queued;
    }
  }

  String get formattedSpeed {
    if (speedBytesPerSec < 1024) return '${speedBytesPerSec.toStringAsFixed(0)} B/s';
    if (speedBytesPerSec < 1048576) return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(speedBytesPerSec / 1048576).toStringAsFixed(1)} MB/s';
  }

  String get formattedEta {
    if (etaSeconds <= 0) return '--';
    if (etaSeconds < 60) return '${etaSeconds}s';
    if (etaSeconds < 3600) return '${etaSeconds ~/ 60}m ${etaSeconds % 60}s';
    return '${etaSeconds ~/ 3600}h ${(etaSeconds % 3600) ~/ 60}m';
  }

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
