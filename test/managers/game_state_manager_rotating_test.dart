import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/managers/game_state_manager.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_registry.dart';
import 'package:horologium/game/resources/resources.dart';

void main() {
  group('GameStateManager rotating quests', () {
    test('refreshRotatingQuests adds daily and weekly quests', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.questManager = QuestManager(quests: QuestRegistry.starterQuests);

      final date = DateTime(2026, 2, 27);
      final refreshed = gsm.refreshRotatingQuests(now: date);

      expect(refreshed, isTrue);
      final allQuests = gsm.questManager!.quests;
      expect(allQuests.any((q) => q.id.startsWith('daily_')), isTrue);
      expect(allQuests.any((q) => q.id.startsWith('weekly_')), isTrue);
    });

    test('does not refresh if same day', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.questManager = QuestManager(quests: []);

      final date = DateTime(2026, 2, 27);
      gsm.refreshRotatingQuests(now: date);
      final count1 = gsm.questManager!.quests.length;

      // Same day, different time
      final refreshed = gsm.refreshRotatingQuests(
        now: DateTime(2026, 2, 27, 18, 0),
      );
      expect(refreshed, isFalse);
      expect(gsm.questManager!.quests.length, equals(count1));
    });

    test('refreshes when day changes', () {
      final gsm = GameStateManager(resources: Resources());
      gsm.questManager = QuestManager(quests: []);

      gsm.refreshRotatingQuests(now: DateTime(2026, 2, 27));
      final ids1 = gsm.questManager!.quests
          .where((q) => q.id.startsWith('daily_'))
          .map((q) => q.id)
          .toSet();

      gsm.refreshRotatingQuests(now: DateTime(2026, 2, 28));
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
}
