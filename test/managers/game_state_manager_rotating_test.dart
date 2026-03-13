import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/managers/game_state_manager.dart';
import 'package:horologium/game/quests/daily_quest_generator.dart';
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

  group('GameStateManager seed recovery', () {
    test(
      'recoverSeedsFromExistingQuests extracts seeds from rotating quest IDs',
      () {
        final gsm = GameStateManager(resources: Resources());
        final questManager = QuestManager(quests: []);
        gsm.questManager = questManager;

        // Use Jan 15, 2024 (which is a Monday - same day for daily and weekly)
        final testDate = DateTime.utc(2024, 1, 15);
        final dailySeed = DailyQuestGenerator.dailySeedForDate(testDate);
        final weeklySeed = DailyQuestGenerator.weeklySeedForDate(testDate);

        final daily = DailyQuestGenerator.generateDaily(seed: dailySeed);
        final weekly = DailyQuestGenerator.generateWeekly(seed: weeklySeed);
        questManager.addRotatingQuests(daily);
        questManager.addRotatingQuests(weekly);

        // Initialize with seeds of 0 (simulating old save)
        gsm.initializeSeedsFromLoadedData(0, 0);
        expect(
          gsm.refreshRotatingQuests(now: testDate),
          isTrue,
          reason: 'Should refresh with seed 0',
        );

        // Reset to simulate fresh load
        final gsm2 = GameStateManager(resources: Resources());
        final questManager2 = QuestManager(quests: []);
        gsm2.questManager = questManager2;
        questManager2.addRotatingQuests(daily);
        questManager2.addRotatingQuests(weekly);

        // Initialize with seeds of 0, but then recover
        gsm2.initializeSeedsFromLoadedData(0, 0);
        gsm2.recoverSeedsFromExistingQuests();

        // Now refresh should not trigger (seeds match current date)
        expect(
          gsm2.refreshRotatingQuests(now: testDate),
          isFalse,
          reason: 'Should not refresh after recovering seeds from quests',
        );
      },
    );

    test('recoverSeedsFromExistingQuests does not overwrite non-zero seeds', () {
      final gsm = GameStateManager(resources: Resources());
      final questManager = QuestManager(quests: []);
      gsm.questManager = questManager;

      // Add quests with today's seed
      final testDate = DateTime.utc(2024, 1, 15);
      final dailySeed = DailyQuestGenerator.dailySeedForDate(testDate);
      final daily = DailyQuestGenerator.generateDaily(seed: dailySeed);
      questManager.addRotatingQuests(daily);

      // Initialize with different non-zero seed
      final existingSeed = 20240114; // Yesterday
      gsm.initializeSeedsFromLoadedData(existingSeed, 0);

      // Recover should not change the existing seed
      gsm.recoverSeedsFromExistingQuests();

      // Refresh should still happen because existing seed differs from today's
      expect(
        gsm.refreshRotatingQuests(now: testDate),
        isTrue,
        reason: 'Should refresh because existing seed differs from today',
      );
    });

    test(
      'recoverSeedsFromExistingQuests handles mixed seed recovery correctly',
      () {
        final gsm = GameStateManager(resources: Resources());
        final questManager = QuestManager(quests: []);
        gsm.questManager = questManager;

        final testDate = DateTime.utc(2024, 1, 15);
        final dailySeed = DailyQuestGenerator.dailySeedForDate(testDate);

        // Add only daily quests (no weekly)
        final daily = DailyQuestGenerator.generateDaily(seed: dailySeed);
        questManager.addRotatingQuests(daily);

        // Initialize with seeds of 0
        gsm.initializeSeedsFromLoadedData(0, 0);
        gsm.recoverSeedsFromExistingQuests();

        // Daily seed should be recovered, weekly should stay 0
        // So only daily should not refresh, weekly should refresh
        final result = gsm.refreshRotatingQuests(now: testDate);
        // We added daily quests with today's seed, so daily should NOT refresh
        // But weekly (seed 0) != today's weekly seed, so it SHOULD refresh
        expect(result, isTrue);
      },
    );
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

  group('GameStateManager resource generation', () {
    test(
      'startResourceGeneration is idempotent and marks timer ticks',
      () async {
        final gsm = GameStateManager(resources: Resources());
        int updateCalls = 0;
        final timerFlags = <bool>[];

        void onUpdate([bool isTimerTick = false]) {
          updateCalls++;
          timerFlags.add(isTimerTick);
        }

        gsm.startResourceGeneration(() => const [], onUpdate);
        gsm.startResourceGeneration(() => const [], onUpdate);

        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(updateCalls, 1);
        expect(timerFlags, equals([true]));

        gsm.stopResourceGeneration();
        await Future<void>.delayed(const Duration(milliseconds: 1200));

        expect(updateCalls, 1);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });
}
