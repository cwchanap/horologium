import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/site_deck_view.dart';

class TechnologyTrackView {
  const TechnologyTrackView({
    required this.track,
    required this.name,
    required this.level,
    required this.currentEffect,
    required this.nextEffect,
    required this.cost,
    required this.gateSiteName,
    required this.isGateSatisfied,
    required this.isAffordable,
    required this.isMaxLevel,
    required this.disabledReason,
    this.nodeAvailability,
    this.nextNodeAvailability,
  });

  final TechnologyTrack track;
  final String name;
  final int level;
  final String currentEffect;
  final String? nextEffect;
  final int? cost;
  final String? gateSiteName;
  final bool isGateSatisfied;
  final bool isAffordable;
  final bool isMaxLevel;
  final String? disabledReason;
  final String? nodeAvailability;
  final String? nextNodeAvailability;

  bool get canPurchase => !isMaxLevel && isGateSatisfied && isAffordable;

  String? get surveyingNodeAvailability => nodeAvailability;
}

class TechnologySheetView {
  const TechnologySheetView({required this.tracks});

  final List<TechnologyTrackView> tracks;

  TechnologyTrackView track(TechnologyTrack track) =>
      tracks.singleWhere((view) => view.track == track);

  static TechnologySheetView from({
    required MiningSave state,
    required MiningContentRegistry content,
  }) => TechnologySheetView(
    tracks: List<TechnologyTrackView>.unmodifiable([
      for (final track in TechnologyTrack.values)
        _trackView(state, content, track),
    ]),
  );

  static TechnologyTrackView _trackView(
    MiningSave state,
    MiningContentRegistry content,
    TechnologyTrack track,
  ) {
    final level = state.technology.levelFor(track);
    final name = _trackName(track);

    if (level >= MiningContentRegistry.maxTechnologyLevel) {
      return TechnologyTrackView(
        track: track,
        name: name,
        level: level,
        currentEffect: _effect(state, content, track, level),
        nextEffect: null,
        cost: null,
        gateSiteName: null,
        isGateSatisfied: true,
        isAffordable: true,
        isMaxLevel: true,
        disabledReason: 'Technology is at max level.',
        nodeAvailability: track == TechnologyTrack.surveying
            ? _nodeAvailability(state, content, level)
            : null,
        nextNodeAvailability: null,
      );
    }

    final gateSite = MiningContentRegistry.technologySiteGates[level];
    final gateSatisfied = state.sites[gateSite]?.commissioned == true;
    final cost = MiningContentRegistry.technologyCosts[level];
    final affordable = state.cash >= cost;

    return TechnologyTrackView(
      track: track,
      name: name,
      level: level,
      currentEffect: _effect(state, content, track, level),
      nextEffect: _effect(state, content, track, level + 1),
      cost: cost,
      gateSiteName: content.site(gateSite).name,
      isGateSatisfied: gateSatisfied,
      isAffordable: affordable,
      isMaxLevel: false,
      disabledReason: !gateSatisfied
          ? 'Commission the ${content.site(gateSite).name} site first.'
          : !affordable
          ? 'Need $cost cash.'
          : null,
      nodeAvailability: track == TechnologyTrack.surveying
          ? _nodeAvailability(state, content, level)
          : null,
      nextNodeAvailability: track == TechnologyTrack.surveying
          ? _nodeAvailability(state, content, level + 1)
          : null,
    );
  }

  static String _trackName(TechnologyTrack track) =>
      '${track.name[0].toUpperCase()}${track.name.substring(1)}';

  static String _effect(
    MiningSave state,
    MiningContentRegistry content,
    TechnologyTrack track,
    int level,
  ) {
    switch (track) {
      case TechnologyTrack.extraction:
        return 'Mining rate ×'
            '${MiningContentRegistry.extractionRateMultipliers[level].toStringAsFixed(2)}';
      case TechnologyTrack.logistics:
        return 'Mine capacity ×'
            '${MiningContentRegistry.logisticsCapacityMultipliers[level].toStringAsFixed(2)}'
            ', offline cap ${content.offlineCapFor(level).inHours}h';
      case TechnologyTrack.surveying:
        final unlockedPlanets = content.planets.values.where(
          (planet) => state.unlockedPlanetIds.contains(planet.id),
        );
        final total = unlockedPlanets.expand((planet) => planet.sites).length;
        final revealable = unlockedPlanets
            .expand((planet) => planet.sites)
            .where((site) => site.requiredSurveyingLevel <= level)
            .length;
        return '$revealable of $total sites revealable';
    }
  }

