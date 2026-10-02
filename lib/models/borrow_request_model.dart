// lib/models/borrow_request_model.dart

/// Status progression of a borrow request:
/// pending -> approved / rejected -> borrowed -> returned
/// (or pending -> cancelled, by the user themselves before approval)
enum RequestStatus { pending, approved, rejected, borrowed, returned, cancelled }

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
  final String equipmentId;
  final DateTime requestedBorrowDate;
  final DateTime requestedReturnDate;
  final DateTime requestDate; // when the request was submitted
  DateTime? approvedDate;
  DateTime? checkedOutDate;
  DateTime? returnedDate;
  RequestStatus status;

  BorrowRequestModel({
    required this.id,
    required this.studentOrFacultyId,
    required this.equipmentId,
    required this.requestedBorrowDate,
    required this.requestedReturnDate,
    required this.requestDate,
    this.approvedDate,
    this.checkedOutDate,
    this.returnedDate,
    this.status = RequestStatus.pending,
  });
}