import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/presentation/fleet_dock.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

// Mine Site chrome placement shared by the Stack children and the
// unoccluded pan band handed to MiningGridMap.viewportInsets: every offset
// that hides the cavern has exactly one constant, so chrome cannot silently
// cover legal grid cells. Heights reference the fixed sizes owned by
// MiningCashChip, _MineChromeButton, MiningNavigationBar, and the
// horizontal FleetDock.
const double _portraitCashChipTop = 54;
const double _portraitBackTop = 146;
const double _portraitBackLeft = 14;
const double _portraitBackWidth = _MineChromeButton.width;
const double _portraitCargoTop = 50;
const double _portraitCargoRight = 12;
const double _portraitCargoSize = 84;
const double _portraitDockHorizontalMargin = 12;
const double _portraitDockBottom = 100;
const double _portraitDockHeight = FleetDock.horizontalHeight;
const double _portraitSellDockGap = 8;
const double _portraitNavHeight = MiningNavigationBar.height;
const double _landscapeCashChipTop = 52;
const double _landscapeCargoTop = 52;
const double _landscapeCargoRight = 14;
const double _landscapeCargoSize = 74;
const double _landscapeToolbarLeft = 12;
const double _landscapeToolbarBottom = 16;
const double _landscapeToolbarWidth = 252;
const double _landscapeToolbarHeight = MiningNavigationBar.compactHeight;

/// Width of the landscape dock rail. Shared with MiningShell so the
/// pass-through result panel keeps its rendered right edge left of the rail.
const double landscapeRightRailWidth = 104;
const double _landscapeSellBottom = 78;
const double _landscapeSellHeight = 79;
const double _portraitSellRight = 18;
const double _portraitSellHexWidth = 64;
const double _sellLabelGap = 5;
const double _sellHexHeightPortrait = 70;
const double _sellHexHeightLandscape = 62;

/// Screen-space gap below the portrait Sell column that the map's bottom
/// scroll padding and depth rail both clear.
const double _portraitMapSellGap = 12;

class MineSiteScreen extends StatelessWidget {
  const MineSiteScreen({
    super.key,
    required this.view,
    required this.fleetDock,
    required this.onGridCellTap,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onBuildRig,
    required this.onSellCargo,
    required this.onBack,
    required this.onSettings,
    this.onDestinationSelected,
    this.cash = 0,
    this.reducedMotion = false,
    this.impactSequence = 0,
    this.onMiningImpact,
  });

  final MineSiteView view;
  final FleetDockView fleetDock;
  final ValueChanged<MiningGridCell> onGridCellTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final ValueChanged<RigTier> onBuildRig;
  final VoidCallback onSellCargo;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final ValueChanged<MiningNavigationDestination>? onDestinationSelected;
  final int cash;
  final bool reducedMotion;
  final int impactSequence;
  final VoidCallback? onMiningImpact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        return landscape
            ? _LandscapeMineSite(
                view: view,
                fleetDock: fleetDock,
                cash: cash,
                reducedMotion: reducedMotion,
                impactSequence: impactSequence,
                onMiningImpact: onMiningImpact,
                onGridCellTap: onGridCellTap,
                onBayTap: onBayTap,
                onSpawnRig: onSpawnRig,
                onBuildRig: onBuildRig,
                onSellCargo: onSellCargo,
                onBack: onBack,
                onSettings: onSettings,
                onDestinationSelected: onDestinationSelected,
              )
            : _PortraitMineSite(
                view: view,
                fleetDock: fleetDock,
                cash: cash,
                reducedMotion: reducedMotion,
                impactSequence: impactSequence,
                onMiningImpact: onMiningImpact,
                onGridCellTap: onGridCellTap,
                onBayTap: onBayTap,
                onSpawnRig: onSpawnRig,
                onBuildRig: onBuildRig,
                onSellCargo: onSellCargo,
                onBack: onBack,
                onSettings: onSettings,
                onDestinationSelected: onDestinationSelected,
              );
      },
    );
  }
}

