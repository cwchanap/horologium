import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/site_deck_view.dart';

class MineSiteDepositView {
  const MineSiteDepositView({
    required this.definition,
    required this.minerCount,
    required this.isSurveyed,
  });
  final MiningDepositDefinition definition;
  final int minerCount;
  final bool isSurveyed;
}

class MineSiteRigView {
  const MineSiteRigView({
    required this.placement,
    required this.target,
    required this.canRecall,
    required this.disabledReason,
  });
  final MiningRigPlacement placement;
  final MiningDepositDefinition target;
  final bool canRecall;
  final String? disabledReason;
}

enum MineSiteGridTapAction { deploy, recall, blocked }

class MineSiteGridTapOutcome {
  const MineSiteGridTapOutcome.deploy()
    : action = MineSiteGridTapAction.deploy,
      message = null;
  const MineSiteGridTapOutcome.recall()
    : action = MineSiteGridTapAction.recall,
      message = null;
  const MineSiteGridTapOutcome.blocked(this.message)
    : action = MineSiteGridTapAction.blocked;

  final MineSiteGridTapAction action;
  final String? message;
}

class MineSiteView {
  MineSiteView({
    required this.siteId,
    required this.planetId,
    required this.definition,
    required this.isUnlocked,
    required this.surveyingLevel,
    required this.deposits,
    required this.rigs,
    required this.deployedRigs,
    required this.rate,
    required this.capacity,
    required this.cargo,
    required this.projectedSale,
    required this.activePlanetCargo,
    required this.activePlanetProjectedSale,
    required this.canSell,
    required this.isActivePlanet,
    required this.selectedBayId,
    required this.selectedRig,
    required this.isBusy,
    required Set<MiningGridCell> deployableCells,
  }) : deployableCells = Set.unmodifiable(deployableCells);

  final MiningSiteId siteId;
  final MiningPlanetId planetId;
  final MiningSiteDefinition definition;
  final bool isUnlocked;
  final int surveyingLevel;
  final List<MineSiteDepositView> deposits;
  final List<MineSiteRigView> rigs;
  final Set<MiningGridCell> deployableCells;
  final List<RigTier> deployedRigs;
  final double rate;
  final double capacity;
  final double cargo;
  final int projectedSale;
  final double activePlanetCargo;
  final int activePlanetProjectedSale;
  final bool canSell;
  final bool isActivePlanet;
  final DockBayId? selectedBayId;
  final RigTier? selectedRig;
  final bool isBusy;

  String get name => definition.name;

  MineSiteRigView? rigAt(MiningGridCell cell) {
    for (final rig in rigs) {
      if (rig.placement.cell == cell) return rig;
    }
    return null;
  }

  MiningPlacementResult placementAt(MiningGridCell cell) =>
      evaluateMiningPlacement(
        gridWidth: definition.gridWidth,
        gridHeight: definition.gridHeight,
        deposits: definition.deposits,
        occupiedRigCells: rigs.map((rig) => rig.placement.cell),
        candidate: cell,
        surveyingLevel: surveyingLevel,
        maxRigCount: MiningContentRegistry.maxDeployedRigsPerSite,
      );

  MineSiteGridTapOutcome gridTapOutcome(MiningGridCell cell) {
    if (isBusy) {
      return const MineSiteGridTapOutcome.blocked('Finishing previous action…');
    }
    if (!isUnlocked) {
      return const MineSiteGridTapOutcome.blocked('Unlock this site first.');
    }

    final containing = definition.deposits
        .where((deposit) => deposit.contains(cell))
        .toList(growable: false);
    if (containing.length == 1 &&
        surveyingLevel < containing.single.requiredSurveyingLevel) {
      return MineSiteGridTapOutcome.blocked(
        'Requires Surveying ${containing.single.requiredSurveyingLevel}.',
      );
    }

    if (!isActivePlanet) {
      return const MineSiteGridTapOutcome.blocked(
        'Travel to this planet first.',
      );
    }

    final rig = rigAt(cell);
    if (rig != null) {
      if (rig.canRecall) return const MineSiteGridTapOutcome.recall();
      return MineSiteGridTapOutcome.blocked(
        rig.disabledReason ?? 'Finishing previous action…',
      );
    }

    if (selectedRig == null) {
      return const MineSiteGridTapOutcome.blocked(
        'Select a rig from the dock.',
      );
    }

    final placement = placementAt(cell);
    if (placement.isAllowed) return const MineSiteGridTapOutcome.deploy();

    return switch (placement.rejection!) {
      MiningPlacementRejection.siteAtCapacity =>
        const MineSiteGridTapOutcome.blocked(
          'This site already has its maximum rigs.',
        ),
      MiningPlacementRejection.outsideGrid =>
        const MineSiteGridTapOutcome.blocked('Choose a valid grid cell.'),
      MiningPlacementRejection.depositCell =>
        const MineSiteGridTapOutcome.blocked('Resources occupy this cell.'),
      MiningPlacementRejection.rigOccupied =>
        const MineSiteGridTapOutcome.blocked('Grid cell is already occupied.'),
      MiningPlacementRejection.noAdjacentDeposit =>
        const MineSiteGridTapOutcome.blocked(
          'Place the rig next to a resource.',
        ),
      MiningPlacementRejection.surveyingLocked =>
        MineSiteGridTapOutcome.blocked(
          'Requires Surveying ${placement.target!.requiredSurveyingLevel}.',
        ),
      MiningPlacementRejection.depositAtCapacity =>
        const MineSiteGridTapOutcome.blocked(
          'This resource already has its maximum miners.',
        ),
      MiningPlacementRejection.ambiguousAdjacentDeposit => throw StateError(
        'Authored mining grid has ambiguous adjacency.',
      ),
    };
  }

