// lib/providers/auth_provider.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Result of a Request Account submission.
/// Since this is a prototype with no real email server, the generated
/// temporary password is returned directly so the UI can display it
/// (standing in for "the email the Admin would have sent").
class RequestAccountResult {
  final bool success;
  final String? error;
  final String? tempPassword;

  RequestAccountResult.success(this.tempPassword)
    : success = true,
      error = null;

  RequestAccountResult.failure(this.error)
    : success = false,
      tempPassword = null;
}

/// Handles authentication using in-memory mock data.
/// No backend/Firebase yet — everything lives in RAM for this prototype.
///
/// In a real deployment, an Admin would create accounts on a separate web
/// system and email the temporary password. Since this is a school project
/// prototype (not deployed to a real school), Request Account below
/// simulates that same account-creation step directly in the mobile app,
/// generating a temporary password instead of actually sending an email.
class AuthProvider extends ChangeNotifier {
  final List<UserModel> _users = [
    // Temporary account para makapag login agad sa app.
    UserModel(
      id: 'u1',
      fullName: 'Ardy',
      email: 'ardy@gmail.com',
      password: 'Ardy123',
      role: UserRole.student,
      idNumber: '2023-00123',
      mustChangePassword: false,
      yearLevel: '1st year',
      college: 'BSIT',
      block: '4',
      gender: 'Male',
    ),
  ];

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  void updateProfilePhoto(Uint8List imageBytes) {
    if (_currentUser == null) return;

    _currentUser!.profileImageBytes = imageBytes;
    notifyListeners();
  }

  /// Attempts to log a user in against the in-memory list.
  /// Returns null on success, or an error message string on failure.
  Future<String?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400)); // simulate latency

    final matches = _users.where(
      (u) =>
          u.email.toLowerCase() == email.trim().toLowerCase() &&
          u.password == password,
    );

    if (matches.isEmpty) return 'Invalid email or password.';

    _currentUser = matches.first;
    notifyListeners();
    return null;
  }

  /// Simulates the Admin creating an account and emailing a temporary
  /// password. Generates the account here (with a random temp password)
  /// since this prototype has no real email server to send it through.
  Future<RequestAccountResult> requestAccount({
    required String fullName,
    required String email,
    required UserRole role,
    required String idNumber,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final alreadyExists = _users.any(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
    );
    if (alreadyExists) {
      return RequestAccountResult.failure(
        'An account with that email already exists.',
      );
    }

    final tempPassword = _generateTempPassword();

    _users.add(
      UserModel(
        id: 'u${_users.length + 1}',
        fullName: fullName.trim(),
        email: email.trim(),
        password: tempPassword,
        role: role,
        idNumber: idNumber.trim(),
        mustChangePassword: true, // must be changed on first login
      ),
    );

    notifyListeners();
    return RequestAccountResult.success(tempPassword);
  }

  /// Generates an 8-character random temporary password.
  /// Excludes visually-confusing characters (0/O, 1/l/I).
  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final rand = Random();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Sets a new password for the currently logged-in user and clears their
  /// "must change password" flag. Called from SetNewPasswordScreen after a
  /// temporary-password login.
  Future<String?> setNewPassword(String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (_currentUser == null) return 'No user is currently logged in.';

    _currentUser!.password = newPassword;
    _currentUser!.mustChangePassword = false;
    notifyListeners();
    return null;
  }

  /// Updates the currently logged-in user's editable profile fields.
  /// Called from the Account Info screen.
  Future<String?> updateProfile({
    required String fullName,
    required String email,
    String? gender,
    String? college,
    String? yearLevel,
    String? block,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (_currentUser == null) return 'No user is currently logged in.';

    final emailTaken = _users.any(
      (u) =>
          u.id != _currentUser!.id &&
          u.email.toLowerCase() == email.trim().toLowerCase(),
    );
    if (emailTaken) return 'That email is already used by another account.';

    _currentUser!.fullName = fullName.trim();
    _currentUser!.email = email.trim();
    _currentUser!.gender = gender;
    _currentUser!.college = college;
    _currentUser!.yearLevel = yearLevel;
    _currentUser!.block = block;
    notifyListeners();
    return null;
  }

  /// Voluntary password change from the Settings screen — different from
  /// setNewPassword(), which is only used for the forced first-login flow.
  /// Requires the user's current password to be entered correctly.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (_currentUser == null) return 'No user is currently logged in.';
    if (_currentUser!.password != currentPassword) {
      return 'Current password is incorrect.';
    }

    _currentUser!.password = newPassword;
    notifyListeners();
    return null;
  }

  /// Mock "forgot password" flow. Since there's no real email/backend
  /// service yet, this just checks whether the email exists and pretends
  /// to send a reset link.
  Future<String?> sendPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final exists = _users.any(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
    );
    if (!exists) return 'No account found with that email address.';
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
