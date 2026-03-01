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

    // Parse unlocked list defensively
    final List<String> unlocked = [];
    final rawUnlocked = json['unlocked'];
    if (rawUnlocked is List) {
      for (final item in rawUnlocked) {
        if (item is String) {
          unlocked.add(item);
        } else if (item != null) {
          unlocked.add(item.toString());
        }
      }
    }

    // Parse progress map defensively (already defensive, but using same pattern)
    final Map<String, dynamic> progress = {};
    final rawProgress = json['progress'];
    if (rawProgress is Map<String, dynamic>) {
      progress.addAll(rawProgress);
    }

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

      // Parse progress value defensively
      int? value;
      final raw = entry.value;
      if (raw is int) {
        value = raw;
      } else if (raw is num) {
        value = raw.toInt();
      } else if (raw is String) {
        value = int.tryParse(raw);
      }
      // Skip unknown or unparsable values
      if (value == null) continue;

      // Clamp to valid range: >= 0 and <= targetAmount
      final clamped = value.clamp(0, a.targetAmount);
      a.currentAmount = clamped;
    }
  }
}
