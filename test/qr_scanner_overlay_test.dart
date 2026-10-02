import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/widgets/qr_scanner_overlay.dart';

void main() {
  testWidgets('scan line moves down and back up while scanning', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 560,
          child: QrScannerOverlay(showScanLine: true),
        ),
      ),
    );
    await tester.pump();

    final scanLine = find.byKey(const ValueKey('qr-scan-line'));
    final start = tester.getTopLeft(scanLine).dy;

    await tester.pump(const Duration(milliseconds: 1600));
    final middle = tester.getTopLeft(scanLine).dy;
    expect(middle, greaterThan(start));

    await tester.pump(const Duration(milliseconds: 800));
    final end = tester.getTopLeft(scanLine).dy;
    expect(end, lessThan(middle));
  });
}
