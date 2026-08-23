import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

void main() {
  test('stellar mining exposes planets in authored order', () {
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
    expect(content.planet(MiningPlanetId.homeworld).sectors.map((s) => s.id), [
      MiningSectorId.landingBasin,
      MiningSectorId.carbonRidge,
      MiningSectorId.graniteCrater,
    ]);
    expect(
      content.planet(MiningPlanetId.lunarFrontier).sectors.map((s) => s.id),
      [
        MiningSectorId.frozenBasin,
        MiningSectorId.titaniumHighlands,
        MiningSectorId.heliumMare,
      ],
    );
    expect(
      content.planet(MiningPlanetId.marsFrontier).sectors.map((s) => s.id),
      [
        MiningSectorId.ochreBasin,
        MiningSectorId.silicaDunes,
        MiningSectorId.cobaltChasm,
      ],
    );
  });

  test('Mars identity and unlock metadata are authored explicitly', () {
    final content = MiningContentRegistry.stellarMining();
    final mars = content.planet(MiningPlanetId.marsFrontier);

    expect(mars.name, 'Mars Frontier');
    expect(mars.terrainSeed, 641);
    expect(mars.tint, const Color(0xFF2A1512));
    expect(mars.unlockRequiredMasteryPlanetId, MiningPlanetId.lunarFrontier);
    expect(mars.unlockRequiredSurveyingLevel, 5);
    expect(mars.unlockCashCost, 20000);
    expect(mars.masteryRewardCash, 25000);
  });

  test('Mars sector chain, anchors, copy, sprites, and economy are frozen', () {
    final content = MiningContentRegistry.stellarMining();

    final ochre = content.sector(MiningSectorId.ochreBasin);
    expect(ochre.name, 'Ochre Basin');
    expect(ochre.resource, ResourceType.ironOre);
    expect(ochre.mineAsset, Assets.woodFactory);
    expect(ochre.facilityName, 'Iron Rig');
    expect(
      ochre.discoveryText,
      'iron-rich regolith supports the first heavy extraction rig.',
    );
    expect(ochre.requiredSector, isNull);
    expect(ochre.requiredSurveyingLevel, 5);
    expect(ochre.revealCost, 0);
    expect(ochre.buildCost, 5000);
    expect(ochre.baseRatePerSecond, 0.75);
    expect(ochre.baseCapacity, 180);
    expect(ochre.saleValuePerUnit, 32);
    expect(ochre.upgradeCosts, [7000, 14000, 28000, 56000]);
    expect(ochre.anchor.x, -360);
    expect(ochre.anchor.y, 330);

    final silica = content.sector(MiningSectorId.silicaDunes);
    expect(silica.name, 'Silica Dunes');
    expect(silica.resource, ResourceType.silica);
    expect(silica.mineAsset, Assets.riceHuller);
    expect(silica.facilityName, 'Silica Extractor');
    expect(
      silica.discoveryText,
      'glassy dune deposits trade lower throughput for stronger sale value.',
    );
    expect(silica.requiredSector, MiningSectorId.ochreBasin);
    expect(silica.requiredSurveyingLevel, 5);
    expect(silica.revealCost, 12000);
    expect(silica.buildCost, 9000);
    expect(silica.baseRatePerSecond, 0.55);
    expect(silica.baseCapacity, 160);
    expect(silica.saleValuePerUnit, 55);
    expect(silica.upgradeCosts, [12000, 24000, 48000, 96000]);
    expect(silica.anchor.x, 280);
    expect(silica.anchor.y, -60);

    final cobalt = content.sector(MiningSectorId.cobaltChasm);
    expect(cobalt.name, 'Cobalt Chasm');
    expect(cobalt.resource, ResourceType.cobaltOre);
    expect(cobalt.mineAsset, Assets.sawmill);
    expect(cobalt.facilityName, 'Cobalt Drill');
    expect(
      cobalt.discoveryText,
      'deep cobalt seams are the final high-value Mars target.',
    );
    expect(cobalt.requiredSector, MiningSectorId.silicaDunes);
    expect(cobalt.requiredSurveyingLevel, 5);
    expect(cobalt.revealCost, 30000);
    expect(cobalt.buildCost, 18000);
    expect(cobalt.baseRatePerSecond, 0.35);
    expect(cobalt.baseCapacity, 130);
    expect(cobalt.saleValuePerUnit, 110);
    expect(cobalt.upgradeCosts, [24000, 48000, 96000, 192000]);
    expect(cobalt.anchor.x, -80);
    expect(cobalt.anchor.y, -400);
  });

  test('Lunar balance and terrain seeds are authored explicitly', () {
    final content = MiningContentRegistry.stellarMining();

    expect(content.planet(MiningPlanetId.homeworld).terrainSeed, 631);
    expect(content.planet(MiningPlanetId.lunarFrontier).terrainSeed, 638);

    final frozen = content.sector(MiningSectorId.frozenBasin);
    expect(frozen.resource, ResourceType.waterIce);
    expect(frozen.mineAsset, Assets.waterTreatmentPlant);
    expect(frozen.requiredSurveyingLevel, 3);
    expect(frozen.revealCost, 0);
    expect(frozen.buildCost, 500);
    expect(frozen.baseRatePerSecond, 1.00);
    expect(frozen.baseCapacity, 150);
    expect(frozen.saleValuePerUnit, 6);
    expect(frozen.upgradeCosts, [700, 1400, 2800, 5600]);

    final titanium = content.sector(MiningSectorId.titaniumHighlands);
    expect(titanium.resource, ResourceType.titaniumOre);
    expect(titanium.mineAsset, Assets.grinderMill);
    expect(titanium.requiredSurveyingLevel, 4);
    expect(titanium.revealCost, 3000);
    expect(titanium.buildCost, 1200);
    expect(titanium.baseRatePerSecond, 0.80);
    expect(titanium.baseCapacity, 140);
    expect(titanium.saleValuePerUnit, 12);
    expect(titanium.upgradeCosts, [1600, 3200, 6400, 12800]);

    final helium = content.sector(MiningSectorId.heliumMare);
    expect(helium.resource, ResourceType.helium3);
    expect(helium.mineAsset, Assets.researchLab);
    expect(helium.requiredSurveyingLevel, 5);
    expect(helium.revealCost, 8000);
    expect(helium.buildCost, 3000);
    expect(helium.baseRatePerSecond, 0.55);
    expect(helium.baseCapacity, 120);
    expect(helium.saleValuePerUnit, 30);
    expect(helium.upgradeCosts, [4000, 8000, 16000, 32000]);
  });

  test('Homeworld reuses existing resource and mine identities', () {
    final content = MiningContentRegistry.stellarMining();
    final homeworld = content.planet(MiningPlanetId.homeworld).sectors;

    expect(homeworld.map((s) => s.id), [
      MiningSectorId.landingBasin,
      MiningSectorId.carbonRidge,
      MiningSectorId.graniteCrater,
    ]);
    expect(
      content.sector(MiningSectorId.landingBasin).resource,
      ResourceType.gold,
    );
    expect(
      content.sector(MiningSectorId.landingBasin).mineAsset,
      Assets.goldMine,
    );
    expect(
      content.sector(MiningSectorId.carbonRidge).resource,
      ResourceType.coal,
    );
    expect(
      content.sector(MiningSectorId.carbonRidge).mineAsset,
      Assets.coalMine,
    );
    expect(
      content.sector(MiningSectorId.graniteCrater).resource,
      ResourceType.stone,
    );
    expect(
      content.sector(MiningSectorId.graniteCrater).mineAsset,
      Assets.quarry,
    );
    for (final sector in homeworld) {
      expect(sector.requiredSurveyingLevel, 0);
    }
  });

  test('sector and planet lookups resolve globally unique sector ids', () {
    final content = MiningContentRegistry.stellarMining();

    expect(
      content.planetForSector(MiningSectorId.frozenBasin),
      MiningPlanetId.lunarFrontier,
    );
    expect(
      content.planetForSector(MiningSectorId.landingBasin),
      MiningPlanetId.homeworld,
    );
  });

  test('planet mastery requires all three mines on that planet', () {
    final content = MiningContentRegistry.stellarMining();
    const homeworld = {
      MiningSectorId.landingBasin,
      MiningSectorId.carbonRidge,
      MiningSectorId.graniteCrater,
    };
    const lunar = {
      MiningSectorId.frozenBasin,
      MiningSectorId.titaniumHighlands,
      MiningSectorId.heliumMare,
    };
    const mars = {
      MiningSectorId.ochreBasin,
      MiningSectorId.silicaDunes,
      MiningSectorId.cobaltChasm,
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
        {...homeworld}..remove(MiningSectorId.graniteCrater),
      ),
      isFalse,
    );
    expect(
      content.isPlanetMastered(
        MiningPlanetId.lunarFrontier,
        {...lunar}..remove(MiningSectorId.heliumMare),
      ),
      isFalse,
    );
    expect(
      content.isPlanetMastered(
        MiningPlanetId.marsFrontier,
        {...mars}..remove(MiningSectorId.cobaltChasm),
      ),
      isFalse,
    );
  });

  test('mines on another planet do not satisfy planet mastery', () {
    final content = MiningContentRegistry.stellarMining();

    expect(
      content.isPlanetMastered(MiningPlanetId.homeworld, const {
        MiningSectorId.frozenBasin,
        MiningSectorId.titaniumHighlands,
        MiningSectorId.heliumMare,
      }),
      isFalse,
    );
    expect(
      content.isPlanetMastered(MiningPlanetId.lunarFrontier, const {
        MiningSectorId.ochreBasin,
        MiningSectorId.silicaDunes,
        MiningSectorId.cobaltChasm,
      }),
      isFalse,
    );
    expect(
      content.isPlanetMastered(MiningPlanetId.marsFrontier, const {
        MiningSectorId.landingBasin,
        MiningSectorId.carbonRidge,
        MiningSectorId.graniteCrater,
      }),
      isFalse,
    );
  });

  test(
    'technology economy helpers pin exact extraction, logistics, and cap values',
    () {
      final content = MiningContentRegistry.stellarMining();

      expect(content.effectiveRate(MiningSectorId.landingBasin, 1, 1), 0.55);
      expect(
        content.effectiveCapacity(MiningSectorId.landingBasin, 1, 2),
        117.0,
      );
      expect(content.offlineCapFor(5), const Duration(hours: 24));

      expect(content.effectiveRate(MiningSectorId.landingBasin, 1, 0), 0.50);
      expect(content.effectiveRate(MiningSectorId.landingBasin, 1, 2), 0.625);
      expect(content.effectiveRate(MiningSectorId.landingBasin, 1, 3), 0.725);
      expect(content.effectiveRate(MiningSectorId.landingBasin, 1, 4), 0.85);
      expect(content.effectiveRate(MiningSectorId.landingBasin, 1, 5), 1.00);
      expect(content.effectiveRate(MiningSectorId.landingBasin, 2, 2), 0.9375);

      expect(
        content.effectiveCapacity(MiningSectorId.landingBasin, 1, 0),
        90.0,
      );
      expect(
        content.effectiveCapacity(MiningSectorId.landingBasin, 1, 1),
        closeTo(103.5, 1e-9),
      );
      expect(
        content.effectiveCapacity(MiningSectorId.landingBasin, 1, 3),
        135.0,
      );
      expect(
        content.effectiveCapacity(MiningSectorId.landingBasin, 1, 4),
        157.5,
      );
      expect(
        content.effectiveCapacity(MiningSectorId.landingBasin, 1, 5),
        180.0,
      );

      expect(content.offlineCapFor(0), const Duration(hours: 8));
      expect(content.offlineCapFor(1), const Duration(hours: 10));
      expect(content.offlineCapFor(2), const Duration(hours: 12));
      expect(content.offlineCapFor(3), const Duration(hours: 16));
      expect(content.offlineCapFor(4), const Duration(hours: 20));
    },
  );

  test('world units are explicit and every authored anchor is in bounds', () {
    final content = MiningContentRegistry.stellarMining();
    expect(MiningContentRegistry.terrainGridSize, 36);
    expect(MiningContentRegistry.terrainCellSize, 50);
    expect(
      MiningContentRegistry.terrainGridSize *
          MiningContentRegistry.terrainCellSize,
      MiningContentRegistry.worldExtent,
    );
    expect(MiningContentRegistry.worldExtent, 1800);
    expect(MiningContentRegistry.worldHalfExtent, 900);

    for (final sector in content.planets.values.expand(
      (planet) => planet.sectors,
    )) {
      expect(sector.anchor.x, inInclusiveRange(-900, 900));
      expect(sector.anchor.y, inInclusiveRange(-900, 900));
    }
  });

  test('planet seeds and tints distinguish Homeworld from Lunar', () {
    final content = MiningContentRegistry.stellarMining();
    final homeworld = content.planet(MiningPlanetId.homeworld);
    final lunar = content.planet(MiningPlanetId.lunarFrontier);

    expect(homeworld.terrainSeed, 631);
    expect(lunar.terrainSeed, 638);
    expect(homeworld.tint, isNot(equals(lunar.tint)));
  });

  test(
    'resource silhouettes give Lunar and Mars resources distinct identities',
    () {
      final silhouettes = MiningContentRegistry.resourceSilhouettes;

      expect(silhouettes.keys.toSet(), ResourceType.values.toSet());
      final water = silhouettes[ResourceType.waterIce]!;
      final titanium = silhouettes[ResourceType.titaniumOre]!;
      final helium = silhouettes[ResourceType.helium3]!;
      expect({water.icon, titanium.icon, helium.icon}.length, 3);
      expect({water.name, titanium.name, helium.name}.length, 3);
      expect({water.color, titanium.color, helium.color}.length, 3);
      expect(water.icon, isA<IconData>());

      final iron = silhouettes[ResourceType.ironOre]!;
      final silica = silhouettes[ResourceType.silica]!;
      final cobalt = silhouettes[ResourceType.cobaltOre]!;
      expect({iron.icon, silica.icon, cobalt.icon}.length, 3);
      expect({iron.name, silica.name, cobalt.name}.length, 3);
      expect({iron.color, silica.color, cobalt.color}.length, 3);
    },
  );

  test('clean mining state reveals only Landing Basin', () {
    final now = DateTime.utc(2026, 8, 18, 12);
    final state = MiningSave.initial(nowUtc: now);

    expect(state.cash, 100);
    expect(state.lastAccruedAtUtc, now);
    expect(state.sectors.keys.toSet(), MiningSectorId.values.toSet());
    expect(state.sectors[MiningSectorId.landingBasin]!.revealed, isTrue);
    expect(state.sectors[MiningSectorId.carbonRidge]!.revealed, isFalse);
    expect(state.sectors[MiningSectorId.graniteCrater]!.revealed, isFalse);
    expect(state.sectors.values.every((p) => p.mine == null), isTrue);
  });
}
