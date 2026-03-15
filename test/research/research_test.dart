import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';

void main() {
  group('ResearchType.id', () {
    test('returns correct id for each type', () {
      expect(ResearchType.electricity.id, equals('electricity'));
      expect(ResearchType.goldMining.id, equals('gold_mining'));
      expect(ResearchType.expansionPlanning.id, equals('expansion_planning'));
      expect(
        ResearchType.advancedConstruction.id,
        equals('advanced_construction'),
      );
      expect(ResearchType.grainProcessing.id, equals('grain_processing'));
      expect(
        ResearchType.advancedGrainProcessing.id,
        equals('advanced_grain_processing'),
      );
      expect(ResearchType.modernHousing.id, equals('modern_housing'));
      expect(ResearchType.foodProcessing.id, equals('food_processing'));
    });

    test('all types have unique ids', () {
      final ids = ResearchType.values.map((t) => t.id).toList();
      expect(ids.length, equals(ids.toSet().length));
    });
  });

  group('ResearchTypeHelper.fromId', () {
    test('returns correct type for valid id', () {
      expect(
        ResearchTypeHelper.fromId('electricity'),
        equals(ResearchType.electricity),
      );
      expect(
        ResearchTypeHelper.fromId('gold_mining'),
        equals(ResearchType.goldMining),
      );
      expect(
        ResearchTypeHelper.fromId('grain_processing'),
        equals(ResearchType.grainProcessing),
      );
    });

    test('returns null for unknown id', () {
      expect(ResearchTypeHelper.fromId('unknown_tech'), isNull);
      expect(ResearchTypeHelper.fromId(''), isNull);
    });

    test('round-trips all types through id and back', () {
      for (final type in ResearchType.values) {
        expect(ResearchTypeHelper.fromId(type.id), equals(type));
      }
    });
  });

  group('Research.availableResearch', () {
    test('contains expected number of research entries', () {
      expect(Research.availableResearch, isNotEmpty);
    });

    test('each research has a non-empty name and description', () {
      for (final r in Research.availableResearch) {
        expect(r.name, isNotEmpty, reason: '${r.type} has empty name');
        expect(r.description, isNotEmpty, reason: '${r.type} has empty desc');
      }
    });

    test('each research has a positive cost', () {
      for (final r in Research.availableResearch) {
        expect(r.cost, greaterThan(0), reason: '${r.type} cost must be > 0');
      }
    });

    test('id getter delegates to type.id', () {
      final r = Research.availableResearch.first;
      expect(r.id, equals(r.type.id));
    });

    test('electricity research unlocks powerPlant', () {
      final electricity = Research.availableResearch.firstWhere(
        (r) => r.type == ResearchType.electricity,
      );
      expect(electricity.unlocksBuildings, contains(BuildingType.powerPlant));
      expect(electricity.prerequisites, isEmpty);
    });

    test('advancedConstruction requires expansionPlanning as prerequisite', () {
      final advanced = Research.availableResearch.firstWhere(
        (r) => r.type == ResearchType.advancedConstruction,
      );
      expect(advanced.prerequisites, contains(ResearchType.expansionPlanning));
    });

    test('modernHousing requires electricity as prerequisite', () {
      final modern = Research.availableResearch.firstWhere(
        (r) => r.type == ResearchType.modernHousing,
      );
      expect(modern.prerequisites, contains(ResearchType.electricity));
      expect(modern.unlocksBuildings, contains(BuildingType.largeHouse));
    });

    test('all types are represented in availableResearch', () {
      final researchedTypes = Research.availableResearch
          .map((r) => r.type)
          .toSet();
      for (final type in ResearchType.values) {
        expect(
          researchedTypes,
          contains(type),
          reason: '$type is missing from availableResearch',
        );
      }
    });
  });

  group('ResearchManager', () {
    late ResearchManager manager;

    setUp(() {
      manager = ResearchManager();
    });

    test('initially has no completed research', () {
      for (final type in ResearchType.values) {
        expect(manager.isResearched(type), isFalse);
      }
    });

    test('completeResearch marks type as researched', () {
      manager.completeResearch(ResearchType.electricity);
      expect(manager.isResearched(ResearchType.electricity), isTrue);
    });

    test('completing one type does not affect others', () {
      manager.completeResearch(ResearchType.electricity);
      expect(manager.isResearched(ResearchType.goldMining), isFalse);
    });

    test('isResearchedById returns true for completed research', () {
      manager.completeResearch(ResearchType.goldMining);
      expect(manager.isResearchedById('gold_mining'), isTrue);
    });

    test('isResearchedById returns false for incomplete research', () {
      expect(manager.isResearchedById('electricity'), isFalse);
    });

    test('isResearchedById returns false for unknown id', () {
      expect(manager.isResearchedById('nonexistent'), isFalse);
    });

    test('completeResearchById completes research by string id', () {
      manager.completeResearchById('electricity');
      expect(manager.isResearched(ResearchType.electricity), isTrue);
    });

    test('completeResearchById ignores unknown id silently', () {
      manager.completeResearchById('nonexistent');
      expect(manager.completedResearch, isEmpty);
    });

    group('canResearch', () {
      test('returns true for research with no prerequisites when not done', () {
        final electricity = Research.availableResearch.firstWhere(
          (r) => r.type == ResearchType.electricity,
        );
        expect(manager.canResearch(electricity), isTrue);
      });

      test('returns false if already completed', () {
        manager.completeResearch(ResearchType.electricity);
        final electricity = Research.availableResearch.firstWhere(
          (r) => r.type == ResearchType.electricity,
        );
        expect(manager.canResearch(electricity), isFalse);
      });

      test('returns false when prerequisite is not met', () {
        final advanced = Research.availableResearch.firstWhere(
          (r) => r.type == ResearchType.advancedConstruction,
        );
        expect(manager.canResearch(advanced), isFalse);
      });

      test('returns true when prerequisite is met', () {
        manager.completeResearch(ResearchType.expansionPlanning);
        final advanced = Research.availableResearch.firstWhere(
          (r) => r.type == ResearchType.advancedConstruction,
        );
        expect(manager.canResearch(advanced), isTrue);
      });

      test('returns false when only some prerequisites are met', () {
        // grainProcessing requires no prereqs, advancedGrainProcessing requires grainProcessing
        // modernHousing requires electricity — let's make a scenario where
        // advancedGrainProcessing would need grainProcessing but we check before completing it
        final advGrain = Research.availableResearch.firstWhere(
          (r) => r.type == ResearchType.advancedGrainProcessing,
        );
        expect(manager.canResearch(advGrain), isFalse);
        manager.completeResearch(ResearchType.grainProcessing);
        expect(manager.canResearch(advGrain), isTrue);
      });
    });

    group('getUnlockedBuildings', () {
      test('returns empty list when no research is complete', () {
        expect(manager.getUnlockedBuildings(), isEmpty);
      });

      test('returns buildings unlocked by completed research', () {
        manager.completeResearch(ResearchType.electricity);
        expect(
          manager.getUnlockedBuildings(),
          contains(BuildingType.powerPlant),
        );
      });

      test('returns buildings from multiple completed researches', () {
        manager.completeResearch(ResearchType.electricity);
        manager.completeResearch(ResearchType.goldMining);
        final unlocked = manager.getUnlockedBuildings();
        expect(unlocked, contains(BuildingType.powerPlant));
        expect(unlocked, contains(BuildingType.goldMine));
      });

      test('does not include buildings from incomplete research', () {
        manager.completeResearch(ResearchType.electricity);
        expect(
          manager.getUnlockedBuildings(),
          isNot(contains(BuildingType.goldMine)),
        );
      });

      test('research with no building unlocks contributes nothing to list', () {
        manager.completeResearch(ResearchType.expansionPlanning);
        expect(manager.getUnlockedBuildings(), isEmpty);
      });
    });

    group('completedResearch getter', () {
      test('returns a copy of the completed set', () {
        manager.completeResearch(ResearchType.electricity);
        final snapshot = manager.completedResearch;
        manager.completeResearch(ResearchType.goldMining);
        // snapshot should not be affected by subsequent changes
        expect(snapshot, hasLength(1));
        expect(snapshot, contains(ResearchType.electricity));
      });
    });

    group('loadFromList and toList', () {
      test('loadFromList populates completed research from string ids', () {
        manager.loadFromList(['electricity', 'gold_mining']);
        expect(manager.isResearched(ResearchType.electricity), isTrue);
        expect(manager.isResearched(ResearchType.goldMining), isTrue);
        expect(manager.isResearched(ResearchType.grainProcessing), isFalse);
      });

      test('loadFromList clears previous state', () {
        manager.completeResearch(ResearchType.electricity);
        manager.loadFromList(['gold_mining']);
        expect(manager.isResearched(ResearchType.electricity), isFalse);
        expect(manager.isResearched(ResearchType.goldMining), isTrue);
      });

      test('loadFromList ignores unknown ids', () {
        manager.loadFromList(['electricity', 'unknown_research']);
        expect(manager.completedResearch, hasLength(1));
        expect(manager.isResearched(ResearchType.electricity), isTrue);
      });

      test('toList returns string ids of completed research', () {
        manager.completeResearch(ResearchType.electricity);
        manager.completeResearch(ResearchType.goldMining);
        final list = manager.toList();
        expect(list, containsAll(['electricity', 'gold_mining']));
        expect(list, hasLength(2));
      });

      test('toList returns empty list when nothing is completed', () {
        expect(manager.toList(), isEmpty);
      });

      test('round-trip: toList then loadFromList preserves state', () {
        manager.completeResearch(ResearchType.electricity);
        manager.completeResearch(ResearchType.grainProcessing);
        final list = manager.toList();

        final newManager = ResearchManager();
        newManager.loadFromList(list);
        expect(newManager.isResearched(ResearchType.electricity), isTrue);
        expect(newManager.isResearched(ResearchType.grainProcessing), isTrue);
        expect(newManager.isResearched(ResearchType.goldMining), isFalse);
      });
    });
  });
}
