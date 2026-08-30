import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';

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
}) => MineSiteView.from(
  state: state,
  content: _content,
  siteId: MiningSiteId.landingBasin,
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

void main() {
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

  // Characterizes the known narrow-landscape clip (CodeRabbit, PR #20).
  // The landscape node positions are authored for the 874x402 prototype
  // (cavern 770px). At 667x375 (cavern 563px) node N4's fixed left=510 plus
  // its 70px image overflows the cavern's Clip.antiAlias bounds (worse with a
  // rig column). This test locks in the current overflow so a future
  // responsive fix is a deliberate, verified change rather than a silent
  // regression. Flip the expectations (containment) when the layout derives
  // offsets from constraints.
  testWidgets('documents the narrow-landscape node N4 cavern clip at 667x375', (
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

    // Nodes N1, N2, N3 stay inside the cavern at this width.
    for (final node in [MiningNodeId.n1, MiningNodeId.n2, MiningNodeId.n3]) {
      final rect = tester.getRect(
        find.byKey(Key('mine-site-node-${node.name}')),
      );
      expect(
        cavern.contains(rect.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
        reason: '$node should fit inside the cavern at 667x375',
      );
    }

    // Node N4 (index 3, left=510, image width=70) overflows by >=17px even
    // when locked; a deployed rig column widens the overflow further.
    final n4 = tester.getRect(find.byKey(const Key('mine-site-node-n4')));
    expect(n4.left, 510);
    expect(n4.right, greaterThan(cavern.right));
    expect(n4.right - cavern.right, greaterThanOrEqualTo(17));
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
}
