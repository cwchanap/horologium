import 'package:flutter/foundation.dart';

import '../building/building.dart';
import '../research/research.dart';
import '../resources/resource_type.dart';
import '../resources/resources.dart';
import 'quest.dart';
import 'quest_objective.dart';

class QuestManager {
  final Map<String, Quest> _quests;
  ResearchManager? _researchManager;

  void Function(Quest quest)? onQuestCompleted;
  void Function(Quest quest)? onQuestAvailable;
  void Function(Quest quest)? onQuestProgressChanged;
  void Function(Quest quest, QuestStatus oldStatus, QuestStatus newStatus)?
  onQuestStatusChanged;

  /// Called when the set of quests changes structurally (i.e. rotating quests
  /// are added or removed). Listeners such as [QuestLogPage] use this to
  /// rebuild their list without waiting for a status-change event.
  void Function()? onQuestsRefreshed;

  QuestManager({required List<Quest> quests, ResearchManager? researchManager})
    : _quests = {for (final q in quests) q.id: q},
      _researchManager = researchManager;

  void setResearchManager(ResearchManager researchManager) {
    _researchManager = researchManager;
  }

  List<Quest> get quests => _quests.values.toList();

  /// Quests whose prerequisites are all claimed and status is available.
  /// Also filters out quests that require research the player hasn't completed yet.
  List<Quest> getAvailableQuests() {
    return _quests.values.where((q) {
      if (q.status != QuestStatus.available) return false;
      if (!_prerequisitesMet(q)) return false;
      return _researchPrerequisitesMet(q);
    }).toList();
  }

  List<Quest> getActiveQuests() =>
      _quests.values.where((q) => q.status == QuestStatus.active).toList();

  List<Quest> getCompletedQuests() =>
      _quests.values.where((q) => q.status == QuestStatus.completed).toList();

  List<Quest> getClaimedQuests() =>
      _quests.values.where((q) => q.status == QuestStatus.claimed).toList();

  bool get hasUnclaimedRewards => getCompletedQuests().isNotEmpty;

  /// Add procedurally-generated rotating quests.
  /// Skips quests that already exist with completed or claimed status to preserve
  /// player progress and prevent reward re-claiming.
  void addRotatingQuests(List<Quest> quests) {
    for (final q in quests) {
      final existing = _quests[q.id];
      // Skip if existing quest is completed or claimed to preserve progress
      if (existing != null &&
          (existing.status == QuestStatus.completed ||
              existing.status == QuestStatus.claimed)) {
        continue;
      }
      _quests[q.id] = q;
    }
    onQuestsRefreshed?.call();
  }

  /// Remove rotating quests by ID prefix (e.g. 'daily_', 'weekly_').
  /// When [preserveClaimed] is true, preserves quests that have been
  /// completed or claimed (to protect player progress and unclaimed rewards).
  void removeRotatingQuests(String prefix, {bool preserveClaimed = false}) {
    _quests.removeWhere((id, quest) {
      if (!id.startsWith(prefix)) return false;
      if (preserveClaimed &&
          (quest.status == QuestStatus.claimed ||
              quest.status == QuestStatus.completed)) {
        return false;
      }
      return true;
    });
    onQuestsRefreshed?.call();
  }

  void activateQuest(String questId) {
    final quest = _quests[questId];
    if (quest == null || quest.status != QuestStatus.available) return;
    if (!_prerequisitesMet(quest)) return;
    if (!_researchPrerequisitesMet(quest)) return;
    _setQuestStatus(quest, QuestStatus.active);
  }

  void _setQuestStatus(Quest quest, QuestStatus newStatus) {
    final oldStatus = quest.status;
    if (oldStatus == newStatus) return;
    quest.status = newStatus;
    onQuestStatusChanged?.call(quest, oldStatus, newStatus);
  }

  void checkProgress(
    Resources resources,
    List<Building> buildings,
    ResearchManager researchManager, [
    Map<String, int>? cumulativeBuildingCounts,
  ]) {
    // Auto-activate all available quests whose prerequisites are met so that
    // progress is evaluated without requiring an explicit activateQuest() call.
    for (final quest in getAvailableQuests()) {
      activateQuest(quest.id);
    }

    // Cache building counts for O(1) per-objective lookups
    final buildingCounts = <String, int>{};
    for (final b in buildings) {
      final key = b.type.name;
      buildingCounts[key] = (buildingCounts[key] ?? 0) + 1;
    }

    final completedThisTick = <Quest>[];

    for (final quest in getActiveQuests()) {
      bool wasComplete = quest.isComplete;
      bool progressChanged = false;
      for (final objective in quest.objectives) {
        final before = objective.currentAmount;
        _evaluateObjective(
          objective,
          resources,
          buildingCounts,
          cumulativeBuildingCounts,
          researchManager,
        );
        if (objective.currentAmount != before) {
          progressChanged = true;
        }
      }

      if (progressChanged) {
        onQuestProgressChanged?.call(quest);
      }

      if (!wasComplete && quest.isComplete) {
        _setQuestStatus(quest, QuestStatus.completed);
        completedThisTick.add(quest);
      }
    }

    for (final quest in completedThisTick) {
      onQuestCompleted?.call(quest);
    }
  }

