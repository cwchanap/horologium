import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'building/building.dart';
import 'grid.dart';
import 'planet/index.dart';
import 'terrain/index.dart';

class MainGame extends FlameGame
    with
        flame_events.TapCallbacks,
        flame_events.DragCallbacks,
        flame_events.PointerMoveCallbacks {
  Grid? _grid;
  ParallaxTerrainComponent? _terrain;
  Planet? _planet;
  Function(int, int)? onGridCellTapped;
  Function(int, int)? onGridCellLongTapped;
  Function(int, int)? onGridCellSecondaryTapped;
  Function(Planet)? onPlanetChanged;

  static const double _minZoom = 0.1; // Allow zooming out much further
  static const double _maxZoom = 4.0;

  final double _startZoom = _minZoom;

  Building? buildingToPlace;
  final PlacementPreview placementPreview = PlacementPreview();

  MainGame({Planet? planet}) : _planet = planet;

  Grid get grid => _grid!;
  ParallaxTerrainComponent? get terrain => _terrain;
  bool get hasLoaded => _grid != null && _terrain != null;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = _startZoom;
    
    print('=== MAIN GAME LOAD DEBUG ===');
    print('Camera viewfinder anchor: ${camera.viewfinder.anchor}');
    print('Camera zoom: ${camera.viewfinder.zoom}');
    print('Camera position: ${camera.viewfinder.position}');
    print('Camera viewport size: ${camera.viewport.size}');
    print('Cell dimensions: ${cellWidth}x$cellHeight');
    
    // Create terrain first (renders beneath everything)
    _terrain = ParallaxTerrainComponent(
      gridSize: 50, // Match grid size
      seed: _planet?.id.hashCode ?? 42, // Use planet ID as seed for consistent terrain
    );
    _terrain!.size = Vector2(_terrain!.gridSize * cellWidth, _terrain!.gridSize * cellHeight);
    _terrain!.anchor = Anchor.center;
    _terrain!.position = Vector2.zero();
    
    print('Terrain component:');
    print('  - Size: ${_terrain!.size}');
    print('  - Anchor: ${_terrain!.anchor}');
    print('  - Position: ${_terrain!.position}');
    print('  - Expected size: ${50 * cellWidth}x${50 * cellHeight}');
    
    world.add(_terrain!);
    
    // Create grid (renders above terrain)
    _grid = Grid(
      onBuildingPlaced: _onBuildingPlaced,
      onBuildingRemoved: _onBuildingRemoved,
    );
    _grid!.size = Vector2(_grid!.gridSize * cellWidth, _grid!.gridSize * cellHeight);
    _grid!.anchor = Anchor.center;
    _grid!.position = Vector2.zero();
    _grid!.terrainComponent = _terrain; // Connect terrain to grid
    
    print('Grid component:');
    print('  - Size: ${_grid!.size}');
    print('  - Anchor: ${_grid!.anchor}');
    print('  - Position: ${_grid!.position}');
    print('  - Grid size: ${_grid!.gridSize}');
    
    world.add(_grid!);
    
    // Calculate proper zoom level to fit the terrain in the viewport
    final terrainSize = _terrain!.size;
    final viewportSize = camera.viewport.size;
    final zoomX = viewportSize.x / terrainSize.x;
    final zoomY = viewportSize.y / terrainSize.y;
    final properZoom = math.min(zoomX, zoomY) * 0.8; // 80% to leave some margin
    
    print('=== CAMERA ZOOM CALCULATION ===');
    print('Terrain size: $terrainSize');
    print('Viewport size: $viewportSize');
    print('Zoom ratios: X=$zoomX, Y=$zoomY');
    print('Calculated zoom: $properZoom');
    print('Current zoom: ${camera.viewfinder.zoom}');
    
    // Apply the proper zoom to fit terrain in viewport
    camera.viewfinder.zoom = properZoom.clamp(_minZoom, _maxZoom);
    
    print('Applied zoom: ${camera.viewfinder.zoom}');
    
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
      
      // Check both grid availability and terrain suitability
      final gridAvailable = _grid!.isAreaAvailable(gridX, gridY, building.gridSize);
      final terrainSuitable = _terrain?.isBuildableAt(gridX, gridY) ?? true;
      
      placementPreview.isValid = gridAvailable && terrainSuitable;
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

class PlacementPreview extends PositionComponent with HasGameReference<MainGame> {
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

    final buildingSize = math.sqrt(building!.gridSize).toInt();
    final width = (cellWidth * buildingSize).toDouble();
    final height = (cellHeight * buildingSize).toDouble();

    final rect = Rect.fromLTWH(
      2,
      2,
      width - 4,
      height - 4,
    );

    // Get sprite from the grid's cache
    final sprite = game.grid.getSpriteForBuilding(building!);

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