import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_service.dart';
import 'alert_manager.dart';
import 'user_profile_storage.dart';

class SafetyTimerService {
  SafetyTimerService._internal();
  static final SafetyTimerService instance = SafetyTimerService._internal();

  static const String _keyTimerActive = 'safety_timer_active';
  static const String _keyTimerEndTime = 'safety_timer_end_time';
  static const String _keyCheckInNotified = 'safety_timer_check_in_notified';
  static const String _keyTimerTotalMinutes = 'safety_timer_total_minutes';

  static const Duration _checkInWarningDuration = Duration(minutes: 5);
  static const Duration _timerRefresh = Duration(seconds: 1);
  static const Duration _sosDelay = Duration(seconds: 3);

  Timer? _timerTick;
  bool _isActive = false;
  DateTime? _timerEndTime;
  DateTime? _lastCheckInNotificationTime;
  int? _timerTotalMinutes;

  final ValueNotifier<SafetyTimerState?> _stateNotifier =
      ValueNotifier<SafetyTimerState?>(null);
  Function(SafetyTimerEvent)? _onTimerEvent;
  Function()? _onSosTriggered;

  ValueListenable<SafetyTimerState?> get timerState => _stateNotifier;

  Future<void> initialize({
    required Function(SafetyTimerEvent) onTimerEvent,
    Function()? onSosTriggered,
  }) async {
    _onTimerEvent = onTimerEvent;
    _onSosTriggered = onSosTriggered;

    final prefs = await SharedPreferences.getInstance();

    final isActive =
        UserProfileStorage.getBool(
          prefs,
          _keyTimerActive,
          legacyKeys: const [_keyTimerActive],
        ) ??
        false;
    final endTimeMs = UserProfileStorage.getInt(
      prefs,
      _keyTimerEndTime,
      legacyKeys: const [_keyTimerEndTime],
    );
    final checkInNotifiedMs = UserProfileStorage.getInt(
      prefs,
      _keyCheckInNotified,
      legacyKeys: const [_keyCheckInNotified],
    );
    _timerTotalMinutes = UserProfileStorage.getInt(
      prefs,
      _keyTimerTotalMinutes,
      legacyKeys: const [_keyTimerTotalMinutes],
    );

    if (isActive && endTimeMs != null) {
      _timerEndTime = DateTime.fromMillisecondsSinceEpoch(endTimeMs);
      _lastCheckInNotificationTime = checkInNotifiedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(checkInNotifiedMs)
          : null;
      _isActive = true;

      if (DateTime.now().isAfter(_timerEndTime!)) {
        await _triggerSos();
      } else {
        _startTimerTick();
        _notifyStateChange();
      }
    }
  }

  Future<void> startTimer(Duration duration) async {
    if (_isActive) {
      await stopTimer();
    }

    _timerEndTime = DateTime.now().add(duration);
    _lastCheckInNotificationTime = null;
    _isActive = true;
    _timerTotalMinutes = duration.inMinutes;

    final prefs = await SharedPreferences.getInstance();
    await UserProfileStorage.setBool(prefs, _keyTimerActive, true);
    await UserProfileStorage.setInt(
      prefs,
      _keyTimerEndTime,
      _timerEndTime!.millisecondsSinceEpoch,
    );
    await UserProfileStorage.remove(prefs, _keyCheckInNotified);
    await UserProfileStorage.setInt(
      prefs,
      _keyTimerTotalMinutes,
      _timerTotalMinutes!,
    );

    debugPrint(
      '🛡️ Safety Timer started: $_timerEndTime (duration: ${duration.inMinutes}m)',
    );
    _onTimerEvent?.call(SafetyTimerEvent.timerStarted);

    _startTimerTick();
    _notifyStateChange();
  }

