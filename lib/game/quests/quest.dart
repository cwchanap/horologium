import '../resources/resource_type.dart';
import 'quest_objective.dart';

enum QuestStatus { available, active, completed, claimed }

class QuestReward {
  final Map<ResourceType, double> resources;
  final int researchPoints;

  const QuestReward({this.resources = const {}, this.researchPoints = 0});

  Map<String, dynamic> toJson() => {
    'resources': resources.map((key, value) => MapEntry(key.name, value)),
    'researchPoints': researchPoints,
  };

  factory QuestReward.fromJson(Map<String, dynamic> json) {
    final resources = <ResourceType, double>{};
    final resourcesValue = json['resources'];
    if (resourcesValue is Map) {
      for (final entry in resourcesValue.entries) {
        final type = ResourceType.values
            .where((t) => t.name == entry.key)
            .firstOrNull;
        if (type == null) continue;

        final value = entry.value;
        double parsedValue;
        if (value is num) {
          parsedValue = value.toDouble();
        } else if (value is String) {
          parsedValue = double.tryParse(value) ?? 0.0;
        } else {
          parsedValue = 0.0;
        }
        resources[type] = parsedValue;
      }
    }

    final researchPointsValue = json['researchPoints'];
    int researchPoints;
    if (researchPointsValue is int) {
      researchPoints = researchPointsValue;
    } else if (researchPointsValue is num) {
      researchPoints = researchPointsValue.toInt();
    } else if (researchPointsValue is String) {
      researchPoints = int.tryParse(researchPointsValue) ?? 0;
    } else {
      researchPoints = 0;
    }

    return QuestReward(resources: resources, researchPoints: researchPoints);
  }
}

class Quest {
  final String id;
  final String name;
  final String description;
  final List<QuestObjective> objectives;
  final QuestReward reward;
  final List<String> prerequisiteQuestIds;
  QuestStatus status;

  Quest({
    required this.id,
    required this.name,
    required this.description,
    required this.objectives,
    required this.reward,
    this.prerequisiteQuestIds = const [],
    this.status = QuestStatus.available,
  });

  bool get isComplete => objectives.every((o) => o.isComplete);

  double get progress {
    if (objectives.isEmpty) return 1.0;
    return objectives.map((o) => o.progress).reduce((a, b) => a + b) /
        objectives.length;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'objectives': objectives.map((o) => o.toJson()).toList(),
    'reward': reward.toJson(),
    'prerequisiteQuestIds': prerequisiteQuestIds,
    'status': status.name,
  };

  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      objectives: (json['objectives'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(QuestObjective.fromJson)
          .toList(),
      reward: json['reward'] is Map<String, dynamic>
          ? QuestReward.fromJson(json['reward'] as Map<String, dynamic>)
          : const QuestReward(),
      prerequisiteQuestIds:
          (json['prerequisiteQuestIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          [],
      status: QuestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QuestStatus.available,
      ),
    );
  }
}
