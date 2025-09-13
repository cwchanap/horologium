import 'dart:math';

import 'terrain_biome.dart';

class TerrainGenerator {
  final int gridSize;
  final int seed;
  final Random _random;

  TerrainGenerator({
    required this.gridSize,
    this.seed = 42,
  }) : _random = Random(seed);

  /// Generate terrain data for the entire grid
  Map<String, TerrainCell> generateTerrain() {
    final terrain = <String, TerrainCell>{};
    
    // Generate elevation and moisture maps using Perlin-like noise
    final elevationMap = _generateElevationMap();
    final moistureMap = _generateMoistureMap();
    
    // Generate terrain based on elevation and moisture
    for (int xCoord = 0; xCoord < gridSize; xCoord++) {
      for (int yCoord = 0; yCoord < gridSize; yCoord++) {
        final key = '$xCoord,$yCoord';
        final elevation = elevationMap[key] ?? 0.5;
        final moisture = moistureMap[key] ?? 0.5;
        
        // Determine biome based on elevation and moisture
        final biome = _determineBiome(elevation, moisture);
        final biomeConfig = BiomeRegistry.getConfig(biome);
        
        // Select primary terrain type
        final terrainType = _selectTerrainType(biomeConfig, elevation, moisture);
        
        // Generate features for this cell
        final features = _generateFeatures(biomeConfig, xCoord, yCoord, elevation, moisture);
        
        terrain[key] = TerrainCell(
          baseType: terrainType,
          features: features,
          elevation: elevation,
          moisture: moisture,
          biome: biome,
        );
      }
    }
    
    // Post-process to add coherent features like rivers and paths
    _addCoherentFeatures(terrain);
    
    return terrain;
  }

  /// Generate elevation map using noise function
  Map<String, double> _generateElevationMap() {
    final elevationMap = <String, double>{};
    const scale = 0.1;
    
    for (int xCoord = 0; xCoord < gridSize; xCoord++) {
      for (int yCoord = 0; yCoord < gridSize; yCoord++) {
        final key = '$xCoord,$yCoord';
        
        // Multi-octave noise for more natural elevation
        double elevation = 0.0;
        double amplitude = 1.0;
        double frequency = scale;
        
        for (int octave = 0; octave < 4; octave++) {
          elevation += _noise(xCoord * frequency, yCoord * frequency) * amplitude;
          amplitude *= 0.5;
          frequency *= 2;
        }
        
        // Normalize to 0-1 range
        elevation = (elevation + 1) / 2;
        elevation = elevation.clamp(0.0, 1.0);
        
        elevationMap[key] = elevation;
      }
    }
    
    return elevationMap;
  }

  /// Generate moisture map using noise function
  Map<String, double> _generateMoistureMap() {
    final moistureMap = <String, double>{};
    const scale = 0.08;
    
    for (int xCoord = 0; xCoord < gridSize; xCoord++) {
      for (int yCoord = 0; yCoord < gridSize; yCoord++) {
        final key = '$xCoord,$yCoord';
        
        // Different seed offset for moisture
        double moisture = _noise((xCoord + 1000) * scale, (yCoord + 1000) * scale);
        
        // Normalize to 0-1 range
        moisture = (moisture + 1) / 2;
        moisture = moisture.clamp(0.0, 1.0);
        
        moistureMap[key] = moisture;
      }
    }
    
    return moistureMap;
  }

  /// Simple noise function (simplified Perlin noise)
  double _noise(double x, double y) {
    // Hash-based noise function
    int ix = x.floor();
    int iy = y.floor();
    
    double fx = x - ix;
    double fy = y - iy;
    
    // Get random values at grid corners
    double a = _hash(ix, iy);
    double b = _hash(ix + 1, iy);
    double c = _hash(ix, iy + 1);
    double d = _hash(ix + 1, iy + 1);
    
    // Interpolate
    double i1 = _lerp(a, b, fx);
    double i2 = _lerp(c, d, fx);
    
    return _lerp(i1, i2, fy);
  }

  /// Hash function for noise
  double _hash(int x, int y) {
    int hash = (x * 374761393 + y * 668265263) ^ seed;
    hash = (hash ^ (hash >> 13)) * 1274126177;
    hash = hash ^ (hash >> 16);
    return (hash & 0x7fffffff) / 2147483647.0 * 2.0 - 1.0;
  }

  /// Linear interpolation
  double _lerp(double a, double b, double t) {
    return a + t * (b - a);
  }

  /// Determine biome based on elevation and moisture
  BiomeType _determineBiome(double elevation, double moisture) {
    // Simple biome determination based on elevation and moisture
    if (elevation > 0.7) {
      return moisture > 0.3 ? BiomeType.mountains : BiomeType.tundra;
    } else if (elevation < 0.2) {
      return moisture > 0.6 ? BiomeType.wetlands : BiomeType.desert;
    } else if (moisture > 0.7) {
      return BiomeType.forest;
    } else if (moisture < 0.3) {
      return BiomeType.desert;
    } else {
      return BiomeType.grassland;
    }
  }

