import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_controller.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/next_goal_view.dart';
import 'package:horologium/mining/site_deck_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mining_grid_fixtures.dart';

class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

Future<void> expectAction(
  String label,
  Future<MiningActionResult> action,
) async {
  final result = await action;
  expect(result.isSuccess, isTrue, reason: '$label failed: ${result.message}');
}

/// First row-major legal deploy cell per site at its first playable
/// Surveying level (the journey only ever deploys at or above it).
final journeyCell = () {
  final content = MiningContentRegistry.stellarMining();
  return {
    for (final id in MiningSiteId.values)
      id: firstPlayableCell(content.site(id)),
  };
}();

/// One purchase the player could make between visits: what it costs, the
/// cash per visit it adds, and how to buy it through public actions.
typedef _Investment = ({
  String label,
  int cost,
  double gain,
  Future<void> Function() buy,
});

/// A returning player driven only through public controller actions.
///
/// Each visit lets [step] pass, then travels to and sells every unlocked
/// planet, as a returning player collects everything. Between visits it
/// buys the rig or technology with the best payback whenever that payback
/// is shorter than the wait for the current progression target.
class JourneyPlayer {
  JourneyPlayer(this.controller, this.clock, this.content);

  final MiningController controller;
  final TestClock clock;
  final MiningContentRegistry content;
  Duration step = const Duration(minutes: 1);
  int visits = 0;

  MiningSave get state => controller.state;

  Future<void> travel(MiningPlanetId planet) async {
    if (state.activePlanetId == planet) return;
    await expectAction(
      'travel to ${planet.name}',
      controller.switchPlanet(planet),
    );
  }

  Future<void> visit() async {
    clock.advance(step);
    visits++;
    controller.refresh();
    final home = state.activePlanetId;
    for (final planet in MiningPlanetId.values) {
      if (!state.unlockedPlanetIds.contains(planet)) continue;
      await travel(planet);
      final sale = SiteDeckView.from(
        state: state,
        content: content,
        isBusy: false,
      ).sale;
      if (sale.canSell) {
        final result = await controller.sellAllCargo();
        expect(result.isSuccess, isTrue, reason: 'sell ${planet.name}');
      }
    }
    await travel(home);
  }

  /// Visits until cash reaches [cashAtLeast], investing along the way.
  Future<void> earnUntil({
    required int cashAtLeast,
    required String phase,
    int maxVisits = 200,
  }) async {
    final startedAt = clock.now;
    final startVisits = visits;
    final purchases = <String>[];
    while (true) {
      await _invest(cashAtLeast, purchases);
      if (state.cash >= cashAtLeast) break;
      if (visits - startVisits >= maxVisits) {
        fail(
          '$phase failed to reach cash target $cashAtLeast after '
          '${visits - startVisits} visits of ${step.inMinutes} minutes; '
          'current cash=${state.cash}; '
          'income per visit=${incomePerVisit().floor()}',
        );
      }
      await visit();
    }
    final hours = clock.now.difference(startedAt).inMinutes / 60;
    debugPrint(
      'CADENCE step=${step.inMinutes}m phase=$phase '
      'elapsed=${hours.toStringAsFixed(1)}h visits=${visits - startVisits} '
      'cash=${state.cash} bought=${purchases.join(',')}',
    );
  }

  List<RigTier> _rigs(MiningSiteId id) => [
    for (final rig in state.sites[id]!.rigPlacements) rig.tier,
  ];

  double _siteIncome(
    MiningSiteId id,
    List<RigTier> rigs,
    TechnologyLevels tech,
  ) {
    if (rigs.isEmpty) return 0;
    final units = math.min(
      content.effectiveSiteRate(id, rigs, tech.extraction) * step.inSeconds,
      content.effectiveSiteCapacity(id, rigs, tech.logistics),
    );
    return content.cargoValue(id, units, state.relaunchCount);
  }

