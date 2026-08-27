import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';

void main() {
  test('keeps closed site, node, bay, and rig identities', () {
    expect(MiningSiteId.values, hasLength(9));
    expect(MiningNodeId.values.map((id) => id.name), ['n1', 'n2', 'n3', 'n4']);
    expect(DockBayId.values.map((id) => id.name), ['b1', 'b2', 'b3', 'b4']);
    expect(RigTier.values.map((tier) => tier.name), [
      't1',
      't2',
      't3',
      't4',
      't5',
    ]);
  });

  test('reuses current rate and capacity ladders for rigs', () {
    expect(MiningContentRegistry.rateMultipliers, [1.0, 1.5, 2.25, 3.25, 4.5]);
    expect(MiningContentRegistry.capacityMultipliers, [
      1.0,
      1.5,
      2.0,
      3.0,
      4.0,
    ]);
  });

  test('exposes planets and sites in authored order', () {
    final content = MiningContentRegistry.stellarMining();

    expect(MiningPlanetId.values, [
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
      MiningPlanetId.marsFrontier,
    ]);
    expect(content.planets.keys, [
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
      MiningPlanetId.marsFrontier,
    ]);
    expect(content.planet(MiningPlanetId.homeworld).sites.map((s) => s.id), [
      MiningSiteId.landingBasin,
      MiningSiteId.carbonRidge,
      MiningSiteId.graniteCrater,
    ]);
    expect(
      content.planet(MiningPlanetId.lunarFrontier).sites.map((s) => s.id),
      [
        MiningSiteId.frozenBasin,
        MiningSiteId.titaniumHighlands,
        MiningSiteId.heliumMare,
      ],
    );
    expect(content.planet(MiningPlanetId.marsFrontier).sites.map((s) => s.id), [
      MiningSiteId.ochreBasin,
      MiningSiteId.silicaDunes,
      MiningSiteId.cobaltChasm,
    ]);
  });

  test('freezes all site economy and node availability values', () {
    final content = MiningContentRegistry.stellarMining();

    final expected = <MiningSiteId, Map<String, Object?>>{
      MiningSiteId.landingBasin: {
        'resource': ResourceType.gold,
        'requiredSite': null,
        'surveying': 0,
        'unlock': 0,
        'rate': 0.50,
        'capacity': 90,
        'sale': 4,
        'nodes': [0, 0, 1, 2],
      },
      MiningSiteId.carbonRidge: {
        'resource': ResourceType.coal,
        'requiredSite': MiningSiteId.landingBasin,
        'surveying': 0,
        'unlock': 250,
        'rate': 0.75,
        'capacity': 120,
        'sale': 3,
        'nodes': [0, 1, 2, 3],
      },
      MiningSiteId.graniteCrater: {
        'resource': ResourceType.stone,
        'requiredSite': MiningSiteId.carbonRidge,
        'surveying': 0,
        'unlock': 700,
        'rate': 0.60,
        'capacity': 120,
        'sale': 5,
        'nodes': [0, 1, 2, 3],
      },
      MiningSiteId.frozenBasin: {
        'resource': ResourceType.waterIce,
        'requiredSite': null,
        'surveying': 3,
        'unlock': 0,
        'rate': 1.00,
        'capacity': 150,
        'sale': 6,
        'nodes': [3, 3, 4, 5],
      },
      MiningSiteId.titaniumHighlands: {
        'resource': ResourceType.titaniumOre,
        'requiredSite': MiningSiteId.frozenBasin,
        'surveying': 4,
        'unlock': 3000,
        'rate': 0.80,
        'capacity': 140,
        'sale': 12,
        'nodes': [4, 4, 5, 5],
      },
      MiningSiteId.heliumMare: {
        'resource': ResourceType.helium3,
        'requiredSite': MiningSiteId.titaniumHighlands,
        'surveying': 5,
        'unlock': 8000,
        'rate': 0.55,
        'capacity': 120,
        'sale': 30,
        'nodes': [5, 5, 5, 5],
      },
      MiningSiteId.ochreBasin: {
        'resource': ResourceType.ironOre,
        'requiredSite': null,
        'surveying': 5,
        'unlock': 0,
        'rate': 0.75,
        'capacity': 180,
        'sale': 32,
        'nodes': [5, 5, 5, 5],
      },
      MiningSiteId.silicaDunes: {
        'resource': ResourceType.silica,
        'requiredSite': MiningSiteId.ochreBasin,
        'surveying': 5,
        'unlock': 12000,
        'rate': 0.55,
        'capacity': 160,
        'sale': 55,
        'nodes': [5, 5, 5, 5],
      },
      MiningSiteId.cobaltChasm: {
        'resource': ResourceType.cobaltOre,
        'requiredSite': MiningSiteId.silicaDunes,
        'surveying': 5,
        'unlock': 30000,
        'rate': 0.35,
        'capacity': 130,
        'sale': 110,
        'nodes': [5, 5, 5, 5],
      },
    };

    for (final entry in expected.entries) {
      final site = content.site(entry.key);
      final values = entry.value;
      expect(site.resource, values['resource']);
      expect(site.requiredSite, values['requiredSite']);
      expect(site.requiredSurveyingLevel, values['surveying']);
      expect(site.unlockCost, values['unlock']);
      expect(site.baseRatePerSecond, values['rate']);
      expect(site.baseCapacity, values['capacity']);
      expect(site.saleValuePerUnit, values['sale']);
      expect(
        site.nodes.map((node) => node.requiredSurveyingLevel),
        values['nodes'],
      );
      expect(site.nodes.map((node) => node.id), MiningNodeId.values);
      expect(site.cavernAsset, startsWith('assets/images/mining/caverns/'));
      expect(site.nodeAsset, startsWith('assets/images/mining/nodes/'));
      expect(site.cardAsset, startsWith('assets/images/mining/'));
    }
  });

  test('freezes technology, offline, planet, and Mars reward metadata', () {
    final content = MiningContentRegistry.stellarMining();

    expect(MiningContentRegistry.technologyCosts, [300, 700, 1500, 4000, 9000]);
    expect(MiningContentRegistry.technologySiteGates, [
      MiningSiteId.landingBasin,
      MiningSiteId.carbonRidge,
      MiningSiteId.graniteCrater,
      MiningSiteId.frozenBasin,
      MiningSiteId.titaniumHighlands,
    ]);
    expect(MiningContentRegistry.offlineCapsByLogistics, [
      const Duration(hours: 8),
      const Duration(hours: 10),
      const Duration(hours: 12),
      const Duration(hours: 16),
      const Duration(hours: 20),
      const Duration(hours: 24),
    ]);

    final homeworld = content.planet(MiningPlanetId.homeworld);
    expect(homeworld.rigSpawnCost, 25);
    expect(homeworld.unlockRequiredMasteryPlanetId, isNull);
    expect(homeworld.unlockRequiredSurveyingLevel, 0);
    expect(homeworld.unlockCashCost, 0);
    expect(homeworld.masteryRewardCash, 0);
    expect(homeworld.planetAsset, 'assets/images/mining/planets/homeworld.png');

    final lunar = content.planet(MiningPlanetId.lunarFrontier);
    expect(lunar.rigSpawnCost, 500);
    expect(lunar.unlockRequiredMasteryPlanetId, MiningPlanetId.homeworld);
    expect(lunar.unlockRequiredSurveyingLevel, 3);
    expect(lunar.unlockCashCost, 2500);
    expect(lunar.masteryRewardCash, 0);
    expect(
      lunar.planetAsset,
      'assets/images/mining/planets/lunar_frontier.png',
    );

    final mars = content.planet(MiningPlanetId.marsFrontier);
    expect(mars.name, 'Mars Frontier');
    expect(mars.rigSpawnCost, 5000);
    expect(mars.unlockRequiredMasteryPlanetId, MiningPlanetId.lunarFrontier);
    expect(mars.unlockRequiredSurveyingLevel, 5);
    expect(mars.unlockCashCost, 20000);
    expect(mars.masteryRewardCash, 25000);
    expect(mars.planetAsset, 'assets/images/mining/planets/mars_frontier.png');
  });

  test('preserves optional Mars site copy and final asset paths', () {
    final content = MiningContentRegistry.stellarMining();
    final ochre = content.site(MiningSiteId.ochreBasin);

    expect(ochre.facilityName, 'Iron Rig');
    expect(
      ochre.discoveryText,
      'iron-rich regolith supports the first heavy extraction rig.',
    );
    expect(ochre.cavernAsset, 'assets/images/mining/caverns/iron_ore.png');
    expect(ochre.nodeAsset, 'assets/images/mining/nodes/iron_ore.png');
    expect(ochre.cardAsset, 'assets/images/mining/caverns/iron_ore.png');
  });

  test('one T1 preserves the current Landing Basin base capacity', () {
    final content = MiningContentRegistry.stellarMining();
    expect(
      content.effectiveSiteCapacity(MiningSiteId.landingBasin, const [
        RigTier.t1,
      ], 0),
      90,
    );
  });

  test('four rigs contribute storage shares without normalization', () {
    final content = MiningContentRegistry.stellarMining();
    expect(
      content.effectiveSiteCapacity(MiningSiteId.landingBasin, const [
        RigTier.t1,
        RigTier.t1,
        RigTier.t1,
        RigTier.t1,
      ], 0),
      360,
    );
    expect(
      content.effectiveSiteCapacity(MiningSiteId.landingBasin, const [
        RigTier.t5,
        RigTier.t5,
        RigTier.t5,
        RigTier.t5,
      ], 5),
      2880,
    );
  });

  test('site and planet lookups resolve globally unique site ids', () {
    final content = MiningContentRegistry.stellarMining();

    expect(
      content.planetForSite(MiningSiteId.frozenBasin),
      MiningPlanetId.lunarFrontier,
    );
    expect(
      content.planetForSite(MiningSiteId.landingBasin),
      MiningPlanetId.homeworld,
    );
  });

  test('planet mastery requires all three sites on that planet', () {
    final content = MiningContentRegistry.stellarMining();
    const homeworld = {
      MiningSiteId.landingBasin,
      MiningSiteId.carbonRidge,
      MiningSiteId.graniteCrater,
    };
    const lunar = {
      MiningSiteId.frozenBasin,
      MiningSiteId.titaniumHighlands,
      MiningSiteId.heliumMare,
    };
    const mars = {
      MiningSiteId.ochreBasin,
      MiningSiteId.silicaDunes,
      MiningSiteId.cobaltChasm,
    };

    expect(
      content.isPlanetMastered(MiningPlanetId.homeworld, homeworld),
      isTrue,
    );
    expect(
      content.isPlanetMastered(MiningPlanetId.lunarFrontier, lunar),
      isTrue,
    );
    expect(content.isPlanetMastered(MiningPlanetId.marsFrontier, mars), isTrue);
    expect(
      content.isPlanetMastered(
        MiningPlanetId.homeworld,
        {...homeworld}..remove(MiningSiteId.graniteCrater),
      ),
      isFalse,
    );
    expect(
      content.isPlanetMastered(
        MiningPlanetId.lunarFrontier,
        {...lunar}..remove(MiningSiteId.heliumMare),
      ),
      isFalse,
    );
  });

  test('resource silhouettes retain every resource identity', () {
    final silhouettes = MiningContentRegistry.resourceSilhouettes;

    expect(silhouettes.keys.toSet(), ResourceType.values.toSet());
    final water = silhouettes[ResourceType.waterIce]!;
    final titanium = silhouettes[ResourceType.titaniumOre]!;
    final helium = silhouettes[ResourceType.helium3]!;
    expect({water.icon, titanium.icon, helium.icon}.length, 3);
    expect({water.name, titanium.name, helium.name}.length, 3);
    expect({water.color, titanium.color, helium.color}.length, 3);
    expect(water.icon, isA<IconData>());
  });
}
