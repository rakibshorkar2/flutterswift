import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the LiveActivityBridge singleton.
final liveActivityBridgeProvider =
    Provider<LiveActivityBridge>((ref) => LiveActivityBridge());

/// Drives Live Activities and Dynamic Island updates via MethodChannel.
class LiveActivityBridge {
  static const MethodChannel _channel =
      MethodChannel('com.dirxplorerakib.pro/live_activity');

  /// Start a Live Activity for a download task.
  Future<void> startActivity({
    required String taskId,
    required String fileName,
    required double progress,
    required double speedBytesPerSec,
    required int etaSeconds,
  }) async {
    await _channel.invokeMethod('startActivity', {
      'taskId': taskId,
      'fileName': fileName,
      'progress': progress,
      'speed': speedBytesPerSec,
      'eta': etaSeconds,
    });
  }

  /// Update an existing Live Activity with new progress data.
  Future<void> updateActivity({
    required String taskId,
    required double progress,
    required double speedBytesPerSec,
    required int etaSeconds,
    required String status,
  }) async {
    await _channel.invokeMethod('updateActivity', {
      'taskId': taskId,
      'progress': progress,
      'speed': speedBytesPerSec,
      'eta': etaSeconds,
      'status': status,
    });
  }

  /// End a Live Activity when download completes, fails, or is cancelled.
  Future<void> endActivity(String taskId) async {
    await _channel.invokeMethod('endActivity', {'taskId': taskId});
  }
}
