import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/achievements/achievement.dart';
import 'package:horologium/game/achievements/achievement_manager.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/pages/quest_log_page.dart';

void main() {
  group('QuestLogPage', () {
    late QuestManager questManager;
    late AchievementManager achievementManager;

    setUp(() {
      final quest1 = Quest(
        id: 'q1',
        name: 'Active Quest',
        description: 'An active quest',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 2,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 100}),
        status: QuestStatus.active,
      );

      final quest2 = Quest(
        id: 'q2',
        name: 'Claimed Quest',
        description: 'A claimed quest',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'mine',
            targetAmount: 1,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.gold: 50}),
        status: QuestStatus.claimed,
      );

      questManager = QuestManager(quests: [quest1, quest2]);

      achievementManager = AchievementManager(
        achievements: [
          Achievement(
            id: 'a1',
            name: 'First Steps',
            description: 'Build your first building',
            type: AchievementType.buildingCount,
            targetAmount: 1,
          ),
        ],
      );
    });

    testWidgets('shows Active tab by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: questManager,
            achievementManager: achievementManager,
          ),
        ),
      );

      expect(find.text('Active Quest'), findsOneWidget);
      expect(find.text('Claimed Quest'), findsNothing);
    });

    testWidgets('can switch to Claimed tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: questManager,
            achievementManager: achievementManager,
          ),
        ),
      );

      await tester.tap(find.text('Claimed'));
      await tester.pumpAndSettle();

      expect(find.text('Claimed Quest'), findsOneWidget);
      expect(find.text('Active Quest'), findsNothing);
    });

    testWidgets('can switch to Achievements tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: questManager,
            achievementManager: achievementManager,
          ),
        ),
      );

      await tester.tap(find.text('Achievements'));
      await tester.pumpAndSettle();

      expect(find.text('First Steps'), findsOneWidget);
    });

    testWidgets('shows empty state when no active quests', (tester) async {
      final emptyQM = QuestManager(quests: []);
      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: emptyQM,
            achievementManager: achievementManager,
          ),
        ),
      );

      expect(find.text('No active quests'), findsOneWidget);
    });
  });
}
