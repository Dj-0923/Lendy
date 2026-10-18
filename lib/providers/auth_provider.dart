import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../utils/first_launch_store.dart';
import '../utils/session_preference_store.dart';

class RequestAccountResult {
  final bool success;
  final String? error;

  RequestAccountResult.success() : success = true, error = null;

  RequestAccountResult.failure(this.error) : success = false;
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
  }

  AuthProvider.forTesting({UserModel? currentUser})
    : _auth = null,
      _firestore = null,
      _forTesting = true,
      _isReady = true,
      _currentUser = currentUser;

  final firebase_auth.FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final bool _forTesting;
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _accountRequestSubscription;
  UserModel? _currentUser;
  Map<String, dynamic>? _accountRequestData;
  String? _approvalRequestId;
  bool _isReady;
  String? _authError;
  bool _accountRequestInProgress = false;
  bool _loginInProgress = false;

  UserModel? get currentUser => _currentUser;
  Map<String, dynamic>? get accountRequestData => _accountRequestData;
  bool get isLoggedIn => _currentUser != null;
  bool get isReady => _isReady;
  String? get authError => _authError;

  Future<void> _handleAuthStateChanged(firebase_auth.User? user) async {
    if (_accountRequestInProgress || _loginInProgress) return;
    if (user == null) {
      await _accountRequestSubscription?.cancel();
      _accountRequestSubscription = null;
      _currentUser = null;
      _accountRequestData = null;
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
        if (data['status'] == 'approved' &&
            data['temporaryPassword'] is String) {
          final account = await _firestore
              .collection('accounts')
              .doc(user.uid)
              .get();
          if (account.data()?['status'] == 'active' &&
              account.data()?['mustChangePassword'] == true) {
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
          _accountRequestData = null;
          _approvalRequestId = null;
          _authError = 'The account request could not be found.';
        } else {
          final data = snapshot.data()!;
          final isWaiting =
              data['status'] == 'pending' || data['status'] == 'rejected';
          final hasTemporaryPassword =
              data['status'] == 'approved' &&
              data['temporaryPassword'] is String;
          if (isWaiting || hasTemporaryPassword) {
            _accountRequestData = data;
          } else {
            _accountRequestData = null;
            _approvalRequestId = null;
            _accountRequestSubscription?.cancel();
            _accountRequestSubscription = null;
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
      throw StateError('This account is disabled. Contact an administrator.');
    }
    if (user.email != null && data['email'] != user.email) {
      await snapshot.reference.update({'email': user.email});
    }

    return UserModel.fromMap(
      id: user.uid,
      data: {...data, 'email': user.email ?? data['email']},
    );
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
        if (data['status'] == 'approved' &&
            data['temporaryPassword'] is String) {
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
  }) async {
    if (_forTesting) {
      return RequestAccountResult.success();
    }

    _accountRequestInProgress = true;
    firebase_auth.User? createdUser;
    try {
      final random = Random.secure();
      final randomPassword = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: randomPassword,
      );
      createdUser = credential.user;
      if (createdUser == null) {
        throw StateError('Could not create the authentication account.');
      }
      await createdUser.updateDisplayName(fullName.trim());
      final request = _firestore!.collection('accountRequests').doc();
      await request.set({
        'id': request.id,
        'authUid': createdUser.uid,
        'name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'role': role.name,
        'idNumber': idNumber.trim(),
        'college': college.trim(),
        'status': 'pending',
        'submittedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      _accountRequestData = {
        'id': request.id,
        'authUid': createdUser.uid,
        'name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'status': 'pending',
      };
      _approvalRequestId = request.id;
      _watchAccountRequest(request);
      return RequestAccountResult.success();
    } catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (cleanupError) {
          _accountRequestInProgress = false;
          return RequestAccountResult.failure(
            '${_errorMessage(error)} The sign-in account was created but could '
            'not be removed; contact an administrator before retrying '
            '(${_errorMessage(cleanupError)}).',
          );
        }
      }
      return RequestAccountResult.failure(_errorMessage(error));
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
      await user.updatePassword(newPassword);
      await _firestore!.collection('accounts').doc(user.uid).update({
        'mustChangePassword': false,
      });
      if (_approvalRequestId case final requestId?) {
        await _firestore.collection('accountRequests').doc(requestId).update({
          'temporaryPassword': FieldValue.delete(),
        });
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
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail != user.email?.toLowerCase()) {
        await user.verifyBeforeUpdateEmail(normalizedEmail);
      }

      await _firestore!.collection('accounts').doc(user.uid).update({
        'name': fullName.trim(),
        'gender': gender,
        'college': college,
        'course': college ?? '',
        'yearLevel': yearLevel,
        'block': block,
        'profileUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      _currentUser!
        ..fullName = fullName.trim()
        ..gender = gender
        ..college = college
        ..yearLevel = yearLevel
        ..block = block;
      notifyListeners();
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
    if (!_forTesting) {
      await _auth!.signOut();
      await SessionPreferenceStore.setKeepSignedIn(false);
    }
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
    _authStateSubscription?.cancel();
    _accountRequestSubscription?.cancel();
    super.dispose();
  }
}
