import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/providers/notification_provider.dart';
import 'package:lendy/providers/request_provider.dart';
import 'package:lendy/screens/main_shell.dart';
import 'package:provider/provider.dart';

void main() {
  late AuthProvider auth;
  late EquipmentProvider equipment;
  late RequestProvider requests;
  late NotificationProvider notifications;

  Future<void> pumpMainShell(WidgetTester tester) async {
    auth = AuthProvider.forTesting();
    equipment = EquipmentProvider();
    requests = RequestProvider(equipment);
    notifications = NotificationProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: equipment),
          ChangeNotifierProvider.value(value: requests),
          ChangeNotifierProvider.value(value: notifications),
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('system back from Request returns to Home', (tester) async {
    await pumpMainShell(tester);

    await tester.tap(find.text('Request').last);
    await tester.pumpAndSettle();
    expect(find.text('My requests'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Browse Item'), findsOneWidget);
  });

  testWidgets('system back from Notification returns to Home', (tester) async {
    await pumpMainShell(tester);

    await tester.tap(find.text('Notification').last);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Browse Item'), findsOneWidget);
  });

  testWidgets('system back on Home shows exit prompt', (tester) async {
    await pumpMainShell(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Tap again to exit'), findsOneWidget);
  });

  testWidgets('second system back on Home exits the app', (tester) async {
    await pumpMainShell(tester);
    var exited = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemNavigator.pop') exited = true;
          return null;
        });

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(exited, isTrue);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}
