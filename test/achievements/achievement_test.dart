import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/achievements/achievement.dart';

void main() {
  group('AchievementType', () {
    test('has all expected types', () {
      expect(
        AchievementType.values,
        containsAll([
          AchievementType.buildingCount,
          AchievementType.populationReached,
          AchievementType.resourceAccumulated,
          AchievementType.researchCompleted,
          AchievementType.happinessReached,
        ]),
      );
    });
  });

  group('Achievement', () {
    test('creates with correct initial values', () {
      final achievement = Achievement(
        id: 'ach_test',
        name: 'Test Achievement',
        description: 'A test achievement',
        type: AchievementType.buildingCount,
        targetAmount: 10,
      );

      expect(achievement.id, 'ach_test');
      expect(achievement.name, 'Test Achievement');
      expect(achievement.description, 'A test achievement');
      expect(achievement.type, AchievementType.buildingCount);
      expect(achievement.targetAmount, 10);
      expect(achievement.isUnlocked, isFalse);
    });

    test('progress returns fraction', () {
      final achievement = Achievement(
        id: 'ach_test',
        name: 'Test',
        description: 'Test',
        type: AchievementType.buildingCount,
        targetAmount: 10,
      );
      achievement.currentAmount = 5;

      expect(achievement.progress, 0.5);
    });

    test('progress clamped to 1.0', () {
      final achievement = Achievement(
        id: 'ach_test',
        name: 'Test',
        description: 'Test',
        type: AchievementType.buildingCount,
        targetAmount: 5,
      );
      achievement.currentAmount = 10;

      expect(achievement.progress, 1.0);
    });

    test('isUnlocked tracks separately from progress', () {
      final achievement = Achievement(
        id: 'ach_test',
        name: 'Test',
        description: 'Test',
        type: AchievementType.buildingCount,
        targetAmount: 5,
      );
      achievement.currentAmount = 5;

      // Not yet officially unlocked (manager does that)
      expect(achievement.isUnlocked, isFalse);

      achievement.isUnlocked = true;
      expect(achievement.isUnlocked, isTrue);
    });
  });
}
