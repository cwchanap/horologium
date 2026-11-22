import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/game/storage_alerts.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_controller.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_shell.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_background_music_player.dart';
import '../../support/fake_storage_alert_platform.dart';
import '../../support/mining_grid_fixtures.dart';
import '../../support/mining_visual_frames.dart';
import 'mining_shell_harness.dart';

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

final _start = miningShellTestStart;

/// A legal Surveying-0 Landing Basin deploy cell.
final landingRigCell = firstPlayableCell(
  MiningContentRegistry.stellarMining().site(MiningSiteId.landingBasin),
);

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

Finder _inGoalStrip(Finder matching) => find.descendant(
  of: find.byKey(const Key('site-deck-next-goal')),
  matching: matching,
);

/// A free Surveying-0 perimeter cell of Landing Basin, distinct from
/// [landingRigCell], used to deploy a freshly spawned rig without re-tapping
/// the dock.
final _freeLandingDeployCell = deployableMiningCells(
  MiningContentRegistry.stellarMining().site(MiningSiteId.landingBasin),
).firstWhere((cell) => cell != landingRigCell);

/// A legal Surveying-3 Frozen Basin deploy cell.
final frozenRigCell = firstPlayableCell(
  MiningContentRegistry.stellarMining().site(MiningSiteId.frozenBasin),
);

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

final _graniteCraterDeployCell = graniteCraterDeployCell;
final _osmiumDeployCell = osmiumDeployCell;

/// The authored right-edge bottom pocket: tapping this cell after scrolling
/// also proves the rightmost tap column stays reachable beside the rail.
const _workflowPocketCell = MiningGridCell(7, 21);

/// A shared-adjacency gap between pockets (0,20) and (2,20).
const _workflowAmbiguousCell = MiningGridCell(1, 20);

/// A unique perimeter cell of the left Surveying-1 lode at (0,9).
const _workflowLodeCell = MiningGridCell(3, 10);

/// Fresh Landing Basin with the minimum cash the ordered workflow needs:
/// one spawned T1 plus the 300-cash Surveying 1 research. A pristine save
/// starts at 100 cash, so the requested order would otherwise need a sale
/// before research.
MiningSave workflowStartState(DateTime now) =>
    MiningSave.initial(nowUtc: now).copyWith(cash: 400);

MiningSave deployedCarbonRidgeState(DateTime now) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    sites: {
      ...base.sites,
      MiningSiteId.carbonRidge: base.sites[MiningSiteId.carbonRidge]!.copyWith(
        unlocked: true,
        commissioned: true,
        rigPlacements: [
          MiningRigPlacement(tier: RigTier.t1, cell: _carbonRidgeCell),
        ],
      ),
    },
  );
}

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

Future<void> pumpMiningTick(
  WidgetTester tester,
  TestClock clock, {
  Duration elapsed = const Duration(seconds: 1),
}) async {
  clock.now = clock.now.add(elapsed);
  await tester.pump(const Duration(seconds: 1));
}

/// The key of the shell's non-blocking result feedback panel, attached to
/// the styled panel Container.
const Key miningResultPanelKey = Key('mining-result-panel');

Finder get _resultPanel => find.byKey(miningResultPanelKey);

const List<Size> _feedbackViewports = [
  Size(360, 640),
  Size(390, 844),
  Size(874, 402),
];

/// Asserts the visible result panel carries the authored dark style:
/// MiningTheme.panel background with a 12px accent border, an Orbitron 13px
/// primary-text message, and live-region semantics. Tests calling this must
/// have enabled semantics via [WidgetTester.ensureSemantics].
void expectThemedResultPanel(WidgetTester tester, Finder message) {
  expect(_resultPanel, findsOneWidget);
  expect(find.descendant(of: _resultPanel, matching: message), findsOneWidget);
  final decoration =
      tester.widget<Container>(_resultPanel).decoration! as BoxDecoration;
  expect(decoration.color, MiningTheme.panel);
  expect(decoration.borderRadius, BorderRadius.circular(12));
  expect((decoration.border! as Border).top.color, MiningTheme.accent);
  final text = tester.widget<Text>(
    find.descendant(of: _resultPanel, matching: message),
  );
  expect(text.style?.fontFamily, 'Orbitron');
  expect(text.style?.fontSize, 13);
  expect(text.style?.fontWeight, FontWeight.w600);
  expect(text.style?.color, MiningTheme.primaryText);
  expect(
    tester
        .getSemantics(message)
        .getSemanticsData()
        .flagsCollection
        .isLiveRegion,
    isTrue,
  );
}

/// Asserts the result panel renders fully opaque: any ancestor [Opacity] or
/// [FadeTransition] that could fade it must sit at 1.0, so an entrance fade
/// fails on the frame this helper is called in — geometry alone cannot
/// detect a fade.
void expectPanelFullyVisible(WidgetTester tester) {
  for (final element
      in find
          .ancestor(of: _resultPanel, matching: find.byType(Opacity))
          .evaluate()) {
    expect(
      element.widget as Opacity,
      isA<Opacity>().having((o) => o.opacity, 'opacity', 1.0),
      reason: 'result panel is faded by an ancestor Opacity',
    );
  }
  for (final element
      in find
          .ancestor(of: _resultPanel, matching: find.byType(FadeTransition))
          .evaluate()) {
    final opacity = element.widget as FadeTransition;
    expect(
      opacity.opacity.value,
      1.0,
      reason: 'result panel is mid-fade in an ancestor FadeTransition',
    );
  }
}

/// Asserts the visible result panel's rect does not intersect [chrome].
void expectPanelClearOf(WidgetTester tester, Finder chrome) {
  expect(chrome, findsOneWidget, reason: 'chrome $chrome must be present');
  final panel = tester.getRect(_resultPanel);
  final blocked = tester.getRect(chrome);
  final intersects =
      panel.left < blocked.right &&
      panel.right > blocked.left &&
      panel.top < blocked.bottom &&
      panel.bottom > blocked.top;
  expect(
    intersects,
    isFalse,
    reason: 'result panel $panel overlaps $chrome at $blocked',
  );
}

/// Taps the upper or lower quarter of a nav button so both portions of the
/// interactive hit region are exercised during visible feedback.
Future<void> tapNavPortion(
  WidgetTester tester,
  Finder navButton, {
  required bool upper,
}) async {
  final rect = tester.getRect(navButton);
  await tester.tapAt(
    Offset(rect.center.dx, rect.top + rect.height * (upper ? .25 : .75)),
  );
}

/// Asserts the surface or sheet for [destination] is showing.
void expectDestinationReached(
  WidgetTester tester,
  MiningNavigationDestination destination,
) {
  switch (destination) {
    case MiningNavigationDestination.siteDeck:
      expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
      expect(find.byKey(const Key('mine-site-screen')), findsNothing);
    case MiningNavigationDestination.technology:
      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
    case MiningNavigationDestination.stellarMap:
      expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
    case MiningNavigationDestination.settings:
      expect(find.byKey(const Key('mining-settings-sheet')), findsOneWidget);
  }
}

/// Enters Landing Basin and sells its cargo so a success message is visible
/// while the navigation is exercised. Pass `settle: Duration.zero` to keep
/// the caller on the panel's first rendered frame without advancing fake
/// time, so the four-second clock starts at show time.
Future<void> showSaleFeedback(
  WidgetTester tester, {
  Duration settle = const Duration(milliseconds: 300),
}) async {
  final enter = find.byKey(const Key('site-card-landingBasin-enter'));
  await tester.ensureVisible(enter);
  await tester.pump();
  await tester.tap(enter);
  await tester.pump();
  await tester.tap(find.byKey(const Key('mine-site-sell')));
  await tester.pump(settle);
  expect(find.textContaining('Sold'), findsOneWidget);
}

