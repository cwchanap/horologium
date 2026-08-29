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
    this.axis = FleetDockAxis.horizontal,
    this.inline = false,
  });

  final FleetDockView view;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final FleetDockAxis axis;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('fleet-dock'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.transparent,
      child: inline
          ? Row(children: _inlineChildren())
          : axis == FleetDockAxis.vertical
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

  List<Widget> _inlineChildren() => [
    const SizedBox(width: 54, child: _FleetLabel()),
    SizedBox(
      width: 48,
      height: 54,
      child: _SpawnHex(view: view, onSpawnRig: onSpawnRig),
    ),
    const SizedBox(width: 4),
    for (final bayId in DockBayId.values) ...[
      Expanded(
        child: SizedBox(
          height: 58,
          child: _BayButton(
            view: view.bay(bayId),
            onTap: () => onBayTap(bayId),
          ),
        ),
      ),
      if (bayId != DockBayId.values.last) const SizedBox(width: 4),
    ],
  ];

  List<Widget> _horizontalChildren() => [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const _FleetLabel(),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            view.selectedBayId == null
                ? 'TAP A RIG, THEN A NODE'
                : 'TAP A NODE TO DEPLOY',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 9),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 60,
          height: 66,
          child: _SpawnHex(view: view, onSpawnRig: onSpawnRig, showRig: true),
        ),
        for (final bayId in DockBayId.values)
          SizedBox(
            width: 60,
            height: 66,
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
    const SizedBox(height: 6),
    SizedBox(
      width: 56,
      height: 62,
      child: _SpawnHex(view: view, onSpawnRig: onSpawnRig, showRig: true),
    ),
    const SizedBox(height: 4),
    for (final bayId in DockBayId.values) ...[
      SizedBox(
        width: 56,
        height: 62,
        child: _BayButton(view: view.bay(bayId), onTap: () => onBayTap(bayId)),
      ),
      if (bayId != DockBayId.values.last) const SizedBox(height: 4),
    ],
  ];
}

class _FleetLabel extends StatelessWidget {
  const _FleetLabel();

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(MiningVisuals.mergeIcon, width: 14, height: 14),
        const SizedBox(width: 6),
        const Text(
          'FLEET',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );
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
              width: 30,
              height: 30,
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                color: MiningTheme.highlight,
                size: showRig ? 12 : 18,
              ),
              if (showRig) const SizedBox(width: 2),
              Text(
                '${view.spawnCost}',
                style: TextStyle(
                  color: MiningTheme.highlight,
                  fontSize: showRig ? 9 : 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
    return Semantics(
      button: true,
      enabled: !view.isBusy,
      label: 'Dock bay $bayName: ${view.hint}',
      child: MiningHex(
        fill: view.isSelected
            ? const Color.fromRGBO(24, 255, 255, .16)
            : rig == null
            ? const Color.fromRGBO(255, 255, 255, .05)
            : tierColor.withValues(alpha: .14),
        border: view.isSelected
            ? MiningTheme.highlight
            : rig == null
            ? const Color.fromRGBO(255, 255, 255, .16)
            : tierColor.withValues(alpha: .6),
        onTap: view.isBusy ? null : onTap,
        child: Container(
          key: ValueKey<String>(view.id.name),
          constraints: const BoxConstraints(minHeight: 54, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (rig == null)
                const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white38,
                  size: 27,
                  semanticLabel: 'Empty bay',
                )
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
