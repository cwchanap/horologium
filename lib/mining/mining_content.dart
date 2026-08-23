import 'package:flutter/material.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';

enum MiningPlanetId { homeworld, lunarFrontier, marsFrontier }

enum MiningSectorId {
  landingBasin,
  carbonRidge,
  graniteCrater,
  frozenBasin,
  titaniumHighlands,
  heliumMare,
  ochreBasin,
  silicaDunes,
  cobaltChasm,
}

enum TechnologyTrack { extraction, logistics, surveying }

// World-pixel offset from centered 1800×1800 terrain origin.
class MiningWorldAnchor {
  const MiningWorldAnchor(this.x, this.y);
  final double x;
  final double y;
}

class MiningSectorDefinition {
  const MiningSectorDefinition({
    required this.id,
    required this.name,
    required this.resource,
    required this.mineAsset,
    required this.revealCost,
    required this.requiredSector,
    required this.requiredSurveyingLevel,
    required this.buildCost,
    required this.baseRatePerSecond,
    required this.baseCapacity,
    required this.saleValuePerUnit,
    required this.upgradeCosts,
    required this.anchor,
    this.facilityName,
    this.discoveryText,
  });

  final MiningSectorId id;
  final String name;
  final ResourceType resource;
  final String mineAsset;
  final int revealCost;
  final MiningSectorId? requiredSector;
  final int requiredSurveyingLevel;
  final int buildCost;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<int> upgradeCosts;
  final MiningWorldAnchor anchor;
  final String? facilityName;
  final String? discoveryText;
}

/// Built-in Material-icon silhouette for a resource: distinct icon, display
/// name, and color per [ResourceType], so no PNG assets are needed.
class ResourceSilhouette {
  const ResourceSilhouette({
    required this.icon,
    required this.name,
    required this.color,
  });

  final IconData icon;
  final String name;
  final Color color;
}

class MiningPlanetDefinition {
  const MiningPlanetDefinition({
    required this.id,
    required this.name,
    required this.sectors,
    required this.terrainSeed,
    required this.tint,
    required this.unlockRequiredMasteryPlanetId,
    required this.unlockRequiredSurveyingLevel,
    required this.unlockCashCost,
    required this.masteryRewardCash,
  });

  final MiningPlanetId id;
  final String name;
  final List<MiningSectorDefinition> sectors;
  final int terrainSeed;

  /// Mining-world tint. The world renders this as its atmosphere/background
  /// so each planet keeps a distinct visual identity.
  final Color tint;
  final MiningPlanetId? unlockRequiredMasteryPlanetId;
  final int unlockRequiredSurveyingLevel;
  final int unlockCashCost;
  final int masteryRewardCash;
}

class MiningContentRegistry {
  const MiningContentRegistry._(this.planets);

  static const int terrainGridSize = 36;
  static const double terrainCellSize = 50;
  static const double worldExtent = terrainGridSize * terrainCellSize;
  static const double worldHalfExtent = worldExtent / 2;
  static const int maxTechnologyLevel = 5;
  static const technologyCosts = <int>[300, 700, 1500, 4000, 9000];
  static const technologyMineGates = <MiningSectorId>[
    MiningSectorId.landingBasin,
    MiningSectorId.carbonRidge,
    MiningSectorId.graniteCrater,
    MiningSectorId.frozenBasin,
    MiningSectorId.titaniumHighlands,
  ];
  static const int lunarUnlockCashCost = 2500;
  static const int lunarUnlockSurveyingLevel = 3;
  static const offlineCapsByLogistics = <Duration>[
    Duration(hours: 8),
    Duration(hours: 10),
    Duration(hours: 12),
    Duration(hours: 16),
    Duration(hours: 20),
    Duration(hours: 24),
  ];
  static const rateMultipliers = <double>[1.0, 1.5, 2.25, 3.25, 4.5];
  static const capacityMultipliers = <double>[1.0, 1.5, 2.0, 3.0, 4.0];
  static const extractionRateMultipliers = <double>[
    1.0,
    1.1,
    1.25,
    1.45,
    1.7,
    2.0,
  ];
  static const logisticsCapacityMultipliers = <double>[
    1.0,
    1.15,
    1.3,
    1.5,
    1.75,
    2.0,
  ];

  final Map<MiningPlanetId, MiningPlanetDefinition> planets;

