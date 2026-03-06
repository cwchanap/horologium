import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/game/services/save_service.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
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
          'planet_earth_resources_json': '{}',
          'planet_earth_quests': corruptQuestJson,
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
  });
}
