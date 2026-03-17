import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/achievements/achievement.dart';
import 'package:horologium/game/achievements/achievement_manager.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/managers/game_state_manager.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:shared_preferences/shared_preferences.dart';

Building _makeHouse() {
  return Building(
    type: BuildingType.house,
    name: 'House',
    description: 'Housing',
    icon: Icons.house,
    color: Colors.green,
    baseCost: 120,
    basePopulation: 2,
    requiredWorkers: 0,
    category: BuildingCategory.residential,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameStateManager.checkProgress', () {
    test('does not throw when questManager and achievementManager are null', () {
      final gsm = GameStateManager(resources: Resources());

      expect(
        () => gsm.checkProgress([_makeHouse()]),
        returnsNormally,
      );
    });

    test('delegates to questManager when set', () {
      final resources = Resources();
      resources.cash = 1000;

      final quest = Quest(
        id: 'test_cash_quest',
        name: 'Cash Collector',
        description: 'Accumulate 500 cash',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.accumulateResource,
            targetId: 'cash',
            targetAmount: 500,
          ),
        ],
        reward: const QuestReward(),
      );

      final gsm = GameStateManager(resources: resources);
      gsm.questManager = QuestManager(quests: [quest]);

      gsm.checkProgress([]);

      final completedQuests = gsm.questManager!.getCompletedQuests();
      expect(completedQuests, isNotEmpty);
      expect(completedQuests.first.id, equals('test_cash_quest'));
    });

    test('delegates to achievementManager when set', () {
      final resources = Resources();
      // Set cash high enough to trigger the wealthy achievement
      resources.cash = 15000;

      final wealthyAchievement = Achievement(
        id: 'ach_wealthy',
        name: 'Wealthy',
        description: 'Accumulate 10000 cash',
        type: AchievementType.resourceAccumulated,
        targetAmount: 10000,
        targetId: 'cash',
      );

      final gsm = GameStateManager(resources: resources);
      gsm.achievementManager = AchievementManager(
        achievements: [wealthyAchievement],
      );

      gsm.checkProgress([]);

      final unlocked = gsm.achievementManager!.getUnlocked();
      expect(unlocked, isNotEmpty);
      expect(unlocked.first.id, equals('ach_wealthy'));
    });

    test(
      'both questManager and achievementManager are checked in same call',
      () {
        final resources = Resources();
        resources.cash = 10000;

        final quest = Quest(
          id: 'cash_quest',
          name: 'Cash Quest',
          description: 'Get 1000 cash',
          objectives: [
            QuestObjective(
              type: QuestObjectiveType.accumulateResource,
              targetId: 'cash',
              targetAmount: 1000,
            ),
          ],
          reward: const QuestReward(),
        );

        final achievement = Achievement(
          id: 'ach_cash',
          name: 'Rich',
          description: 'Get 5000 cash',
          type: AchievementType.resourceAccumulated,
          targetAmount: 5000,
          targetId: 'cash',
        );

        final gsm = GameStateManager(resources: resources);
        gsm.questManager = QuestManager(quests: [quest]);
        gsm.achievementManager = AchievementManager(achievements: [achievement]);

        gsm.checkProgress([]);

        expect(gsm.questManager!.getCompletedQuests(), isNotEmpty);
        expect(gsm.achievementManager!.getUnlocked(), isNotEmpty);
      },
    );

    test('passes cumulative building counts to questManager', () {
      final resources = Resources();

      // Create a quest that requires placing 3 houses cumulatively
      final quest = Quest(
        id: 'builder_quest',
        name: 'Builder',
        description: 'Place 3 houses',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 3,
          ),
        ],
        reward: const QuestReward(),
      );

      final gsm = GameStateManager(resources: resources);
      gsm.questManager = QuestManager(quests: [quest]);

      // First call with count 0 establishes baseline (startingAmount = 0)
      gsm.checkProgress([], {'house': 0}, null);
      expect(gsm.questManager!.getCompletedQuests(), isEmpty);

      // Second call with count 3 shows progress of 3 - 0 = 3, completing the quest
      gsm.checkProgress([], {'house': 3}, null);

      final completedQuests = gsm.questManager!.getCompletedQuests();
      expect(completedQuests, isNotEmpty);
      expect(completedQuests.first.id, equals('builder_quest'));
    });

    test('passes totalBuildingsPlaced to achievementManager', () {
      final resources = Resources();

      final achievement = Achievement(
        id: 'ach_first_building',
        name: 'Foundation',
        description: 'Place 1 building',
        type: AchievementType.buildingCount,
        targetAmount: 1,
      );

      final gsm = GameStateManager(resources: resources);
      gsm.achievementManager =
          AchievementManager(achievements: [achievement]);

      // Pass totalBuildingsPlaced = 1
      gsm.checkProgress([], null, 1);

      final unlocked = gsm.achievementManager!.getUnlocked();
      expect(unlocked, isNotEmpty);
      expect(unlocked.first.id, equals('ach_first_building'));
    });
  });

  group('GameStateManager.dispose', () {
    test(
      'stops resource generation timer on dispose',
      () async {
        int tickCount = 0;
        final gsm = GameStateManager(resources: Resources());

        gsm.startResourceGeneration(
          () => [],
          ([bool _ = false]) => tickCount++,
        );

        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect(tickCount, greaterThan(0));

        final countBeforeDispose = tickCount;
        gsm.dispose();

        await Future<void>.delayed(const Duration(milliseconds: 1200));
        // No additional ticks after dispose
        expect(tickCount, equals(countBeforeDispose));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test('dispose is safe to call when timer was never started', () {
      final gsm = GameStateManager(resources: Resources());
      expect(() => gsm.dispose(), returnsNormally);
    });

    test('dispose is idempotent', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.startResourceGeneration(() => [], ([bool _ = false]) {});
      expect(() {
        gsm.dispose();
        gsm.dispose();
      }, returnsNormally);
    });
  });

  group('GameStateManager.initializeSeedsFromLoadedData', () {
    test('prevents re-generation on same day when seeds match', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.questManager = QuestManager(quests: []);

      final date = DateTime.utc(2026, 3, 15);

      // First refresh to record seeds
      gsm.refreshRotatingQuests(now: date);

      // Simulate app restart: create new manager with loaded seeds
      final gsm2 = GameStateManager(resources: Resources());
      gsm2.questManager = QuestManager(quests: []);
      gsm2.initializeSeedsFromLoadedData(20260315, 20260309);

      // Should not refresh on same day
      final refreshed = gsm2.refreshRotatingQuests(now: date);
      expect(refreshed, isFalse);
    });

    test('allows refresh when loaded seeds differ from current date', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.questManager = QuestManager(quests: []);

      // Simulate old save seeds from yesterday
      gsm.initializeSeedsFromLoadedData(20260314, 20260309);

      final today = DateTime.utc(2026, 3, 15);
      final refreshed = gsm.refreshRotatingQuests(now: today);
      expect(refreshed, isTrue);
    });
  });

  group('GameStateManager researchManager integration', () {
    test('checkProgress uses the assigned researchManager', () {
      final rm = ResearchManager();
      rm.completeResearch(ResearchType.electricity);

      final quest = Quest(
        id: 'research_quest',
        name: 'Researcher',
        description: 'Complete electricity research',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.completeResearch,
            targetId: 'electricity',
            targetAmount: 1,
          ),
        ],
        reward: const QuestReward(),
      );

      final gsm = GameStateManager(resources: Resources());
      gsm.researchManager = rm;
      gsm.questManager = QuestManager(quests: [quest]);

      gsm.checkProgress([]);

      final completed = gsm.questManager!.getCompletedQuests();
      expect(completed, isNotEmpty);
    });

    test(
      'checkProgress with default researchManager does not unlock research quest',
      () {
        final quest = Quest(
          id: 'research_quest',
          name: 'Researcher',
          description: 'Complete electricity research',
          objectives: [
            QuestObjective(
              type: QuestObjectiveType.completeResearch,
              targetId: 'electricity',
              targetAmount: 1,
            ),
          ],
          reward: const QuestReward(),
        );

        final gsm = GameStateManager(resources: Resources());
        // researchManager starts with no completions
        gsm.questManager = QuestManager(quests: [quest]);

        gsm.checkProgress([]);

        expect(gsm.questManager!.getCompletedQuests(), isEmpty);
      },
    );
  });
}
