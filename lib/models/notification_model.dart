// lib/models/notification_model.dart

/// A single notification item (reminder, approval update, or return alert).
class NotificationModel {
  final String id;
  final String message;
  final String type;
  final DateTime timestamp;
  bool isRead;
  bool isSeen;

  NotificationModel({
    required this.id,
    required this.message,
    this.type = '',
    required this.timestamp,
    this.isRead = false,
    this.isSeen = false,
  });
}
