import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

class FleetDockBayView {
  const FleetDockBayView({
    required this.id,
    required this.rig,
    required this.isSelected,
    required this.canMergeWithSelection,
    required this.hint,
    required this.isBusy,
  });

  final DockBayId id;
  final RigTier? rig;
  final bool isSelected;
  final bool canMergeWithSelection;
  final String hint;
  final bool isBusy;

  RigTier? get tier => rig;
  RigTier? get rigTier => rig;
  bool get isEmpty => rig == null;
  String get contextualHint => hint;
}

class FleetDockView {
  const FleetDockView({
    required this.bays,
    required this.selectedBayId,
    required this.spawnCost,
    required this.canSpawn,
    required this.spawnDisabledReason,
    required this.spawnHint,
    required this.bestAffordableTier,
    required this.buildCost,
    required this.canBuild,
    required this.buildHint,
    required this.dockHint,
    required this.isBusy,
  });

  final Map<DockBayId, FleetDockBayView> bays;
  final DockBayId? selectedBayId;
  final int spawnCost;
  final bool canSpawn;
  final String? spawnDisabledReason;
  final String spawnHint;
  final RigTier? bestAffordableTier;
  final int buildCost;
  final bool canBuild;
  final String? buildHint;

  /// Resolved instruction copy for the dock hint row.
  final String dockHint;

  final bool isBusy;

  FleetDockBayView bay(DockBayId id) => bays[id]!;

  bool get spawnEnabled => canSpawn;
  String? get spawnReason => spawnDisabledReason;
  String? get disabledReason => spawnDisabledReason;

  static FleetDockView from({
    required MiningSave state,
    required MiningContentRegistry content,
    required DockBayId? selectedBayId,
    required bool isBusy,
  }) {
    final dock = state.docks[state.activePlanetId]!;
    final spawnCost = content.planet(state.activePlanetId).rigSpawnCost;
    final selectedRig = selectedBayId == null ? null : dock[selectedBayId];
    final String dockHint;
    if (selectedRig == null) {
      dockHint = 'TAP A RIG, THEN A HIGHLIGHTED CELL';
    } else if (selectedRig == RigTier.t5) {
      dockHint = 'TAP A HIGHLIGHTED CELL';
    } else {
      dockHint = 'DEPLOY · UPGRADE · MERGE';
    }
    final hasEmptyBay = DockBayId.values.any((id) => dock[id] == null);
    final spawnDisabledReason = isBusy
        ? 'Finishing previous action…'
        : !hasEmptyBay
        ? 'Dock is full.'
        : state.cash < spawnCost
        ? 'Need ${formatMiningCash(spawnCost)} cash.'
        : null;

    RigTier? bestAffordableTier;
    if (hasEmptyBay) {
      for (final tier in RigTier.values.skip(1)) {
        if (state.cash >= content.rigCost(state.activePlanetId, tier)) {
          bestAffordableTier = tier;
        }
      }
    }
    final canBuild = !isBusy && bestAffordableTier != null;
    final buildCost = bestAffordableTier == null
        ? 0
        : content.rigCost(state.activePlanetId, bestAffordableTier);

    final bays = <DockBayId, FleetDockBayView>{};
    for (final id in DockBayId.values) {
      final rig = dock[id];
      final isSelected = selectedBayId == id;
      final canMergeWithSelection =
          !isBusy &&
          !isSelected &&
          rig != null &&
          selectedRig != null &&
          rigMergeFailure(selectedRig, rig) == null;
      final tierName = rig?.name.toUpperCase();
      final hint = isBusy
          ? 'Finishing previous action…'
          : rig == null
          ? 'Empty bay.'
          : isSelected
          ? 'Selected $tierName rig.'
          : canMergeWithSelection
          ? 'Merge with selected bay.'
          : '$tierName rig.';
      bays[id] = FleetDockBayView(
        id: id,
        rig: rig,
        isSelected: isSelected,
        canMergeWithSelection: canMergeWithSelection,
        hint: hint,
        isBusy: isBusy,
      );
    }

    final canSpawn = spawnDisabledReason == null;
    return FleetDockView(
      bays: Map<DockBayId, FleetDockBayView>.unmodifiable(bays),
      selectedBayId: selectedBayId,
      spawnCost: spawnCost,
      canSpawn: canSpawn,
      spawnDisabledReason: spawnDisabledReason,
      spawnHint: canSpawn
          ? 'Spawn a T1 rig for ${formatMiningCash(spawnCost)} cash.'
          : spawnDisabledReason,
      bestAffordableTier: bestAffordableTier,
      buildCost: buildCost,
      canBuild: canBuild,
      buildHint: bestAffordableTier == null
          ? null
          : canBuild
          ? 'Build a ${bestAffordableTier.name.toUpperCase()} rig for '
                '${formatMiningCash(buildCost)} cash.'
          : 'Finishing previous action…',
      dockHint: dockHint,
      isBusy: isBusy,
    );
  }
}
