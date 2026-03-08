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
    test('rotating quest definitions are saved and restored directly', () {
      // With rotatingQuestDefinitions, quest definitions are saved directly
      // and restored without needing pre-population or regeneration.
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

      // Verify rotatingQuestDefinitions is included in saved JSON
      expect(
        savedJson.containsKey('rotatingQuestDefinitions'),
        isTrue,
        reason: 'toJson should include rotatingQuestDefinitions',
      );

      // --- Load side (no pre-population needed with rotatingQuestDefinitions) ---
      final loadManager = QuestManager(quests: []);
      // Don't pre-populate - definitions come from rotatingQuestDefinitions
      loadManager.loadFromJson(savedJson);
      expect(
        loadManager.getCompletedQuests().any((q) => q.id == firstId),
        isTrue,
        reason:
            'With rotatingQuestDefinitions, completed rotating quest is restored',
      );
    });
    test(
      'rotating quest state survives save-load when pre-populated (legacy compatibility)',
      () {
        // This test verifies backward compatibility when rotatingQuestDefinitions is NOT present
        // (i.e., old save format). In that case, pre-population is still needed.
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
        // Simulate old save format by removing rotatingQuestDefinitions
        savedJson.remove('rotatingQuestDefinitions');

        // --- Load side (old format: no rotatingQuestDefinitions) ---
        // Without rotatingQuestDefinitions, need to pre-populate for IDs to match
        final loadManager = QuestManager(quests: []);
        loadManager.addRotatingQuests(
          DailyQuestGenerator.generateDaily(seed: seed),
        );
        loadManager.loadFromJson(savedJson);
        expect(
          loadManager.getCompletedQuests().any((q) => q.id == firstId),
          isTrue,
          reason:
              'With pre-population, completed rotating quest is restored (legacy format)',
        );
      },
    );
  });
}
