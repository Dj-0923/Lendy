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

  testWidgets('Loans replaces Request in the bottom navigation', (
    tester,
  ) async {
    await pumpMainShell(tester);

    expect(find.text('Request'), findsNothing);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.byKey(const Key('main-scan-button')), findsOneWidget);
    expect(find.byKey(const Key('browse-search-scanner')), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
    final avatarOutline = tester.widget<Container>(
      find.byKey(const Key('dashboard-profile-outline')),
    );
    final avatarDecoration = avatarOutline.decoration! as BoxDecoration;
    expect(avatarDecoration.border!.top.color, const Color(0xFF9FE3A5));
    final header = tester.widget<Container>(
      find.byKey(const Key('dashboard-header')),
    );
    final headerDecoration = header.decoration! as BoxDecoration;
    expect(
      headerDecoration.borderRadius,
      const BorderRadius.only(
        bottomLeft: Radius.circular(40),
        bottomRight: Radius.circular(40),
      ),
    );
    final notificationCircle = tester.widget<Container>(
      find.byKey(const Key('dashboard-notification-circle')),
    );
    final notificationDecoration =
        notificationCircle.decoration! as BoxDecoration;
    expect(notificationDecoration.shape, BoxShape.circle);
    expect(
      tester.getSize(find.byKey(const Key('dashboard-notification-circle'))),
      const Size(36, 36),
    );
    await tester.tap(find.text('Loans').last);
    await tester.pumpAndSettle();
    final loansHeaderHeight = tester
        .getSize(find.byKey(const Key('loans-header')))
        .height;
    final loansHeader = tester.widget<Container>(
      find.byKey(const Key('loans-header')),
    );
    expect((loansHeader.decoration! as BoxDecoration).borderRadius, isNull);
    expect(find.text('Loans'), findsWidgets);
    expect(find.byKey(const Key('loans-header')), findsOneWidget);
    expect(find.byKey(const Key('loans-back')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-profile-avatar')), findsNothing);
    expect(find.byKey(const Key('dashboard-notifications')), findsNothing);
    expect(find.byKey(const Key('main-scan-button')), findsNothing);
    expect(find.text('Messages'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(
      find.text('Track everything you\'ve borrowed, requested, or returned.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('loans-back')));
    await tester.pumpAndSettle();

    expect(find.text('Browse Items'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('dashboard-header'))).height,
      greaterThan(loansHeaderHeight),
    );
  });

  testWidgets('Loans shows a badge for unread loan updates', (tester) async {
    await pumpMainShell(tester);

    expect(find.byKey(const Key('loans-nav-badge')), findsNothing);

    notifications.addNotification('Request approved');
    await tester.pump();

    expect(find.byKey(const Key('loans-nav-badge')), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await notifications.markAllRead();
    await tester.pump();

    expect(find.byKey(const Key('loans-nav-badge')), findsNothing);
  });

  testWidgets('system back from Notification returns to Home', (tester) async {
    await pumpMainShell(tester);
    notifications.addNotification('Request approved');
    await tester.pump();
    expect(
      find.byKey(const Key('dashboard-notification-badge')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('dashboard-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-profile-avatar')), findsNothing);
    expect(find.byKey(const Key('dashboard-notifications')), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(notifications.unreadCount, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Browse Items'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-notification-badge')), findsNothing);
  });

  testWidgets('Notifications back button returns to Home', (tester) async {
    await pumpMainShell(tester);

    await tester.tap(find.text('Loans').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loans-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Browse Items'), findsOneWidget);
  });

  testWidgets('Messages opens a full-screen conversation with a back button', (
    tester,
  ) async {
    await pumpMainShell(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('messages-back')), findsOneWidget);
    expect(find.text('Lendy Admin'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-notifications')), findsNothing);
    expect(find.byKey(const Key('main-scan-button')), findsNothing);
    expect(find.text('Scan'), findsNothing);
    expect(find.text('Home'), findsNothing);

    await tester.tap(find.byKey(const Key('messages-back')));
    await tester.pumpAndSettle();

    expect(find.text('Browse Items'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets('system back from Messages returns to Home', (tester) async {
    await pumpMainShell(tester);

    await tester.tap(find.text('Loans').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loans-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Browse Items'), findsOneWidget);
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
