// lib/utils/college_programs.dart
import 'text_formatters.dart';

/// One degree programme offered by the school.
class CollegeProgram {
  /// The shortcut saved to the user record.
  /// For programmes the school has no official acronym for, this is the same
  /// text as [full].
  final String short;

  /// The full title, shown in the open dropdown where there is room for it.
  final String full;

  const CollegeProgram(this.short, this.full);

  /// The dropdown row, for example "BS Information Technology (BSIT)".
  String get menuLabel => '$full ($short)';

  /// The part of [full] that actually identifies the programme, with the
  /// degree prefix dropped: "BS Information Technology" becomes
  /// "Information Technology". This is what gets matched against free text.
  String get topicKey {
    for (final prefix in const [
      'Bachelor of Science in ',
      'Bachelor of ',
      'BS ',
      'BA ',
    ]) {
      if (full.toLowerCase().startsWith(prefix.toLowerCase())) {
        return full.substring(prefix.length);
      }
    }
    return full;
  }

  @override
  String toString() => short;
}

/// Programme names used to recognize existing saved college values.
const List<CollegeProgram> collegePrograms = [
  CollegeProgram('BSIT', 'BS Information Technology'),
  CollegeProgram('BSCS', 'BS Computer Science'),
  CollegeProgram('BSCRIM', 'BS Criminology'),
  CollegeProgram('BSIS', 'BS Information Systems'),
  CollegeProgram('BSCpE', 'BS Computer Engineering'),
  CollegeProgram('BSBA', 'BS Business Administration'),
  CollegeProgram('BSA', 'BS Accountancy'),
  CollegeProgram('BSAIS', 'BS Accounting Information System'),
  CollegeProgram('BS Entrepreneurship', 'BS Entrepreneurship'),
  CollegeProgram('BS Marketing Management', 'BS Marketing Management'),
  CollegeProgram('BEEd', 'Bachelor of Elementary Education'),
  CollegeProgram('BSEd', 'Bachelor of Secondary Education'),
  CollegeProgram(
    'BTVTEd',
    'Bachelor of Technical-Vocational Teacher Education',
  ),
  CollegeProgram('BSCE', 'BS Civil Engineering'),
  CollegeProgram('BS Mechanical Engineering', 'BS Mechanical Engineering'),
  CollegeProgram('BS Electrical Engineering', 'BS Electrical Engineering'),
  CollegeProgram('BS Electronics Engineering', 'BS Electronics Engineering'),
  CollegeProgram('BS Industrial Engineering', 'BS Industrial Engineering'),
  CollegeProgram('BSN', 'BS Nursing'),
  CollegeProgram('BS Medical Technology', 'BS Medical Technology'),
  CollegeProgram('BS Pharmacy', 'BS Pharmacy'),
  CollegeProgram('BS Psychology', 'BS Psychology'),
  CollegeProgram('BS Physical Therapy', 'BS Physical Therapy'),
  CollegeProgram('BA Communication', 'BA Communication'),
  CollegeProgram('BA English Language', 'BA English Language'),
  CollegeProgram('BA Political Science', 'BA Political Science'),
  CollegeProgram('BA Sociology', 'BA Sociology'),
  CollegeProgram('BSHM', 'BS Hospitality Management'),
  CollegeProgram('BS Tourism Management', 'BS Tourism Management'),
  CollegeProgram('BS Culinary Management', 'BS Culinary Management'),
  CollegeProgram('BS Biology', 'BS Biology'),
  CollegeProgram('BS Mathematics', 'BS Mathematics'),
  CollegeProgram('BS Chemistry', 'BS Chemistry'),
  CollegeProgram('BS Agriculture', 'BS Agriculture'),
  CollegeProgram('BS Environmental Science', 'BS Environmental Science'),
];

/// Programmes offered in the student Course dropdown, in the requested order.
const List<CollegeProgram> collegeProgramOptions = [
  CollegeProgram('BSIT', 'BS Information Technology'),
  CollegeProgram('BSCS', 'BS Computer Science'),
  CollegeProgram('BSCRIM', 'BS Criminology'),
  CollegeProgram('BSN', 'BS Nursing'),
  CollegeProgram('BS Psychology', 'BS Psychology'),
  CollegeProgram('BSA', 'BS Accountancy'),
  CollegeProgram('BSCE', 'BS Civil Engineering'),
  CollegeProgram('BEEd', 'Bachelor of Elementary Education'),
  CollegeProgram('BSEd', 'Bachelor of Secondary Education'),
  CollegeProgram('BSHM', 'BS Hospitality Management'),
];

