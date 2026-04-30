import 'terrain_biome.dart';

class TerrainAssets {
  TerrainAssets._();

  /// Resolves a [FeatureType] to its asset path, or null if unavailable.
  static String? getFeatureAssetPath(FeatureType feature) {
    switch (feature) {
      case FeatureType.treeOakSmall:
        return treeOakSmall;
      case FeatureType.treeOakLarge:
        return treeOakLarge;
      case FeatureType.treePineSmall:
        return treePineSmall;
      case FeatureType.treePineLarge:
        return treePineLarge;
      case FeatureType.bushGreen:
        return bushGreen;
      case FeatureType.bushFlowering:
        return bushFlowering;
      case FeatureType.rockSmall:
        return rockSmall;
      case FeatureType.rockMedium:
        return rockMedium;
      case FeatureType.rockLarge:
        return rockLarge;
      case FeatureType.riverHorizontal:
        return riverHorizontal;
      case FeatureType.riverVertical:
        return riverVertical;
      case FeatureType.riverCornerTL:
        return riverCornerTL;
      case FeatureType.riverCornerTR:
        return riverCornerTR;
      case FeatureType.riverCornerBL:
        return riverCornerBL;
      case FeatureType.riverCornerBR:
        return riverCornerBR;
      case FeatureType.lakeSmall:
        return lakeSmall;
      case FeatureType.lakeLarge:
        return lakeLarge;
    }
  }

  /// Resolves a [TerrainType] to its base asset path, or null if unavailable.
  static String? getBaseAssetPath(TerrainType type) {
    switch (type) {
      case TerrainType.grass:
        return grassBase;
      case TerrainType.dirt:
        return dirtBase;
      case TerrainType.sand:
        return sandBase;
      case TerrainType.rock:
        return rockBase;
      case TerrainType.snow:
        return snowBase;
      case TerrainType.water:
        // water_base.png not available - will use fallback color
        return null;
    }
  }

  // Base terrain textures (64x64) - Available assets only
  static const String grassBase = 'terrain/base/grass_base.png';
  static const String dirtBase = 'terrain/base/dirt_base.png';
  static const String sandBase = 'terrain/base/sand_base.png';
  static const String rockBase = 'terrain/base/rock_base.png';
  static const String snowBase = 'terrain/base/snow_base.png';
  // Note: water_base.png not available - will use fallback color

  // Detail overlays (256x256)
  static const String grassFlowers = 'terrain/details/grass_flowers.png';
  static const String rockPebbles = 'terrain/details/rock_pebbles.png';
  static const String sandDunes = 'terrain/details/sand_dunes.png';
  static const String dirtPatches = 'terrain/details/dirt_patches.png';

  // Trees
  static const String treeOakSmall =
      'terrain/features/trees/tree_oak_small.png';
  static const String treeOakLarge =
      'terrain/features/trees/tree_oak_large.png';
  static const String treePineSmall =
      'terrain/features/trees/tree_pine_small.png';
  static const String treePineLarge =
      'terrain/features/trees/tree_pine_large.png';

  // Bushes
  static const String bushGreen = 'terrain/features/bushes/bush_green.png';
  static const String bushFlowering =
      'terrain/features/bushes/bush_flowering.png';

  // Rocks
  static const String rockSmall = 'terrain/features/rocks/rock_small.png';
  static const String rockMedium = 'terrain/features/rocks/rock_medium.png';
  static const String rockLarge = 'terrain/features/rocks/rock_large.png';

  // Water features
  static const String riverHorizontal =
      'terrain/features/water/river_horizontal.png';
  static const String riverVertical =
      'terrain/features/water/river_vertical.png';
  static const String riverCornerTL =
      'terrain/features/water/river_corner_tl.png';
  static const String riverCornerTR =
      'terrain/features/water/river_corner_tr.png';
  static const String riverCornerBL =
      'terrain/features/water/river_corner_bl.png';
  static const String riverCornerBR =
      'terrain/features/water/river_corner_br.png';
  static const String lakeSmall = 'terrain/features/water/lake_small.png';
  static const String lakeLarge = 'terrain/features/water/lake_large.png';

  // Paths
  static const String pathDirtStraight =
      'terrain/paths/dirt/path_dirt_straight.png';
  static const String pathDirtCorner =
      'terrain/paths/dirt/path_dirt_corner.png';
  static const String pathStoneStraight =
      'terrain/paths/stone/path_stone_straight.png';
  static const String pathStoneCorner =
      'terrain/paths/stone/path_stone_corner.png';

  // Effects
  static const String buildingShadow =
      'terrain/effects/shadows/building_shadow.png';
  static const String treeShadow = 'terrain/effects/shadows/tree_shadow.png';
  static const String ambientLight =
      'terrain/effects/lighting/ambient_light.png';

  // Get all asset paths for preloading.
  static List<String> get allAssets => [
    // Base terrains
    grassBase, dirtBase, sandBase, rockBase, snowBase,
    // Details
    grassFlowers, rockPebbles, sandDunes, dirtPatches,
    // Trees
    treeOakSmall, treeOakLarge, treePineSmall, treePineLarge,
    // Bushes
    bushGreen, bushFlowering,
    // Rocks
    rockSmall, rockMedium, rockLarge,
    // Water features
    riverHorizontal,
    riverVertical,
    riverCornerTL,
    riverCornerTR,
    riverCornerBL,
    riverCornerBR,
    lakeSmall,
    lakeLarge,
    // Paths
    pathDirtStraight, pathDirtCorner, pathStoneStraight, pathStoneCorner,
    // Effects
    buildingShadow, treeShadow, ambientLight,
  ];
}
