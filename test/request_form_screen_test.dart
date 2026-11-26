import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/providers/request_provider.dart';
import 'package:lendy/screens/request_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('group request form lists every selected item', (tester) async {
    final auth = AuthProvider.forTesting();
    final equipmentProvider = EquipmentProvider();
    final requestProvider = RequestProvider(equipmentProvider);
    addTearDown(auth.dispose);
    addTearDown(requestProvider.dispose);
    addTearDown(equipmentProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<RequestProvider>.value(value: requestProvider),
        ],
        child: MaterialApp(
          home: RequestFormScreen.multi(
            equipments: [
              EquipmentModel(
                id: 'EQ-001',
                name: 'Projector',
                category: EquipmentCategory.projector,
                assetTag: 'PJ-001',
                location: 'AV Storage',
                status: EquipmentStatus.available,
              ),
              EquipmentModel(
                id: 'EQ-002',
                name: 'Tripod',
                category: EquipmentCategory.camera,
                assetTag: 'CM-002',
                location: 'AV Storage',
                status: EquipmentStatus.available,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2 items selected'), findsOneWidget);
    expect(find.text('Projector'), findsOneWidget);
    expect(find.text('Tripod'), findsOneWidget);
    expect(find.text('How long will you use these items?'), findsOneWidget);
    expect(find.text('Maximum borrowing period: 14 days.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request form switches between hourly and daily schedules', (
    tester,
  ) async {
    final auth = AuthProvider.forTesting();
    final equipmentProvider = EquipmentProvider();
    final requestProvider = RequestProvider(equipmentProvider);
    addTearDown(auth.dispose);
    addTearDown(requestProvider.dispose);
    addTearDown(equipmentProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<RequestProvider>.value(value: requestProvider),
        ],
        child: MaterialApp(
          home: RequestFormScreen(
            equipment: EquipmentModel(
              id: 'EQ-001',
              name: 'Projector',
              category: EquipmentCategory.projector,
              location: 'AV Storage',
              status: EquipmentStatus.available,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Maximum borrowing period: 14 days.'), findsOneWidget);
    expect(find.text('Preferred Return Date'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'For hours'));
    await tester.pumpAndSettle();

    expect(find.text('Preferred Use Date'), findsOneWidget);
    expect(find.text('Preferred Borrow Time'), findsOneWidget);
    expect(find.text('Preferred Return Time'), findsOneWidget);
    expect(find.text('Preferred Return Date'), findsNothing);
  });
}
