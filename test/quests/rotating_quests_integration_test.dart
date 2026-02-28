import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/quests/daily_quest_generator.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';

void main() {
  group('QuestManager rotating quests', () {
    test('addRotatingQuests adds generated quests', () {
      final manager = QuestManager(quests: []);
      final daily = DailyQuestGenerator.generateDaily(seed: 42);
      manager.addRotatingQuests(daily);

      expect(manager.quests.length, equals(daily.length));
      for (final q in daily) {
        expect(
          manager.quests.any((mq) => mq.id == q.id),
          isTrue,
          reason: 'Quest ${q.id} should be in manager',
        );
      }
    });

    test('removeRotatingQuests removes by prefix', () {
      final manager = QuestManager(quests: []);
      final daily = DailyQuestGenerator.generateDaily(seed: 42);
      final weekly = DailyQuestGenerator.generateWeekly(seed: 42);
      manager.addRotatingQuests(daily);
      manager.addRotatingQuests(weekly);

      final totalBefore = manager.quests.length;
      expect(totalBefore, equals(daily.length + weekly.length));

      manager.removeRotatingQuests('daily_');
      expect(manager.quests.length, equals(weekly.length));
      expect(manager.quests.every((q) => q.id.startsWith('weekly_')), isTrue);
    });

    test('refreshDailyQuests replaces old daily with new', () {
      final manager = QuestManager(quests: []);
      final day1 = DailyQuestGenerator.generateDaily(seed: 100);
      manager.addRotatingQuests(day1);

      final oldIds = manager.quests.map((q) => q.id).toSet();

      manager.removeRotatingQuests('daily_');
      final day2 = DailyQuestGenerator.generateDaily(seed: 200);
      manager.addRotatingQuests(day2);

      final newIds = manager.quests.map((q) => q.id).toSet();
      expect(oldIds.intersection(newIds), isEmpty);
    });

    test('static quests are not removed by removeRotatingQuests', () {
      final staticQuest = Quest(
        id: 'quest_welcome',
        name: 'Welcome',
        description: 'A static quest',
        objectives: [],
        reward: const QuestReward(),
      );
      final manager = QuestManager(quests: [staticQuest]);
      final daily = DailyQuestGenerator.generateDaily(seed: 42);
      manager.addRotatingQuests(daily);

      manager.removeRotatingQuests('daily_');
      expect(manager.quests.length, equals(1));
      expect(manager.quests.first.id, equals('quest_welcome'));
    });

    test('claimed rotating quests are preserved during removal', () {
      final manager = QuestManager(quests: []);
      final daily = DailyQuestGenerator.generateDaily(seed: 42);
      manager.addRotatingQuests(daily);

      // Claim the first daily quest
      final firstId = daily.first.id;
      manager.activateQuest(firstId);
      // Simulate completion
      final q = manager.quests.firstWhere((q) => q.id == firstId);
      q.status = QuestStatus.claimed;

      // Removing should skip claimed quests
      manager.removeRotatingQuests('daily_', preserveClaimed: true);
      expect(
        manager.quests.any((q) => q.id == firstId),
        isTrue,
        reason: 'Claimed rotating quest should be preserved',
      );
    });
    test('rotating quest state survives save-load when pre-populated', () {
      // Simulate SaveService.loadPlanet: pre-populate rotating quests BEFORE
      // calling loadFromJson so saved daily/weekly states are not dropped.
      final seed = 42;
      final daily = DailyQuestGenerator.generateDaily(seed: seed);

      // --- Save side ---
      final saveSideManager = QuestManager(quests: []);
      saveSideManager.addRotatingQuests(daily);
      final firstId = daily.first.id;
      saveSideManager.activateQuest(firstId);
      final q = saveSideManager.quests.firstWhere((q) => q.id == firstId);
      q.status = QuestStatus.completed;

      final savedJson = saveSideManager.toJson();

      // --- Load side (mimics old broken behavior: no rotating quests before load) ---
      final brokenManager = QuestManager(quests: []);
      brokenManager.loadFromJson(savedJson);
      expect(
        brokenManager.getCompletedQuests().any((q) => q.id == firstId),
        isFalse,
        reason: 'Without pre-population the saved state is silently dropped',
      );

      // --- Load side (new correct behavior: add rotating quests BEFORE load) ---
      final fixedManager = QuestManager(quests: []);
      fixedManager.addRotatingQuests(
        DailyQuestGenerator.generateDaily(seed: seed),
      );
      fixedManager.loadFromJson(savedJson);
      expect(
        fixedManager.getCompletedQuests().any((q) => q.id == firstId),
        isTrue,
        reason: 'With pre-population the completed rotating quest is restored',
      );
    });
  });
}
