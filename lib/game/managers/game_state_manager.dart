import 'dart:async' as async;
import 'package:flutter/material.dart';

import '../achievements/achievement_manager.dart';
import '../building/building.dart';
import '../quests/daily_quest_generator.dart';
import '../quests/quest_manager.dart';
import '../research/research.dart';
import '../resources/resources.dart';
import '../services/resource_service.dart';

class GameStateManager {
  final Resources resources;
  final ResearchManager researchManager = ResearchManager();
  final BuildingLimitManager buildingLimitManager = BuildingLimitManager();
  QuestManager? questManager;
  AchievementManager? achievementManager;

  /// Tracks the last daily/weekly seed so we know when to refresh.
  int _lastDailySeed = 0;
  int _lastWeeklySeed = 0;

  async.Timer? _resourceTimer;

  GameStateManager({required this.resources});

  void startResourceGeneration(
    List<Building> Function() getBuildingsCallback,
    VoidCallback onUpdate,
  ) {
    _resourceTimer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
      final buildings = getBuildingsCallback();
      ResourceService.updateResources(resources, buildings);

      // Check quest and achievement progress
      questManager?.checkProgress(resources, buildings, researchManager);
      achievementManager?.checkProgress(resources, buildings, researchManager);

      onUpdate();
    });
  }

  void stopResourceGeneration() {
    _resourceTimer?.cancel();
    _resourceTimer = null;
  }

  /// Refresh daily and weekly rotating quests if the date-based seed has changed.
  /// Returns true if any quests were refreshed.
  bool refreshRotatingQuests({DateTime? now}) {
    final qm = questManager;
    if (qm == null) return false;

    final date = now ?? DateTime.now();
    final dailySeed = DailyQuestGenerator.dailySeedForDate(date);
    final weeklySeed = DailyQuestGenerator.weeklySeedForDate(date);

    bool refreshed = false;

    if (dailySeed != _lastDailySeed) {
      qm.removeRotatingQuests('daily_', preserveClaimed: true);
      qm.addRotatingQuests(DailyQuestGenerator.generateDaily(seed: dailySeed));
      _lastDailySeed = dailySeed;
      refreshed = true;
    }

    if (weeklySeed != _lastWeeklySeed) {
      qm.removeRotatingQuests('weekly_', preserveClaimed: true);
      qm.addRotatingQuests(
        DailyQuestGenerator.generateWeekly(seed: weeklySeed),
      );
      _lastWeeklySeed = weeklySeed;
      refreshed = true;
    }

    return refreshed;
  }

  void dispose() {
    stopResourceGeneration();
  }
}
