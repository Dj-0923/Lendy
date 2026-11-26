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
  bool _loanPageVisible = false;
  final Set<String> _submittingEquipmentIds = {};
  int _localRequestGroupSequence = 0;

  /// Called by the ProxyProviders whenever a dependency changes.
  void updateEquipmentProvider(EquipmentProvider equipmentProvider) {
    _equipmentProvider = equipmentProvider;
  }

  void setLoanPageVisible(bool visible) {
    if (_loanPageVisible == visible) return;
    _loanPageVisible = visible;
    final userId = _userId;
    if (visible && userId != null) {
      unawaited(markRejectedReturnsSeen(userId));
    }
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
      // Keep each user's request history scoped to their own Firebase account.
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
                final userId = _userId;
                if (_loanPageVisible && userId != null) {
                  unawaited(markRejectedReturnsSeen(userId));
                }
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

  bool hasPendingRequest(String userId, String equipmentId) => _requests.any(
    (request) =>
        request.studentOrFacultyId == userId &&
        request.equipmentId == equipmentId &&
        request.status == RequestStatus.pending,
  );

  List<BorrowRequestModel> activeRequests(String userId) =>
      requestsForUser(userId)
          .where(
            (r) =>
                r.status == RequestStatus.approved ||
                r.status == RequestStatus.borrowed ||
                r.status == RequestStatus.returnPending,
          )
          .toList();

  List<BorrowRequestModel> pendingRequests(String userId) => requestsForUser(
    userId,
  ).where((r) => r.status == RequestStatus.pending).toList();

  List<List<BorrowRequestModel>> pendingRequestGroups(String userId) {
    final groups = <String, List<BorrowRequestModel>>{};
    for (final request in pendingRequests(userId)) {
      final key = request.requestGroupId ?? request.id;
      groups.putIfAbsent(key, () => []).add(request);
    }
    return groups.values.toList()
      ..sort((a, b) => b.first.requestDate.compareTo(a.first.requestDate));
  }

  List<BorrowRequestModel> historyRequests(String userId) =>
      requestsForUser(userId)
          .where(
            (r) =>
                r.status == RequestStatus.approved ||
                (r.status == RequestStatus.borrowed &&
                    r.returnVerificationStatus != 'rejected') ||
                r.status == RequestStatus.rejected ||
                r.status == RequestStatus.returned ||
                r.status == RequestStatus.cancelled,
          )
          .toList();

  int rejectedReturnCount(String userId) => requestsForUser(userId)
      .where(
        (request) =>
            request.status == RequestStatus.borrowed &&
            request.returnVerificationStatus == 'rejected' &&
            !request.returnRejectionSeen,
      )
      .length;

  Future<void> markRejectedReturnsSeen(String userId) async {
    final unseenRequests = requestsForUser(userId)
        .where(
          (request) =>
              request.status == RequestStatus.borrowed &&
              request.returnVerificationStatus == 'rejected' &&
              !request.returnRejectionSeen,
        )
        .toList();
    if (unseenRequests.isEmpty) return;

    final firestore = _firestore;
    if (firestore == null) {
      for (final request in unseenRequests) {
        request.returnRejectionSeen = true;
      }
      notifyListeners();
      return;
    }

    try {
      final batch = firestore.batch();
      for (final request in unseenRequests) {
        batch.update(firestore.collection('loans').doc(request.id), {
          'returnRejectionSeen': true,
        });
      }
      await batch.commit();
      for (final request in unseenRequests) {
        request.returnRejectionSeen = true;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Could not mark return rejections as seen: $error';
      notifyListeners();
    }
  }

  /// Active or returned borrowings, most recent first, for the profile history.
  List<BorrowRequestModel> recentBorrowings(String userId, {int limit = 3}) {
    final list =
        requestsForUser(userId)
            .where(
              (r) =>
                  r.status == RequestStatus.approved ||
                  r.status == RequestStatus.borrowed ||
                  r.status == RequestStatus.returnPending ||
                  r.status == RequestStatus.returned,
            )
            .toList()
          ..sort((a, b) {
            return b.activityDate.compareTo(a.activityDate);
          });
    return list.take(limit).toList();
  }

  // ----- Borrowing summary counts (used on the Profile screen) -----

  int totalBorrowedCount(String userId) =>
      requestsForUser(userId).where(_isBorrowingOrReturned).length;

  int currentBorrowedCount(String userId) =>
      requestsForUser(userId).where(_isCurrentlyBorrowed).length;

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
      request.status == RequestStatus.borrowed ||
      request.status == RequestStatus.returnPending;

  bool _isBorrowingOrReturned(BorrowRequestModel request) =>
      _isCurrentlyBorrowed(request) || request.status == RequestStatus.returned;

  /// Submits a new borrow request. Equipment stays "Available" until the
  /// request is Approved — per the system's lifecycle rules.
  Future<void> submitRequest({
    required String userId,
    required String equipmentId,
    required String equipmentName,
    required String borrowerName,
    required DateTime borrowDate,
    required DateTime returnDate,
    BorrowDurationType durationType = BorrowDurationType.days,
  }) async {
    _validateLoanPeriod(
      borrowDate: borrowDate,
      returnDate: returnDate,
      durationType: durationType,
    );

    final submissionKey = '$userId::$equipmentId';
    if (hasPendingRequest(userId, equipmentId) ||
        !_submittingEquipmentIds.add(submissionKey)) {
      throw StateError('You already have a pending request for this item.');
    }

    final now = DateTime.now();
    try {
      if (_firestore == null) {
        _requests.add(
          BorrowRequestModel(
            id: 'r${_requests.length + 1}_${now.millisecondsSinceEpoch}',
            studentOrFacultyId: userId,
            borrowerName: borrowerName,
            equipmentId: equipmentId,
            requestedBorrowDate: borrowDate,
            requestedReturnDate: returnDate,
            durationType: durationType,
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
        'startAt': borrowDate.toIso8601String(),
        'endAt': returnDate.toIso8601String(),
        'durationType': durationType.name,
        'status': 'pending',
        'returnedOn': null,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      _requests.add(
        BorrowRequestModel(
          id: document.id,
          studentOrFacultyId: userId,
          borrowerName: borrowerName,
          equipmentId: equipmentId,
          requestedBorrowDate: borrowDate,
          requestedReturnDate: returnDate,
          durationType: durationType,
          requestDate: now,
          status: RequestStatus.pending,
        ),
      );
      notifyListeners();
    } finally {
      _submittingEquipmentIds.remove(submissionKey);
    }
  }

  /// Submits one shared request for several equipment items.
  Future<void> submitGroupRequest({
    required String userId,
    required List<EquipmentModel> equipment,
    required String borrowerName,
    required DateTime borrowDate,
    required DateTime returnDate,
    BorrowDurationType durationType = BorrowDurationType.days,
  }) async {
    _validateLoanPeriod(
      borrowDate: borrowDate,
      returnDate: returnDate,
      durationType: durationType,
    );
    if (equipment.length < 2) {
      throw ArgumentError('A grouped request must contain at least two items.');
    }
    if (equipment.length > 500) {
      throw ArgumentError('A request can include up to 500 items.');
    }
    final equipmentIds = equipment.map((item) => item.id).toSet();
    if (equipmentIds.length != equipment.length) {
      throw ArgumentError('A request cannot contain the same item twice.');
    }

    final reservedKeys = <String>[];
    for (final item in equipment) {
      final key = '$userId::${item.id}';
      if (hasPendingRequest(userId, item.id) ||
          !_submittingEquipmentIds.add(key)) {
        _submittingEquipmentIds.removeAll(reservedKeys);
        throw StateError(
          'You already have a pending request for one of these items.',
        );
      }
      reservedKeys.add(key);
    }

    final now = DateTime.now();
    final groupId =
        _firestore?.collection('loans').doc().id ??
        'local_${now.microsecondsSinceEpoch}_${_localRequestGroupSequence++}';
    try {
      if (_firestore == null) {
        var localRequestNumber = _requests.length;
        _requests.addAll(
          equipment.map((item) {
            localRequestNumber++;
            return BorrowRequestModel(
              id: 'r${localRequestNumber}_${now.microsecondsSinceEpoch}',
              studentOrFacultyId: userId,
              borrowerName: borrowerName,
              equipmentId: item.id,
              requestGroupId: groupId,
              requestedBorrowDate: borrowDate,
              requestedReturnDate: returnDate,
              durationType: durationType,
              requestDate: now,
              status: RequestStatus.pending,
            );
          }),
        );
        notifyListeners();
        return;
      }

      final firestore = _firestore;
      final batch = firestore.batch();
      final createdRequestIds = <String>[];
      for (final item in equipment) {
        final document = firestore.collection('loans').doc();
        createdRequestIds.add(document.id);
        batch.set(document, {
          'id': document.id,
          'borrowerUid': userId,
          'equipmentId': item.id,
          'name': item.name,
          'borrower': borrowerName,
          'start': _dateOnly(borrowDate),
          'end': _dateOnly(returnDate),
          'startAt': borrowDate.toIso8601String(),
          'endAt': returnDate.toIso8601String(),
          'durationType': durationType.name,
          'requestGroupId': groupId,
          'status': 'pending',
          'returnedOn': null,
          'updatedAt': now.millisecondsSinceEpoch,
        });
      }
      await batch.commit();
      for (var index = 0; index < equipment.length; index++) {
        final item = equipment[index];
        final requestId = createdRequestIds[index];
        if (_requests.any((request) => request.id == requestId)) continue;
        _requests.add(
          BorrowRequestModel(
            id: requestId,
            studentOrFacultyId: userId,
            borrowerName: borrowerName,
            equipmentId: item.id,
            requestGroupId: groupId,
            requestedBorrowDate: borrowDate,
            requestedReturnDate: returnDate,
            durationType: durationType,
            requestDate: now,
            status: RequestStatus.pending,
          ),
        );
      }
      notifyListeners();
    } finally {
      _submittingEquipmentIds.removeAll(reservedKeys);
    }
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
    final group = request.requestGroupId == null
        ? [request]
        : _requests
              .where((r) => r.requestGroupId == request.requestGroupId)
              .toList();
    if (group.any((r) => r.status != RequestStatus.pending)) {
      throw StateError('This request is no longer pending.');
    }

    if (_firestore != null) {
      final batch = _firestore.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final member in group) {
        batch.update(_firestore.collection('loans').doc(member.id), {
          'status': 'cancelled',
          'updatedAt': now,
        });
      }
      await batch.commit();
    } else {
      for (final member in group) {
        member.status = RequestStatus.cancelled;
      }
      notifyListeners();
    }
  }

  Future<void> reportReturn(String requestId) async {
    final request = _requests.firstWhere((r) => r.id == requestId);
    final now = DateTime.now();
    if (_firestore != null) {
      await _firestore.collection('loans').doc(requestId).update({
        'status': 'return_pending',
        'returnRequestedAt': FieldValue.serverTimestamp(),
        'returnVerificationStatus': 'pending',
        'returnRejectionReason': null,
        'updatedAt': now.millisecondsSinceEpoch,
      });
    } else {
      request.status = RequestStatus.returnPending;
      request.returnVerificationStatus = 'pending';
      request.returnRejectionReason = null;
      request.activityDate = now;
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
      'return_pending' => RequestStatus.returnPending,
      'rejected' => RequestStatus.rejected,
      'returned' => RequestStatus.returned,
      'cancelled' => RequestStatus.cancelled,
      final value => throw FormatException('Unknown loan status: $value'),
    };
    final durationType = switch (data['durationType']) {
      'hours' => BorrowDurationType.hours,
      'days' || null => BorrowDurationType.days,
      final value => throw FormatException(
        'Unknown loan duration type: $value',
      ),
    };
    return BorrowRequestModel(
      id: document.id,
      studentOrFacultyId: data['borrowerUid'] as String,
      borrowerName: data['borrower'] as String? ?? '',
      equipmentId: data['equipmentId'] as String,
      requestGroupId: data['requestGroupId'] as String?,
      requestedBorrowDate: _loanDateTime(data, 'startAt', 'start'),
      requestedReturnDate: _loanDateTime(data, 'endAt', 'end'),
      durationType: durationType,
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
      returnVerificationStatus: data['returnVerificationStatus'] as String?,
      returnRejectionReason: data['returnRejectionReason'] as String?,
      returnRejectionSeen: data['returnRejectionSeen'] == true,
      returnRequestedAt: _dateTimeFromFirestore(data['returnRequestedAt']),
      returnVerifiedAt: _dateTimeFromFirestore(data['returnVerifiedAt']),
      status: status,
    );
  }

  DateTime? _dateTimeFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  DateTime _loanDateTime(
    Map<String, dynamic> data,
    String dateTimeField,
    String dateField,
  ) {
    final dateTime = data[dateTimeField];
    return DateTime.parse(
      dateTime is String ? dateTime : data[dateField] as String,
    );
  }

  void _validateLoanPeriod({
    required DateTime borrowDate,
    required DateTime returnDate,
    required BorrowDurationType durationType,
  }) {
    final borrowDay = DateTime.utc(
      borrowDate.year,
      borrowDate.month,
      borrowDate.day,
    );
    final returnDay = DateTime.utc(
      returnDate.year,
      returnDate.month,
      returnDate.day,
    );
    final dayCount = returnDay.difference(borrowDay).inDays;

    if (durationType == BorrowDurationType.hours) {
      if (dayCount != 0 ||
          !returnDate.isAfter(borrowDate) ||
          returnDate.difference(borrowDate) > const Duration(days: 1)) {
        throw ArgumentError(
          'Hourly requests must start and end on the same date, '
          'with the return time after the borrow time.',
        );
      }
      return;
    }

    if (dayCount < 0) {
      throw ArgumentError('Return date cannot be before the borrow date.');
    }
    if (dayCount > 14) {
      throw ArgumentError('The maximum borrowing period is 14 days.');
    }
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }
}
