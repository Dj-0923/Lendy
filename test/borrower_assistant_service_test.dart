import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/models/equipment_model.dart';
import 'package:lendy/services/borrower_assistant_service.dart';

void main() {
  test('assistant maps approved inventory to the Reserved equipment status', () {
    final item = BorrowerAssistantItem.fromJson({
      'id': 'equipment-1',
      'name': 'Projector',
      'status': 'Reserved',
    });

    expect(item.status, EquipmentStatus.reserved);
    expect(item.statusLabel, 'Reserved');
  });
}
