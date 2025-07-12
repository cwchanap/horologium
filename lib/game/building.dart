import 'package:flutter/material.dart';

enum BuildingType {
  powerPlant,
  factory,
  researchLab,
  house,
  goldMine,
}

class Building {
  final BuildingType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int cost;
  final Map<String, double> generation;
  final int population;

  const Building({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.cost,
    this.generation = const {},
    this.population = 0,
  });

  static const List<Building> availableBuildings = [
    Building(
      type: BuildingType.powerPlant,
      name: 'Power Plant',
      description: 'Generates energy for your colony',
      icon: Icons.bolt,
      color: Colors.yellow,
      cost: 100,
      generation: {'electricity': 1},
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
    ),
    Building(
      type: BuildingType.house,
      name: 'House',
      description: 'Increases population and generates money',
      icon: Icons.home,
      color: Colors.green,
      cost: 120,
      population: 5,
      generation: {'money': 1, 'electricity': -1},
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
  ];
}
