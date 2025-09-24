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

  // Debug overlays (border and markers) toggle
  bool showDebug = false;

  // Callbacks for building changes (replaces direct SharedPreferences)
  final Function(int x, int y, Building building)? onBuildingPlaced;
  final Function(int x, int y)? onBuildingRemoved;

  // Reference to terrain for buildability checks
  ParallaxTerrainComponent? terrainComponent;

  Grid({this.gridSize = 50, this.onBuildingPlaced, this.onBuildingRemoved});

  // Public getter to access the sprite cache
  Sprite? getSpriteForBuilding(Building building) {
    return building.assetPath != null
        ? _spriteCache[building.assetPath!]
        : null;
  }

  Vector2? getGridPosition(Vector2 localPosition) {
    // Local coordinates are top-left-based inside render
    final adjustedX = localPosition.x;
    final adjustedY = localPosition.y;

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
    // Local coordinates are top-left-based inside render
    return Vector2(
      (x * cellWidth) + (cellWidth / 2),
      (y * cellHeight) + (cellHeight / 2),
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

  void placeBuilding(
    int x,
    int y,
    Building building, {
    bool notifyCallbacks = true,
  }) {
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
      ..color = Colors.white
          .withAlpha((255 * 0.25).round()) // More visible for debugging
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0; // Slightly thicker lines

    // Draw from local top-left (0,0) for center-anchored component
    final offsetX = 0.0;
    final offsetY = 0.0;

    // Draw grid lines
    for (var i = 0; i <= gridSize; i++) {
      final double x = offsetX + i * cellWidth;
      canvas.drawLine(Offset(x, offsetY), Offset(x, offsetY + size.y), paint);
    }

    for (var i = 0; i <= gridSize; i++) {
      final double y = offsetY + i * cellHeight;
      canvas.drawLine(Offset(offsetX, y), Offset(offsetX + size.x, y), paint);
    }

    if (showDebug) {
      // Debug: blue border to compare with terrain red border
      final borderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, size.x, size.y),
        borderPaint,
      );

      // Debug markers: center and corners
      final centerPaint = Paint()..color = Colors.orange; // (size/2,size/2)
      final tlPaint = Paint()..color = Colors.green; // (0,0)
      final brPaint = Paint()..color = Colors.cyan; // (size,size)

      // Center marker (local center is at (size/2,size/2))
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - 5, size.y / 2 - 5, 10, 10),
        centerPaint,
      );
      // Top-left marker
      canvas.drawRect(Rect.fromLTWH(offsetX, offsetY, 8, 8), tlPaint);
      // Bottom-right marker
      canvas.drawRect(
        Rect.fromLTWH(offsetX + size.x - 8, offsetY + size.y - 8, 8, 8),
        brPaint,
      );
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

    final rect = Rect.fromLTWH(
      x * cellWidth + 2,
      y * cellHeight + 2,
      cellWidth * buildingSize - 4,
      cellHeight * buildingSize - 4,
    );

    // If the building has a sprite asset, render it.
    if (building.assetPath != null) {
      final sprite = _spriteCache[building.assetPath!];
      if (sprite != null) {
        sprite.render(
          canvas,
          position: rect.topLeft.toVector2(),
          size: rect.size.toVector2(),
        );
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
