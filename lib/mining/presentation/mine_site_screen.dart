import 'package:flutter/material.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/fleet_dock.dart';
import 'package:horologium/mining/presentation/mining_dashed_border.dart';
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
                onDestinationSelected: onDestinationSelected,
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
              onNodeTap: onNodeTap,
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
              onNodeTap: onNodeTap,
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
    required this.onNodeTap,
    required this.onSellCargo,
    this.portraitTopInset = 0,
    this.landscapeLeftInset = 0,
  });

  final MineSiteView view;
  final bool reducedMotion;
  final ValueChanged<MiningNodeId> onNodeTap;
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
                onNodeTap: onNodeTap,
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
              left: landscape ? 236 : null,
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
    required this.onNodeTap,
    this.landscapeLeftInset = 0,
    this.cavernWidth = 0,
  });

  final MineSiteView view;
  final bool landscape;
  final bool reducedMotion;
  final ValueChanged<MiningNodeId> onNodeTap;
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
          if (!landscape) ...[
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 180,
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
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 290,
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
          ] else
            const DecoratedBox(
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
          for (var index = 0; index < view.nodeList.length; index++)
            _positionedNode(index),
        ],
      ),
    );
  }

  Widget _positionedNode(int index) {
    // N4 is the only landscape node that can overflow a narrower cavern. When
    // it would, anchor its right edge to the cavern's right edge (right: 0) so
    // it clears the Clip regardless of its rendered label width. The one
    // exception is when both N3 and N4 are occupied: N4's rig column makes it
    // wide enough that right-anchoring would slide it under N3, and since N4 is
    // later in the Stack it would steal the overlap from N3's tap target. In
    // that case anchor N4 to N3's occupied right edge plus a gap instead,
    // accepting that N4's own rig column may clip the cavern at very narrow
    // widths rather than N3 losing any tap target. At 874x402 the anchor never
    // engages and the authored prototype positions are preserved.
    final n4RightAnchored =
        landscape &&
        index == 3 &&
        _landscapeN4Overflows(cavernWidth, landscapeLeftInset);
    final n4ShiftedPastN3 =
        n4RightAnchored &&
        _landscapeN4OverlapsOccupiedN3(view, cavernWidth, landscapeLeftInset);
    final double? n4Left;
    final double? n4Right;
    if (n4RightAnchored) {
      if (n4ShiftedPastN3) {
        n4Left = _landscapeN4ShiftedLeft(view, landscapeLeftInset);
        n4Right = null;
      } else {
        n4Left = null;
        n4Right = 0;
      }
    } else {
      n4Left =
          _nodeLeft(index, landscape) + (landscape ? landscapeLeftInset : 0);
      n4Right = null;
    }
    return Positioned(
      left: n4Left,
      right: n4Right,
      top: _nodeTop(index, landscape),
      child: _MineNodeButton(
        view: view.nodeList[index],
        nodeAsset: view.definition.nodeAsset,
        nodeSize: _nodeSize(index, landscape),
        rigSize: _rigSize(index, landscape),
        progress: view.capacity <= 0
            ? 0
            : (view.cargo / view.capacity).clamp(0, 1),
        reducedMotion: reducedMotion,
        onTap: () => onNodeTap(view.nodeList[index].id),
      ),
    );
  }
}

class _MineNodeButton extends StatelessWidget {
  const _MineNodeButton({
    required this.view,
    required this.nodeAsset,
    required this.nodeSize,
    required this.rigSize,
    required this.progress,
    required this.reducedMotion,
    required this.onTap,
  });

