import 'package:flutter/material.dart';
import '../building/building.dart';
import 'research_type.dart';

class Research {
  final ResearchType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int cost;
  final List<ResearchType> prerequisites;
  final List<BuildingType> unlocksBuildings;

  Research({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.cost,
    this.prerequisites = const [],
    this.unlocksBuildings = const [],
  });

  String get id => type.id;

  static final List<Research> availableResearch = [
    Research(
      type: ResearchType.electricity,
      name: 'Electricity',
      description: 'Unlocks the ability to build Power Plants',
      icon: Icons.bolt,
      color: Colors.yellow,
      cost: 5,
      unlocksBuildings: [BuildingType.powerPlant],
    ),
    Research(
      type: ResearchType.goldMining,
      name: 'Gold Mining',
      description: 'Unlocks the ability to build Gold Mines',
      icon: Icons.attach_money,
      color: Colors.amber,
      cost: 10,
      unlocksBuildings: [BuildingType.goldMine],
    ),
    Research(
      type: ResearchType.expansionPlanning,
      name: 'Expansion Planning',
      description: 'Increases building limits by 2 for all building types',
      icon: Icons.business,
      color: Colors.orange,
      cost: 15,
    ),
    Research(
      type: ResearchType.advancedConstruction,
      name: 'Advanced Construction',
      description:
          'Further increases building limits by 3 for all building types',
      icon: Icons.engineering,
      color: Colors.purple,
      cost: 25,
      prerequisites: [ResearchType.expansionPlanning],
    ),
    Research(
      type: ResearchType.grainProcessing,
      name: 'Grain Processing',
      description: 'Unlocks Wind Mills and Grinder Mills',
      icon: Icons.grain,
      color: Colors.brown,
      cost: 20,
      unlocksBuildings: [BuildingType.windMill, BuildingType.grinderMill],
    ),
    Research(
      type: ResearchType.advancedGrainProcessing,
      name: 'Advanced Grain Processing',
      description: 'Unlocks Rice Hullers and Malt Houses',
      icon: Icons.grain,
      color: Colors.brown,
      cost: 30,
      prerequisites: [ResearchType.grainProcessing],
      unlocksBuildings: [BuildingType.riceHuller, BuildingType.maltHouse],
    ),
    Research(
      type: ResearchType.modernHousing,
      name: 'Modern Housing',
      description:
          'Unlocks Large Houses with better efficiency and accommodation',
      icon: Icons.apartment,
      color: Colors.lightGreen,
      cost: 25,
      prerequisites: [ResearchType.electricity],
      unlocksBuildings: [BuildingType.largeHouse],
    ),
    Research(
      type: ResearchType.foodProcessing,
      name: 'Food Processing',
      description: 'Unlocks Bakeries for producing bread and pastries',
      icon: Icons.bakery_dining,
      color: Colors.orange,
      cost: 30,
      prerequisites: [ResearchType.grainProcessing],
      unlocksBuildings: [BuildingType.bakery],
    ),
  ];
}

class ResearchManager {
  final Set<ResearchType> _completedResearch = <ResearchType>{};

  bool isResearched(ResearchType researchType) {
    return _completedResearch.contains(researchType);
  }

  // Legacy method for backward compatibility with string IDs
  bool isResearchedById(String researchId) {
    final type = ResearchTypeHelper.fromId(researchId);
    return type != null && _completedResearch.contains(type);
  }

  void completeResearch(ResearchType researchType) {
    _completedResearch.add(researchType);
  }

  // Legacy method for backward compatibility with string IDs
  void completeResearchById(String researchId) {
    final type = ResearchTypeHelper.fromId(researchId);
    if (type != null) {
      _completedResearch.add(type);
    }
  }

  bool canResearch(Research research) {
    // Check if already completed
    if (isResearched(research.type)) return false;

    // Check if all prerequisites are met
    for (final prereq in research.prerequisites) {
      if (!isResearched(prereq)) return false;
    }

    return true;
  }

  List<BuildingType> getUnlockedBuildings() {
    final List<BuildingType> unlocked = [];

    for (final research in Research.availableResearch) {
      if (isResearched(research.type)) {
        unlocked.addAll(research.unlocksBuildings);
      }
    }

    return unlocked;
  }

  Set<ResearchType> get completedResearch => Set.from(_completedResearch);

  void loadFromList(List<String> completed) {
    _completedResearch.clear();
    for (final id in completed) {
      final type = ResearchTypeHelper.fromId(id);
      if (type != null) {
        _completedResearch.add(type);
      }
    }
  }

  List<String> toList() {
    return _completedResearch.map((type) => type.id).toList();
  }
}
