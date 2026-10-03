// lib/utils/college_programs.dart
import 'text_formatters.dart';

/// One degree programme offered by the school.
class CollegeProgram {
  /// What gets saved to the user record and shown in the closed field.
  /// For programmes the school has no official acronym for, this is the same
  /// text as [full].
  final String short;

  /// The full title, shown in the open dropdown where there is room for it.
  final String full;

  const CollegeProgram(this.short, this.full);

  /// The dropdown row: "BSIT — BS Information Technology", or just the title
  /// when the programme has no acronym of its own.
  String get menuLabel => short == full ? full : '$short — $full';

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

/// Every programme a student can pick, in the order shown in the dropdown.
///
/// The school did not publish acronyms for every programme, so only the ones
/// that were supplied are shortened; the rest keep their full title.
const List<CollegeProgram> collegePrograms = [
  CollegeProgram('BSIT', 'BS Information Technology'),
  CollegeProgram('BSCS', 'BS Computer Science'),
  CollegeProgram('BSIS', 'BS Information Systems'),
  CollegeProgram('BSCpE', 'BS Computer Engineering'),
  CollegeProgram('BSBA', 'BS Business Administration'),
  CollegeProgram('BSA', 'BS Accountancy'),
  CollegeProgram('BSAIS', 'BS Accounting Information System'),
  CollegeProgram('BS Entrepreneurship', 'BS Entrepreneurship'),
  CollegeProgram('BS Marketing Management', 'BS Marketing Management'),
  CollegeProgram('BEEd', 'Bachelor of Elementary Education'),
  CollegeProgram('BSEd', 'Bachelor of Secondary Education'),
  CollegeProgram('BTVTEd', 'Bachelor of Technical-Vocational Teacher Education'),
  CollegeProgram('BS Civil Engineering', 'BS Civil Engineering'),
  CollegeProgram('BS Mechanical Engineering', 'BS Mechanical Engineering'),
  CollegeProgram('BS Electrical Engineering', 'BS Electrical Engineering'),
  CollegeProgram('BS Electronics Engineering', 'BS Electronics Engineering'),
  CollegeProgram('BS Industrial Engineering', 'BS Industrial Engineering'),
  CollegeProgram('BS Nursing', 'BS Nursing'),
  CollegeProgram('BS Medical Technology', 'BS Medical Technology'),
  CollegeProgram('BS Pharmacy', 'BS Pharmacy'),
  CollegeProgram('BS Psychology', 'BS Psychology'),
  CollegeProgram('BS Physical Therapy', 'BS Physical Therapy'),
  CollegeProgram('BA Communication', 'BA Communication'),
  CollegeProgram('BA English Language', 'BA English Language'),
  CollegeProgram('BA Political Science', 'BA Political Science'),
  CollegeProgram('BA Sociology', 'BA Sociology'),
  CollegeProgram('BS Hospitality Management', 'BS Hospitality Management'),
  CollegeProgram('BS Tourism Management', 'BS Tourism Management'),
  CollegeProgram('BS Culinary Management', 'BS Culinary Management'),
  CollegeProgram('BS Biology', 'BS Biology'),
  CollegeProgram('BS Mathematics', 'BS Mathematics'),
  CollegeProgram('BS Chemistry', 'BS Chemistry'),
  CollegeProgram('BS Agriculture', 'BS Agriculture'),
  CollegeProgram('BS Environmental Science', 'BS Environmental Science'),
];

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
Set<String> _wordsOf(String text) => text
    .split(RegExp('[^a-z0-9]+'))
    .where((word) => word.isNotEmpty)
    .toSet();

/// The most characters, spaces not counted, that the Profile screen shows for a
/// college before it falls back to the programme's shortcut.
const int collegeDisplayLimit = 22;

/// The college text to display on the Profile screen.
///
/// A full title is shown when it fits inside [collegeDisplayLimit] letters
/// ("BS NURSING" is short enough), otherwise the programme's shortcut is shown
/// instead ("BTVTEd"), because a truncated half-title is harder to read than
/// the acronym. This is a display concern only: the value saved on the user
/// record is left untouched, so switching back to the full title stays possible.
String collegeDisplay(String? saved) {
  final value = saved?.trim() ?? '';
  if (value.isEmpty) return 'N/A';

  if (countLetters(value) <= collegeDisplayLimit) return value;

  final program = collegeProgramFor(value);
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
