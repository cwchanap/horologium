import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/planet/placed_building_data.dart';
import 'package:horologium/game/resources/resource_type.dart';

void main() {
  group('PlacedBuildingData.createBuilding - Field variants', () {
    test('creates Field with wheat crop type (default)', () {
      const data = PlacedBuildingData(
        id: 'f1',
        x: 0,
        y: 0,
        type: BuildingType.field,
      );
      final building = data.createBuilding();
      expect(building, isA<Field>());
      final field = building as Field;
      expect(field.cropType, equals(CropType.wheat));
      expect(field.generation[ResourceType.wheat], equals(1.0));
    });

    test('creates Field with corn crop type from variant', () {
      const data = PlacedBuildingData(
        id: 'f2',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'corn',
      );
      final building = data.createBuilding();
      expect(building, isA<Field>());
      final field = building as Field;
      expect(field.cropType, equals(CropType.corn));
      expect(field.generation[ResourceType.corn], equals(1.0));
    });

    test('creates Field with rice crop type from variant', () {
      const data = PlacedBuildingData(
        id: 'f3',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'rice',
      );
      final building = data.createBuilding();
      final field = building as Field;
      expect(field.cropType, equals(CropType.rice));
    });

    test('creates Field with barley crop type from variant', () {
      const data = PlacedBuildingData(
        id: 'f4',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'barley',
      );
      final building = data.createBuilding();
      final field = building as Field;
      expect(field.cropType, equals(CropType.barley));
    });

    test('falls back to wheat for unknown crop variant', () {
      const data = PlacedBuildingData(
        id: 'f5',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'unknownCrop',
      );
      final building = data.createBuilding();
      final field = building as Field;
      expect(field.cropType, equals(CropType.wheat));
    });

    test('preserves level and assignedWorkers', () {
      const data = PlacedBuildingData(
        id: 'f6',
        x: 0,
        y: 0,
        type: BuildingType.field,
        level: 3,
        assignedWorkers: 1,
        variant: 'corn',
      );
      final building = data.createBuilding()!;
      expect(building.level, equals(3));
      expect(building.assignedWorkers, equals(1));
    });
  });

  group('PlacedBuildingData.createBuilding - Bakery variants', () {
    test('creates Bakery with bread product type (default)', () {
      const data = PlacedBuildingData(
        id: 'b1',
        x: 0,
        y: 0,
        type: BuildingType.bakery,
      );
      final building = data.createBuilding();
      expect(building, isA<Bakery>());
      final bakery = building as Bakery;
      expect(bakery.productType, equals(BakeryProduct.bread));
      expect(bakery.generation[ResourceType.bread], equals(1.0));
    });

    test('creates Bakery with pastries product type from variant', () {
      const data = PlacedBuildingData(
        id: 'b2',
        x: 0,
        y: 0,
        type: BuildingType.bakery,
        variant: 'pastries',
      );
      final building = data.createBuilding();
      expect(building, isA<Bakery>());
      final bakery = building as Bakery;
      expect(bakery.productType, equals(BakeryProduct.pastries));
      expect(bakery.generation[ResourceType.pastries], equals(1.0));
    });

    test('falls back to bread for unknown bakery variant', () {
      const data = PlacedBuildingData(
        id: 'b3',
        x: 0,
        y: 0,
        type: BuildingType.bakery,
        variant: 'unknownProduct',
      );
      final building = data.createBuilding();
      final bakery = building as Bakery;
      expect(bakery.productType, equals(BakeryProduct.bread));
    });

    test('preserves level and assignedWorkers for Bakery', () {
      const data = PlacedBuildingData(
        id: 'b4',
        x: 0,
        y: 0,
        type: BuildingType.bakery,
        level: 2,
        assignedWorkers: 1,
        variant: 'pastries',
      );
      final building = data.createBuilding()!;
      expect(building.level, equals(2));
      expect(building.assignedWorkers, equals(1));
    });
  });

  group('PlacedBuildingData.createBuilding - regular buildings', () {
    test('creates regular Building with correct type', () {
      const data = PlacedBuildingData(
        id: 'pw1',
        x: 0,
        y: 0,
        type: BuildingType.powerPlant,
        level: 2,
        assignedWorkers: 1,
      );
      final building = data.createBuilding();
      expect(building, isNotNull);
      expect(building, isA<Building>());
      expect(building!.type, equals(BuildingType.powerPlant));
      expect(building.level, equals(2));
      expect(building.assignedWorkers, equals(1));
    });
  });

  group('PlacedBuildingData.copyWith', () {
    test('returns copy with updated level', () {
      const data = PlacedBuildingData(
        id: 'c1',
        x: 1,
        y: 2,
        type: BuildingType.house,
        level: 1,
      );
      final upgraded = data.copyWith(level: 3);
      expect(upgraded.level, equals(3));
      expect(upgraded.id, equals('c1'));
      expect(upgraded.x, equals(1));
      expect(upgraded.y, equals(2));
      expect(upgraded.type, equals(BuildingType.house));
    });

    test('returns copy with updated assignedWorkers', () {
      const data = PlacedBuildingData(
        id: 'c2',
        x: 0,
        y: 0,
        type: BuildingType.coalMine,
      );
      final withWorker = data.copyWith(assignedWorkers: 1);
      expect(withWorker.assignedWorkers, equals(1));
      expect(data.assignedWorkers, equals(0)); // Original unchanged
    });

    test('can explicitly clear variant to null', () {
      const data = PlacedBuildingData(
        id: 'c3',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'corn',
      );
      final cleared = data.copyWith(variant: null);
      expect(cleared.variant, isNull);
    });

    test('preserves variant when not specified in copyWith', () {
      const data = PlacedBuildingData(
        id: 'c4',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'rice',
      );
      final copy = data.copyWith(level: 2);
      expect(copy.variant, equals('rice'));
    });

    test('can update x and y coordinates', () {
      const data = PlacedBuildingData(
        id: 'c5',
        x: 0,
        y: 0,
        type: BuildingType.house,
      );
      final moved = data.copyWith(x: 10, y: 20);
      expect(moved.x, equals(10));
      expect(moved.y, equals(20));
    });
  });

  group('PlacedBuildingData equality', () {
    test('two instances with same values are equal', () {
      const a = PlacedBuildingData(
        id: 'eq1',
        x: 1,
        y: 2,
        type: BuildingType.house,
        level: 2,
        assignedWorkers: 1,
      );
      const b = PlacedBuildingData(
        id: 'eq1',
        x: 1,
        y: 2,
        type: BuildingType.house,
        level: 2,
        assignedWorkers: 1,
      );
      expect(a, equals(b));
    });

    test('instances with different ids are not equal', () {
      const a = PlacedBuildingData(
        id: 'eq1',
        x: 1,
        y: 2,
        type: BuildingType.house,
      );
      const b = PlacedBuildingData(
        id: 'eq2',
        x: 1,
        y: 2,
        type: BuildingType.house,
      );
      expect(a, isNot(equals(b)));
    });

    test('instances with different levels are not equal', () {
      const a = PlacedBuildingData(
        id: 'eq3',
        x: 0,
        y: 0,
        type: BuildingType.house,
        level: 1,
      );
      const b = PlacedBuildingData(
        id: 'eq3',
        x: 0,
        y: 0,
        type: BuildingType.house,
        level: 2,
      );
      expect(a, isNot(equals(b)));
    });

    test('instances with different variants are not equal', () {
      const a = PlacedBuildingData(
        id: 'eq4',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'wheat',
      );
      const b = PlacedBuildingData(
        id: 'eq4',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'corn',
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      const a = PlacedBuildingData(
        id: 'hash1',
        x: 5,
        y: 5,
        type: BuildingType.goldMine,
      );
      const b = PlacedBuildingData(
        id: 'hash1',
        x: 5,
        y: 5,
        type: BuildingType.goldMine,
      );
      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('PlacedBuildingData.toLegacyString with variant', () {
    test('includes percent-encoded variant in string', () {
      const data = PlacedBuildingData(
        id: 'v1',
        x: 0,
        y: 0,
        type: BuildingType.field,
        variant: 'corn',
      );
      final str = data.toLegacyString();
      expect(str, contains('corn'));
    });

    test('round-trips variant through toLegacyString/fromLegacyString', () {
      const original = PlacedBuildingData(
        id: 'v2',
        x: 3,
        y: 7,
        type: BuildingType.field,
        variant: 'barley',
        level: 2,
        assignedWorkers: 1,
      );
      final serialized = original.toLegacyString();
      final restored = PlacedBuildingData.fromLegacyString(serialized);
      expect(restored, isNotNull);
      expect(restored!.variant, equals('barley'));
      expect(restored.level, equals(2));
      expect(restored.assignedWorkers, equals(1));
    });

    test('toLegacyString without variant does not have trailing comma', () {
      const data = PlacedBuildingData(
        id: 'v3',
        x: 1,
        y: 2,
        type: BuildingType.house,
      );
      final str = data.toLegacyString();
      final parts = str.split(',');
      // Without variant: id,x,y,type,level,workers = 6 parts
      expect(parts.length, equals(6));
    });
  });

  group('PlacedBuildingData.toString', () {
    test('includes key fields in string representation', () {
      const data = PlacedBuildingData(
        id: 'str1',
        x: 4,
        y: 8,
        type: BuildingType.house,
        level: 2,
      );
      final str = data.toString();
      expect(str, contains('str1'));
      expect(str, contains('4'));
      expect(str, contains('8'));
      expect(str, contains('house'));
    });
  });
}
