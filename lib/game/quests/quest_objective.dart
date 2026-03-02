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
    final targetIdValue = json['targetId'];
    final targetAmountValue = json['targetAmount'];
    final currentAmountValue = json['currentAmount'];

    int parseAmount(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value < 0 ? 0 : value;
      if (value is num) return value.toInt() < 0 ? 0 : value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed == null || parsed < 0 ? 0 : parsed;
      }
      return 0;
    }

    return QuestObjective(
      type: QuestObjectiveType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => QuestObjectiveType.buildBuilding,
      ),
      targetId: targetIdValue is String
          ? targetIdValue
          : targetIdValue?.toString() ?? '',
      targetAmount: parseAmount(targetAmountValue),
      currentAmount: parseAmount(currentAmountValue),
    );
  }
}
