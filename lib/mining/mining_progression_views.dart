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
    required this.gateSectorName,
    required this.isGateSatisfied,
    required this.isAffordable,
    required this.isMaxLevel,
    required this.disabledReason,
  });

  final TechnologyTrack track;
  final String name;
  final int level;
  final String currentEffect;
  final String? nextEffect;
  final int? cost;
  final String? gateSectorName;
  final bool isGateSatisfied;
  final bool isAffordable;
  final bool isMaxLevel;
  final String? disabledReason;

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
        gateSectorName: null,
        isGateSatisfied: true,
        isAffordable: true,
        isMaxLevel: true,
        disabledReason: 'Technology is at max level.',
      );
    }

    final gateSector = MiningContentRegistry.technologyMineGates[level];
    final gateSatisfied = state.sectors[gateSector]?.mine != null;
    final cost = MiningContentRegistry.technologyCosts[level];
    final affordable = state.cash >= cost;

    return TechnologyTrackView(
      track: track,
      name: name,
      level: level,
      currentEffect: _effect(state, content, track, level),
      nextEffect: _effect(state, content, track, level + 1),
      cost: cost,
      gateSectorName: content.sector(gateSector).name,
      isGateSatisfied: gateSatisfied,
      isAffordable: affordable,
      isMaxLevel: false,
      disabledReason: !gateSatisfied
          ? 'Build the ${content.sector(gateSector).name} mine first.'
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
        final total = unlockedPlanets.expand((planet) => planet.sectors).length;
        final revealable = unlockedPlanets
            .expand((planet) => planet.sectors)
            .where((sector) => sector.requiredSurveyingLevel <= level)
            .length;
        return '$revealable of $total sectors revealable';
    }
  }
}

class StellarMapPlanetView {
  const StellarMapPlanetView({
    required this.id,
    required this.name,
    required this.isUnlocked,
    required this.isActive,
    required this.minesBuilt,
    required this.mineTotal,
    required this.requiredMasteryPlanetId,
    required this.hasRequiredMastery,
    required this.requiredSurveyingLevel,
    required this.hasSurveying,
    required this.unlockCashCost,
    required this.hasCash,
  });

  final MiningPlanetId id;
  final String name;
  final bool isUnlocked;
  final bool isActive;
  final int minesBuilt;
  final int mineTotal;
  final MiningPlanetId? requiredMasteryPlanetId;
  final bool hasRequiredMastery;
  final int requiredSurveyingLevel;
  final bool hasSurveying;
  final int unlockCashCost;
  final bool hasCash;

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
    final minedSectorIds = state.sectors.entries
        .where((entry) => entry.value.mine != null)
        .map((entry) => entry.key);

    return StellarMapView(
      planets: [
        for (final definition in content.planets.values)
          if (_isVisible(definition, unlockedPlanetIds))
            _planetView(state, content, definition, minedSectorIds),
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
    Iterable<MiningSectorId> minedSectorIds,
  ) {
    final requiredMasteryPlanetId = definition.unlockRequiredMasteryPlanetId;
    final hasRequiredMastery =
        requiredMasteryPlanetId == null ||
        content.isPlanetMastered(requiredMasteryPlanetId, minedSectorIds);
    final minesBuilt = definition.sectors
        .where((sector) => state.sectors[sector.id]?.mine != null)
        .length;

    return StellarMapPlanetView(
      id: definition.id,
      name: definition.name,
      isUnlocked: state.unlockedPlanetIds.contains(definition.id),
      isActive: state.activePlanetId == definition.id,
      minesBuilt: minesBuilt,
      mineTotal: definition.sectors.length,
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
