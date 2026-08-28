import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

SiteProgress progress({
  bool unlocked = true,
  bool commissioned = false,
  double storedAmount = 0,
  Map<MiningNodeId, RigTier?>? rigs,
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigByNode: rigs ?? {for (final node in MiningNodeId.values) node: null},
);

MiningSave stateWith({SiteProgress? landing, SiteProgress? carbon}) {
  final initial = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26));
  return initial.copyWith(
    sites: {
      ...initial.sites,
      if (landing != null) MiningSiteId.landingBasin: landing,
      if (carbon != null) MiningSiteId.carbonRidge: carbon,
    },
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();

  test('projects four node availability states from state and selection', () {
    final available = MineSiteView.from(
      state: stateWith(),
      content: content,
      siteId: MiningSiteId.landingBasin,
      selectedBayId: null,
      isBusy: false,
    );
    expect(
      available.nodes[MiningNodeId.n1]!.state,
      MineSiteNodeState.available,
    );
    expect(
      available.nodes[MiningNodeId.n2]!.state,
      MineSiteNodeState.available,
    );
    expect(available.nodes[MiningNodeId.n3]!.state, MineSiteNodeState.locked);
    expect(available.nodes[MiningNodeId.n4]!.state, MineSiteNodeState.locked);

    final deployable = MineSiteView.from(
      state: stateWith(),
      content: content,
      siteId: MiningSiteId.landingBasin,
      selectedBayId: DockBayId.b1,
      isBusy: false,
    );
    expect(
      deployable.nodes[MiningNodeId.n1]!.state,
      MineSiteNodeState.deployable,
    );
    expect(deployable.nodes[MiningNodeId.n1]!.canDeploy, isTrue);

    final occupied = MineSiteView.from(
      state: stateWith(
        landing: progress(
          commissioned: true,
          rigs: {MiningNodeId.n1: RigTier.t1},
        ),
      ),
      content: content,
      siteId: MiningSiteId.landingBasin,
      selectedBayId: DockBayId.b2,
      isBusy: false,
    );
    expect(occupied.nodes[MiningNodeId.n1]!.state, MineSiteNodeState.occupied);
    expect(occupied.nodes[MiningNodeId.n1]!.canRecall, isTrue);
  });

  test('projects rig rate, capacity, cargo, and active-planet sale', () {
    final view = MineSiteView.from(
      state: stateWith(
        landing: progress(
          commissioned: true,
          storedAmount: 10,
          rigs: {MiningNodeId.n1: RigTier.t1},
        ),
      ),
      content: content,
      siteId: MiningSiteId.landingBasin,
      selectedBayId: null,
      isBusy: false,
    );

    expect(view.rate, 0.5);
    expect(view.capacity, 90);
    expect(view.cargo, 10);
    expect(view.projectedSale, 40);
    expect(view.canSell, isTrue);
  });

  test('projects active-planet cargo and sale across two sites', () {
    final view = MineSiteView.from(
      state: stateWith(
        landing: progress(commissioned: true, storedAmount: 1.125),
        carbon: progress(commissioned: true, storedAmount: 0.5),
      ),
      content: content,
      siteId: MiningSiteId.landingBasin,
      selectedBayId: null,
      isBusy: false,
    );

    expect(view.activePlanetCargo, 1.625);
    // Landing Basin is 4.5 cash and Carbon Ridge is 1.5 cash; flooring the
    // combined gross value gives 6, while flooring each site first gives 5.
    expect(view.activePlanetProjectedSale, 6);
    expect(view.canSell, isTrue);
  });

  test('does not expose sale while the shell is busy', () {
    final view = MineSiteView.from(
      state: stateWith(landing: progress(commissioned: true, storedAmount: 10)),
      content: content,
      siteId: MiningSiteId.landingBasin,
      selectedBayId: null,
      isBusy: true,
    );

    expect(view.canSell, isFalse);
  });

  test('disables recall when cargo exceeds post-recall capacity', () {
    final view = MineSiteView.from(
      state: stateWith(
        landing: progress(
          commissioned: true,
          storedAmount: 150,
          rigs: {MiningNodeId.n1: RigTier.t1, MiningNodeId.n2: RigTier.t1},
        ),
      ),
      content: content,
      siteId: MiningSiteId.landingBasin,
      selectedBayId: null,
      isBusy: false,
    );

    final node = view.nodes[MiningNodeId.n1]!;
    expect(node.canRecall, isFalse);
    expect(node.disabledReason, 'Sell cargo before recalling this rig.');
  });
}
