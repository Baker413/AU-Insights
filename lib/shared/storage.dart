import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedStorage {
  static const MethodChannel _channel = MethodChannel('com.au/appgroup');

  /// Returns the base App Group path used by all AU apps, or null on error.
  static Future<String?> getAppGroupPath() async {
    try {
      final String? path =
          await _channel.invokeMethod<String>('getAppGroupPath');
      if (path == null || path.isEmpty) {
        debugPrint('SharedStorage(AU Insights): empty App Group path.');
        return null;
      }
      return path;
    } catch (e, st) {
      debugPrint('SharedStorage(AU Insights): error getting App Group path: $e\n$st');
      return null;
    }
  }
}
