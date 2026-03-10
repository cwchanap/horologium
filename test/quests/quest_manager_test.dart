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

    group('checkProgress auto-activation', () {
      test('activates available quests without explicit activateQuest call', () {
        // No manual activateQuest call — checkProgress must auto-activate.
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        // test_build_house should be auto-activated and completed immediately.
        expect(
          manager.getCompletedQuests().any((q) => q.id == 'test_build_house'),
          isTrue,
        );
      });

      test('does not activate chained quest until prerequisite is claimed', () {
        // Build enough houses to complete test_build_house, but do NOT claim it.
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        // test_chained should still be in available (prereq not yet claimed).
        expect(
          manager.getActiveQuests().any((q) => q.id == 'test_chained'),
          isFalse,
        );
        expect(
          manager.getAvailableQuests().any((q) => q.id == 'test_chained'),
          isFalse,
        );
      });
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

        // test_build_house is completed; other eligible quests are auto-activated
        // but remain active (their objectives are not met with the given state).
        expect(
          manager.getActiveQuests().any((q) => q.id == 'test_build_house'),
          isFalse,
        );
        expect(
          manager.getCompletedQuests().any((q) => q.id == 'test_build_house'),
          isTrue,
        );
        expect(manager.getCompletedQuests(), hasLength(1));
      });
    });

    group('checkProgress with accumulateResource objective', () {
      test('updates resource accumulation objective', () {
        manager.activateQuest('test_accumulate');

        final resources = Resources();
        resources.resources[ResourceType.gold] = 75;
        manager.checkProgress(resources, [], ResearchManager());

        final quest = manager.getActiveQuests().firstWhere(
          (q) => q.id == 'test_accumulate',
        );
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

        // test_research remains active; other quests are auto-activated too.
        expect(
          manager.getActiveQuests().any((q) => q.id == 'test_research'),
          isTrue,
        );
        expect(
          manager.getCompletedQuests().any((q) => q.id == 'test_research'),
          isFalse,
        );
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

    group('onQuestProgressChanged callback', () {
      test('fires when objective progress changes', () {
        final qm = QuestManager(quests: [_resourceQuest()]);
        qm.activateQuest('test_accumulate');

        Quest? changedQuest;
        int callCount = 0;
        qm.onQuestProgressChanged = (quest) {
          changedQuest = quest;
          callCount++;
        };

        final resources = Resources();
        resources.resources[ResourceType.gold] = 75;
        qm.checkProgress(resources, [], ResearchManager());

        expect(callCount, 1);
        expect(changedQuest, isNotNull);
        expect(changedQuest!.id, 'test_accumulate');
      });

      test('does not fire when progress is unchanged', () {
        final qm = QuestManager(quests: [_resourceQuest()]);
        qm.activateQuest('test_accumulate');

        int callCount = 0;
        qm.onQuestProgressChanged = (_) => callCount++;

        final resources = Resources();
        resources.resources[ResourceType.gold] = 50;
        qm.checkProgress(resources, [], ResearchManager());
        qm.checkProgress(resources, [], ResearchManager());

        expect(callCount, 1);
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
        // checkProgress also auto-activates the remaining 3 available quests
        // (test_research, test_population, test_happiness).
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

        // All 5 non-chained quests are now active (auto-activated during checkProgress).
        expect(restored.getActiveQuests(), hasLength(5));

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

      test('loadFromJson clamps negative objective progress to zero', () {
        manager.loadFromJson({
          'active': ['test_build_house'],
          'objectiveProgress': {
            'test_build_house': {'0': -5},
          },
        });

        final restoredQuest = manager.getActiveQuests().firstWhere(
          (q) => q.id == 'test_build_house',
        );

        expect(restoredQuest.objectives.first.currentAmount, equals(0));
      });

      test('preserves claimed quest objective progress after save/load', () {
        // Set up a quest that gets completed and claimed with progress
        manager.activateQuest('test_build_house');
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        final resources = Resources();
        manager.checkProgress(resources, buildings, ResearchManager());
        manager.claimReward('test_build_house', resources);

        // Verify the quest is claimed with correct progress
        final claimedQuests = manager.getClaimedQuests();
        expect(claimedQuests, hasLength(1));
        expect(claimedQuests.first.objectives[0].currentAmount, 2);

        // Save and restore
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

        // Verify claimed quest still has correct progress after restore
        final restoredClaimed = restored.getClaimedQuests();
        expect(restoredClaimed, hasLength(1));
        expect(restoredClaimed.first.objectives[0].currentAmount, 2);
      });
    });

    group('research prerequisites', () {
      test(
        'quest requiring research is not available until research is completed',
        () {
          final goldRushQuest = Quest(
            id: 'quest_gold_rush',
            name: 'Gold Rush',
            description: 'Build a gold mine',
            objectives: [
              QuestObjective(
                type: QuestObjectiveType.buildBuilding,
                targetId: 'goldMine',
                targetAmount: 1,
              ),
            ],
            reward: QuestReward(resources: {ResourceType.cash: 500}),
            requiredResearchIds: ['gold_mining'],
          );

          final researchManager = ResearchManager();
          final questManagerWithResearch = QuestManager(
            quests: [goldRushQuest],
            researchManager: researchManager,
          );

          // Without gold_mining research, quest should not be available
          final availableBefore = questManagerWithResearch.getAvailableQuests();
          expect(
            availableBefore.any((q) => q.id == 'quest_gold_rush'),
            isFalse,
          );

          // Complete the gold_mining research
          researchManager.completeResearchById('gold_mining');

          // Now the quest should be available
          final availableAfter = questManagerWithResearch.getAvailableQuests();
          expect(availableAfter.any((q) => q.id == 'quest_gold_rush'), isTrue);
        },
      );

      test(
        'quest requiring multiple research is not available until all research is completed',
        () {
          final complexQuest = Quest(
            id: 'quest_complex',
            name: 'Complex Quest',
            description: 'Requires multiple research',
            objectives: [
              QuestObjective(
                type: QuestObjectiveType.buildBuilding,
                targetId: 'powerPlant',
                targetAmount: 1,
              ),
            ],
            reward: QuestReward(resources: {ResourceType.cash: 1000}),
            requiredResearchIds: ['electricity', 'gold_mining'],
          );

          final researchManager = ResearchManager();
          final questManagerWithResearch = QuestManager(
            quests: [complexQuest],
            researchManager: researchManager,
          );

          // Without any research, quest should not be available
          expect(
            questManagerWithResearch.getAvailableQuests().any(
              (q) => q.id == 'quest_complex',
            ),
            isFalse,
          );

          // Complete only one research
          researchManager.completeResearchById('electricity');
          expect(
            questManagerWithResearch.getAvailableQuests().any(
              (q) => q.id == 'quest_complex',
            ),
            isFalse,
          );

          // Complete the second research
          researchManager.completeResearchById('gold_mining');
          expect(
            questManagerWithResearch.getAvailableQuests().any(
              (q) => q.id == 'quest_complex',
            ),
            isTrue,
          );
        },
      );

      test(
        'quest without research requirements is available without research manager',
        () {
          final simpleQuest = Quest(
            id: 'quest_simple',
            name: 'Simple Quest',
            description: 'No research needed',
            objectives: [
              QuestObjective(
                type: QuestObjectiveType.buildBuilding,
                targetId: 'house',
                targetAmount: 1,
              ),
            ],
            reward: QuestReward(resources: {ResourceType.cash: 100}),
          );

          // Create manager without research manager
          final questManagerWithoutResearch = QuestManager(
            quests: [simpleQuest],
          );

          // Quest should be available even without research manager
          final available = questManagerWithoutResearch.getAvailableQuests();
          expect(available.any((q) => q.id == 'quest_simple'), isTrue);
        },
      );

      test('setResearchManager updates the research manager', () {
        final goldRushQuest = Quest(
          id: 'quest_gold_rush',
          name: 'Gold Rush',
          description: 'Build a gold mine',
          objectives: [
            QuestObjective(
              type: QuestObjectiveType.buildBuilding,
              targetId: 'goldMine',
              targetAmount: 1,
            ),
          ],
          reward: QuestReward(resources: {ResourceType.cash: 500}),
          requiredResearchIds: ['gold_mining'],
        );

        // Create manager without research manager
        final questManager = QuestManager(quests: [goldRushQuest]);

        // Quest should be available because no research manager is set
        expect(
          questManager.getAvailableQuests().any(
            (q) => q.id == 'quest_gold_rush',
          ),
          isTrue,
        );

        // Now set a research manager without the required research
        final researchManager = ResearchManager();
        questManager.setResearchManager(researchManager);

        // Quest should no longer be available
        expect(
          questManager.getAvailableQuests().any(
            (q) => q.id == 'quest_gold_rush',
          ),
          isFalse,
        );
      });

      test(
        'setResearchManager properly filters existing quest availability',
        () {
          final goldRushQuest = Quest(
            id: 'quest_gold_rush',
            name: 'Gold Rush',
            description: 'Build a gold mine',
            objectives: [
              QuestObjective(
                type: QuestObjectiveType.buildBuilding,
                targetId: 'goldMine',
                targetAmount: 1,
              ),
            ],
            reward: QuestReward(resources: {ResourceType.cash: 500}),
            requiredResearchIds: ['gold_mining'],
          );

          // Create manager without research manager
          final questManager = QuestManager(quests: [goldRushQuest]);

          // Quest should be available because no research manager is set
          expect(
            questManager.getAvailableQuests().any(
              (q) => q.id == 'quest_gold_rush',
            ),
            isTrue,
          );

          // Complete the required research first
          final researchManager = ResearchManager();
          researchManager.completeResearchById('gold_mining');

          // Now set the research manager with completed research
          questManager.setResearchManager(researchManager);

          // Quest should still be available
          expect(
            questManager.getAvailableQuests().any(
              (q) => q.id == 'quest_gold_rush',
            ),
            isTrue,
          );
        },
      );
    });

    group('onQuestStatusChanged callback', () {
      test('fires when quest is activated', () {
        Quest? changedQuest;
        QuestStatus? oldStatus;
        QuestStatus? newStatus;

        manager.onQuestStatusChanged = (quest, old, new_) {
          changedQuest = quest;
          oldStatus = old;
          newStatus = new_;
        };

        manager.activateQuest('test_build_house');

        expect(changedQuest, isNotNull);
        expect(changedQuest!.id, 'test_build_house');
        expect(oldStatus, QuestStatus.available);
        expect(newStatus, QuestStatus.active);
      });

      test('fires when quest is completed', () {
        manager.activateQuest('test_build_house');

        Quest? changedQuest;
        QuestStatus? oldStatus;
        QuestStatus? newStatus;

        manager.onQuestStatusChanged = (quest, old, new_) {
          changedQuest = quest;
          oldStatus = old;
          newStatus = new_;
        };

        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        expect(changedQuest, isNotNull);
        expect(changedQuest!.id, 'test_build_house');
        expect(oldStatus, QuestStatus.active);
        expect(newStatus, QuestStatus.completed);
      });

      test('fires when quest is claimed', () {
        manager.activateQuest('test_build_house');
        final buildings = [
          _makeBuilding(BuildingType.house),
          _makeBuilding(BuildingType.house),
        ];
        manager.checkProgress(Resources(), buildings, ResearchManager());

        Quest? changedQuest;
        QuestStatus? oldStatus;
        QuestStatus? newStatus;

        manager.onQuestStatusChanged = (quest, old, new_) {
          changedQuest = quest;
          oldStatus = old;
          newStatus = new_;
        };

        manager.claimReward('test_build_house', Resources());

        expect(changedQuest, isNotNull);
        expect(changedQuest!.id, 'test_build_house');
        expect(oldStatus, QuestStatus.completed);
        expect(newStatus, QuestStatus.claimed);
      });
    });

    group('onQuestsRefreshed callback', () {
      test('addRotatingQuests fires onQuestsRefreshed', () {
        int callCount = 0;
        manager.onQuestsRefreshed = () => callCount++;

        manager.addRotatingQuests([
          Quest(
            id: 'daily_20260101_0',
            name: 'Daily',
            description: 'Daily quest',
            objectives: [],
            reward: const QuestReward(),
          ),
        ]);

        expect(callCount, 1);
      });

      test('removeRotatingQuests fires onQuestsRefreshed', () {
        manager.addRotatingQuests([
          Quest(
            id: 'daily_20260101_0',
            name: 'Daily',
            description: 'Daily quest',
            objectives: [],
            reward: const QuestReward(),
          ),
        ]);

        int callCount = 0;
        manager.onQuestsRefreshed = () => callCount++;

        manager.removeRotatingQuests('daily_');

        expect(callCount, 1);
      });

      test('onQuestsRefreshed is null by default', () {
        final qm = QuestManager(quests: []);
        expect(qm.onQuestsRefreshed, isNull);
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
