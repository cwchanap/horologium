import 'package:flutter/foundation.dart';

import '../building/building.dart';
import '../research/research.dart';
import '../resources/resource_type.dart';
import '../resources/resources.dart';
import 'quest.dart';
import 'quest_objective.dart';

class QuestManager {
  final Map<String, Quest> _quests;

  void Function(Quest quest)? onQuestCompleted;
  void Function(Quest quest)? onQuestAvailable;

  QuestManager({required List<Quest> quests})
    : _quests = {for (final q in quests) q.id: q};

  List<Quest> get quests => _quests.values.toList();

  /// Quests whose prerequisites are all claimed and status is available.
  List<Quest> getAvailableQuests() {
    return _quests.values.where((q) {
      if (q.status != QuestStatus.available) return false;
      return _prerequisitesMet(q);
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
  void addRotatingQuests(List<Quest> quests) {
    for (final q in quests) {
      _quests[q.id] = q;
    }
  }

  /// Remove rotating quests by ID prefix (e.g. 'daily_', 'weekly_').
  /// Optionally preserve quests that have already been claimed.
  void removeRotatingQuests(String prefix, {bool preserveClaimed = false}) {
    _quests.removeWhere((id, quest) {
      if (!id.startsWith(prefix)) return false;
      if (preserveClaimed && quest.status == QuestStatus.claimed) return false;
      return true;
    });
  }

  void activateQuest(String questId) {
    final quest = _quests[questId];
    if (quest == null || quest.status != QuestStatus.available) return;
    if (!_prerequisitesMet(quest)) return;
    quest.status = QuestStatus.active;
  }

  void checkProgress(
    Resources resources,
    List<Building> buildings,
    ResearchManager researchManager,
  ) {
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
      for (final objective in quest.objectives) {
        _evaluateObjective(
          objective,
          resources,
          buildingCounts,
          researchManager,
        );
      }

      if (!wasComplete && quest.isComplete) {
        quest.status = QuestStatus.completed;
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
      final current = resources.resources[entry.key] ?? 0;
      resources.resources[entry.key] = current + entry.value;
    }

    // Distribute research points
    if (quest.reward.researchPoints > 0) {
      resources.resources[ResourceType.research] =
          (resources.resources[ResourceType.research] ?? 0) +
          quest.reward.researchPoints;
    }

    quest.status = QuestStatus.claimed;

    // Notify any quests that became available because this quest is now claimed
    for (final q in _quests.values) {
      if (q.status == QuestStatus.available &&
          q.prerequisiteQuestIds.contains(questId) &&
          _prerequisitesMet(q)) {
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

  void _evaluateObjective(
    QuestObjective objective,
    Resources resources,
    Map<String, int> buildingCounts,
    ResearchManager researchManager,
  ) {
    switch (objective.type) {
      case QuestObjectiveType.buildBuilding:
        objective.currentAmount = buildingCounts[objective.targetId] ?? 0;
      case QuestObjectiveType.accumulateResource:
        final type = ResourceType.values
            .where((r) => r.name == objective.targetId)
            .firstOrNull;
        if (type != null) {
          objective.currentAmount = (resources.resources[type] ?? 0).toInt();
        }
      case QuestObjectiveType.completeResearch:
        objective.currentAmount =
            researchManager.isResearchedById(objective.targetId) ? 1 : 0;
      case QuestObjectiveType.reachPopulation:
        objective.currentAmount = resources.population;
      case QuestObjectiveType.achieveHappiness:
        objective.currentAmount = resources.happiness.toInt();
      case QuestObjectiveType.upgradeBuilding:
        // Future: check max level of specific building type
        objective.currentAmount = 0;
    }
  }

  // Serialization

  Map<String, dynamic> toJson() {
    final active = <String>[];
    final completed = <String>[];
    final claimed = <String>[];
    final objectiveProgress = <String, Map<String, int>>{};

    for (final quest in _quests.values) {
      switch (quest.status) {
        case QuestStatus.active:
          active.add(quest.id);
        case QuestStatus.completed:
          completed.add(quest.id);
        case QuestStatus.claimed:
          claimed.add(quest.id);
        case QuestStatus.available:
          break;
      }

      // Save objective progress for active and completed quests
      if (quest.status == QuestStatus.active ||
          quest.status == QuestStatus.completed) {
        final progress = <String, int>{};
        for (int i = 0; i < quest.objectives.length; i++) {
          progress[i.toString()] = quest.objectives[i].currentAmount;
        }
        objectiveProgress[quest.id] = progress;
      }
    }

    return {
      'active': active,
      'completed': completed,
      'claimed': claimed,
      'objectiveProgress': objectiveProgress,
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    // Reset all quests to available
    for (final quest in _quests.values) {
      quest.status = QuestStatus.available;
      for (final obj in quest.objectives) {
        obj.currentAmount = 0;
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

    for (final id in claimed) {
      final quest = _quests[id];
      if (quest == null) {
        debugPrint('Warning: Unknown claimed quest ID "$id", skipping.');
        continue;
      }
      quest.status = QuestStatus.claimed;
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
        quest.objectives[index].currentAmount = safeInt ?? 0;
      }
    }
  }
}
