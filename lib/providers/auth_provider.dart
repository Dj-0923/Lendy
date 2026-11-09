import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../utils/first_launch_store.dart';
import '../utils/session_preference_store.dart';

const _approvalApiUrl = 'https://lendy-account-approval.onrender.com';

class RequestAccountResult {
  final bool success;
  final String? error;
  final String? code;
  final String? warning;

  RequestAccountResult.success({this.warning})
    : success = true,
      error = null,
      code = null;

  RequestAccountResult.failure(this.error, {this.code})
    : success = false,
      warning = null;
}

class AuthProvider extends ChangeNotifier {
  AuthProvider()
    : _auth = firebase_auth.FirebaseAuth.instance,
      _firestore = FirebaseFirestore.instance,
      _forTesting = false,
      _isReady = false {
    _authStateSubscription = _auth!.authStateChanges().listen(
      _handleAuthStateChanged,
      onError: (Object error) {
        _authError = _errorMessage(error);
        _isReady = true;
        notifyListeners();
      },
    );
    unawaited(_restorePendingAccountRequest());
  }

  AuthProvider.forTesting({
    UserModel? currentUser,
    Map<String, dynamic>? accountRequestData,
  }) : _auth = null,
       _firestore = null,
       _forTesting = true,
       _isReady = true,
       _currentUser = currentUser,
       _accountRequestData = accountRequestData;

  final firebase_auth.FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final bool _forTesting;
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _accountRequestSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _temporaryCredentialSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _accountStatusSubscription;
  UserModel? _currentUser;
  Map<String, dynamic>? _accountRequestData;
  String? _approvalRequestId;
  bool _isReady;
  String? _authError;
  bool _accountRequestInProgress = false;
  bool _loginInProgress = false;
  bool _handlingRevocation = false;
  int _accessRevokedVersion = 0;
  String? _requestStatusToken;
  String? _requestStatusId;
  Timer? _requestStatusTimer;
  bool _requestStatusRefreshInProgress = false;
  bool _disposed = false;

  static const _storedRequestIdKey = 'pending_account_request_id';
  static const _storedRequestTokenKey = 'pending_account_request_token';

  UserModel? get currentUser => _currentUser;
  Map<String, dynamic>? get accountRequestData => _accountRequestData;
  bool get isLoggedIn => _currentUser != null;
  bool get isReady => _isReady;
  String? get authError => _authError;
  int get accessRevokedVersion => _accessRevokedVersion;

