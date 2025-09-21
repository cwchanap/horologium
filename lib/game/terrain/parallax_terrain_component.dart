import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import '../grid.dart';
import 'parallax_terrain_layer.dart';
import 'terrain_biome.dart';
import 'terrain_depth_manager.dart';
import 'terrain_generator.dart';

class ParallaxTerrainComponent extends PositionComponent with HasGameReference {
  final int gridSize;
  final TerrainGenerator generator;
  final Map<String, TerrainCell> _baseTerrain = {};
  final Map<TerrainDepth, ParallaxTerrainLayer> _parallaxLayers = {};
  
  bool _isLoaded = false;
  bool _loggedParentRenderOnce = false;
  
  // Toggle for debug overlays (fill, border, axes, markers)
  bool showDebug = false;
  // Toggle for parallax across all layers
  bool parallaxEnabled = true;

  ParallaxTerrainComponent({
    required this.gridSize,
    int? seed,
  }) : generator = TerrainGenerator(gridSize: gridSize, seed: seed ?? 42);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set component size to match the grid
    size = Vector2(gridSize * cellWidth, gridSize * cellHeight);
    
    // Generate base terrain data
    _generateTerrain();
    
    // Create parallax layers
    await _createParallaxLayers();
    
    _isLoaded = true;
  }

  void _generateTerrain() {
    _baseTerrain.clear();
    final generatedTerrain = generator.generateTerrain();
    _baseTerrain.addAll(generatedTerrain);
  }

  Future<void> _createParallaxLayers() async {
    _parallaxLayers.clear();
    removeAll(children);

    // Get sorted depths (far to near)
    final sortedDepths = TerrainDepthManager.getSortedDepths();
    
    for (final depth in sortedDepths) {
      // Skip interactive layer - that's handled by the grid
      if (depth == TerrainDepth.interactive) continue;
      
      // Filter terrain data for this depth layer
      Map<String, TerrainCell> layerTerrain;
      
      if (depth == TerrainDepth.farBackground) {
        // Generate special far background terrain (distant mountains)
        layerTerrain = TerrainDepthManager.generateFarBackgroundTerrain(
          gridSize,
          _baseTerrain,
        );
      } else {
        // Filter existing terrain for this depth
        layerTerrain = TerrainDepthManager.filterTerrainForDepth(
          _baseTerrain,
          depth,
        );
      }

      // Create parallax layer if it has terrain to render
      if (layerTerrain.isNotEmpty) {
        final parallaxLayer = ParallaxTerrainLayer(
          depth: depth,
          terrainData: layerTerrain,
          gridSize: gridSize,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
        );
        
        // Match grid & layer rendering: draw from local top-left with Anchor.center.
        // For a center-anchored child to align its (0,0) with the parent's (0,0),
        // set the child local position to size/2 (cancels the anchor shift).
        parallaxLayer.size = Vector2(gridSize * cellWidth, gridSize * cellHeight);
        parallaxLayer.anchor = Anchor.center;
        parallaxLayer.position = parallaxLayer.size / 2;
        
        // Propagate debug flag
        parallaxLayer.showDebug = showDebug;
        // Propagate parallax flag
        parallaxLayer.enableParallax = parallaxEnabled;

        _parallaxLayers[depth] = parallaxLayer;
        add(parallaxLayer);
      } else {
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isLoaded) return;
    // 1) Atmosphere under children (local top-left drawing)
    _renderAtmosphereEffects(canvas);

    // 2) Optional parent debug fill (UNDER children)
    if (showDebug) {
      final dbgFill = Paint()
        ..color = const Color(0xFF44FF55).withAlpha(60)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        dbgFill,
      );
    }

    // 3) Render children (terrain layers)
    super.render(canvas);

    // 4) Optional red border, axes and debug markers (local top-left drawing)
    if (showDebug) {
      final borderPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        borderPaint,
      );

      // Center axes to visualize the component's local center
      final axesPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      // Vertical axis at x = size.x/2
      canvas.drawLine(
        Offset(size.x / 2, 0),
        Offset(size.x / 2, size.y),
        axesPaint,
      );
      // Horizontal axis at y = size.y/2
      canvas.drawLine(
        Offset(0, size.y / 2),
        Offset(size.x, size.y / 2),
        axesPaint,
      );

      // Debug markers for local top-left
      final pTopLeftPaint = Paint()..color = Colors.green;       // (0,0)
      final pCenterPaint = Paint()..color = Colors.orange;       // (size/2, size/2)
      final pBottomRightPaint = Paint()..color = Colors.cyan;    // (size-40, size-40)
      // Larger markers for visibility
      canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 40), pTopLeftPaint);
      canvas.drawRect(Rect.fromLTWH(size.x / 2 - 20, size.y / 2 - 20, 40, 40), pCenterPaint);
      canvas.drawRect(Rect.fromLTWH(size.x - 40, size.y - 40, 40, 40), pBottomRightPaint);
    }

    if (!_loggedParentRenderOnce) {
      _loggedParentRenderOnce = true;
    }
  }

  void _renderAtmosphereEffects(Canvas canvas) {
    // Subtle ambient lighting, local top-left
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 2.0,
      colors: [
        Colors.yellow.withValues(alpha: 0.05),
        Colors.transparent,
        Colors.blue.withValues(alpha: 0.02),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.x, size.y),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      paint,
    );
  }

  /// Get terrain data for a specific cell (for buildability checks)
  TerrainCell? getTerrainAt(int x, int y) {
    final key = '$x,$y';
    return _baseTerrain[key];
  }

  /// Check if a grid cell has buildable terrain
  bool isBuildableAt(int x, int y) {
    final terrain = getTerrainAt(x, y);
    if (terrain == null) return true; // Default to buildable if no terrain data
    
    // Water and steep terrain are typically not buildable
    if (terrain.baseType == TerrainType.water) {
      return false;
    }
    
    // Very steep terrain is not buildable
    if (terrain.elevation > 0.8) {
      return false;
    }
    
    // Large features block building (check all features across all layers)
    for (final feature in terrain.features) {
      if (_isLargeFeature(feature)) {
        return false;
      }
    }
    
    return true;
  }

  bool _isLargeFeature(FeatureType feature) {
    switch (feature) {
      case FeatureType.treeOakLarge:
      case FeatureType.treePineLarge:
      case FeatureType.rockLarge:
      case FeatureType.lakeSmall:
      case FeatureType.lakeLarge:
        return true;
      default:
        return false;
    }
  }

  /// Regenerate terrain with a new seed
  Future<void> regenerateTerrain({int? newSeed}) async {
    if (newSeed != null) {
      // Create new generator with different seed
      final newGenerator = TerrainGenerator(gridSize: gridSize, seed: newSeed);
      _baseTerrain.clear();
      _baseTerrain.addAll(newGenerator.generateTerrain());
    } else {
      _generateTerrain();
    }
    
    await _createParallaxLayers();
  }

  /// Get all parallax layers (useful for debugging or effects)
  List<ParallaxTerrainLayer> getAllLayers() {
    return _parallaxLayers.values.toList();
  }

  /// Get a specific parallax layer
  ParallaxTerrainLayer? getLayer(TerrainDepth depth) {
    return _parallaxLayers[depth];
  }

  /// Get biome distribution for statistics
  Map<BiomeType, int> getBiomeDistribution() {
    final distribution = <BiomeType, int>{};
    
    for (final terrain in _baseTerrain.values) {
      distribution[terrain.biome] = (distribution[terrain.biome] ?? 0) + 1;
    }
    
    return distribution;
  }

  /// Get terrain statistics
  Map<String, dynamic> getTerrainStats() {
    final stats = <String, dynamic>{
      'totalCells': _baseTerrain.length,
      'biomeDistribution': getBiomeDistribution(),
      'parallaxLayers': _parallaxLayers.length,
      'averageElevation': 0.0,
      'averageMoisture': 0.0,
      'waterPercentage': 0.0,
    };

    if (_baseTerrain.isNotEmpty) {
      double totalElevation = 0.0;
      double totalMoisture = 0.0;
      int waterCells = 0;

      for (final terrain in _baseTerrain.values) {
        totalElevation += terrain.elevation;
        totalMoisture += terrain.moisture;
        if (terrain.baseType == TerrainType.water) {
          waterCells++;
        }
      }

      stats['averageElevation'] = totalElevation / _baseTerrain.length;
      stats['averageMoisture'] = totalMoisture / _baseTerrain.length;
      stats['waterPercentage'] = (waterCells / _baseTerrain.length) * 100;
    }

    return stats;
  }

  /// Enable/disable parallax effect on all layers
  void setParallaxEnabled(bool enabled) {
    parallaxEnabled = enabled;
    for (final layer in _parallaxLayers.values) {
      layer.enableParallax = enabled;
    }
  }

  /// Adjust parallax speeds for all layers (for dramatic effects or settings)
  void adjustParallaxSpeeds(double multiplier) {
    // This could be implemented to dynamically adjust parallax speeds
    // Currently the speeds are fixed in TerrainDepthManager
  }

  /// Enable/disable debug overlays on parent and all child layers
  void setDebugOverlays(bool enabled) {
    showDebug = enabled;
    for (final layer in _parallaxLayers.values) {
      layer.showDebug = enabled;
    }
  }

  /// Generate terrain for a specific region (useful for large worlds)
  Future<void> loadRegion(int startX, int startY, int width, int height) async {
    final regionData = generator.generateRegion(startX, startY, width, height);
    
    // Update base terrain data for this region
    _baseTerrain.addAll(regionData);
    
    // Recreate parallax layers to include new terrain
    await _createParallaxLayers();
  }

  @override
  bool get isLoaded => _isLoaded;
}
