import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'building.dart';

const double cellWidth = 100;
const double cellHeight = 100;

class Grid extends PositionComponent {
  final int gridSize;
  final Map<String, Building> _buildings = {};

  Grid({this.gridSize = 10});

  Vector2? getGridPosition(Vector2 screenPosition) {
    if (screenPosition.x < 0 ||
        screenPosition.y < 0 ||
        screenPosition.x >= size.x ||
        screenPosition.y >= size.y) {
      return null;
    }

    final gridX = (screenPosition.x / cellWidth).floor();
    final gridY = (screenPosition.y / cellHeight).floor();

    return Vector2(gridX.toDouble(), gridY.toDouble());
  }

  void placeBuilding(int x, int y, Building building) {
    final key = '$x,$y';
    _buildings[key] = building;
  }

  bool isCellOccupied(int x, int y) {
    final key = '$x,$y';
    return _buildings.containsKey(key);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
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
        ..color = building.color.withOpacity(0.8)
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
