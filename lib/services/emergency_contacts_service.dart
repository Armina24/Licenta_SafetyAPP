import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class EmergencyContactsService {
  EmergencyContactsService._();
  static final EmergencyContactsService instance = EmergencyContactsService._();

  final http.Client _client = http.Client();
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> fetchContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('Utilizatorul nu este autentificat.');
    }

    final response = await _client.get(
      _api.buildUri('/api/emergency-contacts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(
        'Eroare la încărcarea contactelor: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> addContact({
    required String name,
    required String phoneNumber,
    String? relationship,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('Utilizatorul nu este autentificat.');
    }

    final body = {'name': name, 'phoneNumber': phoneNumber};
    if (relationship != null) {
      body['relationship'] = relationship;
    }

    final response = await _client.post(
      _api.buildUri('/api/emergency-contacts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Eroare la adăugarea contactului: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> updateContact({
    required int contactId,
    String? name,
    String? phoneNumber,
    String? relationship,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('Utilizatorul nu este autentificat.');
    }

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (relationship != null) body['relationship'] = relationship;

    final response = await _client.put(
      _api.buildUri('/api/emergency-contacts/$contactId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Eroare la actualizarea contactului: ${response.statusCode}',
      );
    }
  }

  Future<void> deleteContact(int contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('Utilizatorul nu este autentificat.');
    }

    final response = await _client.delete(
      _api.buildUri('/api/emergency-contacts/$contactId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Eroare la ștergerea contactului: ${response.statusCode}',
      );
    }
  }

  Future<void> syncLocalContacts(
    List<Map<String, String>> localContacts,
  ) async {
    for (final contact in localContacts) {
      try {
        await addContact(
          name: contact['name'] ?? 'Contact',
          phoneNumber: contact['phone'] ?? '',
        );
      } catch (e) {
        print('Failed to sync contact: $e');
      }
    }
  }
}
