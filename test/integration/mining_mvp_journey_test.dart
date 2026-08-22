import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/main.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;
}

const _viewport = Size(360, 640);

Future<void> pumpInjectedMiningScreen(
  WidgetTester tester, {
  required MiningSaveRepository repository,
  required DateTime Function() nowUtc,
  Key? screenKey,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: const Key('injected-mining-app'),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MiningScreen(
          key: screenKey,
          content: MiningContentRegistry.stellarMining(),
          repository: repository,
          nowUtc: nowUtc,
        ),
      ),
    ),
  );

  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Map<String, Object?> _mineDocument({double storedAmount = 0}) =>
    <String, Object?>{'level': 1, 'storedAmount': storedAmount};

Map<String, Object?> _sectorDocument({
  bool revealed = false,
  Map<String, Object?>? mine,
}) => <String, Object?>{'revealed': revealed, 'mine': mine};

Map<String, Object?> _sixSectorDocuments({
  Map<String, Object?>? landingBasin,
  Map<String, Object?>? carbonRidge,
  Map<String, Object?>? graniteCrater,
  Map<String, Object?>? frozenBasin,
  Map<String, Object?>? titaniumHighlands,
  Map<String, Object?>? heliumMare,
}) => <String, Object?>{
  'landingBasin': landingBasin ?? _sectorDocument(),
  'carbonRidge': carbonRidge ?? _sectorDocument(),
  'graniteCrater': graniteCrater ?? _sectorDocument(),
  'frozenBasin': frozenBasin ?? _sectorDocument(),
  'titaniumHighlands': titaniumHighlands ?? _sectorDocument(),
  'heliumMare': heliumMare ?? _sectorDocument(),
};

/// Seeds only the current six-key mining document; legacy save shapes are not
/// part of either product journey.
void seedCurrentMiningSave({
  required int cash,
  required DateTime lastAccruedAtUtc,
  required int surveying,
  required List<String> unlockedPlanetIds,
  required String activePlanetId,
  required Map<String, Object?> sectors,
}) {
  SharedPreferences.setMockInitialValues({
    MiningSaveRepository.saveKey: jsonEncode(<String, Object?>{
      'cash': cash,
      'lastAccruedAtUtc': lastAccruedAtUtc.toUtc().toIso8601String(),
      'technology': <String, Object?>{
        'extraction': 0,
        'logistics': 0,
        'surveying': surveying,
      },
      'unlockedPlanetIds': unlockedPlanetIds,
      'activePlanetId': activePlanetId,
      'sectors': sectors,
    }),
  });
}

Future<void> purchaseSurveyingLevel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mining-technology-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);

  final purchase = find.byKey(const Key('mining-technology-buy-surveying'));
  await tester.ensureVisible(purchase);
  await tester.tap(purchase);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text('Technology upgraded.'), findsOneWidget);
}

Future<void> openStellarMap(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mining-stellar-map-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byKey(const Key('mining-stellar-map-sheet')), findsOneWidget);
}

MiningSave stateFromScreen(WidgetTester tester) =>
    (tester.state(find.byType(MiningScreen)) as MiningScreenHandles)
        .controller
        .state;

