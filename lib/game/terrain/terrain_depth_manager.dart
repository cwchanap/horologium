import 'terrain_biome.dart';

enum TerrainDepth {
  farBackground, // 0.1-0.2 speed - distant mountains, sky
  midBackground, // 0.4-0.5 speed - main terrain base
  nearBackground, // 0.7-0.8 speed - large features (trees, rocks)
  foreground, // 0.9 speed - detail overlays, small features
  interactive, // 1.0 speed - grid, buildings (no parallax)
}

class TerrainDepthConfig {
  final double parallaxSpeed;
  final int renderOrder;
  final String layerName;
  final List<TerrainType> allowedTerrainTypes;
  final List<FeatureType> allowedFeatureTypes;

  const TerrainDepthConfig({
    required this.parallaxSpeed,
    required this.renderOrder,
    required this.layerName,
    this.allowedTerrainTypes = const [],
    this.allowedFeatureTypes = const [],
  });
}

class TerrainDepthManager {
  static const Map<TerrainDepth, TerrainDepthConfig> depthConfigs = {
    TerrainDepth.farBackground: TerrainDepthConfig(
      parallaxSpeed: 0.15,
      renderOrder: 0,
      layerName: 'Far Background',
      allowedTerrainTypes: [
        TerrainType.rock, // Distant mountains
        TerrainType.snow, // Snow-capped peaks
      ],
      allowedFeatureTypes: [
        // No features in far background - just base terrain
      ],
    ),

    TerrainDepth.midBackground: TerrainDepthConfig(
      parallaxSpeed: 0.45,
      renderOrder: 1,
      layerName: 'Mid Background',
      allowedTerrainTypes: [
        TerrainType.grass,
        TerrainType.dirt,
        TerrainType.sand,
        TerrainType.water,
      ],
      allowedFeatureTypes: [
        FeatureType.lakeSmall,
        FeatureType.lakeLarge,
        FeatureType.riverHorizontal,
        FeatureType.riverVertical,
      ],
    ),

    TerrainDepth.nearBackground: TerrainDepthConfig(
      parallaxSpeed: 0.75,
      renderOrder: 2,
      layerName: 'Near Background',
      allowedTerrainTypes: [],
      allowedFeatureTypes: [
        FeatureType.treeOakLarge,
        FeatureType.treePineLarge,
        FeatureType.rockLarge,
        FeatureType.rockMedium,
      ],
    ),

    TerrainDepth.foreground: TerrainDepthConfig(
      parallaxSpeed: 0.9,
      renderOrder: 3,
      layerName: 'Foreground',
      allowedTerrainTypes: [],
      allowedFeatureTypes: [
        FeatureType.treeOakSmall,
        FeatureType.treePineSmall,
        FeatureType.bushGreen,
        FeatureType.bushFlowering,
        FeatureType.rockSmall,
      ],
    ),

    TerrainDepth.interactive: TerrainDepthConfig(
      parallaxSpeed: 1.0,
      renderOrder: 4,
      layerName: 'Interactive',
      allowedTerrainTypes: [],
      allowedFeatureTypes: [],
    ),
  };

  /// Get configuration for a specific depth layer
  static TerrainDepthConfig getConfig(TerrainDepth depth) {
    return depthConfigs[depth]!;
  }

  /// Get all depth layers sorted by render order
  static List<TerrainDepth> getSortedDepths() {
    final depths = TerrainDepth.values.toList();
    depths.sort(
      (a, b) => getConfig(a).renderOrder.compareTo(getConfig(b).renderOrder),
    );
    return depths;
  }

  /// Determine which depth layer a terrain type should be rendered on
  static TerrainDepth getDepthForTerrainType(TerrainType terrainType) {
    for (final depth in TerrainDepth.values) {
      final config = getConfig(depth);
      if (config.allowedTerrainTypes.contains(terrainType)) {
        return depth;
      }
    }
    // Default to mid background for base terrain
    return TerrainDepth.midBackground;
  }

