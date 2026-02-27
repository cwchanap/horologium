enum AchievementType {
  buildingCount,
  populationReached,
  resourceAccumulated,
  researchCompleted,
  happinessReached,
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final AchievementType type;
  final int targetAmount;
  final String? targetId;
  int currentAmount;
  bool isUnlocked;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.targetAmount,
    this.targetId,
    this.currentAmount = 0,
    this.isUnlocked = false,
  });

  double get progress =>
      targetAmount <= 0 ? 1.0 : (currentAmount / targetAmount).clamp(0.0, 1.0);
}
