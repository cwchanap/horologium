import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/services/save_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Building createBuilding({
    required BuildingType type,
    Map<String, double> generation = const {},
    Map<String, double> consumption = const {},
    int requiredWorkers = 1,
    int assignedWorkers = 0,
    int level = 1,
    BuildingCategory category = BuildingCategory.services,
  }) {
    final building = Building(
      type: type,
      name: 'Test ${type.name}',
      description: 'Test building',
      icon: Icons.build,
      color: Colors.white,
      baseCost: 0,
      baseGeneration: generation,
      baseConsumption: consumption,
      requiredWorkers: requiredWorkers,
      level: level,
      category: category,
    );

    for (int i = 0; i < assignedWorkers; i++) {
      building.assignWorker();
    }

    return building;
  }

  group('Resources.update', () {
    test(
      'generates resources for worker-operated building without consumption',
      () {
        final resources = Resources();
        resources.resources[ResourceType.electricity] = 0;

        final building = createBuilding(
          type: BuildingType.powerPlant,
          generation: const {'electricity': 2},
          requiredWorkers: 1,
          assignedWorkers: 1,
        );

        resources.update([building]);

        expect(resources.electricity, 2);
        expect(
          resources.availableWorkers,
          resources.population - building.assignedWorkers,
        );
      },
    );

    test('does not produce when consumption requirements are unmet', () {
      final resources = Resources();
      resources.resources[ResourceType.coal] = 2;
      resources.resources[ResourceType.electricity] = 5;

      final building = createBuilding(
        type: BuildingType.powerPlant,
        generation: const {'electricity': 3},
        consumption: const {'coal': 5},
        requiredWorkers: 1,
        assignedWorkers: 1,
      );

      resources.update([building]);

      expect(resources.electricity, 5);
      expect(resources.coal, 2);
    });

    test('consumes inputs and produces outputs when requirements are met', () {
      final resources = Resources();
      resources.resources[ResourceType.coal] = 5;
      resources.resources[ResourceType.electricity] = 0;

      final building = createBuilding(
        type: BuildingType.powerPlant,
        generation: const {'electricity': 3},
        consumption: const {'coal': 5},
        requiredWorkers: 1,
        assignedWorkers: 1,
      );

      resources.update([building]);

      expect(resources.electricity, 3);
      expect(resources.coal, 0);
    });

    test('accumulates research output over time for active labs', () {
      final resources = Resources();
      resources.resources[ResourceType.electricity] = 20;
      resources.resources[ResourceType.research] = 0;

      final researchLab = createBuilding(
        type: BuildingType.researchLab,
        generation: const {'research': 1},
        consumption: const {'electricity': 1},
        requiredWorkers: 1,
        assignedWorkers: 1,
      );

      for (int i = 0; i < 9; i++) {
        resources.update([researchLab]);
      }

      expect(resources.research, 0);
      expect(resources.electricity, 11);

      resources.update([researchLab]);

      expect(resources.research, 1);
      expect(resources.electricity, 10);
    });
  });

  group('Resource transactions', () {
    test(
      'buyResource deducts cash and increases inventory when affordable',
      () {
        final resources = Resources();
        resources.cash = 100;
        resources.resources[ResourceType.gold] = 0;

        final success = resources.buyResource(ResourceType.gold, 5);

        expect(success, isTrue);
        expect(resources.cash, 50);
        expect(resources.gold, 5);

        final failure = resources.buyResource(ResourceType.gold, 1000);

        expect(failure, isFalse);
        expect(resources.gold, 5);
      },
    );

    test('sellResource increases cash when inventory is sufficient', () {
      final resources = Resources();
      resources.cash = 0;
      resources.resources[ResourceType.gold] = 10;

      final success = resources.sellResource(ResourceType.gold, 5);

      expect(success, isTrue);
      expect(resources.cash, 40);
      expect(resources.gold, 5);

      final failure = resources.sellResource(ResourceType.gold, 10);

      expect(failure, isFalse);
      expect(resources.cash, 40);
      expect(resources.gold, 5);
    });

    test('legacy trade converts resources using exchange rate', () {
      final resources = Resources();
      resources.resources[ResourceType.wood] = 10;
      resources.resources[ResourceType.gold] = 0;

      resources.trade(ResourceType.wood, ResourceType.gold, 10);

      expect(resources.wood, 0);
      expect(resources.gold, closeTo(8, 1e-9));
    });
  });

  group('Population management', () {
    test('decreasePopulation does nothing when population is 1', () {
      final resources = Resources();
      resources.population = 1;
      resources.availableWorkers = 0;

      final powerPlant = createBuilding(
        type: BuildingType.powerPlant,
        generation: const {'electricity': 2},
        requiredWorkers: 1,
        assignedWorkers: 1,
      );

      final initialPopulation = resources.population;
      final initialWorkers = powerPlant.assignedWorkers;

      resources.decreasePopulation([powerPlant]);

      // Population should remain at 1 (minimum)
      expect(resources.population, initialPopulation);
      // No worker should be unassigned
      expect(powerPlant.assignedWorkers, initialWorkers);
    });

    test('decreasePopulation decreases available workers when available', () {
      final resources = Resources();
      resources.population = 10;
      resources.availableWorkers = 3;

      final powerPlant = createBuilding(
        type: BuildingType.powerPlant,
        generation: const {'electricity': 2},
        requiredWorkers: 7, // Increase to allow 7 workers
        assignedWorkers: 7,
      );

      resources.decreasePopulation([powerPlant]);

      expect(resources.population, 9);
      expect(resources.availableWorkers, 2);
      expect(powerPlant.assignedWorkers, 7);
    });

    test('decreasePopulation unassigns worker when no available workers', () {
      final resources = Resources();
      resources.population = 10;
      resources.availableWorkers = 0;

      final powerPlant = createBuilding(
        type: BuildingType.powerPlant,
        generation: const {'electricity': 2},
        requiredWorkers: 10, // Allow 10 workers
        assignedWorkers: 10,
      );

      resources.decreasePopulation([powerPlant]);

      expect(resources.population, 9);
      expect(resources.availableWorkers, 0);
      expect(powerPlant.assignedWorkers, 9);
    });

    test('decreasePopulation handles mixed building worker assignments', () {
      final resources = Resources();
      resources.population = 20;
      resources.availableWorkers = 0;

      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Test house',
        icon: Icons.house,
        color: Colors.green,
        baseCost: 100,
        basePopulation: 20,
        requiredWorkers: 0,
        category: BuildingCategory.residential,
      );

      final powerPlant = createBuilding(
        type: BuildingType.powerPlant,
        generation: const {'electricity': 2},
        requiredWorkers: 10, // Allow 10 workers
        assignedWorkers: 10,
      );

      final coalMine = createBuilding(
        type: BuildingType.coalMine,
        generation: const {'coal': 1},
        requiredWorkers: 10, // Allow 10 workers
        assignedWorkers: 10,
      );

      resources.decreasePopulation([house, powerPlant, coalMine]);

      expect(resources.population, 19);
      expect(resources.availableWorkers, 0);
      // Total assigned workers should be 19
      expect(powerPlant.assignedWorkers + coalMine.assignedWorkers, 19);
    });
  });

  group('Happiness system', () {
    test('happiness increases when all factors are satisfied', () {
      final resources = Resources();
      resources.population = 10;
      resources.availableWorkers = 0; // All employed
      resources.unshelteredPopulation = 0; // All sheltered
      resources.resources[ResourceType.bread] = 10; // Plenty of food
      resources.resources[ResourceType.water] = 10; // Plenty of water
      resources.resources[ResourceType.electricity] = 10; // Plenty of power
      resources.happiness = 0; // Start low

      // Create a house to provide accommodation
      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Test house',
        icon: Icons.house,
        color: Colors.green,
        baseCost: 100,
        basePopulation: 10,
        requiredWorkers: 0,
        category: BuildingCategory.residential,
      );

      // Run several update cycles
      for (int i = 0; i < 20; i++) {
        resources.update([house]);
      }

      // Happiness should have increased significantly
      expect(resources.happiness, greaterThan(50));
    });

    test('happiness decreases when factors are unsatisfied', () {
      final resources = Resources();
      resources.population = 10;
      resources.availableWorkers = 10; // No one employed
      resources.unshelteredPopulation = 10; // No one sheltered
      resources.resources[ResourceType.bread] = 0; // No food
      resources.resources[ResourceType.water] = 0; // No water
      resources.resources[ResourceType.electricity] = 0; // No power
      resources.happiness = 100; // Start high

      // Run several update cycles with no buildings (no housing)
      for (int i = 0; i < 20; i++) {
        resources.update([]);
      }

      // Happiness should have decreased significantly
      expect(resources.happiness, lessThan(50));
    });

    test('population grows when happiness is high and housing available', () {
      final resources = Resources();
      resources.population = 5;
      resources.availableWorkers = 0;
      resources.unshelteredPopulation = 0;
      resources.happiness = 80; // High happiness
      resources.resources[ResourceType.bread] = 100;
      resources.resources[ResourceType.water] = 100;
      resources.resources[ResourceType.electricity] = 100;

      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Test house',
        icon: Icons.house,
        color: Colors.green,
        baseCost: 100,
        basePopulation: 20, // Plenty of housing
        requiredWorkers: 0,
        category: BuildingCategory.residential,
      );

      // Run 31 update cycles (30 seconds = 1 growth check)
      for (int i = 0; i < 31; i++) {
        resources.update([house]);
      }

      // Population should have increased by 1
      expect(resources.population, 6);
    });

    test(
      'population decrease with no available workers unassigns from building',
      () {
        final resources = Resources();
        resources.population = 5;
        // Don't set availableWorkers manually, let update() calculate it
        // We'll call decreasePopulation directly to test the worker unassignment

        // Create a building with assigned workers
        final house = Building(
          type: BuildingType.house,
          name: 'House',
          description: 'Test house',
          icon: Icons.house,
          color: Colors.green,
          baseCost: 100,
          basePopulation: 20,
          requiredWorkers: 0,
          category: BuildingCategory.residential,
        );

        final powerPlant = createBuilding(
          type: BuildingType.powerPlant,
          generation: const {'electricity': 2},
          requiredWorkers: 5, // Allow up to 5 workers
          assignedWorkers: 5, // All workers are assigned
        );

        // Set state to have no available workers (all 5 assigned to powerPlant)
        resources.availableWorkers = 0;

        final initialAssignedWorkers = powerPlant.assignedWorkers;

        // Trigger population decrease using the production code
        resources.decreasePopulation([house, powerPlant]);

        // Population should have decreased by 1
        expect(resources.population, 4);

        // At least one worker should have been unassigned
        expect(powerPlant.assignedWorkers, lessThan(initialAssignedWorkers));

        // availableWorkers should be recalculated correctly
        expect(
          resources.availableWorkers,
          resources.population -
              powerPlant.assignedWorkers -
              house.assignedWorkers,
        );
      },
    );

    test('happiness thresholds are defined correctly', () {
      // Verify that shared constants have expected values
      expect(HappinessThresholds.high, 60.0);
      expect(HappinessThresholds.low, 30.0);
    });

    test('happiness setter clamps value to valid range', () {
      final resources = Resources();

      // Test setting above max
      resources.happiness = 150;
      expect(resources.happiness, 100);

      // Test setting below min
      resources.happiness = -50;
      expect(resources.happiness, 0);

      // Test valid values
      resources.happiness = 75;
      expect(resources.happiness, 75);
    });

    test('population does NOT decrease after only 1 low happiness cycle', () {
      final resources = Resources();
      resources.population = 10;
      resources.availableWorkers = 10;
      resources.unshelteredPopulation = 10;
      resources.happiness = 20; // Below low threshold (30)

      final initialPopulation = resources.population;

      // Run exactly 30 cycles (one growth check cycle)
      for (int i = 0; i < 30; i++) {
        resources.update([]);
      }

      // Population should NOT have decreased after just 1 low happiness cycle
      expect(resources.population, initialPopulation);
    });

    test('population decreases after 2 consecutive low happiness cycles', () {
      final resources = Resources();
      resources.population = 10;
      resources.availableWorkers = 10;
      resources.unshelteredPopulation = 10;
      resources.happiness = 20; // Below low threshold (30)

      final initialPopulation = resources.population;

      // Run 60 cycles (two growth check cycles at 30 seconds each)
      for (int i = 0; i < 60; i++) {
        resources.update([]);
      }

      // Population should have decreased after 2 consecutive low happiness cycles
      expect(resources.population, initialPopulation - 1);
    });

    test('low happiness streak resets when happiness rises above threshold', () {
      final resources = Resources();
      resources.population = 10;
      resources.availableWorkers = 10;
      resources.unshelteredPopulation = 10;
      resources.happiness = 20; // Below low threshold

      final initialPopulation = resources.population;

      // Run 30 cycles (one low happiness cycle) - no buildings means happiness stays low
      for (int i = 0; i < 30; i++) {
        resources.update([]);
      }

      // Population should still be the same (only 1 low cycle, need 2)
      expect(resources.population, initialPopulation);

      // Now provide moderate conditions that raise happiness above low threshold
      // but below high threshold (so no growth triggers, just streak reset)
      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Test house',
        icon: Icons.house,
        color: Colors.green,
        baseCost: 100,
        basePopulation: 10, // Full housing
        requiredWorkers: 0,
        category: BuildingCategory.residential,
      );

      // Add employment via a building with assigned workers (partial employment)
      // Note: update() recalculates availableWorkers, so we need actual assigned workers
      final factory = createBuilding(
        type: BuildingType.woodFactory,
        generation: const {'wood': 1},
        requiredWorkers: 5, // Allow 5 workers
        assignedWorkers: 5, // 5 workers employed = 50% employment
      );

      // With house + factory:
      // Housing = 100% * 0.30 = 30
      // Employment = 50% * 0.20 = 10
      // Food = 0%, Services = 0%
      // Target happiness = 40 (above 30, below 60)

      for (int i = 0; i < 50; i++) {
        // Run enough cycles for happiness to stabilize
        resources.update([house, factory]);
      }

      // Happiness should be above low threshold (30) but below high (60)
      expect(resources.happiness, greaterThan(HappinessThresholds.low));
      expect(resources.happiness, lessThan(HappinessThresholds.high));
      expect(resources.population, initialPopulation);

      // Now remove housing and employment to drop happiness again
      resources.availableWorkers = 10; // No one employed
      resources.resources[ResourceType.bread] = 0;
      resources.resources[ResourceType.water] = 0;
      resources.resources[ResourceType.electricity] = 0;

      // Run 60 more cycles with bad conditions (need 2 consecutive low cycles again)
      for (int i = 0; i < 60; i++) {
        resources.update([]);
      }

      // Now population should have decreased (after 2 fresh low happiness cycles)
      expect(resources.population, initialPopulation - 1);
    });

    test('low happiness streak resets after population decreases', () {
      final resources = Resources();
      resources.population = 10;
      resources.availableWorkers = 10;
      resources.unshelteredPopulation = 10;
      resources.happiness = 20; // Below low threshold

      final initialPopulation = resources.population;

      // Run 60 cycles to trigger first population decrease (2 consecutive low cycles)
      for (int i = 0; i < 60; i++) {
        resources.update([]);
      }

      // Population should have decreased by 1
      expect(resources.population, initialPopulation - 1);

      // Run another 30 cycles (one more low happiness cycle)
      for (int i = 0; i < 30; i++) {
        resources.update([]);
      }

      // Population should NOT have decreased again (streak should have reset)
      expect(resources.population, initialPopulation - 1);

      // Run another 30 cycles to complete the second 60s interval
      for (int i = 0; i < 30; i++) {
        resources.update([]);
      }

      // Now population should decrease again (after 2 fresh low cycles)
      expect(resources.population, initialPopulation - 2);
    });

    test(
      'population does not grow when happiness is high but no housing available',
      () {
        final resources = Resources();
        resources.population = 10;
        resources.availableWorkers = 0;
        resources.unshelteredPopulation = 5; // Some people unsheltered
        resources.happiness = 80; // High happiness

        final initialPopulation = resources.population;

        // Run 31 update cycles (past one growth check)
        for (int i = 0; i < 31; i++) {
          resources.update([]);
        }

        // Population should NOT have increased because unshelteredPopulation > 0
        expect(resources.population, initialPopulation);
      },
    );

    test('happiness factor weights contribute proportionally', () {
      // Create house that provides accommodation
      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Test house',
        icon: Icons.house,
        color: Colors.green,
        baseCost: 100,
        basePopulation: 10, // Provides housing for 10
        requiredWorkers: 0,
        category: BuildingCategory.residential,
      );

      // Test housing-only scenario (30% weight)
      final resourcesHousing = Resources();
      resourcesHousing.population = 10;
      resourcesHousing.availableWorkers = 10; // No employment
      resourcesHousing.resources[ResourceType.bread] = 0; // No food
      resourcesHousing.resources[ResourceType.water] = 0; // No services
      resourcesHousing.resources[ResourceType.electricity] = 0;
      resourcesHousing.happiness = 0;

      // Run many cycles to let happiness stabilize with house providing shelter
      for (int i = 0; i < 100; i++) {
        resourcesHousing.update([house]);
      }

      // Housing = 100%, Food = 0%, Services = 0%, Employment = 0%
      // Expected: 100*0.30 + 0*0.25 + 0*0.25 + 0*0.20 = 30
      expect(resourcesHousing.happiness, closeTo(30, 5));

      // Test employment-only scenario (20% weight)
      // Need a building that has workers assigned to create employment
      final coalMine = createBuilding(
        type: BuildingType.coalMine,
        generation: const {'coal': 1},
        requiredWorkers: 10, // Allow 10 workers
        assignedWorkers: 10, // All workers assigned = full employment
      );

      final resourcesEmployment = Resources();
      resourcesEmployment.population = 10;
      // update() will calculate availableWorkers from buildings
      resourcesEmployment.resources[ResourceType.bread] = 0;
      resourcesEmployment.resources[ResourceType.water] = 0;
      resourcesEmployment.resources[ResourceType.electricity] = 0;
      resourcesEmployment.happiness = 0;

      // Run with no house (no housing) but with all workers employed
      for (int i = 0; i < 100; i++) {
        resourcesEmployment.update([coalMine]);
      }

      // Housing = 0%, Food = 0%, Services = 0%, Employment = 100%
      // Expected: 0*0.30 + 0*0.25 + 0*0.25 + 100*0.20 = 20
      expect(resourcesEmployment.happiness, closeTo(20, 5));
    });
  });

  group('Worker management', () {
    test('assignWorkerTo attaches workers when available', () {
      final resources = Resources();
      resources.availableWorkers = 1;

      final building = createBuilding(
        type: BuildingType.coalMine,
        generation: const {'coal': 1},
        requiredWorkers: 1,
      );

      expect(resources.canAssignWorkerTo(building), isTrue);

      resources.assignWorkerTo(building);

      expect(building.assignedWorkers, 1);
      expect(resources.availableWorkers, 0);
    });

    test('assignWorkerTo does nothing when no workers remain', () {
      final resources = Resources();
      resources.availableWorkers = 0;

      final building = createBuilding(
        type: BuildingType.coalMine,
        generation: const {'coal': 1},
        requiredWorkers: 1,
      );

      expect(resources.canAssignWorkerTo(building), isFalse);

      resources.assignWorkerTo(building);

      expect(building.assignedWorkers, 0);
      expect(resources.availableWorkers, 0);
    });

    test('unassignWorkerFrom returns workers to the pool', () {
      final resources = Resources();
      resources.availableWorkers = 5;

      final building = createBuilding(
        type: BuildingType.coalMine,
        generation: const {'coal': 1},
        requiredWorkers: 1,
        assignedWorkers: 1,
      );

      resources.unassignWorkerFrom(building);

      expect(building.assignedWorkers, 0);
      expect(resources.availableWorkers, 6);
    });
  });

  group('Happiness persistence', () {
    test(
      'saveGameState and loadGameState persist happiness correctly',
      () async {
        SharedPreferences.setMockInitialValues({});

        final resources = Resources();
        resources.happiness = 75.0;
        resources.cash = 500.0;
        resources.population = 30;

        final researchManager = ResearchManager();

        // Save game state
        await SaveService.saveGameState(
          resources: resources,
          researchManager: researchManager,
        );

        // Create new resources to load into
        final loadedResources = Resources();
        final loadedResearchManager = ResearchManager();

        // Load game state
        await SaveService.loadGameState(
          resources: loadedResources,
          researchManager: loadedResearchManager,
        );

        // Verify happiness was persisted correctly
        expect(loadedResources.happiness, 75.0);
        expect(loadedResources.cash, 500.0);
        expect(loadedResources.population, 30);
      },
    );

    test('loadGameState uses default happiness when not saved', () async {
      SharedPreferences.setMockInitialValues({});

      final resources = Resources();
      final researchManager = ResearchManager();

      // Load game state without any saved happiness
      await SaveService.loadGameState(
        resources: resources,
        researchManager: researchManager,
      );

      // Verify default happiness value is used
      expect(resources.happiness, 50.0);
    });
  });
}
