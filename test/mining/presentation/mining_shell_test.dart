import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/game/storage_alerts.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';
import 'package:horologium/mining/presentation/mining_shell.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_background_music_player.dart';
import '../../support/fake_storage_alert_platform.dart';
import '../../support/mining_grid_fixtures.dart';
import '../../support/mining_visual_frames.dart';

class CountingMiningSaveRepository extends MiningSaveRepository {
  var saveCount = 0;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    await super.save(state);
  }
}

class FailingMiningSaveRepository extends MiningSaveRepository {
  var failSaves = false;

  @override
  Future<void> save(MiningSave state) async {
    if (failSaves) throw Exception('storage unavailable');
    await super.save(state);
  }
}

class DelayedMiningSaveRepository extends MiningSaveRepository {
  final saveStarted = Completer<void>();
  final allowSave = Completer<void>();
  var saveCount = 0;
  var delayNextSave = false;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    if (delayNextSave) {
      delayNextSave = false;
      saveStarted.complete();
      await allowSave.future;
    }
    await super.save(state);
  }
}

class DelayedAudioPrefsManager extends AudioManager {
  DelayedAudioPrefsManager({
    required super.backgroundMusicPlayer,
    super.soundEffectPlayer,
  });

  final loadStarted = Completer<void>();
  final allowLoad = Completer<void>();

  @override
  Future<void> loadPrefs() async {
    if (!loadStarted.isCompleted) loadStarted.complete();
    await allowLoad.future;
    await super.loadPrefs();
  }
}

class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;
}

const _viewport = Size(360, 640);
final _start = DateTime.utc(2026, 8, 26, 12);

const landingRigCell = MiningGridCell(3, 2);

MiningSave deployedLandingBasin(DateTime now) {
  final base = MiningSave.initial(nowUtc: now);
  final landing = base.sites[MiningSiteId.landingBasin]!;
  final sites = <MiningSiteId, SiteProgress>{...base.sites};
  sites[MiningSiteId.landingBasin] = landing.copyWith(
    commissioned: true,
    rigPlacements: [MiningRigPlacement(tier: RigTier.t1, cell: landingRigCell)],
  );
  return base.copyWith(sites: sites);
}

MiningSave deployedLandingState(DateTime now, {double cargo = 0}) {
  final base = MiningSave.initial(nowUtc: now);
  final landing = base.sites[MiningSiteId.landingBasin]!;
  final sites = <MiningSiteId, SiteProgress>{...base.sites};
  sites[MiningSiteId.landingBasin] = landing.copyWith(
    commissioned: true,
    storedAmount: cargo,
    rigPlacements: [MiningRigPlacement(tier: RigTier.t1, cell: landingRigCell)],
  );
  return base.copyWith(
    sites: sites,
    docks: {
      ...base.docks,
      MiningPlanetId.homeworld: {
        ...base.docks[MiningPlanetId.homeworld]!,
        DockBayId.b1: null,
      },
    },
  );
}

/// Every Homeworld site commissioned, as after Homeworld mastery.
MiningSave homeworldMasteredState(
  DateTime now, {
  int surveying = 0,
  int cash = 0,
}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    cash: cash,
    technology: TechnologyLevels(surveying: surveying),
    sites: {
      ...base.sites,
      for (final site
          in MiningContentRegistry.stellarMining()
              .planet(MiningPlanetId.homeworld)
              .sites)
        site.id: base.sites[site.id]!.copyWith(
          unlocked: true,
          commissioned: true,
        ),
    },
  );
}

/// Every authored site commissioned and planet unlocked, so the final
/// planet is mastered and Relaunch is available.
MiningSave finalPlanetMasteredState(DateTime now) {
  final content = MiningContentRegistry.stellarMining();
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    cash: 1_000_000,
    unlockedPlanetIds: {...MiningPlanetId.values},
    activePlanetId: content.finalPlanetId,
    sites: {
      ...base.sites,
      for (final planet in MiningPlanetId.values)
        for (final site in content.planet(planet).sites)
          site.id: base.sites[site.id]!.copyWith(
            unlocked: true,
            commissioned: true,
          ),
    },
  );
}

Finder _inGoalStrip(Finder matching) => find.descendant(
  of: find.byKey(const Key('site-deck-next-goal')),
  matching: matching,
);

/// Taps the center of a grid cell through the pannable mine-site transform.
Future<void> tapGridCell(WidgetTester tester, MiningGridCell cell) async {
  final surface = tester.getRect(find.byKey(const Key('mining-grid-surface')));
  await tester.tapAt(
    surface.topLeft +
        Offset(
          (cell.x + .5) * miningGridCellSize,
          (cell.y + .5) * miningGridCellSize,
        ),
  );
}

/// A free Surveying-0 perimeter cell of Landing Basin, distinct from
/// [landingRigCell], used to deploy a freshly spawned rig without re-tapping
/// the dock.
final _freeLandingDeployCell = deployableMiningCells(
  MiningContentRegistry.stellarMining().site(MiningSiteId.landingBasin),
).firstWhere((cell) => cell != landingRigCell);

const frozenRigCell = MiningGridCell(4, 2);

/// Homeworld mastered, Lunar Frontier unlocked and active at Surveying 3,
/// with one T1 rig mining Frozen Basin from [frozenRigCell].
MiningSave deployedFrozenBasinState(
  DateTime now, {
  double cargo = 0,
  bool withRig = true,
}) {
  final base = homeworldMasteredState(now, surveying: 3);
  return base.copyWith(
    unlockedPlanetIds: {MiningPlanetId.homeworld, MiningPlanetId.lunarFrontier},
    activePlanetId: MiningPlanetId.lunarFrontier,
    sites: {
      ...base.sites,
      MiningSiteId.frozenBasin: base.sites[MiningSiteId.frozenBasin]!.copyWith(
        unlocked: true,
        commissioned: true,
        storedAmount: cargo,
        rigPlacements: [
          if (withRig)
            MiningRigPlacement(tier: RigTier.t1, cell: frozenRigCell),
        ],
      ),
    },
  );
}

/// Surveying-0 legal deploy cell for Carbon Ridge, used to prove dock
/// selection does not leak across sites.
final _carbonRidgeCell = deployableMiningCells(
  MiningContentRegistry.stellarMining().site(MiningSiteId.carbonRidge),
).first;

/// Two producers across unlocked planets with a clear earliest fill:
/// Landing Basin (Homeworld, full in 7200 s) and Frozen Basin (Lunar
/// Frontier, full in 6600 s from 600 stored units at 1.00/s).
MiningSave multiProducerState(DateTime now) {
  final base = homeworldMasteredState(now, surveying: 3);
  return base.copyWith(
    unlockedPlanetIds: {MiningPlanetId.homeworld, MiningPlanetId.lunarFrontier},
    sites: {
      ...base.sites,
      MiningSiteId.landingBasin: base.sites[MiningSiteId.landingBasin]!
          .copyWith(
            rigPlacements: [
              MiningRigPlacement(tier: RigTier.t1, cell: landingRigCell),
            ],
          ),
      MiningSiteId.frozenBasin: base.sites[MiningSiteId.frozenBasin]!.copyWith(
        unlocked: true,
        commissioned: true,
        storedAmount: 600,
        rigPlacements: [
          MiningRigPlacement(tier: RigTier.t1, cell: frozenRigCell),
        ],
      ),
    },
  );
}

