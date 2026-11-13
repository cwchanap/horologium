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

    expect(viewFor().dockHint, 'TAP A RIG, THEN A HIGHLIGHTED CELL');

    // The initial homeworld dock holds T1 rigs in b1 and b2.
    for (final tier in const [RigTier.t1, RigTier.t2, RigTier.t3, RigTier.t4]) {
      final hint = viewFor(
        bays: {DockBayId.b1: tier},
        selectedBayId: DockBayId.b1,
      ).dockHint;
      expect(hint, 'DEPLOY · UPGRADE · MERGE', reason: tier.name);
      for (final action in const ['DEPLOY', 'UPGRADE', 'MERGE']) {
        expect(hint, contains(action), reason: '${tier.name} $action');
      }
    }
    final t5Hint = viewFor(
      bays: {DockBayId.b1: RigTier.t5},
      selectedBayId: DockBayId.b1,
    ).dockHint;
    expect(t5Hint, 'TAP A HIGHLIGHTED CELL');
    // T5 is the ceiling: the deploy-only hint must not offer impossible actions.
    expect(t5Hint, isNot(contains('UPGRADE')));
    expect(t5Hint, isNot(contains('MERGE')));

    for (final view in [
      viewFor(),
      viewFor(selectedBayId: DockBayId.b1),
      viewFor(bays: {DockBayId.b1: RigTier.t5}, selectedBayId: DockBayId.b1),
    ]) {
      expect(view.dockHint, isNot(contains('NODE')));
    }
  });

  test('highlights merge targets through the shared merge rule', () {
    final view = FleetDockView.from(
      state: stateWith(
        bays: {
          DockBayId.b1: RigTier.t5,
          DockBayId.b2: RigTier.t5,
          DockBayId.b3: RigTier.t3,
        },
      ),
      content: content,
      selectedBayId: DockBayId.b1,
      isBusy: false,
    );

    expect(view.bays[DockBayId.b2]!.canMergeWithSelection, isFalse);
    expect(view.bays[DockBayId.b3]!.canMergeWithSelection, isFalse);
  });

  test('derives the best affordable build tier from cash and a free bay', () {
    FleetDockView viewFor({
      int? cash,
      Map<DockBayId, RigTier?>? bays,
      bool isBusy = false,
    }) => FleetDockView.from(
      state: stateWith(cash: cash, bays: bays),
      content: content,
      selectedBayId: null,
      isBusy: isBusy,
    );

    expect(viewFor(cash: 49).bestAffordableTier, isNull);
    expect(viewFor(cash: 50).bestAffordableTier, RigTier.t2);
    expect(viewFor(cash: 199).bestAffordableTier, RigTier.t3);
    expect(viewFor(cash: 1000).bestAffordableTier, RigTier.t5);

    final build = viewFor(cash: 200);
    expect(build.bestAffordableTier, RigTier.t4);
    expect(build.buildCost, 200);
    expect(build.canBuild, isTrue);
    expect(build.buildHint, 'Build a T4 rig for 200 cash.');

    final full = viewFor(
      cash: 1000,
      bays: {for (final bay in DockBayId.values) bay: RigTier.t1},
    );
    expect(full.bestAffordableTier, isNull);
    expect(full.canBuild, isFalse);

    final busy = viewFor(cash: 1000, isBusy: true);
    expect(busy.bestAffordableTier, RigTier.t5);
    expect(busy.canBuild, isFalse);
    expect(busy.buildHint, 'Finishing previous action…');
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
