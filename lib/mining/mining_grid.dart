enum MiningDepositId { d1, d2, d3, d4 }

enum MiningPlacementRejection {
  siteAtCapacity,
  outsideGrid,
  depositCell,
  rigOccupied,
  noAdjacentDeposit,
  ambiguousAdjacentDeposit,
  surveyingLocked,
  depositAtCapacity,
}

class MiningGridCell {
  const MiningGridCell(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is MiningGridCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

class MiningDepositDefinition {
  const MiningDepositDefinition({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.maxMiners,
    required this.requiredSurveyingLevel,
  });
  final MiningDepositId id;
  final int x;
  final int y;
  final int size;
  final int maxMiners;
  final int requiredSurveyingLevel;

  bool contains(MiningGridCell cell) =>
      cell.x >= x && cell.x < x + size && cell.y >= y && cell.y < y + size;

  bool isOrthogonallyAdjacent(MiningGridCell cell) {
    final inColumns = cell.x >= x && cell.x < x + size;
    final inRows = cell.y >= y && cell.y < y + size;
    return (inColumns && (cell.y == y - 1 || cell.y == y + size)) ||
        (inRows && (cell.x == x - 1 || cell.x == x + size));
  }
}

class MiningPlacementResult {
  const MiningPlacementResult.allowed(this.target) : rejection = null;
  const MiningPlacementResult.rejected(this.rejection, {this.target});
  final MiningDepositDefinition? target;
  final MiningPlacementRejection? rejection;
  bool get isAllowed => rejection == null;
}

MiningDepositDefinition? uniqueAdjacentDeposit({
  required List<MiningDepositDefinition> deposits,
  required MiningGridCell cell,
}) {
  final adjacent = deposits
      .where((deposit) => deposit.isOrthogonallyAdjacent(cell))
      .toList(growable: false);
  return adjacent.length == 1 ? adjacent.single : null;
}

MiningPlacementResult evaluateMiningPlacement({
  required int gridWidth,
  required int gridHeight,
  required List<MiningDepositDefinition> deposits,
  required Iterable<MiningGridCell> occupiedRigCells,
  required MiningGridCell candidate,
  required int surveyingLevel,
  required int maxRigCount,
}) {
  final occupied = occupiedRigCells.toList(growable: false);
  if (occupied.length >= maxRigCount) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.siteAtCapacity,
    );
  }
  if (candidate.x < 0 ||
      candidate.x >= gridWidth ||
      candidate.y < 0 ||
      candidate.y >= gridHeight) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.outsideGrid,
    );
  }

  final containing = deposits
      .where((deposit) => deposit.contains(candidate))
      .toList(growable: false);
  if (containing.isNotEmpty) {
    return MiningPlacementResult.rejected(
      MiningPlacementRejection.depositCell,
      target: containing.length == 1 ? containing.single : null,
    );
  }
  if (occupied.contains(candidate)) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.rigOccupied,
    );
  }

  final adjacent = deposits
      .where((deposit) => deposit.isOrthogonallyAdjacent(candidate))
      .toList(growable: false);
  if (adjacent.isEmpty) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.noAdjacentDeposit,
    );
  }
  if (adjacent.length != 1) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.ambiguousAdjacentDeposit,
    );
  }

  final target = adjacent.single;
  if (surveyingLevel < target.requiredSurveyingLevel) {
    return MiningPlacementResult.rejected(
      MiningPlacementRejection.surveyingLocked,
      target: target,
    );
  }
  final miners = occupied.where((cell) {
    return uniqueAdjacentDeposit(deposits: deposits, cell: cell)?.id ==
        target.id;
  }).length;
  if (miners >= target.maxMiners) {
    return MiningPlacementResult.rejected(
      MiningPlacementRejection.depositAtCapacity,
      target: target,
    );
  }
  return MiningPlacementResult.allowed(target);
}
