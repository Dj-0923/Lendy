// lib/models/notification_model.dart

/// A single notification item (reminder, approval update, or return alert).
class NotificationModel {
  final String id;
  final String message;
  final DateTime timestamp;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}