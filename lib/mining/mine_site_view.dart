import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

enum MineSiteNodeState { locked, available, deployable, occupied }

class MineSiteNodeView {
  const MineSiteNodeView({
    required this.id,
    required this.state,
    required this.rig,
    required this.requiredSurveyingLevel,
    required this.canDeploy,
    required this.canRecall,
    required this.disabledReason,
    required this.isBusy,
  });

  final MiningNodeId id;
  final MineSiteNodeState state;
  final RigTier? rig;
  final int requiredSurveyingLevel;
  final bool canDeploy;
  final bool canRecall;
  final String? disabledReason;
  final bool isBusy;

  RigTier? get rigTier => rig;
  bool get isLocked => state == MineSiteNodeState.locked;
  bool get isAvailable => state == MineSiteNodeState.available;
  bool get isDeployable => state == MineSiteNodeState.deployable;
  bool get isOccupied => state == MineSiteNodeState.occupied;
  String? get hint => disabledReason;
}

class MineSiteView {
  const MineSiteView({
    required this.siteId,
    required this.planetId,
    required this.definition,
    required this.nodes,
    required this.nodeList,
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
  });

  final MiningSiteId siteId;
  final MiningPlanetId planetId;
  final MiningSiteDefinition definition;
  final Map<MiningNodeId, MineSiteNodeView> nodes;
  final List<MineSiteNodeView> nodeList;
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
  String get cavernAsset => definition.cavernAsset;
  String get nodeAsset => definition.nodeAsset;
  double get storedAmount => cargo;
  int get projectedValue => projectedSale;
  double get siteRate => rate;
  double get siteCapacity => capacity;
  bool get hasCargo => cargo > 0;

  MineSiteNodeView node(MiningNodeId id) => nodes[id]!;

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
    final deployedRigs = progress.rigByNode.values
        .whereType<RigTier>()
        .toList();
    final hasRigs = deployedRigs.isNotEmpty;
    final capacity = hasRigs
        ? content.effectiveSiteCapacity(
            siteId,
            deployedRigs,
            state.technology.logistics,
          )
        : 0.0;
    final rate = hasRigs
        ? content.effectiveSiteRate(
            siteId,
            deployedRigs,
            state.technology.extraction,
          )
        : 0.0;
    final nodeViews = <MiningNodeId, MineSiteNodeView>{};
    for (final nodeDefinition in definition.nodes) {
      final rig = progress.rigByNode[nodeDefinition.id];
      final stateForNode = rig != null
          ? MineSiteNodeState.occupied
          : !progress.unlocked ||
                state.technology.surveying <
                    nodeDefinition.requiredSurveyingLevel
          ? MineSiteNodeState.locked
          : selectedRig != null && active
          ? MineSiteNodeState.deployable
          : MineSiteNodeState.available;
      final recallCapacity = rig == null
          ? null
          : content.effectiveSiteCapacity(
              siteId,
              progress.rigByNode.entries
                  .where((entry) => entry.key != nodeDefinition.id)
                  .map((entry) => entry.value)
                  .whereType<RigTier>(),
              state.technology.logistics,
            );
      final disabledReason = isBusy
          ? 'Finishing previous action…'
          : stateForNode == MineSiteNodeState.locked
          ? !progress.unlocked
                ? 'Unlock this site first.'
                : 'Requires Surveying ${nodeDefinition.requiredSurveyingLevel}.'
          : stateForNode == MineSiteNodeState.available
          ? !active
                ? 'Travel to this planet first.'
                : 'Select a rig from the dock.'
          : stateForNode == MineSiteNodeState.occupied &&
                recallCapacity != null &&
                progress.storedAmount > recallCapacity
          ? 'Sell cargo before recalling this rig.'
          : stateForNode == MineSiteNodeState.occupied && !hasEmptyDockBay
          ? 'Dock is full.'
          : null;
      final canDeploy =
          !isBusy && stateForNode == MineSiteNodeState.deployable && active;
      final canRecall =
          !isBusy &&
          stateForNode == MineSiteNodeState.occupied &&
          active &&
          hasEmptyDockBay &&
          (recallCapacity == null || progress.storedAmount <= recallCapacity);
      nodeViews[nodeDefinition.id] = MineSiteNodeView(
        id: nodeDefinition.id,
        state: stateForNode,
        rig: rig,
        requiredSurveyingLevel: nodeDefinition.requiredSurveyingLevel,
        canDeploy: canDeploy,
        canRecall: canRecall,
        disabledReason: disabledReason,
        isBusy: isBusy,
      );
    }

    return MineSiteView(
      siteId: siteId,
      planetId: planetId,
      definition: definition,
      nodes: Map<MiningNodeId, MineSiteNodeView>.unmodifiable(nodeViews),
      nodeList: List<MineSiteNodeView>.unmodifiable(nodeViews.values),
      deployedRigs: List<RigTier>.unmodifiable(deployedRigs),
      rate: rate,
      capacity: capacity,
      cargo: progress.storedAmount,
      projectedSale: active
          ? (progress.storedAmount * definition.saleValuePerUnit).floor()
          : 0,
      activePlanetCargo: activePlanetCargo,
      activePlanetProjectedSale: activePlanetGrossSale.floor(),
      canSell: active && activePlanetCargo > 0,
      isActivePlanet: active,
      selectedBayId: selectedBayId,
      selectedRig: selectedRig,
      isBusy: isBusy,
    );
  }
}
