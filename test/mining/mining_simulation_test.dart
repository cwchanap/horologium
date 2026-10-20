import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';

import '../support/mining_grid_fixtures.dart';

List<MiningRigPlacement> placements(List<(MiningGridCell, RigTier)> rigs) => [
  for (final (cell, tier) in rigs) MiningRigPlacement(tier: tier, cell: cell),
];

SiteProgress progress({
  bool unlocked = true,
  bool commissioned = false,
  double storedAmount = 0,
  List<MiningRigPlacement> rigs = const [],
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigPlacements: rigs,
);

MiningSave stateWithLandingRigs({
  required DateTime now,
  List<MiningRigPlacement> rigs = const [],
  int extraction = 0,
  int logistics = 0,
  double storedAmount = 0,
}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    technology: TechnologyLevels(extraction: extraction, logistics: logistics),
    sites: {
      ...base.sites,
      MiningSiteId.landingBasin: progress(
        storedAmount: storedAmount,
        rigs: rigs,
      ),
    },
  );
}

final _content = MiningContentRegistry.stellarMining();

/// First row-major legal deploy cell for [id] at its first playable
/// Surveying level.
MiningGridCell _firstCell(MiningSiteId id) =>
    firstPlayableCell(_content.site(id));

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
    sites: {
      ...base.sites,
      MiningSiteId.landingBasin: progress(
        storedAmount: homeworldStored,
        rigs: [
          MiningRigPlacement(
            tier: RigTier.t1,
            cell: _firstCell(MiningSiteId.landingBasin),
          ),
        ],
      ),
      MiningSiteId.frozenBasin: progress(
        storedAmount: lunarStored,
        rigs: [
          MiningRigPlacement(
            tier: RigTier.t1,
            cell: _firstCell(MiningSiteId.frozenBasin),
          ),
        ],
      ),
      MiningSiteId.ochreBasin: progress(
        storedAmount: marsStored,
        rigs: [
          MiningRigPlacement(
            tier: RigTier.t1,
            cell: _firstCell(MiningSiteId.ochreBasin),
          ),
        ],
      ),
    },
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();
  final simulation = MiningSimulation(content);
  final start = DateTime.utc(2026, 8, 26, 12);
  final landingCells = deployableMiningCells(
    content.site(MiningSiteId.landingBasin),
  );
  final carbonRidgeCell = _firstCell(MiningSiteId.carbonRidge);

  test('one T1 fills Landing Basin in exactly two hours and stops', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: placements([(landingCells[0], RigTier.t1)]),
    );
    final almost = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(hours: 2, seconds: -1)),
    );
    expect(almost.summary.fullSites, isEmpty);
    expect(
      almost.state.sites[MiningSiteId.landingBasin]!.storedAmount,
      closeTo(3599.5, 1e-9),
    );

    final result = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(hours: 3)),
    );
    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 3600);
    expect(result.summary.produced[ResourceType.gold], 3600);
    expect(result.summary.fullSites, contains(MiningSiteId.landingBasin));
  });

  test('Logistics 5 stretches one T1 Landing Basin to four hours', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: placements([(landingCells[0], RigTier.t1)]),
      logistics: 5,
    );
    final almost = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(hours: 4, seconds: -1)),
    );
    expect(almost.summary.fullSites, isEmpty);

    final result = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(hours: 4)),
    );
    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 7200);
    expect(result.summary.fullSites, contains(MiningSiteId.landingBasin));
  });

  test('four max rigs preserve the old max-tier fill curve', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: placements([
        for (final cell in landingCells.take(4)) (cell, RigTier.t5),
      ]),
      extraction: 5,
      logistics: 5,
    );
    final result = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(hours: 4)),
    );

    // 18/s fills 115,200 in 6,400 s, so the old 160 s curve scales by 40.
    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 115200);
    expect(result.summary.produced[ResourceType.gold], 115200);
    final early = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(seconds: 160)),
    );
    expect(early.summary.produced[ResourceType.gold], closeTo(2880, 1e-9));
  });

  test('mixed rig tiers sum rate and capacity shares', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: placements([
        (landingCells[0], RigTier.t1),
        (landingCells[1], RigTier.t2),
      ]),
    );
    final result = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(seconds: 180)),
    );

    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 225);
    expect(result.summary.produced[ResourceType.gold], 225);
  });

  test('docked rigs produce nothing and add no site capacity', () {
    final result = simulation.accrue(
      MiningSave.initial(nowUtc: start),
      start.add(const Duration(hours: 1)),
    );

    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 0);
    expect(result.summary.produced, isEmpty);
    expect(result.summary.productionByPlanet, isEmpty);
    expect(result.summary.fullSites, isEmpty);
  });

  test(
    'all unlocked planets accrue while inactive planets remain included',
    () {
      final state = threePlanetState(
        start,
        technology: const TechnologyLevels(extraction: 1),
        activePlanet: MiningPlanetId.homeworld,
      );
      final result = simulation.accrue(
        state,
        start.add(const Duration(seconds: 10)),
      );

      expect(
        result.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        closeTo(5.5, 0.0001),
      );
      expect(
        result.state.sites[MiningSiteId.frozenBasin]!.storedAmount,
        closeTo(11, 0.0001),
      );
      expect(
        result.state.sites[MiningSiteId.ochreBasin]!.storedAmount,
        closeTo(8.25, 0.0001),
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
    },
  );

  test('one window accrues all four planets and fills Ceres storage', () {
    final base = threePlanetState(start);
    MiningRigPlacement t1(MiningSiteId id) =>
        MiningRigPlacement(tier: RigTier.t1, cell: _firstCell(id));
    final state = base.copyWith(
      unlockedPlanetIds: MiningPlanetId.values.toSet(),
      activePlanetId: MiningPlanetId.ceresFrontier,
      sites: {
        ...base.sites,
        MiningSiteId.nickelShoals: progress(
          rigs: [t1(MiningSiteId.nickelShoals)],
        ),
        MiningSiteId.platinumRift: progress(
          storedAmount: 3238,
          rigs: [t1(MiningSiteId.platinumRift)],
        ),
      },
    );
    final result = simulation.accrue(
      state,
      start.add(const Duration(seconds: 10)),
    );

    expect(
      result.state.sites[MiningSiteId.landingBasin]!.storedAmount,
      closeTo(5, 0.0001),
    );
    expect(
      result.state.sites[MiningSiteId.ochreBasin]!.storedAmount,
      closeTo(7.5, 0.0001),
    );
    expect(
      result.state.sites[MiningSiteId.nickelShoals]!.storedAmount,
      closeTo(6, 0.0001),
    );
    expect(result.state.sites[MiningSiteId.platinumRift]!.storedAmount, 3240);
    expect(result.summary.fullSites, {MiningSiteId.platinumRift});
    expect(result.summary.productionByPlanet[MiningPlanetId.ceresFrontier], {
      ResourceType.nickelOre: closeTo(6, 0.0001),
      ResourceType.platinum: closeTo(2, 0.0001),
    });
  });

  test('a locked Ceres produces nothing', () {
    final base = threePlanetState(start);
    final state = base.copyWith(
      sites: {
        ...base.sites,
        MiningSiteId.nickelShoals: progress(
          rigs: [
            MiningRigPlacement(
              tier: RigTier.t1,
              cell: _firstCell(MiningSiteId.nickelShoals),
            ),
          ],
        ),
      },
    );
    final result = simulation.accrue(
      state,
      start.add(const Duration(seconds: 10)),
    );

    expect(result.state.sites[MiningSiteId.nickelShoals]!.storedAmount, 0);
    expect(
      result.summary.productionByPlanet[MiningPlanetId.ceresFrontier] ?? {},
      isEmpty,
    );
  });

  test('locked and empty sites do not accrue', () {
    final base = stateWithLandingRigs(
      now: start,
      rigs: placements([(landingCells[0], RigTier.t1)]),
    );
    final state = base.copyWith(
      sites: {
        ...base.sites,
        MiningSiteId.carbonRidge: progress(
          unlocked: false,
          storedAmount: 4,
          rigs: placements([(carbonRidgeCell, RigTier.t5)]),
        ),
        MiningSiteId.graniteCrater: progress(storedAmount: 8),
      },
    );
    final result = simulation.accrue(
      state,
      start.add(const Duration(seconds: 10)),
    );

    expect(result.state.sites[MiningSiteId.carbonRidge]!.storedAmount, 4);
    expect(result.state.sites[MiningSiteId.graniteCrater]!.storedAmount, 8);
    expect(result.summary.productionByPlanet[MiningPlanetId.homeworld], {
      ResourceType.gold: 5,
    });
  });

  test('zero elapsed returns the same state and empty summary', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: placements([(landingCells[0], RigTier.t1)]),
      storedAmount: 10,
    );
    final result = simulation.accrue(state, start);

    expect(result.state.toJson(), state.toJson());
    expect(result.summary.elapsedUsed, Duration.zero);
    expect(result.summary.produced, isEmpty);
    expect(result.summary.productionByPlanet, isEmpty);
    expect(result.summary.fullSites, isEmpty);
    expect(result.summary.wasOfflineCapped, isFalse);
  });

  test('negative elapsed does not move time backward or accrue', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: placements([(landingCells[0], RigTier.t1)]),
      storedAmount: 10,
    );
    final result = simulation.accrue(
      state,
      start.subtract(const Duration(minutes: 1)),
    );

    expect(result.state.toJson(), state.toJson());
    expect(result.summary.totalProduced, 0);
    expect(result.summary.elapsedUsed, Duration.zero);
  });

  test('full-site reporting includes a site that starts full', () {
    final result = simulation.accrue(
      stateWithLandingRigs(
        now: start,
        rigs: placements([(landingCells[0], RigTier.t1)]),
        storedAmount: 3600,
      ),
      start.add(const Duration(seconds: 10)),
    );

    expect(result.summary.fullSites, contains(MiningSiteId.landingBasin));
    expect(result.summary.produced[ResourceType.gold], 0);
    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 3600);
  });

  test('offline accrual caps at 24 hours whatever the Logistics level', () {
    for (final logistics in [0, 5]) {
      final result = simulation.accrue(
        stateWithLandingRigs(
          now: start,
          rigs: placements([(landingCells[0], RigTier.t1)]),
          logistics: logistics,
        ),
        start.add(const Duration(hours: 24)),
      );
      expect(result.summary.elapsedUsed, const Duration(hours: 24));
      expect(result.summary.wasOfflineCapped, isFalse);
    }
  });

  test('a 30-hour gap accrues 24 hours to rig capacity', () {
    final result = simulation.accrue(
      stateWithLandingRigs(
        now: start,
        rigs: placements([(landingCells[0], RigTier.t1)]),
        logistics: 2,
      ),
      start.add(const Duration(hours: 30)),
    );

    expect(result.summary.elapsedAway, const Duration(hours: 30));
    expect(result.summary.elapsedUsed, const Duration(hours: 24));
    expect(result.state.lastAccruedAtUtc, start.add(const Duration(hours: 30)));
    expect(result.summary.wasOfflineCapped, isTrue);
    expect(result.summary.fullSites, contains(MiningSiteId.landingBasin));
    expect(
      result.state.sites[MiningSiteId.landingBasin]!.storedAmount,
      closeTo(
        content.effectiveSiteCapacity(MiningSiteId.landingBasin, const [
          RigTier.t1,
        ], 2),
        0.0001,
      ),
    );
  });

  test('identical inputs and clock produce identical immutable results', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: placements([
        (landingCells[0], RigTier.t1),
        (landingCells[1], RigTier.t3),
      ]),
      storedAmount: 10,
    );
    final now = start.add(const Duration(hours: 1));
    final first = simulation.accrue(state, now);
    final second = simulation.accrue(state, now);

    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 10);
    expect(first.state.toJson(), second.state.toJson());
    expect(first.summary.elapsedUsed, second.summary.elapsedUsed);
    expect(first.summary.totalProduced, second.summary.totalProduced);
    expect(first.summary.fullSites, second.summary.fullSites);
    expect(first.summary.wasOfflineCapped, second.summary.wasOfflineCapped);
    expect(first.summary.produced, second.summary.produced);
    expect(first.summary.productionByPlanet, second.summary.productionByPlanet);
  });
}
