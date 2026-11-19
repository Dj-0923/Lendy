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
import 'package:lendy/screens/borrower_assistant_screen.dart';
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
    tester.view.physicalSize = const Size(470, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpBrowse(tester);

    expect(find.byKey(const Key('browse-search-field')), findsOneWidget);
    expect(find.byKey(const Key('browse-ai-assistant-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI assistant button opens the borrower assistant', (
    tester,
  ) async {
    await pumpBrowse(tester);

    final assistantButton = find.byKey(const Key('browse-ai-assistant-button'));
    expect(assistantButton, findsOneWidget);
    expect(tester.getSize(assistantButton), const Size(64, 64));
    final assistantButtonMaterial = tester.widget<Material>(assistantButton);
    expect(assistantButtonMaterial.color, Colors.white);
    expect(assistantButtonMaterial.elevation, 2);
    expect(find.text('ASK ME'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    final fabiiDecoration = find.byKey(const Key('browse-fabii-decoration'));
    expect(fabiiDecoration, findsOneWidget);
    final decorationPointerGuard = tester.widget<IgnorePointer>(
      find
          .ancestor(of: fabiiDecoration, matching: find.byType(IgnorePointer))
          .first,
    );
    expect(decorationPointerGuard.ignoring, isTrue);
    await tester.tap(assistantButton);
    await tester.pumpAndSettle();

    expect(find.text('Fabii'), findsOneWidget);
    expect(find.text('your AI assistant'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    final assistantHeaderAvatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('assistant-header-avatar')),
    );
    expect(
      assistantHeaderAvatar.backgroundImage,
      const AssetImage('assets/images/botpfp.png'),
    );
    final titleRect = tester.getRect(find.text('Fabii'));
    final subtitleRect = tester.getRect(find.text('your AI assistant'));
    expect(subtitleRect.top - titleRect.bottom, lessThanOrEqualTo(2));
    expect(find.byKey(const Key('assistant-online-indicator')), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).titleSpacing, 0);
    expect(find.textContaining('You can ask me in English'), findsOneWidget);
  });

  testWidgets(
    'three home AI suggestions stay above search and open a question',
    (tester) async {
      await pumpBrowse(tester);

      final suggestion = find.byKey(const Key('browse-ai-suggestion-0'));
      final search = find.byKey(const Key('browse-search-field'));
      expect(suggestion, findsOneWidget);
      expect(
        tester.getBottomLeft(suggestion).dy,
        lessThanOrEqualTo(tester.getTopLeft(search).dy),
      );
      expect(find.text('Available items?'), findsOneWidget);
      expect(find.text('Camera to borrow?'), findsOneWidget);
      expect(find.text('Request status?'), findsOneWidget);
      expect(find.byKey(const Key('browse-ai-suggestion-3')), findsNothing);

      await tester.tap(suggestion);
      await tester.pumpAndSettle();

      final assistant = tester.widget<BorrowerAssistantScreen>(
        find.byType(BorrowerAssistantScreen),
      );
      expect(assistant.initialQuestion, 'Available items?');
    },
  );

  testWidgets('home suggestions match the reference layout beside Fabii', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(547, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpBrowse(tester);

    final suggestions = find.byKey(const Key('browse-ai-suggestions'));
    final suggestionsRect = tester.getRect(suggestions);
    final assistantButton = find.byKey(const Key('browse-ai-assistant-button'));
    final search = find.byKey(const Key('browse-search-field'));
    final title = find.text('What do you need today?');
    final subtitle = find.text('Browse equipment or ask Fabii for help.');
    final dashboardHeader = find.byKey(const Key('dashboard-header'));
    final pinnedSearch = find.byKey(const Key('browse-pinned-search'));
    final buttonRect = tester.getRect(assistantButton);
    final searchRect = tester.getRect(search);
    final pinnedSearchRect = tester.getRect(pinnedSearch);
    final pinnedDecoration =
        tester.widget<Container>(pinnedSearch).decoration! as BoxDecoration;
    final contentClip = tester.widget<ClipRRect>(
      find.byKey(const Key('browse-pinned-search-content-clip')),
    );

    expect(pinnedSearchRect.height, 180);
    expect(
      pinnedDecoration.borderRadius,
      const BorderRadius.only(
        bottomLeft: Radius.circular(48),
        bottomRight: Radius.circular(48),
      ),
    );
    expect(contentClip.borderRadius, pinnedDecoration.borderRadius);
    expect(
      find.ancestor(
        of: assistantButton,
        matching: find.byKey(const Key('browse-pinned-search-content-clip')),
      ),
      findsNothing,
    );
    expect(buttonRect.right, 547 - 16);
    expect(buttonRect.bottom, lessThan(380));
    expect(find.byKey(const Key('browse-fabii-decoration')), findsOneWidget);
    expect(searchRect.height, 48);
    expect(searchRect.bottom, pinnedSearchRect.bottom - 40);
    expect(suggestionsRect.width, searchRect.width);
    expect(searchRect.top - suggestionsRect.bottom, 24);
    expect(title, findsOneWidget);
    expect(subtitle, findsOneWidget);
    expect(tester.getSize(dashboardHeader).height, lessThan(160));
    expect(
      tester.getTopLeft(title).dy,
      greaterThan(tester.getBottomLeft(find.text('Lendy')).dy),
    );
    expect(
      tester.getTopLeft(subtitle).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(title).dy),
    );
    expect(
      tester.getTopLeft(suggestions).dy - tester.getBottomLeft(subtitle).dy,
      lessThan(45),
    );
    for (var index = 0; index < 3; index++) {
      final suggestion = find.byKey(Key('browse-ai-suggestion-$index'));
      final rect = tester.getRect(suggestion);
      expect(rect.height, 40);
      expect(rect.width, inInclusiveRange(110, 120));
      expect(rect.left, greaterThanOrEqualTo(suggestionsRect.left));
      expect(rect.right, lessThanOrEqualTo(suggestionsRect.right + 0.01));
    }
    expect(
      (tester.getRect(find.byKey(const Key('browse-ai-suggestion-0'))).width -
              tester
                  .getRect(find.byKey(const Key('browse-ai-suggestion-2')))
                  .width)
          .abs(),
      lessThan(0.01),
    );
  });

  testWidgets('hides the home scrollbar and shows all three prompts', (
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
    expect(find.byKey(const Key('browse-ai-suggestion-0')), findsOneWidget);
    expect(find.byKey(const Key('browse-ai-suggestion-1')), findsOneWidget);
    expect(find.byKey(const Key('browse-ai-suggestion-2')), findsOneWidget);
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
    expect(find.text('Lendy'), findsOneWidget);
    expect(find.text('Browse Items'), findsNothing);
    expect(search, findsOneWidget);
    expect(tester.getSize(search).height, lessThan(50));
    expect(tester.getRect(statusBar).height, 24);
    expect(tester.getRect(header).top, 24);
    expect(
      (tester.widget<Container>(header).decoration! as BoxDecoration)
          .borderRadius,
      isNull,
    );
    expect(
      (tester.widget<Container>(pinnedSearch).decoration! as BoxDecoration)
          .borderRadius,
      const BorderRadius.only(
        bottomLeft: Radius.circular(48),
        bottomRight: Radius.circular(48),
      ),
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
    expect(tester.getRect(pinnedSearch).height, 64);
    expect(pinnedSearchRect.top, 32);
    expect(tester.getRect(filters).top, 88);
    expect(tester.getRect(statusBar).top, 0);

    await tester.drag(scrollView, const Offset(0, -50));
    await tester.pumpAndSettle();

    expect(tester.getRect(search), pinnedSearchRect);
    expect(tester.getRect(filters).top, 88);
  });
}
