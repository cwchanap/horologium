import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/quests/quest_objective.dart';

void main() {
  group('QuestObjectiveType', () {
    test('has all expected types', () {
      expect(
        QuestObjectiveType.values,
        containsAll([
          QuestObjectiveType.buildBuilding,
          QuestObjectiveType.accumulateResource,
          QuestObjectiveType.completeResearch,
          QuestObjectiveType.reachPopulation,
          QuestObjectiveType.achieveHappiness,
          QuestObjectiveType.upgradeBuilding,
        ]),
      );
    });
  });

  group('QuestObjective', () {
    test('creates with correct initial values', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.buildBuilding,
        targetId: 'house',
        targetAmount: 3,
      );

      expect(objective.type, QuestObjectiveType.buildBuilding);
      expect(objective.targetId, 'house');
      expect(objective.targetAmount, 3);
      expect(objective.currentAmount, 0);
    });

    test('isComplete returns false when currentAmount < targetAmount', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.accumulateResource,
        targetId: 'gold',
        targetAmount: 100,
      );
      objective.currentAmount = 50;

      expect(objective.isComplete, isFalse);
    });

    test('isComplete returns true when currentAmount == targetAmount', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.accumulateResource,
        targetId: 'gold',
        targetAmount: 100,
      );
      objective.currentAmount = 100;

      expect(objective.isComplete, isTrue);
    });

    test('isComplete returns true when currentAmount > targetAmount', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.accumulateResource,
        targetId: 'gold',
        targetAmount: 100,
      );
      objective.currentAmount = 150;

      expect(objective.isComplete, isTrue);
    });

    test('progress returns fraction of completion', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.buildBuilding,
        targetId: 'house',
        targetAmount: 4,
      );
      objective.currentAmount = 1;

      expect(objective.progress, 0.25);
    });

    test('progress is clamped to 1.0 when overachieved', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.buildBuilding,
        targetId: 'house',
        targetAmount: 2,
      );
      objective.currentAmount = 5;

      expect(objective.progress, 1.0);
    });

    test('progress is 0.0 when targetAmount is 0', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.buildBuilding,
        targetId: 'house',
        targetAmount: 0,
      );

      expect(objective.progress, 1.0);
    });

    test('description returns human-readable text for buildBuilding', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.buildBuilding,
        targetId: 'house',
        targetAmount: 3,
      );

      expect(objective.description, contains('Build'));
      expect(objective.description, contains('3'));
      expect(objective.description, contains('house'));
    });

    test('description returns human-readable text for accumulateResource', () {
      final objective = QuestObjective(
        type: QuestObjectiveType.accumulateResource,
        targetId: 'gold',
        targetAmount: 100,
      );

      expect(objective.description, contains('Accumulate'));
      expect(objective.description, contains('100'));
      expect(objective.description, contains('gold'));
    });

    test('toJson and fromJson round-trip', () {
      final original = QuestObjective(
        type: QuestObjectiveType.completeResearch,
        targetId: 'electricity',
        targetAmount: 1,
      );
      original.currentAmount = 1;

      final json = original.toJson();
      final restored = QuestObjective.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.targetId, original.targetId);
      expect(restored.targetAmount, original.targetAmount);
      expect(restored.currentAmount, original.currentAmount);
    });
  });
}
