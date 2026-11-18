import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/notification_provider.dart';
import 'package:lendy/utils/phone_notification_service.dart';

class _RecordingPhoneNotifications extends PhoneNotificationService {
  final List<({int id, String title, String body, String? payload})> shown = [];

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }
}

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

    notifications.setActivePage('notifications');
    expect(
      notifications.shouldSuppressForegroundNotification('admin_chat_reply'),
      isFalse,
    );
    expect(
      notifications.shouldSuppressForegroundNotification('approved'),
      isTrue,
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

    expect(notifications.unreadAdminChatCount, 1);
    expect(notifications.unseenLoanUpdateCount, 1);
    expect(notifications.unreadCount, 2);
  });

  test(
    'foreground FCM alerts use phone notifications outside matching chat',
    () async {
      final incomingMessages = StreamController<RemoteMessage>.broadcast(
        sync: true,
      );
      final phoneNotifications = _RecordingPhoneNotifications();
      final notifications = NotificationProvider(
        phoneNotifications: phoneNotifications,
        foregroundMessages: incomingMessages.stream,
      );
      addTearDown(notifications.dispose);
      addTearDown(incomingMessages.close);

      notifications.setActivePage('home');
      incomingMessages.add(
        RemoteMessage(
          messageId: 'approval-1',
          notification: const RemoteNotification(
            title: 'Request approved',
            body: 'Your item request was approved.',
          ),
          data: const {'type': 'approved', 'notificationId': 'approval-1'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(phoneNotifications.shown, hasLength(1));
      expect(phoneNotifications.shown.single.title, 'Request approved');
      expect(
        phoneNotifications.shown.single.body,
        'Your item request was approved.',
      );

      notifications.setActivePage('messages');
      incomingMessages.add(
        RemoteMessage(
          messageId: 'admin-chat-1',
          notification: const RemoteNotification(
            title: 'New admin reply',
            body: 'An admin replied.',
          ),
          data: const {
            'type': 'admin_chat_reply',
            'notificationId': 'admin-chat-1',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(phoneNotifications.shown, hasLength(1));
    },
  );

  test(
    'notification page excludes chat replies and keeps them unread',
    () async {
      final notifications = NotificationProvider();
      addTearDown(notifications.dispose);

      notifications.addNotification(
        'Admin replied to your chat.',
        type: 'admin_chat_reply',
      );
      notifications.addNotification(
        'Fabii replied to your chat.',
        type: 'assistant_reply',
      );
      notifications.addNotification(
        'Your request was approved.',
        type: 'approved',
      );
      notifications.addNotification(
        'Your item is due tomorrow.',
        type: 'due_reminder',
      );

      expect(
        notifications.notificationPageNotifications.map((item) => item.type),
        containsAll(['approved', 'due_reminder']),
      );
      expect(notifications.notificationPageNotifications, hasLength(2));

      await notifications.markNotificationPageSeen();
      expect(notifications.unseenLoanUpdateCount, 0);
      expect(
        notifications.notificationPageNotifications.every(
          (notification) => notification.isSeen && !notification.isRead,
        ),
        isTrue,
      );
      expect(notifications.unreadCount, 4);

      await notifications.markNotificationPageRead();
      expect(notifications.unreadAdminChatCount, 1);
      expect(notifications.unseenLoanUpdateCount, 0);
      expect(notifications.unreadCount, 2);
    },
  );

  test('opening each chat clears only that chat reply badge count', () async {
    final notifications = NotificationProvider();
    addTearDown(notifications.dispose);

    notifications.addNotification(
      'Admin replied to your chat.',
      type: 'admin_chat_reply',
    );
    notifications.addNotification(
      'Fabii replied to your chat.',
      type: 'assistant_reply',
    );
    notifications.addNotification(
      'Your request was approved.',
      type: 'approved',
    );

    await notifications.markAssistantNotificationsRead();

    expect(notifications.unreadAdminChatCount, 1);
    expect(notifications.unseenLoanUpdateCount, 1);

    await notifications.markAdminChatNotificationsRead();
    expect(notifications.unreadAdminChatCount, 0);
    expect(notifications.unseenLoanUpdateCount, 1);
  });
}
