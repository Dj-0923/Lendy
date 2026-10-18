import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/user_model.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/providers/request_provider.dart';
import 'package:lendy/screens/profile_screen.dart';
import 'package:provider/provider.dart';

void main() {
  late EquipmentProvider equipment;

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
    final auth = AuthProvider();
    final requestFuture = auth.requestAccount(
      fullName: 'Jane Doe',
      email: 'jane.faculty@example.com',
      role: UserRole.faculty,
      idNumber: 'FAC-001',
    );
    await tester.pump(const Duration(milliseconds: 600));
    final accountResult = await requestFuture;

    final loginFuture = auth.login(
      'jane.faculty@example.com',
      accountResult.tempPassword!,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(await loginFuture, isNull);

    auth.currentUser!.college = 'BSIT';
    auth.currentUser!.gender = 'Female';
    return auth;
  }

  Future<AuthProvider> loginStudent(WidgetTester tester) async {
    final auth = AuthProvider();
    const email = 'student@example.com';
    final accountFuture = auth.requestAccount(
      fullName: 'Student User',
      email: email,
      role: UserRole.student,
      idNumber: 'STU-001',
    );
    await tester.pump(const Duration(milliseconds: 600));
    final accountResult = await accountFuture;

    final loginFuture = auth.login(email, accountResult.tempPassword!);
    await tester.pump(const Duration(milliseconds: 500));
    expect(await loginFuture, isNull);
    return auth;
  }

  testWidgets('Faculty sees only role, department, and gender details', (
    tester,
  ) async {
    final auth = await loginFaculty(tester);
    await pumpProfile(tester, auth);

    expect(find.text('Account role'), findsOneWidget);
    expect(find.text('Department'), findsOneWidget);
    expect(find.text('BSIT'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Year Level'), findsNothing);
    expect(find.text('College'), findsNothing);
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
