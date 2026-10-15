import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/next_goal_view.dart';

final _content = MiningContentRegistry.stellarMining();
final _now = DateTime.utc(2026, 10, 15, 12);

SiteProgress _progress({bool unlocked = false, bool commissioned = false}) =>
    SiteProgress(
      unlocked: unlocked,
      commissioned: commissioned,
      storedAmount: 0,
      rigPlacements: const [],
    );

SiteProgress _commissioned() => _progress(unlocked: true, commissioned: true);

Map<MiningSiteId, SiteProgress> _commissionedSites(
  Iterable<MiningSiteId> ids,
) => {for (final id in ids) id: _commissioned()};

final _homeworldSites = _content
    .planet(MiningPlanetId.homeworld)
    .sites
    .map((site) => site.id);
final _lunarSites = _content
    .planet(MiningPlanetId.lunarFrontier)
    .sites
    .map((site) => site.id);

MiningSave _stateWith({
  int? cash,
  TechnologyLevels? technology,
  Set<MiningPlanetId>? unlockedPlanetIds,
  MiningPlanetId? activePlanetId,
  Map<MiningPlanetId, Map<DockBayId, RigTier?>>? docks,
  Map<MiningSiteId, SiteProgress>? sites,
}) {
  final initial = MiningSave.initial(nowUtc: _now);
  return initial.copyWith(
    cash: cash,
    technology: technology,
    unlockedPlanetIds: unlockedPlanetIds,
    activePlanetId: activePlanetId,
    docks: docks == null ? null : {...initial.docks, ...docks},
    sites: sites == null ? null : {...initial.sites, ...sites},
  );
}

Map<DockBayId, RigTier?> _dock([RigTier? b1, RigTier? b2]) => {
  DockBayId.b1: b1,
  DockBayId.b2: b2,
  DockBayId.b3: null,
  DockBayId.b4: null,
};

MiningNextGoalView _goal(MiningSave state, {int sellableValue = 0}) =>
    MiningNextGoalView.from(
      state: state,
      content: _content,
      sellableValue: sellableValue,
    );

/// Homeworld mastered on a single-planet save, as after the third Homeworld
/// commission.
MiningSave _homeworldMastered({int cash = 0, int surveying = 0}) => _stateWith(
  cash: cash,
  technology: TechnologyLevels(surveying: surveying),
  sites: _commissionedSites(_homeworldSites),
);