  Iterable<MiningSiteDefinition> get _producingSites => [
    for (final planet in content.planets.values)
      if (state.unlockedPlanetIds.contains(planet.id))
        for (final site in planet.sites)
          if (state.sites[site.id]!.commissioned) site,
  ];

  double incomePerVisit([TechnologyLevels? tech]) => _producingSites.fold(
    0,
    (sum, site) =>
        sum + _siteIncome(site.id, _rigs(site.id), tech ?? state.technology),
  );

  MiningGridCell? _freeCell(MiningSiteId id) {
    final site = content.site(id);
    final occupied = [
      for (final rig in state.sites[id]!.rigPlacements) rig.cell,
    ];
    for (final cell in deployableMiningCells(
      site,
      surveyingLevel: state.technology.surveying,
    )) {
      final placement = evaluateMiningPlacement(
        gridWidth: site.gridWidth,
        gridHeight: site.gridHeight,
        deposits: site.deposits,
        occupiedRigCells: occupied,
        candidate: cell,
        surveyingLevel: state.technology.surveying,
        maxRigCount: MiningContentRegistry.maxDeployedRigsPerSite,
      );
      if (placement.isAllowed) return cell;
    }
    return null;
  }

  /// Builds a rig of [tier] in the active planet's dock from T1 spawns.
  Future<DockBayId> _build(RigTier tier) async {
    if (tier == RigTier.t1) {
      final spawn = await controller.spawnRig();
      expect(spawn.isSuccess, isTrue, reason: 'spawn: ${spawn.message}');
      return spawn.dockBayId!;
    }
    final lower = RigTier.values[tier.index - 1];
    final source = await _build(lower);
    final target = await _build(lower);
    await expectAction(
      'merge to ${tier.name}',
      controller.mergeDockRigs(source, target),
    );
    return target;
  }

  DockBayId _firstEmptyBay() => DockBayId.values.firstWhere(
    (bay) => state.docks[state.activePlanetId]![bay] == null,
  );

  List<_Investment> _investments() {
    final current = incomePerVisit();
    final options = <_Investment>[];
    for (final site in _producingSites) {
      final planet = content.planets.values
          .firstWhere((planet) => planet.sites.contains(site))
          .id;
      final spawnCost = content.planet(planet).rigSpawnCost;
      final rigs = _rigs(site.id);
      final others = current - _siteIncome(site.id, rigs, state.technology);
      final cell = rigs.length < MiningContentRegistry.maxDeployedRigsPerSite
          ? _freeCell(site.id)
          : null;
      if (cell != null) {
        options.add((
          label: '${site.name} +T1',
          cost: spawnCost,
          gain:
              others +
              _siteIncome(site.id, [...rigs, RigTier.t1], state.technology) -
              current,
          buy: () async {
            await travel(planet);
            final bay = await _build(RigTier.t1);
            await expectAction(
              'deploy to ${site.name}',
              controller.deployRig(bay, site.id, cell),
            );
          },
        ));
        continue;
      }
      // A full site upgrades its lowest rig by merging in a matching one.
      // Building a T4 already needs every dock bay, so upgrades stop there.
      final placement = state.sites[site.id]!.rigPlacements.reduce(
        (a, b) => a.tier.index <= b.tier.index ? a : b,
      );
      if (placement.tier.index >= RigTier.t4.index) continue;
      final upgraded = [
        for (final rig in state.sites[site.id]!.rigPlacements)
          rig == placement ? RigTier.values[rig.tier.index + 1] : rig.tier,
      ];
      options.add((
        label:
            '${site.name} ${placement.tier.name}->'
            '${RigTier.values[placement.tier.index + 1].name}',
        cost: spawnCost * (1 << placement.tier.index),
        gain:
            others + _siteIncome(site.id, upgraded, state.technology) - current,
        buy: () async {
          await travel(planet);
          final recalledBay = _firstEmptyBay();
          await expectAction(
            'recall from ${site.name}',
            controller.recallRig(site.id, placement.cell),
          );
          final built = await _build(placement.tier);
          await expectAction(
            'merge recalled rig',
            controller.mergeDockRigs(recalledBay, built),
          );
          await expectAction(
            'redeploy to ${site.name}',
            controller.deployRig(built, site.id, placement.cell),
          );
        },
      ));
    }
    final technology = TechnologySheetView.from(state: state, content: content);
    for (final track in const [
      TechnologyTrack.extraction,
      TechnologyTrack.logistics,
    ]) {
      final view = technology.track(track);
      if (!view.canPurchase) continue;
      final levels = state.technology;
      final extraction = track == TechnologyTrack.extraction;
      final next = TechnologyLevels(
        extraction: levels.extraction + (extraction ? 1 : 0),
        logistics: levels.logistics + (extraction ? 0 : 1),
        surveying: levels.surveying,
      );
      options.add((
        label: '${track.name} ${view.level + 1}',
        cost: view.cost!,
        gain: incomePerVisit(next) - current,
        buy: () => expectAction(
          'research ${track.name}',
          controller.purchaseTechnology(track),
        ),
      ));
    }
    return options;
  }

