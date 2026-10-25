import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';

void main() {
  test('formats cash with separators, then truncated M and B', () {
    for (final entry in {
      0: '0',
      999: '999',
      1000: '1,000',
      999999: '999,999',
      1000000: '1.00M',
      1250000: '1.25M',
      16000000: '16.00M',
      999999999: '999.99M',
      1000000000: '1.00B',
    }.entries) {
      expect(formatMiningCash(entry.key), entry.value, reason: '${entry.key}');
    }
  });

  test('formats resource units with one decimal, then separators', () {
    for (final entry in {
      0.0: '0.0',
      0.5: '0.5',
      0.3: '0.3',
      90.0: '90.0',
      999.9: '999.9',
      999.99: '999.9',
      1000.0: '1,000',
      12960.4: '12,960',
      1250000.0: '1.25M',
    }.entries) {
      expect(formatMiningUnits(entry.key), entry.value, reason: '${entry.key}');
    }
  });

  test('formats waits in whole minutes, rounding up', () {
    for (final entry in {
      Duration.zero: '0m',
      const Duration(seconds: 59): '<1m',
      const Duration(minutes: 1): '1m',
      const Duration(minutes: 14): '14m',
      const Duration(minutes: 14, seconds: 1): '15m',
      const Duration(hours: 1, minutes: 52): '1h 52m',
      const Duration(hours: 1, minutes: 52, seconds: 1): '1h 53m',
      const Duration(hours: 2): '2h 00m',
      const Duration(hours: 24): '24h 00m',
    }.entries) {
      expect(
        formatMiningDuration(entry.key),
        entry.value,
        reason: '${entry.key}',
      );
    }
  });

  test('scales sale multiplier by one half per relaunch', () {
    expect(MiningContentRegistry.saleMultiplier(0), 1.0);
    expect(MiningContentRegistry.saleMultiplier(1), 1.5);
    expect(MiningContentRegistry.saleMultiplier(2), 2.0);
  });

  test('final planet is Ceres Frontier', () {
    expect(
      MiningContentRegistry.stellarMining().finalPlanetId,
      MiningPlanetId.ceresFrontier,
    );
  });

  test('cargoValue applies the relaunch multiplier unrounded', () {
    final content = MiningContentRegistry.stellarMining();

    expect(content.cargoValue(MiningSiteId.landingBasin, 10, 0), 40.0);
    expect(content.cargoValue(MiningSiteId.landingBasin, 10, 2), 80.0);
  });

  test('formats sale multiplier with up to two trimmed decimals', () {
    expect(formatSaleMultiplier(0), '×1');
    expect(formatSaleMultiplier(1), '×1.5');
    expect(formatSaleMultiplier(2), '×2');
  });

  test('keeps closed site, bay, and rig identities', () {
    expect(MiningSiteId.values, hasLength(12));
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
      MiningPlanetId.ceresFrontier,
    ]);
    expect(content.planets.keys, [
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
      MiningPlanetId.marsFrontier,
      MiningPlanetId.ceresFrontier,
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
    expect(
      content.planet(MiningPlanetId.ceresFrontier).sites.map((s) => s.id),
      [
        MiningSiteId.nickelShoals,
        MiningSiteId.platinumRift,
        MiningSiteId.iridiumSpire,
      ],
    );
  });

  test('freezes all site economy and progression availability values', () {
    final content = MiningContentRegistry.stellarMining();

    final expected = <MiningSiteId, Map<String, Object?>>{
      MiningSiteId.landingBasin: {
        'resource': ResourceType.gold,
        'requiredSite': null,
        'surveying': 0,
        'unlock': 0,
        'rate': 0.50,
        'capacity': 3600,
        'sale': 4,
        'deposits': [0, 0, 1, 2],
      },
      MiningSiteId.carbonRidge: {
        'resource': ResourceType.coal,
        'requiredSite': MiningSiteId.landingBasin,
        'surveying': 0,
        'unlock': 250,
        'rate': 0.75,
        'capacity': 5400,
        'sale': 3,
        'deposits': [0, 1, 2, 3],
      },
      MiningSiteId.graniteCrater: {
        'resource': ResourceType.stone,
        'requiredSite': MiningSiteId.carbonRidge,
        'surveying': 0,
        'unlock': 700,
        'rate': 0.60,
        'capacity': 4320,
        'sale': 5,
        'deposits': [0, 1, 2, 3],
      },
      MiningSiteId.frozenBasin: {
        'resource': ResourceType.waterIce,
        'requiredSite': null,
        'surveying': 3,
        'unlock': 0,
        'rate': 1.00,
        'capacity': 7200,
        'sale': 6,
        'deposits': [3, 3, 4, 5],
      },
      MiningSiteId.titaniumHighlands: {
        'resource': ResourceType.titaniumOre,
        'requiredSite': MiningSiteId.frozenBasin,
        'surveying': 4,
        'unlock': 250000,
        'rate': 0.80,
        'capacity': 5760,
        'sale': 12,
        'deposits': [4, 4, 5, 5],
      },
      MiningSiteId.heliumMare: {
        'resource': ResourceType.helium3,
        'requiredSite': MiningSiteId.titaniumHighlands,
        'surveying': 5,
        'unlock': 650000,
        'rate': 0.55,
        'capacity': 3960,
        'sale': 30,
        'deposits': [5, 5, 5, 5],
      },
      MiningSiteId.ochreBasin: {
        'resource': ResourceType.ironOre,
        'requiredSite': null,
        'surveying': 5,
        'unlock': 0,
        'rate': 0.75,
        'capacity': 5400,
        'sale': 32,
        'deposits': [5, 5, 5, 5],
      },
      MiningSiteId.silicaDunes: {
        'resource': ResourceType.silica,
        'requiredSite': MiningSiteId.ochreBasin,
        'surveying': 5,
        'unlock': 10000000,
        'rate': 0.55,
        'capacity': 3960,
        'sale': 55,
        'deposits': [5, 5, 5, 5],
      },
      MiningSiteId.cobaltChasm: {
        'resource': ResourceType.cobaltOre,
        'requiredSite': MiningSiteId.silicaDunes,
        'surveying': 5,
        'unlock': 25000000,
        'rate': 0.35,
        'capacity': 2520,
        'sale': 110,
        'deposits': [5, 5, 5, 5],
      },
      MiningSiteId.nickelShoals: {
        'resource': ResourceType.nickelOre,
        'requiredSite': null,
        'surveying': 5,
        'unlock': 0,
        'rate': 0.60,
        'capacity': 4320,
        'sale': 100,
        'deposits': [5, 5, 5, 5],
      },
      MiningSiteId.platinumRift: {
        'resource': ResourceType.platinum,
        'requiredSite': MiningSiteId.nickelShoals,
        'surveying': 5,
        'unlock': 18000000,
        'rate': 0.45,
        'capacity': 3240,
        'sale': 180,
        'deposits': [5, 5, 5, 5],
      },
      MiningSiteId.iridiumSpire: {
        'resource': ResourceType.iridium,
        'requiredSite': MiningSiteId.platinumRift,
        'surveying': 5,
        'unlock': 45000000,
        'rate': 0.30,
        'capacity': 2160,
        'sale': 350,
        'deposits': [5, 5, 5, 5],
      },
    };

    expect(expected.keys, MiningSiteId.values);

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
        site.deposits.take(4).map((deposit) => deposit.requiredSurveyingLevel),
        values['deposits'],
      );
      expect(site.cavernAsset, startsWith('assets/images/mining/caverns/'));
      expect(site.depositAsset, startsWith('assets/images/mining/nodes/'));
      expect(site.cardAsset, startsWith('assets/images/mining/'));
    }
  });

  test('freezes technology, offline, planet, and Ceres reward metadata', () {
    final content = MiningContentRegistry.stellarMining();

    expect(MiningContentRegistry.technologyCosts, [
      300,
      700,
      1500,
      300000,
      750000,
    ]);
    expect(MiningContentRegistry.technologySiteGates, [
      MiningSiteId.landingBasin,
      MiningSiteId.carbonRidge,
      MiningSiteId.graniteCrater,
      MiningSiteId.frozenBasin,
      MiningSiteId.titaniumHighlands,
    ]);
    expect(MiningContentRegistry.offlineAccrualCap, const Duration(hours: 24));
    expect(MiningContentRegistry.storageWindow, const Duration(hours: 2));
    for (final site in content.planets.values.expand((p) => p.sites)) {
      expect(
        site.baseCapacity,
        closeTo(
          site.baseRatePerSecond *
              MiningContentRegistry.storageWindow.inSeconds,
          1e-9,
        ),
        reason: '${site.name} storage holds two hours of base production',
      );
    }

    final homeworld = content.planet(MiningPlanetId.homeworld);
    expect(homeworld.rigSpawnCost, 25);
    expect(homeworld.unlockRequiredMasteryPlanetId, isNull);
    expect(homeworld.unlockRequiredSurveyingLevel, 0);
    expect(homeworld.unlockCashCost, 0);
    expect(homeworld.masteryRewardCash, 0);
    expect(homeworld.planetAsset, 'assets/images/mining/planets/homeworld.png');

    final lunar = content.planet(MiningPlanetId.lunarFrontier);
    expect(lunar.rigSpawnCost, 40000);
    expect(lunar.unlockRequiredMasteryPlanetId, MiningPlanetId.homeworld);
    expect(lunar.unlockRequiredSurveyingLevel, 3);
    expect(lunar.unlockCashCost, 200000);
    expect(lunar.masteryRewardCash, 0);
    expect(
      lunar.planetAsset,
      'assets/images/mining/planets/lunar_frontier.png',
    );

    final mars = content.planet(MiningPlanetId.marsFrontier);
    expect(mars.name, 'Mars Frontier');
    expect(mars.rigSpawnCost, 4000000);
    expect(mars.unlockRequiredMasteryPlanetId, MiningPlanetId.lunarFrontier);
    expect(mars.unlockRequiredSurveyingLevel, 5);
    expect(mars.unlockCashCost, 16000000);
    expect(mars.masteryRewardCash, 0);
    expect(mars.planetAsset, 'assets/images/mining/planets/mars_frontier.png');

    final ceres = content.planet(MiningPlanetId.ceresFrontier);
    expect(ceres.name, 'Ceres Frontier');
    expect(ceres.rigSpawnCost, 7500000);
    expect(ceres.unlockRequiredMasteryPlanetId, MiningPlanetId.marsFrontier);
    expect(ceres.unlockRequiredSurveyingLevel, 5);
    expect(ceres.unlockCashCost, 30000000);
    expect(ceres.masteryRewardCash, 30000000);
    expect(
      ceres.planetAsset,
      'assets/images/mining/planets/ceres_frontier.png',
    );

    expect(
      content.planets.values
          .where((planet) => planet.masteryRewardCash > 0)
          .map((planet) => planet.id),
      [MiningPlanetId.ceresFrontier],
      reason: 'the game grants exactly one completion reward',
    );
    for (final planet in content.planets.values) {
      final ids = planet.sites.map((site) => site.id).toList();
      for (final (index, site) in planet.sites.indexed) {
        if (site.requiredSite == null) continue;
        expect(
          ids.indexOf(site.requiredSite!),
          lessThan(index),
          reason: '${site.name} requires an earlier site on ${planet.name}',
        );
      }
    }
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
    expect(ochre.depositAsset, 'assets/images/mining/nodes/iron_ore.png');
    expect(ochre.cardAsset, 'assets/images/mining/caverns/iron_ore.png');
  });

  test('authors Ceres facility copy and asset paths', () {
    final content = MiningContentRegistry.stellarMining();
    final expected = {
      MiningSiteId.nickelShoals: (
        'Nickel Shoals',
        'Nickel Dredge',
        'shallow nickel-iron shoals ring the crater floor.',
        'nickel_ore',
      ),
      MiningSiteId.platinumRift: (
        'Platinum Rift',
        'Platinum Cutter',
        'a fractured rift exposes platinum seams under the salt crust.',
        'platinum',
      ),
      MiningSiteId.iridiumSpire: (
        'Iridium Spire',
        'Iridium Lance',
        "the ice volcano's flank hides the belt's richest iridium.",
        'iridium',
      ),
    };

    for (final MapEntry(key: id, value: (name, facility, discovery, art))
        in expected.entries) {
      final site = content.site(id);
      expect(site.name, name);
      expect(site.facilityName, facility);
      expect(site.discoveryText, discovery);
      expect(site.cavernAsset, 'assets/images/mining/caverns/$art.png');
      expect(site.depositAsset, 'assets/images/mining/nodes/$art.png');
      expect(site.cardAsset, 'assets/images/mining/caverns/$art.png');
    }
  });

  test('one T1 preserves the current Landing Basin base capacity', () {
    final content = MiningContentRegistry.stellarMining();
    expect(
      content.effectiveSiteCapacity(MiningSiteId.landingBasin, const [
        RigTier.t1,
      ], 0),
      3600,
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
      14400,
    );
    expect(
      content.effectiveSiteCapacity(MiningSiteId.landingBasin, const [
        RigTier.t5,
        RigTier.t5,
        RigTier.t5,
        RigTier.t5,
      ], 5),
      115200,
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
    const ceres = {
      MiningSiteId.nickelShoals,
      MiningSiteId.platinumRift,
      MiningSiteId.iridiumSpire,
    };
    expect(
      content.isPlanetMastered(MiningPlanetId.ceresFrontier, ceres),
      isTrue,
    );
    expect(
      content.isPlanetMastered(
        MiningPlanetId.ceresFrontier,
        {...ceres}..remove(MiningSiteId.iridiumSpire),
      ),
      isFalse,
    );
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
    final nickel = silhouettes[ResourceType.nickelOre]!;
    final platinum = silhouettes[ResourceType.platinum]!;
    final iridium = silhouettes[ResourceType.iridium]!;
    expect(
      (nickel.icon, nickel.name, nickel.color),
      (Icons.hexagon, 'Nickel Ore', Colors.lightGreenAccent),
    );
    expect(
      (platinum.icon, platinum.name, platinum.color),
      (Icons.auto_awesome, 'Platinum', const Color(0xFFE5E4E2)),
    );
    expect(
      (iridium.icon, iridium.name, iridium.color),
      (Icons.flare, 'Iridium', Colors.purpleAccent),
    );
    expect(silhouettes.values.map((s) => s.icon).toSet(), hasLength(12));
  });

  test('caches the generated stellar mining registry', () {
    expect(
      identical(
        MiningContentRegistry.stellarMining(),
        MiningContentRegistry.stellarMining(),
      ),
      isTrue,
    );
  });

  test('generates one dense 50x50 field of 100 unique resources per site', () {
    final content = MiningContentRegistry.stellarMining();

    for (final siteId in MiningSiteId.values) {
      final site = content.site(siteId);
      expect(site.gridWidth, 50, reason: site.name);
      expect(site.gridHeight, 50, reason: site.name);
      expect(site.deposits, hasLength(100), reason: site.name);
      expect(site.deposits.toSet(), hasLength(100), reason: site.name);
      expect(site.deposits.map((d) => d.size).toSet(), {
        1,
        2,
        3,
      }, reason: site.name);
      expect(
        site.perimeterCellsByDeposit.keys.toSet(),
        site.deposits.toSet(),
        reason: site.name,
      );
    }
  });

  test('pins deterministic progression tuples from the documented formula', () {
    final content = MiningContentRegistry.stellarMining();

    expect(
      content
          .site(MiningSiteId.landingBasin)
          .deposits
          .take(4)
          .map((d) => (d.x, d.y, d.size, d.requiredSurveyingLevel)),
      [(1, 1, 2, 0), (6, 1, 3, 0), (11, 2, 2, 1), (16, 1, 3, 2)],
    );
    expect(
      content
          .site(MiningSiteId.cobaltChasm)
          .deposits
          .take(4)
          .map((d) => (d.x, d.y, d.size, d.requiredSurveyingLevel)),
      [(1, 1, 2, 5), (6, 1, 3, 5), (11, 2, 2, 5), (16, 1, 3, 5)],
    );
  });

  test('keeps dense fields in bounds, disjoint, and unambiguous', () {
    final content = MiningContentRegistry.stellarMining();

    for (final siteId in MiningSiteId.values) {
      final site = content.site(siteId);

      for (final deposit in site.deposits) {
        expect(deposit.x, greaterThanOrEqualTo(0), reason: site.name);
        expect(deposit.y, greaterThanOrEqualTo(0), reason: site.name);
        expect(
          deposit.x + deposit.size,
          lessThanOrEqualTo(site.gridWidth),
          reason: site.name,
        );
        expect(
          deposit.y + deposit.size,
          lessThanOrEqualTo(site.gridHeight),
          reason: site.name,
        );
      }

      for (var x = 0; x < site.gridWidth; x++) {
        for (var y = 0; y < site.gridHeight; y++) {
          final cell = MiningGridCell(x, y);
          final containing = site.deposits
              .where((d) => d.contains(cell))
              .toList();
          expect(
            containing.length,
            lessThanOrEqualTo(1),
            reason: '${site.name} $cell',
          );
          if (containing.isEmpty) {
            final adjacent = site.deposits
                .where((d) => d.isOrthogonallyAdjacent(cell))
                .toList();
            expect(
              adjacent.length,
              lessThanOrEqualTo(1),
              reason: '${site.name} $cell',
            );
          }
        }
      }
    }
  });

  test('freezes Surveying pacing toward the deployed-rig cap', () {
    final content = MiningContentRegistry.stellarMining();

    const expectedBySite = <MiningSiteId, List<int>>{
      MiningSiteId.landingBasin: [4, 4, 4, 4, 4, 4],
      MiningSiteId.carbonRidge: [4, 4, 4, 4, 4, 4],
      MiningSiteId.graniteCrater: [4, 4, 4, 4, 4, 4],
      MiningSiteId.frozenBasin: [0, 0, 0, 4, 4, 4],
      MiningSiteId.titaniumHighlands: [0, 0, 0, 0, 4, 4],
      MiningSiteId.heliumMare: [0, 0, 0, 0, 0, 4],
      MiningSiteId.ochreBasin: [0, 0, 0, 0, 0, 4],
      MiningSiteId.silicaDunes: [0, 0, 0, 0, 0, 4],
      MiningSiteId.cobaltChasm: [0, 0, 0, 0, 0, 4],
      MiningSiteId.nickelShoals: [0, 0, 0, 0, 0, 4],
      MiningSiteId.platinumRift: [0, 0, 0, 0, 0, 4],
      MiningSiteId.iridiumSpire: [0, 0, 0, 0, 0, 4],
    };

    for (final entry in expectedBySite.entries) {
      final site = content.site(entry.key);
      final actual = <int>[];
      var previous = -1;
      for (var level = 0; level <= 5; level++) {
        final surveyedCells = <MiningGridCell>{
          for (final cellEntry in site.perimeterCellsByDeposit.entries)
            if (cellEntry.key.requiredSurveyingLevel <= level)
              ...cellEntry.value,
        };
        final reachable = surveyedCells.length.clamp(
          0,
          MiningContentRegistry.maxDeployedRigsPerSite,
        );
        expect(reachable, greaterThanOrEqualTo(previous), reason: site.name);
        previous = reachable;
        actual.add(reachable);
      }
      expect(actual, entry.value, reason: site.name);
    }

    for (final siteId in MiningSiteId.values) {
      final site = content.site(siteId);
      final surveyedAtSiteLevel = site.perimeterCellsByDeposit.entries
          .where(
            (cellEntry) =>
                cellEntry.key.requiredSurveyingLevel <=
                site.requiredSurveyingLevel,
          )
          .toList();
      expect(
        surveyedAtSiteLevel.any((cellEntry) => cellEntry.value.length >= 2),
        isTrue,
        reason: site.name,
      );
    }
  });
}