Future<void> pumpShell(
  WidgetTester tester, {
  MiningSaveRepository? repository,
  TestClock? clock,
  AudioManager? audioManager,
  StorageAlerts? storageAlerts,
  bool disableAnimations = false,
  Key? shellKey,
  int pumpCycles = 6,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  final testClock = clock ?? TestClock(_start);
  final audio =
      audioManager ??
      AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: FakeBackgroundMusicPlayer(),
      );
  if (audioManager == null) addTearDown(audio.dispose);
  // Default to a fake platform so shell tests never touch the real plugin
  // channel, mirroring the fake-backed AudioManager default above.
  final alerts =
      storageAlerts ?? StorageAlerts(platform: FakeStorageAlertPlatform());
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MiningShell(
          key: shellKey,
          content: MiningContentRegistry.stellarMining(),
          repository: repository,
          nowUtc: testClock.call,
          audioManager: audio,
          storageAlerts: alerts,
        ),
      ),
    ),
  );
  for (var i = 0; i < pumpCycles; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Future<void> pumpMiningTick(
  WidgetTester tester,
  TestClock clock, {
  Duration elapsed = const Duration(seconds: 1),
}) async {
  clock.now = clock.now.add(elapsed);
  await tester.pump(const Duration(seconds: 1));
}

MiningShellHandles shellHandles(WidgetTester tester) =>
    tester.state(find.byType(MiningShell)) as MiningShellHandles;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'open technology sheet adapts to rotation and preserves the visor',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      final audio = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: FakeBackgroundMusicPlayer(),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await audio.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MiningShell(
            nowUtc: () => _start,
            audioManager: audio,
            storageAlerts: StorageAlerts(platform: FakeStorageAlertPlatform()),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      shellHandles(tester).openTechnology();
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('mining-technology-sheet'));
      expect(tester.getRect(sheet).top, greaterThan(130));
      expect(tester.getSize(sheet).width, 430);
      tester.view.physicalSize = const Size(874, 402);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('mining-sheet-panel'))).left,
        greaterThan(300),
      );
      expect(
        tester.getSize(find.byKey(const Key('mining-sheet-panel'))).width,
        528,
      );
      final scene = find.byType(MiningSheetScene);
      final navigation = tester.widget<MiningNavigationBar>(
        find.descendant(of: scene, matching: find.byType(MiningNavigationBar)),
      );
      expect(navigation.selected, MiningNavigationDestination.technology);
      expect(
        tester
            .widget<Image>(find.byKey(const Key('mining-sheet-background')))
            .image,
        AssetImage(
          MiningContentRegistry.stellarMining()
              .site(MiningSiteId.landingBasin)
              .cavernAsset,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: scene,
          matching: find.byKey(const Key('mining-nav-settings')),
        ),
      );
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.byKey(const Key('mining-settings-sheet')), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close Settings'));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    },
  );

  testWidgets(
    'technology sheet HUD refreshes cargo while the foreground timer accrues',
    (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start));
      final clock = TestClock(_start);
      await pumpShell(tester, repository: repository, clock: clock);

      shellHandles(tester).openTechnology();
      await tester.pump();

      MiningCargoGauge sheetGauge() => tester.widget<MiningCargoGauge>(
        find.descendant(
          of: find.byType(MiningSheetScene),
          matching: find.byKey(const Key('mining-cargo-gauge')),
        ),
      );

      expect(sheetGauge().cargo, 0);

      await pumpMiningTick(tester, clock);
      await tester.pump();

      expect(sheetGauge().cargo, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders the Site Deck and active-planet HUD', (tester) async {
    await pumpShell(tester);

    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
    expect(
      find.byKey(const Key('fleet-dock')),
      findsNothing,
      reason: 'Fleet management is Mine-Site-only.',
    );
    expect(find.byKey(const Key('mining-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mining-cash-chip')), findsOneWidget);
    expect(find.byKey(const Key('mining-cargo-gauge')), findsOneWidget);
    expect(find.text('HOMEWORLD'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('mining-cash-chip')),
        matching: find.text('100'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation opens the full-screen Stellar Map locally', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
    await tester.pump();

    expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
    expect(find.byKey(const Key('site-deck-scroll')), findsNothing);

    await tester.tap(find.byKey(const Key('mining-nav-siteDeck')));
    await tester.pump();
    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
  });

  testWidgets(
    'Stellar Map unlock and travel settle through serialized actions',
    (tester) async {
      final initial = MiningSave.initial(nowUtc: _start);
      final sites = <MiningSiteId, SiteProgress>{...initial.sites};
      for (final site
          in MiningContentRegistry.stellarMining()
              .planet(MiningPlanetId.homeworld)
              .sites) {
        sites[site.id] = sites[site.id]!.copyWith(
          unlocked: true,
          commissioned: true,
        );
      }
      final repository = CountingMiningSaveRepository();
      await repository.save(
        initial.copyWith(
          cash: 203_000,
          technology: const TechnologyLevels(surveying: 3),
          sites: sites,
        ),
      );
      await pumpShell(tester, repository: repository);

      await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
      await tester.pump();
      final unlock = find.byKey(
        const Key('mining-stellar-map-unlock-lunarFrontier'),
      );
      await tester.ensureVisible(unlock);
      await tester.tap(unlock);
      await tester.pump(const Duration(milliseconds: 300));

      final controller = shellHandles(tester).controller;
      expect(controller.state.activePlanetId, MiningPlanetId.lunarFrontier);
      expect(
        controller.state.unlockedPlanetIds,
        contains(MiningPlanetId.lunarFrontier),
      );

      final travel = find.byKey(
        const Key('mining-stellar-map-travel-homeworld'),
      );
      await tester.ensureVisible(travel);
      await tester.tap(travel);
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.state.activePlanetId, MiningPlanetId.homeworld);
      expect(repository.saveCount, greaterThanOrEqualTo(3));
    },
  );

  testWidgets(
    'relaunch cancels cleanly and confirms through the one mutation path',
    (tester) async {
      final clock = TestClock(_start);
      final repository = DelayedMiningSaveRepository();
      await repository.save(finalPlanetMasteredState(clock.now));
      final effects = FakeBackgroundMusicPlayer();
      final audio = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: effects,
      );
      addTearDown(audio.dispose);
      await pumpShell(
        tester,
        repository: repository,
        clock: clock,
        audioManager: audio,
      );

      await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
      await tester.pump();
      final action = find.byKey(const Key('stellar-map-relaunch-action'));
      await tester.ensureVisible(action);
      await tester.pump();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mining-relaunch-sheet')), findsOneWidget);

      // Cancel just dismisses; nothing mutates or navigates.
      await tester.ensureVisible(find.byKey(const Key('relaunch-cancel')));
      await tester.tap(find.byKey(const Key('relaunch-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mining-relaunch-sheet')), findsNothing);
      expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
      var state = shellHandles(tester).controller.state;
      expect(state.cash, 1_000_000);
      expect(state.relaunchCount, 0);
      expect(state.activePlanetId, MiningPlanetId.values.last);
      expect(
        effects.playedAssets,
        everyElement('audio/tap.wav'),
        reason: 'cancelling plays no action sound',
      );

      // Confirm: dismiss, one save in flight, no celebration yet.
      await tester.tap(action);
      await tester.pumpAndSettle();
      final savesBefore = repository.saveCount;
      repository.delayNextSave = true;
      await tester.ensureVisible(find.byKey(const Key('relaunch-confirm')));
      await tester.tap(find.byKey(const Key('relaunch-confirm')));
      await repository.saveStarted.future;
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mining-relaunch-sheet')), findsNothing);
      expect(repository.saveCount, savesBefore + 1);
      expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
      expect(
        effects.playedAssets.where((path) => path == 'audio/milestone.wav'),
        isEmpty,
        reason: 'milestone waits for successful persistence',
      );

      repository.allowSave.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        effects.playedAssets.where((path) => path == 'audio/milestone.wav'),
        hasLength(1),
      );
      expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
      state = shellHandles(tester).controller.state;
      expect(state.cash, 100);
      expect(state.relaunchCount, 1);
      expect(state.activePlanetId, MiningPlanetId.homeworld);
      expect(state.unlockedPlanetIds, {MiningPlanetId.homeworld});

      final reloaded = await repository.load(nowUtc: clock.now);
      expect(reloaded.state.relaunchCount, 1);
      expect(reloaded.state.cash, 100);
    },
  );

  testWidgets(
    'relaunch confirm during a queued save reports busy, not silence',
    (tester) async {
      final clock = TestClock(_start);
      final repository = DelayedMiningSaveRepository();
      await repository.save(finalPlanetMasteredState(clock.now));
      final effects = FakeBackgroundMusicPlayer();
      final audio = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: effects,
      );
      addTearDown(audio.dispose);
      await pumpShell(
        tester,
        repository: repository,
        clock: clock,
        audioManager: audio,
      );

      await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
      await tester.pump();
      final action = find.byKey(const Key('stellar-map-relaunch-action'));
      await tester.ensureVisible(action);
      await tester.pump();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mining-relaunch-sheet')), findsOneWidget);

      // A queued lifecycle-style checkpoint keeps the controller busy
      // while the sheet is open; the confirm used to die silently there.
      repository.delayNextSave = true;
      final checkpoint = shellHandles(tester).controller.checkpoint();
      await repository.saveStarted.future;
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('relaunch-confirm')));
      await tester.tap(find.byKey(const Key('relaunch-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mining-relaunch-sheet')), findsNothing);
      expect(find.text('Finishing previous action…'), findsOneWidget);
      expect(
        effects.playedAssets.where((path) => path == 'audio/reject.wav'),
        hasLength(1),
      );
      expect(
        effects.playedAssets.where((path) => path == 'audio/milestone.wav'),
        isEmpty,
      );

      repository.allowSave.complete();
      await checkpoint;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final state = shellHandles(tester).controller.state;
      expect(state.relaunchCount, 0);
      expect(state.activePlanetId, MiningPlanetId.values.last);
    },
  );

  testWidgets(
    'travel clears the selected dock bay before the new planet view',
    (tester) async {
      final initial = MiningSave.initial(nowUtc: _start);
      final repository = CountingMiningSaveRepository();
      final sites = <MiningSiteId, SiteProgress>{...initial.sites};
      sites[MiningSiteId.frozenBasin] = sites[MiningSiteId.frozenBasin]!
          .copyWith(unlocked: true);
      final lunarDock = <DockBayId, RigTier?>{
        ...initial.docks[MiningPlanetId.lunarFrontier]!,
        DockBayId.b1: RigTier.t1,
      };
      await repository.save(
        initial.copyWith(
          cash: 205_000,
          technology: const TechnologyLevels(surveying: 3),
          unlockedPlanetIds: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          docks: {...initial.docks, MiningPlanetId.lunarFrontier: lunarDock},
          sites: sites,
        ),
      );
      await pumpShell(tester, repository: repository);

      await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
      await tester.pump();
      final travel = find.byKey(
        const Key('mining-stellar-map-travel-lunarFrontier'),
      );
      await tester.ensureVisible(travel);
      await tester.tap(travel);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('mining-nav-siteDeck')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('site-card-frozenBasin-enter')));
      await tester.pump();
      await tapGridCell(tester, frozenRigCell);
      await tester.pump(const Duration(milliseconds: 300));

      final state = shellHandles(tester).controller.state;
      expect(state.activePlanetId, MiningPlanetId.lunarFrontier);
      expect(state.sites[MiningSiteId.frozenBasin]!.rigPlacements, isEmpty);
    },
  );

  testWidgets('planet unlock clears the selected dock bay before activation', (
    tester,
  ) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final repository = CountingMiningSaveRepository();
    final sites = <MiningSiteId, SiteProgress>{...initial.sites};
    for (final site
        in MiningContentRegistry.stellarMining()
            .planet(MiningPlanetId.homeworld)
            .sites) {
      sites[site.id] = sites[site.id]!.copyWith(
        unlocked: true,
        commissioned: true,
      );
    }
    await repository.save(
      initial.copyWith(
        cash: 205_000,
        technology: const TechnologyLevels(surveying: 3),
        sites: sites,
      ),
    );
    await pumpShell(tester, repository: repository);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
    await tester.pump();
    final unlock = find.byKey(
      const Key('mining-stellar-map-unlock-lunarFrontier'),
    );
    await tester.ensureVisible(unlock);
    await tester.tap(unlock);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('mining-nav-siteDeck')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('site-card-frozenBasin-enter')));
    await tester.pump();
    await tapGridCell(tester, frozenRigCell);
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.activePlanetId, MiningPlanetId.lunarFrontier);
    expect(state.sites[MiningSiteId.frozenBasin]!.rigPlacements, isEmpty);
  });

  testWidgets('missing save attempts initial persistence', (tester) async {
    final repository = CountingMiningSaveRepository();

    await pumpShell(tester, repository: repository);

    expect(repository.saveCount, 1);
    expect(shellHandles(tester).controller.state.cash, 100);
  });

  testWidgets(
    'first commission celebrates; repeat deployment uses the rig cue',
    (tester) async {
      final effects = FakeBackgroundMusicPlayer();
      final audio = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: effects,
      );
      addTearDown(audio.dispose);
      await pumpShell(tester, audioManager: audio);
      expect(effects.playedAssets, ['audio/tap.wav']);
      await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.pump();
      await tapGridCell(tester, landingRigCell);
      await tester.pump(const Duration(milliseconds: 300));
      expect(effects.playedAssets.last, 'audio/milestone.wav');
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.commissioned,
        isTrue,
      );

      await tapGridCell(tester, landingRigCell);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.pump();
      await tapGridCell(tester, landingRigCell);
      await tester.pump(const Duration(milliseconds: 300));
      expect(effects.playedAssets.last, 'audio/rig.wav');
      expect(
        effects.playedAssets.where((path) => path == 'audio/milestone.wav'),
        hasLength(1),
      );
    },
  );

  testWidgets('failed persistence rejects the action without success audio', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    repository.delayNextSave = true;
    await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
    await tester.pump();
    repository.allowSave.completeError(StateError('save failed'));
    await tester.pump();
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/reject.wav',
    ]);
    expect(shellHandles(tester).controller.state.cash, 100);

    // The failed spawn leaves no phantom selected bay behind.
    await tapGridCell(tester, landingRigCell);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Select a rig from the dock.'), findsOneWidget);
    expect(
      shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.landingBasin]!.rigPlacements,
      isEmpty,
    );
  });

  testWidgets(
    'technology selection and dismissal use taps; muted entry is silent',
    (tester) async {
      SharedPreferences.setMockInitialValues({'audio.soundEnabled': false});
      final effects = FakeBackgroundMusicPlayer();
      final audio = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: effects,
      );
      addTearDown(audio.dispose);
      await pumpShell(tester, audioManager: audio);
      expect(effects.playedAssets, isEmpty);
      await audio.setSoundEnabled(true);
      shellHandles(tester).openTechnology();
      await tester.pumpAndSettle();
      expect(effects.playedAssets, hasLength(1), reason: 'open');
      await tester.tap(find.byKey(const Key('technology-track-logistics')));
      await tester.pump();
      expect(effects.playedAssets, hasLength(2), reason: 'selection');
      await tester.tap(find.byKey(const Key('technology-track-logistics')));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Close Technology'));
      await tester.pumpAndSettle();
      expect(effects.playedAssets, [
        'audio/tap.wav',
        'audio/tap.wav',
        'audio/tap.wav',
      ]);
    },
  );

  testWidgets('Mine Site wires bay selection, merge, spawn, and site exit', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(MiningSave.initial(nowUtc: _start));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.tap(find.byKey(const ValueKey<String>('b2')));
    await tester.pump(const Duration(milliseconds: 300));

    final controller = shellHandles(tester).controller;
    expect(
      controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b1],
      isNull,
    );
    expect(
      controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b2],
      RigTier.t2,
    );
    expect(find.text('Rigs merged.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b1],
      RigTier.t1,
    );
    expect(controller.state.cash, 75);

    await tester.tap(find.byKey(const Key('mine-site-back')));
    await tester.pump();
    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
    expect(
      find.byKey(const Key('fleet-dock')),
      findsNothing,
      reason: 'Fleet management is Mine-Site-only.',
    );
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/merge.wav',
      'audio/rig.wav',
      'audio/tap.wav',
    ]);
  });

  testWidgets('spawn selects its filled bay so the new rig deploys directly', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(_start));
    await pumpShell(tester, repository: repository);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
    await tester.binding.idle();
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b1], RigTier.t1);

    // The new bay is not tapped again; the spawned T1 deploys straight away.
    await tapGridCell(tester, _freeLandingDeployCell);
    await tester.pump(const Duration(milliseconds: 300));

    final deployed = shellHandles(tester).controller.state;
    expect(deployed.docks[MiningPlanetId.homeworld]![DockBayId.b1], isNull);
    expect(
      deployed.sites[MiningSiteId.landingBasin]!.rigPlacements,
      contains(
        MiningRigPlacement(tier: RigTier.t1, cell: _freeLandingDeployCell),
      ),
    );
    expect(find.text('Rig deployed.'), findsOneWidget);
  });

  testWidgets('merge keeps the combined rig selected so it deploys directly', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(MiningSave.initial(nowUtc: _start));
    await pumpShell(tester, repository: repository);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('b2')));
    await tester.binding.idle();
    await tester.pump(const Duration(milliseconds: 300));

    var state = shellHandles(tester).controller.state;
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b1], isNull);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b2], RigTier.t2);
    expect(find.text('Rigs merged.'), findsOneWidget);

    // The target bay is not tapped again; the merged T2 deploys straight away.
    await tapGridCell(tester, landingRigCell);
    await tester.pump(const Duration(milliseconds: 300));

    state = shellHandles(tester).controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, [
      MiningRigPlacement(tier: RigTier.t2, cell: landingRigCell),
    ]);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b2], isNull);
    expect(find.text('Rig deployed.'), findsOneWidget);
  });

  testWidgets('a failed merge keeps the source rig selected', (tester) async {
    final repository = DelayedMiningSaveRepository();
    await repository.save(MiningSave.initial(nowUtc: _start));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.pump();
    repository.delayNextSave = true;
    await tester.tap(find.byKey(const ValueKey<String>('b2')));
    await repository.saveStarted.future;
    repository.allowSave.completeError(StateError('save failed'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Action failed.'), findsOneWidget);
    expect(
      shellHandles(
        tester,
      ).controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b2],
      RigTier.t1,
      reason: 'merge did not persist',
    );
    expect(
      find.bySemanticsLabel('Dock bay B1: Selected T1 rig.'),
      findsOneWidget,
    );
  });

  testWidgets('dock selection clears when leaving Mine Site', (tester) async {
    // Arrange two unlocked sites so a selection can be exercised across a
    // site boundary.
    final initial = MiningSave.initial(nowUtc: _start);
    final repository = CountingMiningSaveRepository();
    await repository.save(
      initial.copyWith(
        sites: {
          ...initial.sites,
          MiningSiteId.carbonRidge: initial.sites[MiningSiteId.carbonRidge]!
              .copyWith(unlocked: true),
        },
      ),
    );
    await pumpShell(tester, repository: repository);

    // Enter site A and select a dock rig.
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.pump();

    // Back to Site Deck, then enter site B and tap a legal cell without
    // selecting again.
    await tester.tap(find.byKey(const Key('mine-site-back')));
    await tester.pump();
    final enterCarbonRidge = find.byKey(
      const Key('site-card-carbonRidge-enter'),
    );
    await tester.ensureVisible(enterCarbonRidge);
    await tester.pump();
    await tester.tap(enterCarbonRidge);
    await tester.pump();
    await tapGridCell(tester, _carbonRidgeCell);
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.sites[MiningSiteId.carbonRidge]!.rigPlacements, isEmpty);
    expect(find.text('Select a rig from the dock.'), findsOneWidget);
  });

  testWidgets(
    'spawn finishing after leaving Mine Site keeps the selection cleared',
    (tester) async {
      final initial = MiningSave.initial(nowUtc: _start);
      final repository = DelayedMiningSaveRepository();
      await repository.save(
        initial.copyWith(
          sites: {
            ...initial.sites,
            MiningSiteId.carbonRidge: initial.sites[MiningSiteId.carbonRidge]!
                .copyWith(unlocked: true),
          },
        ),
      );
      await pumpShell(tester, repository: repository);

      await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
      await tester.pump();
      repository.delayNextSave = true;
      await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
      await repository.saveStarted.future;

      // Leaving while persistence is in flight must not let the pending
      // success callback restore a hidden selection on the Site Deck.
      await tester.tap(find.byKey(const Key('mine-site-back')));
      await tester.pump();
      expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
      repository.allowSave.complete();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        shellHandles(
          tester,
        ).controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b3],
        RigTier.t1,
        reason: 'spawn persisted after the exit',
      );

      final enterCarbonRidge = find.byKey(
        const Key('site-card-carbonRidge-enter'),
      );
      await tester.ensureVisible(enterCarbonRidge);
      await tester.pump();
      await tester.tap(enterCarbonRidge);
      await tester.pump();
      await tapGridCell(tester, _carbonRidgeCell);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.carbonRidge]!.rigPlacements,
        isEmpty,
      );
      expect(find.text('Select a rig from the dock.'), findsOneWidget);
    },
  );

  testWidgets(
    'merge finishing after leaving Mine Site keeps the selection cleared',
    (tester) async {
      final initial = MiningSave.initial(nowUtc: _start);
      final repository = DelayedMiningSaveRepository();
      await repository.save(
        initial.copyWith(
          sites: {
            ...initial.sites,
            MiningSiteId.carbonRidge: initial.sites[MiningSiteId.carbonRidge]!
                .copyWith(unlocked: true),
          },
        ),
      );
      await pumpShell(tester, repository: repository);

      await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.pump();
      repository.delayNextSave = true;
      await tester.tap(find.byKey(const ValueKey<String>('b2')));
      await repository.saveStarted.future;

      // Leaving while persistence is in flight must not let the pending
      // success callback restore a hidden selection on the Site Deck.
      await tester.tap(find.byKey(const Key('mine-site-back')));
      await tester.pump();
      expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
      repository.allowSave.complete();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        shellHandles(
          tester,
        ).controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b2],
        RigTier.t2,
        reason: 'merge persisted after the exit',
      );

      final enterCarbonRidge = find.byKey(
        const Key('site-card-carbonRidge-enter'),
      );
      await tester.ensureVisible(enterCarbonRidge);
      await tester.pump();
      await tester.tap(enterCarbonRidge);
      await tester.pump();
      await tapGridCell(tester, _carbonRidgeCell);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.carbonRidge]!.rigPlacements,
        isEmpty,
      );
      expect(find.text('Select a rig from the dock.'), findsOneWidget);
    },
  );

  testWidgets('Mine Site deploys and recalls through the controller', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(_start));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tapGridCell(tester, landingRigCell);
    await tester.pump(const Duration(milliseconds: 300));

    var state = shellHandles(tester).controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, isEmpty);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b1], RigTier.t1);
    expect(find.text('Rig recalled.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.pump();
    await tapGridCell(tester, landingRigCell);
    await tester.pump(const Duration(milliseconds: 300));

    state = shellHandles(tester).controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, [
      MiningRigPlacement(tier: RigTier.t1, cell: landingRigCell),
    ]);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b1], isNull);
    expect(find.text('Rig deployed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/rig.wav',
      'audio/tap.wav',
      'audio/rig.wav',
    ]);
  });

  testWidgets('Mine Site sells active-planet cargo and reports revenue', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(_start, cargo: 10));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mine-site-sell')));
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.cash, 140);
    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 0);
    expect(find.text('Sold 40 cash.'), findsOneWidget);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/sale.wav',
    ]);
  });

  testWidgets('Site Deck sells active-planet cargo and reports revenue', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(_start, cargo: 10));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    final sell = find.byKey(const Key('site-deck-sell'));
    expect(sell, findsOneWidget);
    expect(tester.widget<OutlinedButton>(sell).onPressed, isNotNull);
    expect(
      find.bySemanticsLabel('Sell all cargo for 40 cash.'),
      findsOneWidget,
    );

    await tester.tap(sell);
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.cash, 140);
    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 0);
    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
    expect(find.byKey(const Key('mining-grid-surface')), findsNothing);
    expect(find.text('Sold 40 cash.'), findsOneWidget);
    expect(
      effects.playedAssets.where((path) => path == 'audio/sale.wav'),
      hasLength(1),
    );
    expect(effects.playedAssets, ['audio/tap.wav', 'audio/sale.wav']);
  });

  testWidgets('a busy Site Deck sell ignores a second tap and sells once', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
    await repository.save(deployedLandingState(_start, cargo: 10));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    final sell = find.byKey(const Key('site-deck-sell'));
    repository.delayNextSave = true;
    await tester.tap(sell);
    await repository.saveStarted.future;
    await tester.pump();

    expect(tester.widget<OutlinedButton>(sell).onPressed, isNull);
    expect(find.bySemanticsLabel('Finishing previous action…'), findsOneWidget);

    await tester.tap(sell, warnIfMissed: false);
    repository.allowSave.complete();
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.cash, 140);
    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 0);
    expect(find.text('Sold 40 cash.'), findsOneWidget);
    expect(find.text('No cargo to sell.'), findsNothing);
    expect(find.text('Sale failed.'), findsNothing);
    expect(
      effects.playedAssets.where((path) => path == 'audio/sale.wav'),
      hasLength(1),
    );
    expect(effects.playedAssets, ['audio/tap.wav', 'audio/sale.wav']);
  });

  testWidgets('blocked occupied cell tap shows its disabled reason', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(_start, cargo: 150));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tapGridCell(tester, landingRigCell);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sell cargo before recalling this rig.'), findsOneWidget);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/reject.wav',
    ]);
  });

  testWidgets('busy node tap explains the pending action without mutating', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
    await repository.save(MiningSave.initial(nowUtc: _start));
    repository.delayNextSave = true;
    await pumpShell(tester, repository: repository);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
    await repository.saveStarted.future;
    await tester.pump();

    expect(shellHandles(tester).controller.isBusy, isTrue);
    expect(repository.saveCount, 2);
    try {
      await tapGridCell(tester, landingRigCell);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Finishing previous action…'), findsOneWidget);
    } finally {
      repository.allowSave.complete();
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(repository.saveCount, 2);
  });

  testWidgets('reduced motion makes Mine Site sale feedback settle instantly', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(_start, cargo: 10));
    await pumpShell(tester, repository: repository, disableAnimations: true);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mine-site-sell')));
    await tester.pump(const Duration(milliseconds: 300));

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.animation, isA<AnimationController>());
    expect(
      (snackBar.animation! as AnimationController).duration,
      Duration.zero,
    );
  });

  testWidgets('Site Deck unlocks an eligible site through the controller', (
    tester,
  ) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final repository = CountingMiningSaveRepository();
    await repository.save(
      initial.copyWith(
        cash: 300,
        sites: {
          ...initial.sites,
          MiningSiteId.landingBasin: initial.sites[MiningSiteId.landingBasin]!
              .copyWith(unlocked: true),
        },
      ),
    );
    await pumpShell(tester, repository: repository);

    await tester.ensureVisible(
      find.byKey(const Key('site-card-carbonRidge-unlock')),
    );
    await tester.drag(
      find.byKey(const Key('site-deck-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('site-card-carbonRidge-unlock')));
    await tester.pump(const Duration(milliseconds: 300));

    final controller = shellHandles(tester).controller;
    expect(controller.state.sites[MiningSiteId.carbonRidge]!.unlocked, isTrue);
    expect(controller.state.cash, 50);
  });

  testWidgets(
    'recovered save attempts initial persistence and explains reset',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: '{ malformed mining json',
      });
      final repository = CountingMiningSaveRepository();

      await pumpShell(tester, repository: repository, pumpCycles: 12);

      expect(repository.saveCount, 1);
      expect(
        find.text(
          'Mining progress could not be loaded, so a fresh mining save was '
          'started.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('timer refresh accrues cargo without persisting', (tester) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingBasin(_start));
    final savesBeforeTicks = repository.saveCount;

    await pumpShell(tester, repository: repository, clock: clock);
    clock.now = _start.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    final gauge = tester.widget<MiningCargoGauge>(
      find.byKey(const Key('mining-cargo-gauge')),
    );
    expect(gauge.cargo, 1);
    expect(gauge.projectedValue, 4);
    expect(repository.saveCount, savesBeforeTicks);
    expect(
      shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
      1.0,
    );
  });

  testWidgets('passive Landing Basin production increments one impact', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingBasin(clock.now));
    final savesBeforeTick = repository.saveCount;

    await pumpShell(tester, repository: repository, clock: clock);
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    final before = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    await pumpMiningTick(tester, clock);

    final after = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;
    final gauge = tester.widget<MiningCargoGauge>(
      find.byKey(const Key('mining-cargo-gauge')),
    );

    expect(after - before, 1);
    expect(gauge.cargo, closeTo(.5, .0001));
    expect(repository.saveCount, savesBeforeTick);
  });

  testWidgets('delayed foreground accrual still emits one impact', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingBasin(clock.now));
    await pumpShell(tester, repository: repository, clock: clock);
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    final before = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    await pumpMiningTick(tester, clock, elapsed: const Duration(seconds: 3));

    final after = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;
    expect(after - before, 1);
    expect(
      shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
      closeTo(1.5, .0001),
    );
  });

  testWidgets('final-fill production emits one impact and stops at capacity', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(clock.now, cargo: 3599.5));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(
      tester,
      repository: repository,
      clock: clock,
      audioManager: audio,
    );
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    final before = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    await pumpMiningTick(tester, clock);

    final after = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;
    expect(after - before, 1);
    expect(
      shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
      3600,
    );

    await pumpMiningTick(tester, clock);

    final afterFull = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;
    expect(afterFull - after, 0);
    expect(
      effects.playedAssets.where((path) => path == 'audio/cargoFull.wav'),
      hasLength(1),
    );
  });

  testWidgets('closed Landing Basin production emits no impact', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final initial = deployedLandingBasin(clock.now);
    final repository = CountingMiningSaveRepository();
    await repository.save(
      initial.copyWith(
        sites: {
          ...initial.sites,
          MiningSiteId.carbonRidge: initial.sites[MiningSiteId.carbonRidge]!
              .copyWith(unlocked: true, commissioned: true),
        },
      ),
    );
    await pumpShell(tester, repository: repository, clock: clock);
    final carbonRidge = find.byKey(const Key('site-card-carbonRidge-enter'));
    await tester.ensureVisible(carbonRidge);
    await tester.tap(carbonRidge);
    await tester.pump();

    final before = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;
    await pumpMiningTick(tester, clock);
    final after = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    expect(after - before, 0);
  });

  testWidgets('Landing Basin without a rig emits no impact', (tester) async {
    final clock = TestClock(_start);
    final initial = MiningSave.initial(nowUtc: clock.now);
    final repository = CountingMiningSaveRepository();
    await repository.save(
      initial.copyWith(
        sites: {
          ...initial.sites,
          MiningSiteId.landingBasin: initial.sites[MiningSiteId.landingBasin]!
              .copyWith(commissioned: true),
        },
      ),
    );
    await pumpShell(tester, repository: repository, clock: clock);
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    final before = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;
    await pumpMiningTick(tester, clock);
    final after = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    expect(after - before, 0);
  });

  testWidgets('already-full Landing Basin production emits no impact', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(clock.now, cargo: 3600));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(
      tester,
      repository: repository,
      clock: clock,
      audioManager: audio,
    );
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    final before = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;
    await pumpMiningTick(tester, clock);
    final after = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    expect(after - before, 0);
    expect(
      effects.playedAssets.where((path) => path == 'audio/cargoFull.wav'),
      isEmpty,
    );
  });

  testWidgets('controller and audio identities survive rebuild and rotation', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(
      backgroundMusicPlayer: player,
      soundEffectPlayer: FakeBackgroundMusicPlayer(),
    );
    const shellKey = ValueKey('stable-mining-shell');

    await pumpShell(
      tester,
      repository: repository,
      clock: clock,
      audioManager: audioManager,
      shellKey: shellKey,
    );
    final before = shellHandles(tester);

    final portraitSize = tester.view.physicalSize;
    try {
      tester.view.physicalSize = const Size(640, 360);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(),
            child: MiningShell(
              key: shellKey,
              content: MiningContentRegistry.stellarMining(),
              repository: repository,
              nowUtc: clock.call,
              audioManager: audioManager,
            ),
          ),
        ),
      );
      await tester.pump();

      final after = shellHandles(tester);
      expect(after.controller, same(before.controller));
      expect(after.audioManager, same(before.audioManager));
    } finally {
      tester.view.physicalSize = portraitSize;
      await tester.pump();
    }
  });

  testWidgets('first gesture starts BGM through the injected manager', (
    tester,
  ) async {
    final player = FakeBackgroundMusicPlayer();
    final audioManager = AudioManager(
      backgroundMusicPlayer: player,
      soundEffectPlayer: FakeBackgroundMusicPlayer(),
    );
    await pumpShell(tester, audioManager: audioManager);

    await tester.tap(find.byKey(const Key('site-deck-scroll')));
    await tester.pump();

    expect(player.playedAssets, <String>['audio/orbital_foundry.mp3']);
  });

  testWidgets('audio gestures wait for preferences to finish loading', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'audio.musicEnabled': false});
    final player = FakeBackgroundMusicPlayer();
    final audioManager = DelayedAudioPrefsManager(
      backgroundMusicPlayer: player,
    );

    await pumpShell(tester, audioManager: audioManager, pumpCycles: 1);
    await audioManager.loadStarted.future;
    await tester.tap(find.byKey(const Key('mining-shell-loading')));
    await tester.pump();
    expect(player.playedAssets, isEmpty);

    audioManager.allowLoad.complete();
    await tester.pump();
    await tester.pump();
    expect(audioManager.musicEnabled, isFalse);
  });

  testWidgets('pre-initialization renders no enabled mining actions', (
    tester,
  ) async {
    final audioManager = DelayedAudioPrefsManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: FakeBackgroundMusicPlayer(),
    );

    await pumpShell(tester, audioManager: audioManager, pumpCycles: 1);
    await audioManager.loadStarted.future;

    expect(find.byKey(const Key('mining-shell-loading')), findsOneWidget);
    expect(find.byKey(const Key('site-deck-scroll')), findsNothing);
    expect(find.byKey(const Key('fleet-dock-spawn')), findsNothing);
    expect(find.byKey(const Key('mining-bottom-navigation')), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);

    audioManager.allowLoad.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
    expect(shellHandles(tester).controller.state.cash, 100);
  });

  testWidgets('settings keeps the injected AudioManager preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'audio.musicEnabled': false,
      'audio.musicVolume': 0.75,
    });
    final audioManager = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: FakeBackgroundMusicPlayer(),
    );
    await pumpShell(tester, audioManager: audioManager);

    shellHandles(tester).openSettings();
    await tester.pump(const Duration(milliseconds: 300));

    final sheet = find.byKey(const Key('mining-settings-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('mining-music-state')))
          .properties
          .toggled,
      isFalse,
    );
    expect(
      tester
          .widget<Slider>(
            find.descendant(of: sheet, matching: find.byType(Slider)),
          )
          .value,
      0.75,
    );
  });

  testWidgets('reduced motion follows MediaQuery at the shell owner', (
    tester,
  ) async {
    await pumpShell(tester, disableAnimations: true);

    expect(shellHandles(tester).reducedMotion, isTrue);
  });

  testWidgets(
    'pause stops the timer, checkpoints, and resume shows Offline Return',
    (tester) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingBasin(_start));
      await pumpShell(tester, repository: repository, clock: clock);

      clock.now = _start.add(const Duration(seconds: 4));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.saveCount, 2);
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        2.0,
      );

      clock.now = _start.add(const Duration(seconds: 14));
      await tester.pump(const Duration(seconds: 2));
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        2.0,
      );

      // A real device reports inactive on its way back to resumed; it must
      // not consume the away window before resume() can summarize it.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
      expect(find.textContaining('Gold'), findsWidgets);
    },
  );

  testWidgets(
    'inactive then resumed accrues silently with no checkpoint or sheet',
    (tester) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingBasin(_start));
      final platform = FakeStorageAlertPlatform();
      await pumpShell(
        tester,
        repository: repository,
        clock: clock,
        storageAlerts: StorageAlerts(platform: platform),
      );

      // A system dialog or the notification shade only inactivates: no
      // checkpoint, no alert projection, and the return sheet stays hidden
      // even though the site kept producing.
      clock.now = _start.add(const Duration(seconds: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.saveCount, 1);
      expect(platform.scheduleCount, 0);
      expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        greaterThan(0),
      );
    },
  );

  testWidgets(
    'backgrounding during initialization does not start the refresh timer',
    (tester) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start));
      final audio = DelayedAudioPrefsManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: FakeBackgroundMusicPlayer(),
      );
      addTearDown(audio.dispose);
      final platform = FakeStorageAlertPlatform();
      await pumpShell(
        tester,
        repository: repository,
        clock: clock,
        audioManager: audio,
        storageAlerts: StorageAlerts(platform: platform),
        pumpCycles: 1,
      );
      await audio.loadStarted.future;

      // The pause arrives before the shell is initialized, so it is
      // ignored; initialization then completes while still backgrounded.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      audio.allowLoad.complete();
      await tester.pump();
      await tester.pump();

      clock.now = _start.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        0.0,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        greaterThan(0),
      );
    },
  );

  testWidgets('a failing checkpoint save is swallowed and the shell works', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = FailingMiningSaveRepository();
    await repository.save(deployedLandingState(_start));
    await pumpShell(tester, repository: repository, clock: clock);

    repository.failSaves = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // The best-effort checkpoint handler absorbs the storage failure: the
    // lifecycle still completes, and resume accrues from the last good save.
    clock.now = _start.add(const Duration(seconds: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
  });

  testWidgets('lifecycle resume does not replay passive impacts', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingBasin(clock.now));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(
      tester,
      repository: repository,
      clock: clock,
      audioManager: audio,
    );
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    final before = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock.now = clock.now.add(const Duration(minutes: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    final after = tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;
    expect(after - before, 0);
    expect(effects.playedAssets, ['audio/tap.wav', 'audio/tap.wav']);
    expect(
      shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
      greaterThan(0),
    );
  });

  testWidgets('a visible Landing Basin strike plays the mining cue', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingBasin(clock.now));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await warmDepositFrames(tester, MiningDepositFrames.gold);
    await pumpShell(
      tester,
      repository: repository,
      clock: clock,
      audioManager: audio,
    );
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    await pumpMiningTick(tester, clock);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/mining.wav',
    ]);
  }, skip: kIsWeb);

  group('Frozen Basin impacts', () {
    int impactSequence(WidgetTester tester) => tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    Future<void> openFrozenBasin(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('site-card-frozenBasin-enter')));
      await tester.pump();
    }

    testWidgets('passive production strikes once and plays the mining cue', (
      tester,
    ) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedFrozenBasinState(clock.now));
      final effects = FakeBackgroundMusicPlayer();
      final audio = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: effects,
      );
      addTearDown(audio.dispose);
      await warmDepositFrames(tester, MiningDepositFrames.waterIce);
      await pumpShell(
        tester,
        repository: repository,
        clock: clock,
        audioManager: audio,
      );
      await openFrozenBasin(tester);

      final before = impactSequence(tester);
      await pumpMiningTick(tester, clock);
      expect(impactSequence(tester) - before, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(effects.playedAssets, [
        'audio/tap.wav',
        'audio/tap.wav',
        'audio/mining.wav',
      ]);
    }, skip: kIsWeb);

    testWidgets('closed Frozen Basin production emits no impact', (
      tester,
    ) async {
      final clock = TestClock(_start);
      final initial = deployedFrozenBasinState(clock.now);
      final repository = CountingMiningSaveRepository();
      await repository.save(
        initial.copyWith(
          sites: {
            ...initial.sites,
            MiningSiteId.titaniumHighlands: initial
                .sites[MiningSiteId.titaniumHighlands]!
                .copyWith(unlocked: true, commissioned: true),
          },
        ),
      );
      await pumpShell(tester, repository: repository, clock: clock);
      final titanium = find.byKey(
        const Key('site-card-titaniumHighlands-enter'),
      );
      await tester.ensureVisible(titanium);
      await tester.tap(titanium);
      await tester.pump();

      final before = impactSequence(tester);
      await pumpMiningTick(tester, clock);
      expect(impactSequence(tester) - before, 0);
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.frozenBasin]!.storedAmount,
        greaterThan(0),
      );
    });

    testWidgets('unrigged Frozen Basin emits no impact', (tester) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(
        deployedFrozenBasinState(clock.now, withRig: false),
      );
      await pumpShell(tester, repository: repository, clock: clock);
      await openFrozenBasin(tester);

      final before = impactSequence(tester);
      await pumpMiningTick(tester, clock);
      expect(impactSequence(tester) - before, 0);
    });

    testWidgets('already-full Frozen Basin emits no impact', (tester) async {
      final clock = TestClock(_start);
      final content = MiningContentRegistry.stellarMining();
      final capacity = content.effectiveSiteCapacity(MiningSiteId.frozenBasin, [
        RigTier.t1,
      ], 0);
      final repository = CountingMiningSaveRepository();
      await repository.save(
        deployedFrozenBasinState(clock.now, cargo: capacity),
      );
      await pumpShell(tester, repository: repository, clock: clock);
      await openFrozenBasin(tester);

      final before = impactSequence(tester);
      await pumpMiningTick(tester, clock);
      expect(impactSequence(tester) - before, 0);
    });

    testWidgets('lifecycle resume emits no Frozen Basin impact', (
      tester,
    ) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedFrozenBasinState(clock.now));
      await pumpShell(tester, repository: repository, clock: clock);
      await openFrozenBasin(tester);

      final before = impactSequence(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.now = clock.now.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(impactSequence(tester) - before, 0);
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.frozenBasin]!.storedAmount,
        greaterThan(0),
      );
    });

    testWidgets(
      'leaving Landing Basin for Frozen Basin waits for the next tick',
      (tester) async {
        final clock = TestClock(_start);
        final frozen = deployedFrozenBasinState(clock.now);
        final repository = CountingMiningSaveRepository();
        await repository.save(
          frozen.copyWith(
            activePlanetId: MiningPlanetId.homeworld,
            sites: {
              ...frozen.sites,
              MiningSiteId.landingBasin: frozen
                  .sites[MiningSiteId.landingBasin]!
                  .copyWith(
                    rigPlacements: [
                      MiningRigPlacement(
                        tier: RigTier.t1,
                        cell: landingRigCell,
                      ),
                    ],
                  ),
            },
          ),
        );
        await pumpShell(tester, repository: repository, clock: clock);
        await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
        await tester.pump();
        await pumpMiningTick(tester, clock);

        await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
        await tester.pump();
        final travel = find.byKey(
          const Key('mining-stellar-map-travel-lunarFrontier'),
        );
        await tester.ensureVisible(travel);
        await tester.tap(travel);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const Key('mining-nav-siteDeck')));
        await tester.pump();
        await openFrozenBasin(tester);

        final opened = impactSequence(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(impactSequence(tester), opened);
        await pumpMiningTick(tester, clock);
        expect(impactSequence(tester) - opened, 1);
      },
    );
  });

  testWidgets('tapping an empty dock bay rejects with guidance', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(MiningSave.initial(nowUtc: _start));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    // The keyed Container is clipped inside the bay's MiningHex, so tap the
    // InkWell ancestor that actually receives the gesture.
    final emptyBay = find.ancestor(
      of: find.byKey(const ValueKey<String>('b3')),
      matching: find.byType(InkWell),
    );
    await tester.tap(emptyBay);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Select an occupied rig bay.'), findsOneWidget);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/reject.wav',
    ]);
  });

  testWidgets('tapping a mismatched dock rig reselects it', (tester) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final repository = CountingMiningSaveRepository();
    await repository.save(
      initial.copyWith(
        docks: {
          ...initial.docks,
          MiningPlanetId.homeworld: {
            ...initial.docks[MiningPlanetId.homeworld]!,
            DockBayId.b2: RigTier.t2,
          },
        },
      ),
    );
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.tap(find.byKey(const ValueKey<String>('b2')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.bySemanticsLabel('Dock bay B2: Selected T2 rig.'),
      findsOneWidget,
    );
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/tap.wav',
    ]);
  });

  testWidgets('a second stale sale rejects once cargo is gone', (tester) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingState(_start, cargo: 10));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    final sell = find.byKey(const Key('mine-site-sell'));
    // tester.tap does not pump a frame, so the still-enabled button can be
    // tapped again after the first sale settles and empties the cargo.
    await tester.tap(sell);
    await tester.binding.idle();
    await tester.tap(sell);
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.cash, 140);
    expect(find.text('No cargo to sell.'), findsOneWidget);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/sale.wav',
      'audio/reject.wav',
    ]);
  });

  testWidgets('a failed sale write reports and rejects', (tester) async {
    final repository = DelayedMiningSaveRepository();
    await repository.save(deployedLandingState(_start, cargo: 10));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    repository.delayNextSave = true;
    await tester.tap(find.byKey(const Key('mine-site-sell')));
    await repository.saveStarted.future;
    repository.allowSave.completeError(StateError('save failed'));
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.cash, 100);
    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 10);
    expect(find.text('Sale failed.'), findsOneWidget);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/reject.wav',
    ]);
  });

  testWidgets('a second stale spawn reports the failure politely', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    await repository.save(
      MiningSave.initial(nowUtc: _start).copyWith(cash: 25),
    );
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);
    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    final spawn = find.byKey(const Key('fleet-dock-spawn'));
    // The first spawn drains cash to zero; the still-enabled stale button
    // then reaches the controller and returns a failure result.
    await tester.tap(spawn);
    await tester.binding.idle();
    await tester.tap(spawn);
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.cash, 0);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b3], RigTier.t1);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b4], isNull);
    expect(find.text('Not enough cash.'), findsOneWidget);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/rig.wav',
      'audio/reject.wav',
    ]);
  });

  group('next-goal strip', () {
    testWidgets('fresh save commissions Landing Basin through its Mine Site', (
      tester,
    ) async {
      await pumpShell(tester);

      expect(
        _inGoalStrip(find.textContaining('Commission Landing Basin')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('site-deck-next-goal')));
      await tester.pump();

      expect(find.byType(MineSiteScreen), findsOneWidget);
      expect(
        tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).view.siteId,
        MiningSiteId.landingBasin,
      );
    });

    testWidgets('a Surveying goal opens the Technology sheet', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(homeworldMasteredState(_start, cash: 400));
      await pumpShell(tester, repository: repository);

      expect(
        _inGoalStrip(find.textContaining('Research Surveying 1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('site-deck-next-goal')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
    });

    testWidgets('a planet goal opens the Stellar Map', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(
        homeworldMasteredState(_start, surveying: 3, cash: 3_000),
      );
      await pumpShell(tester, repository: repository);

      expect(
        _inGoalStrip(find.textContaining('Unlock Lunar Frontier')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('site-deck-next-goal')));
      await tester.pump();

      expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
      expect(find.byKey(const Key('site-deck-next-goal')), findsNothing);
    });

    testWidgets('the goal follows foreground accrual and sales', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start).copyWith(cash: 200));
      final clock = TestClock(_start);
      await pumpShell(tester, repository: repository, clock: clock);

      expect(
        _inGoalStrip(find.text('Unlock it on its site card.')),
        findsOneWidget,
      );

      // 30 s at 0.50/s is 15 gold, worth 60 cash: 200 + 60 covers 250.
      await pumpMiningTick(tester, clock, elapsed: const Duration(seconds: 30));
      expect(
        _inGoalStrip(find.text('Sell cargo to afford it.')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('site-deck-sell')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        _inGoalStrip(find.text('Ready: unlock it on its site card.')),
        findsOneWidget,
      );
      expect(shellHandles(tester).controller.state.cash, greaterThan(250));
    });
  });

  group('storage-full alerts', () {
    /// Commissions Landing Basin with a first rig deploy through the Mine
    /// Site, the shell's only successful-commission path in a fresh save.
    Future<void> commissionLandingBasin(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.pump();
      await tapGridCell(tester, landingRigCell);
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('initialization cancels stale alerts', (tester) async {
      final platform = FakeStorageAlertPlatform();
      await pumpShell(tester, storageAlerts: StorageAlerts(platform: platform));

      expect(platform.cancelAllCount, 1);
      expect(platform.scheduleCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'first commission requests permission when alerts are enabled',
      (tester) async {
        final platform = FakeStorageAlertPlatform();
        await pumpShell(
          tester,
          storageAlerts: StorageAlerts(platform: platform),
        );

        await commissionLandingBasin(tester);

        expect(
          shellHandles(
            tester,
          ).controller.state.sites[MiningSiteId.landingBasin]!.commissioned,
          isTrue,
        );
        expect(platform.requestPermissionCount, 1);
      },
    );

    testWidgets('disabled-before-commission never requests permission', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'notifications.storageFullEnabled': false,
      });
      final platform = FakeStorageAlertPlatform();
      await pumpShell(tester, storageAlerts: StorageAlerts(platform: platform));

      await commissionLandingBasin(tester);

      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.commissioned,
        isTrue,
      );
      expect(platform.requestPermissionCount, 0);
    });

    testWidgets('pausing without a producing site cancels the pending alert', (
      tester,
    ) async {
      final platform = FakeStorageAlertPlatform();
      await pumpShell(tester, storageAlerts: StorageAlerts(platform: platform));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();

      expect(platform.scheduleCount, 0);
      // Initialization plus the no-producer projection.
      expect(platform.cancelAllCount, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets(
      'pausing with production schedules the earliest unlocked-planet fill',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(multiProducerState(_start));
        final platform = FakeStorageAlertPlatform();
        await pumpShell(
          tester,
          repository: repository,
          storageAlerts: StorageAlerts(platform: platform),
        );

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump();

        // Frozen Basin (Lunar Frontier) fills in 6600 s, before Landing
        // Basin (Homeworld) fills in 7200 s. The player is on Homeworld.
        expect(platform.scheduleCount, 1);
        expect(platform.cancelAllCount, 1);
        expect(
          platform.scheduledTitle,
          'Frozen Basin on Lunar Frontier is full',
        );
        expect(platform.scheduledBody, 'Sell its cargo to keep mining.');
        expect(
          platform.scheduledAtUtc,
          _start.add(const Duration(seconds: 6600)),
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      },
    );

    testWidgets('resuming cancels the scheduled alert', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start));
      final platform = FakeStorageAlertPlatform();
      await pumpShell(
        tester,
        repository: repository,
        storageAlerts: StorageAlerts(platform: platform),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      expect(platform.scheduleCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(platform.cancelAllCount, 2);
      expect(platform.scheduleCount, 1);
    });

    testWidgets('a checkpoint finishing after resume schedules nothing late', (
      tester,
    ) async {
      final repository = DelayedMiningSaveRepository();
      await repository.save(deployedLandingState(_start));
      final platform = FakeStorageAlertPlatform();
      await pumpShell(
        tester,
        repository: repository,
        storageAlerts: StorageAlerts(platform: platform),
      );

      repository.delayNextSave = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await repository.saveStarted.future;
      await tester.pump();

      // The app is back before the paused checkpoint's save lands.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      repository.allowSave.complete();
      await tester.pump();
      await tester.pump();

      expect(platform.scheduleCount, 0);
      expect(platform.cancelAllCount, 2);
    });

    testWidgets('one trip to the background schedules a single alert', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start));
      final platform = FakeStorageAlertPlatform();
      await pumpShell(
        tester,
        repository: repository,
        storageAlerts: StorageAlerts(platform: platform),
      );

      // Transient focus loss is not a background transition: no checkpoint,
      // no projection.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(platform.scheduleCount, 0);
      expect(repository.saveCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();

      expect(platform.scheduleCount, 1);
      expect(platform.scheduledTitle, 'Landing Basin on Homeworld is full');
      expect(
        platform.scheduledAtUtc,
        _start.add(const Duration(seconds: 7200)),
      );
      expect(platform.cancelAllCount, 1);
      expect(repository.saveCount, 2);

      // Android reports paused then hidden on the same trip: the second
      // backgrounded event must not checkpoint and schedule again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      await tester.pump();
      expect(platform.scheduleCount, 1);
      expect(repository.saveCount, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets('an in-flight sale projects the alert from post-sale cargo', (
      tester,
    ) async {
      final repository = DelayedMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      final platform = FakeStorageAlertPlatform();
      await pumpShell(
        tester,
        repository: repository,
        storageAlerts: StorageAlerts(platform: platform),
      );

      repository.delayNextSave = true;
      await tester.tap(find.byKey(const Key('site-deck-sell')));
      await repository.saveStarted.future;
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      repository.allowSave.complete();
      await tester.pump();
      await tester.pump();

      // Pre-sale cargo 10 projects full in 7180 s; the post-sale empty
      // storage anchors the full 7200 s window.
      expect(platform.scheduleCount, 1);
      expect(
        platform.scheduledAtUtc,
        _start.add(const Duration(seconds: 7200)),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets('disposing the shell arms the alert from the latest state', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start));
      final platform = FakeStorageAlertPlatform();
      await pumpShell(
        tester,
        repository: repository,
        storageAlerts: StorageAlerts(platform: platform),
      );

      // Leaving the mining surface is a background-equivalent handoff:
      // the player may quit the app from the main menu, so dispose arms
      // the pending alert instead of abandoning it.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();

      expect(platform.scheduleCount, 1);
      expect(
        platform.scheduledAtUtc,
        _start.add(const Duration(seconds: 7200)),
      );
    });

    testWidgets(
      'disposing the shell with nothing to fill clears the pending alert',
      (tester) async {
        final platform = FakeStorageAlertPlatform();
        await pumpShell(
          tester,
          storageAlerts: StorageAlerts(platform: platform),
        );
        expect(platform.cancelAllCount, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump();

        // Initialization cancels; the no-producer dispose projection cancels.
        expect(platform.cancelAllCount, 2);
        expect(platform.scheduleCount, 0);
      },
    );

    testWidgets('finishing initialization in the background arms the alert', (
      tester,
    ) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start));
      final audio = DelayedAudioPrefsManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: FakeBackgroundMusicPlayer(),
      );
      addTearDown(audio.dispose);
      final platform = FakeStorageAlertPlatform();
      await pumpShell(
        tester,
        repository: repository,
        clock: clock,
        audioManager: audio,
        storageAlerts: StorageAlerts(platform: platform),
        pumpCycles: 1,
      );
      await audio.loadStarted.future;

      // The pause lands before the shell is initialized, so the paused
      // path ignores it and never checkpoints or schedules. Finishing
      // the load while still backgrounded must take that path itself —
      // no backgrounded lifecycle event can arrive to trigger it.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      audio.allowLoad.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(repository.saveCount, 2);
      expect(platform.cancelAllCount, 1);
      expect(platform.scheduleCount, 1);
      expect(
        platform.scheduledAtUtc,
        _start.add(const Duration(seconds: 7200)),
      );

      // Resume behaves like any return from the background: the armed
      // alert is cancelled and the foreground timer starts.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(platform.cancelAllCount, 2);
      expect(platform.scheduleCount, 1);
    });

    testWidgets(
      'a disposed shell cannot rearm the alert after a shell reentry',
      (tester) async {
        final repository = DelayedMiningSaveRepository();
        await repository.save(deployedLandingState(_start));
        final firstPlatform = FakeStorageAlertPlatform();
        await pumpShell(
          tester,
          repository: repository,
          clock: TestClock(_start),
          storageAlerts: StorageAlerts(platform: firstPlatform),
        );
        expect(firstPlatform.cancelAllCount, 1);

        // Leaving mining stalls inside the dispose checkpoint's save...
        repository.delayNextSave = true;
        await tester.pumpWidget(const SizedBox.shrink());
        await repository.saveStarted.future;

        // ...while a reopened shell takes ownership and clears the pending
        // alert from its own, unserialized StorageAlerts queue.
        final secondPlatform = FakeStorageAlertPlatform();
        await pumpShell(
          tester,
          repository: repository,
          clock: TestClock(_start),
          storageAlerts: StorageAlerts(platform: secondPlatform),
        );

        repository.allowSave.complete();
        await tester.pump();
        await tester.pump();

        // The stale projection drops instead of rearming the shared
        // notification id after the new shell's cancellation.
        expect(firstPlatform.scheduleCount, 0);
        expect(firstPlatform.cancelAllCount, 1);
        expect(secondPlatform.cancelAllCount, 1);
      },
    );
  });
}
