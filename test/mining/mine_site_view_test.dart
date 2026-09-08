import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';

SiteProgress progress({
  bool unlocked = true,
  bool commissioned = false,
  double storedAmount = 0,
  List<MiningRigPlacement> rigs = const [],
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigPlacements: rigs,
);

MiningSave stateWith({
  SiteProgress? landing,
  SiteProgress? carbon,
  SiteProgress? frozen,
}) {
  final initial = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26));
  return initial.copyWith(
    sites: {
      ...initial.sites,
      if (landing != null) MiningSiteId.landingBasin: landing,
      if (carbon != null) MiningSiteId.carbonRidge: carbon,
      if (frozen != null) MiningSiteId.frozenBasin: frozen,
    },
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();

  MineSiteView viewFor(
    MiningSave state, {
    MiningSiteId siteId = MiningSiteId.landingBasin,
    DockBayId? selectedBayId,
    bool isBusy = false,
  }) => MineSiteView.from(
    state: state,
    content: content,
    siteId: siteId,
    selectedBayId: selectedBayId,
    isBusy: isBusy,
  );

  test('projects grid deployable cells and blocked tap outcomes', () {
    final view = viewFor(
      stateWith(landing: progress()),
      selectedBayId: DockBayId.b1,
    );

    expect(view.isUnlocked, isTrue);
    expect(view.surveyingLevel, 0);
    expect(view.deployableCells, contains(const MiningGridCell(3, 2)));
    expect(view.deployableCells, contains(const MiningGridCell(16, 2)));
    expect(view.deployableCells, isNot(contains(const MiningGridCell(5, 10))));

    expect(
      view.gridTapOutcome(const MiningGridCell(5, 11)).message,
      'Requires Surveying 1.',
    );
    expect(
      view.gridTapOutcome(const MiningGridCell(10, 8)).message,
      'Place the rig next to a resource.',
    );
  });

  test('deployable cells stay empty without a selected rig', () {
    final view = viewFor(stateWith(landing: progress()));

    expect(view.deployableCells, isEmpty);
    expect(
      view.gridTapOutcome(const MiningGridCell(3, 2)).message,
      'Select a rig from the dock.',
    );
  });

  test('projects rig rate, capacity, cargo, and active-planet sale', () {
    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          storedAmount: 10,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
          ],
        ),
      ),
    );

    expect(view.rate, 0.5);
    expect(view.capacity, 90);
    expect(view.cargo, 10);
    expect(view.projectedSale, 40);
    expect(view.canSell, isTrue);
  });

  test('projects active-planet cargo and sale across two sites', () {
    final view = viewFor(
      stateWith(
        landing: progress(commissioned: true, storedAmount: 1.125),
        carbon: progress(unlocked: true, commissioned: true, storedAmount: 0.5),
      ),
    );

    expect(view.activePlanetCargo, 1.625);
    // Landing Basin is 4.5 cash and Carbon Ridge is 1.5 cash; flooring the
    // combined gross value gives 6, while flooring each site first gives 5.
    expect(view.activePlanetProjectedSale, 6);
    expect(view.canSell, isTrue);
  });

  test('keeps sub-1-cash cargo unsellable while cargo is present', () {
    // 0.1 Gold at Landing Basin (4 cash/unit) = 0.4 gross, which floors to 0.
    final view = viewFor(
      stateWith(landing: progress(commissioned: true, storedAmount: 0.1)),
    );

    expect(view.activePlanetCargo, 0.1);
    expect(view.activePlanetProjectedSale, 0);
    expect(view.canSell, isFalse);
    expect(view.hasUnsellableCargo, isTrue);
  });

  test('does not expose sale while the shell is busy', () {
    final view = viewFor(
      stateWith(landing: progress(commissioned: true, storedAmount: 10)),
      isBusy: true,
    );

    expect(view.canSell, isFalse);
  });

  test('busy tap is blocked with the pending-action copy', () {
    final view = viewFor(
      stateWith(landing: progress()),
      selectedBayId: DockBayId.b1,
      isBusy: true,
    );

    expect(view.deployableCells, isEmpty);
    expect(
      view.gridTapOutcome(const MiningGridCell(3, 2)).message,
      'Finishing previous action…',
    );
  });

  test('locked site blocks every tap with the unlock copy', () {
    final view = viewFor(
      stateWith(landing: progress(unlocked: false)),
      selectedBayId: DockBayId.b1,
    );

    expect(view.isUnlocked, isFalse);
    expect(
      view.gridTapOutcome(const MiningGridCell(3, 2)).message,
      'Unlock this site first.',
    );
  });

  test('inactive planet blocks free cells with the travel copy', () {
    final viewSurveyed = viewFor(
      stateWith(frozen: progress(unlocked: true, commissioned: true)).copyWith(
        technology: const TechnologyLevels(surveying: 3),
        unlockedPlanetIds: {
          MiningPlanetId.homeworld,
          MiningPlanetId.lunarFrontier,
        },
      ),
      siteId: MiningSiteId.frozenBasin,
      selectedBayId: DockBayId.b1,
    );

    expect(viewSurveyed.isActivePlanet, isFalse);
    expect(
      viewSurveyed.gridTapOutcome(const MiningGridCell(4, 2)).message,
      'Travel to this planet first.',
    );
  });

  test('surveyed deposit tap reports the surveying requirement first', () {
    final view = viewFor(
      stateWith(frozen: progress(unlocked: true, commissioned: true)).copyWith(
        unlockedPlanetIds: {
          MiningPlanetId.homeworld,
          MiningPlanetId.lunarFrontier,
        },
        activePlanetId: MiningPlanetId.lunarFrontier,
      ),
      siteId: MiningSiteId.frozenBasin,
      selectedBayId: DockBayId.b1,
    );

    // D4 on Frozen Basin requires Surveying 5; the cell inside the deposit
    // surfaces the requirement before any other outcome.
    expect(
      view.gridTapOutcome(const MiningGridCell(17, 11)).message,
      'Requires Surveying 5.',
    );
  });

  test(
    'recalls an occupied cell and blocks on cargo above post-recall capacity',
    () {
      final rigs = const [
        MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
        MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(16, 2)),
      ];
      final view = viewFor(
        stateWith(
          landing: progress(commissioned: true, storedAmount: 150, rigs: rigs),
        ),
      );

      final rig = view.rigAt(const MiningGridCell(3, 2))!;
      expect(rig.canRecall, isFalse);
      expect(rig.disabledReason, 'Sell cargo before recalling this rig.');
      expect(
        view.gridTapOutcome(const MiningGridCell(3, 2)).message,
        'Sell cargo before recalling this rig.',
      );

      final soldView = viewFor(
        stateWith(
          landing: progress(commissioned: true, storedAmount: 0, rigs: rigs),
        ),
      );

      expect(
        soldView.gridTapOutcome(const MiningGridCell(3, 2)).action,
        MineSiteGridTapAction.recall,
      );
    },
  );

  test('blocks recall while the dock has no empty bay', () {
    final initial = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26));
    final state = initial.copyWith(
      docks: {
        ...initial.docks,
        MiningPlanetId.homeworld: const {
          DockBayId.b1: RigTier.t1,
          DockBayId.b2: RigTier.t2,
          DockBayId.b3: RigTier.t3,
          DockBayId.b4: RigTier.t4,
        },
      },
      sites: {
        ...initial.sites,
        MiningSiteId.landingBasin: progress(
          commissioned: true,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
          ],
        ),
      },
    );
    final view = viewFor(state);

    expect(
      view.gridTapOutcome(const MiningGridCell(3, 2)).message,
      'Dock is full.',
    );
  });

  test('rig semantics resolve their target deposit and miner counts', () {
    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t2, cell: MiningGridCell(3, 2)),
          ],
        ),
      ),
    );

    expect(view.rigs.single.target.id, MiningDepositId.d1);
    expect(
      view.deposits
          .singleWhere((d) => d.definition.id == MiningDepositId.d1)
          .minerCount,
      1,
    );
    expect(
      view.deposits
          .singleWhere((d) => d.definition.id == MiningDepositId.d2)
          .minerCount,
      0,
    );
  });

  test('occupied and deposit cells block deployment with grid copy', () {
    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          rigs: const [
            MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
          ],
        ),
      ),
      selectedBayId: DockBayId.b1,
    );

    expect(
      view.gridTapOutcome(const MiningGridCell(3, 3)).message,
      'Resources occupy this cell.',
    );
  });
}
