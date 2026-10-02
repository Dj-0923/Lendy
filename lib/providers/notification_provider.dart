// lib/providers/notification_provider.dart
import 'package:flutter/material.dart';
import '../models/notification_model.dart';

/// Manages the in-memory list of notifications, plus the user's
/// notification preference toggles (Notification Settings screen).
class NotificationProvider extends ChangeNotifier {
  final List<NotificationModel> _notifications = [
    NotificationModel(
      id: 'n1',
      message: 'Your request for Canon DSLR Camera is pending approval.',
      timestamp: DateTime.now(),
    ),
    NotificationModel(
      id: 'n2',
      message: 'Dell Latitude Laptop is due back tomorrow.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  List<NotificationModel> get notifications {
    final list = List<NotificationModel>.from(_notifications);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    final notification = _notifications.firstWhere((n) => n.id == id);
    notification.isRead = true;
    notifyListeners();
  }

  void addNotification(String message) {
    _notifications.insert(
      0,
      NotificationModel(
        id: 'n${_notifications.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
        message: message,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // ----- Notification preference toggles (Notification Settings screen) -----

  bool requestUpdatesEnabled = false;
  bool returnRemindersEnabled = false;
  bool pushNotificationsEnabled = false;

  void setRequestUpdatesEnabled(bool value) {
    requestUpdatesEnabled = value;
    notifyListeners();
  }

  void setReturnRemindersEnabled(bool value) {
    returnRemindersEnabled = value;
    notifyListeners();
  }

  void setPushNotificationsEnabled(bool value) {
    pushNotificationsEnabled = value;
    notifyListeners();
  }
}