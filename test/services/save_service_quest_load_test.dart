import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/game/achievements/achievement_manager.dart';
import 'package:horologium/game/services/save_service.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_registry.dart';
import 'package:horologium/game/planet/planet.dart';

void main() {
  group('SaveService quest loading', () {
    test(
      'loadOrCreatePlanet sets questLoadFailed when quest JSON is corrupt',
      () async {
        SharedPreferences.setMockInitialValues({
          'planet.earth.resources_json': '{}',
          'planet.earth.quests': '{invalid json',
        });
        final planet = await SaveService.loadOrCreatePlanet('earth');
        expect(planet.questLoadFailed, isTrue);
      },
    );

    test(
      'loadOrCreatePlanet sets achievementLoadFailed when achievement JSON is corrupt',
      () async {
        SharedPreferences.setMockInitialValues({
          'planet.earth.resources_json': '{}',
          'planet.earth.achievements': '{invalid json',
        });
        final planet = await SaveService.loadOrCreatePlanet('earth');
        expect(planet.achievementLoadFailed, isTrue);
      },
    );

    test(
      'loadOrCreatePlanet does not set questLoadFailed when quest JSON is valid or absent',
      () async {
        SharedPreferences.setMockInitialValues({
          'planet.earth.resources_json': '{}',
        });
        final planet = await SaveService.loadOrCreatePlanet('earth');
        expect(planet.questLoadFailed, isFalse);
      },
    );

    test(
      'loadOrCreatePlanet handles non-string elements in quest list IDs gracefully',
      () async {
        // Simulate corrupted JSON where quest IDs are integers, not strings
        const corruptQuestJson =
            '{"active":[123,456],"completed":[],"claimed":[],"objectiveProgress":{}}';
        SharedPreferences.setMockInitialValues({
          'planet.earth.resources_json': '{}',
          'planet.earth.quests': corruptQuestJson,
        });
        // Should not throw; should return a planet with default quest manager
        final planet = await SaveService.loadOrCreatePlanet('earth');
        expect(planet.questManager, isNotNull);
      },
    );

    test(
      'savePlanet persists correct daily seed when all daily quests are claimed',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        // Build a quest manager with only a claimed daily quest (no active daily quests)
        final questManager = QuestManager(
          quests: [
            Quest(
              id: 'daily_20260101_0',
              name: 'Test',
              description: 'Test quest',
              objectives: [],
              reward: const QuestReward(),
            ),
          ],
        );
        // Mark it as claimed
        questManager.quests
                .firstWhere((q) => q.id == 'daily_20260101_0')
                .status =
            QuestStatus.claimed;

        final planet = Planet(
          id: 'earth',
          name: 'Earth',
          questManager: questManager,
        );
        await SaveService.savePlanet(planet);

        // The saved daily seed must be 20260101, NOT today's date
        final savedSeed = prefs.getInt('planet.earth.quests.dailySeed');
        expect(savedSeed, equals(20260101));
      },
    );

    test(
      'savePlanet persists latest daily seed when old claimed and new active quests coexist',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        // Build a quest manager with both old claimed quests and new active quests
        final questManager = QuestManager(
          quests: [
            // Old claimed quest from Jan 1
            Quest(
              id: 'daily_20260101_0',
              name: 'Old Quest',
              description: 'Old quest from previous day',
              objectives: [],
              reward: const QuestReward(),
            ),
            // New active quest from Jan 5
            Quest(
              id: 'daily_20260105_1',
              name: 'New Quest',
              description: 'Current active quest',
              objectives: [],
              reward: const QuestReward(),
            ),
          ],
        );
        // Mark old quest as claimed, new quest as active
        questManager.quests
                .firstWhere((q) => q.id == 'daily_20260101_0')
                .status =
            QuestStatus.claimed;
        questManager.quests
                .firstWhere((q) => q.id == 'daily_20260105_1')
                .status =
            QuestStatus.active;

        final planet = Planet(
          id: 'earth',
          name: 'Earth',
          questManager: questManager,
        );
        await SaveService.savePlanet(planet);

        // The saved daily seed must be the LATEST seed (20260105), not the first one (20260101)
        final savedSeed = prefs.getInt('planet.earth.quests.dailySeed');
        expect(
          savedSeed,
          equals(20260105),
          reason: 'Should save latest seed, not first matching seed',
        );
      },
    );

    test(
      'savePlanet persists latest weekly seed when old and new weekly quests coexist',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        // Build a quest manager with both old and new weekly quests
        final questManager = QuestManager(
          quests: [
            Quest(
              id: 'weekly_202601_0',
              name: 'Old Weekly',
              description: 'Old weekly quest',
              objectives: [],
              reward: const QuestReward(),
            ),
            Quest(
              id: 'weekly_202603_1',
              name: 'New Weekly',
              description: 'Current weekly quest',
              objectives: [],
              reward: const QuestReward(),
            ),
          ],
        );
        questManager.quests
                .firstWhere((q) => q.id == 'weekly_202601_0')
                .status =
            QuestStatus.claimed;
        questManager.quests
                .firstWhere((q) => q.id == 'weekly_202603_1')
                .status =
            QuestStatus.active;

        final planet = Planet(
          id: 'earth',
          name: 'Earth',
          questManager: questManager,
        );
        await SaveService.savePlanet(planet);

        // The saved weekly seed must be the LATEST seed (202603), not the first one (202601)
        final savedSeed = prefs.getInt('planet.earth.quests.weeklySeed');
        expect(
          savedSeed,
          equals(202603),
          reason: 'Should save latest weekly seed, not first matching seed',
        );
      },
    );
  });

  group('SaveService round-trip', () {
    test(
      'savePlanet and loadOrCreatePlanet round-trips quest status correctly',
      () async {
        SharedPreferences.setMockInitialValues({});

        final questManager = QuestManager(quests: QuestRegistry.starterQuests);
        final allQuests = questManager.quests;

        // Need at least 3 quests to test all statuses
        expect(allQuests.length, greaterThanOrEqualTo(3));

        // Set 3 different statuses
        final q0 = allQuests[0];
        final q1 = allQuests[1];
        final q2 = allQuests[2];

        q0.status = QuestStatus.active;
        if (q0.objectives.isNotEmpty) {
          q0.objectives.first.currentAmount = 3;
        }
        q1.status = QuestStatus.completed;
        q2.status = QuestStatus.claimed;

        final planet = Planet(
          id: 'roundtrip_test',
          name: 'Test',
          questManager: questManager,
        );
        await SaveService.savePlanet(planet);

        final loaded = await SaveService.loadOrCreatePlanet(
          'roundtrip_test',
          name: 'Test',
        );
        final loadedQuests = loaded.questManager.quests;

        final loadedQ0 = loadedQuests.firstWhere((q) => q.id == q0.id);
        final loadedQ1 = loadedQuests.firstWhere((q) => q.id == q1.id);
        final loadedQ2 = loadedQuests.firstWhere((q) => q.id == q2.id);

        expect(loadedQ0.status, equals(QuestStatus.active));
        expect(loadedQ1.status, equals(QuestStatus.completed));
        expect(loadedQ2.status, equals(QuestStatus.claimed));

        // Verify objective progress survived if q0 had objectives
        if (q0.objectives.isNotEmpty) {
          final loadedObj = loadedQ0.objectives.first;
          expect(loadedObj.currentAmount, equals(3));
        }
      },
    );

    test(
      'savePlanet and loadOrCreatePlanet round-trips achievement state correctly',
      () async {
        SharedPreferences.setMockInitialValues({});

        final achievements = Planet.defaultAchievements();
        final firstId = achievements[0].id;
        final secondId = achievements[1].id;

        achievements[0].isUnlocked = true; // first achievement unlocked
        achievements[1].currentAmount = 7; // second achievement at 7 progress

        final achievementManager = AchievementManager(
          achievements: achievements,
        );
        final planet = Planet(
          id: 'ach_roundtrip_test',
          name: 'Test',
          achievementManager: achievementManager,
        );
        await SaveService.savePlanet(planet);

        final loaded = await SaveService.loadOrCreatePlanet(
          'ach_roundtrip_test',
          name: 'Test',
        );
        final loadedAchs = loaded.achievementManager.achievements;

        final loadedFirst = loadedAchs.firstWhere((a) => a.id == firstId);
        final loadedSecond = loadedAchs.firstWhere((a) => a.id == secondId);

        expect(loadedFirst.isUnlocked, isTrue);
        expect(loadedSecond.currentAmount, equals(7));
      },
    );
  });
}