/// Enters Landing Basin and taps an empty dock bay so the rejection message
/// is visible while the navigation is exercised. Pass
/// `settle: Duration.zero` to keep the caller on the panel's first rendered
/// frame without advancing fake time, so the four-second clock starts at
/// show time.
Future<void> showRejectionFeedback(
  WidgetTester tester, {
  Duration settle = const Duration(milliseconds: 300),
}) async {
  final enter = find.byKey(const Key('site-card-landingBasin-enter'));
  await tester.ensureVisible(enter);
  await tester.pump();
  await tester.tap(enter);
  await tester.pump();
  // The keyed Container is clipped inside the bay's MiningHex, so tap the
  // InkWell ancestor that actually receives the gesture.
  final emptyBay = find.ancestor(
    of: find.byKey(const ValueKey<String>('b3')),
    matching: find.byType(InkWell),
  );
  await tester.tap(emptyBay);
  await tester.pump(settle);
  expect(find.text('Select an occupied rig bay.'), findsOneWidget);
}

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

  testWidgets('the sheet cargo gauge values only the active planet', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    final base = deployedLandingState(_start, cargo: 100);
    final repository = CountingMiningSaveRepository();
    await repository.save(
      base.copyWith(
        technology: const TechnologyLevels(surveying: 3),
        unlockedPlanetIds: {
          MiningPlanetId.homeworld,
          MiningPlanetId.lunarFrontier,
        },
        sites: {
          ...base.sites,
          MiningSiteId.frozenBasin: base.sites[MiningSiteId.frozenBasin]!
              .copyWith(
                unlocked: true,
                commissioned: true,
                storedAmount: 600,
                rigPlacements: [
                  MiningRigPlacement(tier: RigTier.t1, cell: frozenRigCell),
                ],
              ),
        },
      ),
    );
    await pumpShell(tester, repository: repository);

    shellHandles(tester).openTechnology();
    await tester.pump();

    // The Lunar cargo must survive loading for the active-planet
    // assertions to detect a gauge that sums across planets: an
    // uncommissioned or rigless site would clamp to zero on decode.
    expect(
      shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.frozenBasin]!.storedAmount,
      600,
    );

    final gauge = tester.widget<MiningCargoGauge>(
      find.descendant(
        of: find.byType(MiningSheetScene),
        matching: find.byKey(const Key('mining-cargo-gauge')),
      ),
    );
    expect(gauge.cargo, 100);
    expect(
      gauge.projectedValue,
      base.saleValue(content, MiningPlanetId.homeworld),
    );
    expect(tester.takeException(), isNull);
  });

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
      // The panel carries the busy message; the stellar-map planet cards
      // legitimately render their own busy labels once the shell rebuild
      // refreshes them with the queued save's busy state.
      expect(
        find.descendant(
          of: _resultPanel,
          matching: find.text('Finishing previous action…'),
        ),
        findsOneWidget,
      );
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
    expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
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

  testWidgets('a reusable full shell workflow covers the progressive map', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(workflowStartState(_start));
    await pumpShell(
      tester,
      repository: repository,
      clock: clock,
      viewport: const Size(390, 844),
    );

    final handles = shellHandles(tester);
    var state = handles.controller.state;
    final content = MiningContentRegistry.stellarMining();
    final landing = state.sites[MiningSiteId.landingBasin]!;
    expect(landing.unlocked, isTrue);
    expect(landing.commissioned, isFalse);
    expect(landing.rigPlacements, isEmpty);

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();

    // A fresh Landing Basin shows pockets and seams open, lodes locked, and
    // the rail's semantic target carries the same lock state.
    expect(find.text('Surveying 1 opens the lodes'), findsOneWidget);
    expect(find.byKey(const Key('mining-band-lock-lodes')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Jump to Lodes band. Requires Surveying 1.'),
      findsOneWidget,
    );

    // Spawn a T1 (the fresh save's b1/b2 stay untouched), then deploy it on
    // the right-edge bottom pocket after a physical scroll.
    var saves = repository.saveCount;
    await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
    await tester.pump(const Duration(milliseconds: 300));
    state = handles.controller.state;
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b3], RigTier.t1);
    expect(state.cash, 375);
    expect(repository.saveCount, saves + 1);

    saves = repository.saveCount;
    await tapGridCell(tester, _workflowPocketCell);
    await tester.pump(const Duration(milliseconds: 300));
    state = handles.controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, [
      const MiningRigPlacement(tier: RigTier.t1, cell: _workflowPocketCell),
    ]);
    expect(state.sites[MiningSiteId.landingBasin]!.commissioned, isTrue);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b3], isNull);
    expect(repository.saveCount, saves + 1);
    expect(
      find.bySemanticsLabel(
        RegExp(r'T1 rig at \(7,21\) mining deposit \(7,20\)'),
      ),
      findsOneWidget,
    );

    // Select a dock T1, then reject the shared-adjacency gap as ordinary
    // feedback: no exception, no lost rig, cash, or save.
    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.pump();
    expect(
      find.bySemanticsLabel('Dock bay B1: Selected T1 rig.'),
      findsOneWidget,
    );
    saves = repository.saveCount;
    await tapGridCell(tester, _workflowAmbiguousCell);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Place the rig next to a single resource.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    state = handles.controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, hasLength(1));
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b1], RigTier.t1);
    expect(state.cash, 375);
    expect(repository.saveCount, saves);

    // The locked lode is a normal rejection while the same rig stays selected.
    await tapGridCell(tester, _workflowLodeCell);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Requires Surveying 1.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state = handles.controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, hasLength(1));
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b1], RigTier.t1);
    expect(repository.saveCount, saves);

    // Research Surveying 1 through the real Technology sheet.
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('mining-grid-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    double scrollPixels() =>
        tester.state<ScrollableState>(scrollable).position.pixels;
    final beforeResearch = scrollPixels();
    await tester.tap(find.byKey(const Key('mining-nav-technology')));
    await pumpSheet(tester);
    expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('technology-track-surveying')));
    await tester.pump();
    saves = repository.saveCount;
    await tester.tap(find.byKey(const Key('mining-technology-buy-surveying')));
    await tester.pump(const Duration(milliseconds: 400));
    state = handles.controller.state;
    expect(state.technology.surveying, 1);
    expect(state.cash, 75);
    expect(repository.saveCount, saves + 1);

    await tester.tap(find.bySemanticsLabel('Close Technology'));
    await pumpSheet(tester);
    expect(find.byKey(const Key('mining-technology-sheet')), findsNothing);

    // The purchase updates the rail and lock copy in place without reframing.
    expect(scrollPixels(), beforeResearch);
    expect(find.byKey(const Key('mining-band-lock-lodes')), findsNothing);
    expect(
      find.byKey(const Key('mining-band-lock-motherlode')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Jump to Lodes band'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Jump to Motherlode band. Requires Surveying 2.'),
      findsOneWidget,
    );

    // Rail navigation moves to the newly opened band.
    final surface = tester.getRect(
      find.byKey(const Key('mining-grid-surface')),
    );
    final cargoBottom = tester
        .getRect(find.byKey(const Key('mine-site-cargo')))
        .bottom;
    await tester.tap(find.byKey(const Key('mining-depth-rail-lodes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scrollPixels(), isNot(beforeResearch));
    expect(
      scrollPixels(),
      closeTo(
        cargoBottom +
            MiningBand.lodes.labelRow *
                miningGridCellSize *
                surface.width /
                miningGridSceneWidth,
        0.5,
      ),
    );

    // The still-selected dock rig deploys on the now-open lode.
    saves = repository.saveCount;
    await tapGridCell(tester, _workflowLodeCell);
    await tester.pump(const Duration(milliseconds: 300));
    state = handles.controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, hasLength(2));
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b1], isNull);
    expect(state.cash, 75);
    expect(repository.saveCount, saves + 1);

    // Accrue both producers, sell once, and verify the persisted result.
    clock.now = clock.now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    state = handles.controller.state;
    expect(
      state.storedCargo(content, MiningPlanetId.homeworld),
      greaterThan(0),
    );
    final cashBeforeSale = state.cash;
    saves = repository.saveCount;
    await tester.tap(find.byKey(const Key('mine-site-sell')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Sold '), findsOneWidget);
    state = handles.controller.state;
    expect(state.storedCargo(content, MiningPlanetId.homeworld), 0);
    expect(state.cash, greaterThan(cashBeforeSale));
    expect(repository.saveCount, saves + 1);

    // Reload through a second repository and shell: controller-owned
    // persistence restores the researched level, both rigs, and the sale.
    final sold = state;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final reloadedRepository = CountingMiningSaveRepository();
    await pumpShell(
      tester,
      repository: reloadedRepository,
      clock: clock,
      viewport: const Size(390, 844),
    );
    final reloaded = shellHandles(tester).controller.state;
    expect(
      reloaded.sites[MiningSiteId.landingBasin]!.rigPlacements,
      sold.sites[MiningSiteId.landingBasin]!.rigPlacements,
    );
    expect(reloaded.technology.surveying, 1);
    expect(reloaded.cash, sold.cash);
    expect(reloaded.storedCargo(content, MiningPlanetId.homeworld), 0);
    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Mine Site upgrades a placed rig with a matching dock rig', (
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
    await tester.tap(find.byKey(const ValueKey<String>('b2')));
    await tester.pump();
    await tapGridCell(tester, landingRigCell);
    await tester.pump(const Duration(milliseconds: 300));

    var state = shellHandles(tester).controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, [
      MiningRigPlacement(tier: RigTier.t2, cell: landingRigCell),
    ]);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b2], isNull);
    expect(find.text('Rig upgraded.'), findsOneWidget);

    await tapGridCell(tester, _freeLandingDeployCell);
    await tester.pump(const Duration(milliseconds: 300));
    state = shellHandles(tester).controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, hasLength(1));
    expect(find.text('Select a rig from the dock.'), findsOneWidget);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/merge.wav',
      'audio/reject.wav',
    ]);
  });

  testWidgets('a mismatched dock rig cannot upgrade a placed rig', (
    tester,
  ) async {
    final base = deployedLandingState(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(
      base.copyWith(
        docks: {
          ...base.docks,
          MiningPlanetId.homeworld: {
            ...base.docks[MiningPlanetId.homeworld]!,
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
    await tester.tap(find.byKey(const ValueKey<String>('b2')));
    await tester.pump();
    await tapGridCell(tester, landingRigCell);
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, [
      MiningRigPlacement(tier: RigTier.t1, cell: landingRigCell),
    ]);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b2], RigTier.t2);
    expect(find.text('Rigs must be the same tier.'), findsOneWidget);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/reject.wav',
    ]);
  });

  testWidgets('BUILD buys the displayed tier through the existing spawn path', (
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

    final pill = find.byKey(const Key('fleet-dock-build'));
    expect(pill, findsOneWidget);
    expect(find.text('BUILD T3 · 100'), findsOneWidget);
    await tester.tap(pill);
    await tester.pump(const Duration(milliseconds: 300));

    var state = shellHandles(tester).controller.state;
    expect(state.cash, 0);
    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b3], RigTier.t3);
    expect(find.text('T3 rig spawned.'), findsOneWidget);

    await tapGridCell(tester, _freeLandingDeployCell);
    await tester.pump(const Duration(milliseconds: 300));
    state = shellHandles(tester).controller.state;
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, [
      MiningRigPlacement(tier: RigTier.t3, cell: _freeLandingDeployCell),
    ]);
    expect(effects.playedAssets, [
      'audio/tap.wav',
      'audio/tap.wav',
      'audio/rig.wav',
      'audio/milestone.wav',
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

  testWidgets('Site Deck sells cargo across every unlocked planet', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    final seeded = multiProducerState(_start);
    await repository.save(
      seeded.copyWith(
        sites: {
          ...seeded.sites,
          MiningSiteId.landingBasin: seeded.sites[MiningSiteId.landingBasin]!
              .copyWith(storedAmount: 10),
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

    final sell = find.byKey(const Key('site-deck-sell'));
    expect(sell, findsOneWidget);
    expect(tester.widget<OutlinedButton>(sell).onPressed, isNotNull);
    expect(
      find.bySemanticsLabel('Sell all cargo for 3,640 cash.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge')))
          .projectedValue,
      40,
    );

    await tester.tap(sell);
    await tester.pump(const Duration(milliseconds: 300));

    final state = shellHandles(tester).controller.state;
    expect(state.cash, 3640);
    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 0);
    expect(state.sites[MiningSiteId.frozenBasin]!.storedAmount, 0);
    expect(find.text('Sold 3,640 cash.'), findsOneWidget);
    expect(
      effects.playedAssets.where((path) => path == 'audio/sale.wav'),
      hasLength(1),
    );
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

  testWidgets(
    'reduced motion shows Mine Site sale feedback settled instantly',
    (tester) async {
      final handle = tester.ensureSemantics();
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      await pumpShell(
        tester,
        repository: repository,
        disableAnimations: true,
        useViewSafeArea: true,
      );

      await showSaleFeedback(tester, settle: Duration.zero);

      // First rendered frame: reduced motion shows the settled, fully
      // opaque panel immediately — no fade, slide, or delayed entrance.
      expectThemedResultPanel(tester, find.textContaining('Sold'));
      expectPanelFullyVisible(tester);
      final settled = tester.getRect(_resultPanel);

      // Short intervals after the first frame: geometry and visibility never
      // change, so no fade in either direction can be running.
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(_resultPanel), settled);
      expectPanelFullyVisible(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(_resultPanel), settled);
      expectPanelFullyVisible(tester);
      handle.dispose();
    },
  );

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('success feedback is a themed result panel at $label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      await pumpShell(
        tester,
        repository: repository,
        viewport: size,
        useViewSafeArea: true,
      );

      await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mine-site-sell')));
      await tester.pump(const Duration(milliseconds: 300));

      expectThemedResultPanel(tester, find.textContaining('Sold'));
      handle.dispose();
    });

    testWidgets('rejection guidance is a themed result panel at $label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: size,
        useViewSafeArea: true,
      );

      await showRejectionFeedback(tester);

      expectThemedResultPanel(tester, find.text('Select an occupied rig bay.'));
      handle.dispose();
    });

    testWidgets('recovery notice is a themed result panel at $label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: '{ malformed mining json',
      });
      final repository = CountingMiningSaveRepository();

      await pumpShell(
        tester,
        repository: repository,
        viewport: size,
        useViewSafeArea: true,
        pumpCycles: 12,
      );

      expectThemedResultPanel(
        tester,
        find.text(
          'Mining progress could not be loaded, so a fresh mining save was '
          'started.',
        ),
      );
      handle.dispose();
    });
  }

  group('non-blocking result feedback', () {
    testWidgets(
      'the first tap opens the Stellar Map while spawn feedback is visible '
      'at 390x844',
      (tester) async {
        // HPA-1086: the old floating SnackBar covered part of the bottom
        // nav, so tapping the lower half of the Stellar Map destination
        // while feedback was visible swallowed the tap. The panel must pass
        // every tap through to the nav.
        final repository = CountingMiningSaveRepository();
        await repository.save(MiningSave.initial(nowUtc: _start));
        await pumpShell(
          tester,
          repository: repository,
          viewport: const Size(390, 844),
          useViewSafeArea: true,
        );

        await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
        // Let the spawn feedback appear before exercising the nav.
        await tester.pumpAndSettle();

        expect(find.text('T1 rig spawned.'), findsOneWidget);
        await tapNavPortion(
          tester,
          find.byKey(const Key('mining-nav-stellarMap')),
          upper: false,
        );
        await tester.pump();

        expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
        expect(find.byKey(const Key('site-deck-scroll')), findsNothing);
      },
    );

    testWidgets('Mine Site Back receives its first tap under feedback', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      await showRejectionFeedback(tester);
      expect(_resultPanel, findsOneWidget);

      // Linear Mockup 1: the message visually overlaps Back, so pass-through
      // is proven by tapping inside the panel/Back intersection itself.
      final panel = tester.getRect(_resultPanel);
      final back = tester.getRect(find.byKey(const Key('mine-site-back')));
      expect(
        panel.overlaps(back),
        isTrue,
        reason:
            'result panel $panel must visually overlap '
            'mine-site-back $back for this pass-through test',
      );
      await tester.tapAt(panel.intersect(back).center);
      await tester.pump();

      expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
      expect(find.byKey(const Key('mine-site-screen')), findsNothing);
    });

    for (final size in _feedbackViewports) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      for (final destination in MiningNavigationDestination.values) {
        testWidgets(
          'feedback keeps ${destination.name} first taps working at $label',
          (tester) async {
            final repository = CountingMiningSaveRepository();
            await repository.save(deployedLandingState(_start, cargo: 10));
            await pumpShell(
              tester,
              repository: repository,
              viewport: size,
              useViewSafeArea: true,
            );

            await showSaleFeedback(tester);
            expect(_resultPanel, findsOneWidget);

            final navButton = find.byKey(Key('mining-nav-${destination.name}'));
            await tapNavPortion(tester, navButton, upper: true);
            await pumpSheet(tester);
            expectDestinationReached(tester, destination);

            if (destination == MiningNavigationDestination.technology ||
                destination == MiningNavigationDestination.settings) {
              await tester.tap(
                find.bySemanticsLabel(
                  destination == MiningNavigationDestination.technology
                      ? 'Close Technology'
                      : 'Close Settings',
                ),
              );
              await pumpSheet(tester);

              // Reopening the closed sheet through the nav's lower quarter
              // proves the tap reached the destination. Primary surfaces
              // cover their lower halves in the fresh-shell cases below.
              await tapNavPortion(tester, navButton, upper: false);
              await pumpSheet(tester);
              expectDestinationReached(tester, destination);
            }
          },
        );
      }
    }

    // A lower-quarter re-tap on an already-shown primary surface cannot
    // prove pass-through, so each fresh shell starts on Mine Site with the
    // sale panel up and taps only the lower half of the nav destination.
    for (final size in const [Size(360, 640), Size(874, 402)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      for (final destination in const [
        MiningNavigationDestination.siteDeck,
        MiningNavigationDestination.stellarMap,
      ]) {
        testWidgets(
          'feedback keeps the ${destination.name} lower-half first tap '
          'working at $label',
          (tester) async {
            final repository = CountingMiningSaveRepository();
            await repository.save(deployedLandingState(_start, cargo: 10));
            await pumpShell(
              tester,
              repository: repository,
              viewport: size,
              useViewSafeArea: true,
            );

            await showSaleFeedback(tester);
            expect(_resultPanel, findsOneWidget);

            await tapNavPortion(
              tester,
              find.byKey(Key('mining-nav-${destination.name}')),
              upper: false,
            );
            await pumpSheet(tester);

            expectDestinationReached(tester, destination);
            expect(find.byKey(const Key('mine-site-screen')), findsNothing);
          },
        );
      }
    }

    testWidgets('feedback clears portrait Site Deck chrome', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      await tester.tap(find.byKey(const Key('site-deck-sell')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_resultPanel, findsOneWidget);

      for (final key in const [
        'mining-cash-chip',
        'mining-cargo-gauge',
        'site-deck-sell',
        'site-deck-next-goal',
        'mining-bottom-navigation',
      ]) {
        expectPanelClearOf(tester, find.byKey(Key(key)));
      }
    });

    testWidgets('feedback clears portrait Site Deck chrome at 360x640', (
      tester,
    ) async {
      // The narrowest specified portrait viewport: the panel is widest
      // relative to the screen and wraps tallest, while Site Deck Sell ends
      // only 4px above the panel's +160 top.
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(360, 640),
        useViewSafeArea: true,
      );

      await tester.tap(find.byKey(const Key('site-deck-sell')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_resultPanel, findsOneWidget);

      for (final key in const [
        'mining-cash-chip',
        'mining-cargo-gauge',
        'site-deck-sell',
        'site-deck-next-goal',
        'mining-bottom-navigation',
      ]) {
        expectPanelClearOf(tester, find.byKey(Key(key)));
      }
    });

    testWidgets('feedback clears portrait Mine Site chrome', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      await showRejectionFeedback(tester);
      expect(_resultPanel, findsOneWidget);

      for (final key in const [
        'mining-cash-chip',
        'mine-site-cargo',
        'fleet-dock',
        'mine-site-sell',
        'mining-bottom-navigation',
      ]) {
        expectPanelClearOf(tester, find.byKey(Key(key)));
      }
    });

    testWidgets('feedback clears Stellar Map chrome', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      await showRejectionFeedback(tester);
      await tapNavPortion(
        tester,
        find.byKey(const Key('mining-nav-stellarMap')),
        upper: true,
      );
      await tester.pump();
      expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
      expect(_resultPanel, findsOneWidget);

      for (final key in const [
        'mining-cash-chip',
        'mining-cargo-gauge',
        'mining-bottom-navigation',
      ]) {
        expectPanelClearOf(tester, find.byKey(Key(key)));
      }
    });

    testWidgets(
      'feedback clears landscape Site Deck chrome with safe-area insets',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(deployedLandingState(_start, cargo: 10));
        await pumpShell(
          tester,
          repository: repository,
          viewport: const Size(874, 402),
          safeArea: const EdgeInsets.only(left: 44, right: 44),
          useViewSafeArea: true,
        );

        await tester.tap(find.byKey(const Key('site-deck-sell')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_resultPanel, findsOneWidget);

        for (final key in const [
          'mining-cash-chip',
          'mining-cargo-gauge',
          'site-deck-sell',
          'site-deck-next-goal',
          'mining-bottom-navigation',
        ]) {
          expectPanelClearOf(tester, find.byKey(Key(key)));
        }
      },
    );

    testWidgets(
      'feedback clears landscape Mine Site chrome with safe-area insets',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(deployedLandingState(_start, cargo: 10));
        await pumpShell(
          tester,
          repository: repository,
          viewport: const Size(874, 402),
          safeArea: const EdgeInsets.only(left: 44, right: 44),
          useViewSafeArea: true,
        );

        await showSaleFeedback(tester);
        expect(_resultPanel, findsOneWidget);

        for (final key in const [
          'mining-cash-chip',
          'mine-site-cargo',
          'mine-site-right-rail',
          'mine-site-sell',
          'mining-bottom-navigation',
        ]) {
          expectPanelClearOf(tester, find.byKey(Key(key)));
        }
      },
    );

    testWidgets('feedback expires after four seconds', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      await showRejectionFeedback(tester, settle: Duration.zero);
      expect(_resultPanel, findsOneWidget);

      // Still visible immediately before the four-second deadline...
      await tester.pump(const Duration(seconds: 3, milliseconds: 999));
      expect(_resultPanel, findsOneWidget);
      expect(find.text('Select an occupied rig bay.'), findsOneWidget);

      // ... and gone once four seconds have elapsed.
      await tester.pump(const Duration(milliseconds: 10));
      expect(_resultPanel, findsNothing);
      expect(find.text('Select an occupied rig bay.'), findsNothing);
    });

    testWidgets('a new message replaces the visible one without queueing', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      // The rejection shows, then ages half of its own four-second window.
      await showRejectionFeedback(tester, settle: Duration.zero);
      await tester.pump(const Duration(seconds: 2));

      // Selling replaces it immediately: the very next frame shows the new
      // message, with no queue or restart delay.
      await tester.tap(find.byKey(const Key('mine-site-sell')));
      await tester.pump();
      expect(_resultPanel, findsOneWidget);
      expect(find.text('Select an occupied rig bay.'), findsNothing);
      expect(find.textContaining('Sold'), findsOneWidget);

      // The replacement survives past the original deadline (two seconds
      // shown plus two remaining) because its own clock restarted...
      await tester.pump(const Duration(seconds: 2, milliseconds: 100));
      expect(_resultPanel, findsOneWidget);
      expect(find.textContaining('Sold'), findsOneWidget);

      // ... stays up immediately before its own four-second deadline...
      await tester.pump(const Duration(seconds: 1, milliseconds: 899));
      expect(_resultPanel, findsOneWidget);

      // ... and expires at its own deadline.
      await tester.pump(const Duration(milliseconds: 10));
      expect(_resultPanel, findsNothing);
      expect(find.textContaining('Sold'), findsNothing);
    });

    testWidgets('the live region follows message changes', (tester) async {
      final handle = tester.ensureSemantics();
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      const rejection = 'Select an occupied rig bay.';
      await showRejectionFeedback(tester, settle: Duration.zero);
      expect(
        tester.getSemantics(find.text(rejection)).getSemanticsData(),
        isA<SemanticsData>()
            .having((d) => d.label, 'label', rejection)
            .having(
              (d) => d.flagsCollection.isLiveRegion,
              'liveRegion',
              isTrue,
            ),
      );

      // Re-showing the identical message replaces the same live-region node
      // rather than stacking a second announcement source.
      final emptyBay = find.ancestor(
        of: find.byKey(const ValueKey<String>('b3')),
        matching: find.byType(InkWell),
      );
      await tester.tap(emptyBay);
      await tester.pump();
      expect(find.bySemanticsLabel(rejection), findsOneWidget);

      // A different message changes the live-region node's label — the
      // node change live-region announcement responds to — so the replacement
      // is announced instead of the stale text.
      await tester.tap(find.byKey(const Key('mine-site-sell')));
      await tester.pump();
      final saleData = tester
          .getSemantics(find.textContaining('Sold'))
          .getSemanticsData();
      expect(saleData.label, contains('Sold'));
      expect(saleData.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('rotation while feedback is visible keeps clearance', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      await showRejectionFeedback(tester);
      expect(_resultPanel, findsOneWidget);

      tester.view.physicalSize = const Size(874, 402);
      await tester.pump();

      expect(find.byKey(const Key('mine-site-screen')), findsOneWidget);
      expect(find.text('Select an occupied rig bay.'), findsOneWidget);
      expect(_resultPanel, findsOneWidget);
      for (final key in const [
        'mining-cash-chip',
        'mine-site-cargo',
        'mine-site-right-rail',
        'mining-bottom-navigation',
      ]) {
        expectPanelClearOf(tester, find.byKey(Key(key)));
      }
    });

    testWidgets('feedback appears settled with no entrance animation', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      final handle = tester.ensureSemantics();
      await showRejectionFeedback(tester, settle: Duration.zero);

      // First rendered frame: the panel is already at its settled geometry
      // and fully opaque — an entrance animation of any length would show a
      // mid-flight frame here instead.
      expectThemedResultPanel(tester, find.text('Select an occupied rig bay.'));
      expectPanelFullyVisible(tester);
      final settled = tester.getRect(_resultPanel);

      // Short subsequent intervals keep the exact settled geometry and full
      // visibility, so no fade in either direction can be running.
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(_resultPanel), settled);
      expectPanelFullyVisible(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(_resultPanel), settled);
      expectPanelFullyVisible(tester);
      handle.dispose();
    });

    testWidgets('the feedback timer is canceled on shell disposal', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      await showRejectionFeedback(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));

      // The expiry callback throws if it ever fires after disposal, so an
      // uncanceled timer surfaces here instead of passing silently.
      expect(tester.takeException(), isNull);
      expect(_resultPanel, findsNothing);
    });

    testWidgets('a repeated message re-keys its live region', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: _start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        useViewSafeArea: true,
      );

      await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
      await tester.pump();
      final emptyBay = find.ancestor(
        of: find.byKey(const ValueKey<String>('b3')),
        matching: find.byType(InkWell),
      );
      await tester.tap(emptyBay);
      await tester.pump(const Duration(milliseconds: 300));
      final firstKey = tester
          .widget<Semantics>(
            find.descendant(of: _resultPanel, matching: find.byType(Semantics)),
          )
          .key;

      await tester.tap(emptyBay);
      await tester.pump(const Duration(milliseconds: 300));
      final secondKey = tester
          .widget<Semantics>(
            find.descendant(of: _resultPanel, matching: find.byType(Semantics)),
          )
          .key;

      // Same text, new live-region identity, so screen readers announce it.
      expect(secondKey, isNot(firstKey));
      expect(find.text('Select an occupied rig bay.'), findsOneWidget);
    });
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

      clock.now = _start.add(const Duration(minutes: 6));
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
      clock.now = _start.add(const Duration(minutes: 6));
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
    clock.now = _start.add(const Duration(minutes: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
  });

  testWidgets(
    'a cold load under five minutes accrues without the return sheet',
    (tester) async {
      final clock = TestClock(
        _start.add(const Duration(minutes: 4, seconds: 59)),
      );
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingBasin(_start));
      await pumpShell(tester, repository: repository, clock: clock);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        greaterThan(0),
      );

      final accrued = shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount;
      expect(repository.saveCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.saveCount, 2);

      final persisted = await repository.load(nowUtc: clock.now);
      expect(persisted.recoveredFromInvalidSave, isFalse);
      expect(
        persisted.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        accrued,
      );
      expect(persisted.state.lastAccruedAtUtc, clock.now);

      final reloaded = MiningController(
        content: MiningContentRegistry.stellarMining(),
        repository: repository,
        nowUtc: clock.call,
      );
      await reloaded.initialize();
      expect(
        reloaded.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        accrued,
      );
    },
  );

  testWidgets('a cold load at five minutes shows the return sheet', (
    tester,
  ) async {
    final clock = TestClock(_start.add(const Duration(minutes: 5)));
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingBasin(_start));
    await pumpShell(tester, repository: repository, clock: clock);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
    expect(find.textContaining('Gold'), findsWidgets);
  });

  testWidgets(
    'a background return under five minutes accrues without the sheet',
    (tester) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingBasin(_start));
      await pumpShell(tester, repository: repository, clock: clock);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();

      clock.now = _start.add(const Duration(minutes: 4, seconds: 59));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        greaterThan(0),
      );

      final accrued = shellHandles(
        tester,
      ).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount;
      expect(repository.saveCount, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.saveCount, 3);

      final persisted = await repository.load(nowUtc: clock.now);
      expect(persisted.recoveredFromInvalidSave, isFalse);
      expect(
        persisted.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        accrued,
      );
      expect(persisted.state.lastAccruedAtUtc, clock.now);

      final reloaded = MiningController(
        content: MiningContentRegistry.stellarMining(),
        repository: repository,
        nowUtc: clock.call,
      );
      await reloaded.initialize();
      expect(
        reloaded.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        accrued,
      );
    },
  );

  testWidgets('a background return at five minutes shows the sheet', (
    tester,
  ) async {
    final clock = TestClock(_start);
    final repository = CountingMiningSaveRepository();
    await repository.save(deployedLandingBasin(_start));
    await pumpShell(tester, repository: repository, clock: clock);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();

    clock.now = _start.add(const Duration(minutes: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
    expect(find.textContaining('Gold'), findsWidgets);
  });

  testWidgets(
    'Offline Return SELL ALL dismisses the sheet and sells every unlocked '
    'planet once',
    (tester) async {
      final clock = TestClock(_start.add(const Duration(minutes: 5)));
      final repository = CountingMiningSaveRepository();
      await repository.save(multiProducerState(_start));
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
      expect(find.text('SELL ALL · +6,000'), findsOneWidget);

      await tester.tap(find.byKey(const Key('offline-return-sell-all')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
      final state = shellHandles(tester).controller.state;
      expect(state.cash, 6000);
      expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 0);
      expect(state.sites[MiningSiteId.frozenBasin]!.storedAmount, 0);
      expect(find.text('Sold 6,000 cash.'), findsOneWidget);
      expect(
        effects.playedAssets.where((path) => path == 'audio/sale.wav'),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'Offline Return SELL ALL over an open sheet exposes the shell before '
    'reporting the sale',
    (tester) async {
      final clock = TestClock(_start);
      final repository = CountingMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      await pumpShell(tester, repository: repository, clock: clock);

      shellHandles(tester).openTechnology();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      clock.now = _start.add(const Duration(minutes: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);

      await tester.tap(find.byKey(const Key('offline-return-sell-all')));
      await tester.pumpAndSettle();

      // The sale feedback renders on the shell beneath modal routes, so both
      // stacked sheets must be gone for it to be visible.
      expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
      expect(find.byKey(const Key('mining-technology-sheet')), findsNothing);
      expect(find.textContaining('Sold '), findsOneWidget);
    },
  );

  testWidgets(
    'Offline Return SELL ALL during a checkpoint reports busy and sells '
    'nothing',
    (tester) async {
      final clock = TestClock(_start.add(const Duration(minutes: 5)));
      final repository = DelayedMiningSaveRepository();
      await repository.save(deployedLandingState(_start, cargo: 10));
      await pumpShell(tester, repository: repository, clock: clock);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
      expect(find.text('SELL ALL · +640'), findsOneWidget);

      repository.delayNextSave = true;
      unawaited(shellHandles(tester).controller.checkpoint());
      await repository.saveStarted.future;
      await tester.pump();
      expect(shellHandles(tester).controller.isBusy, isTrue);

      await tester.tap(find.byKey(const Key('offline-return-sell-all')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
      expect(find.text('Finishing previous action…'), findsOneWidget);
      expect(find.text('Sold 640 cash.'), findsNothing);

      repository.allowSave.complete();
      await tester.pump(const Duration(milliseconds: 300));

      final state = shellHandles(tester).controller.state;
      expect(state.cash, 100);
      expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 160);
      expect(find.text('Sold 640 cash.'), findsNothing);
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

  group('animated site impacts', () {
    int impactSequence(WidgetTester tester) => tester
        .widget<MineSiteScreen>(find.byType(MineSiteScreen))
        .impactSequence;

    Future<void> openFrozenBasin(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('site-card-frozenBasin-enter')));
      await tester.pump();
    }

    /// The deployed save builder per animated site. A closed switch keeps
    /// this loud: a newly animated site without a builder throws instead of
    /// silently losing strike and sound coverage.
    MiningSave Function(DateTime) deployedSaveFor(MiningSiteId siteId) =>
        switch (siteId) {
          MiningSiteId.landingBasin => deployedLandingBasin,
          MiningSiteId.frozenBasin => deployedFrozenBasinState,
          MiningSiteId.carbonRidge => deployedCarbonRidgeState,
          _ => throw StateError('no deployed save builder for ${siteId.name}'),
        };

    for (final siteId in animatedMiningSiteIds) {
      testWidgets(
        'passive ${siteId.name} production strikes once and plays the mining '
        'cue',
        (tester) async {
          final clock = TestClock(_start);
          final repository = CountingMiningSaveRepository();
          await repository.save(deployedSaveFor(siteId)(clock.now));
          final effects = FakeBackgroundMusicPlayer();
          final audio = AudioManager(
            backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
            soundEffectPlayer: effects,
          );
          addTearDown(audio.dispose);
          await warmDepositFrames(
            tester,
            MiningVisuals.depositFramesFor(siteId)!,
          );
          await pumpShell(
            tester,
            repository: repository,
            clock: clock,
            audioManager: audio,
          );
          final enter = find.byKey(Key('site-card-${siteId.name}-enter'));
          await tester.ensureVisible(enter);
          await tester.tap(enter);
          await tester.pump();

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
        },
        skip: kIsWeb,
      );
    }

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

  testWidgets(
    'a rejected purchase dismisses the sheet so the failure is visible',
    (tester) async {
      final repository = DelayedMiningSaveRepository();
      await repository.save(homeworldMasteredState(_start, cash: 1_000));
      final effects = FakeBackgroundMusicPlayer();
      final audio = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: effects,
      );
      addTearDown(audio.dispose);
      await pumpShell(tester, repository: repository, audioManager: audio);
      tester.view.physicalSize = const Size(430, 932);
      await tester.pump();

      shellHandles(tester).openTechnology();
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('mining-technology-sheet'));
      expect(sheet, findsOneWidget);

      repository.delayNextSave = true;
      final buy = find.byKey(const Key('mining-technology-buy-extraction'));
      await tester.tap(buy);
      await repository.saveStarted.future;
      await tester.pump();

      // The button disables while the save is in flight.
      final inFlightButton = tester.widget<ElevatedButton>(
        find.descendant(of: buy, matching: find.byType(ElevatedButton)),
      );
      expect(inFlightButton.onPressed, isNull);

      repository.allowSave.completeError(StateError('save failed'));
      await tester.pumpAndSettle();

      // The covering sheet is dismissed so the failure panel is visible on
      // the shell, and the rejection plays audio without mutating.
      expect(sheet, findsNothing);
      expect(find.text('Action failed.'), findsOneWidget);
      final state = shellHandles(tester).controller.state;
      expect(state.technology.extraction, 0);
      expect(state.cash, 1_000);
      expect(effects.playedAssets, contains('audio/reject.wav'));
    },
  );

  testWidgets(
    'a successful technology purchase updates the sheet in place and shows no toast',
    (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(homeworldMasteredState(_start, cash: 1_000));
      final effects = FakeBackgroundMusicPlayer();
      final audio = AudioManager(
        backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
        soundEffectPlayer: effects,
      );
      addTearDown(audio.dispose);
      await pumpShell(tester, repository: repository, audioManager: audio);
      tester.view.physicalSize = const Size(430, 932);
      await tester.pump();

      shellHandles(tester).openTechnology();
      await tester.pumpAndSettle();

      final buy = find.byKey(const Key('mining-technology-buy-extraction'));
      await tester.tap(buy);
      await tester.pumpAndSettle();

      // No feedback panel is queued behind the modal sheet.
      expect(find.text('Technology upgraded.'), findsNothing);
      expect(_resultPanel, findsNothing);
      final state = shellHandles(tester).controller.state;
      expect(state.technology.extraction, 1);
      expect(effects.playedAssets, contains('audio/upgrade.wav'));

      // Dismiss the sheet and ensure no stale feedback appears on the shell.
      await tester.tap(find.bySemanticsLabel('Close Technology'));
      await tester.pumpAndSettle();
      expect(find.text('Technology upgraded.'), findsNothing);
      expect(_resultPanel, findsNothing);
    },
  );

  testWidgets('a late purchase failure reports once the sheet is dismissed', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
    await repository.save(homeworldMasteredState(_start, cash: 1_000));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);
    tester.view.physicalSize = const Size(430, 932);
    await tester.pump();

    shellHandles(tester).openTechnology();
    await tester.pumpAndSettle();

    repository.delayNextSave = true;
    await tester.tap(find.byKey(const Key('mining-technology-buy-extraction')));
    await repository.saveStarted.future;

    await tester.tap(find.bySemanticsLabel('Close Technology'));
    await tester.pumpAndSettle();

    repository.allowSave.completeError(StateError('save failed'));
    await tester.pumpAndSettle();

    expect(find.text('Action failed.'), findsOneWidget);
    final state = shellHandles(tester).controller.state;
    expect(state.technology.extraction, 0);
    expect(state.cash, 1_000);
    expect(effects.playedAssets.last, 'audio/reject.wav');
  });

  testWidgets('a failed sale leaves a sheet opened during the save intact', (
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

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.pump();
    repository.delayNextSave = true;
    await tester.tap(find.byKey(const Key('mine-site-sell')));
    await repository.saveStarted.future;

    // The sale was launched from the Mine Site surface, so a sheet opened
    // while its save is in flight is not the initiating route and must not
    // be popped when the failure lands. Landing Basin's animated layer keeps
    // scheduling frames, so the sheet entrance is pumped rather than settled.
    shellHandles(tester).openSettings();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final settingsSheet = find.byKey(const Key('mining-settings-sheet'));
    expect(settingsSheet, findsOneWidget);

    repository.allowSave.completeError(StateError('save failed'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(settingsSheet, findsOneWidget);
    expect(find.text('Sale failed.'), findsOneWidget);
    final state = shellHandles(tester).controller.state;
    expect(state.cash, 100);
    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 10);
    expect(effects.playedAssets.last, 'audio/reject.wav');
  });

  testWidgets('a late purchase failure leaves a different sheet intact', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
    await repository.save(homeworldMasteredState(_start, cash: 1_000));
    final effects = FakeBackgroundMusicPlayer();
    final audio = AudioManager(
      backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
      soundEffectPlayer: effects,
    );
    addTearDown(audio.dispose);
    await pumpShell(tester, repository: repository, audioManager: audio);
    tester.view.physicalSize = const Size(430, 932);
    await tester.pump();

    shellHandles(tester).openTechnology();
    await tester.pumpAndSettle();

    repository.delayNextSave = true;
    await tester.tap(find.byKey(const Key('mining-technology-buy-extraction')));
    await repository.saveStarted.future;

    // The initiating Technology sheet was already dismissed and replaced
    // by Settings before the save failed, so the failure reports without
    // popping the current route.
    await tester.tap(find.bySemanticsLabel('Close Technology'));
    await tester.pumpAndSettle();
    shellHandles(tester).openSettings();
    await tester.pumpAndSettle();
    final settingsSheet = find.byKey(const Key('mining-settings-sheet'));
    expect(settingsSheet, findsOneWidget);

    repository.allowSave.completeError(StateError('save failed'));
    await tester.pumpAndSettle();

    expect(settingsSheet, findsOneWidget);
    expect(find.text('Action failed.'), findsOneWidget);
    final state = shellHandles(tester).controller.state;
    expect(state.technology.extraction, 0);
    expect(state.cash, 1_000);
    expect(effects.playedAssets.last, 'audio/reject.wav');
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
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('mining-technology-buy-surveying')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mining-technology-buy-extraction')),
        findsNothing,
      );
    });

    testWidgets('technology navigation without a goal defaults to Extraction', (
      tester,
    ) async {
      await pumpShell(tester);

      shellHandles(tester).openTechnology();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mining-technology-buy-extraction')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mining-technology-buy-surveying')),
        findsNothing,
      );
    });

    testWidgets(
      'consecutive purchases update the open Technology sheet in place',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(homeworldMasteredState(_start, cash: 1_000));
        final effects = FakeBackgroundMusicPlayer();
        final audio = AudioManager(
          backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
          soundEffectPlayer: effects,
        );
        addTearDown(audio.dispose);
        final hapticCalls = <MethodCall>[];
        TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'HapticFeedback.vibrate') {
                hapticCalls.add(call);
              }
              return null;
            });
        addTearDown(() {
          TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });
        await pumpShell(tester, repository: repository, audioManager: audio);
        tester.view.physicalSize = const Size(430, 932);
        await tester.pump();

        await tester.tap(find.byKey(const Key('site-deck-next-goal')));
        await tester.pumpAndSettle();

        final sheet = find.byKey(const Key('mining-technology-sheet'));
        final buySurveying = find.byKey(
          const Key('mining-technology-buy-surveying'),
        );
        expect(sheet, findsOneWidget);
        expect(buySurveying, findsOneWidget);
        expect(find.text('Surveys 15 Homeworld deposits'), findsOneWidget);
        expect(
          find.text('Next: Surveys 8 new Homeworld deposits'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.bySemanticsLabel(
              RegExp(r'^Surveying level 1, next'),
            ),
          ),
          findsOneWidget,
        );
        final node1 = find.descendant(
          of: sheet,
          matching: find.byKey(const Key('technology-node-surveying-1')),
        );
        expect(
          find.descendant(of: node1, matching: find.text('1')),
          findsOneWidget,
        );
        expect(tester.widget<MiningHex>(node1).fill, const Color(0xFF0E1828));
        expect(tester.widget<MiningHex>(node1).border, MiningTheme.warning);
        expect(
          tester
              .widget<Text>(
                find.descendant(of: node1, matching: find.text('1')),
              )
              .style
              ?.color,
          MiningTheme.warning,
        );
        expect(
          find.ancestor(
            of: node1,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Transform &&
                  (widget.transform.getMaxScaleOnAxis() - 1.12).abs() < 0.001,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: buySurveying, matching: find.text('300')),
          findsOneWidget,
        );

        await tester.tap(buySurveying);
        await tester.pump(const Duration(milliseconds: 300));

        expect(sheet, findsOneWidget);
        expect(buySurveying, findsOneWidget);
        expect(find.text('Surveys 8 Homeworld deposits'), findsOneWidget);
        expect(
          find.text('Next: Surveys 5 new Homeworld deposits'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.bySemanticsLabel(
              RegExp(r'^Surveying level 1, owned'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.bySemanticsLabel(
              RegExp(r'^Surveying level 2, next'),
            ),
          ),
          findsOneWidget,
        );
        expect(tester.widget<MiningHex>(node1).fill, MiningTheme.accent);
        expect(tester.widget<MiningHex>(node1).border, MiningTheme.accent);
        expect(
          tester
              .widget<Text>(
                find.descendant(of: node1, matching: find.text('1')),
              )
              .style
              ?.color,
          const Color(0xFF04121A),
        );
        expect(
          find.ancestor(
            of: node1,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Transform &&
                  (widget.transform.getMaxScaleOnAxis() - 1.12).abs() < 0.001,
            ),
          ),
          findsNothing,
        );
        final node2 = find.descendant(
          of: sheet,
          matching: find.byKey(const Key('technology-node-surveying-2')),
        );
        expect(
          find.descendant(of: node2, matching: find.text('2')),
          findsOneWidget,
        );
        expect(tester.widget<MiningHex>(node2).fill, const Color(0xFF0E1828));
        expect(tester.widget<MiningHex>(node2).border, MiningTheme.warning);
        expect(
          tester
              .widget<Text>(
                find.descendant(of: node2, matching: find.text('2')),
              )
              .style
              ?.color,
          MiningTheme.warning,
        );
        expect(
          find.ancestor(
            of: node2,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Transform &&
                  (widget.transform.getMaxScaleOnAxis() - 1.12).abs() < 0.001,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: buySurveying, matching: find.text('700')),
          findsOneWidget,
        );
        expect(shellHandles(tester).controller.state.technology.surveying, 1);
        expect(shellHandles(tester).controller.state.cash, 700);

        await tester.tap(buySurveying);
        await tester.pump(const Duration(milliseconds: 300));

        expect(sheet, findsOneWidget);
        expect(buySurveying, findsOneWidget);
        expect(find.text('Surveys 5 Homeworld deposits'), findsOneWidget);
        expect(
          find.text(
            'Next: Surveys 2 new Homeworld deposits · Needed for Lunar Frontier',
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.bySemanticsLabel(
              RegExp(r'^Surveying level 2, owned'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.bySemanticsLabel(
              RegExp(r'^Surveying level 3, next'),
            ),
          ),
          findsOneWidget,
        );
        expect(tester.widget<MiningHex>(node2).fill, MiningTheme.accent);
        expect(tester.widget<MiningHex>(node2).border, MiningTheme.accent);
        expect(
          tester
              .widget<Text>(
                find.descendant(of: node2, matching: find.text('2')),
              )
              .style
              ?.color,
          const Color(0xFF04121A),
        );
        final node3 = find.descendant(
          of: sheet,
          matching: find.byKey(const Key('technology-node-surveying-3')),
        );
        expect(
          find.descendant(of: node3, matching: find.text('3')),
          findsOneWidget,
        );
        expect(tester.widget<MiningHex>(node3).fill, const Color(0xFF0E1828));
        expect(tester.widget<MiningHex>(node3).border, MiningTheme.warning);
        expect(
          tester
              .widget<Text>(
                find.descendant(of: node3, matching: find.text('3')),
              )
              .style
              ?.color,
          MiningTheme.warning,
        );
        expect(
          find.ancestor(
            of: node3,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Transform &&
                  (widget.transform.getMaxScaleOnAxis() - 1.12).abs() < 0.001,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: buySurveying, matching: find.text('1,500')),
          findsOneWidget,
        );
        expect(find.text('Need 1,500 cash.'), findsOneWidget);
        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: buySurveying,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(button.onPressed, isNull);
        expect(shellHandles(tester).controller.state.technology.surveying, 2);
        expect(shellHandles(tester).controller.state.cash, 0);
        expect(
          effects.playedAssets.where((path) => path == 'audio/upgrade.wav'),
          hasLength(2),
        );
        expect(
          hapticCalls
              .where(
                (call) => call.arguments == 'HapticFeedbackType.lightImpact',
              )
              .length,
          2,
        );

        await tester.tap(buySurveying);
        await tester.pump(const Duration(milliseconds: 300));
        expect(shellHandles(tester).controller.state.technology.surveying, 2);
        expect(
          effects.playedAssets.where((path) => path == 'audio/upgrade.wav'),
          hasLength(2),
        );
      },
    );

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

    testWidgets(
      'a superseded shell finishing its load late cannot cancel the alert',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(deployedLandingState(_start));
        final audio = DelayedAudioPrefsManager(
          backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
          soundEffectPlayer: FakeBackgroundMusicPlayer(),
        );
        addTearDown(audio.dispose);
        final firstPlatform = FakeStorageAlertPlatform();
        await pumpShell(
          tester,
          repository: repository,
          clock: TestClock(_start),
          audioManager: audio,
          storageAlerts: StorageAlerts(platform: firstPlatform),
          pumpCycles: 1,
        );
        await audio.loadStarted.future;

        // Leaving mining before initialization completes disposes the
        // first shell; the reopened shell takes ownership and arms the
        // shared alert from the same producing save.
        await tester.pumpWidget(const SizedBox.shrink());
        final secondPlatform = FakeStorageAlertPlatform();
        await pumpShell(
          tester,
          repository: repository,
          clock: TestClock(_start),
          storageAlerts: StorageAlerts(platform: secondPlatform),
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump();
        expect(secondPlatform.scheduleCount, 1);

        // The first shell's delayed load now finishes. Its stale-alert
        // cancellation is gated on mounted ownership, so the live shell's
        // armed alert is the only write the shared id ever sees.
        audio.allowLoad.complete();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(firstPlatform.cancelAllCount, 0);
        expect(firstPlatform.scheduleCount, 0);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      },
    );

    testWidgets(
      'a schedule queued behind a slow request drops after a shell reentry',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(deployedLandingState(_start));
        final firstPlatform = FakeStorageAlertPlatform();
        final firstAlerts = StorageAlerts(platform: firstPlatform);
        await pumpShell(
          tester,
          repository: repository,
          clock: TestClock(_start),
          storageAlerts: firstAlerts,
        );
        expect(firstPlatform.cancelAllCount, 1);

        // An OS permission prompt can outlive the shell: it holds the
        // first queue open while the dispose projection enqueues its
        // schedule behind it — still as the owner, since no shell has
        // reopened yet.
        firstPlatform.permissionGate = Completer<void>();
        unawaited(firstAlerts.requestPermission());
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump();

        // The reopened shell claims ownership and clears the shared id on
        // its own unserialized queue before the queued schedule runs.
        final secondPlatform = FakeStorageAlertPlatform();
        await pumpShell(
          tester,
          repository: repository,
          clock: TestClock(_start),
          storageAlerts: StorageAlerts(platform: secondPlatform),
        );
        expect(secondPlatform.cancelAllCount, 1);

        firstPlatform.permissionGate!.complete();
        await tester.pump();
        await tester.pump();

        // The enqueued write rechecks ownership when it runs, so the
        // stale schedule drops instead of rearming the shared alert.
        expect(firstPlatform.scheduleCount, 0);
      },
    );

    testWidgets(
      'a reopened shell\'s cancel lands after an in-flight stale schedule',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(deployedLandingState(_start));
        final eventLog = <String>[];
        final firstPlatform = FakeStorageAlertPlatform(
          eventLog: eventLog,
          name: 'A',
        );
        await pumpShell(
          tester,
          repository: repository,
          clock: TestClock(_start),
          storageAlerts: StorageAlerts(platform: firstPlatform),
        );
        expect(firstPlatform.cancelAllCount, 1);

        // The pause projection reaches the platform and stalls inside it —
        // the same shape as scheduleAt awaiting plugin initialization.
        firstPlatform.scheduleGate = Completer<void>();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(firstPlatform.scheduleCount, 1);

        // The player returns, then leaves mining while the schedule is
        // still in flight: the resumed cancel and the dispose projection
        // queue on the first shell's own chain behind it.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump();

        // Reopening claims ownership and asks for the stale-alert cancel
        // from a separate StorageAlerts. On the shared write chain it must
        // run after the in-flight schedule rather than overtake it.
        final secondPlatform = FakeStorageAlertPlatform(
          eventLog: eventLog,
          name: 'B',
        );
        await pumpShell(
          tester,
          repository: repository,
          clock: TestClock(_start),
          storageAlerts: StorageAlerts(platform: secondPlatform),
        );
        expect(secondPlatform.cancelAllCount, 0);

        firstPlatform.scheduleGate!.complete();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // The in-flight write lands first and the new owner's cancel
        // follows, so the stale arm never lands last on the shared
        // notification id; every stale write queued behind it drops on
        // the lost lease.
        expect(firstPlatform.scheduleCount, 1);
        expect(firstPlatform.cancelAllCount, 1);
        expect(secondPlatform.scheduleCount, 0);
        expect(secondPlatform.cancelAllCount, 1);
        expect(eventLog, ['A cancel', 'A schedule', 'B cancel']);
      },
    );
  });

  /// The nearest enclosing route scope, the node a screen reader selects as
  /// the current route.
  SemanticsNode? routeScopeOf(SemanticsNode node) {
    for (
      SemanticsNode? current = node;
      current != null;
      current = current.parent
    ) {
      if (current.getSemanticsData().flagsCollection.scopesRoute) {
        return current;
      }
    }
    return null;
  }

  /// The announced route name: the first non-empty `namesRoute` label in
  /// depth-first paint order inside [scope], matching the engine's documented
  /// `scopesRoute` selection.
  SemanticsNode? announcedRouteName(SemanticsNode scope) {
    SemanticsNode? found;
    void search(SemanticsNode node) {
      if (found != null) return;
      final data = node.getSemanticsData();
      if (data.flagsCollection.namesRoute && data.label.isNotEmpty) {
        found = node;
        return;
      }
      node.visitChildren((child) {
        search(child);
        return found == null;
      });
    }

    search(scope);
    return found;
  }

  /// A mastery card route must announce the milestone title that the badge
  /// already presents as a heading, on both variants.
  void expectMilestoneRouteAnnouncement(
    WidgetTester tester, {
    required String title,
  }) {
    expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);
    expect(
      ModalRoute.of(
        tester.element(find.byKey(const Key('planet-mastery-card'))),
      ),
      isA<RawDialogRoute<void>>(),
      reason: 'the card is hosted by the real shell dialog route',
    );

    final titleNode = tester.getSemantics(find.text(title));
    final scope = routeScopeOf(titleNode);
    expect(scope, isNotNull, reason: 'the card sits inside a route scope');
    final routeName = announcedRouteName(scope!);
    expect(routeName, isNotNull, reason: 'the route announces a name');
    expect(routeName!.getSemanticsData().label, title);

    final titleData = titleNode.getSemanticsData();
    expect(titleData.flagsCollection.isHeader, isTrue);
    expect(titleData.label, title);
  }

  group('planet mastery feedback', () {
    testWidgets('nonfinal mastery shows the projected next-frontier gates', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(tester, repository: repository);

      await deployIntoMastery(
        tester,
        MiningSiteId.graniteCrater,
        _graniteCraterDeployCell,
      );

      expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);
      expect(find.text('PLANET MASTERED'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('planet-mastery-planet')))
            .data,
        'Homeworld',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('planet-mastery-successor')))
            .data,
        'NEXT · LUNAR FRONTIER',
      );
      expect(find.text('Rig deployed.'), findsNothing);
      expect(_resultPanel, findsNothing);

      final after = shellHandles(tester).controller.state;
      final requirements = StellarMapView.from(
        state: after,
        content: MiningContentRegistry.stellarMining(),
      ).planet(MiningPlanetId.lunarFrontier).requirements;
      expect(requirements, isNotEmpty);
      expect(requirements.any((gate) => gate.isSatisfied), isTrue);
      expect(requirements.any((gate) => !gate.isSatisfied), isTrue);
      // The Stellar Map projection keeps its authored labels; only the card
      // uses the mockup's mastery wording.
      expect(requirements.first.label, 'Homeworld sites 3/3');
      for (var i = 0; i < requirements.length; i++) {
        final gate = requirements[i];
        final displayLabel = i == 0 ? 'Homeworld mastered' : gate.label;
        final row = find.byKey(Key('planet-mastery-requirement-$i'));
        expect(row, findsOneWidget, reason: gate.label);
        expect(
          find.descendant(of: row, matching: find.text(displayLabel)),
          findsOneWidget,
          reason: gate.label,
        );
        if (i == 0) {
          expect(
            find.descendant(
              of: row,
              matching: find.text('Homeworld sites 3/3'),
            ),
            findsNothing,
          );
        }
        if (gate.currentValue != null) {
          expect(
            find.descendant(
              of: row,
              matching: find.text('· ${gate.currentValue}'),
            ),
            findsOneWidget,
            reason: gate.label,
          );
        }
        if (gate.isSatisfied) {
          expect(
            find.descendant(of: row, matching: find.byIcon(Icons.check)),
            findsOneWidget,
            reason: gate.label,
          );
          expect(
            find.descendant(of: row, matching: find.byIcon(Icons.close)),
            findsNothing,
            reason: gate.label,
          );
        } else {
          // The approved mockup marks unmet gates with a small hollow orange
          // circle instead of the previous orange cross.
          expect(
            find.descendant(of: row, matching: find.byIcon(Icons.close)),
            findsNothing,
            reason: gate.label,
          );
          final indicator = find.descendant(
            of: row,
            matching: find.byKey(const Key('planet-mastery-gate-unmet')),
          );
          expect(indicator, findsOneWidget, reason: gate.label);
          final decoration =
              tester.widget<Container>(indicator).decoration! as BoxDecoration;
          expect(decoration.shape, BoxShape.circle, reason: gate.label);
          expect(
            (decoration.border! as Border).top.color,
            MiningTheme.gate,
            reason: gate.label,
          );
          final indicatorRect = tester.getRect(indicator);
          expect(
            indicatorRect.width,
            lessThanOrEqualTo(12),
            reason: gate.label,
          );
          expect(
            indicatorRect.height,
            lessThanOrEqualTo(12),
            reason: gate.label,
          );
        }
        expect(
          find.bySemanticsLabel(
            RegExp(
              '^${RegExp.escape(displayLabel)}, '
              '${gate.isSatisfied ? 'satisfied' : 'required'}',
            ),
          ),
          findsOneWidget,
        );
      }

      await tester.ensureVisible(
        find.byKey(const Key('planet-mastery-continue')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('planet-mastery-continue')));
      await pumpSheet(tester);

      expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      expect(find.byKey(const Key('mine-site-screen')), findsOneWidget);
      expect(find.byKey(const Key('stellar-map-screen')), findsNothing);
      expect(find.text('Rig deployed.'), findsNothing);
    });

    testWidgets('mastery card text uses the production default text style', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(tester, repository: repository);

      await deployIntoMastery(
        tester,
        MiningSiteId.graniteCrater,
        _graniteCraterDeployCell,
      );

      for (final (finder, fontFamily) in [
        (find.text('All 3 sites commissioned'), 'IBM Plex Mono'),
        // The mockup's gate rows use the geometric display face.
        (find.text('Homeworld mastered'), 'Orbitron'),
      ]) {
        final richText = tester.widget<RichText>(
          find.descendant(of: finder, matching: find.byType(RichText)),
        );
        final style = richText.text.style!;
        expect(
          style.decoration ?? TextDecoration.none,
          TextDecoration.none,
          reason: 'the dialog must not inherit the fallback underline',
        );
        expect(
          style.decorationStyle,
          isNot(TextDecorationStyle.double),
          reason: 'the dialog must not inherit the yellow double underline',
        );
        expect(style.decorationColor, isNot(const Color(0xFFFFFF00)));
        expect(style.fontFamily, fontFamily);
        expect(style.fontSize, 12);
        expect(richText.textScaler.scale(12), 12);
      }
    });

    testWidgets('taps above the floating mastery art reach the barrier', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        useViewSafeArea: true,
        safeArea: const EdgeInsets.only(top: 24, bottom: 24),
      );

      await deployIntoMastery(
        tester,
        MiningSiteId.graniteCrater,
        _graniteCraterDeployCell,
      );

      final card = tester.getRect(find.byKey(const Key('planet-mastery-card')));
      expect(
        card.top,
        greaterThan(0),
        reason: 'the sheet must be bounded around the floating card',
      );
      expect(card.height, lessThan(844));
      await tester.tapAt(Offset(195, card.top - 20));
      await pumpSheet(tester);

      expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      expect(find.byKey(const Key('mine-site-screen')), findsOneWidget);
    });

    testWidgets('taps beside the floating mastery card reach the barrier', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        useViewSafeArea: true,
        safeArea: const EdgeInsets.only(top: 24, bottom: 24),
      );

      await deployIntoMastery(
        tester,
        MiningSiteId.graniteCrater,
        _graniteCraterDeployCell,
      );

      final card = tester.getRect(find.byKey(const Key('planet-mastery-card')));
      await tester.tapAt(Offset(8, card.center.dy));
      await pumpSheet(tester);

      expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      expect(find.byKey(const Key('mine-site-screen')), findsOneWidget);
    });

    for (final (edge, atTop) in const [('upper', true), ('lower', false)]) {
      testWidgets('mastery close dismisses from the $edge edge of its circle', (
        tester,
      ) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(nearHomeworldMasteryState(_start));
        await pumpShell(
          tester,
          repository: repository,
          viewport: const Size(390, 844),
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          useViewSafeArea: true,
          safeArea: const EdgeInsets.only(top: 24, bottom: 24),
        );

        await deployIntoMastery(
          tester,
          MiningSiteId.graniteCrater,
          _graniteCraterDeployCell,
        );

        final close = find.bySemanticsLabel('Close PLANET MASTERED');
        expect(close, findsOneWidget);
        final rect = tester.getRect(close);
        final point = atTop
            ? Offset(rect.center.dx, rect.top + 4)
            : Offset(rect.center.dx, rect.bottom - 4);
        await tester.tapAt(point);
        await pumpSheet(tester);

        expect(
          find.byKey(const Key('planet-mastery-card')),
          findsNothing,
          reason: 'the $edge close point $point must be hit-testable',
        );
        expect(find.byKey(const Key('mine-site-screen')), findsOneWidget);
      });
    }

    testWidgets('mastery close is reachable by Tab and activates with Enter', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        useViewSafeArea: true,
        safeArea: const EdgeInsets.only(top: 24, bottom: 24),
      );

      await deployIntoMastery(
        tester,
        MiningSiteId.graniteCrater,
        _graniteCraterDeployCell,
      );

      final close = find.bySemanticsLabel('Close PLANET MASTERED');
      expect(close, findsOneWidget);
      var focused = false;
      for (var tab = 0; tab < 6 && !focused; tab++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focusedContext = FocusManager.instance.primaryFocus?.context;
        focused =
            focusedContext != null &&
            find
                .descendant(
                  of: close,
                  matching: find.byElementPredicate(
                    (element) => element == focusedContext,
                  ),
                )
                .evaluate()
                .isNotEmpty;
      }
      expect(focused, isTrue, reason: 'Tab traversal must reach the close');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await pumpSheet(tester);
      expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      expect(find.byKey(const Key('mine-site-screen')), findsOneWidget);
    });

    testWidgets('Open Map dismisses the mastery card before navigating', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(tester, repository: repository);

      await deployIntoMastery(
        tester,
        MiningSiteId.graniteCrater,
        _graniteCraterDeployCell,
      );
      await tester.ensureVisible(
        find.byKey(const Key('planet-mastery-open-map')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('planet-mastery-open-map')));
      await pumpSheet(tester);

      expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
    });

    testWidgets('failed mastery persistence never shows the mastery card', (
      tester,
    ) async {
      final repository = DelayedMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(tester, repository: repository);

      final enter = find.byKey(const Key('site-card-graniteCrater-enter'));
      await tester.ensureVisible(enter);
      await tester.pump();
      await tester.tap(enter);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.pump();
      repository.delayNextSave = true;
      await tapGridCell(tester, _graniteCraterDeployCell);
      await tester.pump();
      repository.allowSave.completeError(StateError('save failed'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      expect(find.text('Action failed.'), findsOneWidget);
      expect(
        shellHandles(
          tester,
        ).controller.state.sites[MiningSiteId.graniteCrater]!.commissioned,
        isFalse,
      );
    });

    testWidgets(
      'final mastery pays once and relays Relaunch through the card',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(nearFinalPlanetMasteryState(_start));
        await pumpShell(tester, repository: repository);

        await deployIntoMastery(
          tester,
          MiningSiteId.osmiumCaldera,
          _osmiumDeployCell,
        );

        final controller = shellHandles(tester).controller;
        final reward = MiningContentRegistry.stellarMining()
            .planet(MiningPlanetId.ioFrontier)
            .masteryRewardCash;
        expect(controller.state.cash, 1_000_000 + reward);
        expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);
        expect(find.text('FINAL PLANET MASTERED'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('planet-mastery-reward')))
              .data,
          '+${formatMiningCash(reward)}',
        );
        expect(find.textContaining('Io mastered'), findsNothing);

        await tester.ensureVisible(
          find.byKey(const Key('planet-mastery-relaunch')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('planet-mastery-relaunch')));
        await pumpSheet(tester);

        expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
        expect(find.byKey(const Key('mining-relaunch-sheet')), findsOneWidget);

        await tester.tap(find.byKey(const Key('relaunch-cancel')));
        await pumpSheet(tester);
        expect(controller.state.relaunchCount, 0);
        expect(controller.state.cash, 1_000_000 + reward);
        expect(
          controller.state.sites[MiningSiteId.osmiumCaldera]!.commissioned,
          isTrue,
        );

        // Recall and redeploy after mastery: no second reward, no second card.
        await tapGridCell(tester, _osmiumDeployCell);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          controller.state.sites[MiningSiteId.osmiumCaldera]!.rigPlacements,
          isEmpty,
        );
        await tester.tap(find.byKey(const ValueKey<String>('b2')));
        await tester.pump();
        await tapGridCell(tester, _osmiumDeployCell);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
        expect(controller.state.cash, 1_000_000 + reward);

        // Confirm still follows the existing relaunch reset path.
        await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
        await tester.pump();
        final relaunchAction = find.byKey(
          const Key('stellar-map-relaunch-action'),
        );
        await tester.ensureVisible(relaunchAction);
        await tester.pump();
        await tester.tap(relaunchAction);
        await pumpSheet(tester);
        await tester.tap(find.byKey(const Key('relaunch-confirm')));
        await pumpSheet(tester);

        expect(controller.state.relaunchCount, 1);
        expect(controller.state.cash, 100);
        expect(
          controller.state.sites[MiningSiteId.osmiumCaldera]!.commissioned,
          isFalse,
        );
        expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
      },
    );

    testWidgets(
      'final mastery after a relaunch projects the next run multiplier',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(
          nearFinalPlanetMasteryState(_start).copyWith(relaunchCount: 1),
        );
        await pumpShell(tester, repository: repository);

        await deployIntoMastery(
          tester,
          MiningSiteId.osmiumCaldera,
          _osmiumDeployCell,
        );

        expect(
          tester
              .widget<Text>(find.byKey(const Key('planet-mastery-multiplier')))
              .data,
          contains('×2'),
        );
      },
    );

    testWidgets('reduced motion removes sheet transitions through relaunch', (
      tester,
    ) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearFinalPlanetMasteryState(_start));
      await pumpShell(tester, repository: repository, disableAnimations: true);

      shellHandles(tester).openTechnology();
      await tester.pump();
      final technologyRoute = ModalRoute.of(
        tester.element(find.byKey(const Key('mining-technology-sheet'))),
      );
      expect(technologyRoute!.transitionDuration, Duration.zero);
      expect(technologyRoute.reverseTransitionDuration, Duration.zero);
      await tester.tap(find.bySemanticsLabel('Close Technology'));
      await tester.pump();

      await deployIntoMastery(
        tester,
        MiningSiteId.osmiumCaldera,
        _osmiumDeployCell,
      );
      expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);
      final cardRoute = ModalRoute.of(
        tester.element(find.byKey(const Key('planet-mastery-card'))),
      );
      expect(cardRoute!.transitionDuration, Duration.zero);
      expect(cardRoute.reverseTransitionDuration, Duration.zero);

      await tester.ensureVisible(
        find.byKey(const Key('planet-mastery-relaunch')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('planet-mastery-relaunch')));
      await tester.pump();
      expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      final relaunchRoute = ModalRoute.of(
        tester.element(find.byKey(const Key('mining-relaunch-sheet'))),
      );
      expect(relaunchRoute!.transitionDuration, Duration.zero);
      expect(relaunchRoute.reverseTransitionDuration, Duration.zero);

      await tester.tap(find.byKey(const Key('relaunch-cancel')));
      await tester.pump();
      expect(find.byKey(const Key('mining-relaunch-sheet')), findsNothing);
    });

    testWidgets('mastery title is announced as a heading', (tester) async {
      final handle = tester.ensureSemantics();
      final repository = CountingMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(tester, repository: repository);

      await deployIntoMastery(
        tester,
        MiningSiteId.graniteCrater,
        _graniteCraterDeployCell,
      );

      expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('PLANET MASTERED'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('nonfinal mastery route announces the milestone title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = CountingMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(tester, repository: repository);

      await deployIntoMastery(
        tester,
        MiningSiteId.graniteCrater,
        _graniteCraterDeployCell,
      );

      expectMilestoneRouteAnnouncement(tester, title: 'PLANET MASTERED');
      handle.dispose();
    });

    testWidgets('final mastery route announces the milestone title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = CountingMiningSaveRepository();
      await repository.save(nearFinalPlanetMasteryState(_start));
      await pumpShell(tester, repository: repository);

      await deployIntoMastery(
        tester,
        MiningSiteId.osmiumCaldera,
        _osmiumDeployCell,
      );

      expectMilestoneRouteAnnouncement(tester, title: 'FINAL PLANET MASTERED');
      handle.dispose();
    });

    testWidgets('Open Map unwinds a sheet opened while mastery was saving', (
      tester,
    ) async {
      final repository = DelayedMiningSaveRepository();
      await repository.save(nearHomeworldMasteryState(_start));
      await pumpShell(tester, repository: repository);

      final enter = find.byKey(const Key('site-card-graniteCrater-enter'));
      await tester.ensureVisible(enter);
      await tester.pump();
      await tester.tap(enter);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.pump();
      repository.delayNextSave = true;
      await tapGridCell(tester, _graniteCraterDeployCell);
      await tester.pump();
      await repository.saveStarted.future;

      // The player opens Technology while the mastering deploy persists.
      shellHandles(tester).openTechnology();
      await pumpSheet(tester);
      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);

      repository.allowSave.complete();
      await tester.pump();
      await pumpSheet(tester);
      expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);
      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
      expect(find.byKey(const Key('mining-sheet-body')), findsOneWidget);
      expect(
        find.byKey(const Key('mining-sheet-pinned-footer')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('planet-mastery-body')), findsOneWidget);
      expect(
        find.byKey(const Key('planet-mastery-pinned-footer')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('planet-mastery-open-map')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('planet-mastery-open-map')));
      await pumpSheet(tester);

      expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      expect(find.byKey(const Key('mining-technology-sheet')), findsNothing);
      expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
      final shellRoute = ModalRoute.of(
        tester.element(find.byKey(const Key('stellar-map-screen'))),
      );
      expect(shellRoute!.isCurrent, isTrue);
    });

    testWidgets(
      'Relaunch unwinds a sheet opened while final mastery was saving',
      (tester) async {
        final repository = DelayedMiningSaveRepository();
        await repository.save(nearFinalPlanetMasteryState(_start));
        await pumpShell(tester, repository: repository);

        final enter = find.byKey(const Key('site-card-osmiumCaldera-enter'));
        await tester.ensureVisible(enter);
        await tester.pump();
        await tester.tap(enter);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey<String>('b1')));
        await tester.pump();
        repository.delayNextSave = true;
        await tapGridCell(tester, _osmiumDeployCell);
        await tester.pump();
        await repository.saveStarted.future;

        // The player opens Settings while the mastering deploy persists.
        shellHandles(tester).openSettings();
        await pumpSheet(tester);
        expect(find.byKey(const Key('mining-settings-sheet')), findsOneWidget);

        repository.allowSave.complete();
        await tester.pump();
        await pumpSheet(tester);
        expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);
        expect(find.byKey(const Key('mining-settings-sheet')), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('planet-mastery-relaunch')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('planet-mastery-relaunch')));
        await pumpSheet(tester);

        expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
        expect(find.byKey(const Key('mining-settings-sheet')), findsNothing);
        expect(find.byKey(const Key('mining-relaunch-sheet')), findsOneWidget);

        await tester.tap(find.byKey(const Key('relaunch-confirm')));
        await pumpSheet(tester);

        expect(find.byKey(const Key('mining-relaunch-sheet')), findsNothing);
        expect(find.byKey(const Key('mining-settings-sheet')), findsNothing);
        expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
        expect(
          shellHandles(tester).controller.state.relaunchCount,
          1,
          reason: 'confirmation still resets the run once',
        );
      },
    );
  });
}
