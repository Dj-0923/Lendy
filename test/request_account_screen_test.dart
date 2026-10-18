import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/screens/request_account_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('request account includes a required College text field', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(),
        child: const MaterialApp(home: RequestAccountScreen()),
      ),
    );

    expect(find.text('College'), findsOneWidget);
    expect(find.text('e.g. College of Computer Studies'), findsOneWidget);
  });
}
