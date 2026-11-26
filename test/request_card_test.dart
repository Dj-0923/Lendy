import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/borrow_request_model.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/theme/app_colors.dart';
import 'package:lendy/widgets/request_card.dart';

void main() {
  testWidgets('grouped pending request presents one cancel action', (
    tester,
  ) async {
    final requestDate = DateTime(2026, 11, 26);
    final group = [
      for (final item in ['EQ-014', 'EQ-015'])
        BorrowRequestModel(
          id: 'loan-$item',
          studentOrFacultyId: 'user-1',
          borrowerName: 'Test User',
          equipmentId: item,
          requestGroupId: 'request-group-1',
          requestedBorrowDate: requestDate,
          requestedReturnDate: requestDate.add(const Duration(days: 3)),
          requestDate: requestDate,
        ),
    ];
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupedRequestCard(
            requests: group,
            equipments: [
              EquipmentModel(
                id: 'EQ-014',
                name: 'Projector',
                category: EquipmentCategory.projector,
                assetTag: 'PJ-014',
                location: 'AV Storage',
                status: EquipmentStatus.available,
              ),
              EquipmentModel(
                id: 'EQ-015',
                name: 'Tripod',
                category: EquipmentCategory.camera,
                assetTag: 'CM-015',
                location: 'AV Storage',
                status: EquipmentStatus.available,
              ),
            ],
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    expect(find.text('2 items requested'), findsOneWidget);
    expect(find.text('Projector'), findsOneWidget);
    expect(find.text('Tripod'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);

    await tester.tap(find.text('Cancel request'));
    expect(cancelled, isTrue);
  });

  testWidgets('approved hourly loan shows times and borrowing reminders', (
    tester,
  ) async {
    final borrowDate = DateTime(2026, 11, 13, 9);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestCard(
            request: BorrowRequestModel(
              id: 'loan-hours',
              studentOrFacultyId: 'user-1',
              borrowerName: 'Test User',
              equipmentId: 'EQ-014',
              requestedBorrowDate: borrowDate,
              requestedReturnDate: DateTime(2026, 11, 13, 10, 30),
              durationType: BorrowDurationType.hours,
              requestDate: borrowDate,
              status: RequestStatus.approved,
            ),
            equipment: EquipmentModel(
              id: 'EQ-014',
              name: 'Projector',
              category: EquipmentCategory.projector,
              location: 'Storage Room',
              status: EquipmentStatus.reserved,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nov 13 · 9:00 AM – Nov 13 · 10:30 AM'), findsOneWidget);
    expect(find.text('Do not take borrowed items home.'), findsOneWidget);
    expect(
      find.text(
        'Borrowers are responsible for repair or replacement costs for lost '
        'or damaged items.',
      ),
      findsOneWidget,
    );
  });

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
              assetTag: 'PJ-OY3I',
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
    expect(find.text('PJ-OY3I'), findsOneWidget);
    expect(find.text('EQ-014'), findsNothing);
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
