import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'building/building.dart';

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

  Grid({this.gridSize = 50});

  Vector2? getGridPosition(Vector2 localPosition) {
    if (localPosition.x < 0 ||
        localPosition.y < 0 ||
        localPosition.x >= size.x ||
        localPosition.y >= size.y) {
      return null;
    }

    final gridX = (localPosition.x / cellWidth).floor();
    final gridY = (localPosition.y / cellHeight).floor();

    return Vector2(gridX.toDouble(), gridY.toDouble());
  }

  Vector2 getGridCenterPosition(int x, int y) {
    return Vector2(
      (x * cellWidth) + (cellWidth / 2),
      (y * cellHeight) + (cellHeight / 2),
    );
  }

  Future<void> saveBuildings() async {
    final prefs = await SharedPreferences.getInstance();
    final buildingData = _buildings.values.toSet().map((placedBuilding) {
      return '${placedBuilding.x},${placedBuilding.y},${placedBuilding.building.name}';
    }).toList();
    await prefs.setStringList('buildings', buildingData);
  }

  bool isAreaAvailable(int x, int y, int size) {
    final buildingSize = sqrt(size).toInt();
    if (x + buildingSize > gridSize || y + buildingSize > gridSize) {
      return false;
    }
    for (var i = 0; i < buildingSize; i++) {
      for (var j = 0; j < buildingSize; j++) {
        if (isCellOccupied(x + i, y + j)) {
          return false;
        }
      }
    }
    return true;
  }

  void placeBuilding(int x, int y, Building building) {
    final buildingSize = sqrt(building.gridSize).toInt();
    final placedBuilding = PlacedBuilding(building, x, y);
    for (var i = 0; i < buildingSize; i++) {
      for (var j = 0; j < buildingSize; j++) {
        final key = '${x + i},${y + j}';
        _buildings[key] = placedBuilding;
      }
    }
    saveBuildings();
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
    saveBuildings();
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
      ..color = Colors.white.withAlpha((255 * 0.2).round())
      ..style = PaintingStyle.stroke;

    // Draw grid lines
    for (var i = 0; i <= gridSize; i++) {
      final double x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), paint);
    }

    for (var i = 0; i <= gridSize; i++) {
      final double y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.x, y), paint);
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