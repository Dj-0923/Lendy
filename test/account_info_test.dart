// ════════════════════════════════════════════════════════════════════════════
//  TEST FILE — this is NOT part of the running app.
//
//  Everything in the test/ folder is only executed when you type
//  `flutter test` in the terminal. It is never compiled into the APK, so it
//  cannot change anything you see on your phone.
//
//  What this file protects against:
//    1. The Year level field must only ever hold a single digit 1-5, and must
//       turn it into "1st year" / "2nd year" / "3rd year" / "4th year" /
//       "5th year".
//    2. The Gender dropdown must look identical to the text fields above it
//       and must never move when an option is chosen.
//    3. The College field accepts either the shortcut or the full programme
//       title, and the Profile screen always shows the shortcut when the typed
//       wording is longer than 22 letters (spaces not counted).
//
//  Run just this file:  flutter test test/account_info_test.dart
//  Run every test:      flutter test
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/user_model.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/screens/account_info_screen.dart';
import 'package:lendy/utils/college_programs.dart';
import 'package:lendy/utils/text_formatters.dart';
import 'package:lendy/utils/year_level.dart';
import 'package:lendy/widgets/plain_text_field.dart';
import 'package:provider/provider.dart';

void main() {
  // These four are plain unit tests: no widgets, just the year-level rules
  // in lib/utils/year_level.dart.
  group('year level', () {
    test('each digit becomes its ordinal label', () {
      expect(yearLevelToLabel('1'), '1st year');
      expect(yearLevelToLabel('2'), '2nd year');
      expect(yearLevelToLabel('3'), '3rd year');
      expect(yearLevelToLabel('4'), '4th year');
      expect(yearLevelToLabel('5'), '5th year');
    });

    test('non numeric or out of range has no label', () {
      for (final bad in [
        '',
        ' ',
        '0',
        '6',
        '7',
        '9',
        'abc',
        '1a',
        '12',
        null,
      ]) {
        expect(yearLevelToLabel(bad), isNull, reason: 'accepted "$bad"');
      }
    });

    test('a stored label round-trips back to its digit', () {
      for (final digit in yearLevelOptions) {
        expect(yearLevelToDigit(yearLevelToLabel(digit)), digit);
      }
      expect(yearLevelToDigit('1st year'), '1');
      expect(yearLevelToDigit('3rd year'), '3');
      expect(yearLevelToDigit('5th year'), '5');
    });

    test('validator rejects anything outside 1-5', () {
      expect(validateYearLevel(''), 'Year level is required');
      expect(validateYearLevel('1'), isNull);
      expect(validateYearLevel('5'), isNull);
      expect(validateYearLevel('0'), yearLevelRangeMessage);
      expect(validateYearLevel('6'), yearLevelRangeMessage);
      expect(validateYearLevel('abc'), yearLevelRangeMessage);
    });
  });

  // Plain unit tests for the Profile screen's college shortening rule. This is
  // display-only: the value stored on the user record is never changed.
  group('college shown on the profile', () {
    test('a title of 22 letters or fewer is shown in full', () {
      // Letters are counted without spaces, so a long-looking title can still
      // fit: "BS COMPUTER ENGINEERING" is 21.
      expect(collegeDisplay('BSIT'), 'BSIT');
      expect(collegeDisplay('BS NURSING'), 'BS NURSING');
      expect(countLetters('BS COMPUTER ENGINEERING'), 21);
      expect(
        collegeDisplay('BS COMPUTER ENGINEERING'),
        'BS COMPUTER ENGINEERING',
      );
    });

    test('a longer title falls back to the programme shortcut', () {
      expect(
        collegeDisplay('BACHELOR OF TECHNICAL-VOCATIONAL TEACHER EDUCATION'),
        'BTVTEd',
      );
      expect(collegeDisplay('BACHELOR OF ELEMENTARY EDUCATION'), 'BEEd');
      expect(collegeDisplay('BS INFORMATION TECHNOLOGY'), 'BSIT');
      // 21 letters, so this one is still shown in full.
      expect(
        collegeDisplay('BS MARKETING MANAGEMENT'),
        'BS MARKETING MANAGEMENT',
      );
    });

    // Students type the long wording, not the listed title, so the shortcut is
    // found even when the value is not an exact match for any programme.
    test('a long wording still resolves to the shortcut', () {
      expect(
        collegeDisplay(
          'BACHELOR OF SCIENCE IN INFORMATION IN TECHNOLOGY AND EDUCATION',
        ),
        'BSIT',
      );
      expect(
        collegeDisplay('BACHELOR OF SCIENCE IN INFORMATION TECHNOLOGY'),
        'BSIT',
      );
      expect(collegeDisplay('BS INFORMATION TECHNOLOGY (BSIT)'), 'BSIT');
      // The full title is only 21 letters, so it stays readable as it is.
      expect(
        collegeDisplay('BS COMPUTER ENGINEERING'),
        'BS COMPUTER ENGINEERING',
      );
      expect(
        collegeDisplay('BACHELOR OF SCIENCE IN COMPUTER ENGINEERING'),
        'BSCpE',
      );
    });

    // "Electronics" must not be read as "Electrical".
    test('similar programmes are not confused', () {
      expect(
        collegeDisplay('BACHELOR OF SCIENCE IN ELECTRONICS ENGINEERING'),
        'BS Electronics Engineering',
      );
      expect(
        collegeDisplay('BACHELOR OF SCIENCE IN ELECTRICAL ENGINEERING'),
        'BS Electrical Engineering',
      );
    });

    test('the shortcut is found whether it or the title was saved', () {
      // Typing "BSIT" and saving the full title end up displaying the same.
      expect(
        collegeDisplay('BSIT'),
        collegeDisplay('BS Information Technology'),
      );
    });

    test('an unlisted value is trimmed on a word boundary', () {
      // Never leaves half a word hanging.
      expect(
        collegeDisplay('SOME VERY LONG COURSE NAME THAT IS NOT LISTED'),
        'SOME VERY LONG COURSE...',
      );
    });

    test('an empty value stays empty', () {
      expect(collegeDisplay(null), '');
      expect(collegeDisplay('   '), '');
    });
  });

  // The rest drive the real widget: they type into the fields and measure the
  // rendered boxes, the same way a person would see them.
  group('AccountInfoScreen', () {
    // Finds a text field by the grey hint inside it. Matched loosely so a
    // longer hint can be added later without breaking these tests.
    Finder fieldWithHint(String hint) => find.byWidgetPredicate(
      (w) =>
          w is InputDecorator && (w.decoration.hintText ?? '').contains(hint),
    );

    // The actual typing area of a text field (the part that holds the text).
    Finder editableIn(String hint) => find.descendant(
      of: fieldWithHint(hint),
      matching: find.byType(EditableText),
    );

    // The gender dropdown is a menu anchored to its decorated field.
    final genderField = find.byWidgetPredicate(
      (w) => w is MenuAnchor,
      description: 'gender dropdown',
    );
    final genderArrow = find.descendant(
      of: genderField,
      matching: find.byType(IconButton),
    );

    // The bordered box around the gender dropdown.
    final genderBorder = find
        .descendant(of: genderField, matching: find.byType(InputDecorator))
        .first;

    // Builds the Account Info screen inside the test's fake phone.
    Future<void> pumpScreen(WidgetTester tester, {AuthProvider? auth}) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => auth ?? AuthProvider(),
          child: const MaterialApp(home: AccountInfoScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Types letters, then two digits, then one digit: the field must end up
    // empty, then "1", then "4".
    testWidgets('year level field only accepts a single digit', (tester) async {
      await pumpScreen(tester);
      final field = editableIn('e.g. 3');

      await tester.enterText(field, 'abc');
      await tester.pump();
      expect(tester.widget<EditableText>(field).controller.text, '');

      await tester.enterText(field, '12');
      await tester.pump();
      expect(tester.widget<EditableText>(field).controller.text, '1');

      await tester.enterText(field, '4');
      await tester.pump();
      expect(tester.widget<EditableText>(field).controller.text, '4');
    });

    // The ordinal must NOT appear under the field — it is only ever shown on
    // the Profile screen, from the value that gets saved.
    testWidgets('year level shows no ordinal text under the field', (
      tester,
    ) async {
      await pumpScreen(tester);
      final field = editableIn('e.g. 3');

      for (final digit in ['1', '2', '3', '4', '5']) {
        await tester.enterText(field, digit);
        await tester.pump();
        for (final label in [
          '1st year',
          '2nd year',
          '3rd year',
          '4th year',
          '5th year',
        ]) {
          expect(find.text(label), findsNothing, reason: 'for $digit');
        }
      }
    });

    // The input takes either the shortcut or the whole title, upper cased, and
    // is not length-capped: shortening to 22 letters happens on the Profile.
    testWidgets('college accepts the shortcut or the full title', (
      tester,
    ) async {
      await pumpScreen(tester);
      final field = editableIn('e.g. BSIT');

      await tester.enterText(field, 'bsit');
      await tester.pump();
      expect(tester.widget<EditableText>(field).controller.text, 'BSIT');

      // A title well past 22 letters must still be accepted here.
      await tester.enterText(
        field,
        'Bachelor of Science in Information Technology',
      );
      await tester.pump();
      expect(
        tester.widget<EditableText>(field).controller.text,
        'BACHELOR OF SCIENCE IN INFORMATION TECHNOLOGY',
      );
    });

    // The filled boxes must keep their full size: the height the widget
    // declares has to be exactly what actually gets laid out, otherwise the
    // text ends up cramped inside the border.
    testWidgets('text fields render at their full declared height', (
      tester,
    ) async {
      await pumpScreen(tester);

      for (final hint in [
        'e.g. Juan Dela Cruz',
        'e.g. dhie@gmail.com',
        'e.g. BSIT',
        'e.g. 3',
        'e.g. 7',
      ]) {
        expect(
          tester.getRect(fieldWithHint(hint)).height,
          PlainTextField.fieldHeight,
          reason: '"$hint" is not ${PlainTextField.fieldHeight} tall',
        );
      }
    });

    // Two things at once: the gender field must be exactly as tall as the
    // "Full name" field above it, and it must keep the same position and size
    // after each of the three choices is tapped.
    testWidgets('gender field matches the text field design and never moves', (
      tester,
    ) async {
      await pumpScreen(tester);

      final genderRect = tester.getRect(genderBorder);
      final fullNameRect = tester.getRect(fieldWithHint('e.g. Juan Dela Cruz'));

      expect(
        genderRect.height,
        fullNameRect.height,
        reason: 'gender field must be the same height as the text fields',
      );

      for (final gender in ['Male', 'Female']) {
        await tester.tap(genderArrow);
        await tester.pumpAndSettle();
        await tester.tap(find.text(gender).last);
        await tester.pumpAndSettle();

        expect(
          tester.getRect(genderField),
          genderRect,
          reason: 'field moved when selecting $gender',
        );
      }
    });

    testWidgets('gender menu stays below the field after selecting Female', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(genderArrow);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      final fieldBottom = tester.getRect(genderBorder).bottom;
      await tester.tap(genderArrow);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Male').last).dy,
        greaterThanOrEqualTo(fieldBottom),
      );
      expect(
        tester.getTopLeft(find.text('Female').last).dy,
        greaterThanOrEqualTo(fieldBottom),
      );
    });

    // The menu contains only the two supported gender choices.
    testWidgets('gender offers exactly the two expected choices', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(genderArrow);
      await tester.pumpAndSettle();

      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Prefer not to say'), findsNothing);
      expect(find.text('Bading'), findsNothing);
      expect(find.text('Yombot'), findsNothing);
    });

    testWidgets('only the gender arrow opens the choices menu', (tester) async {
      await pumpScreen(tester);

      final fieldRect = tester.getRect(genderBorder);
      await tester.tapAt(Offset(fieldRect.left + 24, fieldRect.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Male'), findsNothing);

      await tester.tap(genderArrow);
      await tester.pumpAndSettle();
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
    });

    testWidgets('faculty Account Info hides year level and block', (
      tester,
    ) async {
      final auth = AuthProvider();
      const email = 'faculty@example.com';
      final accountFuture = auth.requestAccount(
        fullName: 'Faculty User',
        email: email,
        role: UserRole.faculty,
        idNumber: 'FAC-001',
      );
      await tester.pump(const Duration(milliseconds: 600));
      final accountResult = await accountFuture;

      final loginFuture = auth.login(email, accountResult.tempPassword!);
      await tester.pump(const Duration(milliseconds: 500));
      expect(await loginFuture, isNull);

      await pumpScreen(tester, auth: auth);

      expect(find.text('Department'), findsOneWidget);
      expect(find.text('College'), findsNothing);
      expect(find.text('Year level'), findsNothing);
      expect(find.text('Block'), findsNothing);
      expect(fieldWithHint('e.g. 3'), findsNothing);
      expect(fieldWithHint('e.g. 7'), findsNothing);
    });
  });
}
