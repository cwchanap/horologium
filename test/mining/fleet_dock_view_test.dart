import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

MiningSave stateWith({int? cash, Map<DockBayId, RigTier?>? bays}) {
  final initial = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26));
  return initial.copyWith(
    cash: cash,
    docks: {
      ...initial.docks,
      MiningPlanetId.homeworld: {
        ...initial.docks[MiningPlanetId.homeworld]!,
        ...?bays,
      },
    },
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();

  test('projects every closed dock bay and the selected merge target', () {
    final view = FleetDockView.from(
      state: MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26)),
      content: content,
      selectedBayId: DockBayId.b1,
      isBusy: false,
    );

    expect(view.bays.keys, DockBayId.values);
    expect(view.bays[DockBayId.b1]!.isSelected, isTrue);
    expect(view.bays[DockBayId.b2]!.canMergeWithSelection, isTrue);
    expect(view.bays[DockBayId.b3]!.rig, isNull);
    expect(view.spawnCost, 25);
    expect(view.canSpawn, isTrue);
    expect(view.spawnDisabledReason, isNull);
    expect(
      () => view.bays[DockBayId.b1] = view.bays[DockBayId.b1]!,
      throwsUnsupportedError,
    );
  });

  test('reports full, poor, and busy spawn reasons', () {
    final full = FleetDockView.from(
      state: stateWith(
        bays: {for (final bay in DockBayId.values) bay: RigTier.t1},
      ),
      content: content,
      selectedBayId: null,
      isBusy: false,
    );
    expect(full.canSpawn, isFalse);
    expect(full.spawnDisabledReason, 'Dock is full.');

    final poor = FleetDockView.from(
      state: stateWith(cash: 24, bays: {DockBayId.b3: null}),
      content: content,
      selectedBayId: null,
      isBusy: false,
    );
    expect(poor.canSpawn, isFalse);
    expect(poor.spawnDisabledReason, 'Need 25 cash.');

    final busy = FleetDockView.from(
      state: stateWith(),
      content: content,
      selectedBayId: DockBayId.b1,
      isBusy: true,
    );
    expect(busy.canSpawn, isFalse);
    expect(busy.spawnDisabledReason, 'Finishing previous action…');
    expect(busy.bays[DockBayId.b2]!.canMergeWithSelection, isFalse);
  });

  test('provides contextual bay hints for empty, selected, and merge bays', () {
    final view = FleetDockView.from(
      state: MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26)),
      content: content,
      selectedBayId: DockBayId.b1,
      isBusy: false,
    );

    expect(view.bays[DockBayId.b1]!.hint, contains('Selected'));
    expect(view.bays[DockBayId.b2]!.hint, 'Merge with selected bay.');
    expect(view.bays[DockBayId.b3]!.hint, contains('Empty'));
  });

  test('resolves dockHint for every dock instruction state', () {
    FleetDockView viewFor({
      Map<DockBayId, RigTier?>? bays,
      DockBayId? selectedBayId,
    }) => FleetDockView.from(
      state: stateWith(bays: bays),
      content: content,
      selectedBayId: selectedBayId,
      isBusy: false,
    );

    expect(viewFor().dockHint, 'TAP A RIG, THEN A NODE');

    // The initial homeworld dock holds T1 rigs in b1 and b2.
    expect(
      viewFor(selectedBayId: DockBayId.b1).dockHint,
      'T1 + T1 = T2 • STRONGER PER SLOT',
    );
    expect(
      viewFor(
        bays: {DockBayId.b1: RigTier.t4},
        selectedBayId: DockBayId.b1,
      ).dockHint,
      'T4 + T4 = T5 • STRONGER PER SLOT',
    );
    expect(
      viewFor(
        bays: {DockBayId.b1: RigTier.t5},
        selectedBayId: DockBayId.b1,
      ).dockHint,
      'TAP A NODE TO DEPLOY',
    );
  });

  test('busy state keeps the merge flag off without a merge hint', () {
    final busy = FleetDockView.from(
      state: stateWith(),
      content: content,
      selectedBayId: DockBayId.b1,
      isBusy: true,
    );

    expect(busy.bays[DockBayId.b2]!.canMergeWithSelection, isFalse);
    expect(busy.bays[DockBayId.b2]!.hint, isNot(contains('Merge')));
  });
}
