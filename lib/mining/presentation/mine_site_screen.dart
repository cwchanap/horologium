import 'package:flutter/material.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/fleet_dock.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

class MineSiteScreen extends StatelessWidget {
  const MineSiteScreen({
    super.key,
    required this.view,
    required this.fleetDock,
    required this.onNodeTap,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onSellCargo,
    required this.onBack,
    required this.onSettings,
    this.onDestinationSelected,
    this.cash = 0,
    this.reducedMotion = false,
  });

  final MineSiteView view;
  final FleetDockView fleetDock;
  final ValueChanged<MiningNodeId> onNodeTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final VoidCallback onSellCargo;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final ValueChanged<MiningNavigationDestination>? onDestinationSelected;
  final int cash;
  final bool reducedMotion;

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
                onNodeTap: onNodeTap,
                onBayTap: onBayTap,
                onSpawnRig: onSpawnRig,
                onSellCargo: onSellCargo,
                onBack: onBack,
                onSettings: onSettings,
              )
            : _PortraitMineSite(
                view: view,
                fleetDock: fleetDock,
                cash: cash,
                reducedMotion: reducedMotion,
                onNodeTap: onNodeTap,
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
    required this.onNodeTap,
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
  final ValueChanged<MiningNodeId> onNodeTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final VoidCallback onSellCargo;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final ValueChanged<MiningNavigationDestination>? onDestinationSelected;

  void _navigate(MiningNavigationDestination destination) {
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
    return ColoredBox(
      key: const Key('mine-site-screen'),
      color: const Color(0xFF07111E),
      child: Stack(
        children: [
          Positioned.fill(
            child: _CavernScene(
              view: view,
              anchors: MiningVisuals.portraitNodeAnchors,
              reducedMotion: reducedMotion,
              onNodeTap: onNodeTap,
              onSellCargo: onSellCargo,
            ),
          ),
          Positioned(top: 8, left: 8, child: MiningCashChip(cash: cash)),
          Positioned(
            top: 64,
            left: 8,
            child: _MineChromeButton(
              key: const Key('mine-site-back'),
              icon: Icons.arrow_back_rounded,
              label: 'Back to Site Deck',
              onPressed: onBack,
            ),
          ),
          Positioned(
            top: 64,
            right: 96,
            child: _MineChromeButton(
              key: const Key('mine-site-settings'),
              icon: Icons.settings_rounded,
              label: 'Settings',
              onPressed: onSettings,
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 64,
            height: 116,
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
            bottom: 0,
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
    required this.onNodeTap,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onSellCargo,
    required this.onBack,
    required this.onSettings,
  });

  final MineSiteView view;
  final FleetDockView fleetDock;
  final int cash;
  final bool reducedMotion;
  final ValueChanged<MiningNodeId> onNodeTap;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final VoidCallback onSellCargo;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('mine-site-screen'),
      color: const Color(0xFF07111E),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 104,
            bottom: 0,
            child: _CavernScene(
              view: view,
              anchors: MiningVisuals.landscapeNodeAnchors,
              reducedMotion: reducedMotion,
              onNodeTap: onNodeTap,
              onSellCargo: onSellCargo,
            ),
          ),
          Positioned(top: 8, left: 8, child: MiningCashChip(cash: cash)),
          Positioned(
            left: 8,
            bottom: 8,
            child: _MineSiteToolbar(onBack: onBack, onSettings: onSettings),
          ),
          Positioned(
            key: const Key('mine-site-right-rail'),
            top: 0,
            right: 0,
            bottom: 0,
            width: 104,
            child: ColoredBox(
              color: const Color(0xF20E1828),
              child: FleetDock(
                view: fleetDock,
                axis: FleetDockAxis.vertical,
                onBayTap: onBayTap,
                onSpawnRig: onSpawnRig,
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
    required this.anchors,
    required this.reducedMotion,
    required this.onNodeTap,
    required this.onSellCargo,
  });

  final MineSiteView view;
  final List<Alignment> anchors;
  final bool reducedMotion;
  final ValueChanged<MiningNodeId> onNodeTap;
  final VoidCallback onSellCargo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _MineCavern(
            view: view,
            anchors: anchors,
            reducedMotion: reducedMotion,
            onNodeTap: onNodeTap,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: MiningCargoGauge(
            containerKey: const Key('mine-site-cargo'),
            buttonKey: const Key('mine-site-sell'),
            cargo: view.cargo,
            capacity: view.capacity,
            projectedValue: view.activePlanetProjectedSale,
            size: 78,
            semanticLabel: _saleLabel(view),
            onPressed: view.canSell ? onSellCargo : null,
          ),
        ),
      ],
    );
  }
}

class _MineCavern extends StatelessWidget {
  const _MineCavern({
    required this.view,
    required this.anchors,
    required this.reducedMotion,
    required this.onNodeTap,
  });

  final MineSiteView view;
  final List<Alignment> anchors;
  final bool reducedMotion;
  final ValueChanged<MiningNodeId> onNodeTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mine-site-cavern'),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Color(0xFF101C2A)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            view.definition.cavernAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
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
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black38, Colors.transparent, Colors.black45],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          for (var index = 0; index < view.nodeList.length; index++)
            Align(
              alignment: anchors[index % anchors.length],
              child: _MineNodeButton(
                view: view.nodeList[index],
                nodeAsset: view.definition.nodeAsset,
                reducedMotion: reducedMotion,
                onTap: () => onNodeTap(view.nodeList[index].id),
              ),
            ),
        ],
      ),
    );
  }
}

