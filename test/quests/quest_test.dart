import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/resources/resource_type.dart';

void main() {
  group('QuestStatus', () {
    test('has all expected values', () {
      expect(
        QuestStatus.values,
        containsAll([
          QuestStatus.available,
          QuestStatus.active,
          QuestStatus.completed,
          QuestStatus.claimed,
        ]),
      );
    });
  });

  group('QuestReward', () {
    test('creates with resource rewards', () {
      final reward = QuestReward(
        resources: {ResourceType.cash: 500, ResourceType.gold: 50},
      );

      expect(reward.resources[ResourceType.cash], 500);
      expect(reward.resources[ResourceType.gold], 50);
      expect(reward.researchPoints, 0);
    });

    test('creates with research points', () {
      final reward = QuestReward(researchPoints: 10);

      expect(reward.resources, isEmpty);
      expect(reward.researchPoints, 10);
    });

    test('toJson and fromJson round-trip', () {
      final original = QuestReward(
        resources: {ResourceType.cash: 200, ResourceType.wood: 100},
        researchPoints: 5,
      );

      final json = original.toJson();
      final restored = QuestReward.fromJson(json);

      expect(restored.resources[ResourceType.cash], 200);
      expect(restored.resources[ResourceType.wood], 100);
      expect(restored.researchPoints, 5);
    });
  });

  group('Quest', () {
    late Quest quest;

    setUp(() {
      quest = Quest(
        id: 'test_quest',
        name: 'Test Quest',
        description: 'A test quest',
        objectives: [
          QuestObjective(
            type: QuestObjectiveType.buildBuilding,
            targetId: 'house',
            targetAmount: 2,
          ),
          QuestObjective(
            type: QuestObjectiveType.accumulateResource,
            targetId: 'cash',
            targetAmount: 500,
          ),
        ],
        reward: QuestReward(resources: {ResourceType.cash: 1000}),
      );
    });

    test('creates with correct initial values', () {
      expect(quest.id, 'test_quest');
      expect(quest.name, 'Test Quest');
      expect(quest.description, 'A test quest');
      expect(quest.objectives, hasLength(2));
      expect(quest.prerequisiteQuestIds, isEmpty);
      expect(quest.status, QuestStatus.available);
    });

    test('isComplete returns false when not all objectives met', () {
      quest.objectives[0].currentAmount = 2;
      quest.objectives[1].currentAmount = 100;

      expect(quest.isComplete, isFalse);
    });

    test('isComplete returns true when all objectives met', () {
      quest.objectives[0].currentAmount = 2;
      quest.objectives[1].currentAmount = 500;

      expect(quest.isComplete, isTrue);
    });

    test('progress returns average of objective progress', () {
      quest.objectives[0].currentAmount = 1; // 50%
      quest.objectives[1].currentAmount = 250; // 50%

      expect(quest.progress, closeTo(0.5, 0.01));
    });

    test('progress is 1.0 with no objectives', () {
      final emptyQuest = Quest(
        id: 'empty',
        name: 'Empty',
        description: 'No objectives',
        objectives: [],
        reward: QuestReward(),
      );

      expect(emptyQuest.progress, 1.0);
    });

    test('supports prerequisite quest IDs', () {
      final chainedQuest = Quest(
        id: 'chained',
        name: 'Chained Quest',
        description: 'Requires another quest',
        objectives: [],
        reward: QuestReward(),
        prerequisiteQuestIds: ['test_quest', 'other_quest'],
      );

      expect(chainedQuest.prerequisiteQuestIds, ['test_quest', 'other_quest']);
    });

    test('status can be changed', () {
      expect(quest.status, QuestStatus.available);
      quest.status = QuestStatus.active;
      expect(quest.status, QuestStatus.active);
      quest.status = QuestStatus.completed;
      expect(quest.status, QuestStatus.completed);
      quest.status = QuestStatus.claimed;
      expect(quest.status, QuestStatus.claimed);
    });

    test('toJson and fromJson round-trip', () {
      quest.status = QuestStatus.active;
      quest.objectives[0].currentAmount = 1;
      quest.objectives[1].currentAmount = 300;

      final json = quest.toJson();
      final restored = Quest.fromJson(json);

      expect(restored.id, quest.id);
      expect(restored.name, quest.name);
      expect(restored.description, quest.description);
      expect(restored.objectives, hasLength(2));
      expect(restored.objectives[0].currentAmount, 1);
      expect(restored.objectives[1].currentAmount, 300);
      expect(restored.status, QuestStatus.active);
      expect(restored.reward.resources[ResourceType.cash], 1000);
    });

    test('fromJson with prerequisiteQuestIds', () {
      final chainedQuest = Quest(
        id: 'chained',
        name: 'Chained',
        description: 'Chained quest',
        objectives: [],
        reward: QuestReward(),
        prerequisiteQuestIds: ['prereq1'],
      );

      final json = chainedQuest.toJson();
      final restored = Quest.fromJson(json);

      expect(restored.prerequisiteQuestIds, ['prereq1']);
    });
  });
}
