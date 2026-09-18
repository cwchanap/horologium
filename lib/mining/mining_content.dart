import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_grid.dart';

enum MiningPlanetId { homeworld, lunarFrontier, marsFrontier }

enum MiningSiteId {
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

enum DockBayId { b1, b2, b3, b4 }

enum RigTier { t1, t2, t3, t4, t5 }

enum TechnologyTrack { extraction, logistics, surveying }

class MiningSiteDefinition {
  MiningSiteDefinition({
    required this.id,
    required this.name,
    required this.resource,
    required this.unlockCost,
    required this.requiredSite,
    required this.requiredSurveyingLevel,
    required this.baseRatePerSecond,
    required this.baseCapacity,
    required this.saleValuePerUnit,
    required this.gridWidth,
    required this.gridHeight,
    required List<MiningDepositDefinition> deposits,
    required this.cavernAsset,
    required this.depositAsset,
    required this.cardAsset,
    this.facilityName,
    this.discoveryText,
  }) : deposits = List.unmodifiable(deposits),
       perimeterCellsByDeposit = _perimeterCellsByDeposit(
         gridWidth: gridWidth,
         gridHeight: gridHeight,
         deposits: deposits,
       );

  final MiningSiteId id;
  final String name;
  final ResourceType resource;
  final int unlockCost;
  final MiningSiteId? requiredSite;
  final int requiredSurveyingLevel;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final int gridWidth;
  final int gridHeight;
  final List<MiningDepositDefinition> deposits;
  final Map<MiningDepositDefinition, Set<MiningGridCell>>
  perimeterCellsByDeposit;
  final String cavernAsset;
  final String depositAsset;
  final String cardAsset;
  final String? facilityName;
  final String? discoveryText;
}

const _denseGridWidth = 50;
const _denseGridHeight = 50;

const _surveyingProgressionLevels = <MiningSiteId, List<int>>{
  MiningSiteId.landingBasin: [0, 0, 1, 2],
  MiningSiteId.carbonRidge: [0, 1, 2, 3],
  MiningSiteId.graniteCrater: [0, 1, 2, 3],
  MiningSiteId.frozenBasin: [3, 3, 4, 5],
  MiningSiteId.titaniumHighlands: [4, 4, 5, 5],
  MiningSiteId.heliumMare: [5, 5, 5, 5],
  MiningSiteId.ochreBasin: [5, 5, 5, 5],
  MiningSiteId.silicaDunes: [5, 5, 5, 5],
  MiningSiteId.cobaltChasm: [5, 5, 5, 5],
};

Map<MiningDepositDefinition, Set<MiningGridCell>> _perimeterCellsByDeposit({
  required int gridWidth,
  required int gridHeight,
  required List<MiningDepositDefinition> deposits,
}) => Map.unmodifiable({
  for (final deposit in deposits)
    deposit: Set.unmodifiable(
      miningPerimeterCells(
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        deposits: deposits,
        target: deposit,
      ),
    ),
});

List<MiningDepositDefinition> _denseResourceField(MiningSiteId siteId) {
  final progressionLevels = _surveyingProgressionLevels[siteId]!;
  final maxLevel = progressionLevels.reduce((a, b) => a > b ? a : b);
  final deposits = <MiningDepositDefinition>[];

  for (var row = 0; row < 10; row++) {
    for (var column = 0; column < 10; column++) {
      final index = row * 10 + column;
      final value = (siteId.index * 31 + index * 17 + index * index * 7) % 97;
      final isProgressionResource = index < 4;
      final size = isProgressionResource ? 2 + index % 2 : 1 + value % 3;
      final requiredSurveyingLevel = isProgressionResource
          ? progressionLevels[index]
          : maxLevel;
      final movableSpan = 4 - size;
      final offsetX = 1 + (value ~/ 3) % movableSpan;
      final offsetY = 1 + (value ~/ 11) % movableSpan;

      deposits.add(
        MiningDepositDefinition(
          x: column * 5 + offsetX,
          y: row * 5 + offsetY,
          size: size,
          requiredSurveyingLevel: requiredSurveyingLevel,
        ),
      );
    }
  }

  return List.unmodifiable(deposits);
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
  MiningPlanetDefinition({
    required this.id,
    required this.name,
    required List<MiningSiteDefinition> sites,
    required this.unlockRequiredMasteryPlanetId,
    required this.unlockRequiredSurveyingLevel,
    required this.unlockCashCost,
    required this.masteryRewardCash,
    required this.rigSpawnCost,
    required this.planetAsset,
  }) : sites = List.unmodifiable(sites);

  final MiningPlanetId id;
  final String name;
  final List<MiningSiteDefinition> sites;
  final MiningPlanetId? unlockRequiredMasteryPlanetId;
  final int unlockRequiredSurveyingLevel;
  final int unlockCashCost;
  final int masteryRewardCash;
  final int rigSpawnCost;
  final String planetAsset;
}

class MiningContentRegistry {
  MiningContentRegistry._(Map<MiningPlanetId, MiningPlanetDefinition> planets)
    : planets = Map.unmodifiable(planets);

