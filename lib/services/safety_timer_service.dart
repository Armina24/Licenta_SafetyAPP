import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_service.dart';
import 'alert_manager.dart';

/// Safety Timer (Dead Man's Switch) service
/// User sets a timer and if they don't check in or disable it by the time it expires,
/// an automatic SOS is triggered. Useful for solo travel, night runs, etc.
class SafetyTimerService {
  SafetyTimerService._internal();
  static final SafetyTimerService instance = SafetyTimerService._internal();

  // SharedPreferences keys
  static const String _keyTimerActive = 'safety_timer_active';
  static const String _keyTimerEndTime = 'safety_timer_end_time'; // Unix milliseconds
  static const String _keyCheckInNotified = 'safety_timer_check_in_notified'; // Unix milliseconds
  static const String _keyTimerTotalMinutes = 'safety_timer_total_minutes';

  // Configuration
  static const Duration _checkInWarningDuration = Duration(minutes: 5); // Notify 5 min before
  static const Duration _timerRefresh = Duration(seconds: 1); // Check every 1 second
  static const Duration _sosDelay = Duration(seconds: 3); // Delay before sending SOS (allow cancel)

  // State
  Timer? _timerTick;
  bool _isActive = false;
  DateTime? _timerEndTime;
  DateTime? _lastCheckInNotificationTime;
  int? _timerTotalMinutes;

  // Callbacks
  final ValueNotifier<SafetyTimerState?> _stateNotifier = ValueNotifier<SafetyTimerState?>(null);
  Function(SafetyTimerEvent)? _onTimerEvent;
  Function()? _onSosTriggered;

  ValueListenable<SafetyTimerState?> get timerState => _stateNotifier;

  /// Initialize the service and restore any saved timer state
  Future<void> initialize({
    required Function(SafetyTimerEvent) onTimerEvent,
    Function()? onSosTriggered,
  }) async {
    _onTimerEvent = onTimerEvent;
    _onSosTriggered = onSosTriggered;

    // Restore state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_keyTimerActive) ?? false;
    final endTimeMs = prefs.getInt(_keyTimerEndTime);
    final checkInNotifiedMs = prefs.getInt(_keyCheckInNotified);
    _timerTotalMinutes = prefs.getInt(_keyTimerTotalMinutes);

    if (isActive && endTimeMs != null) {
      _timerEndTime = DateTime.fromMillisecondsSinceEpoch(endTimeMs);
      _lastCheckInNotificationTime = checkInNotifiedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(checkInNotifiedMs)
          : null;
      _isActive = true;

      // Check if timer already expired
      if (DateTime.now().isAfter(_timerEndTime!)) {
        await _triggerSos();
      } else {
        // Start monitoring the existing timer
        _startTimerTick();
        _notifyStateChange();
      }
    }
  }

  /// Start a new safety timer
  /// Duration can be 15, 30, 60+ minutes
  Future<void> startTimer(Duration duration) async {
    if (_isActive) {
      await stopTimer();
    }

    _timerEndTime = DateTime.now().add(duration);
    _lastCheckInNotificationTime = null;
    _isActive = true;
    _timerTotalMinutes = duration.inMinutes;

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTimerActive, true);
    await prefs.setInt(_keyTimerEndTime, _timerEndTime!.millisecondsSinceEpoch);
    await prefs.remove(_keyCheckInNotified); // Reset check-in notification
    await prefs.setInt(_keyTimerTotalMinutes, _timerTotalMinutes!);

    debugPrint('🛡️ Safety Timer started: $_timerEndTime (duration: ${duration.inMinutes}m)');
    _onTimerEvent?.call(SafetyTimerEvent.timerStarted);

