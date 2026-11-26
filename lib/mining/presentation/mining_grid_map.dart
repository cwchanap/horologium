import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/presentation/animated_mining_grid_visual_layer.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

const double miningGridCellSize = 56;
const double miningGridSceneWidth =
    MiningContentRegistry.mineGridWidth * miningGridCellSize;
const double miningGridSceneHeight =
    MiningContentRegistry.mineGridHeight * miningGridCellSize;

/// Gold shared by the rig upgrade chip and the upgrade-target ring.
const Color _upgradeGold = Color(0xFFF5B44C);

/// Dark ink that clears 4.5:1 contrast on [_upgradeGold].
const Color _upgradeInk = Color(0xFF04121A);

/// Fixed scene-space height of the top-anchored rig chip.
const double miningRigChipHeight = 18;

/// Widest label box that still leaves the whole chip inside one cell: cell
/// width minus the chip's 2px side padding, 1px border, and 1px of slack.
const double _rigChipLabelMaxWidth = miningGridCellSize - 7;

/// Vertical room above a rig cell that a damage label needs so the rig's
/// top-anchored tier chip cannot cover it: the chip's full height plus a
/// small gap.
const double miningRigChipClearance = miningRigChipHeight + 2;

/// Minimum actionable depth-rail target.
const double _depthRailTargetSize = 44;

/// Rail targets read top-to-bottom as the map scrolls: Motherlode at the top,
/// pockets at the bottom. The compact horizontal row keeps that same order.
const List<MiningBand> _depthRailBands = [
  MiningBand.motherlode,
  MiningBand.lodes,
  MiningBand.seams,
  MiningBand.pockets,
];

typedef _JumpInputs = ({
  Size size,
  EdgeInsets viewportInsets,
  Rect? upperHudHitRect,
  double railTop,
  double railBottom,
  double? placementSafeY,
  double railRight,
  double? railClearRight,
  double? railBelowClearRight,
  double? railBelowLeft,
  double? railBelowBottom,
});

/// Oversized deposit art edge, keyed by the deposit's logical footprint in
/// cells. The art is centered over the logical footprint so hit-testing and
/// overlay rects stay on authored grid coordinates.
double depositVisualSize(int footprint) => switch (footprint) {
  1 => 80,
  2 => 120,
  3 => 168,
  4 => 224,
  _ => throw ArgumentError.value(footprint),
};

/// Stable overlay/visual key derived from the deposit's authored geometry:
/// banded-grid resources key by footprint, not by list position.
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
    this.upperHudHitRect,
    this.hudHitKeys = const [],
    this.railTop = 0,
    this.railBottom = double.infinity,
    this.placementSafeY,
    this.railRight = 8,
    this.railClearRight,
    this.railBelowClearRight,
    this.railBelowLeft,
    this.railBelowBottom,
  });

  final MineSiteView view;
  final ValueChanged<MiningGridCell> onCellTap;
  final int impactSequence;
  final VoidCallback? onMiningImpact;
  final bool reducedMotion;

  /// Vertical scroll clearance around the map scene. The left value is also
  /// the compact depth rail's safe left edge; the right value is ignored
  /// because the map keeps the full viewport width so the 8-cell scene can
  /// scale down instead of shrinking under HUD columns.
  final EdgeInsets viewportInsets;

  /// Actionable upper-chrome bounds in the map's local coordinates. Chrome
  /// inside [viewportInsets.top] is already clear of the preferred frame; this
  /// rect is for a control such as portrait Back that reaches below it.
  final Rect? upperHudHitRect;

  /// Actionable HUD controls measured in place, including controls fully inside
  /// [viewportInsets.top]: deep scrolls can move placement centres underneath
  /// them even when the preferred frame starts below the top chrome.
  final List<GlobalKey> hudHitKeys;

  /// Vertical span and right inset of the depth rail in the map's local
  /// coordinates, supplied by the screen so the rail stays between the cargo
  /// gauge and the Sell/bottom chrome.
  final double railTop;
  final double railBottom;

  /// Bottom edge of the lowest chrome a placement tap must clear. Portrait
  /// passes the Sell top; other layouts use the bottom viewport inset.
  final double? placementSafeY;
  final double railRight;

  /// Right edge available to a horizontal rail row in the map's local
  /// coordinates: the landscape Sell column's left edge, supplied by the
  /// screen. A compact row shrinks its gaps to fit between the safe left edge
  /// and this limit instead of reaching the Sell.
  final double? railClearRight;

  /// Right edge available to the below-grid fallback row: the Sell column's
  /// left edge, whichever chrome shares that strip. The portrait Sell column
  /// sits in it stacked above the map, so a row reaching under it would sell
  /// cargo on a rail tap. Defaults to [railClearRight] when unset.
  final double? railBelowClearRight;

  /// Left edge available to the below-grid fallback row. The strip is below
  /// the Back chrome, so it starts at the safe-area edge rather than the map
  /// content's wider left clearance.
  final double? railBelowLeft;

  /// Bottom edge available to the below-grid fallback row: the nearest bottom
  /// chrome that horizontally overlaps that row, such as the landscape
  /// toolbar. Defaults to the viewport edge for a strip with no such chrome.
  final double? railBelowBottom;

  @override
  State<MiningGridMap> createState() => _MiningGridMapState();
}