  static const int maxTechnologyLevel = 5;
  static const int maxDeployedRigsPerSite = 4;
  static const technologyCosts = <int>[300, 700, 1500, 4000, 9000];
  static const technologySiteGates = <MiningSiteId>[
    MiningSiteId.landingBasin,
    MiningSiteId.carbonRidge,
    MiningSiteId.graniteCrater,
    MiningSiteId.frozenBasin,
    MiningSiteId.titaniumHighlands,
  ];
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

  static final MiningContentRegistry _stellar = _buildStellarMining();

  factory MiningContentRegistry.stellarMining() => _stellar;

  static MiningContentRegistry
  _buildStellarMining() => MiningContentRegistry._({
    MiningPlanetId.homeworld: MiningPlanetDefinition(
      id: MiningPlanetId.homeworld,
      name: 'Homeworld',
      unlockRequiredMasteryPlanetId: null,
      unlockRequiredSurveyingLevel: 0,
      unlockCashCost: 0,
      masteryRewardCash: 0,
      rigSpawnCost: 25,
      planetAsset: 'assets/images/mining/planets/homeworld.png',
      sites: [
        MiningSiteDefinition(
          id: MiningSiteId.landingBasin,
          name: 'Landing Basin',
          resource: ResourceType.gold,
          unlockCost: 0,
          requiredSite: null,
          requiredSurveyingLevel: 0,
          baseRatePerSecond: 0.50,
          baseCapacity: 90,
          saleValuePerUnit: 4,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.landingBasin),
          cavernAsset: 'assets/images/mining/caverns/gold.png',
          depositAsset: 'assets/images/mining/nodes/gold.png',
          cardAsset: 'assets/images/mining/sites/landing_basin.png',
        ),
        MiningSiteDefinition(
          id: MiningSiteId.carbonRidge,
          name: 'Carbon Ridge',
          resource: ResourceType.coal,
          unlockCost: 250,
          requiredSite: MiningSiteId.landingBasin,
          requiredSurveyingLevel: 0,
          baseRatePerSecond: 0.75,
          baseCapacity: 120,
          saleValuePerUnit: 3,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.carbonRidge),
          cavernAsset: 'assets/images/mining/caverns/coal.png',
          depositAsset: 'assets/images/mining/nodes/coal.png',
          cardAsset: 'assets/images/mining/sites/carbon_ridge.png',
        ),
        MiningSiteDefinition(
          id: MiningSiteId.graniteCrater,
          name: 'Granite Crater',
          resource: ResourceType.stone,
          unlockCost: 700,
          requiredSite: MiningSiteId.carbonRidge,
          requiredSurveyingLevel: 0,
          baseRatePerSecond: 0.60,
          baseCapacity: 120,
          saleValuePerUnit: 5,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.graniteCrater),
          cavernAsset: 'assets/images/mining/caverns/stone.png',
          depositAsset: 'assets/images/mining/nodes/stone.png',
          cardAsset: 'assets/images/mining/sites/granite_crater.png',
        ),
      ],
    ),
    MiningPlanetId.lunarFrontier: MiningPlanetDefinition(
      id: MiningPlanetId.lunarFrontier,
      name: 'Lunar Frontier',
      unlockRequiredMasteryPlanetId: MiningPlanetId.homeworld,
      unlockRequiredSurveyingLevel: 3,
      unlockCashCost: 2500,
      masteryRewardCash: 0,
      rigSpawnCost: 500,
      planetAsset: 'assets/images/mining/planets/lunar_frontier.png',
      sites: [
        MiningSiteDefinition(
          id: MiningSiteId.frozenBasin,
          name: 'Frozen Basin',
          resource: ResourceType.waterIce,
          unlockCost: 0,
          requiredSite: null,
          requiredSurveyingLevel: 3,
          baseRatePerSecond: 1.00,
          baseCapacity: 150,
          saleValuePerUnit: 6,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.frozenBasin),
          cavernAsset: 'assets/images/mining/caverns/water_ice.png',
          depositAsset: 'assets/images/mining/nodes/water_ice.png',
          cardAsset: 'assets/images/mining/caverns/water_ice.png',
        ),
        MiningSiteDefinition(
          id: MiningSiteId.titaniumHighlands,
          name: 'Titanium Highlands',
          resource: ResourceType.titaniumOre,
          unlockCost: 3000,
          requiredSite: MiningSiteId.frozenBasin,
          requiredSurveyingLevel: 4,
          baseRatePerSecond: 0.80,
          baseCapacity: 140,
          saleValuePerUnit: 12,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.titaniumHighlands),
          cavernAsset: 'assets/images/mining/caverns/titanium_ore.png',
          depositAsset: 'assets/images/mining/nodes/titanium_ore.png',
          cardAsset: 'assets/images/mining/caverns/titanium_ore.png',
        ),
        MiningSiteDefinition(
          id: MiningSiteId.heliumMare,
          name: 'Helium Mare',
          resource: ResourceType.helium3,
          unlockCost: 8000,
          requiredSite: MiningSiteId.titaniumHighlands,
          requiredSurveyingLevel: 5,
          baseRatePerSecond: 0.55,
          baseCapacity: 120,
          saleValuePerUnit: 30,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.heliumMare),
          cavernAsset: 'assets/images/mining/caverns/helium_3.png',
          depositAsset: 'assets/images/mining/nodes/helium_3.png',
          cardAsset: 'assets/images/mining/caverns/helium_3.png',
        ),
      ],
    ),
    MiningPlanetId.marsFrontier: MiningPlanetDefinition(
      id: MiningPlanetId.marsFrontier,
      name: 'Mars Frontier',
      unlockRequiredMasteryPlanetId: MiningPlanetId.lunarFrontier,
      unlockRequiredSurveyingLevel: 5,
      unlockCashCost: 20000,
      masteryRewardCash: 25000,
      rigSpawnCost: 5000,
      planetAsset: 'assets/images/mining/planets/mars_frontier.png',
      sites: [
        MiningSiteDefinition(
          id: MiningSiteId.ochreBasin,
          name: 'Ochre Basin',
          resource: ResourceType.ironOre,
          unlockCost: 0,
          requiredSite: null,
          requiredSurveyingLevel: 5,
          baseRatePerSecond: 0.75,
          baseCapacity: 180,
          saleValuePerUnit: 32,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.ochreBasin),
          cavernAsset: 'assets/images/mining/caverns/iron_ore.png',
          depositAsset: 'assets/images/mining/nodes/iron_ore.png',
          cardAsset: 'assets/images/mining/caverns/iron_ore.png',
          facilityName: 'Iron Rig',
          discoveryText:
              'iron-rich regolith supports the first heavy extraction rig.',
        ),
        MiningSiteDefinition(
          id: MiningSiteId.silicaDunes,
          name: 'Silica Dunes',
          resource: ResourceType.silica,
          unlockCost: 12000,
          requiredSite: MiningSiteId.ochreBasin,
          requiredSurveyingLevel: 5,
          baseRatePerSecond: 0.55,
          baseCapacity: 160,
          saleValuePerUnit: 55,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.silicaDunes),
          cavernAsset: 'assets/images/mining/caverns/silica.png',
          depositAsset: 'assets/images/mining/nodes/silica.png',
          cardAsset: 'assets/images/mining/caverns/silica.png',
          facilityName: 'Silica Extractor',
          discoveryText:
              'glassy dune deposits trade lower throughput for stronger sale value.',
        ),
        MiningSiteDefinition(
          id: MiningSiteId.cobaltChasm,
          name: 'Cobalt Chasm',
          resource: ResourceType.cobaltOre,
          unlockCost: 30000,
          requiredSite: MiningSiteId.silicaDunes,
          requiredSurveyingLevel: 5,
          baseRatePerSecond: 0.35,
          baseCapacity: 130,
          saleValuePerUnit: 110,
          gridWidth: _denseGridWidth,
          gridHeight: _denseGridHeight,
          deposits: _denseResourceField(MiningSiteId.cobaltChasm),
          cavernAsset: 'assets/images/mining/caverns/cobalt_ore.png',
          depositAsset: 'assets/images/mining/nodes/cobalt_ore.png',
          cardAsset: 'assets/images/mining/caverns/cobalt_ore.png',
          facilityName: 'Cobalt Drill',
          discoveryText:
              'deep cobalt seams are the final high-value Mars target.',
        ),
      ],
    ),
  });

  MiningPlanetDefinition planet(MiningPlanetId id) => planets[id]!;

  MiningSiteDefinition site(MiningSiteId id) => planets.values
      .expand((planet) => planet.sites)
      .singleWhere((site) => site.id == id);

  MiningPlanetId planetForSite(MiningSiteId id) => planets.entries
      .singleWhere((entry) => entry.value.sites.any((site) => site.id == id))
      .key;

  double rigRateMultiplier(RigTier tier) => rateMultipliers[tier.index];

  double rigCapacityMultiplier(RigTier tier) => capacityMultipliers[tier.index];

  double effectiveSiteRate(
    MiningSiteId id,
    Iterable<RigTier> rigs,
    int extraction,
  ) =>
      site(id).baseRatePerSecond *
      rigs.fold<double>(0, (sum, tier) => sum + rigRateMultiplier(tier)) *
      extractionRateMultipliers[extraction];

  double effectiveSiteCapacity(
    MiningSiteId id,
    Iterable<RigTier> rigs,
    int logistics,
  ) =>
      site(id).baseCapacity *
      rigs.fold<double>(0, (sum, tier) => sum + rigCapacityMultiplier(tier)) *
      logisticsCapacityMultipliers[logistics];

  Duration offlineCapFor(int logistics) => offlineCapsByLogistics[logistics];

  /// Planet mastery: every site on [planetId] is commissioned. Takes only
  /// site ids so content never imports mining state.
  bool isPlanetMastered(
    MiningPlanetId planetId,
    Iterable<MiningSiteId> commissionedSiteIds,
  ) {
    final commissioned = commissionedSiteIds.toSet();
    return planet(
      planetId,
    ).sites.every((site) => commissioned.contains(site.id));
  }
}
