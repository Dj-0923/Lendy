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

    expect(tester.getSize(find.byType(Image)).height, 140);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    expect(
      tester.widget<StatusBadge>(find.byType(StatusBadge)).compact,
      isTrue,
    );
  });

  testWidgets('item code is aligned to the right edge of the card', (
    tester,
  ) async {
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
    final codeRow = find.ancestor(of: code, matching: find.byType(Row)).first;

    expect(
      tester.getRect(code).right,
      closeTo(tester.getRect(codeRow).right, 1),
    );
  });
}