  static const Map<ResourceType, ResourceSilhouette> resourceSilhouettes = {
    ResourceType.gold: ResourceSilhouette(
      icon: Icons.monetization_on,
      name: 'Gold',
      color: Colors.amberAccent,
    ),
    ResourceType.coal: ResourceSilhouette(
      icon: Icons.local_fire_department,
      name: 'Coal',
      color: Colors.blueGrey,
    ),
    ResourceType.stone: ResourceSilhouette(
      icon: Icons.landscape,
      name: 'Stone',
      color: Colors.grey,
    ),
    ResourceType.waterIce: ResourceSilhouette(
      icon: Icons.ac_unit,
      name: 'Water Ice',
      color: Colors.lightBlueAccent,
    ),
    ResourceType.titaniumOre: ResourceSilhouette(
      icon: Icons.diamond,
      name: 'Titanium Ore',
      color: Colors.deepOrangeAccent,
    ),
    ResourceType.helium3: ResourceSilhouette(
      icon: Icons.blur_on,
      name: 'Helium-3',
      color: Colors.cyanAccent,
    ),
    ResourceType.ironOre: ResourceSilhouette(
      icon: Icons.construction,
      name: 'Iron Ore',
      color: Colors.deepOrange,
    ),
    ResourceType.silica: ResourceSilhouette(
      icon: Icons.grain,
      name: 'Silica',
      color: Colors.amber,
    ),
    ResourceType.cobaltOre: ResourceSilhouette(
      icon: Icons.science,
      name: 'Cobalt Ore',
      color: Colors.blueAccent,
    ),
  };

  factory MiningContentRegistry.stellarMining() => const MiningContentRegistry._({
    MiningPlanetId.homeworld: MiningPlanetDefinition(
      id: MiningPlanetId.homeworld,
      name: 'Homeworld',
      terrainSeed: 631,
      tint: Color(0xFF0A1218),
      unlockRequiredMasteryPlanetId: null,
      unlockRequiredSurveyingLevel: 0,
      unlockCashCost: 0,
      masteryRewardCash: 0,
      sectors: [
        MiningSectorDefinition(
          id: MiningSectorId.landingBasin,
          name: 'Landing Basin',
          resource: ResourceType.gold,
          mineAsset: Assets.goldMine,
          revealCost: 0,
          requiredSector: null,
          requiredSurveyingLevel: 0,
          buildCost: 50,
          baseRatePerSecond: 0.50,
          baseCapacity: 90,
          saleValuePerUnit: 4,
          upgradeCosts: [80, 160, 320, 640],
          anchor: MiningWorldAnchor(-72, 396),
        ),
        MiningSectorDefinition(
          id: MiningSectorId.carbonRidge,
          name: 'Carbon Ridge',
          resource: ResourceType.coal,
          mineAsset: Assets.coalMine,
          revealCost: 250,
          requiredSector: MiningSectorId.landingBasin,
          requiredSurveyingLevel: 0,
          buildCost: 100,
          baseRatePerSecond: 0.75,
          baseCapacity: 120,
          saleValuePerUnit: 3,
          upgradeCosts: [150, 300, 600, 1200],
          anchor: MiningWorldAnchor(-396, -72),
        ),
        MiningSectorDefinition(
          id: MiningSectorId.graniteCrater,
          name: 'Granite Crater',
          resource: ResourceType.stone,
          mineAsset: Assets.quarry,
          revealCost: 700,
          requiredSector: MiningSectorId.carbonRidge,
          requiredSurveyingLevel: 0,
          buildCost: 250,
          baseRatePerSecond: 0.60,
          baseCapacity: 120,
          saleValuePerUnit: 5,
          upgradeCosts: [350, 700, 1400, 2800],
          anchor: MiningWorldAnchor(324, -360),
        ),
      ],
    ),
    MiningPlanetId.lunarFrontier: MiningPlanetDefinition(
      id: MiningPlanetId.lunarFrontier,
      name: 'Lunar Frontier',
      terrainSeed: 638,
      tint: Color(0xFF151324),
      unlockRequiredMasteryPlanetId: MiningPlanetId.homeworld,
      unlockRequiredSurveyingLevel: 3,
      unlockCashCost: 2500,
      masteryRewardCash: 0,
      sectors: [
        MiningSectorDefinition(
          id: MiningSectorId.frozenBasin,
          name: 'Frozen Basin',
          resource: ResourceType.waterIce,
          mineAsset: Assets.waterTreatmentPlant,
          revealCost: 0,
          requiredSector: null,
          requiredSurveyingLevel: 3,
          buildCost: 500,
          baseRatePerSecond: 1.00,
          baseCapacity: 150,
          saleValuePerUnit: 6,
          upgradeCosts: [700, 1400, 2800, 5600],
          anchor: MiningWorldAnchor(-420, 320),
        ),
        MiningSectorDefinition(
          id: MiningSectorId.titaniumHighlands,
          name: 'Titanium Highlands',
          resource: ResourceType.titaniumOre,
          mineAsset: Assets.grinderMill,
          revealCost: 3000,
          requiredSector: MiningSectorId.frozenBasin,
          requiredSurveyingLevel: 4,
          buildCost: 1200,
          baseRatePerSecond: 0.80,
          baseCapacity: 140,
          saleValuePerUnit: 12,
          upgradeCosts: [1600, 3200, 6400, 12800],
          anchor: MiningWorldAnchor(120, -80),
        ),
        MiningSectorDefinition(
          id: MiningSectorId.heliumMare,
          name: 'Helium Mare',
          resource: ResourceType.helium3,
          mineAsset: Assets.researchLab,
          revealCost: 8000,
          requiredSector: MiningSectorId.titaniumHighlands,
          requiredSurveyingLevel: 5,
          buildCost: 3000,
          baseRatePerSecond: 0.55,
          baseCapacity: 120,
          saleValuePerUnit: 30,
          upgradeCosts: [4000, 8000, 16000, 32000],
          anchor: MiningWorldAnchor(390, -410),
        ),
      ],
    ),
    MiningPlanetId.marsFrontier: MiningPlanetDefinition(
      id: MiningPlanetId.marsFrontier,
      name: 'Mars Frontier',
      terrainSeed: 641,
      tint: Color(0xFF2A1512),
      unlockRequiredMasteryPlanetId: MiningPlanetId.lunarFrontier,
      unlockRequiredSurveyingLevel: 5,
      unlockCashCost: 20000,
      masteryRewardCash: 25000,
      sectors: [
        MiningSectorDefinition(
          id: MiningSectorId.ochreBasin,
          name: 'Ochre Basin',
          resource: ResourceType.ironOre,
          mineAsset: Assets.woodFactory,
          revealCost: 0,
          requiredSector: null,
          requiredSurveyingLevel: 5,
          buildCost: 5000,
          baseRatePerSecond: 0.75,
          baseCapacity: 180,
          saleValuePerUnit: 32,
          upgradeCosts: [7000, 14000, 28000, 56000],
          anchor: MiningWorldAnchor(-360, 330),
          facilityName: 'Iron Rig',
          discoveryText:
              'iron-rich regolith supports the first heavy extraction rig.',
        ),
        MiningSectorDefinition(
          id: MiningSectorId.silicaDunes,
          name: 'Silica Dunes',
          resource: ResourceType.silica,
          mineAsset: Assets.riceHuller,
          revealCost: 12000,
          requiredSector: MiningSectorId.ochreBasin,
          requiredSurveyingLevel: 5,
          buildCost: 9000,
          baseRatePerSecond: 0.55,
          baseCapacity: 160,
          saleValuePerUnit: 55,
          upgradeCosts: [12000, 24000, 48000, 96000],
          anchor: MiningWorldAnchor(280, -60),
          facilityName: 'Silica Extractor',
          discoveryText:
              'glassy dune deposits trade lower throughput for stronger sale value.',
        ),
        MiningSectorDefinition(
          id: MiningSectorId.cobaltChasm,
          name: 'Cobalt Chasm',
          resource: ResourceType.cobaltOre,
          mineAsset: Assets.sawmill,
          revealCost: 30000,
          requiredSector: MiningSectorId.silicaDunes,
          requiredSurveyingLevel: 5,
          buildCost: 18000,
          baseRatePerSecond: 0.35,
          baseCapacity: 130,
          saleValuePerUnit: 110,
          upgradeCosts: [24000, 48000, 96000, 192000],
          anchor: MiningWorldAnchor(-80, -400),
          facilityName: 'Cobalt Drill',
          discoveryText:
              'deep cobalt seams are the final high-value Mars target.',
        ),
      ],
    ),
  });

