import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/offline_return_sheet.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

final _now = DateTime.utc(2026, 8, 26, 12);

SiteProgress _site({double stored = 0}) => SiteProgress(
  unlocked: true,
  commissioned: true,
  storedAmount: stored,
  rigPlacements: const [],
);

MiningSave _state({
  int relaunchCount = 0,
  Set<MiningPlanetId>? unlockedPlanets,
  Map<MiningSiteId, SiteProgress>? sites,
}) {
  final base = MiningSave.initial(nowUtc: _now, relaunchCount: relaunchCount);
  return base.copyWith(
    unlockedPlanetIds: unlockedPlanets,
    sites: sites == null ? null : {...base.sites, ...sites},
  );
}

void main() {
  // Real Orbitron metrics: the test font's square glyphs understate line
  // height, hiding footer overlap on the small viewports.
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

  testWidgets('landscape continue action is visible without scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(874, 402);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.zero,
              child: OfflineReturnSheet(
                content: MiningContentRegistry.stellarMining(),
                state: _state(),
                onSellCargo: () {},
                summary: const OfflineProductionSummary(
                  elapsedAway: Duration(hours: 30),
                  elapsedUsed: Duration(hours: 24),
                  produced: {ResourceType.gold: 742.5},
                  productionByPlanet: {
                    MiningPlanetId.homeworld: {
                      ResourceType.gold: 742.5,
                      ResourceType.coal: 318,
                      ResourceType.stone: 96.4,
                    },
                  },
                  fullSites: {MiningSiteId.landingBasin},
                  wasOfflineCapped: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final button = find.byKey(const Key('offline-return-sell-all'));
    expect(button.hitTestable(), findsOneWidget);
    final report = find.byKey(const Key('offline-return-planet-homeworld'));
    expect(tester.widget<Container>(report).decoration, isNull);
    expect(tester.getRect(report).top, 52);
    expect(tester.getRect(report).left, 421);
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(402));
    expect(find.text('Away\n30h 00m'), findsOneWidget);
    expect(find.text('Capped at 24h 00m.'), findsOneWidget);
    expect(find.textContaining('Logistics'), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('offline-return-cap'))).bottom,
      lessThanOrEqualTo(402),
    );
    expect(
      tester.getRect(find.text('Storage full: Landing Basin.')).bottom,
      lessThanOrEqualTo(402),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders one section per producing planet with catalog-resolved '
      'full sites', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const summary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 2),
      elapsedUsed: Duration(hours: 2),
      produced: {
        ResourceType.gold: 5.0,
        ResourceType.waterIce: 20.0,
        ResourceType.ironOre: 8.0,
      },
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 5.0},
        MiningPlanetId.lunarFrontier: {ResourceType.waterIce: 20.0},
        MiningPlanetId.marsFrontier: {ResourceType.ironOre: 8.0},
      },
      fullSites: {
        MiningSiteId.graniteCrater,
        MiningSiteId.heliumMare,
        MiningSiteId.cobaltChasm,
      },
      wasOfflineCapped: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineReturnSheet(
            summary: summary,
            content: MiningContentRegistry.stellarMining(),
            state: _state(),
            onSellCargo: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Image>(find.byKey(const Key('offline-return-hero'))).image,
      isA<AssetImage>(),
    );

    final homeworld = find.byKey(const Key('offline-return-planet-homeworld'));
    final lunar = find.byKey(const Key('offline-return-planet-lunarFrontier'));
    final mars = find.byKey(const Key('offline-return-planet-marsFrontier'));
    expect(homeworld, findsOneWidget);
    expect(lunar, findsOneWidget);
    expect(mars, findsOneWidget);

    // Each planet's production rows and silhouettes live under its section.
    expect(
      find.descendant(of: homeworld, matching: find.text('Gold')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: homeworld,
        matching: find.byKey(const Key('offline-resource-gold')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: homeworld, matching: find.text('+5.0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lunar, matching: find.text('Water Ice')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: lunar,
        matching: find.byIcon(
          MiningContentRegistry
              .resourceSilhouettes[ResourceType.waterIce]!
              .icon,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lunar, matching: find.text('+20.0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mars, matching: find.text('Iron Ore')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mars,
        matching: find.byIcon(
          MiningContentRegistry.resourceSilhouettes[ResourceType.ironOre]!.icon,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mars, matching: find.text('+8.0')),
      findsOneWidget,
    );

    // fullSites is flat; each site name resolves to its own planet section
    // via the catalog.
    expect(
      find.descendant(
        of: homeworld,
        matching: find.text('Storage full: Granite Crater.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: lunar,
        matching: find.text('Storage full: Helium Mare.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mars,
        matching: find.text('Storage full: Cobalt Chasm.'),
      ),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('lists a Ceres section with its silhouettes at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const summary = OfflineProductionSummary(
        elapsedAway: Duration(hours: 2),
        elapsedUsed: Duration(hours: 2),
        produced: {
          ResourceType.nickelOre: 4320.0,
          ResourceType.platinum: 3240.0,
          ResourceType.iridium: 12.5,
        },
        productionByPlanet: {
          MiningPlanetId.ceresFrontier: {
            ResourceType.nickelOre: 4320.0,
            ResourceType.platinum: 3240.0,
            ResourceType.iridium: 12.5,
          },
        },
        fullSites: {MiningSiteId.nickelShoals},
        wasOfflineCapped: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineReturnSheet(
              summary: summary,
              content: MiningContentRegistry.stellarMining(),
              state: _state(),
              onSellCargo: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final ceres = find.byKey(
        const Key('offline-return-planet-ceresFrontier'),
      );
      expect(ceres, findsOneWidget);
      for (final (resource, name, amount) in const [
        (ResourceType.nickelOre, 'Nickel Ore', '+4,320'),
        (ResourceType.platinum, 'Platinum', '+3,240'),
        (ResourceType.iridium, 'Iridium', '+12.5'),
      ]) {
        expect(
          find.descendant(of: ceres, matching: find.text(name)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: ceres, matching: find.text(amount)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: ceres,
            matching: find.byKey(Key('offline-resource-${resource.name}')),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: ceres,
          matching: find.textContaining('Nickel Shoals'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('lists an Io section with its silhouettes at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const summary = OfflineProductionSummary(
        elapsedAway: Duration(hours: 2),
        elapsedUsed: Duration(hours: 2),
        produced: {
          ResourceType.sulfur: 4320.0,
          ResourceType.cinnabar: 3240.0,
          ResourceType.osmium: 12.5,
        },
        productionByPlanet: {
          MiningPlanetId.ioFrontier: {
            ResourceType.sulfur: 4320.0,
            ResourceType.cinnabar: 3240.0,
            ResourceType.osmium: 12.5,
          },
        },
        fullSites: {MiningSiteId.sulfurFlats},
        wasOfflineCapped: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineReturnSheet(
              summary: summary,
              content: MiningContentRegistry.stellarMining(),
              state: _state(),
              onSellCargo: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final io = find.byKey(const Key('offline-return-planet-ioFrontier'));
      expect(io, findsOneWidget);
      for (final (resource, name, amount) in const [
        (ResourceType.sulfur, 'Sulfur', '+4,320'),
        (ResourceType.cinnabar, 'Cinnabar', '+3,240'),
        (ResourceType.osmium, 'Osmium', '+12.5'),
      ]) {
        expect(
          find.descendant(of: io, matching: find.text(name)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: io, matching: find.text(amount)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: io,
            matching: find.byIcon(
              MiningContentRegistry.resourceSilhouettes[resource]!.icon,
            ),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: io, matching: find.textContaining('Sulfur Flats')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows the full time away and the capped duration', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    const summary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 30),
      elapsedUsed: Duration(hours: 24),
      produced: {ResourceType.gold: 1.0},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 1.0},
      },
      fullSites: {},
      wasOfflineCapped: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineReturnSheet(
            summary: summary,
            content: content,
            state: _state(),
            onSellCargo: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Away\n30h 00m'), findsOneWidget);
    expect(find.text('Capped at 24h 00m.'), findsOneWidget);
  });

  testWidgets('renders large hauls as whole separated units', (tester) async {
    const summary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 2),
      elapsedUsed: Duration(hours: 2),
      produced: {ResourceType.gold: 12960.4},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 12960.4},
      },
      fullSites: {},
      wasOfflineCapped: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineReturnSheet(
            summary: summary,
            content: MiningContentRegistry.stellarMining(),
            state: _state(),
            onSellCargo: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('+12,960'), findsOneWidget);
    expect(find.text('Away\n2h 00m'), findsOneWidget);
  });

  testWidgets('keeps the continue action reachable at phone text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const summary = OfflineProductionSummary(
      elapsedAway: Duration(minutes: 30),
      elapsedUsed: Duration(minutes: 30),
      produced: {ResourceType.gold: 1},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 1},
      },
      fullSites: {},
      wasOfflineCapped: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: OfflineReturnSheet(
              summary: summary,
              content: MiningContentRegistry.stellarMining(),
              state: _state(),
              onSellCargo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final sellAll = find.byKey(const Key('offline-return-sell-all'));
    expect(tester.getSize(sellAll).height, greaterThanOrEqualTo(48));
    expect(MiningVisuals.offlineHero, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reports each planet post-accrual sellable value with the run multiplier',
    (tester) async {
      final content = MiningContentRegistry.stellarMining();
      const summary = OfflineProductionSummary(
        elapsedAway: Duration(hours: 1),
        elapsedUsed: Duration(hours: 1),
        produced: {ResourceType.gold: 5, ResourceType.waterIce: 20},
        productionByPlanet: {
          MiningPlanetId.homeworld: {ResourceType.gold: 5},
          MiningPlanetId.lunarFrontier: {ResourceType.waterIce: 20},
        },
        fullSites: {},
        wasOfflineCapped: false,
      );
      MiningSave sellable({int relaunchCount = 0}) => _state(
        relaunchCount: relaunchCount,
        unlockedPlanets: {
          MiningPlanetId.homeworld,
          MiningPlanetId.lunarFrontier,
        },
        sites: {
          MiningSiteId.landingBasin: _site(stored: 105),
          MiningSiteId.frozenBasin: _site(stored: 20),
        },
      );

      Future<void> pumpSheet(MiningSave state) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineReturnSheet(
              summary: summary,
              content: content,
              state: state,
              onSellCargo: () {},
            ),
          ),
        ),
      );

      String? saleLabel(MiningPlanetId id) => tester
          .widget<Text>(find.byKey(Key('offline-return-sale-${id.name}')))
          .data;

      await pumpSheet(sellable());
      await tester.pump();
      expect(saleLabel(MiningPlanetId.homeworld), '420');
      expect(saleLabel(MiningPlanetId.lunarFrontier), '120');

      await pumpSheet(sellable(relaunchCount: 1));
      await tester.pump();
      expect(saleLabel(MiningPlanetId.homeworld), '630');
      expect(saleLabel(MiningPlanetId.lunarFrontier), '180');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('collapses the warnings only when every authored site is full', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    const summary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 1),
      elapsedUsed: Duration(hours: 1),
      produced: {ResourceType.gold: 5, ResourceType.waterIce: 20},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 5},
        MiningPlanetId.lunarFrontier: {ResourceType.waterIce: 20},
      },
      fullSites: {
        MiningSiteId.landingBasin,
        MiningSiteId.carbonRidge,
        MiningSiteId.graniteCrater,
        MiningSiteId.heliumMare,
      },
      wasOfflineCapped: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineReturnSheet(
            summary: summary,
            content: content,
            state: _state(),
            onSellCargo: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final homeworld = find.byKey(const Key('offline-return-planet-homeworld'));
    final lunar = find.byKey(const Key('offline-return-planet-lunarFrontier'));
    expect(
      find.descendant(
        of: homeworld,
        matching: find.text('All 3 sites full · sell to resume'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: homeworld,
        matching: find.textContaining('Storage full:'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: lunar,
        matching: find.text('Storage full: Helium Mare.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lunar, matching: find.textContaining('sites full')),
      findsNothing,
    );

    // Selling clears cargo on every unlocked planet, so the all-full prompt
    // reads the same whether or not the planet is active.
    const nonActiveAllFullSummary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 1),
      elapsedUsed: Duration(hours: 1),
      produced: {ResourceType.gold: 5, ResourceType.waterIce: 20},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 5},
        MiningPlanetId.lunarFrontier: {ResourceType.waterIce: 20},
      },
      fullSites: {
        MiningSiteId.heliumMare,
        MiningSiteId.frozenBasin,
        MiningSiteId.titaniumHighlands,
      },
      wasOfflineCapped: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineReturnSheet(
            summary: nonActiveAllFullSummary,
            content: content,
            state: _state(), // active is homeworld
            onSellCargo: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final lunarCard = find.byKey(
      const Key('offline-return-planet-lunarFrontier'),
    );
    expect(
      find.descendant(
        of: lunarCard,
        matching: find.text('All 3 sites full · sell to resume'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: homeworld, matching: find.text('+5.0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lunar, matching: find.text('+20.0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SELL ALL reports the all-unlocked-planet sale total', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    const summary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 1),
      elapsedUsed: Duration(hours: 1),
      produced: {ResourceType.gold: 5, ResourceType.waterIce: 20},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 5},
        MiningPlanetId.lunarFrontier: {ResourceType.waterIce: 20},
      },
      fullSites: {},
      wasOfflineCapped: false,
    );
    final state = _state(
      unlockedPlanets: {MiningPlanetId.homeworld, MiningPlanetId.lunarFrontier},
      sites: {
        MiningSiteId.landingBasin: _site(stored: 105),
        MiningSiteId.frozenBasin: _site(stored: 20),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineReturnSheet(
            summary: summary,
            content: content,
            state: state,
            onSellCargo: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('SELL ALL · +540'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Sell all cargo for 540 cash.'),
      findsOneWidget,
    );
  });

  testWidgets('SELL ALL pops the sheet before invoking the sale once', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    const summary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 1),
      elapsedUsed: Duration(hours: 1),
      produced: {ResourceType.gold: 5},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 5},
      },
      fullSites: {},
      wasOfflineCapped: false,
    );
    final state = _state(
      sites: {MiningSiteId.landingBasin: _site(stored: 105)},
    );
    var sales = 0;
    var routeCurrentAtCallback = true;
    ModalRoute<dynamic>? sheetRoute;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: OutlinedButton(
              key: const Key('open-return'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (sheetContext) {
                  sheetRoute = ModalRoute.of(sheetContext);
                  return OfflineReturnSheet(
                    summary: summary,
                    content: content,
                    state: state,
                    onSellCargo: () {
                      sales++;
                      routeCurrentAtCallback = sheetRoute?.isCurrent ?? true;
                    },
                  );
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-return')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('offline-return-sell-all')));
    expect(sales, 1);
    expect(routeCurrentAtCallback, isFalse);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
  });

  testWidgets('SELL ALL is a semantic button whose tap sells once', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    const summary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 1),
      elapsedUsed: Duration(hours: 1),
      produced: {ResourceType.gold: 5},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 5},
      },
      fullSites: {},
      wasOfflineCapped: false,
    );
    var sales = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: OutlinedButton(
              key: const Key('open-return'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => OfflineReturnSheet(
                  summary: summary,
                  content: content,
                  state: _state(
                    sites: {MiningSiteId.landingBasin: _site(stored: 105)},
                  ),
                  onSellCargo: () => sales++,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-return')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final semantics = tester.ensureSemantics();

    final node = tester
        .getSemantics(find.bySemanticsLabel('Sell all cargo for 420 cash.'))
        .getSemanticsData();
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.performAction(
      find.semantics.byLabel('Sell all cargo for 420 cash.'),
      SemanticsAction.tap,
    );
    expect(sales, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
    semantics.dispose();
  });

  testWidgets('the continue action pops without selling', (tester) async {
    final content = MiningContentRegistry.stellarMining();
    const summary = OfflineProductionSummary(
      elapsedAway: Duration(hours: 1),
      elapsedUsed: Duration(hours: 1),
      produced: {ResourceType.gold: 5},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 5},
      },
      fullSites: {},
      wasOfflineCapped: false,
    );
    var sales = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: OutlinedButton(
              key: const Key('open-return'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => OfflineReturnSheet(
                  summary: summary,
                  content: content,
                  state: _state(
                    sites: {MiningSiteId.landingBasin: _site(stored: 105)},
                  ),
                  onSellCargo: () => sales++,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-return')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.bySemanticsLabel('Continue mining'));
    await tester.pumpAndSettle();

    expect(sales, 0);
    expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
  });

  for (final scale in const [1.0, 1.3]) {
    testWidgets('the all-full warning scrolls fully clear of the footer at '
        '360x640 and ${scale}x text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final content = MiningContentRegistry.stellarMining();
      const summary = OfflineProductionSummary(
        elapsedAway: Duration(hours: 1),
        elapsedUsed: Duration(hours: 1),
        produced: {ResourceType.gold: 5},
        productionByPlanet: {
          MiningPlanetId.homeworld: {ResourceType.gold: 5},
        },
        fullSites: {
          MiningSiteId.landingBasin,
          MiningSiteId.carbonRidge,
          MiningSiteId.graniteCrater,
        },
        wasOfflineCapped: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: OfflineReturnSheet(
                summary: summary,
                content: content,
                state: _state(),
                onSellCargo: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final warning = find.text('All 3 sites full · sell to resume');
      expect(warning, findsOneWidget);
      final footerTop = tester
          .getRect(find.byKey(const Key('offline-return-footer')))
          .top;
      for (var i = 0; i < 10; i++) {
        if (tester.getRect(warning).bottom <= footerTop) break;
        await tester.drag(
          find.byKey(const Key('offline-return-scroll')),
          const Offset(0, -60),
        );
        await tester.pump();
      }
      final rect = tester.getRect(warning);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(footerTop));
      expect(warning.hitTestable(), findsOneWidget);
      expect(
        find.bySemanticsLabel('All 3 sites full · sell to resume'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    testWidgets('pins the footer below all five planet reports at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineReturnSheet(
              summary: _fivePlanetSummary,
              content: MiningContentRegistry.stellarMining(),
              state: _state(),
              onSellCargo: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final scroll = tester.getRect(
        find.byKey(const Key('offline-return-scroll')),
      );
      final footer = tester.getRect(
        find.byKey(const Key('offline-return-footer')),
      );
      // The fixed footer and the scrolling viewport never share pixels.
      expect(scroll.bottom, lessThanOrEqualTo(footer.top));
      expect(footer.bottom, size.height);
      expect(
        tester.getRect(find.byKey(const Key('mining-cash-chip'))).top,
        greaterThanOrEqualTo(0),
      );
      expect(
        find.byKey(const Key('offline-return-sell-all')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('offline-return-next-action')).hitTestable(),
        findsOneWidget,
      );
      for (final planet in MiningPlanetId.values) {
        expect(
          find.byKey(Key('offline-return-planet-${planet.name}')),
          findsOneWidget,
        );
      }

      // Every planet report is reachable by scrolling the list only.
      await tester.ensureVisible(find.text('Sulfur'));
      await tester.pump();
      expect(find.text('Sulfur').hitTestable(), findsOneWidget);
      final lastReport = find.byKey(
        const Key('offline-return-planet-ioFrontier'),
      );
      expect(tester.getRect(lastReport).bottom, lessThanOrEqualTo(footer.top));
      expect(find.byKey(const Key('offline-return-sell-all')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SELL ALL and continue stay pinned and unchanged at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var sales = 0;

      Future<void> openSheet() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: OutlinedButton(
                  key: const Key('open-return'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => OfflineReturnSheet(
                      summary: _fivePlanetSummary,
                      content: MiningContentRegistry.stellarMining(),
                      state: _state(),
                      onSellCargo: () => sales++,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('open-return')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await openSheet();
      final sellAll = find.byKey(const Key('offline-return-sell-all'));
      expect(sellAll.hitTestable(), findsOneWidget);
      await tester.tap(sellAll);
      expect(sales, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offline-return-sheet')), findsNothing);

      await openSheet();
      await tester.tap(find.bySemanticsLabel('Continue mining'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
      expect(sales, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps the pinned footer clear of the bottom safe-area inset', (
    tester,
  ) async {
    const padBottom = 34.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(
      left: 0,
      top: 0,
      right: 0,
      bottom: padBottom,
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineReturnSheet(
            summary: _fivePlanetSummary,
            content: MiningContentRegistry.stellarMining(),
            state: _state(),
            onSellCargo: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getRect(find.byKey(const Key('offline-return-sell-all'))).bottom,
      lessThanOrEqualTo(844 - padBottom),
    );
    expect(
      tester
          .getRect(find.byKey(const Key('offline-return-next-action')))
          .bottom,
      lessThanOrEqualTo(844 - padBottom),
    );
    expect(
      tester.getRect(find.byKey(const Key('offline-return-footer'))).bottom,
      844,
    );
    expect(tester.takeException(), isNull);
  });
}

const _fivePlanetSummary = OfflineProductionSummary(
  elapsedAway: Duration(hours: 8),
  elapsedUsed: Duration(hours: 8),
  produced: {
    ResourceType.gold: 10,
    ResourceType.waterIce: 20,
    ResourceType.ironOre: 30,
    ResourceType.nickelOre: 40,
    ResourceType.sulfur: 50,
  },
  productionByPlanet: {
    MiningPlanetId.homeworld: {ResourceType.gold: 10},
    MiningPlanetId.lunarFrontier: {ResourceType.waterIce: 20},
    MiningPlanetId.marsFrontier: {ResourceType.ironOre: 30},
    MiningPlanetId.ceresFrontier: {ResourceType.nickelOre: 40},
    MiningPlanetId.ioFrontier: {ResourceType.sulfur: 50},
  },
  fullSites: {},
  wasOfflineCapped: false,
);
