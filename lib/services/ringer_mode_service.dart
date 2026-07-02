import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

enum RingerMode { normal, vibrate, silent }

class RingerModeService {
  static const platform = MethodChannel('com.safety_app/ringer_mode');

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

  static Future<bool> isSilentMode() async {
    final mode = await getRingerMode();
    return mode == RingerMode.silent;
  }

  static Future<bool> isVibrateMode() async {
    final mode = await getRingerMode();
    return mode == RingerMode.vibrate;
  }

  static Future<bool> isNormalMode() async {
    final mode = await getRingerMode();
    return mode == RingerMode.normal;
  }
}
