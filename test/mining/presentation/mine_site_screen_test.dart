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
    MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(1.3),
      ),
      child: MaterialApp(
        home: MineSiteScreen(
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
    await tester.tap(find.byKey(const Key('mine-site-settings')));
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

  testWidgets('busy sale semantics explain the pending action', (tester) async {
    final state = _stateWith(
      landing: _progress(commissioned: true, storedAmount: 10),
    );
    await _pumpMineSite(
      tester,
      view: _siteView(state, isBusy: true),
      dock: _dockView(state),
    );

    final cargoSemantics = find
        .ancestor(
          of: find.byKey(const Key('mine-site-cargo')),
          matching: find.byType(Semantics),
        )
        .first;
    expect(
      tester.widget<Semantics>(cargoSemantics).properties.label,
      'Finishing previous action…',
    );
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
      expect(cavern.right, lessThanOrEqualTo(rail.left));
      expect(
        rail.contains(
          tester.getRect(find.byKey(const Key('mine-site-cargo'))).topLeft,
        ),
        isTrue,
      );
      expect(
        rail.contains(
          tester.getRect(find.byKey(const Key('fleet-dock'))).topLeft,
        ),
        isTrue,
      );
      expect(
        tester.getRect(find.byKey(const Key('mine-site-back'))).right,
        lessThanOrEqualTo(rail.left),
      );
      expect(
        tester.getRect(find.byKey(const Key('mine-site-settings'))).right,
        lessThanOrEqualTo(rail.left),
      );
    },
  );

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

    expect(find.byType(AnimatedSwitcher), findsWidgets);
    for (final switcher in tester.widgetList<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    )) {
      expect(switcher.duration, Duration.zero);
    }
    expect(tester.takeException(), isNull);
  });
}