Future<void> waitForSnackBarToClear(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    if (find.byType(SnackBar).evaluate().isEmpty) return;
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> selectSector(WidgetTester tester, MiningSectorId id) async {
  final tab = find.byKey(Key('mining-sector-${id.name}'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pump();
}

Future<void> selectSellTab(WidgetTester tester) async {
  final tab = find.byKey(const Key('mining-sell-tab'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pump();
}

Future<void> tapPrimary(
  WidgetTester tester,
  String expectedLabel, {
  String? successMessage,
}) async {
  await waitForSnackBarToClear(tester);
  expect(find.text(expectedLabel), findsOneWidget);
  final primary = find.byKey(const Key('mining-primary-action'));
  await tester.ensureVisible(primary);
  await tester.tap(primary);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  if (successMessage != null) {
    expect(find.text(successMessage), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      if (find.byType(SnackBar).evaluate().isEmpty) break;
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(SnackBar), findsNothing);
  }
}

Future<void> advanceClock(
  WidgetTester tester,
  TestClock clock,
  Duration elapsed,
) async {
  clock.now = clock.now.add(elapsed);
  await tester.pump(const Duration(seconds: 1));
}

void expectStatus(
  WidgetTester tester, {
  required int cash,
  required String cargoValue,
  required String sectors,
}) {
  final status = find.byKey(const Key('mining-status-bar'));
  expect(
    find.descendant(of: status, matching: find.text('$cash')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: status, matching: find.text(cargoValue)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: status, matching: find.text(sectors)),
    findsOneWidget,
  );
}

/// Boots the real app entry into START MINING, then retires that production
/// session and awaits its dispose checkpoint so its real-clock timestamp
/// cannot race the injected session's TestClock under the shared save key.
Future<void> pumpProductionEntryThenRetireIt(WidgetTester tester) async {
  await tester.pumpWidget(const HorologiumApp());
  await tester.pump(const Duration(seconds: 3));
  await tester.tap(find.text('START MINING'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(MiningScreen), findsOneWidget);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));

  // The retired session's dispose checkpoint wrote a real-clock timestamp
  // under the shared save key. Wipe it so the injected session cannot load a
  // later-than-TestClock base and skip accrual.
  SharedPreferences.setMockInitialValues({});
}

Future<void> progressLandingBasinEconomy(
  WidgetTester tester,
  TestClock clock,
) async {
  await selectSector(tester, MiningSectorId.landingBasin);
  await tapPrimary(tester, 'Build for 50 cash', successMessage: 'Mine built.');
  expectStatus(tester, cash: 50, cargoValue: '0', sectors: '1/3');

  await advanceClock(tester, clock, const Duration(minutes: 2));
  await selectSellTab(tester);
  await tapPrimary(
    tester,
    'Sell All for 240 cash',
    successMessage: 'Sold cargo for 240 cash.',
  );
  expectStatus(tester, cash: 290, cargoValue: '0', sectors: '1/3');

  await selectSector(tester, MiningSectorId.landingBasin);
  await tapPrimary(
    tester,
    'Upgrade for 80 cash',
    successMessage: 'Mine upgraded.',
  );
  expect(find.textContaining('Level 2'), findsOneWidget);
  expectStatus(tester, cash: 210, cargoValue: '0', sectors: '1/3');

  await advanceClock(tester, clock, const Duration(seconds: 15));
  await selectSellTab(tester);
  await tapPrimary(
    tester,
    'Sell All for 45 cash',
    successMessage: 'Sold cargo for 45 cash.',
  );
  expectStatus(tester, cash: 255, cargoValue: '0', sectors: '1/3');
}

Future<void> expandIntoCarbonRidge(WidgetTester tester, TestClock clock) async {
  await selectSector(tester, MiningSectorId.carbonRidge);
  await tapPrimary(
    tester,
    'Reveal for 250 cash',
    successMessage: 'Sector revealed.',
  );
  expectStatus(tester, cash: 5, cargoValue: '0', sectors: '2/3');

  await advanceClock(tester, clock, const Duration(seconds: 40));
  await selectSellTab(tester);
  await tapPrimary(
    tester,
    'Sell All for 120 cash',
    successMessage: 'Sold cargo for 120 cash.',
  );
  expectStatus(tester, cash: 125, cargoValue: '0', sectors: '2/3');

  await selectSector(tester, MiningSectorId.carbonRidge);
  await tapPrimary(tester, 'Build for 100 cash', successMessage: 'Mine built.');
  expectStatus(tester, cash: 25, cargoValue: '0', sectors: '2/3');

  await advanceClock(tester, clock, const Duration(seconds: 180));
  await selectSellTab(tester);
  await tapPrimary(
    tester,
    'Sell All for 900 cash',
    successMessage: 'Sold cargo for 900 cash.',
  );
  expectStatus(tester, cash: 925, cargoValue: '0', sectors: '2/3');

  await advanceClock(tester, clock, const Duration(seconds: 5));
  await selectSellTab(tester);
  await tapPrimary(
    tester,
    'Sell All for 26 cash',
    successMessage: 'Sold cargo for 26 cash.',
  );
  expectStatus(tester, cash: 951, cargoValue: '0', sectors: '2/3');
}

Future<void> completeGraniteCrater(WidgetTester tester) async {
  await selectSector(tester, MiningSectorId.graniteCrater);
  await tapPrimary(
    tester,
    'Reveal for 700 cash',
    successMessage: 'Sector revealed.',
  );
  await tapPrimary(tester, 'Build for 250 cash', successMessage: 'Mine built.');
  expectStatus(tester, cash: 1, cargoValue: '0', sectors: '3/3');
}

Future<void> verifyMultiSectorStoredCargoAndSellRemainder(
  WidgetTester tester,
  TestClock clock,
) async {
  await advanceClock(tester, clock, const Duration(seconds: 1));

  await selectSector(tester, MiningSectorId.landingBasin);
  expect(find.textContaining('Level 2'), findsOneWidget);
  expect(find.textContaining('stored 0.8'), findsOneWidget);
  await selectSector(tester, MiningSectorId.carbonRidge);
  expect(find.textContaining('Level 1'), findsOneWidget);
  expect(find.textContaining('stored 0.8'), findsOneWidget);
  await selectSector(tester, MiningSectorId.graniteCrater);
  expect(find.textContaining('Level 1'), findsOneWidget);
  expect(find.textContaining('stored 0.6'), findsOneWidget);

  await selectSellTab(tester);
  expectStatus(tester, cash: 1, cargoValue: '8', sectors: '3/3');
  await tapPrimary(
    tester,
    'Sell All for 8 cash',
    successMessage: 'Sold cargo for 8 cash.',
  );
  expectStatus(tester, cash: 9, cargoValue: '0', sectors: '3/3');

  final homeworldSectors = MiningContentRegistry.stellarMining()
      .planet(MiningPlanetId.homeworld)
      .sectors
      .map((definition) => definition.id);
  for (final id in homeworldSectors) {
    await selectSector(tester, id);
    expect(find.textContaining('stored 0.0'), findsOneWidget);
  }
}

/// Pauses the app (lifecycle checkpoint), then cold-recreates the session
/// after two offline hours and validates the offline return presentation and
/// persisted state. Returns the pre-offline save and start time for further
/// offline-cap checks.
Future<(MiningSave, DateTime)> checkpointLifecycleAndRecreateOffline(
  WidgetTester tester, {
  required TestClock clock,
  required MiningContentRegistry content,
  required MiningSaveRepository repository,
}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump(const Duration(milliseconds: 500));
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump(const Duration(milliseconds: 500));
  final prefs = await SharedPreferences.getInstance();
  final rawBeforeRecreate = prefs.getString(MiningSaveRepository.saveKey);
  expect(rawBeforeRecreate, isNotNull);
  final savedState = (await repository.load(nowUtc: clock.now)).state;

  final offlineStart = clock.now;
  final offlineReturn = offlineStart.add(const Duration(hours: 2));
  clock.now = offlineReturn;
  await pumpInjectedMiningScreen(
    tester,
    repository: repository,
    nowUtc: clock.call,
    screenKey: const Key('cold-recreated-mining-screen'),
  );
  await tester.pump(const Duration(milliseconds: 300));

  expect(prefs.getString(MiningSaveRepository.saveKey), rawBeforeRecreate);
  expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
  expect(find.text('Offline return'), findsOneWidget);
  expect(find.textContaining('Mining continued for 2h 0m.'), findsOneWidget);
  expect(find.textContaining('Gold'), findsWidgets);
  expect(find.textContaining('Coal'), findsWidgets);
  expect(find.textContaining('Stone'), findsWidgets);

  final expectedOffline = MiningSimulation(
    content,
  ).accrue(savedState, offlineReturn);
  expect(expectedOffline.summary.elapsedUsed, const Duration(hours: 2));
  expect(expectedOffline.summary.wasOfflineCapped, isFalse);
  expect(
    expectedOffline
        .state
        .sectors[MiningSectorId.landingBasin]!
        .mine!
        .storedAmount,
    135,
  );
  expect(
    expectedOffline
        .state
        .sectors[MiningSectorId.carbonRidge]!
        .mine!
        .storedAmount,
    120,
  );
  expect(
    expectedOffline
        .state
        .sectors[MiningSectorId.graniteCrater]!
        .mine!
        .storedAmount,
    120,
  );

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump(const Duration(milliseconds: 500));
  final restoredState = (await repository.load(nowUtc: clock.now)).state;
  expect(restoredState.toJson(), expectedOffline.state.toJson());

  return (savedState, offlineStart);
}

Future<void> verifyOfflineAccrualIsCappedAtEightHours({
  required MiningContentRegistry content,
  required MiningSave savedState,
  required DateTime offlineStart,
}) async {
  final capped = MiningSimulation(
    content,
  ).accrue(savedState, offlineStart.add(const Duration(hours: 12)));
  expect(capped.summary.elapsedUsed, const Duration(hours: 8));
  expect(capped.summary.wasOfflineCapped, isTrue);
  expect(
    capped.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
    135,
  );
  expect(
    capped.state.sectors[MiningSectorId.carbonRidge]!.mine!.storedAmount,
    120,
  );
  expect(
    capped.state.sectors[MiningSectorId.graniteCrater]!.mine!.storedAmount,
    120,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'completes the first-session loop and restores capped offline production',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _viewport;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpProductionEntryThenRetireIt(tester);

      final content = MiningContentRegistry.stellarMining();
      final repository = MiningSaveRepository(content: content);
      final clock = TestClock(DateTime.utc(2026, 8, 18, 12));

      await pumpInjectedMiningScreen(
        tester,
        repository: repository,
        nowUtc: clock.call,
      );

      await progressLandingBasinEconomy(tester, clock);
      await expandIntoCarbonRidge(tester, clock);
      await completeGraniteCrater(tester);
      await verifyMultiSectorStoredCargoAndSellRemainder(tester, clock);
      final (
        savedState,
        offlineStart,
      ) = await checkpointLifecycleAndRecreateOffline(
        tester,
        clock: clock,
        content: content,
        repository: repository,
      );
      await verifyOfflineAccrualIsCappedAtEightHours(
        content: content,
        savedState: savedState,
        offlineStart: offlineStart,
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('progresses from Homeworld mastery to Lunar Frontier and back', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _viewport;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final start = DateTime.utc(2026, 8, 19, 12);
    final clock = TestClock(start);
    final content = MiningContentRegistry.stellarMining();
    final repository = MiningSaveRepository(content: content);
    seedCurrentMiningSave(
      cash: 8000,
      lastAccruedAtUtc: start,
      surveying: 0,
      unlockedPlanetIds: ['homeworld'],
      activePlanetId: 'homeworld',
      sectors: _sixSectorDocuments(
        landingBasin: _sectorDocument(revealed: true, mine: _mineDocument()),
        carbonRidge: _sectorDocument(revealed: true, mine: _mineDocument()),
        graniteCrater: _sectorDocument(revealed: true, mine: _mineDocument()),
      ),
    );

    await pumpInjectedMiningScreen(
      tester,
      repository: repository,
      nowUtc: clock.call,
      disableAnimations: true,
    );

    await purchaseSurveyingLevel(tester);
    await purchaseSurveyingLevel(tester);
    await purchaseSurveyingLevel(tester);

    var state = stateFromScreen(tester);
    expect(state.technology.surveying, 3);
    expect(state.cash, 5500);

    await openStellarMap(tester);
    await tester.tap(find.byKey(const Key('mining-stellar-map-unlock')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    state = stateFromScreen(tester);
    expect(state.unlockedPlanetIds, {
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
    });
    expect(state.activePlanetId, MiningPlanetId.lunarFrontier);
    expect(state.cash, 3000);

    await selectSector(tester, MiningSectorId.frozenBasin);
    await tapPrimary(
      tester,
      'Reveal for 0 cash',
      successMessage: 'Sector revealed.',
    );
    await tapPrimary(
      tester,
      'Build for 500 cash',
      successMessage: 'Mine built.',
    );

    await openStellarMap(tester);
    final homeworldTravel = find.byKey(
      const Key('mining-stellar-map-travel-homeworld'),
    );
    await tester.ensureVisible(homeworldTravel);
    await tester.tap(homeworldTravel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    state = stateFromScreen(tester);
    expect(state.activePlanetId, MiningPlanetId.homeworld);
    expect(state.cash, 2500);
    expect(
      state.sectors[MiningSectorId.landingBasin]!.mine,
      const MineState(level: 1, storedAmount: 0),
    );
    expect(
      state.sectors[MiningSectorId.carbonRidge]!.mine,
      const MineState(level: 1, storedAmount: 0),
    );
    expect(
      state.sectors[MiningSectorId.graniteCrater]!.mine,
      const MineState(level: 1, storedAmount: 0),
    );
    expect(state.sectors[MiningSectorId.frozenBasin]!.revealed, isTrue);
    expect(
      state.sectors[MiningSectorId.frozenBasin]!.mine,
      const MineState(level: 1, storedAmount: 0),
    );
    expect(state.sectors[MiningSectorId.titaniumHighlands]!.revealed, isFalse);
    expect(state.sectors[MiningSectorId.heliumMare]!.revealed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'groups two-planet offline production and sells each active cargo hold',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _viewport;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final start = DateTime.utc(2026, 8, 20, 12);
      final clock = TestClock(start.add(const Duration(seconds: 10)));
      final content = MiningContentRegistry.stellarMining();
      final repository = MiningSaveRepository(content: content);
      seedCurrentMiningSave(
        cash: 1000,
        lastAccruedAtUtc: start,
        surveying: 3,
        unlockedPlanetIds: ['homeworld', 'lunarFrontier'],
        activePlanetId: 'lunarFrontier',
        sectors: _sixSectorDocuments(
          landingBasin: _sectorDocument(revealed: true, mine: _mineDocument()),
          carbonRidge: _sectorDocument(revealed: true, mine: _mineDocument()),
          graniteCrater: _sectorDocument(revealed: true, mine: _mineDocument()),
          frozenBasin: _sectorDocument(revealed: true, mine: _mineDocument()),
        ),
      );

      await pumpInjectedMiningScreen(
        tester,
        repository: repository,
        nowUtc: clock.call,
        disableAnimations: true,
      );

      final offlineSheet = find.byKey(const Key('offline-return-sheet'));
      expect(offlineSheet, findsOneWidget);
      final homeworldSummary = find.byKey(
        const Key('offline-return-planet-homeworld'),
      );
      final lunarSummary = find.byKey(
        const Key('offline-return-planet-lunarFrontier'),
      );
      expect(homeworldSummary, findsOneWidget);
      expect(lunarSummary, findsOneWidget);
      expect(
        find.descendant(of: homeworldSummary, matching: find.text('+5.0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: homeworldSummary, matching: find.text('+7.5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: homeworldSummary, matching: find.text('+6.0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lunarSummary, matching: find.text('+10.0')),
        findsOneWidget,
      );

      final dismissOfflineReturn = find.byKey(
        const Key('offline-return-dismiss'),
      );
      await tester.ensureVisible(dismissOfflineReturn);
      await tester.tap(dismissOfflineReturn);
      await tester.pump();

      await selectSellTab(tester);
      await tapPrimary(
        tester,
        'Sell All for 60 cash',
        successMessage: 'Sold cargo for 60 cash.',
      );

      var state = stateFromScreen(tester);
      expect(state.cash, 1060);
      expect(state.sectors[MiningSectorId.frozenBasin]!.mine!.storedAmount, 0);
      expect(
        state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
        closeTo(5, 0.0001),
      );
      expect(
        state.sectors[MiningSectorId.carbonRidge]!.mine!.storedAmount,
        closeTo(7.5, 0.0001),
      );
      expect(
        state.sectors[MiningSectorId.graniteCrater]!.mine!.storedAmount,
        closeTo(6, 0.0001),
      );

      await openStellarMap(tester);
      final homeworldTravel = find.byKey(
        const Key('mining-stellar-map-travel-homeworld'),
      );
      await tester.ensureVisible(homeworldTravel);
      await tester.tap(homeworldTravel);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await selectSellTab(tester);
      await tapPrimary(
        tester,
        'Sell All for 72 cash',
        successMessage: 'Sold cargo for 72 cash.',
      );

      state = stateFromScreen(tester);
      expect(state.cash, 1132);
      expect(state.activePlanetId, MiningPlanetId.homeworld);
      for (final id in const [
        MiningSectorId.landingBasin,
        MiningSectorId.carbonRidge,
        MiningSectorId.graniteCrater,
        MiningSectorId.frozenBasin,
      ]) {
        expect(state.sectors[id]!.mine!.storedAmount, 0);
      }

      final persisted = (await repository.load(nowUtc: clock.now)).state;
      expect(persisted.cash, 1132);
      expect(persisted.activePlanetId, MiningPlanetId.homeworld);
      expect(persisted.unlockedPlanetIds, {
        MiningPlanetId.homeworld,
        MiningPlanetId.lunarFrontier,
      });
      expect(
        persisted.sectors[MiningSectorId.frozenBasin]!.mine!.storedAmount,
        0,
      );
      expect(
        persisted.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
        0,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
  );
}
