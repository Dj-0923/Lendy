import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/widgets/equipment_card.dart';
import 'package:lendy/widgets/status_badge.dart';

void main() {
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

    expect(tester.getSize(find.byType(Image)).height, 110);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    final statusBadge = find.byType(StatusBadge);
    expect(tester.widget<StatusBadge>(statusBadge).compact, isTrue);
    final badgeText = find.descendant(
      of: statusBadge,
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(badgeText).style?.fontSize, 9);
    final badgeContainer = tester.widget<Container>(
      find.descendant(of: statusBadge, matching: find.byType(Container)),
    );
    expect(
      badgeContainer.padding,
      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
    final imageRect = tester.getRect(find.byType(Image));
    final badgeContainerFinder = find.descendant(
      of: find.byType(StatusBadge),
      matching: find.byType(Container),
    );
    final badgeRect = tester.getRect(badgeContainerFinder);
    expect(badgeRect.top, greaterThanOrEqualTo(imageRect.top));
    expect(badgeRect.right, closeTo(imageRect.right - 8, 1));
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
      const Size(170, 350),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('equipment-card-without-image')),
      ),
      const Size(170, 350),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('item code is left-aligned below the item name', (tester) async {
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

    expect(tester.getRect(code).top, greaterThan(tester.getRect(name).bottom));
    expect(tester.getRect(code).left, closeTo(tester.getRect(name).left, 1));
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
}
