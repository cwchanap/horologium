import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/presentation/animated_mining_grid_visual_layer.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

const double miningGridCellSize = 56;
const double miningGridMinScale = 0.8;
const double miningGridMaxScale = 1.6;

/// Oversized deposit art edge, keyed by the deposit's logical footprint in
/// cells. The art is centered over the logical footprint so hit-testing and
/// overlay rects stay on authored grid coordinates.
double depositVisualSize(int footprint) => switch (footprint) {
  1 => 80,
  2 => 120,
  3 => 168,
  _ => throw ArgumentError.value(footprint),
};

/// Stable overlay/visual key derived from the deposit's authored geometry:
/// dense-field resources key by footprint, not by list position.
String _depositKey(MiningDepositDefinition definition) =>
    '${definition.x}-${definition.y}-${definition.size}';

class MiningGridMap extends StatefulWidget {
  const MiningGridMap({
    super.key,
    required this.view,
    required this.onCellTap,
    required this.impactSequence,
    this.onMiningImpact,
    required this.reducedMotion,
    this.viewportInsets = EdgeInsets.zero,
  });

  final MineSiteView view;
  final ValueChanged<MiningGridCell> onCellTap;
  final int impactSequence;
  final VoidCallback? onMiningImpact;
  final bool reducedMotion;

  /// Screen-space chrome clearance around the map viewport. The pan
  /// boundaries divide it by [miningGridMinScale] because
  /// [InteractiveViewer.boundaryMargin] works in scene coordinates, so the
  /// full clearance survives at the zoom floor.
  final EdgeInsets viewportInsets;

  @override
  State<MiningGridMap> createState() => _MiningGridMapState();
}

class _MiningGridMapState extends State<MiningGridMap> {
  final TransformationController _transformationController =
      TransformationController();
  bool _cameraPlaced = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Widget _objectLayer() {
    final view = widget.view;
    final frames = MiningVisuals.depositFramesFor(view.siteId);
    if (frames != null) {
      return AnimatedMiningGridVisualLayer(
        key: Key(
          '${MiningVisuals.siteKeyPrefix(view.siteId)}-grid-visual-layer',
        ),
        view: view,
        frames: frames,
        impactSequence: widget.impactSequence,
        onMiningImpact: widget.onMiningImpact,
        reducedMotion: widget.reducedMotion,
        cellSize: miningGridCellSize,
      );
    }
    return _StaticMiningGridVisualLayer(
      key: const Key('static-mining-grid-visual-layer'),
      view: view,
      cellSize: miningGridCellSize,
    );
  }

  /// Scene-space point the initial 1.0x camera centers on: the placed rigs'
  /// bounding box when the site is populated, otherwise the first surveyed
  /// deposit that still has free perimeter slots. Null keeps the identity
  /// transform.
  Offset? _initialFocus() {
    final view = widget.view;
    if (view.rigs.isNotEmpty) {
      var left = view.definition.gridWidth;
      var top = view.definition.gridHeight;
      var right = 0;
      var bottom = 0;
      for (final rig in view.rigs) {
        final cell = rig.placement.cell;
        left = math.min(left, cell.x);
        top = math.min(top, cell.y);
        right = math.max(right, cell.x + 1);
        bottom = math.max(bottom, cell.y + 1);
      }
      return Offset(
        (left + right) * miningGridCellSize / 2,
        (top + bottom) * miningGridCellSize / 2,
      );
    }
    for (final deposit in view.deposits) {
      if (deposit.isSurveyed && deposit.minerCount < deposit.slotCount) {
        final definition = deposit.definition;
        return Offset(
          (definition.x + definition.size / 2) * miningGridCellSize,
          (definition.y + definition.size / 2) * miningGridCellSize,
        );
      }
    }
    return null;
  }

