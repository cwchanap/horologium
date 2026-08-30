import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/mining_dashed_border.dart';
import 'package:horologium/mining/presentation/mining_hex.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';
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
    this.cash = 0,
    this.cargo = 0,
    this.capacity = 0,
    this.projectedValue = 0,
  });

  final StellarMapView view;
  final MiningContentRegistry content;
  final ValueChanged<MiningPlanetId> onUnlock;
  final ValueChanged<MiningPlanetId> onTravel;
  final ValueChanged<MiningNavigationDestination>? onDestinationSelected;
  final MiningNavigationDestination selectedDestination;
  final int cash;
  final double cargo;
  final double capacity;
  final int projectedValue;

  @override
  Widget build(BuildContext context) {
    final visiblePlanetIds = view.planets.map((planet) => planet.id).toSet();
    final cards = <Widget>[
      for (final planet in view.planets)
        _PlanetCard(
          view: planet,
          content: content,
          onUnlock: onUnlock,
          onTravel: onTravel,
        ),
      for (final definition in content.planets.values)
        if (!visiblePlanetIds.contains(definition.id))
          _LockedPlanetTeaser(
            definition: definition,
            requiredPlanetName: content
                .planet(definition.unlockRequiredMasteryPlanetId!)
                .name,
          ),
    ];
    final pad = MediaQuery.paddingOf(context);
    return ColoredBox(
      key: const Key('stellar-map-screen'),
      color: const Color(0xFF060A10),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.68),
                  radius: .9,
                  colors: [Color(0xFF16233A), Color(0xFF060A10)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 54 + pad.top,
            left: 0,
            child: MiningCashChip(cash: cash),
          ),
          Positioned(
            top: 50 + pad.top,
            right: 12,
            child: MiningCargoGauge(
              cargo: cargo,
              capacity: capacity,
              projectedValue: projectedValue,
              size: 80,
            ),
          ),
          Positioned(left: 16, top: 112 + pad.top, child: const _MapHeader()),
          Positioned(
            left: 14,
            right: 14,
            top: 146 + pad.top,
            bottom: 99 + pad.bottom,
            child: SingleChildScrollView(
              key: const Key('stellar-map-scroll'),
              child: Column(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    cards[index],
                    if (index != cards.length - 1) const SizedBox(height: 11),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: pad.bottom,
            child: MiningNavigationBar(
              selected: selectedDestination,
              onDestinationSelected: onDestinationSelected ?? (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedPlanetTeaser extends StatelessWidget {
  const _LockedPlanetTeaser({
    required this.definition,
    required this.requiredPlanetName,
  });

  final MiningPlanetDefinition definition;
  final String requiredPlanetName;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '${definition.name}, locked planet',
    child: Container(
      key: Key('mining-stellar-map-teaser-${definition.id.name}'),
      width: double.infinity,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xB20A0F16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      child: CustomPaint(
        foregroundPainter: const MiningDashedRoundedBorderPainter(
          color: Color.fromRGBO(255, 255, 255, .14),
          radius: 16,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -2,
              top: -2,
              child: Opacity(
                opacity: .34,
                child: _PlanetArt(definition: definition, size: 92),
              ),
            ),
            Positioned(
              left: 14,
              top: 18,
              child: Text(
                definition.name,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 17,
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    color: Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'UNLOCK ${requiredPlanetName.split(' ').first.toUpperCase()} FIRST',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
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

class _MapHeader extends StatelessWidget {
  const _MapHeader();

  @override
  Widget build(BuildContext context) => const Text(
    'STELLAR MAP',
    style: TextStyle(
      color: Colors.white54,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.9,
    ),
  );
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
    final height = view.isActive ? 264.0 : 255.0;
    return Semantics(
      container: true,
      label: '${view.name}, ${stateLabel.toLowerCase()} planet',
      child: Container(
        key: Key('mining-stellar-map-planet-${view.id.name}'),
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xF20A111A),
          gradient: RadialGradient(
            center: const Alignment(.45, -.5),
            radius: .9,
            colors: view.isActive
                ? const [Color(0xFF1B2F47), Color(0xFF0B131C)]
                : const [Color(0xFF1A2230), Color(0xFF0A0F16)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor(view)),
          boxShadow: view.isActive
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(83, 212, 232, .1),
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              right: view.isActive ? -27 : -8,
              top: view.isActive ? -43 : 2,
              child: Opacity(
                opacity: view.isUnlocked ? 1 : .9,
                child: _PlanetArt(
                  definition: definition,
                  size: view.isActive ? 172 : 96,
                ),
              ),
            ),
            if (view.isActive)
              Positioned(
                left: 14,
                top: 14,
                child: _StateChip(label: stateLabel, view: view),
              ),
            Positioned(
              left: 14,
              top: view.isActive ? 56 : 16,
              child: Text(
                view.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: view.isActive ? 24 : 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (view.isActive)
              Positioned(
                left: 14,
                right: 14,
                bottom: 70,
                child: Row(
                  children: [
                    for (final indicator in view.siteIndicators) ...[
                      Expanded(
                        child: _SiteIndicator(
                          key: Key(
                            'stellar-map-site-${view.id.name}-${indicator.id.name}',
                          ),
                          indicator: indicator,
                          content: content,
                        ),
                      ),
                      if (indicator != view.siteIndicators.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              )
            else ...[
              Positioned(
                left: 14,
                right: 14,
                top: 54,
                child: Column(
                  children: [
                    for (final requirement in view.requirements)
                      _RequirementRow(requirement: requirement),
                    if (view.isBusy)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Finishing previous action…',
                          style: TextStyle(
                            color: MiningTheme.warning,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 76,
                child: Row(
                  children: [
                    for (final indicator in view.siteIndicators) ...[
                      Expanded(
                        child: _SiteIndicator(
                          key: Key(
                            'stellar-map-site-${view.id.name}-${indicator.id.name}',
                          ),
                          indicator: indicator,
                          content: content,
                        ),
                      ),
                      if (indicator != view.siteIndicators.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                children: [
                  if (view.isActive)
                    Expanded(child: _PlanetMetrics(view: view)),
                  if (view.isActive) const SizedBox(width: 12),
                  if (view.isActive)
                    _PlanetAction(
                      view: view,
                      onUnlock: onUnlock,
                      onTravel: onTravel,
                    )
                  else
                    Expanded(
                      child: _PlanetAction(
                        view: view,
                        onUnlock: onUnlock,
                        onTravel: onTravel,
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

  static String _stateLabel(StellarMapPlanetView view) {
    if (view.isActive) return 'ACTIVE';
    if (view.isUnlocked) return 'UNLOCKED';
    return 'LOCKED';
  }

  static Color _borderColor(StellarMapPlanetView view) {
    if (view.isActive) {
      return const Color.fromRGBO(83, 212, 232, .5);
    }
    if (view.isUnlocked) return Colors.white38;
    return Colors.white24;
  }
}

class _PlanetArt extends StatelessWidget {
  const _PlanetArt({required this.definition, this.size = 104});

  final MiningPlanetDefinition definition;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      definition.planetAsset,
      key: Key('mining-stellar-map-planet-${definition.id.name}-art'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: size,
        height: size,
        child: const Icon(
          Icons.public_rounded,
          color: Colors.white24,
          size: 72,
        ),
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
    const color = MiningTheme.highlight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanetMetrics extends StatelessWidget {
  const _PlanetMetrics({required this.view});

  final StellarMapPlanetView view;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('stellar-map-planet-${view.id.name}-summary'),
      children: [
        const Icon(
          Icons.grid_view_rounded,
          color: MiningTheme.accent,
          size: 15,
        ),
        const SizedBox(width: 6),
        Text(
          '${view.sitesCommissioned}/${view.siteTotal}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 1, height: 18, color: Colors.white24),
        const SizedBox(width: 10),
        const Icon(Icons.speed_rounded, color: MiningTheme.accent, size: 16),
        const SizedBox(width: 6),
        Text(
          '${view.rate.toStringAsFixed(1)}/s',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
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
    final site = content.site(indicator.id);
    final color = indicator.isCommissioned
        ? MiningTheme.warning
        : _stateColor(indicator.state);
    return Semantics(
      container: true,
      label: '${indicator.name}, ${_stateLabel(indicator.state).toLowerCase()}',
      child: CustomPaint(
        foregroundPainter: !indicator.isUnlocked
            ? const MiningDashedRoundedBorderPainter(
                color: Color.fromRGBO(255, 255, 255, .24),
                radius: 13,
              )
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: !indicator.isUnlocked
                  ? Colors.transparent
                  : color.withAlpha(120),
            ),
          ),
          child: !indicator.isUnlocked
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      color: Colors.white38,
                      size: 27,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.biotech_rounded,
                          color: MiningTheme.accent,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${site.requiredSurveyingLevel}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      site.nodeAsset,
                      width: 30,
                      height: 30,
                      opacity: indicator.isUnlocked
                          ? null
                          : const AlwaysStoppedAnimation(.45),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < 5; index++) ...[
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < (indicator.isCommissioned ? 3 : 0)
                                  ? color
                                  : Colors.white24,
                            ),
                          ),
                          if (index != 4) const SizedBox(width: 3),
                        ],
                      ],
                    ),
                  ],
                ),
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
    final label = requirement.label;
    final (asset, value) = label.contains(' sites ')
        ? (MiningVisuals.cargoIcon, label.split(' ').last)
        : label.startsWith('Surveying ')
        ? (MiningVisuals.surveyingIcon, 'LV ${label.split(' ').last}')
        : (MiningVisuals.cashIcon, label.split(' ').first);
    final color = requirement.isSatisfied
        ? MiningTheme.accent
        : MiningTheme.gate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        label: '$label, ${requirement.isSatisfied ? 'satisfied' : 'required'}',
        child: Row(
          children: [
            Image.asset(asset, width: 17, height: 17),
            const SizedBox(width: 7),
            Text(
              '$value  ${requirement.isSatisfied ? '✓' : '×'}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
        width: 54,
        height: 60,
        child: MiningHex(
          fill: MiningTheme.highlight,
          border: MiningTheme.highlight,
          onTap: !view.isActive && !view.isBusy
              ? () => onTravel(view.id)
              : null,
          semanticLabel: view.isActive ? 'Current location' : 'Travel here',
          child: const Icon(
            Icons.my_location_rounded,
            color: Color(0xFF04121A),
            size: 26,
          ),
        ),
      );
    }
    final gatesLeft = view.requirements
        .where((requirement) => !requirement.isSatisfied)
        .length;
    final canUnlock = view.canUnlock && !view.isBusy;
    return SizedBox(
      key: Key('mining-stellar-map-unlock-${view.id.name}'),
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: canUnlock ? () => onUnlock(view.id) : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: MiningTheme.warning,
          disabledForegroundColor: Colors.white38,
          disabledBackgroundColor: const Color.fromRGBO(255, 255, 255, .05),
          side: BorderSide(
            color: canUnlock
                ? MiningTheme.warning.withAlpha(160)
                : const Color.fromRGBO(255, 255, 255, .14),
          ),
          shape: const StadiumBorder(),
        ),
        child: canUnlock
            ? Text('UNLOCK FOR ${view.unlockCashCost} CASH')
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 16),
                  const SizedBox(width: 9),
                  Text('$gatesLeft GATES LEFT'),
                ],
              ),
      ),
    );
  }
}
