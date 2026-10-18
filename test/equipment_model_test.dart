import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/equipment_model.dart';

void main() {
  group('EquipmentModel.fromFirestore', () {
    test(
      'maps admin equipment fields and retains the Firestore document ID',
      () {
        final equipment = EquipmentModel.fromFirestore(
          documentId: 'firestore-document-id',
          data: {
            'name': 'Sony A7 Camera',
            'category': 'Cameras',
            'tag': 'CM-01AB',
            'image': 'data:image/jpeg;base64,aGVsbG8=',
            'maintenance': false,
          },
          status: EquipmentStatus.available,
        );

        expect(equipment.id, 'firestore-document-id');
        expect(equipment.name, 'Sony A7 Camera');
        expect(equipment.category, EquipmentCategory.camera);
        expect(equipment.displayCategory, 'Cameras');
        expect(equipment.assetTag, 'CM-01AB');
        expect(equipment.imageBytes, [104, 101, 108, 108, 111]);
      },
    );

    test(
      'preserves custom admin categories for display and groups their filter',
      () {
        final equipment = EquipmentModel.fromFirestore(
          documentId: 'custom-item',
          data: {'name': 'Custom item', 'category': '3D Printers'},
          status: EquipmentStatus.available,
        );

        expect(equipment.displayCategory, '3D Printers');
        expect(equipment.category, EquipmentCategory.accessories);
      },
    );

    test('handles missing optional fields and invalid image data', () {
      final equipment = EquipmentModel.fromFirestore(
        documentId: 'item-without-optionals',
        data: {'name': 'Item', 'image': 'not-base64'},
        status: EquipmentStatus.maintenance,
      );

      expect(equipment.category, EquipmentCategory.accessories);
      expect(equipment.assetTag, isNull);
      expect(equipment.location, isEmpty);
      expect(equipment.imageBytes, isNull);
      expect(equipment.status, EquipmentStatus.maintenance);
    });
  });
}
