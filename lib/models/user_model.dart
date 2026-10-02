// lib/models/user_model.dart

import 'dart:typed_data';

/// Role of a user in the system.
/// Only Student and Faculty exist in this mobile app (no Admin role here —
/// account creation and approval decisions happen on a separate admin web
/// system).
enum UserRole { student, faculty }

extension UserRoleX on UserRole {
  String get label => this == UserRole.student ? 'Student' : 'Faculty';
}

/// Represents a user account. Accounts are created by an Admin on the
/// separate web system (not this mobile app) — the Admin emails the user a
/// temporary password, and [mustChangePassword] stays true until the user
/// sets their own password after their first login.
class UserModel {
  final String id;
  String fullName; // editable via Account Info
  String email; // editable via Account Info
  String
  password; // mutable — updated via AuthProvider.setNewPassword()/changePassword()
  final UserRole role;
  final String idNumber;
  bool mustChangePassword;

  // Optional profile fields, editable via Account Info.
  // Shown as "N/A" elsewhere in the app when null.
  String? yearLevel;
  String? college;
  String? block;
  String? gender;
  Uint8List? profileImageBytes;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    required this.idNumber,
    this.mustChangePassword = true,
    this.yearLevel,
    this.college,
    this.block,
    this.gender,
  });
}
