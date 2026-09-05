import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

final _start = DateTime.utc(2026, 8, 26, 12);
final _content = MiningContentRegistry.stellarMining();

SiteProgress _progress({
  bool unlocked = true,
  bool commissioned = false,
  double storedAmount = 0,
  Map<MiningNodeId, RigTier?>? rigs,
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigByNode: rigs ?? {for (final node in MiningNodeId.values) node: null},
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
      MiningSiteId.landingBasin: SiteProgress(
        unlocked: true,
        commissioned: true,
        storedAmount: landingCargo,
        rigByNode: {for (final node in MiningNodeId.values) node: null},
      ),
      MiningSiteId.carbonRidge: SiteProgress(
        unlocked: true,
        commissioned: true,
        storedAmount: carbonCargo,
        rigByNode: {for (final node in MiningNodeId.values) node: null},
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
  ValueChanged<MiningNodeId>? onNodeTap,
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
          onNodeTap: onNodeTap ?? (_) {},
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

// Resolve the finite gold frame set in real async before the Landing Basin
// visual mounts, so its _precacheFrames Future.wait completes from cache hits
// and _framesReady becomes true via actual precache completion (the deferral
// budget drops a stalled impact, it does not fire it). A bare host gives
// precacheImage a Directionality context; the global image cache persists
// across the subsequent pumpWidget that mounts the MineSiteScreen.
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
    'uses the Landing Basin prototype for an occupied T1 node',
    (tester) async {
      // Warm the finite gold frames in real async so the visual's
      // _framesReady becomes true via actual precache completion; the deferral
      // budget drops a stalled impact rather than firing it (see
      // landing_basin_mining_node_visual for the rationale).
      await _warmGoldFrames(tester);
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          rigs: {MiningNodeId.n1: RigTier.t1},
        ),
      );
      await _pumpMineSite(
        tester,
        size: const Size(402, 874),
        view: _siteView(state),
        dock: _dockView(state),
      );

      expect(find.byKey(const Key('landing-basin-deposit-n1')), findsOneWidget);
      expect(find.byKey(const Key('landing-basin-robot-n1')), findsOneWidget);
      expect(find.byKey(const Key('mine-site-node-n1')), findsOneWidget);

      await _pumpMineSite(
        tester,
        size: const Size(402, 874),
        impactSequence: 1,
        view: _siteView(state),
        dock: _dockView(state),
      );
      // With the finite frames warmed, _framesReady is true and the one-shot
      // impact fires immediately on the sequence change (no deferral budget).
      // Advance into the S1 hit window.
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: find.byKey(const Key('landing-basin-deposit-n1')),
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
    // Basin keys are covered on web by the deposit-variants test below.
    skip: kIsWeb,
  );

  testWidgets(
    'selects Landing Basin deposit variants and articulated robot tiers per occupied node',
    (tester) async {
      final state = _stateWith(
        landing: _progress(
          commissioned: true,
          rigs: {MiningNodeId.n1: RigTier.t4, MiningNodeId.n2: RigTier.t3},
        ),
      );
      await _pumpMineSite(
        tester,
        size: const Size(402, 874),
        view: _siteView(state),
        dock: _dockView(state),
      );

      for (final entry in {
        MiningNodeId.n1: RigTier.t4,
        MiningNodeId.n2: RigTier.t3,
      }.entries) {
        final node = entry.key.name;
        final tier = entry.value;
        expect(find.byKey(Key('landing-basin-deposit-$node')), findsOneWidget);
        expect(find.byKey(Key('landing-basin-robot-$node')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(Key('landing-basin-deposit-$node')),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName ==
                      MiningVisuals.goldNodeIdleAsset(1),
            ),
          ),
          findsOneWidget,
        );
        for (final assetPath in [
          MiningVisuals.landingBasinRobotBodyAsset(tier),
          MiningVisuals.landingBasinRobotArmAsset(tier),
        ]) {
          expect(
            find.descendant(
              of: find.byKey(Key('landing-basin-robot-$node')),
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

  testWidgets('keeps non-gold sites on the existing static node and rig art', (
    tester,
  ) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final state = initial.copyWith(
      sites: {
        ...initial.sites,
        MiningSiteId.carbonRidge: _progress(
          commissioned: true,
          rigs: {MiningNodeId.n1: RigTier.t1},
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

    expect(find.byKey(const Key('landing-basin-deposit-n1')), findsNothing);
    expect(find.byKey(const Key('landing-basin-robot-n1')), findsNothing);
    final n1 = find.byKey(const Key('mine-site-node-n1'));
    expect(
      find.descendant(
        of: n1,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  view.definition.nodeAsset,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: n1,
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
        rigs: {MiningNodeId.n1: RigTier.t1, MiningNodeId.n3: RigTier.t2},
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
    expect(
      tester.getRect(find.byKey(const Key('mine-site-node-n1'))).topLeft,
      const Offset(18, 222),
    );
    expect(
      tester.getRect(find.byKey(const Key('mine-site-node-n2'))).topLeft,
      const Offset(236, 186),
    );
    final sell = tester.getRect(find.byKey(const Key('mine-site-sell')));
    expect(sell.top, 506);
    expect(sell.right, closeTo(382, 4));
  });

  testWidgets('forwards bay, node, sale, back, settings, and nav callbacks', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        storedAmount: 10,
        rigs: {MiningNodeId.n2: RigTier.t1},
      ),
    );
    final selected = _siteView(state, selectedBayId: DockBayId.b1);
    final bayTaps = <DockBayId>[];
    final nodeTaps = <MiningNodeId>[];
    final destinations = <MiningNavigationDestination>[];
    var sold = false;
    var backed = false;
    var settings = false;

    await _pumpMineSite(
      tester,
      view: selected,
      dock: _dockView(state, selectedBayId: DockBayId.b1),
      onNodeTap: nodeTaps.add,
      onBayTap: bayTaps.add,
      onSellCargo: () => sold = true,
      onBack: () => backed = true,
      onSettings: () => settings = true,
      onDestinationSelected: destinations.add,
    );

    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.tap(find.byKey(const Key('mine-site-node-n1')));
    await tester.tap(find.byKey(const Key('mine-site-sell')));
    await tester.tap(find.byKey(const Key('mine-site-back')));
    await tester.tap(find.byKey(const Key('mining-nav-settings')));
    await tester.tap(find.byKey(const Key('mining-nav-technology')));

    expect(bayTaps, <DockBayId>[DockBayId.b1]);
    expect(nodeTaps, <MiningNodeId>[MiningNodeId.n1]);
    expect(sold, isTrue);
    expect(backed, isTrue);
    expect(settings, isTrue);
    expect(destinations, <MiningNavigationDestination>[
      MiningNavigationDestination.technology,
    ]);
  });

  testWidgets('keeps selected bay and node semantics accessible', (
    tester,
  ) async {
    final state = _stateWith();
    await _pumpMineSite(
      tester,
      view: _siteView(state, selectedBayId: DockBayId.b1),
      dock: _dockView(state, selectedBayId: DockBayId.b1),
    );

    expect(find.bySemanticsLabel(RegExp(r'Dock bay B1')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Node N1')), findsOneWidget);
    for (final node in MiningNodeId.values) {
      final control = find.byKey(Key('mine-site-node-${node.name}'));
      expect(control, findsOneWidget);
      final size = tester.getSize(control);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('anchors the cash chip and cargo gauge over portrait art', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        storedAmount: 10,
        rigs: {MiningNodeId.n1: RigTier.t2},
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
          rigs: {MiningNodeId.n1: RigTier.t1, MiningNodeId.n2: RigTier.t1},
        ),
      );
      await _pumpMineSite(
        tester,
        view: _siteView(state),
        dock: _dockView(state),
      );

      expect(
        find.bySemanticsLabel(
          RegExp(r'Node N1.*Sell cargo before recalling this rig'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('mine-site-node-n1')))
            .onTap,
        isNotNull,
      );
    },
  );

  testWidgets('keeps every anchored node inside the cavern at portrait sizes', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        rigs: {MiningNodeId.n1: RigTier.t1},
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
      for (final node in MiningNodeId.values) {
        final rect = tester.getRect(
          find.byKey(Key('mine-site-node-${node.name}')),
        );
        expect(cavern.contains(rect.topLeft), isTrue);
        expect(
          cavern.contains(rect.bottomRight - const Offset(0.1, 0.1)),
          isTrue,
        );
      }
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
          rigs: {MiningNodeId.n1: RigTier.t1},
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

  // Landscape node left offsets are authored for the 874x402 prototype
  // (cavern 770px). N1-N3 keep their authored positions at every width; only
  // N4 (authored left 510) can overflow a narrower cavern, so when it would it
  // is anchored to the cavern's right edge instead of its authored left. At
  // 667x375 the cavern is 563px: N4's right edge sits at the cavern boundary
  // while N1-N3 stay put. N3 (left 307, right 401) must also stay clear of the
  // fixed Sell control (left 236, width 56 -> right 292), which is painted
  // later in the cavern Stack and would otherwise mask N3's tap target. At
  // 874x402 the right-anchor does not engage (covered by the 'fits landscape
  // cavern and controls inside the fixed right rail' test).
  testWidgets('keeps every landscape node inside the cavern at 667x375', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(commissioned: true, storedAmount: 10),
    );
    await _pumpMineSite(
      tester,
      size: const Size(667, 375),
      view: _siteView(state),
      dock: _dockView(state),
    );

    expect(tester.takeException(), isNull);
    final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
    expect(cavern, const Rect.fromLTWH(0, 0, 563, 375));

    // Every node, including N4, fits fully inside the narrower cavern.
    for (final node in MiningNodeId.values) {
      final rect = tester.getRect(
        find.byKey(Key('mine-site-node-${node.name}')),
      );
      expect(
        cavern.contains(rect.topLeft),
        isTrue,
        reason: '$node top-left should be inside the cavern at 667x375',
      );
      expect(
        cavern.contains(rect.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
        reason: '$node bottom-right should be inside the cavern at 667x375',
      );
    }

    // N3 keeps its authored left (307) and must not slide under the fixed Sell
    // control, which is painted later in the cavern Stack and would mask N3's
    // tap target. The earlier uniform scaling moved N3 to ~224 and overlapped
    // the Sell control (left 236, right 292).
    final n3 = tester.getRect(find.byKey(const Key('mine-site-node-n3')));
    final sell = tester.getRect(find.byKey(const Key('mine-site-sell')));
    expect(
      n3.overlaps(sell),
      isFalse,
      reason: 'N3 must not overlap the Sell control at 667x375',
    );
  });

  // At 667x375 an occupied N3 (width 150) and an occupied N4 (width 116)
  // cannot both fit inside the 563px cavern at their authored positions without
  // overlapping. N4 right-anchors to the cavern's right edge and N3 shifts left
  // so its occupied right edge plus a 4px gap reaches N4's left edge: both
  // occupied tap targets stay disjoint AND fully contained (N4 no longer clips
  // the cavern), and N3 stays clear of the fixed Sell control (right 292).
  testWidgets('keeps occupied N3 and N4 tap targets disjoint at 667x375', (
    tester,
  ) async {
    final state = _stateWith(
      landing: _progress(
        commissioned: true,
        storedAmount: 10,
        rigs: {MiningNodeId.n3: RigTier.t2, MiningNodeId.n4: RigTier.t1},
      ),
    );
    await _pumpMineSite(
      tester,
      size: const Size(667, 375),
      view: _siteView(state),
      dock: _dockView(state),
    );

    expect(tester.takeException(), isNull);
    final cavern = tester.getRect(find.byKey(const Key('mine-site-cavern')));
    final n3 = tester.getRect(find.byKey(const Key('mine-site-node-n3')));
    final n4 = tester.getRect(find.byKey(const Key('mine-site-node-n4')));
    final sell = tester.getRect(find.byKey(const Key('mine-site-sell')));
    expect(
      n3.overlaps(n4),
      isFalse,
      reason: 'Occupied N3 and N4 tap targets must not overlap at 667x375',
    );
    // N3 shifts left from its authored left (307) to 293 so N4 can right-anchor;
    // N3's occupied right edge (443) leaves a 4px gap to N4 and a 1px gap to the
    // fixed Sell control (right 292).
    expect(n3.left, 293);
    expect(n3.right, 443);
    expect(
      n3.overlaps(sell),
      isFalse,
      reason: 'Shifted N3 must not overlap the Sell control at 667x375',
    );
    // N4 right-anchors to the cavern's right edge and stays fully contained.
    expect(n4.left, 447);
    expect(n4.right, cavern.right);
    expect(
      cavern.contains(n4.bottomRight - const Offset(0.1, 0.1)),
      isTrue,
      reason: 'Occupied N4 must stay fully inside the cavern at 667x375',
    );
    expect(
      cavern.contains(n3.bottomRight - const Offset(0.1, 0.1)),
      isTrue,
      reason: 'Occupied N3 must stay fully inside the cavern at 667x375',
    );
  });

  testWidgets('reduced motion settles node feedback without overflow', (
    tester,
  ) async {
    final state = _stateWith();
    await _pumpMineSite(
      tester,
      disableAnimations: true,
      view: _siteView(state, selectedBayId: DockBayId.b1),
      dock: _dockView(state, selectedBayId: DockBayId.b1),
    );

    expect(find.byKey(const Key('mine-site-node-n1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked node renders its authored Surveying requirement', (
    tester,
  ) async {
    // Landing Basin N4 requires Surveying 2; with default Surveying 0 the
    // node is locked and must show 'LV 2', not the previous hard-coded 'LV 1'.
    final state = _stateWith(landing: _progress(commissioned: true));
    await _pumpMineSite(tester, view: _siteView(state), dock: _dockView(state));

    final n4 = find.byKey(const Key('mine-site-node-n4'));
    expect(n4, findsOneWidget);
    expect(
      find.descendant(of: n4, matching: find.text('LV 2')),
      findsOneWidget,
    );
    expect(find.descendant(of: n4, matching: find.text('LV 1')), findsNothing);
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
          rigs: {MiningNodeId.n1: RigTier.t2},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 100,
            onNodeTap: (_) {},
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
          rigs: {MiningNodeId.n1: RigTier.t2},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          home: MineSiteScreen(
            view: _siteView(state),
            fleetDock: _dockView(state),
            cash: 100,
            onNodeTap: (_) {},
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
      // The interactive node layer is translated past the left cutout: N1's
      // authored left is 22, which would sit under the 44 px cutout unless the
      // node layer is inset by pad.left.
      final nodeN1 = tester.getRect(find.byKey(const Key('mine-site-node-n1')));
      expect(nodeN1.left, greaterThanOrEqualTo(padLeft));
      // The vertical fleet dock stops above the home-indicator inset: the last
      // bay (b4) must not extend into the bottom 21 px.
      final lastBay = tester.getRect(find.byKey(const ValueKey<String>('b4')));
      expect(lastBay.bottom, lessThanOrEqualTo(402 - padBottom));
    },
  );
}
