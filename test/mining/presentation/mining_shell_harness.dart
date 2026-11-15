import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/audio_manager.dart';
import 'package:horologium/game/storage_alerts.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_shell.dart';

import '../../support/fake_background_music_player.dart';
import '../../support/fake_storage_alert_platform.dart';
import '../../support/mining_grid_fixtures.dart';

class CountingMiningSaveRepository extends MiningSaveRepository {
  var saveCount = 0;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    await super.save(state);
  }
}

class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;
}

const Size miningShellTestViewport = Size(360, 640);
final DateTime miningShellTestStart = DateTime.utc(2026, 8, 26, 12);

/// Legal deploy cell for each planet's last authored site, whose deploy
/// masters that planet on the near-mastery fixtures.
final MiningGridCell graniteCraterDeployCell = deployableMiningCells(
  MiningContentRegistry.stellarMining().site(MiningSiteId.graniteCrater),
).first;
final MiningGridCell osmiumDeployCell = firstPlayableCell(
  MiningContentRegistry.stellarMining().site(MiningSiteId.osmiumCaldera),
);

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

/// Homeworld's last site is unlocked but uncommissioned: one deploy masters
/// Homeworld and surfaces the next-frontier mastery card.
MiningSave nearHomeworldMasteryState(DateTime now) {
  final base = homeworldMasteredState(now);
  return base.copyWith(
    sites: {
      ...base.sites,
      MiningSiteId.graniteCrater: base.sites[MiningSiteId.graniteCrater]!
          .copyWith(commissioned: false, rigPlacements: []),
    },
  );
}

/// Every planet unlocked and every site commissioned except Io's last site:
/// one deploy masters the final planet.
MiningSave nearFinalPlanetMasteryState(DateTime now) {
  final base = finalPlanetMasteredState(now);
  return base.copyWith(
    technology: const TechnologyLevels(surveying: 5),
    docks: {
      ...base.docks,
      MiningPlanetId.ioFrontier: {
        DockBayId.b1: RigTier.t1,
        DockBayId.b2: RigTier.t1,
        DockBayId.b3: null,
        DockBayId.b4: null,
      },
    },
    sites: {
      ...base.sites,
      MiningSiteId.osmiumCaldera: base.sites[MiningSiteId.osmiumCaldera]!
          .copyWith(commissioned: false, rigPlacements: []),
    },
  );
}

/// Taps the center of a grid cell through the pannable mine-site transform.
/// The cell is first dragged toward the cavern's clear center band so the
/// physical tap lands inside the grid surface instead of HUD chrome. Timed
/// drags keep the end-of-gesture velocity realistic so the
/// InteractiveViewer pan and its inertia behave like a physical flick.
Future<void> tapGridCell(WidgetTester tester, MiningGridCell cell) async {
  final interactive = find.byKey(const Key('mining-grid-interactive'));
  Offset cellPoint() {
    final surface = tester.getRect(
      find.byKey(const Key('mining-grid-surface')),
    );
    final scale = surface.width / (50 * miningGridCellSize);
    return surface.topLeft +
        Offset(
          (cell.x + .5) * miningGridCellSize * scale,
          (cell.y + .5) * miningGridCellSize * scale,
        );
  }

  final viewport = tester.getRect(interactive);
  final target = Offset(
    viewport.left + viewport.width / 2,
    viewport.top + viewport.height * .42,
  );
  for (var i = 0; i < 10; i++) {
    final delta = target - cellPoint();
    if (delta.distance < .5) break;
    await tester.timedDrag(
      interactive,
      delta,
      const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(seconds: 2));
  }
  await tester.tapAt(cellPoint());
}

