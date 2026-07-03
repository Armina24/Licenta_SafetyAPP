import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

class AlertManager {
  AlertManager._internal();
  static final AlertManager instance = AlertManager._internal();

  static const int _preAlarmNotificationId = 42000;
  static const int _timerWarningNotificationId = 42001;
  static const String _preAlarmChannelId = 'pre_alarm_channel';
  static const String _preAlarmChannelName = 'Safety Pre-Alarms';
  static const String _preAlarmChannelDescription =
      'Heads-up alerts with countdown before sending SOS.';

  static const String _timerChannelId = 'safety_timer_channel';
  static const String _timerChannelName = 'Safety Timer';
  static const String _timerChannelDescription =
      'Safety Timer warnings with quick actions.';

  static const String _actionCancelId = 'action_pre_alarm_cancel';
  static const String _actionTimerStopId = 'action_timer_stop';
  static const String _actionTimerAdd5Id = 'action_timer_add5';
  static const String _actionTimerAdd15Id = 'action_timer_add15';
  static const String _actionTimerAdd30Id = 'action_timer_add30';
  static const String _payloadPreAlarm = 'payload_pre_alarm';
  static const String _payloadTimerWarning = 'payload_timer_warning';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _preAlarmActive = false;
  String? _currentSource;

  Future<void> Function()? _onSendSos;
  VoidCallback? _onCancelled;
  Function(String actionId)? _onTimerAction;

  Future<void> initialize({
    required Future<void> Function() onSendSos,
    VoidCallback? onCancelled,
    Function(String actionId)? onTimerAction,
  }) async {
    _onSendSos = onSendSos;
    _onCancelled = onCancelled;
    _onTimerAction = onTimerAction;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          AlertManager._handleBackgroundNotificationResponse,
    );

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _preAlarmChannelId,
          _preAlarmChannelName,
          description: _preAlarmChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _timerChannelId,
          _timerChannelName,
          description: _timerChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  Future<void> triggerPreAlarm({
    required String source,
    Duration countdown = const Duration(seconds: 15),
  }) async {
    if (_preAlarmActive) {
      debugPrint(
        '[AlertManager] Pre-alarm already active, ignoring new trigger: $source',
      );
      return;
    }

    _preAlarmActive = true;
    _remaining = countdown;
    _currentSource = source;

    await _showOrUpdatePreAlarmNotification();
    _startCountdown();
    _vibratePattern();
  }

  Future<void> cancelPreAlarm({String? reason}) async {
    _preAlarmActive = false;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _remaining = Duration.zero;
    _currentSource = null;

    await _notifications.cancel(_preAlarmNotificationId);
    try {
      await Vibration.cancel();
    } catch (_) {}

    _onCancelled?.call();
    if (reason != null) {
      debugPrint('[AlertManager] Pre-alarm cancelled ($reason)');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _remaining = _remaining - const Duration(seconds: 1);

      if (_remaining <= Duration.zero) {
        timer.cancel();
        _countdownTimer = null;
        await _fireSos();
        return;
      }

      await _showOrUpdatePreAlarmNotification();
    });
  }

  Future<void> _fireSos() async {
    if (!_preAlarmActive) {
      debugPrint('[AlertManager] SOS fire cancelled - alarm was deactivated');
      return;
    }

    _preAlarmActive = false;
    await _notifications.cancel(_preAlarmNotificationId);
    try {
      await Vibration.cancel();
    } catch (_) {}

    debugPrint('[AlertManager] Firing SOS after countdown expired');
    if (_onSendSos != null) {
      await _onSendSos!.call();
    }
  }

  Future<void> _showOrUpdatePreAlarmNotification() async {
    final remainingSeconds = _remaining.inSeconds.clamp(0, 9999);
    final body =
        'Detected: ${_currentSource ?? 'Unknown'} • Sending SOS in ${remainingSeconds}s';

    final androidDetails = AndroidNotificationDetails(
      _preAlarmChannelId,
      _preAlarmChannelName,
      channelDescription: _preAlarmChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.alarm,
      ticker: 'Safety alert',
      visibility: NotificationVisibility.public,
      enableVibration: true,
      onlyAlertOnce: true,
      autoCancel: false,

      vibrationPattern: Int64List.fromList([
        0,
        500,
        300,
        500,
        300,
        500,
        300,
        500,
      ]),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _actionCancelId,
          "I'M OK",
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _preAlarmNotificationId,
      'Safety Alert',
      body,
      details,
      payload: _payloadPreAlarm,
    );
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    await _processResponse(response);
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    await AlertManager.instance._processResponse(response);
  }

  Future<void> _processResponse(NotificationResponse response) async {
    if (response.payload == _payloadTimerWarning) {
      if (response.actionId == _actionTimerStopId ||
          response.actionId == _actionTimerAdd5Id ||
          response.actionId == _actionTimerAdd15Id ||
          response.actionId == _actionTimerAdd30Id) {
        _onTimerAction?.call(response.actionId ?? '');
      }
      return;
    }

    if (!_preAlarmActive) return;

    if (response.actionId == _actionCancelId) {
      await cancelPreAlarm(reason: 'user tapped action');
      return;
    }

    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      await cancelPreAlarm(reason: 'user tapped notification');
    }
  }

  Future<void> _vibratePattern() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == false) return;

      await Vibration.vibrate(
        pattern: const [0, 500, 300, 500, 300, 500, 300, 500],
      );
    } catch (_) {}
  }

  Future<void> showTimerWarningNotification({required String timerText}) async {
    final androidDetails = AndroidNotificationDetails(
      _timerChannelId,
      _timerChannelName,
      channelDescription: _timerChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ticker: 'Safety Timer Warning',
      visibility: NotificationVisibility.public,
      enableVibration: true,
      onlyAlertOnce: false,
      autoCancel: false,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _actionTimerStopId,
          'Stop',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          _actionTimerAdd5Id,
          '+5 min',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          _actionTimerAdd15Id,
          '+15 min',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          _actionTimerAdd30Id,
          '+30 min',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _timerWarningNotificationId,
      'Safety Timer Warning',
      timerText,
      details,
      payload: _payloadTimerWarning,
    );

    try {
      await Vibration.vibrate(pattern: const [0, 300, 200, 300]);
    } catch (_) {}
  }

  Future<void> cancelTimerWarning() async {
    await _notifications.cancel(_timerWarningNotificationId);
  }

  Future<void> updateTimerWarningNotification({
    required String timerText,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _timerChannelId,
      _timerChannelName,
      channelDescription: _timerChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ticker: 'Safety Timer Warning',
      visibility: NotificationVisibility.public,
      enableVibration: false,
      onlyAlertOnce: true,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _actionTimerStopId,
          'Stop',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          _actionTimerAdd5Id,
          '+5 min',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          _actionTimerAdd15Id,
          '+15 min',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          _actionTimerAdd30Id,
          '+30 min',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _timerWarningNotificationId,
      'Safety Timer Warning',
      timerText,
      details,
      payload: _payloadTimerWarning,
    );
  }
}
