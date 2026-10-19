import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lendy/utils/responsive_layout.dart';

void main() {
  testWidgets('responsive app frame fills a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveAppFrame(child: SizedBox.expand(key: Key('app-frame'))),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('app-frame'))),
      const Size(320, 568),
    );
  });

  testWidgets('responsive app frame centers and caps wide viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveAppFrame(child: SizedBox.expand(key: Key('app-frame'))),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('app-frame'))),
      const Size(ResponsiveAppFrame.maxAppWidth, 900),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('app-frame'))).dx,
      (1600 - ResponsiveAppFrame.maxAppWidth) / 2,
    );
  });

  testWidgets('responsive content stays top-aligned on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveContent(
            child: SizedBox(key: Key('content'), width: 200, height: 100),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(const Key('content'))).dy, 0);
    expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 80);
  });
}
