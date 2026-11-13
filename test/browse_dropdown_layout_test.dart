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
          ChangeNotifierProvider(create: (_) => AuthProvider.forTesting()),
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

  // Walks through category names plus the "All categories" reset, and
  // requires the field's box to stay byte-identical every time.
  testWidgets('category field never changes size or position', (tester) async {
    await pumpBrowse(tester);

    final baseline = fieldRect(tester, 0);
    expect(baseline.height, 38.0);

    for (final category in ['Cameras', '3D Printers', 'New category']) {
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
    expect(baseline.height, 38.0);

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

  // With no inventory, the only category option is the reset choice.
  testWidgets('category menu shows the all-categories option', (tester) async {
    await pumpBrowse(tester);

    await tester.tap(dropdowns.at(0));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('All Categories').last).dy,
      greaterThanOrEqualTo(fieldRect(tester, 0).bottom),
      reason: 'category choices should open below the filter field',
    );

    final menuRows = find.byType(MenuItemButton);
    expect(menuRows, findsOneWidget);
    expect(tester.getSize(menuRows.first).height, 48.0);
  });

  testWidgets('dashboard avatar opens the profile', (tester) async {
    var profileOpened = false;
    await pumpBrowse(tester, onProfileTap: () => profileOpened = true);

    await tester.tap(find.byKey(const Key('dashboard-profile-avatar')));

    expect(profileOpened, isTrue);
  });

  testWidgets('Home header scrolls with the Browse content', (tester) async {
    tester.view.physicalSize = const Size(800, 350);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpBrowse(tester);

    final header = find.byKey(const Key('dashboard-header'));
    final initialTop = tester.getTopLeft(header).dy;
    expect(find.byKey(const Key('browse-scroll-view')), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(header).dy, lessThan(initialTop));
  });
}
