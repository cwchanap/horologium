import 'package:flutter/material.dart';

import '../building/building.dart';
import '../main_game.dart';
import '../resources.dart';
import '../services/resource_service.dart';

class BuildingPlacementManager {
  final MainGame game;
  final Resources resources;
  final BuildingLimitManager buildingLimitManager;
  final VoidCallback onResourcesChanged;

  BuildingPlacementManager({
    required this.game,
    required this.resources,
    required this.buildingLimitManager,
    required this.onResourcesChanged,
  });

  bool handleBuildingPlacement(int x, int y, BuildContext context) {
    if (game.buildingToPlace == null) return false;

    if (!game.placementPreview.isValid) {
      // Cancel placement when clicking on invalid position
      game.buildingToPlace = null;
      game.hidePlacementPreview();
      return true;
    }

    final buildingType = game.buildingToPlace!.type;
    final currentCount = game.grid.countBuildingsOfType(buildingType);
    final limit = buildingLimitManager.getBuildingLimit(buildingType);
    
    if (currentCount >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Building limit reached! Maximum $limit ${game.buildingToPlace!.name}s allowed.')),
      );
      return false;
    }

    if (!ResourceService.canAffordBuilding(resources, game.buildingToPlace!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient funds!'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Place the building
    game.grid.placeBuilding(x, y, game.buildingToPlace!);
    ResourceService.purchaseBuilding(resources, game.buildingToPlace!);
    
    game.buildingToPlace = null;
    game.hidePlacementPreview();
    onResourcesChanged();
    return true;
  }

  void cancelPlacement() {
    game.buildingToPlace = null;
    game.hidePlacementPreview();
  }

  void selectBuilding(Building building) {
    game.buildingToPlace = building;
  }
}