import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/borrow_request_model.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/theme/app_colors.dart';
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

    final locationIcon = tester.widget<Icon>(find.byIcon(Icons.location_on));
    expect(locationIcon.color, AppColors.primaryLight);
    expect(find.text('Storage Room'), findsOneWidget);
  });

  testWidgets('returned history card displays user and Admin timestamps', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 13);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestCard(
            request: BorrowRequestModel(
              id: 'loan-2',
              studentOrFacultyId: 'user-1',
              borrowerName: 'Test User',
              equipmentId: 'EQ-014',
              requestedBorrowDate: now,
              requestedReturnDate: now.add(const Duration(days: 3)),
              requestDate: now,
              status: RequestStatus.returned,
              returnRequestedAt: DateTime(2026, 11, 16, 9, 5),
              returnVerifiedAt: DateTime(2026, 11, 16, 10, 30),
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

    expect(
      find.text('Return reported: November 16, 2026 at 9:05 AM'),
      findsOneWidget,
    );
    expect(
      find.text('Verified by Admin: November 16, 2026 at 10:30 AM'),
      findsOneWidget,
    );
  });

  testWidgets('overdue borrowed card is styled red', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestCard(
            request: BorrowRequestModel(
              id: 'loan-3',
              studentOrFacultyId: 'user-1',
              borrowerName: 'Test User',
              equipmentId: 'EQ-014',
              requestedBorrowDate: today.subtract(const Duration(days: 5)),
              requestedReturnDate: today.subtract(const Duration(days: 1)),
              requestDate: today,
              status: RequestStatus.borrowed,
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

    final card = tester.widget<Container>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).border != null,
          )
          .first,
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFFEBEE));
    expect((decoration.border! as Border).top.color, AppColors.danger);
  });
}
