/// Shared theme utilities for production overlay widgets.
library;

import 'package:flutter/material.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/production_graph.dart';

/// Theme utilities for production overlay visualization.
class ProductionTheme {
  // Layout constants
  static const double nodeWidth = 120.0;
  static const double nodeHeight = 80.0;
  static const double edgePadding = 50.0;
  static const double clusterWidth = 140.0;
  static const double clusterHeight = 140.0; // Estimated for canvas sizing

  /// Get color for a given flow status.
  static Color getStatusColor(FlowStatus status) {
    switch (status) {
      case FlowStatus.surplus:
        return const Color(0xFF4CAF50); // Green
      case FlowStatus.balanced:
        return const Color(0xFFFFEB3B); // Yellow
      case FlowStatus.deficit:
        return const Color(0xFFF44336); // Red
      case FlowStatus.unknown:
        return const Color(0xFF9E9E9E); // Gray
    }
  }

  /// Get icon data for a given flow status.
  static IconData getStatusIcon(FlowStatus status) {
    switch (status) {
      case FlowStatus.surplus:
        return Icons.check;
      case FlowStatus.balanced:
        return Icons.remove;
      case FlowStatus.deficit:
        return Icons.close;
      case FlowStatus.unknown:
        return Icons.help_outline;
    }
  }

  /// Get icon widget for a building category.
  static Widget getCategoryIcon(BuildingCategory category, {double size = 16}) {
    IconData iconData;
    switch (category) {
      case BuildingCategory.rawMaterials:
        iconData = Icons.terrain;
        break;
      case BuildingCategory.processing:
      case BuildingCategory.primaryFactory:
        iconData = Icons.factory;
        break;
      case BuildingCategory.refinement:
        iconData = Icons.science;
        break;
      case BuildingCategory.residential:
        iconData = Icons.home;
        break;
      case BuildingCategory.services:
        iconData = Icons.storefront;
        break;
      case BuildingCategory.foodResources:
        iconData = Icons.restaurant;
        break;
    }

    return Icon(iconData, size: size, color: Colors.grey[400]);
  }

  /// Get IconData for a building category (without wrapping in Icon widget).
  static IconData getCategoryIconData(BuildingCategory category) {
    switch (category) {
      case BuildingCategory.rawMaterials:
        return Icons.terrain;
      case BuildingCategory.processing:
      case BuildingCategory.primaryFactory:
        return Icons.factory;
      case BuildingCategory.refinement:
        return Icons.science;
      case BuildingCategory.residential:
        return Icons.home;
      case BuildingCategory.services:
        return Icons.storefront;
      case BuildingCategory.foodResources:
        return Icons.restaurant;
    }
  }
}
