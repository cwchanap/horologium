import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resource_type.dart';

void main() {
  group('Building Upgrade Tests', () {
    late Building testBuilding;

    setUp(() {
      testBuilding = Building(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        description: 'Generates electricity',
        icon: Icons.bolt,
        color: Colors.yellow,
        baseCost: 100,
        baseGeneration: {ResourceType.electricity: 1},
        baseConsumption: {ResourceType.coal: 1},
        maxLevel: 5,
        requiredWorkers: 1,
        category: BuildingCategory.services,
        level: 1,
      );
    });

    test('canUpgrade returns true when below max level', () {
      expect(testBuilding.canUpgrade, isTrue);
    });

    test('canUpgrade returns false at max level', () {
      testBuilding = Building(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        description: 'Generates electricity',
        icon: Icons.bolt,
        color: Colors.yellow,
        baseCost: 100,
        baseGeneration: {ResourceType.electricity: 1},
        maxLevel: 5,
        requiredWorkers: 1,
        category: BuildingCategory.services,
        level: 5,
      );

      expect(testBuilding.canUpgrade, isFalse);
    });

    test('upgradeCost includes cash for the next level', () {
      expect(testBuilding.upgradeCost.resources[ResourceType.cash], 200);

      testBuilding.upgrade();

      expect(testBuilding.upgradeCost.resources[ResourceType.cash], 300);
    });

    test('processing building upgradeCost includes planks and stone', () {
      final windMill = BuildingRegistry.availableBuildings.firstWhere(
        (building) => building.type == BuildingType.windMill,
      );

      expect(windMill.upgradeCost.resources[ResourceType.cash], equals(200));
      expect(
        windMill.upgradeCost.resources[ResourceType.planks],
        greaterThan(0),
      );
      expect(
        windMill.upgradeCost.resources[ResourceType.stone],
        greaterThan(0),
      );
    });

    test('refinement building upgradeCost includes planks and stone', () {
      final bakery = BuildingRegistry.availableBuildings.firstWhere(
        (building) => building.type == BuildingType.bakery,
      );

      expect(bakery.upgradeCost.resources[ResourceType.cash], equals(300));
      expect(bakery.upgradeCost.resources[ResourceType.planks], greaterThan(0));
      expect(bakery.upgradeCost.resources[ResourceType.stone], greaterThan(0));
    });

    test('upgrade increases level by 1', () {
      expect(testBuilding.level, 1);

      testBuilding.upgrade();

      expect(testBuilding.level, 2);
    });

    test('upgrade does nothing at max level', () {
      testBuilding = Building(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        description: 'Generates electricity',
        icon: Icons.bolt,
        color: Colors.yellow,
        baseCost: 100,
        baseGeneration: {ResourceType.electricity: 1},
        maxLevel: 5,
        requiredWorkers: 1,
        category: BuildingCategory.services,
        level: 5,
      );

      testBuilding.upgrade();

      expect(testBuilding.level, 5);
    });

    test('generation scales with level', () {
      // Level 1: 1 electricity
      expect(testBuilding.generation[ResourceType.electricity], 1);

      testBuilding.upgrade();
      // Level 2: 2 electricity
      expect(testBuilding.generation[ResourceType.electricity], 2);

      testBuilding.upgrade();
      // Level 3: 3 electricity
      expect(testBuilding.generation[ResourceType.electricity], 3);
    });

    test('consumption scales with level', () {
      // Level 1: 1 coal
      expect(testBuilding.consumption[ResourceType.coal], 1);

      testBuilding.upgrade();
      // Level 2: 2 coal
      expect(testBuilding.consumption[ResourceType.coal], 2);
    });

    test('accommodationCapacity scales with level for houses', () {
      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Housing',
        icon: Icons.house,
        color: Colors.green,
        baseCost: 120,
        basePopulation: 2,
        maxLevel: 5,
        requiredWorkers: 0,
        category: BuildingCategory.residential,
        level: 1,
      );

      expect(house.accommodationCapacity, 2);

      house.upgrade();
      expect(house.accommodationCapacity, 4);

      house.upgrade();
      expect(house.accommodationCapacity, 6);
    });

    test('cost getter returns baseCost times current level', () {
      // Level 1: cost = 100
      expect(testBuilding.cost, 100);

      testBuilding.upgrade();
      // Level 2: cost = 200
      expect(testBuilding.cost, 200);
    });
  });
}
