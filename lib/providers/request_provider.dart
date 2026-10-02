// lib/providers/request_provider.dart
import 'package:flutter/material.dart';
import '../models/borrow_request_model.dart';
import '../models/equipment_model.dart';
import 'equipment_provider.dart';

/// Manages the in-memory list of borrow requests.
///
/// ALL status-changing logic lives in this single provider (specifically in
/// [updateRequestStatus]) rather than being scattered across screens, so
/// swapping this out for real Firebase logic later only requires touching
/// this file.
class RequestProvider extends ChangeNotifier {
  EquipmentProvider _equipmentProvider;

  RequestProvider(this._equipmentProvider) {
    _seedMockRequests();
  }

  /// Called by the ProxyProvider whenever EquipmentProvider rebuilds.
  void updateEquipmentProvider(EquipmentProvider equipmentProvider) {
    _equipmentProvider = equipmentProvider;
  }

  final List<BorrowRequestModel> _requests = [];

  void _seedMockRequests() {
    final now = DateTime.now();
    _requests.addAll([
      BorrowRequestModel(
        id: 'r1',
        studentOrFacultyId: 'u1',
        equipmentId: 'EQ-003',
        requestedBorrowDate: DateTime(now.year, 8, 19),
        requestedReturnDate: DateTime(now.year, 8, 23),
        requestDate: now.subtract(const Duration(days: 2)),
        status: RequestStatus.pending,
      ),
      BorrowRequestModel(
        id: 'r2',
        studentOrFacultyId: 'u1',
        equipmentId: 'EQ-007',
        requestedBorrowDate: DateTime(now.year, 9, 1),
        requestedReturnDate: DateTime(now.year, 9, 3),
        requestDate: now.subtract(const Duration(days: 1)),
        status: RequestStatus.pending,
      ),
      BorrowRequestModel(
        id: 'r3',
        studentOrFacultyId: 'u1',
        equipmentId: 'EQ-001',
        requestedBorrowDate: DateTime(now.year, 8, 10),
        requestedReturnDate: DateTime(now.year, 8, 15),
        requestDate: now.subtract(const Duration(days: 10)),
        approvedDate: now.subtract(const Duration(days: 9)),
        status: RequestStatus.approved,
      ),
      BorrowRequestModel(
        id: 'r4',
        studentOrFacultyId: 'u1',
        equipmentId: 'EQ-002',
        requestedBorrowDate: DateTime(now.year, 8, 5),
        requestedReturnDate: now.add(const Duration(days: 2)),
        requestDate: now.subtract(const Duration(days: 14)),
        approvedDate: now.subtract(const Duration(days: 13)),
        checkedOutDate: now.subtract(const Duration(days: 12)),
        status: RequestStatus.borrowed,
      ),
      BorrowRequestModel(
        id: 'r5',
        studentOrFacultyId: 'u1',
        equipmentId: 'EQ-004',
        requestedBorrowDate: DateTime(now.year, 7, 20),
        requestedReturnDate: DateTime(now.year, 7, 22),
        requestDate: now.subtract(const Duration(days: 20)),
        status: RequestStatus.rejected,
      ),
      BorrowRequestModel(
        id: 'r6',
        studentOrFacultyId: 'u1',
        equipmentId: 'EQ-005',
        requestedBorrowDate: DateTime(now.year, 7, 1),
        requestedReturnDate: DateTime(now.year, 7, 3),
        requestDate: now.subtract(const Duration(days: 30)),
        approvedDate: now.subtract(const Duration(days: 29)),
        checkedOutDate: now.subtract(const Duration(days: 28)),
        returnedDate: now.subtract(const Duration(days: 25)),
        status: RequestStatus.returned,
      ),
    ]);
  }

  List<BorrowRequestModel> requestsForUser(String userId) =>
      _requests.where((r) => r.studentOrFacultyId == userId).toList();

  List<BorrowRequestModel> activeRequests(String userId) => requestsForUser(userId)
      .where((r) => r.status == RequestStatus.approved || r.status == RequestStatus.borrowed)
      .toList();

  List<BorrowRequestModel> pendingRequests(String userId) => requestsForUser(userId)
      .where((r) => r.status == RequestStatus.pending)
      .toList();

  List<BorrowRequestModel> historyRequests(String userId) => requestsForUser(userId)
      .where((r) =>
          r.status == RequestStatus.rejected ||
          r.status == RequestStatus.returned ||
          r.status == RequestStatus.cancelled)
      .toList();

