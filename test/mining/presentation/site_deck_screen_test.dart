import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
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
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
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
  testWidgets('matches the authored 402x874 Site Deck composition', (
    tester,
  ) async {
    final state = _stateWith(
      cash: 412,
      sites: {
        MiningSiteId.landingBasin: _progress(
          unlocked: true,
          commissioned: true,
          rigs: {MiningNodeId.n1: RigTier.t1, MiningNodeId.n2: RigTier.t3},
        ),
      },
    );
    await _pumpDeck(tester, view: _deckView(state), dock: _dockView(state));
    tester.view.physicalSize = const Size(402, 874);
    await tester.pump();

    final first = tester.getRect(
      find.byKey(const Key('site-card-landingBasin')),
    );
    final second = tester.getRect(
      find.byKey(const Key('site-card-carbonRidge')),
    );
    final third = tester.getRect(
      find.byKey(const Key('site-card-graniteCrater')),
    );
    expect(first, const Rect.fromLTWH(14, 164, 374, 216));
    expect(second, const Rect.fromLTWH(14, 391, 374, 170));
    expect(third, const Rect.fromLTWH(14, 572, 374, 104));

    final cash = tester.getRect(find.byKey(const Key('mining-cash-chip')));
    final gauge = tester.getRect(find.byKey(const Key('mining-cargo-gauge')));
    expect(cash.top, 54);
    expect(cash.left, 0);
    expect(gauge, const Rect.fromLTWH(310, 50, 80, 80));
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('site-deck-header-art')))
          .opacity,
      .55,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('site-card-landingBasin-enter')),
        matching: find.byType(MiningHex),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('site-card-landingBasin-node-dots')),
      findsOneWidget,
    );
  });

  testWidgets('navigation hexes use prototype selection and panel alpha', (
    tester,
  ) async {
    final state = _stateWith();
    await _pumpDeck(tester, view: _deckView(state), dock: _dockView(state));

    final selected = tester.widget<MiningHex>(
      find.ancestor(
        of: find.byKey(const Key('mining-nav-siteDeck')),
        matching: find.byType(MiningHex),
      ),
    );
    final idle = tester.widget<MiningHex>(
      find.ancestor(
        of: find.byKey(const Key('mining-nav-technology')),
        matching: find.byType(MiningHex),
      ),
    );
    expect(selected.fill, const Color.fromRGBO(24, 255, 255, .16));
    expect(selected.border, const Color(0xFF18FFFF));
    expect(idle.fill, const Color.fromRGBO(6, 10, 16, .86));
    expect(idle.border, const Color.fromRGBO(83, 212, 232, .3));
  });

  testWidgets('renders each projected card state with canonical asset art', (
    tester,
  ) async {
    final fresh = _deckView(
      _stateWith(sites: {MiningSiteId.landingBasin: _progress(unlocked: true)}),
    );
    await _pumpDeck(tester, view: fresh, dock: _dockView(_stateWith()));
    expect(
      find.byKey(const Key('site-card-landingBasin-node-dots')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'Carbon Ridge.*locked', caseSensitive: false),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Image>(find.byKey(const Key('site-card-landingBasin-art')))
          .image,
      isA<AssetImage>(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
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
    expect(
      find.byKey(const Key('site-card-carbonRidge-node-dots')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('site-card-graniteCrater-node-dots')),
      findsOneWidget,
    );
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
    expect(find.text('250'), findsOneWidget);
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

    expect(DockBayId.values, hasLength(4));
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

  testWidgets('portrait locked card shows the prerequisite-site gate', (
    tester,
  ) async {
    // Granite Crater requires Carbon Ridge. With only Landing Basin unlocked,
    // Granite Crater is blocked by the prerequisite site (not Surveying or
    // cash), so the portrait _LockedSite must surface that gate alongside the
    // authored LV 0 / 700 requirements rather than looking cash/Surveying-only.
    final state = _stateWith(
      sites: {MiningSiteId.landingBasin: _progress(unlocked: true)},
    );
    await _pumpDeck(tester, view: _deckView(state), dock: _dockView(state));

    final granite = find.byKey(const Key('site-card-graniteCrater'));
    expect(granite, findsOneWidget);
    expect(
      find.descendant(of: granite, matching: find.text('LV 0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: granite, matching: find.text('700')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: granite,
        matching: find.text('Unlock Carbon Ridge first.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('offsets interactive chrome below non-zero safe-area insets', (
    tester,
  ) async {
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
      cash: 2_000,
      sites: {
        MiningSiteId.landingBasin: _progress(
          unlocked: true,
          commissioned: true,
          rigs: {MiningNodeId.n1: RigTier.t1},
        ),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        home: SiteDeckScreen(
          view: _deckView(state),
          fleetDock: _dockView(state),
          onEnterSite: (_) {},
          onUnlockSite: (_) {},
          onBayTap: (_) {},
          onSpawnRig: () {},
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pump();

    final cash = tester.getRect(find.byKey(const Key('mining-cash-chip')));
    final gauge = tester.getRect(find.byKey(const Key('mining-cargo-gauge')));
    final nav = tester.getRect(
      find.byKey(const Key('mining-bottom-navigation')),
    );
    expect(cash.top, 54 + 59);
    expect(gauge.top, 50 + 59);
    expect(nav.bottom, 932 - 34);
  });
}