  final MineSiteNodeView view;
  final String nodeAsset;
  final double nodeSize;
  final double rigSize;
  final double progress;
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
          child: view.isLocked
              ? _LockedNode(
                  size: nodeSize,
                  requiredSurveyingLevel: view.requiredSurveyingLevel,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Image.asset(
                          nodeAsset,
                          width: nodeSize,
                          height: nodeSize,
                          opacity: view.rig == null
                              ? const AlwaysStoppedAnimation(.62)
                              : null,
                        ),
                        if (view.rig != null) ...[
                          const SizedBox(width: 2),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                MiningVisuals.rigAsset(view.rig!),
                                width: rigSize,
                                height: rigSize,
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: MiningTheme.accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  view.rig!.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF04121A),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: nodeSize * .86,
                      height: 7,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(0, 0, 0, .6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: view.rig == null
                              ? Colors.white24
                              : MiningTheme.accent,
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        heightFactor: 1,
                        child: const ColoredBox(color: MiningTheme.warning),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LockedNode extends StatelessWidget {
  const _LockedNode({required this.size, required this.requiredSurveyingLevel});

  final double size;
  final int requiredSurveyingLevel;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomPaint(
        foregroundPainter: MiningDashedRoundedBorderPainter(
          color: const Color.fromRGBO(255, 255, 255, .24),
          radius: size / 2,
          strokeWidth: 2,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(6, 10, 16, .72),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_rounded,
            color: Colors.white38,
            size: 27,
          ),
        ),
      ),
      const SizedBox(height: 9),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.biotech_rounded,
            size: 15,
            color: MiningTheme.accent,
          ),
          const SizedBox(width: 6),
          Text(
            'LV $requiredSurveyingLevel',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ],
  );
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

// Landscape node left offsets are authored for the 874x402 prototype, whose
// cavern is 770px wide (874 - 104 right rail). N1-N3 keep their authored
// positions at every landscape width: their right edges (max 401 for N3) fit
// inside any phone-width landscape cavern and stay clear of the fixed Sell
// control (left 236, width 56 -> right 292). N4 (authored left 510) is the only
// node that can overflow a narrower cavern; when it would, it is anchored to
// the cavern's right edge instead of its authored left so its right side always
// clears the Clip regardless of label width. When both N3 and N4 are occupied
// the anchor shifts N4 past N3's right edge so N4 never paints over N3's tap
// target (see _landscapeN4OverlapsOccupiedN3). At 874x402 (cavern 770) the
// anchor does not engage and the authored prototype positions are preserved.
double _nodeLeft(int index, bool landscape) => landscape
    ? const [22.0, 210.0, 307.0, 510.0][index]
    : const [18.0, 236.0, 86.0, 278.0][index];

// Whether landscape N4 would overflow the cavern at its authored left. N4's
// widget can be wider than its 70px circle (lock/rig labels add a label row or
// a rig column), so reserve the max node width (image + gap + rig column)
// against the available cavern width.
bool _landscapeN4Overflows(double cavernWidth, double landscapeLeftInset) {
  const authoredN4Left = 510.0;
  final maxWidth = _nodeSize(3, true) + 2 + _rigSize(3, true);
  return authoredN4Left + landscapeLeftInset + maxWidth > cavernWidth;
}

// Whether an occupied N4 right-anchored to the cavern's right edge would
// overlap an occupied N3 (and so steal part of N3's tap target, since N4 is
// painted later in the cavern Stack). Only the occupied case is deterministic
// (image + 2px gap + rig column); a non-occupied N4 renders at the image width
// plus a short label row that stays clear of N3 at phone landscape widths, so
// it keeps the right anchor.
bool _landscapeN4OverlapsOccupiedN3(
  MineSiteView view,
  double cavernWidth,
  double landscapeLeftInset,
) {
  final n4 = view.nodeList[3];
  final n3 = view.nodeList[2];
  if (n4.rig == null || n3.rig == null) return false;
  final n4OccupiedWidth = _nodeSize(3, true) + 2 + _rigSize(3, true);
  final n3OccupiedWidth = _nodeSize(2, true) + 2 + _rigSize(2, true);
  final rightAnchorLeft = cavernWidth - n4OccupiedWidth;
  final n3Right = _nodeLeft(2, true) + landscapeLeftInset + n3OccupiedWidth;
  return rightAnchorLeft < n3Right;
}

// N4's left when it must shift past an occupied N3: N3's occupied right edge
// plus a gap, so the two tap targets stay disjoint. N4's own right edge may
// then clip the cavern at very narrow widths.
double _landscapeN4ShiftedLeft(MineSiteView view, double landscapeLeftInset) {
  final n3OccupiedWidth = _nodeSize(2, true) + 2 + _rigSize(2, true);
  final n3Right = _nodeLeft(2, true) + landscapeLeftInset + n3OccupiedWidth;
  const gap = 4.0;
  return n3Right + gap;
}

double _nodeTop(int index, bool landscape) => landscape
    ? const [132.0, 118.0, 194.0, 138.0][index]
    : const [222.0, 186.0, 372.0, 404.0][index];

double _nodeSize(int index, bool landscape) => landscape
    ? const [80.0, 66.0, 94.0, 70.0][index]
    : const [88.0, 70.0, 102.0, 78.0][index];

double _rigSize(int index, bool landscape) => landscape
    ? const [48.0, 44.0, 54.0, 44.0][index]
    : const [52.0, 48.0, 58.0, 48.0][index];

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