  bool claimReward(String questId, Resources resources) {
    final quest = _quests[questId];
    if (quest == null || quest.status != QuestStatus.completed) return false;

    // Distribute resource rewards
    for (final entry in quest.reward.resources.entries) {
      final current = resources.resources[entry.key] ?? 0.0;
      resources.resources[entry.key] = current + entry.value;
    }

    // Distribute research points
    if (quest.reward.researchPoints > 0) {
      resources.resources[ResourceType.research] =
          (resources.resources[ResourceType.research] ?? 0.0) +
          quest.reward.researchPoints.toDouble();
    }

    _setQuestStatus(quest, QuestStatus.claimed);

    // Notify any quests that became available because this quest is now claimed
    // Use getAvailableQuests() to enforce both prerequisite and research gating
    for (final q in getAvailableQuests()) {
      if (q.prerequisiteQuestIds.contains(questId)) {
        onQuestAvailable?.call(q);
      }
    }

    return true;
  }

  bool _prerequisitesMet(Quest quest) {
    for (final prereqId in quest.prerequisiteQuestIds) {
      final prereq = _quests[prereqId];
      if (prereq == null || prereq.status != QuestStatus.claimed) return false;
    }
    return true;
  }

  /// Checks if all required research for a quest has been completed.
  /// Returns true if the quest has no research requirements or if all
  /// required research is completed.
  bool _researchPrerequisitesMet(Quest quest) {
    if (_researchManager == null) return true;
    for (final researchId in quest.requiredResearchIds) {
      if (!_researchManager!.isResearchedById(researchId)) {
        return false;
      }
    }
    return true;
  }

  void _evaluateObjective(
    QuestObjective objective,
    Resources resources,
    Map<String, int> buildingCounts,
    Map<String, int>? cumulativeBuildingCounts,
    ResearchManager researchManager,
  ) {
    switch (objective.type) {
      case QuestObjectiveType.buildBuilding:
        final lifetimeCount = cumulativeBuildingCounts?[objective.targetId];
        if (lifetimeCount != null) {
          if (objective.startingAmount == null) {
            final baseline = lifetimeCount - objective.currentAmount;
            objective.startingAmount = baseline < 0
                ? 0
                : (baseline > lifetimeCount ? lifetimeCount : baseline);
          }
          objective.currentAmount =
              lifetimeCount - (objective.startingAmount ?? lifetimeCount);
        } else {
          objective.currentAmount = buildingCounts[objective.targetId] ?? 0;
        }
        break;
      case QuestObjectiveType.accumulateResource:
        final type = ResourceType.values
            .where((r) => r.name == objective.targetId)
            .firstOrNull;
        if (type != null) {
          objective.currentAmount = (resources.resources[type] ?? 0).toInt();
        }
        break;
      case QuestObjectiveType.completeResearch:
        objective.currentAmount =
            researchManager.isResearchedById(objective.targetId) ? 1 : 0;
        break;
      case QuestObjectiveType.reachPopulation:
        objective.currentAmount = resources.population;
        break;
      case QuestObjectiveType.achieveHappiness:
        objective.currentAmount = resources.happiness.toInt();
        break;
      case QuestObjectiveType.upgradeBuilding:
        // Future: check max level of specific building type
        objective.currentAmount = 0;
        break;
    }
  }

  // Serialization

