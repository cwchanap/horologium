import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

import '../../support/mining_grid_fixtures.dart';
import '../../support/mining_visual_frames.dart';

final _start = DateTime.utc(2026, 8, 26, 12);
final _content = MiningContentRegistry.stellarMining();
final _landingDefinition = _content.site(MiningSiteId.landingBasin);
final _landingRigCells = deployableMiningCells(_landingDefinition);

SiteProgress _progress({
  bool unlocked = true,
  bool commissioned = false,
  double storedAmount = 0,
  List<MiningRigPlacement> rigs = const [],
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigPlacements: rigs,
);

MiningSave _stateWith({SiteProgress? landing, int? cash}) {
  final initial = MiningSave.initial(nowUtc: _start);
  return initial.copyWith(
    cash: cash,
    sites: {
      ...initial.sites,
      if (landing != null) MiningSiteId.landingBasin: landing,
    },
  );
}

MiningSave _stateWithTwoSites({
  required double landingCargo,
  required double carbonCargo,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  return initial.copyWith(
    sites: {
      ...initial.sites,
      MiningSiteId.landingBasin: _progress(
        unlocked: true,
        commissioned: true,
        storedAmount: landingCargo,
      ),
      MiningSiteId.carbonRidge: _progress(
        unlocked: true,
        commissioned: true,
        storedAmount: carbonCargo,
      ),
    },
  );
}

MiningSave _stateWithLunarCargo({
  required double landingCargo,
  required double lunarCargo,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  return initial.copyWith(
    unlockedPlanetIds: const {
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
    },
    sites: {
      ...initial.sites,
      MiningSiteId.landingBasin: _progress(
        unlocked: true,
        commissioned: true,
        storedAmount: landingCargo,
      ),
      MiningSiteId.frozenBasin: _progress(
        unlocked: true,
        commissioned: true,
        storedAmount: lunarCargo,
      ),
    },
  );
}

MineSiteView _siteView(
  MiningSave state, {
  DockBayId? selectedBayId,
  bool isBusy = false,
  MiningSiteId siteId = MiningSiteId.landingBasin,
}) => MineSiteView.from(
  state: state,
  content: _content,
  siteId: siteId,
  selectedBayId: selectedBayId,
  isBusy: isBusy,
);

FleetDockView _dockView(
  MiningSave state, {
  DockBayId? selectedBayId,
  bool isBusy = false,
}) => FleetDockView.from(
  state: state,
  content: _content,
  selectedBayId: selectedBayId,
  isBusy: isBusy,
);

Future<void> _pumpMineSite(
  WidgetTester tester, {
  required MineSiteView view,
  required FleetDockView dock,
  Size size = const Size(360, 640),
  EdgeInsets padding = EdgeInsets.zero,
  bool disableAnimations = false,
  int impactSequence = 0,
  ValueChanged<MiningGridCell>? onGridCellTap,
  ValueChanged<DockBayId>? onBayTap,
  VoidCallback? onSpawnRig,
  ValueChanged<RigTier>? onBuildRig,
  VoidCallback? onSellCargo,
  VoidCallback? onBack,
  VoidCallback? onSettings,
  ValueChanged<MiningNavigationDestination>? onDestinationSelected,
  double textScale = 1.3,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
      builder: (context, child) =>
          Material(type: MaterialType.transparency, child: child!),
      home: MediaQuery(
        data: MediaQueryData(
          padding: padding,
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MineSiteScreen(
          view: view,
          fleetDock: dock,
          cash: 100,
          reducedMotion: disableAnimations,
          impactSequence: impactSequence,
          onGridCellTap: onGridCellTap ?? (_) {},
          onBayTap: onBayTap ?? (_) {},
          onSpawnRig: onSpawnRig ?? () {},
          onBuildRig: onBuildRig ?? (_) {},
          onSellCargo: onSellCargo ?? () {},
          onBack: onBack ?? () {},
          onSettings: onSettings ?? () {},
          onDestinationSelected: onDestinationSelected,
        ),
      ),
    ),
  );
  await tester.pump();
}

Offset _cellPoint(WidgetTester tester, MiningGridCell cell) {
  final surface = tester.getRect(find.byKey(const Key('mining-grid-surface')));
  final scale = surface.width / miningGridSceneWidth;
  return surface.topLeft +
      Offset(
        (cell.x + .5) * miningGridCellSize * scale,
        (cell.y + .5) * miningGridCellSize * scale,
      );
}

ScrollPosition _scrollPosition(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byKey(const Key('mining-grid-map')),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable.first).position;
}

/// Landscape cavern band: cash chip/cargo top band, gauge column, and the
/// compact navigation toolbar above the left cutout and home indicator.
Rect _unoccludedLandscapeBand(
  Size cavern, {
  double left = 0,
  double bottom = 70,
}) => Rect.fromLTRB(left, 126, cavern.width - 88, cavern.height - bottom);

/// Scrolls [cell] into the screen's clear band and returns the first point
/// inside its displayed rect that is clear of the depth rail.
Future<Offset> _scrollToCell(WidgetTester tester, MiningGridCell cell) async {
  final map = tester.getRect(find.byKey(const Key('mining-grid-map')));
  final cargo = find.byKey(const Key('mine-site-cargo'));
  final sell = find.byKey(const Key('mine-site-sell'));
  var clearTop = map.top + 8;
  if (tester.any(cargo)) {
    clearTop = math.max(clearTop, tester.getRect(cargo).bottom + 8);
  }
  final back = find.byKey(const Key('mine-site-back'));
  if (tester.any(back)) {
    clearTop = math.max(clearTop, tester.getRect(back).bottom + 8);
  }
  var clearBottom = map.bottom - 12;
  if (tester.any(sell)) {
    clearBottom = math.min(clearBottom, tester.getRect(sell).top - 2);
  }
  final position = _scrollPosition(tester);
  Rect currentCellRect() {
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
    final rect = currentCellRect();
    if (rect.top < clearTop) {
      position.jumpTo(position.pixels - (clearTop - rect.top));
    } else if (rect.bottom > clearBottom) {
      position.jumpTo(position.pixels + (rect.bottom - clearBottom));
    } else {
      break;
    }
    await tester.pump();
  }

  final surface = tester.getRect(find.byKey(const Key('mining-grid-surface')));
  final scale = surface.width / miningGridSceneWidth;
  final size = miningGridCellSize * scale;
  final cellRect = Rect.fromLTWH(
    surface.left + cell.x * size,
    surface.top + cell.y * size,
    size,
    size,
  );
  final rail = tester.any(find.byKey(const Key('mining-depth-rail')))
      ? tester.getRect(find.byKey(const Key('mining-depth-rail')))
      : Rect.zero;
  return [
    cellRect.center,
    Offset(cellRect.center.dx, cellRect.bottom - 4),
    Offset(cellRect.left + 6, cellRect.center.dy),
    Offset(cellRect.right - 6, cellRect.bottom - 4),
  ].firstWhere(
    (point) =>
        map.contains(point) &&
        !rail.contains(point) &&
        point.dy > clearTop &&
        point.dy <= clearBottom,
    orElse: () => cellRect.center,
  );
}

/// Chrome rects that must never cover a reachable grid cell or its rig/HP
/// overlays; keys absent in the current orientation are skipped.
List<Rect> _hudRects(WidgetTester tester) => [
  for (final key in const [
    'mining-cash-chip',
    'mine-site-back',
    'mine-site-cargo',
    'mine-site-sell',
    'fleet-dock',
    'mining-bottom-navigation',
    'mine-site-toolbar',
    'mine-site-right-rail',
  ])
    if (tester.any(find.byKey(Key(key)))) tester.getRect(find.byKey(Key(key))),
];

/// The Sell control's full rect: the mine-site-sell key marks only the hex
/// button, while the tappable column includes the projected-value label
/// below it.
Rect _sellControlRect(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.byKey(const Key('mine-site-sell')),
        matching: find.byType(Column),
      )
      .first,
);

/// [extraLegalCells] are rig cells the test state adds on top of the site's
/// legal deploy cells. At maximum scroll no depth-rail target may swallow the
/// centre of a legal target, whatever arrangement the rail takes.
void _expectRailClearOfLegalCellCentres(
  WidgetTester tester,
  Iterable<MiningGridCell> extraLegalCells,
) {
  final surface = tester.getRect(find.byKey(const Key('mining-grid-surface')));
  final cellSize = surface.width / miningGridWidth;
  final targets = [
    for (final band in MiningBand.values)
      tester.getRect(find.byKey(Key('mining-depth-rail-${band.name}'))),
  ];
  for (final cell in {..._landingRigCells, ...extraLegalCells}) {
    final center =
        surface.topLeft +
        Offset((cell.x + .5) * cellSize, (cell.y + .5) * cellSize);
    for (final target in targets) {
      expect(
        target.contains(center),
        isFalse,
        reason: 'rail target $target covers legal cell $cell centre $center',
      );
    }
  }
}

/// Animated-layer keys proving the top and bottom edge rigs and their mined
/// resources stay on the unobscured cavern: each rig's robot plus the HP
/// chrome of the deposit it mines.
final _edgeCellOverlays = <MiningGridCell, List<String>>{
  const MiningGridCell(2, 1): const [
    'landing-basin-robot-2-1',
    'landing-basin-hp-2-2-4',
  ],
  const MiningGridCell(7, 21): const [
    'landing-basin-robot-7-21',
    'landing-basin-hp-7-20-1',
  ],
};

/// Scrolls every entry in [overlays] into [band], taps it, and asserts the
/// tap produced exactly one new [cellTaps] callback carrying that cell.
/// Each rig's robot/HP overlays must then sit inside [cavern] and outside
/// every [hud] rect.
Future<void> _expectEdgeCellsTappable(
  WidgetTester tester, {
  required Rect band,
  required Rect cavern,
  required List<Rect> hud,
  required List<MiningGridCell> cellTaps,
  required Map<MiningGridCell, List<String>> overlays,
}) async {
  for (final entry in overlays.entries) {
    final cell = entry.key;
    final point = await _scrollToCell(tester, cell);
    expect(band.contains(point), isTrue, reason: '$cell: $point outside $band');
    for (final chrome in hud) {
      expect(chrome.contains(point), isFalse, reason: '$cell under $chrome');
    }
    cellTaps.clear();
    await tester.tapAt(point);
    await tester.pump();
    expect(
      cellTaps,
      orderedEquals(<MiningGridCell>[cell]),
      reason: 'tap $cell',
    );
    for (final overlayKey in entry.value) {
      final overlay = tester.getRect(find.byKey(Key(overlayKey)));
      expect(
        cavern.contains(overlay.center),
        isTrue,
        reason: '$overlayKey: $overlay',
      );
      for (final chrome in hud) {
        expect(
          chrome.contains(overlay.center),
          isFalse,
          reason: '$overlayKey under $chrome',
        );
      }
    }
  }
}

void main() {
  setUpAll(() async {
    if (kIsWeb) return;
    final loader = FontLoader('Orbitron')
      ..addFont(
        File(
          'assets/fonts/Orbitron-Variable.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await loader.load();
  });

  testWidgets(
    'uses the Landing Basin grid layer for an occupied T1 rig',
    (tester) async {
      // Warm the finite gold frames in real async so the layer's
      // _framesReady becomes true via actual precache completion (see
      // landing_basin_grid_visual_layer_test for the rationale).
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          rigs: [
            MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells.first),
          ],
        ),
      );
      await _pumpMineSite(
        tester,
        size: const Size(402, 874),
        view: _siteView(state),
        dock: _dockView(state),
      );

      expect(
        find.byKey(const Key('landing-basin-grid-visual-layer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('landing-basin-deposit-0-15-2')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('landing-basin-robot-0-14')), findsOneWidget);

      await _pumpMineSite(
        tester,
        size: const Size(402, 874),
        impactSequence: 1,
        view: _siteView(state),
        dock: _dockView(state),
      );
      // With the finite frames warmed, _framesReady is true and the one-shot
      // impact fires immediately on the sequence change. Advance into the S1
      // hit window.
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: find.byKey(const Key('landing-basin-deposit-0-15-2')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    MiningDepositFrames.gold.hit(1),
          ),
        ),
        findsOneWidget,
      );
    },
    // Finite-frame precache needs the VM asset channel; the structural Landing
    // Basin keys are covered on web by the variants test below.
    skip: kIsWeb,
  );

  testWidgets(
    'selects Landing Basin articulated robot tiers per occupied cell',
    (tester) async {
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          rigs: [
            MiningRigPlacement(tier: RigTier.t4, cell: _landingRigCells[0]),
            MiningRigPlacement(tier: RigTier.t3, cell: _landingRigCells[1]),
          ],
        ),
      );
      await _pumpMineSite(
        tester,
        size: const Size(402, 874),
        view: _siteView(state),
        dock: _dockView(state),
      );

      for (final entry in {
        _landingRigCells[0]: RigTier.t4,
        _landingRigCells[1]: RigTier.t3,
      }.entries) {
        final cell = entry.key;
        final tier = entry.value;
        expect(
          find.byKey(Key('landing-basin-robot-${cell.x}-${cell.y}')),
          findsOneWidget,
        );
        for (final assetPath in [
          MiningVisuals.miningRobotBodyAsset(tier),
          MiningVisuals.miningRobotArmAsset(tier),
        ]) {
          expect(
            find.descendant(
              of: find.byKey(Key('landing-basin-robot-${cell.x}-${cell.y}')),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Image &&
                    widget.image is AssetImage &&
                    (widget.image as AssetImage).assetName == assetPath,
              ),
            ),
            findsOneWidget,
          );
        }
      }
    },
  );

  testWidgets('keeps non-animated sites on the static deposit and rig art', (
    tester,
  ) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final state = initial.copyWith(
      sites: {
        ...initial.sites,
        staticMiningSiteId: _progress(
          unlocked: true,
          commissioned: true,
          rigs: [
            MiningRigPlacement(
              tier: RigTier.t1,
              cell: firstPlayableCell(_content.site(staticMiningSiteId)),
            ),
          ],
        ),
      },
    );
    final view = _siteView(state, siteId: staticMiningSiteId);
    await _pumpMineSite(
      tester,
      impactSequence: 1,
      view: view,
      dock: _dockView(state),
    );

    for (final id in animatedMiningSiteIds) {
      expect(
        find.byKey(Key('${MiningVisuals.siteKeyPrefix(id)}-grid-visual-layer')),
        findsNothing,
        reason: id.name,
      );
    }
    expect(
      find.byKey(const Key('static-mining-grid-visual-layer')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('static-mining-grid-visual-layer')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  view.definition.depositAsset,
        ),
      ),
      findsNWidgets(view.deposits.length),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('static-mining-grid-visual-layer')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/mining/rigs/t1.png',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('matches the authored 402x874 Mine Site chrome', (tester) async {
    final state = _stateWith(
      cash: 412,
      landing: _progress(
        commissioned: true,
        storedAmount: 30,
        rigs: [
          MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells.first),
        ],
      ),
    );
    await _pumpMineSite(
      tester,
      size: const Size(402, 874),
      view: _siteView(state),
      dock: _dockView(state),
    );

    expect(
      tester.getRect(find.byKey(const Key('mining-cash-chip'))).topLeft,
      const Offset(0, 54),
    );
    expect(
      tester.getRect(find.byKey(const Key('mine-site-cargo'))),
      const Rect.fromLTWH(306, 50, 84, 84),
    );
    expect(
      tester.getRect(find.byKey(const Key('mine-site-back'))),
      const Rect.fromLTWH(14, 146, 44, 48),
    );
    // The scroll scene scales the 448dp surface to 402dp and starts below
    // the cash chip/cargo gauge band.
    final surface = tester.getRect(
      find.byKey(const Key('mining-grid-surface')),
    );
    expect(surface.left, closeTo(0, .01));
    expect(surface.width, closeTo(402, .01));
    expect(
      tester.getRect(find.byKey(const Key('mining-grid-map'))).topLeft,
      Offset.zero,
    );
    // The 4x4 Motherlode overlay rides the scaled scene.
    final motherlode = tester.getRect(
      find.byKey(const Key('mining-deposit-2-2-4')),
    );
    expect(motherlode.width, closeTo(4 * miningGridCellSize * 402 / 448, .01));
    expect(motherlode.left, closeTo(2 * miningGridCellSize * 402 / 448, .01));
    final sell = _sellControlRect(tester);
    expect(sell.bottom, 874 - 204);
    expect(sell.right, closeTo(382, 4));
  });

  testWidgets(
    'forwards bay, grid cell, sale, back, settings, and nav callbacks',
    (tester) async {
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          storedAmount: 10,
          rigs: [
            MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells[1]),
          ],
        ),
      );
      final selected = _siteView(state, selectedBayId: DockBayId.b1);
      final bayTaps = <DockBayId>[];
      final cellTaps = <MiningGridCell>[];
      final destinations = <MiningNavigationDestination>[];
      var sold = false;
      var backed = false;
      var settings = false;

      await _pumpMineSite(
        tester,
        view: selected,
        dock: _dockView(state, selectedBayId: DockBayId.b1),
        onGridCellTap: cellTaps.add,
        onBayTap: bayTaps.add,
        onSellCargo: () => sold = true,
        onBack: () => backed = true,
        onSettings: () => settings = true,
        onDestinationSelected: destinations.add,
      );

      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.tapAt(await _scrollToCell(tester, _landingRigCells.first));
      await tester.tap(find.byKey(const Key('mine-site-sell')));
      await tester.tap(find.byKey(const Key('mine-site-back')));
      await tester.tap(find.byKey(const Key('mining-nav-settings')));
      await tester.tap(find.byKey(const Key('mining-nav-technology')));

      expect(bayTaps, <DockBayId>[DockBayId.b1]);
      expect(cellTaps, <MiningGridCell>[_landingRigCells.first]);
      expect(sold, isTrue);
      expect(backed, isTrue);
      expect(settings, isTrue);
      expect(destinations, <MiningNavigationDestination>[
        MiningNavigationDestination.technology,
      ]);
    },
  );

  testWidgets('keeps selected bay and grid object semantics accessible', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        rigs: [
          MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells.first),
        ],
      ),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(state, selectedBayId: DockBayId.b1),
      dock: _dockView(state, selectedBayId: DockBayId.b1),
    );

    expect(find.bySemanticsLabel(RegExp(r'Dock bay B1')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'Gold resource 2x2, 1 miners, 3 of 4 perimeter slots free'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'T1 rig at \(0,14\)')),
      findsOneWidget,
    );
    final deposit = tester.getRect(
      find.byKey(const Key('mining-deposit-2-2-4')),
    );
    final surface = tester.getRect(
      find.byKey(const Key('mining-grid-surface')),
    );
    final scale = surface.width / miningGridSceneWidth;
    expect(deposit.width, closeTo(4 * miningGridCellSize * scale, .01));
    expect(deposit.height, closeTo(4 * miningGridCellSize * scale, .01));
  });

  testWidgets('anchors the cash chip and cargo gauge over portrait art', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        storedAmount: 10,
        rigs: [
          MiningRigPlacement(tier: RigTier.t2, cell: _landingRigCells.first),
        ],
      ),
    );
    await _pumpMineSite(
      tester,
      size: const Size(430, 932),
      view: _siteView(state),
      dock: _dockView(state),
    );

    final cash = tester.getRect(find.byKey(const Key('mining-cash-chip')));
    final gauge = tester.getRect(find.byKey(const Key('mining-cargo-gauge')));
    final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
    expect(cash.width, greaterThanOrEqualTo(64));
    expect(gauge.width, greaterThanOrEqualTo(72));
    expect(gauge.height, greaterThanOrEqualTo(72));
    expect(cavern.overlaps(gauge), isTrue);
    expect(gauge.right, lessThanOrEqualTo(cavern.right));
  });

  testWidgets('uses the cavern as the full-bleed portrait canvas', (
    tester,
  ) async {
    final state = _stateWith();
    await _pumpMineSite(
      tester,
      size: const Size(402, 874),
      view: _siteView(state),
      dock: _dockView(state),
    );

    final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
    expect(cavern, const Rect.fromLTWH(0, 0, 402, 874));
    expect(
      cavern.contains(
        tester.getRect(find.byKey(const Key('fleet-dock'))).center,
      ),
      isTrue,
    );
    expect(
      cavern.contains(
        tester
            .getRect(find.byKey(const Key('mining-bottom-navigation')))
            .center,
      ),
      isTrue,
    );
  });

  testWidgets('shows a large all-unlocked-planet sale with separators', (
    tester,
  ) async {
    final state = _stateWithTwoSites(landingCargo: 0, carbonCargo: 5000);
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));

    expect(find.text('+15,000'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Sell all cargo for 15,000 cash')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'binds sale control to all-unlocked cargo while the gauge stays local',
    (tester) async {
      final sell = find.byKey(const Key('mine-site-sell'));

      await _pumpMineSite(
        tester,
        view: _siteView(_stateWithLunarCargo(landingCargo: 10, lunarCargo: 20)),
        dock: _dockView(_stateWithLunarCargo(landingCargo: 10, lunarCargo: 20)),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Sell all cargo for 160 cash')),
        findsOneWidget,
      );
      expect(find.text('+160'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(sell).onPressed, isNotNull);
      expect(
        tester
            .widget<MiningCargoGauge>(
              find.byKey(const Key('mining-cargo-gauge')),
            )
            .projectedValue,
        40,
        reason: 'the cargo gauge keeps the active-planet projection',
      );

      await _pumpMineSite(
        tester,
        view: _siteView(_stateWithLunarCargo(landingCargo: 0, lunarCargo: 20)),
        dock: _dockView(_stateWithLunarCargo(landingCargo: 0, lunarCargo: 20)),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Sell all cargo for 120 cash')),
        findsOneWidget,
      );
      expect(find.text('+120'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(sell).onPressed, isNotNull);
      expect(
        tester
            .widget<MiningCargoGauge>(
              find.byKey(const Key('mining-cargo-gauge')),
            )
            .projectedValue,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sells sub-1-cash cargo for a +0 sale', (tester) async {
    // 0.1 Gold at Landing Basin (4 cash/unit) = 0.4 gross, which floors to 0.
    final state = _stateWith(
      landing: _progress(commissioned: true, storedAmount: 0.1),
    );
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));

    expect(
      find.bySemanticsLabel(RegExp(r'Sell all cargo for 0 cash')),
      findsOneWidget,
    );
    expect(find.text('+0'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('mine-site-sell')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('busy sale semantics explain the pending action', (tester) async {
    final state = _stateWith(
      landing: _progress(commissioned: true, storedAmount: 10),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(state, isBusy: true),
      dock: _dockView(state),
    );

    expect(find.bySemanticsLabel('Finishing previous action…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('mine-site-sell')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('sell control forwards its semantic tap action to the sale', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var sold = false;
    final state = _stateWith(
      landing: _progress(commissioned: true, storedAmount: 10),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(state),
      dock: _dockView(state),
      onSellCargo: () => sold = true,
    );

    tester.semantics.performAction(
      find.semantics.byLabel('Sell all cargo for 40 cash.'),
      SemanticsAction.tap,
    );
    expect(sold, isTrue);
    handle.dispose();
  });

  testWidgets('busy sell control keeps its label but drops the tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final state = _stateWith(
      landing: _progress(commissioned: true, storedAmount: 10),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(state, isBusy: true),
      dock: _dockView(state),
    );

    final node = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == 'Finishing previous action…',
      ),
    );
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
      reason: 'a busy sale must not announce an activatable button',
    );
    handle.dispose();
  });

  testWidgets(
    'exposes recall capacity rejection copy without enabling recall',
    (tester) async {
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          storedAmount: 6000,
          rigs: [
            MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells.first),
            MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells[1]),
          ],
        ),
      );
      await _pumpMineSite(
        tester,
        view: _siteView(state),
        dock: _dockView(state),
      );

      expect(
        find.bySemanticsLabel(
          RegExp(r'T1 rig at \(0,14\).*Sell cargo before recalling this rig'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.onTap != null &&
              widget.properties.label != null &&
              widget.properties.label!.contains(
                'Sell cargo before recalling',
              ) &&
              widget.properties.label!.contains('T1 rig at (0,14)'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps the grid viewport inside the cavern at portrait sizes', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        rigs: [
          MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells.first),
        ],
      ),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(state, selectedBayId: DockBayId.b2),
      dock: _dockView(state, selectedBayId: DockBayId.b2),
    );

    for (final size in [
      const Size(360, 640),
      const Size(402, 874),
      const Size(430, 932),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.takeException(), isNull);

      final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
      final map = tester.getRect(find.byKey(const Key('mining-grid-map')));
      expect(cavern.contains(map.topLeft), isTrue);
      expect(cavern.contains(map.bottomRight - const Offset(0.1, 0.1)), isTrue);
      expect(
        tester.getRect(find.byKey(const Key('mining-grid-surface'))).width,
        closeTo(size.width, .01),
      );
      final dock = tester.getRect(find.byKey(const Key('fleet-dock')));
      final nav = tester.getRect(
        find.byKey(const Key('mining-bottom-navigation')),
      );
      expect(dock.overlaps(nav), isFalse);
      expect(nav.bottom, lessThanOrEqualTo(size.height));
    }
  });

  testWidgets(
    'fits landscape cavern and controls inside the fixed right rail',
    (tester) async {
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          storedAmount: 10,
          rigs: [
            MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells.first),
          ],
        ),
      );
      await _pumpMineSite(
        tester,
        size: const Size(874, 402),
        view: _siteView(state),
        dock: _dockView(state),
      );

      expect(tester.takeException(), isNull);
      final rail = tester.getRect(
        find.byKey(const Key('mine-site-right-rail')),
      );
      final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
      expect(cavern, const Rect.fromLTWH(0, 0, 770, 402));
      expect(
        tester.getRect(find.byKey(const Key('mine-site-sell'))).left,
        closeTo(271.04, .01),
      );
      expect(rail.width, 104);
      expect(cavern.right, lessThanOrEqualTo(rail.left));
      expect(
        tester.getRect(find.byKey(const Key('mine-site-cargo'))).right,
        lessThanOrEqualTo(rail.left),
      );
      expect(
        tester.getSize(find.byKey(const Key('mine-site-cargo'))).width,
        greaterThanOrEqualTo(72),
      );
      expect(
        tester.getSize(find.byKey(const Key('mine-site-cargo'))).height,
        greaterThanOrEqualTo(72),
      );
      expect(
        rail.contains(
          tester.getRect(find.byKey(const Key('fleet-dock'))).topLeft,
        ),
        isTrue,
      );
      expect(
        tester.getRect(find.byKey(const Key('mining-nav-siteDeck'))).right,
        lessThanOrEqualTo(rail.left),
      );
      expect(
        tester.getRect(find.byKey(const Key('mining-nav-settings'))).right,
        lessThanOrEqualTo(rail.left),
      );
    },
  );

  testWidgets('reduced motion settles grid feedback without overflow', (
    tester,
  ) async {
    final state = _stateWith();
    await _pumpMineSite(
      tester,
      disableAnimations: true,
      view: _siteView(state, selectedBayId: DockBayId.b1),
      dock: _dockView(state, selectedBayId: DockBayId.b1),
    );

    expect(find.byKey(const Key('mining-grid-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked resources stay legible without repeated lock badges', (
    tester,
  ) async {
    // At Surveying 0 most of Landing Basin's authored bands are locked. The map
    // must not repeat a floating badge per locked resource; the dimmed
    // resources keep their Surveying requirement in semantics instead.
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));

    expect(find.text('Surveying 1'), findsNothing);
    expect(find.text('Surveying 2'), findsNothing);
    // Each locked 3x3 lode keeps its own requirement label; the two lodes are
    // separate semantics nodes rather than one merged map node.
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'resource \d+x\d+, 0 miners, \d+ of \d+ perimeter slots '
          r'free\. Requires Surveying 1\.',
        ),
      ),
      findsNWidgets(2),
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'resource \d+x\d+, 0 miners, \d+ of \d+ perimeter slots '
          r'free\. Requires Surveying 2\.',
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'offsets cash chip, cargo gauge, and nav below safe-area insets',
    (tester) async {
      // _pumpMineSite wraps MineSiteScreen in a zero-padding MediaQuery, which
      // would mask the system insets. Pump the screen directly so the portrait
      // chrome reads MediaQuery.paddingOf(context) from the view padding.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      tester.view.padding = const FakeViewPadding(
        left: 0,
        top: 59,
        right: 0,
        bottom: 34,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          storedAmount: 10,
          rigs: [
            MiningRigPlacement(tier: RigTier.t2, cell: _landingRigCells.first),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          builder: (context, child) =>
              Material(type: MaterialType.transparency, child: child!),
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 100,
            onGridCellTap: (_) {},
            onBayTap: (_) {},
            onSpawnRig: () {},
            onBuildRig: (_) {},
            onSellCargo: () {},
            onBack: () {},
            onSettings: () {},
          ),
        ),
      );
      await tester.pump();

      final cash = tester.getRect(find.byKey(const Key('mining-cash-chip')));
      final gauge = tester.getRect(find.byKey(const Key('mine-site-cargo')));
      final nav = tester.getRect(
        find.byKey(const Key('mining-bottom-navigation')),
      );
      expect(cash.top, 54 + 59);
      expect(gauge.top, 50 + 59);
      expect(nav.bottom, 932 - 34);
    },
  );

  testWidgets('keeps the portrait Sell hitbox clear of the dock BUILD pill', (
    tester,
  ) async {
    // 390x780 portrait with a 34px home-indicator inset: the dock header's
    // BUILD pill must not sit under the Sell control. Pump the screen
    // directly so the chrome reads MediaQuery.paddingOf(context) from the
    // view padding.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 780);
    tester.view.padding = const FakeViewPadding(
      left: 0,
      top: 0,
      right: 0,
      bottom: 34,
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });
    final state = _stateWith(
      cash: 100,
      landing: _progress(
        commissioned: true,
        storedAmount: 10,
        rigs: [
          MiningRigPlacement(tier: RigTier.t2, cell: _landingRigCells.first),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        builder: (context, child) =>
            Material(type: MaterialType.transparency, child: child!),
        home: MineSiteScreen(
          view: _siteView(state),
          fleetDock: _dockView(state),
          cash: 100,
          onGridCellTap: (_) {},
          onBayTap: (_) {},
          onSpawnRig: () {},
          onBuildRig: (_) {},
          onSellCargo: () {},
          onBack: () {},
          onSettings: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('fleet-dock-build')), findsOneWidget);
    final sell = _sellControlRect(tester);
    final build = tester.getRect(find.byKey(const Key('fleet-dock-build')));
    expect(sell.overlaps(build), isFalse, reason: 'sell $sell vs $build');
    expect(sell.bottom, lessThanOrEqualTo(build.top));
  });

  testWidgets(
    'offsets landscape cash chip, toolbar, and right rail by safe-area insets',
    (tester) async {
      // Landscape on a notched device: the cutout side and home-indicator
      // inset must not sit under the cash chip, the compact nav toolbar, or
      // the fleet rail. Pump directly so the landscape chrome reads
      // MediaQuery.paddingOf(context) from the view padding.
      const padLeft = 44.0;
      const padRight = 44.0;
      const padBottom = 21.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(874, 402);
      tester.view.padding = const FakeViewPadding(
        left: padLeft,
        top: 0,
        right: padRight,
        bottom: padBottom,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          storedAmount: 10,
          rigs: [
            MiningRigPlacement(tier: RigTier.t2, cell: _landingRigCells.first),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          builder: (context, child) =>
              Material(type: MaterialType.transparency, child: child!),
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 100,
            onGridCellTap: (_) {},
            onBayTap: (_) {},
            onSpawnRig: () {},
            onBuildRig: (_) {},
            onSellCargo: () {},
            onBack: () {},
            onSettings: () {},
          ),
        ),
      );
      await tester.pump();

      final cash = tester.getRect(find.byKey(const Key('mining-cash-chip')));
      final toolbar = tester.getRect(
        find.byKey(const Key('mine-site-toolbar')),
      );
      final rail = tester.getRect(
        find.byKey(const Key('mine-site-right-rail')),
      );
      final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
      // Cash chip clears the left cutout.
      expect(cash.left, padLeft);
      // Compact nav toolbar clears the left cutout and the home indicator.
      expect(toolbar.left, 12 + padLeft);
      expect(toolbar.bottom, 402 - 16 - padBottom);
      // Right fleet rail clears the right cutout and stays adjacent to the
      // cavern (no overlap, no gap).
      expect(rail.right, 874 - padRight);
      expect(cavern.right, lessThanOrEqualTo(rail.left));
      // Cavern art stays full-bleed on the left edge.
      expect(cavern.left, 0);
      // Cavern art stays full-bleed on the left edge, and the scroll map
      // fills the cavern: the centred scene keeps every cell reachable by
      // vertical scrolling instead of hard-insetting the grid.
      final map = tester.getRect(find.byKey(const Key('mining-grid-map')));
      expect(map.left, 0);
      expect(map.left, lessThanOrEqualTo(cavern.left + 0.1));
      expect(
        tester.getRect(find.byKey(const Key('mining-grid-surface'))).left,
        closeTo((cavern.width - miningGridSceneWidth) / 2, .01),
      );
      // The vertical fleet dock stops above the home-indicator inset: the last
      // bay (b4) must not extend into the bottom 21 px.
      final lastBay = tester.getRect(find.byKey(const ValueKey<String>('b4')));
      expect(lastBay.bottom, lessThanOrEqualTo(402 - padBottom));
    },
  );

  testWidgets(
    'keeps the landscape rail inside safe-area insets on a short phone',
    (tester) async {
      const padLeft = 44.0;
      const padRight = 44.0;
      const padBottom = 21.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(812, 375);
      tester.view.padding = const FakeViewPadding(
        left: padLeft,
        top: 0,
        right: padRight,
        bottom: padBottom,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });
      final built = <RigTier>[];
      final bayTaps = <DockBayId>[];
      final state = _stateWith(
        cash: 200,
        landing: _progress(
          commissioned: true,
          storedAmount: 10,
          rigs: [
            MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCells.first),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          builder: (context, child) =>
              Material(type: MaterialType.transparency, child: child!),
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 100,
            onGridCellTap: (_) {},
            onBayTap: bayTaps.add,
            onSpawnRig: () {},
            onBuildRig: built.add,
            onSellCargo: () {},
            onBack: () {},
            onSettings: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      for (final bay in DockBayId.values) {
        final rect = tester.getRect(find.byKey(ValueKey<String>(bay.name)));
        expect(
          rect.bottom,
          lessThanOrEqualTo(375 - padBottom),
          reason: '${bay.name} bottom $rect',
        );
        expect(
          rect.height,
          greaterThanOrEqualTo(44),
          reason: '${bay.name} height $rect',
        );
      }
      await tester.tap(find.byKey(const ValueKey<String>('b4')));
      await tester.pump();
      expect(bayTaps, <DockBayId>[DockBayId.b4]);

      await tester.ensureVisible(find.byKey(const Key('fleet-dock-build')));
      await tester.pump();
      final pillRect = tester.getRect(
        find.byKey(const Key('fleet-dock-build')),
      );
      expect(pillRect.bottom, lessThanOrEqualTo(375 - padBottom));
      expect(pillRect.height, greaterThanOrEqualTo(44));
      await tester.tap(find.byKey(const Key('fleet-dock-build')));
      await tester.pump();
      expect(built, <RigTier>[RigTier.t4]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('renders a Ceres site on its cavern and node art at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final initial = MiningSave.initial(nowUtc: _start);
      final state = initial.copyWith(
        technology: const TechnologyLevels(surveying: 5),
        unlockedPlanetIds: MiningPlanetId.values.toSet(),
        activePlanetId: MiningPlanetId.ceresFrontier,
        sites: {
          ...initial.sites,
          MiningSiteId.nickelShoals: _progress(
            unlocked: true,
            commissioned: true,
            rigs: [
              MiningRigPlacement(
                tier: RigTier.t1,
                cell: firstPlayableCell(
                  _content.site(MiningSiteId.nickelShoals),
                ),
              ),
            ],
          ),
        },
      );
      final view = _siteView(state, siteId: MiningSiteId.nickelShoals);
      await _pumpMineSite(
        tester,
        size: size,
        view: view,
        dock: _dockView(state),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('static-mining-grid-visual-layer')),
        findsOneWidget,
      );
      bool usesAsset(Widget widget, String asset) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == asset;
      expect(
        find.byWidgetPredicate(
          (widget) =>
              usesAsset(widget, 'assets/images/mining/caverns/nickel_ore.png'),
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              usesAsset(widget, 'assets/images/mining/nodes/nickel_ore.png'),
        ),
        findsNWidgets(view.deposits.length),
      );
    });
  }

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('renders an Io site on its cavern and node art at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final initial = MiningSave.initial(nowUtc: _start);
      final state = initial.copyWith(
        technology: const TechnologyLevels(surveying: 5),
        unlockedPlanetIds: MiningPlanetId.values.toSet(),
        activePlanetId: MiningPlanetId.ioFrontier,
        sites: {
          ...initial.sites,
          MiningSiteId.sulfurFlats: _progress(
            unlocked: true,
            commissioned: true,
            rigs: [
              MiningRigPlacement(
                tier: RigTier.t1,
                cell: firstPlayableCell(
                  _content.site(MiningSiteId.sulfurFlats),
                ),
              ),
            ],
          ),
        },
      );
      final view = _siteView(state, siteId: MiningSiteId.sulfurFlats);
      await _pumpMineSite(
        tester,
        size: size,
        view: view,
        dock: _dockView(state),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('static-mining-grid-visual-layer')),
        findsOneWidget,
      );
      bool usesAsset(Widget widget, String asset) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == asset;
      expect(
        find.byWidgetPredicate(
          (widget) =>
              usesAsset(widget, 'assets/images/mining/caverns/sulfur.png'),
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              usesAsset(widget, 'assets/images/mining/nodes/sulfur.png'),
        ),
        findsNWidgets(view.deposits.length),
      );
    });
  }

  testWidgets('fits frontier spawn costs inside the Spawn hex', (tester) async {
    for (final (planet, site, cost) in const [
      (MiningPlanetId.lunarFrontier, MiningSiteId.frozenBasin, '40,000'),
      (MiningPlanetId.marsFrontier, MiningSiteId.ochreBasin, '4.00M'),
      (MiningPlanetId.ceresFrontier, MiningSiteId.nickelShoals, '7.50M'),
      (MiningPlanetId.ioFrontier, MiningSiteId.sulfurFlats, '22.50M'),
    ]) {
      final initial = MiningSave.initial(nowUtc: _start);
      final state = initial.copyWith(
        unlockedPlanetIds: {MiningPlanetId.homeworld, planet},
        activePlanetId: planet,
        sites: {
          ...initial.sites,
          site: _progress(unlocked: true, commissioned: true),
        },
      );
      for (final size in const [Size(360, 640), Size(874, 402)]) {
        await _pumpMineSite(
          tester,
          size: size,
          view: _siteView(state, siteId: site),
          dock: _dockView(state),
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('fleet-dock-spawn')),
            matching: find.text(cost),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '$cost at $size');
      }
    }
  });

  testWidgets(
    'keeps four bays plus Spawn with one hint row in both orientations',
    (tester) async {
      final state = _stateWith();
      for (final size in const [Size(360, 640), Size(874, 402)]) {
        await _pumpMineSite(
          tester,
          size: size,
          view: _siteView(state),
          dock: _dockView(state),
        );
        for (final bay in DockBayId.values) {
          expect(find.byKey(ValueKey<String>(bay.name)), findsOneWidget);
        }
        expect(find.byKey(const Key('fleet-dock-spawn')), findsOneWidget);
      }
      // The landscape vertical rail carries no hint row at all.
      expect(find.byKey(const Key('fleet-dock-hint')), findsNothing);
    },
  );

  testWidgets('renders the resolved dock hint without a selection branch', (
    tester,
  ) async {
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));
    expect(find.text('TAP A RIG, THEN A HIGHLIGHTED CELL'), findsOneWidget);

    await _pumpMineSite(
      tester,
      view: _siteView(state, selectedBayId: DockBayId.b1),
      dock: _dockView(state, selectedBayId: DockBayId.b1),
    );
    expect(find.text('DEPLOY · UPGRADE · MERGE'), findsOneWidget);
  });

  testWidgets(
    'strengthens compatible merge-target chrome over normal occupied bays',
    (tester) async {
      final initial = _stateWith(landing: _progress(commissioned: true));
      // b3 gains a T2 rig: occupied, but not a merge target for the selected
      // T1 in b1 (the other T1 sits in b2).
      final state = initial.copyWith(
        docks: {
          ...initial.docks,
          MiningPlanetId.homeworld: {
            ...initial.docks[MiningPlanetId.homeworld]!,
            DockBayId.b3: RigTier.t2,
          },
        },
      );
      await _pumpMineSite(
        tester,
        view: _siteView(state, selectedBayId: DockBayId.b1),
        dock: _dockView(state, selectedBayId: DockBayId.b1),
      );

      MiningHex hexOf(DockBayId id) => tester.widget<MiningHex>(
        find.ancestor(
          of: find.byKey(ValueKey<String>(id.name)),
          matching: find.byType(MiningHex),
        ),
      );
      final target = hexOf(DockBayId.b2);
      final normal = hexOf(DockBayId.b3);
      expect(target.fill.a, greaterThan(normal.fill.a));
      expect(target.border.a, greaterThan(normal.border.a));
    },
  );

  testWidgets('keeps the dock hint inside max lines at 360x640', (
    tester,
  ) async {
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      size: const Size(360, 640),
      view: _siteView(state, selectedBayId: DockBayId.b1),
      dock: _dockView(state, selectedBayId: DockBayId.b1),
    );

    final hint = find.byKey(const Key('fleet-dock-hint'));
    expect(tester.widget<Text>(hint).maxLines, 3);
    final paragraph = tester.renderObject<RenderParagraph>(hint);
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('bounds the depth rail between cargo and the Sell column', (
    tester,
  ) async {
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(state),
      dock: _dockView(state),
    );

    final cargo = tester.getRect(find.byKey(const Key('mine-site-cargo')));
    final sell = _sellControlRect(tester);
    final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
    expect(rail.top, greaterThanOrEqualTo(cargo.bottom));
    expect(rail.bottom, lessThanOrEqualTo(sell.top));

    final buttons = [
      for (final band in MiningBand.values)
        tester.getRect(find.byKey(Key('mining-depth-rail-${band.name}'))),
    ];
    for (final button in buttons) {
      expect(button.width, greaterThanOrEqualTo(44));
      expect(button.height, greaterThanOrEqualTo(44 - .01));
      expect(rail.contains(button.topLeft), isTrue);
      expect(
        rail.contains(button.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
      );
    }
    for (var i = 0; i < buttons.length; i++) {
      expect(buttons[i].overlaps(cargo), isFalse, reason: 'button $i vs cargo');
      expect(buttons[i].overlaps(sell), isFalse, reason: 'button $i vs sell');
      for (var j = i + 1; j < buttons.length; j++) {
        expect(
          buttons[i].overlaps(buttons[j]),
          isFalse,
          reason: 'buttons $i and $j overlap',
        );
      }
    }
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    testWidgets('physically scrolls and taps (7,21) above Sell at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });
      final taps = <MiningGridCell>[];
      final state = _stateWith(
        cash: 412,
        landing: _progress(
          commissioned: true,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(7, 21)),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: const TextScaler.linear(1.3)),
              child: Material(type: MaterialType.transparency, child: child!),
            );
          },
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 412,
            onGridCellTap: taps.add,
            onBayTap: (_) {},
            onSpawnRig: () {},
            onBuildRig: (_) {},
            onSellCargo: () {},
            onBack: () {},
            onSettings: () {},
          ),
        ),
      );
      await tester.pump();

      final sell = _sellControlRect(tester);
      final cargo = tester.getRect(find.byKey(const Key('mine-site-cargo')));
      expect(tester.takeException(), isNull);

      final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
      expect(rail.top, greaterThanOrEqualTo(cargo.bottom));
      expect(rail.bottom, lessThanOrEqualTo(sell.top));
      final buttons = [
        for (final band in MiningBand.values.reversed)
          tester.getRect(find.byKey(Key('mining-depth-rail-${band.name}'))),
      ];
      for (final button in buttons) {
        expect(button.width, greaterThanOrEqualTo(44 - .01));
        expect(button.height, greaterThanOrEqualTo(44 - .01));
        for (final chrome in _hudRects(tester)) {
          expect(button.overlaps(chrome), isFalse, reason: 'button vs $chrome');
        }
      }
      for (var i = 0; i < buttons.length; i++) {
        for (var j = i + 1; j < buttons.length; j++) {
          expect(
            buttons[i].overlaps(buttons[j]),
            isFalse,
            reason: 'rail targets $i and $j overlap at $size',
          );
        }
      }
      if (rail.height >= 176) {
        expect(
          buttons.map((rect) => rect.left).toSet(),
          hasLength(1),
          reason: 'four targets fit in one column at $size',
        );
        expect(buttons[1].top - buttons[0].top, greaterThanOrEqualTo(44));
      } else {
        // Measured 360x640 / 1.3 / top 47 / bottom 34 constraint: four 44dp
        // targets need 176dp but the clear cargo-to-Sell band is only 108dp
        // (155dp with just the bottom inset). Keep four independent targets
        // high in one horizontal row, leaving the band below clear.
        expect(
          176 - rail.height,
          greaterThan(0),
          reason: 'clear band ${rail.height}dp measured; 176dp required',
        );
        expect(rail.height, 44);
        expect(buttons.map((rect) => rect.top).toSet(), hasLength(1));
        expect(buttons.map((rect) => rect.left).toSet(), hasLength(4));
      }
      final hud = _hudRects(tester);
      for (var i = 0; i < hud.length; i++) {
        for (var j = i + 1; j < hud.length; j++) {
          expect(hud[i].overlaps(hud[j]), isFalse, reason: '$i vs $j');
        }
      }

      // Real scroll physics to the maximum extent, then a physical tap on
      // the bottom-right pocket rig (7,21). Scroll up first so the down drag
      // also works when the initial frame already sits at the bottom, and
      // stop just short of the edge so the transient overscroll stretch never
      // distorts the scene; the final jump pins the exact extent.
      final scroll = find.byKey(const Key('mining-grid-scroll'));
      await tester.drag(scroll, const Offset(0, 200));
      await tester.pump();
      final position = _scrollPosition(tester);
      final delta = position.maxScrollExtent - position.pixels;
      if (delta > 48) {
        await tester.drag(scroll, Offset(0, -(delta - 24)));
        await tester.pump();
      }
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final bottom = _cellPoint(tester, const MiningGridCell(7, 21));
      expect(
        bottom.dy,
        lessThan(sell.top),
        reason: 'the bottom row must clear Sell at maximum scroll',
      );
      final surface = tester.getRect(
        find.byKey(const Key('mining-grid-surface')),
      );
      final scale = surface.width / miningGridSceneWidth;
      final cellSize = miningGridCellSize * scale;
      final cellRect = Rect.fromCenter(
        center: bottom,
        width: cellSize,
        height: cellSize,
      );
      final visible = cellRect.intersect(
        tester.getRect(find.byKey(const Key('mining-grid-map'))),
      );
      var blocked = 0.0;
      for (final chrome in [..._hudRects(tester), rail]) {
        final overlap = cellRect.intersect(chrome);
        if (overlap.width > 0 && overlap.height > 0) {
          blocked += overlap.width * overlap.height;
        }
      }
      final unobstructed = visible.width * visible.height - blocked;
      expect(
        unobstructed,
        greaterThanOrEqualTo(44 * 44 - .01),
        reason:
            'the bottom-right cell must expose a full 44dp interaction area, '
            'not just a sliver: $cellRect',
      );
      // A thin blocked strip can leave area without a contiguous target:
      // merge the blocked spans at the cell's vertical centre and require a
      // contiguous 44dp clear span, not just 44dp of clear width in total.
      final centerY = bottom.dy;
      final spans = <({double left, double right})>[
        for (final chrome in [..._hudRects(tester), rail])
          if (chrome.top < centerY && chrome.bottom > centerY)
            (
              left: math.max(cellRect.left, chrome.left),
              right: math.min(cellRect.right, chrome.right),
            ),
      ]..sort((a, b) => a.left.compareTo(b.left));
      var clearSpan = 0.0;
      var cursor = cellRect.left;
      for (final span in spans) {
        clearSpan = math.max(clearSpan, span.left - cursor);
        cursor = math.max(cursor, span.right);
      }
      clearSpan = math.max(clearSpan, cellRect.right - cursor);
      expect(
        clearSpan,
        greaterThanOrEqualTo(44 - .01),
        reason: 'no contiguous 44dp clear width at the cell centre: $cellRect',
      );

      // Direct center tap: the compact rail must not intercept the legal
      // bottom-right cell's normal target.
      taps.clear();
      await tester.tapAt(bottom);
      await tester.pump();
      expect(taps, <MiningGridCell>[const MiningGridCell(7, 21)]);

      // The right edge likewise remains reachable beside the rail.
      taps.clear();
      await tester.tapAt(Offset(cellRect.right - 2, bottom.dy));
      await tester.pump();
      expect(taps, <MiningGridCell>[const MiningGridCell(7, 21)]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'keeps the zero-inset compact rail off the bottom-right cell centre',
    (tester) async {
      // 360x640 at 1.3x text with no safe-area insets leaves a clear band
      // tall enough for four vertical targets, but the bottom-right legal
      // cell scrolls into its lower edge. The rail must reserve that row
      // instead of intercepting the cell's centre tap.
      final taps = <MiningGridCell>[];
      final state = _stateWith(
        cash: 412,
        landing: _progress(
          commissioned: true,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(7, 21)),
          ],
        ),
      );
      await _pumpMineSite(
        tester,
        size: const Size(360, 640),
        view: _siteView(state),
        dock: _dockView(state),
        onGridCellTap: taps.add,
      );

      final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
      expect(rail.height, 44, reason: 'the compact fallback row is horizontal');
      expect(
        tester.getRect(find.byKey(const Key('mining-depth-rail-pockets'))),
        Rect.fromLTWH(rail.left + 3 * 52, 134, 44, 44),
      );

      final position = _scrollPosition(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final center = _cellPoint(tester, const MiningGridCell(7, 21));
      expect(
        rail.contains(center),
        isFalse,
        reason: 'rail $rail centre $center',
      );
      _expectRailClearOfLegalCellCentres(tester, const [MiningGridCell(7, 21)]);

      await tester.tapAt(center);
      await tester.pump();
      expect(taps, <MiningGridCell>[const MiningGridCell(7, 21)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps the zero-inset landscape rail off the bottom-right cell centre',
    (tester) async {
      // 590x360 with no safe-area insets is the narrow landscape case: the map
      // column still reaches the rail's right-edge column, but the bottom
      // scroll padding puts the last row's centre well above the rail band's
      // lower edge. The rail must stay above that row at maximum scroll.
      final taps = <MiningGridCell>[];
      final state = _stateWith(
        cash: 412,
        landing: _progress(
          commissioned: true,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(7, 21)),
          ],
        ),
      );
      await _pumpMineSite(
        tester,
        size: const Size(590, 360),
        view: _siteView(state),
        dock: _dockView(state),
        onGridCellTap: taps.add,
      );

      final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
      final position = _scrollPosition(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final center = _cellPoint(tester, const MiningGridCell(7, 21));
      expect(
        rail.contains(center),
        isFalse,
        reason: 'rail $rail centre $center',
      );
      _expectRailClearOfLegalCellCentres(tester, const [MiningGridCell(7, 21)]);

      await tester.tapAt(center);
      await tester.pump();
      expect(taps, <MiningGridCell>[const MiningGridCell(7, 21)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'drops the compact rail below the grid when it would cover a legal '
    'centre',
    (tester) async {
      // 590x390 with no safe-area insets: anchoring the horizontal row at the
      // Sell column's left edge lands it on legal cell (3,20)'s centre at
      // maximum scroll. The strip below the grid can hold it, so it drops
      // there and the cell's physical tap still resolves.
      final taps = <MiningGridCell>[];
      final state = _stateWith(landing: _progress(commissioned: true));
      await _pumpMineSite(
        tester,
        size: const Size(590, 390),
        view: _siteView(state, selectedBayId: DockBayId.b1),
        dock: _dockView(state, selectedBayId: DockBayId.b1),
        onGridCellTap: taps.add,
      );

      final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
      expect(rail.height, 44, reason: 'the compact fallback row is horizontal');

      final position = _scrollPosition(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final center = _cellPoint(tester, const MiningGridCell(3, 20));
      expect(
        rail.contains(center),
        isFalse,
        reason: 'rail $rail centre $center',
      );
      _expectRailClearOfLegalCellCentres(tester, const [MiningGridCell(3, 20)]);

      await tester.tapAt(center);
      await tester.pump();
      expect(taps, <MiningGridCell>[const MiningGridCell(3, 20)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps the zero-inset 480x350 rail off every legal cell centre', (
    tester,
  ) async {
    // 480x350 with no safe-area insets leaves 43.5dp between the cargo
    // gauge (bottom 126) and the bottom row's centre (169.5) at maximum
    // scroll: half a dp short of the 44dp compact row. Top-anchoring the row
    // at 126 put its lower edge at 170, so the Lodes target swallowed the
    // legal (5,21) centre tap at (258.5, 169.5).
    final taps = <MiningGridCell>[];
    final state = _stateWith(
      cash: 412,
      landing: _progress(
        commissioned: true,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(5, 21)),
        ],
      ),
    );
    await _pumpMineSite(
      tester,
      size: const Size(480, 350),
      view: _siteView(state),
      dock: _dockView(state),
      onGridCellTap: taps.add,
    );

    final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
    expect(rail.height, 44, reason: 'the compact fallback row is horizontal');
    for (final band in MiningBand.values) {
      final target = tester.getRect(
        find.byKey(Key('mining-depth-rail-${band.name}')),
      );
      expect(target.width, greaterThanOrEqualTo(44 - .01));
      expect(target.height, greaterThanOrEqualTo(44 - .01));
    }
    for (final chrome in _hudRects(tester)) {
      expect(rail.overlaps(chrome), isFalse, reason: 'rail $rail vs $chrome');
    }

    final position = _scrollPosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    final center = _cellPoint(tester, const MiningGridCell(5, 21));
    expect(rail.contains(center), isFalse, reason: 'rail $rail centre $center');
    await tester.tapAt(center);
    await tester.pump();
    expect(taps, <MiningGridCell>[const MiningGridCell(5, 21)]);
    // The compact row fits below the grid's maximum-scroll bottom, so it
    // cannot reach any legal target's centre.
    final surface = tester.getRect(
      find.byKey(const Key('mining-grid-surface')),
    );
    expect(rail.top, greaterThanOrEqualTo(surface.bottom - .01));
    _expectRailClearOfLegalCellCentres(tester, const [MiningGridCell(5, 21)]);
    expect(tester.takeException(), isNull);
  });

  for (final inset in const [44.0, 60.0]) {
    testWidgets(
      'keeps the ${inset.toInt()}dp-inset compact rail clear of Sell',
      (tester) async {
        // 480x350 with a left safe-area inset pushes the below-grid fallback
        // row right of the map's clear left edge: at 44dp it spans x 44..244
        // and at 60dp x 60..260, while the landscape Sell column starts at
        // x=236. The row must size its gaps from the space between the safe
        // left edge and Sell, keeping four 44dp targets and never covering
        // Sell, so a Pockets tap cannot land on the Sell control.
        final taps = <MiningGridCell>[];
        var sold = false;
        final state = _stateWith(
          cash: 412,
          landing: _progress(
            commissioned: true,
            storedAmount: 5,
            rigs: const [
              MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(5, 21)),
            ],
          ),
        );
        await _pumpMineSite(
          tester,
          size: const Size(480, 350),
          padding: EdgeInsets.only(left: inset),
          view: _siteView(state),
          dock: _dockView(state),
          onGridCellTap: taps.add,
          onSellCargo: () => sold = true,
        );

        final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
        final sell = _sellControlRect(tester);
        expect(
          rail.height,
          44,
          reason: 'the compact fallback row is horizontal',
        );
        expect(rail.left, inset);
        expect(rail.overlaps(sell), isFalse, reason: 'rail $rail Sell $sell');
        for (final band in MiningBand.values) {
          final target = tester.getRect(
            find.byKey(Key('mining-depth-rail-${band.name}')),
          );
          expect(target.width, greaterThanOrEqualTo(44 - .01));
          expect(target.height, greaterThanOrEqualTo(44 - .01));
          expect(
            target.overlaps(sell),
            isFalse,
            reason: '${band.name} $target covers Sell $sell',
          );
        }

        // Tapping the Pockets target centre runs the band action, never the
        // Sell control that shares this HUD strip.
        final pockets = tester.getRect(
          find.byKey(const Key('mining-depth-rail-pockets')),
        );
        final before = _scrollPosition(tester).pixels;
        await tester.tapAt(pockets.center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          sold,
          isFalse,
          reason: 'Pockets centre ${pockets.center} hit Sell',
        );
        expect(taps, isEmpty, reason: 'the Pockets tap must not reach the map');
        expect(
          _scrollPosition(tester).pixels,
          isNot(closeTo(before, .5)),
          reason: 'the Pockets band action must run',
        );

        // The row also stays clear of every legal cell centre at max scroll.
        final position = _scrollPosition(tester);
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        final center = _cellPoint(tester, const MiningGridCell(5, 21));
        expect(
          rail.contains(center),
          isFalse,
          reason: 'rail $rail centre $center',
        );
        _expectRailClearOfLegalCellCentres(tester, const [
          MiningGridCell(5, 21),
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'keeps landscape edge rigs scrollable clear of the toolbar and rail',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(874, 402);
      tester.view.padding = const FakeViewPadding(
        left: 44,
        top: 0,
        right: 44,
        bottom: 21,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });
      final initial = MiningSave.initial(nowUtc: _start);
      final state = initial.copyWith(
        technology: const TechnologyLevels(surveying: 5),
        sites: {
          ...initial.sites,
          MiningSiteId.landingBasin: _progress(
            unlocked: true,
            commissioned: true,
            rigs: const [
              MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(2, 1)),
              MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(7, 21)),
            ],
          ),
        },
      );
      final cellTaps = <MiningGridCell>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          builder: (context, child) =>
              Material(type: MaterialType.transparency, child: child!),
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 100,
            onGridCellTap: cellTaps.add,
            onBayTap: (_) {},
            onSpawnRig: () {},
            onBuildRig: (_) {},
            onSellCargo: () {},
            onBack: () {},
            onSettings: () {},
          ),
        ),
      );
      await tester.pump();

      final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
      final cargo = tester.getRect(find.byKey(const Key('mine-site-cargo')));
      final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
      expect(rail.top, greaterThanOrEqualTo(cargo.bottom));
      expect(rail.bottom, lessThanOrEqualTo(402 - 21));
      final buttons = [
        for (final band in MiningBand.values.reversed)
          tester.getRect(find.byKey(Key('mining-depth-rail-${band.name}'))),
      ];
      expect(buttons.map((rect) => rect.left).toSet(), hasLength(1));
      expect(rail.height, 224, reason: 'four 44dp targets plus 3x16dp gaps');
      for (var i = 0; i < buttons.length; i++) {
        expect(buttons[i].height, greaterThanOrEqualTo(44 - .01));
        if (i > 0) {
          expect(buttons[i].top - buttons[i - 1].top, 60);
        }
        for (final chrome in _hudRects(tester)) {
          expect(
            buttons[i].overlaps(chrome),
            isFalse,
            reason: 'button vs $chrome',
          );
        }
      }
      expect(buttons.last.bottom, lessThanOrEqualTo(402 - 21));
      final band = _unoccludedLandscapeBand(
        cavern.size,
        left: 44,
        bottom: 157,
      ).shift(cavern.topLeft);
      await _expectEdgeCellsTappable(
        tester,
        band: band,
        cavern: cavern,
        hud: _hudRects(tester),
        cellTaps: cellTaps,
        overlays: _edgeCellOverlays,
      );
    },
  );

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    testWidgets('scrolls top and bottom edge rigs clear of portrait HUD at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final initial = MiningSave.initial(nowUtc: _start);
      // Surveying 5 exposes the full field; rigs on the top and bottom
      // perimeter-legal edge cells each mine their adjacent resource.
      final state = initial.copyWith(
        technology: const TechnologyLevels(surveying: 5),
        sites: {
          ...initial.sites,
          MiningSiteId.landingBasin: _progress(
            unlocked: true,
            commissioned: true,
            rigs: const [
              MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(2, 1)),
              MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(7, 21)),
            ],
          ),
        },
      );
      final cellTaps = <MiningGridCell>[];
      await _pumpMineSite(
        tester,
        size: size,
        view: _siteView(state),
        dock: _dockView(state),
        onGridCellTap: cellTaps.add,
      );

      final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
      final cargo = tester.getRect(find.byKey(const Key('mine-site-cargo')));
      final sell = _sellControlRect(tester);
      final band = Rect.fromLTRB(0, cargo.bottom + 8, size.width, sell.top);
      await _expectEdgeCellsTappable(
        tester,
        band: band,
        cavern: cavern,
        hud: _hudRects(tester),
        cellTaps: cellTaps,
        overlays: _edgeCellOverlays,
      );
    });
  }

  testWidgets('frames the highest open band once per site entry', (
    tester,
  ) async {
    final state = _stateWithTwoSites(landingCargo: 0, carbonCargo: 0);
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(state),
      dock: _dockView(state),
    );
    final scale =
        tester.getRect(find.byKey(const Key('mining-grid-surface'))).width /
        miningGridSceneWidth;
    final topPadding = tester
        .getRect(find.byKey(const Key('mine-site-cargo')))
        .bottom;
    expect(
      _scrollPosition(tester).pixels,
      closeTo(
        math.min(
          topPadding + MiningBand.seams.labelRow * miningGridCellSize * scale,
          _scrollPosition(tester).maxScrollExtent,
        ),
        .5,
      ),
    );

    // A fresh entry at Surveying 5 frames the all-open Motherlode instead.
    await tester.pumpWidget(const SizedBox.shrink());
    final surveyed = state.copyWith(
      technology: const TechnologyLevels(surveying: 5),
    );
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(surveyed),
      dock: _dockView(surveyed),
    );
    // Motherlode row 0 target is exactly the map's top padding, so the
    // scene top sits at the map's top edge and the label rides at y=0.
    expect(_scrollPosition(tester).pixels, closeTo(topPadding, .5));
    expect(
      tester.getRect(find.byKey(const Key('mining-band-label-motherlode'))).top,
      closeTo(tester.getRect(find.byKey(const Key('mining-grid-map'))).top, .5),
    );
  });

  testWidgets('live Surveying updates the rail without stealing the scroll', (
    tester,
  ) async {
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(state),
      dock: _dockView(state),
    );
    _scrollPosition(tester).jumpTo(_scrollPosition(tester).pixels + 120);
    await tester.pump();
    final scrolled = _scrollPosition(tester).pixels;

    final surveyed = state.copyWith(
      technology: const TechnologyLevels(surveying: 2),
    );
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(surveyed),
      dock: _dockView(surveyed),
    );

    expect(_scrollPosition(tester).pixels, scrolled);
    expect(find.text('Surveying 1 opens the lodes'), findsNothing);
    expect(find.text('Surveying 2 opens the motherlode'), findsNothing);
  });

  testWidgets('right-column legal cells stay tappable beside the rail', (
    tester,
  ) async {
    final taps = <MiningGridCell>[];
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      size: const Size(360, 640),
      view: _siteView(state),
      dock: _dockView(state),
      onGridCellTap: taps.add,
    );

    for (final cell in const [MiningGridCell(7, 14), MiningGridCell(7, 21)]) {
      taps.clear();
      await tester.tapAt(await _scrollToCell(tester, cell));
      await tester.pump();
      expect(taps, <MiningGridCell>[cell], reason: '$cell');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the scroll position across the next-second view refresh', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
        ],
      ),
    );
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(state),
      dock: _dockView(state),
    );

    // The entry frame clamps to the maximum extent at this size, so an
    // upward drag cannot move from it. Drop to the top first: the drag then
    // produces a measured offset that would reveal a reframe on rebuild.
    _scrollPosition(tester).jumpTo(0);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('mining-grid-scroll')),
      const Offset(0, -120),
    );
    await tester.pump();
    final scrolled = _scrollPosition(tester).pixels;
    expect(scrolled, greaterThan(0));

    // The one-second foreground refresh supplies a fresh view instance
    // behind the same site key: the widget-local scroll must not jump.
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(state),
      dock: _dockView(state),
    );
    expect(_scrollPosition(tester).pixels, scrolled);
  });

  testWidgets('frames a fresh scroll on site change and re-entry', (
    tester,
  ) async {
    final state = _stateWithTwoSites(landingCargo: 0, carbonCargo: 0);
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(state),
      dock: _dockView(state),
    );
    final landingFrame = _scrollPosition(tester).pixels;
    _scrollPosition(tester).jumpTo(landingFrame + 100);
    await tester.pump();

    // The keyed map remounts on a site swap with its own fresh frame.
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(state, siteId: MiningSiteId.carbonRidge),
      dock: _dockView(state),
    );
    expect(_scrollPosition(tester).pixels, isNot(landingFrame + 100));

    // Re-entry after the map unmounts also frames fresh.
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpMineSite(
      tester,
      size: const Size(390, 844),
      view: _siteView(state),
      dock: _dockView(state),
    );
    expect(_scrollPosition(tester).pixels, closeTo(landingFrame, .5));
  });

  testWidgets(
    'keeps the map scroll and animated layer across an orientation change',
    (tester) async {
      final state = _stateWith(landing: _progress(commissioned: true));
      await _pumpMineSite(
        tester,
        size: const Size(390, 844),
        view: _siteView(state),
        dock: _dockView(state),
      );
      final layerFinder = find.byKey(
        const Key('landing-basin-grid-visual-layer'),
      );
      final layer = tester.state(layerFinder);
      _scrollPosition(tester).jumpTo(100);
      await tester.pump();

      // Crossing the breakpoint must keep the map in its slot: a remount
      // would reframe the highest open band and reset transient animation.
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      expect(find.byKey(const Key('mine-site-right-rail')), findsOneWidget);
      expect(find.byKey(const Key('mine-site-back')), findsNothing);
      expect(identical(tester.state(layerFinder), layer), isTrue);
      expect(_scrollPosition(tester).pixels, 100);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(find.byKey(const Key('mine-site-back')), findsOneWidget);
      expect(identical(tester.state(layerFinder), layer), isTrue);
      expect(_scrollPosition(tester).pixels, 100);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fits the scroll map at every supported viewport', (
    tester,
  ) async {
    final state = _stateWith(
      cash: 412,
      landing: _progress(
        commissioned: true,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
        ],
      ),
    );
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(430, 932),
      Size(874, 402),
      Size(1024, 768),
    ]) {
      await _pumpMineSite(
        tester,
        size: size,
        view: _siteView(state),
        dock: _dockView(state),
      );
      expect(tester.takeException(), isNull, reason: '$size');

      final map = tester.getRect(find.byKey(const Key('mining-grid-map')));
      final background = tester.getRect(
        find.byKey(const Key('mining-grid-background')),
      );
      final surface = tester.getRect(
        find.byKey(const Key('mining-grid-surface')),
      );
      expect(background.size, map.size, reason: 'full-bleed $size');
      expect(surface.width, lessThanOrEqualTo(miningGridSceneWidth + .01));
      expect(surface.left, greaterThanOrEqualTo(map.left - .01));
      expect(surface.right, lessThanOrEqualTo(map.right + .01));
      expect(
        find.byKey(const Key('mining-grid-scroll')),
        findsOneWidget,
        reason: 'scroll-only map $size',
      );
      expect(find.byKey(const Key('mining-depth-rail')), findsOneWidget);

      final cell = surface.width / miningGridWidth;
      expect(cell, lessThanOrEqualTo(miningGridCellSize + .01));
      if (size.width == 360) {
        expect(cell, greaterThanOrEqualTo(44), reason: '360 cell $cell');
      }
    }
  });

  testWidgets('band labels and lock chips are non-interactive overlays', (
    tester,
  ) async {
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));

    for (final band in MiningBand.values) {
      final label = find.byKey(Key('mining-band-label-${band.name}'));
      expect(label, findsOneWidget);
      expect(
        find.descendant(of: label, matching: find.byType(IgnorePointer)),
        findsOneWidget,
        reason: band.name,
      );
    }
    for (final band in [MiningBand.lodes, MiningBand.motherlode]) {
      final chip = find.byKey(Key('mining-band-lock-${band.name}'));
      expect(chip, findsOneWidget, reason: band.name);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: chip, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
        reason: band.name,
      );
    }
  });

  testWidgets('near-square landscape window uses landscape cavern layout', (
    tester,
  ) async {
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      size: const Size(1000, 950),
      view: _siteView(state),
      dock: _dockView(state),
    );
    // In 1000x950, cavern width (1000 - 180 = 820) is narrower than height (950),
    // but the screen orientation is landscape so the cavern must use landscape.
    expect(find.byKey(const Key('mine-site-right-rail')), findsOneWidget);
    expect(find.byKey(const Key('mine-site-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('mine-site-cargo')), findsOneWidget);
    final cargoRect = tester.getRect(find.byKey(const Key('mine-site-cargo')));
    expect(cargoRect.top, 52.0);
  });

  testWidgets('BUILD forwards its displayed tier on portrait', (tester) async {
    final built = <RigTier>[];
    final state = _stateWith(cash: 200, landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      view: _siteView(state),
      dock: _dockView(state),
      onBuildRig: built.add,
    );

    final pill = find.byKey(const Key('fleet-dock-build'));
    expect(pill, findsOneWidget);
    expect(find.text('BUILD T4 · 200'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Build a T4 rig for 200 cash.'),
      findsOneWidget,
    );
    for (final bay in DockBayId.values) {
      expect(find.byKey(ValueKey<String>(bay.name)), findsOneWidget);
    }
    expect(find.byKey(const Key('fleet-dock-spawn')), findsOneWidget);

    await tester.tap(pill);
    await tester.pump();
    expect(built, [RigTier.t4]);
  });

  testWidgets('BUILD hides below T2 or on a full dock and disables on busy', (
    tester,
  ) async {
    final state = _stateWith(cash: 25, landing: _progress(commissioned: true));
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));
    expect(find.byKey(const Key('fleet-dock-build')), findsNothing);

    final full = _stateWith(cash: 1000, landing: _progress(commissioned: true))
        .copyWith(
          docks: {
            ...MiningSave.initial(nowUtc: _start).docks,
            MiningPlanetId.homeworld: const {
              DockBayId.b1: RigTier.t1,
              DockBayId.b2: RigTier.t1,
              DockBayId.b3: RigTier.t1,
              DockBayId.b4: RigTier.t1,
            },
          },
        );
    await _pumpMineSite(tester, view: _siteView(full), dock: _dockView(full));
    expect(find.byKey(const Key('fleet-dock-build')), findsNothing);

    final built = <RigTier>[];
    await _pumpMineSite(
      tester,
      view: _siteView(full, isBusy: true),
      dock: _dockView(full, isBusy: true),
      onBuildRig: built.add,
    );
    expect(find.byKey(const Key('fleet-dock-build')), findsNothing);

    final busyState = _stateWith(
      cash: 1000,
      landing: _progress(commissioned: true),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(busyState, isBusy: true),
      dock: _dockView(busyState, isBusy: true),
      onBuildRig: built.add,
    );
    final pill = find.byKey(const Key('fleet-dock-build'));
    expect(pill, findsOneWidget);
    expect(find.bySemanticsLabel('Finishing previous action…'), findsWidgets);
    await tester.tap(pill, warnIfMissed: false);
    await tester.pump();
    expect(built, isEmpty);
  });

  testWidgets('BUILD stays reachable inside the landscape right rail', (
    tester,
  ) async {
    final built = <RigTier>[];
    final state = _stateWith(cash: 200, landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      size: const Size(874, 402),
      view: _siteView(state),
      dock: _dockView(state),
      onBuildRig: built.add,
    );

    final pill = find.byKey(const Key('fleet-dock-build'));
    expect(pill, findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const Key('mine-site-right-rail')))
          .contains(tester.getRect(pill).center),
      isTrue,
    );
    await tester.tap(pill);
    await tester.pump();
    expect(built, [RigTier.t4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BUILD and the dock hint fit every supported size', (
    tester,
  ) async {
    final state = _stateWith(cash: 200, landing: _progress(commissioned: true));
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(430, 932),
      Size(874, 402),
    ]) {
      await _pumpMineSite(
        tester,
        size: size,
        view: _siteView(state, selectedBayId: DockBayId.b1),
        dock: _dockView(state, selectedBayId: DockBayId.b1),
      );
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.byKey(const Key('fleet-dock-build')), findsOneWidget);
      expect(find.byKey(const Key('fleet-dock-spawn')), findsOneWidget);
    }
  });

  testWidgets('keeps the selected-dock hint legible at 360 px', (tester) async {
    final state = _stateWith(cash: 200, landing: _progress(commissioned: true));
    var height = 0.0;
    for (final textScale in const [1.0, 1.3]) {
      await _pumpMineSite(
        tester,
        size: const Size(360, 640),
        view: _siteView(state, selectedBayId: DockBayId.b1),
        dock: _dockView(state, selectedBayId: DockBayId.b1),
        textScale: textScale,
      );

      final hint = find.byKey(const Key('fleet-dock-hint'));
      expect(tester.widget<Text>(hint).data, 'DEPLOY · UPGRADE · MERGE');
      final render = tester.renderObject<RenderParagraph>(hint);
      expect(
        render.text.style?.fontFamily,
        'Orbitron',
        reason: 'the hint must measure the shipped font, not the test fallback',
      );
      expect(
        render.didExceedMaxLines,
        isFalse,
        reason: 'textScale $textScale must not truncate the hint',
      );
      if (!kIsWeb) {
        final text = render.text.toPlainText();
        final lineTops = render
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.length),
            )
            .map((box) => box.top)
            .toSet();
        expect(
          lineTops.length,
          1,
          reason:
              'shipped Orbitron keeps the hint on one line at 360 px '
              '(textScale $textScale)',
        );
        expect(
          render.getMaxIntrinsicWidth(double.infinity),
          closeTo(textScale == 1.0 ? 166.0935821533203 : 211.6016845703125, 4),
          reason: 'textScale $textScale must measure shipped Orbitron widths',
        );
      }
      final bounds = MatrixUtils.transformRect(
        render.getTransformTo(null),
        render.paintBounds,
      );
      expect(
        bounds.height / render.size.height,
        greaterThanOrEqualTo(.9),
        reason:
            'textScale $textScale scale factor '
            '${bounds.height / render.size.height}',
      );
      expect(
        bounds.height,
        greaterThanOrEqualTo(10),
        reason: 'textScale $textScale transformed height ${bounds.height}',
      );
      if (textScale == 1.3) {
        expect(
          bounds.height,
          greaterThan(height * 1.15),
          reason: 'textScale 1.3 height ${bounds.height} vs 1.0 height $height',
        );
      }
      height = bounds.height;
      expect(tester.takeException(), isNull, reason: 'textScale $textScale');
    }
  });

  testWidgets('BUILD exposes a semantic tap action that forwards its tier', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final built = <RigTier>[];
    final state = _stateWith(cash: 200, landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      view: _siteView(state),
      dock: _dockView(state),
      onBuildRig: built.add,
    );

    tester.semantics.performAction(
      find.semantics.byLabel('Build a T4 rig for 200 cash.'),
      SemanticsAction.tap,
    );
    expect(built, [RigTier.t4]);
    handle.dispose();
  });

  testWidgets('BUILD takes keyboard focus and activates its displayed tier', (
    tester,
  ) async {
    final built = <RigTier>[];
    final state = _stateWith(cash: 200, landing: _progress(commissioned: true));
    await _pumpMineSite(
      tester,
      view: _siteView(state),
      dock: _dockView(state),
      onBuildRig: built.add,
    );

    final pill = find.byKey(const Key('fleet-dock-build'));
    final focusContext = tester.element(
      find.descendant(of: pill, matching: find.byType(GestureDetector)),
    );
    final focusNode = Focus.of(focusContext);
    expect(focusNode.canRequestFocus, isTrue);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(built, <RigTier>[RigTier.t4]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(built, <RigTier>[RigTier.t4, RigTier.t4]);
  });

  testWidgets('busy BUILD cannot be focused or keyboard-activated', (
    tester,
  ) async {
    final built = <RigTier>[];
    final busyState = _stateWith(
      cash: 1000,
      landing: _progress(commissioned: true),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(busyState, isBusy: true),
      dock: _dockView(busyState, isBusy: true),
      onBuildRig: built.add,
    );

    final pill = find.byKey(const Key('fleet-dock-build'));
    final focusContext = tester.element(
      find.descendant(of: pill, matching: find.byType(GestureDetector)),
    );
    final focusNode = Focus.of(focusContext);
    expect(focusNode.canRequestFocus, isFalse);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(built, isEmpty);
  });

  testWidgets('BUILD keeps at least a 44 px touch target at every size', (
    tester,
  ) async {
    final state = _stateWith(cash: 200, landing: _progress(commissioned: true));
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(430, 932),
      Size(874, 402),
    ]) {
      await _pumpMineSite(
        tester,
        size: size,
        view: _siteView(state),
        dock: _dockView(state),
      );
      final pill = find.byKey(const Key('fleet-dock-build'));
      final target = tester.getSize(pill);
      expect(target.width, greaterThanOrEqualTo(44), reason: '$size width');
      expect(target.height, greaterThanOrEqualTo(44), reason: '$size height');
      final pillRect = tester.getRect(pill);
      final spawnRect = tester.getRect(
        find.byKey(const Key('fleet-dock-spawn')),
      );
      expect(
        pillRect.bottom,
        lessThanOrEqualTo(spawnRect.top),
        reason: '$size header position',
      );
      expect(pillRect.overlaps(spawnRect), isFalse, reason: '$size spawn');
      for (final bay in DockBayId.values) {
        final bayRect = tester.getRect(find.byKey(ValueKey<String>(bay.name)));
        expect(
          pillRect.overlaps(bayRect),
          isFalse,
          reason: '$size ${bay.name}',
        );
      }
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('BUILD renders a readable unrotated header label', (
    tester,
  ) async {
    final state = _stateWith(cash: 200, landing: _progress(commissioned: true));
    for (final textScale in const [1.0, 1.3]) {
      await _pumpMineSite(
        tester,
        size: const Size(360, 640),
        view: _siteView(state),
        dock: _dockView(state),
        textScale: textScale,
      );
      final label = find.text('BUILD T4 · 200');
      expect(label, findsOneWidget, reason: 'textScale $textScale');
      expect(
        find.ancestor(of: label, matching: find.byType(RotatedBox)),
        findsNothing,
        reason: 'textScale $textScale rotation',
      );
      final render = tester.renderObject<RenderParagraph>(label);
      final bounds = MatrixUtils.transformRect(
        render.getTransformTo(null),
        render.paintBounds,
      );
      expect(
        bounds.height,
        greaterThanOrEqualTo(5),
        reason: 'textScale $textScale transformed height ${bounds.height}',
      );
      final spawnRect = tester.getRect(
        find.byKey(const Key('fleet-dock-spawn')),
      );
      expect(
        bounds.bottom,
        lessThanOrEqualTo(spawnRect.top),
        reason: 'textScale $textScale header position',
      );
      expect(tester.takeException(), isNull, reason: 'textScale $textScale');
    }

    await _pumpMineSite(
      tester,
      size: const Size(874, 402),
      view: _siteView(state),
      dock: _dockView(state),
    );
    final railLabel = find.text('BUILD T4 · 200');
    expect(railLabel, findsOneWidget);
    expect(
      find.ancestor(of: railLabel, matching: find.byType(RotatedBox)),
      findsNothing,
    );
    final railRender = tester.renderObject<RenderParagraph>(railLabel);
    final railBounds = MatrixUtils.transformRect(
      railRender.getTransformTo(null),
      railRender.paintBounds,
    );
    expect(
      railBounds.height,
      greaterThanOrEqualTo(5),
      reason: 'rail transformed height ${railBounds.height}',
    );
  });
}
