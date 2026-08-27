import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/presentation/offline_return_sheet.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

void main() {
  testWidgets('renders one section per producing planet with catalog-resolved '
      'full sites', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const summary = OfflineProductionSummary(
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
        matching: find.byIcon(
          MiningContentRegistry.resourceSilhouettes[ResourceType.gold]!.icon,
        ),
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

  testWidgets('renders the Logistics 2 offline cap in the capped message', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    final summary = OfflineProductionSummary(
      elapsedUsed: content.offlineCapFor(2),
      produced: const {ResourceType.gold: 1.0},
      productionByPlanet: const {
        MiningPlanetId.homeworld: {ResourceType.gold: 1.0},
      },
      fullSites: const {},
      wasOfflineCapped: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineReturnSheet(summary: summary, content: content),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Offline production was capped at 12h 0m.'),
      findsOneWidget,
    );
    expect(
      find.text('Offline production was capped at 8 hours.'),
      findsNothing,
    );
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
      elapsedUsed: Duration(minutes: 30),
      produced: {ResourceType.gold: 1},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 1},
      },
      fullSites: {},
      wasOfflineCapped: false,
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: OfflineReturnSheet(
              summary: summary,
              content: MiningContentRegistry.stellarMining(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final dismiss = find.byKey(const Key('offline-return-dismiss'));
    expect(tester.getSize(dismiss).height, greaterThanOrEqualTo(48));
    expect(MiningVisuals.offlineHero, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
