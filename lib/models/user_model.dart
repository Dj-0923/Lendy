// lib/models/user_model.dart

import 'dart:typed_data';
import 'dart:convert';

/// Role of a user in the system.
/// Only Student and Faculty exist in this mobile app (no Admin role here —
/// account creation and approval decisions happen on a separate admin web
/// system).
enum UserRole { student, faculty }

extension UserRoleX on UserRole {
  String get label => this == UserRole.student ? 'Student' : 'Faculty';
}

/// Represents an approved user account shared by the mobile and admin apps.
class UserModel {
  final String id;
  String fullName; // editable via Account Info
  String email; // editable via Account Info
  final UserRole role;
  final String idNumber;
  final String status;
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
    required this.role,
    required this.idNumber,
    this.status = 'active',
    this.mustChangePassword = true,
    this.yearLevel,
    this.college,
    this.block,
    this.gender,
    this.profileImageBytes,
  });

  factory UserModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return UserModel(
      id: id,
      fullName: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] == UserRole.faculty.name
          ? UserRole.faculty
          : UserRole.student,
      idNumber: data['idNumber'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      mustChangePassword: data['mustChangePassword'] as bool? ?? false,
      yearLevel: data['yearLevel'] as String?,
      college: data['college'] as String? ?? data['course'] as String?,
      block: data['block'] as String?,
      gender: data['gender'] as String?,
      profileImageBytes: _decodeProfileImage(data['profileImage']),
    );
  }

  static Uint8List? _decodeProfileImage(Object? value) {
    if (value is! String || !value.startsWith('data:image/')) return null;
    final separator = value.indexOf(',');
    if (separator < 0) {
      throw const FormatException('Invalid profile image data URI.');
    }
    return base64Decode(value.substring(separator + 1));
  }
}
