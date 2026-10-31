// lib/providers/notification_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_model.dart';
import '../utils/local_return_reminder.dart';

/// Keeps the signed-in user's notification feed and delivery preferences in sync.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _firestore = firestore,
       _messaging = messaging,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseFirestore? _firestore;
  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final List<NotificationModel> _notifications = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _accountSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _loanSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Timer? _reminderTimer;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _loanDocuments = [];
  String? _userId;
  String? _deviceDocumentId;
  String? _errorMessage;
  String? _permissionMessage;
  bool _preferencesReady = false;
  bool _loanDataReady = false;
  Future<void> _localReminderSync = Future<void>.value();
  final Set<String> _knownNotificationIds = {};

  bool requestUpdatesEnabled = true;
  bool returnRemindersEnabled = true;
  bool pushNotificationsEnabled = true;

  String? get errorMessage => _errorMessage;
  String? get permissionMessage => _permissionMessage;
  List<NotificationModel> get notifications {
    final list = List<NotificationModel>.from(_notifications);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void updateAuthentication({required String? userId}) {
    if (_userId == userId) return;
    final oldUserId = _userId;
    final oldDeviceDocumentId = _deviceDocumentId;
    _userId = userId;
    _deviceDocumentId = null;
    _accountSubscription?.cancel();
    _notificationSubscription?.cancel();
    _loanSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _tokenSubscription?.cancel();
    _reminderTimer?.cancel();
    _accountSubscription = null;
    _notificationSubscription = null;
    _loanSubscription = null;
    _foregroundSubscription = null;
    _tokenSubscription = null;
    _reminderTimer = null;
    _loanDocuments = [];
    _loanDataReady = false;
    _knownNotificationIds.clear();
    _notifications.clear();
    _errorMessage = null;
    _permissionMessage = null;
    _preferencesReady = false;

    if (oldUserId != null && oldUserId != userId) {
      _queueLocalReturnReminders(null);
    }

    if (oldUserId != null &&
        oldDeviceDocumentId != null &&
        _firestore != null) {
      _firestore
          .collection('accounts')
          .doc(oldUserId)
          .collection('devices')
          .doc(oldDeviceDocumentId)
          .delete()
          .catchError((Object error) {
            debugPrint(
              'Could not unregister the old notification device: $error',
            );
          });
    }

    if (userId != null && _firestore != null) {
      _watchUser(userId);
    }
    notifyListeners();
  }

  void _watchUser(String userId) {
    final firestore = _firestore!;
    final account = firestore.collection('accounts').doc(userId);
    _accountSubscription = account.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) {
          _errorMessage =
              'Could not load notification settings for this account.';
          notifyListeners();
          return;
        }
        final values = snapshot.data()?['notificationPreferences'];
        if (values is Map<String, dynamic>) {
          requestUpdatesEnabled = values['requestUpdatesEnabled'] is bool
              ? values['requestUpdatesEnabled'] as bool
              : true;
          returnRemindersEnabled = values['returnRemindersEnabled'] is bool
              ? values['returnRemindersEnabled'] as bool
              : true;
          pushNotificationsEnabled = values['pushNotificationsEnabled'] is bool
              ? values['pushNotificationsEnabled'] as bool
              : true;
        }
        _preferencesReady = true;
        _errorMessage = null;
        notifyListeners();
        _reconcileLoanNotifications(userId);
        _queueLocalReturnReminders(userId);
        _syncPushRegistration(userId);
      },
      onError: (Object error) {
        _errorMessage = 'Could not load notification settings: $error';
        notifyListeners();
      },
    );
    _notificationSubscription = account
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            _notifications
              ..clear()
              ..addAll(snapshot.docs.map(_notificationFromDocument));
            _knownNotificationIds
              ..clear()
              ..addAll(snapshot.docs.map((document) => document.id));
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error) {
            _errorMessage = 'Could not load your notifications: $error';
            notifyListeners();
          },
        );
    _loanSubscription = firestore
        .collection('loans')
        .where('borrowerUid', isEqualTo: userId)
        .snapshots()
        .listen(
          (snapshot) {
            _loanDocuments = snapshot.docs;
            _loanDataReady = true;
            _reconcileLoanNotifications(userId);
            _queueLocalReturnReminders(userId);
          },
          onError: (Object error) {
            _errorMessage = 'Could not check your loan notifications: $error';
            notifyListeners();
          },
        );
    _reminderTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (_userId == userId) _reconcileLoanNotifications(userId);
    });
  }

  void _reconcileLoanNotifications(String userId) {
    if (_userId != userId || !_preferencesReady || _firestore == null) return;
    final today = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayKey = _dateKey(today);
    final tomorrowKey = _dateKey(today.add(const Duration(days: 1)));

    for (final document in _loanDocuments) {
      final loan = document.data();
      final status = loan['status'];
      final name = loan['name'] is String && (loan['name'] as String).isNotEmpty
          ? loan['name'] as String
          : 'your requested item';

      if (requestUpdatesEnabled &&
          (status == 'approved' || status == 'rejected')) {
        final approved = status == 'approved';
        _createLoanNotification(
          userId: userId,
          documentId: '${document.id}_$status',
          loanId: document.id,
          type: status as String,
          title: approved ? 'Request approved' : 'Request rejected',
          message: approved
              ? '$name has been approved.'
              : '$name was not approved.',
        );
      }

      if (status == 'returned' && returnRemindersEnabled) {
        _createLoanNotification(
          userId: userId,
          documentId: '${document.id}_returned',
          loanId: document.id,
          type: 'returned',
          title: 'Item return confirmed',
          message: '$name has been marked as returned. Thank you.',
        );
      }

      final end = loan['end'];
      if (status != 'approved' || end is! String || !returnRemindersEnabled) {
        continue;
      }
      if (end == tomorrowKey) {
        _createLoanNotification(
          userId: userId,
          documentId: '${document.id}_due_$tomorrowKey',
          loanId: document.id,
          type: 'due_reminder',
          title: 'Return due tomorrow',
          message: '$name is due tomorrow. Please return it on time.',
        );
      } else if (end.compareTo(todayKey) < 0) {
        _createLoanNotification(
          userId: userId,
          documentId: '${document.id}_overdue_$todayKey',
          loanId: document.id,
          type: 'overdue',
          title: 'Item overdue',
          message:
              '$name was due $end and is overdue. Please return it as soon as possible.',
        );
      }
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _queueLocalReturnReminders(String? userId) {
    _localReminderSync = _localReminderSync.then((_) async {
      try {
        if (userId == null) {
          await _cancelScheduledReturnReminders();
          return;
        }
        if (_userId != userId || !_preferencesReady || !_loanDataReady) return;
        await _syncScheduledReturnReminders();
      } catch (error) {
        _errorMessage = 'Could not schedule return reminders: $error';
        notifyListeners();
      }
    });
  }

  Future<void> _syncScheduledReturnReminders() async {
    final enabled = returnRemindersEnabled && pushNotificationsEnabled;
    final desired = <int, LocalReturnReminder>{};
    if (enabled) {
      final now = tz.TZDateTime.now(tz.local);
      for (final document in _loanDocuments) {
        final loan = document.data();
        final end = loan['end'];
        if (end is! String) continue;
        final reminder = localReturnReminderForLoan(
          loanId: document.id,
          itemName: loan['name'] is String && (loan['name'] as String).isNotEmpty
              ? loan['name'] as String
              : 'Your requested item',
          status: loan['status'] is String ? loan['status'] as String : '',
          dueDate: end,
          now: now,
        );
        if (reminder == null) continue;
        final existing = desired[reminder.id];
        if (existing != null && existing.loanId != reminder.loanId) {
          throw StateError('Local reminder ID collision for ${reminder.loanId}.');
        }
        desired[reminder.id] = reminder;
      }
    }

    final pending = await _localNotifications.pendingNotificationRequests();
    final existingReminders = pending
        .where(
          (request) =>
              request.payload?.startsWith(localReturnReminderPayloadPrefix) ??
              false,
        )
        .toList();
    final existingIds = <int>{};
    for (final request in existingReminders) {
      final reminder = desired[request.id];
      if (reminder == null ||
          request.payload != reminder.payload ||
          request.title != reminder.title ||
          request.body != reminder.body) {
        await _localNotifications.cancel(id: request.id);
      } else {
        existingIds.add(request.id);
      }
    }

    for (final reminder in desired.values) {
      if (existingIds.contains(reminder.id)) continue;
      await _localNotifications.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        payload: reminder.payload,
        scheduledDate: reminder.scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'lendy_alerts',
            'Lendy alerts',
            channelDescription: 'Borrowing requests and return reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _cancelScheduledReturnReminders() async {
    final pending = await _localNotifications.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(localReturnReminderPayloadPrefix) ??
          false) {
        await _localNotifications.cancel(id: request.id);
      }
    }
  }

  Future<void> _createLoanNotification({
    required String userId,
    required String documentId,
    required String loanId,
    required String type,
    required String title,
    required String message,
  }) async {
    final firestore = _firestore;
    if (firestore == null || _knownNotificationIds.contains(documentId)) return;
    final reference = firestore
        .collection('accounts')
        .doc(userId)
        .collection('notifications')
        .doc(documentId);
    try {
      await firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) return;
        transaction.set(reference, {
          'id': documentId,
          'loanId': loanId,
          'type': type,
          'title': title,
          'message': message,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
      _knownNotificationIds.add(documentId);
    } catch (error) {
      _errorMessage = 'Could not save a loan notification: $error';
      notifyListeners();
    }
  }

  NotificationModel _notificationFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['timestamp'];
    return NotificationModel(
      id: document.id,
      message: data['message'] as String? ?? '',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      isRead: data['isRead'] == true,
    );
  }

  Future<void> _syncPushRegistration(String userId) async {
    final messaging = _messaging;
    final firestore = _firestore;
    if (kIsWeb ||
        !_preferencesReady ||
        messaging == null ||
        firestore == null) {
      return;
    }
    if (!pushNotificationsEnabled) {
      await _unregisterDevice(userId);
      return;
    }

    try {
      var settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await messaging.requestPermission();
      }
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _permissionMessage =
            'Notifications are blocked in device settings. Allow Lendy notifications to receive alerts.';
        notifyListeners();
        return;
      }
      _permissionMessage = null;

      // Firebase Admin sends to FCM registration tokens, not Firebase
      // Installation IDs, so keep using its registration-token API.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveDeviceToken(userId, token);
      }
      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      // ignore: deprecated_member_use
      _tokenSubscription ??= messaging.onTokenRefresh.listen((token) {
        final currentUser = _userId;
        if (currentUser != null && pushNotificationsEnabled) {
          _saveDeviceToken(currentUser, token).catchError((Object error) {
            _errorMessage = 'Could not refresh the notification token: $error';
            notifyListeners();
          });
        }
      });
    } catch (error) {
      _errorMessage = 'Could not enable device notifications: $error';
      notifyListeners();
    }
  }

  Future<void> _saveDeviceToken(String userId, String token) async {
    final documentId = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
    await _firestore!
        .collection('accounts')
        .doc(userId)
        .collection('devices')
        .doc(documentId)
        .set({
          'token': token,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
    _deviceDocumentId = documentId;
    _errorMessage = null;
  }

  Future<void> _unregisterDevice(String userId) async {
    final documentId = _deviceDocumentId;
    if (documentId == null) return;
    await _firestore!
        .collection('accounts')
        .doc(userId)
        .collection('devices')
        .doc(documentId)
        .delete();
    _deviceDocumentId = null;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!pushNotificationsEnabled) return;
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;
    await _localNotifications.show(
      id:
          (message.messageId ?? message.hashCode.toString()).hashCode &
          0x7fffffff,
      title: title ?? 'Lendy',
      body: body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lendy_alerts',
          'Lendy alerts',
          channelDescription: 'Borrowing requests and return reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> _savePreferences() async {
    final userId = _userId;
    if (userId == null || _firestore == null) return;
    try {
      await _firestore.collection('accounts').doc(userId).set({
        'notificationPreferences': {
          'requestUpdatesEnabled': requestUpdatesEnabled,
          'returnRemindersEnabled': returnRemindersEnabled,
          'pushNotificationsEnabled': pushNotificationsEnabled,
        },
      }, SetOptions(merge: true));
      _errorMessage = null;
      _reconcileLoanNotifications(userId);
      _queueLocalReturnReminders(userId);
    } catch (error) {
      _errorMessage = 'Could not save notification settings: $error';
      notifyListeners();
    }
  }

  void setRequestUpdatesEnabled(bool value) {
    requestUpdatesEnabled = value;
    notifyListeners();
    _savePreferences();
  }

  void setReturnRemindersEnabled(bool value) {
    returnRemindersEnabled = value;
    notifyListeners();
    final userId = _userId;
    if (userId != null) _queueLocalReturnReminders(userId);
    _savePreferences();
  }

  void setPushNotificationsEnabled(bool value) {
    pushNotificationsEnabled = value;
    notifyListeners();
    final userId = _userId;
    if (userId != null) _queueLocalReturnReminders(userId);
    _savePreferences().then((_) {
      final userId = _userId;
      if (userId != null) _syncPushRegistration(userId);
    });
  }

  Future<void> markAllRead() async {
    final userId = _userId;
    if (userId == null || _firestore == null) {
      for (final notification in _notifications) {
        notification.isRead = true;
      }
      notifyListeners();
      return;
    }
    try {
      final batch = _firestore.batch();
      for (final notification in _notifications.where((item) => !item.isRead)) {
        batch.update(
          _firestore
              .collection('accounts')
              .doc(userId)
              .collection('notifications')
              .doc(notification.id),
          {'isRead': true},
        );
      }
      await batch.commit();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Could not mark notifications as read: $error';
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final userId = _userId;
    if (userId == null || _firestore == null) {
      final notification = _notifications.firstWhere((item) => item.id == id);
      notification.isRead = true;
      notifyListeners();
      return;
    }
    try {
      await _firestore
          .collection('accounts')
          .doc(userId)
          .collection('notifications')
          .doc(id)
          .update({'isRead': true});
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Could not mark notification as read: $error';
      notifyListeners();
    }
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

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _notificationSubscription?.cancel();
    _loanSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _tokenSubscription?.cancel();
    _reminderTimer?.cancel();
    super.dispose();
  }
}
