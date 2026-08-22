import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/stellar_map_sheet.dart';

const _viewports = [Size(360, 640), Size(430, 932)];

StellarMapView _lockedView({int minesBuilt = 0}) => StellarMapView(
  homeworldMinesBuilt: minesBuilt,
  homeworldMineTotal: 3,
  hasHomeworldMastery: minesBuilt == 3,
  requiredSurveyingLevel: 3,
  hasSurveying: false,
  lunarUnlockCashCost: 2500,
  hasCash: false,
  isLunarUnlocked: false,
);

StellarMapView _unlockedLunarActiveView() => const StellarMapView(
  homeworldMinesBuilt: 3,
  homeworldMineTotal: 3,
  hasHomeworldMastery: true,
  requiredSurveyingLevel: 3,
  hasSurveying: true,
  lunarUnlockCashCost: 2500,
  hasCash: true,
  isLunarUnlocked: true,
);

Widget _sheet(
  StellarMapView view, {
  MiningPlanetId activePlanetId = MiningPlanetId.homeworld,
  VoidCallback? onUnlockLunar,
  ValueChanged<MiningPlanetId>? onTravel,
}) => StellarMapSheet(
  view: view,
  activePlanetId: activePlanetId,
  homeworldName: 'Homeworld',
  lunarName: 'Lunar Frontier',
  onUnlockLunar: onUnlockLunar ?? () {},
  onTravel: onTravel ?? (_) {},
);

Future<void> _pump(WidgetTester tester, Size viewport, Widget sheet) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: sheet)));
  await tester.pump();
}

void main() {
  for (final viewport in _viewports) {
    testWidgets(
      'locked Lunar card shows exact unmet requirements at $viewport',
      (tester) async {
        await _pump(tester, viewport, _sheet(_lockedView(minesBuilt: 1)));

        expect(
          find.byKey(const Key('mining-stellar-map-sheet')),
          findsOneWidget,
        );
        expect(find.text('Homeworld'), findsOneWidget);
        expect(find.text('Lunar Frontier'), findsOneWidget);
        expect(find.text('Homeworld mines 1/3'), findsOneWidget);
        expect(find.text('Surveying 3'), findsOneWidget);
        expect(find.text('2500 cash'), findsOneWidget);

        // Requirements are decorated with satisfied/unmet status icons.
        expect(find.byIcon(Icons.cancel), findsNWidgets(3));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('controls meet the 48px minimum at $viewport', (tester) async {
      await _pump(
        tester,
        viewport,
        _sheet(
          _unlockedLunarActiveView(),
          activePlanetId: MiningPlanetId.lunarFrontier,
        ),
      );
      for (final key in const [
        'mining-stellar-map-travel-homeworld',
        'mining-stellar-map-travel-lunarFrontier',
      ]) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }

      await _pump(tester, viewport, _sheet(_lockedView()));
      final unlock = tester.getSize(
        find.byKey(const Key('mining-stellar-map-unlock')),
      );
      expect(unlock.height, greaterThanOrEqualTo(48));
      expect(unlock.width, greaterThanOrEqualTo(48));
    });
  }

  testWidgets('unlock stays disabled until the view allows it', (tester) async {
    await _pump(
      tester,
      const Size(360, 640),
      _sheet(_lockedView(minesBuilt: 1)),
    );

    final locked = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('mining-stellar-map-unlock')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(locked.onPressed, isNull);

    // Travel to locked Lunar is not offered; travel to the active planet is
    // inert.
    expect(
      find.byKey(const Key('mining-stellar-map-travel-lunarFrontier')),
      findsNothing,
    );
    final activeTravel = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('mining-stellar-map-travel-homeworld')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(activeTravel.onPressed, isNull);
  });

  testWidgets('unlock and travel callbacks fire from the sheet', (
    tester,
  ) async {
    final unlocked = <bool>[];
    final traveled = <MiningPlanetId>[];
    final view = StellarMapView(
      homeworldMinesBuilt: 3,
      homeworldMineTotal: 3,
      hasHomeworldMastery: true,
      requiredSurveyingLevel: 3,
      hasSurveying: true,
      lunarUnlockCashCost: 2500,
      hasCash: true,
      isLunarUnlocked: false,
    );

    await _pump(
      tester,
      const Size(360, 640),
      _sheet(view, onUnlockLunar: () => unlocked.add(true)),
    );
    await tester.tap(find.byKey(const Key('mining-stellar-map-unlock')));
    expect(unlocked, [true]);

    await _pump(
      tester,
      const Size(360, 640),
      _sheet(
        _unlockedLunarActiveView(),
        activePlanetId: MiningPlanetId.lunarFrontier,
        onTravel: traveled.add,
      ),
    );
    await tester.tap(
      find.byKey(const Key('mining-stellar-map-travel-homeworld')),
    );
    expect(traveled, [MiningPlanetId.homeworld]);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(0));
  });
}
