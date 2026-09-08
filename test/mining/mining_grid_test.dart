import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_grid.dart';

void main() {
  const d1 = MiningDepositDefinition(
    id: MiningDepositId.d1,
    x: 3,
    y: 3,
    size: 1,
    maxMiners: 1,
    requiredSurveyingLevel: 0,
  );
  const d3 = MiningDepositDefinition(
    id: MiningDepositId.d3,
    x: 5,
    y: 11,
    size: 2,
    maxMiners: 1,
    requiredSurveyingLevel: 1,
  );
  const deposits = [d1, d3];

  MiningPlacementResult placement(
    MiningGridCell candidate, {
    Iterable<MiningGridCell> occupied = const [],
    int surveying = 5,
    List<MiningDepositDefinition> authored = deposits,
  }) => evaluateMiningPlacement(
    gridWidth: 24,
    gridHeight: 18,
    deposits: authored,
    occupiedRigCells: occupied,
    candidate: candidate,
    surveyingLevel: surveying,
    maxRigCount: 4,
  );

  test('deposit footprints and orthogonal adjacency are exact', () {
    expect(d1.contains(const MiningGridCell(3, 3)), isTrue);
    expect(d1.isOrthogonallyAdjacent(const MiningGridCell(3, 2)), isTrue);
    expect(d1.isOrthogonallyAdjacent(const MiningGridCell(2, 2)), isFalse);
    expect(d3.contains(const MiningGridCell(6, 12)), isTrue);
    expect(d3.isOrthogonallyAdjacent(const MiningGridCell(5, 10)), isTrue);
  });

  test('placement returns the unique target', () {
    final result = placement(const MiningGridCell(3, 2), surveying: 0);
    expect(result.isAllowed, isTrue);
    expect(result.target, d1);
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
    final depositCell = placement(const MiningGridCell(5, 11), surveying: 0);
    expect(depositCell.rejection, MiningPlacementRejection.depositCell);
    expect(depositCell.target, d3);
    expect(
      placement(
        const MiningGridCell(3, 2),
        occupied: const [MiningGridCell(3, 2)],
      ).rejection,
      MiningPlacementRejection.rigOccupied,
    );
    expect(
      placement(const MiningGridCell(10, 8)).rejection,
      MiningPlacementRejection.noAdjacentDeposit,
    );
    const ambiguous = [
      MiningDepositDefinition(
        id: MiningDepositId.d1,
        x: 3,
        y: 3,
        size: 1,
        maxMiners: 1,
        requiredSurveyingLevel: 0,
      ),
      MiningDepositDefinition(
        id: MiningDepositId.d2,
        x: 3,
        y: 1,
        size: 1,
        maxMiners: 1,
        requiredSurveyingLevel: 0,
      ),
    ];
    expect(
      placement(const MiningGridCell(3, 2), authored: ambiguous).rejection,
      MiningPlacementRejection.ambiguousAdjacentDeposit,
    );
    expect(
      placement(const MiningGridCell(5, 10), surveying: 0).rejection,
      MiningPlacementRejection.surveyingLocked,
    );
    expect(
      placement(
        const MiningGridCell(3, 4),
        occupied: const [MiningGridCell(3, 2)],
        surveying: 0,
      ).rejection,
      MiningPlacementRejection.depositAtCapacity,
    );
  });
}
