import 'dart:math';

import '../building/building.dart';
import '../research/research.dart';
import '../resources/resource_type.dart';
import '../services/building_service.dart';
import 'quest.dart';
import 'quest_objective.dart';

/// Generates procedural daily and weekly quests from a deterministic seed.
class DailyQuestGenerator {
  static const int dailyQuestCount = 3;
  static const int weeklyQuestCount = 2;

  /// Mapping from target string IDs to BuildingType enum values
  /// Used to filter building targets based on research state
  static final Map<String, BuildingType> _buildingTypeMap = {
    'house': BuildingType.house,
    'powerPlant': BuildingType.powerPlant,
    'goldMine': BuildingType.goldMine,
    'woodFactory': BuildingType.woodFactory,
    'waterTreatment': BuildingType.waterTreatment,
  };

  /// Templates that the generator picks from.
  static const _templates = [
    _QuestTemplate(
      namePrefix: 'Build',
      objectiveType: QuestObjectiveType.buildBuilding,
      targets: [
        'house',
        'powerPlant',
        'goldMine',
        'woodFactory',
        'waterTreatment',
      ],
      dailyRange: [1, 3],
      weeklyRange: [3, 8],
      rewardType: ResourceType.cash,
      dailyRewardRange: [100, 300],
      weeklyRewardRange: [500, 1500],
    ),
    _QuestTemplate(
      namePrefix: 'Gather',
      objectiveType: QuestObjectiveType.accumulateResource,
      targets: ['cash', 'gold', 'wood', 'coal', 'water'],
      dailyRange: [50, 200],
      weeklyRange: [500, 2000],
      rewardType: ResourceType.cash,
      dailyRewardRange: [50, 200],
      weeklyRewardRange: [300, 1000],
    ),
    _QuestTemplate(
      namePrefix: 'Populate',
      objectiveType: QuestObjectiveType.reachPopulation,
      targets: [''],
      dailyRange: [10, 30],
      weeklyRange: [50, 150],
      rewardType: ResourceType.gold,
      dailyRewardRange: [20, 80],
      weeklyRewardRange: [100, 500],
    ),
    _QuestTemplate(
      namePrefix: 'Happiness',
      objectiveType: QuestObjectiveType.achieveHappiness,
      targets: [''],
      dailyRange: [40, 70],
      weeklyRange: [60, 90],
      rewardType: ResourceType.cash,
      dailyRewardRange: [100, 400],
      weeklyRewardRange: [500, 2000],
    ),
  ];

  static final _targetDisplayNames = {
    'house': 'Houses',
    'powerPlant': 'Power Plants',
    'goldMine': 'Gold Mines',
    'woodFactory': 'Wood Factories',
    'waterTreatment': 'Water Treatment',
    'cash': 'Cash',
    'gold': 'Gold',
    'wood': 'Wood',
    'coal': 'Coal',
    'water': 'Water',
  };

  /// Generate a deterministic daily seed from a date (ignoring time-of-day).
  /// Uses UTC to ensure cross-device consistency across time zones.
  static int dailySeedForDate(DateTime date) {
    final utc = date.toUtc();
    return utc.year * 10000 + utc.month * 100 + utc.day;
  }

  /// Generate a deterministic weekly seed from a date (ISO week boundary).
  /// Uses UTC to ensure cross-device consistency across time zones.
  static int weeklySeedForDate(DateTime date) {
    // Normalize to UTC midnight to prevent time-of-day/timezone from shifting week boundaries.
    final utc = date.toUtc();
    final normalizedDate = DateTime.utc(utc.year, utc.month, utc.day);
    // Normalize to the Monday of the ISO week.
    final monday = normalizedDate.subtract(
      Duration(days: (normalizedDate.weekday - 1)),
    );
    return monday.year * 10000 + monday.month * 100 + monday.day;
  }

  static List<Quest> generateDaily({
    required int seed,
    ResearchManager? researchManager,
  }) {
    return _generate(
      seed: seed,
      count: dailyQuestCount,
      prefix: 'daily',
      isWeekly: false,
      researchManager: researchManager,
    );
  }

  static List<Quest> generateWeekly({
    required int seed,
    ResearchManager? researchManager,
  }) {
    return _generate(
      seed: seed,
      count: weeklyQuestCount,
      prefix: 'weekly',
      isWeekly: true,
      researchManager: researchManager,
    );
  }

