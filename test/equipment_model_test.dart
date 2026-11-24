import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/equipment_model.dart';

void main() {
  group('activeEquipmentStatusForLoan', () {
    test('approved loans are reserved until checkout', () {
      expect(
        activeEquipmentStatusForLoan({'status': 'approved'}),
        EquipmentStatus.reserved,
      );
      expect(
        activeEquipmentStatusForLoan({
          'status': 'approved',
          'checkedOutAt': 123,
        }),
        EquipmentStatus.borrowed,
      );
    });

    test('items awaiting return verification remain borrowed', () {
      expect(
        activeEquipmentStatusForLoan({'status': 'return_pending'}),
        EquipmentStatus.borrowed,
      );
      expect(activeEquipmentStatusForLoan({'status': 'returned'}), isNull);
    });
  });

  group('EquipmentModel.fromFirestore', () {
    test(
      'maps admin equipment fields and retains the Firestore document ID',
      () {
        final equipment = EquipmentModel.fromFirestore(
          documentId: 'firestore-document-id',
          data: {
            'name': 'Camera A',
            'category': 'Cameras',
            'tag': 'CM-01AB',
            'location': 'AV Storage, Room 101',
            'image': 'data:image/jpeg;base64,aGVsbG8=',
            'maintenance': false,
          },
          status: EquipmentStatus.available,
        );

        expect(equipment.id, 'firestore-document-id');
        expect(equipment.name, 'Camera A');
        expect(equipment.category, EquipmentCategory.camera);
        expect(equipment.displayCategory, 'Cameras');
        expect(equipment.assetTag, 'CM-01AB');
        expect(equipment.location, 'AV Storage, Room 101');
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
