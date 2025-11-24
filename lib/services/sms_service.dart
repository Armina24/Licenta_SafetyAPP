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
    final report = await sendSmsSilentlyWithReport(
      phoneNumbers: [phoneNumber],
      message: message,
    );
    return report.allSent;
  }

  Future<bool> sendSmsSilentlyToMultiple({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    final report = await sendSmsSilentlyWithReport(
      phoneNumbers: phoneNumbers,
      message: message,
    );
    return report.allSent;
  }

  Future<SmsSendReport> sendSmsSilentlyWithReport({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    if (phoneNumbers.isEmpty) {
      return SmsSendReport.empty(message: message);
    }

    final permissionGranted = await ensureSmsPermission();
    if (!permissionGranted) {
      return SmsSendReport.permissionDenied(
        phoneNumbers: phoneNumbers,
        message: message,
      );
    }

    final successes = <String>[];
    final failures = <SmsSendFailure>[];

    for (final number in phoneNumbers) {
      try {
        final result = await _channel.invokeMethod<bool>('sendSms', {
          'to': number,
          'message': message,
        });
        final sent = result ?? false;
        if (sent) {
          successes.add(number);
        } else {
          failures.add(
            SmsSendFailure(
              phoneNumber: number,
              reason: 'Eroare necunoscută la trimiterea SMS-ului.',
            ),
          );
        }
      } on PlatformException catch (error) {
        failures.add(
          SmsSendFailure(
            phoneNumber: number,
            reason: error.message ?? 'Eroare platformă la trimiterea SMS-ului.',
          ),
        );
      } catch (error) {
        failures.add(
          SmsSendFailure(
            phoneNumber: number,
            reason: error.toString(),
          ),
        );
      }
    }

    return SmsSendReport(
      message: message,
      successfullySent: successes,
      failed: failures,
    );
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

class SmsSendReport {
  final String message;
  final List<String> successfullySent;
  final List<SmsSendFailure> failed;

  const SmsSendReport({
    required this.message,
    required this.successfullySent,
    required this.failed,
  });

  factory SmsSendReport.empty({required String message}) => SmsSendReport(
        message: message,
        successfullySent: const [],
        failed: const [],
      );

  factory SmsSendReport.permissionDenied({
    required List<String> phoneNumbers,
    required String message,
  }) =>
      SmsSendReport(
        message: message,
        successfullySent: const [],
        failed: phoneNumbers
            .map(
              (number) => SmsSendFailure(
                phoneNumber: number,
                reason: 'Permisiunea SEND_SMS nu este acordată.',
              ),
            )
            .toList(),
      );

  bool get allSent => failed.isEmpty && successfullySent.isNotEmpty;
  bool get hasPartialSuccess =>
      successfullySent.isNotEmpty && failed.isNotEmpty;
  bool get noneSent => successfullySent.isEmpty;
}

class SmsSendFailure {
  final String phoneNumber;
  final String reason;

  const SmsSendFailure({
    required this.phoneNumber,
    required this.reason,
  });
}
