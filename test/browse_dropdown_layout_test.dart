// ════════════════════════════════════════════════════════════════════════════
//  TEST FILE — this is NOT part of the running app.
//
//  Everything in the test/ folder is only executed when you type
//  `flutter test` in the terminal. It is never compiled into the APK, so it
//  cannot change anything you see on your phone.
//
//  What this file protects against:
//    The "All categories" and "Any availability" dropdowns on the Browse
//    screen used to change size/position depending on which option you
//    picked. These tests measure the rendered box and fail if it ever moves,
//    so the bug cannot silently come back.
//
//  Run just this file:  flutter test test/browse_dropdown_layout_test.dart
//  Run every test:      flutter test
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/screens/browse_screen.dart';
import 'package:provider/provider.dart';

void main() {
  late EquipmentProvider equipment;

  // Builds the Browse screen inside the test's fake 800x600 phone.
  Future<void> pumpBrowse(
    WidgetTester tester, {
    VoidCallback? onProfileTap,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(
            create: (_) => equipment = EquipmentProvider(),
          ),
        ],
        child: MaterialApp(home: BrowseScreen(onProfileTap: onProfileTap)),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Every filter menu on the screen, in order: 0 = category, 1 = availability.
  final Finder dropdowns = find.byWidgetPredicate(
    (w) => w is MenuAnchor,
    description: 'filter menu',
  );

  // The bordered filter field inside its anchored menu.
  Rect fieldRect(WidgetTester tester, int dropdownIndex) {
    final container = find
        .descendant(
          of: dropdowns.at(dropdownIndex),
          matching: find.byType(Container),
        )
        .first;
    return tester.getRect(container);
  }

  // Walks through all 6 categories plus the "All categories" reset, and
  // requires the field's box to stay byte-identical every time.
  testWidgets('category field never changes size or position', (tester) async {
    await pumpBrowse(tester);

    final baseline = fieldRect(tester, 0);
    expect(baseline.height, 48.0);

    for (final category in EquipmentCategory.values) {
      equipment.setCategory(category);
      await tester.pump();
      final rect = fieldRect(tester, 0);
      expect(rect, baseline, reason: 'field moved when selecting $category');
    }

    equipment.setCategory(null);
    await tester.pump();
    expect(fieldRect(tester, 0), baseline, reason: 'field moved on reset');
  });

  // Same check for the 4 availability options.
  testWidgets('availability field never changes size or position', (
    tester,
  ) async {
    await pumpBrowse(tester);

    final baseline = fieldRect(tester, 1);
    expect(baseline.height, 48.0);

    for (final status in EquipmentStatus.values) {
      equipment.setAvailability(status);
      await tester.pump();
      final rect = fieldRect(tester, 1);
      expect(rect, baseline, reason: 'field moved when selecting $status');
    }

    equipment.setAvailability(null);
    await tester.pump();
    expect(fieldRect(tester, 1), baseline, reason: 'field moved on reset');
  });

  // Opens the menu for real and checks every option row has one fixed height.
  testWidgets('open menu rows are all the same height', (tester) async {
    await pumpBrowse(tester);

    equipment.setCategory(EquipmentCategory.tablet);
    await tester.pump();
    await tester.tap(dropdowns.at(0));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('All categories')).dy,
      greaterThanOrEqualTo(fieldRect(tester, 0).bottom),
      reason: 'category choices should open below the filter field',
    );

    final menuRows = find.byType(MenuItemButton);
    expect(menuRows, findsNWidgets(7));
    for (var index = 0; index < 7; index++) {
      expect(tester.getSize(menuRows.at(index)).height, 48.0);
    }
  });

  testWidgets('dashboard avatar opens the profile', (tester) async {
    var profileOpened = false;
    await pumpBrowse(tester, onProfileTap: () => profileOpened = true);

    await tester.tap(find.byKey(const Key('dashboard-profile-avatar')));

    expect(profileOpened, isTrue);
  });
}
