import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resource_type.dart';

Building _makeBuilding({int requiredWorkers = 1}) {
  return Building(
    type: BuildingType.woodFactory,
    name: 'Wood Factory',
    description: 'Produces wood',
    icon: Icons.park,
    color: Colors.brown,
    baseCost: 80,
    baseGeneration: {ResourceType.wood: 1},
    requiredWorkers: requiredWorkers,
    category: BuildingCategory.rawMaterials,
  );
}

void main() {
  group('Building worker assignment', () {
    group('hasWorkers', () {
      test('returns false when no workers assigned and requiredWorkers > 0', () {
        final building = _makeBuilding(requiredWorkers: 1);
        expect(building.hasWorkers, isFalse);
      });

      test('returns true when assignedWorkers meets requiredWorkers', () {
        final building = _makeBuilding(requiredWorkers: 1);
        building.assignWorker();
        expect(building.hasWorkers, isTrue);
      });

      test('returns true when requiredWorkers is 0', () {
        final building = _makeBuilding(requiredWorkers: 0);
        expect(building.hasWorkers, isTrue);
      });

      test('returns false when partially assigned', () {
        final building = _makeBuilding(requiredWorkers: 2);
        building.assignWorker();
        expect(building.hasWorkers, isFalse);
      });

      test('returns true when fully assigned with multiple required workers', () {
        final building = _makeBuilding(requiredWorkers: 2);
        building.assignWorker();
        building.assignWorker();
        expect(building.hasWorkers, isTrue);
      });
    });

    group('canAssignWorker', () {
      test('returns true when not fully assigned', () {
        final building = _makeBuilding(requiredWorkers: 2);
        expect(building.canAssignWorker, isTrue);
      });

      test('returns false when fully assigned', () {
        final building = _makeBuilding(requiredWorkers: 1);
        building.assignWorker();
        expect(building.canAssignWorker, isFalse);
      });

      test('returns false when requiredWorkers is 0 (already "full")', () {
        final building = _makeBuilding(requiredWorkers: 0);
        expect(building.canAssignWorker, isFalse);
      });
    });

    group('assignWorker', () {
      test('increments assignedWorkers', () {
        final building = _makeBuilding(requiredWorkers: 2);
        expect(building.assignedWorkers, 0);
        building.assignWorker();
        expect(building.assignedWorkers, 1);
        building.assignWorker();
        expect(building.assignedWorkers, 2);
      });

      test('does not exceed requiredWorkers', () {
        final building = _makeBuilding(requiredWorkers: 1);
        building.assignWorker();
        building.assignWorker(); // Extra call should be a no-op
        expect(building.assignedWorkers, 1);
      });

      test('no-op when requiredWorkers is 0', () {
        final building = _makeBuilding(requiredWorkers: 0);
        building.assignWorker();
        expect(building.assignedWorkers, 0);
      });
    });

    group('unassignWorker', () {
      test('decrements assignedWorkers', () {
        final building = _makeBuilding(requiredWorkers: 2);
        building.assignWorker();
        building.assignWorker();
        building.unassignWorker();
        expect(building.assignedWorkers, 1);
      });

      test('does not go below 0', () {
        final building = _makeBuilding(requiredWorkers: 1);
        building.unassignWorker(); // Should be a no-op
        expect(building.assignedWorkers, 0);
      });

      test('assign then unassign returns to original state', () {
        final building = _makeBuilding(requiredWorkers: 1);
        building.assignWorker();
        expect(building.hasWorkers, isTrue);
        building.unassignWorker();
        expect(building.hasWorkers, isFalse);
        expect(building.assignedWorkers, 0);
      });
    });

    group('initial state', () {
      test('starts with zero assigned workers', () {
        final building = _makeBuilding();
        expect(building.assignedWorkers, equals(0));
      });
    });
  });
}
