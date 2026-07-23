import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(
      android: android,
    );

    await notifications.initialize(settings);
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'eye_break_channel',
      'Eye Break Reminder',
      channelDescription: 'Eye break notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    await notifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: android),
    );
  }
}