class _MiningGridMapState extends State<MiningGridMap> {
  final ScrollController _scrollController = ScrollController();
  final Map<MiningBand, GlobalKey> _railHitKeys = {
    for (final band in _depthRailBands) band: GlobalKey(),
  };
  bool _framed = false;
  bool _initialFrameVisible = false;
  double _sceneScale = 1;
  double _sceneLeft = 0;
  MiningBand? _railJumpBand;
  int _railJumpSeq = 0;
  _JumpInputs? _jumpInputs;
  final Map<MiningBand, FocusNode> _railFocusNodes = {
    for (final band in MiningBand.values) band: FocusNode(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _railFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  MiningBand _bandOf(MineSiteDepositView deposit) =>
      bandForDeposit(deposit.definition);

  Iterable<MineSiteDepositView> _depositsIn(MiningBand band) =>
      widget.view.deposits.where((deposit) => _bandOf(deposit) == band);

  bool _isBandOpen(MiningBand band) =>
      _depositsIn(band).every((deposit) => deposit.isSurveyed);

  int _bandRequirement(MiningBand band) =>
      _depositsIn(band).first.definition.requiredSurveyingLevel;

  /// Highest fully surveyed band: Motherlode on the all-5 late sites.
  MiningBand _highestOpenBand() {
    for (final band in MiningBand.values.reversed) {
      if (_depositsIn(band).isNotEmpty && _isBandOpen(band)) return band;
    }
    return MiningBand.values.first;
  }

  /// Deepest unique-perimeter row in [band]. This authored geometry stays
  /// fixed while rig selection or occupancy changes, so jump targets do not
  /// move underneath the pointer during a mutation.
  int _bottomPlacementRow(MiningBand band) {
    var row = 0;
    for (final deposit in _depositsIn(band)) {
      for (final cell
          in widget.view.definition.perimeterCellsByDeposit[deposit
              .definition]!) {
        row = math.max(row, cell.y);
      }
    }
    return row;
  }

  Rect? _rectInMap(GlobalKey key, RenderBox mapBox) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final topLeft = mapBox.globalToLocal(box.localToGlobal(Offset.zero));
    final bottomRight = mapBox.globalToLocal(
      box.localToGlobal(Offset(box.size.width, box.size.height)),
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  Iterable<Rect> _measuredHitRects(
    Iterable<GlobalKey> keys,
    RenderBox mapBox,
  ) sync* {
    for (final key in keys) {
      final rect = _rectInMap(key, mapBox);
      if (rect != null) yield rect;
    }
  }

  /// One scroll path for the once-per-entry frame and every rail tap. The
  /// preferred target is the scale-aware row offset `labelRow * 56 *
  /// min(1, width / 448)` in scroll-content coordinates. Because the
  /// scrollable child already starts after the top padding, that target
  /// places the label at viewportInsets.top rather than screen y=0. When that
  /// leaves an open band's deepest placement row in the bottom HUD clearance,
  /// scroll farther until that row clears it; on a short viewport the label
  /// may leave the top clearance, but a visible placement tap cannot sell. A
  /// locked band has no deployable row to rescue, so it keeps the label and
  /// its Surveying copy at the preferred frame. Open-band targets then prefer
  /// the nearest clamped scroll offset whose placement centres clear the upper
  /// chrome and the actual depth-rail target rectangles. Bottom clearance and
  /// rows visible in that frame are hard constraints: when no rail-clear
  /// offset satisfies them, the jump keeps the bottom-safe frame instead of
  /// hiding a placement row or putting a placement tap on Sell.
  void _scrollToBand(MiningBand band, {required bool animate}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxTarget = math.max(0.0, position.maxScrollExtent);
    final cellSize = miningGridCellSize * _sceneScale;
    final labelTarget = band.labelRow * cellSize;
    final bottomClearY =
        position.viewportDimension - widget.viewportInsets.bottom;
    final open = _isBandOpen(band);
    var placementBottomTarget = double.negativeInfinity;
    var placementCenterTarget = double.negativeInfinity;
    var target = labelTarget;
    if (open) {
      final bottomRow = _bottomPlacementRow(band);
      placementBottomTarget =
          widget.viewportInsets.top + (bottomRow + 1) * cellSize - bottomClearY;
      placementCenterTarget =
          widget.viewportInsets.top +
          (bottomRow + .5) * cellSize -
          (widget.placementSafeY ?? bottomClearY);
      target = math.max(labelTarget, placementBottomTarget);
    }
    final mapBox = context.findRenderObject();
    final hitRects = [
      if (widget.upperHudHitRect != null) widget.upperHudHitRect!,
      if (mapBox is RenderBox && mapBox.hasSize) ...[
        ..._measuredHitRects(widget.hudHitKeys, mapBox),
        ..._measuredHitRects(_railHitKeys.values, mapBox),
      ],
    ];
    if (open && hitRects.isNotEmpty) {
      final centers = <Offset>[];
      for (final deposit in _depositsIn(band)) {
        for (final cell
            in widget.view.definition.perimeterCellsByDeposit[deposit
                .definition]!) {
          centers.add(
            Offset(
              _sceneLeft + (cell.x + .5) * cellSize,
              widget.viewportInsets.top + (cell.y + .5) * cellSize,
            ),
          );
        }
      }
      final collisions = <({double start, double end})>[];
      for (final center in centers) {
        for (final hitRect in hitRects) {
          if (center.dx < hitRect.left || center.dx >= hitRect.right) {
            continue;
          }
          collisions.add((
            start: center.dy - hitRect.bottom,
            end: center.dy - hitRect.top + 1,
          ));
        }
      }
      bool clearsCollisions(double value) => collisions.every(
        (collision) => value <= collision.start || value >= collision.end,
      );
      final preferredTarget = target;
      final preferredFrameTarget = preferredTarget
          .clamp(0.0, maxTarget)
          .toDouble();
      const tolerance = 0.001;
      final visibleCenterDys = <double>[
        for (final center in centers)
          if ((center.dy - preferredFrameTarget) >= -tolerance &&
              (center.dy - preferredFrameTarget) <=
                  position.viewportDimension + tolerance)
            center.dy,
      ];
      bool keepsPlacementFrame(double value) {
        if (value + tolerance < placementCenterTarget) return false;
        return visibleCenterDys.every((centerDy) {
          final y = centerDy - value;
          return y >= -tolerance && y <= position.viewportDimension + tolerance;
        });
      }

      final candidates =
          <double>{
                0,
                maxTarget,
                preferredTarget,
                for (final collision in collisions) ...[
                  collision.start,
                  collision.end,
                ],
              }
              .map((value) => value.clamp(0.0, maxTarget).toDouble())
              .where(
                (value) =>
                    clearsCollisions(value) && keepsPlacementFrame(value),
              )
              .toList()
            ..sort();
      if (candidates.isNotEmpty) {
        target = candidates.reduce(
          (best, value) =>
              (value - preferredFrameTarget).abs() <=
                  (best - preferredFrameTarget).abs()
              ? value
              : best,
        );
      } else {
        // No collision-free offset can keep the bottom-safe rows visible;
        // preserve that usable frame and let the player scroll manually
        // around any remaining chrome overlap.
        target = preferredFrameTarget;
      }
    }
    final clampedTarget = target.clamp(0.0, maxTarget).toDouble();
    if (animate && !widget.reducedMotion) {
      // Track the in-flight jump so a mid-animation viewport change can
      // re-target the band's new offset; completion or a canceled jump
      // clears it, so an idle map never reframes on its own.
      _railJumpBand = band;
      final seq = ++_railJumpSeq;
      _scrollController
          .animateTo(
            clampedTarget,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (seq == _railJumpSeq) _railJumpBand = null;
          });
    } else {
      _scrollController.jumpTo(clampedTarget);
    }
  }

  /// Scroll offset that preserves the old viewport centre across a layout
  /// change. Edge-pinned positions stay pinned instead: their centre includes
  /// content the player was not necessarily looking at, while the edge itself
  /// is the meaningful anchor (for example a locked band label at row zero).
  double? _resizeScrollTarget(_JumpInputs previousInputs, _JumpInputs inputs) {
    if (!_scrollController.hasClients) return null;
    final position = _scrollController.position;
    final scale = math.min(1.0, inputs.size.width / miningGridSceneWidth);
    final contentHeight =
        inputs.viewportInsets.top +
        miningGridSceneHeight * scale +
        inputs.viewportInsets.bottom;
    final maxTarget = math.max(0.0, contentHeight - inputs.size.height);
    const tolerance = 0.001;
    if (position.pixels <= position.minScrollExtent + tolerance) return 0;
    if (position.pixels >= position.maxScrollExtent - tolerance) {
      return maxTarget;
    }
    final previousScale = math.min(
      1.0,
      previousInputs.size.width / miningGridSceneWidth,
    );
    final focalSceneY =
        (position.pixels +
            previousInputs.size.height / 2 -
            previousInputs.viewportInsets.top) /
        previousScale;
    return (focalSceneY * scale +
            inputs.viewportInsets.top -
            inputs.size.height / 2)
        .clamp(0.0, maxTarget)
        .toDouble();
  }

  /// Re-targets an in-flight rail jump after a layout change: the band's
  /// scale-aware offset moved, so the stale animation target would land the
  /// label off-screen. Re-animating re-arms tracking, so a multi-frame
  /// resize keeps chasing the moving target until the jump finishes.
  void _retargetPendingJump() {
    final band = _railJumpBand;
    if (band == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _railJumpBand == band) {
        _scrollToBand(band, animate: true);
      }
    });
  }

