// ════════════════════════════════════════════════════════════════════════════
//  TEST FILE — this is NOT part of the running app.
//
//  Everything in the test/ folder is only executed when you type
//  `flutter test` in the terminal. It is never compiled into the APK, so it
//  cannot change anything you see on your phone.
//
//  What this file checks:
//    The app starts without throwing, and the splash screen finishes its
//    animation and navigates away instead of leaving a timer running.
//
//  Run just this file:  flutter test test/widget_test.dart
//  Run every test:      flutter test
// ════════════════════════════════════════════════════════════════════════════

// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:lendy/main.dart';
import 'package:lendy/providers/auth_provider.dart';

void main() {
  testWidgets('app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      SmartClassroomApp(
        authProvider: AuthProvider.forTesting(),
        showWelcome: true,
      ),
    );

    expect(find.byType(SmartClassroomApp), findsOneWidget);

    // The splash chains Future.delayed gaps, which schedule no frames, so
    // pumpAndSettle would return before its timers fire. Step time instead.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Welcome!'), findsOneWidget);
  });

  testWidgets('later launches skip the welcome page and open login', (
    tester,
  ) async {
    await tester.pumpWidget(
      SmartClassroomApp(
        authProvider: AuthProvider.forTesting(),
        showWelcome: false,
      ),
    );

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Welcome!'), findsNothing);
    expect(find.text('Welcome to'), findsOneWidget);
  });
}
