import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import 'building/building.dart';
import 'terrain/index.dart';

const double cellWidth = 50;
const double cellHeight = 50;

class PlacedBuilding {
  final Building building;
  final int x;
  final int y;

  PlacedBuilding(this.building, this.x, this.y);
}

class Grid extends PositionComponent with HasGameReference {
  final int gridSize;
  final Map<String, PlacedBuilding> _buildings = {};
  final Map<String, Sprite> _spriteCache = {};
  int _lastLoggedGridSize = -1; // For debug logging
  
  // Callbacks for building changes (replaces direct SharedPreferences)
  final Function(int x, int y, Building building)? onBuildingPlaced;
  final Function(int x, int y)? onBuildingRemoved;
  
  // Reference to terrain for buildability checks
  ParallaxTerrainComponent? terrainComponent;

  Grid({
    this.gridSize = 50, 
    this.onBuildingPlaced,
    this.onBuildingRemoved,
  });

  // Public getter to access the sprite cache
  Sprite? getSpriteForBuilding(Building building) {
    return building.assetPath != null ? _spriteCache[building.assetPath!] : null;
  }

  Vector2? getGridPosition(Vector2 localPosition) {
    // Adjust for centered anchor
    final adjustedX = localPosition.x + size.x / 2;
    final adjustedY = localPosition.y + size.y / 2;
    
    if (adjustedX < 0 ||
        adjustedY < 0 ||
        adjustedX >= size.x ||
        adjustedY >= size.y) {
      return null;
    }

    final gridX = (adjustedX / cellWidth).floor();
    final gridY = (adjustedY / cellHeight).floor();

    return Vector2(gridX.toDouble(), gridY.toDouble());
  }

  Vector2 getGridCenterPosition(int x, int y) {
    // Adjust for centered anchor
    final offsetX = -size.x / 2;
    final offsetY = -size.y / 2;
    
    return Vector2(
      offsetX + (x * cellWidth) + (cellWidth / 2),
      offsetY + (y * cellHeight) + (cellHeight / 2),
    );
  }

  bool isAreaAvailable(int x, int y, int size) {
    final buildingSize = sqrt(size).toInt();
    if (x + buildingSize > gridSize || y + buildingSize > gridSize) {
      return false;
    }
    
    // Check grid occupancy
    for (var i = 0; i < buildingSize; i++) {
      for (var j = 0; j < buildingSize; j++) {
        if (isCellOccupied(x + i, y + j)) {
          return false;
        }
      }
    }
    
    // Check terrain buildability if terrain component is available
    if (terrainComponent != null) {
      for (var i = 0; i < buildingSize; i++) {
        for (var j = 0; j < buildingSize; j++) {
          if (!terrainComponent!.isBuildableAt(x + i, y + j)) {
            return false;
          }
        }
      }
    }
    
    return true;
  }

  void placeBuilding(int x, int y, Building building, {bool notifyCallbacks = true}) {
    final buildingSize = sqrt(building.gridSize).toInt();
    final placedBuilding = PlacedBuilding(building, x, y);
    for (var i = 0; i < buildingSize; i++) {
      for (var j = 0; j < buildingSize; j++) {
        final key = '${x + i},${y + j}';
        _buildings[key] = placedBuilding;
      }
    }
    if (notifyCallbacks) {
      onBuildingPlaced?.call(x, y, building);
    }
  }

  PlacedBuilding? getPlacedBuildingAt(int x, int y) {
    final key = '$x,$y';
    return _buildings[key];
  }

  Building? getBuildingAt(int x, int y) {
    return getPlacedBuildingAt(x, y)?.building;
  }

  void removeBuilding(int x, int y) {
    final placedBuilding = getPlacedBuildingAt(x, y);
    if (placedBuilding == null) {
      return;
    }

    final buildingSize = sqrt(placedBuilding.building.gridSize).toInt();
    for (var i = 0; i < buildingSize; i++) {
      for (var j = 0; j < buildingSize; j++) {
        final key = '${placedBuilding.x + i},${placedBuilding.y + j}';
        _buildings.remove(key);
      }
    }
    onBuildingRemoved?.call(x, y);
  }

