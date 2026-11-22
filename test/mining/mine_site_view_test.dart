import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';

import '../support/mining_grid_fixtures.dart';

final _landingSite = MiningContentRegistry.stellarMining().site(
  MiningSiteId.landingBasin,
);
final _frozenSite = MiningContentRegistry.stellarMining().site(
  MiningSiteId.frozenBasin,
);

/// A legal Landing Basin deploy cell at Surveying 0.
final _landingRigCell = firstPlayableCell(_landingSite);

/// A legal Frozen Basin deploy cell at Surveying 3.
final _frozenRigCell = firstPlayableCell(_frozenSite);

/// The resource mined from [_landingRigCell]: the surveyed target whose
/// deposit origin blocks deployment.
final _landingRigTarget = uniqueAdjacentDeposit(
  deposits: _landingSite.deposits,
  cell: _landingRigCell,
)!;

/// The authored deposit gated at [level] with unique perimeter slots.
MiningDepositDefinition _depositAt(MiningSiteDefinition site, int level) =>
    site.deposits.firstWhere(
      (deposit) =>
          deposit.requiredSurveyingLevel == level &&
          site.perimeterCellsByDeposit[deposit]!.isNotEmpty,
    );

/// First row-major cell that touches no authored resource.
final _landingClearCell = () {
  for (var y = 0; y < _landingSite.gridHeight; y++) {
    for (var x = 0; x < _landingSite.gridWidth; x++) {
      final cell = MiningGridCell(x, y);
      if (_landingSite.deposits.every(
        (deposit) =>
            !deposit.contains(cell) && !deposit.isOrthogonallyAdjacent(cell),
      )) {
        return cell;
      }
    }
  }
  throw StateError('Landing Basin has no cell clear of resources.');
}();

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
    final site = content.site(MiningSiteId.landingBasin);
    final view = viewFor(
      stateWith(landing: progress()),
      selectedBayId: DockBayId.b1,
    );

    expect(view.isUnlocked, isTrue);
    expect(view.surveyingLevel, 0);
    expect(view.deployableCells, deployableMiningCells(site).toSet());

    // Inside the Surveying-2 resource.
    final lockedDeposit = _depositAt(site, 2);
    expect(
      view
          .gridTapOutcome(MiningGridCell(lockedDeposit.x, lockedDeposit.y))
          .message,
      'Requires Surveying 2.',
    );
    // Adjacent to the Surveying-1 resource.
    final lockedCell = site.perimeterCellsByDeposit[_depositAt(site, 1)]!.first;
    expect(view.gridTapOutcome(lockedCell).message, 'Requires Surveying 1.');
    expect(
      view.gridTapOutcome(_landingClearCell).message,
      'Place the rig next to a resource.',
    );
  });

  test('deployable cells stay empty without a selected rig', () {
    final view = viewFor(stateWith(landing: progress()));

    expect(view.deployableCells, isEmpty);
    expect(
      view.gridTapOutcome(_landingRigCell).message,
      'Select a rig from the dock.',
    );
  });

  test('projects rig rate, capacity, cargo, and active-planet sale', () {
    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          storedAmount: 10,
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCell)],
        ),
      ),
    );

    expect(view.rate, 0.5);
    expect(view.capacity, 3600);
    expect(view.cargo, 10);
    expect(view.projectedSale, 40);
    expect(view.sale.projectedValue, 40);
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

  test('sells sub-1-cash cargo for a +0 sale', () {
    // 0.1 Gold at Landing Basin (4 cash/unit) = 0.4 gross, which floors to 0.
    final view = viewFor(
      stateWith(landing: progress(commissioned: true, storedAmount: 0.1)),
    );

    expect(view.activePlanetCargo, 0.1);
    expect(view.activePlanetProjectedSale, 0);
    expect(view.canSell, isTrue);
    expect(view.sale.projectedValue, 0);
    expect(view.sale.label, 'Sell all cargo for 0 cash.');
  });

  test('enables the sale when only an inactive unlocked planet has cargo', () {
    final view = viewFor(
      stateWith(
        frozen: progress(unlocked: true, commissioned: true, storedAmount: 20),
      ).copyWith(
        unlockedPlanetIds: {
          MiningPlanetId.homeworld,
          MiningPlanetId.lunarFrontier,
        },
      ),
    );

    expect(view.activePlanetCargo, 0);
    expect(view.activePlanetProjectedSale, 0);
    expect(view.canSell, isTrue);
    expect(view.sale.projectedValue, 120);
    expect(view.sale.label, 'Sell all cargo for 120 cash.');
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
      view.gridTapOutcome(_landingRigCell).message,
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
      view.gridTapOutcome(_landingRigCell).message,
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
      viewSurveyed.gridTapOutcome(_frozenRigCell).message,
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

    // A resource gated above Surveying 0 is locked; a cell inside it surfaces
    // the requirement before any other outcome.
    final lockedDeposit = _depositAt(_frozenSite, 5);
    expect(
      view
          .gridTapOutcome(MiningGridCell(lockedDeposit.x, lockedDeposit.y))
          .message,
      'Requires Surveying 5.',
    );
  });

  test(
    'recalls an occupied cell and blocks on cargo above post-recall capacity',
    () {
      final cells = deployableMiningCells(
        content.site(MiningSiteId.landingBasin),
      );
      final rigs = [
        MiningRigPlacement(tier: RigTier.t1, cell: cells[0]),
        MiningRigPlacement(tier: RigTier.t1, cell: cells[1]),
      ];
      final view = viewFor(
        stateWith(
          landing: progress(commissioned: true, storedAmount: 6000, rigs: rigs),
        ),
      );

      final rig = view.rigAt(cells[0])!;
      expect(rig.canRecall, isFalse);
      expect(rig.disabledReason, 'Sell cargo before recalling this rig.');
      expect(
        view.gridTapOutcome(cells[0]).message,
        'Sell cargo before recalling this rig.',
      );

      final soldView = viewFor(
        stateWith(
          landing: progress(commissioned: true, storedAmount: 0, rigs: rigs),
        ),
      );

      expect(
        soldView.gridTapOutcome(cells[0]).action,
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
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCell)],
        ),
      },
    );
    final view = viewFor(state);

    expect(view.gridTapOutcome(_landingRigCell).message, 'Dock is full.');
  });

  test('two rigs on one resource share its target and miner count', () {
    final site = content.site(MiningSiteId.landingBasin);
    final target = site.deposits.first;
    final cells = site.perimeterCellsByDeposit[target]!.toList();
    expect(cells.length, greaterThanOrEqualTo(2));

    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          rigs: [
            MiningRigPlacement(tier: RigTier.t2, cell: cells[0]),
            MiningRigPlacement(tier: RigTier.t1, cell: cells[1]),
          ],
        ),
      ),
    );

    expect(view.rigs[0].target, target);
    expect(view.rigs[1].target, target);
    final depositView = view.deposits.singleWhere(
      (deposit) => deposit.definition == target,
    );
    expect(depositView.minerCount, 2);
    expect(depositView.slotCount, cells.length);
    final locked = view.deposits.singleWhere(
      (deposit) => deposit.definition == _depositAt(site, 1),
    );
    expect(locked.minerCount, 0);
    expect(locked.slotCount, greaterThan(0));
    expect(locked.isSurveyed, isFalse);
  });

  test('occupied and deposit cells block deployment with grid copy', () {
    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCell)],
        ),
      ),
      selectedBayId: DockBayId.b1,
    );

    expect(
      view.gridTapOutcome(_landingClearCell).message,
      'Place the rig next to a resource.',
    );
    final depositOrigin = MiningGridCell(
      _landingRigTarget.x,
      _landingRigTarget.y,
    );
    expect(
      view.gridTapOutcome(depositOrigin).message,
      'Resources occupy this cell.',
    );
  });

  test('a matching selected dock rig upgrades the occupied cell', () {
    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCell)],
        ),
      ),
      selectedBayId: DockBayId.b1,
    );

    final rig = view.rigAt(_landingRigCell)!;
    expect(rig.canUpgradeWithSelection, isTrue);
    expect(rig.upgradeFailure, isNull);
    expect(view.upgradeableCells, {_landingRigCell});
    expect(
      view.gridTapOutcome(_landingRigCell).action,
      MineSiteGridTapAction.upgrade,
    );
    final freeCell = view.deployableCells.first;
    expect(view.gridTapOutcome(freeCell).action, MineSiteGridTapAction.deploy);
  });

  test('a mismatched selected dock rig reports the merge rule', () {
    final initial = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26));
    final state = initial.copyWith(
      docks: {
        ...initial.docks,
        MiningPlanetId.homeworld: {
          ...initial.docks[MiningPlanetId.homeworld]!,
          DockBayId.b1: RigTier.t2,
        },
      },
      sites: {
        ...initial.sites,
        MiningSiteId.landingBasin: progress(
          commissioned: true,
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCell)],
        ),
      },
    );
    final view = viewFor(state, selectedBayId: DockBayId.b1);

    final rig = view.rigAt(_landingRigCell)!;
    expect(rig.canUpgradeWithSelection, isFalse);
    expect(rig.upgradeFailure, 'Rigs must be the same tier.');
    expect(view.upgradeableCells, isEmpty);
    expect(
      view.gridTapOutcome(_landingRigCell).message,
      'Rigs must be the same tier.',
    );
  });

  test('a selected T5 cannot merge into a placed T5', () {
    final initial = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26));
    final state = initial.copyWith(
      docks: {
        ...initial.docks,
        MiningPlanetId.homeworld: {
          ...initial.docks[MiningPlanetId.homeworld]!,
          DockBayId.b1: RigTier.t5,
        },
      },
      sites: {
        ...initial.sites,
        MiningSiteId.landingBasin: progress(
          commissioned: true,
          rigs: [MiningRigPlacement(tier: RigTier.t5, cell: _landingRigCell)],
        ),
      },
    );
    final view = viewFor(state, selectedBayId: DockBayId.b1);

    final rig = view.rigAt(_landingRigCell)!;
    expect(rig.canUpgradeWithSelection, isFalse);
    expect(rig.upgradeFailure, 'T5 rigs cannot merge.');
    expect(
      view.gridTapOutcome(_landingRigCell).message,
      'T5 rigs cannot merge.',
    );
  });

  test('the upgrade path stays busy-blocked like every grid tap', () {
    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCell)],
        ),
      ),
      selectedBayId: DockBayId.b1,
      isBusy: true,
    );

    final rig = view.rigAt(_landingRigCell)!;
    expect(rig.canUpgradeWithSelection, isFalse);
    expect(rig.upgradeFailure, 'Finishing previous action…');
    expect(view.upgradeableCells, isEmpty);
    expect(
      view.gridTapOutcome(_landingRigCell).message,
      'Finishing previous action…',
    );
  });

  test('upgrade ignores the recall-only cargo and dock-space rules', () {
    final initial = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26));
    final state = initial.copyWith(
      docks: {
        ...initial.docks,
        MiningPlanetId.homeworld: const {
          DockBayId.b1: RigTier.t1,
          DockBayId.b2: RigTier.t1,
          DockBayId.b3: RigTier.t1,
          DockBayId.b4: RigTier.t1,
        },
      },
      sites: {
        ...initial.sites,
        MiningSiteId.landingBasin: progress(
          commissioned: true,
          storedAmount: 6000,
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCell)],
        ),
      },
    );
    final view = viewFor(state, selectedBayId: DockBayId.b1);

    final rig = view.rigAt(_landingRigCell)!;
    expect(rig.canRecall, isFalse);
    expect(rig.canUpgradeWithSelection, isTrue);
    expect(view.upgradeableCells, {_landingRigCell});
    expect(
      view.gridTapOutcome(_landingRigCell).action,
      MineSiteGridTapAction.upgrade,
    );
  });

  test('an occupied cell without a dock selection still recalls', () {
    final view = viewFor(
      stateWith(
        landing: progress(
          commissioned: true,
          rigs: [MiningRigPlacement(tier: RigTier.t1, cell: _landingRigCell)],
        ),
      ),
    );

    final rig = view.rigAt(_landingRigCell)!;
    expect(rig.canUpgradeWithSelection, isFalse);
    expect(rig.upgradeFailure, isNull);
    expect(view.upgradeableCells, isEmpty);
    expect(
      view.gridTapOutcome(_landingRigCell).action,
      MineSiteGridTapAction.recall,
    );
  });
}
