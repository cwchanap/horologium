import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';

MiningSave goldState(DateTime now, {double stored = 0, int level = 1}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    sectors: {
      ...base.sectors,
      MiningSectorId.landingBasin: SectorProgress(
        revealed: true,
        mine: MineState(level: level, storedAmount: stored),
      ),
    },
  );
}

MiningSave stellarState(
  DateTime now, {
  TechnologyLevels technology = const TechnologyLevels(),
  double homeworldStored = 0,
  double lunarStored = 0,
}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    technology: technology,
    unlockedPlanetIds: const {
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
    },
    activePlanetId: MiningPlanetId.lunarFrontier,
    sectors: {
      ...base.sectors,
      MiningSectorId.landingBasin: SectorProgress(
        revealed: true,
        mine: MineState(level: 1, storedAmount: homeworldStored),
      ),
      MiningSectorId.frozenBasin: SectorProgress(
        revealed: true,
        mine: MineState(level: 1, storedAmount: lunarStored),
      ),
    },
  );
}

MiningSave threePlanetState(
  DateTime now, {
  TechnologyLevels technology = const TechnologyLevels(),
  double homeworldStored = 0,
  double lunarStored = 0,
  double marsStored = 0,
  MiningPlanetId activePlanet = MiningPlanetId.marsFrontier,
}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    technology: technology,
    unlockedPlanetIds: const {
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
      MiningPlanetId.marsFrontier,
    },
    activePlanetId: activePlanet,
    sectors: {
      ...base.sectors,
      MiningSectorId.landingBasin: SectorProgress(
        revealed: true,
        mine: MineState(level: 1, storedAmount: homeworldStored),
      ),
      MiningSectorId.frozenBasin: SectorProgress(
        revealed: true,
        mine: MineState(level: 1, storedAmount: lunarStored),
      ),
      MiningSectorId.ochreBasin: SectorProgress(
        revealed: true,
        mine: MineState(level: 1, storedAmount: marsStored),
      ),
    },
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();
  final simulation = MiningSimulation(content);
  final start = DateTime.utc(2026, 8, 18, 12);

  test('level one gold produces five units in ten seconds', () {
    final result = simulation.accrue(
      goldState(start),
      start.add(const Duration(seconds: 10)),
    );
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      closeTo(5, 0.0001),
    );
  });

  test('storage caps production', () {
    final result = simulation.accrue(
      goldState(start, stored: 89),
      start.add(const Duration(minutes: 1)),
    );
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      90,
    );
  });

  test('clock rollback produces zero and does not move time backward', () {
    final state = goldState(start, stored: 10);
    final result = simulation.accrue(
      state,
      start.subtract(const Duration(minutes: 1)),
    );
    expect(result.state.toJson(), state.toJson());
    expect(result.summary.totalProduced, 0);
  });

  test('twelve hours uses at most the eight hour cap', () {
    final result = simulation.accrue(
      goldState(start),
      start.add(const Duration(hours: 12)),
    );
    expect(result.summary.elapsedUsed, const Duration(hours: 8));
    expect(result.summary.wasOfflineCapped, isTrue);
  });

  test('identical inputs and clock produce identical results', () {
    final state = goldState(start, stored: 10);
    final now = start.add(const Duration(hours: 1));
    final first = simulation.accrue(state, now);
    final second = simulation.accrue(state, now);
    expect(first.state.toJson(), second.state.toJson());
    expect(first.summary.elapsedUsed, second.summary.elapsedUsed);
    expect(first.summary.totalProduced, second.summary.totalProduced);
    expect(first.summary.fullSectors, second.summary.fullSectors);
    expect(first.summary.wasOfflineCapped, second.summary.wasOfflineCapped);
    expect(first.summary.produced, second.summary.produced);
    expect(first.summary.productionByPlanet, second.summary.productionByPlanet);
  });

  test('both unlocked planets accrue in one window with technology once', () {
    final state = stellarState(
      start,
      technology: const TechnologyLevels(extraction: 1, logistics: 2),
    );
    final result = simulation.accrue(
      state,
      start.add(const Duration(seconds: 10)),
    );

    expect(result.summary.elapsedUsed, const Duration(seconds: 10));
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      closeTo(5.5, 0.0001),
    );
    expect(
      result.state.sectors[MiningSectorId.frozenBasin]!.mine!.storedAmount,
      closeTo(11, 0.0001),
    );
    expect(result.summary.produced[ResourceType.gold], closeTo(5.5, 0.0001));
    expect(result.summary.produced[ResourceType.waterIce], closeTo(11, 0.0001));
  });

  test('all three unlocked planets accrue one supplied window', () {
    final result = simulation.accrue(
      threePlanetState(
        start,
        technology: const TechnologyLevels(extraction: 1, logistics: 2),
      ),
      start.add(const Duration(seconds: 10)),
    );

    expect(result.summary.elapsedUsed, const Duration(seconds: 10));
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      closeTo(5.5, 0.0001),
    );
    expect(
      result.state.sectors[MiningSectorId.frozenBasin]!.mine!.storedAmount,
      closeTo(11, 0.0001),
    );
    expect(
      result.state.sectors[MiningSectorId.ochreBasin]!.mine!.storedAmount,
      closeTo(8.25, 0.0001),
    );
    expect(
      result.summary.productionByPlanet[MiningPlanetId.homeworld]![ResourceType
          .gold],
      closeTo(5.5, 0.0001),
    );
    expect(
      result.summary.productionByPlanet[MiningPlanetId
          .lunarFrontier]![ResourceType.waterIce],
      closeTo(11, 0.0001),
    );
    expect(
      result.summary.productionByPlanet[MiningPlanetId
          .marsFrontier]![ResourceType.ironOre],
      closeTo(8.25, 0.0001),
    );
  });

  test('summary groups production by planet with flat full sectors', () {
    final state = stellarState(
      start,
      technology: const TechnologyLevels(logistics: 2),
      lunarStored: 194.9,
    );
    final summary = simulation
        .accrue(state, start.add(const Duration(seconds: 10)))
        .summary;

    expect(
      summary.productionByPlanet[MiningPlanetId.homeworld]![ResourceType.gold],
      greaterThan(0),
    );
    expect(
      summary.productionByPlanet[MiningPlanetId.lunarFrontier]![ResourceType
          .waterIce],
      greaterThan(0),
    );
    expect(summary.fullSectors, contains(MiningSectorId.frozenBasin));
    expect(summary.fullSectors, isNot(contains(MiningSectorId.landingBasin)));
  });

  test('locked Lunar Frontier does not accrue', () {
    final base = MiningSave.initial(nowUtc: start);
    final state = base.copyWith(
      sectors: {
        ...base.sectors,
        MiningSectorId.landingBasin: const SectorProgress(
          revealed: true,
          mine: MineState(level: 1, storedAmount: 0),
        ),
        MiningSectorId.frozenBasin: const SectorProgress(
          revealed: true,
          mine: MineState(level: 1, storedAmount: 42),
        ),
      },
    );
    final result = simulation.accrue(
      state,
      start.add(const Duration(hours: 1)),
    );

    expect(
      result.state.sectors[MiningSectorId.frozenBasin]!.mine!.storedAmount,
      42,
    );
    expect(
      result.summary.productionByPlanet,
      isNot(contains(MiningPlanetId.lunarFrontier)),
    );
    expect(
      result.summary.fullSectors,
      isNot(contains(MiningSectorId.frozenBasin)),
    );
  });

  test('locked Mars Frontier stays pristine and produces zero', () {
    final state =
        threePlanetState(
          start,
          technology: const TechnologyLevels(extraction: 1, logistics: 2),
          marsStored: 7,
        ).copyWith(
          unlockedPlanetIds: const {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          activePlanetId: MiningPlanetId.homeworld,
        );
    final result = simulation.accrue(
      state,
      start.add(const Duration(minutes: 10)),
    );

    expect(
      result.state.sectors[MiningSectorId.ochreBasin],
      state.sectors[MiningSectorId.ochreBasin],
    );
    expect(
      result.state.sectors[MiningSectorId.silicaDunes],
      state.sectors[MiningSectorId.silicaDunes],
    );
    expect(
      result.state.sectors[MiningSectorId.cobaltChasm],
      state.sectors[MiningSectorId.cobaltChasm],
    );
    expect(
      result.summary.productionByPlanet,
      isNot(contains(MiningPlanetId.marsFrontier)),
    );
    expect(result.summary.produced, isNot(contains(ResourceType.ironOre)));
  });

  test('Mars reuses effective logistics capacity and offline cap', () {
    final content = MiningContentRegistry.stellarMining();
    final result = simulation.accrue(
      threePlanetState(
        start,
        technology: const TechnologyLevels(extraction: 1, logistics: 2),
      ),
      start.add(const Duration(hours: 13)),
    );

    expect(result.summary.elapsedUsed, content.offlineCapFor(2));
    expect(result.summary.wasOfflineCapped, isTrue);
    expect(
      result.state.sectors[MiningSectorId.ochreBasin]!.mine!.storedAmount,
      closeTo(
        content.effectiveCapacity(MiningSectorId.ochreBasin, 1, 2),
        0.0001,
      ),
    );
    expect(result.summary.fullSectors, contains(MiningSectorId.ochreBasin));
    expect(
      result.summary.productionByPlanet[MiningPlanetId
          .marsFrontier]![ResourceType.ironOre],
      closeTo(
        content.effectiveCapacity(MiningSectorId.ochreBasin, 1, 2),
        0.0001,
      ),
    );
  });

  test('full Mars storage does not disturb other unlocked planets', () {
    final content = MiningContentRegistry.stellarMining();
    final marsCapacity = content.effectiveCapacity(
      MiningSectorId.ochreBasin,
      1,
      2,
    );
    final result = simulation.accrue(
      threePlanetState(
        start,
        technology: const TechnologyLevels(extraction: 1, logistics: 2),
        marsStored: marsCapacity,
      ),
      start.add(const Duration(seconds: 10)),
    );

    expect(
      result.state.sectors[MiningSectorId.ochreBasin]!.mine!.storedAmount,
      marsCapacity,
    );
    expect(
      result.summary.productionByPlanet[MiningPlanetId
          .marsFrontier]![ResourceType.ironOre],
      0,
    );
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      closeTo(5.5, 0.0001),
    );
    expect(
      result.state.sectors[MiningSectorId.frozenBasin]!.mine!.storedAmount,
      closeTo(11, 0.0001),
    );
    expect(result.summary.fullSectors, contains(MiningSectorId.ochreBasin));
  });

  test('active planet selection does not change multi-planet accrual', () {
    final homeworldActive = simulation.accrue(
      threePlanetState(
        start,
        technology: const TechnologyLevels(extraction: 1, logistics: 2),
        activePlanet: MiningPlanetId.homeworld,
      ),
      start.add(const Duration(seconds: 10)),
    );
    final marsActive = simulation.accrue(
      threePlanetState(
        start,
        technology: const TechnologyLevels(extraction: 1, logistics: 2),
        activePlanet: MiningPlanetId.marsFrontier,
      ),
      start.add(const Duration(seconds: 10)),
    );

    expect(homeworldActive.summary.produced, marsActive.summary.produced);
    expect(
      homeworldActive.summary.productionByPlanet,
      marsActive.summary.productionByPlanet,
    );
    expect(homeworldActive.summary.fullSectors, marsActive.summary.fullSectors);
    for (final id in [
      MiningSectorId.landingBasin,
      MiningSectorId.frozenBasin,
      MiningSectorId.ochreBasin,
    ]) {
      expect(
        homeworldActive.state.sectors[id]!.mine!.storedAmount,
        marsActive.state.sectors[id]!.mine!.storedAmount,
      );
    }
  });

  test('offline cap grows with logistics', () {
    final cappedAt12 = simulation.accrue(
      goldState(
        start,
      ).copyWith(technology: const TechnologyLevels(logistics: 2)),
      start.add(const Duration(hours: 13)),
    );
    expect(cappedAt12.summary.elapsedUsed, const Duration(hours: 12));
    expect(cappedAt12.summary.wasOfflineCapped, isTrue);

    final cappedAt24 = simulation.accrue(
      goldState(
        start,
      ).copyWith(technology: const TechnologyLevels(logistics: 5)),
      start.add(const Duration(hours: 30)),
    );
    expect(cappedAt24.summary.elapsedUsed, const Duration(hours: 24));
    expect(cappedAt24.summary.wasOfflineCapped, isTrue);
  });
}