  static List<Quest> _generate({
    required int seed,
    required int count,
    required String prefix,
    required bool isWeekly,
    ResearchManager? researchManager,
  }) {
    final rng = Random(seed);
    final quests = <Quest>[];

    // Get available building types if researchManager is provided
    Set<BuildingType>? availableBuildings;
    if (researchManager != null) {
      availableBuildings = BuildingService.getAvailableBuildings(
        researchManager,
      ).map((b) => b.type).toSet();
    }

    for (int i = 0; i < count; i++) {
      final templateIndex = rng.nextInt(_templates.length);
      final template = _templates[templateIndex];

      // Filter targets based on available buildings for building objectives
      List<String> filteredTargets = template.targets;
      if (template.objectiveType == QuestObjectiveType.buildBuilding &&
          availableBuildings != null) {
        filteredTargets = template.targets.where((targetId) {
          final buildingType = _buildingTypeMap[targetId];
          return buildingType == null ||
              availableBuildings!.contains(buildingType);
        }).toList();

        // If all targets are filtered out, skip this quest or fall back to first available
        if (filteredTargets.isEmpty) {
          // Find at least one building that's available
          final availableBuildingTargets = _buildingTypeMap.entries
              .where((entry) => availableBuildings!.contains(entry.value))
              .map((entry) => entry.key)
              .toList();

          if (availableBuildingTargets.isNotEmpty) {
            filteredTargets = [
              availableBuildingTargets[rng.nextInt(
                availableBuildingTargets.length,
              )],
            ];
          } else {
            // If no buildings available at all, skip this quest
            continue;
          }
        }
      }

      final targetIndex = rng.nextInt(filteredTargets.length);
      final targetId = filteredTargets[targetIndex];

      final range = isWeekly ? template.weeklyRange : template.dailyRange;
      final targetAmount = range[0] + rng.nextInt(range[1] - range[0] + 1);

      final rewardRange = isWeekly
          ? template.weeklyRewardRange
          : template.dailyRewardRange;
      final rewardAmount =
          rewardRange[0] + rng.nextInt(rewardRange[1] - rewardRange[0] + 1);

      final displayTarget = _targetDisplayNames[targetId] ?? targetId;
      final name = displayTarget.isEmpty
          ? template.namePrefix
          : '${template.namePrefix} $displayTarget';

      // IDs are unique by construction: prefix + seed + index.
      final questId = '${prefix}_${seed}_$i';

      quests.add(
        Quest(
          id: questId,
          name: name,
          description: _descriptionFor(
            template.objectiveType,
            displayTarget,
            targetAmount,
          ),
          objectives: [
            QuestObjective(
              type: template.objectiveType,
              targetId: targetId,
              targetAmount: targetAmount,
            ),
          ],
          reward: QuestReward(
            resources: {template.rewardType: rewardAmount.toDouble()},
          ),
        ),
      );
    }

    return quests;
  }

  static String _descriptionFor(
    QuestObjectiveType type,
    String target,
    int amount,
  ) {
    switch (type) {
      case QuestObjectiveType.buildBuilding:
        return 'Build $amount $target.';
      case QuestObjectiveType.accumulateResource:
        return 'Accumulate $amount $target.';
      case QuestObjectiveType.reachPopulation:
        return 'Grow your population to $amount.';
      case QuestObjectiveType.achieveHappiness:
        return 'Reach $amount happiness.';
      case QuestObjectiveType.completeResearch:
        return 'Complete $amount research projects.';
      case QuestObjectiveType.upgradeBuilding:
        return 'Upgrade $target $amount times.';
    }
  }
}

class _QuestTemplate {
  final String namePrefix;
  final QuestObjectiveType objectiveType;
  final List<String> targets;
  final List<int> dailyRange;
  final List<int> weeklyRange;
  final ResourceType rewardType;
  final List<int> dailyRewardRange;
  final List<int> weeklyRewardRange;

  const _QuestTemplate({
    required this.namePrefix,
    required this.objectiveType,
    required this.targets,
    required this.dailyRange,
    required this.weeklyRange,
    required this.rewardType,
    required this.dailyRewardRange,
    required this.weeklyRewardRange,
  });
}
