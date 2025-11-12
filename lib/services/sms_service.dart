// lib/services/sms_service.dart
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  SmsService._internal();
  static final SmsService instance = SmsService._internal();

  static const _channel = MethodChannel('safety_app/sms');

  Future<bool> hasSmsPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  Future<bool> ensureSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    final req = await Permission.sms.request();
    return req.isGranted;
  }

  /// Trimite SMS la un singur număr (deschide aplicația de mesaje).
  Future<void> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    if (!await launchUrl(uri)) {
      // aici poți pune un SnackBar / print pentru eroare
      // print('Nu am putut deschide aplicația de mesaje.');
    }
  }

  /// Trimite același mesaj la mai multe contacte, unul după altul.
  Future<void> sendSmsToMultiple({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    for (final number in phoneNumbers) {
      await sendSms(phoneNumber: number, message: message);
    }
  }

  /// Trimite SMS direct, în background (Android), fără a deschide aplicația de mesaje.
  Future<bool> sendSmsSilently({
    required String phoneNumber,
    required String message,
  }) async {
    final ok = await ensureSmsPermission();
    if (!ok) {
      // opțional: deschide setările aplicației pentru a acorda permisiunea
      // await openAppSettings();
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('sendSms', {
        'to': phoneNumber,
        'message': message,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> sendSmsSilentlyToMultiple({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    bool allSent = true;
    for (final number in phoneNumbers) {
      final sent = await sendSmsSilently(phoneNumber: number, message: message);
      if (!sent) {
        allSent = false;
      }
    }
    return allSent;
  }

  Future<List<String>> loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final csv = prefs.getString('emergency_contacts') ?? '';
    return csv
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Helper special pentru locație (lat, lon → mesaj frumos).
  Future<void> sendLocationToContacts({
    required List<String> phoneNumbers,
    required double latitude,
    required double longitude,
  }) async {
    final latStr = latitude.toStringAsFixed(6);
    final lonStr = longitude.toStringAsFixed(6);

    final message = '''
Atenție! Acesta este un mesaj automat din aplicația de siguranță.

Ultima mea locație cunoscută:
Latitudine: $latStr
Longitudine: $lonStr

Link hartă:
https://maps.google.com/?q=$latStr,$lonStr
''';

    await sendSmsToMultiple(
      phoneNumbers: phoneNumbers,
      message: message,
    );
  }

  Future<bool> sendLocationToContactsSilently({
    required List<String> phoneNumbers,
    required double latitude,
    required double longitude,
  }) async {
    final latStr = latitude.toStringAsFixed(6);
    final lonStr = longitude.toStringAsFixed(6);

    final message = '''
Atenție! Acesta este un mesaj automat din aplicația de siguranță.

Ultima mea locație cunoscută:
Latitudine: $latStr
Longitudine: $lonStr

Link hartă:
https://maps.google.com/?q=$latStr,$lonStr
''';

    return sendSmsSilentlyToMultiple(
      phoneNumbers: phoneNumbers,
      message: message,
    );
  }
}
