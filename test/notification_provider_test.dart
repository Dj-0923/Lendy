import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/notification_provider.dart';

void main() {
  test('notification and push preferences start enabled', () {
    final notifications = NotificationProvider();
    addTearDown(notifications.dispose);

    expect(notifications.requestUpdatesEnabled, isTrue);
    expect(notifications.returnRemindersEnabled, isTrue);
    expect(notifications.pushNotificationsEnabled, isTrue);
  });

  test('in-app notifications can be marked read', () async {
    final notifications = NotificationProvider();
    addTearDown(notifications.dispose);

    notifications.addNotification('Request approved');
    expect(notifications.unreadCount, 1);

    await notifications.markAllRead();
    expect(notifications.unreadCount, 0);
    expect(notifications.notifications.single.isRead, isTrue);
  });
}
