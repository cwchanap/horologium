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
    _baseTerrain.addAll(generator.generateTerrain());
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
        
        // Position the layer at the correct grid position
        parallaxLayer.position = Vector2.zero();
        parallaxLayer.anchor = Anchor.center;
        
        _parallaxLayers[depth] = parallaxLayer;
        add(parallaxLayer);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isLoaded) return;
    
    super.render(canvas);
    
    // Optional: Add overall atmosphere effects
    _renderAtmosphereEffects(canvas);
  }

  void _renderAtmosphereEffects(Canvas canvas) {
    // Create a subtle ambient lighting effect that affects all layers
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
    for (final layer in _parallaxLayers.values) {
      // This could be extended to pause/resume parallax updates
      layer.priority = enabled ? 0 : -1;
    }
  }

  /// Adjust parallax speeds for all layers (for dramatic effects or settings)
  void adjustParallaxSpeeds(double multiplier) {
    // This could be implemented to dynamically adjust parallax speeds
    // Currently the speeds are fixed in TerrainDepthManager
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
