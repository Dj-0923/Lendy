// lib/providers/request_provider.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/borrow_request_model.dart';
import '../models/equipment_model.dart';
import 'equipment_provider.dart';

/// Streams borrower requests from the same Firestore collection used by admin.
class RequestProvider extends ChangeNotifier {
  RequestProvider(this._equipmentProvider, {FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  EquipmentProvider _equipmentProvider;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestSubscription;
  String? _userId;
  String? _errorMessage;

  /// Called by the ProxyProviders whenever a dependency changes.
  void updateEquipmentProvider(EquipmentProvider equipmentProvider) {
    _equipmentProvider = equipmentProvider;
  }

  String? get errorMessage => _errorMessage;

  final List<BorrowRequestModel> _requests = [];

  void updateAuthentication({required String? userId}) {
    if (_userId == userId) return;

    _userId = userId;
    _requestSubscription?.cancel();
    _requestSubscription = null;
    _requests.clear();
    _errorMessage = null;

    if (userId != null && _firestore != null) {
      _requestSubscription = _firestore
          .collection('loans')
          .where('borrowerUid', isEqualTo: userId)
          .snapshots()
          .listen(
            (snapshot) {
              try {
                final requests = snapshot.docs
                    .map(_requestFromDocument)
                    .toList();
                _requests
                  ..clear()
                  ..addAll(requests);
                _errorMessage = null;
              } on FormatException catch (error) {
                _errorMessage = 'Could not read your loan data: $error';
              } on TypeError catch (error) {
                _errorMessage = 'Could not read your loan data: $error';
              }
              notifyListeners();
            },
            onError: (Object error) {
              _errorMessage = 'Could not load your requests: $error';
              notifyListeners();
            },
          );
    }
    notifyListeners();
  }

  List<BorrowRequestModel> requestsForUser(String userId) =>
      _requests.where((r) => r.studentOrFacultyId == userId).toList();

  List<BorrowRequestModel> activeRequests(String userId) =>
      requestsForUser(userId)
          .where(
            (r) =>
                r.status == RequestStatus.approved ||
                r.status == RequestStatus.borrowed,
          )
          .toList();

  List<BorrowRequestModel> pendingRequests(String userId) => requestsForUser(
    userId,
  ).where((r) => r.status == RequestStatus.pending).toList();

  List<BorrowRequestModel> historyRequests(String userId) =>
      requestsForUser(userId)
          .where(
            (r) =>
                r.status == RequestStatus.rejected ||
                r.status == RequestStatus.returned ||
                r.status == RequestStatus.cancelled,
          )
          .toList();

  /// Borrowed or returned items, most recent first, for the profile history.
  List<BorrowRequestModel> recentBorrowings(String userId, {int limit = 3}) {
    final list =
        requestsForUser(userId)
            .where(
              (r) =>
                  r.status == RequestStatus.approved ||
                  r.status == RequestStatus.borrowed ||
                  r.status == RequestStatus.returned,
            )
            .toList()
          ..sort((a, b) {
            return b.activityDate.compareTo(a.activityDate);
          });
    return list.take(limit).toList();
  }

  // ----- Borrowing summary counts (used on the Profile screen) -----

  int totalBorrowedCount(String userId) => requestsForUser(userId)
      .where(_isBorrowingOrReturned)
      .length;

  int currentBorrowedCount(String userId) => requestsForUser(
    userId,
  ).where(_isCurrentlyBorrowed).length;

  int returnedCount(String userId) => requestsForUser(
    userId,
  ).where((r) => r.status == RequestStatus.returned).length;

  /// Items due today or within the next two days, matching the admin summary.
  int dueSoonCount(String userId) {
    final today = DateUtils.dateOnly(DateTime.now());
    return requestsForUser(userId).where((r) {
      if (!_isCurrentlyBorrowed(r)) return false;
      final dueDate = DateUtils.dateOnly(r.requestedReturnDate);
      final daysUntilDue = dueDate.difference(today).inDays;
      return daysUntilDue >= 0 && daysUntilDue <= 2;
    }).length;
  }

  bool _isCurrentlyBorrowed(BorrowRequestModel request) =>
      request.status == RequestStatus.approved ||
      request.status == RequestStatus.borrowed;

  bool _isBorrowingOrReturned(BorrowRequestModel request) =>
      _isCurrentlyBorrowed(request) ||
      request.status == RequestStatus.returned;

  /// Submits a new borrow request. Equipment stays "Available" until the
  /// request is Approved — per the system's lifecycle rules.
  Future<void> submitRequest({
    required String userId,
    required String equipmentId,
    required String equipmentName,
    required String borrowerName,
    required DateTime borrowDate,
    required DateTime returnDate,
  }) async {
    final now = DateTime.now();
    if (_firestore == null) {
      _requests.add(
        BorrowRequestModel(
          id: 'r${_requests.length + 1}_${now.millisecondsSinceEpoch}',
          studentOrFacultyId: userId,
          borrowerName: borrowerName,
          equipmentId: equipmentId,
          requestedBorrowDate: borrowDate,
          requestedReturnDate: returnDate,
          requestDate: now,
          status: RequestStatus.pending,
        ),
      );
      notifyListeners();
      return;
    }

    final document = _firestore.collection('loans').doc();
    await document.set({
      'id': document.id,
      'borrowerUid': userId,
      'equipmentId': equipmentId,
      'name': equipmentName,
      'borrower': borrowerName,
      'start': _dateOnly(borrowDate),
      'end': _dateOnly(returnDate),
      'status': 'pending',
      'returnedOn': null,
      'updatedAt': now.millisecondsSinceEpoch,
    });
  }

  Future<void> checkOut(String requestId) async {
    final request = _requests.firstWhere((r) => r.id == requestId);
    final now = DateTime.now();

    if (_firestore != null) {
      await _firestore.collection('loans').doc(requestId).update({
        'checkedOutAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
    } else {
      request.status = RequestStatus.borrowed;
      request.checkedOutDate = now;
      request.activityDate = now;
      _equipmentProvider.setStatus(
        request.equipmentId,
        EquipmentStatus.borrowed,
      );
      notifyListeners();
    }
  }

  Future<void> cancelRequest(String requestId) async {
    final request = _requests.firstWhere((r) => r.id == requestId);
    if (_firestore != null) {
      await _firestore.collection('loans').doc(requestId).update({
        'status': 'cancelled',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      request.status = RequestStatus.cancelled;
      notifyListeners();
    }
  }

  Future<void> reportReturn(String requestId) async {
    final request = _requests.firstWhere((r) => r.id == requestId);
    final now = DateTime.now();
    if (_firestore != null) {
      await _firestore.collection('loans').doc(requestId).update({
        'status': 'returned',
        'returnedOn': _dateOnly(now),
        'updatedAt': now.millisecondsSinceEpoch,
      });
    } else {
      request.status = RequestStatus.returned;
      request.returnedDate = now;
      request.activityDate = now;
      _equipmentProvider.setStatus(
        request.equipmentId,
        EquipmentStatus.available,
      );
      notifyListeners();
    }
  }

  BorrowRequestModel _requestFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final status = switch (data['status']) {
      'pending' => RequestStatus.pending,
      'approved' when data['checkedOutAt'] is int => RequestStatus.borrowed,
      'approved' => RequestStatus.approved,
      'rejected' => RequestStatus.rejected,
      'returned' => RequestStatus.returned,
      'cancelled' => RequestStatus.cancelled,
      final value => throw FormatException('Unknown loan status: $value'),
    };
    return BorrowRequestModel(
      id: document.id,
      studentOrFacultyId: data['borrowerUid'] as String,
      borrowerName: data['borrower'] as String? ?? '',
      equipmentId: data['equipmentId'] as String,
      requestedBorrowDate: DateTime.parse(data['start'] as String),
      requestedReturnDate: DateTime.parse(data['end'] as String),
      requestDate: DateTime.fromMillisecondsSinceEpoch(
        data['updatedAt'] as int? ?? 0,
      ),
      activityDate: DateTime.fromMillisecondsSinceEpoch(
        data['updatedAt'] as int? ?? 0,
      ),
      checkedOutDate: data['checkedOutAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['checkedOutAt'] as int)
          : null,
      returnedDate: data['returnedOn'] is String
          ? DateTime.tryParse(data['returnedOn'] as String)
          : null,
      status: status,
    );
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }
}