  Map<String, dynamic> toJson() {
    final active = <String>[];
    final completed = <String>[];
    final claimed = <String>[];
    final objectiveProgress = <String, Map<String, int>>{};
    final objectiveStartingAmounts = <String, Map<String, int>>{};
    final rotatingQuestDefinitions = <String, Map<String, dynamic>>{};

    for (final quest in _quests.values) {
      switch (quest.status) {
        case QuestStatus.active:
          active.add(quest.id);
          break;
        case QuestStatus.completed:
          completed.add(quest.id);
          break;
        case QuestStatus.claimed:
          claimed.add(quest.id);
          break;
        case QuestStatus.available:
          break;
      }

      // Save objective progress for active, completed, and claimed quests
      // Claimed quests need progress saved to avoid showing "0 / target" after load
      if (quest.status == QuestStatus.active ||
          quest.status == QuestStatus.completed ||
          quest.status == QuestStatus.claimed) {
        final progress = <String, int>{};
        final startingAmounts = <String, int>{};
        for (int i = 0; i < quest.objectives.length; i++) {
          progress[i.toString()] = quest.objectives[i].currentAmount;
          final startingAmount = quest.objectives[i].startingAmount;
          if (startingAmount != null) {
            startingAmounts[i.toString()] = startingAmount;
          }
        }
        objectiveProgress[quest.id] = progress;
        if (startingAmounts.isNotEmpty) {
          objectiveStartingAmounts[quest.id] = startingAmounts;
        }
      }

      // Save full definition for rotating quests (daily_, weekly_)
      // to prevent objective/reward mismatch after research changes
      if (quest.id.startsWith('daily_') || quest.id.startsWith('weekly_')) {
        rotatingQuestDefinitions[quest.id] = quest.toJson();
      }
    }

    return {
      'active': active,
      'completed': completed,
      'claimed': claimed,
      'objectiveProgress': objectiveProgress,
      'objectiveStartingAmounts': objectiveStartingAmounts,
      'rotatingQuestDefinitions': rotatingQuestDefinitions,
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    // First, restore rotating quest definitions from saved data
    // This ensures the correct objectives/rewards are used even if research state changed
    final rawDefinitions = json['rotatingQuestDefinitions'];
    if (rawDefinitions is Map<String, dynamic>) {
      for (final entry in rawDefinitions.entries) {
        final questId = entry.key;
        if (entry.value is Map<String, dynamic>) {
          final quest = Quest.fromJson(entry.value as Map<String, dynamic>);
          _quests[questId] = quest;
        }
      }
    }

    // Reset all quests to available
    for (final quest in _quests.values) {
      quest.status = QuestStatus.available;
      for (final obj in quest.objectives) {
        obj.currentAmount = 0;
        obj.startingAmount = null;
      }
    }

    // Parse active, completed, claimed lists defensively
    final List<String> active = [];
    final rawActive = json['active'];
    if (rawActive is List) {
      for (final item in rawActive) {
        if (item is String) {
          active.add(item);
        } else if (item != null) {
          active.add(item.toString());
        }
      }
    }

    final List<String> completed = [];
    final rawCompleted = json['completed'];
    if (rawCompleted is List) {
      for (final item in rawCompleted) {
        if (item is String) {
          completed.add(item);
        } else if (item != null) {
          completed.add(item.toString());
        }
      }
    }

    final List<String> claimed = [];
    final rawClaimed = json['claimed'];
    if (rawClaimed is List) {
      for (final item in rawClaimed) {
        if (item is String) {
          claimed.add(item);
        } else if (item != null) {
          claimed.add(item.toString());
        }
      }
    }

    // Parse objective progress map defensively
    final Map<String, dynamic> objectiveProgress = {};
    final rawObjectiveProgress = json['objectiveProgress'];
    if (rawObjectiveProgress is Map<String, dynamic>) {
      objectiveProgress.addAll(rawObjectiveProgress);
    }

    final Map<String, dynamic> objectiveStartingAmounts = {};
    final rawObjectiveStartingAmounts = json['objectiveStartingAmounts'];
    if (rawObjectiveStartingAmounts is Map<String, dynamic>) {
      objectiveStartingAmounts.addAll(rawObjectiveStartingAmounts);
    }

    for (final id in claimed) {
      final quest = _quests[id];
      if (quest == null) {
        debugPrint('Warning: Unknown claimed quest ID "$id", skipping.');
        continue;
      }
      _setQuestStatus(quest, QuestStatus.claimed);
    }

    for (final id in completed) {
      final quest = _quests[id];
      if (quest == null) {
        debugPrint('Warning: Unknown completed quest ID "$id", skipping.');
        continue;
      }
      quest.status = QuestStatus.completed;
    }

    for (final id in active) {
      final quest = _quests[id];
      if (quest == null) {
        debugPrint('Warning: Unknown active quest ID "$id", skipping.');
        continue;
      }
      quest.status = QuestStatus.active;
    }

    // Restore objective progress
    for (final entry in objectiveProgress.entries) {
      final quest = _quests[entry.key];
      if (quest == null) continue;
      if (entry.value is! Map<String, dynamic>) continue;
      final progress = entry.value as Map<String, dynamic>;
      for (final pEntry in progress.entries) {
        final index = int.tryParse(pEntry.key);
        if (index == null || index < 0 || index >= quest.objectives.length) {
          continue;
        }
        final raw = pEntry.value;
        int? safeInt;
        if (raw is int) {
          safeInt = raw;
        } else if (raw is num) {
          safeInt = raw.toInt();
        } else if (raw is String) {
          safeInt = int.tryParse(raw);
        }
        final restoredAmount = safeInt ?? 0;
        quest.objectives[index].currentAmount = restoredAmount < 0
            ? 0
            : restoredAmount;
      }
    }

    for (final entry in objectiveStartingAmounts.entries) {
      final quest = _quests[entry.key];
      if (quest == null) continue;
      if (entry.value is! Map<String, dynamic>) continue;
      final startingAmounts = entry.value as Map<String, dynamic>;
      for (final pEntry in startingAmounts.entries) {
        final index = int.tryParse(pEntry.key);
        if (index == null || index < 0 || index >= quest.objectives.length) {
          continue;
        }
        final raw = pEntry.value;
        int? safeInt;
        if (raw is int) {
          safeInt = raw;
        } else if (raw is num) {
          safeInt = raw.toInt();
        } else if (raw is String) {
          safeInt = int.tryParse(raw);
        }
        if (safeInt == null) continue;
        quest.objectives[index].startingAmount = safeInt < 0 ? 0 : safeInt;
      }
    }
  }
}
