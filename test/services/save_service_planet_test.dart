import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/planet/index.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/services/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SaveService Planet APIs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('savePlanet and loadOrCreatePlanet', () {
      test('should save and load happiness correctly', () async {
        // Create a test planet with custom happiness
        final planet = Planet(id: 'test_happiness', name: 'Happiness Test');
        planet.resources.happiness = 75.0;

        // Save the planet
        await SaveService.savePlanet(planet);

        // Load the planet back
        final loadedPlanet = await SaveService.loadOrCreatePlanet(
          'test_happiness',
          name: 'Happiness Test',
        );

        // Verify happiness is preserved
        expect(loadedPlanet.resources.happiness, 75.0);
      });

      test('should default happiness to 50 when not saved', () async {
        // Load a planet that doesn't exist
        final planet = await SaveService.loadOrCreatePlanet(
          'new_planet_happiness',
          name: 'New Planet',
        );

        // Verify default happiness value
        expect(planet.resources.happiness, 50.0);
      });

      test('should save and load planet data correctly', () async {
        // Create a test planet with some data
        final planet = Planet(id: 'test', name: 'Test Planet');
        planet.resources.cash = 5000.0;
        planet.resources.gold = 100.0;
        planet.resources.population = 50;
        planet.resources.availableWorkers = 30;

        // Add some research
        planet.researchManager.completeResearch(ResearchType.electricity);
        planet.researchManager.completeResearch(ResearchType.goldMining);

        // Add some building limits
        planet.buildingLimitManager.increaseBuildingLimit(
          BuildingType.powerPlant,
          2,
        );

        // Add some buildings
        planet.addBuilding(
          const PlacedBuildingData(
            x: 5,
            y: 5,
            type: BuildingType.house,
            level: 2,
            assignedWorkers: 1,
          ),
        );
        planet.addBuilding(
          const PlacedBuildingData(x: 10, y: 10, type: BuildingType.powerPlant),
        );

        // Save the planet
        await SaveService.savePlanet(planet);

        // Load the planet back
        final loadedPlanet = await SaveService.loadOrCreatePlanet(
          'test',
          name: 'Test Planet',
        );

        // Verify all data is preserved
        expect(loadedPlanet.id, 'test');
        expect(loadedPlanet.name, 'Test Planet');
        expect(loadedPlanet.resources.cash, 5000.0);
        expect(loadedPlanet.resources.gold, 100.0);
        expect(loadedPlanet.resources.population, 50);
        expect(loadedPlanet.resources.availableWorkers, 30);

        expect(
          loadedPlanet.researchManager.isResearched(ResearchType.electricity),
          true,
        );
        expect(
          loadedPlanet.researchManager.isResearched(ResearchType.goldMining),
          true,
        );
        expect(
          loadedPlanet.researchManager.isResearched(
            ResearchType.expansionPlanning,
          ),
          false,
        );

        expect(
          loadedPlanet.buildingLimitManager.getBuildingLimit(
            BuildingType.powerPlant,
          ),
          6,
        ); // 4 + 2

        expect(loadedPlanet.buildings.length, 2);
        final house = loadedPlanet.buildings.firstWhere(
          (b) => b.type == BuildingType.house,
        );
        expect(house.x, 5);
        expect(house.y, 5);
        expect(house.level, 2); // Level is now preserved
        expect(house.assignedWorkers, 1); // Worker count is now preserved

        final powerPlant = loadedPlanet.buildings.firstWhere(
          (b) => b.type == BuildingType.powerPlant,
        );
        expect(powerPlant.x, 10);
        expect(powerPlant.y, 10);
        expect(powerPlant.level, 1); // Default level
        expect(powerPlant.assignedWorkers, 0); // Default worker count
      });

      test('should create new planet when no data exists', () async {
        final planet = await SaveService.loadOrCreatePlanet(
          'new_planet',
          name: 'New Planet',
        );

        expect(planet.id, 'new_planet');
        expect(planet.name, 'New Planet');
        expect(planet.resources.cash, 1000.0); // Default value
        expect(planet.resources.population, 20); // Default value
        expect(planet.buildings.isEmpty, true);
        expect(planet.researchManager.completedResearch.isEmpty, true);
      });
    });

    group('active planet ID', () {
      test('should save and load active planet ID', () async {
        await SaveService.saveActivePlanetId('earth');
        final loadedId = await SaveService.loadActivePlanetId();
        expect(loadedId, 'earth');
      });

      test('should return null when no active planet ID is saved', () async {
        final loadedId = await SaveService.loadActivePlanetId();
        expect(loadedId, null);
      });
    });

    group('migration from legacy data', () {
      test('should migrate legacy save data to Earth planet', () async {
        // Set up legacy data
        SharedPreferences.setMockInitialValues({
          'cash': 2000.0,
          'population': 40,
          'availableWorkers': 25,
          'gold': 50.0,
          'wood': 30.0,
          'coal': 20.0,
          'electricity': 10.0,
          'research': 5.0,
          'water': 15.0,
          'completed_research': ['electricity', 'gold_mining'],
          'buildings': ['5,5,house', '10,10,powerPlant'],
        });

        // Load should trigger migration
        final earth = await SaveService.loadOrCreatePlanet(
          'earth',
          name: 'Earth',
        );

        expect(earth.id, 'earth');
        expect(earth.name, 'Earth');
        expect(earth.resources.cash, 2000.0);
        expect(earth.resources.population, 40);
        expect(earth.resources.availableWorkers, 25);
        expect(earth.resources.gold, 50.0);
        expect(earth.resources.wood, 30.0);
        expect(earth.resources.coal, 20.0);
        expect(earth.resources.electricity, 10.0);
        expect(earth.resources.research, 5.0);
        expect(earth.resources.water, 15.0);

        expect(earth.researchManager.isResearchedById('electricity'), true);
        expect(earth.researchManager.isResearchedById('gold_mining'), true);

        expect(earth.buildings.length, 2);
        final house = earth.buildings.firstWhere(
          (b) => b.type == BuildingType.house,
        );
        expect(house.x, 5);
        expect(house.y, 5);

        // Verify data was saved to new planet format
        final activePlanetId = await SaveService.loadActivePlanetId();
        expect(activePlanetId, 'earth');
      });

      test('should not migrate when planet data already exists', () async {
        // Set up both legacy data and planet data
        SharedPreferences.setMockInitialValues({
          'cash': 2000.0, // Legacy
          'planet.earth.resources.cash': 3000.0, // Planet format
          'population': 40, // Legacy
          'planet.earth.population': 60, // Planet format
        });

        final earth = await SaveService.loadOrCreatePlanet(
          'earth',
          name: 'Earth',
        );

        // Should use planet format data, not legacy
        expect(earth.resources.cash, 3000.0);
        expect(earth.resources.population, 60);
      });

      test('should not migrate for non-earth planets', () async {
        // Set up legacy data
        SharedPreferences.setMockInitialValues({
          'cash': 2000.0,
          'population': 40,
        });

        // Load a different planet should not trigger migration
        final mars = await SaveService.loadOrCreatePlanet('mars', name: 'Mars');

        expect(mars.id, 'mars');
        expect(mars.name, 'Mars');
        expect(mars.resources.cash, 1000.0); // Default, not migrated
        expect(mars.resources.population, 20); // Default, not migrated
      });
    });
  });
}
