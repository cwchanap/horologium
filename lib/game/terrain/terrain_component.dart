import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import '../grid.dart';
import 'terrain_assets.dart';
import 'terrain_biome.dart';
import 'terrain_generator.dart';
import 'terrain_layer.dart';

class TerrainComponent extends PositionComponent with HasGameReference {
  final int gridSize;
  final TerrainGenerator generator;
  final Map<String, TerrainCell> _terrainData = {};
  final Map<String, TerrainLayer> _terrainLayers = {};

  bool _isLoaded = false;
  late Vector2 _cellSize;

  TerrainComponent({required this.gridSize, int? seed})
    : generator = TerrainGenerator(gridSize: gridSize, seed: seed ?? 42);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Match the grid cell size
    _cellSize = Vector2(cellWidth, cellHeight);

    // Set component size to match the grid
    size = Vector2(gridSize * cellWidth, gridSize * cellHeight);

    // Pre-load all terrain assets
    await _preloadAssets();

    // Generate terrain data
    _generateTerrain();

    // Create terrain layers
    await _createTerrainLayers();

    _isLoaded = true;
  }

  Future<void> _preloadAssets() async {
    // Pre-load all terrain assets for better performance
    for (final assetPath in TerrainAssets.allAssets) {
      try {
        await game.images.load(assetPath);
      } catch (e) {
        // Skip missing assets for now - they'll use fallback colors
        // print('Warning: Could not load terrain asset: $assetPath');
      }
    }
  }

  void _generateTerrain() {
    _terrainData.clear();
    _terrainData.addAll(generator.generateTerrain());
  }

  Future<void> _createTerrainLayers() async {
    _terrainLayers.clear();
    removeAll(children);

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        final key = '$x,$y';
        final terrainCell = _terrainData[key];

        if (terrainCell != null) {
          final layer = TerrainLayer(
            terrainType: terrainCell.baseType,
            features: terrainCell.features,
            renderOrder: 0,
          );

          // Position the layer at the correct grid cell
          layer.position = Vector2(x * cellWidth, y * cellHeight);
          layer.size = _cellSize;

          _terrainLayers[key] = layer;
          add(layer);
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isLoaded) return;

    super.render(canvas);

    // Optional: Render ambient lighting overlay
    _renderAmbientLighting(canvas);
  }

  void _renderAmbientLighting(Canvas canvas) {
    // Create a subtle ambient lighting effect
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.5,
      colors: [Colors.yellow.withValues(alpha: 0.1), Colors.transparent],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }

  /// Get terrain data for a specific cell
  TerrainCell? getTerrainAt(int x, int y) {
    final key = '$x,$y';
    return _terrainData[key];
  }

  /// Update terrain at a specific location
  Future<void> updateTerrainAt(int x, int y, TerrainCell newTerrain) async {
    final key = '$x,$y';
    _terrainData[key] = newTerrain;

    final layer = _terrainLayers[key];
    if (layer != null) {
      await layer.updateTerrain(newTerrain.baseType, newTerrain.features);
    }
  }

  /// Regenerate terrain with a new seed
  Future<void> regenerateTerrain({int? newSeed}) async {
    if (newSeed != null) {
      // Create new generator with different seed
      final newGenerator = TerrainGenerator(gridSize: gridSize, seed: newSeed);
      _terrainData.clear();
      _terrainData.addAll(newGenerator.generateTerrain());
    } else {
      _generateTerrain();
    }

    await _createTerrainLayers();
  }

  /// Get all terrain layers (useful for debugging or effects)
  List<TerrainLayer> getAllLayers() {
    return _terrainLayers.values.toList();
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

    // Large features block building
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

  /// Get biome distribution for statistics
  Map<BiomeType, int> getBiomeDistribution() {
    final distribution = <BiomeType, int>{};

    for (final terrain in _terrainData.values) {
      distribution[terrain.biome] = (distribution[terrain.biome] ?? 0) + 1;
    }

    return distribution;
  }

  /// Get terrain statistics
  Map<String, dynamic> getTerrainStats() {
    final stats = <String, dynamic>{
      'totalCells': _terrainData.length,
      'biomeDistribution': getBiomeDistribution(),
      'averageElevation': 0.0,
      'averageMoisture': 0.0,
      'waterPercentage': 0.0,
    };

    if (_terrainData.isNotEmpty) {
      double totalElevation = 0.0;
      double totalMoisture = 0.0;
      int waterCells = 0;

      for (final terrain in _terrainData.values) {
        totalElevation += terrain.elevation;
        totalMoisture += terrain.moisture;
        if (terrain.baseType == TerrainType.water) {
          waterCells++;
        }
      }

      stats['averageElevation'] = totalElevation / _terrainData.length;
      stats['averageMoisture'] = totalMoisture / _terrainData.length;
      stats['waterPercentage'] = (waterCells / _terrainData.length) * 100;
    }

    return stats;
  }

  /// Generate terrain for a specific region (useful for large worlds)
  Future<void> loadRegion(int startX, int startY, int width, int height) async {
    final regionData = generator.generateRegion(startX, startY, width, height);

    // Update terrain data for this region
    _terrainData.addAll(regionData);

    // Create layers for the new region
    for (int x = startX; x < startX + width && x < gridSize; x++) {
      for (int y = startY; y < startY + height && y < gridSize; y++) {
        final key = '$x,$y';
        final terrainCell = regionData[key];

        if (terrainCell != null && !_terrainLayers.containsKey(key)) {
          final layer = TerrainLayer(
            terrainType: terrainCell.baseType,
            features: terrainCell.features,
            renderOrder: 0,
          );

          layer.position = Vector2(x * cellWidth, y * cellHeight);
          layer.size = _cellSize;

          _terrainLayers[key] = layer;
          add(layer);
        }
      }
    }
  }

  @override
  bool get isLoaded => _isLoaded;
}
