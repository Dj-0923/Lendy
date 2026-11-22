import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/notification_provider.dart';
import 'package:lendy/screens/notification_settings_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('each notification switch shows an on/off snackbar', (
    tester,
  ) async {
    final notifications = NotificationProvider();
    addTearDown(notifications.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifications,
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );

    expect(
      find.byKey(const Key('notification-preference-status')),
      findsNothing,
    );

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Returns reminders off'), findsOneWidget);

    await tester.tap(find.byType(Switch).at(0));
    await tester.pumpAndSettle();
    expect(find.text('Request approved / rejected off'), findsOneWidget);

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Push notifications off'), findsOneWidget);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Returns reminders on'), findsOneWidget);
  });
}
