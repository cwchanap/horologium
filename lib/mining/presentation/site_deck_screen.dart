import 'package:flutter/material.dart';
import 'package:horologium/mining/fleet_dock_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/fleet_dock.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';
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
    final compact = size.height < 500;
    final landscape = size.width > size.height;
    final deckContent = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: MiningHud(
          planetName: view.planetName,
          cash: cash,
          commissionedSites: view.commissionedCount,
          totalSites: view.siteCount,
          cargoValue: view.projectedValue,
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
      if (!compact)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
          child: _DeckSummary(view: view),
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
    final silhouette =
        MiningContentRegistry.resourceSilhouettes[card.definition.resource];
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
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                card.cardAsset,
                key: Key('site-card-${card.id.name}-art'),
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.36),
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xF20A1524),
                      const Color(0xC90A1524),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              silhouette?.name.toUpperCase() ?? 'RESOURCE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    silhouette?.color ?? MiningTheme.mutedText,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StateChip(label: stateLabel, state: card.state),
                    ],
                  ),
                  const SizedBox(height: 11),
                  _CardDetails(card: card),
                  const SizedBox(height: 10),
                  if (card.isUnlocked)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
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
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
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
                        child: Text('UNLOCK · ${card.unlockCost}'),
                      ),
                    ),
                  if (card.unlockDisabledReason != null && !card.canUnlock)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        card.unlockDisabledReason!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MiningTheme.mutedText,
                          fontSize: 11,
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
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({required this.card});

  final MiningSiteCardView card;

  @override
  Widget build(BuildContext context) {
    if (!card.isUnlocked) {
      return Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white54, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              card.requiredSite == null
                  ? 'Surveying ${card.requiredSurveyingLevel} required'
                  : 'Previous site required',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      );
    }
    final cargo = card.capacity <= 0
        ? 'NO CARGO'
        : '${_amount(card.cargo)} / ${_amount(card.capacity)}'
              ' CARGO';
    final rate = card.rate <= 0 ? 'IDLE' : '${card.rate.toStringAsFixed(2)}/s';
    return Row(
      children: [
        Expanded(
          child: _Stat(label: 'CARGO', value: cargo),
        ),
        Expanded(
          child: _Stat(label: 'RATE', value: rate),
        ),
        Expanded(
          child: _Stat(label: 'VALUE', value: '${card.projectedValue}'),
        ),
      ],
    );
  }

  static String _amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({required this.view});

  final SiteDeckView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: MiningTheme.hudPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DeckMetric(
              icon: MiningVisuals.cargoIcon,
              label: 'CARGO',
              value:
                  '${_amount(view.totalCargo)} / ${_amount(view.totalCapacity)}',
            ),
          ),
          Expanded(
            child: _DeckMetric(
              icon: MiningVisuals.cashIcon,
              label: 'VALUE',
              value: '${view.projectedValue}',
            ),
          ),
          Expanded(
            child: _DeckMetric(
              label: 'RATE',
              value: '${view.totalRate.toStringAsFixed(2)}/s',
            ),
          ),
        ],
      ),
    );
  }

  static String _amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _DeckMetric extends StatelessWidget {
  const _DeckMetric({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Image.asset(
              icon!,
              width: 15,
              height: 15,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MiningTheme.mutedText,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: MiningTheme.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MiningTheme.mutedText,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: MiningTheme.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
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
