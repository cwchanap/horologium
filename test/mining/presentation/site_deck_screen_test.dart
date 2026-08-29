import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/site_deck_screen.dart';
import 'package:horologium/mining/site_deck_view.dart';

final _start = DateTime.utc(2026, 8, 26, 12);
final _content = MiningContentRegistry.stellarMining();

MiningSave _stateWith({int? cash, Map<MiningSiteId, SiteProgress>? sites}) {
  final initial = MiningSave.initial(nowUtc: _start);
  return initial.copyWith(
    cash: cash,
    sites: sites == null ? null : {...initial.sites, ...sites},
  );
}

SiteProgress _progress({
  bool unlocked = false,
  bool commissioned = false,
  Map<MiningNodeId, RigTier?>? rigs,
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: 0,
  rigByNode: rigs ?? {for (final node in MiningNodeId.values) node: null},
);

SiteDeckView _deckView(MiningSave state) =>
    SiteDeckView.from(state: state, content: _content, isBusy: false);

FleetDockView _dockView(MiningSave state) => FleetDockView.from(
  state: state,
  content: _content,
  selectedBayId: null,
  isBusy: false,
);

Future<void> _pumpDeck(
  WidgetTester tester, {
  required SiteDeckView view,
  required FleetDockView dock,
  ValueChanged<MiningSiteId>? onEnterSite,
  ValueChanged<MiningSiteId>? onUnlockSite,
  ValueChanged<DockBayId>? onBayTap,
  VoidCallback? onSpawnRig,
  ValueChanged<MiningNavigationDestination>? onDestinationSelected,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 640);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: SiteDeckScreen(
        view: view,
        fleetDock: dock,
        onEnterSite: onEnterSite ?? (_) {},
        onUnlockSite: onUnlockSite ?? (_) {},
        onBayTap: onBayTap ?? (_) {},
        onSpawnRig: onSpawnRig ?? () {},
        onDestinationSelected: onDestinationSelected ?? (_) {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders each projected card state with canonical asset art', (
    tester,
  ) async {
    final fresh = _deckView(
      _stateWith(sites: {MiningSiteId.landingBasin: _progress(unlocked: true)}),
    );
    await _pumpDeck(tester, view: fresh, dock: _dockView(_stateWith()));
    expect(find.text('IDLE'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(
      tester
          .widget<Image>(find.byKey(const Key('site-card-landingBasin-art')))
          .image,
      isA<AssetImage>(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SiteDeckScreen(
          view: _deckView(
            _stateWith(
              cash: 2_000,
              sites: {
                MiningSiteId.landingBasin: _progress(
                  unlocked: true,
                  commissioned: true,
                ),
                MiningSiteId.carbonRidge: _progress(unlocked: true),
                MiningSiteId.graniteCrater: _progress(
                  unlocked: true,
                  commissioned: true,
                  rigs: {MiningNodeId.n1: RigTier.t1},
                ),
              },
            ),
          ),
          fleetDock: _dockView(_stateWith()),
          onEnterSite: (_) {},
          onUnlockSite: (_) {},
          onBayTap: (_) {},
          onSpawnRig: () {},
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('site-deck-scroll')),
      const Offset(0, -500),
    );
    await tester.pump();
    expect(find.text('AVAILABLE'), findsOneWidget);
    expect(find.text('OPERATIONAL'), findsOneWidget);
    expect(MiningSiteCardState.values, <MiningSiteCardState>[
      MiningSiteCardState.locked,
      MiningSiteCardState.available,
      MiningSiteCardState.idle,
      MiningSiteCardState.operational,
    ]);
  });

  testWidgets('keeps site art dominant and exposes visual HUD gauges', (
    tester,
  ) async {
    final state = _stateWith(
      cash: 2_000,
      sites: {
        MiningSiteId.landingBasin: _progress(
          unlocked: true,
          commissioned: true,
          rigs: {MiningNodeId.n1: RigTier.t2},
        ),
      },
    );
    await _pumpDeck(tester, view: _deckView(state), dock: _dockView(state));
    tester.view.physicalSize = const Size(430, 932);
    await tester.pump();

    expect(find.byKey(const Key('mining-cash-chip')), findsOneWidget);
    expect(find.byKey(const Key('mining-cargo-gauge')), findsOneWidget);

    final card = tester.getRect(
      find.byKey(const Key('site-card-landingBasin')),
    );
    final artFrame = tester.getRect(
      find.byKey(const Key('site-card-landingBasin-art-frame')),
    );
    expect(artFrame.height, greaterThanOrEqualTo(120));
    expect(artFrame.height, greaterThan(card.height * 0.45));
    final action = tester.getRect(
      find.byKey(const Key('site-card-landingBasin-enter')),
    );
    expect(artFrame.contains(action.center), isTrue);
    expect(card.height, lessThanOrEqualTo(artFrame.height + 4));
    expect(
      tester
          .widget<Image>(find.byKey(const Key('site-card-landingBasin-art')))
          .opacity
          ?.value,
      anyOf(isNull, equals(1)),
    );

    await tester.drag(
      find.byKey(const Key('site-deck-scroll')),
      const Offset(0, -220),
    );
    await tester.pump();
    expect(tester.widget<Text>(find.text('UNLOCK · 250')).maxLines, 1);
  });

  testWidgets('emits site, dock, spawn, and bottom navigation callbacks', (
    tester,
  ) async {
    final state = _stateWith(
      cash: 2_000,
      sites: {MiningSiteId.landingBasin: _progress(unlocked: true)},
    );
    final entered = <MiningSiteId>[];
    final unlocked = <MiningSiteId>[];
    final bays = <DockBayId>[];
    final destinations = <MiningNavigationDestination>[];
    var spawned = false;
    await _pumpDeck(
      tester,
      view: _deckView(state),
      dock: _dockView(state),
      onEnterSite: entered.add,
      onUnlockSite: unlocked.add,
      onBayTap: bays.add,
      onSpawnRig: () => spawned = true,
      onDestinationSelected: destinations.add,
    );

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.drag(
      find.byKey(const Key('site-deck-scroll')),
      const Offset(0, -240),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('site-card-carbonRidge-unlock')));
    await tester.tap(find.byKey(const ValueKey<String>('b1')));
    await tester.tap(find.byKey(const ValueKey<String>('b2')));
    await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
    await tester.tap(find.byKey(const Key('mining-nav-technology')));

    expect(entered, <MiningSiteId>[MiningSiteId.landingBasin]);
    expect(unlocked, <MiningSiteId>[MiningSiteId.carbonRidge]);
    expect(bays, <DockBayId>[DockBayId.b1, DockBayId.b2]);
    expect(spawned, isTrue);
    expect(destinations, <MiningNavigationDestination>[
      MiningNavigationDestination.technology,
    ]);
  });

  testWidgets('keeps four bay controls and interactive targets accessible', (
    tester,
  ) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final state = initial.copyWith(
      cash: 2_000,
      sites: {
        for (final entry in initial.sites.entries)
          entry.key: entry.value.copyWith(unlocked: true),
      },
    );
    await _pumpDeck(tester, view: _deckView(state), dock: _dockView(state));

    final bayControls = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return widget is InkWell &&
          key is ValueKey<String> &&
          key.value.startsWith('b');
    });
    expect(DockBayId.values, hasLength(4));
    expect(bayControls, findsNWidgets(4));
    for (final bay in DockBayId.values) {
      final control = find.byKey(ValueKey<String>(bay.name));
      expect(control, findsOneWidget);
      final size = tester.getSize(control);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel(RegExp('Dock bay ${bay.name.toUpperCase()}')),
        findsOneWidget,
      );
    }

    final spawn = find.byKey(const Key('fleet-dock-spawn'));
    final spawnSize = tester.getSize(spawn);
    expect(spawnSize.width, greaterThanOrEqualTo(48));
    expect(spawnSize.height, greaterThanOrEqualTo(48));

    final scroll = find.byKey(const Key('site-deck-scroll'));
    for (final card in _deckView(state).sites) {
      final action = find.byKey(Key('site-card-${card.id.name}-enter'));
      for (
        var attempt = 0;
        attempt < 8 && action.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(scroll, const Offset(0, -320));
        await tester.pump();
      }
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      final size = tester.getSize(action);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }

    for (final destination in MiningNavigationDestination.values) {
      final control = find.byKey(Key('mining-nav-${destination.name}'));
      expect(control, findsOneWidget);
      final size = tester.getSize(control);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('fits compact and large portrait viewports at text scale 1.3', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = _stateWith(
      cash: 2_000,
      sites: {
        MiningSiteId.landingBasin: _progress(
          unlocked: true,
          commissioned: true,
          rigs: {MiningNodeId.n1: RigTier.t1},
        ),
        MiningSiteId.carbonRidge: _progress(unlocked: true, commissioned: true),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SiteDeckScreen(
          view: _deckView(state),
          fleetDock: _dockView(state),
          onEnterSite: (_) {},
          onUnlockSite: (_) {},
          onBayTap: (_) {},
          onSpawnRig: () {},
          onDestinationSelected: (_) {},
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
      ),
    );
    for (final size in [
      const Size(360, 640),
      const Size(430, 932),
      const Size(874, 402),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
      expect(find.byKey(const Key('fleet-dock')), findsOneWidget);
      expect(find.byKey(const Key('mining-bottom-navigation')), findsOneWidget);
      final navRect = tester.getRect(
        find.byKey(const Key('mining-bottom-navigation')),
      );
      final dockRect = tester.getRect(find.byKey(const Key('fleet-dock')));
      expect(navRect.overlaps(dockRect), isFalse);
      expect(navRect.bottom, lessThanOrEqualTo(size.height));
    }
  });

  testWidgets(
    'keeps the landscape site action reachable above the fixed dock',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(874, 402);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final state = _stateWith(
        cash: 2_000,
        sites: {MiningSiteId.landingBasin: _progress(unlocked: true)},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SiteDeckScreen(
            view: _deckView(state),
            fleetDock: _dockView(state),
            onEnterSite: (_) {},
            onUnlockSite: (_) {},
            onBayTap: (_) {},
            onSpawnRig: () {},
            onDestinationSelected: (_) {},
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      );
      await tester.pump();

      final action = find.byKey(const Key('site-card-landingBasin-enter'));
      final initialActionRect = tester.getRect(action);
      final dockRect = tester.getRect(find.byKey(const Key('fleet-dock')));
      final navRect = tester.getRect(
        find.byKey(const Key('mining-bottom-navigation')),
      );
      expect(initialActionRect.top, greaterThanOrEqualTo(0));
      expect(initialActionRect.bottom, lessThanOrEqualTo(navRect.top));
      expect(initialActionRect.overlaps(dockRect), isFalse);
      expect(initialActionRect.overlaps(navRect), isFalse);
      final spawn = find.byKey(const Key('fleet-dock-spawn'));
      final spawnSize = tester.getSize(spawn);
      expect(spawnSize.width, greaterThanOrEqualTo(48));
      expect(spawnSize.height, greaterThanOrEqualTo(48));
      for (final bay in DockBayId.values) {
        final control = find.byKey(ValueKey<String>(bay.name));
        final size = tester.getSize(control);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      for (final destination in MiningNavigationDestination.values) {
        final control = find.byKey(Key('mining-nav-${destination.name}'));
        final size = tester.getSize(control);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      await tester.ensureVisible(action);
      await tester.pump();
      final actionRect = tester.getRect(action);
      expect(actionRect.top, greaterThanOrEqualTo(0));
      expect(actionRect.bottom, lessThanOrEqualTo(navRect.top));
      expect(actionRect.overlaps(dockRect), isFalse);
      expect(actionRect.overlaps(navRect), isFalse);
      expect(actionRect.height, greaterThanOrEqualTo(48));
    },
  );
}
