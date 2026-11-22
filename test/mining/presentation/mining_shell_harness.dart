import 'dart:math' as math;

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

/// Taps the center of a grid cell through the vertical map scroll. The cell
/// is first scrolled into the map's clear band (below the cargo gauge and
/// above the Sell column), then tapped at the first point in its displayed
/// rect that is not under the depth rail. A timed drag keeps the end-of-
/// gesture velocity realistic so the real scroll physics handles the move.
Future<void> tapGridCell(WidgetTester tester, MiningGridCell cell) async {
  final map = find.byKey(const Key('mining-grid-map'));
  final scrollable = find
      .descendant(of: map, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  final mapRect = tester.getRect(map);
  final cargo = find.byKey(const Key('mine-site-cargo'));
  final sell = find.byKey(const Key('mine-site-sell'));
  var clearTop = mapRect.top + 8;
  if (tester.any(cargo)) {
    clearTop = math.max(clearTop, tester.getRect(cargo).bottom + 8);
  }
  var clearBottom = mapRect.bottom - 12;
  if (tester.any(sell)) {
    clearBottom = math.min(clearBottom, tester.getRect(sell).top - 16);
  }

  Rect cellRect() {
    final surface = tester.getRect(
      find.byKey(const Key('mining-grid-surface')),
    );
    final scale = surface.width / miningGridSceneWidth;
    final size = miningGridCellSize * scale;
    return Rect.fromLTWH(
      surface.left + cell.x * size,
      surface.top + cell.y * size,
      size,
      size,
    );
  }

  for (var i = 0; i < 8; i++) {
    final rect = cellRect();
    if (rect.top < clearTop) {
      position.jumpTo(position.pixels - (clearTop - rect.top));
    } else if (rect.bottom > clearBottom) {
      position.jumpTo(position.pixels + (rect.bottom - clearBottom));
    } else {
      break;
    }
    await tester.pump();
  }

  final railFinder = find.byKey(const Key('mining-depth-rail'));
  final rail = tester.any(railFinder) ? tester.getRect(railFinder) : Rect.zero;
  final rect = cellRect();
  final candidates = <Offset>[
    rect.center,
    Offset(rect.center.dx, rect.bottom - 4),
    Offset(rect.left + 6, rect.center.dy),
    Offset(rect.right - 6, rect.bottom - 4),
    Offset(rect.center.dx, rect.top + 4),
  ];
  final point = candidates.firstWhere(
    (candidate) =>
        mapRect.contains(candidate) &&
        !rail.contains(candidate) &&
        candidate.dy > clearTop &&
        candidate.dy <= clearBottom,
    orElse: () => rect.center,
  );
  await tester.tapAt(point);
  await tester.pump();
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
  bool boldText = false,
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
                  boldText: boldText || media.boldText,
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
