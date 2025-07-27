import 'package:flutter/material.dart';

import '../building/building.dart';
import '../building/menu.dart';
import '../main_game.dart';
import '../resources/resources.dart';
import 'building_placement_manager.dart';

class InputHandler {
  final MainGame game;
  final Resources resources;
  final BuildingPlacementManager placementManager;
  final Function(int, int) onEmptyGridTapped;
  final Function(int, int, Building) onBuildingLongTapped;
  final VoidCallback onResourcesChanged;

  InputHandler({
    required this.game,
    required this.resources,
    required this.placementManager,
    required this.onEmptyGridTapped,
    required this.onBuildingLongTapped,
    required this.onResourcesChanged,
  });

  void handleGridCellTapped(int x, int y, BuildContext context) {
    // Handle cancel case (clicked outside grid)
    if (x == -1 && y == -1) {
      if (game.buildingToPlace != null) {
        placementManager.cancelPlacement();
      }
      return;
    }

    if (game.buildingToPlace != null) {
      placementManager.handleBuildingPlacement(x, y, context);
    } else {
      final building = game.grid.getBuildingAt(x, y);
      if (building != null) {
        _showBuildingDetailsDialog(context, x, y, building);
      } else {
        onEmptyGridTapped(x, y);
      }
    }
  }

  void handleGridCellLongTapped(int x, int y) {
    final building = game.grid.getBuildingAt(x, y);
    if (building != null) {
      onBuildingLongTapped(x, y, building);
    }
  }

  void _showBuildingDetailsDialog(BuildContext context, int x, int y, Building building) {
    BuildingMenu.showBuildingDetailsDialog(
      context: context,
      x: x,
      y: y,
      building: building,
      resources: resources,
      onResourcesChanged: onResourcesChanged,
      onBuildingUpgraded: onResourcesChanged,
      onBuildingDeleted: onResourcesChanged,
    );
  }
}