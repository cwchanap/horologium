import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/game/services/resource_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Building createBuilding({
    required BuildingType type,
    required int cost,
    int requiredWorkers = 1,
  }) {
    return Building(
      type: type,
      name: type.name,
      description: 'Test',
      icon: Icons.build,
      color: Colors.blue,
      baseCost: cost,
      requiredWorkers: requiredWorkers,
      category: BuildingCategory.rawMaterials,
    );
  }

  group('ResourceService.canAffordBuilding', () {
    test('returns true when cash equals building cost', () {
      final resources = Resources()..resources[ResourceType.cash] = 100;
      final building = createBuilding(type: BuildingType.coalMine, cost: 100);
      expect(ResourceService.canAffordBuilding(resources, building), isTrue);
    });

    test('returns true when cash exceeds building cost', () {
      final resources = Resources()..resources[ResourceType.cash] = 500;
      final building = createBuilding(type: BuildingType.coalMine, cost: 100);
      expect(ResourceService.canAffordBuilding(resources, building), isTrue);
    });

    test('returns false when cash is less than building cost', () {
      final resources = Resources()..resources[ResourceType.cash] = 50;
      final building = createBuilding(type: BuildingType.coalMine, cost: 100);
      expect(ResourceService.canAffordBuilding(resources, building), isFalse);
    });

    test('returns false when cash is zero and building has a cost', () {
      final resources = Resources()..resources[ResourceType.cash] = 0;
      final building = createBuilding(type: BuildingType.coalMine, cost: 1);
      expect(ResourceService.canAffordBuilding(resources, building), isFalse);
    });

    test('returns true for a free building (cost 0) with zero cash', () {
      final resources = Resources()..resources[ResourceType.cash] = 0;
      final building = createBuilding(type: BuildingType.house, cost: 0);
      expect(ResourceService.canAffordBuilding(resources, building), isTrue);
    });
  });

  group('ResourceService.purchaseBuilding', () {
    test('deducts building cost from cash', () {
      final resources = Resources()..resources[ResourceType.cash] = 300;
      final building = createBuilding(
        type: BuildingType.coalMine,
        cost: 100,
        requiredWorkers: 0,
      );
      ResourceService.purchaseBuilding(resources, building);
      expect(resources.cash, equals(200));
    });

    test('does nothing when player cannot afford the building', () {
      final resources = Resources()..resources[ResourceType.cash] = 50;
      final building = createBuilding(
        type: BuildingType.coalMine,
        cost: 100,
        requiredWorkers: 0,
      );
      ResourceService.purchaseBuilding(resources, building);
      expect(resources.cash, equals(50));
    });

    test(
      'auto-assigns a worker when building requires one and workers exist',
      () {
        final resources = Resources()..resources[ResourceType.cash] = 1000;
        final building = createBuilding(
          type: BuildingType.coalMine,
          cost: 100,
          requiredWorkers: 1,
        );
        ResourceService.purchaseBuilding(resources, building);
        expect(building.assignedWorkers, equals(1));
      },
    );

    test('does not assign workers when requiredWorkers is 0', () {
      final resources = Resources()..resources[ResourceType.cash] = 1000;
      final building = createBuilding(
        type: BuildingType.house,
        cost: 50,
        requiredWorkers: 0,
      );
      ResourceService.purchaseBuilding(resources, building);
      expect(building.assignedWorkers, equals(0));
    });

    test('deducts cost based on building level', () {
      final resources = Resources()..resources[ResourceType.cash] = 1000;
      final building = createBuilding(
        type: BuildingType.coalMine,
        cost: 100,
        requiredWorkers: 0,
      );
      building.upgrade(); // level 2, cost = baseCost * level = 200
      ResourceService.purchaseBuilding(resources, building);
      expect(resources.cash, equals(800));
    });
  });

  group('ResourceService.refundBuilding', () {
    test('refunds building cost to cash', () {
      final resources = Resources()..resources[ResourceType.cash] = 100;
      final building = createBuilding(
        type: BuildingType.coalMine,
        cost: 200,
        requiredWorkers: 0,
      );
      ResourceService.refundBuilding(resources, building);
      expect(resources.cash, equals(300));
    });

    test('unassigns all workers when refunding', () {
      final resources = Resources()..resources[ResourceType.cash] = 1000;
      final building = createBuilding(
        type: BuildingType.coalMine,
        cost: 100,
        requiredWorkers: 2,
      );
      final initialAvailableWorkers = resources.availableWorkers;
      resources.assignWorkerTo(building);
      resources.assignWorkerTo(building);
      expect(building.assignedWorkers, equals(2));
      expect(resources.availableWorkers, equals(initialAvailableWorkers - 2));

      ResourceService.refundBuilding(resources, building);
      expect(building.assignedWorkers, equals(0));
      expect(resources.availableWorkers, equals(initialAvailableWorkers));
    });

    test('refund works even when building has no workers', () {
      final resources = Resources()..resources[ResourceType.cash] = 100;
      final building = createBuilding(
        type: BuildingType.house,
        cost: 50,
        requiredWorkers: 0,
      );
      ResourceService.refundBuilding(resources, building);
      expect(resources.cash, equals(150));
      expect(building.assignedWorkers, equals(0));
    });

    test('purchase then refund restores original cash', () {
      final resources = Resources()..resources[ResourceType.cash] = 500;
      final building = createBuilding(
        type: BuildingType.coalMine,
        cost: 200,
        requiredWorkers: 0,
      );
      ResourceService.purchaseBuilding(resources, building);
      expect(resources.cash, equals(300));
      ResourceService.refundBuilding(resources, building);
      expect(resources.cash, equals(500));
    });
  });

  group('ResourceService.updateResources', () {
    test('delegates update to resources object', () {
      final resources = Resources()..resources[ResourceType.electricity] = 0;
      final building = Building(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        description: 'Test',
        icon: Icons.bolt,
        color: Colors.yellow,
        baseCost: 0,
        baseGeneration: const {ResourceType.electricity: 2.0},
        requiredWorkers: 1,
        category: BuildingCategory.services,
      );
      building.assignWorker();

      ResourceService.updateResources(resources, [building]);

      expect(resources.resources[ResourceType.electricity], equals(2.0));
    });
  });
}