  /// Buys the best-payback investment while it shortens the wait for
  /// [target]: cost / gain must be under the visits still needed.
  Future<void> _invest(int target, List<String> purchases) async {
    final home = state.activePlanetId;
    while (state.cash < target) {
      final income = incomePerVisit();
      final visitsLeft = income <= 0
          ? double.infinity
          : (target - state.cash) / income;
      _Investment? best;
      for (final option in _investments()) {
        if (option.gain <= 0 || option.cost > state.cash) continue;
        if (option.cost / option.gain >= visitsLeft) continue;
        if (best == null || option.gain / option.cost > best.gain / best.cost) {
          best = option;
        }
      }
      if (best == null) break;
      await best.buy();
      purchases.add(best.label);
    }
    await travel(home);
  }
}

void main() {
  test(
    'earnUntil reports phase, target, step, and cash at its bound',
    () async {
      SharedPreferences.setMockInitialValues({});
      final clock = TestClock(DateTime.utc(2026, 8, 27, 12));
      final content = MiningContentRegistry.stellarMining();
      final controller = MiningController(
        content: content,
        repository: MiningSaveRepository(content: content),
        nowUtc: clock.call,
      );
      await controller.initialize();
      final player = JourneyPlayer(controller, clock, content)
        ..step = const Duration(hours: 2);

      await expectLater(
        player.earnUntil(cashAtLeast: 101, phase: 'bound probe', maxVisits: 0),
        throwsA(
          predicate<Object>((error) {
            final message = error.toString();
            return message.contains('bound probe') &&
                message.contains('cash target 101') &&
                message.contains('visits of 120 minutes') &&
                message.contains('current cash=100');
          }),
        ),
      );
    },
  );

  for (final (cadence, marsMinimum, marsMaximum, ceresMinimum, ceresMaximum)
      in const [
        // A return every storage window: about a day of returns to Mars,
        // about two to Ceres.
        (
          Duration(hours: 2),
          Duration(hours: 24),
          Duration(hours: 60),
          Duration(hours: 40),
          Duration(hours: 90),
        ),
        // Four visits a day: storage caps between visits.
        (
          Duration(hours: 6),
          Duration(days: 2),
          Duration(days: 4),
          Duration(days: 4),
          Duration(days: 8),
        ),
      ]) {
    test(
      'fresh public actions master Mars at ${cadence.inHours}h visits within '
      '${marsMinimum.inHours}-${marsMaximum.inHours}h, Ceres within '
      '${ceresMinimum.inHours}-${ceresMaximum.inHours}h, and reload the save',
      () => _journey(
        cadence,
        marsMinimum: marsMinimum,
        marsMaximum: marsMaximum,
        ceresMinimum: ceresMinimum,
        ceresMaximum: ceresMaximum,
      ),
    );
  }
}

