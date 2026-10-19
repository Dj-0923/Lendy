import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/user_model.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/providers/notification_provider.dart';
import 'package:lendy/providers/request_provider.dart';
import 'package:lendy/screens/profile_screen.dart';
import 'package:provider/provider.dart';

void main() {
  late EquipmentProvider equipment;

  test('providers start without preloaded sample data', () async {
    final auth = AuthProvider.forTesting();
    final equipment = EquipmentProvider();
    final requests = RequestProvider(equipment);
    final notifications = NotificationProvider();

    expect(equipment.filteredEquipment, isEmpty);
    expect(requests.requestsForUser('u1'), isEmpty);
    expect(notifications.notifications, isEmpty);
    expect(
      await auth.login('user@example.invalid', 'not-a-real-password'),
      'Invalid email or password.',
    );
  });

  Future<void> pumpProfile(WidgetTester tester, AuthProvider auth) async {
    equipment = EquipmentProvider();
    final requests = RequestProvider(equipment);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: equipment),
          ChangeNotifierProvider.value(value: requests),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<AuthProvider> loginFaculty(WidgetTester tester) async {
    final auth = AuthProvider.forTesting(
      currentUser: UserModel(
        id: 'faculty-1',
        fullName: 'Jane Doe',
        email: 'jane.faculty@example.com',
        role: UserRole.faculty,
        idNumber: 'FAC-001',
      ),
    );
    auth.currentUser!.college = 'BSIT';
    auth.currentUser!.gender = 'Female';
    return auth;
  }

  Future<AuthProvider> loginStudent(WidgetTester tester) async {
    return AuthProvider.forTesting(
      currentUser: UserModel(
        id: 'student-1',
        fullName: 'Student User',
        email: 'student@example.com',
        role: UserRole.student,
        idNumber: 'STU-001',
      ),
    );
  }

  testWidgets('Faculty sees college but not student details', (
    tester,
  ) async {
    final auth = await loginFaculty(tester);
    await pumpProfile(tester, auth);

    expect(find.text('Account role'), findsOneWidget);
    expect(find.text('College'), findsOneWidget);
    expect(find.text('BSIT'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Year Level'), findsNothing);
    expect(find.text('Department'), findsNothing);
    expect(find.text('Block'), findsNothing);
  });

  testWidgets('Student retains year level, college, and block details', (
    tester,
  ) async {
    final auth = await loginStudent(tester);
    await pumpProfile(tester, auth);

    expect(find.text('Account role'), findsOneWidget);
    expect(find.text('Year Level'), findsOneWidget);
    expect(find.text('College'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Department'), findsNothing);
  });
}
