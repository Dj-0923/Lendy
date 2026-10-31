import 'package:timezone/timezone.dart' as tz;

const String localReturnReminderPayloadPrefix = 'lendy_return_due:';

class LocalReturnReminder {
  const LocalReturnReminder({
    required this.id,
    required this.loanId,
    required this.title,
    required this.body,
    required this.payload,
    required this.scheduledDate,
  });

  final int id;
  final String loanId;
  final String title;
  final String body;
  final String payload;
  final tz.TZDateTime scheduledDate;
}

LocalReturnReminder? localReturnReminderForLoan({
  required String loanId,
  required String itemName,
  required String status,
  required String dueDate,
  required tz.TZDateTime now,
}) {
  if (status != 'approved' ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dueDate)) {
    return null;
  }

  final year = int.parse(dueDate.substring(0, 4));
  final month = int.parse(dueDate.substring(5, 7));
  final day = int.parse(dueDate.substring(8, 10));
  final scheduledDate = tz.TZDateTime(tz.local, year, month, day, 9);
  if (scheduledDate.year != year ||
      scheduledDate.month != month ||
      scheduledDate.day != day ||
      !scheduledDate.isAfter(now)) {
    return null;
  }

  return LocalReturnReminder(
    id: _stableNotificationId(loanId),
    loanId: loanId,
    title: 'Return due today',
    body: '$itemName is due today. Please return it on time.',
    payload: '$localReturnReminderPayloadPrefix$loanId:$dueDate',
    scheduledDate: scheduledDate,
  );
}

int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
