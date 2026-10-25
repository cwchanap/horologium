import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

enum MiningGoalKind {
  commissionSite,
  unlockSite,
  researchSurveying,
  unlockPlanet,
  returnToFrontier,
  relaunch,
}

enum MiningGoalTargetKind { mineSite, technology, stellarMap, none }

/// Where tapping the next-goal strip navigates. Navigation only: a target
/// never names a mutation.
class MiningGoalTarget {
  const MiningGoalTarget.mineSite(MiningSiteId this.siteId)
    : kind = MiningGoalTargetKind.mineSite;
  const MiningGoalTarget.technology()
    : kind = MiningGoalTargetKind.technology,
      siteId = null;
  const MiningGoalTarget.stellarMap()
    : kind = MiningGoalTargetKind.stellarMap,
      siteId = null;
  const MiningGoalTarget.none()
    : kind = MiningGoalTargetKind.none,
      siteId = null;

  final MiningGoalTargetKind kind;
  final MiningSiteId? siteId;

  bool get isNavigable => kind != MiningGoalTargetKind.none;

  @override
  bool operator ==(Object other) =>
      other is MiningGoalTarget && kind == other.kind && siteId == other.siteId;

  @override
  int get hashCode => Object.hash(kind, siteId);

  @override
  String toString() => 'MiningGoalTarget(${kind.name}, ${siteId?.name})';
}

/// Stateless projection of the one next progression step, walked along the
/// authored Homeworld -> Lunar Frontier -> Mars Frontier order in the same
/// guard order as [MiningController]'s unlock, research, and planet actions.
class MiningNextGoalView {
  const MiningNextGoalView({
    required this.kind,
    required this.title,
    required this.detail,
    required this.target,
    required this.cash,
    this.cashCost,
    this.sellWouldAfford = false,
  });

  final MiningGoalKind kind;
  final String title;
  final String detail;
  final MiningGoalTarget target;
  final int cash;

  /// Cash the goal still needs in total, or null when the goal is not
  /// cash-gated.
  final int? cashCost;

  /// Selling the active planet's cargo would cover [cashCost].
  final bool sellWouldAfford;

  bool get isCashGated => cashCost != null;

  bool get isReady => cashCost != null && cash >= cashCost!;

  double? get progress {
    final cost = cashCost;
    if (cost == null) return null;
    if (cost <= 0) return 1;
    return (cash / cost).clamp(0.0, 1.0).toDouble();
  }

  String? get cashLabel {
    final cost = cashCost;
    if (cost == null) return null;
    return '${formatMiningCash(cash)} / ${formatMiningCash(cost)}';
  }

  String get semanticsLabel {
    final cost = cashCost;
    final cashPart = cost == null
        ? ''
        : ' ${formatMiningCash(cash)} of ${formatMiningCash(cost)} cash.';
    return 'Next goal: $title. $detail$cashPart';
  }

  /// [sellableValue] is the active planet's floored sale value
  /// ([SiteDeckView.projectedValue]), so the sell hint never disagrees with
  /// the Sell button.
  static MiningNextGoalView from({
    required MiningSave state,
    required MiningContentRegistry content,
    required int sellableValue,
  }) {
    final ladder = _GoalLadder(state, content, sellableValue);
    for (final planetId in MiningPlanetId.values) {
      if (state.unlockedPlanetIds.contains(planetId) &&
          !ladder.isMastered(planetId)) {
        return ladder.frontier(planetId);
      }
    }
    for (final planetId in MiningPlanetId.values) {
      if (!state.unlockedPlanetIds.contains(planetId)) {
        return ladder.nextPlanet(planetId);
      }
    }
    return ladder.complete();
  }
}

class _GoalLadder {
  _GoalLadder(this.state, this.content, this.sellableValue)
    : commissioned = {
        for (final entry in state.sites.entries)
          if (entry.value.commissioned) entry.key,
      };

  final MiningSave state;
  final MiningContentRegistry content;
  final int sellableValue;
  final Set<MiningSiteId> commissioned;

  bool isMastered(MiningPlanetId id) =>
      content.isPlanetMastered(id, commissioned);

