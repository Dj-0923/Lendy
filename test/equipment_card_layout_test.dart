import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/theme/app_colors.dart';
import 'package:lendy/widgets/equipment_card.dart';
import 'package:lendy/widgets/status_badge.dart';

void main() {
  test('equipment model reads optional brand and details fields', () {
    final equipment = EquipmentModel.fromFirestore(
      documentId: 'EQ-014',
      data: {
        'name': 'Aula Keyboard',
        'category': 'Input Devices',
        'tag': 'KB-001',
        'brand': 'Aula',
        'details': 'Mechanical keyboard',
        'location': 'Storage Room',
      },
      status: EquipmentStatus.available,
    );

    expect(equipment.brand, 'Aula');
    expect(equipment.details, 'Mechanical keyboard');
  });

  test('long legacy tags use a short category-prefixed display tag', () {
    final equipment = EquipmentModel(
      id: 'EQ-014',
      name: 'Camera',
      category: EquipmentCategory.camera,
      location: 'AV Storage',
      status: EquipmentStatus.available,
      assetTag: 'LEGACY-ASSET-REFERENCE-2024',
    );

    expect(equipment.displayTag, 'CM-EQ-0');
  });

  test('valid short asset tags are preserved', () {
    final equipment = EquipmentModel(
      id: 'EQ-014',
      name: 'Camera',
      category: EquipmentCategory.camera,
      location: 'AV Storage',
      status: EquipmentStatus.available,
      assetTag: 'CM-QBTO',
    );

    expect(equipment.displayTag, 'CM-QBTO');
  });

  testWidgets('item image uses a compact card height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipmentCard(
            equipment: EquipmentModel(
              id: 'EQ-014',
              name: 'Camera',
              category: EquipmentCategory.camera,
              assetTag: 'CM-01AB',
              location: 'AV Storage',
              image: 'R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=',
              status: EquipmentStatus.available,
            ),
            onRequest: () {},
          ),
        ),
      ),
    );

    final locationIcon = tester.widget<Icon>(find.byIcon(Icons.location_on));
    expect(locationIcon.color, AppColors.primaryLight);
    expect(find.text('Tap for details'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    final viewDetailsRect = tester.getRect(
      find.byKey(const Key('equipment-card-view-details')),
    );
    final requestRect = tester.getRect(
      find.widgetWithText(ElevatedButton, 'Request'),
    );
    expect(viewDetailsRect.width, closeTo(requestRect.width, 0.1));
    expect(viewDetailsRect.height, closeTo(requestRect.height, 0.1));
    expect(tester.getSize(find.byType(Image)).height, 118);
    final codeRect = tester.getRect(find.text('CM-01AB'));
    final locationRect = tester.getRect(find.text('AV Storage'));
    expect(locationRect.top - codeRect.bottom, lessThan(50));
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    final statusBadge = find.byType(StatusBadge);
    expect(tester.widget<StatusBadge>(statusBadge).compact, isTrue);
    final badgeText = find.descendant(
      of: statusBadge,
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(badgeText).style?.fontSize, 9);
    final badgeContainer = tester.widget<Container>(
      find.byKey(const Key('status-badge-container')),
    );
    expect(
      badgeContainer.padding,
      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    );
    final imageRect = tester.getRect(find.byType(Image));
    final cardRect = tester.getRect(
      find.byKey(const ValueKey('equipment-card-EQ-014')),
    );
    expect(imageRect.left, closeTo(cardRect.left + 1, 1));
    expect(imageRect.right, closeTo(cardRect.right - 1, 1));
    expect(imageRect.top, closeTo(cardRect.top + 1, 1));
    expect(
      tester
          .widget<ClipRRect>(find.byKey(const Key('equipment-card-image-clip')))
          .borderRadius,
      const BorderRadius.vertical(top: Radius.circular(13)),
    );
    final badgeContainerFinder = find.byKey(
      const Key('status-badge-container'),
    );
    final badgeRect = tester.getRect(badgeContainerFinder);
    expect(badgeRect.top, greaterThanOrEqualTo(imageRect.top));
    expect(badgeRect.right, closeTo(imageRect.right - 8, 1));
  });

  testWidgets('status badge stays on one line in a narrow card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 112,
              child: EquipmentCard(
                equipment: EquipmentModel(
                  id: 'EQ-017',
                  name: 'Projector',
                  category: EquipmentCategory.projector,
                  location: 'AV Storage',
                  status: EquipmentStatus.maintenance,
                ),
                onRequest: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final badgeText = find.descendant(
      of: find.byType(StatusBadge),
      matching: find.byType(Text),
    );
    expect(tester.getSize(badgeText).height, lessThan(14));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an item opens its details and request action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var requested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: EquipmentCard(
                equipment: EquipmentModel(
                  id: 'EQ-001',
                  name: 'Aula Keyboard',
                  category: EquipmentCategory.accessories,
                  categoryName: 'Input Devices',
                  assetTag: 'KB-001',
                  brand: 'Aula',
                  details:
                      'A high-performance mechanical keyboard with responsive keys.',
                  location: 'Storage Room',
                  image: 'R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=',
                  status: EquipmentStatus.available,
                ),
                onRequest: () => requested = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('equipment-card-view-details')));
    await tester.pumpAndSettle();

    final detailsDialog = find.byKey(const Key('equipment-details-dialog'));
    expect(detailsDialog, findsOneWidget);
    final dialog = tester.widget<Dialog>(detailsDialog);
    expect(dialog.backgroundColor, Colors.white);
    expect(dialog.surfaceTintColor, Colors.white);
    final closeBackground = tester.widget<DecoratedBox>(
      find.byKey(const Key('equipment-details-close-background')),
    );
    final closeDecoration = closeBackground.decoration as BoxDecoration;
    expect(closeDecoration.color, const Color(0xFFE4F0EC));
    expect(closeDecoration.shape, BoxShape.circle);
    expect(
      find.descendant(of: detailsDialog, matching: find.text('Input Devices')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailsDialog, matching: find.text('Aula Keyboard')),
      findsOneWidget,
    );
    expect(find.text('Tag: KB-001'), findsOneWidget);
    expect(find.text('Brand: Aula'), findsOneWidget);
    expect(
      find.text('A high-performance mechanical keyboard with responsive keys.'),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailsDialog, matching: find.text('Location')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detailsDialog, matching: find.text('Storage Room')),
      findsOneWidget,
    );

    final requestButton = find.byKey(const Key('equipment-details-request'));
    expect(
      find.descendant(of: requestButton, matching: find.byType(Icon)),
      findsNothing,
    );
    await tester.tap(requestButton);
    await tester.pumpAndSettle();

    expect(requested, isTrue);
    expect(detailsDialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request button on the item card does not open details', (
    tester,
  ) async {
    var requested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipmentCard(
            equipment: EquipmentModel(
              id: 'EQ-015',
              name: 'Projector',
              category: EquipmentCategory.projector,
              location: 'AV Storage',
              status: EquipmentStatus.available,
            ),
            onRequest: () => requested = true,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Request'));
    await tester.pumpAndSettle();

    expect(requested, isTrue);
    expect(find.byKey(const Key('equipment-details-dialog')), findsNothing);
  });

  testWidgets('selection checkbox invokes the item selection callback', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => EquipmentCard(
              equipment: EquipmentModel(
                id: 'EQ-020',
                name: 'Camera',
                category: EquipmentCategory.camera,
                location: 'AV Storage',
                status: EquipmentStatus.available,
              ),
              selectionMode: true,
              selected: selected,
              onSelect: () => setState(() => selected = !selected),
              onRequest: () {},
            ),
          ),
        ),
      ),
    );

    final checkboxRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Select Camera',
      ),
    );
    final cardRect = tester.getRect(
      find.byKey(const ValueKey('equipment-card-EQ-020')),
    );
    expect(checkboxRect.left, closeTo(cardRect.left - 6, 0.1));
    expect(checkboxRect.top, closeTo(cardRect.top - 4, 0.1));

    await tester.tap(find.byTooltip('Select Camera'));
    await tester.pump();

    expect(selected, isTrue);
    final selectedCheckboxRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Deselect Camera',
      ),
    );
    final selectedCardRect = tester.getRect(
      find.byKey(const ValueKey('equipment-card-EQ-020')),
    );
    expect(selectedCheckboxRect.left, closeTo(selectedCardRect.left - 5, 0.1));
    expect(selectedCheckboxRect.top, closeTo(selectedCardRect.top - 3, 0.1));
  });

  testWidgets('tapping item content does not open details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipmentCard(
            equipment: EquipmentModel(
              id: 'EQ-016',
              name: 'Camera',
              category: EquipmentCategory.camera,
              location: 'AV Storage',
              status: EquipmentStatus.available,
            ),
            onRequest: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('equipment-details-dialog')), findsNothing);
  });

  testWidgets('items with different optional content have equal card heights', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 170,
                    child: EquipmentCard(
                      equipment: EquipmentModel(
                        id: 'with-image',
                        name: 'A very long equipment name',
                        category: EquipmentCategory.camera,
                        categoryName: 'Custom equipment category',
                        location: 'AV Storage, Room 101',
                        image: 'R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=',
                        status: EquipmentStatus.available,
                      ),
                      onRequest: () {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 170,
                    child: EquipmentCard(
                      equipment: EquipmentModel(
                        id: 'without-image',
                        name: 'Projector',
                        category: EquipmentCategory.projector,
                        location: '',
                        status: EquipmentStatus.available,
                      ),
                      onRequest: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('equipment-card-with-image'))),
      const Size(170, 290),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('equipment-card-without-image')),
      ),
      const Size(170, 290),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('item tag is left-aligned below the item name', (tester) async {
    const cardWidth = 350.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: cardWidth,
              child: EquipmentCard(
                equipment: EquipmentModel(
                  id: 'EQ-014',
                  name: 'Camera',
                  category: EquipmentCategory.camera,
                  assetTag: 'CM-01AB',
                  location: 'AV Storage',
                  status: EquipmentStatus.available,
                ),
                onRequest: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final code = find.text('CM-01AB');
    final name = find.text('Camera');
    final category = find.text('CAMERA');

    expect(tester.getRect(code).top, greaterThan(tester.getRect(name).bottom));
    expect(tester.getRect(code).left, closeTo(tester.getRect(name).left, 1));
    expect(
      tester.getRect(name).top - tester.getRect(category).bottom,
      closeTo(2, 0.1),
    );
  });

  testWidgets('unavailable item details keep a gray disabled Request button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipmentCard(
            equipment: EquipmentModel(
              id: 'EQ-018',
              name: 'Printer',
              category: EquipmentCategory.laptop,
              location: 'AV Storage',
              status: EquipmentStatus.borrowed,
            ),
            onRequest: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('equipment-card-view-details')));
    await tester.pumpAndSettle();

    final requestButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('equipment-details-request')),
    );
    final requestLabel = find.descendant(
      of: find.byKey(const Key('equipment-details-request')),
      matching: find.text('Request'),
    );
    expect(requestLabel, findsOneWidget);
    expect(requestButton.onPressed, isNull);
    expect(
      requestButton.style?.backgroundColor?.resolve({}),
      const Color(0xFFE0E0E0),
    );
  });

  testWidgets('requested item shows a disabled Requested button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipmentCard(
            equipment: EquipmentModel(
              id: 'EQ-015',
              name: 'Projector',
              category: EquipmentCategory.projector,
              location: 'AV Storage',
              status: EquipmentStatus.available,
            ),
            requested: true,
            onRequest: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(find.text('Requested'), findsOneWidget);
    expect(button.onPressed, isNull);
  });

  testWidgets('unavailable items keep a gray disabled Request button', (
    tester,
  ) async {
    for (final status in [
      EquipmentStatus.reserved,
      EquipmentStatus.borrowed,
      EquipmentStatus.maintenance,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquipmentCard(
              equipment: EquipmentModel(
                id: 'EQ-016',
                name: 'Projector',
                category: EquipmentCategory.projector,
                location: 'AV Storage',
                status: status,
              ),
              onRequest: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(find.text('Request'), findsOneWidget);
      expect(find.text(status.label.toUpperCase()), findsOneWidget);
      expect(button.onPressed, isNull);
      expect(
        button.style?.backgroundColor?.resolve({}),
        const Color(0xFFE0E0E0),
      );
    }
  });
}
