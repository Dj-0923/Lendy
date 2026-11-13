// lib/models/borrow_request_model.dart

/// Status progression: pending -> approved / rejected -> borrowed ->
/// returnPending -> returned. A rejected return report returns to borrowed;
/// a request can also be cancelled before approval.
enum RequestStatus {
  pending,
  approved,
  rejected,
  borrowed,
  returnPending,
  returned,
  cancelled,
}

extension RequestStatusX on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.borrowed:
        return 'Borrowed';
      case RequestStatus.returnPending:
        return 'Return verification';
      case RequestStatus.returned:
        return 'Returned';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// A single equipment borrow request made by a Student or Faculty user.
/// Structured with clear timestamp fields so swapping in a real backend
/// (e.g. Firebase) later is straightforward.
class BorrowRequestModel {
  final String id;
  final String studentOrFacultyId; // the logged-in user's id
  final String borrowerName;
  final String equipmentId;
  final DateTime requestedBorrowDate;
  final DateTime requestedReturnDate;
  final DateTime requestDate; // when the request was submitted
  DateTime activityDate;
  DateTime? approvedDate;
  DateTime? checkedOutDate;
  DateTime? returnedDate;
  String? returnVerificationStatus;
  String? returnRejectionReason;
  RequestStatus status;

  BorrowRequestModel({
    required this.id,
    required this.studentOrFacultyId,
    required this.borrowerName,
    required this.equipmentId,
    required this.requestedBorrowDate,
    required this.requestedReturnDate,
    required this.requestDate,
    DateTime? activityDate,
    this.approvedDate,
    this.checkedOutDate,
    this.returnedDate,
    this.returnVerificationStatus,
    this.returnRejectionReason,
    this.status = RequestStatus.pending,
  }) : activityDate = activityDate ?? requestDate;
}
