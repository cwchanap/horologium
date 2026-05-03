import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/managers/building_placement_manager.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

import 'test_game_manager_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Building createBuilding({
    BuildingType type = BuildingType.house,
    String name = 'House',
    int cost = 120,
  }) {
    return Building(
      type: type,
      name: name,
      description: 'Test building',
      icon: Icons.home,
      color: Colors.green,
      baseCost: cost,
      requiredWorkers: 0,
      category: BuildingCategory.residential,
    );
  }

  Future<BuildContext> pumpPlacementHarness(WidgetTester tester) async {
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

  group('BuildingPlacementManager', () {
    late TestGameManagerContext game;
    late Resources resources;
    late BuildingLimitManager buildingLimitManager;
    late int resourcesChangedCount;
    late BuildingPlacementManager manager;

    setUp(() {
      game = TestGameManagerContext();
      resources = Resources()..resources[ResourceType.cash] = 1000;
      buildingLimitManager = BuildingLimitManager();
      resourcesChangedCount = 0;
      manager = BuildingPlacementManager(
        game: game,
        resources: resources,
        buildingLimitManager: buildingLimitManager,
        onResourcesChanged: () => resourcesChangedCount++,
      );
    });

    testWidgets('returns false when no building is selected', (tester) async {
      final context = await pumpPlacementHarness(tester);

      final placed = manager.handleBuildingPlacement(2, 3, context);

      expect(placed, isFalse);
      expect(game.grid.getBuildingAt(2, 3), isNull);
      expect(resourcesChangedCount, equals(0));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'shows invalid-location snackbar and keeps placement mode active',
      (tester) async {
        final context = await pumpPlacementHarness(tester);
        final building = createBuilding();
        game.buildingToPlace = building;
        game.grid.placeBuilding(
          0,
          0,
          createBuilding(type: BuildingType.coalMine),
        );

        final placed = manager.handleBuildingPlacement(0, 0, context);
        await tester.pump();

        expect(placed, isFalse);
        expect(
          find.text('Invalid location: blocked or unsuitable terrain.'),
          findsOneWidget,
        );
        expect(game.buildingToPlace, same(building));
        expect(game.hidePlacementPreviewCallCount, equals(0));
        expect(resourcesChangedCount, equals(0));
      },
    );

    testWidgets('shows snackbar when building limit is reached', (
      tester,
    ) async {
      final context = await pumpPlacementHarness(tester);
      final building = createBuilding();
      final limit = buildingLimitManager.getBuildingLimit(BuildingType.house);
      game.buildingToPlace = building;
      for (var i = 0; i < limit; i++) {
        game.grid.placeBuilding(i * 2, 0, createBuilding());
      }

      final placed = manager.handleBuildingPlacement(limit * 2, 0, context);
      await tester.pump();

      expect(placed, isFalse);
      expect(
        find.text('Building limit reached! Maximum $limit Houses allowed.'),
        findsOneWidget,
      );
      expect(game.buildingToPlace, same(building));
      expect(game.hidePlacementPreviewCallCount, equals(0));
      expect(resourcesChangedCount, equals(0));
    });

    testWidgets('shows snackbar when cash is insufficient', (tester) async {
      final context = await pumpPlacementHarness(tester);
      resources.resources[ResourceType.cash] = 10;
      final building = createBuilding(cost: 50);
      game.buildingToPlace = building;

      final placed = manager.handleBuildingPlacement(3, 3, context);
      await tester.pump();

      expect(placed, isFalse);
      expect(find.text('Insufficient funds!'), findsOneWidget);
      expect(game.grid.getBuildingAt(3, 3), isNull);
      expect(game.buildingToPlace, same(building));
      expect(resources.cash, equals(10));
      expect(resourcesChangedCount, equals(0));
    });

    testWidgets(
      'places a building, deducts cash, clears selection, and hides the preview',
      (tester) async {
        final context = await pumpPlacementHarness(tester);
        final building = createBuilding(cost: 120);
        game.buildingToPlace = building;

        final placed = manager.handleBuildingPlacement(5, 5, context);
        await tester.pump();

        expect(placed, isTrue);
        final placedBuilding = game.grid.getBuildingAt(5, 5);
        expect(placedBuilding, isNotNull);
        expect(placedBuilding, isNot(same(building)));
        expect(placedBuilding!.id, isNot(equals(building.id)));
        expect(placedBuilding.type, equals(building.type));
        expect(placedBuilding.name, equals(building.name));
        expect(resources.cash, equals(880));
        expect(game.buildingToPlace, isNull);
        expect(game.hidePlacementPreviewCallCount, equals(1));
        expect(resourcesChangedCount, equals(1));
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'places repeated Kitchen selections as independent recipe instances',
      (tester) async {
        final context = await pumpPlacementHarness(tester);
        final kitchenTemplate = Kitchen(
          type: BuildingType.kitchen,
          name: 'Kitchen',
          description: 'Prepares food',
          icon: Icons.restaurant,
          color: Colors.deepOrange,
          baseCost: 180,
          requiredWorkers: 1,
          category: BuildingCategory.refinement,
          productType: KitchenProduct.maltDrink,
        )..level = 2;

        game.buildingToPlace = kitchenTemplate;
        expect(manager.handleBuildingPlacement(0, 0, context), isTrue);

        game.buildingToPlace = kitchenTemplate;
        expect(manager.handleBuildingPlacement(3, 0, context), isTrue);

        final firstKitchen = game.grid.getBuildingAt(0, 0)! as Kitchen;
        final secondKitchen = game.grid.getBuildingAt(3, 0)! as Kitchen;

        expect(firstKitchen, isNot(same(kitchenTemplate)));
        expect(secondKitchen, isNot(same(kitchenTemplate)));
        expect(firstKitchen, isNot(same(secondKitchen)));
        expect(firstKitchen.id, isNot(equals(kitchenTemplate.id)));
        expect(secondKitchen.id, isNot(equals(kitchenTemplate.id)));
        expect(firstKitchen.id, isNot(equals(secondKitchen.id)));
        expect(firstKitchen.productType, equals(KitchenProduct.maltDrink));
        expect(secondKitchen.productType, equals(KitchenProduct.maltDrink));
        expect(firstKitchen.level, equals(2));
        expect(secondKitchen.level, equals(2));

        firstKitchen.productType = KitchenProduct.riceMeals;

        expect(firstKitchen.productType, equals(KitchenProduct.riceMeals));
        expect(secondKitchen.productType, equals(KitchenProduct.maltDrink));
        expect(kitchenTemplate.productType, equals(KitchenProduct.maltDrink));

        final graph = ProductionGraph.fromBuildings(
          game.grid.getAllBuildings(),
          resources,
        );
        final kitchenNodeIds = graph.nodes
            .where((node) => node.type == BuildingType.kitchen)
            .map((node) => node.id)
            .toSet();

        expect(kitchenNodeIds.length, equals(2));
        expect(kitchenNodeIds, contains(firstKitchen.id));
        expect(kitchenNodeIds, contains(secondKitchen.id));
      },
    );

    testWidgets('preserves Field and Bakery selected variants on placement', (
      tester,
    ) async {
      final context = await pumpPlacementHarness(tester);
      final fieldTemplate = Field(
        type: BuildingType.field,
        name: 'Field',
        description: 'Grows crops',
        icon: Icons.grass,
        color: Colors.lightGreen,
        baseCost: 50,
        requiredWorkers: 1,
        category: BuildingCategory.foodResources,
        cropType: CropType.barley,
      );
      final bakeryTemplate = Bakery(
        type: BuildingType.bakery,
        name: 'Bakery',
        description: 'Bakes food',
        icon: Icons.bakery_dining,
        color: Colors.orange,
        baseCost: 150,
        requiredWorkers: 1,
        category: BuildingCategory.refinement,
        productType: BakeryProduct.pastries,
      );

      game.buildingToPlace = fieldTemplate;
      expect(manager.handleBuildingPlacement(0, 0, context), isTrue);

      game.buildingToPlace = bakeryTemplate;
      expect(manager.handleBuildingPlacement(3, 0, context), isTrue);

      final placedField = game.grid.getBuildingAt(0, 0)! as Field;
      final placedBakery = game.grid.getBuildingAt(3, 0)! as Bakery;

      expect(placedField, isNot(same(fieldTemplate)));
      expect(placedField.id, isNot(equals(fieldTemplate.id)));
      expect(placedField.cropType, equals(CropType.barley));

      expect(placedBakery, isNot(same(bakeryTemplate)));
      expect(placedBakery.id, isNot(equals(bakeryTemplate.id)));
      expect(placedBakery.productType, equals(BakeryProduct.pastries));
    });

    test('selectBuilding and cancelPlacement update placement state', () {
      final building = createBuilding(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
      );

      manager.selectBuilding(building);
      expect(game.buildingToPlace, same(building));

      manager.cancelPlacement();
      expect(game.buildingToPlace, isNull);
      expect(game.hidePlacementPreviewCallCount, equals(1));
    });
  });
}
