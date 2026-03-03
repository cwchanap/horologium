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
