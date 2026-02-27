enum QuestObjectiveType {
  buildBuilding,
  accumulateResource,
  completeResearch,
  reachPopulation,
  achieveHappiness,
  upgradeBuilding,
}

class QuestObjective {
  final QuestObjectiveType type;
  final String targetId;
  final int targetAmount;
  int currentAmount;

  QuestObjective({
    required this.type,
    required this.targetId,
    required this.targetAmount,
    this.currentAmount = 0,
  });

  bool get isComplete => currentAmount >= targetAmount;

  double get progress =>
      targetAmount <= 0 ? 1.0 : (currentAmount / targetAmount).clamp(0.0, 1.0);

  String get description {
    switch (type) {
      case QuestObjectiveType.buildBuilding:
        return 'Build $targetAmount $targetId';
      case QuestObjectiveType.accumulateResource:
        return 'Accumulate $targetAmount $targetId';
      case QuestObjectiveType.completeResearch:
        return 'Complete research: $targetId';
      case QuestObjectiveType.reachPopulation:
        return 'Reach population $targetAmount';
      case QuestObjectiveType.achieveHappiness:
        return 'Achieve happiness $targetAmount';
      case QuestObjectiveType.upgradeBuilding:
        return 'Upgrade $targetId to level $targetAmount';
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'targetId': targetId,
    'targetAmount': targetAmount,
    'currentAmount': currentAmount,
  };

  factory QuestObjective.fromJson(Map<String, dynamic> json) {
    return QuestObjective(
      type: QuestObjectiveType.values.firstWhere((t) => t.name == json['type']),
      targetId: json['targetId'] as String,
      targetAmount: json['targetAmount'] as int,
      currentAmount: json['currentAmount'] as int? ?? 0,
    );
  }
}
