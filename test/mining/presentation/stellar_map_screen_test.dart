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
  Map<MiningNodeId, RigTier?>? rigs,
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigByNode: rigs ?? {for (final node in MiningNodeId.values) node: null},
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

Future<void> _pumpMap(
  WidgetTester tester, {
  required StellarMapView view,
  ValueChanged<MiningPlanetId>? onUnlock,
  ValueChanged<MiningPlanetId>? onTravel,
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
        home: StellarMapScreen(
          view: view,
          content: _content,
          onUnlock: onUnlock ?? (_) {},
          onTravel: onTravel ?? (_) {},
          onDestinationSelected: onDestinationSelected ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('fresh map progressively discloses Homeworld and Lunar', (
    tester,
  ) async {
    final view = StellarMapView.from(
      state: MiningSave.initial(nowUtc: _start),
      content: _content,
    );
    await _pumpMap(tester, view: view);

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
    expect(find.text('Mars Frontier'), findsNothing);
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

  testWidgets('renders full-strength planet globes on a spatial route', (
    tester,
  ) async {
    final view = StellarMapView.from(
      state: MiningSave.initial(nowUtc: _start),
      content: _content,
    );
    await _pumpMap(tester, view: view, viewport: const Size(430, 932));

    expect(find.byKey(const Key('stellar-map-route')), findsOneWidget);
    expect(
      find.byKey(const Key('stellar-map-orbit-homeworld')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('stellar-map-orbit-lunarFrontier')),
      findsOneWidget,
    );
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
      greaterThanOrEqualTo(140),
    );
    expect(
      find.byKey(const Key('stellar-map-planet-homeworld-summary')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('stellar-map-planet-homeworld-summary')),
        matching: find.text('0.00/s · 0 cargo · +0'),
      ),
      findsOneWidget,
    );
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
      find.descendant(of: mars, matching: find.text('LOCKED')).first,
      findsOneWidget,
    );
    expect(
      find.descendant(of: mars, matching: find.text('Homeworld sites 0/3')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: mars,
        matching: find.text('Lunar Frontier sites 0/3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mars, matching: find.text('Surveying 5')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mars, matching: find.text('20000 cash')),
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
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('stellar-map-site-marsFrontier-silicaDunes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('stellar-map-site-marsFrontier-cobaltChasm')),
      findsOneWidget,
    );
  });

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
        cash: 20_000,
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
        expect(indicators, findsNWidgets(3));
      }
    }
  });
}
