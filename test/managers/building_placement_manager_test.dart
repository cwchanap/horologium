import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/grid.dart';
import 'package:horologium/game/managers/building_placement_manager.dart';
import 'package:horologium/game/managers/game_manager_context.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

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
      game.buildingToPlace = building;
      game.grid
        ..placeBuilding(0, 0, createBuilding())
        ..placeBuilding(2, 0, createBuilding())
        ..placeBuilding(4, 0, createBuilding())
        ..placeBuilding(6, 0, createBuilding());

      final placed = manager.handleBuildingPlacement(8, 0, context);
      await tester.pump();

      expect(placed, isFalse);
      expect(
        find.text('Building limit reached! Maximum 4 Houses allowed.'),
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
        expect(game.grid.getBuildingAt(5, 5), same(building));
        expect(resources.cash, equals(880));
        expect(game.buildingToPlace, isNull);
        expect(game.hidePlacementPreviewCallCount, equals(1));
        expect(resourcesChangedCount, equals(1));
        expect(find.byType(SnackBar), findsNothing);
      },
    );

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

class TestGameManagerContext implements GameManagerContext {
  @override
  // Safe in these tests because placement manager paths only exercise Grid's
  // internal occupancy methods and never require a mounted Flame game.
  final Grid grid = Grid();

  @override
  Building? buildingToPlace;

  int hidePlacementPreviewCallCount = 0;

  @override
  void hidePlacementPreview() {
    hidePlacementPreviewCallCount++;
  }
}
