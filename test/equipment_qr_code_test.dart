import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/utils/equipment_qr_code.dart';

void main() {
  test('extracts equipment ID from the admin item URL in QR labels', () {
    expect(
      equipmentIdFromQrCode(
        'https://borrowing-system-lendy.web.app/item.html?id=equipment%201',
      ),
      'equipment 1',
    );
  });

  test('continues to accept QR codes containing a plain equipment ID', () {
    expect(equipmentIdFromQrCode('  EQ-014  '), 'EQ-014');
  });

  test('returns an empty ID for an empty QR payload', () {
    expect(equipmentIdFromQrCode('  '), isEmpty);
  });
}
