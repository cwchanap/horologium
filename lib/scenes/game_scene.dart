import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const double gridWidth = 2000;
const double gridHeight = 2000;
const double cellWidth = 100;
const double cellHeight = 100;

enum BuildingType {
  powerPlant,
  factory,
  researchLab,
  habitat,
}

class Building {
  final BuildingType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int cost;

  const Building({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.cost,
  });

  static const List<Building> availableBuildings = [
    Building(
      type: BuildingType.powerPlant,
      name: 'Power Plant',
      description: 'Generates energy for your colony',
      icon: Icons.bolt,
      color: Colors.yellow,
      cost: 100,
    ),
    Building(
      type: BuildingType.factory,
      name: 'Factory',
      description: 'Produces resources and materials',
      icon: Icons.factory,
      color: Colors.orange,
      cost: 150,
    ),
    Building(
      type: BuildingType.researchLab,
      name: 'Research Lab',
      description: 'Unlocks new technologies',
      icon: Icons.science,
      color: Colors.blue,
      cost: 200,
    ),
    Building(
      type: BuildingType.habitat,
      name: 'Habitat',
      description: 'Houses colonists and crew',
      icon: Icons.home,
      color: Colors.green,
      cost: 120,
    ),
  ];
}

class GameScene extends FlameGame with TapCallbacks, DragCallbacks {
  final int gridSize;
  late Grid _grid;
  Function(int, int)? onGridCellTapped;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 4.0;

  double _startZoom = _minZoom;

  GameScene({this.gridSize = 10});

  Grid get grid => _grid;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = _startZoom;
    _grid = Grid(gridSize: gridSize)
      ..size = Vector2(gridSize * cellWidth, gridSize * cellHeight)
      ..anchor = Anchor.center;
    world.add(_grid);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    camera.viewfinder.position -= event.canvasDelta / camera.viewfinder.zoom;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final gridPosition = _grid.getGridPosition(event.localPosition);

    if (gridPosition != null) {
      onGridCellTapped?.call(gridPosition.x.toInt(), gridPosition.y.toInt());
    }
  }

  

  void clampZoom() {
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(_minZoom, _maxZoom);
  }
}

class Grid extends PositionComponent {
  final int gridSize;
  final Map<String, Building> _buildings = {};

  Grid({this.gridSize = 10});

  Vector2? getGridPosition(Vector2 screenPosition) {
    if (screenPosition.x < 0 || screenPosition.y < 0 ||
        screenPosition.x >= size.x || screenPosition.y >= size.y) {
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
      ..color = Colors.white.withValues(alpha: 0.2)
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
        ..color = building.color.withValues(alpha: 0.8)
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
