import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/providers/request_provider.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/models/user_model.dart';
import 'package:lendy/screens/borrower_assistant_screen.dart';
import 'package:lendy/screens/browse_screen.dart';
import 'package:lendy/services/borrower_assistant_service.dart';
import 'package:lendy/utils/borrower_assistant_conversation_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpMaintenanceAssistant(
  WidgetTester tester,
  List<EquipmentModel> equipment,
) async {
  final client = MockClient(
    (_) async =>
        throw StateError('Maintenance questions should use inventory.'),
  );
  addTearDown(client.close);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider.forTesting()),
        ChangeNotifierProvider(
          create: (_) => EquipmentProvider(initialEquipment: equipment),
        ),
      ],
      child: MaterialApp(
        home: BorrowerAssistantScreen(
          service: BorrowerAssistantService(
            client: client,
            getIdToken: () async => 'test-token',
            apiUrl: 'https://example.test',
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'saves a reply after leaving the assistant and shows a Browse notice',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      BorrowerAssistantConversationStore.replyNotice.value = null;
      final responseCompleter = Completer<http.Response>();
      var requestStarted = false;
      final client = MockClient((_) {
        requestStarted = true;
        return responseCompleter.future;
      });
      addTearDown(client.close);
      const userId = 'assistant-reply-test-user';

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider.forTesting(
                currentUser: UserModel(
                  id: userId,
                  fullName: 'Test Borrower',
                  email: 'borrower@example.test',
                  role: UserRole.student,
                  idNumber: 'TEST-001',
                  mustChangePassword: false,
                ),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => EquipmentProvider(initialEquipment: const []),
            ),
          ],
          child: MaterialApp(
            home: BrowseScreen(
              assistantService: BorrowerAssistantService(
                client: client,
                getIdToken: () async => 'test-token',
                apiUrl: 'https://example.test',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('browse-ai-assistant-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'What items are available?',
      );
      await tester.tap(find.byKey(const Key('borrower-assistant-send')));
      await tester.pump();
      expect(requestStarted, isTrue);

      Navigator.of(tester.element(find.byType(BorrowerAssistantScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      responseCompleter.complete(
        http.Response(
          jsonEncode({'answer': 'The projector is available.', 'items': []}),
          200,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final replyBadge = find.byKey(const Key('browse-ai-reply-badge'));
      expect(replyBadge, findsOneWidget);
      expect(
        find.descendant(of: replyBadge, matching: find.text('1')),
        findsOneWidget,
      );
      final savedConversation = await BorrowerAssistantConversationStore.load(
        userId,
      );
      final assistantRect = tester.getRect(
        find.byKey(const Key('browse-ai-assistant-button')),
      );
      expect(assistantRect.right, greaterThan(0));
      await tester.tap(find.byKey(const Key('browse-ai-assistant-button')));
      await tester.pumpAndSettle();

      expect(find.text('What items are available?'), findsOneWidget);
      expect(find.text('The projector is available.'), findsOneWidget);
      expect(BorrowerAssistantConversationStore.replyNotice.value, isNull);
      expect(replyBadge, findsNothing);
      expect(
        savedConversation?.messages.map((message) => message.text),
        contains('The projector is available.'),
      );
      Navigator.of(tester.element(find.byType(BorrowerAssistantScreen))).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('maintenance question shows only maintenance items', (
    tester,
  ) async {
    final equipment = [
      EquipmentModel.fromFirestore(
        documentId: 'maintenance-monitor',
        data: {
          'name': 'Maintenance Monitor',
          'category': 'Computers',
          'location': 'Technical Room',
        },
        status: EquipmentStatus.maintenance,
      ),
      EquipmentModel.fromFirestore(
        documentId: 'available-camera',
        data: {
          'name': 'Available Camera',
          'category': 'Cameras',
          'location': 'Storage Room',
        },
        status: EquipmentStatus.available,
      ),
    ];
    await pumpMaintenanceAssistant(tester, equipment);

    await tester.enterText(find.byType(TextField), 'maintenance items?');
    await tester.tap(find.byKey(const Key('borrower-assistant-send')));
    await tester.pumpAndSettle();

    expect(
      find.text('1 item(s) are currently in maintenance.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('assistant-landscape-item-maintenance-monitor')),
      findsOneWidget,
    );
    expect(find.text('Available Camera'), findsNothing);
  });

  testWidgets('maintenance question says when the inventory has no matches', (
    tester,
  ) async {
    final equipment = [
      EquipmentModel.fromFirestore(
        documentId: 'available-camera',
        data: {
          'name': 'Available Camera',
          'category': 'Cameras',
          'location': 'Storage Room',
        },
        status: EquipmentStatus.available,
      ),
    ];
    await pumpMaintenanceAssistant(tester, equipment);

    await tester.enterText(find.byType(TextField), 'maintenance items?');
    await tester.tap(find.byKey(const Key('borrower-assistant-send')));
    await tester.pumpAndSettle();

    expect(
      find.text('There are no items in maintenance right now.'),
      findsOneWidget,
    );
    expect(find.text('Available Camera'), findsNothing);
  });

  testWidgets(
    'shows typing while waiting and lets borrowers request a suggested item',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final responseCompleter = Completer<http.Response>();
      var requestCount = 0;
      final client = MockClient((request) async {
        expect(request.url.path, '/borrower-assistant');
        expect(request.headers['Authorization'], 'Bearer test-token');
        requestCount++;
        expect(jsonDecode(request.body), {
          'question': 'What items are available?',
        });
        return responseCompleter.future;
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider.forTesting()),
            ChangeNotifierProvider(create: (_) => EquipmentProvider()),
            ChangeNotifierProxyProvider<EquipmentProvider, RequestProvider>(
              create: (context) =>
                  RequestProvider(context.read<EquipmentProvider>()),
              update: (context, equipment, requests) =>
                  requests ?? RequestProvider(equipment),
            ),
          ],
          child: MaterialApp(
            home: BorrowerAssistantScreen(
              service: BorrowerAssistantService(
                client: client,
                getIdToken: () async => 'test-token',
                apiUrl: 'https://example.test',
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final assistantAvatar = tester.widget<CircleAvatar>(
        find.byKey(const Key('assistant-profile-avatar')),
      );
      expect(
        assistantAvatar.backgroundImage,
        const AssetImage('assets/images/botpfp.png'),
      );
      expect(
        find.byKey(const Key('assistant-suggestions-list')),
        findsOneWidget,
      );
      expect(find.text('Available items?'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'What items are available?',
      );
      await tester.tap(find.byKey(const Key('borrower-assistant-send')));
      await tester.pump();

      expect(find.bySemanticsLabel('Assistant is typing'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      responseCompleter.complete(
        http.Response(
          jsonEncode({
            'answer':
                'One projector is available. Choose one below to request it.',
            'items': [
              {
                'id': 'projector-1',
                'name': 'Projector',
                'category': 'Projectors',
                'location': 'AV Room',
                'tag': 'PRJ-001',
                'status': 'Available',
              },
            ],
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();

      final conversation = find.byType(ListView).first;
      await tester.drag(conversation, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('What items are available?'), findsOneWidget);
      await tester.drag(conversation, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'One projector is available. Choose one below to request it.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('assistant-suggestions-list')), findsNothing);
      expect(find.text('Projector'), findsOneWidget);
      expect(find.text('PROJECTORS'), findsOneWidget);
      expect(find.text('PRJ-001'), findsOneWidget);
      expect(find.text('AV Room'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('assistant-landscape-item-projector-1')),
        findsOneWidget,
      );
      final requestButton = find.byKey(
        const Key('assistant-request-item-projector-1'),
      );
      expect(requestButton, findsOneWidget);

      await tester.tap(requestButton);
      await tester.pumpAndSettle();
      expect(find.text('Request Equipment'), findsOneWidget);
      expect(find.text('Projector'), findsOneWidget);

      Navigator.of(tester.element(find.text('Request Equipment'))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant-suggestions-list')), findsNothing);
      expect(
        find.byKey(const Key('assistant-suggestion-Available items?')),
        findsNothing,
      );
      expect(requestCount, 1);
    },
  );

  testWidgets('selecting a suggested question hides the recommendations', (
    tester,
  ) async {
    final client = MockClient((request) async {
      expect(jsonDecode(request.body), {'question': 'Camera to borrow?'});
      return http.Response(
        jsonEncode({'answer': 'Oo, may camera.', 'items': []}),
        200,
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider.forTesting()),
          ChangeNotifierProvider(create: (_) => EquipmentProvider()),
          ChangeNotifierProxyProvider<EquipmentProvider, RequestProvider>(
            create: (context) =>
                RequestProvider(context.read<EquipmentProvider>()),
            update: (context, equipment, requests) =>
                requests ?? RequestProvider(equipment),
          ),
        ],
        child: MaterialApp(
          home: BorrowerAssistantScreen(
            service: BorrowerAssistantService(
              client: client,
              getIdToken: () async => 'test-token',
              apiUrl: 'https://example.test',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('assistant-suggestions-list')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('assistant-suggestion-Camera to borrow?')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camera to borrow?'), findsOneWidget);
    expect(find.text('Oo, may camera.'), findsOneWidget);
    expect(find.byKey(const Key('assistant-suggestions-list')), findsNothing);
    expect(
      find.byKey(const Key('assistant-suggestion-Camera to borrow?')),
      findsNothing,
    );
  });

  testWidgets('item replies show remaining count and hide expanded items', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'answer': 'I found 3 cameras.',
          'items': [
            {
              'id': 'camera-1',
              'name': 'Camera One',
              'category': 'Cameras',
              'location': 'Room 1',
              'tag': 'CAM-001',
              'status': 'Available',
            },
            {
              'id': 'camera-2',
              'name': 'Camera Two',
              'category': 'Cameras',
              'location': 'Room 2',
              'tag': 'CAM-002',
              'status': 'Available',
            },
            {
              'id': 'camera-3',
              'name': 'Camera Three',
              'category': 'Cameras',
              'location': 'Room 3',
              'tag': 'CAM-003',
              'status': 'Available',
            },
          ],
        }),
        200,
      ),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider.forTesting()),
          ChangeNotifierProvider(create: (_) => EquipmentProvider()),
        ],
        child: MaterialApp(
          home: BorrowerAssistantScreen(
            service: BorrowerAssistantService(
              client: client,
              getIdToken: () async => 'test-token',
              apiUrl: 'https://example.test',
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Cameras');
    await tester.tap(find.byKey(const Key('borrower-assistant-send')));
    await tester.pumpAndSettle();

    expect(find.text('Camera One'), findsOneWidget);
    expect(find.text('Camera Two'), findsOneWidget);
    expect(find.text('Camera Three'), findsNothing);
    expect(find.text('Show 1 more'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-show-more-items')));
    await tester.pumpAndSettle();

    expect(find.text('Camera Three'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('assistant-show-more-items')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-show-more-items')));
    await tester.pumpAndSettle();

    expect(find.text('Camera Three'), findsNothing);
    expect(find.text('Show 1 more'), findsOneWidget);
  });

  testWidgets('delete conversation menu clears messages and saved data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const userId = 'delete-conversation-test-user';
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.forTesting(
          currentUser: UserModel(
            id: userId,
            fullName: 'Test Borrower',
            email: 'borrower@example.test',
            role: UserRole.student,
            idNumber: 'DELETE-001',
            mustChangePassword: false,
          ),
        ),
        child: MaterialApp(home: const BorrowerAssistantScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant-conversation-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-conversation-menu-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-conversation-confirm')));
    await tester.pumpAndSettle();

    expect(await BorrowerAssistantConversationStore.load(userId), isNull);
  });
}
