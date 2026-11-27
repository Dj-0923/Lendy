import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/borrow_request_model.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/providers/request_provider.dart';

void main() {
  late EquipmentProvider equipment;
  late RequestProvider requests;

  setUp(() {
    equipment = EquipmentProvider();
    requests = RequestProvider(equipment);
  });

  tearDown(() {
    requests.dispose();
  });

  Future<String> addBorrowing({
    required String userId,
    required DateTime returnDate,
  }) async {
    final now = DateTime.now();
    final borrowDate = returnDate.isBefore(now)
        ? returnDate.subtract(const Duration(days: 4))
        : now;
    await requests.submitRequest(
      userId: userId,
      equipmentId: 'equipment-1',
      equipmentName: 'Equipment',
      borrowerName: 'Test User',
      borrowDate: borrowDate,
      returnDate: returnDate,
    );
    final id = requests.requestsForUser(userId).last.id;
    await requests.checkOut(id);
    return id;
  }

  test(
    'summary counts loans and excludes overdue items from due soon',
    () async {
      const userId = 'user-1';
      final today = DateTime.now();
      final overdueId = await addBorrowing(
        userId: userId,
        returnDate: today.subtract(const Duration(days: 1)),
      );
      final soonId = await addBorrowing(
        userId: userId,
        returnDate: today.add(const Duration(days: 2)),
      );
      await addBorrowing(
        userId: userId,
        returnDate: today.add(const Duration(days: 5)),
      );

      expect(requests.dueSoonCount(userId), 1);
      expect(requests.totalBorrowedCount(userId), 3);
      expect(requests.currentBorrowedCount(userId), 3);
      expect(requests.returnedCount(userId), 0);

      await requests.reportReturn(overdueId);
      expect(requests.dueSoonCount(userId), 1);

      await requests.reportReturn(soonId);
      expect(requests.dueSoonCount(userId), 1);
      expect(requests.totalBorrowedCount(userId), 3);
      expect(requests.currentBorrowedCount(userId), 3);
      expect(requests.returnedCount(userId), 0);
      expect(
        requests
            .requestsForUser(userId)
            .where((request) => request.status == RequestStatus.returnPending),
        hasLength(2),
      );
    },
  );

  test('recent borrowings returns only the three latest activities', () async {
    const userId = 'user-2';
    final returnDate = DateTime.now().add(const Duration(days: 10));
    final ids = <String>[];

    for (var i = 0; i < 4; i++) {
      ids.add(await addBorrowing(userId: userId, returnDate: returnDate));
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await requests.reportReturn(ids.first);

    expect(requests.recentBorrowings(userId).map((request) => request.id), [
      ids.first,
      ids[3],
      ids[2],
    ]);
  });

  test(
    'borrowing records belong only to the user who submitted them',
    () async {
      await requests.submitRequest(
        userId: 'borrower-1',
        equipmentId: 'equipment-1',
        equipmentName: 'Equipment',
        borrowerName: 'First Borrower',
        borrowDate: DateTime.now(),
        returnDate: DateTime.now().add(const Duration(days: 3)),
      );
      final requestId = requests.requestsForUser('borrower-1').single.id;
      await requests.checkOut(requestId);

      expect(requests.activeRequests('borrower-1'), isEmpty);
      expect(requests.readyToReturnRequests('borrower-1'), hasLength(1));
      expect(
        requests.activeRequests('borrower-2'),
        isEmpty,
        reason:
            'Other users see shared item availability, not this loan record.',
      );
      expect(
        requests.requestsForUser('borrower-1').single.studentOrFacultyId,
        'borrower-1',
      );
    },
  );

  test('a user can only submit one pending request per item', () async {
    Future<void> submit(String equipmentId) => requests.submitRequest(
      userId: 'requester',
      equipmentId: equipmentId,
      equipmentName: 'Equipment',
      borrowerName: 'Test User',
      borrowDate: DateTime.now(),
      returnDate: DateTime.now().add(const Duration(days: 3)),
    );

    await submit('equipment-1');

    expect(requests.hasPendingRequest('requester', 'equipment-1'), isTrue);
    await expectLater(submit('equipment-1'), throwsA(isA<StateError>()));
    await submit('equipment-2');

    expect(requests.requestsForUser('requester'), hasLength(2));
  });

  test('day-based loan requests cannot exceed 14 days', () async {
    final borrowDate = DateTime(2026, 11, 26);
    await requests.submitRequest(
      userId: 'two-week-user',
      equipmentId: 'equipment-14-days',
      equipmentName: 'Equipment',
      borrowerName: 'Test User',
      borrowDate: borrowDate,
      returnDate: borrowDate.add(const Duration(days: 14)),
    );

    await expectLater(
      requests.submitRequest(
        userId: 'two-week-user',
        equipmentId: 'equipment-too-long',
        equipmentName: 'Equipment',
        borrowerName: 'Test User',
        borrowDate: borrowDate,
        returnDate: borrowDate.add(const Duration(days: 15)),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(requests.requestsForUser('two-week-user'), hasLength(1));
  });

  test('hour-based loan requests preserve their selected times', () async {
    final borrowDate = DateTime(2026, 11, 26, 9);
    final returnDate = DateTime(2026, 11, 26, 11, 30);
    await requests.submitRequest(
      userId: 'hourly-user',
      equipmentId: 'equipment-hourly',
      equipmentName: 'Equipment',
      borrowerName: 'Test User',
      borrowDate: borrowDate,
      returnDate: returnDate,
      durationType: BorrowDurationType.hours,
    );

    final request = requests.requestsForUser('hourly-user').single;
    expect(request.durationType, BorrowDurationType.hours);
    expect(request.requestedBorrowDate, borrowDate);
    expect(request.requestedReturnDate, returnDate);
  });

  test('grouped requests share dates and cancel together', () async {
    const userId = 'grouped-user';
    final borrowDate = DateTime(2026, 11, 26, 9);
    final returnDate = DateTime(2026, 11, 27, 9);
    await requests.submitGroupRequest(
      userId: userId,
      borrowerName: 'Test User',
      equipment: [
        EquipmentModel(
          id: 'group-item-1',
          name: 'Camera',
          category: EquipmentCategory.camera,
          location: 'AV Storage',
          status: EquipmentStatus.available,
        ),
        EquipmentModel(
          id: 'group-item-2',
          name: 'Tripod',
          category: EquipmentCategory.accessories,
          location: 'AV Storage',
          status: EquipmentStatus.available,
        ),
      ],
      borrowDate: borrowDate,
      returnDate: returnDate,
    );

    final group = requests.pendingRequestGroups(userId).single;
    expect(group, hasLength(2));
    expect(group.map((request) => request.equipmentId), [
      'group-item-1',
      'group-item-2',
    ]);
    expect(
      group.map((request) => request.requestGroupId).toSet(),
      hasLength(1),
    );
    expect(group.first.requestGroupId, isNotNull);
    expect(
      group.every((request) => request.requestedBorrowDate == borrowDate),
      isTrue,
    );
    expect(
      group.every((request) => request.requestedReturnDate == returnDate),
      isTrue,
    );

    await requests.cancelRequest(group.first.id);

    expect(requests.pendingRequests(userId), isEmpty);
    expect(
      requests
          .requestsForUser(userId)
          .every((request) => request.status == RequestStatus.cancelled),
      isTrue,
    );
  });

  test('rejected return count clears when the borrower resubmits', () async {
    const userId = 'return-user';
    final requestId = await addBorrowing(
      userId: userId,
      returnDate: DateTime.now().add(const Duration(days: 3)),
    );
    await requests.reportReturn(requestId);

    final request = requests.requestsForUser(userId).single;
    request
      ..status = RequestStatus.borrowed
      ..returnVerificationStatus = 'rejected'
      ..returnRejectionReason = 'Return the item to the storage room.';

    expect(requests.rejectedReturnCount(userId), 1);
    expect(requests.rejectedReturnCount('another-user'), 0);

    await requests.reportReturn(requestId);
    expect(requests.rejectedReturnCount(userId), 0);
  });

  test('viewing Loans clears the rejected return badge', () async {
    const userId = 'return-user';
    final requestId = await addBorrowing(
      userId: userId,
      returnDate: DateTime.now().add(const Duration(days: 3)),
    );
    await requests.reportReturn(requestId);

    final request = requests.requestsForUser(userId).single
      ..status = RequestStatus.borrowed
      ..returnVerificationStatus = 'rejected'
      ..returnRejectionReason = 'Return the item to the storage room.';

    expect(requests.rejectedReturnCount(userId), 1);

    await requests.markRejectedReturnsSeen(userId);

    expect(requests.rejectedReturnCount(userId), 0);
    expect(request.returnRejectionSeen, isTrue);
  });

  test(
    'active, ready-to-return, and history requests stay separate',
    () async {
      const userId = 'history-user';
      final requestIds = <String>[];
      for (var i = 0; i < 7; i++) {
        await requests.submitRequest(
          userId: userId,
          equipmentId: 'equipment-$i',
          equipmentName: 'Equipment $i',
          borrowerName: 'Test User',
          borrowDate: DateTime.now(),
          returnDate: DateTime.now().add(const Duration(days: 3)),
        );
        requestIds.add(requests.requestsForUser(userId).last.id);
      }

      final userRequests = requests.requestsForUser(userId);
      userRequests[0].status = RequestStatus.approved;
      userRequests[1].status = RequestStatus.rejected;
      userRequests[2].status = RequestStatus.borrowed;
      userRequests[3].status = RequestStatus.returned;
      userRequests[4].status = RequestStatus.cancelled;
      userRequests[5].status = RequestStatus.returnPending;
      userRequests[6]
        ..status = RequestStatus.borrowed
        ..returnVerificationStatus = 'rejected';

      expect(requests.historyRequests(userId).map((request) => request.id), [
        requestIds[1],
        requestIds[3],
        requestIds[4],
      ]);
      expect(requests.activeRequests(userId).map((request) => request.id), [
        requestIds[0],
        requestIds[5],
      ]);
      expect(
        requests.readyToReturnRequests(userId).map((request) => request.id),
        [requestIds[2], requestIds[6]],
      );
    },
  );
}
