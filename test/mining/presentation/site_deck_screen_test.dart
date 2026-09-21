import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/site_deck_screen.dart';
import 'package:horologium/mining/site_deck_view.dart';

import '../../support/mining_grid_fixtures.dart';

final _start = DateTime.utc(2026, 8, 26, 12);
final _content = MiningContentRegistry.stellarMining();
final _landingCells = deployableMiningCells(
  _content.site(MiningSiteId.landingBasin),
);
final _graniteCell = firstPlayableCell(
  _content.site(MiningSiteId.graniteCrater),
);

MiningSave _stateWith({
  int? cash,
  Map<MiningSiteId, SiteProgress>? sites,
  Set<MiningPlanetId>? unlockedPlanetIds,
  MiningPlanetId? activePlanetId,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  return initial.copyWith(
    cash: cash,
    unlockedPlanetIds: unlockedPlanetIds,
    activePlanetId: activePlanetId,
    sites: sites == null ? null : {...initial.sites, ...sites},
  );
}

SiteProgress _progress({
  bool unlocked = false,
  bool commissioned = false,
  double storedAmount = 0,
  List<MiningRigPlacement> rigs = const [],
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigPlacements: rigs,
);

SiteDeckView _deckView(MiningSave state, {bool isBusy = false}) =>
    SiteDeckView.from(state: state, content: _content, isBusy: isBusy);

/// A commissioned Lunar Frontier state so portrait header tests can exercise a
/// long non-Homeworld planet name (`LUNAR FRONTIER`).
MiningSave _lunarState() => _stateWith(
  cash: 2_000,
  unlockedPlanetIds: const {
    MiningPlanetId.homeworld,
    MiningPlanetId.lunarFrontier,
  },
  activePlanetId: MiningPlanetId.lunarFrontier,
  sites: {
    MiningSiteId.frozenBasin: _progress(
      unlocked: true,
      commissioned: true,
      storedAmount: 10,
    ),
  },
);

/// Landing Basin with one T1 rig: rate 0.50/s, capacity 90. Stored at
/// capacity makes the card cargo-full.
SiteProgress _fullLandingBasin() => _progress(
  unlocked: true,
  commissioned: true,
  storedAmount: 90,
  rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingCells[0])],
);

