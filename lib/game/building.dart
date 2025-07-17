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
  final int cost;
  final Map<String, double> generation;
  final Map<String, double> consumption;
  final int population;
  final List<Building> upgrades;
  final int gridSize;

  Building({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.cost,
    this.generation = const {},
    this.consumption = const {},
    this.population = 0,
    this.upgrades = const [],
    this.gridSize = 4,
  });

  static final Building powerPlant2 = Building(
    type: BuildingType.powerPlant,
    name: 'Power Plant Lvl. 2',
    description: 'Generates more energy for your colony',
    icon: Icons.bolt,
    color: Colors.yellow,
    cost: 200,
    generation: {'electricity': 2},
    consumption: {'coal': 1},
  );

  static final List<Building> availableBuildings = [
    Building(
      type: BuildingType.powerPlant,
      name: 'Power Plant',
      description: 'Generates energy for your colony',
      icon: Icons.bolt,
      color: Colors.yellow,
      cost: 100,
      generation: {'electricity': 1},
      consumption: {'coal': 1},
      upgrades: [powerPlant2],
    ),
    Building(
      type: BuildingType.factory,
      name: 'Factory',
      description: 'Produces resources and materials',
      icon: Icons.factory,
      color: Colors.orange,
      cost: 150,
    ),
    Building(
      type: BuildingType.researchLab,
      name: 'Research Lab',
      description: 'Unlocks new technologies',
      icon: Icons.science,
      color: Colors.blue,
      cost: 200,
      generation: {'research': 0.1},
    ),
    Building(
      type: BuildingType.house,
      name: 'House',
      description: 'Increases population and generates money',
      icon: Icons.home,
      color: Colors.green,
      cost: 120,
      population: 2,
      generation: {'money': 1},
      consumption: {'wood': 1, 'water': 1},
    ),
    Building(
      type: BuildingType.largeHouse,
      name: 'Large House',
      description: 'Modern housing with more population and money generation',
      icon: Icons.apartment,
      color: Colors.lightGreen,
      cost: 250,
      population: 8,
      generation: {'money': 3},
      consumption: {'electricity': 1, 'water': 2},
    ),
    Building(
      type: BuildingType.goldMine,
      name: 'Gold Mine',
      description: 'Generates gold',
      icon: Icons.attach_money,
      color: Colors.amber,
      cost: 300,
      generation: {'gold': 0.1},
    ),
    Building(
      type: BuildingType.woodFactory,
      name: 'Wood Factory',
      description: 'Produces wood',
      icon: Icons.park,
      color: Colors.brown,
      cost: 80,
      generation: {'wood': 1},
    ),
    Building(
      type: BuildingType.coalMine,
      name: 'Coal Mine',
      description: 'Produces coal',
      icon: Icons.fireplace,
      color: Colors.grey,
      cost: 90,
      generation: {'coal': 1},
    ),
    Building(
      type: BuildingType.waterTreatment,
      name: 'Water Treatment Plant',
      description: 'Produces clean water',
      icon: Icons.water_drop,
      color: Colors.lightBlue,
      cost: 150,
      generation: {'water': 2},
    ),
  ];
}
