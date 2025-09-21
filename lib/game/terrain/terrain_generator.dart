import 'dart:math';

import 'terrain_biome.dart';

class TerrainGenerator {
  final int gridSize;
  final int seed;
  final Random _random;
  // Phase 1: Patch-based grouping parameters
  final int patchSizeBase;     // approximate patch span in cells (e.g., 9)
  final int patchJitter;       // max center jitter in cells (e.g., 2)
  final double primaryWeight;  // probability to pick biome primary terrain for a patch
  // Phase 2: Edge blending & domain warping
  final double warpAmplitude;  // cells, e.g., 1.5
  final double warpFrequency;  // e.g., 0.18 per cell
  final double edgeWidth;      // blending zone width in cells, e.g., 1.2
  final double edgeGamma;      // blending curve exponent, e.g., 1.6

  TerrainGenerator({
    required this.gridSize,
    this.seed = 42,
    this.patchSizeBase = 9,
    this.patchJitter = 2,
    this.primaryWeight = 0.85,
    this.warpAmplitude = 1.5,
    this.warpFrequency = 0.18,
    this.edgeWidth = 1.2,
    this.edgeGamma = 1.6,
  }) : _random = Random(seed);

  /// Generate terrain data for the entire grid
  Map<String, TerrainCell> generateTerrain() {
    final terrain = <String, TerrainCell>{};
    
    // Generate elevation and moisture maps using Perlin-like noise
    final elevationMap = _generateElevationMap();
    final moistureMap = _generateMoistureMap();

    // Phase 1: Precompute jittered patch centers and per-patch main terrain types
    final patchCenters = _generatePatchCentersForBounds(0, 0, gridSize - 1, gridSize - 1);
    final Map<Point<int>, TerrainType> patchMainTypes = {
      for (final c in patchCenters) c: _choosePatchMainTypeAt(c.x, c.y)
    };

    // Assign cells to nearest (and blend with second-nearest) patch center
    for (int xCoord = 0; xCoord < gridSize; xCoord++) {
      for (int yCoord = 0; yCoord < gridSize; yCoord++) {
        final key = '$xCoord,$yCoord';
        final elevation = elevationMap[key] ?? 0.5;
        final moisture = moistureMap[key] ?? 0.5;

        // Determine biome for feature placement and stats
        final biome = _determineBiome(elevation, moisture);
        final biomeConfig = BiomeRegistry.getConfig(biome);

        // Domain-warped coordinates for organic borders
        final wx = xCoord + warpAmplitude * _noise(xCoord * warpFrequency + 917.0, yCoord * warpFrequency + 613.0);
        final wy = yCoord + warpAmplitude * _noise(xCoord * warpFrequency + 231.0, yCoord * warpFrequency + 101.0);

        // Find nearest and second-nearest centers
        final nearestPair = _nearestTwoCenters(wx, wy, patchCenters);
        final Point<int>? c1 = nearestPair.$1;
        final Point<int>? c2 = nearestPair.$2;
        final double d1 = nearestPair.$3;
        final double d2 = nearestPair.$4;

        // Base from nearest patch
        TerrainType baseType = c1 != null
            ? (patchMainTypes[c1] ?? biomeConfig.primaryTerrain)
            : biomeConfig.primaryTerrain;

        // Edge blending near borders using second nearest patch
        if (c1 != null && c2 != null) {
          final borderMetric = (sqrt(d2) - sqrt(d1)).abs();
          if (borderMetric < edgeWidth) {
            final t = (borderMetric / edgeWidth).clamp(0.0, 1.0);
            final p = 1.0 - pow(t, edgeGamma).toDouble();
            final noiseP = _rand01FromCell(xCoord, yCoord, 4242);
            if (noiseP < p) {
              final neighborType = patchMainTypes[c2] ?? biomeConfig.primaryTerrain;
              baseType = _transitionBlend(baseType, neighborType, elevation, moisture);
            }
          }
        }

        // Generate features for this cell (unchanged)
        final features = _generateFeatures(biomeConfig, xCoord, yCoord, elevation, moisture);

        terrain[key] = TerrainCell(
          baseType: baseType,
          features: features,
          elevation: elevation,
          moisture: moisture,
          biome: biome,
        );
      }
    }

    // Phase 3: Deterministic water overlay & shorelines (seam-free)
    _applyWaterOverlay(terrain);

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

  // Removed legacy coherent features (rivers/paths) in favor of deterministic
  // water overlay with shorelines implemented in _applyWaterOverlay.

  /// Generate terrain for a specific region (useful for streaming)
  Map<String, TerrainCell> generateRegion(int startX, int startY, int width, int height) {
    final terrain = <String, TerrainCell>{};
    
    // Compute an expanded bounds for patch centers to avoid edge artifacts
    final minX = max(0, startX - patchSizeBase * 2);
    final minY = max(0, startY - patchSizeBase * 2);
    final maxX = min(gridSize - 1, startX + width - 1 + patchSizeBase * 2);
    final maxY = min(gridSize - 1, startY + height - 1 + patchSizeBase * 2);

    final patchCenters = _generatePatchCentersForBounds(minX, minY, maxX, maxY);
    final Map<Point<int>, TerrainType> patchMainTypes = {
      for (final c in patchCenters) c: _choosePatchMainTypeAt(c.x, c.y)
    };

    // Generate just the requested region with patch-based base assignment & blending
    for (int x = startX; x < startX + width && x < gridSize; x++) {
      for (int y = startY; y < startY + height && y < gridSize; y++) {
        final key = '$x,$y';

        final elevation = _generateElevationForCell(x, y);
        final moisture = _generateMoistureForCell(x, y);
        final biome = _determineBiome(elevation, moisture);
        final biomeConfig = BiomeRegistry.getConfig(biome);

        // Warped coords and nearest-two centers
        final wx = x + warpAmplitude * _noise(x * warpFrequency + 917.0, y * warpFrequency + 613.0);
        final wy = y + warpAmplitude * _noise(x * warpFrequency + 231.0, y * warpFrequency + 101.0);
        final nearestPair = _nearestTwoCenters(wx, wy, patchCenters);
        final Point<int>? c1 = nearestPair.$1;
        final Point<int>? c2 = nearestPair.$2;
        final double d1 = nearestPair.$3;
        final double d2 = nearestPair.$4;

        TerrainType baseType = c1 != null
            ? (patchMainTypes[c1] ?? biomeConfig.primaryTerrain)
            : biomeConfig.primaryTerrain;
        if (c1 != null && c2 != null) {
          final borderMetric = (sqrt(d2) - sqrt(d1)).abs();
          if (borderMetric < edgeWidth) {
            final t = (borderMetric / edgeWidth).clamp(0.0, 1.0);
            final p = 1.0 - pow(t, edgeGamma).toDouble();
            final noiseP = _rand01FromCell(x, y, 4242);
            if (noiseP < p) {
              final neighborType = patchMainTypes[c2] ?? biomeConfig.primaryTerrain;
              baseType = _transitionBlend(baseType, neighborType, elevation, moisture);
            }
          }
        }
        final features = _generateFeatures(biomeConfig, x, y, elevation, moisture);
        
        terrain[key] = TerrainCell(
          baseType: baseType,
          features: features,
          elevation: elevation,
          moisture: moisture,
          biome: biome,
        );
      }
    }

    // Apply deterministic water overlay & shorelines for seam-free region streaming
    _applyWaterOverlay(terrain);
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

  // ===== Phase 1 helpers: patch centers & selection =====

  // Generate jittered patch centers for a rectangular bounds (inclusive)
  List<Point<int>> _generatePatchCentersForBounds(int minX, int minY, int maxX, int maxY) {
    final centers = <Point<int>>[];
    final seen = <String>{};

    final minPx = (minX / patchSizeBase).floor();
    final maxPx = (maxX / patchSizeBase).floor();
    final minPy = (minY / patchSizeBase).floor();
    final maxPy = (maxY / patchSizeBase).floor();

    for (int px = minPx; px <= maxPx; px++) {
      for (int py = minPy; py <= maxPy; py++) {
        final baseCx = px * patchSizeBase + (patchSizeBase ~/ 2);
        final baseCy = py * patchSizeBase + (patchSizeBase ~/ 2);
        final jx = _jitterInt(px, py, 13);
        final jy = _jitterInt(px, py, 37);
        final cx = baseCx + jx;
        final cy = baseCy + jy;

        // Clamp to grid bounds (as ints)
        final clampedX = max(0, min(gridSize - 1, cx));
        final clampedY = max(0, min(gridSize - 1, cy));
        final key = '$clampedX,$clampedY';
        if (!seen.contains(key)) {
          seen.add(key);
          centers.add(Point<int>(clampedX, clampedY));
        }
      }
    }

    return centers;
  }

  /// Public helper for debug/visualization to retrieve patch centers in bounds (inclusive)
  List<Point<int>> getPatchCentersForBounds(int minX, int minY, int maxX, int maxY) {
    return _generatePatchCentersForBounds(minX, minY, maxX, maxY);
  }

  /// Public helper: domain-warped coordinates for a cell
  (double, double) warpCoords(num x, num y) {
    final wx = x + warpAmplitude * _noise(x * warpFrequency + 917.0, y * warpFrequency + 613.0);
    final wy = y + warpAmplitude * _noise(x * warpFrequency + 231.0, y * warpFrequency + 101.0);
    return (wx.toDouble(), wy.toDouble());
  }

  /// Public helper: nearest and second-nearest patch centers to warped coords
  (Point<int>?, Point<int>?, double, double) nearestTwoCenters(double wx, double wy, List<Point<int>> centers) {
    return _nearestTwoCenters(wx, wy, centers);
  }

  /// Public helper: compute border metric (smaller means closer to a border) at cell using provided centers
  double computeBorderMetricAt(int x, int y, List<Point<int>> centers) {
    final (wx, wy) = warpCoords(x, y);
    final (_, __, d1, d2) = _nearestTwoCenters(wx, wy, centers);
    return (sqrt(d2) - sqrt(d1)).abs();
  }

  // Deterministic small integer jitter in [-patchJitter, patchJitter]
  int _jitterInt(int px, int py, int salt) {
    final v = _hash(px * 374761393 + salt, py * 668265263 + seed); // [-1, 1]
    return (v * patchJitter).round();
  }

  // Pick main terrain type for a patch center based on biome at center
  TerrainType _choosePatchMainTypeAt(int cx, int cy) {
    final elevation = _generateElevationForCell(cx, cy);
    final moisture = _generateMoistureForCell(cx, cy);
    final biome = _determineBiome(elevation, moisture);
    final config = BiomeRegistry.getConfig(biome);

    // Prefer land for patch main type; avoid pure water patches in Phase 1
    // If biome primary is water (e.g., wetlands), pick a land secondary if available.
    TerrainType pickFromSecondaries() {
      if (config.secondaryTerrains.isEmpty) {
        // Fallback: choose a plausible land type by moisture
        if (moisture > 0.6) return TerrainType.grass;
        if (moisture < 0.25) return TerrainType.sand;
        return TerrainType.dirt;
      }
      final rIdx = _rand01FromCenter(cx, cy, 997);
      final idx = (rIdx * config.secondaryTerrains.length).floor().clamp(0, config.secondaryTerrains.length - 1);
      final candidate = config.secondaryTerrains[idx];
      // If the randomly chosen secondary is water, swap to a landy fallback
      if (candidate == TerrainType.water) {
        if (moisture > 0.6) return TerrainType.grass;
        if (moisture < 0.25) return TerrainType.sand;
        return TerrainType.dirt;
      }
      return candidate;
    }

    final rPrimary = _rand01FromCenter(cx, cy, 991);
    if (config.primaryTerrain == TerrainType.water) {
      // Avoid water as patch main type: choose land-oriented secondary/fallback
      return pickFromSecondaries();
    }

    if (rPrimary < primaryWeight) {
      return config.primaryTerrain;
    }
    return pickFromSecondaries();
  }

  // Deterministic 0..1 value from center coords and salt
  double _rand01FromCenter(int cx, int cy, int salt) {
    final v = _hash(cx * 1103515245 + salt, cy * 12345 + seed); // [-1,1]
    return (v + 1.0) * 0.5; // [0,1]
  }

  // Euclidean distance squared between a cell (x,y) and center (cx,cy)
  double _distanceSquared(double x, double y, int cx, int cy) {
    final dx = x - cx;
    final dy = y - cy;
    return dx * dx + dy * dy;
  }

  // Find nearest and second-nearest centers to (wx, wy)
  (Point<int>?, Point<int>?, double, double) _nearestTwoCenters(double wx, double wy, List<Point<int>> centers) {
    Point<int>? first;
    Point<int>? second;
    double d1 = double.infinity;
    double d2 = double.infinity;
    for (final c in centers) {
      final dist2 = _distanceSquared(wx, wy, c.x, c.y);
      if (dist2 < d1) {
        // shift current best to second
        second = first;
        d2 = d1;
        first = c;
        d1 = dist2;
      } else if (dist2 < d2) {
        second = c;
        d2 = dist2;
      }
    }
    return (first, second, d1, d2);
  }

  // Deterministic 0..1 for a cell
  double _rand01FromCell(int x, int y, int salt) {
    final v = _hash(x * 2654435761 % 0x7fffffff + salt, y * 40503 % 0x7fffffff + seed);
    return (v + 1.0) * 0.5;
  }

  // Transition rules for edge blending
  TerrainType _transitionBlend(
    TerrainType core,
    TerrainType neighbor,
    double elevation,
    double moisture,
  ) {
    // Water edges prefer sand
    if (core == TerrainType.water || neighbor == TerrainType.water) {
      return TerrainType.sand;
    }
    // Snow transitions toward rock
    if (core == TerrainType.snow || neighbor == TerrainType.snow) {
      return TerrainType.rock;
    }
    // Rock transitions toward dirt
    if (core == TerrainType.rock || neighbor == TerrainType.rock) {
      return TerrainType.dirt;
    }
    // Sand transitions toward dirt
    if (core == TerrainType.sand || neighbor == TerrainType.sand) {
      return TerrainType.dirt;
    }
    // Grass vs dirt by moisture
    return (moisture > 0.45) ? TerrainType.grass : TerrainType.dirt;
  }

  // ===== Phase 3: Deterministic water overlay & shorelines =====
  void _applyWaterOverlay(Map<String, TerrainCell> terrain) {
    // First pass: determine water mask and set baseType to water
    final keys = terrain.keys.toList();
    for (final key in keys) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final x = int.tryParse(parts[0]);
      final y = int.tryParse(parts[1]);
      if (x == null || y == null) continue;
      if (_isWaterAt(x, y)) {
        final cell = terrain[key]!;
        terrain[key] = cell.copyWith(baseType: TerrainType.water);
      }
    }

    // Second pass: shoreline sand on non-water cells adjacent to water
    for (final key in keys) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final x = int.tryParse(parts[0]);
      final y = int.tryParse(parts[1]);
      if (x == null || y == null) continue;
      final cell = terrain[key]!;
      if (cell.baseType == TerrainType.water) continue;
      final neighborWater = _isWaterAt(x - 1, y) || _isWaterAt(x + 1, y) || _isWaterAt(x, y - 1) || _isWaterAt(x, y + 1);
      if (neighborWater) {
        terrain[key] = cell.copyWith(baseType: TerrainType.sand);
      }
    }
  }

  bool _isWaterAt(int x, int y) {
    if (x < 0 || y < 0 || x >= gridSize || y >= gridSize) return false;
    final elev = _generateElevationForCell(x, y);
    final moist = _generateMoistureForCell(x, y);
    // Wet and low areas
    final isLow = elev < 0.22;
    final isWet = moist > 0.78;
    // River-like bands using noise near zero
    const rScale = 0.09;
    const rBand = 0.055;
    final rNoise = _noise((x + 2000) * rScale, (y + 2000) * rScale);
    final river = (rNoise.abs() < rBand);
    // Lakes using high-value noise in wet + low
    const lScale = 0.05;
    final lNoise = (_noise((x + 4000) * lScale, (y + 4000) * lScale) + 1.0) * 0.5; // 0..1
    final lake = lNoise > 0.85;
    return isLow && isWet && (river || lake);
  }
}
