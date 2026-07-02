import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'black_box_recorder_service.dart';
import 'connectivity_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'sms_service.dart';
import 'alerts_service.dart';

class EmergencyService {
  EmergencyService._internal();
  static final EmergencyService instance = EmergencyService._internal();

  final LocationService _locationService = LocationService.instance;
  final SmsService _smsService = SmsService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  final BlackBoxRecorderService _blackBoxRecorder =
      BlackBoxRecorderService.instance;

  final Duration offlineThrottle = const Duration(minutes: 30);

  final ValueNotifier<EmergencyBackgroundEvent?> _backgroundEventNotifier =
      ValueNotifier<EmergencyBackgroundEvent?>(null);

  ValueListenable<EmergencyBackgroundEvent?> get backgroundEvents =>
      _backgroundEventNotifier;

  bool _initialized = false;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _lastHadInternet = true;
  DateTime? _lastOfflineAlertAt;

  Future<void> initialize() async {
    if (_initialized) return;

    await _blackBoxRecorder.initialize();

    _lastHadInternet = await _connectivityService.hasInternetNow();
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen((hasInternet) {
          unawaited(_handleConnectivityChange(hasInternet));
        });
    _initialized = true;
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    await _blackBoxRecorder.stopRecording();

    _initialized = false;
  }

  EmergencyBackgroundEvent? popBackgroundEvent() {
    final event = _backgroundEventNotifier.value;
    if (event != null) {
      _backgroundEventNotifier.value = null;
    }
    return event;
  }

  Future<EmergencyActionResult> sendManualSos() async {
    _blackBoxRecorder.startRecording(
      recordingDuration: const Duration(minutes: 5),
      snapshotInterval: const Duration(seconds: 3),
    );

    final contacts = await _smsService.loadEmergencyContacts();
    if (contacts.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        failureType: EmergencyFailureType.noContacts,
        userMessage: 'Nu există contacte de urgență salvate.',
      );
    }

    final locationReading = await _locationService.acquireLocation(
      allowLastKnownFallback: true,
    );
    if (!locationReading.isSuccess) {
      final message =
          locationReading.errorMessage ?? 'Nu am putut obține locația curentă.';
      final failureType =
          locationReading.error == LocationFailure.permissionDenied
          ? EmergencyFailureType.permissionDenied
          : EmergencyFailureType.locationUnavailable;
      return EmergencyActionResult(
        success: false,
        failureType: failureType,
        userMessage: message,
      );
    }

    final position = locationReading.position!;
    final message = _buildManualSosMessage(
      position: position,
      usedLastKnown: locationReading.usedLastKnownPosition,
    );

    final report = await _smsService.sendSmsSilentlyWithReport(
      phoneNumbers: contacts,
      message: message,
    );

    if (report.allSent) {
      return EmergencyActionResult(
        success: true,
        failureType: null,
        userMessage: locationReading.usedLastKnownPosition
            ? 'Mesajul SOS a fost trimis cu ultima locație cunoscută.'
            : 'Mesajul SOS a fost trimis către contactele de urgență.',
        usedLastKnownLocation: locationReading.usedLastKnownPosition,
      );
    }

    if (report.hasPartialSuccess) {
      final failedNumbers = report.failed
          .map((failure) => failure.phoneNumber)
          .join(', ');
      return EmergencyActionResult(
        success: false,
        failureType: EmergencyFailureType.smsPartialFailure,
        userMessage:
            'Mesajul SOS a fost trimis doar către unele contacte. Nu s-a trimis către: $failedNumbers.',
        smsFailures: report.failed,
        usedLastKnownLocation: locationReading.usedLastKnownPosition,
      );
    }

    final permissionGranted = await _smsService.hasSmsPermission();
    final failureType = permissionGranted
        ? EmergencyFailureType.smsFailed
        : EmergencyFailureType.permissionDenied;

    final failureReason = report.failed.isNotEmpty
        ? report.failed.first.reason
        : null;

    final userMessage = permissionGranted
        ? 'Nu am putut trimite mesajul SOS. ${failureReason ?? 'Verifică semnalul și creditul.'}'
        : 'Permisiunea SEND_SMS este necesară pentru a trimite mesajul SOS.';