  Future<void> _restorePendingAccountRequest() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final requestId = preferences.getString(_storedRequestIdKey);
      final token = preferences.getString(_storedRequestTokenKey);
      if (_disposed || requestId == null || token == null) return;
      _requestStatusId = requestId;
      _requestStatusToken = token;
      await _refreshAccountRequestStatus();
      if (!_disposed &&
          _accountRequestData?['status'] != 'approved' &&
          _accountRequestData?['status'] != 'rejected' &&
          _requestStatusToken != null) {
        _startRequestStatusPolling();
      }
    } catch (error) {
      if (_disposed) return;
      _authError = 'Could not restore account request status: $error';
      notifyListeners();
    }
  }

  Future<void> _storeRequestStatusCredentials(
    String requestId,
    String token,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final savedId = await preferences.setString(_storedRequestIdKey, requestId);
    final savedToken = await preferences.setString(
      _storedRequestTokenKey,
      token,
    );
    if (!savedId || !savedToken) {
      throw StateError('Could not save the account request status locally.');
    }
  }

  Future<void> _clearRequestStatusCredentials() async {
    _requestStatusTimer?.cancel();
    _requestStatusTimer = null;
    _requestStatusId = null;
    _requestStatusToken = null;
    if (_forTesting) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storedRequestIdKey);
    await preferences.remove(_storedRequestTokenKey);
  }

  void _startRequestStatusPolling() {
    _requestStatusTimer?.cancel();
    _requestStatusTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_refreshAccountRequestStatus()),
    );
  }

  Future<void> _refreshAccountRequestStatus() async {
    final requestId = _requestStatusId;
    final token = _requestStatusToken;
    if (requestId == null || token == null || _requestStatusRefreshInProgress) {
      return;
    }
    _requestStatusRefreshInProgress = true;
    try {
      final response = await http.post(
        Uri.parse('$_approvalApiUrl/account-request-status'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'statusToken': token}),
      );
      if (_disposed) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 404 && body['code'] == 'request-removed') {
        _accountRequestData = {
          ...?_accountRequestData,
          'status': 'rejected',
          'requestDeleted': true,
        };
        await _clearRequestStatusCredentials();
        _approvalRequestId = null;
        notifyListeners();
        return;
      }
      if (response.statusCode != 200) {
        throw StateError(
          body['error'] as String? ?? 'Could not refresh request status.',
        );
      }
      _accountRequestData = {...?_accountRequestData, ...body, 'id': requestId};
      if (_accountRequestData?['status'] != 'pending') {
        _requestStatusTimer?.cancel();
        _requestStatusTimer = null;
      }
      notifyListeners();
    } catch (error) {
      if (_disposed) return;
      _authError = 'Could not refresh account request status: $error';
      notifyListeners();
    } finally {
      _requestStatusRefreshInProgress = false;
    }
  }

  Future<void> _handleAuthStateChanged(firebase_auth.User? user) async {
    if (_accountRequestInProgress || _loginInProgress) return;
    if (user == null) {
      await _accountRequestSubscription?.cancel();
      _accountRequestSubscription = null;
      await _temporaryCredentialSubscription?.cancel();
      _temporaryCredentialSubscription = null;
      await _accountStatusSubscription?.cancel();
      _accountStatusSubscription = null;
      _currentUser = null;
      if (_requestStatusToken == null) {
        _accountRequestData = null;
      }
      _isReady = true;
      notifyListeners();
      return;
    }

    try {
      final requests = await _firestore!
          .collection('accountRequests')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (requests.docs.isNotEmpty) {
        final data = requests.docs.first.data();
        if (data['status'] == 'pending' || data['status'] == 'rejected') {
          _approvalRequestId = requests.docs.first.id;
          _watchAccountRequest(requests.docs.first.reference);
          _accountRequestData = data;
          _currentUser = null;
          _authError = null;
          return;
        }
        if (data['status'] == 'approved') {
          final account = await _firestore
              .collection('accounts')
              .doc(user.uid)
              .get();
          if (account.data()?['status'] == 'active' &&
              account.data()?['mustChangePassword'] == true) {
            _watchAccountStatus(user);
            _approvalRequestId = requests.docs.first.id;
            _watchAccountRequest(requests.docs.first.reference);
            _accountRequestData = data;
            _currentUser = null;
            _authError = null;
            return;
          }
        }
      }
      await _accountRequestSubscription?.cancel();
      _accountRequestSubscription = null;
      _approvalRequestId = null;
      _accountRequestData = null;
      final account = await _loadActiveAccount(user);
      _currentUser = account;
      _authError = null;
    } catch (error) {
      _authError = _errorMessage(error);
      _currentUser = null;
      if (_authError!.startsWith('Access denied:')) {
        _accessRevokedVersion++;
      }
      await _auth!.signOut();
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  void _watchAccountRequest(
    DocumentReference<Map<String, dynamic>> requestReference,
  ) {
    if (_accountRequestSubscription != null) return;
    _accountRequestSubscription = requestReference.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) {
          final previousRequest = _accountRequestData;
          if (previousRequest?['status'] == 'pending' ||
              previousRequest?['status'] == 'rejected') {
            _accountRequestData = {
              ...previousRequest!,
              'status': 'rejected',
              'requestDeleted': true,
            };
          } else {
            _accountRequestData = null;
          }
          _approvalRequestId = null;
          _authError = null;
          _temporaryCredentialSubscription?.cancel();
          _temporaryCredentialSubscription = null;
        } else {
          final data = snapshot.data()!;
          final isWaiting =
              data['status'] == 'pending' || data['status'] == 'rejected';
          final hasApprovedRequest = data['status'] == 'approved';
          if (isWaiting || hasApprovedRequest) {
            final loadedPassword = _accountRequestData?['temporaryPassword'];
            _accountRequestData = {
              ...data,
              if (loadedPassword is String) 'temporaryPassword': loadedPassword,
            };
            if (hasApprovedRequest) {
              _watchTemporaryCredential(requestReference);
            } else {
              _temporaryCredentialSubscription?.cancel();
              _temporaryCredentialSubscription = null;
            }
          } else {
            _accountRequestData = null;
            _approvalRequestId = null;
            _accountRequestSubscription?.cancel();
            _accountRequestSubscription = null;
            _temporaryCredentialSubscription?.cancel();
            _temporaryCredentialSubscription = null;
          }
        }
        notifyListeners();
      },
      onError: (Object error) {
        _authError = _errorMessage(error);
        notifyListeners();
      },
    );
  }

  void _watchTemporaryCredential(
    DocumentReference<Map<String, dynamic>> requestReference,
  ) {
    if (_temporaryCredentialSubscription != null) return;
    _temporaryCredentialSubscription = requestReference
        .collection('privateCredentials')
        .doc('temporary')
        .snapshots()
        .listen(
          (snapshot) {
            final current = _accountRequestData;
            if (current == null) return;
            final credential = snapshot.data();
            if (credential?['temporaryPassword'] is String) {
              _accountRequestData = {
                ...current,
                'temporaryPassword': credential!['temporaryPassword'],
              };
            } else if (current['temporaryPassword'] is! String) {
              final updated = Map<String, dynamic>.from(current)
                ..remove('temporaryPassword');
              _accountRequestData = updated;
            }
            notifyListeners();
          },
          onError: (Object error) {
            _authError = _errorMessage(error);
            notifyListeners();
          },
        );
  }

  Future<UserModel> _loadActiveAccount(firebase_auth.User user) async {
    final snapshot = await _firestore!
        .collection('accounts')
        .doc(user.uid)
        .get();
    if (!snapshot.exists) {
      throw StateError('This account has not been approved yet.');
    }
    final data = snapshot.data()!;
    if (data['status'] != 'active') {
      throw StateError(
        'Access denied: your account has been revoked. Contact an administrator.',
      );
    }
    _watchAccountStatus(user);
    if (user.email != null && data['email'] != user.email) {
      await snapshot.reference.update({'email': user.email});
    }

    return UserModel.fromMap(
      id: user.uid,
      data: {...data, 'email': user.email ?? data['email']},
    );
  }

  void _watchAccountStatus(firebase_auth.User user) {
    if (_accountStatusSubscription != null) return;
    _accountStatusSubscription = _firestore!
        .collection('accounts')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists || snapshot.data()?['status'] != 'active') {
              _handleRevokedAccount();
            }
          },
          onError: (Object error) {
            _authError = _errorMessage(error);
            notifyListeners();
          },
        );
  }

  Future<void> _handleRevokedAccount() async {
    if (_auth?.currentUser == null || _handlingRevocation) return;
    _handlingRevocation = true;
    _currentUser = null;
    _authError =
        'Access denied: your account has been revoked. Contact an administrator.';
    _accessRevokedVersion++;
    await _accountStatusSubscription?.cancel();
    _accountStatusSubscription = null;
    notifyListeners();
    try {
      await _auth!.signOut();
    } finally {
      _handlingRevocation = false;
    }
  }

  Future<String?> updateProfilePhoto(Uint8List imageBytes) async {
    final currentUser = _currentUser;
    if (currentUser == null) return 'No user is currently logged in.';
    if (imageBytes.length > 500000) {
      return 'Choose a smaller photo and try again.';
    }
    if (!_forTesting) {
      try {
        await _firestore!.collection('accounts').doc(currentUser.id).update({
          'profileImage': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
        });
      } catch (error) {
        return _errorMessage(error);
      }
    }
    currentUser.profileImageBytes = imageBytes;
    notifyListeners();
    return null;
  }

  Future<String?> login(
    String email,
    String password, {
    bool keepSignedIn = false,
  }) async {
    if (_forTesting) return 'Invalid email or password.';

    _loginInProgress = true;
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'Sign-in failed. Please try again.';
      final requests = await _firestore!
          .collection('accountRequests')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      await _accountRequestSubscription?.cancel();
      _accountRequestSubscription = null;
      _accountRequestData = null;
      _approvalRequestId = null;

      if (requests.docs.isNotEmpty) {
        final request = requests.docs.first;
        final data = request.data();
        if (data['status'] == 'pending' || data['status'] == 'rejected') {
          _approvalRequestId = request.id;
          _watchAccountRequest(request.reference);
          _accountRequestData = data;
          await SessionPreferenceStore.setKeepSignedIn(keepSignedIn);
          await FirstLaunchStore.markWelcomeSeen();
          _authError = null;
          notifyListeners();
          return null;
        }
        if (data['status'] == 'approved') {
          final account = await _firestore
              .collection('accounts')
              .doc(user.uid)
              .get();
          if (account.data()?['status'] == 'active' &&
              account.data()?['mustChangePassword'] == true) {
            _approvalRequestId = request.id;
            _currentUser = await _loadActiveAccount(user);
            await SessionPreferenceStore.setKeepSignedIn(keepSignedIn);
            await FirstLaunchStore.markWelcomeSeen();
            _authError = null;
            notifyListeners();
            return null;
          }
        }
      }
      _currentUser = await _loadActiveAccount(user);
      await SessionPreferenceStore.setKeepSignedIn(keepSignedIn);
      await FirstLaunchStore.markWelcomeSeen();
      _authError = null;
      notifyListeners();
      return null;
    } catch (error) {
      if (_auth!.currentUser != null) await _auth.signOut();
      return _errorMessage(error);
    } finally {
      _loginInProgress = false;
    }
  }

  Future<RequestAccountResult> requestAccount({
    required String fullName,
    required String email,
    required UserRole role,
    required String idNumber,
    required String college,
    required String gender,
    String? yearLevel,
    String? block,
  }) async {
    if (_forTesting) {
      return RequestAccountResult.success();
    }

    _accountRequestInProgress = true;
    try {
      final response = await http.post(
        Uri.parse('$_approvalApiUrl/request-account'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'role': role.name,
          'idNumber': idNumber.trim(),
          'college': college.trim(),
          'gender': gender,
          if (role == UserRole.student) ...{
            'yearLevel': yearLevel,
            'block': block,
          },
        }),
      );
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 201) {
        return RequestAccountResult.failure(
          responseData['error'] as String? ??
              'Could not submit the account request.',
          code: responseData['code'] as String?,
        );
      }
      final requestId = responseData['requestId'] as String;
      final statusToken = responseData['statusToken'] as String;
      _requestStatusId = requestId;
      _requestStatusToken = statusToken;
      _accountRequestData = {
        'id': requestId,
        'name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'status': 'pending',
      };
      _approvalRequestId = requestId;
      String? warning;
      try {
        await _storeRequestStatusCredentials(requestId, statusToken);
      } catch (error) {
        warning =
            'Your request was submitted, but this device could not save its status check. Keep the app open to follow the request.';
        debugPrint('Could not persist account request status: $error');
      }
      _startRequestStatusPolling();
      unawaited(_refreshAccountRequestStatus());
      return RequestAccountResult.success(warning: warning);
    } catch (error) {
      return RequestAccountResult.failure(
        'Could not submit the account request: $error',
      );
    } finally {
      _accountRequestInProgress = false;
      _isReady = true;
      notifyListeners();
    }
  }

  Future<String?> setNewPassword(String newPassword) async {
    if (_forTesting) {
      _currentUser?.mustChangePassword = false;
      notifyListeners();
      return null;
    }

    final user = _auth!.currentUser;
    if (user == null || _currentUser == null) {
      return 'No user is currently logged in.';
    }

    try {
      await _temporaryCredentialSubscription?.cancel();
      _temporaryCredentialSubscription = null;
      await user.updatePassword(newPassword);
      await _firestore!.collection('accounts').doc(user.uid).update({
        'mustChangePassword': false,
      });
      if (_approvalRequestId case final requestId?) {
        await _firestore
            .collection('accountRequests')
            .doc(requestId)
            .collection('privateCredentials')
            .doc('temporary')
            .delete();
        if (_accountRequestData?['temporaryPassword'] is String) {
          await _firestore.collection('accountRequests').doc(requestId).update({
            'temporaryPassword': FieldValue.delete(),
          });
        }
        _approvalRequestId = null;
      }
      await _accountRequestSubscription?.cancel();
      _accountRequestSubscription = null;
      _accountRequestData = null;
      _currentUser!.mustChangePassword = false;
      notifyListeners();
      return null;
    } catch (error) {
      return _errorMessage(error);
    }
  }

  Future<String?> updateProfile({
    required String fullName,
    required String email,
    String? gender,
    String? college,
    String? yearLevel,
    String? block,
  }) async {
    if (_currentUser == null) return 'No user is currently logged in.';

    if (_forTesting) {
      _currentUser!
        ..fullName = fullName.trim()
        ..email = email.trim()
        ..gender = gender
        ..college = college
        ..yearLevel = yearLevel
        ..block = block;
      notifyListeners();
      return null;
    }

    final user = _auth!.currentUser;
    if (user == null) return 'No user is currently logged in.';

    try {
      final normalizedName = fullName.trim();
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail != user.email?.toLowerCase()) {
        await user.verifyBeforeUpdateEmail(normalizedEmail);
      }

      await _firestore!.collection('accounts').doc(user.uid).update({
        'name': normalizedName,
        'gender': gender,
        'college': college,
        'course': college ?? '',
        'yearLevel': yearLevel,
        'block': block,
        'profileUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      _currentUser!
        ..fullName = normalizedName
        ..gender = gender
        ..college = college
        ..yearLevel = yearLevel
        ..block = block;
      notifyListeners();
      if (user.displayName != normalizedName) {
        await user.updateDisplayName(normalizedName);
      }
      return null;
    } catch (error) {
      return _errorMessage(error);
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_forTesting) return null;

    final user = _auth!.currentUser;
    if (user == null || user.email == null) {
      return 'No user is currently logged in.';
    }

    try {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } catch (error) {
      return _errorMessage(error);
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    if (_forTesting) return null;

    try {
      await _auth!.sendPasswordResetEmail(email: email.trim());
      return null;
    } catch (error) {
      return _errorMessage(error);
    }
  }

  Future<void> logout() async {
    await _accountRequestSubscription?.cancel();
    _accountRequestSubscription = null;
    await _temporaryCredentialSubscription?.cancel();
    _temporaryCredentialSubscription = null;
    await _accountStatusSubscription?.cancel();
    _accountStatusSubscription = null;
    if (!_forTesting) {
      await _auth!.signOut();
      await SessionPreferenceStore.setKeepSignedIn(false);
    }
    await _clearRequestStatusCredentials();
    _currentUser = null;
    _accountRequestData = null;
    notifyListeners();
  }

  static String _errorMessage(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'An account with that email already exists.';
        case 'requires-recent-login':
          return 'Please sign in again before changing your password or email.';
        case 'weak-password':
          return 'Choose a stronger password.';
        case 'network-request-failed':
          return 'Could not connect. Check your internet connection and try again.';
      }
      return error.message ?? 'Authentication failed.';
    }
    if (error is FirebaseException) {
      return error.message ?? 'Could not connect to the account database.';
    }
    if (error is StateError) return error.message;
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    _requestStatusTimer?.cancel();
    _authStateSubscription?.cancel();
    _accountRequestSubscription?.cancel();
    super.dispose();
  }
}