    _startTimerTick();
    _notifyStateChange();
  }

  /// Extend the current timer by additional time
  Future<void> extendTimer(Duration additionalDuration) async {
    if (!_isActive || _timerEndTime == null) {
      return;
    }

    _timerEndTime = _timerEndTime!.add(additionalDuration);
    _lastCheckInNotificationTime = null; // Reset check-in notification

    final remainingMinutes = _timerEndTime!.difference(DateTime.now()).inMinutes;
    _timerTotalMinutes = (_timerTotalMinutes ?? remainingMinutes) + additionalDuration.inMinutes;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTimerEndTime, _timerEndTime!.millisecondsSinceEpoch);
    await prefs.remove(_keyCheckInNotified);
    await prefs.setInt(_keyTimerTotalMinutes, _timerTotalMinutes ?? 0);

    debugPrint('⏱️ Safety Timer extended to: $_timerEndTime');
    _onTimerEvent?.call(SafetyTimerEvent.timerExtended);

    _notifyStateChange();
  }

  /// Stop/cancel the timer (user is safe)
  Future<void> stopTimer() async {
    if (!_isActive) {
      return;
    }

    _isActive = false;
    _timerEndTime = null;
    _lastCheckInNotificationTime = null;
    _timerTick?.cancel();
    _timerTotalMinutes = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTimerActive, false);
    await prefs.remove(_keyTimerEndTime);
    await prefs.remove(_keyCheckInNotified);
    await prefs.remove(_keyTimerTotalMinutes);

    debugPrint('✅ Safety Timer stopped');
    _onTimerEvent?.call(SafetyTimerEvent.timerStopped);

    _stateNotifier.value = null;
  }

  /// Internal: Start the timer tick (runs every second)
  void _startTimerTick() {
    _timerTick?.cancel();
    _timerTick = Timer.periodic(_timerRefresh, (_) async {
      if (!_isActive || _timerEndTime == null) {
        _timerTick?.cancel();
        return;
      }

      final now = DateTime.now();
      final remaining = _timerEndTime!.difference(now);

      // Check if timer expired
      if (remaining.isNegative) {
        _timerTick?.cancel();
        await AlertManager.instance.cancelTimerWarning();
        await _triggerSos();
        return;
      }

      // Check if 5 minutes remaining and not yet notified
      if (remaining <= _checkInWarningDuration) {
        if (_lastCheckInNotificationTime == null) {
          _lastCheckInNotificationTime = now;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_keyCheckInNotified, now.millisecondsSinceEpoch);

          debugPrint('⚠️ Safety Timer check-in notification triggered');
          _onTimerEvent?.call(SafetyTimerEvent.checkInNotification);
          
          // Show background notification with action buttons
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          final timerText = '$mins:${secs.toString().padLeft(2, '0')} remaining';
          await AlertManager.instance.showTimerWarningNotification(
            timerText: timerText,
          );
        } else {
          // Update notification every second while in the 5-minute window
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          final timerText = '$mins:${secs.toString().padLeft(2, '0')} remaining';
          await AlertManager.instance.updateTimerWarningNotification(
            timerText: timerText,
          );
        }
      }

      // Update state every second
      _notifyStateChange();
    });
  }

  /// Internal: Trigger SOS when timer expires
  Future<void> _triggerSos() async {
    debugPrint('🚨 Safety Timer EXPIRED - Triggering SOS!');

    _isActive = false;
    _timerEndTime = null;
    _lastCheckInNotificationTime = null;
    _timerTotalMinutes = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTimerActive, false);
    await prefs.remove(_keyTimerEndTime);
    await prefs.remove(_keyCheckInNotified);
    await prefs.remove(_keyTimerTotalMinutes);

    _onTimerEvent?.call(SafetyTimerEvent.sosTriggered);

    // Give user a small delay to cancel if UI is shown
    await Future.delayed(_sosDelay);

    // Execute SOS via emergency service
    _onSosTriggered?.call();
    await EmergencyService.instance.sendManualSos();

    _stateNotifier.value = null;
  }

  /// Get current timer state
  SafetyTimerState? getCurrentState() {
    if (!_isActive || _timerEndTime == null) {
      return null;
    }

    final remaining = _timerEndTime!.difference(DateTime.now());

    if (remaining.isNegative) {
      return SafetyTimerState(
        isActive: false,
        remainingSeconds: 0,
        endTime: _timerEndTime!,
        isCheckInWarning: false,
        totalMinutes: _timerTotalMinutes ?? 0,
      );
    }

    return SafetyTimerState(
      isActive: true,
      remainingSeconds: remaining.inSeconds,
      endTime: _timerEndTime!,
      isCheckInWarning: remaining <= _checkInWarningDuration,
      totalMinutes: _timerTotalMinutes ?? remaining.inMinutes,
    );
  }

  /// Notify listeners of state change
  void _notifyStateChange() {
    final state = getCurrentState();
    _stateNotifier.value = state;
  }

  /// Check if timer is currently active
  bool get isActive => _isActive;

  /// Cleanup on app shutdown
  void dispose() {
    _timerTick?.cancel();
    _stateNotifier.dispose();
  }
}

/// Events triggered by the Safety Timer
enum SafetyTimerEvent {
  timerStarted, // Timer was started
  timerExtended, // Timer was extended
  timerStopped, // Timer was stopped by user
  checkInNotification, // 5 minutes remaining - ask if OK
  sosTriggered, // Timer expired - SOS being sent
}

/// Current state of the safety timer
class SafetyTimerState {
  final bool isActive;
  final int remainingSeconds; // Time left on timer
  final DateTime endTime; // When timer will expire
  final bool isCheckInWarning; // True when 5 minutes or less remaining
  final int totalMinutes; // Total duration when timer started/extended

  SafetyTimerState({
    required this.isActive,
    required this.remainingSeconds,
    required this.endTime,
    required this.isCheckInWarning,
    required this.totalMinutes,
  });

  String get remainingTimeFormatted {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  String toString() =>
      'SafetyTimerState(active=$isActive, remaining=$remainingTimeFormatted, warning=$isCheckInWarning)';
}
