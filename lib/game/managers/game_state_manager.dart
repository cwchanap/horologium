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
  ResearchManager researchManager =
      ResearchManager(); // Mutable because loaded Planet state can replace it during initialization/restore.
  final BuildingLimitManager buildingLimitManager = BuildingLimitManager();
  QuestManager? questManager;
  AchievementManager? achievementManager;

  /// Tracks the last daily/weekly seed so we know when to refresh.
  int _lastDailySeed = 0;
  int _lastWeeklySeed = 0;

  /// Initialize seeds from loaded save data to prevent regeneration on first refresh.
  /// Pass the last saved seeds from [SaveService] to properly detect date changes.
  void initializeSeedsFromLoadedData(
    int loadedDailySeed,
    int loadedWeeklySeed,
  ) {
    _lastDailySeed = loadedDailySeed;
    _lastWeeklySeed = loadedWeeklySeed;
  }

  /// Extracts seeds from existing rotating quest IDs and updates internal seeds.
  /// This should be called after quest manager is set but before refreshRotatingQuests()
  /// to properly handle migration from old saves where seeds were not persisted.
  void recoverSeedsFromExistingQuests() {
    final qm = questManager;
    if (qm == null) return;

    final allQuestIds = qm.quests.map((q) => q.id);

    // Only recover if seed is 0 (old save or missing seed data)
    if (_lastDailySeed == 0) {
      final dailySeed = _extractSeedFromQuestIds(allQuestIds, 'daily_');
      if (dailySeed != null) {
        _lastDailySeed = dailySeed;
      }
    }

    if (_lastWeeklySeed == 0) {
      final weeklySeed = _extractSeedFromQuestIds(allQuestIds, 'weekly_');
      if (weeklySeed != null) {
        _lastWeeklySeed = weeklySeed;
      }
    }
  }

  /// Extract the seed from quest IDs matching the given prefix.
  /// Returns null if no matching quest found.
  int? _extractSeedFromQuestIds(Iterable<String> questIds, String prefix) {
    int? latestSeed;
    for (final id in questIds) {
      if (id.startsWith(prefix)) {
        final parts = id.split('_');
        if (parts.length >= 2) {
          final seed = int.tryParse(parts[1]);
          if (seed != null) {
            // Track the maximum (latest) seed
            if (latestSeed == null || seed > latestSeed) {
              latestSeed = seed;
            }
          }
        }
      }
    }
    return latestSeed;
  }

  async.Timer? _resourceTimer;

  GameStateManager({required this.resources});

  void startResourceGeneration(
    List<Building> Function() getBuildingsCallback,
    VoidCallback onUpdate, [
    Map<String, int>? cumulativeBuildingCounts,
    int? totalBuildingsPlaced,
  ]) {
    _resourceTimer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        final buildings = getBuildingsCallback();
        ResourceService.updateResources(resources, buildings);

        // Check quest and achievement progress
        questManager?.checkProgress(
          resources,
          buildings,
          researchManager,
          cumulativeBuildingCounts,
        );
        achievementManager?.checkProgress(
          resources,
          buildings,
          researchManager,
          totalBuildingsPlaced,
        );

        onUpdate();
      } catch (e, stackTrace) {
        debugPrint('Resource generation tick failed: $e\n$stackTrace');
        // Do not rethrow: re-throwing would cancel the Timer.periodic permanently.
      }
    });
  }

  void stopResourceGeneration() {
    _resourceTimer?.cancel();
    _resourceTimer = null;
  }

  /// Check quest and achievement progress with the provided buildings list.
  /// This should be called before saving when buildings, resources, or research
  /// have changed outside the periodic tick (e.g., building placement, research
  /// completion, reward claiming) to ensure progress is not lost on app close.
  void checkProgress(
    List<Building> buildings, [
    Map<String, int>? cumulativeBuildingCounts,
    int? totalBuildingsPlaced,
  ]) {
    questManager?.checkProgress(
      resources,
      buildings,
      researchManager,
      cumulativeBuildingCounts,
    );
    achievementManager?.checkProgress(
      resources,
      buildings,
      researchManager,
      totalBuildingsPlaced,
    );
  }

  /// Refresh daily and weekly rotating quests if the date-based seed has changed.
  /// Returns true if any quests were refreshed.
  ///
  /// If [onSeedsChanged] is provided and quests were refreshed, it will be called
  /// to persist the new seed values. This ensures seeds stay synchronized across
  /// session boundaries, preventing unnecessary quest regeneration on re-entry.
  bool refreshRotatingQuests({
    DateTime? now,
    void Function(int dailySeed, int weeklySeed)? onSeedsChanged,
  }) {
    final qm = questManager;
    if (qm == null) return false;

    final date = now ?? DateTime.now();
    final dailySeed = DailyQuestGenerator.dailySeedForDate(date);
    final weeklySeed = DailyQuestGenerator.weeklySeedForDate(date);

    bool refreshed = false;

    if (dailySeed != _lastDailySeed) {
      qm.removeRotatingQuests('daily_', preserveClaimed: true);
      qm.addRotatingQuests(
        DailyQuestGenerator.generateDaily(
          seed: dailySeed,
          researchManager: researchManager,
        ),
      );
      _lastDailySeed = dailySeed;
      refreshed = true;
    }

    if (weeklySeed != _lastWeeklySeed) {
      qm.removeRotatingQuests('weekly_', preserveClaimed: true);
      qm.addRotatingQuests(
        DailyQuestGenerator.generateWeekly(
          seed: weeklySeed,
          researchManager: researchManager,
        ),
      );
      _lastWeeklySeed = weeklySeed;
      refreshed = true;
    }

    // Persist seeds if changed and callback provided
    if (refreshed && onSeedsChanged != null) {
      onSeedsChanged(dailySeed, weeklySeed);
    }

    return refreshed;
  }

  void dispose() {
    stopResourceGeneration();
  }
}
