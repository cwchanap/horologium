import 'package:flutter/material.dart';

enum BuildingType {
  powerPlant,
  factory,
  researchLab,
  habitat,
}

class Building {
  final BuildingType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int cost;

  const Building({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.cost,
  });

  static const List<Building> availableBuildings = [
    Building(
      type: BuildingType.powerPlant,
      name: 'Power Plant',
      description: 'Generates energy for your colony',
      icon: Icons.bolt,
      color: Colors.yellow,
      cost: 100,
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
      type: BuildingType.habitat,
      name: 'Habitat',
      description: 'Houses colonists and crew',
      icon: Icons.home,
      color: Colors.green,
      cost: 120,
    ),
  ];
}
