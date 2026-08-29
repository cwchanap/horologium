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
    final deckContent = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
        child: Row(
          children: [
            const Icon(
              Icons.radar_rounded,
              color: MiningTheme.accent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${view.planetName.toUpperCase()} SITE DECK',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MiningTheme.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Text(
              '${view.totalRate.toStringAsFixed(2)}/s',
              style: const TextStyle(
                color: MiningTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.separated(
          key: const Key('site-deck-scroll'),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          itemCount: view.sites.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) => _SiteCard(
            card: view.sites[index],
            onEnter: () => onEnterSite(view.sites[index].id),
            onUnlock: () => onUnlockSite(view.sites[index].id),
          ),
        ),
      ),
    ];
    final dock = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: FleetDock(
        view: fleetDock,
        onBayTap: onBayTap,
        onSpawnRig: onSpawnRig,
      ),
    );
    final navigation = MiningNavigationBar(
      selected: selectedDestination,
      onDestinationSelected: onDestinationSelected,
    );
    return ColoredBox(
      key: const Key('mining-shell-placeholder'),
      color: const Color(0xFF07111E),
      child: SafeArea(
        child: landscape
            ? Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: deckContent)),
                        SizedBox(
                          width: 248,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 12, 8),
                            child: FleetDock(
                              view: fleetDock,
                              onBayTap: onBayTap,
                              onSpawnRig: onSpawnRig,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  navigation,
                ],
              )
            : Column(children: [...deckContent, dock, navigation]),
      ),
    );
  }
}

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
    final artHeight = MediaQuery.sizeOf(context).height < 500 ? 104.0 : 150.0;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
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
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
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
                    right: card.isUnlocked ? 82 : 12,
                    bottom: 12,
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
                      bottom: 9,
                      child: MiningCargoGauge(
                        key: Key('site-card-${card.id.name}-cargo-gauge'),
                        cargo: card.cargo,
                        capacity: card.capacity,
                        projectedValue: card.projectedValue,
                        size: 62,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
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
                            ),
                            child: const Text('ENTER SITE'),
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
