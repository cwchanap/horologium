import 'dart:math';

import '../resources/resource_type.dart';
import 'quest.dart';
import 'quest_objective.dart';

/// Generates procedural daily and weekly quests from a deterministic seed.
class DailyQuestGenerator {
  static const int dailyQuestCount = 3;
  static const int weeklyQuestCount = 2;

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
  static int dailySeedForDate(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  /// Generate a deterministic weekly seed from a date (ISO week boundary).
  static int weeklySeedForDate(DateTime date) {
    // Normalize to midnight to prevent time-of-day from shifting week boundaries.
    final normalizedDate = DateTime(date.year, date.month, date.day);
    // Normalize to the Monday of the ISO week.
    final monday = normalizedDate.subtract(
      Duration(days: (normalizedDate.weekday - 1)),
    );
    return monday.year * 10000 + monday.month * 100 + monday.day;
  }

  static List<Quest> generateDaily({required int seed}) {
    return _generate(
      seed: seed,
      count: dailyQuestCount,
      prefix: 'daily',
      isWeekly: false,
    );
  }

  static List<Quest> generateWeekly({required int seed}) {
    return _generate(
      seed: seed,
      count: weeklyQuestCount,
      prefix: 'weekly',
      isWeekly: true,
    );
  }

  static List<Quest> _generate({
    required int seed,
    required int count,
    required String prefix,
    required bool isWeekly,
  }) {
    final rng = Random(seed);
    final usedIds = <String>{};
    final quests = <Quest>[];

    for (int i = 0; i < count; i++) {
      final templateIndex = rng.nextInt(_templates.length);
      final template = _templates[templateIndex];
      final targetIndex = rng.nextInt(template.targets.length);
      final targetId = template.targets[targetIndex];

      final range = isWeekly ? template.weeklyRange : template.dailyRange;
      final targetAmount = range[0] + rng.nextInt(range[1] - range[0] + 1);

      final rewardRange = isWeekly
          ? template.weeklyRewardRange
          : template.dailyRewardRange;
      final rewardAmount =
          rewardRange[0] + rng.nextInt(rewardRange[1] - rewardRange[0] + 1);

      final displayTarget = _targetDisplayNames[targetId] ?? targetId;
      final name = '${template.namePrefix} $displayTarget';

      // IDs are unique by construction: prefix + seed + index.
      final questId = '${prefix}_${seed}_$i';
      usedIds.add(questId);

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
