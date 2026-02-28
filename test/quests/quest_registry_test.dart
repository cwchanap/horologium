import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/quests/quest_registry.dart';

void main() {
  group('QuestRegistry', () {
    test('has at least 10 starter quests', () {
      expect(QuestRegistry.starterQuests.length, greaterThanOrEqualTo(10));
    });

    test('all quests have unique IDs', () {
      final ids = QuestRegistry.starterQuests.map((q) => q.id).toSet();
      expect(ids.length, QuestRegistry.starterQuests.length);
    });

    test('all quests have non-empty name and description', () {
      for (final quest in QuestRegistry.starterQuests) {
        expect(
          quest.name,
          isNotEmpty,
          reason: 'Quest ${quest.id} has empty name',
        );
        expect(
          quest.description,
          isNotEmpty,
          reason: 'Quest ${quest.id} has empty description',
        );
      }
    });

    test('all quests have at least one objective', () {
      for (final quest in QuestRegistry.starterQuests) {
        expect(
          quest.objectives,
          isNotEmpty,
          reason: 'Quest ${quest.id} has no objectives',
        );
      }
    });

    test('all quest objectives have targetAmount > 0', () {
      for (final quest in QuestRegistry.starterQuests) {
        for (final obj in quest.objectives) {
          expect(
            obj.targetAmount,
            greaterThan(0),
            reason: 'Quest ${quest.id} has objective with targetAmount <= 0',
          );
        }
      }
    });

    test('prerequisite IDs reference existing quests', () {
      final allIds = QuestRegistry.starterQuests.map((q) => q.id).toSet();
      for (final quest in QuestRegistry.starterQuests) {
        for (final prereqId in quest.prerequisiteQuestIds) {
          expect(
            allIds.contains(prereqId),
            isTrue,
            reason:
                'Quest ${quest.id} references unknown prerequisite $prereqId',
          );
        }
      }
    });

    test('no quest lists itself as prerequisite', () {
      for (final quest in QuestRegistry.starterQuests) {
        expect(
          quest.prerequisiteQuestIds.contains(quest.id),
          isFalse,
          reason: 'Quest ${quest.id} lists itself as prerequisite',
        );
      }
    });

    test('no circular prerequisite chains exist', () {
      final questMap = {for (final q in QuestRegistry.starterQuests) q.id: q};

      bool hasCircularDependency(String startId) {
        final visited = <String>{};
        final visiting = <String>{};

        bool dfs(String id) {
          if (visiting.contains(id)) return true; // Found a cycle
          if (visited.contains(id)) return false; // Already fully explored

          visiting.add(id);
          final quest = questMap[id];
          if (quest != null) {
            for (final prereqId in quest.prerequisiteQuestIds) {
              if (dfs(prereqId)) return true;
            }
          }
          visiting.remove(id);
          visited.add(id);
          return false;
        }

        return dfs(startId);
      }

      for (final quest in QuestRegistry.starterQuests) {
        expect(
          hasCircularDependency(quest.id),
          isFalse,
          reason: 'Quest ${quest.id} has a circular prerequisite chain',
        );
      }
    });
  });
}
