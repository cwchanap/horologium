import 'package:flutter/material.dart';

enum ResourceCategory {
  rawMaterials,
  foodResources,
}

extension ResourceCategoryExtension on ResourceCategory {
  String get displayName {
    switch (this) {
      case ResourceCategory.rawMaterials:
        return 'Raw Materials';
      case ResourceCategory.foodResources:
        return 'Food Resources';
    }
  }

  IconData get icon {
    switch (this) {
      case ResourceCategory.rawMaterials:
        return Icons.build;
      case ResourceCategory.foodResources:
        return Icons.restaurant;
    }
  }
}