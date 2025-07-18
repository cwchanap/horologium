import 'package:flutter/material.dart';

enum BuildingType {
  powerPlant,
  factory,
  researchLab,
  house,
  largeHouse,
  goldMine,
  woodFactory,
  coalMine,
  waterTreatment,
}

class Building {
  final BuildingType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int baseCost;
  final Map<String, double> baseGeneration;
  final Map<String, double> baseConsumption;
  final int basePopulation;
  final int maxLevel;
  final int gridSize;
  final int baseBuildingLimit;
  final int requiredWorkers;
  int level;
  int assignedWorkers;

  Building({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.baseCost,
    this.baseGeneration = const {},
    this.baseConsumption = const {},
    this.basePopulation = 0,
    this.maxLevel = 5,
    this.gridSize = 4,
    this.baseBuildingLimit = 4,
    this.requiredWorkers = 1,
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
    ),
    Building(
      type: BuildingType.factory,
      name: 'Factory',
      description: 'Produces resources and materials',
      icon: Icons.factory,
      color: Colors.orange,
      baseCost: 150,
      maxLevel: 5,
      requiredWorkers: 1,
    ),
    Building(
      type: BuildingType.researchLab,
      name: 'Research Lab',
      description: 'Unlocks new technologies',
      icon: Icons.science,
      color: Colors.blue,
      baseCost: 200,
      baseGeneration: {'research': 0.1},
      maxLevel: 5,
      requiredWorkers: 1,
    ),
    Building(
      type: BuildingType.house,
      name: 'House',
      description: 'Accommodates population and generates money',
      icon: Icons.home,
      color: Colors.green,
      baseCost: 120,
      basePopulation: 2,
      baseGeneration: {'money': 1},
      baseConsumption: {'wood': 1, 'water': 1},
      maxLevel: 5,
      requiredWorkers: 0,
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
    ),
    Building(
      type: BuildingType.goldMine,
      name: 'Gold Mine',
      description: 'Generates gold',
      icon: Icons.attach_money,
      color: Colors.amber,
      baseCost: 300,
      baseGeneration: {'gold': 0.1},
      maxLevel: 5,
      requiredWorkers: 1,
    ),
    Building(
      type: BuildingType.woodFactory,
      name: 'Wood Factory',
      description: 'Produces wood',
      icon: Icons.park,
      color: Colors.brown,
      baseCost: 80,
      baseGeneration: {'wood': 1},
      maxLevel: 5,
      requiredWorkers: 1,
    ),
    Building(
      type: BuildingType.coalMine,
      name: 'Coal Mine',
      description: 'Produces coal',
      icon: Icons.fireplace,
      color: Colors.grey,
      baseCost: 90,
      baseGeneration: {'coal': 1},
      maxLevel: 5,
      requiredWorkers: 1,
    ),
    Building(
      type: BuildingType.waterTreatment,
      name: 'Water Treatment Plant',
      description: 'Produces clean water',
      icon: Icons.water_drop,
      color: Colors.lightBlue,
      baseCost: 150,
      baseGeneration: {'water': 2},
      maxLevel: 5,
      requiredWorkers: 1,
    ),
  ];
}
