import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

final _start = DateTime.utc(2026, 8, 26, 12);
final _content = MiningContentRegistry.stellarMining();

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

FleetDockView _dockView(MiningSave state, {DockBayId? selectedBayId}) =>
    FleetDockView.from(
      state: state,
      content: _content,
      selectedBayId: selectedBayId,
      isBusy: false,
    );

Future<void> _pumpMineSite(
  WidgetTester tester, {
  required MineSiteView view,
  required FleetDockView dock,
  Size size = const Size(360, 640),
  bool disableAnimations = false,
  int impactSequence = 0,
  ValueChanged<MiningGridCell>? onGridCellTap,
  ValueChanged<DockBayId>? onBayTap,
  VoidCallback? onSpawnRig,
  VoidCallback? onSellCargo,
  VoidCallback? onBack,
  VoidCallback? onSettings,
  ValueChanged<MiningNavigationDestination>? onDestinationSelected,
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
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(1.3),
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
  return surface.topLeft +
      Offset(
        (cell.x + .5) * miningGridCellSize,
        (cell.y + .5) * miningGridCellSize,
      );
}

// Resolve the finite gold frame set in real async before the Landing Basin
// layer mounts, so its _precacheFrames Future.wait completes from cache hits
// and _framesReady becomes true via actual precache completion (the deferral
// budget drops a stalled impact, it does not fire it).
Future<void> _warmGoldFrames(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final path in [
      for (var stage = 1; stage <= 4; stage++)
        MiningVisuals.goldNodeStageAsset(stage),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeIdleAsset(frame),
      for (var frame = 1; frame <= 3; frame++)
        MiningVisuals.goldNodeHitAsset(frame),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeExhaustAsset(frame),
    ]) {
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pump();
}

void main() {
  testWidgets(
    'uses the Landing Basin grid layer for an occupied T1 rig',
    (tester) async {
      // Warm the finite gold frames in real async so the layer's
      // _framesReady becomes true via actual precache completion (see
      // landing_basin_grid_visual_layer_test for the rationale).
      await _warmGoldFrames(tester);
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
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
      expect(find.byKey(const Key('landing-basin-deposit-d1')), findsOneWidget);
      expect(find.byKey(const Key('landing-basin-robot-3-2')), findsOneWidget);

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
          of: find.byKey(const Key('landing-basin-deposit-d1')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    MiningVisuals.goldNodeHitAsset(1),
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
          rigs: const [
            MiningRigPlacement(tier: RigTier.t4, cell: MiningGridCell(3, 2)),
            MiningRigPlacement(tier: RigTier.t3, cell: MiningGridCell(16, 2)),
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
        const MiningGridCell(3, 2): RigTier.t4,
        const MiningGridCell(16, 2): RigTier.t3,
      }.entries) {
        final cell = entry.key;
        final tier = entry.value;
        expect(
          find.byKey(Key('landing-basin-robot-${cell.x}-${cell.y}')),
          findsOneWidget,
        );
        for (final assetPath in [
          MiningVisuals.landingBasinRobotBodyAsset(tier),
          MiningVisuals.landingBasinRobotArmAsset(tier),
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

  testWidgets('keeps non-gold sites on the static deposit and rig art', (
    tester,
  ) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final state = initial.copyWith(
      sites: {
        ...initial.sites,
        MiningSiteId.carbonRidge: _progress(
          unlocked: true,
          commissioned: true,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(5, 1)),
          ],
        ),
      },
    );
    final view = _siteView(state, siteId: MiningSiteId.carbonRidge);
    await _pumpMineSite(
      tester,
      impactSequence: 1,
      view: view,
      dock: _dockView(state),
    );

    expect(
      find.byKey(const Key('landing-basin-grid-visual-layer')),
      findsNothing,
    );
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
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
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
    // The fixed-node rects are replaced by the grid viewport/object contract:
    // the pan/zoom viewport starts at the cavern origin and d1's overlay sits
    // on its logical footprint.
    expect(
      tester.getRect(find.byKey(const Key('mining-grid-interactive'))).topLeft,
      Offset.zero,
    );
    expect(
      tester.getRect(find.byKey(const Key('mining-deposit-d1'))).topLeft,
      const Offset(3 * miningGridCellSize, 3 * miningGridCellSize),
    );
    final sell = tester.getRect(find.byKey(const Key('mine-site-sell')));
    expect(sell.top, 506);
    expect(sell.right, closeTo(382, 4));
  });

  testWidgets(
    'forwards bay, grid cell, sale, back, settings, and nav callbacks',
    (tester) async {
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          storedAmount: 10,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(16, 2)),
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
      await tester.tapAt(_cellPoint(tester, const MiningGridCell(3, 2)));
      await tester.tap(find.byKey(const Key('mine-site-sell')));
      await tester.tap(find.byKey(const Key('mine-site-back')));
      await tester.tap(find.byKey(const Key('mining-nav-settings')));
      await tester.tap(find.byKey(const Key('mining-nav-technology')));

      expect(bayTaps, <DockBayId>[DockBayId.b1]);
      expect(cellTaps, <MiningGridCell>[const MiningGridCell(3, 2)]);
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
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
        ],
      ),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(state, selectedBayId: DockBayId.b1),
      dock: _dockView(state, selectedBayId: DockBayId.b1),
    );

    expect(find.bySemanticsLabel(RegExp(r'Dock bay B1')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Deposit D1')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'T1 rig at \(3,2\)')), findsOneWidget);
    final d1 = tester.getRect(find.byKey(const Key('mining-deposit-d1')));
    expect(d1.width, miningGridCellSize);
    expect(d1.height, miningGridCellSize);
  });

  testWidgets('anchors the cash chip and cargo gauge over portrait art', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        storedAmount: 10,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t2, cell: MiningGridCell(3, 2)),
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

  testWidgets('binds sale control to active-planet aggregate cargo and value', (
    tester,
  ) async {
    final state = _stateWithTwoSites(landingCargo: 0, carbonCargo: 10);
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));

    expect(
      find.bySemanticsLabel(RegExp(r'Sell all cargo for 30 cash')),
      findsOneWidget,
    );
    expect(find.text('+30'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('mine-site-sell')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('keeps sub-1-cash cargo unsellable with keep-mining feedback', (
    tester,
  ) async {
    // 0.1 Gold at Landing Basin (4 cash/unit) = 0.4 gross, which floors to 0.
    final state = _stateWith(
      landing: _progress(commissioned: true, storedAmount: 0.1),
    );
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));

    expect(
      find.bySemanticsLabel(
        RegExp(r'Keep mining until cargo is worth at least 1 cash'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('mine-site-sell')))
          .onPressed,
      isNull,
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

  testWidgets(
    'exposes recall capacity rejection copy without enabling recall',
    (tester) async {
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          storedAmount: 150,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(16, 2)),
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
          RegExp(r'T1 rig at \(3,2\).*Sell cargo before recalling this rig'),
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
              widget.properties.label!.contains('T1 rig at (3,2)'),
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
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
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
      final viewport = tester.getRect(
        find.byKey(const Key('mining-grid-interactive')),
      );
      expect(cavern.contains(viewport.topLeft), isTrue);
      expect(
        cavern.contains(viewport.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
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
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
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

    expect(find.byKey(const Key('mining-grid-interactive')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked deposits render their authored Surveying requirement', (
    tester,
  ) async {
    // Landing Basin d3 requires Surveying 1 and d4 requires Surveying 2; with
    // default Surveying 0 both show their authored LV badges, not a hard-coded
    // 'LV 1' for every locked deposit.
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));

    expect(find.text('LV 1'), findsOneWidget);
    expect(find.text('LV 2'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Deposit D3.*Surveying 1')),
      findsOneWidget,
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
          rigs: const [
            MiningRigPlacement(tier: RigTier.t2, cell: MiningGridCell(3, 2)),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 100,
            onGridCellTap: (_) {},
            onBayTap: (_) {},
            onSpawnRig: () {},
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
          rigs: const [
            MiningRigPlacement(tier: RigTier.t2, cell: MiningGridCell(3, 2)),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 100,
            onGridCellTap: (_) {},
            onBayTap: (_) {},
            onSpawnRig: () {},
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
      // Cavern art stays full-bleed on the left edge, and the pannable grid
      // viewport starts at the cavern origin: cells can be dragged clear of
      // the cutout instead of being hard-inset like the old fixed nodes.
      final viewport = tester.getRect(
        find.byKey(const Key('mining-grid-interactive')),
      );
      expect(viewport.left, 0);
      expect(viewport.left, lessThanOrEqualTo(cavern.left + 0.1));
      // The vertical fleet dock stops above the home-indicator inset: the last
      // bay (b4) must not extend into the bottom 21 px.
      final lastBay = tester.getRect(find.byKey(const ValueKey<String>('b4')));
      expect(lastBay.bottom, lessThanOrEqualTo(402 - padBottom));
    },
  );
}
