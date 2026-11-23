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
    VoidCallback? onNotificationTap,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider.forTesting()),
          ChangeNotifierProvider(
            create: (_) => equipment = EquipmentProvider(),
          ),
        ],
        child: MaterialApp(
          home: BrowseScreen(
            onProfileTap: onProfileTap,
            onNotificationTap: onNotificationTap,
          ),
        ),
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

  testWidgets('dropdown icons stay pinned to the right as selections change', (
    tester,
  ) async {
    await pumpBrowse(tester);

    for (final index in [0, 1]) {
      final icon = find.byIcon(Icons.keyboard_arrow_down).at(index);
      final rightInset =
          tester.getRect(dropdowns.at(index)).right -
          tester.getRect(icon).right;
      expect(
        fieldRect(tester, index).width,
        lessThanOrEqualTo(index == 0 ? 140 : 150),
      );
      expect(
        rightInset,
        closeTo(13, 0.01),
        reason: 'dropdown icon should align with the field right edge',
      );

      final values = index == 0
          ? <Object?>[null, 'Cameras', '3D Printers', 'New category']
          : <Object?>[null, ...EquipmentStatus.values];
      for (final value in values) {
        if (index == 0) {
          equipment.setCategory(value as String?);
        } else {
          equipment.setAvailability(value as EquipmentStatus?);
        }
        await tester.pump();
        expect(
          tester.getRect(icon).right,
          closeTo(tester.getRect(dropdowns.at(index)).right - rightInset, 0.01),
        );
      }
    }
  });

  // With no inventory, the only category option is the reset choice.
  testWidgets('category menu shows the all-categories option', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

  testWidgets('search scanner and assistant controls fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(470, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpBrowse(tester);

    expect(find.byKey(const Key('browse-search-field')), findsOneWidget);
    expect(find.byKey(const Key('browse-ai-assistant-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browse layout fits mobile and tablet widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [
      773.0,
      700.0,
      600.0,
      520.0,
      500.0,
      480.0,
      430.0,
      390.0,
      360.0,
      320.0,
    ]) {
      final height = width * 1.8;
      tester.view.physicalSize = Size(width, height);
      await pumpBrowse(tester);

      expect(tester.takeException(), isNull, reason: 'at ${width.toInt()}px');

      final searchRect = tester.getRect(
        find.byKey(const Key('browse-search-field')),
      );
      expect(
        searchRect.height,
        lessThanOrEqualTo(64),
        reason: 'search field should stay compact at ${width.toInt()}px',
      );
      final searchIcon = find.descendant(
        of: find.byKey(const Key('browse-search-field')),
        matching: find.byIcon(Icons.search),
      );
      expect(searchIcon, findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
      expect(
        tester.getCenter(searchIcon).dx,
        greaterThan(searchRect.center.dx),
      );
      final assistantRect = tester.getRect(
        find.byKey(const Key('browse-ai-assistant-button')),
      );
      expect(searchRect.left, greaterThanOrEqualTo(0));
      expect(searchRect.right, lessThanOrEqualTo(width));
      expect(assistantRect.left, greaterThanOrEqualTo(0));
      expect(assistantRect.right, lessThanOrEqualTo(width));
      expect(assistantRect.bottom, lessThanOrEqualTo(height));
    }
  });

  testWidgets('AI assistant button opens the borrower assistant', (
    tester,
  ) async {
    await pumpBrowse(tester);

    final assistantButton = find.byKey(const Key('browse-ai-assistant-button'));
    expect(assistantButton, findsOneWidget);
    expect(tester.getSize(assistantButton), const Size(64, 64));
    final homeAvatarImage = tester.widget<Image>(
      find.descendant(of: assistantButton, matching: find.byType(Image)),
    );
    expect(
      homeAvatarImage.image,
      const AssetImage('assets/images/botFabii.png'),
    );
    expect(homeAvatarImage.width, 58);
    expect(homeAvatarImage.height, 58);
    expect(homeAvatarImage.filterQuality, FilterQuality.high);
    final messageIcon = find.byKey(const Key('browse-ai-message-icon'));
    expect(messageIcon, findsOneWidget);
    expect(tester.getSize(messageIcon), const Size(17, 15));
    final assistantButtonMaterial = tester.widget<Material>(assistantButton);
    expect(assistantButtonMaterial.color, Colors.white);
    expect(assistantButtonMaterial.elevation, 2);
    expect(find.text('ASK ME'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    await tester.tap(assistantButton);
    await tester.pumpAndSettle();

    expect(find.text('Fabii'), findsOneWidget);
    expect(find.text('your AI assistant'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    final assistantHeaderAvatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('assistant-header-avatar')),
    );
    expect(assistantHeaderAvatar.backgroundImage, isNull);
    final assistantHeaderImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('assistant-header-avatar')),
        matching: find.byType(Image),
      ),
    );
    expect(
      assistantHeaderImage.image,
      const AssetImage('assets/images/fabi_pfp.png'),
    );
    expect(assistantHeaderImage.width, 48);
    expect(assistantHeaderImage.height, 48);
    expect(assistantHeaderImage.filterQuality, FilterQuality.high);
    final titleRect = tester.getRect(find.text('Fabii'));
    final subtitleRect = tester.getRect(find.text('your AI assistant'));
    expect(subtitleRect.top - titleRect.bottom, lessThanOrEqualTo(2));
    expect(find.byKey(const Key('assistant-online-indicator')), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).titleSpacing, 0);
    expect(find.textContaining('You can ask me in English'), findsOneWidget);
  });

  testWidgets('home uses the hero image and places search below it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(773, 684);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await pumpBrowse(tester, onProfileTap: () {}, onNotificationTap: () {});

    final header = find.byKey(const Key('dashboard-header'));
    final headerContainer = tester.widget<Container>(header);
    final headerDecoration = headerContainer.decoration! as BoxDecoration;
    final headerRect = tester.getRect(header);
    final logoRect = tester.getRect(
      find.byKey(const Key('dashboard-header-logo')),
    );
    final notificationsRect = tester.getRect(
      find.byKey(const Key('dashboard-notifications')),
    );
    final profileRect = tester.getRect(
      find.byKey(const Key('dashboard-profile-avatar')),
    );
    final greeting = find.byKey(const Key('browse-home-greeting'));
    final subtitle = find.text('Browse equipment or ask Fabii for help.');
    final search = find.byKey(const Key('browse-search-field'));
    final searchContainer = tester.widget<Container>(
      find.byKey(const Key('browse-search-field-container')),
    );
    final searchRect = tester.getRect(search);
    final filters = tester.getRect(
      find.byKey(const Key('browse-pinned-filters')),
    );

    expect(
      headerDecoration.image!.image,
      const AssetImage('assets/images/bg-fabi.png'),
    );
    expect(headerDecoration.image!.fit, BoxFit.cover);
    expect(
      headerDecoration.borderRadius,
      const BorderRadius.only(
        bottomLeft: Radius.circular(48),
        bottomRight: Radius.circular(48),
      ),
    );
    expect(headerRect.top, 24);
    expect(headerRect.height, closeTo(773 / 2 - 24, 0.1));
    expect(notificationsRect.top, closeTo(headerRect.top + 16, 0.1));
    expect(profileRect.top, closeTo(headerRect.top + 16, 0.1));
    expect(logoRect.center.dy, closeTo(notificationsRect.center.dy, 0.1));
    expect(greeting, findsOneWidget);
    expect(subtitle, findsOneWidget);
    expect(
      tester.getSize(greeting).width,
      lessThan(headerRect.width * 0.7),
      reason: 'the greeting should stay in the wide left portion of the hero',
    );
    expect(
      searchRect.left,
      closeTo(40, 0.1),
      reason: 'the search field should have the wide reference inset',
    );
    expect(searchRect.width, closeTo(693, 0.1));
    expect(searchRect.height, 64);
    expect((searchContainer.decoration! as BoxDecoration).color, Colors.white);
    expect(
      find.descendant(of: search, matching: find.byType(VerticalDivider)),
      findsNothing,
    );
    expect(searchRect.top, greaterThan(headerRect.bottom));
    expect(filters.top, greaterThan(searchRect.bottom));
    expect(find.byKey(const Key('browse-ai-suggestions')), findsNothing);
    expect(find.text('Available items?'), findsNothing);
    expect(find.text('Camera to borrow?'), findsNothing);
    expect(find.text('Request status?'), findsNothing);
  });

  testWidgets('hides the home scrollbar and keeps categories below search', (
    tester,
  ) async {
    await pumpBrowse(tester);

    final scrollView = find.byKey(const Key('browse-scroll-view'));
    final scrollContext = tester.element(scrollView);
    final behavior = ScrollConfiguration.of(scrollContext);
    const child = SizedBox();
    final verticalScrollbar = behavior.buildScrollbar(
      scrollContext,
      child,
      const ScrollableDetails(direction: AxisDirection.down),
    );
    expect(identical(verticalScrollbar, child), isTrue);
    expect(find.byKey(const Key('browse-ai-suggestions')), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('browse-pinned-filters'))).top,
      greaterThan(
        tester.getRect(find.byKey(const Key('browse-search-field'))).bottom,
      ),
    );
  });

  testWidgets('header scrolls away while search and categories stay pinned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 260);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await pumpBrowse(tester);

    final header = find.byKey(const Key('dashboard-header'));
    final search = find.byKey(const Key('browse-search-field'));
    final pinnedSearch = find.byKey(const Key('browse-pinned-search'));
    final filters = find.byKey(const Key('browse-pinned-filters'));
    final statusBar = find.byKey(const Key('browse-status-bar-background'));
    final scrollView = find.byKey(const Key('browse-scroll-view'));
    expect(tester.widget<ColoredBox>(statusBar).color, Colors.black);
    expect(find.text('Lendy'), findsOneWidget);
    expect(find.text('Browse Items'), findsNothing);
    expect(search, findsNothing);
    expect(tester.getRect(statusBar).height, 24);
    expect(tester.getRect(header).top, 24);
    final headerDecoration =
        tester.widget<Container>(header).decoration! as BoxDecoration;
    expect(
      headerDecoration.image!.image,
      const AssetImage('assets/images/bg-fabi.png'),
    );
    expect(
      headerDecoration.borderRadius,
      const BorderRadius.only(
        bottomLeft: Radius.circular(48),
        bottomRight: Radius.circular(48),
      ),
    );
    expect(
      tester.getRect(header).bottom,
      greaterThan(tester.view.physicalSize.height),
    );

    await tester.drag(scrollView, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(header, findsNothing);
    expect(find.text('Lendy'), findsNothing);
    expect(search, findsOneWidget);
    expect(find.byKey(const Key('browse-ai-suggestions')), findsNothing);
    expect(find.text('Available items?'), findsNothing);
    expect(find.text('Camera to borrow?'), findsNothing);
    expect(find.text('Request status?'), findsNothing);
    expect(find.byKey(const Key('browse-ai-assistant-button')), findsOneWidget);
    expect(find.byKey(const Key('browse-fabii-decoration')), findsNothing);
    expect(tester.getRect(pinnedSearch).top, 24);
    final pinnedSearchRect = tester.getRect(search);
    expect(tester.getRect(pinnedSearch).height, 76);
    expect(pinnedSearchRect.top, 30);
    expect(pinnedSearchRect.height, 64);
    expect(tester.getRect(filters).top, 100);
    expect(tester.getRect(statusBar).top, 0);

    await tester.drag(scrollView, const Offset(0, -50));
    await tester.pumpAndSettle();

    expect(tester.getRect(search), pinnedSearchRect);
    expect(tester.getRect(filters).top, 100);
  });
}
