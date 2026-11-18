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

  test('foreground alerts are suppressed only on their matching page', () {
    final notifications = NotificationProvider();
    addTearDown(notifications.dispose);

    notifications.setActivePage('messages');
    expect(
      notifications.shouldSuppressForegroundNotification('admin_chat_reply'),
      isTrue,
    );
    expect(
      notifications.shouldSuppressForegroundNotification('approved'),
      isFalse,
    );

    notifications.setActivePage('loans');
    expect(
      notifications.shouldSuppressForegroundNotification('approved'),
      isTrue,
    );
    expect(
      notifications.shouldSuppressForegroundNotification('admin_chat_reply'),
      isFalse,
    );

    final assistantPage = notifications.beginActivePage('fabii_chat');
    expect(
      notifications.shouldSuppressForegroundNotification('assistant_reply'),
      isTrue,
    );
    notifications.endActivePage(assistantPage);
    expect(
      notifications.shouldSuppressForegroundNotification('assistant_reply'),
      isFalse,
    );

    notifications.setActivePage('account_request_status');
    expect(
      notifications.shouldSuppressForegroundNotification('account_approved'),
      isTrue,
    );
  });

  test('unread chat and loan notifications have separate badge counts', () {
    final notifications = NotificationProvider();
    addTearDown(notifications.dispose);

    notifications.addNotification(
      'Admin replied to your chat.',
      type: 'admin_chat_reply',
    );
    notifications.addNotification(
      'Your request was approved.',
      type: 'approved',
    );

    expect(notifications.unreadChatCount, 1);
    expect(notifications.unreadLoanUpdateCount, 1);
    expect(notifications.unreadCount, 2);
  });
}
