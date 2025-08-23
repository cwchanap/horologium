import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'building/building.dart';
import 'grid.dart';
import 'planet/index.dart';

class MainGame extends FlameGame
    with
        flame_events.TapCallbacks,
        flame_events.DragCallbacks,
        flame_events.PointerMoveCallbacks {
  Grid? _grid;
  Planet? _planet;
  Function(int, int)? onGridCellTapped;
  Function(int, int)? onGridCellLongTapped;
  Function(int, int)? onGridCellSecondaryTapped;
  Function(Planet)? onPlanetChanged;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 4.0;

  final double _startZoom = _minZoom;

  Building? buildingToPlace;
  final PlacementPreview placementPreview = PlacementPreview();

  MainGame({Planet? planet}) : _planet = planet;

  Grid get grid => _grid!;
  bool get hasLoaded => _grid != null;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = _startZoom;
    _grid = Grid(
      onBuildingPlaced: _onBuildingPlaced,
      onBuildingRemoved: _onBuildingRemoved,
    );
    _grid!.size =
        Vector2(_grid!.gridSize * cellWidth, _grid!.gridSize * cellHeight);
    _grid!.anchor = Anchor.center;
    world.add(_grid!);
    await loadBuildings();
  }

  Future<void> loadBuildings() async {
    if (_planet == null || _grid == null) {
      return;
    }

    for (final buildingData in _planet!.buildings) {
      final building = buildingData.createBuilding();
      _grid!.placeBuilding(buildingData.x, buildingData.y, building, notifyCallbacks: false);
    }
  }

  // Planet management
  void setPlanet(Planet planet) {
    _planet = planet;
  }

  Planet? get planet => _planet;

  // Grid callbacks for planet updates
  void _onBuildingPlaced(int x, int y, Building building) {
    if (_planet == null) return;
    
    final buildingData = PlacedBuildingData(
      x: x,
      y: y,
      type: building.type,
      level: building.level,
      assignedWorkers: building.assignedWorkers,
    );
    
    _planet!.addBuilding(buildingData);
    onPlanetChanged?.call(_planet!);
  }

  void _onBuildingRemoved(int x, int y) {
    if (_planet == null) return;
    
    _planet!.removeBuildingAt(x, y);
    onPlanetChanged?.call(_planet!);
  }

  @override
  void onDragUpdate(flame_events.DragUpdateEvent event) {
    camera.viewfinder.position -= event.canvasDelta / camera.viewfinder.zoom;
  }

  @override
  void onPointerMove(flame_events.PointerMoveEvent event) {
    super.onPointerMove(event);
    if (buildingToPlace != null) {
      final worldPosition = camera.globalToLocal(event.canvasPosition);
      showPlacementPreview(buildingToPlace!, worldPosition);
    }
  }

  @override
  void onTapUp(flame_events.TapUpEvent event) {
    if (_grid == null) return;
    
    final worldPosition = camera.globalToLocal(event.canvasPosition);
    final localPosition = _grid!.toLocal(worldPosition);
    final gridPosition = _grid!.getGridPosition(localPosition);

    if (gridPosition != null) {
      onGridCellTapped?.call(gridPosition.x.toInt(), gridPosition.y.toInt());
    } else {
      // Clicked outside grid - cancel building placement if active
      if (buildingToPlace != null) {
        onGridCellTapped?.call(-1, -1); // Special coordinates to indicate cancel
      }
    }
  }

  @override
  void onLongTapDown(flame_events.TapDownEvent event) {
    if (_grid == null) return;
    
    final worldPosition = camera.globalToLocal(event.canvasPosition);
    final localPosition = _grid!.toLocal(worldPosition);
    final gridPosition = _grid!.getGridPosition(localPosition);

    if (gridPosition != null) {
      onGridCellLongTapped?.call(
          gridPosition.x.toInt(), gridPosition.y.toInt());
    }
  }

  void onSecondaryTapUp(flame_events.TapUpEvent event) {
    if (_grid == null) return;
    
    final worldPosition = camera.globalToLocal(event.canvasPosition);
    final localPosition = _grid!.toLocal(worldPosition);
    final gridPosition = _grid!.getGridPosition(localPosition);

    if (gridPosition != null) {
      onGridCellSecondaryTapped?.call(
          gridPosition.x.toInt(), gridPosition.y.toInt());
    }
  }

  void clampZoom() {
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(_minZoom, _maxZoom);
  }

  void showPlacementPreview(Building building, Vector2 position) {
    if (_grid == null) return;
    
    placementPreview.setBuilding(building);
    
    final localPosition = _grid!.toLocal(position);
    final gridPosition = _grid!.getGridPosition(localPosition);

    if (gridPosition != null) {
      // Use the same positioning logic as the grid's render method
      final gridX = gridPosition.x.toInt();
      final gridY = gridPosition.y.toInt();
      
      // Calculate position relative to grid's local coordinate system (top-left corner like buildings)
      final localX = gridX * cellWidth;
      final localY = gridY * cellHeight;
      
      // Since grid is centered at world (0,0), local coordinates are already relative to world center
      final worldPosition = Vector2(localX - _grid!.size.x / 2, localY - _grid!.size.y / 2);
      placementPreview.position = worldPosition;
      
      
      placementPreview.isValid = _grid!.isAreaAvailable(gridX, gridY, building.gridSize);
    } else {
      // Hide preview when outside grid bounds
      placementPreview.position = Vector2(-10000, -10000);
      placementPreview.isValid = false;
    }

    if (!world.contains(placementPreview)) {
      world.add(placementPreview);
    }
  }

  void hidePlacementPreview() {
    if (world.contains(placementPreview)) {
      world.remove(placementPreview);
    }
  }
}

class PlacementPreview extends PositionComponent with HasGameRef<MainGame> {
  Building? building;
  bool isValid = false;

  void setBuilding(Building? newBuilding) {
    building = newBuilding;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (building == null) {
      return;
    }

    final buildingSize = sqrt(building!.gridSize).toInt();
    final width = (cellWidth * buildingSize).toDouble();
    final height = (cellHeight * buildingSize).toDouble();

    final rect = Rect.fromLTWH(
      2,
      2,
      width - 4,
      height - 4,
    );

    // Get sprite from the grid's cache
    final sprite = gameRef.grid.getSpriteForBuilding(building!);

    // Render the building sprite if available
    if (sprite != null) {
      // Draw a semi-transparent background first
      final backgroundPaint = Paint()
        ..color = (isValid ? Colors.green : Colors.red).withAlpha(50)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, backgroundPaint);
      
      // Draw the building sprite with transparency
      final spritePaint = Paint()
        ..colorFilter = ColorFilter.mode(
          (isValid ? Colors.white : Colors.red).withAlpha(180),
          BlendMode.modulate,
        );
      
      sprite.render(
        canvas, 
        position: Vector2(rect.left, rect.top), 
        size: Vector2(rect.width, rect.height),
        overridePaint: spritePaint,
      );
      
      // Draw a border
      final borderPaint = Paint()
        ..color = (isValid ? Colors.green : Colors.red)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, borderPaint);
    } else {
      // Fallback to colored rectangle if no sprite available
      final paint = Paint()
        ..color = (isValid ? Colors.green : Colors.red).withAlpha(100)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);
    }
  }
}