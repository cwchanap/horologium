import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';

void main() {
  test('technology levels access and replace one exhaustive track', () {
    const levels = TechnologyLevels(extraction: 1, logistics: 2, surveying: 3);

    expect(levels.levelFor(TechnologyTrack.extraction), 1);
    expect(levels.levelFor(TechnologyTrack.logistics), 2);
    expect(levels.levelFor(TechnologyTrack.surveying), 3);
    expect(
      levels.withLevel(TechnologyTrack.extraction, 4),
      const TechnologyLevels(extraction: 4, logistics: 2, surveying: 3),
    );
  });

  test('rig placement has value equality', () {
    expect(
      const MiningRigPlacement(tier: RigTier.t2, cell: MiningGridCell(3, 2)),
      const MiningRigPlacement(tier: RigTier.t2, cell: MiningGridCell(3, 2)),
    );
  });

  test('site progress serializes and protects rig placements', () {
    const placement = MiningRigPlacement(
      tier: RigTier.t2,
      cell: MiningGridCell(3, 2),
    );
    final progress = SiteProgress(
      unlocked: true,
      commissioned: true,
      storedAmount: 12.5,
      rigPlacements: const [placement],
    );

    expect(progress.toJson()['rigPlacements'], [
      {'tier': 't2', 'x': 3, 'y': 2},
    ]);

    final copy = progress.copyWith();
    expect(copy, progress);
    expect(
      () => copy.rigPlacements.add(
        const MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(16, 2)),
      ),
      throwsUnsupportedError,
    );
  });

  test('fresh state seeds only Homeworld and two T1 rigs', () {
    final state = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26, 12));

    expect(state.cash, 100);
    expect(state.unlockedPlanetIds, {MiningPlanetId.homeworld});
    expect(state.activePlanetId, MiningPlanetId.homeworld);
    expect(state.docks[MiningPlanetId.homeworld], {
      DockBayId.b1: RigTier.t1,
      DockBayId.b2: RigTier.t1,
      DockBayId.b3: null,
      DockBayId.b4: null,
    });
    expect(state.sites[MiningSiteId.landingBasin]!.unlocked, isTrue);
    expect(state.sites[MiningSiteId.landingBasin]!.commissioned, isFalse);
    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 0);
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, isEmpty);
  });

  test('fresh state has exact bay keys on every planet and empty sites', () {
    final state = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26, 12));

    expect(state.docks.keys.toSet(), MiningPlanetId.values.toSet());
    for (final bays in state.docks.values) {
      expect(bays.keys.toSet(), DockBayId.values.toSet());
    }
    expect(state.sites.keys.toSet(), MiningSiteId.values.toSet());
    for (final progress in state.sites.values) {
      expect(progress.rigPlacements, isEmpty);
    }

    for (final id in [
      MiningSiteId.frozenBasin,
      MiningSiteId.titaniumHighlands,
      MiningSiteId.heliumMare,
      MiningSiteId.ochreBasin,
      MiningSiteId.silicaDunes,
      MiningSiteId.cobaltChasm,
    ]) {
      final progress = state.sites[id]!;
      expect(progress.unlocked, isFalse);
      expect(progress.commissioned, isFalse);
      expect(progress.storedAmount, 0);
      expect(progress.rigPlacements, isEmpty);
    }
  });

  test('state constructor and copyWith defensively copy nested maps', () {
    final docks = <MiningPlanetId, Map<DockBayId, RigTier?>>{
      for (final planet in MiningPlanetId.values)
        planet: <DockBayId, RigTier?>{
          for (final bay in DockBayId.values) bay: null,
        },
    };
    final placements = <MiningRigPlacement>[];
    final sites = <MiningSiteId, SiteProgress>{
      for (final site in MiningSiteId.values)
        site: SiteProgress(
          unlocked: site == MiningSiteId.landingBasin,
          commissioned: false,
          storedAmount: 0,
          rigPlacements: placements,
        ),
    };
    final state = MiningSave(
      cash: 100,
      lastAccruedAtUtc: DateTime.utc(2026, 8, 26, 12),
      technology: const TechnologyLevels(),
      unlockedPlanetIds: const {MiningPlanetId.homeworld},
      activePlanetId: MiningPlanetId.homeworld,
      docks: docks,
      sites: sites,
    );

    docks[MiningPlanetId.homeworld]![DockBayId.b1] = RigTier.t5;
    placements.add(
      const MiningRigPlacement(tier: RigTier.t5, cell: MiningGridCell(0, 0)),
    );
    sites[MiningSiteId.landingBasin] = SiteProgress(
      unlocked: false,
      commissioned: false,
      storedAmount: 20,
      rigPlacements: const [],
    );

    expect(state.docks[MiningPlanetId.homeworld]![DockBayId.b1], isNull);
    expect(state.sites[MiningSiteId.landingBasin]!.rigPlacements, isEmpty);
    expect(state.sites[MiningSiteId.landingBasin]!.storedAmount, 0);

    final copiedDocks = {
      for (final entry in state.docks.entries)
        entry.key: Map<DockBayId, RigTier?>.from(entry.value),
    };
    final copiedSites = Map<MiningSiteId, SiteProgress>.from(state.sites);
    final copy = state.copyWith(docks: copiedDocks, sites: copiedSites);
    copiedDocks[MiningPlanetId.homeworld]![DockBayId.b1] = RigTier.t4;
    copiedSites[MiningSiteId.landingBasin] = SiteProgress(
      unlocked: true,
      commissioned: true,
      storedAmount: 40,
      rigPlacements: const [],
    );

    expect(copy.docks[MiningPlanetId.homeworld]![DockBayId.b1], isNull);
    expect(copy.sites[MiningSiteId.landingBasin]!.commissioned, isFalse);
    expect(copy.sites[MiningSiteId.landingBasin]!.storedAmount, 0);
  });

  test('nested state maps are immutable snapshots', () {
    final state = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26, 12));

    expect(
      () => state.docks[MiningPlanetId.homeworld]![DockBayId.b1] = null,
      throwsUnsupportedError,
    );
    expect(
      () => state.sites[MiningSiteId.landingBasin]!.rigPlacements.add(
        const MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
      ),
      throwsUnsupportedError,
    );
  });

  test('SiteProgress copyWith snapshots its placement list', () {
    final placements = <MiningRigPlacement>[];
    final progress = SiteProgress(
      unlocked: true,
      commissioned: false,
      storedAmount: 0,
      rigPlacements: placements,
    );
    final copy = progress.copyWith();

    placements.add(
      const MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
    );

    expect(copy.rigPlacements, isEmpty);
  });

  test('save JSON uses flat sites and enum-keyed docks', () {
    final state = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26, 12));

    expect(state.toJson().keys.toSet(), {
      'cash',
      'lastAccruedAtUtc',
      'technology',
      'unlockedPlanetIds',
      'activePlanetId',
      'docks',
      'sites',
    });
    expect(
      (state.toJson()['docks'] as Map<String, Object?>).keys,
      MiningPlanetId.values.map((id) => id.name),
    );
    expect(
      ((state.toJson()['docks'] as Map<String, Object?>)['homeworld']
              as Map<String, Object?>)
          .keys,
      DockBayId.values.map((id) => id.name),
    );
  });
}
