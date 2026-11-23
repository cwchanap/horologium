import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/presentation/animated_mining_grid_visual_layer.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

const double miningGridCellSize = 56;
const int miningGridWidth = 8;
const int miningGridHeight = 22;
const double miningGridSceneWidth = miningGridWidth * miningGridCellSize;
const double miningGridSceneHeight = miningGridHeight * miningGridCellSize;

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
    this.railTop = 0,
    this.railBottom = double.infinity,
    this.railRight = 8,
  });

  final MineSiteView view;
  final ValueChanged<MiningGridCell> onCellTap;
  final int impactSequence;
  final VoidCallback? onMiningImpact;
  final bool reducedMotion;

  /// Vertical scroll clearance around the map scene. The left/right values
  /// are ignored: the map keeps the full viewport width so the 8-cell scene
  /// can scale down instead of shrinking under HUD columns.
  final EdgeInsets viewportInsets;

  /// Vertical span and right inset of the depth rail in the map's local
  /// coordinates, supplied by the screen so the rail stays between the cargo
  /// gauge and the Sell/bottom chrome.
  final double railTop;
  final double railBottom;
  final double railRight;

  @override
  State<MiningGridMap> createState() => _MiningGridMapState();
}

class _MiningGridMapState extends State<MiningGridMap> {
  final ScrollController _scrollController = ScrollController();
  bool _framed = false;
  double _sceneScale = 1;
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

  /// One scroll path for the once-per-entry frame and every rail tap. The
  /// target is the specified scale-aware row offset
  /// `topPadding + labelRow * 56 * min(1, width / 448)`, clamped to the valid
  /// scroll extent; an unscaled logical offset would overshoot on phones.
  void _scrollToBand(MiningBand band, {required bool animate}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target =
        (widget.viewportInsets.top +
                band.labelRow * miningGridCellSize * _sceneScale)
            .clamp(0.0, math.max(0.0, position.maxScrollExtent))
            .toDouble();
    if (animate && !widget.reducedMotion) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
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
                        '${band.label.toUpperCase()} · '
                        '${band.footprint}-cell ore',
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

  /// Four depth-rail targets on the viewport's right edge. The column is
  /// sized to its buttons so the rest of the rail region is pointer
  /// transparent, and each target keeps a full 44dp hit region.
  Widget _depthRail(double viewportHeight, double viewportWidth) {
    final top = widget.railTop.clamp(0.0, viewportHeight);
    final requestedBottom = widget.railBottom.isFinite
        ? widget.railBottom
        : viewportHeight;
    final bottom = requestedBottom.clamp(top, viewportHeight);
    final height = bottom - top;
    // Four 44dp targets need 176dp to sit in one column without overlap.
    // Above that threshold the gaps shrink from 16dp to zero first. A shorter
    // clear band keeps the targets high in a horizontal row, which leaves the
    // bottom-right cell clear; both arrangements stay inside the HUD bounds
    // and only the targets intercept pointers.
    final vertical = height >= 176;
    final gap = vertical
        ? ((height - 176) / 3).clamp(0.0, 16.0)
        : (viewportWidth - widget.railRight >= 4 * _depthRailTargetSize + 3 * 8
              ? 8.0
              : 0.0);
    final railWidth = vertical
        ? _depthRailTargetSize
        : 4 * _depthRailTargetSize + 3 * gap;
    final railHeight = vertical
        ? math.min(height, 176 + gap * 3)
        : _depthRailTargetSize;
    // shortcut: a clear band or viewport narrower than one 44dp row cannot
    // fit; no tested viewport reaches that, revisit with HPA-1244's rail.
    return Positioned(
      key: const Key('mining-depth-rail'),
      top: top,
      height: railHeight,
      right: widget.railRight,
      child: SizedBox(
        width: railWidth,
        height: railHeight,
        child: Stack(
          children: [
            for (final (index, band) in _depthRailBands.indexed)
              Positioned(
                top: vertical ? index * (_depthRailTargetSize + gap) : 0,
                left: vertical ? 0 : index * (_depthRailTargetSize + gap),
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
        width: _depthRailTargetSize,
        height: _depthRailTargetSize,
        child: Focus(
          key: Key('mining-depth-rail-focus-${band.name}'),
          focusNode: _railFocusNodes[band],
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key != LogicalKeyboardKey.enter &&
                key != LogicalKeyboardKey.space) {
              return KeyEventResult.ignored;
            }
            _scrollToBand(band, animate: true);
            return KeyEventResult.handled;
          },
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            onPressed: () => _scrollToBand(band, animate: true),
            icon: _depthRailMarker(band, open),
          ),
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
        _sceneScale = math.min(
          1.0,
          constraints.maxWidth / miningGridSceneWidth,
        );
        _scheduleInitialFrame();
        return Stack(
          key: const Key('mining-grid-map'),
          children: [
            Positioned.fill(child: _background()),
            Positioned.fill(
              child: ScrollConfiguration(
                // No glow/stretch: the scene is the map itself, and a
                // transient overscroll scale would distort cell hit mapping.
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(overscroll: false),
                child: SingleChildScrollView(
                  key: const Key('mining-grid-scroll'),
                  controller: _scrollController,
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
                          onTapUp: (details) => widget.onCellTap(
                            MiningGridCell(
                              details.localPosition.dx ~/ miningGridCellSize,
                              details.localPosition.dy ~/ miningGridCellSize,
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
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
                                      upgradeableCells: view.upgradeableCells,
                                    ),
                                  ),
                                ),
                              ),
                              // Object overlays: exactly one semantics overlay per
                              // authored deposit and at most one per deployed rig.
                              // These are not tile widgets; empty cells render
                              // nothing.
                              for (final deposit in view.deposits)
                                Positioned(
                                  key: Key(
                                    'mining-deposit-'
                                    '${_depositKey(deposit.definition)}',
                                  ),
                                  left:
                                      deposit.definition.x * miningGridCellSize,
                                  top:
                                      deposit.definition.y * miningGridCellSize,
                                  width:
                                      deposit.definition.size *
                                      miningGridCellSize,
                                  height:
                                      deposit.definition.size *
                                      miningGridCellSize,
                                  child: IgnorePointer(
                                    child: Semantics(
                                      label: _depositLabel(deposit),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                              for (final rig in view.rigs) ...[
                                Positioned(
                                  key: Key(
                                    'mining-rig-chip-'
                                    '${rig.placement.cell.x}-'
                                    '${rig.placement.cell.y}',
                                  ),
                                  left:
                                      rig.placement.cell.x * miningGridCellSize,
                                  top:
                                      rig.placement.cell.y * miningGridCellSize,
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
                                Positioned(
                                  left:
                                      rig.placement.cell.x * miningGridCellSize,
                                  top:
                                      rig.placement.cell.y * miningGridCellSize,
                                  width: miningGridCellSize,
                                  height: miningGridCellSize,
                                  child: Semantics(
                                    button: true,
                                    enabled: view.selectedRig != null
                                        ? rig.canUpgradeWithSelection
                                        : rig.canRecall,
                                    label: _rigLabel(rig),
                                    onTap: () =>
                                        widget.onCellTap(rig.placement.cell),
                                    // IgnorePointer sits below the Semantics node
                                    // so physical taps stay with the map-level
                                    // gesture surface while the semantic tap
                                    // action survives for assistive tech.
                                    child: IgnorePointer(
                                      child: const SizedBox.expand(),
                                    ),
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
              ),
            ),
            _depthRail(constraints.maxHeight, constraints.maxWidth),
          ],
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
