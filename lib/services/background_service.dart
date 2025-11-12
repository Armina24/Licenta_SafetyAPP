import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';
import 'sms_service.dart';

class AppBackgroundService {
  AppBackgroundService._internal();
  static final AppBackgroundService instance = AppBackgroundService._internal();

  static const String _keyLastOfflineSmsAt = 'last_offline_sms_at';
  static const String _keyContacts = 'emergency_contacts'; // CSV: num1,num2,...

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      return;
    }
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: true,
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: 'Safety App',
        initialNotificationContent: 'Monitoring connectivity and location',
      ),
      iosConfiguration: IosConfiguration(),
    );

    await service.startService();
  }

  static Future<void> _onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }

    final connectivity = Connectivity();
    await LocationService.instance.ensurePermission();

    bool lastHadInternet = true;
    try {
      final current = await connectivity.checkConnectivity();
      lastHadInternet = current.any((result) => result != ConnectivityResult.none);
    } catch (_) {}

    final sub = connectivity.onConnectivityChanged.listen((results) async {
      final hasNet = results.any((result) => result != ConnectivityResult.none);
      if (!hasNet && lastHadInternet) {
        // tocmai am pierdut internetul -> trimite SMS cu ultima locație
        await _sendOfflineLocationSms();
      }
      lastHadInternet = hasNet;
    });

    // Keep alive timer ping
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'Safety App',
          content: 'Running • monitoring connectivity and location',
        );
      }
    });

    service.on('stopService').listen((event) {
      sub.cancel();
      service.stopSelf();
    });
  }

  static Future<void> _sendOfflineLocationSms() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsCsv = prefs.getString(_keyContacts) ?? '';
    final contacts = contactsCsv
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (contacts.isEmpty) return;

    if (!await SmsService.instance.hasSmsPermission()) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('SMS not sent: permission missing');
      }
      return;
    }

    // throttle: nu trimite mai des de o dată la 10 minute
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastAt = prefs.getInt(_keyLastOfflineSmsAt) ?? 0;
    if (now - lastAt < 10 * 60 * 1000) {
      return;
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }
    final lat = pos?.latitude;
    final lon = pos?.longitude;
    final latStr = lat?.toStringAsFixed(6) ?? 'N/A';
    final lonStr = lon?.toStringAsFixed(6) ?? 'N/A';

    final message = StringBuffer()
      ..writeln('Am rămas fără internet.')
      ..writeln('Aceasta este ultima mea locație cunoscută:')
      ..writeln('Latitudine: $latStr')
      ..writeln('Longitudine: $lonStr');
    if (lat != null && lon != null) {
      message
        ..writeln()
        ..writeln('Link hartă:')
        ..writeln('https://maps.google.com/?q=$latStr,$lonStr');
    }

    final success = await SmsService.instance.sendSmsSilentlyToMultiple(
      phoneNumbers: contacts,
      message: message.toString(),
    );

    if (!success && kDebugMode) {
      // ignore: avoid_print
      print('Background SMS failed');
    }

    await prefs.setInt(_keyLastOfflineSmsAt, now);
  }
}


