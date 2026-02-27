import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/quests/quest.dart';
import 'package:horologium/game/quests/quest_manager.dart';
import 'package:horologium/game/quests/quest_objective.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

Quest _buildQuest() => Quest(
  id: 'test_build_house',
  name: 'Build Houses',
  description: 'Build 2 houses',
  objectives: [
    QuestObjective(
      type: QuestObjectiveType.buildBuilding,
      targetId: 'house',
      targetAmount: 2,
    ),
  ],
  reward: QuestReward(resources: {ResourceType.cash: 500}),
);

Quest _resourceQuest() => Quest(
  id: 'test_accumulate',
  name: 'Get Gold',
  description: 'Accumulate 100 gold',
  objectives: [
    QuestObjective(
      type: QuestObjectiveType.accumulateResource,
      targetId: 'gold',
      targetAmount: 100,
    ),
  ],
  reward: QuestReward(resources: {ResourceType.cash: 200}),
);

Quest _researchQuest() => Quest(
  id: 'test_research',
  name: 'Research Electricity',
  description: 'Complete electricity research',
  objectives: [
    QuestObjective(
      type: QuestObjectiveType.completeResearch,
      targetId: 'electricity',
      targetAmount: 1,
    ),
  ],
  reward: QuestReward(researchPoints: 10),
);

Quest _populationQuest() => Quest(
  id: 'test_population',
  name: 'Grow Population',
  description: 'Reach population 50',
  objectives: [
    QuestObjective(
      type: QuestObjectiveType.reachPopulation,
      targetId: '',
      targetAmount: 50,
    ),
  ],
  reward: QuestReward(resources: {ResourceType.cash: 300}),
);

Quest _happinessQuest() => Quest(
  id: 'test_happiness',
  name: 'Happy Town',
  description: 'Achieve happiness 70',
  objectives: [
    QuestObjective(
      type: QuestObjectiveType.achieveHappiness,
      targetId: '',
      targetAmount: 70,
    ),
  ],
  reward: QuestReward(resources: {ResourceType.cash: 500}),
);

Quest _chainedQuest() => Quest(
  id: 'test_chained',
  name: 'Chained Quest',
  description: 'Requires test_build_house',
  objectives: [
    QuestObjective(
      type: QuestObjectiveType.buildBuilding,
      targetId: 'powerPlant',
      targetAmount: 1,
    ),
  ],
  reward: QuestReward(resources: {ResourceType.cash: 300}),
  prerequisiteQuestIds: ['test_build_house'],
);

