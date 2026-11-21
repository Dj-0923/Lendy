import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/screens/request_account_screen.dart';
import 'package:lendy/utils/college_programs.dart';
import 'package:lendy/widgets/app_text_field.dart';
import 'package:provider/provider.dart';

void main() {
  Finder idNumberInput() => find.byWidgetPredicate(
    (widget) => widget is AppTextField && widget.hint == 'e.g. 20243781',
  );
  Finder idNumberEditable() =>
      find.descendant(of: idNumberInput(), matching: find.byType(EditableText));

  testWidgets('student account request shows paired student profile fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(),
        child: const MaterialApp(home: RequestAccountScreen()),
      ),
    );

    expect(find.text('Course'), findsOneWidget);
    expect(find.text('Select course'), findsOneWidget);
    expect(find.text('Student ID No.'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Year level'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.byType(MenuAnchor), findsNWidgets(4));
  });

  testWidgets('student ID number is limited to exactly 8 characters', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(),
        child: const MaterialApp(home: RequestAccountScreen()),
      ),
    );

    final idField = tester.widget<AppTextField>(idNumberInput());
    expect(
      idField.validator?.call('1234567'),
      'Student ID No. must be exactly 8 characters',
    );
    expect(idField.validator?.call('12345678'), isNull);

    await tester.enterText(idNumberEditable(), '123456789');
    expect(
      tester.widget<AppTextField>(idNumberInput()).controller.text,
      '12345678',
    );
  });

  testWidgets('student Course dropdown shows the requested programmes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(),
        child: const MaterialApp(home: RequestAccountScreen()),
      ),
    );

    await tester.ensureVisible(find.byTooltip('Select Course'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select Course'));
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton), findsNWidgets(10));
    for (final program in collegeProgramOptions) {
      expect(find.text(program.menuLabel).last, findsOneWidget);
    }

    final menuViewport = find.byType(SingleChildScrollView).last;
    expect(tester.getSize(menuViewport).height, lessThanOrEqualTo(240));
    await tester.ensureVisible(find.text(collegeProgramOptions.last.menuLabel));
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(find.text(collegeProgramOptions.last.menuLabel).last)
          .bottom,
      lessThanOrEqualTo(tester.getRect(menuViewport).bottom),
    );
  });

  testWidgets('faculty account request only shows the gender dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(),
        child: const MaterialApp(home: RequestAccountScreen()),
      ),
    );

    await tester.tap(find.text('Faculty'));
    await tester.pumpAndSettle();

    expect(find.text('Faculty ID No.'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('College'), findsOneWidget);
    expect(find.text('Course'), findsNothing);
    expect(find.text('Year level'), findsNothing);
    expect(find.text('Block'), findsNothing);
    expect(find.byType(MenuAnchor), findsNWidgets(2));
    final facultyIdField = tester.widget<AppTextField>(idNumberInput());
    expect(facultyIdField.inputFormatters, hasLength(1));
    expect(
      facultyIdField.validator?.call('FAC-001'),
      'Faculty ID No. must be exactly 8 characters',
    );
    expect(facultyIdField.validator?.call('FAC-0012'), isNull);
    await tester.enterText(idNumberEditable(), 'FAC-001234');
    expect(
      tester.widget<AppTextField>(idNumberInput()).controller.text,
      'FAC-0012',
    );

    await tester.ensureVisible(find.byTooltip('Select College'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select College'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(8));
    expect(facultyCollegeOptions.map((college) => college.short).toList(), [
      'CITE',
      'CCJE',
      'COHS',
      'CBMA',
      'CEA',
      'CTE',
      'CHTM',
      'CHS',
    ]);
    for (final college in facultyCollegeOptions) {
      expect(find.text(college.menuLabel).last, findsOneWidget);
    }
  });

  testWidgets('student year and block dropdowns have the requested ranges', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(),
        child: const MaterialApp(home: RequestAccountScreen()),
      ),
    );

    await tester.tap(find.byTooltip('Select Year level'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(5));
    for (final year in ['1', '2', '3', '4', '5']) {
      expect(find.text(year), findsOneWidget);
    }

    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select Block'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(11));

    final blockField = find.ancestor(
      of: find.byTooltip('Select Block'),
      matching: find.byType(InputDecorator),
    );
    final menuViewport = find.byType(SingleChildScrollView).last;
    expect(tester.getSize(menuViewport).height, lessThanOrEqualTo(240));
    expect(
      tester.getRect(menuViewport).overlaps(tester.getRect(blockField)),
      isFalse,
      reason: 'the Block menu should not cover its field',
    );

    await tester.ensureVisible(find.text('11').last);
    await tester.pumpAndSettle();
    expect(find.text('11').last, findsOneWidget);
    expect(
      tester.getRect(find.text('11').last).bottom,
      lessThanOrEqualTo(tester.getRect(menuViewport).bottom),
    );
  });
}
