import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  static const String offlineAlertPayload = 'offline_alert';

  static const int _offlineNotificationId = 1001;
  static const String _offlineChannelId = 'offline_alerts_channel';
  static const String _offlineChannelName = 'Alerte offline';
  static const String _offlineChannelDescription =
      'Notificări trimise când pierzi conexiunea la internet.';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize({
    required Future<void> Function(String? payload) onSelectNotification,
  }) async {
    const androidInitialization = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final initializationSettings = const InitializationSettings(
      android: androidInitialization,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onSelectNotification(response.payload);
      },
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _offlineChannelId,
          _offlineChannelName,
          description: _offlineChannelDescription,
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> showOfflineAlertNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _offlineChannelId,
      _offlineChannelName,
      channelDescription: _offlineChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );

    await _notificationsPlugin.show(
      _offlineNotificationId,
      'Fără internet',
      'Ai rămas fără internet. Apasă pentru a trimite SMS de urgență cu ultima locație.',
      const NotificationDetails(android: androidDetails),
      payload: offlineAlertPayload,
    );
  }
}
