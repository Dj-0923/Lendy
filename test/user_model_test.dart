import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/user_model.dart';

void main() {
  test('loads profile photo and account details from Firestore data', () {
    final photoBytes = [1, 2, 3, 4];
    final user = UserModel.fromMap(
      id: 'user-1',
      data: {
        'name': 'Test User',
        'email': 'test@example.com',
        'role': 'student',
        'idNumber': '123',
        'gender': 'Female',
        'college': 'BSIT',
        'yearLevel': '3rd Year',
        'block': '7',
        'profileImage': 'data:image/jpeg;base64,${base64Encode(photoBytes)}',
      },
    );

    expect(user.fullName, 'Test User');
    expect(user.email, 'test@example.com');
    expect(user.gender, 'Female');
    expect(user.college, 'BSIT');
    expect(user.yearLevel, '3rd Year');
    expect(user.block, '7');
    expect(user.profileImageBytes, photoBytes);
  });
}
