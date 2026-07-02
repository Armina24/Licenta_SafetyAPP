import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AlertsService {
  AlertsService._();
  static final AlertsService instance = AlertsService._();

  final http.Client _client = http.Client();
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('Utilizatorul nu este autentificat.');
    }

    final response = await _client.get(
      _api.buildUri('/api/alerts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('Eroare la încărcarea alertelor: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> logAlert({
    double? latitude,
    double? longitude,
    String status = 'pending',
    int contactsReached = 0,
    String? message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      throw Exception('Utilizatorul nu este autentificat.');
    }

    final body = {'status': status, 'contactsReached': contactsReached};
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (message != null) body['message'] = message;

    final response = await _client.post(
      _api.buildUri('/api/alerts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Eroare la salvarea alertei: ${response.statusCode}');
    }
  }
}