MiningNextGoalView _goal(JourneyPlayer player) => MiningNextGoalView.from(
  state: player.controller.state,
  content: player.content,
  sellableValue: SiteDeckView.from(
    state: player.controller.state,
    content: player.content,
    isBusy: false,
  ).projectedValue,
);

void _expectGoal(
  JourneyPlayer player,
  MiningGoalKind kind,
  String title,
  String point,
) {
  final next = _goal(player);
  expect(next.kind, kind, reason: '$point goal kind');
  expect(next.title, title, reason: '$point goal title');
}

Future<void> _commission(JourneyPlayer player, MiningSiteId site) async {
  final spawn = await player.controller.spawnRig();
  expect(spawn.isSuccess, isTrue, reason: 'spawn: ${spawn.message}');
  await expectAction(
    'commission ${site.name}',
    player.controller.deployRig(spawn.dockBayId!, site, journeyCell[site]!),
  );
  expect(player.controller.state.sites[site]!.commissioned, isTrue);
}

/// One full run: fresh Homeworld through final-planet mastery via public
/// actions, ending with the mastered-state recall/redeploy check. The
/// returned timings are measured from this run's own start.
Future<({Duration opening, Duration mars, Duration last})> _playRun(
  JourneyPlayer player,
  Duration cadence,
) async {
  final controller = player.controller;
  final content = player.content;
  final runStart = player.clock.now;

  await expectAction(
    'merge the fresh Homeworld rigs',
    controller.mergeDockRigs(DockBayId.b1, DockBayId.b2),
  );
  expect(
    controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b2],
    RigTier.t2,
  );
  await expectAction(
    'commission Landing Basin',
    controller.deployRig(
      DockBayId.b2,
      MiningSiteId.landingBasin,
      journeyCell[MiningSiteId.landingBasin]!,
    ),
  );
  expect(
    controller.state.sites[MiningSiteId.landingBasin]!.commissioned,
    isTrue,
  );
  debugPrint('SEQUENCE Homeworld merge t1+t1->t2; deploy Landing Basin');

  // The opening session is active play, selling every minute.
  await player.earnUntil(
    cashAtLeast: 250,
    phase: 'Homeworld before Carbon Ridge',
  );
  await expectAction(
    'unlock Carbon Ridge',
    controller.unlockSite(MiningSiteId.carbonRidge),
  );
  await _commission(player, MiningSiteId.carbonRidge);

  await player.earnUntil(
    cashAtLeast: 700,
    phase: 'Homeworld before Granite Crater',
  );
  await expectAction(
    'unlock Granite Crater',
    controller.unlockSite(MiningSiteId.graniteCrater),
  );
  await _commission(player, MiningSiteId.graniteCrater);
  expect(
    content.isPlanetMastered(
      MiningPlanetId.homeworld,
      MiningSiteId.values.where(
        (id) => controller.state.sites[id]!.commissioned,
      ),
    ),
    isTrue,
  );
  _expectGoal(
    player,
    MiningGoalKind.researchSurveying,
    'Research Surveying 1',
    'Homeworld mastery',
  );

  await player.earnUntil(
    cashAtLeast: 2500,
    phase: 'Homeworld mastery and Surveying 3',
  );
  for (final level in [1, 2, 3]) {
    await expectAction(
      'raise Surveying to $level',
      controller.purchaseTechnology(TechnologyTrack.surveying),
    );
  }
  expect(controller.state.technology.surveying, 3);
  _expectGoal(
    player,
    MiningGoalKind.unlockPlanet,
    'Unlock Lunar Frontier',
    'Surveying 3',
  );
  final opening = player.clock.now.difference(runStart);
  debugPrint('OPENING elapsed=${opening.inMinutes}m');

  // From here the player returns once per cadence.
  player.step = cadence;
  await player.earnUntil(
    cashAtLeast: 200000,
    phase: 'Homeworld before Lunar unlock',
  );
  await expectAction(
    'unlock Lunar Frontier',
    controller.unlockPlanet(MiningPlanetId.lunarFrontier),
  );
  expect(controller.state.activePlanetId, MiningPlanetId.lunarFrontier);
  expect(controller.state.docks[MiningPlanetId.lunarFrontier], {
    DockBayId.b1: RigTier.t1,
    DockBayId.b2: RigTier.t1,
    DockBayId.b3: null,
    DockBayId.b4: null,
  });
  expect(controller.state.sites[MiningSiteId.frozenBasin]!.unlocked, isTrue);
  _expectGoal(
    player,
    MiningGoalKind.commissionSite,
    'Commission Frozen Basin',
    'Lunar unlock',
  );

  final homeworldCargoBeforeLunarRefresh =
      controller.state.sites[MiningSiteId.landingBasin]!.storedAmount;
  player.clock.advance(const Duration(seconds: 30));
  controller.refresh();
  final homeworldCargoAfterLunarRefresh =
      controller.state.sites[MiningSiteId.landingBasin]!.storedAmount;
  expect(controller.state.activePlanetId, MiningPlanetId.lunarFrontier);
  expect(
    homeworldCargoAfterLunarRefresh,
    greaterThan(homeworldCargoBeforeLunarRefresh),
  );
  debugPrint(
    'INACTIVE_HOMEWORLD active=Lunar Frontier elapsed=30s '
    'cargo=$homeworldCargoBeforeLunarRefresh->$homeworldCargoAfterLunarRefresh',
  );

  await expectAction(
    'merge the fresh Lunar rigs',
    controller.mergeDockRigs(DockBayId.b1, DockBayId.b2),
  );
  await expectAction(
    'commission Frozen Basin',
    controller.deployRig(
      DockBayId.b2,
      MiningSiteId.frozenBasin,
      journeyCell[MiningSiteId.frozenBasin]!,
    ),
  );
  debugPrint('SEQUENCE Lunar merge t1+t1->t2; deploy Frozen Basin');
  _expectGoal(
    player,
    MiningGoalKind.researchSurveying,
    'Research Surveying 4',
    'Frozen Basin commissioned',
  );

  await player.earnUntil(
    cashAtLeast: 590000,
    phase: 'Lunar before Surveying 4 and Titanium Highlands',
  );
  await expectAction(
    'raise Surveying to 4',
    controller.purchaseTechnology(TechnologyTrack.surveying),
  );
  await expectAction(
    'unlock Titanium Highlands',
    controller.unlockSite(MiningSiteId.titaniumHighlands),
  );
  await _commission(player, MiningSiteId.titaniumHighlands);

  await player.earnUntil(
    cashAtLeast: 1440000,
    phase: 'Lunar before Surveying 5 and Helium Mare',
  );
  await expectAction(
    'raise Surveying to 5',
    controller.purchaseTechnology(TechnologyTrack.surveying),
  );
  await expectAction(
    'unlock Helium Mare',
    controller.unlockSite(MiningSiteId.heliumMare),
  );
  await _commission(player, MiningSiteId.heliumMare);
  expect(
    content.isPlanetMastered(
      MiningPlanetId.lunarFrontier,
      MiningSiteId.values.where(
        (id) => controller.state.sites[id]!.commissioned,
      ),
    ),
    isTrue,
  );

  await player.earnUntil(
    cashAtLeast: 16000000,
    phase: 'Lunar mastery before Mars unlock',
  );
  _expectGoal(
    player,
    MiningGoalKind.unlockPlanet,
    'Unlock Mars Frontier',
    'Lunar mastery',
  );
  await expectAction(
    'unlock Mars Frontier',
    controller.unlockPlanet(MiningPlanetId.marsFrontier),
  );
  expect(controller.state.activePlanetId, MiningPlanetId.marsFrontier);
  expect(controller.state.docks[MiningPlanetId.marsFrontier], {
    DockBayId.b1: RigTier.t1,
    DockBayId.b2: RigTier.t1,
    DockBayId.b3: null,
    DockBayId.b4: null,
  });
  expect(controller.state.sites[MiningSiteId.ochreBasin]!.unlocked, isTrue);

  await expectAction(
    'merge the fresh Mars rigs',
    controller.mergeDockRigs(DockBayId.b1, DockBayId.b2),
  );
  await expectAction(
    'commission Ochre Basin',
    controller.deployRig(
      DockBayId.b2,
      MiningSiteId.ochreBasin,
      journeyCell[MiningSiteId.ochreBasin]!,
    ),
  );
  debugPrint('SEQUENCE Mars merge t1+t1->t2; deploy Ochre Basin');

  await player.earnUntil(
    cashAtLeast: 14000000,
    phase: 'Mars before Silica Dunes',
  );
  await expectAction(
    'unlock Silica Dunes',
    controller.unlockSite(MiningSiteId.silicaDunes),
  );
  await _commission(player, MiningSiteId.silicaDunes);

  await player.earnUntil(
    cashAtLeast: 29000000,
    phase: 'Mars before Cobalt Chasm',
  );
  await expectAction(
    'unlock Cobalt Chasm',
    controller.unlockSite(MiningSiteId.cobaltChasm),
  );
  final cobaltSpawn = await controller.spawnRig();
  expect(cobaltSpawn.isSuccess, isTrue);
  _expectGoal(
    player,
    MiningGoalKind.commissionSite,
    'Commission Cobalt Chasm',
    'final Mars site',
  );
  expect(_goal(player).detail, 'Deploy a rig beside a resource.');
  final cashBeforeMarsMastery = controller.state.cash;
  final marsMastery = await controller.deployRig(
    cobaltSpawn.dockBayId!,
    MiningSiteId.cobaltChasm,
    journeyCell[MiningSiteId.cobaltChasm]!,
  );
  expect(marsMastery.isSuccess, isTrue);
  expect(marsMastery.message, isNull);
  expect(controller.state.cash, cashBeforeMarsMastery);
  expect(
    content.isPlanetMastered(
      MiningPlanetId.marsFrontier,
      MiningSiteId.values.where(
        (id) => controller.state.sites[id]!.commissioned,
      ),
    ),
    isTrue,
  );
  _expectGoal(
    player,
    MiningGoalKind.unlockPlanet,
    'Unlock Ceres Frontier',
    'Mars mastery',
  );
  final toMarsMastery = player.clock.now.difference(runStart);
  debugPrint(
    'MASTERY planet=Mars step=${cadence.inHours}h elapsed='
    '${(toMarsMastery.inMinutes / 60).toStringAsFixed(1)}h '
    'visits=${player.visits} cash=${controller.state.cash} '
    'tech=${controller.state.technology.toJson()}',
  );

  await player.earnUntil(
    cashAtLeast: 30000000,
    phase: 'Mars mastery before Ceres unlock',
  );
  await expectAction(
    'unlock Ceres Frontier',
    controller.unlockPlanet(MiningPlanetId.ceresFrontier),
  );
  expect(controller.state.activePlanetId, MiningPlanetId.ceresFrontier);
  expect(controller.state.docks[MiningPlanetId.ceresFrontier], {
    DockBayId.b1: RigTier.t1,
    DockBayId.b2: RigTier.t1,
    DockBayId.b3: null,
    DockBayId.b4: null,
  });
  expect(controller.state.sites[MiningSiteId.nickelShoals]!.unlocked, isTrue);
  _expectGoal(
    player,
    MiningGoalKind.commissionSite,
    'Commission Nickel Shoals',
    'Ceres unlock',
  );

  await expectAction(
    'merge the fresh Ceres rigs',
    controller.mergeDockRigs(DockBayId.b1, DockBayId.b2),
  );
  await expectAction(
    'commission Nickel Shoals',
    controller.deployRig(
      DockBayId.b2,
      MiningSiteId.nickelShoals,
      journeyCell[MiningSiteId.nickelShoals]!,
    ),
  );
  debugPrint('SEQUENCE Ceres merge t1+t1->t2; deploy Nickel Shoals');

  await player.earnUntil(
    cashAtLeast: 25500000,
    phase: 'Ceres before Platinum Rift',
  );
  await expectAction(
    'unlock Platinum Rift',
    controller.unlockSite(MiningSiteId.platinumRift),
  );
  await _commission(player, MiningSiteId.platinumRift);

  await player.earnUntil(
    cashAtLeast: 52500000,
    phase: 'Ceres before Iridium Spire',
  );
  await expectAction(
    'unlock Iridium Spire',
    controller.unlockSite(MiningSiteId.iridiumSpire),
  );
  final iridiumSpawn = await controller.spawnRig();
  expect(iridiumSpawn.isSuccess, isTrue);
  _expectGoal(
    player,
    MiningGoalKind.commissionSite,
    'Commission Iridium Spire',
    'final Ceres site',
  );
  expect(_goal(player).detail, contains('+30.00M'));
  final cashBeforeCeresMastery = controller.state.cash;
  final mastery = await controller.deployRig(
    iridiumSpawn.dockBayId!,
    MiningSiteId.iridiumSpire,
    journeyCell[MiningSiteId.iridiumSpire]!,
  );
  expect(mastery.isSuccess, isTrue);
  expect(mastery.message, 'Ceres mastered — +30.00M cash.');
  expect(controller.state.cash, cashBeforeCeresMastery + 30000000);
  expect(_goal(player).kind, MiningGoalKind.relaunch);
  expect(_goal(player).title, 'Relaunch');
  final toMastery = player.clock.now.difference(runStart);
  final ceresPhase = toMastery - toMarsMastery;
  debugPrint(
    'MASTERY planet=Ceres step=${cadence.inHours}h elapsed='
    '${(toMastery.inMinutes / 60).toStringAsFixed(1)}h '
    'ceresPhase=${(ceresPhase.inMinutes / 60).toStringAsFixed(1)}h '
    'visits=${player.visits} reward=30000000 '
    'cash=$cashBeforeCeresMastery->${controller.state.cash} '
    'tech=${controller.state.technology.toJson()}',
  );
  for (final siteId in MiningSiteId.values) {
    expect(controller.state.sites[siteId]!.commissioned, isTrue);
  }

  final cashAfterFirstMastery = controller.state.cash;
  await expectAction(
    'recall the mastered Iridium Spire rig',
    controller.recallRig(
      MiningSiteId.iridiumSpire,
      journeyCell[MiningSiteId.iridiumSpire]!,
    ),
  );
  final redeploy = await controller.deployRig(
    iridiumSpawn.dockBayId!,
    MiningSiteId.iridiumSpire,
    journeyCell[MiningSiteId.iridiumSpire]!,
  );
  expect(redeploy.isSuccess, isTrue);
  expect(redeploy.message, isNull);
  expect(controller.state.cash, cashAfterFirstMastery);

  return (opening: opening, mars: toMarsMastery, last: toMastery);
}

