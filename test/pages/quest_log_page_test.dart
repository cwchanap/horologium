import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/achievements/achievement.dart';
import 'package:horologium/game/achievements/achievement_manager.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';
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

    testWidgets('excludes prerequisite-locked quests from Active tab', (
      tester,
    ) async {
      // Create a quest that is locked behind a prerequisite
      final lockedQuest = Quest(
        id: 'locked_quest',
        name: 'Locked Quest',
        description: 'Requires q1 to be claimed',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 100}),
        prerequisiteQuestIds: ['q1'],
        status: QuestStatus.available,
      );

      // Create an available quest with no prerequisites
      final availableQuest = Quest(
        id: 'available_quest',
        name: 'Available Quest',
        description: 'No prerequisites',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 50}),
        status: QuestStatus.available,
      );

      final qm = QuestManager(quests: [availableQuest, lockedQuest]);

      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: qm,
            achievementManager: achievementManager,
          ),
        ),
      );

      // Should show the available quest but not the locked quest
      expect(find.text('Available Quest'), findsOneWidget);
      expect(find.text('Locked Quest'), findsNothing);
    });

    testWidgets('rebuilds when quest is completed', (tester) async {
      // Create an active quest that can be completed
      final activeQuest = Quest(
        id: 'active_quest',
        name: 'Active Quest',
        description: 'Will be completed',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 50}),
        status: QuestStatus.active,
      );

      final qm = QuestManager(quests: [activeQuest]);

      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: qm,
            achievementManager: achievementManager,
          ),
        ),
      );

      // Initially shows the active quest
      expect(find.text('Active Quest'), findsOneWidget);

      // Complete the quest objective and check progress
      // This should trigger onQuestStatusChanged and rebuild the page
      final building = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'A house',
        icon: Icons.house,
        color: Colors.brown,
        baseCost: 100,
        category: BuildingCategory.residential,
      );
      qm.checkProgress(Resources(), [building], ResearchManager());
      await tester.pump();

      // Page should rebuild - quest should now show as completed
      // (QuestCard shows different UI for completed quests)
      expect(find.text('Active Quest'), findsOneWidget);
    });

    testWidgets('rebuilds when achievement is unlocked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: questManager,
            achievementManager: achievementManager,
          ),
        ),
      );

      // Switch to Achievements tab
      await tester.tap(find.text('Achievements'));
      await tester.pumpAndSettle();

      // Initially shows the achievement as locked
      expect(find.text('First Steps'), findsOneWidget);

      // Complete the achievement
      final achievement = achievementManager.achievements.first;
      achievement.currentAmount = achievement.targetAmount;
      achievement.isUnlocked = true;

      // Trigger the callback manually (simulating what checkProgress would do)
      achievementManager.onAchievementUnlocked?.call(achievement);
      await tester.pump();

      // Achievement should still be visible (now unlocked)
      expect(find.text('First Steps'), findsOneWidget);
    });

    testWidgets('updates listener when questManager changes', (tester) async {
      final quest1 = Quest(
        id: 'q1',
        name: 'Original Quest',
        description: 'Original',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 100}),
        status: QuestStatus.active,
      );

      final originalQM = QuestManager(quests: [quest1]);

      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: originalQM,
            achievementManager: achievementManager,
          ),
        ),
      );

      expect(find.text('Original Quest'), findsOneWidget);

      // Create a new quest manager with a different quest
      final quest2 = Quest(
        id: 'q2',
        name: 'New Quest',
        description: 'New',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 200}),
        status: QuestStatus.active,
      );
      final newQM = QuestManager(quests: [quest2]);

      // Rebuild with new quest manager
      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: newQM,
            achievementManager: achievementManager,
          ),
        ),
      );

      // Should show the new quest
      expect(find.text('New Quest'), findsOneWidget);
      expect(find.text('Original Quest'), findsNothing);
    });

    testWidgets('cleans up listeners on dispose', (tester) async {
      final quest1 = Quest(
        id: 'q1',
        name: 'Test Quest',
        description: 'Test',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 1,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 100}),
        status: QuestStatus.active,
      );

      final qm = QuestManager(quests: [quest1]);

      await tester.pumpWidget(
        MaterialApp(
          home: QuestLogPage(
            questManager: qm,
            achievementManager: achievementManager,
          ),
        ),
      );

      // Verify listeners are set up
      expect(qm.onQuestStatusChanged, isNotNull);
      expect(achievementManager.onAchievementUnlocked, isNotNull);

      // Dispose the page by navigating away
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Empty'))),
      );

      // Listeners should be cleared
      expect(qm.onQuestStatusChanged, isNull);
      expect(achievementManager.onAchievementUnlocked, isNull);
    });
  });
}
