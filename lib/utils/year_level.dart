// lib/utils/year_level.dart

/// The year levels a student can pick from, in display order.
const List<String> yearLevelOptions = ['1', '2', '3', '4', '5'];

/// Shown when the typed year level is not one of [yearLevelOptions].
const String yearLevelRangeMessage =
    'Please input your year level (1, 2, 3, 4 or 5)';

String _ordinalSuffix(int year) {
  if (year % 100 >= 11 && year % 100 <= 13) return 'th';
  return switch (year % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}

/// "3" -> "3rd year". Returns null when [digit] is not a valid year level.
String? yearLevelToLabel(String? digit) {
  final year = int.tryParse(digit?.trim() ?? '');
  if (year == null || year < 1 || year > yearLevelOptions.length) return null;
  return '$year${_ordinalSuffix(year)} year';
}

/// "3rd year" -> "3", so a stored value can be shown in the digits-only field.
/// Returns null when there is no year digit to recover.
String? yearLevelToDigit(String? label) {
  if (label == null) return null;
  return RegExp('[1-${yearLevelOptions.length}]').firstMatch(label)?.group(0);
}

/// Validates the digits-only year level field.
String? validateYearLevel(String? value) {
  final digit = value?.trim() ?? '';
  if (digit.isEmpty) return 'Year level is required';
  if (yearLevelToLabel(digit) == null) return yearLevelRangeMessage;
  return null;
}