Future<void> _journey(
  Duration cadence, {
  required Duration marsMinimum,
  required Duration marsMaximum,
  required Duration ceresMinimum,
  required Duration ceresMaximum,
}) async {
  SharedPreferences.setMockInitialValues({});
  final clock = TestClock(DateTime.utc(2026, 8, 27, 12));
  final content = MiningContentRegistry.stellarMining();
  final repository = MiningSaveRepository(content: content);
  final controller = MiningController(
    content: content,
    repository: repository,
    nowUtc: clock.call,
  );
  final player = JourneyPlayer(controller, clock, content);

  await controller.initialize();
  expect(controller.state.cash, 100);
  expect(controller.state.unlockedPlanetIds, {MiningPlanetId.homeworld});
  expect(controller.state.activePlanetId, MiningPlanetId.homeworld);
  expect(controller.state.docks[MiningPlanetId.homeworld], {
    DockBayId.b1: RigTier.t1,
    DockBayId.b2: RigTier.t1,
    DockBayId.b3: null,
    DockBayId.b4: null,
  });
  expect(controller.state.sites[MiningSiteId.landingBasin]!.unlocked, isTrue);
  _expectGoal(
    player,
    MiningGoalKind.commissionSite,
    'Commission Landing Basin',
    'fresh save',
  );

  final run1 = await _playRun(player, cadence);

  // Run 1 keeps the original absolute pacing bands; run 2 is judged only
  // against run 1 below.
  expect(run1.opening, lessThanOrEqualTo(const Duration(minutes: 20)));
  expect(run1.mars, greaterThanOrEqualTo(marsMinimum));
  expect(run1.mars, lessThanOrEqualTo(marsMaximum));
  expect(run1.last, greaterThanOrEqualTo(ceresMinimum));
  expect(run1.last, lessThanOrEqualTo(ceresMaximum));

  final beforeReload = controller.state;
  final reloaded = MiningController(
    content: content,
    repository: repository,
    nowUtc: clock.call,
  );
  await reloaded.initialize();
  expect(reloaded.recoveredFromInvalidSave, isFalse);
  expect(reloaded.state.cash, beforeReload.cash);
  expect(reloaded.state.technology, beforeReload.technology);
  expect(reloaded.state.unlockedPlanetIds, MiningPlanetId.values.toSet());
  expect(reloaded.state.activePlanetId, MiningPlanetId.ceresFrontier);
  for (final planetId in MiningPlanetId.values) {
    expect(reloaded.state.docks[planetId], beforeReload.docks[planetId]);
  }
  for (final siteId in MiningSiteId.values) {
    expect(reloaded.state.sites[siteId], beforeReload.sites[siteId]);
  }
  debugPrint(
    'RELOAD active=${reloaded.state.activePlanetId.name} '
    'surveying=${reloaded.state.technology.surveying} '
    'ceresCash=${reloaded.state.cash} ceresSites=3/3',
  );

  // A 30-hour absence accrues exactly the 24-hour safety cap.
  clock.advance(const Duration(hours: 30));
  final returned = MiningController(
    content: content,
    repository: repository,
    nowUtc: clock.call,
  );
  await returned.initialize();
  final away = returned.takePendingReturnSummary();
  expect(away, isNotNull);
  expect(away!.elapsedUsed, const Duration(hours: 24));
  expect(away.wasOfflineCapped, isTrue);
  expect(returned.state.lastAccruedAtUtc, clock.now);

  // Relaunch on the returned controller: only its state matches the save.
  final relaunch = await returned.relaunch();
  expect(relaunch.isSuccess, isTrue, reason: relaunch.message);

  final run2Player = JourneyPlayer(returned, clock, content);
  expect(returned.state.cash, 100);
  expect(returned.state.technology, const TechnologyLevels());
  expect(returned.state.relaunchCount, 1);
  final run2 = await _playRun(run2Player, cadence);
  debugPrint(
    'RELAUNCH run=2 mastery=${(run2.last.inMinutes / 60).toStringAsFixed(1)}h '
    'run1=${(run1.last.inMinutes / 60).toStringAsFixed(1)}h '
    'finalPlanet=${content.planet(content.finalPlanetId).name}',
  );
  if (cadence == const Duration(hours: 2)) {
    expect(
      run2.last,
      lessThanOrEqualTo(run1.last * 0.8),
      reason: 'relaunch run 2 at ${cadence.inHours}h cadence',
    );
  } else {
    expect(
      run2.last,
      lessThan(run1.last),
      reason: 'relaunch run 2 at ${cadence.inHours}h cadence',
    );
  }

  final reloadedAfterRelaunch = MiningController(
    content: content,
    repository: repository,
    nowUtc: clock.call,
  );
  await reloadedAfterRelaunch.initialize();
  expect(reloadedAfterRelaunch.state.relaunchCount, 1);
}
