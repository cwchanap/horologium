import 'package:flutter/material.dart';

enum ResourceCategory {
  rawMaterials,
  foodResources,
  stapleGrains,
  refinement,
}

extension ResourceCategoryExtension on ResourceCategory {
  String get displayName {
    switch (this) {
      case ResourceCategory.rawMaterials:
        return 'Raw Materials';
      case ResourceCategory.foodResources:
        return 'Food Resources';
      case ResourceCategory.stapleGrains:
        return 'Staple Grains';
      case ResourceCategory.refinement:
        return 'Refinement';
    }
  }

  IconData get icon {
    switch (this) {
      case ResourceCategory.rawMaterials:
        return Icons.build;
      case ResourceCategory.foodResources:
        return Icons.restaurant;
      case ResourceCategory.stapleGrains:
        return Icons.grain;
      case ResourceCategory.refinement:
        return Icons.bakery_dining;
    }
  }
}