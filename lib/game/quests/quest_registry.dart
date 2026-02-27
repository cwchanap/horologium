import '../resources/resource_type.dart';
import 'quest.dart';
import 'quest_objective.dart';

class QuestRegistry {
  static List<Quest> starterQuests = [
    Quest(
      id: 'quest_welcome',
      name: 'Welcome to Horologium',
      description: 'Build your first house to shelter your citizens.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'house',
          targetAmount: 1,
        ),
      ],
      reward: QuestReward(resources: {ResourceType.cash: 200}),
    ),
    Quest(
      id: 'quest_power_up',
      name: 'Power Up',
      description:
          'Research electricity and build a Power Plant to power your city.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.completeResearch,
          targetId: 'electricity',
          targetAmount: 1,
        ),
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'powerPlant',
          targetAmount: 1,
        ),
      ],
      reward: QuestReward(
        resources: {ResourceType.cash: 300, ResourceType.coal: 50},
      ),
    ),
    Quest(
      id: 'quest_gold_rush',
      name: 'Gold Rush',
      description: 'Start mining gold to boost your economy.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'goldMine',
          targetAmount: 1,
        ),
        QuestObjective(
          type: QuestObjectiveType.accumulateResource,
          targetId: 'gold',
          targetAmount: 100,
        ),
      ],
      reward: QuestReward(resources: {ResourceType.cash: 500}),
    ),
    Quest(
      id: 'quest_lumber_yard',
      name: 'Lumber Yard',
      description: 'Build two Wood Factories for a steady timber supply.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'woodFactory',
          targetAmount: 2,
        ),
      ],
      reward: QuestReward(resources: {ResourceType.wood: 200}),
    ),
    Quest(
      id: 'quest_growing_town',
      name: 'Growing Town',
      description: 'Grow your population to 50 citizens.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.reachPopulation,
          targetId: '',
          targetAmount: 50,
        ),
      ],
      reward: QuestReward(
        resources: {ResourceType.cash: 500, ResourceType.wood: 100},
      ),
    ),
    Quest(
      id: 'quest_researcher',
      name: 'Knowledge Seeker',
      description: 'Complete 3 research projects to advance your technology.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.completeResearch,
          targetId: 'electricity',
          targetAmount: 1,
        ),
        QuestObjective(
          type: QuestObjectiveType.completeResearch,
          targetId: 'gold_mining',
          targetAmount: 1,
        ),
        QuestObjective(
          type: QuestObjectiveType.completeResearch,
          targetId: 'expansion_planning',
          targetAmount: 1,
        ),
      ],
      reward: QuestReward(resources: {ResourceType.cash: 1000}),
    ),
    Quest(
      id: 'quest_grain_master',
      name: 'Grain Master',
      description: 'Build grain processing facilities.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'windMill',
          targetAmount: 1,
        ),
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'grinderMill',
          targetAmount: 1,
        ),
      ],
      reward: QuestReward(
        resources: {ResourceType.cash: 300, ResourceType.wheat: 50},
      ),
    ),
    Quest(
      id: 'quest_water_works',
      name: 'Water Works',
      description: 'Build 2 Water Treatment plants to secure clean water.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'waterTreatment',
          targetAmount: 2,
        ),
      ],
      reward: QuestReward(
        resources: {ResourceType.cash: 200, ResourceType.water: 100},
      ),
    ),
    Quest(
      id: 'quest_industrialist',
      name: 'Industrialist',
      description:
          'Build one of each core building: House, Power Plant, Gold Mine, and Wood Factory.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'house',
          targetAmount: 1,
        ),
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'powerPlant',
          targetAmount: 1,
        ),
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'goldMine',
          targetAmount: 1,
        ),
        QuestObjective(
          type: QuestObjectiveType.buildBuilding,
          targetId: 'woodFactory',
          targetAmount: 1,
        ),
      ],
      reward: QuestReward(resources: {ResourceType.cash: 1000}),
    ),
    Quest(
      id: 'quest_happy_town',
      name: 'Happy Citizens',
      description: 'Keep your citizens happy — achieve 70 or higher happiness.',
      objectives: [
        QuestObjective(
          type: QuestObjectiveType.achieveHappiness,
          targetId: '',
          targetAmount: 70,
        ),
      ],
      reward: QuestReward(
        resources: {ResourceType.cash: 500, ResourceType.gold: 200},
      ),
      prerequisiteQuestIds: ['quest_welcome'],
    ),
  ];
}
