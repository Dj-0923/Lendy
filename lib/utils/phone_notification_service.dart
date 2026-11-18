import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PhoneNotificationService {
  PhoneNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'lendy_alerts';
  static const String channelName = 'Lendy alerts';
  static const String channelDescription =
      'Chat, borrowing requests, and deadline reminders';
  static const AndroidNotificationChannel androidChannel =
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      );
  static const NotificationDetails notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize({required bool isWeb}) async {
    if (isWeb) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final pendingNotifications = await _plugin.pendingNotificationRequests();
    for (final notification in pendingNotifications) {
      if (notification.payload?.startsWith('lendy_return_due:') ?? false) {
        await _plugin.cancel(id: notification.id);
      }
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}
