import 'package:shared_preferences/shared_preferences.dart';

class UserProfileStorage {
  UserProfileStorage._();

  static String _normalizeEmail(String email) {
    return Uri.encodeComponent(email.trim().toLowerCase());
  }

  static String _scopedKey(String email, String key) {
    return 'profile:${_normalizeEmail(email)}:$key';
  }

  static String? currentEmail(SharedPreferences prefs) {
    final email = prefs.getString('userEmail');
    if (email != null && email.trim().isNotEmpty) {
      return email.trim();
    }
    return null;
  }

  static String? getString(
    SharedPreferences prefs,
    String key, {
    List<String> legacyKeys = const [],
  }) {
    final email = currentEmail(prefs);
    if (email != null) {
      final scopedValue = prefs.getString(_scopedKey(email, key));
      if (scopedValue != null) {
        return scopedValue;
      }
    }

    for (final legacyKey in legacyKeys) {
      final legacyValue = prefs.getString(legacyKey);
      if (legacyValue != null) {
        return legacyValue;
      }
    }

    return null;
  }

  static Future<void> setString(
    SharedPreferences prefs,
    String key,
    String value, {
    List<String> legacyKeys = const [],
  }) async {
    final email = currentEmail(prefs);
    if (email != null) {
      await prefs.setString(_scopedKey(email, key), value);
    }

    for (final legacyKey in legacyKeys) {
      await prefs.setString(legacyKey, value);
    }
  }

  static bool? getBool(
    SharedPreferences prefs,
    String key, {
    List<String> legacyKeys = const [],
  }) {
    final email = currentEmail(prefs);
    if (email != null) {
      final scopedValue = prefs.getBool(_scopedKey(email, key));
      if (scopedValue != null) {
        return scopedValue;
      }
    }

    for (final legacyKey in legacyKeys) {
      final legacyValue = prefs.getBool(legacyKey);
      if (legacyValue != null) {
        return legacyValue;
      }
    }

    return null;
  }

  static Future<void> setBool(
    SharedPreferences prefs,
    String key,
    bool value, {
    List<String> legacyKeys = const [],
  }) async {
    final email = currentEmail(prefs);
    if (email != null) {
      await prefs.setBool(_scopedKey(email, key), value);
    }

    for (final legacyKey in legacyKeys) {
      await prefs.setBool(legacyKey, value);
    }
  }

  static int? getInt(
    SharedPreferences prefs,
    String key, {
    List<String> legacyKeys = const [],
  }) {
    final email = currentEmail(prefs);
    if (email != null) {
      final scopedValue = prefs.getInt(_scopedKey(email, key));
      if (scopedValue != null) {
        return scopedValue;
      }
    }

    for (final legacyKey in legacyKeys) {
      final legacyValue = prefs.getInt(legacyKey);
      if (legacyValue != null) {
        return legacyValue;
      }
    }

    return null;
  }

  static Future<void> setInt(
    SharedPreferences prefs,
    String key,
    int value, {
    List<String> legacyKeys = const [],
  }) async {
    final email = currentEmail(prefs);
    if (email != null) {
      await prefs.setInt(_scopedKey(email, key), value);
    }

    for (final legacyKey in legacyKeys) {
      await prefs.setInt(legacyKey, value);
    }
  }

  static Future<void> remove(
    SharedPreferences prefs,
    String key, {
    List<String> legacyKeys = const [],
  }) async {
    final email = currentEmail(prefs);
    if (email != null) {
      await prefs.remove(_scopedKey(email, key));
    }

    for (final legacyKey in legacyKeys) {
      await prefs.remove(legacyKey);
    }
  }
}
