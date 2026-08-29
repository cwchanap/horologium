import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/fleet_dock.dart';
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
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 3),
              child: _MineSiteHeader(
                view: view,
                cash: cash,
                onBack: onBack,
                onSettings: onSettings,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: _MineSiteMetrics(view: view),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: _MineCavern(
                  view: view,
                  anchors: MiningVisuals.portraitNodeAnchors,
                  reducedMotion: reducedMotion,
                  onNodeTap: onNodeTap,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: _MineCargoControl(view: view, onSellCargo: onSellCargo),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 5),
              child: FleetDock(
                view: fleetDock,
                axis: FleetDockAxis.horizontal,
                onBayTap: onBayTap,
                onSpawnRig: onSpawnRig,
              ),
            ),
            MiningNavigationBar(
              selected: MiningNavigationDestination.siteDeck,
              onDestinationSelected: _navigate,
            ),
          ],
        ),
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
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 8, 5),
                child: Column(
                  children: [
                    _MineSiteHeader(
                      view: view,
                      cash: cash,
                      showNavigation: false,
                      onBack: onBack,
                      onSettings: onSettings,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _MineCavern(
                        view: view,
                        anchors: MiningVisuals.landscapeNodeAnchors,
                        reducedMotion: reducedMotion,
                        onNodeTap: onNodeTap,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MineSiteToolbar(onBack: onBack, onSettings: onSettings),
                  ],
                ),
              ),
            ),
            SizedBox(
              key: const Key('mine-site-right-rail'),
              width: 220,
              child: Align(
                alignment: Alignment.topCenter,
                child: Stack(
                  children: [
                    SizedBox(
                      height: 385,
                      child: FleetDock(
                        view: fleetDock,
                        axis: FleetDockAxis.vertical,
                        onBayTap: onBayTap,
                        onSpawnRig: onSpawnRig,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _MineCargoControl(
                        view: view,
                        compact: true,
                        onSellCargo: onSellCargo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MineSiteHeader extends StatelessWidget {
  const _MineSiteHeader({
    required this.view,
    required this.cash,
    required this.onBack,
    required this.onSettings,
    this.showNavigation = true,
  });

  final MineSiteView view;
  final int cash;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mine-site-header'),
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: MiningTheme.hudPanel,
        border: Border.all(color: MiningTheme.accent.withAlpha(120)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (showNavigation)
            _MineChromeButton(
              key: const Key('mine-site-back'),
              icon: Icons.arrow_back_rounded,
              label: 'Back to Site Deck',
              onPressed: onBack,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MiningTheme.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    '${_planetName(view.planetId)} · ${_resourceName(view.definition.resource)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MiningTheme.secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _HeaderCash(cash: cash),
          if (showNavigation)
            _MineChromeButton(
              key: const Key('mine-site-settings'),
              icon: Icons.settings_rounded,
              label: 'Settings',
              onPressed: onSettings,
            ),
        ],
      ),
    );
  }
}

class _HeaderCash extends StatelessWidget {
  const _HeaderCash({required this.cash});

  final int cash;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cash $cash',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            MiningVisuals.cashIcon,
            width: 20,
            height: 20,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.monetization_on_rounded,
              color: MiningTheme.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$cash',
            style: const TextStyle(
              color: MiningTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MineSiteMetrics extends StatelessWidget {
  const _MineSiteMetrics({required this.view});

  final MineSiteView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mine-site-metrics'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _Metric(label: 'RATE', value: '${view.rate.toStringAsFixed(2)}/s'),
          _Metric(
            label: 'CARGO',
            value: '${_amount(view.cargo)} / ${_amount(view.capacity)}',
          ),
          _Metric(label: 'SALE', value: '+${view.activePlanetProjectedSale}'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MiningTheme.mutedText,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: MiningTheme.accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF101C2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MiningTheme.accent.withAlpha(120)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
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
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: enabled
                  ? MiningTheme.accent.withAlpha(25)
                  : Colors.black.withAlpha(50),
              borderRadius: BorderRadius.circular(14),
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

class _MineCargoControl extends StatelessWidget {
  const _MineCargoControl({
    required this.view,
    required this.onSellCargo,
    this.compact = false,
  });

  final MineSiteView view;
  final VoidCallback onSellCargo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final saleLabel = view.isBusy
        ? 'Finishing previous action…'
        : view.canSell
        ? 'Sell all cargo for ${view.activePlanetProjectedSale} cash.'
        : view.hasUnsellableCargo
        ? 'Keep mining until cargo is worth at least 1 cash.'
        : 'No cargo to sell.';
    if (compact) {
      return Semantics(
        button: true,
        enabled: view.canSell,
        label: saleLabel,
        child: Container(
          key: const Key('mine-site-cargo'),
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: MiningTheme.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MiningTheme.accent.withAlpha(100)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                MiningVisuals.cargoIcon,
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.inventory_2_rounded,
                  color: MiningTheme.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_amount(view.activePlanetCargo)}\nTOTAL',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MiningTheme.primaryText,
                      fontSize: 8,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: const Key('mine-site-sell'),
                  tooltip: saleLabel,
                  onPressed: view.canSell ? onSellCargo : null,
                  icon: const Icon(Icons.sell_rounded, size: 20),
                  color: MiningTheme.accent,
                  disabledColor: MiningTheme.mutedText,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: view.canSell,
      label: saleLabel,
      child: Container(
        key: const Key('mine-site-cargo'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: MiningTheme.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MiningTheme.accent.withAlpha(100)),
        ),
        child: Row(
          children: [
            Image.asset(
              MiningVisuals.cargoIcon,
              width: 25,
              height: 25,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.inventory_2_rounded,
                color: MiningTheme.accent,
                size: 25,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CARGO HOLD',
                    style: TextStyle(
                      color: MiningTheme.mutedText,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${_amount(view.activePlanetCargo)} total  ·  +${view.activePlanetProjectedSale}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MiningTheme.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            OutlinedButton.icon(
              key: const Key('mine-site-sell'),
              onPressed: view.canSell ? onSellCargo : null,
              icon: const Icon(Icons.sell_rounded, size: 17),
              label: const Text('SELL ALL CARGO'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                foregroundColor: MiningTheme.accent,
                disabledForegroundColor: MiningTheme.mutedText,
                side: BorderSide(color: MiningTheme.accent.withAlpha(150)),
                textStyle: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
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

String _amount(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _planetName(MiningPlanetId id) {
  switch (id) {
    case MiningPlanetId.homeworld:
      return 'Homeworld';
    case MiningPlanetId.lunarFrontier:
      return 'Lunar Frontier';
    case MiningPlanetId.marsFrontier:
      return 'Mars Frontier';
  }
}

String _resourceName(ResourceType resource) =>
    MiningContentRegistry.resourceSilhouettes[resource]!.name;