class _MineNodeButton extends StatelessWidget {
  const _MineNodeButton({
    required this.view,
    required this.nodeAsset,
    required this.reducedMotion,
    required this.onTap,
  });

  final MineSiteNodeView view;
  final String nodeAsset;
  final bool reducedMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = view.canDeploy || view.canRecall;
    final canForwardDisabledTap = view.disabledReason != null;
    final label = _nodeLabel(view);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('mine-site-node-${view.id.name}'),
          onTap: enabled || canForwardDisabledTap ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: enabled
                  ? MiningTheme.accent.withAlpha(25)
                  : Colors.black.withAlpha(50),
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled ? MiningTheme.accent : Colors.white30,
                width: enabled ? 1.5 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  child: AnimatedSwitcher(
                    duration: reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => reducedMotion
                        ? child
                        : FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                          ),
                    child: _NodeArt(
                      key: ValueKey<String>(
                        '${view.id.name}-${view.rig?.name}-${view.state.name}',
                      ),
                      view: view,
                      nodeAsset: nodeAsset,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      view.rig == null
                          ? view.id.name.toUpperCase()
                          : '${view.id.name.toUpperCase()} · ${view.rig!.name.toUpperCase()}',
                      maxLines: 1,
                      style: TextStyle(
                        color: enabled
                            ? MiningTheme.primaryText
                            : MiningTheme.mutedText,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeArt extends StatelessWidget {
  const _NodeArt({super.key, required this.view, required this.nodeAsset});

  final MineSiteNodeView view;
  final String nodeAsset;

  @override
  Widget build(BuildContext context) {
    final node = Opacity(
      opacity: view.isLocked ? 0.35 : 1,
      child: Image.asset(
        nodeAsset,
        width: 52,
        height: 52,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.hub_rounded, color: MiningTheme.accent, size: 42),
      ),
    );
    if (view.rig == null) return node;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          node,
          Image.asset(
            MiningVisuals.rigAsset(view.rig!),
            width: 36,
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.precision_manufacturing_rounded,
              color: MiningTheme.accent,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _MineSiteToolbar extends StatelessWidget {
  const _MineSiteToolbar({required this.onBack, required this.onSettings});

  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('mine-site-toolbar'),
      children: [
        _MineChromeButton(
          key: const Key('mine-site-back'),
          icon: Icons.arrow_back_rounded,
          label: 'Back to Site Deck',
          onPressed: onBack,
        ),
        const SizedBox(width: 4),
        _MineChromeButton(
          key: const Key('mine-site-settings'),
          icon: Icons.settings_rounded,
          label: 'Settings',
          onPressed: onSettings,
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon),
        color: MiningTheme.accent,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    );
  }
}

String _nodeLabel(MineSiteNodeView view) {
  final state = switch (view.state) {
    MineSiteNodeState.locked => 'Locked',
    MineSiteNodeState.available => 'Available',
    MineSiteNodeState.deployable => 'Ready to deploy',
    MineSiteNodeState.occupied => 'Occupied',
  };
  final reason = view.disabledReason;
  final rig = view.rig == null ? '' : ' ${view.rig!.name.toUpperCase()} rig.';
  return 'Node ${view.id.name.toUpperCase()}: $state.$rig${reason == null ? '' : ' $reason'}';
}

String _saleLabel(MineSiteView view) => view.isBusy
    ? 'Finishing previous action…'
    : view.canSell
    ? 'Sell all cargo for ${view.activePlanetProjectedSale} cash.'
    : view.hasUnsellableCargo
    ? 'Keep mining until cargo is worth at least 1 cash.'
    : 'No cargo to sell.';
