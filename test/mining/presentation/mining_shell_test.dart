import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_background_music_player.dart';
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

/// Surveying-0 legal deploy cell for Carbon Ridge, used to prove dock
/// selection does not leak across sites.
final _carbonRidgeCell = deployableMiningCells(
  MiningContentRegistry.stellarMining().site(MiningSiteId.carbonRidge),
).first;

Future<void> pumpShell(
  WidgetTester tester, {
  MiningSaveRepository? repository,
  TestClock? clock,
  AudioManager? audioManager,
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
          home: MiningShell(nowUtc: () => _start, audioManager: audio),
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
          cash: 3_000,
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
          cash: 5_000,
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
        cash: 5_000,
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
    await repository.save(deployedLandingState(clock.now, cargo: 89.5));
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
      90,
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
    await repository.save(deployedLandingState(clock.now, cargo: 90));
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

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
      expect(find.textContaining('Gold'), findsWidgets);
    },
  );

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
    await warmGoldFrames(tester);
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
}
