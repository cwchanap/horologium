import 'package:flutter/material.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/presentation/landing_basin_grid_visual_layer.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

const double miningGridCellSize = 56;

/// Oversized deposit art edge, keyed by the deposit's logical footprint in
/// cells. The art is centered over the logical footprint so hit-testing and
/// overlay rects stay on authored grid coordinates.
double depositVisualSize(int footprint) => switch (footprint) {
  1 => 80,
  2 => 120,
  3 => 168,
  _ => throw ArgumentError.value(footprint),
};

class MiningGridMap extends StatelessWidget {
  const MiningGridMap({
    super.key,
    required this.view,
    required this.onCellTap,
    required this.impactSequence,
    required this.reducedMotion,
  });

  final MineSiteView view;
  final ValueChanged<MiningGridCell> onCellTap;
  final int impactSequence;
  final bool reducedMotion;

  Widget _objectLayer() => view.siteId == MiningSiteId.landingBasin
      ? LandingBasinGridVisualLayer(
          key: const Key('landing-basin-grid-visual-layer'),
          view: view,
          impactSequence: impactSequence,
          reducedMotion: reducedMotion,
          cellSize: miningGridCellSize,
        )
      : _StaticMiningGridVisualLayer(
          key: const Key('static-mining-grid-visual-layer'),
          view: view,
          cellSize: miningGridCellSize,
        );

  @override
  Widget build(BuildContext context) {
    final width = view.definition.gridWidth * miningGridCellSize;
    final height = view.definition.gridHeight * miningGridCellSize;
    return InteractiveViewer(
      key: const Key('mining-grid-interactive'),
      constrained: false,
      alignment: Alignment.topLeft,
      minScale: 0.8,
      maxScale: 1.6,
      child: SizedBox(
        key: const Key('mining-grid-surface'),
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => onCellTap(
            MiningGridCell(
              details.localPosition.dx ~/ miningGridCellSize,
              details.localPosition.dy ~/ miningGridCellSize,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Image.asset(
                  view.definition.cavernAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1D2B3D), Color(0xFF0B1420)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.terrain_rounded,
                            color: Colors.white24,
                            size: 48,
                          ),
                        ),
                      ),
                ),
              ),
              Positioned.fill(child: IgnorePointer(child: _objectLayer())),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: MiningGridPainter(
                      width: view.definition.gridWidth,
                      height: view.definition.gridHeight,
                      deployableCells: view.deployableCells,
                    ),
                  ),
                ),
              ),
              // Object overlays: exactly one semantics/lock overlay per
              // authored deposit and at most one per deployed rig. These are
              // not tile widgets; empty cells render nothing.
              for (final deposit in view.deposits)
                Positioned(
                  key: Key('mining-deposit-${deposit.definition.id.name}'),
                  left: deposit.definition.x * miningGridCellSize,
                  top: deposit.definition.y * miningGridCellSize,
                  width: deposit.definition.size * miningGridCellSize,
                  height: deposit.definition.size * miningGridCellSize,
                  child: IgnorePointer(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Semantics(
                            label: _depositLabel(deposit),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        if (!deposit.isSurveyed)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _DepositLockBadge(
                                  requiredSurveyingLevel:
                                      deposit.definition.requiredSurveyingLevel,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              for (final rig in view.rigs)
                Positioned(
                  left: rig.placement.cell.x * miningGridCellSize,
                  top: rig.placement.cell.y * miningGridCellSize,
                  width: miningGridCellSize,
                  height: miningGridCellSize,
                  child: Semantics(
                    button: true,
                    enabled: rig.canRecall,
                    label: _rigLabel(rig),
                    onTap: () => onCellTap(rig.placement.cell),
                    // IgnorePointer sits below the Semantics node so physical
                    // taps stay with the map-level gesture surface while the
                    // semantic tap action survives for assistive tech.
                    child: IgnorePointer(child: const SizedBox.expand()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _depositLabel(MineSiteDepositView deposit) {
    final definition = deposit.definition;
    final resource = MiningContentRegistry
        .resourceSilhouettes[view.definition.resource]!
        .name;
    final locked = deposit.isSurveyed
        ? ''
        : ' Requires Surveying ${definition.requiredSurveyingLevel}.';
    return '$resource deposit ${definition.id.name.toUpperCase()}: '
        '${definition.size}x${definition.size}, '
        '${deposit.minerCount} of ${definition.maxMiners} miners.$locked';
  }

  String _rigLabel(MineSiteRigView rig) {
    final reason = rig.disabledReason;
    return '${rig.placement.tier.name.toUpperCase()} rig at '
        '(${rig.placement.cell.x},${rig.placement.cell.y}) mining '
        '${rig.target.id.name.toUpperCase()}.'
        '${reason == null ? '' : ' $reason'}';
  }
}

class _DepositLockBadge extends StatelessWidget {
  const _DepositLockBadge({required this.requiredSurveyingLevel});

  final int requiredSurveyingLevel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: const BoxDecoration(
      color: Color.fromRGBO(6, 10, 16, .72),
      borderRadius: BorderRadius.all(Radius.circular(9)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.biotech_rounded, size: 12, color: MiningTheme.accent),
        const SizedBox(width: 4),
        Text(
          'Surveying $requiredSurveyingLevel',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _StaticMiningGridVisualLayer extends StatelessWidget {
  const _StaticMiningGridVisualLayer({
    super.key,
    required this.view,
    required this.cellSize,
  });

  final MineSiteView view;
  final double cellSize;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final deposit in view.deposits)
        Positioned(
          left: deposit.definition.x * cellSize,
          top: deposit.definition.y * cellSize,
          width: deposit.definition.size * cellSize,
          height: deposit.definition.size * cellSize,
          child: OverflowBox(
            maxWidth: depositVisualSize(deposit.definition.size),
            maxHeight: depositVisualSize(deposit.definition.size),
            alignment: Alignment.center,
            child: Image.asset(
              view.definition.depositAsset,
              width: depositVisualSize(deposit.definition.size),
              height: depositVisualSize(deposit.definition.size),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ),
      for (final rig in view.rigs)
        Positioned(
          left: rig.placement.cell.x * cellSize,
          top: rig.placement.cell.y * cellSize,
          width: cellSize,
          height: cellSize,
          child: OverflowBox(
            maxWidth: cellSize + 12,
            maxHeight: cellSize + 12,
            alignment: Alignment.center,
            child: Image.asset(
              MiningVisuals.rigAsset(rig.placement.tier),
              width: cellSize + 12,
              height: cellSize + 12,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ),
    ],
  );
}

class MiningGridPainter extends CustomPainter {
  MiningGridPainter({
    required this.width,
    required this.height,
    required this.deployableCells,
  });

  final int width;
  final int height;
  final Set<MiningGridCell> deployableCells;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = miningGridCellSize;
    final highlight = Paint()..color = const Color.fromRGBO(83, 212, 232, .16);
    for (final cellPos in deployableCells) {
      canvas.drawRect(
        Rect.fromLTWH(cellPos.x * cell, cellPos.y * cell, cell, cell),
        highlight,
      );
    }
    final line = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 1;
    for (var x = 0; x <= width; x++) {
      canvas.drawLine(
        Offset(x * cell, 0),
        Offset(x * cell, height * cell),
        line,
      );
    }
    for (var y = 0; y <= height; y++) {
      canvas.drawLine(
        Offset(0, y * cell),
        Offset(width * cell, y * cell),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(MiningGridPainter oldDelegate) =>
      oldDelegate.width != width ||
      oldDelegate.height != height ||
      oldDelegate.deployableCells != deployableCells;
}
