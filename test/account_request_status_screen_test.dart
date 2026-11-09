import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/screens/account_request_status_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'approved request notifies the requester and continues to login',
    (tester) async {
      var continuedToLogin = false;
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
              onContinueToLogin: () => continuedToLogin = true,
              onRequestAgain: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(continuedToLogin, isTrue);
      expect(find.text('Account approved'), findsOneWidget);
      expect(
        find.textContaining('sent to requester@example.com'),
        findsOneWidget,
      );
    },
  );
}
