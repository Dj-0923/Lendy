// lib/providers/notification_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';

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
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _userId;
  String? _deviceDocumentId;
  String? _errorMessage;
  String? _permissionMessage;
  bool _preferencesReady = false;

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
    _foregroundSubscription?.cancel();
    _tokenSubscription?.cancel();
    _accountSubscription = null;
    _notificationSubscription = null;
    _foregroundSubscription = null;
    _tokenSubscription = null;
    _notifications.clear();
    _errorMessage = null;
    _permissionMessage = null;
    _preferencesReady = false;

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
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error) {
            _errorMessage = 'Could not load your notifications: $error';
            notifyListeners();
          },
        );
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
    _savePreferences();
  }

  void setPushNotificationsEnabled(bool value) {
    pushNotificationsEnabled = value;
    notifyListeners();
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
    _foregroundSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }
}