  MiningNextGoalView frontier(MiningPlanetId planetId) {
    final planet = content.planet(planetId);
    if (planetId != state.activePlanetId) {
      final done = planet.sites
          .where((site) => commissioned.contains(site.id))
          .length;
      return _plain(
        kind: MiningGoalKind.returnToFrontier,
        title: 'Return to ${planet.name}',
        detail: '$done/${planet.sites.length} sites commissioned.',
        target: const MiningGoalTarget.stellarMap(),
      );
    }
    final site = planet.sites.firstWhere(
      (site) => !commissioned.contains(site.id),
    );
    if (state.sites[site.id]!.unlocked) return _commission(site);
    if (state.technology.surveying < site.requiredSurveyingLevel) {
      return _surveying(neededFor: site.name);
    }
    // requiredSite is not re-checked: the walk already passed every earlier
    // site, and a content-invariant test pins that requiredSite precedes it.
    return _cashGoal(
      kind: MiningGoalKind.unlockSite,
      title: 'Unlock ${site.name}',
      cost: site.unlockCost,
      defaultDetail: 'Unlock it on its site card.',
      readyDetail: 'Ready: unlock it on its site card.',
      target: const MiningGoalTarget.none(),
    );
  }

  MiningNextGoalView nextPlanet(MiningPlanetId planetId) {
    final planet = content.planet(planetId);
    if (state.technology.surveying < planet.unlockRequiredSurveyingLevel) {
      return _surveying(neededFor: planet.name);
    }
    return _cashGoal(
      kind: MiningGoalKind.unlockPlanet,
      title: 'Unlock ${planet.name}',
      cost: planet.unlockCashCost,
      defaultDetail: 'Unlock it from the Stellar Map.',
      readyDetail: 'Ready on the Stellar Map.',
      target: const MiningGoalTarget.stellarMap(),
    );
  }

  MiningNextGoalView complete() => _plain(
    kind: MiningGoalKind.relaunch,
    title: 'Relaunch',
    // formatSaleMultiplier includes the × sign.
    detail:
        'Start again with sales ${formatSaleMultiplier(state.relaunchCount + 1)}.',
    target: const MiningGoalTarget.stellarMap(),
  );

  MiningNextGoalView _commission(MiningSiteDefinition site) {
    final planetId = content.planetForSite(site.id);
    final planet = content.planet(planetId);
    final title = 'Commission ${site.name}';
    final target = MiningGoalTarget.mineSite(site.id);
    final dockEmpty = state.docks[planetId]!.values.every(
      (tier) => tier == null,
    );
    if (dockEmpty) {
      final spawnDetail =
          'Spawn a rig for ${formatMiningCash(planet.rigSpawnCost)} cash, '
          'then deploy it.';
      return _cashGoal(
        kind: MiningGoalKind.commissionSite,
        title: title,
        cost: planet.rigSpawnCost,
        defaultDetail: spawnDetail,
        readyDetail: spawnDetail,
        target: target,
      );
    }
    final remaining = planet.sites
        .where((candidate) => !commissioned.contains(candidate.id))
        .length;
    return _plain(
      kind: MiningGoalKind.commissionSite,
      title: title,
      detail: remaining == 1 && planet.masteryRewardCash > 0
          ? 'Last ${planet.name} site: mastery pays '
                '+${formatMiningCash(planet.masteryRewardCash)} cash.'
          : 'Deploy a rig beside a resource.',
      target: target,
    );
  }

  MiningNextGoalView _surveying({required String neededFor}) {
    final level = state.technology.surveying;
    final gate = MiningContentRegistry.technologySiteGates[level];
    // Unreachable with authored content (every gate precedes what it
    // unlocks); kept so an inconsistent state still names a valid step.
    if (!commissioned.contains(gate)) return _commission(content.site(gate));
    return _cashGoal(
      kind: MiningGoalKind.researchSurveying,
      title: 'Research Surveying ${level + 1}',
      cost: MiningContentRegistry.technologyCosts[level],
      defaultDetail: 'Needed for $neededFor.',
      readyDetail: 'Ready in Technology.',
      target: const MiningGoalTarget.technology(),
    );
  }

  MiningNextGoalView _cashGoal({
    required MiningGoalKind kind,
    required String title,
    required int cost,
    required String defaultDetail,
    required String readyDetail,
    required MiningGoalTarget target,
  }) {
    final ready = state.cash >= cost;
    final sellWouldAfford = !ready && state.cash + sellableValue >= cost;
    return MiningNextGoalView(
      kind: kind,
      title: title,
      detail: ready
          ? readyDetail
          : sellWouldAfford
          ? 'Sell cargo to afford it.'
          : defaultDetail,
      target: target,
      cash: state.cash,
      cashCost: cost,
      sellWouldAfford: sellWouldAfford,
    );
  }

  MiningNextGoalView _plain({
    required MiningGoalKind kind,
    required String title,
    required String detail,
    required MiningGoalTarget target,
  }) => MiningNextGoalView(
    kind: kind,
    title: title,
    detail: detail,
    target: target,
    cash: state.cash,
  );
}
