import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/grid.dart';
import 'package:horologium/game/planet/planet.dart';
import 'package:horologium/game/planet/placed_building_data.dart';
import 'package:horologium/game/services/save_service.dart';

void main() {
  group('Planet Placement Persistence Integration Tests', () {
    late Planet planet;
    late Grid grid;
    bool planetSaved = false;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      
      // Create a planet
      planet = Planet(
        id: 'earth',
        name: 'Earth',
      );
      
      // Create grid with callbacks
      grid = Grid(
        onBuildingPlaced: (x, y, building) {
          final buildingData = PlacedBuildingData(
            x: x,
            y: y,
            type: building.type,
            level: building.level,
            assignedWorkers: building.assignedWorkers,
          );
          planet.addBuilding(buildingData);
          planetSaved = true; // Track that planet would be saved
        },
        onBuildingRemoved: (x, y) {
          planet.removeBuildingAt(x, y);
          planetSaved = true; // Track that planet would be saved
        },
      );
      
      planetSaved = false;
    });

    test('building placement updates planet and triggers save', () async {
      // Arrange
      final building = BuildingRegistry.availableBuildings.first;
      expect(planet.buildings, isEmpty);
      
      // Act - Place building through grid (simulates placement manager)
      grid.placeBuilding(2, 3, building);
      
      // Assert - Planet updated
      expect(planetSaved, isTrue);
      final buildings = planet.buildings;
      expect(buildings, hasLength(1));
      expect(buildings.first.x, equals(2));
      expect(buildings.first.y, equals(3));
      expect(buildings.first.type, equals(building.type));
      
      // Verify grid and planet are in sync
      expect(grid.getBuildingAt(2, 3)?.type, equals(building.type));
    });

    test('building removal updates planet and triggers save', () async {
      // Arrange - Start with a building
      final building = BuildingRegistry.availableBuildings
          .where((b) => b.type == BuildingType.house)
          .first;
      grid.placeBuilding(5, 7, building);
      planetSaved = false; // Reset save tracking
      
      expect(planet.buildings, hasLength(1));
      expect(grid.getBuildingAt(5, 7), isNotNull);
      
      // Act - Remove building through grid (simulates scene widget)
      grid.removeBuilding(5, 7);
      
      // Assert - Planet updated
      expect(planetSaved, isTrue);
      expect(planet.buildings, isEmpty);
      expect(grid.getBuildingAt(5, 7), isNull);
    });

    test('multiple placements maintain consistency', () async {
      // Arrange
      final building1 = BuildingRegistry.availableBuildings
          .where((b) => b.type == BuildingType.powerPlant)
          .first;
      final building2 = BuildingRegistry.availableBuildings
          .where((b) => b.type == BuildingType.goldMine)
          .first;
      
      // Act - Place multiple buildings
      grid.placeBuilding(1, 1, building1);
      grid.placeBuilding(10, 10, building2);
      
      // Assert - Both in planet
      final buildings = planet.buildings;
      expect(buildings, hasLength(2));
      
      final positions = buildings.map((b) => '${b.x},${b.y}').toSet();
      expect(positions, contains('1,1'));
      expect(positions, contains('10,10'));
      
      // Assert - Both in grid
      expect(grid.getBuildingAt(1, 1)?.type, equals(BuildingType.powerPlant));
      expect(grid.getBuildingAt(10, 10)?.type, equals(BuildingType.goldMine));
    });

    test('end-to-end persistence through SaveService', () async {
      // Arrange
      final building = BuildingRegistry.availableBuildings
          .where((b) => b.type == BuildingType.house)
          .first;
      
      // Act - Place building and save planet
      grid.placeBuilding(0, 0, building);
      await SaveService.savePlanet(planet);
      
      // Load a fresh planet from storage
      final loadedPlanet = await SaveService.loadOrCreatePlanet('earth');
      
      // Assert - Building persisted
      final loadedBuildings = loadedPlanet.buildings;
      expect(loadedBuildings, hasLength(1));
      expect(loadedBuildings.first.x, equals(0));
      expect(loadedBuildings.first.y, equals(0));
      expect(loadedBuildings.first.type, equals(BuildingType.house));
    });

    test('removal after persistence works correctly', () async {
      // Arrange - Place and save building
      final building = BuildingRegistry.availableBuildings
          .where((b) => b.type == BuildingType.researchLab)
          .first;
      grid.placeBuilding(8, 9, building);
      await SaveService.savePlanet(planet);
      
      // Act - Remove building and save again
      grid.removeBuilding(8, 9);
      await SaveService.savePlanet(planet);
      
      // Load fresh planet
      final loadedPlanet = await SaveService.loadOrCreatePlanet('earth');
      
      // Assert - Building removed from persistence
      expect(loadedPlanet.buildings, isEmpty);
    });
  });
}
