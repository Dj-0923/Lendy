import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/borrow_request_model.dart';
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
    await requests.submitRequest(
      userId: userId,
      equipmentId: 'equipment-1',
      equipmentName: 'Equipment',
      borrowerName: 'Test User',
      borrowDate: DateTime.now(),
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
      expect(requests.dueSoonCount(userId), 0);
      expect(requests.totalBorrowedCount(userId), 3);
      expect(requests.currentBorrowedCount(userId), 1);
      expect(requests.returnedCount(userId), 2);
    },
  );

  test('recent borrowings returns only the three latest activities', () async {
    const userId = 'user-2';
    final returnDate = DateTime.now().add(const Duration(days: 30));
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

      expect(requests.activeRequests('borrower-1'), hasLength(1));
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

  test('history includes approved, rejected, and completed requests', () async {
    const userId = 'history-user';
    final requestIds = <String>[];
    for (var i = 0; i < 5; i++) {
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
    userRequests[4].status = RequestStatus.pending;

    expect(
      requests.historyRequests(userId).map((request) => request.id),
      requestIds.take(4),
    );
  });
}
