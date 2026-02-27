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
    final resourcesJson = json['resources'] as Map<String, dynamic>? ?? {};
    final resources = <ResourceType, double>{};
    for (final entry in resourcesJson.entries) {
      final type = ResourceType.values
          .where((t) => t.name == entry.key)
          .firstOrNull;
      if (type != null) {
        resources[type] = (entry.value as num).toDouble();
      }
    }
    return QuestReward(
      resources: resources,
      researchPoints: json['researchPoints'] as int? ?? 0,
    );
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
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      objectives: (json['objectives'] as List)
          .map((o) => QuestObjective.fromJson(o as Map<String, dynamic>))
          .toList(),
      reward: QuestReward.fromJson(json['reward'] as Map<String, dynamic>),
      prerequisiteQuestIds:
          (json['prerequisiteQuestIds'] as List?)?.cast<String>() ?? [],
      status: QuestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QuestStatus.available,
      ),
    );
  }
}
