import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';

Map<MiningNodeId, RigTier?> rigMap(Map<MiningNodeId, RigTier> rigs) => {
  for (final node in MiningNodeId.values) node: rigs[node],
};

SiteProgress progress({
  bool unlocked = true,
  bool commissioned = false,
  double storedAmount = 0,
  Map<MiningNodeId, RigTier> rigs = const {},
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigByNode: rigMap(rigs),
);

MiningSave stateWithLandingRigs({
  required DateTime now,
  Map<MiningNodeId, RigTier> rigs = const {},
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

MiningSave threePlanetState(
  DateTime now, {
  TechnologyLevels technology = const TechnologyLevels(),
  double homeworldStored = 0,
  double lunarStored = 0,
  double marsStored = 0,
  Map<MiningNodeId, RigTier> homeworldRigs = const {
    MiningNodeId.n1: RigTier.t1,
  },
  Map<MiningNodeId, RigTier> lunarRigs = const {MiningNodeId.n1: RigTier.t1},
  Map<MiningNodeId, RigTier> marsRigs = const {MiningNodeId.n1: RigTier.t1},
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
        rigs: homeworldRigs,
      ),
      MiningSiteId.frozenBasin: progress(
        storedAmount: lunarStored,
        rigs: lunarRigs,
      ),
      MiningSiteId.ochreBasin: progress(
        storedAmount: marsStored,
        rigs: marsRigs,
      ),
    },
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();
  final simulation = MiningSimulation(content);
  final start = DateTime.utc(2026, 8, 26, 12);

  test('one T1 keeps Landing Basin roughly 180 seconds to full', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: const {MiningNodeId.n1: RigTier.t1},
    );
    final result = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(seconds: 180)),
    );

    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 90);
    expect(result.summary.produced[ResourceType.gold], 90);
  });

  test('four max rigs preserve the old max-tier fill curve', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: const {
        MiningNodeId.n1: RigTier.t5,
        MiningNodeId.n2: RigTier.t5,
        MiningNodeId.n3: RigTier.t5,
        MiningNodeId.n4: RigTier.t5,
      },
      extraction: 5,
      logistics: 5,
    );
    final result = simulation.accrue(
      state,
      state.lastAccruedAtUtc.add(const Duration(seconds: 160)),
    );

    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 2880);
    expect(result.summary.produced[ResourceType.gold], 2880);
  });

  test('mixed rig tiers sum rate and capacity shares', () {
    final state = stateWithLandingRigs(
      now: start,
      rigs: const {MiningNodeId.n1: RigTier.t1, MiningNodeId.n2: RigTier.t2},
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

  test('locked and empty sites do not accrue', () {
    final base = stateWithLandingRigs(
      now: start,
      rigs: const {MiningNodeId.n1: RigTier.t1},
    );
    final state = base.copyWith(
      sites: {
        ...base.sites,
        MiningSiteId.carbonRidge: progress(
          unlocked: false,
          storedAmount: 4,
          rigs: const {MiningNodeId.n1: RigTier.t5},
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
      rigs: const {MiningNodeId.n1: RigTier.t1},
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
      rigs: const {MiningNodeId.n1: RigTier.t1},
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
        rigs: const {MiningNodeId.n1: RigTier.t1},
        storedAmount: 90,
      ),
      start.add(const Duration(seconds: 10)),
    );

    expect(result.summary.fullSites, contains(MiningSiteId.landingBasin));
    expect(result.summary.produced[ResourceType.gold], 0);
    expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 90);
  });

  test('offline production uses the logistics cap and rig capacity', () {
    final result = simulation.accrue(
      stateWithLandingRigs(
        now: start,
        rigs: const {MiningNodeId.n1: RigTier.t1},
        logistics: 2,
      ),
      start.add(const Duration(hours: 13)),
    );

    expect(result.summary.elapsedUsed, const Duration(hours: 12));
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
      rigs: const {MiningNodeId.n1: RigTier.t1, MiningNodeId.n2: RigTier.t3},
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