  /// Select terrain type based on biome configuration
  TerrainType _selectTerrainType(BiomeConfig config, double elevation, double moisture) {
    // Primarily use the primary terrain type
    if (_random.nextDouble() < 0.7) {
      return config.primaryTerrain;
    }
    
    // Sometimes use secondary terrain types
    if (config.secondaryTerrains.isNotEmpty) {
      return config.secondaryTerrains[_random.nextInt(config.secondaryTerrains.length)];
    }
    
    return config.primaryTerrain;
  }

  /// Generate features for a terrain cell
  List<FeatureType> _generateFeatures(
    BiomeConfig config, 
    int x, 
    int y, 
    double elevation, 
    double moisture,
  ) {
    final features = <FeatureType>[];
    
    // Don't place features on every cell to avoid clutter
    if (_random.nextDouble() > 0.3) {
      return features;
    }
    
    // Randomly select from common features for this biome
    if (config.commonFeatures.isNotEmpty) {
      final featureIndex = _random.nextInt(config.commonFeatures.length);
      features.add(config.commonFeatures[featureIndex]);
    }
    
    return features;
  }

  /// Add coherent features like rivers that span multiple cells
  void _addCoherentFeatures(Map<String, TerrainCell> terrain) {
    // Add a few rivers
    _addRivers(terrain, 2 + _random.nextInt(3));
    
    // Add some paths connecting areas
    _addPaths(terrain, 1 + _random.nextInt(2));
  }

  /// Add rivers to the terrain
  void _addRivers(Map<String, TerrainCell> terrain, int riverCount) {
    for (int i = 0; i < riverCount; i++) {
      // Start from a high elevation point
      int startX = _random.nextInt(gridSize);
      int startY = _random.nextInt(gridSize);
      
      // Find the path downhill
      var currentX = startX;
      var currentY = startY;
      
      for (int step = 0; step < 20; step++) {
        final key = '$currentX,$currentY';
        final cell = terrain[key];
        if (cell == null) break;
        
        // Add river feature
        final newFeatures = List<FeatureType>.from(cell.features);
        if (_random.nextDouble() < 0.8) {
          // Choose river direction based on path
          if (step % 3 == 0) {
            newFeatures.add(FeatureType.riverHorizontal);
          } else {
            newFeatures.add(FeatureType.riverVertical);
          }
        }
        
        terrain[key] = cell.copyWith(features: newFeatures);
        
        // Move to next cell (simplified - just move randomly)
        final direction = _random.nextInt(4);
        switch (direction) {
          case 0: currentX = (currentX + 1).clamp(0, gridSize - 1);
          case 1: currentX = (currentX - 1).clamp(0, gridSize - 1);
          case 2: currentY = (currentY + 1).clamp(0, gridSize - 1);
          case 3: currentY = (currentY - 1).clamp(0, gridSize - 1);
        }
      }
    }
  }

  /// Add paths to connect different areas
  void _addPaths(Map<String, TerrainCell> terrain, int pathCount) {
    // Implementation for adding paths (simplified for now)
    // This would create dirt or stone paths connecting points of interest
  }

  /// Generate terrain for a specific region (useful for streaming)
  Map<String, TerrainCell> generateRegion(int startX, int startY, int width, int height) {
    final terrain = <String, TerrainCell>{};
    
    // Generate just the requested region
    for (int x = startX; x < startX + width && x < gridSize; x++) {
      for (int y = startY; y < startY + height && y < gridSize; y++) {
        final key = '$x,$y';
        
        // Use the same generation logic but for specific coordinates
        final elevation = _generateElevationForCell(x, y);
        final moisture = _generateMoistureForCell(x, y);
        final biome = _determineBiome(elevation, moisture);
        final biomeConfig = BiomeRegistry.getConfig(biome);
        final terrainType = _selectTerrainType(biomeConfig, elevation, moisture);
        final features = _generateFeatures(biomeConfig, x, y, elevation, moisture);
        
        terrain[key] = TerrainCell(
          baseType: terrainType,
          features: features,
          elevation: elevation,
          moisture: moisture,
          biome: biome,
        );
      }
    }
    
    return terrain;
  }

  double _generateElevationForCell(int x, int y) {
    const scale = 0.1;
    double elevation = 0.0;
    double amplitude = 1.0;
    double frequency = scale;
    
    for (int octave = 0; octave < 4; octave++) {
      elevation += _noise(x * frequency, y * frequency) * amplitude;
      amplitude *= 0.5;
      frequency *= 2;
    }
    
    elevation = (elevation + 1) / 2;
    return elevation.clamp(0.0, 1.0);
  }

  double _generateMoistureForCell(int x, int y) {
    const scale = 0.08;
    double moisture = _noise((x + 1000) * scale, (y + 1000) * scale);
    moisture = (moisture + 1) / 2;
    return moisture.clamp(0.0, 1.0);
  }
}
