import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/widgets/cards/quest_card.dart';

void main() {
  group('QuestCard', () {
    late Quest quest;

    setUp(() {
      quest = Quest(
        id: 'test_quest',
        name: 'Build Houses',
        description: 'Build 2 houses to shelter citizens',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 2,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 500}),
        status: QuestStatus.active,
      );
    });

    testWidgets('displays quest name and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuestCard(quest: quest)),
        ),
      );

      expect(find.text('Build Houses'), findsOneWidget);
      expect(find.text('Build 2 houses to shelter citizens'), findsOneWidget);
    });

    testWidgets('shows objective progress text', (tester) async {
      quest.objectives[0].currentAmount = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuestCard(quest: quest)),
        ),
      );

      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('shows claim button when completed', (tester) async {
      quest.status = QuestStatus.completed;
      quest.objectives[0].currentAmount = 2;
      bool claimed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestCard(quest: quest, onClaim: () => claimed = true),
          ),
        ),
      );

      expect(find.text('Claim Reward'), findsOneWidget);

      await tester.tap(find.text('Claim Reward'));
      expect(claimed, isTrue);
    });

    testWidgets('does not show claim button when active', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuestCard(quest: quest)),
        ),
      );

      expect(find.text('Claim Reward'), findsNothing);
    });

    testWidgets('shows reward preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuestCard(quest: quest)),
        ),
      );

      expect(find.text('500'), findsOneWidget);
    });
  });
}
