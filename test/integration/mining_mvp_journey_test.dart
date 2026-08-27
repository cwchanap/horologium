import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/main.dart';
import 'package:horologium/mining/presentation/mining_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _viewport = Size(360, 640);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('production entry opens the Flame-free mining shell', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _viewport;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const HorologiumApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('START MINING'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MiningShell), findsOneWidget);
    expect(find.byKey(const Key('mining-shell-placeholder')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
