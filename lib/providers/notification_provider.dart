// lib/providers/notification_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../utils/phone_notification_service.dart';

/// Keeps the signed-in user's notification feed and delivery preferences in sync.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    PhoneNotificationService? phoneNotifications,
    Stream<RemoteMessage>? foregroundMessages,
  }) : _firestore = firestore,
       _messaging = messaging,
       _phoneNotifications = phoneNotifications {
    final messageStream =
        foregroundMessages ??
        (_messaging == null ? null : FirebaseMessaging.onMessage);
    if (messageStream != null) {
      _foregroundMessageSubscription = messageStream.listen(
        _handleForegroundMessage,
      );
    }
  }

  final FirebaseFirestore? _firestore;
  final FirebaseMessaging? _messaging;
  final PhoneNotificationService? _phoneNotifications;
  final List<NotificationModel> _notifications = [];
  final Map<int, String> _activePageOverlays = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _accountSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _userId;
  String? _deviceDocumentId;
  String? _errorMessage;
  String? _permissionMessage;
  String _activePage = 'home';
  int _nextActivePageOverlayId = 0;
  bool _preferencesReady = false;

  bool requestUpdatesEnabled = true;
  bool returnRemindersEnabled = true;
  bool pushNotificationsEnabled = true;
  static const Set<String> _notificationPageTypes = {
    'approved',
    'rejected',
    'return_rejected',
    'returned',
    'due_reminder',
    'due_today',
    'overdue',
  };

  String? get errorMessage => _errorMessage;
  String? get permissionMessage => _permissionMessage;
  List<NotificationModel> get notifications {
    final list = List<NotificationModel>.from(_notifications);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  List<NotificationModel> get notificationPageNotifications => notifications
      .where(
        (notification) => _notificationPageTypes.contains(notification.type),
      )
      .toList();

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get unreadAdminChatCount => _notifications
      .where(
        (notification) =>
            !notification.isRead && notification.type == 'admin_chat_reply',
      )
      .length;
  int get unseenLoanUpdateCount => _notifications
      .where(
        (notification) =>
            !notification.isSeen &&
            _notificationPageTypes.contains(notification.type),
      )
      .length;

  void setActivePage(String page) {
    _activePage = page;
  }

  int beginActivePage(String page) {
    final id = ++_nextActivePageOverlayId;
    _activePageOverlays[id] = page;
    return id;
  }

  void endActivePage(int id) {
    _activePageOverlays.remove(id);
  }

  bool shouldSuppressForegroundNotification(String type) {
    final activePage = _currentActivePage;
    return switch (type) {
      'admin_chat_reply' => activePage == 'messages',
      'assistant_reply' => activePage == 'fabii_chat',
      'approved' ||
      'rejected' ||
      'return_rejected' ||
      'returned' ||
      'due_reminder' ||
      'due_today' ||
      'overdue' => activePage == 'loans' || activePage == 'notifications',
      _ => false,
    };
  }

  String get _currentActivePage => _activePageOverlays.values.isEmpty
      ? _activePage
      : _activePageOverlays.values.last;

  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? '';
    if (shouldSuppressForegroundNotification(type)) {
      final notificationId = message.data['notificationId']?.toString();
      final isVisibleInNotificationFeed =
          _currentActivePage == 'notifications' &&
          _notificationPageTypes.contains(type);
      if (!isVisibleInNotificationFeed &&
          notificationId != null &&
          notificationId.isNotEmpty) {
        unawaited(markNotificationReadById(notificationId));
      }
      return;
    }

    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body =
        message.notification?.body ?? message.data['message']?.toString();
    if (body == null || body.trim().isEmpty) return;
    final notificationId =
        message.data['notificationId']?.toString() ?? message.messageId;
    final id =
        (notificationId ?? DateTime.now().microsecondsSinceEpoch).hashCode &
        0x7fffffff;
    unawaited(
      _showPhoneNotification(
        id: id,
        title: title ?? 'Lendy',
        body: body,
        payload: notificationId,
      ),
    );
  }

  Future<void> _showPhoneNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final phoneNotifications = _phoneNotifications;
    if (phoneNotifications == null) {
      _errorMessage =
          'Could not show the phone notification while the app is open.';
      debugPrint(_errorMessage);
      notifyListeners();
      return;
    }
    try {
      await phoneNotifications.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (error) {
      _errorMessage = 'Could not show the phone notification: $error';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  void updateAuthentication({required String? userId}) {
    if (_userId == userId) return;
    final oldUserId = _userId;
    final oldDeviceDocumentId = _deviceDocumentId;
    _userId = userId;
    _deviceDocumentId = null;
    _accountSubscription?.cancel();
    _notificationSubscription?.cancel();
    _tokenSubscription?.cancel();
    _accountSubscription = null;
    _notificationSubscription = null;
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
            if (_isViewingLoanNotifications) {
              unawaited(markNotificationPageSeen());
            }
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
      type: data['type'] as String? ?? '',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      isRead: data['isRead'] == true,
      isSeen: data['isSeen'] == true || data['isRead'] == true,
    );
  }

  bool get _isViewingLoanNotifications =>
      _currentActivePage == 'loans' || _currentActivePage == 'notifications';

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
    final unreadNotifications = _notifications
        .where((notification) => !notification.isRead)
        .toList();
    if (unreadNotifications.isEmpty) return;
    if (userId == null || _firestore == null) {
      for (final notification in unreadNotifications) {
        notification.isRead = true;
        notification.isSeen = true;
      }
      notifyListeners();
      return;
    }
    try {
      final batch = _firestore.batch();
      for (final notification in unreadNotifications) {
        batch.update(
          _firestore
              .collection('accounts')
              .doc(userId)
              .collection('notifications')
              .doc(notification.id),
          {'isRead': true, 'isSeen': true},
        );
      }
      await batch.commit();
      for (final notification in unreadNotifications) {
        notification.isRead = true;
        notification.isSeen = true;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Could not mark notifications as read: $error';
      notifyListeners();
    }
  }

  Future<void> markAdminChatNotificationsRead() =>
      _markNotificationsReadForTypes({'admin_chat_reply'});

  Future<void> markAssistantNotificationsRead() =>
      _markNotificationsReadForTypes({'assistant_reply'});

  Future<void> markNotificationPageSeen() =>
      _markNotificationsSeenForTypes(_notificationPageTypes);

  Future<void> markNotificationPageRead() =>
      _markNotificationsReadForTypes(_notificationPageTypes);

  Future<void> _markNotificationsSeenForTypes(Set<String> types) async {
    final unseenNotifications = _notifications
        .where((notification) => !notification.isSeen)
        .where((notification) => types.contains(notification.type))
        .toList();
    if (unseenNotifications.isEmpty) return;

    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      for (final notification in unseenNotifications) {
        notification.isSeen = true;
      }
      notifyListeners();
      return;
    }

    try {
      final batch = firestore.batch();
      for (final notification in unseenNotifications) {
        batch.update(
          firestore
              .collection('accounts')
              .doc(userId)
              .collection('notifications')
              .doc(notification.id),
          {'isSeen': true},
        );
      }
      await batch.commit();
      for (final notification in unseenNotifications) {
        notification.isSeen = true;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Could not mark notifications as seen: $error';
      notifyListeners();
    }
  }

  Future<void> _markNotificationsReadForTypes(Set<String> types) async {
    final unreadNotifications = _notifications
        .where((notification) => !notification.isRead)
        .where((notification) => types.contains(notification.type))
        .toList();
    if (unreadNotifications.isEmpty) return;

    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      for (final notification in unreadNotifications) {
        notification.isRead = true;
        notification.isSeen = true;
      }
      notifyListeners();
      return;
    }

    try {
      final batch = firestore.batch();
      for (final notification in unreadNotifications) {
        batch.update(
          firestore
              .collection('accounts')
              .doc(userId)
              .collection('notifications')
              .doc(notification.id),
          {'isRead': true, 'isSeen': true},
        );
      }
      await batch.commit();
      for (final notification in unreadNotifications) {
        notification.isRead = true;
        notification.isSeen = true;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Could not mark notifications as read: $error';
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final userId = _userId;
    if (userId == null || _firestore == null) {
      final notification = _notifications.firstWhere((item) => item.id == id);
      notification
        ..isRead = true
        ..isSeen = true;
      notifyListeners();
      return;
    }
    try {
      await _firestore
          .collection('accounts')
          .doc(userId)
          .collection('notifications')
          .doc(id)
          .update({'isRead': true, 'isSeen': true});
      for (final notification in _notifications.where(
        (item) => item.id == id,
      )) {
        notification
          ..isRead = true
          ..isSeen = true;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Could not mark notification as read: $error';
      notifyListeners();
    }
  }

  Future<void> markNotificationReadById(String id) async {
    final userId = _userId;
    if (userId == null || _firestore == null || id.isEmpty) return;
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

  void addNotification(String message, {String type = ''}) {
    _notifications.insert(
      0,
      NotificationModel(
        id: 'n${_notifications.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
        message: message,
        type: type,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _notificationSubscription?.cancel();
    _tokenSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    super.dispose();
  }
}