void main() {
  group('MiningNextGoalView ladder', () {
    test('fresh save commissions Landing Basin', () {
      final goal = _goal(MiningSave.initial(nowUtc: _now));

      expect(goal.kind, MiningGoalKind.commissionSite);
      expect(goal.title, 'Commission Landing Basin');
      expect(goal.detail, 'Deploy a rig beside a resource.');
      expect(
        goal.target,
        const MiningGoalTarget.mineSite(MiningSiteId.landingBasin),
      );
      expect(goal.isCashGated, isFalse);
      expect(goal.cashCost, isNull);
      expect(goal.progress, isNull);
      expect(goal.cashLabel, isNull);
    });

    test('an empty dock makes commissioning cash-gated on a spawn', () {
      final goal = _goal(
        _stateWith(
          cash: 10,
          docks: {MiningPlanetId.homeworld: _dock()},
          sites: {
            MiningSiteId.landingBasin: _commissioned(),
            MiningSiteId.carbonRidge: _progress(unlocked: true),
          },
        ),
      );

      expect(goal.kind, MiningGoalKind.commissionSite);
      expect(goal.title, 'Commission Carbon Ridge');
      expect(goal.detail, 'Spawn a rig for 25 cash, then deploy it.');
      expect(goal.cashCost, 25);
      expect(goal.progress, closeTo(0.4, 1e-9));
      expect(
        goal.target,
        const MiningGoalTarget.mineSite(MiningSiteId.carbonRidge),
      );
    });

    test('a ready spawn keeps the spawn instruction', () {
      final goal = _goal(
        _stateWith(
          cash: 40,
          docks: {MiningPlanetId.homeworld: _dock()},
          sites: {
            MiningSiteId.landingBasin: _commissioned(),
            MiningSiteId.carbonRidge: _progress(unlocked: true),
          },
        ),
      );

      expect(goal.isReady, isTrue);
      expect(goal.detail, 'Spawn a rig for 25 cash, then deploy it.');
    });

    group('unlock site', () {
      MiningSave landingOnly(int cash) => _stateWith(
        cash: cash,
        sites: {MiningSiteId.landingBasin: _commissioned()},
      );

      test('short of cash shows progress and the card instruction', () {
        final goal = _goal(landingOnly(100));

        expect(goal.kind, MiningGoalKind.unlockSite);
        expect(goal.title, 'Unlock Carbon Ridge');
        expect(goal.detail, 'Unlock it on its card below.');
        expect(goal.cashCost, 250);
        expect(goal.progress, closeTo(0.4, 1e-9));
        expect(goal.cashLabel, '100 / 250');
        expect(goal.sellWouldAfford, isFalse);
        expect(goal.target, const MiningGoalTarget.none());
        expect(goal.target.isNavigable, isFalse);
      });

      test('says to sell when active cargo would cover the cost', () {
        final goal = _goal(landingOnly(100), sellableValue: 150);

        expect(goal.detail, 'Sell cargo to afford it.');
        expect(goal.sellWouldAfford, isTrue);
        expect(goal.isReady, isFalse);
      });

      test('cargo short of the cost keeps the default detail', () {
        final goal = _goal(landingOnly(100), sellableValue: 149);

        expect(goal.detail, 'Unlock it on its card below.');
        expect(goal.sellWouldAfford, isFalse);
      });

      test('affordable unlock is ready', () {
        final goal = _goal(landingOnly(250), sellableValue: 500);

        expect(goal.detail, 'Ready: unlock it below.');
        expect(goal.isReady, isTrue);
        expect(goal.sellWouldAfford, isFalse);
        expect(goal.progress, 1);
      });

      test('progress clamps above the cost', () {
        expect(_goal(landingOnly(1_000)).progress, 1);
        expect(_goal(landingOnly(1_000)).cashLabel, '1,000 / 250');
      });
    });

    test('a Surveying-gated site asks for research in Technology', () {
      final goal = _goal(
        _stateWith(
          cash: 1_000,
          technology: const TechnologyLevels(surveying: 3),
          unlockedPlanetIds: const {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          activePlanetId: MiningPlanetId.lunarFrontier,
          sites: {
            ..._commissionedSites(_homeworldSites),
            MiningSiteId.frozenBasin: _commissioned(),
          },
        ),
      );

      expect(goal.kind, MiningGoalKind.researchSurveying);
      expect(goal.title, 'Research Surveying 4');
      expect(goal.detail, 'Needed for Titanium Highlands.');
      expect(goal.cashCost, 4000);
      expect(goal.target, const MiningGoalTarget.technology());
    });

    test('a Surveying-gated planet asks for research first', () {
      final goal = _goal(_homeworldMastered());

      expect(goal.kind, MiningGoalKind.researchSurveying);
      expect(goal.title, 'Research Surveying 1');
      expect(goal.detail, 'Needed for Lunar Frontier.');
      expect(goal.cashCost, 300);
    });

    test('ready research points at Technology', () {
      final goal = _goal(_homeworldMastered(cash: 700, surveying: 1));

      expect(goal.title, 'Research Surveying 2');
      expect(goal.detail, 'Ready in Technology.');
    });

    test('next planet unlock points at the Stellar Map', () {
      final goal = _goal(_homeworldMastered(cash: 1_000, surveying: 3));

      expect(goal.kind, MiningGoalKind.unlockPlanet);
      expect(goal.title, 'Unlock Lunar Frontier');
      expect(goal.detail, 'Unlock it from the Stellar Map.');
      expect(goal.cashCost, 2500);
      expect(goal.cashLabel, '1,000 / 2,500');
      expect(goal.target, const MiningGoalTarget.stellarMap());
    });

    test('ready planet unlock says so', () {
      final goal = _goal(_homeworldMastered(cash: 2_500, surveying: 3));

      expect(goal.detail, 'Ready on the Stellar Map.');
    });

    test('an inactive frontier asks the player to return to it', () {
      final goal = _goal(
        _stateWith(
          technology: const TechnologyLevels(surveying: 3),
          unlockedPlanetIds: const {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          activePlanetId: MiningPlanetId.homeworld,
          sites: {
            ..._commissionedSites(_homeworldSites),
            MiningSiteId.frozenBasin: _commissioned(),
          },
        ),
      );

      expect(goal.kind, MiningGoalKind.returnToFrontier);
      expect(goal.title, 'Return to Lunar Frontier');
      expect(goal.detail, '1/3 sites commissioned.');
      expect(goal.target, const MiningGoalTarget.stellarMap());
    });

    test('the last rewarded site names the mastery reward', () {
      final goal = _goal(
        _stateWith(
          technology: const TechnologyLevels(surveying: 5),
          unlockedPlanetIds: MiningPlanetId.values.toSet(),
          activePlanetId: MiningPlanetId.marsFrontier,
          docks: {MiningPlanetId.marsFrontier: _dock(RigTier.t1)},
          sites: {
            ..._commissionedSites(_homeworldSites),
            ..._commissionedSites(_lunarSites),
            MiningSiteId.ochreBasin: _commissioned(),
            MiningSiteId.silicaDunes: _commissioned(),
            MiningSiteId.cobaltChasm: _progress(unlocked: true),
          },
        ),
      );

      expect(goal.title, 'Commission Cobalt Chasm');
      expect(
        goal.detail,
        'Last Mars Frontier site: mastery pays +25,000 cash.',
      );
    });

    test('mastering every frontier points at remaining upgrades', () {
      final goal = _goal(
        _stateWith(
          technology: const TechnologyLevels(surveying: 5, logistics: 5),
          unlockedPlanetIds: MiningPlanetId.values.toSet(),
          sites: _commissionedSites(MiningSiteId.values),
        ),
      );

      expect(goal.kind, MiningGoalKind.frontiersMastered);
      expect(goal.title, 'All frontiers mastered');
      expect(goal.detail, 'Keep upgrading Extraction and Logistics.');
      expect(goal.target, const MiningGoalTarget.technology());
    });

    test('mastering everything with maxed technology has no target', () {
      final goal = _goal(
        _stateWith(
          technology: const TechnologyLevels(
            extraction: 5,
            logistics: 5,
            surveying: 5,
          ),
          unlockedPlanetIds: MiningPlanetId.values.toSet(),
          sites: _commissionedSites(MiningSiteId.values),
        ),
      );

      expect(goal.detail, 'Every frontier is mastered.');
      expect(goal.target, const MiningGoalTarget.none());
    });

    test('an uncommissioned Surveying gate falls back to commissioning it', () {
      // Inconsistent on purpose: only Lunar Frontier is unlocked, so the
      // Titanium Highlands Surveying rung meets an uncommissioned Landing
      // Basin gate. Authored play cannot reach this state.
      final goal = _goal(
        _stateWith(
          cash: 5_000,
          unlockedPlanetIds: const {MiningPlanetId.lunarFrontier},
          activePlanetId: MiningPlanetId.lunarFrontier,
          docks: {MiningPlanetId.homeworld: _dock(RigTier.t1)},
          sites: {
            MiningSiteId.landingBasin: _progress(unlocked: true),
            MiningSiteId.frozenBasin: _commissioned(),
          },
        ),
      );

      expect(goal.kind, MiningGoalKind.commissionSite);
      expect(goal.title, 'Commission Landing Basin');
      expect(
        goal.target,
        const MiningGoalTarget.mineSite(MiningSiteId.landingBasin),
      );
    });

    test('semantics label reads title, detail, and cash progress', () {
      final goal = _goal(
        _stateWith(
          cash: 100,
          sites: {MiningSiteId.landingBasin: _commissioned()},
        ),
      );

      expect(
        goal.semanticsLabel,
        'Next goal: Unlock Carbon Ridge. Unlock it on its card below. '
        '100 of 250 cash.',
      );
      expect(
        _goal(MiningSave.initial(nowUtc: _now)).semanticsLabel,
        'Next goal: Commission Landing Basin. Deploy a rig beside a resource.',
      );
    });

    test('goal targets compare by kind and site', () {
      const basin = MiningGoalTarget.mineSite(MiningSiteId.landingBasin);
      final sameBasin = MiningGoalTarget.mineSite(MiningSiteId.values.first);

      expect(sameBasin, basin);
      expect(sameBasin.hashCode, basin.hashCode);
      expect(
        basin,
        isNot(const MiningGoalTarget.mineSite(MiningSiteId.carbonRidge)),
      );
      expect(
        const MiningGoalTarget.technology(),
        isNot(const MiningGoalTarget.stellarMap()),
      );
      expect(basin.toString(), 'MiningGoalTarget(mineSite, landingBasin)');
      expect(
        const MiningGoalTarget.none().toString(),
        'MiningGoalTarget(none, null)',
      );
    });
  });

  group('authored content invariants the ladder relies on', () {
    final order = <MiningSiteId>[
      for (final planetId in MiningPlanetId.values)
        for (final site in _content.planet(planetId).sites) site.id,
    ];

    test('Surveying gates precede every site that needs them', () {
      for (final planetId in MiningPlanetId.values) {
        for (final site in _content.planet(planetId).sites) {
          for (final gate in MiningContentRegistry.technologySiteGates.take(
            site.requiredSurveyingLevel,
          )) {
            expect(
              order.indexOf(gate),
              lessThan(order.indexOf(site.id)),
              reason: '${site.name} needs ${gate.name} commissioned first',
            );
          }
        }
      }
    });

    test('Surveying gates for a planet sit on earlier planets', () {
      for (final planetId in MiningPlanetId.values) {
        final planet = _content.planet(planetId);
        for (final gate in MiningContentRegistry.technologySiteGates.take(
          planet.unlockRequiredSurveyingLevel,
        )) {
          expect(
            _content.planetForSite(gate).index,
            lessThan(planetId.index),
            reason: '${planet.name} needs ${gate.name} commissioned first',
          );
        }
      }
    });

    test('every requiredSite precedes its site on the same planet', () {
      for (final planetId in MiningPlanetId.values) {
        final sites = _content.planet(planetId).sites;
        for (var index = 0; index < sites.length; index++) {
          final requiredSite = sites[index].requiredSite;
          if (requiredSite == null) continue;
          final requiredIndex = sites.indexWhere(
            (site) => site.id == requiredSite,
          );
          expect(requiredIndex, isNonNegative);
          expect(requiredIndex, lessThan(index));
        }
      }
    });

    test('each planet requires mastery of the planet before it', () {
      for (final planetId in MiningPlanetId.values) {
        final required = _content
            .planet(planetId)
            .unlockRequiredMasteryPlanetId;
        if (planetId.index == 0) {
          expect(required, isNull);
        } else {
          expect(required, MiningPlanetId.values[planetId.index - 1]);
        }
      }
    });
  });
}
