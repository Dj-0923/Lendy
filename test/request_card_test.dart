import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/borrow_request_model.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/widgets/request_card.dart';

void main() {
  testWidgets('loan card displays a location icon beside the location', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 13);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestCard(
            request: BorrowRequestModel(
              id: 'loan-1',
              studentOrFacultyId: 'user-1',
              borrowerName: 'Test User',
              equipmentId: 'EQ-014',
              requestedBorrowDate: now,
              requestedReturnDate: now.add(const Duration(days: 3)),
              requestDate: now,
            ),
            equipment: EquipmentModel(
              id: 'EQ-014',
              name: 'Projector',
              category: EquipmentCategory.projector,
              location: 'Storage Room',
              status: EquipmentStatus.borrowed,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.text('Storage Room'), findsOneWidget);
  });
}
