import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/main_menu.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _menuViewports = [Size(360, 640), Size(430, 932)];
final _validMiningSave = jsonEncode(
  MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 18, 12)).toJson(),
);
const _cityActions = [
  'START EXPEDITION',
  'MINING MVP',
  'TRADE',
  'STELLAR MAP',
  'RESEARCH LAB',
];

Future<void> pumpMenu(
  WidgetTester tester,
  Size viewport, {
  Map<String, Object> preferences = const {},
  bool disableAnimations = false,
  Duration settle = const Duration(seconds: 3),
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData.fromView(
          tester.view,
        ).copyWith(disableAnimations: disableAnimations),
        child: const MainMenu(),
      ),
    ),
  );
  if (settle > Duration.zero) {
    await tester.pump(settle);
  }
}

void expectMiningOnlyLanding(WidgetTester tester, String primaryLabel) {
  expect(find.text(primaryLabel), findsOneWidget);
  expect(
    find.text(
      primaryLabel == 'START MINING' ? 'CONTINUE MINING' : 'START MINING',
    ),
    findsNothing,
  );
  for (final action in _cityActions) {
    expect(find.text(action), findsNothing);
  }
  expect(find.text('SETTINGS'), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final viewport in _menuViewports) {
    testWidgets('fresh landing is mining-only at $viewport', (tester) async {
      await pumpMenu(tester, viewport);

      expectMiningOnlyLanding(tester, 'START MINING');
    });

    testWidgets('legacy city data still starts mining at $viewport', (
      tester,
    ) async {
      await pumpMenu(
        tester,
        viewport,
        preferences: {
          'cash': 999999.0,
          'planet.earth.resources.cash': 888888.0,
          'buildings': <String>['1,1,Gold Mine'],
        },
      );

      expectMiningOnlyLanding(tester, 'START MINING');
    });

    testWidgets('existing mining data continues mining at $viewport', (
      tester,
    ) async {
      await pumpMenu(
        tester,
        viewport,
        preferences: {MiningSaveRepository.saveKey: _validMiningSave},
      );

      expectMiningOnlyLanding(tester, 'CONTINUE MINING');
    });
  }

  testWidgets('the primary mining CTA opens MiningShell', (tester) async {
    await pumpMenu(tester, _menuViewports.first);

    await tester.tap(find.text('START MINING'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MiningShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fresh start then back shows CONTINUE after init persists the save',
    (tester) async {
      await pumpMenu(tester, _menuViewports.first);

      await tester.tap(find.text('START MINING'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MiningShell), findsOneWidget);

      // Pop without performing any action. MiningController.initialize()
      // persists the freshly constructed initial state, so the save key
      // exists before the menu rechecks hasSave().
      final screenContext = tester.element(find.byType(MiningShell));
      Navigator.of(screenContext).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('CONTINUE MINING'), findsOneWidget);
      expect(find.text('START MINING'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion settles the launch presentation', (tester) async {
    await pumpMenu(
      tester,
      _menuViewports.first,
      disableAnimations: true,
      settle: Duration.zero,
    );

    expect(find.byType(FloatingParticle), findsNothing);
    final starfieldBefore =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('main-menu-starfield')),
                )
                .painter!
            as StarfieldPainter;
    final titleOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('main-menu-title-opacity')),
    );
    final titleTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('main-menu-title-transform')),
    );
    final buttonOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('main-menu-button-opacity')),
    );
    final buttonTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('main-menu-button-transform')),
    );

    expect(starfieldBefore.animationValue, equals(0));
    expect(titleOpacity.opacity, equals(1));
    expect(titleTransform.transform.storage[0], equals(1));
    expect(buttonOpacity.opacity, equals(1));
    expect(buttonTransform.transform.storage[13], equals(0));

    await tester.pump(const Duration(seconds: 1));

    final starfieldAfter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('main-menu-starfield')),
                )
                .painter!
            as StarfieldPainter;
    expect(
      starfieldAfter.animationValue,
      equals(starfieldBefore.animationValue),
    );
    expect(tester.takeException(), isNull);
  });
}
