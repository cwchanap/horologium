import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/site_deck_view.dart';

/// Full-screen planet progression surface. All economy and action affordances
/// are supplied by [StellarMapView]; this widget only renders and delegates.
class StellarMapScreen extends StatelessWidget {
  const StellarMapScreen({
    super.key,
    required this.view,
    required this.content,
    required this.onUnlock,
    required this.onTravel,
    this.onDestinationSelected,
    this.selectedDestination = MiningNavigationDestination.stellarMap,
  });

  final StellarMapView view;
  final MiningContentRegistry content;
  final ValueChanged<MiningPlanetId> onUnlock;
  final ValueChanged<MiningPlanetId> onTravel;
  final ValueChanged<MiningNavigationDestination>? onDestinationSelected;
  final MiningNavigationDestination selectedDestination;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('stellar-map-screen'),
      color: const Color(0xFF07111E),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _MapHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('stellar-map-scroll'),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    for (var index = 0; index < view.planets.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == view.planets.length - 1 ? 0 : 10,
                        ),
                        child: _PlanetCard(
                          view: view.planets[index],
                          content: content,
                          onUnlock: onUnlock,
                          onTravel: onTravel,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            MiningNavigationBar(
              selected: selectedDestination,
              onDestinationSelected: onDestinationSelected ?? (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.public_rounded, color: MiningTheme.accent, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'STELLAR MAP',
                style: TextStyle(
                  color: MiningTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Choose the next frontier for your mining fleet.',
                style: TextStyle(
                  color: MiningTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanetCard extends StatelessWidget {
  const _PlanetCard({
    required this.view,
    required this.content,
    required this.onUnlock,
    required this.onTravel,
  });

  final StellarMapPlanetView view;
  final MiningContentRegistry content;
  final ValueChanged<MiningPlanetId> onUnlock;
  final ValueChanged<MiningPlanetId> onTravel;

  @override
  Widget build(BuildContext context) {
    final definition = content.planet(view.id);
    final stateLabel = _stateLabel(view);
    return Semantics(
      container: true,
      label: '${view.name}, ${stateLabel.toLowerCase()} planet',
      child: Container(
        key: Key('mining-stellar-map-planet-${view.id.name}'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MiningTheme.panel.withAlpha(235),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor(view)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              view.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MiningTheme.primaryText,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _StateChip(label: stateLabel, view: view),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${view.sitesCommissioned}/${view.siteTotal} ONLINE',
                        style: const TextStyle(
                          color: MiningTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _PlanetMetrics(view: view),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _PlanetArt(definition: definition),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                for (final indicator in view.siteIndicators)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _SiteIndicator(
                        key: Key(
                          'stellar-map-site-${view.id.name}-${indicator.id.name}',
                        ),
                        indicator: indicator,
                        content: content,
                      ),
                    ),
                  ),
              ],
            ),
            if (view.requirements.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final requirement in view.requirements)
                _RequirementRow(requirement: requirement),
            ],
            if (view.isBusy) ...[
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Finishing previous action…',
                  style: TextStyle(color: MiningTheme.warning, fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 7),
            _PlanetAction(view: view, onUnlock: onUnlock, onTravel: onTravel),
          ],
        ),
      ),
    );
  }

  static String _stateLabel(StellarMapPlanetView view) {
    if (view.isActive) return 'ACTIVE';
    if (view.isUnlocked) return 'UNLOCKED';
    return 'LOCKED';
  }

  static Color _borderColor(StellarMapPlanetView view) {
    if (view.isActive) return MiningTheme.accent.withAlpha(190);
    if (view.isUnlocked) return Colors.white38;
    return Colors.white24;
  }
}

class _PlanetArt extends StatelessWidget {
  const _PlanetArt({required this.definition});

  final MiningPlanetDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      definition.planetAsset,
      key: Key('mining-stellar-map-planet-${definition.id.name}-art'),
      width: 104,
      height: 104,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const SizedBox(
        width: 104,
        height: 104,
        child: Icon(Icons.public_rounded, color: Colors.white24, size: 72),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.view});

  final String label;
  final StellarMapPlanetView view;

  @override
  Widget build(BuildContext context) {
    final color = view.isActive
        ? MiningTheme.accent
        : view.isUnlocked
        ? Colors.white70
        : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(150)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PlanetMetrics extends StatelessWidget {
  const _PlanetMetrics({required this.view});

  final StellarMapPlanetView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('stellar-map-planet-${view.id.name}-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: MiningTheme.hudPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '${view.rate.toStringAsFixed(2)}/s · ${_amount(view.cargo)} cargo · +${view.projectedValue}',
          maxLines: 1,
          style: const TextStyle(
            color: MiningTheme.primaryText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  static String _amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _SiteIndicator extends StatelessWidget {
  const _SiteIndicator({
    super.key,
    required this.indicator,
    required this.content,
  });

  final StellarMapSiteIndicatorView indicator;
  final MiningContentRegistry content;

  @override
  Widget build(BuildContext context) {
    final silhouette = MiningContentRegistry
        .resourceSilhouettes[content.site(indicator.id).resource];
    final color = _stateColor(indicator.state);
    return Semantics(
      container: true,
      label: '${indicator.name}, ${_stateLabel(indicator.state).toLowerCase()}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Column(
          children: [
            Icon(silhouette?.icon ?? Icons.circle, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              indicator.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MiningTheme.primaryText,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _stateLabel(indicator.state),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
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
        return 'ONLINE';
    }
  }

  static Color _stateColor(MiningSiteCardState state) {
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

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.requirement});

  final StellarMapRequirementView requirement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            requirement.isSatisfied
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: requirement.isSatisfied
                ? MiningTheme.accent
                : MiningTheme.warning,
            size: 17,
            semanticLabel: requirement.isSatisfied ? 'Satisfied' : 'Required',
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              requirement.label,
              style: const TextStyle(
                color: MiningTheme.secondaryText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanetAction extends StatelessWidget {
  const _PlanetAction({
    required this.view,
    required this.onUnlock,
    required this.onTravel,
  });

  final StellarMapPlanetView view;
  final ValueChanged<MiningPlanetId> onUnlock;
  final ValueChanged<MiningPlanetId> onTravel;

  @override
  Widget build(BuildContext context) {
    if (view.isUnlocked) {
      return SizedBox(
        key: Key('mining-stellar-map-travel-${view.id.name}'),
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: !view.isActive && !view.isBusy
              ? () => onTravel(view.id)
              : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: MiningTheme.accent,
            disabledForegroundColor: MiningTheme.mutedText,
            side: BorderSide(color: MiningTheme.accent.withAlpha(160)),
          ),
          child: Text(view.isActive ? 'CURRENT LOCATION' : 'TRAVEL HERE'),
        ),
      );
    }
    return SizedBox(
      key: Key('mining-stellar-map-unlock-${view.id.name}'),
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: view.canUnlock && !view.isBusy
            ? () => onUnlock(view.id)
            : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: MiningTheme.warning,
          disabledForegroundColor: MiningTheme.mutedText,
          side: BorderSide(color: MiningTheme.warning.withAlpha(160)),
        ),
        child: Text('UNLOCK FOR ${view.unlockCashCost} CASH'),
      ),
    );
  }
}