  /// The 1.0x transform placed once, before the first InteractiveViewer
  /// build: [focus] lands on the unoccluded viewport's center unless the
  /// scale-aware pan bounds clamp it closer.
  Matrix4 _initialCamera(Size viewport, Offset focus) {
    final insets = widget.viewportInsets;
    final margin = insets / miningGridMinScale;
    final view = widget.view;
    final childWidth = view.definition.gridWidth * miningGridCellSize;
    final childHeight = view.definition.gridHeight * miningGridCellSize;
    final center = Offset(
      insets.left + (viewport.width - insets.horizontal) / 2,
      insets.top + (viewport.height - insets.vertical) / 2,
    );
    final tx = (center.dx - focus.dx)
        .clamp(viewport.width - childWidth - margin.right, margin.left)
        .toDouble();
    final ty = (center.dy - focus.dy)
        .clamp(viewport.height - childHeight - margin.bottom, margin.top)
        .toDouble();
    return Matrix4.translationValues(tx, ty, 0);
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final width = view.definition.gridWidth * miningGridCellSize;
    final height = view.definition.gridHeight * miningGridCellSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_cameraPlaced) {
          _cameraPlaced = true;
          final focus = _initialFocus();
          if (focus != null) {
            _transformationController.value = _initialCamera(
              constraints.biggest,
              focus,
            );
          }
        }
        return InteractiveViewer(
          key: const Key('mining-grid-interactive'),
          transformationController: _transformationController,
          boundaryMargin: widget.viewportInsets / miningGridMinScale,
          constrained: false,
          alignment: Alignment.topLeft,
          minScale: miningGridMinScale,
          maxScale: miningGridMaxScale,
          child: SizedBox(
            key: const Key('mining-grid-surface'),
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => widget.onCellTap(
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
                      fit: BoxFit.none,
                      alignment: Alignment.topLeft,
                      repeat: ImageRepeat.repeat,
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
                  // Object overlays: exactly one semantics overlay per authored
                  // deposit and at most one per deployed rig. These are not
                  // tile widgets; empty cells render nothing.
                  for (final deposit in view.deposits)
                    Positioned(
                      key: Key(
                        'mining-deposit-${_depositKey(deposit.definition)}',
                      ),
                      left: deposit.definition.x * miningGridCellSize,
                      top: deposit.definition.y * miningGridCellSize,
                      width: deposit.definition.size * miningGridCellSize,
                      height: deposit.definition.size * miningGridCellSize,
                      child: IgnorePointer(
                        child: Semantics(
                          label: _depositLabel(deposit),
                          child: const SizedBox.expand(),
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
                        onTap: () => widget.onCellTap(rig.placement.cell),
                        // IgnorePointer sits below the Semantics node so
                        // physical taps stay with the map-level gesture
                        // surface while the semantic tap action survives for
                        // assistive tech.
                        child: IgnorePointer(child: const SizedBox.expand()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _depositLabel(MineSiteDepositView deposit) {
    final definition = deposit.definition;
    final resource = MiningContentRegistry
        .resourceSilhouettes[widget.view.definition.resource]!
        .name;
    final locked = deposit.isSurveyed
        ? ''
        : ' Requires Surveying ${definition.requiredSurveyingLevel}.';
    final freeSlots = deposit.slotCount - deposit.minerCount;
    return '$resource resource ${definition.size}x${definition.size}, '
        '${deposit.minerCount} miners, '
        '$freeSlots of ${deposit.slotCount} perimeter slots free.$locked';
  }

  String _rigLabel(MineSiteRigView rig) {
    final reason = rig.disabledReason;
    return '${rig.placement.tier.name.toUpperCase()} rig at '
        '(${rig.placement.cell.x},${rig.placement.cell.y}) mining '
        'deposit (${rig.target.x},${rig.target.y}).'
        '${reason == null ? '' : ' $reason'}';
  }
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
          key: Key('static-deposit-${_depositKey(deposit.definition)}'),
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
              // Unsurveyed art dims so locked resources read differently
              // from surveyed peers without floating lock badges.
              opacity: deposit.isSurveyed
                  ? null
                  : const AlwaysStoppedAnimation(.62),
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
      !setEquals(oldDelegate.deployableCells, deployableCells);
}
