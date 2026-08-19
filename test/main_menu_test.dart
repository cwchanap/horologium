import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _menuViewports = [Size(360, 640), Size(430, 932)];

Future<void> pumpMenu(WidgetTester tester, Size viewport) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const HorologiumApp());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  for (final viewport in _menuViewports) {
    testWidgets('menu remains usable at $viewport', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpMenu(tester, viewport);

      expect(find.text('START EXPEDITION'), findsOneWidget);
      expect(find.text('MINING MVP'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('MINING MVP opens the mining screen without changing start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpMenu(tester, _menuViewports.first);

    final startButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('START EXPEDITION'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(startButton.onPressed, isNotNull);

    await tester.tap(find.text('MINING MVP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Landing Basin'), findsWidgets);
    expect(find.text('SELL ALL CARGO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
