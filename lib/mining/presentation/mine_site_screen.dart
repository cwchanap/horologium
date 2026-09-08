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

class MineSiteScreen extends StatelessWidget {
  const MineSiteScreen({
    super.key,
    required this.view,
    required this.fleetDock,
    required this.onGridCellTap,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onSellCargo,
    required this.onBack,
    required this.onSettings,
    this.onDestinationSelected,
    this.cash = 0,
    this.reducedMotion = false,
    this.impactSequence = 0,
  });

  final MineSiteView view;
  final FleetDockView fleetDock;
  final ValueChanged<MiningGridCell> onGridCellTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final VoidCallback onSellCargo;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final ValueChanged<MiningNavigationDestination>? onDestinationSelected;
  final int cash;
  final bool reducedMotion;
  final int impactSequence;

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
                onGridCellTap: onGridCellTap,
                onBayTap: onBayTap,
                onSpawnRig: onSpawnRig,
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
                onGridCellTap: onGridCellTap,
                onBayTap: onBayTap,
                onSpawnRig: onSpawnRig,
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
    required this.onGridCellTap,
    required this.onBayTap,
    required this.onSpawnRig,
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
  final ValueChanged<MiningGridCell> onGridCellTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
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
    return ColoredBox(
      key: const Key('mine-site-screen'),
      color: const Color(0xFF0A1218),
      child: Stack(
        children: [
          Positioned.fill(
            child: _CavernScene(
              view: view,
              reducedMotion: reducedMotion,
              impactSequence: impactSequence,
              onGridCellTap: onGridCellTap,
              onSellCargo: onSellCargo,
              portraitTopInset: pad.top,
            ),
          ),
          Positioned(
            top: 54 + pad.top,
            left: 0,
            child: MiningCashChip(cash: cash),
          ),
          Positioned(
            top: 146 + pad.top,
            left: 14,
            child: _MineChromeButton(
              key: const Key('mine-site-back'),
              icon: Icons.chevron_left_rounded,
              label: 'Back to Site Deck',
              onPressed: onBack,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 100 + pad.bottom,
            child: FleetDock(
              view: fleetDock,
              axis: FleetDockAxis.horizontal,
              onBayTap: onBayTap,
              onSpawnRig: onSpawnRig,
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
  }
}

class _LandscapeMineSite extends StatelessWidget {
  const _LandscapeMineSite({
    required this.view,
    required this.fleetDock,
    required this.cash,
    required this.reducedMotion,
    required this.impactSequence,
    required this.onGridCellTap,
    required this.onBayTap,
    required this.onSpawnRig,
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
  final ValueChanged<MiningGridCell> onGridCellTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
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
    return ColoredBox(
      key: const Key('mine-site-screen'),
      color: const Color(0xFF07111E),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 104 + pad.right,
            bottom: 0,
            child: _CavernScene(
              view: view,
              reducedMotion: reducedMotion,
              impactSequence: impactSequence,
              onGridCellTap: onGridCellTap,
              onSellCargo: onSellCargo,
              landscapeLeftInset: pad.left,
            ),
          ),
          Positioned(
            top: 52,
            left: pad.left,
            child: MiningCashChip(cash: cash, compact: true),
          ),
          Positioned(
            left: 12 + pad.left,
            bottom: 16 + pad.bottom,
            width: 252,
            height: 54,
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
            width: 104,
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
    required this.reducedMotion,
    required this.impactSequence,
    required this.onGridCellTap,
    required this.onSellCargo,
    this.portraitTopInset = 0,
    this.landscapeLeftInset = 0,
  });

  final MineSiteView view;
  final bool reducedMotion;
  final int impactSequence;
  final ValueChanged<MiningGridCell> onGridCellTap;
  final VoidCallback onSellCargo;
  final double portraitTopInset;
  final double landscapeLeftInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: _MineCavern(
                view: view,
                landscape: landscape,
                reducedMotion: reducedMotion,
                impactSequence: impactSequence,
                onGridCellTap: onGridCellTap,
                landscapeLeftInset: landscapeLeftInset,
                cavernWidth: constraints.maxWidth,
              ),
            ),
            Positioned(
              top: landscape ? 52 : 50 + portraitTopInset,
              right: landscape ? 14 : 12,
              child: MiningCargoGauge(
                containerKey: const Key('mine-site-cargo'),
                cargo: view.cargo,
                capacity: view.capacity,
                projectedValue: view.activePlanetProjectedSale,
                size: landscape ? 74 : 84,
                rate: view.rate,
              ),
            ),
            Positioned(
              left: landscape
                  ? _landscapeX(236, .34, constraints.maxWidth)
                  : null,
              right: landscape ? null : 18,
              top: landscape
                  ? null
                  : constraints.maxHeight < 750
                  ? constraints.maxHeight - 310
                  : 506,
              bottom: landscape ? 78 : null,
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
    required this.onGridCellTap,
    this.landscapeLeftInset = 0,
    this.cavernWidth = 0,
  });

  final MineSiteView view;
  final bool landscape;
  final bool reducedMotion;
  final int impactSequence;
  final ValueChanged<MiningGridCell> onGridCellTap;
  final double landscapeLeftInset;
  final double cavernWidth;

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
            view: view,
            onCellTap: onGridCellTap,
            impactSequence: impactSequence,
            reducedMotion: reducedMotion,
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
    label: _saleLabel(view),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 56 : 64,
          height: compact ? 62 : 70,
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
        const SizedBox(height: 5),
        Text(
          '+${view.activePlanetProjectedSale}',
          style: TextStyle(
            color: MiningTheme.warning,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w800,
          ),
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

class _MineChromeButton extends StatelessWidget {
  const _MineChromeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 48,
    child: MiningHex(
      fill: const Color.fromRGBO(6, 10, 16, .82),
      border: const Color.fromRGBO(83, 212, 232, .32),
      onTap: onPressed,
      semanticLabel: label,
      child: Icon(icon, color: MiningTheme.accent, size: 22),
    ),
  );
}

String _saleLabel(MineSiteView view) => view.isBusy
    ? 'Finishing previous action…'
    : view.canSell
    ? 'Sell all cargo for ${view.activePlanetProjectedSale} cash.'
    : view.hasUnsellableCargo
    ? 'Keep mining until cargo is worth at least 1 cash.'
    : 'No cargo to sell.';
