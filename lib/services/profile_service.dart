import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'user_profile_storage.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final http.Client _client = http.Client();
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('Utilizatorul nu este autentificat.');
    }

    final response = await _client.get(
      _api.buildUri('/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return {};
    } else {
      throw Exception(
        'Eroare la încărcarea profilului: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? phoneNumber,
    String? bio,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('Utilizatorul nu este autentificat.');
    }

    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (bio != null) body['bio'] = bio;

    final response = await _client.post(
      _api.buildUri('/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final result = jsonDecode(response.body) as Map<String, dynamic>;

      await UserProfileStorage.setString(prefs, 'fullName', displayName ?? '');
      if (phoneNumber != null) {
        await UserProfileStorage.setString(
          prefs,
          'phone',
          phoneNumber,
          legacyKeys: const ['phoneNumber'],
        );
      }

      return result;
    } else {
      throw Exception(
        'Eroare la actualizarea profilului: ${response.statusCode}',
      );
    }
  }
}
