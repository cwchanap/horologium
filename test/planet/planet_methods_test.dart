import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/planet/planet.dart';
import 'package:horologium/game/planet/placed_building_data.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/resources/resources.dart';

PlacedBuildingData _house({String id = 'h1', int x = 0, int y = 0}) {
  return PlacedBuildingData(id: id, x: x, y: y, type: BuildingType.house);
}

PlacedBuildingData _powerPlant({String id = 'p1', int x = 4, int y = 0}) {
  return PlacedBuildingData(
    id: id,
    x: x,
    y: y,
    type: BuildingType.powerPlant,
  );
}

Planet _emptyPlanet() =>
    Planet(id: 'test', name: 'Test', questManager: QuestManager(quests: []));

void main() {
  group('Planet.addBuilding', () {
    test('adds building to the planet', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      expect(planet.buildings.length, equals(1));
    });

    test('increments totalBuildingsPlaced', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      expect(planet.totalBuildingsPlaced, equals(1));
    });

    test('updates cumulative building counts', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(id: 'h1'));
      planet.addBuilding(_house(id: 'h2', x: 1));
      expect(planet.getCumulativeBuildingCount(BuildingType.house), equals(2));
    });

    test('cumulative count does not decrease when building is later removed',
        () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      planet.removeBuildingAt(0, 0);
      expect(planet.getCumulativeBuildingCount(BuildingType.house), equals(1));
    });

    test('tracks multiple building types independently', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      planet.addBuilding(_powerPlant());
      expect(
        planet.getCumulativeBuildingCount(BuildingType.house),
        equals(1),
      );
      expect(
        planet.getCumulativeBuildingCount(BuildingType.powerPlant),
        equals(1),
      );
    });
  });

  group('Planet.removeBuildingAt', () {
    test('removes existing building and returns true', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(x: 5, y: 5));
      final removed = planet.removeBuildingAt(5, 5);
      expect(removed, isTrue);
      expect(planet.buildings.isEmpty, isTrue);
    });

    test('returns false when no building at coordinates', () {
      final planet = _emptyPlanet();
      final removed = planet.removeBuildingAt(99, 99);
      expect(removed, isFalse);
    });

    test('only removes the targeted building', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(id: 'h1', x: 0, y: 0));
      planet.addBuilding(_house(id: 'h2', x: 1, y: 0));
      planet.removeBuildingAt(0, 0);
      expect(planet.buildings.length, equals(1));
      expect(planet.buildings.first.x, equals(1));
    });
  });

  group('Planet.getBuildingAt', () {
    test('returns building at exact coordinates', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(x: 3, y: 7));
      final building = planet.getBuildingAt(3, 7);
      expect(building, isNotNull);
      expect(building!.type, equals(BuildingType.house));
    });

    test('returns null when no building at coordinates', () {
      final planet = _emptyPlanet();
      expect(planet.getBuildingAt(0, 0), isNull);
    });

    test('returns null when planet has buildings but none at given coordinates',
        () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(x: 1, y: 1));
      expect(planet.getBuildingAt(5, 5), isNull);
    });
  });

  group('Planet.isPositionOccupied', () {
    test('returns true when building exists at position', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(x: 2, y: 3));
      expect(planet.isPositionOccupied(2, 3), isTrue);
    });

    test('returns false when no building at position', () {
      final planet = _emptyPlanet();
      expect(planet.isPositionOccupied(0, 0), isFalse);
    });
  });

  group('Planet.updateBuildingAt', () {
    test('replaces building data at coordinates and returns true', () {
      final planet = _emptyPlanet();
      planet.addBuilding(
        const PlacedBuildingData(
          id: 'orig',
          x: 2,
          y: 2,
          type: BuildingType.house,
          level: 1,
        ),
      );

      final upgraded = const PlacedBuildingData(
        id: 'orig',
        x: 2,
        y: 2,
        type: BuildingType.house,
        level: 3,
      );
      final result = planet.updateBuildingAt(2, 2, upgraded);

      expect(result, isTrue);
      expect(planet.getBuildingAt(2, 2)!.level, equals(3));
    });

    test('returns false when no building at coordinates', () {
      final planet = _emptyPlanet();
      final result = planet.updateBuildingAt(
        5,
        5,
        const PlacedBuildingData(id: 'x', x: 5, y: 5, type: BuildingType.house),
      );
      expect(result, isFalse);
    });
  });

  group('Planet.getBuildingCount', () {
    test('returns 0 when no buildings of given type', () {
      final planet = _emptyPlanet();
      expect(planet.getBuildingCount(BuildingType.house), equals(0));
    });

    test('counts only matching type', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(id: 'h1', x: 0, y: 0));
      planet.addBuilding(_house(id: 'h2', x: 1, y: 0));
      planet.addBuilding(_powerPlant());
      expect(planet.getBuildingCount(BuildingType.house), equals(2));
      expect(planet.getBuildingCount(BuildingType.powerPlant), equals(1));
    });
  });

  group('Planet.getCumulativeBuildingCount', () {
    test('returns 0 for type never placed', () {
      final planet = _emptyPlanet();
      expect(
        planet.getCumulativeBuildingCount(BuildingType.goldMine),
        equals(0),
      );
    });

    test('returns count even after removal', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      planet.removeBuildingAt(0, 0);
      expect(
        planet.getCumulativeBuildingCount(BuildingType.house),
        equals(1),
      );
    });
  });

  group('Planet.getTotalBuildingsPlaced', () {
    test('returns 0 for empty planet', () {
      expect(_emptyPlanet().getTotalBuildingsPlaced(), equals(0));
    });

    test('increments with each addBuilding', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(id: 'h1', x: 0, y: 0));
      planet.addBuilding(_house(id: 'h2', x: 1, y: 0));
      expect(planet.getTotalBuildingsPlaced(), equals(2));
    });

    test('does not decrease after removeBuildingAt', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      planet.removeBuildingAt(0, 0);
      expect(planet.getTotalBuildingsPlaced(), equals(1));
    });
  });

  group('Planet.setBuildings', () {
    test('replaces all existing buildings', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(id: 'old', x: 0, y: 0));

      final newBuildings = [_powerPlant(id: 'new', x: 5, y: 5)];
      planet.setBuildings(newBuildings);

      expect(planet.buildings.length, equals(1));
      expect(planet.buildings.first.type, equals(BuildingType.powerPlant));
    });

    test('can clear all buildings', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      planet.setBuildings([]);
      expect(planet.buildings, isEmpty);
    });
  });

  group('Planet.getActiveBuildings', () {
    test('returns Building instances for all placed buildings', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house(id: 'h1', x: 0, y: 0));
      planet.addBuilding(_powerPlant(id: 'p1', x: 4, y: 0));
      final active = planet.getActiveBuildings();
      expect(active.length, equals(2));
    });

    test('preserves level from placement data', () {
      final planet = _emptyPlanet();
      planet.addBuilding(
        const PlacedBuildingData(
          id: 'h1',
          x: 0,
          y: 0,
          type: BuildingType.house,
          level: 3,
        ),
      );
      final buildings = planet.getActiveBuildings();
      expect(buildings.first.level, equals(3));
    });

    test('returns empty list for planet with no buildings', () {
      expect(_emptyPlanet().getActiveBuildings(), isEmpty);
    });
  });

  group('Planet.copyWith', () {
    test('creates planet with updated name', () {
      final planet = Planet(id: 'mars', name: 'Mars', questManager: QuestManager(quests: []));
      final copy = planet.copyWith(name: 'Mars II');
      expect(copy.name, equals('Mars II'));
      expect(copy.id, equals('mars'));
    });

    test('preserves original field when not overridden', () {
      final planet = Planet(
        id: 'venus',
        name: 'Venus',
        questManager: QuestManager(quests: []),
        lastDailySeed: 20260315,
      );
      final copy = planet.copyWith(name: 'Venus II');
      expect(copy.lastDailySeed, equals(20260315));
    });

    test('copies buildings list', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      final copy = planet.copyWith();
      expect(copy.buildings.length, equals(1));
    });

    test('can override specific boolean flags', () {
      final planet = _emptyPlanet();
      final copy = planet.copyWith(questLoadFailed: true);
      expect(copy.questLoadFailed, isTrue);
      expect(planet.questLoadFailed, isFalse);
    });

    test('can replace resources', () {
      final planet = _emptyPlanet();
      final newResources = Resources();
      newResources.cash = 99999;
      final copy = planet.copyWith(resources: newResources);
      expect(copy.resources.cash, equals(99999));
    });
  });

  group('Planet.toString', () {
    test('includes planet id, name, and building count', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      final str = planet.toString();
      expect(str, contains('test'));
      expect(str, contains('Test'));
      expect(str, contains('1'));
    });
  });

  group('Planet constructor cumulative count initialization', () {
    test(
      'uses provided cumulativeBuildingCounts when non-empty',
      () {
        final counts = {BuildingType.house: 10};
        final planet = Planet(
          id: 'p',
          name: 'P',
          cumulativeBuildingCounts: counts,
          questManager: QuestManager(quests: []),
        );
        expect(
          planet.getCumulativeBuildingCount(BuildingType.house),
          equals(10),
        );
      },
    );

    test(
      'derives counts from buildings when cumulativeBuildingCounts not provided',
      () {
        final planet = Planet(
          id: 'p',
          name: 'P',
          buildings: [
            _house(id: 'h1', x: 0, y: 0),
            _house(id: 'h2', x: 1, y: 0),
          ],
          questManager: QuestManager(quests: []),
        );
        expect(
          planet.getCumulativeBuildingCount(BuildingType.house),
          equals(2),
        );
      },
    );

    test('returns empty counts for planet with no buildings or counts', () {
      final planet = _emptyPlanet();
      expect(planet.cumulativeBuildingCounts, isEmpty);
    });
  });

  group('Planet.defaultAchievements', () {
    test('returns non-empty list', () {
      expect(Planet.defaultAchievements(), isNotEmpty);
    });

    test('all achievement ids are unique', () {
      final achievements = Planet.defaultAchievements();
      final ids = achievements.map((a) => a.id).toSet();
      expect(ids.length, equals(achievements.length));
    });

    test('includes key achievements', () {
      final achievements = Planet.defaultAchievements();
      final ids = achievements.map((a) => a.id).toSet();
      expect(ids, contains('ach_first_building'));
      expect(ids, contains('ach_rich'));
      expect(ids, contains('ach_all_research'));
    });
  });

  group('Planet buildings are unmodifiable', () {
    test('buildings getter returns unmodifiable list', () {
      final planet = _emptyPlanet();
      planet.addBuilding(_house());
      expect(
        () => planet.buildings.add(_powerPlant()),
        throwsUnsupportedError,
      );
    });
  });

  group('Planet default constructor values', () {
    test('creates with default resources when none provided', () {
      final planet = Planet(
        id: 'p',
        name: 'P',
        questManager: QuestManager(quests: []),
      );
      expect(planet.resources, isNotNull);
      expect(planet.buildings, isEmpty);
      expect(planet.lastDailySeed, equals(0));
      expect(planet.lastWeeklySeed, equals(0));
      expect(planet.buildingLimitsParseError, isFalse);
      expect(planet.questLoadFailed, isFalse);
      expect(planet.achievementLoadFailed, isFalse);
    });

    test('achievementManager is set from defaultAchievements when not provided',
        () {
      final planet = Planet(
        id: 'p',
        name: 'P',
        questManager: QuestManager(quests: []),
      );
      expect(planet.achievementManager, isNotNull);
      expect(planet.achievementManager.achievements, isNotEmpty);
    });
  });
}
