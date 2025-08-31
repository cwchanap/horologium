class TerrainAssets {
  TerrainAssets._();

  // Base terrain textures (64x64) - Available assets only
  static const String grassBase = 'terrain/base/grass_base.png';
  static const String dirtBase = 'terrain/base/dirt_base.png';
  static const String sandBase = 'terrain/base/sand_base.png';
  static const String rockBase = 'terrain/base/rock_base.png';
  static const String snowBase = 'terrain/base/snow_base.png';
  // Note: water_base.png not available - will use fallback color

  // Detail overlays (256x256)
  static const String grassFlowers = 'images/terrain/details/grass_flowers.png';
  static const String rockPebbles = 'images/terrain/details/rock_pebbles.png';
  static const String sandDunes = 'images/terrain/details/sand_dunes.png';
  static const String dirtPatches = 'images/terrain/details/dirt_patches.png';

  // Trees
  static const String treeOakSmall = 'terrain/features/trees/tree_oak_small.png';
  static const String treeOakLarge = 'terrain/features/trees/tree_oak_large.png';
  static const String treePineSmall = 'terrain/features/trees/tree_pine_small.png';
  static const String treePineLarge = 'terrain/features/trees/tree_pine_large.png';

  // Bushes
  static const String bushGreen = 'images/terrain/features/bushes/bush_green.png';
  static const String bushFlowering = 'images/terrain/features/bushes/bush_flowering.png';

  // Rocks
  static const String rockSmall = 'images/terrain/features/rocks/rock_small.png';
  static const String rockMedium = 'images/terrain/features/rocks/rock_medium.png';
  static const String rockLarge = 'images/terrain/features/rocks/rock_large.png';

  // Water features
  static const String riverHorizontal = 'images/terrain/features/water/river_horizontal.png';
  static const String riverVertical = 'images/terrain/features/water/river_vertical.png';
  static const String riverCornerTL = 'images/terrain/features/water/river_corner_tl.png';
  static const String riverCornerTR = 'images/terrain/features/water/river_corner_tr.png';
  static const String riverCornerBL = 'images/terrain/features/water/river_corner_bl.png';
  static const String riverCornerBR = 'images/terrain/features/water/river_corner_br.png';
  static const String lakeSmall = 'images/terrain/features/water/lake_small.png';
  static const String lakeLarge = 'images/terrain/features/water/lake_large.png';

  // Paths
  static const String pathDirtStraight = 'images/terrain/paths/dirt/path_dirt_straight.png';
  static const String pathDirtCorner = 'images/terrain/paths/dirt/path_dirt_corner.png';
  static const String pathStoneStraight = 'images/terrain/paths/stone/path_stone_straight.png';
  static const String pathStoneCorner = 'images/terrain/paths/stone/path_stone_corner.png';

  // Effects
  static const String buildingShadow = 'images/terrain/effects/shadows/building_shadow.png';
  static const String treeShadow = 'images/terrain/effects/shadows/tree_shadow.png';
  static const String ambientLight = 'images/terrain/effects/lighting/ambient_light.png';

  // Get all asset paths for preloading (only available assets)
  static List<String> get allAssets => [
    // Base terrains (only available assets)
    grassBase, dirtBase, sandBase, rockBase, snowBase,
    // Trees (only available assets)
    treeOakSmall, treeOakLarge,
    // TODO: Add more assets as they become available
    // Details, bushes, rocks, water features, paths, effects
  ];
}
