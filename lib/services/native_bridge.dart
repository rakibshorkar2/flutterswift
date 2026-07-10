import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the HapticsBridge singleton.
final hapticsBridgeProvider =
    Provider<HapticsBridge>((ref) => HapticsBridge());

/// Fires native iOS Taptic Engine haptics via MethodChannel.
class HapticsBridge {
  static const MethodChannel _channel =
      MethodChannel('com.dirxplorerakib.pro/haptics');

  /// Fire a light impact.
  Future<void> lightImpact() =>
      _channel.invokeMethod('impact', {'style': 'light'});

  /// Fire a medium impact.
  Future<void> mediumImpact() =>
      _channel.invokeMethod('impact', {'style': 'medium'});

  /// Fire a heavy impact.
  Future<void> heavyImpact() =>
      _channel.invokeMethod('impact', {'style': 'heavy'});

  /// Fire a success notification haptic.
  Future<void> success() =>
      _channel.invokeMethod('notification', {'type': 'success'});

  /// Fire a warning notification haptic.
  Future<void> warning() =>
      _channel.invokeMethod('notification', {'type': 'warning'});

  /// Fire an error notification haptic.
  Future<void> error() =>
      _channel.invokeMethod('notification', {'type': 'error'});

  /// Fire a selection changed haptic.
  Future<void> selectionChanged() =>
      _channel.invokeMethod('selectionChanged');
}

/// Provider for the QuickLookBridge singleton.
final quickLookBridgeProvider =
    Provider<QuickLookBridge>((ref) => QuickLookBridge());

/// Opens local files using native iOS QuickLook via MethodChannel.
class QuickLookBridge {
  static const MethodChannel _channel =
      MethodChannel('com.dirxplorerakib.pro/quicklook');

  /// Present QuickLook for a file at the given local path.
  Future<void> preview(String filePath) async {
    await _channel.invokeMethod('preview', {'filePath': filePath});
  }

  /// Present UIDocumentInteractionController for the given file.
  Future<void> openIn(String filePath) async {
    await _channel.invokeMethod('openIn', {'filePath': filePath});
  }
}
