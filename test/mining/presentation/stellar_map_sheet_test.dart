import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/stellar_map_sheet.dart';

const _viewports = [Size(360, 640), Size(430, 932)];

const _homeworld = StellarMapPlanetView(
  id: MiningPlanetId.homeworld,
  name: 'Homeworld',
  isUnlocked: true,
  isActive: true,
  minesBuilt: 0,
  mineTotal: 3,
  requiredMasteryPlanetId: null,
  hasRequiredMastery: true,
  requiredSurveyingLevel: 0,
  hasSurveying: true,
  unlockCashCost: 0,
  hasCash: true,
);

const _homeworldMastered = StellarMapPlanetView(
  id: MiningPlanetId.homeworld,
  name: 'Homeworld',
  isUnlocked: true,
  isActive: true,
  minesBuilt: 3,
  mineTotal: 3,
  requiredMasteryPlanetId: null,
  hasRequiredMastery: true,
  requiredSurveyingLevel: 0,
  hasSurveying: true,
  unlockCashCost: 0,
  hasCash: true,
);

const _lockedLunar = StellarMapPlanetView(
  id: MiningPlanetId.lunarFrontier,
  name: 'Lunar Frontier',
  isUnlocked: false,
  isActive: false,
  minesBuilt: 0,
  mineTotal: 3,
  requiredMasteryPlanetId: MiningPlanetId.homeworld,
  hasRequiredMastery: false,
  requiredSurveyingLevel: 3,
  hasSurveying: false,
  unlockCashCost: 2500,
  hasCash: false,
);

const _unlockedLunar = StellarMapPlanetView(
  id: MiningPlanetId.lunarFrontier,
  name: 'Lunar Frontier',
  isUnlocked: true,
  isActive: false,
  minesBuilt: 1,
  mineTotal: 3,
  requiredMasteryPlanetId: MiningPlanetId.homeworld,
  hasRequiredMastery: true,
  requiredSurveyingLevel: 3,
  hasSurveying: true,
  unlockCashCost: 2500,
  hasCash: true,
);

const _lockedMars = StellarMapPlanetView(
  id: MiningPlanetId.marsFrontier,
  name: 'Mars Frontier',
  isUnlocked: false,
  isActive: false,
  minesBuilt: 0,
  mineTotal: 3,
  requiredMasteryPlanetId: MiningPlanetId.lunarFrontier,
  hasRequiredMastery: false,
  requiredSurveyingLevel: 5,
  hasSurveying: false,
  unlockCashCost: 20000,
  hasCash: false,
);

const _unlockedMars = StellarMapPlanetView(
  id: MiningPlanetId.marsFrontier,
  name: 'Mars Frontier',
  isUnlocked: true,
  isActive: true,
  minesBuilt: 2,
  mineTotal: 3,
  requiredMasteryPlanetId: MiningPlanetId.lunarFrontier,
  hasRequiredMastery: true,
  requiredSurveyingLevel: 5,
  hasSurveying: true,
  unlockCashCost: 20000,
  hasCash: true,
);

StellarMapView _freshView() =>
    const StellarMapView(planets: [_homeworld, _lockedLunar]);

StellarMapView _lunarUnlockedView() => const StellarMapView(
  planets: [_homeworldMastered, _unlockedLunar, _lockedMars],
);

StellarMapView _marsUnlockedView() => const StellarMapView(
  planets: [_homeworldMastered, _unlockedLunar, _unlockedMars],
);

