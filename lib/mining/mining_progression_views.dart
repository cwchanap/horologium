import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

class TechnologyTrackView {
  const TechnologyTrackView({
    required this.track,
    required this.name,
    required this.level,
    required this.currentEffect,
    required this.nextEffect,
    required this.cost,
    String? gateSiteName,
    String? gateSectorName,
    required this.isGateSatisfied,
    required this.isAffordable,
    required this.isMaxLevel,
    required this.disabledReason,
  }) : gateSiteName = gateSiteName ?? gateSectorName;

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

  /// Kept as a source-compatible alias while the presentation cutover lands.
  String? get gateSectorName => gateSiteName;

  bool get canPurchase => !isMaxLevel && isGateSatisfied && isAffordable;
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
    tracks: [
      for (final track in TechnologyTrack.values)
        _trackView(state, content, track),
    ],
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
}

class StellarMapPlanetView {
  const StellarMapPlanetView({
    required this.id,
    required this.name,
    required this.isUnlocked,
    required this.isActive,
    int? sitesCommissioned,
    int? siteTotal,
    int? minesBuilt,
    int? mineTotal,
    required this.requiredMasteryPlanetId,
    required this.hasRequiredMastery,
    required this.requiredSurveyingLevel,
    required this.hasSurveying,
    required this.unlockCashCost,
    required this.hasCash,
  }) : sitesCommissioned = sitesCommissioned ?? minesBuilt ?? 0,
       siteTotal = siteTotal ?? mineTotal ?? 0;

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

  /// Kept as source-compatible aliases while Stellar Map presentation moves.
  int get minesBuilt => sitesCommissioned;
  int get mineTotal => siteTotal;

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
  }) {
    final unlockedPlanetIds = state.unlockedPlanetIds;
    final commissionedSiteIds = state.sites.entries
        .where((entry) => entry.value.commissioned)
        .map((entry) => entry.key);

    return StellarMapView(
      planets: [
        for (final definition in content.planets.values)
          if (_isVisible(definition, unlockedPlanetIds))
            _planetView(state, content, definition, commissionedSiteIds),
      ],
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
    Iterable<MiningSiteId> commissionedSiteIds,
  ) {
    final requiredMasteryPlanetId = definition.unlockRequiredMasteryPlanetId;
    final hasRequiredMastery =
        requiredMasteryPlanetId == null ||
        content.isPlanetMastered(requiredMasteryPlanetId, commissionedSiteIds);
    final sitesCommissioned = definition.sites
        .where((site) => state.sites[site.id]?.commissioned == true)
        .length;

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
    );
  }
}
