import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'audio_monitor_service.dart';

/// Represents a threat detection event with confidence scores
class ThreatDetectionEvent {
  final SoundAlertResult soundResult;
  final ThreatType threatType;
  final double confidenceScore; // 0.0 - 1.0
  final DateTime detectedAt;

  ThreatDetectionEvent({
    required this.soundResult,
    required this.threatType,
    required this.confidenceScore,
    required this.detectedAt,
  });

  @override
  String toString() => 'ThreatDetectionEvent(type=$threatType, confidence=$confidenceScore)';
}

/// Type of threat detected
enum ThreatType {
  scream, // tipete - high-pitched sounds indicating distress
  glassBreak, // spargere - glass breaking sound
  // note: crowdNoise excluded from auto-SOS triggers
}

/// Pre-alarm state for sound detection verification
/// Prevents false positives while giving user control
class SoundDetectionPreAlarm {
  final ThreatDetectionEvent threatEvent;
  final Duration timeout;
  final Function() onConfirm; // Execute SOS
  final Function() onCancel; // Log as false alarm
  late Timer _countdownTimer;

  SoundDetectionPreAlarm({
    required this.threatEvent,
    required this.timeout,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Start the pre-alarm countdown
  void start() {
    _countdownTimer = Timer(timeout, () {
      onConfirm();
    });
  }

  /// Cancel the countdown (user said "I'm OK" or "False Alarm")
  void cancel() {
    _countdownTimer.cancel();
  }

  /// Execute immediately (user said "Help Now" or "Send Alert")
  void executeNow() {
    _countdownTimer.cancel();
    onConfirm();
  }
}

/// Enhanced audio threat detection service with pre-alarm verification
class AudioThreatDetectionService {
  AudioThreatDetectionService._internal();
  static final AudioThreatDetectionService instance = AudioThreatDetectionService._internal();

  // Confidence thresholds for triggering pre-alarm (higher than normal detection)
  static const double _screamConfidenceThreshold = 0.10; // 80% confidence
  static const double _glassConfidenceThreshold = 0.15; // 85% confidence

  // Haptic feedback configuration
  static const int _hapticDurationMs = 3000; // 3 second vibration

  // Pre-alarm configuration
  static const Duration _preAlarmTimeout = Duration(seconds: 15);

  // State tracking
  SoundDetectionPreAlarm? _currentPreAlarm;
  DateTime? _lastPreAlarmTime;
  static const Duration _preAlarmDebounce = Duration(seconds: 30); // Prevent rapid re-triggers

  // Callbacks
  Function(ThreatDetectionEvent)? _onThreatDetected;
  Function(ThreatDetectionEvent)? _onPreAlarmConfirmed;
  Function(ThreatDetectionEvent, String reason)? _onPreAlarmCancelled;

  /// Initialize threat detection service
  void initialize({
    required Function(ThreatDetectionEvent) onThreatDetected,
    required Function(ThreatDetectionEvent) onPreAlarmConfirmed,
    Function(ThreatDetectionEvent, String reason)? onPreAlarmCancelled,
  }) {
    _onThreatDetected = onThreatDetected;
    _onPreAlarmConfirmed = onPreAlarmConfirmed;
    _onPreAlarmCancelled = onPreAlarmCancelled;
  }

  /// Process sound detection and trigger pre-alarm if confidence is high
  Future<void> processSoundDetection(SoundAlertResult soundResult) async {
    // Determine threat type and confidence
    ThreatType? threatType;
    double confidence = 0.0;

    // Check for scream (tipete) - screams/shouts/distress sounds
    if (soundResult.isScream && soundResult.tipete > _screamConfidenceThreshold) {
      threatType = ThreatType.scream;
      confidence = soundResult.tipete;
    }
    // Check for glass breaking (spargere)
    else if (soundResult.isGlass && soundResult.spargere > _glassConfidenceThreshold) {
      threatType = ThreatType.glassBreak;
      confidence = soundResult.spargere;
    }
    // Note: crowdNoise (aglomeratie) is NOT treated as threat trigger
    // as it's too common in urban environments

    if (threatType == null) {
      return; // No high-confidence threat detected
    }

    // Check debounce to avoid rapid successive alarms
    if (_lastPreAlarmTime != null) {
      if (DateTime.now().difference(_lastPreAlarmTime!) < _preAlarmDebounce) {
        return;
      }
    }

    // Create threat event
    final threatEvent = ThreatDetectionEvent(
      soundResult: soundResult,
      threatType: threatType,
      confidenceScore: confidence,
      detectedAt: DateTime.now(),
    );

    _lastPreAlarmTime = DateTime.now();

    // Notify listeners
    _onThreatDetected?.call(threatEvent);

    // Trigger pre-alarm sequence
    await _triggerPreAlarm(threatEvent);
  }

  /// Trigger the pre-alarm verification sequence
  Future<void> _triggerPreAlarm(ThreatDetectionEvent threatEvent) async {
    // Cancel any existing pre-alarm
    _currentPreAlarm?.cancel();

    debugPrint('🚨 [AUDIO THREAT] ${threatEvent.threatType} detected at ${threatEvent.confidenceScore.toStringAsFixed(2)}% confidence');

    // Step 1: Aggressive haptic feedback for 3 seconds
    await _triggerHapticFeedback();

    // Step 2: Create pre-alarm state with callbacks
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

    // Step 3: Start countdown (UI will show popup with 15s timer)
    _currentPreAlarm!.start();
  }

  /// Trigger aggressive haptic feedback (3 seconds)
  Future<void> _triggerHapticFeedback() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        debugPrint('⚠️ Device does not support vibration');
        return;
      }

      // Pattern: strong vibration for 3 seconds
      // We'll use a series of vibrations to create a continuous strong feedback
      final hasCustomSupport = await Vibration.hasCustomVibrationsSupport();

      if (hasCustomSupport == true) {
        // Use custom pattern: alternating strong/medium pulses for 3 seconds
        // Heavy vibration: 100ms on, 50ms off, repeated
        for (int i = 0; i < 20; i++) {
          Vibration.vibrate(duration: 100);
          await Future.delayed(const Duration(milliseconds: 150));
        }
      } else {
        // Fallback: simple long vibration
        Vibration.vibrate(duration: _hapticDurationMs);
      }
    } catch (e) {
      debugPrint('⚠️ Haptic feedback error: $e');
    }
  }

  /// User tapped "False Alarm" - cancel pre-alarm and log for retraining
  void handleFalseAlarm(String reason) {
    if (_currentPreAlarm == null) return;

    debugPrint('✓ [AUDIO] User dismissed threat as false alarm: $reason');
    _currentPreAlarm!.cancel();
    _onPreAlarmCancelled?.call(
      _currentPreAlarm!.threatEvent,
      reason,
    );
    _currentPreAlarm = null;
  }

  /// User tapped "Help Now" - execute SOS immediately
  void handleHelpNow() {
    if (_currentPreAlarm == null) return;

    debugPrint('🚨 [AUDIO] User requested immediate help');
    _currentPreAlarm!.executeNow();
    _currentPreAlarm = null;
  }

  /// Get current pre-alarm state (for UI)
  SoundDetectionPreAlarm? get currentPreAlarm => _currentPreAlarm;

  /// Check if there's an active pre-alarm
  bool get hasActivePreAlarm => _currentPreAlarm != null;

  /// Cancel any active pre-alarm (e.g., app shutdown)
  void cancelActivePreAlarm() {
    _currentPreAlarm?.cancel();
    _currentPreAlarm = null;
  }
}
