import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_grid.dart';

void main() {
  const target = MiningDepositDefinition(
    x: 3,
    y: 3,
    size: 1,
    requiredSurveyingLevel: 0,
  );
  const deposits = [target];

  MiningPlacementResult placement(
    MiningGridCell candidate, {
    Iterable<MiningGridCell> occupied = const [],
    int surveying = 5,
    List<MiningDepositDefinition> authored = deposits,
  }) => evaluateMiningPlacement(
    gridWidth: 8,
    gridHeight: 8,
    deposits: authored,
    occupiedRigCells: occupied,
    candidate: candidate,
    surveyingLevel: surveying,
    maxRigCount: 4,
  );

  test('deposit footprints and orthogonal adjacency are exact', () {
    expect(target.contains(const MiningGridCell(3, 3)), isTrue);
    expect(target.isOrthogonallyAdjacent(const MiningGridCell(3, 2)), isTrue);
    expect(target.isOrthogonallyAdjacent(const MiningGridCell(2, 2)), isFalse);
  });

  test('same resource hosts multiple robots on sibling perimeter cells', () {
    expect(
      miningPerimeterCells(
        gridWidth: 8,
        gridHeight: 8,
        deposits: deposits,
        target: target,
      ),
      {
        const MiningGridCell(3, 2),
        const MiningGridCell(2, 3),
        const MiningGridCell(4, 3),
        const MiningGridCell(3, 4),
      },
    );

    final second = evaluateMiningPlacement(
      gridWidth: 8,
      gridHeight: 8,
      deposits: deposits,
      occupiedRigCells: const [MiningGridCell(3, 2)],
      candidate: const MiningGridCell(2, 3),
      surveyingLevel: 0,
      maxRigCount: 4,
    );
    expect(second.isAllowed, isTrue);
    expect(second.target, target);
  });

  test('placement returns the unique target', () {
    final result = placement(const MiningGridCell(3, 2), surveying: 0);
    expect(result.isAllowed, isTrue);
    expect(result.target, target);
  });

  test('placement rejection matrix is exact', () {
    expect(
      placement(
        const MiningGridCell(3, 2),
        occupied: const [
          MiningGridCell(1, 1),
          MiningGridCell(2, 1),
          MiningGridCell(3, 1),
          MiningGridCell(4, 1),
        ],
      ).rejection,
      MiningPlacementRejection.siteAtCapacity,
    );
    expect(
      placement(const MiningGridCell(-1, 0)).rejection,
      MiningPlacementRejection.outsideGrid,
    );
    final depositCell = placement(const MiningGridCell(3, 3), surveying: 0);
    expect(depositCell.rejection, MiningPlacementRejection.depositCell);
    expect(depositCell.target, target);
    expect(
      placement(
        const MiningGridCell(3, 2),
        occupied: const [MiningGridCell(3, 2)],
      ).rejection,
      MiningPlacementRejection.rigOccupied,
    );
    expect(
      placement(const MiningGridCell(0, 0)).rejection,
      MiningPlacementRejection.noAdjacentDeposit,
    );
    const ambiguous = [
      MiningDepositDefinition(x: 3, y: 3, size: 1, requiredSurveyingLevel: 0),
      MiningDepositDefinition(x: 3, y: 1, size: 1, requiredSurveyingLevel: 0),
    ];
    expect(
      placement(const MiningGridCell(3, 2), authored: ambiguous).rejection,
      MiningPlacementRejection.ambiguousAdjacentDeposit,
    );
    const locked = MiningDepositDefinition(
      x: 3,
      y: 3,
      size: 1,
      requiredSurveyingLevel: 3,
    );
    expect(
      placement(
        const MiningGridCell(3, 2),
        surveying: 0,
        authored: [locked],
      ).rejection,
      MiningPlacementRejection.surveyingLocked,
    );
  });
}
