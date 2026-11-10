import 'package:flutter/material.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';

enum FleetDockAxis { horizontal, vertical }

class FleetDock extends StatelessWidget {
  const FleetDock({
    super.key,
    required this.view,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onBuildRig,
    this.axis = FleetDockAxis.horizontal,
  });

  final FleetDockView view;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final ValueChanged<RigTier> onBuildRig;
  final FleetDockAxis axis;

  static const double horizontalHeight = 96;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('fleet-dock'),
      height: axis == FleetDockAxis.horizontal ? horizontalHeight : null,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.transparent,
      child: axis == FleetDockAxis.vertical
          ? SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _verticalChildren(),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: _horizontalChildren(),
            ),
    );
  }

  List<Widget> _horizontalChildren() => [
    SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              view.dockHint,
              key: const Key('fleet-dock-hint'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: .6,
              ),
            ),
          ),
          if (view.bestAffordableTier != null) ...[
            const SizedBox(width: 7),
            SizedBox(
              width: 96,
              height: 44,
              child: _BuildPill(view: view, onBuildRig: onBuildRig),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 4),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 60,
          height: 44,
          child: _SpawnHex(view: view, onSpawnRig: onSpawnRig, showRig: true),
        ),
        for (final bayId in DockBayId.values)
          SizedBox(
            width: 60,
            height: 44,
            child: _BayButton(
              view: view.bay(bayId),
              onTap: () => onBayTap(bayId),
            ),
          ),
      ],
    ),
  ];

  List<Widget> _verticalChildren() => [
    const _FleetLabel(),
    if (view.bestAffordableTier != null) ...[
      const SizedBox(height: 6),
      SizedBox(
        width: 96,
        height: 44,
        child: _BuildPill(view: view, onBuildRig: onBuildRig),
      ),
    ],
    const SizedBox(height: 6),
    SizedBox(
      width: 56,
      height: 56,
      child: _SpawnHex(view: view, onSpawnRig: onSpawnRig, showRig: true),
    ),
    const SizedBox(height: 4),
    for (final bayId in DockBayId.values) ...[
      SizedBox(
        width: 56,
        height: 56,
        child: _BayButton(view: view.bay(bayId), onTap: () => onBayTap(bayId)),
      ),
      if (bayId != DockBayId.values.last) const SizedBox(height: 4),
    ],
  ];
}

class _FleetLabel extends StatelessWidget {
  const _FleetLabel();

  @override
  Widget build(BuildContext context) => const FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      'FLEET',
      style: TextStyle(
        color: Colors.white54,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _BuildPill extends StatelessWidget {
  const _BuildPill({required this.view, required this.onBuildRig});

  final FleetDockView view;
  final ValueChanged<RigTier> onBuildRig;

  @override
  Widget build(BuildContext context) {
    final tier = view.bestAffordableTier!;
    final enabled = view.canBuild;
    final VoidCallback? onTap = enabled ? () => onBuildRig(tier) : null;
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'BUILD ${tier.name.toUpperCase()} · '
        '${formatMiningCash(view.buildCost)}',
        maxLines: 1,
        style: TextStyle(
          color: enabled ? MiningTheme.highlight : Colors.white38,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: view.buildHint,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: const Key('fleet-dock-build'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Color.fromRGBO(24, 255, 255, enabled ? .14 : .06),
            border: Border.all(
              color: Color.fromRGBO(24, 255, 255, enabled ? .55 : .24),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: label),
        ),
      ),
    );
  }
}

class _SpawnHex extends StatelessWidget {
  const _SpawnHex({
    required this.view,
    required this.onSpawnRig,
    this.showRig = false,
  });

  final FleetDockView view;
  final VoidCallback onSpawnRig;
  final bool showRig;

  @override
  Widget build(BuildContext context) => MiningHex(
    fill: const Color.fromRGBO(24, 255, 255, .1),
    border: const Color.fromRGBO(24, 255, 255, .55),
    onTap: view.canSpawn ? onSpawnRig : null,
    semanticLabel: view.spawnHint,
    child: SizedBox.expand(
      key: const Key('fleet-dock-spawn'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showRig)
            Image.asset(
              MiningVisuals.rigAsset(RigTier.t1),
              width: 24,
              height: 24,
            ),
          // Frontier spawn costs (`40,000`, `4.00M`) scale down to fit the hex.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: MiningTheme.highlight,
                  size: showRig ? 12 : 18,
                ),
                if (showRig) const SizedBox(width: 2),
                Text(
                  formatMiningCash(view.spawnCost),
                  style: TextStyle(
                    color: MiningTheme.highlight,
                    fontSize: showRig ? 9 : 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BayButton extends StatelessWidget {
  const _BayButton({required this.view, required this.onTap});

  final FleetDockBayView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bayName = view.id.name.toUpperCase();
    final rig = view.rig;
    final tierColor = rig != null && rig.index >= RigTier.t3.index
        ? const Color(0xFFC4AFFF)
        : MiningTheme.accent;
    final isMergeTarget = view.canMergeWithSelection;
    return Semantics(
      button: true,
      enabled: !view.isBusy,
      label: 'Dock bay $bayName: ${view.hint}',
      child: MiningHex(
        fill: view.isSelected
            ? const Color.fromRGBO(24, 255, 255, .16)
            : isMergeTarget
            ? tierColor.withValues(alpha: .28)
            : rig == null
            ? const Color.fromRGBO(255, 255, 255, .05)
            : tierColor.withValues(alpha: .14),
        border: view.isSelected
            ? MiningTheme.highlight
            : isMergeTarget
            ? tierColor.withValues(alpha: .9)
            : rig == null
            ? const Color.fromRGBO(255, 255, 255, .16)
            : tierColor.withValues(alpha: .6),
        onTap: view.isBusy ? null : onTap,
        child: Container(
          key: ValueKey<String>(view.id.name),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (rig == null)
                Semantics(label: 'Empty bay', child: const SizedBox.expand())
              else
                SizedBox(
                  width: rig.index >= RigTier.t3.index ? 38 : 36,
                  height: rig.index >= RigTier.t3.index ? 38 : 36,
                  child: Image.asset(
                    MiningVisuals.rigAsset(rig),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.precision_manufacturing_rounded,
                      color: MiningTheme.accent,
                      size: 27,
                    ),
                  ),
                ),
              if (rig != null)
                Positioned(
                  bottom: 1,
                  child: Text(
                    rig.name.toUpperCase(),
                    style: TextStyle(
                      color: const Color(0xFF04121A),
                      backgroundColor: tierColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
