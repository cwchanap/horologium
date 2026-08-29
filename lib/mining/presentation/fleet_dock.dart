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
    const SizedBox(width: 46, child: _FleetLabel()),
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
    const SizedBox(height: 7),
    Row(
      children: [
        SizedBox(
          width: 60,
          height: 66,
          child: _SpawnHex(view: view, onSpawnRig: onSpawnRig),
        ),
        const SizedBox(width: 6),
        for (final bayId in DockBayId.values) ...[
          Expanded(
            child: SizedBox(
              height: 66,
              child: _BayButton(
                view: view.bay(bayId),
                onTap: () => onBayTap(bayId),
              ),
            ),
          ),
          if (bayId != DockBayId.values.last) const SizedBox(width: 6),
        ],
      ],
    ),
  ];

  List<Widget> _verticalChildren() => [
    const _FleetLabel(),
    const SizedBox(height: 6),
    SizedBox(
      width: 56,
      height: 62,
      child: _SpawnHex(view: view, onSpawnRig: onSpawnRig),
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
  Widget build(BuildContext context) => const Text(
    'FLEET',
    style: TextStyle(
      color: Colors.white54,
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}

class _SpawnHex extends StatelessWidget {
  const _SpawnHex({required this.view, required this.onSpawnRig});

  final FleetDockView view;
  final VoidCallback onSpawnRig;

  @override
  Widget build(BuildContext context) => MiningHex(
    fill: MiningTheme.accent.withAlpha(24),
    border: MiningTheme.accent.withAlpha(180),
    onTap: view.canSpawn ? onSpawnRig : null,
    semanticLabel: view.spawnHint,
    child: SizedBox.expand(
      key: const Key('fleet-dock-spawn'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_rounded, color: MiningTheme.accent, size: 18),
          Text(
            '${view.spawnCost}',
            style: const TextStyle(
              color: MiningTheme.accent,
              fontSize: 8,
              fontWeight: FontWeight.w800,
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
    return Semantics(
      button: true,
      enabled: !view.isBusy,
      label: 'Dock bay $bayName: ${view.hint}',
      child: MiningHex(
        fill: view.isSelected
            ? MiningTheme.accent.withAlpha(35)
            : const Color(0xD90E1828),
        border: view.isSelected ? MiningTheme.accent : Colors.white24,
        onTap: view.isBusy ? null : onTap,
        child: Container(
          key: ValueKey<String>(view.id.name),
          constraints: const BoxConstraints(minHeight: 54, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 33,
                height: 33,
                child: rig == null
                    ? Icon(
                        Icons.add_circle_outline,
                        color: Colors.white38,
                        size: 27,
                        semanticLabel: 'Empty bay',
                      )
                    : Image.asset(
                        MiningVisuals.rigAsset(rig),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.precision_manufacturing_rounded,
                          color: MiningTheme.accent,
                          size: 27,
                        ),
                      ),
              ),
              const SizedBox(height: 2),
              if (rig != null)
                Text(
                  rig.name.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF04121A),
                    backgroundColor: MiningTheme.accent,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
