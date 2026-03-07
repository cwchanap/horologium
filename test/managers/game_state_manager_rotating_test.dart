import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/managers/game_state_manager.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/quests/quest_registry.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameStateManager rotating quests', () {
    test('refreshRotatingQuests adds daily and weekly quests', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.questManager = QuestManager(quests: QuestRegistry.starterQuests);

      final date = DateTime.utc(2026, 2, 27);
      final refreshed = gsm.refreshRotatingQuests(now: date);

      expect(refreshed, isTrue);
      final allQuests = gsm.questManager!.quests;
      expect(allQuests.any((q) => q.id.startsWith('daily_')), isTrue);
      expect(allQuests.any((q) => q.id.startsWith('weekly_')), isTrue);
    });

    test('does not refresh if same day', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.questManager = QuestManager(quests: []);

      // Use UTC datetimes to avoid timezone-dependent failures
      final date = DateTime.utc(2026, 2, 27);
      gsm.refreshRotatingQuests(now: date);
      final count1 = gsm.questManager!.quests.length;

      // Same UTC day, different time
      final refreshed = gsm.refreshRotatingQuests(
        now: DateTime.utc(2026, 2, 27, 18, 0),
      );
      expect(refreshed, isFalse);
      expect(gsm.questManager!.quests.length, equals(count1));
    });

    test('refreshes when day changes', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.questManager = QuestManager(quests: []);

      gsm.refreshRotatingQuests(now: DateTime.utc(2026, 2, 27));
      final ids1 = gsm.questManager!.quests
          .where((q) => q.id.startsWith('daily_'))
          .map((q) => q.id)
          .toSet();

      gsm.refreshRotatingQuests(now: DateTime.utc(2026, 2, 28));
      final ids2 = gsm.questManager!.quests
          .where((q) => q.id.startsWith('daily_'))
          .map((q) => q.id)
          .toSet();

      expect(ids1.intersection(ids2), isEmpty);
    });

    test('returns false when no quest manager', () {
      final gsm = GameStateManager(resources: Resources());
      expect(gsm.refreshRotatingQuests(), isFalse);
    });

    group('onSeedsChanged callback', () {
      test('callback is invoked when quests are refreshed', () {
        final gsm = GameStateManager(resources: Resources());
        gsm.questManager = QuestManager(quests: []);

        int? capturedDailySeed;
        int? capturedWeeklySeed;

        void onSeedsChanged(int dailySeed, int weeklySeed) {
          capturedDailySeed = dailySeed;
          capturedWeeklySeed = weeklySeed;
        }

        final date = DateTime.utc(2026, 2, 27);
        final refreshed = gsm.refreshRotatingQuests(
          now: date,
          onSeedsChanged: onSeedsChanged,
        );

        expect(refreshed, isTrue);
        expect(capturedDailySeed, isNotNull);
        expect(capturedWeeklySeed, isNotNull);
        // Verify the captured seeds match the expected values for the date
        // Daily seed is YYYYMMDD format
        expect(capturedDailySeed, equals(20260227));
        // Weekly seed is YYYYMMDD of the Monday of that ISO week
        // Feb 27, 2026 is a Friday, so Monday is Feb 23, 2026
        expect(capturedWeeklySeed, equals(20260223));
      });

      test('callback is NOT invoked when quests are not refreshed', () {
        final gsm = GameStateManager(resources: Resources());
        gsm.questManager = QuestManager(quests: []);

        final date = DateTime.utc(2026, 2, 27);

        // First refresh - callback should be called
        var callbackInvoked = false;
        gsm.refreshRotatingQuests(
          now: date,
          onSeedsChanged: (dailySeed, weeklySeed) => callbackInvoked = true,
        );
        expect(callbackInvoked, isTrue);

        // Second refresh with same day - callback should NOT be called
        callbackInvoked = false;
        gsm.refreshRotatingQuests(
          now: DateTime.utc(2026, 2, 27, 18, 0),
          onSeedsChanged: (dailySeed, weeklySeed) => callbackInvoked = true,
        );
        expect(callbackInvoked, isFalse);
      });

      test('callback is NOT invoked when quests are not refreshed', () {
        final gsm = GameStateManager(resources: Resources());
        gsm.questManager = QuestManager(quests: []);

        final date = DateTime.utc(2026, 2, 27);

        // First refresh - callback should be called
        var callbackInvoked = false;
        gsm.refreshRotatingQuests(
          now: date,
          onSeedsChanged: (daily, weekly) => callbackInvoked = true,
        );
        expect(callbackInvoked, isTrue);

        // Second refresh with same day - callback should NOT be called
        callbackInvoked = false;
        gsm.refreshRotatingQuests(
          now: DateTime.utc(2026, 2, 27, 18, 0),
          onSeedsChanged: (daily, weekly) => callbackInvoked = true,
        );
        expect(callbackInvoked, isFalse);
      });

      test('callback is optional - works without it', () {
        final gsm = GameStateManager(resources: Resources());
        gsm.questManager = QuestManager(quests: []);

        // Should not throw when callback is null
        expect(
          () => gsm.refreshRotatingQuests(now: DateTime.utc(2026, 2, 27)),
          returnsNormally,
        );
      });

      test('callback receives correct seeds for different dates', () {
        final gsm = GameStateManager(resources: Resources());
        gsm.questManager = QuestManager(quests: []);

        List<Map<String, int>> capturedSeeds = [];

        // First refresh
        gsm.refreshRotatingQuests(
          now: DateTime.utc(2026, 2, 27),
          onSeedsChanged: (daily, weekly) {
            capturedSeeds.add({'daily': daily, 'weekly': weekly});
          },
        );

        // Second refresh on next day
        gsm.refreshRotatingQuests(
          now: DateTime.utc(2026, 2, 28),
          onSeedsChanged: (daily, weekly) {
            capturedSeeds.add({'daily': daily, 'weekly': weekly});
          },
        );

        expect(capturedSeeds.length, equals(2));
        expect(capturedSeeds[0]['daily'], equals(20260227));
        expect(capturedSeeds[1]['daily'], equals(20260228));
        // Weekly seed should be the same (same week)
        expect(capturedSeeds[0]['weekly'], equals(capturedSeeds[1]['weekly']));
      });
    });
  });

  group('GameStateManager researchManager', () {
    test('researchManager can be replaced with a custom instance', () {
      final gsm = GameStateManager(resources: Resources());
      final customRm = ResearchManager();
      customRm.completeResearch(ResearchType.electricity);

      gsm.researchManager = customRm;

      expect(identical(gsm.researchManager, customRm), isTrue);
      expect(
        gsm.researchManager.isResearched(ResearchType.electricity),
        isTrue,
      );
    });

    test(
      'checkProgress tracks completeResearch objective using assigned researchManager',
      () {
        final rm = ResearchManager();
        rm.completeResearch(ResearchType.electricity);

        final quest = Quest(
          id: 'test_research_quest',
          name: 'Test Research',
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

        // Directly call checkProgress with gsm's researchManager (as the timer would)
        gsm.questManager!.checkProgress(gsm.resources, [], gsm.researchManager);

        // Quest completes immediately since electricity is already researched
        final completedQuests = gsm.questManager!.getCompletedQuests();
        expect(completedQuests, isNotEmpty);
        final completedQuest = completedQuests.first;
        expect(completedQuest.objectives.first.currentAmount, equals(1));
        expect(completedQuest.isComplete, isTrue);
      },
    );
  });
}
