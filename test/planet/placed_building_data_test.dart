import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/planet/placed_building_data.dart';

void main() {
  group('PlacedBuildingData Persistence Tests', () {
    test('toLegacyString includes level and workers', () {
      final data = PlacedBuildingData(
        x: 5,
        y: 10,
        type: BuildingType.powerPlant,
        level: 3,
        assignedWorkers: 2,
      );

      final result = data.toLegacyString();

      expect(result, '5,10,powerPlant,3,2');
    });

    test('fromLegacyString parses new format with level and workers', () {
      final result = PlacedBuildingData.fromLegacyString('5,10,powerPlant,3,2');

      expect(result, isNotNull);
      expect(result!.x, 5);
      expect(result.y, 10);
      expect(result.type, BuildingType.powerPlant);
      expect(result.level, 3);
      expect(result.assignedWorkers, 2);
    });

    test(
      'fromLegacyString parses old format without level (backward compat)',
      () {
        final result = PlacedBuildingData.fromLegacyString('5,10,powerPlant');

        expect(result, isNotNull);
        expect(result!.x, 5);
        expect(result.y, 10);
        expect(result.type, BuildingType.powerPlant);
        expect(result.level, 1); // Default level
        expect(result.assignedWorkers, 0); // Default workers
      },
    );

    test('fromLegacyString parses format with only level (no workers)', () {
      final result = PlacedBuildingData.fromLegacyString('5,10,powerPlant,3');

      expect(result, isNotNull);
      expect(result!.x, 5);
      expect(result.y, 10);
      expect(result.type, BuildingType.powerPlant);
      expect(result.level, 3);
      expect(result.assignedWorkers, 0); // Default workers
    });

    test('fromLegacyString clamps invalid level and workers', () {
      final result = PlacedBuildingData.fromLegacyString(
        '5,10,powerPlant,-2,-1',
      );

      expect(result, isNotNull);
      expect(result!.level, 1); // Clamp to minimum level
      expect(result.assignedWorkers, 0); // Clamp to minimum workers
    });

    test('createBuilding preserves level from PlacedBuildingData', () {
      final data = PlacedBuildingData(
        x: 5,
        y: 10,
        type: BuildingType.powerPlant,
        level: 3,
        assignedWorkers: 1,
      );

      final building = data.createBuilding();

      expect(building.level, 3);
      expect(building.assignedWorkers, 1);
    });

    test('round-trip persistence preserves all data', () {
      final original = PlacedBuildingData(
        x: 15,
        y: 20,
        type: BuildingType.house,
        level: 4,
        assignedWorkers: 0,
      );

      final serialized = original.toLegacyString();
      final restored = PlacedBuildingData.fromLegacyString(serialized);

      expect(restored, isNotNull);
      expect(restored!.x, original.x);
      expect(restored.y, original.y);
      expect(restored.type, original.type);
      expect(restored.level, original.level);
      expect(restored.assignedWorkers, original.assignedWorkers);
    });

    test('handles all building types', () {
      for (final type in BuildingType.values) {
        final data = PlacedBuildingData(
          x: 1,
          y: 1,
          type: type,
          level: 2,
          assignedWorkers: 1,
        );

        final serialized = data.toLegacyString();
        final restored = PlacedBuildingData.fromLegacyString(serialized);

        expect(restored, isNotNull, reason: 'Failed for $type');
        expect(restored!.type, type);
        expect(restored.level, 2);
      }
    });
  });
}
