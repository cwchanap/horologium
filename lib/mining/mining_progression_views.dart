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
        currentEffect: _effect(content, track, level),
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
      currentEffect: _effect(content, track, level),
      nextEffect: _effect(content, track, level + 1),
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
        final total = content.planets.values
            .expand((planet) => planet.sectors)
            .length;
        final revealable = content.planets.values
            .expand((planet) => planet.sectors)
            .where((sector) => sector.requiredSurveyingLevel <= level)
            .length;
        return '$revealable of $total sectors revealable';
    }
  }
}

class StellarMapView {
  const StellarMapView({
    required this.homeworldMinesBuilt,
    required this.homeworldMineTotal,
    required this.hasHomeworldMastery,
    required this.requiredSurveyingLevel,
    required this.hasSurveying,
    required this.lunarUnlockCashCost,
    required this.hasCash,
    required this.isLunarUnlocked,
  });

  final int homeworldMinesBuilt;
  final int homeworldMineTotal;
  final bool hasHomeworldMastery;
  final int requiredSurveyingLevel;
  final bool hasSurveying;
  final int lunarUnlockCashCost;
  final bool hasCash;
  final bool isLunarUnlocked;

  bool get canUnlockLunar =>
      !isLunarUnlocked && hasHomeworldMastery && hasSurveying && hasCash;

  static StellarMapView from({
    required MiningSave state,
    required MiningContentRegistry content,
  }) {
    final homeworld = content.planet(MiningPlanetId.homeworld).sectors;
    final minedSectorIds = state.sectors.entries
        .where((entry) => entry.value.mine != null)
        .map((entry) => entry.key);

    return StellarMapView(
      homeworldMinesBuilt: homeworld
          .where((sector) => state.sectors[sector.id]?.mine != null)
          .length,
      homeworldMineTotal: homeworld.length,
      hasHomeworldMastery: content.isHomeworldMastered(minedSectorIds),
      requiredSurveyingLevel: MiningContentRegistry.lunarUnlockSurveyingLevel,
      hasSurveying:
          state.technology.surveying >=
          MiningContentRegistry.lunarUnlockSurveyingLevel,
      lunarUnlockCashCost: MiningContentRegistry.lunarUnlockCashCost,
      hasCash: state.cash >= MiningContentRegistry.lunarUnlockCashCost,
      isLunarUnlocked: state.unlockedPlanetIds.contains(
        MiningPlanetId.lunarFrontier,
      ),
    );
  }
}
