import 'package:flutter/material.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

enum FleetDockAxis { horizontal, vertical }

class FleetDock extends StatelessWidget {
  const FleetDock({
    super.key,
    required this.view,
    required this.onBayTap,
    required this.onSpawnRig,
    this.axis = FleetDockAxis.horizontal,
  });

  final FleetDockView view;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final FleetDockAxis axis;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('fleet-dock'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.transparent,
      child: axis == FleetDockAxis.vertical
          ? SizedBox.expand(child: Column(children: _dockChildren()))
          : Column(mainAxisSize: MainAxisSize.min, children: _dockChildren()),
    );
  }

  List<Widget> _dockChildren() => [
    if (axis == FleetDockAxis.vertical)
      SizedBox(
        height: 46,
        child: _DockHeader(view: view, onSpawnRig: onSpawnRig),
      )
    else
      _DockHeader(view: view, onSpawnRig: onSpawnRig),
    const SizedBox(height: 2),
    if (axis == FleetDockAxis.vertical)
      Expanded(
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final bayId in DockBayId.values)
              Flexible(
                fit: FlexFit.loose,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _BayButton(
                    view: view.bay(bayId),
                    onTap: () => onBayTap(bayId),
                  ),
                ),
              ),
          ],
        ),
      )
    else
      Flex(
        direction: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final bayId in DockBayId.values)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _BayButton(
                  view: view.bay(bayId),
                  onTap: () => onBayTap(bayId),
                ),
              ),
            ),
        ],
      ),
  ];
}

class _DockHeader extends StatelessWidget {
  const _DockHeader({required this.view, required this.onSpawnRig});

  final FleetDockView view;
  final VoidCallback onSpawnRig;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'FLEET',
            style: TextStyle(
              color: MiningTheme.primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ),
        Semantics(
          button: true,
          enabled: view.canSpawn,
          label: view.spawnHint,
          child: OutlinedButton.icon(
            key: const Key('fleet-dock-spawn'),
            onPressed: view.canSpawn ? onSpawnRig : null,
            icon: Image.asset(
              MiningVisuals.cashIcon,
              width: 17,
              height: 17,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.add_rounded, size: 17),
            ),
            label: Text('${view.spawnCost}'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              foregroundColor: MiningTheme.accent,
              disabledForegroundColor: MiningTheme.mutedText,
              side: BorderSide(color: MiningTheme.accent.withAlpha(150)),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
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
      child: Material(
        color: view.isSelected
            ? MiningTheme.accent.withAlpha(35)
            : const Color(0xD90E1828),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: view.isSelected ? MiningTheme.accent : Colors.white24,
            width: view.isSelected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey<String>(view.id.name),
          onTap: view.isBusy ? null : onTap,
          customBorder: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    rig == null
                        ? bayName
                        : '$bayName · ${rig.name.toUpperCase()}',
                    maxLines: 1,
                    style: TextStyle(
                      color: rig == null
                          ? MiningTheme.mutedText
                          : MiningTheme.primaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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
