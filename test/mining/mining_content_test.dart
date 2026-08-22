import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

void main() {
  test('stellar mining exposes the Homeworld and Lunar Frontier catalogs', () {
    final content = MiningContentRegistry.stellarMining();

    expect(content.planets.keys.toSet(), {
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
    });
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
