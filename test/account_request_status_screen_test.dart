import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/screens/account_request_status_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('approved request displays the emailed temporary password', (
    tester,
  ) async {
    final authProvider = AuthProvider.forTesting(
      accountRequestData: {
        'status': 'approved',
        'credentialEmailStatus': 'sent',
        'temporaryPassword': 'temporary-pass-123',
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: MaterialApp(
          home: AccountRequestStatusScreen(
            email: 'requester@example.com',
            onContinueToLogin: () {},
            onRequestAgain: () {},
          ),
        ),
      ),
    );

    expect(find.text('temporary-pass-123'), findsOneWidget);
    expect(
      find.textContaining('emailed to requester@example.com'),
      findsOneWidget,
    );
    expect(find.text('Continue to Login'), findsOneWidget);
  });
}
