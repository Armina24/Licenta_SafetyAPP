import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_YAMNet/audio_monitor_service.dart';
import 'audio_YAMNet/yamnet_service.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

class BackgroundSoundService {
  BackgroundSoundService._();
  static final BackgroundSoundService instance = BackgroundSoundService._();

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    final micGranted = await _ensureMicrophonePermission();
    final notifGranted = await _ensureNotificationPermission();

    if (!micGranted) {
      debugPrint(
        'Microphone permission not granted; background sound disabled.',
      );
      return;
    }
    if (!notifGranted) {
      debugPrint(
        'Notification permission not granted; cannot start foreground service.',
      );
      return;
    }

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceNotificationId: 1001,
        initialNotificationTitle: 'Safety App',
        initialNotificationContent: 'Listening in background…',
      ),
      iosConfiguration: IosConfiguration(),
    );

    await service.startService();
    debugPrint(
      'BackgroundSoundService started as Android foreground service.',
    );
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) return;

    try {
      service.invoke('stopService');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
    debugPrint('BackgroundSoundService stop requested.');
  }

  Future<bool> _ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> _ensureNotificationPermission() async {
    var status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) return true;

    status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }
}

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  DartPluginRegistrant.ensureInitialized();
  debugPrint(
    'Background sound service isolate started with YAMNet detection.',
  );

  try {
    await WakelockPlus.enable();
    debugPrint('[BG] WakeLock activat! CPU-ul nu va intra in sleep.');
  } catch (e) {
    debugPrint('[BG] Nu am putut activa WakeLock: $e');
  }

  bool audioMonitoring = false;

  debugPrint('[BG] Initializing YAMNet model in isolate...');
  try {
    await YamnetService.instance.init();
    debugPrint('[BG] YAMNet model initialized successfully');
  } catch (e) {
    debugPrint('[BG] Failed to initialize YAMNet: $e');
  }

  service.on('startAudio').listen((event) async {
    debugPrint('[BG] startAudio: beginning sound detection with YAMNet');
    if (audioMonitoring) return;

    audioMonitoring = true;

    try {
      await AudioMonitorService.instance.startMonitoring(
        onAlert: (result) {
          debugPrint(
            '[BG] Sound detected: Tipete=${result.tipete.toStringAsFixed(4)}, '
            'Aglomerație=${result.aglomeratie.toStringAsFixed(4)}, '
            'Spargere=${result.spargere.toStringAsFixed(4)}',
          );

          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Safety App – Sound Monitor',
              content:
                  'Tipete: ${result.tipete.toStringAsFixed(2)}, '
                  'Aglomerație: ${result.aglomeratie.toStringAsFixed(2)}, '
                  'Spargere: ${result.spargere.toStringAsFixed(2)}',
            );
          }
        },
      );
      debugPrint('[BG] Audio monitoring started');
    } catch (e) {
      debugPrint('[BG] Error starting audio monitoring: $e');
      audioMonitoring = false;
    }
  });

  service.on('stopAudio').listen((event) async {
    debugPrint('[BG] stopAudio: stopping sound detection');
    if (!audioMonitoring) return;
    audioMonitoring = false;
    try {
      await AudioMonitorService.instance.stopMonitoring();
      debugPrint('[BG] Audio monitoring stopped');
    } catch (e) {
      debugPrint('[BG] Error stopping audio monitoring: $e');
    }

    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: 'Safety App',
        content: 'Sound monitoring stopped',
      );
    }
  });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: 'Safety App – Sound Monitor',
        content: audioMonitoring
            ? 'Listening for threats...'
            : 'Running in background',
      );
    }
  });

  service.on('stopService').listen((event) async {
    debugPrint('Background sound service stopped');
    if (audioMonitoring) {
      try {
        AudioMonitorService.instance.stopMonitoring();
      } catch (_) {}
    }
    try {
      await WakelockPlus.disable();
      debugPrint('[BG] WakeLock dezactivat. CPU-ul poate intra in sleep.');
    } catch (e) {
      debugPrint('[BG] Nu am putut dezactiva WakeLock: $e');
    }
    service.stopSelf();
  });
}
