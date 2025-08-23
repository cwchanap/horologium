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
      planet.addBuilding(const PlacedBuildingData(
        x: 10,
        y: 10,
        type: BuildingType.house,
      ));
      
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
        grid.placeBuilding(buildingData.x, buildingData.y, building, notifyCallbacks: false);
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
      planet.addBuilding(const PlacedBuildingData(
        x: 5,
        y: 5,
        type: BuildingType.powerPlant,
      ));
      planet.addBuilding(const PlacedBuildingData(
        x: 10,
        y: 10,
        type: BuildingType.house,
      ));

      expect(planet.buildings.length, 2);

      // Create grid and load buildings
      final grid = Grid();
      for (final buildingData in planet.buildings) {
        final building = buildingData.createBuilding();
        grid.placeBuilding(buildingData.x, buildingData.y, building, notifyCallbacks: false);
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
      final house = BuildingRegistry.availableBuildings
          .firstWhere((b) => b.type == BuildingType.house);
      final powerPlant = BuildingRegistry.availableBuildings
          .firstWhere((b) => b.type == BuildingType.powerPlant);

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
  });
}