  static String _nodeAvailability(
    MiningSave state,
    MiningContentRegistry content,
    int level,
  ) {
    var available = 0;
    var total = 0;
    for (final planet in content.planets.values) {
      if (!state.unlockedPlanetIds.contains(planet.id)) continue;
      for (final site in planet.sites) {
        for (final node in site.nodes) {
          total++;
          if (node.requiredSurveyingLevel <= level) available++;
        }
      }
    }
    return '$available of $total nodes available';
  }
}

class StellarMapRequirementView {
  const StellarMapRequirementView({
    required this.label,
    required this.isSatisfied,
  });

  final String label;
  final bool isSatisfied;

  bool get satisfied => isSatisfied;
}

class StellarMapSiteIndicatorView {
  const StellarMapSiteIndicatorView({
    required this.id,
    required this.name,
    required this.state,
    required this.isUnlocked,
    required this.isCommissioned,
    required this.cargo,
    required this.capacity,
    required this.rate,
    required this.projectedValue,
  });

  final MiningSiteId id;
  final String name;
  final MiningSiteCardState state;
  final bool isUnlocked;
  final bool isCommissioned;
  final double cargo;
  final double capacity;
  final double rate;
  final int projectedValue;

  double get storedAmount => cargo;
  bool get isOperational => state == MiningSiteCardState.operational;
}

class StellarMapPlanetView {
  const StellarMapPlanetView({
    required this.id,
    required this.name,
    required this.isUnlocked,
    required this.isActive,
    required this.sitesCommissioned,
    required this.siteTotal,
    required this.requiredMasteryPlanetId,
    required this.hasRequiredMastery,
    required this.requiredSurveyingLevel,
    required this.hasSurveying,
    required this.unlockCashCost,
    required this.hasCash,
    this.cargo = 0,
    this.capacity = 0,
    this.rate = 0,
    this.projectedValue = 0,
    this.siteIndicators = const [],
    this.requirements = const [],
    this.isBusy = false,
  });

  final MiningPlanetId id;
  final String name;
  final bool isUnlocked;
  final bool isActive;
  final int sitesCommissioned;
  final int siteTotal;
  final MiningPlanetId? requiredMasteryPlanetId;
  final bool hasRequiredMastery;
  final int requiredSurveyingLevel;
  final bool hasSurveying;
  final int unlockCashCost;
  final bool hasCash;
  final double cargo;
  final double capacity;
  final double rate;
  final int projectedValue;
  final List<StellarMapSiteIndicatorView> siteIndicators;
  final List<StellarMapRequirementView> requirements;
  final bool isBusy;

  /// Kept as source-compatible aliases while Stellar Map presentation moves.
  int get commissionedCount => sitesCommissioned;
  int get totalSites => siteTotal;
  double get totalCargo => cargo;
  double get totalCapacity => capacity;
  double get productionRate => rate;
  int get projectedSale => projectedValue;
  List<StellarMapSiteIndicatorView> get indicators => siteIndicators;

  StellarMapSiteIndicatorView siteIndicator(MiningSiteId id) =>
      siteIndicators.singleWhere((indicator) => indicator.id == id);

  List<StellarMapRequirementView> get requirementIndicators => requirements;

  bool get canUnlock =>
      !isUnlocked &&
      requiredMasteryPlanetId != null &&
      hasRequiredMastery &&
      hasSurveying &&
      hasCash;
}

class StellarMapView {
  const StellarMapView({required this.planets});

  final List<StellarMapPlanetView> planets;

  StellarMapPlanetView planet(MiningPlanetId id) =>
      planets.singleWhere((view) => view.id == id);

  static StellarMapView from({
    required MiningSave state,
    required MiningContentRegistry content,
    bool isBusy = false,
  }) {
    final unlockedPlanetIds = state.unlockedPlanetIds;
    final commissionedSiteIds = state.sites.entries
        .where((entry) => entry.value.commissioned)
        .map((entry) => entry.key);

    return StellarMapView(
      planets: List<StellarMapPlanetView>.unmodifiable([
        for (final definition in content.planets.values)
          if (_isVisible(definition, unlockedPlanetIds))
            _planetView(
              state,
              content,
              definition,
              commissionedSiteIds,
              isBusy: isBusy,
            ),
      ]),
    );
  }

