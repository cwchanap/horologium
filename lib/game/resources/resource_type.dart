import 'package:collection/collection.dart';
import 'resource_category.dart';

enum ResourceType {
  cash,
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
  wheat,
  corn,
  rice,
  barley,
  flour,
  cornmeal,
  polishedRice,
  maltedBarley,
  bread,
  pastries,
}

class Resource {
  final ResourceType type;
  final String name;
  final double value;
  final ResourceCategory category;

  const Resource({
    required this.type,
    required this.name,
    required this.value,
    required this.category,
  });
}

class ResourceRegistry {
  static final List<Resource> availableResources = [
    Resource(type: ResourceType.cash, name: 'Cash', value: 1, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.gold, name: 'Gold', value: 1, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.wood, name: 'Wood', value: 1, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.coal, name: 'Coal', value: 1, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.electricity, name: 'Electricity', value: 1, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.research, name: 'Research', value: 1, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.water, name: 'Water', value: 0.5, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.planks, name: 'Planks', value: 10, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.stone, name: 'Stone', value: 1, category: ResourceCategory.rawMaterials),
    Resource(type: ResourceType.wheat, name: 'Wheat', value: 1, category: ResourceCategory.foodResources),
    Resource(type: ResourceType.corn, name: 'Corn', value: 1, category: ResourceCategory.foodResources),
    Resource(type: ResourceType.rice, name: 'Rice', value: 1, category: ResourceCategory.foodResources),
    Resource(type: ResourceType.barley, name: 'Barley', value: 1, category: ResourceCategory.foodResources),
    Resource(type: ResourceType.flour, name: 'Flour', value: 5, category: ResourceCategory.stapleGrains),
    Resource(type: ResourceType.cornmeal, name: 'Cornmeal', value: 4, category: ResourceCategory.stapleGrains),
    Resource(type: ResourceType.polishedRice, name: 'Polished Rice', value: 2, category: ResourceCategory.stapleGrains),
    Resource(type: ResourceType.maltedBarley, name: 'Malted Barley', value: 2, category: ResourceCategory.stapleGrains),
    Resource(type: ResourceType.bread, name: 'Bread', value: 10, category: ResourceCategory.refinement),
    Resource(type: ResourceType.pastries, name: 'Pastries', value: 15, category: ResourceCategory.refinement),
  ];

  static Resource? find(ResourceType type) {
    return availableResources.firstWhereOrNull((r) => r.type == type);
  }
}
enum BakeryProduct {
  bread,
  pastries,
}

enum CropType {
  wheat,
  corn,
  rice,
  barley,
}