import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/providers/auth_provider.dart';
import 'package:lendy/providers/equipment_provider.dart';
import 'package:lendy/providers/request_provider.dart';
import 'package:lendy/screens/browse_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('browse selection opens one request form for selected items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthProvider.forTesting();
    final equipment = EquipmentProvider(
      initialEquipment: [
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
    );
    final requests = RequestProvider(equipment);
    addTearDown(auth.dispose);
    addTearDown(equipment.dispose);
    addTearDown(requests.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<EquipmentProvider>.value(value: equipment),
          ChangeNotifierProvider<RequestProvider>.value(value: requests),
        ],
        child: const MaterialApp(home: BrowseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('browse-selected-items-bar')), findsNothing);
    await tester.tap(find.byKey(const Key('browse-multi-select-toggle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
    expect(
      tester.getTopLeft(find.byIcon(Icons.radio_button_unchecked).first).dx,
      closeTo(tester.getTopLeft(find.text('PROJECTOR')).dx - 4, 0.1),
    );
    await tester.tap(find.byTooltip('Select Projector'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.byTooltip('Select Tripod'));
    await tester.pumpAndSettle();

    expect(find.text('2 items selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('browse-request-selected')));
    await tester.pumpAndSettle();

    expect(find.text('Request Items'), findsOneWidget);
    expect(find.text('Projector'), findsOneWidget);
    expect(find.text('Tripod'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('homepage category dropdown scrolls after five options', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthProvider.forTesting();
    final equipment = EquipmentProvider(
      initialEquipment: List.generate(
        6,
        (index) => EquipmentModel(
          id: 'EQ-${index + 1}',
          name: 'Item ${index + 1}',
          category: EquipmentCategory.accessories,
          categoryName: 'Category ${index + 1}',
          location: 'Storage Room',
          status: EquipmentStatus.available,
        ),
      ),
    );
    final requests = RequestProvider(equipment);
    addTearDown(auth.dispose);
    addTearDown(equipment.dispose);
    addTearDown(requests.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<EquipmentProvider>.value(value: equipment),
          ChangeNotifierProvider<RequestProvider>.value(value: requests),
        ],
        child: const MaterialApp(home: BrowseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Categories').first);
    await tester.pumpAndSettle();

    for (var index = 1; index <= 4; index++) {
      expect(find.text('Category $index').hitTestable(), findsOneWidget);
    }
    expect(find.text('Category 5').hitTestable(), findsNothing);
    expect(find.text('Category 6').hitTestable(), findsNothing);

    await tester.drag(find.text('Category 4'), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(find.text('Category 6').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
