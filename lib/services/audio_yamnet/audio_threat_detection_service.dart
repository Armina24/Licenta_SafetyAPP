import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'audio_monitor_service.dart';

class ThreatDetectionEvent {
  final SoundAlertResult soundResult;
  final ThreatType threatType;
  final double confidenceScore;
  final DateTime detectedAt;

  ThreatDetectionEvent({
    required this.soundResult,
    required this.threatType,
    required this.confidenceScore,
    required this.detectedAt,
  });

  @override
  String toString() =>
      'ThreatDetectionEvent(type=$threatType, confidence=$confidenceScore)';
}

enum ThreatType { scream, crowdNoise, glassBreak }

class SoundDetectionPreAlarm {
  final ThreatDetectionEvent threatEvent;
  final Duration timeout;
  final Function() onConfirm;
  final Function() onCancel;
  late Timer _countdownTimer;

  SoundDetectionPreAlarm({
    required this.threatEvent,
    required this.timeout,
    required this.onConfirm,
    required this.onCancel,
  });

  void start() {
    _countdownTimer = Timer(timeout, () {
      onConfirm();
    });
  }

  void cancel() {
    _countdownTimer.cancel();
  }

  void executeNow() {
    _countdownTimer.cancel();
    onConfirm();
  }
}

class AudioThreatDetectionService {
  AudioThreatDetectionService._internal();
  static final AudioThreatDetectionService instance =
      AudioThreatDetectionService._internal();

  static const double _screamConfidenceThreshold = 0.10;
  static const double _crowdConfidenceThreshold = 0.10;
  static const double _glassConfidenceThreshold = 0.15;

  static const int _hapticDurationMs = 3000;

  static const Duration _preAlarmTimeout = Duration(seconds: 15);

  SoundDetectionPreAlarm? _currentPreAlarm;
  DateTime? _lastPreAlarmTime;
  static const Duration _preAlarmDebounce = Duration(seconds: 30);

  Function(ThreatDetectionEvent)? _onThreatDetected;
  Function(ThreatDetectionEvent)? _onPreAlarmConfirmed;
  Function(ThreatDetectionEvent, String reason)? _onPreAlarmCancelled;

  void initialize({
    required Function(ThreatDetectionEvent) onThreatDetected,
    required Function(ThreatDetectionEvent) onPreAlarmConfirmed,
    Function(ThreatDetectionEvent, String reason)? onPreAlarmCancelled,
  }) {
    _onThreatDetected = onThreatDetected;
    _onPreAlarmConfirmed = onPreAlarmConfirmed;
    _onPreAlarmCancelled = onPreAlarmCancelled;
  }

  Future<void> processSoundDetection(SoundAlertResult soundResult) async {
    ThreatType? threatType;
    double confidence = 0.0;

    if (soundResult.isScream &&
        soundResult.tipete > _screamConfidenceThreshold) {
      threatType = ThreatType.scream;
      confidence = soundResult.tipete;
    } else if (soundResult.isCrowd &&
        soundResult.aglomeratie > _crowdConfidenceThreshold) {
      threatType = ThreatType.crowdNoise;
      confidence = soundResult.aglomeratie;
    } else if (soundResult.isGlass &&
        soundResult.spargere > _glassConfidenceThreshold) {
      threatType = ThreatType.glassBreak;
      confidence = soundResult.spargere;
    }

    if (threatType == null) {
      return;
    }

    if (_lastPreAlarmTime != null) {
      if (DateTime.now().difference(_lastPreAlarmTime!) < _preAlarmDebounce) {
        return;
      }
    }

    final threatEvent = ThreatDetectionEvent(
      soundResult: soundResult,
      threatType: threatType,
      confidenceScore: confidence,
      detectedAt: DateTime.now(),
    );

    _lastPreAlarmTime = DateTime.now();

    _onThreatDetected?.call(threatEvent);

    await _triggerPreAlarm(threatEvent);
  }

  Future<void> _triggerPreAlarm(ThreatDetectionEvent threatEvent) async {
    _currentPreAlarm?.cancel();

    debugPrint(
      '🚨 [AUDIO THREAT] ${threatEvent.threatType} detected at ${threatEvent.confidenceScore.toStringAsFixed(2)}% confidence',
    );

    await _triggerHapticFeedback();

    _currentPreAlarm = SoundDetectionPreAlarm(
      threatEvent: threatEvent,
      timeout: _preAlarmTimeout,
      onConfirm: () {
        _onPreAlarmConfirmed?.call(threatEvent);
        _currentPreAlarm = null;
      },
      onCancel: () {
        _onPreAlarmCancelled?.call(threatEvent, 'User dismissed');
        _currentPreAlarm = null;
      },
    );

    _currentPreAlarm!.start();
  }

  Future<void> _triggerHapticFeedback() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        debugPrint('⚠️ Device does not support vibration');
        return;
      }

      final hasCustomSupport = await Vibration.hasCustomVibrationsSupport();

      if (hasCustomSupport == true) {
        for (int i = 0; i < 20; i++) {
          Vibration.vibrate(duration: 100);
          await Future.delayed(const Duration(milliseconds: 150));
        }
      } else {
        Vibration.vibrate(duration: _hapticDurationMs);
      }
    } catch (e) {
      debugPrint('⚠️ Haptic feedback error: $e');
    }
  }

  void handleFalseAlarm(String reason) {
    if (_currentPreAlarm == null) return;

    debugPrint('✓ [AUDIO] User dismissed threat as false alarm: $reason');
    _currentPreAlarm!.cancel();
    _onPreAlarmCancelled?.call(_currentPreAlarm!.threatEvent, reason);
    _currentPreAlarm = null;
  }

  void handleHelpNow() {
    if (_currentPreAlarm == null) return;

    debugPrint('🚨 [AUDIO] User requested immediate help');
    _currentPreAlarm!.executeNow();
    _currentPreAlarm = null;
  }

  SoundDetectionPreAlarm? get currentPreAlarm => _currentPreAlarm;

  bool get hasActivePreAlarm => _currentPreAlarm != null;

  void cancelActivePreAlarm() {
    _currentPreAlarm?.cancel();
    _currentPreAlarm = null;
  }
}
