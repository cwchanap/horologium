import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/planet/placed_building_data.dart';

void main() {
  group('PlacedBuildingData Persistence Tests', () {
    test('toLegacyString includes id, level and workers', () {
      final data = PlacedBuildingData(
        id: 'test-id-123',
        x: 5,
        y: 10,
        type: BuildingType.powerPlant,
        level: 3,
        assignedWorkers: 2,
      );

      final result = data.toLegacyString();

      expect(result, 'test-id-123,5,10,powerPlant,3,2');
    });

    test('fromLegacyString parses new format with id, level and workers', () {
      final result = PlacedBuildingData.fromLegacyString(
        'uuid-123,5,10,powerPlant,3,2',
      );

      expect(result, isNotNull);
      expect(result!.id, 'uuid-123');
      expect(result.x, 5);
      expect(result.y, 10);
      expect(result.type, BuildingType.powerPlant);
      expect(result.level, 3);
      expect(result.assignedWorkers, 2);
    });

    test('fromLegacyString parses old format without id (backward compat)', () {
      final result = PlacedBuildingData.fromLegacyString('5,10,powerPlant');

      expect(result, isNotNull);
      expect(result!.id, isNotNull); // Should generate new ID
      expect(result.x, 5);
      expect(result.y, 10);
      expect(result.type, BuildingType.powerPlant);
      expect(result.level, 1); // Default level
      expect(result.assignedWorkers, 0); // Default workers
    });

    test('fromLegacyString parses format with id and level (no workers)', () {
      final result = PlacedBuildingData.fromLegacyString(
        'uuid-abc,5,10,powerPlant,3',
      );

      expect(result, isNotNull);
      expect(result!.id, 'uuid-abc');
      expect(result.x, 5);
      expect(result.y, 10);
      expect(result.type, BuildingType.powerPlant);
      expect(result.level, 3);
      expect(result.assignedWorkers, 0); // Default workers
    });

    test('fromLegacyString clamps invalid level and workers', () {
      final result = PlacedBuildingData.fromLegacyString(
        'uuid-xyz,5,10,powerPlant,-2,-1',
      );

      expect(result, isNotNull);
      expect(result!.id, 'uuid-xyz');
      expect(result.level, 1); // Clamp to minimum level
      expect(result.assignedWorkers, 0); // Clamp to minimum workers
    });

    test('createBuilding preserves level and id from PlacedBuildingData', () {
      final data = PlacedBuildingData(
        id: 'preserve-id-123',
        x: 5,
        y: 10,
        type: BuildingType.powerPlant,
        level: 3,
        assignedWorkers: 1,
      );

      final building = data.createBuilding();

      expect(building, isNotNull);
      expect(building!.id, 'preserve-id-123');
      expect(building.level, 3);
      expect(building.assignedWorkers, 1);
    });

    test('round-trip persistence preserves all data', () {
      final original = PlacedBuildingData(
        id: 'round-trip-id',
        x: 15,
        y: 20,
        type: BuildingType.house,
        level: 4,
        assignedWorkers: 0,
      );

      final serialized = original.toLegacyString();
      final restored = PlacedBuildingData.fromLegacyString(serialized);

      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.x, original.x);
      expect(restored.y, original.y);
      expect(restored.type, original.type);
      expect(restored.level, original.level);
      expect(restored.assignedWorkers, original.assignedWorkers);
    });

    test('handles all building types', () {
      for (final type in BuildingType.values) {
        final data = PlacedBuildingData(
          id: 'test-$type',
          x: 1,
          y: 1,
          type: type,
          level: 2,
          assignedWorkers: 1,
        );

        final serialized = data.toLegacyString();
        final restored = PlacedBuildingData.fromLegacyString(serialized);

        expect(restored, isNotNull, reason: 'Failed for $type');
        expect(restored!.id, 'test-$type');
        expect(restored.type, type);
        expect(restored.level, 2);
        expect(restored.assignedWorkers, 1);
      }
    });
  });
}
