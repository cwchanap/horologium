import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/planet/placed_building_data.dart';
import 'package:horologium/game/planet/planet.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/game/services/save_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SaveService.saveQuestSeeds', () {
    test('saves daily and weekly seeds from quest IDs', () async {
      // Create some rotating quests with specific seeds
      final dailyQuest = Quest(
        id: 'daily_20260227_0',
        name: 'Daily Quest',
        description: 'Test',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.accumulateResource,
            targetId: 'cash',
            targetAmount: 100,
          ),
        ],
        reward: const QuestReward(resources: {ResourceType.cash: 100.0}),
      );

      final weeklyQuest = Quest(
        id: 'weekly_20260223_0',
        name: 'Weekly Quest',
        description: 'Test',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 5,
          ),
        ],
        reward: const QuestReward(resources: {ResourceType.gold: 200.0}),
      );

      final questManager = QuestManager(quests: [dailyQuest, weeklyQuest]);

      // Save seeds
      await SaveService.saveQuestSeeds('earth', questManager);

      // Load seeds directly from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final dailySeed = prefs.getInt('planet_earth_quests_dailySeed');
      final weeklySeed = prefs.getInt('planet_earth_quests_weeklySeed');

      expect(dailySeed, equals(20260227));
      expect(weeklySeed, equals(20260223));
    });

    test(
      'extracts the latest (maximum) seed when multiple seeds exist',
      () async {
        // Create quests from different days (old claimed and current active)
        final oldQuest = Quest(
          id: 'daily_20260220_0',
          name: 'Old Daily',
          description: 'Test',
          objectives: [
            QuestObjective(
              type: QuestObjectiveType.accumulateResource,
              targetId: 'cash',
              targetAmount: 100,
            ),
          ],
          reward: const QuestReward(resources: {ResourceType.cash: 100.0}),
        );

        final newQuest = Quest(
          id: 'daily_20260227_0',
          name: 'New Daily',
          description: 'Test',
          objectives: [
            QuestObjective(
              type: QuestObjectiveType.accumulateResource,
              targetId: 'cash',
              targetAmount: 100,
            ),
          ],
          reward: const QuestReward(resources: {ResourceType.cash: 100.0}),
        );

        final questManager = QuestManager(quests: [oldQuest, newQuest]);

        // Save seeds - should save the maximum (latest) seed
        await SaveService.saveQuestSeeds('mars', questManager);

        // Load seeds
        final prefs = await SharedPreferences.getInstance();
        final dailySeed = prefs.getInt('planet_mars_quests_dailySeed');

        expect(dailySeed, equals(20260227)); // Should be the newer seed
      },
    );

    test('does not write seed keys when no rotating quests exist', () async {
      // Create only a non-rotating quest (e.g. freshly-migrated legacy save)
      final staticQuest = Quest(
        id: 'build_house',
        name: 'Build House',
        description: 'Test',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
          ),
        ],
        reward: const QuestReward(resources: {ResourceType.cash: 50.0}),
      );

      final questManager = QuestManager(quests: [staticQuest]);

      await SaveService.saveQuestSeeds('moon', questManager);

      final prefs = await SharedPreferences.getInstance();

      // Seeds must NOT be written; their absence lets refreshRotatingQuests()
      // generate quests on the next load instead of skipping generation.
      expect(prefs.containsKey('planet_moon_quests_dailySeed'), isFalse);
      expect(prefs.containsKey('planet_moon_quests_weeklySeed'), isFalse);
    });

    test('removes stale seed keys when no rotating quests exist', () async {
      SharedPreferences.setMockInitialValues({
        'planet.moon.quests.dailySeed': 20260101,
        'planet.moon.quests.weeklySeed': 202601,
      });

      final staticQuest = Quest(
        id: 'build_house',
        name: 'Build House',
        description: 'Test',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
          ),
        ],
        reward: const QuestReward(resources: {ResourceType.cash: 50.0}),
      );

      final questManager = QuestManager(quests: [staticQuest]);
      await SaveService.saveQuestSeeds('moon', questManager);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('planet_moon_quests_dailySeed'), isFalse);
      expect(prefs.containsKey('planet_moon_quests_weeklySeed'), isFalse);
      expect(prefs.containsKey('planet.moon.quests.dailySeed'), isFalse);
      expect(prefs.containsKey('planet.moon.quests.weeklySeed'), isFalse);
    });
  });

  group('SaveService planet building variant round-trips', () {
    test('saves and reloads a Field building with corn crop variant', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const planetId = 'variant-field';
      // Format: id,x,y,type,level,workers,variant
      const buildingStr = 'field-abc,3,4,field,1,1,corn';

      // Set resources JSON key so loadOrCreatePlanet enters the loading branch.
      await prefs.setString('planet.$planetId.resources_json', '{}');
      await prefs.setStringList('planet.$planetId.buildings', [buildingStr]);

      final planet = await SaveService.loadOrCreatePlanet(
        planetId,
        name: 'Field Planet',
      );

      expect(planet.buildings, hasLength(1));
      expect(planet.buildings.first.type, BuildingType.field);
      expect(planet.buildings.first.variant, 'corn');
    });

    test(
      'saves and reloads a Bakery building with pastries product variant',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        const planetId = 'variant-bakery';
        const buildingStr = 'bakery-xyz,1,2,bakery,1,2,pastries';

        // Set resources JSON key so loadOrCreatePlanet enters the loading branch.
        await prefs.setString('planet.$planetId.resources_json', '{}');
        await prefs.setStringList('planet.$planetId.buildings', [buildingStr]);

        final planet = await SaveService.loadOrCreatePlanet(
          planetId,
          name: 'Bakery Planet',
        );

        expect(planet.buildings, hasLength(1));
        expect(planet.buildings.first.type, BuildingType.bakery);
        expect(planet.buildings.first.variant, 'pastries');
      },
    );

    test('building with no variant field loads with null variant', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const planetId = 'no-variant';
      // Old format: id,x,y,type,level,workers (no variant field)
      const buildingStr = 'house-123,5,5,house,1,0';

      // Set resources JSON key so loadOrCreatePlanet enters the loading branch.
      await prefs.setString('planet.$planetId.resources_json', '{}');
      await prefs.setStringList('planet.$planetId.buildings', [buildingStr]);

      final planet = await SaveService.loadOrCreatePlanet(
        planetId,
        name: 'No Variant Planet',
      );

      expect(planet.buildings, hasLength(1));
      expect(planet.buildings.first.variant, isNull);
    });

    test(
      'savePlanet persists Field variant and loadOrCreatePlanet restores it',
      () async {
        SharedPreferences.setMockInitialValues({});

        const planetId = 'roundtrip-field';
        final fieldData = PlacedBuildingData(
          id: 'f1',
          x: 2,
          y: 3,
          type: BuildingType.field,
          variant: 'barley',
        );
        final planet = Planet(
          id: planetId,
          name: 'Round Trip',
          buildings: [fieldData],
        );

        await SaveService.savePlanet(planet);
        final loaded = await SaveService.loadOrCreatePlanet(
          planetId,
          name: 'Round Trip',
        );

        expect(loaded.buildings, hasLength(1));
        expect(loaded.buildings.first.variant, 'barley');
      },
    );
  });
}
