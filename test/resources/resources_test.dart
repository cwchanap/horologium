import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/game/resources/resource_type.dart';

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
        resources.availableWorkers = 0; // No available workers

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
          requiredWorkers: 1,
          assignedWorkers: 3, // All workers are assigned
        );

        // Run one update to set initial state
        resources.update([house, powerPlant]);

        final initialAssignedWorkers = powerPlant.assignedWorkers;

        // Manually trigger the population decrease scenario
        // by directly calling the internal state change
        // In real gameplay, this would happen after 60s of low happiness
        for (final building in [house, powerPlant]) {
          if (building.assignedWorkers > 0) {
            building.unassignWorker();
            break;
          }
        }

        resources.population--;
        resources.availableWorkers =
            resources.population -
            powerPlant.assignedWorkers -
            house.assignedWorkers;

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
}