/// One college available to Faculty accounts.
class FacultyCollege {
  final String short;
  final String full;

  const FacultyCollege(this.short, this.full);

  String get menuLabel => '$full ($short)';
}

/// Colleges offered in the Faculty dropdown, in the requested display order.
const List<FacultyCollege> facultyCollegeOptions = [
  FacultyCollege('CITE', 'College of Information and Technology Education'),
  FacultyCollege('CCJE', 'College of Criminal Justice Education'),
  FacultyCollege('COHS', 'College of Health Sciences'),
  FacultyCollege('CBMA', 'College of Business Management and Accountancy'),
  FacultyCollege('CEA', 'College of Engineering and Architecture'),
  FacultyCollege('CTE', 'College of Teacher Education'),
  FacultyCollege('CHTM', 'College of Hospitality and Tourism Management'),
  FacultyCollege('CHS', 'College of Human Sciences'),
];

/// Resolves either the shortcut or full Faculty college name.
FacultyCollege? facultyCollegeFor(String? saved) {
  final value = saved?.trim().toLowerCase();
  if (value == null || value.isEmpty) return null;

  for (final college in facultyCollegeOptions) {
    if (college.short.toLowerCase() == value ||
        college.full.toLowerCase() == value) {
      return college;
    }
  }
  return null;
}

/// Finds the programme a saved college value refers to, ignoring case.
///
/// Handles three shapes of input:
///   1. the shortcut itself — "BSIT";
///   2. the listed title — "BS Information Technology";
///   3. a longer wording that contains the programme — "Bachelor of Science in
///      Information Technology and Education" still resolves to BSIT, because
///      that is how students actually type it.
///
/// Returns null when nothing matches, so the caller can fall back.
CollegeProgram? collegeProgramFor(String? saved) {
  final value = saved?.trim();
  if (value == null || value.isEmpty) return null;
  final lower = value.toLowerCase();

  for (final program in collegePrograms) {
    if (program.short.toLowerCase() == lower) return program;
    if (program.full.toLowerCase() == lower) return program;
  }

  // The wording may not match the listed title exactly, so fall back to the
  // words that identify the programme. A topic appearing as one unbroken run
  // is the strongest signal — that is what tells "Computer Science" and
  // "Computer Engineering" apart — and otherwise every one of the topic's
  // words just has to be present somewhere.
  final words = _wordsOf(lower);
  final flat = words.join(' ');

  CollegeProgram? best;
  var bestScore = 0;
  for (final program in collegePrograms) {
    final topic = _wordsOf(program.topicKey.toLowerCase());
    if (topic.isEmpty) continue;

    final score = flat.contains(topic.join(' '))
        ? 1000 + topic.length
        : (topic.every(words.contains) ? topic.length : 0);
    if (score > bestScore) {
      best = program;
      bestScore = score;
    }
  }
  return best;
}

/// Splits text into comparable words, dropping punctuation so hyphens and
/// brackets do not affect a match.
Set<String> _wordsOf(String text) =>
    text.split(RegExp('[^a-z0-9]+')).where((word) => word.isNotEmpty).toSet();

/// The legacy display limit for college values that are not in the dropdowns.
const int collegeDisplayLimit = 22;

/// The college text to display on the Profile screen and admin user views.
///
/// Supported student programmes and faculty colleges always display their
/// shortcut, even when a legacy account has the full title saved. Other legacy
/// values retain the previous length-based display behavior.
String collegeDisplay(String? saved) {
  final value = saved?.trim() ?? '';
  if (value.isEmpty) return '';

  final facultyCollege = facultyCollegeFor(value);
  if (facultyCollege != null) return facultyCollege.short;

  final program = collegeProgramFor(value);
  if (program != null) {
    for (final option in collegeProgramOptions) {
      if (option.short.toLowerCase() == program.short.toLowerCase()) {
        return option.short;
      }
    }
  }

  if (countLetters(value) <= collegeDisplayLimit) return value;

  if (program != null) return program.short;

  // Not a listed programme at all, so trim to the limit on a word boundary
  // rather than leaving half a word hanging.
  final letters = RegExp(r'\S').allMatches(value).toList();
  if (letters.length <= collegeDisplayLimit) return value;
  final head = value.substring(0, letters[collegeDisplayLimit - 1].end);
  final lastSpace = head.lastIndexOf(' ');
  final kept = (lastSpace == -1 ? head : head.substring(0, lastSpace))
      .trimRight();
  return '$kept...';
}
