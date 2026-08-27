import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';

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

enum MiningNodeId { n1, n2, n3, n4 }

enum DockBayId { b1, b2, b3, b4 }

enum RigTier { t1, t2, t3, t4, t5 }

enum TechnologyTrack { extraction, logistics, surveying }

class MiningNodeDefinition {
  const MiningNodeDefinition({
    required this.id,
    required this.requiredSurveyingLevel,
  });

  final MiningNodeId id;
  final int requiredSurveyingLevel;
}

class MiningSiteDefinition {
  const MiningSiteDefinition({
    required this.id,
    required this.name,
    required this.resource,
    required this.unlockCost,
    required this.requiredSite,
    required this.requiredSurveyingLevel,
    required this.baseRatePerSecond,
    required this.baseCapacity,
    required this.saleValuePerUnit,
    required this.nodes,
    required this.cavernAsset,
    required this.nodeAsset,
    required this.cardAsset,
    this.facilityName,
    this.discoveryText,
  });

  final MiningSiteId id;
  final String name;
  final ResourceType resource;
  final int unlockCost;
  final MiningSiteId? requiredSite;
  final int requiredSurveyingLevel;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<MiningNodeDefinition> nodes;
  final String cavernAsset;
  final String nodeAsset;
  final String cardAsset;
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
    required this.sites,
    required this.unlockRequiredMasteryPlanetId,
    required this.unlockRequiredSurveyingLevel,
    required this.unlockCashCost,
    required this.masteryRewardCash,
    required this.rigSpawnCost,
    required this.planetAsset,
  });

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
  const MiningContentRegistry._(this.planets);

  static const int maxTechnologyLevel = 5;
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

  factory MiningContentRegistry.stellarMining() => const MiningContentRegistry._({
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 0,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 0,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 1,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 2,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/gold.png',
          nodeAsset: 'assets/images/mining/nodes/gold.png',
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 0,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 1,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 2,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 3,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/coal.png',
          nodeAsset: 'assets/images/mining/nodes/coal.png',
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 0,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 1,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 2,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 3,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/stone.png',
          nodeAsset: 'assets/images/mining/nodes/stone.png',
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 3,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 3,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 4,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 5,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/water_ice.png',
          nodeAsset: 'assets/images/mining/nodes/water_ice.png',
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 4,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 4,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 5,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/titanium_ore.png',
          nodeAsset: 'assets/images/mining/nodes/titanium_ore.png',
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 5,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/helium_3.png',
          nodeAsset: 'assets/images/mining/nodes/helium_3.png',
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 5,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/iron_ore.png',
          nodeAsset: 'assets/images/mining/nodes/iron_ore.png',
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 5,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/silica.png',
          nodeAsset: 'assets/images/mining/nodes/silica.png',
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
          nodes: [
            MiningNodeDefinition(
              id: MiningNodeId.n1,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n2,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n3,
              requiredSurveyingLevel: 5,
            ),
            MiningNodeDefinition(
              id: MiningNodeId.n4,
              requiredSurveyingLevel: 5,
            ),
          ],
          cavernAsset: 'assets/images/mining/caverns/cobalt_ore.png',
          nodeAsset: 'assets/images/mining/nodes/cobalt_ore.png',
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
