import 'package:flutter/foundation.dart';

import '../building/building.dart';
import '../research/research.dart';
import '../resources/resource_type.dart';
import '../resources/resources.dart';
import 'achievement.dart';

class AchievementManager {
  final Map<String, Achievement> _achievements;

  void Function(Achievement)? onAchievementUnlocked;

  AchievementManager({required List<Achievement> achievements})
    : _achievements = {for (final a in achievements) a.id: a};

  List<Achievement> get achievements => _achievements.values.toList();

  List<Achievement> getAll() => _achievements.values.toList();

  List<Achievement> getUnlocked() =>
      _achievements.values.where((a) => a.isUnlocked).toList();

  void checkProgress(
    Resources resources,
    List<Building> buildings,
    ResearchManager researchManager,
  ) {
    for (final achievement in _achievements.values) {
      if (achievement.isUnlocked) continue;

      _evaluateAchievement(achievement, resources, buildings, researchManager);

      if (achievement.currentAmount >= achievement.targetAmount) {
        achievement.isUnlocked = true;
        onAchievementUnlocked?.call(achievement);
      }
    }
  }

  void _evaluateAchievement(
    Achievement achievement,
    Resources resources,
    List<Building> buildings,
    ResearchManager researchManager,
  ) {
    switch (achievement.type) {
      case AchievementType.buildingCount:
        achievement.currentAmount = buildings.length;
      case AchievementType.populationReached:
        achievement.currentAmount = resources.population;
      case AchievementType.resourceAccumulated:
        if (achievement.targetId != null) {
          final type = ResourceType.values
              .where((r) => r.name == achievement.targetId)
              .firstOrNull;
          if (type != null) {
            achievement.currentAmount = (resources.resources[type] ?? 0)
                .toInt();
          }
        }
      case AchievementType.researchCompleted:
        int count = 0;
        for (final r in Research.availableResearch) {
          if (researchManager.isResearched(r.type)) count++;
        }
        achievement.currentAmount = count;
      case AchievementType.happinessReached:
        achievement.currentAmount = resources.happiness.toInt();
    }
  }

  // Serialization

  Map<String, dynamic> toJson() {
    final unlocked = <String>[];
    final progress = <String, int>{};

    for (final a in _achievements.values) {
      if (a.isUnlocked) unlocked.add(a.id);
      if (a.currentAmount > 0) progress[a.id] = a.currentAmount;
    }

    return {'unlocked': unlocked, 'progress': progress};
  }

  void loadFromJson(Map<String, dynamic> json) {
    // Reset all
    for (final a in _achievements.values) {
      a.isUnlocked = false;
      a.currentAmount = 0;
    }

    final unlocked = (json['unlocked'] as List?)?.cast<String>() ?? [];
    final progress = (json['progress'] as Map<String, dynamic>?) ?? {};

    for (final id in unlocked) {
      final a = _achievements[id];
      if (a == null) {
        debugPrint('Warning: Unknown achievement ID "$id", skipping.');
        continue;
      }
      a.isUnlocked = true;
    }

    for (final entry in progress.entries) {
      final a = _achievements[entry.key];
      if (a == null) continue;
      a.currentAmount = entry.value as int;
    }
  }
}
