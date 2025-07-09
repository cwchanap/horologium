import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

class GameScene extends FlameGame with TapCallbacks {
  final int gridSize;
  double _zoom = 1.0;
  late Grid _grid;
  Function(int, int)? onGridCellTapped;

  GameScene({this.gridSize = 10});
  
  Grid get grid => _grid;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final camera = CameraComponent.withFixedResolution(width: 800, height: 600);
    camera.viewfinder.anchor = Anchor.center;
    world.add(camera);
    _grid = Grid(gridSize: gridSize)..size = size;
    world.add(_grid);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final tapPosition = event.localPosition;
    final gridPosition = _grid.getGridPosition(tapPosition);
    
    if (gridPosition != null) {
      onGridCellTapped?.call(gridPosition.x.toInt(), gridPosition.y.toInt());
    }
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final newZoom = _zoom * details.scale;
    _zoom = newZoom.clamp(1.0, 4.0);
    camera.viewfinder.zoom = _zoom;
  }
}

class Grid extends PositionComponent {
  final int gridSize;
  final Map<String, Building> _buildings = {};

  Grid({this.gridSize = 10});

  Vector2? getGridPosition(Vector2 worldPosition) {
    if (worldPosition.x < 0 || worldPosition.y < 0 || 
        worldPosition.x >= size.x || worldPosition.y >= size.y) {
      return null;
    }
    
    final cellSize = size.x / gridSize;
    final gridX = (worldPosition.x / cellSize).floor();
    final gridY = (worldPosition.y / cellSize).floor();
    
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

    final cellSize = size.x / gridSize;

    // Draw grid lines
    for (var i = 0; i <= gridSize; i++) {
      final double x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), paint);
    }

    for (var i = 0; i <= gridSize; i++) {
      final double y = i * cellSize;
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
        x * cellSize + 2,
        y * cellSize + 2,
        cellSize - 4,
        cellSize - 4,
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
