import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'location_service.dart';

class LiveLocationShareSession {
  final String token;
  final Uri shareUri;
  final DateTime expiresAt;
  final int durationMinutes;

  const LiveLocationShareSession({
    required this.token,
    required this.shareUri,
    required this.expiresAt,
    required this.durationMinutes,
  });
}

class LiveLocationShareService {
  LiveLocationShareService._internal();

  static final LiveLocationShareService instance =
      LiveLocationShareService._internal();

  final http.Client _client = http.Client();
  final ApiClient _api = ApiClient.instance;
  final LocationService _locationService = LocationService.instance;

  Timer? _updateTimer;
  Timer? _expiryTimer;
  String? _activeToken;

  Future<LiveLocationShareSession> startSharing({
    required int durationMinutes,
  }) async {
    await stopSharing();

    final permissionGranted = await _locationService.ensurePermission();
    if (!permissionGranted) {
      throw Exception('Location permission is required to start live sharing.');
    }

    final response = await _client.post(
      _api.buildUri('/api/location-shares'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'durationMinutes': durationMinutes}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create live location session.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final session = LiveLocationShareSession(
      token: payload['token'] as String,
      shareUri: Uri.parse(payload['shareUrl'] as String),
      expiresAt: DateTime.parse(payload['expiresAt'] as String),
      durationMinutes: payload['durationMinutes'] as int,
    );

    _activeToken = session.token;
    await _pushLatestLocation(session.token);
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_pushLatestLocation(session.token));
    });

    final remaining = session.expiresAt.difference(DateTime.now());
    _expiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => stopSharing(),
    );

    return session;
  }

  Future<void> stopSharing() async {
    _updateTimer?.cancel();
    _updateTimer = null;

    _expiryTimer?.cancel();
    _expiryTimer = null;

    final token = _activeToken;
    _activeToken = null;

    if (token == null) {
      return;
    }

    try {
      await _client.post(
        _api.buildUri('/api/location-shares/$token/stop'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (_) {}
  }

  Future<void> _pushLatestLocation(String token) async {
    if (_activeToken != token) {
      return;
    }

    try {
      final reading = await _locationService.acquireLocation(
        allowLastKnownFallback: false,
      );

      if (!reading.isSuccess || reading.position == null) {
        return;
      }

      final Position position = reading.position!;
      final resp = await _client.patch(
        _api.buildUri('/api/location-shares/$token/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
        }),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        print(
          '[LiveLocationShare] failed push: ${resp.statusCode} ${resp.body}',
        );
      }
    } catch (_) {}
  }

  String buildShareMessage({
    required String durationLabel,
    required Uri shareUri,
  }) {
    return 'I am sharing my live location for $durationLabel. Track me here: $shareUri';
  }
}