  static bool _isVisible(
    MiningPlanetDefinition definition,
    Set<MiningPlanetId> unlockedPlanetIds,
  ) {
    final requiredMasteryPlanetId = definition.unlockRequiredMasteryPlanetId;
    return definition.id == MiningPlanetId.homeworld ||
        unlockedPlanetIds.contains(definition.id) ||
        (requiredMasteryPlanetId != null &&
            unlockedPlanetIds.contains(requiredMasteryPlanetId));
  }

  static StellarMapPlanetView _planetView(
    MiningSave state,
    MiningContentRegistry content,
    MiningPlanetDefinition definition,
    Iterable<MiningSiteId> commissionedSiteIds, {
    required bool isBusy,
  }) {
    final requiredMasteryPlanetId = definition.unlockRequiredMasteryPlanetId;
    final hasRequiredMastery =
        requiredMasteryPlanetId == null ||
        content.isPlanetMastered(requiredMasteryPlanetId, commissionedSiteIds);
    final sitesCommissioned = definition.sites
        .where((site) => state.sites[site.id]?.commissioned == true)
        .length;
    final indicators = <StellarMapSiteIndicatorView>[];
    var cargo = 0.0;
    var capacity = 0.0;
    var rate = 0.0;
    var projectedValue = 0.0;
    for (final site in definition.sites) {
      final progress = state.sites[site.id]!;
      final metrics = SiteMetrics.of(
        content: content,
        site: site,
        progress: progress,
        technology: state.technology,
      );
      indicators.add(
        StellarMapSiteIndicatorView(
          id: site.id,
          name: site.name,
          state: metrics.cardState,
          isUnlocked: progress.unlocked,
          isCommissioned: progress.commissioned,
          cargo: progress.storedAmount,
          capacity: metrics.capacity,
          rate: metrics.rate,
          projectedValue: (progress.storedAmount * site.saleValuePerUnit)
              .floor(),
        ),
      );
      cargo += progress.storedAmount;
      capacity += metrics.capacity;
      rate += metrics.rate;
      projectedValue += progress.storedAmount * site.saleValuePerUnit;
    }
    final requirements = <StellarMapRequirementView>[];
    if (requiredMasteryPlanetId != null) {
      final requiredPlanet = content.planet(requiredMasteryPlanetId);
      final requiredCommissioned = requiredPlanet.sites
          .where((site) => state.sites[site.id]?.commissioned == true)
          .length;
      requirements.add(
        StellarMapRequirementView(
          label:
              '${requiredPlanet.name} sites '
              '$requiredCommissioned/${requiredPlanet.sites.length}',
          isSatisfied: hasRequiredMastery,
        ),
      );
      requirements.add(
        StellarMapRequirementView(
          label: 'Surveying ${definition.unlockRequiredSurveyingLevel}',
          isSatisfied:
              state.technology.surveying >=
              definition.unlockRequiredSurveyingLevel,
        ),
      );
    }
    if (requiredMasteryPlanetId != null && definition.unlockCashCost > 0) {
      requirements.add(
        StellarMapRequirementView(
          label: '${definition.unlockCashCost} cash',
          isSatisfied: state.cash >= definition.unlockCashCost,
        ),
      );
    }

    return StellarMapPlanetView(
      id: definition.id,
      name: definition.name,
      isUnlocked: state.unlockedPlanetIds.contains(definition.id),
      isActive: state.activePlanetId == definition.id,
      sitesCommissioned: sitesCommissioned,
      siteTotal: definition.sites.length,
      requiredMasteryPlanetId: requiredMasteryPlanetId,
      hasRequiredMastery: hasRequiredMastery,
      requiredSurveyingLevel: definition.unlockRequiredSurveyingLevel,
      hasSurveying:
          state.technology.surveying >= definition.unlockRequiredSurveyingLevel,
      unlockCashCost: definition.unlockCashCost,
      hasCash: state.cash >= definition.unlockCashCost,
      cargo: cargo,
      capacity: capacity,
      rate: rate,
      projectedValue: projectedValue.floor(),
      siteIndicators: List<StellarMapSiteIndicatorView>.unmodifiable(
        indicators,
      ),
      requirements: List<StellarMapRequirementView>.unmodifiable(requirements),
      isBusy: isBusy,
    );
  }
}
