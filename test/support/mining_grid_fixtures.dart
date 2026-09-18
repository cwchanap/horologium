import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';

/// Legal deploy cells for [site] at [surveyingLevel] with no rigs deployed:
/// the site's cached perimeter candidate union filtered through the real
/// placement evaluator, sorted row-major. Never scans the full grid.
List<MiningGridCell> deployableMiningCells(
  MiningSiteDefinition site, {
  int surveyingLevel = 0,
}) {
  final candidates = <MiningGridCell>{
    for (final deposit in site.deposits)
      if (surveyingLevel >= deposit.requiredSurveyingLevel)
        ...site.perimeterCellsByDeposit[deposit]!,
  };
  final legal = candidates
      .where(
        (cell) => evaluateMiningPlacement(
          gridWidth: site.gridWidth,
          gridHeight: site.gridHeight,
          deposits: site.deposits,
          occupiedRigCells: const [],
          candidate: cell,
          surveyingLevel: surveyingLevel,
          maxRigCount: MiningContentRegistry.maxDeployedRigsPerSite,
        ).isAllowed,
      )
      .toList();
  legal.sort((a, b) {
    final row = a.y.compareTo(b.y);
    return row != 0 ? row : a.x.compareTo(b.x);
  });
  return legal;
}

/// First row-major legal deploy cell for [site] at its first playable
/// Surveying level (its first progression resource's requirement).
MiningGridCell firstPlayableCell(MiningSiteDefinition site) =>
    deployableMiningCells(
      site,
      surveyingLevel: site.deposits.first.requiredSurveyingLevel,
    ).first;
