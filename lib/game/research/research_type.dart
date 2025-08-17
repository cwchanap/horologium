enum ResearchType {
  electricity,
  goldMining,
  expansionPlanning,
  advancedConstruction,
  grainProcessing,
  advancedGrainProcessing,
  modernHousing,
  foodProcessing,
}

extension ResearchTypeExtension on ResearchType {
  String get id {
    switch (this) {
      case ResearchType.electricity:
        return 'electricity';
      case ResearchType.goldMining:
        return 'gold_mining';
      case ResearchType.expansionPlanning:
        return 'expansion_planning';
      case ResearchType.advancedConstruction:
        return 'advanced_construction';
      case ResearchType.grainProcessing:
        return 'grain_processing';
      case ResearchType.advancedGrainProcessing:
        return 'advanced_grain_processing';
      case ResearchType.modernHousing:
        return 'modern_housing';
      case ResearchType.foodProcessing:
        return 'food_processing';
    }
  }
}

class ResearchTypeHelper {
  static ResearchType? fromId(String id) {
    for (final type in ResearchType.values) {
      if (type.id == id) {
        return type;
      }
    }
    return null;
  }
}
