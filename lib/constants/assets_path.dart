class Assets {
  Assets._();

  /// With Flame's default image prefix 'assets/images/', we only need the path
  /// relative to that folder.

  // Building assets
  static const String house = 'building/house.png';
  static const String coalMine = 'building/coal_mine.png';
  static const String goldMine = 'building/gold_mine.png';
  static const String quarry = 'building/quarry.png';
  static const String researchLab = 'building/research_lab.png';
  static const String waterTreatmentPlant =
      'building/water_treatment_plant.png';
  static const String woodFactory = 'building/wood_factory.png';
  static const String windMill = 'building/wind_mill.png';
  static const String grinderMill = 'building/grinder_mill.png';
  static const String riceHuller = 'building/rice_huller.png';
  static const String maltHouse = 'building/malt_house.png';
  static const String sawmill = 'building/sawmill.png';
  static const String bakery = 'building/bakery.png';

  // Resource icons
  static const String goldIcon = 'resource/gold.png';
  static const String woodIcon = 'resource/wood.png';
  static const String coalIcon = 'resource/coal.png';
  static const String electricityIcon = 'resource/electricity.png';
  static const String researchIcon = 'resource/research.png';
  static const String waterIcon = 'resource/water.png';
  static const String planksIcon = 'resource/plank.png';
  static const String stoneIcon = 'resource/stone.png';
  static const String wheatIcon = 'resource/wheat.png';
  static const String cornIcon = 'resource/corn.png';
  static const String riceIcon = 'resource/rice.png';
  static const String barleyIcon = 'resource/barley.png';
  static const String flourIcon = 'resource/flour.png';
  static const String cornmealIcon = 'resource/cornmeal.png';
  static const String polishedRiceIcon = 'resource/polished_rice.png';
  static const String maltedBarleyIcon = 'resource/malted_barley.png';
  static const String breadIcon = 'resource/bread.png';
  static const String pastriesIcon = 'resource/pastries.png';

  /// Convert a Flame asset path (relative to `assets/images/`) to a Flutter
  /// asset path usable with `Image.asset()`.
  static String flutterAssetPath(String flamePath) =>
      'assets/images/$flamePath';

  // Terrain assets - included for reference but managed by TerrainAssets class
  // Base terrain textures
  static const String terrainGrassBase = 'terrain/base/grass_base.png';
  static const String terrainDirtBase = 'terrain/base/dirt_base.png';
  static const String terrainSandBase = 'terrain/base/sand_base.png';
  static const String terrainRockBase = 'terrain/base/rock_base.png';
  static const String terrainWaterBase = 'terrain/base/water_base.png';
  static const String terrainSnowBase = 'terrain/base/snow_base.png';
}
