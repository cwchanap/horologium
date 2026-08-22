import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/presentation/offline_return_sheet.dart';

void main() {
  testWidgets('renders one section per producing planet with catalog-resolved '
      'full sectors', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const summary = OfflineProductionSummary(
      elapsedUsed: Duration(hours: 2),
      produced: {ResourceType.gold: 5.0, ResourceType.waterIce: 20.0},
      productionByPlanet: {
        MiningPlanetId.homeworld: {ResourceType.gold: 5.0},
        MiningPlanetId.lunarFrontier: {ResourceType.waterIce: 20.0},
      },
      fullSectors: {MiningSectorId.graniteCrater, MiningSectorId.heliumMare},
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

    final homeworld = find.byKey(const Key('offline-return-planet-homeworld'));
    final lunar = find.byKey(const Key('offline-return-planet-lunarFrontier'));
    expect(homeworld, findsOneWidget);
    expect(lunar, findsOneWidget);

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

    // fullSectors is flat; each sector name resolves to its own planet
    // section via the catalog.
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

    expect(tester.takeException(), isNull);
  });
}