  /// Requests that have actually been picked up at some point (Borrowed or
  /// Returned), most recent first — used for the "Recent Borrowings" list.
  List<BorrowRequestModel> recentBorrowings(String userId, {int limit = 5}) {
    final list = requestsForUser(userId)
        .where((r) => r.status == RequestStatus.borrowed || r.status == RequestStatus.returned)
        .toList()
      ..sort((a, b) {
        final aDate = a.returnedDate ?? a.checkedOutDate ?? a.requestDate;
        final bDate = b.returnedDate ?? b.checkedOutDate ?? b.requestDate;
        return bDate.compareTo(aDate);
      });
    return list.take(limit).toList();
  }

  // ----- Borrowing summary counts (used on the Profile screen) -----

  int totalBorrowedCount(String userId) => requestsForUser(userId)
      .where((r) => r.status == RequestStatus.borrowed || r.status == RequestStatus.returned)
      .length;

  int currentBorrowedCount(String userId) =>
      requestsForUser(userId).where((r) => r.status == RequestStatus.borrowed).length;

  int returnedCount(String userId) =>
      requestsForUser(userId).where((r) => r.status == RequestStatus.returned).length;

  /// Items currently borrowed with a return date within the next 3 days
  /// (including already-overdue items).
  int dueSoonCount(String userId) {
    final now = DateTime.now();
    return requestsForUser(userId).where((r) {
      if (r.status != RequestStatus.borrowed) return false;
      return r.requestedReturnDate.difference(now).inDays <= 3;
    }).length;
  }

  /// Submits a new borrow request. Equipment stays "Available" until the
  /// request is Approved — per the system's lifecycle rules.
  void submitRequest({
    required String userId,
    required String equipmentId,
    required DateTime borrowDate,
    required DateTime returnDate,
  }) {
    _requests.add(BorrowRequestModel(
      id: 'r${_requests.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
      studentOrFacultyId: userId,
      equipmentId: equipmentId,
      requestedBorrowDate: borrowDate,
      requestedReturnDate: returnDate,
      requestDate: DateTime.now(),
      status: RequestStatus.pending,
    ));
    notifyListeners();
  }

  /// SINGLE source of truth for every status transition in the app.
  /// Keeps the linked equipment's status in sync automatically:
  ///   pending  -> approved   : equipment becomes Reserved
  ///   pending  -> rejected   : equipment stays Available
  ///   pending  -> cancelled  : equipment stays Available
  ///   approved -> borrowed   : equipment becomes Borrowed (checked out)
  ///   borrowed -> returned   : equipment becomes Available again
  void updateRequestStatus(String requestId, RequestStatus newStatus) {
    final request = _requests.firstWhere((r) => r.id == requestId);
    final now = DateTime.now();

    switch (newStatus) {
      case RequestStatus.approved:
        request.approvedDate = now;
        _equipmentProvider.setStatus(request.equipmentId, EquipmentStatus.reserved);
        break;
      case RequestStatus.rejected:
        // No equipment change — it was never reserved.
        break;
      case RequestStatus.cancelled:
        // No equipment change — cancelling before approval.
        break;
      case RequestStatus.borrowed:
        request.checkedOutDate = now;
        _equipmentProvider.setStatus(request.equipmentId, EquipmentStatus.borrowed);
        break;
      case RequestStatus.returned:
        request.returnedDate = now;
        _equipmentProvider.setStatus(request.equipmentId, EquipmentStatus.available);
        break;
      case RequestStatus.pending:
        break; // requests always start pending; not re-entered here
    }

    request.status = newStatus;
    notifyListeners();
  }

  /// Mock admin approval simulation — represents the decision that, in the
  /// real system, is made on the separate admin web platform.
  void simulateAdminApproval(String requestId, bool approve) {
    updateRequestStatus(requestId, approve ? RequestStatus.approved : RequestStatus.rejected);
  }

  void cancelRequest(String requestId) {
    updateRequestStatus(requestId, RequestStatus.cancelled);
  }

  /// TEMPORARY manual check-out (no camera scan yet).
  /// Replace with real QR-validated check-out once the QR flow is finalized.
  void checkOut(String requestId) {
    updateRequestStatus(requestId, RequestStatus.borrowed);
  }

  /// TEMPORARY manual check-in / report-return (no camera scan yet).
  /// Replace with real QR-validated check-in once the QR flow is finalized.
  void reportReturn(String requestId) {
    updateRequestStatus(requestId, RequestStatus.returned);
  }
}