  MiningPlanetDefinition planet(MiningPlanetId id) => planets[id]!;

  MiningSectorDefinition sector(MiningSectorId id) => planets.values
      .expand((planet) => planet.sectors)
      .singleWhere((sector) => sector.id == id);

  MiningPlanetId planetForSector(MiningSectorId id) => planets.entries
      .singleWhere(
        (entry) => entry.value.sectors.any((sector) => sector.id == id),
      )
      .key;

  double rateFor(MiningSectorId id, int level) =>
      sector(id).baseRatePerSecond * rateMultipliers[level - 1];

  double capacityFor(MiningSectorId id, int level) =>
      sector(id).baseCapacity * capacityMultipliers[level - 1];

  double effectiveRate(MiningSectorId id, int level, int extraction) =>
      rateFor(id, level) * extractionRateMultipliers[extraction];

  double effectiveCapacity(MiningSectorId id, int level, int logistics) =>
      capacityFor(id, level) * logisticsCapacityMultipliers[logistics];

  Duration offlineCapFor(int logistics) => offlineCapsByLogistics[logistics];

  /// Homeworld mastery: every Homeworld mine exists. Takes only sector ids so
  /// content never imports mining state.
  bool isHomeworldMastered(Iterable<MiningSectorId> minedSectorIds) {
    final mined = minedSectorIds.toSet();
    return planet(
      MiningPlanetId.homeworld,
    ).sectors.every((sector) => mined.contains(sector.id));
  }
}