Widget _sheet(
  StellarMapView view, {
  ValueChanged<MiningPlanetId>? onUnlock,
  ValueChanged<MiningPlanetId>? onTravel,
}) => StellarMapSheet(
  view: view,
  onUnlock: onUnlock ?? (_) {},
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
  testWidgets('fresh map renders Homeworld and Lunar only', (tester) async {
    await _pump(tester, const Size(360, 640), _sheet(_freshView()));

    expect(
      find.byKey(const Key('stellar-map-planet-homeworld')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('stellar-map-planet-lunarFrontier')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('stellar-map-planet-marsFrontier')),
      findsNothing,
    );
    expect(find.text('Mars Frontier'), findsNothing);
  });

  for (final viewport in _viewports) {
    testWidgets(
      'locked Mars shows its prerequisite and authored gates at $viewport',
      (tester) async {
        await _pump(tester, viewport, _sheet(_lunarUnlockedView()));

        expect(
          find.byKey(const Key('stellar-map-planet-marsFrontier')),
          findsOneWidget,
        );
        expect(find.text('Lunar Frontier mines 1/3'), findsOneWidget);
        expect(find.text('Surveying 5'), findsOneWidget);
        expect(find.text('20000 cash'), findsOneWidget);
        final marsCard = find.byKey(
          const Key('stellar-map-planet-marsFrontier'),
        );
        expect(
          find.descendant(of: marsCard, matching: find.text('Mines 0/3')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('mining-stellar-map-unlock-marsFrontier')),
          findsOneWidget,
        );
        expect(find.text('Homeworld mines 3/3'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('unlocked Mars shows its own mine progress at $viewport', (
      tester,
    ) async {
      await _pump(tester, viewport, _sheet(_marsUnlockedView()));

      final marsCard = find.byKey(const Key('stellar-map-planet-marsFrontier'));
      expect(
        find.descendant(of: marsCard, matching: find.text('Mines 2/3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mining-stellar-map-travel-marsFrontier')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('generic unlock and travel callbacks receive planet ids', (
    tester,
  ) async {
    final unlocked = <MiningPlanetId>[];
    final traveled = <MiningPlanetId>[];
    final unlockableMars = StellarMapView(
      planets: [
        _homeworldMastered,
        _unlockedLunar,
        _lockedMars.copyWithForTest(
          hasRequiredMastery: true,
          hasSurveying: true,
          hasCash: true,
        ),
      ],
    );

    await _pump(
      tester,
      const Size(360, 640),
      _sheet(unlockableMars, onUnlock: unlocked.add, onTravel: traveled.add),
    );
    final marsUnlock = find.byKey(
      const Key('mining-stellar-map-unlock-marsFrontier'),
    );
    await tester.ensureVisible(marsUnlock);
    await tester.tap(marsUnlock);
    expect(unlocked, [MiningPlanetId.marsFrontier]);

    final lunarTravel = find.byKey(
      const Key('mining-stellar-map-travel-lunarFrontier'),
    );
    await tester.ensureVisible(lunarTravel);
    await tester.tap(lunarTravel);
    expect(traveled, [MiningPlanetId.lunarFrontier]);
  });

  testWidgets('all map controls remain at least 48px', (tester) async {
    await _pump(tester, const Size(360, 640), _sheet(_lunarUnlockedView()));

    for (final key in const [
      'mining-stellar-map-travel-homeworld',
      'mining-stellar-map-travel-lunarFrontier',
      'mining-stellar-map-unlock-marsFrontier',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('the long Mars map remains scrollable and reachable', (
    tester,
  ) async {
    await _pump(tester, const Size(360, 640), _sheet(_lunarUnlockedView()));

    final mars = find.byKey(const Key('stellar-map-planet-marsFrontier'));
    await tester.ensureVisible(mars);
    expect(mars, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

extension on StellarMapPlanetView {
  StellarMapPlanetView copyWithForTest({
    bool? hasRequiredMastery,
    bool? hasSurveying,
    bool? hasCash,
  }) => StellarMapPlanetView(
    id: id,
    name: name,
    isUnlocked: isUnlocked,
    isActive: isActive,
    minesBuilt: minesBuilt,
    mineTotal: mineTotal,
    requiredMasteryPlanetId: requiredMasteryPlanetId,
    hasRequiredMastery: hasRequiredMastery ?? this.hasRequiredMastery,
    requiredSurveyingLevel: requiredSurveyingLevel,
    hasSurveying: hasSurveying ?? this.hasSurveying,
    unlockCashCost: unlockCashCost,
    hasCash: hasCash ?? this.hasCash,
  );
}
