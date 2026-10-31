import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/screens/request_account_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('student account request shows paired student profile fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(),
        child: const MaterialApp(home: RequestAccountScreen()),
      ),
    );

    expect(find.text('College'), findsOneWidget);
    expect(find.text('e.g. College of Computer Studies'), findsOneWidget);
    expect(find.text('Student ID No.'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Year level'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.byType(MenuAnchor), findsNWidgets(3));
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
    expect(find.text('Year level'), findsNothing);
    expect(find.text('Block'), findsNothing);
    expect(find.byType(MenuAnchor), findsOneWidget);
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
