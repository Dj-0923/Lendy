import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/providers/request_provider.dart';
import 'package:lendy/screens/borrower_assistant_screen.dart';
import 'package:lendy/services/borrower_assistant_service.dart';
import 'package:provider/provider.dart';

void main() {
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
        if (requestCount == 1) {
          expect(jsonDecode(request.body), {
            'question': 'What items are available?',
          });
          return responseCompleter.future;
        }
        expect(jsonDecode(request.body), {'question': 'Available items?'});
        return http.Response(
          jsonEncode({'answer': 'Available ang projector.', 'items': []}),
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

      expect(find.text('Mga puwedeng itanong'), findsOneWidget);
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

      expect(find.text('What items are available?'), findsOneWidget);
      expect(
        find.text(
          'One projector is available. Choose one below to request it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Projector'), findsOneWidget);
      expect(find.text('PROJECTORS'), findsOneWidget);
      expect(find.text('PRJ-001'), findsOneWidget);
      expect(find.text('AV Room'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Mga puwedeng itanong'), findsOneWidget);
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
      await tester.tap(
        find.byKey(const Key('assistant-suggestion-Available items?')),
      );
      await tester.pumpAndSettle();
      expect(requestCount, 2);
      expect(find.text('Available ang projector.'), findsOneWidget);
    },
  );

  testWidgets('automatically asks the question sent from the home screen', (
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
            initialQuestion: 'Camera to borrow?',
            service: BorrowerAssistantService(
              client: client,
              getIdToken: () async => 'test-token',
              apiUrl: 'https://example.test',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Camera to borrow?'), findsNWidgets(2));
    expect(find.text('Oo, may camera.'), findsOneWidget);
  });
}
