import 'package:flutter/material.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/building/crop_type.dart';

enum BuildingType {
  powerPlant,
  researchLab,
  house,
  largeHouse,
  goldMine,
  woodFactory,
  coalMine,
  waterTreatment,
  sawmill,
  quarry,
  field,
  windMill,
  grinderMill,
  riceHuller,
  maltHouse,
}

class Building {
  final BuildingType type;
  final String name;
  final String description;
  final IconData icon;
  final String? assetPath;
  final Color color;
  final int baseCost;
  final Map<String, double> baseGeneration;
  final Map<String, double> baseConsumption;
  final int basePopulation;
  final int maxLevel;
  final int gridSize;
  final int baseBuildingLimit;
  final int requiredWorkers;
  final BuildingCategory category;
  int level;
  int assignedWorkers;

  Building({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.assetPath,
    required this.color,
    required this.baseCost,
    this.baseGeneration = const {},
    this.baseConsumption = const {},
    this.basePopulation = 0,
    this.maxLevel = 5,
    this.gridSize = 4,
    this.baseBuildingLimit = 4,
    this.requiredWorkers = 1,
    required this.category,
    this.level = 1,
  }) : assignedWorkers = 0;

  // Getters for level-scaled values
  int get cost => baseCost * level;
  Map<String, double> get generation => baseGeneration.map((key, value) => MapEntry(key, value * level));
  Map<String, double> get consumption => baseConsumption.map((key, value) => MapEntry(key, value * level));
  int get accommodationCapacity => basePopulation * level; // For houses only
  
  bool get hasWorkers => assignedWorkers >= requiredWorkers;
  bool get canAssignWorker => assignedWorkers < requiredWorkers;
  
  void assignWorker() {
    if (canAssignWorker) {
      assignedWorkers++;
    }
  }
  
  void unassignWorker() {
    if (assignedWorkers > 0) {
      assignedWorkers--;
    }
  }
  
  // Upgrade cost is the cost of the next level
  int get upgradeCost => baseCost * (level + 1);
  
  bool get canUpgrade => level < maxLevel;
  
  void upgrade() {
    if (canUpgrade) {
      level++;
    }
  }
}

class Field extends Building {
  CropType cropType;

  Field({
    required BuildingType type,
    required String name,
    required String description,
    required IconData icon,
    String? assetPath,
    required Color color,
    required int baseCost,
    Map<String, double> baseGeneration = const {},
    Map<String, double> baseConsumption = const {},
    int basePopulation = 0,
    int maxLevel = 5,
    int gridSize = 4,
    int baseBuildingLimit = 4,
    int requiredWorkers = 1,
    required BuildingCategory category,
    int level = 1,
    this.cropType = CropType.wheat,
  }) : super(
          type: type,
          name: name,
          description: description,
          icon: icon,
          assetPath: assetPath,
          color: color,
          baseCost: baseCost,
          baseGeneration: baseGeneration,
          baseConsumption: baseConsumption,
          basePopulation: basePopulation,
          maxLevel: maxLevel,
          gridSize: gridSize,
          baseBuildingLimit: baseBuildingLimit,
          requiredWorkers: requiredWorkers,
          category: category,
          level: level,
        );

  @override
  Map<String, double> get generation {
    return {cropType.toString().split('.').last: 1.0 * level};
  }
}

class BuildingLimitManager {
  final Map<BuildingType, int> _limitUpgrades = {};
  
  int getBuildingLimit(BuildingType type) {
    final baseLimit = BuildingRegistry.availableBuildings
        .firstWhere((b) => b.type == type)
        .baseBuildingLimit;
    return baseLimit + (_limitUpgrades[type] ?? 0);
  }
  
  void increaseBuildingLimit(BuildingType type, int amount) {
    _limitUpgrades.update(type, (value) => value + amount, ifAbsent: () => amount);
  }
  
  Map<BuildingType, int> get limitUpgrades => Map.from(_limitUpgrades);
  
  void loadFromMap(Map<String, int> upgrades) {
    _limitUpgrades.clear();
    for (final entry in upgrades.entries) {
      final type = BuildingType.values.firstWhere(
        (t) => t.toString().split('.').last == entry.key,
        orElse: () => BuildingType.powerPlant,
      );
      _limitUpgrades[type] = entry.value;
    }
  }
  
  Map<String, int> toMap() {
    return _limitUpgrades.map(
      (key, value) => MapEntry(key.toString().split('.').last, value),
    );
  }
}

