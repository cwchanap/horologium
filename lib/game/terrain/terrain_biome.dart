enum TerrainType { grass, dirt, sand, rock, water, snow }

enum FeatureType {
  treeOakSmall,
  treeOakLarge,
  treePineSmall,
  treePineLarge,
  bushGreen,
  bushFlowering,
  rockSmall,
  rockMedium,
  rockLarge,
  riverHorizontal,
  riverVertical,
  riverCornerTL,
  riverCornerTR,
  riverCornerBL,
  riverCornerBR,
  lakeSmall,
  lakeLarge,
}

enum BiomeType { grassland, forest, desert, mountains, tundra, wetlands }

class TerrainCell {
  final TerrainType baseType;
  final List<FeatureType> features;
  final double elevation;
  final double moisture;
  final BiomeType biome;

  const TerrainCell({
    required this.baseType,
    this.features = const [],
    this.elevation = 0.0,
    this.moisture = 0.5,
    this.biome = BiomeType.grassland,
  });

  TerrainCell copyWith({
    TerrainType? baseType,
    List<FeatureType>? features,
    double? elevation,
    double? moisture,
    BiomeType? biome,
  }) {
    return TerrainCell(
      baseType: baseType ?? this.baseType,
      features: features ?? this.features,
      elevation: elevation ?? this.elevation,
      moisture: moisture ?? this.moisture,
      biome: biome ?? this.biome,
    );
  }
}

class BiomeConfig {
  final TerrainType primaryTerrain;
  final List<TerrainType> secondaryTerrains;
  final List<FeatureType> commonFeatures;
  final double elevationMin;
  final double elevationMax;
  final double moistureMin;
  final double moistureMax;

  const BiomeConfig({
    required this.primaryTerrain,
    this.secondaryTerrains = const [],
    this.commonFeatures = const [],
    this.elevationMin = 0.0,
    this.elevationMax = 1.0,
    this.moistureMin = 0.0,
    this.moistureMax = 1.0,
  });
}

class BiomeRegistry {
  static const Map<BiomeType, BiomeConfig> configs = {
    BiomeType.grassland: BiomeConfig(
      primaryTerrain: TerrainType.grass,
      secondaryTerrains: [TerrainType.dirt],
      commonFeatures: [
        FeatureType.treeOakSmall,
        FeatureType.bushGreen,
        FeatureType.bushFlowering,
        FeatureType.rockSmall,
      ],
      elevationMin: 0.2,
      elevationMax: 0.6,
      moistureMin: 0.3,
      moistureMax: 0.8,
    ),

    BiomeType.forest: BiomeConfig(
      primaryTerrain: TerrainType.grass,
      secondaryTerrains: [TerrainType.dirt],
      commonFeatures: [
        FeatureType.treeOakLarge,
        FeatureType.treePineLarge,
        FeatureType.treeOakSmall,
        FeatureType.treePineSmall,
        FeatureType.bushGreen,
        FeatureType.rockMedium,
      ],
      elevationMin: 0.1,
      elevationMax: 0.8,
      moistureMin: 0.5,
      moistureMax: 1.0,
    ),

    BiomeType.desert: BiomeConfig(
      primaryTerrain: TerrainType.sand,
      secondaryTerrains: [TerrainType.rock],
      commonFeatures: [
        FeatureType.rockSmall,
        FeatureType.rockMedium,
        FeatureType.rockLarge,
      ],
      elevationMin: 0.0,
      elevationMax: 0.7,
      moistureMin: 0.0,
      moistureMax: 0.3,
    ),

    BiomeType.mountains: BiomeConfig(
      primaryTerrain: TerrainType.rock,
      secondaryTerrains: [TerrainType.dirt, TerrainType.snow],
      commonFeatures: [
        FeatureType.rockLarge,
        FeatureType.rockMedium,
        FeatureType.treePineSmall,
      ],
      elevationMin: 0.6,
      elevationMax: 1.0,
      moistureMin: 0.2,
      moistureMax: 0.7,
    ),

    BiomeType.tundra: BiomeConfig(
      primaryTerrain: TerrainType.snow,
      secondaryTerrains: [TerrainType.rock, TerrainType.dirt],
      commonFeatures: [FeatureType.treePineSmall, FeatureType.rockSmall],
      elevationMin: 0.3,
      elevationMax: 1.0,
      moistureMin: 0.1,
      moistureMax: 0.5,
    ),

    BiomeType.wetlands: BiomeConfig(
      primaryTerrain: TerrainType.water,
      secondaryTerrains: [TerrainType.grass, TerrainType.dirt],
      commonFeatures: [
        FeatureType.lakeSmall,
        FeatureType.riverHorizontal,
        FeatureType.riverVertical,
        FeatureType.bushGreen,
        FeatureType.treeOakSmall,
      ],
      elevationMin: 0.0,
      elevationMax: 0.3,
      moistureMin: 0.7,
      moistureMax: 1.0,
    ),
  };

  static BiomeConfig getConfig(BiomeType biome) {
    return configs[biome] ?? configs[BiomeType.grassland]!;
  }
}
