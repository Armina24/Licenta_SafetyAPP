import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Removed unnecessary android-specific import; use types from flutter_background_service

import 'location_service.dart';
import 'sms_service.dart';
import 'audio_yamnet/audio_monitor_service.dart';

@pragma('vm:entry-point') // Needed so native background entry can find the class in AOT
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

    //se opreste orice instanta veche 
    final wasRunning = await service.isRunning();
    if(wasRunning)
    {
      debugPrint('⚠️ [BG] Exista deja un service vechi, il opresc...');
      //await service.invoke('stopService');
      
      await Future.delayed(const Duration(seconds: 1));
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: 'Safety App',
        initialNotificationContent: 'Monitoring connectivity and location',
      ),
      iosConfiguration: IosConfiguration(),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    debugPrint('🔵 [BG] _onStart pornit (background service a început).');
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }

    DartPluginRegistrant.ensureInitialized();

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

    bool audioMonitoring = false;  //status audio in bg

    //UI da start la audio
    service.on('startAudio').listen((event) async {
      debugPrint('🟢 [BG] startAudio primit – pornesc AudioMonitorService în background.');
      if (audioMonitoring) return;

      audioMonitoring = true;

      await AudioMonitorService.instance.startMonitoring(onAlert: (result){
        debugPrint('🚨 [BG] ALERTĂ AUDIO: $result');
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Safety App - sunet detectat',
            content: 'Tipete: ${result.tipete.toStringAsFixed(2)}, aglomerație: ${result.aglomeratie.toStringAsFixed(2)}, spargere: ${result.spargere.toStringAsFixed(2)}',
          );
        }
        //aici pot declansa SMS, notificari, etc.

        debugPrint('BACKGROUND ALERT AUDIO: $result');
      });
    });

    //UI da stop la audio
    service.on('stopAudio').listen((event) async {
      debugPrint('🛑 [BG] stopAudio primit – opresc AudioMonitorService.');
      if(!audioMonitoring) return;
      audioMonitoring = false;
      await AudioMonitorService.instance.stopMonitoring();

      if(service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'Safety App', 
          content: 'Running • monitoring connectivity and location',
        );
      }
    });

    // Keep alive timer ping
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'Safety App',
          content: audioMonitoring
            ? 'Running • connectivity, location & audio'
            : 'Running • monitoring connectivity and location',
        );
      }
    });

    service.on('stopService').listen((event) {
      sub.cancel();
      service.stopSelf();
    });

    /*ShakeDetector.autoStart(
      onPhoneShake: (ShakeEvent event) async {
       // print("SHAKE DETECTAT!");
        if( await Vibration.hasVibrator() ?? false) {
          print("666");
          if( await Vibration.hasCustomVibrationsSupport() ?? false) {
            print("888");

            Vibration.vibrate(duration: 1000);
            await Future.delayed(Duration(milliseconds: 500));
            Vibration.vibrate();
          }
        }
      },
      minimumShakeCount: 1,
      shakeSlopTimeMS: 500,
      shakeCountResetTime: 3000,
      shakeThresholdGravity: 2.7,
      useFilter: false,
    );*/
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