  int countBuildingsOfType(BuildingType type) {
    return _buildings.values
        .toSet()
        .where((b) => b.building.type == type)
        .length;
  }

  List<Building> getAllBuildings() {
    return _buildings.values.toSet().map((b) => b.building).toList();
  }

  bool isCellOccupied(int x, int y) {
    final key = '$x,$y';
    return _buildings.containsKey(key);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadBuildingSprites();
  }

  Future<void> _loadBuildingSprites() async {
    for (final building in BuildingRegistry.availableBuildings) {
      // Use assetPath to load sprites for buildings that have one.
      if (building.assetPath != null) {
        final image = await game.images.load(building.assetPath!);
        _spriteCache[building.assetPath!] = Sprite(image);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..color = Colors.white.withAlpha((255 * 0.02).round()) // Much more transparent for debugging
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5; // Thinner lines

    // Calculate offset for centered anchor - matching terrain positioning
    final offsetX = -1225.0; // Grid center at x = 24.5 * 50 = 1225
    final offsetY = -1225.0; // Grid center at y = 24.5 * 50 = 1225

    // Draw grid lines
    for (var i = 0; i <= gridSize; i++) {
      final double x = offsetX + i * cellWidth;
      canvas.drawLine(Offset(x, offsetY), Offset(x, offsetY + size.y), paint);
    }

    for (var i = 0; i <= gridSize; i++) {
      final double y = offsetY + i * cellHeight;
      canvas.drawLine(Offset(offsetX, y), Offset(offsetX + size.x, y), paint);
    }

    // Debug: Print actual grid dimensions being rendered
    if (gridSize != _lastLoggedGridSize) {
      print('=== GRID RENDERING DEBUG ===');
      print('gridSize: $gridSize');
      print('Lines drawn: ${gridSize + 1} in each direction');
      print('Cells created: $gridSize x $gridSize');
      print('Visual size: ${size.x} x ${size.y}');
      print('Cell dimensions: $cellWidth x $cellHeight');
      print('Expected total size: ${gridSize * cellWidth} x ${gridSize * cellHeight}');
      print('Actual calculated size from gridSize: ${gridSize * cellWidth} x ${gridSize * cellHeight}');
      print('Size mismatch: ${size.x != gridSize * cellWidth || size.y != gridSize * cellHeight}');
      _lastLoggedGridSize = gridSize;
    }

    // Draw buildings
    final drawnBuildings = <PlacedBuilding>{};
    _buildings.forEach((key, placedBuilding) {
      if (drawnBuildings.contains(placedBuilding)) {
        return;
      }

      _renderBuilding(canvas, placedBuilding);
      drawnBuildings.add(placedBuilding);
    });
  }

  void _renderBuilding(Canvas canvas, PlacedBuilding placedBuilding) {
    final building = placedBuilding.building;
    final x = placedBuilding.x;
    final y = placedBuilding.y;
    final buildingSize = sqrt(building.gridSize).toInt();

    // Calculate position relative to the centered anchor
    final offsetX = -size.x / 2;
    final offsetY = -size.y / 2;

    final rect = Rect.fromLTWH(
      offsetX + x * cellWidth + 2,
      offsetY + y * cellHeight + 2,
      cellWidth * buildingSize - 4,
      cellHeight * buildingSize - 4,
    );

    // If the building has a sprite asset, render it.
    if (building.assetPath != null) {
      final sprite = _spriteCache[building.assetPath!];
      if (sprite != null) {
        sprite.render(canvas, position: rect.topLeft.toVector2(), size: rect.size.toVector2());
      }
    } else {
      final buildingPaint = Paint()
        ..color = building.color.withAlpha((255 * 0.8).round())
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        buildingPaint,
      );

      // Draw building border
      final borderPaint = Paint()
        ..color = building.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        borderPaint,
      );
    }
  }
}