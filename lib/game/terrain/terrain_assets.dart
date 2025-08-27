class TerrainAssets {
  TerrainAssets._();

  // Base terrain textures (512x512)
  static const String grassBase = 'terrain/base/grass_base.png';
  static const String dirtBase = 'terrain/base/dirt_base.png';
  static const String sandBase = 'terrain/base/sand_base.png';
  static const String rockBase = 'terrain/base/rock_base.png';
  static const String waterBase = 'terrain/base/water_base.png';
  static const String snowBase = 'terrain/base/snow_base.png';

  // Detail overlays (256x256)
  static const String grassFlowers = 'terrain/details/grass_flowers.png';
  static const String rockPebbles = 'terrain/details/rock_pebbles.png';
  static const String sandDunes = 'terrain/details/sand_dunes.png';
  static const String dirtPatches = 'terrain/details/dirt_patches.png';

  // Trees
  static const String treeOakSmall = 'terrain/features/trees/tree_oak_small.png';
  static const String treeOakLarge = 'terrain/features/trees/tree_oak_large.png';
  static const String treePineSmall = 'terrain/features/trees/tree_pine_small.png';
  static const String treePineLarge = 'terrain/features/trees/tree_pine_large.png';

  // Bushes
  static const String bushGreen = 'terrain/features/bushes/bush_green.png';
  static const String bushFlowering = 'terrain/features/bushes/bush_flowering.png';

  // Rocks
  static const String rockSmall = 'terrain/features/rocks/rock_small.png';
  static const String rockMedium = 'terrain/features/rocks/rock_medium.png';
  static const String rockLarge = 'terrain/features/rocks/rock_large.png';

  // Water features
  static const String riverHorizontal = 'terrain/features/water/river_horizontal.png';
  static const String riverVertical = 'terrain/features/water/river_vertical.png';
  static const String riverCornerTL = 'terrain/features/water/river_corner_tl.png';
  static const String riverCornerTR = 'terrain/features/water/river_corner_tr.png';
  static const String riverCornerBL = 'terrain/features/water/river_corner_bl.png';
  static const String riverCornerBR = 'terrain/features/water/river_corner_br.png';
  static const String lakeSmall = 'terrain/features/water/lake_small.png';
  static const String lakeLarge = 'terrain/features/water/lake_large.png';

  // Paths
  static const String pathDirtStraight = 'terrain/paths/dirt/path_dirt_straight.png';
  static const String pathDirtCorner = 'terrain/paths/dirt/path_dirt_corner.png';
  static const String pathStoneStraight = 'terrain/paths/stone/path_stone_straight.png';
  static const String pathStoneCorner = 'terrain/paths/stone/path_stone_corner.png';

  // Effects
  static const String buildingShadow = 'terrain/effects/shadows/building_shadow.png';
  static const String treeShadow = 'terrain/effects/shadows/tree_shadow.png';
  static const String ambientLight = 'terrain/effects/lighting/ambient_light.png';

  // Get all asset paths for preloading
  static List<String> get allAssets => [
    // Base terrains
    grassBase, dirtBase, sandBase, rockBase, waterBase, snowBase,
    // Details
    grassFlowers, rockPebbles, sandDunes, dirtPatches,
    // Trees
    treeOakSmall, treeOakLarge, treePineSmall, treePineLarge,
    // Bushes
    bushGreen, bushFlowering,
    // Rocks
    rockSmall, rockMedium, rockLarge,
    // Water features
    riverHorizontal, riverVertical, riverCornerTL, riverCornerTR,
    riverCornerBL, riverCornerBR, lakeSmall, lakeLarge,
    // Paths
    pathDirtStraight, pathDirtCorner, pathStoneStraight, pathStoneCorner,
    // Effects
    buildingShadow, treeShadow, ambientLight,
  ];
}
