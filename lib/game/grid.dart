import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'building.dart';

const double cellWidth = 100;
const double cellHeight = 100;

class Grid extends PositionComponent {
  final int gridSize;
  final Map<String, Building> _buildings = {};

  Grid({this.gridSize = 10});

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

  Future<void> saveBuildings() async {
    final prefs = await SharedPreferences.getInstance();
    final buildingData = _buildings.entries.map((entry) {
      final coords = entry.key.split(',');
      final x = coords[0];
      final y = coords[1];
      final building = entry.value;
      return '$x,$y,${building.name}';
    }).toList();
    await prefs.setStringList('buildings', buildingData);
  }

  void placeBuilding(int x, int y, Building building) {
    final key = '$x,$y';
    _buildings[key] = building;
    saveBuildings();
  }

  Building? getBuildingAt(int x, int y) {
    final key = '$x,$y';
    return _buildings[key];
  }

  void removeBuilding(int x, int y) {
    final key = '$x,$y';
    _buildings.remove(key);
    saveBuildings();
  }

  bool isCellOccupied(int x, int y) {
    final key = '$x,$y';
    return _buildings.containsKey(key);
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
    _buildings.forEach((key, building) {
      final coords = key.split(',');
      final x = int.parse(coords[0]);
      final y = int.parse(coords[1]);

      final buildingPaint = Paint()
        ..color = building.color.withAlpha((255 * 0.8).round())
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(
        x * cellWidth + 2,
        y * cellHeight + 2,
        cellWidth - 4,
        cellHeight - 4,
      );

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
    });
  }
}