import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/stellar_map_screen.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 27, 12);

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

MiningSave _stateWith({
  int? cash,
  TechnologyLevels? technology,
  Set<MiningPlanetId>? unlockedPlanets,
  MiningPlanetId? activePlanet,
  Map<MiningSiteId, SiteProgress>? sites,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  return initial.copyWith(
    cash: cash,
    technology: technology,
    unlockedPlanetIds: unlockedPlanets,
    activePlanetId: activePlanet,
    sites: sites == null ? null : {...initial.sites, ...sites},
  );
}

/// Every authored site commissioned, so the final planet is mastered and
/// the Relaunch card is unlocked.
MiningSave _masteredSave() => _stateWith(
  unlockedPlanets: {...MiningPlanetId.values},
  activePlanet: MiningPlanetId.values.last,
  sites: {
    for (final planet in MiningPlanetId.values)
      for (final site in _content.planet(planet).sites)
        site.id: _progress(unlocked: true, commissioned: true),
  },
);

Future<void> _pumpMap(
  WidgetTester tester, {
  required StellarMapView view,
  ValueChanged<MiningPlanetId>? onUnlock,
  ValueChanged<MiningPlanetId>? onTravel,
  VoidCallback? onRelaunch,
  ValueChanged<MiningNavigationDestination>? onDestinationSelected,
  Size viewport = const Size(360, 640),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        home: StellarMapScreen(
          view: view,
          content: _content,
          onUnlock: onUnlock ?? (_) {},
          onTravel: onTravel ?? (_) {},
          onRelaunch: onRelaunch ?? () {},
          onDestinationSelected: onDestinationSelected ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('matches the authored 402x874 Stellar Map composition', (
    tester,
  ) async {
    final view = StellarMapView.from(
      state: MiningSave.initial(nowUtc: _start),
      content: _content,
    );
    await _pumpMap(tester, view: view, viewport: const Size(402, 874));

    expect(
      tester.getRect(
        find.byKey(const Key('mining-stellar-map-planet-homeworld')),
      ),
      const Rect.fromLTWH(14, 146, 374, 264),
    );
    expect(
      tester.getRect(
        find.byKey(const Key('mining-stellar-map-planet-homeworld-art')),
      ),
      const Rect.fromLTWH(242, 104, 172, 172),
    );
  });

  testWidgets('fresh map includes the prototype Mars teaser', (tester) async {
    final view = StellarMapView.from(
      state: MiningSave.initial(nowUtc: _start),
      content: _content,
    );
    await _pumpMap(tester, view: view, viewport: const Size(402, 874));

    expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
    expect(find.byKey(const Key('stellar-map-scroll')), findsOneWidget);
    expect(
      find.byKey(const Key('mining-stellar-map-planet-homeworld')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mining-stellar-map-planet-lunarFrontier')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mining-stellar-map-planet-marsFrontier')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mining-stellar-map-teaser-marsFrontier')),
      findsOneWidget,
    );
    expect(find.text('Mars Frontier'), findsOneWidget);
    expect(
      find.byKey(const Key('stellar-map-site-lunarFrontier-frostShelf')),
      findsNothing,
    );
    expect(
      tester
          .getRect(
            find.byKey(const Key('mining-stellar-map-teaser-marsFrontier')),
          )
          .bottom,
      lessThan(775),
    );
    expect(
      tester.getRect(
        find.byKey(const Key('mining-stellar-map-teaser-marsFrontier')),
      ),
      const Rect.fromLTWH(14, 623, 374, 104),
    );
    expect(
      find.byKey(const Key('stellar-map-site-homeworld-landingBasin')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('stellar-map-site-homeworld-carbonRidge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('stellar-map-site-homeworld-graniteCrater')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Image>(
            find.byKey(const Key('mining-stellar-map-planet-homeworld-art')),
          )
          .image,
      isA<AssetImage>(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps each planet globe inside its compact card', (
    tester,
  ) async {
    final view = StellarMapView.from(
      state: MiningSave.initial(nowUtc: _start),
      content: _content,
    );
    await _pumpMap(tester, view: view, viewport: const Size(430, 932));

    expect(find.byKey(const Key('stellar-map-route')), findsNothing);
    final homeworldArt = tester.widget<Image>(
      find.byKey(const Key('mining-stellar-map-planet-homeworld-art')),
    );
    expect(homeworldArt.fit, BoxFit.contain);
    expect(homeworldArt.opacity?.value, anyOf(isNull, equals(1)));
    expect(
      tester
          .getSize(
            find.byKey(const Key('mining-stellar-map-planet-homeworld-art')),
          )
          .shortestSide,
      greaterThanOrEqualTo(96),
    );
    final card = tester.getRect(
      find.byKey(const Key('mining-stellar-map-planet-homeworld')),
    );
    final art = tester.getRect(
      find.byKey(const Key('mining-stellar-map-planet-homeworld-art')),
    );
    expect(card.contains(art.center), isTrue);
    expect(card.height, lessThanOrEqualTo(270));
    expect(
      find.byKey(const Key('stellar-map-planet-homeworld-summary')),
      findsOneWidget,
    );
    expect(
      tester.widget(
        find.byKey(const Key('stellar-map-planet-homeworld-summary')),
      ),
      isA<Row>(),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stellar-map-planet-homeworld-summary')),
        matching: find.text('0/3'),
      ),
      findsOneWidget,
    );
    expect(find.text('0.0/s'), findsOneWidget);
  });

  testWidgets('Lunar unlock shows exact Mars Frontier requirements and state', (
    tester,
  ) async {
    final view = StellarMapView.from(
      state: _stateWith(
        unlockedPlanets: {
          MiningPlanetId.homeworld,
          MiningPlanetId.lunarFrontier,
        },
      ),
      content: _content,
      isBusy: true,
    );
    await _pumpMap(tester, view: view);

    final mars = find.byKey(
      const Key('mining-stellar-map-planet-marsFrontier'),
    );
    expect(mars, findsOneWidget);
    expect(
      find.descendant(of: mars, matching: find.text('Mars Frontier')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Mars Frontier.*locked')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mars, matching: find.text('Homeworld sites 0/3')),
      findsNothing,
    );
    expect(
      find.descendant(of: mars, matching: find.text('0/3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mars, matching: find.text('LV 5')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mars, matching: find.text('16.00M')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mars,
        matching: find.text('Finishing previous action…'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('stellar-map-site-marsFrontier-ochreBasin')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('stellar-map-site-marsFrontier-silicaDunes')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('stellar-map-site-marsFrontier-cobaltChasm')),
      findsNothing,
    );
  });

  testWidgets(
    'locked card keeps requirements and busy notice above its action',
    (tester) async {
      // Three requirements and a busy notice must fit above the action.
      final view = StellarMapView.from(
        state: _stateWith(
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
        ),
        content: _content,
        isBusy: true,
      );
      await _pumpMap(tester, view: view);

      final mars = find.byKey(
        const Key('mining-stellar-map-planet-marsFrontier'),
      );
      final requirementBottom = [
        tester
            .getRect(find.descendant(of: mars, matching: find.text('0/3')))
            .bottom,
        tester
            .getRect(find.descendant(of: mars, matching: find.text('LV 5')))
            .bottom,
        tester
            .getRect(find.descendant(of: mars, matching: find.text('16.00M')))
            .bottom,
        tester
            .getRect(
              find.descendant(
                of: mars,
                matching: find.text('Finishing previous action…'),
              ),
            )
            .bottom,
      ].reduce(math.max);
      final actionTop = tester
          .getRect(
            find.byKey(const Key('mining-stellar-map-unlock-marsFrontier')),
          )
          .top;
      expect(requirementBottom, lessThanOrEqualTo(actionTop));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('map forwards direct travel and unlock actions', (tester) async {
    final initial = MiningSave.initial(nowUtc: _start);
    final sites = <MiningSiteId, SiteProgress>{...initial.sites};
    for (final planet in [
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
    ]) {
      for (final site in _content.planet(planet).sites) {
        sites[site.id] = _progress(unlocked: true, commissioned: true);
      }
    }
    final view = StellarMapView.from(
      state: _stateWith(
        cash: 16_000_000,
        technology: const TechnologyLevels(surveying: 5),
        unlockedPlanets: {
          MiningPlanetId.homeworld,
          MiningPlanetId.lunarFrontier,
        },
        sites: sites,
      ),
      content: _content,
    );
    final unlocked = <MiningPlanetId>[];
    final traveled = <MiningPlanetId>[];
    await _pumpMap(
      tester,
      view: view,
      onUnlock: unlocked.add,
      onTravel: traveled.add,
    );

    final marsUnlock = find.byKey(
      const Key('mining-stellar-map-unlock-marsFrontier'),
    );
    expect(marsUnlock, findsOneWidget);
    expect(tester.getSize(marsUnlock).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(marsUnlock);
    await tester.tap(marsUnlock);
    final lunarTravel = find.byKey(
      const Key('mining-stellar-map-travel-lunarFrontier'),
    );
    await tester.ensureVisible(lunarTravel);
    await tester.tap(lunarTravel);

    expect(unlocked, [MiningPlanetId.marsFrontier]);
    expect(traveled, [MiningPlanetId.lunarFrontier]);
  });

  testWidgets('fresh map teases Ceres behind Mars', (tester) async {
    final view = StellarMapView.from(
      state: MiningSave.initial(nowUtc: _start),
      content: _content,
    );
    await _pumpMap(tester, view: view);

    final ceres = find.byKey(
      const Key('mining-stellar-map-teaser-ceresFrontier'),
    );
    expect(ceres, findsOneWidget);
    expect(
      find.descendant(of: ceres, matching: find.text('UNLOCK MARS FIRST')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mining-stellar-map-planet-ceresFrontier')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('Mars mastery shows a ready Ceres card with compact cash at '
        '${viewport.width.toInt()}x${viewport.height.toInt()}', (tester) async {
      final view = StellarMapView.from(
        state: _stateWith(
          cash: 30000000,
          technology: const TechnologyLevels(surveying: 5),
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
            MiningPlanetId.marsFrontier,
          },
          activePlanet: MiningPlanetId.marsFrontier,
          sites: {
            for (final planet in const [
              MiningPlanetId.homeworld,
              MiningPlanetId.lunarFrontier,
              MiningPlanetId.marsFrontier,
            ])
              for (final site in _content.planet(planet).sites)
                site.id: _progress(unlocked: true, commissioned: true),
          },
        ),
        content: _content,
      );
      MiningPlanetId? unlocked;
      await _pumpMap(
        tester,
        view: view,
        viewport: viewport,
        onUnlock: (id) => unlocked = id,
      );

      final ceres = find.byKey(
        const Key('mining-stellar-map-planet-ceresFrontier'),
      );
      expect(ceres, findsOneWidget);
      expect(
        find.descendant(of: ceres, matching: find.text('Ceres Frontier')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: ceres, matching: find.text('30.00M')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: ceres,
          matching: find.text('UNLOCK FOR 30.00M CASH'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('30000000'), findsNothing);
      expect(
        find.byKey(const Key('mining-stellar-map-teaser-ceresFrontier')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      final unlock = find.byKey(
        const Key('mining-stellar-map-unlock-ceresFrontier'),
      );
      await tester.ensureVisible(unlock);
      await tester.pump();
      await tester.tap(unlock);
      expect(unlocked, MiningPlanetId.ceresFrontier);
    });
  }

  testWidgets('critical map controls fit both phone sizes at text scale 1.3', (
    tester,
  ) async {
    final state = _stateWith(
      unlockedPlanets: {MiningPlanetId.homeworld, MiningPlanetId.lunarFrontier},
    );
    final view = StellarMapView.from(state: state, content: _content);
    for (final viewport in [const Size(360, 640), const Size(430, 932)]) {
      await _pumpMap(tester, view: view, viewport: viewport);
      expect(tester.takeException(), isNull);
      final navigation = find.byKey(const Key('mining-bottom-navigation'));
      expect(navigation, findsOneWidget);
      expect(
        tester.getRect(navigation).bottom,
        lessThanOrEqualTo(viewport.height),
      );
      for (final destination in MiningNavigationDestination.values) {
        final control = find.byKey(Key('mining-nav-${destination.name}'));
        expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
      }
      for (final planet in view.planets) {
        final card = find.byKey(
          Key('mining-stellar-map-planet-${planet.id.name}'),
        );
        expect(card, findsOneWidget);
        final indicators = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'stellar-map-site-${planet.id.name}-',
              ),
        );
        expect(indicators, findsNWidgets(planet.isUnlocked ? 3 : 0));
      }
    }
  });

  testWidgets('site indicators never overlap the bottom planet action', (
    tester,
  ) async {
    // The active card and an unlocked non-active card both end their
    // indicator row above the 60px travel hex at bottom: 14. Assert
    // indicator.bottom <= action.top for every indicator on both cards.
    final view = StellarMapView.from(
      state: _stateWith(
        unlockedPlanets: {
          MiningPlanetId.homeworld,
          MiningPlanetId.lunarFrontier,
        },
      ),
      content: _content,
    );
    await _pumpMap(tester, view: view, viewport: const Size(430, 932));

    for (final planet in view.planets.where((planet) => planet.isUnlocked)) {
      final action = find.byKey(
        Key('mining-stellar-map-travel-${planet.id.name}'),
      );
      expect(action, findsOneWidget);
      final actionTop = tester.getRect(action).top;
      for (final site in _content.planet(planet.id).sites) {
        final indicator = find.byKey(
          Key('stellar-map-site-${planet.id.name}-${site.id.name}'),
        );
        expect(indicator, findsOneWidget);
        expect(
          tester.getRect(indicator).bottom,
          lessThanOrEqualTo(actionTop),
          reason:
              '${site.id.name} indicator overlaps the ${planet.id.name} '
              'action',
        );
      }
    }
  });

  testWidgets(
    'offsets landscape foreground controls by horizontal safe-area insets',
    (tester) async {
      // No orientation lock: rotating to landscape on a device with a
      // left/right display cutout must keep the cash chip, cargo gauge,
      // scroll content, and navigation out of the unsafe horizontal region
      // while the background stays full-bleed. Pump directly so the screen
      // reads MediaQuery.paddingOf(context) from the view padding.
      const padLeft = 44.0;
      const padRight = 44.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(874, 402);
      tester.view.padding = const FakeViewPadding(
        left: padLeft,
        top: 0,
        right: padRight,
        bottom: 0,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });
      final view = StellarMapView.from(
        state: MiningSave.initial(nowUtc: _start),
        content: _content,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          home: StellarMapScreen(
            view: view,
            content: _content,
            onUnlock: (_) {},
            onTravel: (_) {},
            onRelaunch: () {},
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      final cash = tester.getRect(find.byKey(const Key('mining-cash-chip')));
      final cargo = tester.getRect(find.byKey(const Key('mining-cargo-gauge')));
      final scroll = tester.getRect(
        find.byKey(const Key('stellar-map-scroll')),
      );
      final nav = tester.getRect(
        find.byKey(const Key('mining-bottom-navigation')),
      );
      expect(cash.left, padLeft);
      expect(cargo.right, 874 - 12 - padRight);
      expect(scroll.left, 14 + padLeft);
      expect(scroll.right, 874 - 14 - padRight);
      expect(nav.left, padLeft);
      expect(nav.right, 874 - padRight);
    },
  );

  testWidgets('fresh map shows no relaunch card or status line', (
    tester,
  ) async {
    final view = StellarMapView.from(
      state: MiningSave.initial(nowUtc: _start),
      content: _content,
    );
    await _pumpMap(tester, view: view, viewport: const Size(402, 874));

    expect(find.byKey(const Key('stellar-map-relaunch')), findsNothing);
    expect(find.byKey(const Key('stellar-map-relaunch-status')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('final-planet mastery shows an enabled relaunch card', (
    tester,
  ) async {
    final view = StellarMapView.from(state: _masteredSave(), content: _content);
    var relaunchCalls = 0;
    await _pumpMap(
      tester,
      view: view,
      viewport: const Size(402, 874),
      onRelaunch: () => relaunchCalls++,
    );

    final card = find.byKey(const Key('stellar-map-relaunch'));
    expect(card, findsOneWidget);
    final action = find.byKey(const Key('stellar-map-relaunch-action'));
    expect(tester.widget<ElevatedButton>(action).onPressed, isNotNull);
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(relaunchCalls, 1);
    expect(find.byKey(const Key('stellar-map-relaunch-status')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy map keeps the relaunch card with a disabled action', (
    tester,
  ) async {
    final view = StellarMapView.from(
      state: _masteredSave(),
      content: _content,
      isBusy: true,
    );
    await _pumpMap(tester, view: view, viewport: const Size(402, 874));

    expect(find.byKey(const Key('stellar-map-relaunch')), findsOneWidget);
    final action = find.byKey(const Key('stellar-map-relaunch-action'));
    expect(tester.widget<ElevatedButton>(action).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('after a relaunch the status line leads the map scroll', (
    tester,
  ) async {
    final view = StellarMapView.from(
      state: MiningSave.initial(nowUtc: _start, relaunchCount: 1),
      content: _content,
    );
    await _pumpMap(tester, view: view, viewport: const Size(402, 874));

    final scroll = find.byKey(const Key('stellar-map-scroll'));
    final status = find.descendant(
      of: scroll,
      matching: find.text('RELAUNCH 1 · SALES ×1.5'),
    );
    expect(status, findsOneWidget);
    expect(
      tester.getRect(status).top,
      lessThan(
        tester
            .getRect(
              find.byKey(const Key('mining-stellar-map-planet-homeworld')),
            )
            .top,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('mastered map with the relaunch card fits '
        '${viewport.width.toInt()}x${viewport.height.toInt()}', (tester) async {
      final view = StellarMapView.from(
        state: _masteredSave(),
        content: _content,
      );
      await _pumpMap(tester, view: view, viewport: viewport);

      expect(find.byKey(const Key('stellar-map-relaunch')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
