import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Enum for ringer mode states
enum RingerMode {
  normal,     // Normal mode - sound enabled
  vibrate,    // Vibrate mode - no sound
  silent,     // Silent mode - no sound, no vibration
}

/// Service to detect device ringer mode
class RingerModeService {
  static const platform = MethodChannel('com.safety_app/ringer_mode');

  /// Get current ringer mode
  static Future<RingerMode> getRingerMode() async {
    try {
      final int result = await platform.invokeMethod('getRingerMode');
      
      switch (result) {
        case 0:
          return RingerMode.silent;
        case 1:
          return RingerMode.vibrate;
        case 2:
          return RingerMode.normal;
        default:
          return RingerMode.normal;
      }
    } catch (e) {
      debugPrint('Error getting ringer mode: $e');
      return RingerMode.normal;
    }
  }

  /// Check if device is in silent mode
  static Future<bool> isSilentMode() async {
    final mode = await getRingerMode();
    return mode == RingerMode.silent;
  }

  /// Check if device is in vibrate mode
  static Future<bool> isVibrateMode() async {
    final mode = await getRingerMode();
    return mode == RingerMode.vibrate;
  }

  /// Check if device is in normal mode
  static Future<bool> isNormalMode() async {
    final mode = await getRingerMode();
    return mode == RingerMode.normal;
  }
}
