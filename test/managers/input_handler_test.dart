import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/managers/building_placement_manager.dart';
import 'package:horologium/game/managers/input_handler.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

import 'test_game_manager_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Building createBuilding({
    BuildingType type = BuildingType.powerPlant,
    String name = 'Power Plant',
    String description = 'Generates electricity for the colony.',
    int cost = 100,
  }) {
    return Building(
      type: type,
      name: name,
      description: description,
      icon: Icons.bolt,
      color: Colors.amber,
      baseCost: cost,
      baseGeneration: {ResourceType.electricity: 1},
      baseConsumption: {ResourceType.coal: 1},
      requiredWorkers: 0,
      category: BuildingCategory.services,
    );
  }

  Future<BuildContext> pumpInputHarness(WidgetTester tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    return capturedContext;
  }

  group('InputHandler', () {
    late TestGameManagerContext game;
    late Resources resources;
    late BuildingPlacementManager placementManager;
    late InputHandler inputHandler;
    late int resourcesChangedCount;
    late List<int>? emptyGridTapCoordinates;
    late List<Object>? longTapArgs;

    setUp(() {
      game = TestGameManagerContext();
      resources = Resources()..resources[ResourceType.cash] = 1000;
      resourcesChangedCount = 0;
      emptyGridTapCoordinates = null;
      longTapArgs = null;
      placementManager = BuildingPlacementManager(
        game: game,
        resources: resources,
        buildingLimitManager: BuildingLimitManager(),
        onResourcesChanged: () => resourcesChangedCount++,
      );
      inputHandler = InputHandler(
        game: game,
        resources: resources,
        placementManager: placementManager,
        onEmptyGridTapped: (x, y) => emptyGridTapCoordinates = [x, y],
        onBuildingLongTapped: (x, y, building) =>
            longTapArgs = [x, y, building],
        onResourcesChanged: () => resourcesChangedCount++,
      );
    });

    testWidgets('cancel tap clears placement when coordinates are -1,-1', (
      tester,
    ) async {
      final context = await pumpInputHarness(tester);
      final building = createBuilding();
      game.buildingToPlace = building;

      inputHandler.handleGridCellTapped(-1, -1, context);

      expect(game.buildingToPlace, isNull);
      expect(game.hidePlacementPreviewCallCount, equals(1));
      expect(emptyGridTapCoordinates, isNull);
    });

    testWidgets('tapping a placed building opens its details dialog', (
      tester,
    ) async {
      final context = await pumpInputHarness(tester);
      final building = createBuilding();
      game.grid.placeBuilding(4, 7, building);

      inputHandler.handleGridCellTapped(4, 7, context);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(building.name), findsOneWidget);
      expect(find.text(building.description), findsOneWidget);
      expect(find.text('Upgrade (${building.upgradeCost})'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(emptyGridTapCoordinates, isNull);
    });

    testWidgets('tapping an empty grid cell forwards its coordinates', (
      tester,
    ) async {
      final context = await pumpInputHarness(tester);

      inputHandler.handleGridCellTapped(3, 5, context);

      expect(emptyGridTapCoordinates, equals([3, 5]));
      expect(find.byType(AlertDialog), findsNothing);
    });

    test('long press on a building forwards x, y, and the building', () {
      final building = createBuilding();
      game.grid.placeBuilding(6, 2, building);

      inputHandler.handleGridCellLongTapped(6, 2);

      expect(longTapArgs, isNotNull);
      expect(longTapArgs![0], equals(6));
      expect(longTapArgs![1], equals(2));
      expect(longTapArgs![2], same(building));
    });
  });
}