  /// Active-planet cargo is present but its floored aggregate sale value is
  /// 0 cash, so selling would clear cargo without awarding any cash.
  bool get hasUnsellableCargo =>
      !isBusy &&
      isActivePlanet &&
      activePlanetCargo > 0 &&
      activePlanetProjectedSale == 0;

  static MineSiteView from({
    required MiningSave state,
    required MiningContentRegistry content,
    required MiningSiteId siteId,
    required DockBayId? selectedBayId,
    required bool isBusy,
  }) {
    final definition = content.site(siteId);
    final planetId = content.planetForSite(siteId);
    final progress = state.sites[siteId]!;
    final active = planetId == state.activePlanetId;
    var activePlanetCargo = 0.0;
    var activePlanetGrossSale = 0.0;
    for (final activeDefinition in content.planet(state.activePlanetId).sites) {
      final activeProgress = state.sites[activeDefinition.id]!;
      activePlanetCargo += activeProgress.storedAmount;
      activePlanetGrossSale +=
          activeProgress.storedAmount * activeDefinition.saleValuePerUnit;
    }
    final dock = state.docks[state.activePlanetId]!;
    final selectedRig = selectedBayId == null ? null : dock[selectedBayId];
    final hasEmptyDockBay = DockBayId.values.any((id) => dock[id] == null);
    final surveyingLevel = state.technology.surveying;
    final metrics = SiteMetrics.of(
      content: content,
      site: definition,
      progress: progress,
      technology: state.technology,
    );

    final deposits = List<MineSiteDepositView>.unmodifiable([
      for (final deposit in definition.deposits)
        MineSiteDepositView(
          definition: deposit,
          minerCount: progress.rigPlacements
              .where(
                (placement) =>
                    uniqueAdjacentDeposit(
                      deposits: definition.deposits,
                      cell: placement.cell,
                    )?.id ==
                    deposit.id,
              )
              .length,
          isSurveyed: surveyingLevel >= deposit.requiredSurveyingLevel,
        ),
    ]);

    final rigViews = List<MineSiteRigView>.unmodifiable([
      for (final placement in progress.rigPlacements)
        () {
          final target = uniqueAdjacentDeposit(
            deposits: definition.deposits,
            cell: placement.cell,
          );
          if (target == null) {
            throw StateError(
              'Saved rig placement without a unique adjacent deposit.',
            );
          }
          final recallCapacity = content.effectiveSiteCapacity(
            siteId,
            progress.rigPlacements
                .where((other) => other.cell != placement.cell)
                .map((other) => other.tier),
            state.technology.logistics,
          );
          final cargoBlocked = progress.storedAmount > recallCapacity;
          final canRecall =
              !isBusy && active && hasEmptyDockBay && !cargoBlocked;
          final String? disabledReason = isBusy
              ? 'Finishing previous action…'
              : !active
              ? 'Travel to this planet first.'
              : cargoBlocked
              ? 'Sell cargo before recalling this rig.'
              : !hasEmptyDockBay
              ? 'Dock is full.'
              : null;
          return MineSiteRigView(
            placement: placement,
            target: target,
            canRecall: canRecall,
            disabledReason: disabledReason,
          );
        }(),
    ]);

    final canDeployAnywhere =
        !isBusy && progress.unlocked && active && selectedRig != null;
    final deployableCells = <MiningGridCell>{
      if (canDeployAnywhere)
        for (var x = 0; x < definition.gridWidth; x++)
          for (var y = 0; y < definition.gridHeight; y++)
            if (evaluateMiningPlacement(
              gridWidth: definition.gridWidth,
              gridHeight: definition.gridHeight,
              deposits: definition.deposits,
              occupiedRigCells: rigViews.map((rig) => rig.placement.cell),
              candidate: MiningGridCell(x, y),
              surveyingLevel: surveyingLevel,
              maxRigCount: MiningContentRegistry.maxDeployedRigsPerSite,
            ).isAllowed)
              MiningGridCell(x, y),
    };

    return MineSiteView(
      siteId: siteId,
      planetId: planetId,
      definition: definition,
      isUnlocked: progress.unlocked,
      surveyingLevel: surveyingLevel,
      deposits: deposits,
      rigs: rigViews,
      deployableCells: deployableCells,
      deployedRigs: List<RigTier>.unmodifiable(metrics.deployedRigs),
      rate: metrics.rate,
      capacity: metrics.capacity,
      cargo: progress.storedAmount,
      projectedSale: active
          ? (progress.storedAmount * definition.saleValuePerUnit).floor()
          : 0,
      activePlanetCargo: activePlanetCargo,
      activePlanetProjectedSale: activePlanetGrossSale.floor(),
      canSell: !isBusy && active && activePlanetGrossSale.floor() > 0,
      isActivePlanet: active,
      selectedBayId: selectedBayId,
      selectedRig: selectedRig,
      isBusy: isBusy,
    );
  }
}