void main() {
  group('QuestManager', () {
    late QuestManager manager;

    setUp(() {
      manager = QuestManager(
        quests: [
          _buildQuest(),
          _resourceQuest(),
          _researchQuest(),
          _populationQuest(),
          _happinessQuest(),
          _chainedQuest(),
        ],
      );
    });

    test('initializes with all quests as available', () {
      // Non-chained quests should be available
      expect(manager.getAvailableQuests(), hasLength(5));
      expect(manager.getActiveQuests(), isEmpty);
      expect(manager.getCompletedQuests(), isEmpty);
    });

    test('chained quest is not available until prerequisite is claimed', () {
      final available = manager.getAvailableQuests();
      expect(available.any((q) => q.id == 'test_chained'), isFalse);
    });

    test('activateQuest moves quest from available to active', () {
      manager.activateQuest('test_build_house');

      expect(manager.getActiveQuests(), hasLength(1));
      expect(manager.getActiveQuests().first.id, 'test_build_house');
    });

    test('activateQuest does nothing for non-existent quest', () {
      manager.activateQuest('nonexistent');

      expect(manager.getActiveQuests(), isEmpty);
    });

    test('activateQuest does nothing for already active quest', () {
      manager.activateQuest('test_build_house');
      manager.activateQuest('test_build_house');

      expect(manager.getActiveQuests(), hasLength(1));
    });

    group('checkProgress with buildBuilding objective', () {
      test('updates building count objective', () {
        manager.activateQuest('test_build_house');

        final buildings = [_makeBuilding(BuildingType.house)];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        final quest = manager.getActiveQuests().first;
        expect(quest.objectives[0].currentAmount, 1);
      });

      test('completes quest when all objectives met', () {
        manager.activateQuest('test_build_house');

        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        expect(manager.getActiveQuests(), isEmpty);
        expect(manager.getCompletedQuests(), hasLength(1));
      });
    });

    group('checkProgress with accumulateResource objective', () {
      test('updates resource accumulation objective', () {
        manager.activateQuest('test_accumulate');

        final resources = Resources();
        resources.resources[ResourceType.gold] = 75;
        manager.checkProgress(resources, [], ResearchManager());

        final quest = manager.getActiveQuests().first;
        expect(quest.objectives[0].currentAmount, 75);
      });

      test('completes quest when resource target met', () {
        manager.activateQuest('test_accumulate');

        final resources = Resources();
        resources.resources[ResourceType.gold] = 100;
        manager.checkProgress(resources, [], ResearchManager());

        expect(manager.getCompletedQuests(), hasLength(1));
        expect(manager.getCompletedQuests().first.id, 'test_accumulate');
      });
    });

    group('checkProgress with completeResearch objective', () {
      test('updates research objective', () {
        manager.activateQuest('test_research');

        final rm = ResearchManager();
        rm.completeResearch(ResearchType.electricity);
        manager.checkProgress(Resources(), [], rm);

        expect(manager.getCompletedQuests(), hasLength(1));
      });

      test('does not complete when research not done', () {
        manager.activateQuest('test_research');

        manager.checkProgress(Resources(), [], ResearchManager());

        expect(manager.getActiveQuests(), hasLength(1));
      });
    });

    group('checkProgress with reachPopulation objective', () {
      test('updates population objective', () {
        manager.activateQuest('test_population');

        final resources = Resources();
        resources.population = 50;
        manager.checkProgress(resources, [], ResearchManager());

        expect(manager.getCompletedQuests(), hasLength(1));
      });
    });

    group('checkProgress with achieveHappiness objective', () {
      test('updates happiness objective', () {
        manager.activateQuest('test_happiness');

        final resources = Resources();
        resources.happiness = 75;
        manager.checkProgress(resources, [], ResearchManager());

        expect(manager.getCompletedQuests(), hasLength(1));
      });
    });

    group('claimReward', () {
      test('adds resource rewards to player resources', () {
        manager.activateQuest('test_build_house');
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        final resources = Resources();
        manager.checkProgress(resources, buildings, ResearchManager());

        final claimed = manager.claimReward('test_build_house', resources);

        expect(claimed, isTrue);
        // Cash started at 1000 (default) + 500 reward
        expect(resources.resources[ResourceType.cash], 1500);
      });

      test('marks quest as claimed after reward', () {
        manager.activateQuest('test_build_house');
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        final resources = Resources();
        manager.checkProgress(resources, buildings, ResearchManager());

        manager.claimReward('test_build_house', resources);

        expect(manager.getCompletedQuests(), isEmpty);
        expect(manager.getClaimedQuests(), hasLength(1));
      });

      test('returns false for non-completed quest', () {
        manager.activateQuest('test_build_house');

        final result = manager.claimReward('test_build_house', Resources());

        expect(result, isFalse);
      });

      test('returns false for non-existent quest', () {
        final result = manager.claimReward('nonexistent', Resources());

        expect(result, isFalse);
      });

      test('unlocks chained quest after claiming prerequisite', () {
        manager.activateQuest('test_build_house');
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        final resources = Resources();
        manager.checkProgress(resources, buildings, ResearchManager());
        manager.claimReward('test_build_house', resources);

        final available = manager.getAvailableQuests();
        expect(available.any((q) => q.id == 'test_chained'), isTrue);
      });
    });

    group('hasUnclaimedRewards', () {
      test('returns false when no completed quests', () {
        expect(manager.hasUnclaimedRewards, isFalse);
      });

      test('returns true when completed quests exist', () {
        manager.activateQuest('test_build_house');
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        expect(manager.hasUnclaimedRewards, isTrue);
      });
    });

    group('onQuestCompleted callback', () {
      test('fires when quest is completed', () {
        Quest? completedQuest;
        manager.onQuestCompleted = (quest) => completedQuest = quest;

        manager.activateQuest('test_build_house');
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        expect(completedQuest, isNotNull);
        expect(completedQuest!.id, 'test_build_house');
      });
    });

    group('serialization', () {
      test('toJson and loadFromJson round-trip', () {
        manager.activateQuest('test_build_house');
        manager.activateQuest('test_accumulate');

        // Simulate some progress
        final resources = Resources();
        resources.resources[ResourceType.gold] = 50;
        final buildings = [_makeBuilding(BuildingType.house)];
        manager.checkProgress(resources, buildings, ResearchManager());

        final json = manager.toJson();
        final restored = QuestManager(
          quests: [
            _buildQuest(),
            _resourceQuest(),
            _researchQuest(),
            _populationQuest(),
            _happinessQuest(),
            _chainedQuest(),
          ],
        );
        restored.loadFromJson(json);

        expect(restored.getActiveQuests(), hasLength(2));
        final buildQuest = restored.getActiveQuests().firstWhere(
          (q) => q.id == 'test_build_house',
        );
        expect(buildQuest.objectives[0].currentAmount, 1);

        final goldQuest = restored.getActiveQuests().firstWhere(
          (q) => q.id == 'test_accumulate',
        );
        expect(goldQuest.objectives[0].currentAmount, 50);
      });

      test('loadFromJson handles empty/null gracefully', () {
        manager.loadFromJson({});

        // Should reset to defaults
        expect(manager.getActiveQuests(), isEmpty);
      });

      test('loadFromJson ignores unknown quest IDs', () {
        manager.loadFromJson({
          'active': ['unknown_quest_id'],
          'objectiveProgress': {
            'unknown_quest_id': {'0': 5},
          },
        });

        expect(manager.getActiveQuests(), isEmpty);
      });
    });
  });
}

Building _makeBuilding(BuildingType type) {
  final template = BuildingRegistry.availableBuildings.firstWhere(
    (b) => b.type == type,
  );
  return Building(
    type: template.type,
    name: template.name,
    description: template.description,
    icon: template.icon,
    assetPath: template.assetPath,
    color: template.color,
    baseCost: template.baseCost,
    baseGeneration: template.baseGeneration,
    baseConsumption: template.baseConsumption,
    category: template.category,
  );
}
