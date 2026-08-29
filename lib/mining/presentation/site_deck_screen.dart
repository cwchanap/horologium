import 'package:flutter/material.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/fleet_dock.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/site_deck_view.dart';

class SiteDeckScreen extends StatelessWidget {
  const SiteDeckScreen({
    super.key,
    required this.view,
    required this.fleetDock,
    required this.onEnterSite,
    required this.onUnlockSite,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onDestinationSelected,
    this.cash = 0,
    this.selectedDestination = MiningNavigationDestination.siteDeck,
  });

  final SiteDeckView view;
  final FleetDockView fleetDock;
  final ValueChanged<MiningSiteId> onEnterSite;
  final ValueChanged<MiningSiteId> onUnlockSite;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final ValueChanged<MiningNavigationDestination> onDestinationSelected;
  final int cash;
  final MiningNavigationDestination selectedDestination;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    if (!landscape) {
      return _PortraitSiteDeck(
        view: view,
        fleetDock: fleetDock,
        cash: cash,
        selectedDestination: selectedDestination,
        onEnterSite: onEnterSite,
        onUnlockSite: onUnlockSite,
        onBayTap: onBayTap,
        onSpawnRig: onSpawnRig,
        onDestinationSelected: onDestinationSelected,
      );
    }
    return ColoredBox(
      key: const Key('mining-shell-placeholder'),
      color: const Color(0xFF07111E),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: MiningHud(
                planetName: view.planetName,
                cash: cash,
                commissionedSites: view.commissionedCount,
                totalSites: view.siteCount,
                cargo: view.totalCargo,
                capacity: view.totalCapacity,
                cargoValue: view.projectedValue,
                rate: view.totalRate,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      key: const Key('site-deck-scroll'),
                      padding: const EdgeInsets.all(12),
                      itemCount: view.sites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) => _SiteCard(
                        card: view.sites[index],
                        onEnter: () => onEnterSite(view.sites[index].id),
                        onUnlock: () => onUnlockSite(view.sites[index].id),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: FleetDock(
                      view: fleetDock,
                      onBayTap: onBayTap,
                      onSpawnRig: onSpawnRig,
                    ),
                  ),
                ],
              ),
            ),
            MiningNavigationBar(
              selected: selectedDestination,
              onDestinationSelected: onDestinationSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _PortraitSiteDeck extends StatelessWidget {
  const _PortraitSiteDeck({
    required this.view,
    required this.fleetDock,
    required this.cash,
    required this.selectedDestination,
    required this.onEnterSite,
    required this.onUnlockSite,
    required this.onBayTap,
    required this.onSpawnRig,
    required this.onDestinationSelected,
  });

  final SiteDeckView view;
  final FleetDockView fleetDock;
  final int cash;
  final MiningNavigationDestination selectedDestination;
  final ValueChanged<MiningSiteId> onEnterSite;
  final ValueChanged<MiningSiteId> onUnlockSite;
  final ValueChanged<DockBayId> onBayTap;
  final VoidCallback onSpawnRig;
  final ValueChanged<MiningNavigationDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('mining-shell-placeholder'),
      color: const Color(0xFF060A10),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 196,
            child: Opacity(
              opacity: .45,
              child: Image.asset(
                view.sites.first.cardAsset,
                fit: BoxFit.cover,
                alignment: const Alignment(.2, 0),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 196,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x88060A10), Color(0xFA060A10)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(top: 54, left: 0, child: MiningCashChip(cash: cash)),
          Positioned(
            top: 50,
            right: 12,
            child: MiningCargoGauge(
              cargo: view.totalCargo,
              capacity: view.totalCapacity,
              projectedValue: view.projectedValue,
              size: 80,
            ),
          ),
          Positioned(left: 16, top: 110, child: _PlanetProgress(view: view)),
          Positioned(
            left: 14,
            right: 14,
            top: 164,
            bottom: 198,
            child: SingleChildScrollView(
              key: const Key('site-deck-scroll'),
              child: Column(
                children: [
                  for (var index = 0; index < view.sites.length; index++) ...[
                    _PrototypeSiteCard(
                      card: view.sites[index],
                      height: switch (index) {
                        0 => 216,
                        1 => 170,
                        _ => 104,
                      },
                      onEnter: () => onEnterSite(view.sites[index].id),
                      onUnlock: () => onUnlockSite(view.sites[index].id),
                    ),
                    if (index != view.sites.length - 1)
                      const SizedBox(height: 11),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 96,
            height: 64,
            child: FleetDock(
              view: fleetDock,
              inline: true,
              onBayTap: onBayTap,
              onSpawnRig: onSpawnRig,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiningNavigationBar(
              selected: selectedDestination,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanetProgress extends StatelessWidget {
  const _PlanetProgress({required this.view});

  final SiteDeckView view;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Image.asset(_planetAsset(view.activePlanetId), width: 34, height: 34),
      const SizedBox(width: 9),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            view.planetName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var index = 0; index < view.siteCount; index++) ...[
                Container(
                  width: 26,
                  height: 3,
                  color: index < view.commissionedCount
                      ? MiningTheme.accent
                      : Colors.white24,
                ),
                if (index != view.siteCount - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    ],
  );
}

class _PrototypeSiteCard extends StatelessWidget {
  const _PrototypeSiteCard({
    required this.card,
    required this.height,
    required this.onEnter,
    required this.onUnlock,
  });

  final MiningSiteCardView card;
  final double height;
  final VoidCallback onEnter;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final silhouette =
        MiningContentRegistry.resourceSilhouettes[card.definition.resource];
    final locked = !card.isUnlocked && !card.canUnlock;
    return Semantics(
      container: true,
      label: '${card.name}, ${_siteStateLabel(card.state)} site',
      child: Container(
        key: Key('site-card-${card.id.name}'),
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: card.isOperational
                ? MiningTheme.accent.withAlpha(150)
                : Colors.white24,
            width: card.isOperational ? 1.5 : 1,
          ),
        ),
        child: SizedBox.expand(
          key: Key('site-card-${card.id.name}-art-frame'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                card.cardAsset,
                key: Key('site-card-${card.id.name}-art'),
                fit: BoxFit.cover,
                opacity: locked ? const AlwaysStoppedAnimation(.48) : null,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: locked
                        ? const [Color(0x77060A10), Color(0xDD060A10)]
                        : const [Colors.transparent, Color(0xF2060A10)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              if (locked)
                _LockedSite(card: card)
              else ...[
                Positioned(
                  left: 12,
                  top: 11,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 5, 11, 5),
                    decoration: BoxDecoration(
                      color: const Color(0xB8060A10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          card.definition.nodeAsset,
                          width: 22,
                          height: 22,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          (silhouette?.name ?? 'Resource').toUpperCase(),
                          style: TextStyle(
                            color: silhouette?.color ?? MiningTheme.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 12,
                  child: Text(
                    _siteStateLabel(card.state),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (height >= 200 && card.deployedRigs.isNotEmpty)
                  Positioned(
                    left: 22,
                    bottom: 72,
                    child: Row(
                      children: [
                        for (final rig in card.deployedRigs) ...[
                          _RigBadge(rig: rig),
                          const SizedBox(width: 14),
                        ],
                      ],
                    ),
                  ),
                Positioned(
                  left: 13,
                  right: 13,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: height >= 200 ? 22 : 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                            if (card.isUnlocked)
                              _SiteProgress(card: card)
                            else
                              Text(
                                'UNLOCK ${card.unlockCost}',
                                style: const TextStyle(
                                  color: MiningTheme.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (card.isUnlocked)
                        SizedBox(
                          width: 54,
                          height: 60,
                          child: _CardAction(
                            key: Key('site-card-${card.id.name}-enter'),
                            onPressed: card.canEnter && !card.isBusy
                                ? onEnter
                                : null,
                            icon: Icons.play_arrow_rounded,
                          ),
                        )
                      else
                        SizedBox(
                          width: 96,
                          height: 48,
                          child: OutlinedButton(
                            key: Key('site-card-${card.id.name}-unlock'),
                            onPressed: card.canUnlock ? onUnlock : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MiningTheme.warning,
                              side: const BorderSide(
                                color: MiningTheme.warning,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: Text('${card.unlockCost}'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedSite extends StatelessWidget {
  const _LockedSite({required this.card});

  final MiningSiteCardView card;

  @override
  Widget build(BuildContext context) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_rounded, color: Colors.white38, size: 30),
        const SizedBox(width: 18),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LOCKED',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'LV ${card.requiredSurveyingLevel}  ·  ${card.unlockCost}',
              style: const TextStyle(
                color: MiningTheme.warning,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RigBadge extends StatelessWidget {
  const _RigBadge({required this.rig});

  final RigTier rig;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        'assets/images/mining/rigs/${rig.name}.png',
        width: rig == RigTier.t1 ? 44 : 52,
        height: rig == RigTier.t1 ? 44 : 52,
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: MiningTheme.accent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          rig.name.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF04121A),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _SiteProgress extends StatelessWidget {
  const _SiteProgress({required this.card});

  final MiningSiteCardView card;

  @override
  Widget build(BuildContext context) {
    final progress = card.capacity <= 0 ? 0.0 : card.cargo / card.capacity;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0, 1),
              color: MiningTheme.warning,
              backgroundColor: Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(progress * 100).clamp(0, 100).round()}%',
          style: const TextStyle(
            color: MiningTheme.warning,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({super.key, required this.onPressed, required this.icon});

  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
    color: MiningTheme.accent,
    shape: const BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
    child: InkWell(
      onTap: onPressed,
      child: Icon(icon, color: const Color(0xFF04121A), size: 30),
    ),
  );
}

String _planetAsset(MiningPlanetId id) => switch (id) {
  MiningPlanetId.homeworld => 'assets/images/mining/planets/homeworld.png',
  MiningPlanetId.lunarFrontier =>
    'assets/images/mining/planets/lunar_frontier.png',
  MiningPlanetId.marsFrontier =>
    'assets/images/mining/planets/mars_frontier.png',
};

String _siteStateLabel(MiningSiteCardState state) => switch (state) {
  MiningSiteCardState.locked => 'LOCKED',
  MiningSiteCardState.available => 'AVAILABLE',
  MiningSiteCardState.idle => 'IDLE',
  MiningSiteCardState.operational => 'OPERATIONAL',
};

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.card,
    required this.onEnter,
    required this.onUnlock,
  });

  final MiningSiteCardView card;
  final VoidCallback onEnter;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(card.state);
    final artHeight = MediaQuery.sizeOf(context).height < 500
        ? 148.0
        : card.isUnlocked
        ? 196.0
        : 128.0;
    final silhouette =
        MiningContentRegistry.resourceSilhouettes[card.definition.resource];
    final status = !card.isUnlocked
        ? card.unlockDisabledReason ??
              (card.requiredSite == null
                  ? 'Surveying ${card.requiredSurveyingLevel} required'
                  : 'Previous site required')
        : card.rate <= 0
        ? 'IDLE'
        : '${card.rate.toStringAsFixed(2)}/s  ·  ${_amount(card.cargo)} / ${_amount(card.capacity)}';
    return Semantics(
      container: true,
      label: '${card.name}, $stateLabel site',
      child: Container(
        key: Key('site-card-${card.id.name}'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MiningTheme.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _borderColor(card.state),
            width: card.isOperational ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          key: Key('site-card-${card.id.name}-art-frame'),
          height: artHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                card.cardAsset,
                key: Key('site-card-${card.id.name}-art'),
                fit: BoxFit.cover,
                opacity: card.state == MiningSiteCardState.locked
                    ? const AlwaysStoppedAnimation(0.48)
                    : null,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xE607111E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _StateChip(label: stateLabel, state: card.state),
              ),
              Positioned(
                left: 12,
                right: card.isUnlocked ? 74 : 12,
                bottom: 58,
                child: Row(
                  children: [
                    if (silhouette != null)
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: silhouette.color.withAlpha(45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: silhouette.color.withAlpha(150),
                          ),
                        ),
                        child: Icon(
                          silhouette.icon,
                          color: silhouette.color,
                          size: 22,
                          semanticLabel: silhouette.name,
                        ),
                      ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MiningTheme.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            silhouette?.name.toUpperCase() ?? 'RESOURCE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  silhouette?.color ??
                                  MiningTheme.secondaryText,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (card.isUnlocked)
                Positioned(
                  right: 10,
                  bottom: 54,
                  child: MiningCargoGauge(
                    key: Key('site-card-${card.id.name}-cargo-gauge'),
                    cargo: card.cargo,
                    capacity: card.capacity,
                    projectedValue: card.projectedValue,
                    size: 62,
                  ),
                ),
              Positioned(
                left: 12,
                right: 10,
                bottom: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MiningTheme.secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 132,
                      height: 48,
                      child: card.isUnlocked
                          ? OutlinedButton(
                              key: Key('site-card-${card.id.name}-enter'),
                              onPressed: card.canEnter && !card.isBusy
                                  ? onEnter
                                  : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: MiningTheme.accent,
                                disabledForegroundColor: MiningTheme.mutedText,
                                side: BorderSide(
                                  color: MiningTheme.accent.withAlpha(160),
                                ),
                                shape: BeveledRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Icon(Icons.play_arrow_rounded),
                            )
                          : OutlinedButton(
                              key: Key('site-card-${card.id.name}-unlock'),
                              onPressed: card.canUnlock ? onUnlock : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: MiningTheme.warning,
                                disabledForegroundColor: MiningTheme.mutedText,
                                side: BorderSide(
                                  color: MiningTheme.warning.withAlpha(160),
                                ),
                                shape: BeveledRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'UNLOCK · ${card.unlockCost}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _borderColor(MiningSiteCardState state) {
    switch (state) {
      case MiningSiteCardState.locked:
        return Colors.white24;
      case MiningSiteCardState.available:
        return MiningTheme.warning.withAlpha(150);
      case MiningSiteCardState.idle:
        return Colors.white38;
      case MiningSiteCardState.operational:
        return MiningTheme.accent.withAlpha(180);
    }
  }

  static String _stateLabel(MiningSiteCardState state) {
    switch (state) {
      case MiningSiteCardState.locked:
        return 'LOCKED';
      case MiningSiteCardState.available:
        return 'AVAILABLE';
      case MiningSiteCardState.idle:
        return 'IDLE';
      case MiningSiteCardState.operational:
        return 'OPERATIONAL';
    }
  }

  static String _amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.state});

  final String label;
  final MiningSiteCardState state;

  @override
  Widget build(BuildContext context) {
    final color = _color(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withAlpha(130)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Color _color(MiningSiteCardState state) {
    switch (state) {
      case MiningSiteCardState.locked:
        return Colors.white54;
      case MiningSiteCardState.available:
        return MiningTheme.warning;
      case MiningSiteCardState.idle:
        return Colors.white70;
      case MiningSiteCardState.operational:
        return MiningTheme.accent;
    }
  }
}
