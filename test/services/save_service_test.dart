import 'package:flutter_test/flutter_test.dart';
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
      final dailySeed = prefs.getInt('planet.earth.quests.dailySeed');
      final weeklySeed = prefs.getInt('planet.earth.quests.weeklySeed');

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
        final dailySeed = prefs.getInt('planet.mars.quests.dailySeed');

        expect(dailySeed, equals(20260227)); // Should be the newer seed
      },
    );

    test('uses current date seeds when no rotating quests exist', () async {
      // Create only a non-rotating quest
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

      // Save seeds - should use current date's seeds
      await SaveService.saveQuestSeeds('moon', questManager);

      // Load seeds
      final prefs = await SharedPreferences.getInstance();
      final dailySeed = prefs.getInt('planet.moon.quests.dailySeed');
      final weeklySeed = prefs.getInt('planet.moon.quests.weeklySeed');

      // Should match the current date's seeds
      final today = DateTime.now().toUtc();
      final expectedDailySeed =
          today.year * 10000 + today.month * 100 + today.day;

      expect(dailySeed, equals(expectedDailySeed));
      expect(weeklySeed, isNotNull);
    });
  });
}
