import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/quests/daily_quest_generator.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_objective.dart';

void main() {
  group('DailyQuestGenerator', () {
    test('generates daily quests from seed', () {
      final quests = DailyQuestGenerator.generateDaily(seed: 42);
      expect(quests, isNotEmpty);
      expect(quests.length, equals(DailyQuestGenerator.dailyQuestCount));
      for (final q in quests) {
        expect(q.id, startsWith('daily_'));
        expect(q.status, equals(QuestStatus.available));
        expect(q.objectives, isNotEmpty);
      }
    });

    test('same seed produces same quests', () {
      final quests1 = DailyQuestGenerator.generateDaily(seed: 123);
      final quests2 = DailyQuestGenerator.generateDaily(seed: 123);
      expect(quests1.length, equals(quests2.length));
      for (int i = 0; i < quests1.length; i++) {
        expect(quests1[i].id, equals(quests2[i].id));
        expect(quests1[i].name, equals(quests2[i].name));
      }
    });

    test('different seeds produce different quests', () {
      final quests1 = DailyQuestGenerator.generateDaily(seed: 1);
      final quests2 = DailyQuestGenerator.generateDaily(seed: 2);
      // At least one quest should differ (extremely unlikely to be identical)
      final ids1 = quests1.map((q) => q.id).toSet();
      final ids2 = quests2.map((q) => q.id).toSet();
      expect(ids1, isNot(equals(ids2)));
    });

    test('generates weekly quests from seed', () {
      final quests = DailyQuestGenerator.generateWeekly(seed: 42);
      expect(quests, isNotEmpty);
      expect(quests.length, equals(DailyQuestGenerator.weeklyQuestCount));
      for (final q in quests) {
        expect(q.id, startsWith('weekly_'));
      }
    });

    test('weekly quests have higher targets than daily', () {
      // Test across several seeds to verify on average weekly > daily
      double totalDailyAvg = 0;
      double totalWeeklyAvg = 0;
      const trials = 10;

      for (int seed = 0; seed < trials; seed++) {
        final daily = DailyQuestGenerator.generateDaily(seed: seed);
        final weekly = DailyQuestGenerator.generateWeekly(seed: seed);

        double dailySum = 0;
        int dailyCount = 0;
        for (final q in daily) {
          for (final o in q.objectives) {
            dailySum += o.targetAmount;
            dailyCount++;
          }
        }

        double weeklySum = 0;
        int weeklyCount = 0;
        for (final q in weekly) {
          for (final o in q.objectives) {
            weeklySum += o.targetAmount;
            weeklyCount++;
          }
        }

        totalDailyAvg += dailySum / dailyCount;
        totalWeeklyAvg += weeklySum / weeklyCount;
      }

      expect(totalWeeklyAvg / trials, greaterThan(totalDailyAvg / trials));
    });

    test('dailySeedForDate produces consistent seeds per day', () {
      final date1 = DateTime(2026, 2, 27);
      final date2 = DateTime(2026, 2, 27, 14, 30); // same day, different time
      final date3 = DateTime(2026, 2, 28);

      expect(
        DailyQuestGenerator.dailySeedForDate(date1),
        equals(DailyQuestGenerator.dailySeedForDate(date2)),
      );
      expect(
        DailyQuestGenerator.dailySeedForDate(date1),
        isNot(equals(DailyQuestGenerator.dailySeedForDate(date3))),
      );
    });

    test('weeklySeedForDate produces consistent seeds per week', () {
      // Monday and Sunday of the same week (ISO week: Mon-Sun)
      final monday = DateTime(2026, 2, 23); // a Monday
      final wednesday = DateTime(2026, 2, 25); // same week
      final nextMonday = DateTime(2026, 3, 2); // next week

      expect(
        DailyQuestGenerator.weeklySeedForDate(monday),
        equals(DailyQuestGenerator.weeklySeedForDate(wednesday)),
      );
      expect(
        DailyQuestGenerator.weeklySeedForDate(monday),
        isNot(equals(DailyQuestGenerator.weeklySeedForDate(nextMonday))),
      );
    });

    test('quest rewards scale with difficulty', () {
      final daily = DailyQuestGenerator.generateDaily(seed: 42);
      final weekly = DailyQuestGenerator.generateWeekly(seed: 42);

      double dailyRewardSum = 0;
      for (final q in daily) {
        for (final v in q.reward.resources.values) {
          dailyRewardSum += v;
        }
      }

      double weeklyRewardSum = 0;
      for (final q in weekly) {
        for (final v in q.reward.resources.values) {
          weeklyRewardSum += v;
        }
      }

      // Weekly total rewards should exceed daily
      expect(weeklyRewardSum, greaterThan(dailyRewardSum));
    });

    test('all generated objectives have valid types', () {
      // Test across many seeds
      for (int seed = 0; seed < 20; seed++) {
        final quests = DailyQuestGenerator.generateDaily(seed: seed);
        for (final q in quests) {
          for (final o in q.objectives) {
            expect(
              QuestObjectiveType.values.contains(o.type),
              isTrue,
              reason: 'Seed $seed produced invalid objective type',
            );
            expect(o.targetAmount, greaterThan(0));
          }
        }
      }
    });
  });
}
