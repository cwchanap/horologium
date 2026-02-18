import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/grid.dart';
import 'package:horologium/game/planet/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Planet-Grid Integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('building placement should update planet via callbacks', () async {
      // Create a test planet
      final planet = Planet(id: 'test', name: 'Test Planet');
      expect(planet.buildings.length, 0);

      bool planetChangedCalled = false;
      Planet? updatedPlanet;

      // Create callbacks that simulate MainGame behavior
      void onBuildingPlaced(int x, int y, Building building) {
        final buildingData = PlacedBuildingData(
          id: 'test-${building.type.name}-$x-$y',
          x: x,
          y: y,
          type: building.type,
          level: building.level,
          assignedWorkers: building.assignedWorkers,
        );

        planet.addBuilding(buildingData);
        planetChangedCalled = true;
        updatedPlanet = planet;
      }

      void onBuildingRemoved(int x, int y) {
        planet.removeBuildingAt(x, y);
        planetChangedCalled = true;
        updatedPlanet = planet;
      }

      // Create grid with callbacks
      final grid = Grid(
        onBuildingPlaced: onBuildingPlaced,
        onBuildingRemoved: onBuildingRemoved,
      );

      // Simulate building placement
      final building = BuildingRegistry.availableBuildings.first;
      grid.placeBuilding(5, 5, building);

      // Verify callback was triggered
      expect(planetChangedCalled, true);
      expect(updatedPlanet, planet);

      // Verify building was added to planet
      expect(planet.buildings.length, 1);
      final placedBuilding = planet.buildings.first;
      expect(placedBuilding.x, 5);
      expect(placedBuilding.y, 5);
      expect(placedBuilding.type, building.type);

      // Simulate building removal
      planetChangedCalled = false;
      grid.removeBuilding(5, 5);

      // Verify removal callback was triggered
      expect(planetChangedCalled, true);

      // Verify building was removed from planet
      expect(planet.buildings.length, 0);
    });

    test('loading buildings should not trigger callbacks', () async {
      // Create a planet with existing buildings
      final planet = Planet(id: 'test', name: 'Test Planet');
      planet.addBuilding(
        const PlacedBuildingData(
          id: 'house-1',
          x: 10,
          y: 10,
          type: BuildingType.house,
        ),
      );

      expect(planet.buildings.length, 1);

      bool planetChangedCalled = false;

      void onBuildingPlaced(int x, int y, Building building) {
        planetChangedCalled = true;
      }

      void onBuildingRemoved(int x, int y) {
        planetChangedCalled = true;
      }

      // Create grid with callbacks
      final grid = Grid(
        onBuildingPlaced: onBuildingPlaced,
        onBuildingRemoved: onBuildingRemoved,
      );

      // Simulate loading buildings (like MainGame.loadBuildings does)
      for (final buildingData in planet.buildings) {
        final building = buildingData.createBuilding();
        if (building == null) continue;
        grid.placeBuilding(
          buildingData.x,
          buildingData.y,
          building,
          notifyCallbacks: false,
        );
      }

      // Verify callbacks were not triggered during loading
      expect(planetChangedCalled, false);
      expect(grid.getAllBuildings().length, 1);

      // Verify the building is in the correct position
      final buildingInGrid = grid.getBuildingAt(10, 10);
      expect(buildingInGrid, isNotNull);
      expect(buildingInGrid!.type, BuildingType.house);
    });

    test('planet state should persist building data correctly', () async {
      // Create a planet with buildings
      final planet = Planet(id: 'test', name: 'Test Planet');
      planet.addBuilding(
        const PlacedBuildingData(
          id: 'power-1',
          x: 5,
          y: 5,
          type: BuildingType.powerPlant,
        ),
      );
      planet.addBuilding(
        const PlacedBuildingData(
          id: 'house-2',
          x: 10,
          y: 10,
          type: BuildingType.house,
        ),
      );

      expect(planet.buildings.length, 2);

      // Create grid and load buildings
      final grid = Grid();
      for (final buildingData in planet.buildings) {
        final building = buildingData.createBuilding();
        if (building == null) continue;
        grid.placeBuilding(
          buildingData.x,
          buildingData.y,
          building,
          notifyCallbacks: false,
        );
      }

      // Verify buildings are loaded correctly
      expect(grid.getAllBuildings().length, 2);
      expect(grid.getBuildingAt(5, 5)?.type, BuildingType.powerPlant);
      expect(grid.getBuildingAt(10, 10)?.type, BuildingType.house);

      // Verify building properties are preserved
      final powerPlantData = planet.getBuildingAt(5, 5)!;
      expect(powerPlantData.type, BuildingType.powerPlant);
      expect(powerPlantData.level, 1); // Default level
      expect(powerPlantData.assignedWorkers, 0); // Default workers

      final houseData = planet.getBuildingAt(10, 10)!;
      expect(houseData.type, BuildingType.house);
      expect(houseData.level, 1);
      expect(houseData.assignedWorkers, 0);
    });

    test('planet buildings should survive callback-driven updates', () async {
      final planet = Planet(id: 'test', name: 'Test Planet');

      void onBuildingPlaced(int x, int y, Building building) {
        final buildingData = PlacedBuildingData(
          id: 'test-${building.type.name}-$x-$y',
          x: x,
          y: y,
          type: building.type,
          level: building.level,
          assignedWorkers: building.assignedWorkers,
        );
        planet.addBuilding(buildingData);
      }

      void onBuildingRemoved(int x, int y) {
        planet.removeBuildingAt(x, y);
      }

      final grid = Grid(
        onBuildingPlaced: onBuildingPlaced,
        onBuildingRemoved: onBuildingRemoved,
      );

      // Place multiple buildings
      final house = BuildingRegistry.availableBuildings.firstWhere(
        (b) => b.type == BuildingType.house,
      );
      final powerPlant = BuildingRegistry.availableBuildings.firstWhere(
        (b) => b.type == BuildingType.powerPlant,
      );

      grid.placeBuilding(5, 5, house);
      grid.placeBuilding(10, 10, powerPlant);

      expect(planet.buildings.length, 2);
      expect(grid.getAllBuildings().length, 2);

      // Remove one building
      grid.removeBuilding(5, 5);

      expect(planet.buildings.length, 1);
      expect(grid.getAllBuildings().length, 1);
      expect(planet.getBuildingAt(5, 5), isNull);
      expect(planet.getBuildingAt(10, 10), isNotNull);
      expect(planet.getBuildingAt(10, 10)!.type, BuildingType.powerPlant);
    });

    test('getAllPlacedBuildings returns correct positions', () async {
      final grid = Grid();

      final house = BuildingRegistry.availableBuildings.firstWhere(
        (b) => b.type == BuildingType.house,
      );
      final powerPlant = BuildingRegistry.availableBuildings.firstWhere(
        (b) => b.type == BuildingType.powerPlant,
      );

      // Place buildings at different positions
      grid.placeBuilding(5, 5, house, notifyCallbacks: false);
      grid.placeBuilding(10, 10, powerPlant, notifyCallbacks: false);

      // Get all placed buildings with positions
      final placedBuildings = grid.getAllPlacedBuildings();

      expect(placedBuildings.length, 2);

      // Verify positions are correct
      expect(placedBuildings.any((pb) => pb.x == 5 && pb.y == 5), true);
      expect(placedBuildings.any((pb) => pb.x == 10 && pb.y == 10), true);

      // Verify building types
      final housePlaced = placedBuildings.firstWhere(
        (pb) => pb.x == 5 && pb.y == 5,
      );
      expect(housePlaced.building.type, BuildingType.house);

      final powerPlantPlaced = placedBuildings.firstWhere(
        (pb) => pb.x == 10 && pb.y == 10,
      );
      expect(powerPlantPlaced.building.type, BuildingType.powerPlant);
    });

    test('worker assignments can be synced from grid to planet', () async {
      final planet = Planet(id: 'test', name: 'Test Planet');

      void onBuildingPlaced(int x, int y, Building building) {
        final buildingData = PlacedBuildingData(
          id: 'test-${building.type.name}-$x-$y',
          x: x,
          y: y,
          type: building.type,
          level: building.level,
          assignedWorkers: building.assignedWorkers,
        );
        planet.addBuilding(buildingData);
      }

      final grid = Grid(onBuildingPlaced: onBuildingPlaced);

      // Place a building that requires workers
      final powerPlant = BuildingRegistry.availableBuildings.firstWhere(
        (b) => b.type == BuildingType.powerPlant && b.requiredWorkers > 0,
      );

      grid.placeBuilding(5, 5, powerPlant);

      // Verify initial state (no workers)
      expect(planet.getBuildingAt(5, 5)!.assignedWorkers, 0);
      expect(grid.getBuildingAt(5, 5)!.assignedWorkers, 0);

      // Simulate worker assignment in grid
      final buildingInGrid = grid.getBuildingAt(5, 5)!;
      buildingInGrid.assignWorker();

      // Verify grid has the worker
      expect(buildingInGrid.assignedWorkers, 1);

      // Sync from grid to planet
      final placedBuildings = grid.getAllPlacedBuildings();
      for (final placedBuilding in placedBuildings) {
        final building = placedBuilding.building;
        final existingData = planet.getBuildingAt(
          placedBuilding.x,
          placedBuilding.y,
        );
        if (existingData != null) {
          final newData = existingData.copyWith(
            level: building.level,
            assignedWorkers: building.assignedWorkers,
          );
          planet.updateBuildingAt(placedBuilding.x, placedBuilding.y, newData);
        }
      }

      // Verify planet now has the worker count
      expect(planet.getBuildingAt(5, 5)!.assignedWorkers, 1);
    });

    test('level changes are synced from grid to planet', () async {
      final planet = Planet(id: 'test', name: 'Test Planet');

      void onBuildingPlaced(int x, int y, Building building) {
        final buildingData = PlacedBuildingData(
          id: 'test-${building.type.name}-$x-$y',
          x: x,
          y: y,
          type: building.type,
          level: building.level,
          assignedWorkers: building.assignedWorkers,
        );
        planet.addBuilding(buildingData);
      }

      final grid = Grid(onBuildingPlaced: onBuildingPlaced);

      // Place a building
      final powerPlant = BuildingRegistry.availableBuildings.firstWhere(
        (b) => b.type == BuildingType.powerPlant,
      );

      grid.placeBuilding(5, 5, powerPlant);

      // Verify initial level
      expect(planet.getBuildingAt(5, 5)!.level, 1);
      expect(grid.getBuildingAt(5, 5)!.level, 1);

      // Upgrade building in grid
      final buildingInGrid = grid.getBuildingAt(5, 5)!;
      buildingInGrid.upgrade();

      // Verify grid has the new level
      expect(buildingInGrid.level, 2);

      // Sync from grid to planet
      final placedBuildings = grid.getAllPlacedBuildings();
      for (final placedBuilding in placedBuildings) {
        final building = placedBuilding.building;
        final existingData = planet.getBuildingAt(
          placedBuilding.x,
          placedBuilding.y,
        );
        if (existingData != null) {
          final newData = existingData.copyWith(
            level: building.level,
            assignedWorkers: building.assignedWorkers,
          );
          planet.updateBuildingAt(placedBuilding.x, placedBuilding.y, newData);
        }
      }

      // Verify planet now has the new level
      expect(planet.getBuildingAt(5, 5)!.level, 2);
    });
  });
}
