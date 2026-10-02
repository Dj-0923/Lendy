// lib/utils/date_utils.dart

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _monthFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Formats a date as "Aug 19" (no external intl package required).
String formatShortDate(DateTime date) {
  return '${_monthAbbr[date.month - 1]} ${date.day}';
}

/// Formats a date range as "Aug 19 - Aug 23".
String formatDateRange(DateTime start, DateTime end) {
  return '${formatShortDate(start)} - ${formatShortDate(end)}';
}

/// Formats a date as "May 20, 2024".
String formatFullDate(DateTime date) {
  return '${_monthFull[date.month - 1]} ${date.day}, ${date.year}';
}

/// Formats a timestamp as a relative "time ago" string, e.g. "Just now",
/// "2 hours ago", "3 days ago". Falls back to a full date for older items.
String formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  return formatFullDate(dateTime);
}