    return EmergencyActionResult(
      success: false,
      failureType: failureType,
      userMessage: userMessage,
      smsFailures: report.failed,
      usedLastKnownLocation: locationReading.usedLastKnownPosition,
    );
  }

  Future<void> _handleConnectivityChange(bool hasInternet) async {
    debugPrint(
      '[EmergencyService] Connectivity changed. hadInternet=$_lastHadInternet → hasInternet=$hasInternet',
    );
    if (!hasInternet && _lastHadInternet) {
      await _handleLostInternet();
    }
    _lastHadInternet = hasInternet;
  }

  Future<void> _handleLostInternet() async {
    final now = DateTime.now();
    debugPrint('[EmergencyService] Lost internet detected at $now');
    if (_lastOfflineAlertAt != null &&
        now.difference(_lastOfflineAlertAt!) < offlineThrottle) {
      _emitBackgroundEvent(
        EmergencyBackgroundEvent(
          timestamp: now,
          type: EmergencyBackgroundEventType.offlineAlertSkipped,
          message:
              'Alerta offline a fost sărită pentru a evita trimiterea repetată.',
        ),
      );
      return;
    }

    final contacts = await _smsService.loadEmergencyContacts();
    if (contacts.isEmpty) {
      _emitBackgroundEvent(
        EmergencyBackgroundEvent(
          timestamp: now,
          type: EmergencyBackgroundEventType.noContacts,
          message:
              'Nu există contacte de urgență salvate. Notificarea offline nu a fost trimisă.',
        ),
      );
      return;
    }

    _lastOfflineAlertAt = now;
    await NotificationService.instance.showOfflineAlertNotification();

    _emitBackgroundEvent(
      EmergencyBackgroundEvent(
        timestamp: now,
        type: EmergencyBackgroundEventType.offlineAlertRequested,
        message:
            'Conexiunea la internet s-a pierdut. A fost afișată o notificare pentru a trimite SMS-ul manual.',
        recipients: contacts,
      ),
    );
  }

  Future<EmergencyActionResult> sendOfflineAlertManually() async {
    final contacts = await _smsService.loadEmergencyContacts();
    if (contacts.isEmpty) {
      final result = const EmergencyActionResult(
        success: false,
        failureType: EmergencyFailureType.noContacts,
        userMessage: 'Nu există contacte de urgență salvate.',
      );
      _emitBackgroundEvent(
        EmergencyBackgroundEvent(
          timestamp: DateTime.now(),
          type: EmergencyBackgroundEventType.noContacts,
          message:
              'Nu există contacte de urgență salvate. SMS-ul offline nu a fost trimis.',
        ),
      );
      return result;
    }

    final permissionGranted = await _smsService.hasSmsPermission();
    if (!permissionGranted) {
      final result = const EmergencyActionResult(
        success: false,
        failureType: EmergencyFailureType.permissionDenied,
        userMessage:
            'Permisiunea SEND_SMS este necesară pentru a trimite mesajul offline.',
      );
      _emitBackgroundEvent(
        EmergencyBackgroundEvent(
          timestamp: DateTime.now(),
          type: EmergencyBackgroundEventType.offlineAlertFailed,
          message:
              'Nu s-a putut trimite mesajul offline. Permisiunea SEND_SMS lipsește.',
          recipients: contacts,
        ),
      );
      return result;
    }

    final locationReading = await _locationService.acquireLocation(
      allowLastKnownFallback: true,
    );
    final message = _buildOfflineManualMessage(locationReading);

    final report = await _smsService.sendSmsSilentlyWithReport(
      phoneNumbers: contacts,
      message: message,
    );

    final failuresDescription = report.failed
        .map((failure) => '${failure.phoneNumber}: ${failure.reason}')
        .join('; ');

    if (report.allSent) {
      final result = EmergencyActionResult(
        success: true,
        failureType: null,
        userMessage: locationReading.usedLastKnownPosition
            ? 'Mesajul offline a fost trimis cu ultima locație cunoscută.'
            : 'Mesajul offline a fost trimis către contactele de urgență.',
        usedLastKnownLocation: locationReading.usedLastKnownPosition,
      );
      _emitBackgroundEvent(
        EmergencyBackgroundEvent(
          timestamp: DateTime.now(),
          type: EmergencyBackgroundEventType.offlineAlertSent,
          message: 'Mesajul offline a fost trimis către toate contactele.',
          recipients: contacts,
          usedLastKnownLocation: locationReading.usedLastKnownPosition,
        ),
      );
      return result;
    }

    if (report.hasPartialSuccess) {
      final result = EmergencyActionResult(
        success: false,
        failureType: EmergencyFailureType.smsPartialFailure,
        userMessage:
            'Mesajul offline a fost trimis doar către unele contacte. Detalii: $failuresDescription',
        smsFailures: report.failed,
        usedLastKnownLocation: locationReading.usedLastKnownPosition,
      );
      _emitBackgroundEvent(
        EmergencyBackgroundEvent(
          timestamp: DateTime.now(),
          type: EmergencyBackgroundEventType.offlineAlertPartialFailure,
          message:
              'Mesajul offline a fost trimis doar către unele contacte. Detalii: $failuresDescription',
          recipients: contacts,
          failures: report.failed,
          usedLastKnownLocation: locationReading.usedLastKnownPosition,
        ),
      );
      return result;
    }

    final failureReason = failuresDescription.isEmpty
        ? 'Eroare necunoscută la trimiterea SMS-ului.'
        : failuresDescription;

    final result = EmergencyActionResult(
      success: false,
      failureType: EmergencyFailureType.smsFailed,
      userMessage: 'Nu am putut trimite mesajul offline. $failureReason',
      smsFailures: report.failed,
      usedLastKnownLocation: locationReading.usedLastKnownPosition,
    );

    _emitBackgroundEvent(
      EmergencyBackgroundEvent(
        timestamp: DateTime.now(),
        type: EmergencyBackgroundEventType.offlineAlertFailed,
        message: 'Nu s-a putut trimite mesajul offline. $failureReason',
        recipients: contacts,
        failures: report.failed,
        usedLastKnownLocation: locationReading.usedLastKnownPosition,
      ),
    );

    return result;
  }

  void _emitBackgroundEvent(EmergencyBackgroundEvent event) {
    debugPrint('[EmergencyService] ${event.type} - ${event.message}');
    _backgroundEventNotifier.value = event;
  }

  String _buildManualSosMessage({
    required Position position,
    required bool usedLastKnown,
  }) {
    final lat = position.latitude.toStringAsFixed(6);
    final lon = position.longitude.toStringAsFixed(6);
    final link = 'https://maps.google.com/?q=$lat,$lon';
    final buffer = StringBuffer('Ajutor, sunt aici: $link');
    buffer.write(' (lat: $lat, lon: $lon)');
    if (usedLastKnown) {
      buffer.write(' - ultima locație cunoscută');
    }
    return buffer.toString();
  }

  String _buildOfflineManualMessage(LocationReading reading) {
    if (!reading.isSuccess) {
      return 'Am ramas fara internet, ultima mea locatie a fost aici: (nu am putut obține locația)';
    }
    final position = reading.position!;
    final lat = position.latitude.toStringAsFixed(6);
    final lon = position.longitude.toStringAsFixed(6);
    final link = 'https://maps.google.com/?q=$lat,$lon';
    return 'Am ramas fara internet, ultima mea locatie a fost aici: $link (lat: $lat, lon: $lon)';
  }
}

class EmergencyActionResult {
  final bool success;
  final EmergencyFailureType? failureType;
  final String userMessage;
  final List<SmsSendFailure> smsFailures;
  final bool usedLastKnownLocation;

  const EmergencyActionResult({
    required this.success,
    required this.userMessage,
    this.failureType,
    this.smsFailures = const [],
    this.usedLastKnownLocation = false,
  });
}

enum EmergencyFailureType {
  noContacts,
  permissionDenied,
  locationUnavailable,
  smsFailed,
  smsPartialFailure,
}

class EmergencyBackgroundEvent {
  final DateTime timestamp;
  final EmergencyBackgroundEventType type;
  final String message;
  final List<String> recipients;
  final List<SmsSendFailure> failures;
  final bool usedLastKnownLocation;

  EmergencyBackgroundEvent({
    required this.timestamp,
    required this.type,
    required this.message,
    this.recipients = const [],
    this.failures = const [],
    this.usedLastKnownLocation = false,
  });
}

enum EmergencyBackgroundEventType {
  offlineAlertRequested,
  offlineAlertSent,
  offlineAlertPartialFailure,
  offlineAlertFailed,
  offlineAlertSkipped,
  noContacts,
}