  /// Frames the highest open band once, after the scroll view has laid out.
  /// Surveying purchases and one-second refreshes rebuild the view behind the
  /// same key and never move the scroll position.
  void _scheduleInitialFrame() {
    if (_framed) return;
    _framed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollToBand(_highestOpenBand(), animate: false);
      if (!_initialFrameVisible) {
        setState(() => _initialFrameVisible = true);
      }
    });
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

  /// Full-bleed repeating cavern behind the scroll view, so landscape,
  /// tablet margins and vertical scroll padding never expose flat side bars.
  Widget _background() {
    return Image.asset(
      widget.view.definition.cavernAsset,
      key: const Key('mining-grid-background'),
      fit: BoxFit.none,
      alignment: Alignment.topLeft,
      repeat: ImageRepeat.repeat,
      errorBuilder: (context, error, stackTrace) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D2B3D), Color(0xFF0B1420)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(Icons.terrain_rounded, color: Colors.white24, size: 48),
        ),
      ),
    );
  }

  /// One static gold halo behind the object layer for every site. Reduced
  /// motion removes it; the rail then jumps instead of animating.
  Iterable<Widget> _motherlodeHalo() sync* {
    if (widget.reducedMotion) return;
    for (final deposit in widget.view.deposits) {
      final definition = deposit.definition;
      if (definition.size != MiningBand.motherlode.footprint) continue;
      final size = depositVisualSize(definition.size) * 1.45;
      yield Positioned(
        key: const Key('mining-motherlode-halo'),
        left:
            (definition.x + definition.size / 2) * miningGridCellSize -
            size / 2,
        top:
            (definition.y + definition.size / 2) * miningGridCellSize -
            size / 2,
        width: size,
        height: size,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _upgradeGold.withValues(alpha: .34),
                  _upgradeGold.withValues(alpha: .12),
                  _upgradeGold.withValues(alpha: 0),
                ],
                stops: const [0, .55, 1],
              ),
            ),
          ),
        ),
      );
    }
  }

  /// Non-interactive band label and locked-band Surveying chip on the empty
  /// gutter rows 0/7/13/18.
  Iterable<Widget> _bandLabels() sync* {
    for (final band in MiningBand.values) {
      final open = _isBandOpen(band);
      yield Positioned(
        key: Key('mining-band-label-${band.name}'),
        left: 0,
        top: band.labelRow * miningGridCellSize,
        width: miningGridSceneWidth,
        height: miningGridCellSize,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color.fromRGBO(6, 10, 16, .58),
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: Colors.white.withValues(alpha: .12),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${band.label.toUpperCase()} '
                        '×${band.footprint} ore',
                        style: const TextStyle(
                          color: MiningTheme.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (!open) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Surveying ${_bandRequirement(band)} opens the '
                          '${band.label.toLowerCase()}',
                          key: Key('mining-band-lock-${band.name}'),
                          style: const TextStyle(
                            color: MiningTheme.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  /// Four depth-rail targets on the viewport's right edge, or below the grid
  /// when the HUD-clear band cannot hold the compact row. The column is sized
  /// to its buttons so the rest of the rail region is pointer transparent,
  /// and each target keeps a full 44dp hit region.
  Widget _depthRail(double viewportHeight, double viewportWidth) {
    final top = widget.railTop.clamp(0.0, viewportHeight);
    final requestedBottom = widget.railBottom.isFinite
        ? widget.railBottom
        : viewportHeight;
    final bottom = requestedBottom.clamp(top, viewportHeight);
    final height = bottom - top;
    // On narrow viewports the scene reaches the rail's right-edge column, so
    // the rail must never cover the bottom row's legal centre at maximum
    // scroll. Reserve one full scaled cell there; a wide viewport keeps the
    // rail beside the scene and needs no reserve. Landscape puts the last row
    // well above the band's lower edge because the bottom scroll padding ends
    // the scene earlier, so reserve down to that row's actual centre instead
    // of assuming it scrolls up to [railBottom].
    final railLeft = viewportWidth - widget.railRight - _depthRailTargetSize;
    final sceneRight = (viewportWidth + miningGridSceneWidth * _sceneScale) / 2;
    final cellSize = miningGridCellSize * _sceneScale;
    final sceneBottom = math.min(
      widget.viewportInsets.top + miningGridSceneHeight * _sceneScale,
      viewportHeight - widget.viewportInsets.bottom,
    );
    final bottomRowReserve = railLeft < sceneRight
        ? math.max(cellSize, bottom - (sceneBottom - cellSize / 2))
        : 0.0;
    final targetHeight = math.max(0.0, height - bottomRowReserve);
    // Four 44dp targets need 176dp of the reserved band to sit in one column
    // without overlap. Above that threshold the gaps shrink from 16dp to zero
    // first. A shorter clear band keeps the targets high in a horizontal row;
    // when the band cannot hold that row either, the row moves below the grid
    // (see [belowScene]). Both compact arrangements stay inside the HUD bounds
    // and only the targets intercept pointers.
    final vertical = targetHeight >= 176;
    // A horizontal row gets the space between the map's left safe edge and
    // the Sell column (when the screen supplies it) or the rail's right inset.
    // Four 44dp targets need 176dp; gaps shrink from 8dp to zero first, so a
    // left safe-area inset cannot push the row under Sell.
    final clearRight =
        widget.railClearRight ?? viewportWidth - widget.railRight;
    final rowSpace = math.max(0.0, clearRight - widget.viewportInsets.left);
    final gap = vertical
        ? ((targetHeight - 176) / 3).clamp(0.0, 16.0)
        : ((rowSpace - 4 * _depthRailTargetSize) / 3).clamp(0.0, 8.0);
    final railWidth = vertical
        ? _depthRailTargetSize
        : 4 * _depthRailTargetSize + 3 * gap;
    final railHeight = vertical
        ? math.min(targetHeight, 176 + gap * 3)
        : _depthRailTargetSize;
    // A top-anchored row can also sit over a legal cell's centre at maximum
    // scroll (590x390 landscape ends the row at the Sell column, on top of
    // the Pockets band's right cells). The strip below the grid can be
    // narrower than the row's own band — portrait's Sell column eats into
    // it — so size a second row for the strip's space; when it holds the
    // four targets clear of the HUD, prefer that spot, otherwise the cell
    // stays rescuable by scrolling, the same contract as the rest of the
    // chrome.
    final stripClearRight =
        widget.railBelowClearRight ??
        widget.railClearRight ??
        viewportWidth - widget.railRight;
    final belowTop = math.max(top, sceneBottom);
    var belowLeft = widget.railBelowLeft ?? widget.viewportInsets.left;
    final upperHud = widget.upperHudHitRect;
    if (upperHud != null &&
        belowTop < upperHud.bottom &&
        belowTop + _depthRailTargetSize > upperHud.top &&
        belowLeft < upperHud.right) {
      belowLeft = upperHud.right;
    }
    final stripRowSpace = math.max(0.0, stripClearRight - belowLeft);
    final belowGap = ((stripRowSpace - 4 * _depthRailTargetSize) / 3).clamp(
      0.0,
      8.0,
    );
    final belowRailWidth = 4 * _depthRailTargetSize + 3 * belowGap;
    final belowStripFits =
        sceneBottom + _depthRailTargetSize <=
            (widget.railBelowBottom ?? viewportHeight) &&
        stripRowSpace >= 4 * _depthRailTargetSize;
    // A compact row needs the whole 44dp clear band. Drop it just below the
    // grid's maximum-scroll bottom whenever that strip can hold the targets:
    // the top row can otherwise cover a legal centre or the locked-band
    // Surveying copy framed at the same top edge. The portrait Sell column
    // shares that strip and is stacked above the map, so a row reaching under
    // it would sell cargo on a rail tap.
    final belowScene = !vertical && belowStripFits;
    // shortcut: a clear band or viewport narrower than one 44dp row cannot
    // fit, and a viewport whose chrome leaves no strip below the grid or
    // beside its start edge cannot hold the compact row; no tested viewport
    // reaches either, revisit with HPA-1244's rail.
    return Positioned(
      key: const Key('mining-depth-rail'),
      top: belowScene ? belowTop : top,
      height: railHeight,
      left: belowScene ? belowLeft : null,
      // A horizontal row must stay inside the supplied right edge (the Sell
      // column's left edge); the right inset only bounds vertical rails.
      right: belowScene
          ? null
          : vertical
          ? widget.railRight
          : viewportWidth - clearRight,
      child: SizedBox(
        width: belowScene ? belowRailWidth : railWidth,
        height: railHeight,
        child: Stack(
          children: [
            for (final (index, band) in _depthRailBands.indexed)
              Positioned(
                top: vertical ? index * (_depthRailTargetSize + gap) : 0,
                left: vertical
                    ? 0
                    : index *
                          (_depthRailTargetSize +
                              (belowScene ? belowGap : gap)),
                child: _depthRailButton(band),
              ),
          ],
        ),
      ),
    );
  }

  Widget _depthRailButton(MiningBand band) {
    final open = _isBandOpen(band);
    final label = open
        ? 'Jump to ${band.label} band'
        : 'Jump to ${band.label} band. '
              'Requires Surveying ${_bandRequirement(band)}.';
    return Semantics(
      key: Key('mining-depth-rail-${band.name}'),
      container: true,
      button: true,
      enabled: true,
      label: label,
      onTap: () => _scrollToBand(band, animate: true),
      excludeSemantics: true,
      child: SizedBox(
        key: _railHitKeys[band],
        width: _depthRailTargetSize,
        height: _depthRailTargetSize,
        // One focus stop per band: the IconButton owns traversal, the built-in
        // focus highlight, and Enter/Space activation.
        child: IconButton(
          key: Key('mining-depth-rail-button-${band.name}'),
          focusNode: _railFocusNodes[band],
          padding: EdgeInsets.zero,
          iconSize: 20,
          onPressed: () => _scrollToBand(band, animate: true),
          icon: _depthRailMarker(band, open),
        ),
      ),
    );
  }

  /// One distinguishable marker per band; the Motherlode keeps its sparkle,
  /// the other three use the mockup's compact letter badges. The dark disc
  /// keeps every marker legible over the full-bleed cavern.
  Widget _depthRailMarker(MiningBand band, bool open) {
    final color = !open
        ? Colors.white70
        : band == MiningBand.motherlode
        ? _upgradeGold
        : MiningTheme.accent;
    final key = Key('mining-depth-marker-${band.name}');
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xCC060A10),
        border: Border.all(color: color.withValues(alpha: open ? .8 : .35)),
      ),
      child: band == MiningBand.motherlode
          ? Icon(Icons.auto_awesome, key: key, size: 16, color: color)
          : Text(
              band.name[0].toUpperCase(),
              key: key,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final insets = widget.viewportInsets;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollBehavior = ScrollConfiguration.of(context);
        _sceneScale = math.min(
          1.0,
          constraints.maxWidth / miningGridSceneWidth,
        );
        _sceneLeft =
            (constraints.maxWidth - miningGridSceneWidth * _sceneScale) / 2;
        _scheduleInitialFrame();
        final jumpInputs = (
          size: Size(constraints.maxWidth, constraints.maxHeight),
          viewportInsets: insets,
          upperHudHitRect: widget.upperHudHitRect,
          railTop: widget.railTop,
          railBottom: widget.railBottom,
          placementSafeY: widget.placementSafeY,
          railRight: widget.railRight,
          railClearRight: widget.railClearRight,
          railBelowClearRight: widget.railBelowClearRight,
          railBelowLeft: widget.railBelowLeft,
          railBelowBottom: widget.railBelowBottom,
        );
        if (_jumpInputs != jumpInputs) {
          final previousInputs = _jumpInputs;
          final layoutChanged =
              previousInputs != null &&
              (previousInputs.size != jumpInputs.size ||
                  previousInputs.viewportInsets != jumpInputs.viewportInsets);
          final resizeTarget =
              previousInputs == null ||
                  !layoutChanged ||
                  _railJumpBand != null ||
                  !_initialFrameVisible
              ? null
              : _resizeScrollTarget(previousInputs, jumpInputs);
          if (resizeTarget != null && _scrollController.hasClients) {
            // Apply here rather than in the physics: the viewport only asks
            // the physics to correct when its extents or size change, but
            // padding can trade space without either, and the overlay below
            // must paint from the same offset as the scroll view.
            _scrollController.position.correctPixels(resizeTarget);
          }
          _jumpInputs = jumpInputs;
          _retargetPendingJump();
        }
        return Stack(
          key: const Key('mining-grid-map'),
          children: [
            Positioned.fill(child: _background()),
            Positioned.fill(
              child: Opacity(
                key: const Key('mining-grid-initial-frame-opacity'),
                opacity: _initialFrameVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_initialFrameVisible,
                  child: ScrollConfiguration(
                    // No glow/stretch: the scene is the map itself, and a
                    // transient overscroll scale would distort cell hit mapping.
                    behavior: scrollBehavior.copyWith(
                      overscroll: false,
                      dragDevices: {
                        ...scrollBehavior.dragDevices,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: SingleChildScrollView(
                      key: const Key('mining-grid-scroll'),
                      controller: _scrollController,
                      // This is a precise tap surface: a bounce would paint cells
                      // past the extent while the screen-space action rects stay
                      // clamped, so the visible cell and the hitbox would diverge.
                      physics: const ClampingScrollPhysics(
                        parent: RangeMaintainingScrollPhysics(),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: insets.top,
                          bottom: insets.bottom,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            key: const Key('mining-grid-surface'),
                            width: miningGridSceneWidth,
                            height: miningGridSceneHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              // A gesture semantics tap is synthesized at this
                              // surface's centre, so it can never carry the tapped
                              // cell. Keep physical taps here and expose the exact
                              // per-cell actions below instead.
                              excludeFromSemantics: true,
                              onTapUp: (details) => widget.onCellTap(
                                MiningGridCell(
                                  details.localPosition.dx ~/
                                      miningGridCellSize,
                                  details.localPosition.dy ~/
                                      miningGridCellSize,
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ..._motherlodeHalo(),
                                  Positioned.fill(
                                    child: IgnorePointer(child: _objectLayer()),
                                  ),
                                  ..._bandLabels(),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: MiningGridPainter(
                                          width: view.definition.gridWidth,
                                          height: view.definition.gridHeight,
                                          deployableCells: view.deployableCells,
                                          upgradeableCells:
                                              view.upgradeableCells,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Only visuals live inside the scaled scroll
                                  // content. Actionable semantics overlays are
                                  // positioned in screen space outside the
                                  // FittedBox, because Flutter web can report
                                  // scaled scrolled semantics hit areas away from
                                  // their visible cells.
                                  for (final rig in view.rigs)
                                    Positioned(
                                      key: Key(
                                        'mining-rig-chip-'
                                        '${rig.placement.cell.x}-'
                                        '${rig.placement.cell.y}',
                                      ),
                                      left:
                                          rig.placement.cell.x *
                                          miningGridCellSize,
                                      top:
                                          rig.placement.cell.y *
                                          miningGridCellSize,
                                      width: miningGridCellSize,
                                      child: IgnorePointer(
                                        child: ExcludeSemantics(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: _rigChip(rig),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: _initialFrameVisible ? 1 : 0,
                child: _screenSpaceSemantics(
                  constraints.maxWidth,
                  constraints.maxHeight,
                ),
              ),
            ),
            _depthRail(constraints.maxHeight, constraints.maxWidth),
          ],
        );
      },
    );
  }

  /// Actionable/deposit semantics in screen coordinates, above the scroll
  /// view. Flutter web can misplace semantics hit areas that live under a
  /// scaled [FittedBox] inside a scroll view, so keeping these overlays out of
  /// that transform makes each action's browser hit area match its visible
  /// cell at every scroll offset. The offset is clamped to the extent the
  /// current layout will adopt, and a resize correction is applied to the
  /// scroll position during build, so this overlay and the scroll view always
  /// read the same pixels.
  Widget _screenSpaceSemantics(double width, double height) => AnimatedBuilder(
    animation: _scrollController,
    builder: (context, _) {
      final view = widget.view;
      final selectedRig = view.selectedRig;
      final scale = _sceneScale;
      final cellSize = miningGridCellSize * scale;
      final sceneLeft = (width - miningGridSceneWidth * scale) / 2;
      final contentHeight =
          widget.viewportInsets.top +
          miningGridSceneHeight * scale +
          widget.viewportInsets.bottom;
      final maxScroll = math.max(0.0, contentHeight - height);
      final rawScroll = _scrollController.hasClients
          ? _scrollController.position.pixels
          : 0.0;
      final scroll = rawScroll.clamp(0.0, maxScroll);
      final sceneTop = widget.viewportInsets.top - scroll;
      double x(int cellX) => sceneLeft + cellX * cellSize;
      double y(int cellY) => sceneTop + cellY * cellSize;
      // This overlay is not clipped by the scroll viewport, so a cell that
      // scrolled out of view would keep an action that mutates a rig the
      // player cannot see. Deposit keys stay mounted for overlay geometry,
      // but their focusable labels follow the same visibility boundary.
      final viewport = Offset.zero & Size(width, height);
      bool onscreen(MiningGridCell cell) => Rect.fromLTWH(
        x(cell.x),
        y(cell.y),
        cellSize,
        cellSize,
      ).overlaps(viewport);
      bool depositOnscreen(MineSiteDepositView deposit) => Rect.fromLTWH(
        x(deposit.definition.x),
        y(deposit.definition.y),
        deposit.definition.size * cellSize,
        deposit.definition.size * cellSize,
      ).overlaps(viewport);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // One label per authored deposit, exactly as inside the old overlay.
          for (final deposit in view.deposits)
            Positioned(
              key: Key('mining-deposit-${_depositKey(deposit.definition)}'),
              left: x(deposit.definition.x),
              top: y(deposit.definition.y),
              width: deposit.definition.size * cellSize,
              height: deposit.definition.size * cellSize,
              child: IgnorePointer(
                child: depositOnscreen(deposit)
                    ? Semantics(
                        label: _depositLabel(deposit),
                        child: const SizedBox.expand(),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          // A legal target owns its exact assistive-tech action. The map
          // gesture surface exposes no tap action, so activation can never
          // fall back to a meaningless surface-centre cell.
          if (selectedRig != null)
            for (final cell in view.deployableCells.where(onscreen))
              Positioned(
                key: Key('mining-deploy-cell-${cell.x}-${cell.y}'),
                left: x(cell.x),
                top: y(cell.y),
                width: cellSize,
                height: cellSize,
                child: Semantics(
                  container: true,
                  button: true,
                  enabled: true,
                  label:
                      'Place ${selectedRig.name.toUpperCase()} rig at '
                      '(${cell.x},${cell.y}).',
                  onTap: () => widget.onCellTap(cell),
                  // Pointer transparency keeps physical taps on the map-level
                  // surface while the semantic action survives.
                  child: IgnorePointer(child: const SizedBox.expand()),
                ),
              ),
          for (final rig in view.rigs.where(
            (rig) => onscreen(rig.placement.cell),
          ))
            Positioned(
              key: Key(
                'mining-rig-action-'
                '${rig.placement.cell.x}-'
                '${rig.placement.cell.y}',
              ),
              left: x(rig.placement.cell.x),
              top: y(rig.placement.cell.y),
              width: cellSize,
              height: cellSize,
              child: Semantics(
                button: true,
                enabled: selectedRig != null
                    ? rig.canUpgradeWithSelection
                    : rig.canRecall,
                label: _rigLabel(rig),
                onTap: () => widget.onCellTap(rig.placement.cell),
                child: IgnorePointer(child: const SizedBox.expand()),
              ),
            ),
        ],
      );
    },
  );

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
    final base =
        '${rig.placement.tier.name.toUpperCase()} rig at '
        '(${rig.placement.cell.x},${rig.placement.cell.y}) mining '
        'deposit (${rig.target.x},${rig.target.y}).';
    if (widget.view.selectedRig != null) {
      if (rig.canUpgradeWithSelection) {
        final next = RigTier.values[rig.placement.tier.index + 1];
        return '$base Upgrade to ${next.name.toUpperCase()}.';
      }
      return '$base ${rig.upgradeFailure}';
    }
    final reason = rig.disabledReason;
    return '$base${reason == null ? '' : ' $reason'}';
  }

  /// The one tier chip for a placed rig: its tier, or the gold `Tn→Tn+1` of
  /// the same chip when this rig's cell is already an upgrade target.
  Widget _rigChip(MineSiteRigView rig) {
    final upgradeable = widget.view.upgradeableCells.contains(
      rig.placement.cell,
    );
    final tier = rig.placement.tier;
    final label = upgradeable
        ? '${tier.name.toUpperCase()}→'
              '${RigTier.values[tier.index + 1].name.toUpperCase()}'
        : tier.name.toUpperCase();
    return Container(
      height: miningRigChipHeight,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: upgradeable ? _upgradeGold : MiningTheme.hudPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: upgradeable ? _upgradeGold : Colors.white24),
      ),
      // The label shrinks to fit the fixed anchor at large text scales; the
      // capped label box keeps the intrinsic chip narrower than the cell, so
      // the map's outer FittedBox never scales the chip's height down.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _rigChipLabelMaxWidth),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: upgradeable ? _upgradeInk : MiningTheme.primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
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
    required this.upgradeableCells,
  });

  final int width;
  final int height;
  final Set<MiningGridCell> deployableCells;
  final Set<MiningGridCell> upgradeableCells;

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
    final upgradeRing = Paint()
      ..color = _upgradeGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final cellPos in upgradeableCells) {
      canvas.drawRect(
        Rect.fromLTWH(
          cellPos.x * cell,
          cellPos.y * cell,
          cell,
          cell,
        ).deflate(1),
        upgradeRing,
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
      !setEquals(oldDelegate.deployableCells, deployableCells) ||
      !setEquals(oldDelegate.upgradeableCells, upgradeableCells);
}