/// Pumps the frame that starts a modal sheet route, then its animation.
Future<void> pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Enters [siteId] with the first Homeworld/active-planet dock bay selected
/// and taps [cell], the deploy that masters a near-mastery fixture.
Future<void> deployIntoMastery(
  WidgetTester tester,
  MiningSiteId siteId,
  MiningGridCell cell,
) async {
  final enter = find.byKey(Key('site-card-${siteId.name}-enter'));
  await tester.ensureVisible(enter);
  await tester.pump();
  await tester.tap(enter);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('b1')));
  await tester.pump();
  await tapGridCell(tester, cell);
  await pumpSheet(tester);
}

/// Opens the final mastery card at a specific viewport, safe area, and scale.
Future<void> openFinalMasteryAt(
  WidgetTester tester, {
  required Size size,
  required EdgeInsets safeArea,
  double textScale = 1.3,
  int relaunchCount = 1,
}) async {
  final repository = CountingMiningSaveRepository();
  await repository.save(
    nearFinalPlanetMasteryState(
      miningShellTestStart,
    ).copyWith(relaunchCount: relaunchCount),
  );
  await pumpShell(
    tester,
    repository: repository,
    viewport: size,
    theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
    useViewSafeArea: true,
    safeArea: safeArea,
    textScale: textScale,
  );
  if (size.width > size.height) {
    await tester.dragUntilVisible(
      find.byKey(Key('site-card-${MiningSiteId.osmiumCaldera.name}-enter')),
      find.byKey(const Key('site-deck-scroll')),
      const Offset(0, -200),
    );
    await tester.pump();
  }
  await deployIntoMastery(tester, MiningSiteId.osmiumCaldera, osmiumDeployCell);
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
  Size viewport = miningShellTestViewport,
  EdgeInsets safeArea = EdgeInsets.zero,
  double textScale = 1.0,
  bool useViewSafeArea = false,
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  if (useViewSafeArea) {
    tester.view.padding = FakeViewPadding(
      left: safeArea.left,
      top: safeArea.top,
      right: safeArea.right,
      bottom: safeArea.bottom,
    );
    tester.view.viewPadding = FakeViewPadding(
      left: safeArea.left,
      top: safeArea.top,
      right: safeArea.right,
      bottom: safeArea.bottom,
    );
  }
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    if (useViewSafeArea) {
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    }
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  final testClock = clock ?? TestClock(miningShellTestStart);
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
  final shell = MiningShell(
    key: shellKey,
    content: MiningContentRegistry.stellarMining(),
    repository: repository,
    nowUtc: testClock.call,
    audioManager: audio,
    storageAlerts: alerts,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      // Sheet routes are siblings of `home` under the Navigator, so the
      // live-metrics mode must copy the ambient MediaQuery above the
      // Navigator; its padding then drives both the shell and the route.
      builder: useViewSafeArea
          ? (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations:
                      disableAnimations || media.disableAnimations,
                ),
                child: child!,
              );
            }
          : null,
      home: useViewSafeArea
          ? shell
          : MediaQuery(
              data: MediaQueryData(disableAnimations: disableAnimations),
              child: shell,
            ),
    ),
  );
  for (var i = 0; i < pumpCycles; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

MiningShellHandles shellHandles(WidgetTester tester) =>
    tester.state(find.byType(MiningShell)) as MiningShellHandles;

/// A mastery card's text and art must open inside the scrolling body's visible
/// viewport and above the pinned actions.
void expectMasteryBodyContentVisible(
  WidgetTester tester,
  Iterable<Finder> finders,
) {
  final body = tester.getRect(find.byKey(const Key('planet-mastery-body')));
  final footer = tester.getRect(
    find.byKey(const Key('planet-mastery-pinned-footer')),
  );
  for (final finder in finders) {
    final rect = tester.getRect(finder);
    expect(
      body.contains(rect.topLeft),
      isTrue,
      reason: '$finder $rect vs $body',
    );
    expect(
      body.contains(rect.bottomRight - const Offset(1, 1)),
      isTrue,
      reason: '$finder $rect vs $body',
    );
    expect(rect.bottom, lessThanOrEqualTo(footer.top + .5), reason: '$finder');
  }
}
