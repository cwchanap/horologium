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
    required this.isBusy,
  });

  final Map<DockBayId, FleetDockBayView> bays;
  final DockBayId? selectedBayId;
  final int spawnCost;
  final bool canSpawn;
  final String? spawnDisabledReason;
  final String spawnHint;
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
    final hasEmptyBay = DockBayId.values.any((id) => dock[id] == null);
    final spawnDisabledReason = isBusy
        ? 'Finishing previous action…'
        : !hasEmptyBay
        ? 'Dock is full.'
        : state.cash < spawnCost
        ? 'Need $spawnCost cash.'
        : null;

    final bays = <DockBayId, FleetDockBayView>{};
    for (final id in DockBayId.values) {
      final rig = dock[id];
      final isSelected = selectedBayId == id;
      final selectedRig = selectedBayId == null ? null : dock[selectedBayId];
      final canMergeWithSelection =
          !isBusy &&
          !isSelected &&
          rig != null &&
          selectedRig != null &&
          rig == selectedRig &&
          rig != RigTier.t5;
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
          ? 'Spawn a T1 rig for $spawnCost cash.'
          : spawnDisabledReason,
      isBusy: isBusy,
    );
  }
}