class _PortraitMineSite extends StatelessWidget {
  const _PortraitMineSite({
    required this.view,
    required this.fleetDock,
    required this.cash,
    required this.reducedMotion,
    required this.impactSequence,
    this.onMiningImpact,
    required this.onGridCellTap,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onBuildRig,
    required this.onSellCargo,
    required this.onBack,
    required this.onSettings,
    required this.onDestinationSelected,
  });

  final MineSiteView view;
  final FleetDockView fleetDock;
  final int cash;
  final bool reducedMotion;
  final int impactSequence;
  final VoidCallback? onMiningImpact;
  final ValueChanged<MiningGridCell> onGridCellTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final ValueChanged<RigTier> onBuildRig;
  final VoidCallback onSellCargo;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final ValueChanged<MiningNavigationDestination>? onDestinationSelected;

  void _navigate(MiningNavigationDestination destination) {
    if (destination == MiningNavigationDestination.settings) {
      onSettings();
      return;
    }
    final callback = onDestinationSelected;
    if (callback != null) {
      callback(destination);
      return;
    }
    switch (destination) {
      case MiningNavigationDestination.siteDeck:
        onBack();
        break;
      case MiningNavigationDestination.settings:
        onSettings();
        break;
      case MiningNavigationDestination.technology:
      case MiningNavigationDestination.stellarMap:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve well past the dock/nav: the Sell column sits above the dock,
        // so the bottom scroll padding must clear its scaled label height too.
        final sellTop = portraitMineSellTop(
          constraints.maxHeight,
          pad.bottom,
          MediaQuery.textScalerOf(context),
          Theme.of(context).textTheme.bodyMedium,
        );
        final viewportInsets = EdgeInsets.fromLTRB(
          pad.left + _portraitBackLeft + _portraitBackWidth,
          pad.top + _portraitCargoTop + _portraitCargoSize,
          pad.right + _portraitCargoRight + _portraitCargoSize,
          math.max(
            pad.bottom + _portraitNavHeight,
            constraints.maxHeight - sellTop + _portraitMapSellGap,
          ),
        );
        return ColoredBox(
          key: const Key('mine-site-screen'),
          color: const Color(0xFF0A1218),
          child: Stack(
            children: [
              Positioned.fill(
                child: _CavernScene(
                  view: view,
                  landscape: false,
                  reducedMotion: reducedMotion,
                  impactSequence: impactSequence,
                  onMiningImpact: onMiningImpact,
                  onGridCellTap: onGridCellTap,
                  onSellCargo: onSellCargo,
                  portraitTopInset: pad.top,
                  viewportInsets: viewportInsets,
                ),
              ),
              Positioned(
                top: _portraitCashChipTop + pad.top,
                left: 0,
                child: MiningCashChip(cash: cash),
              ),
              Positioned(
                top: _portraitBackTop + pad.top,
                left: _portraitBackLeft,
                child: _MineChromeButton(
                  key: const Key('mine-site-back'),
                  icon: Icons.chevron_left_rounded,
                  label: 'Back to Site Deck',
                  onPressed: onBack,
                ),
              ),
              Positioned(
                left: _portraitDockHorizontalMargin,
                right: _portraitDockHorizontalMargin,
                bottom: _portraitDockBottom + pad.bottom,
                child: FleetDock(
                  view: fleetDock,
                  axis: FleetDockAxis.horizontal,
                  onBayTap: onBayTap,
                  onSpawnRig: onSpawnRig,
                  onBuildRig: onBuildRig,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: pad.bottom,
                child: MiningNavigationBar(
                  selected: MiningNavigationDestination.siteDeck,
                  onDestinationSelected: _navigate,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LandscapeMineSite extends StatelessWidget {
  const _LandscapeMineSite({
    required this.view,
    required this.fleetDock,
    required this.cash,
    required this.reducedMotion,
    required this.impactSequence,
    this.onMiningImpact,
    required this.onGridCellTap,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onBuildRig,
    required this.onSellCargo,
    required this.onBack,
    required this.onSettings,
    required this.onDestinationSelected,
  });

  final MineSiteView view;
  final FleetDockView fleetDock;
  final int cash;
  final bool reducedMotion;
  final int impactSequence;
  final VoidCallback? onMiningImpact;
  final ValueChanged<MiningGridCell> onGridCellTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final ValueChanged<RigTier> onBuildRig;
  final VoidCallback onSellCargo;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final ValueChanged<MiningNavigationDestination>? onDestinationSelected;

  void _navigate(MiningNavigationDestination destination) {
    if (destination == MiningNavigationDestination.siteDeck) {
      onBack();
    } else if (destination == MiningNavigationDestination.settings) {
      onSettings();
    } else {
      onDestinationSelected?.call(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final viewportInsets = EdgeInsets.fromLTRB(
      pad.left,
      math.max(pad.top, _landscapeCargoTop + _landscapeCargoSize),
      _landscapeCargoRight + _landscapeCargoSize,
      pad.bottom +
          math.max(
            _landscapeToolbarBottom + _landscapeToolbarHeight,
            _landscapeSellBottom + _landscapeSellHeight,
          ),
    );
    return ColoredBox(
      key: const Key('mine-site-screen'),
      color: const Color(0xFF07111E),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: landscapeRightRailWidth + pad.right,
            bottom: 0,
            child: _CavernScene(
              view: view,
              landscape: true,
              reducedMotion: reducedMotion,
              impactSequence: impactSequence,
              onMiningImpact: onMiningImpact,
              onGridCellTap: onGridCellTap,
              onSellCargo: onSellCargo,
              viewportInsets: viewportInsets,
            ),
          ),
          Positioned(
            top: _landscapeCashChipTop,
            left: pad.left,
            child: MiningCashChip(cash: cash, compact: true),
          ),
          Positioned(
            left: _landscapeToolbarLeft + pad.left,
            bottom: _landscapeToolbarBottom + pad.bottom,
            width: _landscapeToolbarWidth,
            height: _landscapeToolbarHeight,
            child: SizedBox(
              key: const Key('mine-site-toolbar'),
              child: MiningNavigationBar(
                compact: true,
                selected: MiningNavigationDestination.siteDeck,
                onDestinationSelected: _navigate,
              ),
            ),
          ),
          Positioned(
            key: const Key('mine-site-right-rail'),
            top: 0,
            right: pad.right,
            bottom: 0,
            width: landscapeRightRailWidth,
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(6, 10, 16, .92),
                border: Border(
                  left: BorderSide(color: Color.fromRGBO(83, 212, 232, .24)),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: pad.bottom),
                child: FleetDock(
                  view: fleetDock,
                  axis: FleetDockAxis.vertical,
                  onBayTap: onBayTap,
                  onSpawnRig: onSpawnRig,
                  onBuildRig: onBuildRig,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CavernScene extends StatelessWidget {
  const _CavernScene({
    required this.view,
    required this.landscape,
    required this.reducedMotion,
    required this.impactSequence,
    this.onMiningImpact,
    required this.onGridCellTap,
    required this.onSellCargo,
    this.portraitTopInset = 0,
    this.viewportInsets = EdgeInsets.zero,
  });

  final MineSiteView view;
  final bool landscape;
  final bool reducedMotion;
  final int impactSequence;
  final VoidCallback? onMiningImpact;
  final ValueChanged<MiningGridCell> onGridCellTap;
  final VoidCallback onSellCargo;
  final double portraitTopInset;
  final EdgeInsets viewportInsets;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sellTop = landscape
            ? null
            : portraitMineSellTop(
                constraints.maxHeight,
                padding.bottom,
                MediaQuery.textScalerOf(context),
                Theme.of(context).textTheme.bodyMedium,
              );
        return Stack(
          children: [
            Positioned.fill(
              child: _MineCavern(
                view: view,
                landscape: landscape,
                reducedMotion: reducedMotion,
                impactSequence: impactSequence,
                onMiningImpact: onMiningImpact,
                onGridCellTap: onGridCellTap,
                viewportInsets: viewportInsets,
                cavernWidth: constraints.maxWidth,
                railTop: landscape
                    ? math.max(
                        padding.top,
                        _landscapeCargoTop + _landscapeCargoSize,
                      )
                    : padding.top + _portraitCargoTop + _portraitCargoSize,
                railBottom: landscape
                    ? constraints.maxHeight - padding.bottom
                    : sellTop! - _portraitMapSellGap,
                railRight: landscape ? 8 : padding.right + 8,
              ),
            ),
            Positioned(
              top: landscape
                  ? _landscapeCargoTop
                  : _portraitCargoTop + portraitTopInset,
              right: landscape ? _landscapeCargoRight : _portraitCargoRight,
              child: MiningCargoGauge(
                containerKey: const Key('mine-site-cargo'),
                cargo: view.cargo,
                capacity: view.capacity,
                projectedValue: view.activePlanetProjectedSale,
                size: landscape ? _landscapeCargoSize : _portraitCargoSize,
                rate: view.rate,
              ),
            ),
            Positioned(
              left: landscape
                  ? _landscapeX(236, .34, constraints.maxWidth)
                  : null,
              right: landscape ? null : _portraitSellRight,
              bottom: landscape
                  ? _landscapeSellBottom
                  : MediaQuery.paddingOf(context).bottom +
                        _portraitDockBottom +
                        _portraitDockHeight +
                        _portraitSellDockGap,
              child: _SellControl(
                view: view,
                compact: landscape,
                onSellCargo: onSellCargo,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MineCavern extends StatelessWidget {
  const _MineCavern({
    required this.view,
    required this.landscape,
    required this.reducedMotion,
    required this.impactSequence,
    this.onMiningImpact,
    required this.onGridCellTap,
    this.viewportInsets = EdgeInsets.zero,
    this.cavernWidth = 0,
    this.railTop = 0,
    this.railBottom = double.infinity,
    this.railRight = 8,
  });

  final MineSiteView view;
  final bool landscape;
  final bool reducedMotion;
  final int impactSequence;
  final VoidCallback? onMiningImpact;
  final ValueChanged<MiningGridCell> onGridCellTap;
  final EdgeInsets viewportInsets;
  final double cavernWidth;
  final double railTop;
  final double railBottom;
  final double railRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mine-site-cavern'),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Color(0xFF101C2A)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MiningGridMap(
            key: ValueKey(view.siteId),
            view: view,
            onCellTap: onGridCellTap,
            impactSequence: impactSequence,
            onMiningImpact: onMiningImpact,
            reducedMotion: reducedMotion,
            viewportInsets: viewportInsets,
            railTop: railTop,
            railBottom: railBottom,
            railRight: railRight,
          ),
          if (!landscape) ...[
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 180,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromRGBO(6, 10, 16, .85),
                        Color.fromRGBO(6, 10, 16, .3),
                        Color.fromRGBO(6, 10, 16, 0),
                      ],
                      stops: [0, .66, 1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 290,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromRGBO(6, 10, 16, .95),
                        Color.fromRGBO(6, 10, 16, .62),
                        Color.fromRGBO(6, 10, 16, 0),
                      ],
                      stops: [0, .48, 1],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(6, 10, 16, .9),
                      Color.fromRGBO(6, 10, 16, .28),
                      Color.fromRGBO(6, 10, 16, .32),
                      Color.fromRGBO(6, 10, 16, .92),
                    ],
                    stops: [0, .24, .62, 1],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SellControl extends StatelessWidget {
  const _SellControl({
    required this.view,
    required this.compact,
    required this.onSellCargo,
  });

  final MineSiteView view;
  final bool compact;
  final VoidCallback onSellCargo;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    enabled: view.canSell,
    label: view.sale.label,
    onTap: view.canSell ? onSellCargo : null,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 56 : _portraitSellHexWidth,
          height: compact ? _sellHexHeightLandscape : _sellHexHeightPortrait,
          child: MiningHex(
            fill: const Color(0xEB060A10),
            border: MiningTheme.warning,
            child: OutlinedButton(
              key: const Key('mine-site-sell'),
              onPressed: view.canSell ? onSellCargo : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                fixedSize: Size(compact ? 56 : 64, compact ? 62 : 70),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide.none,
                shape: const RoundedRectangleBorder(),
              ),
              child: Image.asset(
                MiningVisuals.cargoIcon,
                width: 38,
                height: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: _sellLabelGap),
        Text(
          '+${formatMiningCash(view.sale.projectedValue)}',
          style: _sellLabelStyle(compact: compact),
        ),
      ],
    ),
  );
}

// Keep the proven compact layout through 667px, then expand to the mock's
// percentage anchors at 874px. The 104px dock is outside cavernWidth.
double _landscapeX(double compact, double fraction, double cavernWidth) {
  if (cavernWidth <= 563) return compact;
  if (cavernWidth < 770) {
    final reference = 14 + 756 * fraction;
    return compact + (reference - compact) * (cavernWidth - 563) / 207;
  }
  return 14 + (cavernWidth - 14) * fraction;
}

/// Left edge of the landscape Sell control, whose cavern region spans from
/// x=0 to the dock rail. Shared with MiningShell so the pass-through result
/// panel can step right of the Sell when a multiline message would reach it.
double landscapeMineSellLeft(double cavernWidth) =>
    _landscapeX(236, .34, cavernWidth);

/// Minimum rendered width of the landscape Sell control: the 56px hex plus
/// room for the projected-value label. The label is measured at the current
/// text scale because it can outgrow this width.
const double landscapeMineSellWidth = 96;

/// Style of the Sell control's projected-value label, shared by the widget and
/// the result-panel clearance measurement so the two cannot drift.
TextStyle _sellLabelStyle({required bool compact}) => TextStyle(
  color: MiningTheme.warning,
  fontSize: compact ? 12 : 14,
  fontWeight: FontWeight.w800,
);

/// Longest label [formatMiningCash] emits for this game's cash range:
/// `+999,999`, `+999.99M`, or `+999.99B`.
const _worstCaseSellLabel = '+999.99M';

TextPainter _sellLabelPainter({
  required bool compact,
  required TextScaler textScaler,
  TextStyle? baseStyle,
}) => TextPainter(
  text: TextSpan(
    text: _worstCaseSellLabel,
    // The label inherits the ambient DefaultTextStyle; merge the authored
    // size and weight over it exactly as the Text widget does.
    style: (baseStyle ?? const TextStyle()).merge(
      _sellLabelStyle(compact: compact),
    ),
  ),
  textDirection: TextDirection.ltr,
  textScaler: textScaler,
)..layout();

double _sellLabelHeight({
  required bool compact,
  required TextScaler textScaler,
  TextStyle? baseStyle,
}) {
  final painter = _sellLabelPainter(
    compact: compact,
    textScaler: textScaler,
    baseStyle: baseStyle,
  );
  final height = painter.height;
  painter.dispose();
  return height;
}

double _sellLabelWidth({
  required bool compact,
  required TextScaler textScaler,
  TextStyle? baseStyle,
}) {
  final painter = _sellLabelPainter(
    compact: compact,
    textScaler: textScaler,
    baseStyle: baseStyle,
  );
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Rendered width of the landscape Sell column at [textScaler], so the result
/// panel can step right of the label even when it outgrows the hex.
double landscapeMineSellGuardWidth(
  TextScaler textScaler, [
  TextStyle? baseStyle,
]) => math.max(
  landscapeMineSellWidth,
  _sellLabelWidth(compact: true, textScaler: textScaler, baseStyle: baseStyle),
);

/// Top edge of the landscape Sell control's column — its button top, hex and
/// projected-value label included — as far as the pass-through result panel
/// must stay clear. The control anchors to the viewport bottom without a
/// bottom safe-area inset, so [height] is the only input. The label's height
/// scales with [textScaler], so the guard is measured, not fixed. Shared with
/// MiningShell so the panel can step right of the Sell when a multiline
/// message would reach it.
double landscapeMineSellTop(
  double height,
  TextScaler textScaler, [
  TextStyle? baseStyle,
]) =>
    height -
    _landscapeSellBottom -
    (_sellHexHeightLandscape +
        _sellLabelGap +
        _sellLabelHeight(
          compact: true,
          textScaler: textScaler,
          baseStyle: baseStyle,
        ));

/// Top edge of the portrait Sell control's column, which sits above the dock.
/// [bottomInset] is the safe-area bottom the control is anchored above. Shared
/// with MiningShell so the result panel stays above the scalable label.
double portraitMineSellTop(
  double height,
  double bottomInset,
  TextScaler textScaler, [
  TextStyle? baseStyle,
]) =>
    height -
    bottomInset -
    _portraitDockBottom -
    _portraitDockHeight -
    _portraitSellDockGap -
    (_sellHexHeightPortrait +
        _sellLabelGap +
        _sellLabelHeight(
          compact: false,
          textScaler: textScaler,
          baseStyle: baseStyle,
        ));

/// Left edge of the portrait Sell column, which pins [_portraitSellRight]
/// off the viewport's right edge and is as wide as its hex or its scaled
/// label, whichever is wider. Shared with MiningShell so the pass-through
/// result panel's portrait fallback stays left of the column.
double portraitMineSellLeft(
  double width,
  TextScaler textScaler, [
  TextStyle? baseStyle,
]) =>
    width -
    _portraitSellRight -
    math.max(
      _portraitSellHexWidth,
      _sellLabelWidth(
        compact: false,
        textScaler: textScaler,
        baseStyle: baseStyle,
      ),
    );

/// Top edge of the portrait fleet dock, which sits above the navigation
/// bar. Shared with MiningShell so the result panel's portrait fallback
/// stays above it.
double portraitMineDockTop(double height, double bottomInset) =>
    height - bottomInset - _portraitDockBottom - _portraitDockHeight;

/// Bottom edge of the portrait back chrome button. Shared with MiningShell
/// so the result panel's portrait fallback starts below it — and below the
/// cash chip, which always ends higher (54 + 46 < 146 + 48).
double portraitMineBackBottom(double topInset) =>
    topInset + _portraitBackTop + _MineChromeButton.height;

/// Bottom edge of the landscape cargo gauge, which pins to the cavern's
/// right edge — inside the strip the pass-through result panel steps into.
/// Shared with MiningShell so a raised stepped panel stays below it.
const double landscapeMineCargoBottom =
    _landscapeCargoTop + _landscapeCargoSize;

/// Bottom edge of the landscape cash chip, which pins to the safe-area left.
/// Shared with MiningShell so a result panel anchored left of the Sell stays
/// below it.
const double landscapeMineCashChipBottom =
    _landscapeCashChipTop + MiningCashChip.compactHeight;

/// Top edge of the landscape compact nav toolbar. Shared with MiningShell so
/// a result panel anchored left of the Sell stays above it.
double landscapeMineNavTop(double height, double bottomInset) =>
    height - bottomInset - _landscapeToolbarBottom - _landscapeToolbarHeight;

class _MineChromeButton extends StatelessWidget {
  const _MineChromeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const double width = 44;
  static const double height = 48;

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: MiningHex(
      fill: const Color.fromRGBO(6, 10, 16, .82),
      border: const Color.fromRGBO(83, 212, 232, .32),
      onTap: onPressed,
      semanticLabel: label,
      child: Icon(icon, color: MiningTheme.accent, size: 22),
    ),
  );
}
