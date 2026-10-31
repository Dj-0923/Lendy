import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/notification_provider.dart';
import 'package:lendy/utils/local_return_reminder.dart';

void main() {
  setUpAll(() {
    timezone_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));
  });

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

  test(
    'approved loans schedule one local reminder at 9 AM on the due date',
    () {
      final reminder = localReturnReminderForLoan(
        loanId: 'loan-1',
        itemName: 'Camera',
        status: 'approved',
        dueDate: '2026-11-02',
        now: tz.TZDateTime(tz.local, 2026, 11, 1, 12),
      );

      expect(reminder, isNotNull);
      expect(reminder!.scheduledDate, tz.TZDateTime(tz.local, 2026, 11, 2, 9));
      expect(reminder.title, 'Return due today');
      expect(reminder.body, 'Camera is due today. Please return it on time.');
      expect(reminder.payload, 'lendy_return_due:loan-1:2026-11-02');
      expect(
        reminder.id,
        localReturnReminderForLoan(
          loanId: 'loan-1',
          itemName: 'Camera',
          status: 'approved',
          dueDate: '2026-11-02',
          now: tz.TZDateTime(tz.local, 2026, 11, 1, 12),
        )!.id,
      );
    },
  );

  test('inactive, malformed, and already-due loans are not scheduled', () {
    final now = tz.TZDateTime(tz.local, 2026, 11, 2, 10);
    LocalReturnReminder? reminder(String status, String dueDate) =>
        localReturnReminderForLoan(
          loanId: 'loan-1',
          itemName: 'Camera',
          status: status,
          dueDate: dueDate,
          now: now,
        );

    expect(reminder('returned', '2026-11-03'), isNull);
    expect(reminder('approved', 'not-a-date'), isNull);
    expect(reminder('approved', '2026-11-02'), isNull);
    expect(reminder('approved', '2026-11-01'), isNull);
  });
}