Future<void> _pumpDeck(
  WidgetTester tester, {
  required SiteDeckView view,
  Size size = const Size(360, 640),
  double textScale = 1,
  double paddingTop = 0,
  VoidCallback? onSellCargo,
  ValueChanged<MiningSiteId>? onEnterSite,
  ValueChanged<MiningSiteId>? onUnlockSite,
  ValueChanged<MiningNavigationDestination>? onDestinationSelected,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(top: paddingTop);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
      home: SiteDeckScreen(
        view: view,
        onEnterSite: onEnterSite ?? (_) {},
        onUnlockSite: onUnlockSite ?? (_) {},
        onSellCargo: onSellCargo ?? () {},
        onDestinationSelected: onDestinationSelected ?? (_) {},
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
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
          rigs: [
            MiningRigPlacement(tier: RigTier.t1, cell: _landingCells[0]),
            MiningRigPlacement(tier: RigTier.t3, cell: _landingCells[1]),
          ],
        ),
      },
    );
    await _pumpDeck(tester, view: _deckView(state));
    tester.view.physicalSize = const Size(402, 874);
    await tester.pump();

    final scroll = tester.getRect(find.byKey(const Key('site-deck-scroll')));
    expect(scroll.bottom, 778);
    expect(
      find.byKey(const Key('fleet-dock')),
      findsNothing,
      reason: 'Fleet management is Mine-Site-only.',
    );

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
    await _pumpDeck(tester, view: _deckView(state));

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
    await _pumpDeck(tester, view: fresh);
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
                  rigs: [
                    MiningRigPlacement(tier: RigTier.t1, cell: _graniteCell),
                  ],
                ),
              },
            ),
          ),
          onEnterSite: (_) {},
          onUnlockSite: (_) {},
          onSellCargo: () {},
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
          rigs: [MiningRigPlacement(tier: RigTier.t2, cell: _landingCells[0])],
        ),
      },
    );
    await _pumpDeck(tester, view: _deckView(state));
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

  testWidgets('emits site entry, unlock, and bottom navigation callbacks', (
    tester,
  ) async {
    final state = _stateWith(
      cash: 2_000,
      sites: {MiningSiteId.landingBasin: _progress(unlocked: true)},
    );
    final entered = <MiningSiteId>[];
    final unlocked = <MiningSiteId>[];
    final destinations = <MiningNavigationDestination>[];
    await _pumpDeck(
      tester,
      view: _deckView(state),
      onEnterSite: entered.add,
      onUnlockSite: unlocked.add,
      onDestinationSelected: destinations.add,
    );

    await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
    await tester.drag(
      find.byKey(const Key('site-deck-scroll')),
      const Offset(0, -240),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('site-card-carbonRidge-unlock')));
    await tester.tap(find.byKey(const Key('mining-nav-technology')));

    expect(entered, <MiningSiteId>[MiningSiteId.landingBasin]);
    expect(unlocked, <MiningSiteId>[MiningSiteId.carbonRidge]);
    expect(destinations, <MiningNavigationDestination>[
      MiningNavigationDestination.technology,
    ]);
  });

  testWidgets('keeps interactive targets accessible', (tester) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final state = initial.copyWith(
      cash: 2_000,
      sites: {
        for (final entry in initial.sites.entries)
          entry.key: entry.value.copyWith(unlocked: true),
      },
    );
    await _pumpDeck(tester, view: _deckView(state));

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

  testWidgets('marks a full portrait card and renders complete recovery copy', (
    tester,
  ) async {
    final state = _stateWith(
      cash: 2_000,
      sites: {
        MiningSiteId.landingBasin: _fullLandingBasin(),
        MiningSiteId.graniteCrater: _progress(
          unlocked: true,
          commissioned: true,
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _graniteCell)],
        ),
      },
    );
    await _pumpDeck(
      tester,
      view: _deckView(state),
      size: const Size(360, 640),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);

    expect(
      find.bySemanticsLabel(RegExp(r'Landing Basin, FULL site')),
      findsOneWidget,
    );
    final fullCopy = find.text('FULL · SELL TO RESUME');
    expect(fullCopy, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(fullCopy).didExceedMaxLines,
      isFalse,
      reason:
          'the FULL · SELL TO RESUME copy must render completely '
          'at 360px and text scale 1.3, not ellipsize',
    );
    expect(
      find.byKey(const Key('site-card-landingBasin-node-dots')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('site-deck-scroll')),
      const Offset(0, -500),
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp(r'Granite Crater, OPERATIONAL site')),
      findsOneWidget,
      reason: 'Under-capacity operational cards keep OPERATIONAL.',
    );
  });

  testWidgets('marks a full landscape card FULL with operational accent', (
    tester,
  ) async {
    final state = _stateWith(
      cash: 2_000,
      sites: {MiningSiteId.landingBasin: _fullLandingBasin()},
    );
    await _pumpDeck(tester, view: _deckView(state), size: const Size(874, 402));

    expect(
      find.bySemanticsLabel(RegExp(r'Landing Basin, FULL site')),
      findsOneWidget,
    );
    final chip = tester.widget<Text>(find.text('FULL'));
    expect(chip.style?.color, MiningTheme.accent);
    final card = tester.widget<Container>(
      find.byKey(const Key('site-card-landingBasin')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(
      (decoration.border! as Border).top.color,
      MiningTheme.accent.withAlpha(180),
    );
    expect(
      find.text('FULL · 0.50/s · 90 / 90\nSELL TO RESUME'),
      findsOneWidget,
      reason: 'Full status keeps rate and cargo numbers plus recovery copy.',
    );
  });

  testWidgets('emits one sale callback per site-deck-sell tap', (tester) async {
    final state = _stateWith(
      cash: 2_000,
      sites: {
        MiningSiteId.landingBasin: _progress(
          unlocked: true,
          commissioned: true,
          storedAmount: 10,
        ),
      },
    );
    var sales = 0;
    await _pumpDeck(tester, view: _deckView(state), onSellCargo: () => sales++);

    final sell = find.byKey(const Key('site-deck-sell'));
    expect(sell, findsOneWidget);
    expect(
      find.bySemanticsLabel('Sell all cargo for 40 cash.'),
      findsOneWidget,
    );
    expect(find.text('SELL'), findsOneWidget);
    expect(find.text('+40'), findsOneWidget);
    var size = tester.getSize(sell);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(sell);
    await tester.pump();
    expect(sales, 1);

    await _pumpDeck(
      tester,
      view: _deckView(state),
      size: const Size(874, 402),
      textScale: 1.3,
      onSellCargo: () => sales++,
    );
    expect(tester.takeException(), isNull);
    expect(sell, findsOneWidget);
    expect(
      find.bySemanticsLabel('Sell all cargo for 40 cash.'),
      findsOneWidget,
    );
    size = tester.getSize(sell);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(sell);
    await tester.pump();
    expect(sales, 2);
  });

  testWidgets('disables site-deck-sell while busy, tiny-sale, or empty', (
    tester,
  ) async {
    final sellable = _stateWith(
      sites: {
        MiningSiteId.landingBasin: _progress(
          unlocked: true,
          commissioned: true,
          storedAmount: 10,
        ),
      },
    );
    final sell = find.byKey(const Key('site-deck-sell'));

    await _pumpDeck(tester, view: _deckView(sellable, isBusy: true));
    expect(tester.widget<OutlinedButton>(sell).onPressed, isNull);
    expect(find.bySemanticsLabel('Finishing previous action…'), findsOneWidget);

    final tinySale = _stateWith(
      sites: {
        MiningSiteId.landingBasin: _progress(
          unlocked: true,
          commissioned: true,
          storedAmount: 0.1,
        ),
      },
    );
    await _pumpDeck(tester, view: _deckView(tinySale));
    expect(tester.widget<OutlinedButton>(sell).onPressed, isNull);
    expect(
      find.bySemanticsLabel(
        'Keep mining until cargo is worth at least 1 cash.',
      ),
      findsOneWidget,
    );

    await _pumpDeck(tester, view: _deckView(_stateWith()));
    expect(tester.widget<OutlinedButton>(sell).onPressed, isNull);
    expect(find.bySemanticsLabel('No cargo to sell.'), findsOneWidget);
  });

  testWidgets('keeps the portrait Sell band clear across the fit matrix', (
    tester,
  ) async {
    final cases = <(Size, SiteDeckView, String?)>[
      (const Size(360, 640), _deckView(_lunarState()), 'LUNAR FRONTIER'),
      (
        const Size(402, 874),
        _deckView(
          _stateWith(
            cash: 2_000,
            sites: {
              // A full card inside the matrix keeps the wrapped
              // `FULL · SELL TO RESUME` copy under structural checks at 1.3.
              MiningSiteId.landingBasin: _fullLandingBasin(),
              MiningSiteId.carbonRidge: _progress(
                unlocked: true,
                commissioned: true,
              ),
            },
          ),
        ),
        null,
      ),
      (const Size(430, 932), _deckView(_lunarState()), 'LUNAR FRONTIER'),
    ];
    for (final (size, view, planetName) in cases) {
      await _pumpDeck(tester, view: view, size: size, textScale: 1.3);
      expect(tester.takeException(), isNull, reason: '$size overflowed');

      final scroll = tester.getRect(find.byKey(const Key('site-deck-scroll')));
      expect(scroll.top, 164, reason: '$size moved the card list');

      final sell = find.byKey(const Key('site-deck-sell'));
      expect(sell, findsOneWidget);
      final sellRect = tester.getRect(sell);
      expect(sellRect.width, greaterThanOrEqualTo(48));
      expect(sellRect.height, greaterThanOrEqualTo(48));

      final gauge = tester.getRect(find.byKey(const Key('mining-cargo-gauge')));
      expect(
        sellRect.overlaps(gauge),
        isFalse,
        reason: '$size Sell overlaps the cargo gauge',
      );

      final planetProgress = tester.getRect(
        find.byKey(const Key('site-deck-planet-progress')),
      );
      expect(
        sellRect.overlaps(planetProgress),
        isFalse,
        reason: '$size Sell overlaps the planet progress region',
      );

      final firstCard = tester.getRect(
        find.byKey(Key('site-card-${view.sites.first.id.name}')),
      );
      expect(
        sellRect.overlaps(firstCard),
        isFalse,
        reason: '$size Sell overlaps the first site card',
      );

      final nav = tester.getRect(
        find.byKey(const Key('mining-bottom-navigation')),
      );
      expect(
        sellRect.bottom,
        lessThanOrEqualTo(nav.top),
        reason: '$size Sell dips into the bottom navigation',
      );

      if (planetName != null) {
        expect(find.text(planetName), findsOneWidget);
      }
      if (size.width == 402 && size.height == 874) {
        expect(
          sellRect,
          const Rect.fromLTWH(218, 108, 80, 48),
          reason: 'Authored composition pins the Sell rect',
        );
      }
      expect(
        find.byKey(const Key('fleet-dock')),
        findsNothing,
        reason: 'Fleet management is Mine-Site-only.',
      );
    }
  });

  testWidgets(
    'keeps the landscape site action reachable above the navigation',
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
            onEnterSite: (_) {},
            onUnlockSite: (_) {},
            onSellCargo: () {},
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
      final navRect = tester.getRect(
        find.byKey(const Key('mining-bottom-navigation')),
      );
      expect(initialActionRect.top, greaterThanOrEqualTo(0));
      expect(initialActionRect.bottom, lessThanOrEqualTo(navRect.top));
      expect(initialActionRect.overlaps(navRect), isFalse);
      expect(
        find.byKey(const Key('fleet-dock')),
        findsNothing,
        reason: 'Fleet management is Mine-Site-only.',
      );
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
    await _pumpDeck(tester, view: _deckView(state));

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
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingCells[0])],
        ),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        home: SiteDeckScreen(
          view: _deckView(state),
          onEnterSite: (_) {},
          onUnlockSite: (_) {},
          onSellCargo: () {},
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