  Future<void> extendTimer(Duration additionalDuration) async {
    if (!_isActive || _timerEndTime == null) {
      return;
    }

    _timerEndTime = _timerEndTime!.add(additionalDuration);
    _lastCheckInNotificationTime = null;

    final remainingMinutes = _timerEndTime!
        .difference(DateTime.now())
        .inMinutes;
    _timerTotalMinutes =
        (_timerTotalMinutes ?? remainingMinutes) + additionalDuration.inMinutes;

    final prefs = await SharedPreferences.getInstance();
    await UserProfileStorage.setInt(
      prefs,
      _keyTimerEndTime,
      _timerEndTime!.millisecondsSinceEpoch,
    );
    await UserProfileStorage.remove(prefs, _keyCheckInNotified);
    await UserProfileStorage.setInt(
      prefs,
      _keyTimerTotalMinutes,
      _timerTotalMinutes ?? 0,
    );

    debugPrint('⏱️ Safety Timer extended to: $_timerEndTime');
    _onTimerEvent?.call(SafetyTimerEvent.timerExtended);

    _notifyStateChange();
  }

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
    await UserProfileStorage.setBool(prefs, _keyTimerActive, false);
    await UserProfileStorage.remove(prefs, _keyTimerEndTime);
    await UserProfileStorage.remove(prefs, _keyCheckInNotified);
    await UserProfileStorage.remove(prefs, _keyTimerTotalMinutes);

    debugPrint('✅ Safety Timer stopped');
    _onTimerEvent?.call(SafetyTimerEvent.timerStopped);

    _stateNotifier.value = null;
  }

  void _startTimerTick() {
    _timerTick?.cancel();
    _timerTick = Timer.periodic(_timerRefresh, (_) async {
      if (!_isActive || _timerEndTime == null) {
        _timerTick?.cancel();
        return;
      }

      final now = DateTime.now();
      final remaining = _timerEndTime!.difference(now);

      if (remaining.isNegative) {
        _timerTick?.cancel();
        await AlertManager.instance.cancelTimerWarning();
        await _triggerSos();
        return;
      }

      if (remaining <= _checkInWarningDuration) {
        if (_lastCheckInNotificationTime == null) {
          _lastCheckInNotificationTime = now;
          final prefs = await SharedPreferences.getInstance();
          await UserProfileStorage.setInt(
            prefs,
            _keyCheckInNotified,
            now.millisecondsSinceEpoch,
          );

          debugPrint('Safety Timer check-in notification triggered');
          _onTimerEvent?.call(SafetyTimerEvent.checkInNotification);

          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          final timerText =
              '$mins:${secs.toString().padLeft(2, '0')} remaining';
          await AlertManager.instance.showTimerWarningNotification(
            timerText: timerText,
          );
        } else {
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          final timerText =
              '$mins:${secs.toString().padLeft(2, '0')} remaining';
          await AlertManager.instance.updateTimerWarningNotification(
            timerText: timerText,
          );
        }
      }

      _notifyStateChange();
    });
  }

  Future<void> _triggerSos() async {
    debugPrint('🚨 Safety Timer EXPIRED - Triggering SOS!');

    _isActive = false;
    _timerEndTime = null;
    _lastCheckInNotificationTime = null;
    _timerTotalMinutes = null;

    final prefs = await SharedPreferences.getInstance();
    await UserProfileStorage.setBool(prefs, _keyTimerActive, false);
    await UserProfileStorage.remove(prefs, _keyTimerEndTime);
    await UserProfileStorage.remove(prefs, _keyCheckInNotified);
    await UserProfileStorage.remove(prefs, _keyTimerTotalMinutes);

    _onTimerEvent?.call(SafetyTimerEvent.sosTriggered);

    await Future.delayed(_sosDelay);

    _onSosTriggered?.call();
    await EmergencyService.instance.sendManualSos();

    _stateNotifier.value = null;
  }

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

  void _notifyStateChange() {
    final state = getCurrentState();
    _stateNotifier.value = state;
  }

  bool get isActive => _isActive;

  void dispose() {
    _timerTick?.cancel();
    _stateNotifier.dispose();
  }
}

enum SafetyTimerEvent {
  timerStarted,
  timerExtended,
  timerStopped,
  checkInNotification,
  sosTriggered,
}

class SafetyTimerState {
  final bool isActive;
  final int remainingSeconds;
  final DateTime endTime;
  final bool isCheckInWarning;
  final int totalMinutes;

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