  /// Determine which depth layer a feature should be rendered on
  static TerrainDepth getDepthForFeature(FeatureType feature) {
    for (final depth in TerrainDepth.values) {
      final config = getConfig(depth);
      if (config.allowedFeatureTypes.contains(feature)) {
        return depth;
      }
    }
    // Default to foreground for small features
    return TerrainDepth.foreground;
  }

  /// Get features that should appear on a specific depth layer
  static List<FeatureType> getFeaturesForDepth(TerrainDepth depth) {
    return getConfig(depth).allowedFeatureTypes;
  }

  /// Get terrain types that should appear on a specific depth layer
  static List<TerrainType> getTerrainTypesForDepth(TerrainDepth depth) {
    return getConfig(depth).allowedTerrainTypes;
  }

  /// Check if a terrain type should be rendered on a specific depth
  static bool shouldRenderTerrainOnDepth(
    TerrainType terrainType,
    TerrainDepth depth,
  ) {
    return getConfig(depth).allowedTerrainTypes.contains(terrainType);
  }

  /// Check if a feature should be rendered on a specific depth
  static bool shouldRenderFeatureOnDepth(
    FeatureType feature,
    TerrainDepth depth,
  ) {
    return getConfig(depth).allowedFeatureTypes.contains(feature);
  }

  /// Generate terrain cells for a specific depth layer
  static Map<String, TerrainCell> filterTerrainForDepth(
    Map<String, TerrainCell> allTerrain,
    TerrainDepth depth,
  ) {
    final filteredTerrain = <String, TerrainCell>{};
    final config = getConfig(depth);

    // For layers that render base terrain, we need all cells to ensure full coverage
    if (config.allowedTerrainTypes.isNotEmpty) {
      // This layer renders base terrain - include all cells
      for (final entry in allTerrain.entries) {
        final key = entry.key;
        final cell = entry.value;

        final shouldIncludeBase = config.allowedTerrainTypes.contains(
          cell.baseType,
        );
        final filteredFeatures = cell.features
            .where((feature) => config.allowedFeatureTypes.contains(feature))
            .toList();

        if (shouldIncludeBase) {
          // Include with original terrain type
          filteredTerrain[key] = TerrainCell(
            baseType: cell.baseType,
            features: filteredFeatures,
            elevation: cell.elevation,
            moisture: cell.moisture,
            biome: cell.biome,
          );
        } else {
          // Create placeholder cell with default terrain for full coverage
          filteredTerrain[key] = TerrainCell(
            baseType: TerrainType.grass, // Default fallback terrain
            features: filteredFeatures,
            elevation: cell.elevation,
            moisture: cell.moisture,
            biome: cell.biome,
          );
        }
      }
    } else {
      // This layer only renders features - only include cells with relevant features
      for (final entry in allTerrain.entries) {
        final key = entry.key;
        final cell = entry.value;

        final filteredFeatures = cell.features
            .where((feature) => config.allowedFeatureTypes.contains(feature))
            .toList();

        if (filteredFeatures.isNotEmpty) {
          filteredTerrain[key] = TerrainCell(
            baseType: cell.baseType, // Keep original type but won't be rendered
            features: filteredFeatures,
            elevation: cell.elevation,
            moisture: cell.moisture,
            biome: cell.biome,
          );
        }
      }
    }

    return filteredTerrain;
  }

  /// Create background terrain for far background layer
  static Map<String, TerrainCell> generateFarBackgroundTerrain(
    int gridSize,
    Map<String, TerrainCell> baseTerrain,
  ) {
    final farTerrain = <String, TerrainCell>{};

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        final key = '$x,$y';
        final baseCell = baseTerrain[key];

        if (baseCell != null) {
          // Create distant mountains based on elevation
          TerrainType farTerrainType;
          if (baseCell.elevation > 0.6) {
            farTerrainType = baseCell.elevation > 0.8
                ? TerrainType.snow
                : TerrainType.rock;
          } else {
            continue; // No far background for low elevation areas
          }

          farTerrain[key] = TerrainCell(
            baseType: farTerrainType,
            features: [], // No features in far background
            elevation: baseCell.elevation,
            moisture: baseCell.moisture,
            biome: baseCell.biome,
          );
        }
      }
    }

    return farTerrain;
  }
}
