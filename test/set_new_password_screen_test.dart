import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/screens/set_new_password_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('password fields omit lock icons but keep visibility buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(),
        child: const MaterialApp(home: SetNewPasswordScreen()),
      ),
    );

    final fields = tester.widgetList<InputDecorator>(
      find.byType(InputDecorator),
    );
    expect(fields, hasLength(2));
    for (final field in fields) {
      expect(field.decoration.prefixIcon, isNull);
      expect(field.decoration.suffixIcon, isNotNull);
    }
  });
}