class BuildingRegistry {
  static final List<Building> availableBuildings = [
    Building(
      type: BuildingType.powerPlant,
      name: 'Power Plant',
      description: 'Generates energy for your colony',
      icon: Icons.bolt,
      color: Colors.yellow,
      baseCost: 100,
      baseGeneration: {'electricity': 1},
      baseConsumption: {'coal': 1},
      maxLevel: 5,
      requiredWorkers: 1,
      category: BuildingCategory.services,
    ),
    Building(
      type: BuildingType.researchLab,
      name: 'Research Lab',
      description: 'Unlocks new technologies',
      icon: Icons.science,
      assetPath: Assets.researchLab,
      color: Colors.blue,
      baseCost: 200,
      baseGeneration: {'research': 0.1},
      maxLevel: 5,
      requiredWorkers: 1,
      category: BuildingCategory.services,
    ),
    Building(
      type: BuildingType.house,
      name: 'House',
      description: 'Accommodates population and generates money',
      icon: Icons.house,
      assetPath: Assets.house,
      color: Colors.green,
      baseCost: 120,
      basePopulation: 2,
      baseGeneration: {'money': 1},
      baseConsumption: {'wood': 1, 'water': 1},
      maxLevel: 5,
      requiredWorkers: 0,
      category: BuildingCategory.residential,
    ),
    Building(
      type: BuildingType.largeHouse,
      name: 'Large House',
      description: 'Modern housing with more population accommodation and money generation',
      icon: Icons.apartment,
      color: Colors.lightGreen,
      baseCost: 250,
      basePopulation: 8,
      baseGeneration: {'money': 3},
      baseConsumption: {'electricity': 1, 'water': 2},
      maxLevel: 5,
      requiredWorkers: 0,
      category: BuildingCategory.residential,
    ),
    Building(
      type: BuildingType.goldMine,
      name: 'Gold Mine',
      description: 'Generates gold',
      icon: Icons.attach_money,
      assetPath: Assets.goldMine,
      color: Colors.amber,
      baseCost: 300,
      baseGeneration: {'gold': 0.1},
      maxLevel: 5,
      requiredWorkers: 1,
      category: BuildingCategory.rawMaterials,
    ),
    Building(
      type: BuildingType.woodFactory,
      name: 'Wood Factory',
      description: 'Produces wood',
      icon: Icons.park,
      assetPath: Assets.woodFactory,
      color: Colors.brown,
      baseCost: 80,
      baseGeneration: {'wood': 1},
      maxLevel: 5,
      requiredWorkers: 1,
      category: BuildingCategory.rawMaterials,
    ),
    Building(
      type: BuildingType.coalMine,
      name: 'Coal Mine',
      description: 'Produces coal',
      icon: Icons.fireplace,
      assetPath: Assets.coalMine,
      color: Colors.grey,
      baseCost: 90,
      baseGeneration: {'coal': 1},
      maxLevel: 5,
      requiredWorkers: 1,
      category: BuildingCategory.rawMaterials,
    ),
    Building(
      type: BuildingType.waterTreatment,
      name: 'Water Treatment Plant',
      description: 'Produces clean water',
      icon: Icons.water_drop,
      assetPath: Assets.waterTreatmentPlant,
      color: Colors.lightBlue,
      baseCost: 150,
      baseGeneration: {'water': 2},
      maxLevel: 5,
      requiredWorkers: 1,
      category: BuildingCategory.foodResources,
    ),
    Building(
      type: BuildingType.sawmill,
      name: 'Sawmill',
      description: 'Converts wood into planks',
      icon: Icons.home_work,
      color: Colors.brown,
      baseCost: 100,
      baseConsumption: {'wood': 10},
      baseGeneration: {'planks': 1},
      requiredWorkers: 1,
      category: BuildingCategory.primaryFactory,
    ),
    Building(
      type: BuildingType.quarry,
      name: 'Quarry',
      description: 'Produces stone',
      icon: Icons.landscape,
      assetPath: Assets.quarry,
      color: Colors.grey,
      baseCost: 150,
      baseGeneration: {'stone': 1},
      requiredWorkers: 1,
      category: BuildingCategory.rawMaterials,
    ),
    Field(
      type: BuildingType.field,
      name: 'Field',
      description: 'Grows crops',
      icon: Icons.grass,
      color: Colors.lightGreen,
      baseCost: 50,
      requiredWorkers: 1,
      category: BuildingCategory.foodResources,
    ),
    Building(
      type: BuildingType.windMill,
      name: 'Wind Mill',
      description: 'Produce 1 flour from 5 wheat',
      icon: Icons.wind_power,
      assetPath: Assets.windMill,
      color: Colors.brown,
      baseCost: 100,
      baseConsumption: {'wheat': 5},
      baseGeneration: {'flour': 1},
      requiredWorkers: 1,
      category: BuildingCategory.processing,
    ),
    Building(
      type: BuildingType.grinderMill,
      name: 'Grinder Mill',
      description: 'Product 1 cornmeal from 4 corn',
      icon: Icons.grain,
      assetPath: Assets.grinderMill,
      color: Colors.brown,
      baseCost: 100,
      baseConsumption: {'corn': 4},
      baseGeneration: {'cornmeal': 1},
      requiredWorkers: 1,
      category: BuildingCategory.processing,
    ),
    Building(
      type: BuildingType.riceHuller,
      name: 'Rice Huller',
      description: 'Produce 1 polished rice from 2 rice',
      icon: Icons.grain,
      assetPath: Assets.riceHuller,
      color: Colors.brown,
      baseCost: 100,
      baseConsumption: {'rice': 2},
      baseGeneration: {'polishedRice': 1},
      requiredWorkers: 1,
      category: BuildingCategory.processing,
    ),
    Building(
      type: BuildingType.maltHouse,
      name: 'Malt House',
      description: 'Produce 1 Malted barley from 2 barley',
      icon: Icons.grain,
      assetPath: Assets.maltHouse,
      color: Colors.brown,
      baseCost: 100,
      baseConsumption: {'barley': 2},
      baseGeneration: {'maltedBarley': 1},
      requiredWorkers: 1,
      category: BuildingCategory.processing,
    ),
  ];
}