import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';

void main() {
  group('BuildingLimitManager', () {
    late BuildingLimitManager manager;

    setUp(() {
      manager = BuildingLimitManager();
    });

    group('getBuildingLimit', () {
      test('returns base limit with no upgrades', () {
        // house has baseBuildingLimit of 4 (default)
        final limit = manager.getBuildingLimit(BuildingType.house);
        expect(limit, equals(4));
      });

      test('returns base limit + upgrade after increaseBuildingLimit', () {
        manager.increaseBuildingLimit(BuildingType.house, 2);
        final limit = manager.getBuildingLimit(BuildingType.house);
        expect(limit, equals(6));
      });

      test(
        'returns correct limits for different building types independently',
        () {
          manager.increaseBuildingLimit(BuildingType.house, 3);

          final houseLimit = manager.getBuildingLimit(BuildingType.house);
          final powerPlantLimit = manager.getBuildingLimit(
            BuildingType.powerPlant,
          );

          expect(houseLimit, equals(7));
          // powerPlant base limit is 4, unchanged
          expect(powerPlantLimit, equals(4));
        },
      );
    });

    group('increaseBuildingLimit', () {
      test('accumulates multiple increases for same type', () {
        manager.increaseBuildingLimit(BuildingType.goldMine, 1);
        manager.increaseBuildingLimit(BuildingType.goldMine, 2);
        manager.increaseBuildingLimit(BuildingType.goldMine, 3);

        final limit = manager.getBuildingLimit(BuildingType.goldMine);
        // base(4) + 1 + 2 + 3 = 10
        expect(limit, equals(10));
      });

      test('does not affect other building types', () {
        manager.increaseBuildingLimit(BuildingType.coalMine, 5);

        expect(manager.getBuildingLimit(BuildingType.woodFactory), equals(4));
        expect(manager.getBuildingLimit(BuildingType.coalMine), equals(9));
      });
    });

    group('limitUpgrades getter', () {
      test('returns empty map when no upgrades applied', () {
        expect(manager.limitUpgrades, isEmpty);
      });

      test('returns copy of current upgrades', () {
        manager.increaseBuildingLimit(BuildingType.house, 2);
        final upgrades = manager.limitUpgrades;
        expect(upgrades[BuildingType.house], equals(2));

        // Mutating the returned map should not affect the manager
        upgrades[BuildingType.house] = 999;
        expect(manager.getBuildingLimit(BuildingType.house), equals(6));
      });
    });

    group('toMap', () {
      test('returns empty map when no upgrades', () {
        expect(manager.toMap(), isEmpty);
      });

      test('serializes upgrades to string-keyed map', () {
        manager.increaseBuildingLimit(BuildingType.house, 2);
        manager.increaseBuildingLimit(BuildingType.goldMine, 1);

        final map = manager.toMap();
        expect(map['house'], equals(2));
        expect(map['goldMine'], equals(1));
        expect(map.length, equals(2));
      });
    });

    group('loadFromMap', () {
      test('loads upgrades from string-keyed map', () {
        manager.loadFromMap({'house': 3, 'coalMine': 2});

        expect(manager.getBuildingLimit(BuildingType.house), equals(7));
        expect(manager.getBuildingLimit(BuildingType.coalMine), equals(6));
      });

      test('clears previous upgrades before loading', () {
        manager.increaseBuildingLimit(BuildingType.house, 5);
        manager.loadFromMap({'coalMine': 1});

        // house upgrade should be cleared
        expect(manager.getBuildingLimit(BuildingType.house), equals(4));
        expect(manager.getBuildingLimit(BuildingType.coalMine), equals(5));
      });

      test('ignores unknown building type names gracefully', () {
        expect(
          () => manager.loadFromMap({'unknownBuilding': 5}),
          returnsNormally,
        );
        expect(manager.limitUpgrades, isEmpty);
      });

      test('handles empty map', () {
        manager.increaseBuildingLimit(BuildingType.house, 2);
        manager.loadFromMap({});

        expect(manager.limitUpgrades, isEmpty);
      });
    });

    group('round-trip serialization', () {
      test('toMap followed by loadFromMap preserves state', () {
        manager.increaseBuildingLimit(BuildingType.house, 3);
        manager.increaseBuildingLimit(BuildingType.powerPlant, 1);

        final serialized = manager.toMap();

        final manager2 = BuildingLimitManager();
        manager2.loadFromMap(serialized);

        expect(
          manager2.getBuildingLimit(BuildingType.house),
          equals(manager.getBuildingLimit(BuildingType.house)),
        );
        expect(
          manager2.getBuildingLimit(BuildingType.powerPlant),
          equals(manager.getBuildingLimit(BuildingType.powerPlant)),
        );
      });
    });
  });

  group('BuildingLimitManager with custom base limits', () {
    test('reflects baseBuildingLimit from BuildingRegistry', () {
      // Verify that all building types in the registry have accessible limits
      final manager = BuildingLimitManager();
      for (final building in BuildingRegistry.availableBuildings) {
        final limit = manager.getBuildingLimit(building.type);
        expect(
          limit,
          equals(building.baseBuildingLimit),
          reason:
              '${building.type} should have base limit ${building.baseBuildingLimit}',
        );
      }
    });

    test(
      'custom baseBuildingLimit is respected when building has non-default value',
      () {
        // Create a fresh manager and check a building with custom base limit
        final manager = BuildingLimitManager();
        final customBuilding = Building(
          type: BuildingType.researchLab,
          name: 'Research Lab',
          description: 'Test',
          icon: Icons.science,
          color: Colors.blue,
          baseCost: 200,
          baseBuildingLimit: 2,
          requiredWorkers: 1,
          category: BuildingCategory.services,
        );
        // The registry entry for researchLab should match its declared baseBuildingLimit
        final registryBuilding = BuildingRegistry.availableBuildings.firstWhere(
          (b) => b.type == BuildingType.researchLab,
        );
        expect(
          manager.getBuildingLimit(BuildingType.researchLab),
          equals(registryBuilding.baseBuildingLimit),
        );
        // Confirm the customBuilding we built has limit 2 (not testing manager, just the object)
        expect(customBuilding.baseBuildingLimit, equals(2));
      },
    );
  });
}
