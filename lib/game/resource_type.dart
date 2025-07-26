
import 'package:collection/collection.dart';

enum ResourceType {
  money,
  population,
  availableWorkers,
  gold,
  wood,
  coal,
  electricity,
  research,
  water,
  planks,
  stone,
}

class Resource {
  final ResourceType type;
  final String name;
  final double value;

  const Resource({
    required this.type,
    required this.name,
    required this.value,
  });
}

class ResourceRegistry {
  static final List<Resource> availableResources = [
    Resource(type: ResourceType.money, name: 'Money', value: 1),
    Resource(type: ResourceType.gold, name: 'Gold', value: 1),
    Resource(type: ResourceType.wood, name: 'Wood', value: 1),
    Resource(type: ResourceType.coal, name: 'Coal', value: 1),
    Resource(type: ResourceType.electricity, name: 'Electricity', value: 1),
    Resource(type: ResourceType.research, name: 'Research', value: 1),
    Resource(type: ResourceType.water, name: 'Water', value: 0.5),
    Resource(type: ResourceType.planks, name: 'Planks', value: 10),
    Resource(type: ResourceType.stone, name: 'Stone', value: 1),
  ];

  static Resource? find(ResourceType type) {
    return availableResources.firstWhereOrNull((r) => r.type == type);
  }
}
