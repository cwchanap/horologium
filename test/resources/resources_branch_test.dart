import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/game/resources/resource_type.dart';

void main() {
  Building buildCoalMine({int assignedWorkers = 0, int requiredWorkers = 1}) {
    final building = Building(
      type: BuildingType.coalMine,
      name: 'Coal Mine',
      description: 'Produces coal',
      icon: Icons.fireplace,
      color: Colors.grey,
      baseCost: 100,
      baseGeneration: const {ResourceType.coal: 1},
      requiredWorkers: requiredWorkers,
      category: BuildingCategory.rawMaterials,
    );

    for (int i = 0; i < assignedWorkers; i++) {
      building.assignWorker();
    }

    return building;
  }

  group('Resources branch coverage', () {
    test('buyResource rejects unsupported resource types', () {
      final resources = Resources();

      expect(resources.buyResource(ResourceType.population, 1), isFalse);
    });

    test('sellResource rejects unsupported resource types', () {
      final resources = Resources();
      resources.availableWorkers = 5;

      expect(resources.sellResource(ResourceType.availableWorkers, 1), isFalse);
    });

    test('trade ignores unsupported resource types', () {
      final resources = Resources();
      final initialCash = resources.cash;
      final initialGold = resources.gold;

      resources.trade(ResourceType.population, ResourceType.gold, 5);

      expect(resources.cash, equals(initialCash));
      expect(resources.gold, equals(initialGold));
    });

    test('setResource and getResource round-trip values', () {
      final resources = Resources();

      resources.setResource(ResourceType.stone, 12.5);

      expect(resources.getResource(ResourceType.stone), equals(12.5));
      expect(resources.getResource(ResourceType.population), equals(0));
    });

    test(
      'update inserts missing generated resources for non-consuming buildings',
      () {
        final resources = Resources();
        final building = Building(
          type: BuildingType.house,
          name: 'Population Beacon',
          description: 'Adds a generated resource that is not pre-seeded',
          icon: Icons.groups,
          color: Colors.blue,
          baseCost: 0,
          baseGeneration: const {ResourceType.population: 2},
          requiredWorkers: 0,
          category: BuildingCategory.residential,
        );

        resources.update([building]);

        expect(resources.getResource(ResourceType.population), equals(2));
      },
    );

    test(
      'update handles missing consuming and generated keys for active buildings',
      () {
        final resources = Resources();
        final building = Building(
          type: BuildingType.powerPlant,
          name: 'Odd Factory',
          description: 'Consumes and generates non-seeded resource keys',
          icon: Icons.factory,
          color: Colors.orange,
          baseCost: 0,
          baseGeneration: const {ResourceType.availableWorkers: 2},
          baseConsumption: const {ResourceType.population: 0},
          requiredWorkers: 1,
          category: BuildingCategory.services,
        )..assignWorker();

        resources.update([building]);

        expect(resources.getResource(ResourceType.population), equals(0));
        expect(resources.getResource(ResourceType.availableWorkers), equals(2));
      },
    );

    test('recreates a missing research key when research accrues', () {
      final resources = Resources();
      resources.resources.remove(ResourceType.research);
      final researchLab = Building(
        type: BuildingType.researchLab,
        name: 'Research Lab',
        description: 'Produces research',
        icon: Icons.science,
        color: Colors.purple,
        baseCost: 0,
        baseGeneration: const {ResourceType.research: 0.1},
        baseConsumption: const {ResourceType.electricity: 0},
        requiredWorkers: 1,
        category: BuildingCategory.services,
      )..assignWorker();

      for (int i = 0; i < 10; i++) {
        resources.update([researchLab]);
      }

      expect(resources.getResource(ResourceType.research), equals(1.0));
    });

    test('getter accessors expose stored grain and crop values', () {
      final resources = Resources();
      resources.wheat = 1;
      resources.corn = 2;
      resources.rice = 3;
      resources.barley = 4;
      resources.flour = 5;
      resources.cornmeal = 6;
      resources.polishedRice = 7;
      resources.maltedBarley = 8;

      expect(resources.wheat, equals(1));
      expect(resources.corn, equals(2));
      expect(resources.rice, equals(3));
      expect(resources.barley, equals(4));
      expect(resources.flour, equals(5));
      expect(resources.cornmeal, equals(6));
      expect(resources.polishedRice, equals(7));
      expect(resources.maltedBarley, equals(8));
    });

    test('sellResource recreates a missing cash entry via ifAbsent', () {
      final resources = Resources();
      resources.cash = 100;
      resources.gold = 5;
      resources.resources.remove(ResourceType.cash);

      final success = resources.sellResource(ResourceType.gold, 2);

      expect(success, isTrue);
      expect(resources.cash, equals(16));
      expect(resources.gold, equals(3));
    });

    test('cannot assign workers to a building that is already full', () {
      final resources = Resources();
      resources.availableWorkers = 3;
      final building = buildCoalMine(assignedWorkers: 1);

      expect(resources.canAssignWorkerTo(building), isFalse);

      resources.assignWorkerTo(building);

      expect(building.assignedWorkers, equals(1));
      expect(resources.availableWorkers, equals(3));
    });

    test(
      'unassignWorkerFrom leaves state unchanged when no workers are assigned',
      () {
        final resources = Resources();
        resources.availableWorkers = 2;
        final building = buildCoalMine();

        resources.unassignWorkerFrom(building);

        expect(building.assignedWorkers, equals(0));
        expect(resources.availableWorkers, equals(2));
      },
    );
  });
}
