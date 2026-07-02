import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'user_profile_storage.dart';
import 'emergency_contacts_service.dart';

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthException($statusCode): $message';
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final http.Client _client = http.Client();
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _api.buildUri('/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeJson(response.body) as Map<String, dynamic>;
    }

    throw _toAuthException(response);
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _client.post(
      _api.buildUri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = _decodeJson(response.body) as Map<String, dynamic>;
      final accessToken = payload['accessToken'] as String?;
      final refreshToken = payload['refreshToken'] as String?;

      if (accessToken == null || refreshToken == null) {
        throw AuthException('Răspuns invalid de la server.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);
      await prefs.setString('userEmail', email.trim());
      await prefs.setBool('isLoggedIn', true);

      try {
        final serverContacts = await EmergencyContactsService.instance
            .fetchContacts();
        final List<String> phones = [];
        final List<String> contactsList = [];
        for (final contact in serverContacts) {
          final name = contact['name'] ?? 'Contact';
          final phone = contact['phoneNumber'] ?? '';
          if (phone.isNotEmpty) {
            phones.add(phone);
            contactsList.add('$name::$phone');
          }
        }
        if (contactsList.isNotEmpty) {
          await UserProfileStorage.setString(
            prefs,
            'emergency_contacts_list',
            contactsList.join('|'),
          );
          await prefs.setString('emergency_contacts', phones.join(','));
        }
      } catch (e) {
        final contactsJson = UserProfileStorage.getString(
          prefs,
          'emergency_contacts_list',
        );
        if (contactsJson != null && contactsJson.isNotEmpty) {
          final List<dynamic> parsed = contactsJson
              .split('|')
              .map((item) {
                final parts = item.split('::');
                if (parts.length == 2) {
                  return parts[1];
                }
                return null;
              })
              .where((item) => item != null)
              .toList();
          await prefs.setString('emergency_contacts', parsed.join(','));
        }
      }

      return;
    }

    throw _toAuthException(response);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');

    if (refreshToken != null) {
      try {
        await _client.post(
          _api.buildUri('/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      } catch (_) {}
    }

    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userEmail');
    await prefs.setBool('isLoggedIn', false);

    await prefs.remove('emergency_contacts');
    await prefs.remove('emergency_contacts_list');
    await prefs.remove('safety_timer_active');
    await prefs.remove('safety_timer_end_time');
    await prefs.remove('safety_timer_check_in_notified');
    await prefs.remove('safety_timer_total_minutes');
    await prefs.remove('safety_shield_active');
    await prefs.remove('notifications_enabled');
    await prefs.remove('isDarkMode');
    await prefs.remove('last_offline_sms_at');
  }

  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    final token = await _getValidAccessToken();
    if (token == null) return null;

    final response = await _client.get(
      _api.buildUri('/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return _decodeJson(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed != null) {
        return fetchCurrentUser();
      }
      await logout();
      return null;
    }

    throw _toAuthException(response);
  }

  Future<String?> _getValidAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token != null) return token;
    return _refreshAccessToken();
  }

  Future<String?> _refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');
    if (refreshToken == null) return null;

    final response = await _client.post(
      _api.buildUri('/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = _decodeJson(response.body) as Map<String, dynamic>;
      final accessToken = payload['accessToken'] as String?;
      if (accessToken == null) {
        throw AuthException('Răspuns invalid de la server (refresh).');
      }
      await prefs.setString('accessToken', accessToken);
      return accessToken;
    }

    await logout();
    return null;
  }

  Object _decodeJson(String source) {
    if (source.isEmpty) return {};
    return jsonDecode(source);
  }

  AuthException _toAuthException(http.Response response) {
    try {
      final body = _decodeJson(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return AuthException(message, statusCode: response.statusCode);
        }
      }
    } catch (_) {}
    return AuthException(
      'A apărut o eroare (${response.statusCode}). Încearcă din nou.',
      statusCode: response.statusCode,
    );
  }

  Future<void> forgotPassword({
    required String email,
    required String channel,
  }) async {
    final response = await _client.post(
      _api.buildUri('/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'channel': channel}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw _toAuthException(response);
  }

  Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async {
    final response = await _client.post(
      _api.buildUri('/auth/verify-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = _decodeJson(response.body) as Map<String, dynamic>;
      final token = payload['resetToken'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Răspuns invalid de la server.');
      }
      return token;
    }
    throw _toAuthException(response);
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _client.post(
      _api.buildUri('/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'resetToken': resetToken, 'newPassword': newPassword}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw _toAuthException(response);
  }
}
