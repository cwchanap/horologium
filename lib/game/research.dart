import 'package:flutter/material.dart';
import 'building.dart';

class Research {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int cost;
  final List<String> prerequisites;
  final List<BuildingType> unlocksBuildings;

  Research({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.cost,
    this.prerequisites = const [],
    this.unlocksBuildings = const [],
  });

  static final List<Research> availableResearch = [
    Research(
      id: 'electricity',
      name: 'Electricity',
      description: 'Unlocks the ability to build Power Plants',
      icon: Icons.bolt,
      color: Colors.yellow,
      cost: 5,
      unlocksBuildings: [BuildingType.powerPlant],
    ),
    Research(
      id: 'gold_mining',
      name: 'Gold Mining',
      description: 'Unlocks the ability to build Gold Mines',
      icon: Icons.attach_money,
      color: Colors.amber,
      cost: 10,
      unlocksBuildings: [BuildingType.goldMine],
    ),
  ];
}

class ResearchManager {
  final Set<String> _completedResearch = <String>{};
  
  bool isResearched(String researchId) {
    return _completedResearch.contains(researchId);
  }
  
  void completeResearch(String researchId) {
    _completedResearch.add(researchId);
  }
  
  bool canResearch(Research research) {
    // Check if already completed
    if (isResearched(research.id)) return false;
    
    // Check if all prerequisites are met
    for (final prereq in research.prerequisites) {
      if (!isResearched(prereq)) return false;
    }
    
    return true;
  }
  
  List<BuildingType> getUnlockedBuildings() {
    final List<BuildingType> unlocked = [];
    
    for (final research in Research.availableResearch) {
      if (isResearched(research.id)) {
        unlocked.addAll(research.unlocksBuildings);
      }
    }
    
    return unlocked;
  }
  
  Set<String> get completedResearch => Set.from(_completedResearch);
  
  void loadFromList(List<String> completed) {
    _completedResearch.clear();
    _completedResearch.addAll(completed);
  }
}