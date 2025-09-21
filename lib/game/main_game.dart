import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

import 'building/building.dart';
import 'grid.dart';
import 'planet/index.dart';
import 'terrain/index.dart';

class MainGame extends FlameGame
    with
        flame_events.TapCallbacks,
        flame_events.PointerMoveCallbacks,
        ScrollDetector,
        ScaleDetector {
  Grid? _grid;
  ParallaxTerrainComponent? _terrain;
  Planet? _planet;
  Function(int, int)? onGridCellTapped;
  Function(int, int)? onGridCellLongTapped;
  Function(int, int)? onGridCellSecondaryTapped;
  Function(Planet)? onPlanetChanged;

  static const double _minZoom = 0.1; // Allow zooming out much further
  static const double _maxZoom = 4.0;
  static const double _zoomPerScrollUnit = 0.02;
  static const double _zoomSpeedMultiplier = 3.0; // 3x faster zooming

  final double _startZoom = _minZoom;
  late double _scaleStartZoom;
  double? _fitZoom; // Computed zoom that fits the whole terrain in the viewport

  Building? buildingToPlace;
  final PlacementPreview placementPreview = PlacementPreview()..priority = 30; // Ensure preview renders above grid

  MainGame({Planet? planet}) : _planet = planet;

  Grid get grid => _grid!;
  ParallaxTerrainComponent? get terrain => _terrain;
  bool get hasLoaded => _grid != null && _terrain != null;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = _startZoom;
    
    // Create terrain first (renders beneath everything)
    _terrain = ParallaxTerrainComponent(
      gridSize: 50, // Match grid size
      seed: _planet?.id.hashCode ?? 42, // Use planet ID as seed for consistent terrain
    );
    // Keep terrain perfectly aligned with the grid (no parallax drift)
    _terrain!.parallaxEnabled = false;
    _terrain!.size = Vector2(_terrain!.gridSize * cellWidth, _terrain!.gridSize * cellHeight);
    _terrain!.anchor = Anchor.center;
    _terrain!.position = Vector2.zero();
    _terrain!.priority = 10; // Terrain underlay for normal gameplay
    
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
    _grid!.priority = 20; // Grid above terrain
    
    world.add(_grid!);
    
    // Calculate proper zoom level to fit the terrain in the viewport
    final terrainSize = _terrain!.size;
    final viewportSize = camera.viewport.size;
    final zoomX = viewportSize.x / terrainSize.x;
    final zoomY = viewportSize.y / terrainSize.y;
    // Zoom to fit the entire terrain in the viewport. Do NOT go below fit,
    // otherwise the viewport becomes larger than the world and clamping breaks.
    final properZoom = math.min(zoomX, zoomY);
    _fitZoom = properZoom; // Save fit zoom so we never allow zooming out beyond full-terrain view
    
    // Apply the proper zoom to fit terrain in viewport
    camera.viewfinder.zoom = properZoom.clamp(_minZoom, _maxZoom);
    // Center the camera on the terrain and clamp within bounds
    _centerCameraOnTerrain();
    
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

  // Note: Panning is handled in onScaleUpdate when scale is identity

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
    // Update preview on tap as well, so it appears even if the cursor hasn't moved
    if (buildingToPlace != null) {
      showPlacementPreview(buildingToPlace!, worldPosition);
    }
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
    final minAllowed = _fitZoom != null ? math.max(_minZoom, _fitZoom!) : _minZoom;
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(minAllowed, _maxZoom);
  }

  // Mouse wheel / trackpad scroll zoom (web/desktop)
  @override
  void onScroll(flame_events.PointerScrollInfo info) {
    camera.viewfinder.zoom += info.scrollDelta.global.y.sign * _zoomPerScrollUnit * _zoomSpeedMultiplier;
    clampZoom();
    _clampCameraToTerrain();
  }

  // Pinch to zoom (mobile & trackpads supporting pinch)
  @override
  void onScaleStart(flame_events.ScaleStartInfo info) {
    _scaleStartZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(flame_events.ScaleUpdateInfo info) {
    final currentScale = info.scale.global;
    // When pinching, scale is not identity; when panning with one finger it is
    if (!currentScale.isIdentity()) {
      // Amplify pinch zooming speed
      final scaleFactor = 1 + (currentScale.y - 1) * _zoomSpeedMultiplier;
      camera.viewfinder.zoom = (_scaleStartZoom * scaleFactor).clamp(_minZoom, _maxZoom);
      _clampCameraToTerrain();
    } else {
      // Handle pan/drag when not scaling
      final zoom = camera.viewfinder.zoom;
      final delta = (info.delta.global..negate()) / zoom;
      camera.moveBy(delta);
      _clampCameraToTerrain();
    }
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
      
      // Calculate position in grid's local coordinate system (top-left indices)
      final localX = gridX * cellWidth;
      final localY = gridY * cellHeight;
      
      // For center-anchored grid at world (0,0), world = local - size/2
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

  // Camera helpers
  void _clampCameraToTerrain() {
    if (_terrain == null) return;
    final w = _terrain!.size.x;
    final h = _terrain!.size.y;

    // Half viewport in world units
    final halfViewW = camera.viewport.size.x / camera.viewfinder.zoom / 2;
    final halfViewH = camera.viewport.size.y / camera.viewfinder.zoom / 2;

    // Terrain is centered at (0,0). Clamp camera center so viewport stays within terrain.
    // If the viewport is larger than the terrain along an axis, pin the camera to 0 on that axis.
    final overWideX = halfViewW >= w / 2;
    final overWideY = halfViewH >= h / 2;

    final minX = -w / 2 + halfViewW;
    final maxX =  w / 2 - halfViewW;
    final minY = -h / 2 + halfViewH;
    final maxY =  h / 2 - halfViewH;

    final pos = camera.viewfinder.position;
    final clampedX = overWideX ? 0.0 : pos.x.clamp(minX, maxX);
    final clampedY = overWideY ? 0.0 : pos.y.clamp(minY, maxY);
    camera.viewfinder.position = Vector2(clampedX, clampedY);
  }

  void _centerCameraOnTerrain() {
    camera.viewfinder.position = Vector2.zero();
    _clampCameraToTerrain();
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