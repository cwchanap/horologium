import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

enum MiningSiteCardState { locked, available, idle, operational }

class MiningSiteCardView {
  const MiningSiteCardView({
    required this.id,
    required this.definition,
    required this.metrics,
    required this.isUnlocked,
    required this.isCommissioned,
    required this.cargo,
    required this.projectedValue,
    required this.canEnter,
    required this.canUnlock,
    required this.unlockCost,
    required this.unlockDisabledReason,
    required this.isBusy,
  });

  final MiningSiteId id;
  final MiningSiteDefinition definition;
  final SiteMetrics metrics;
  final bool isUnlocked;
  final bool isCommissioned;
  final double cargo;
  final int projectedValue;
  final bool canEnter;
  final bool canUnlock;
  final int unlockCost;
  final String? unlockDisabledReason;
  final bool isBusy;

  MiningSiteCardState get state => metrics.cardState;
  List<RigTier> get deployedRigs => metrics.deployedRigs;
  double get capacity => metrics.capacity;
  double get rate => metrics.rate;

  String get name => definition.name;
  String get cardAsset => definition.cardAsset;
  bool get isOperational => state == MiningSiteCardState.operational;
  bool get isCargoFull => isOperational && capacity > 0 && cargo >= capacity;

  /// How long until this card's displayed storage fills, or `null` when the
  /// site is not producing or already full.
  Duration? get timeToFull => metrics.timeToFull(cargo);
  MiningSiteId? get requiredSite => definition.requiredSite;
  int get requiredSurveyingLevel => definition.requiredSurveyingLevel;
}

/// Shared per-site economy metrics derived from a [SiteProgress] under a
/// [TechnologyLevels]. Site Deck, Mine Site, and Stellar Map projections all
/// route deployed rigs, capacity, rate, and the four-way card state through
/// this so the derivations cannot drift apart.
class SiteMetrics {
  const SiteMetrics({
    required this.deployedRigs,
    required this.capacity,
    required this.rate,
    required this.cardState,
  });

  final List<RigTier> deployedRigs;
  final double capacity;
  final double rate;
  final MiningSiteCardState cardState;

  bool get hasRigs => deployedRigs.isNotEmpty;

  static SiteMetrics of({
    required MiningContentRegistry content,
    required MiningSiteDefinition site,
    required SiteProgress progress,
    required TechnologyLevels technology,
  }) {
    final deployedRigs = progress.rigPlacements
        .map((placement) => placement.tier)
        .toList();
    final hasRigs = deployedRigs.isNotEmpty;
    final capacity = hasRigs
        ? content.effectiveSiteCapacity(
            site.id,
            deployedRigs,
            technology.logistics,
          )
        : 0.0;
    final rate = hasRigs
        ? content.effectiveSiteRate(
            site.id,
            deployedRigs,
            technology.extraction,
          )
        : 0.0;
    final cardState = !progress.unlocked
        ? MiningSiteCardState.locked
        : !progress.commissioned
        ? MiningSiteCardState.available
        : hasRigs
        ? MiningSiteCardState.operational
        : MiningSiteCardState.idle;
    return SiteMetrics(
      deployedRigs: deployedRigs,
      capacity: capacity,
      rate: rate,
      cardState: cardState,
    );
  }

  /// How long until storage fills from [cargo] at the current rate, or
  /// `null` unless the site is operational, producing, and not yet full.
  Duration? timeToFull(double cargo) =>
      cardState != MiningSiteCardState.operational ||
          rate <= 0 ||
          cargo >= capacity
      ? null
      : Duration(
          microseconds:
              ((capacity - cargo) / rate * Duration.microsecondsPerSecond)
                  .ceil(),
        );
}

/// Earliest projected storage-full instant across every unlocked planet, or
/// `null` when no commissioned site is producing toward non-full storage.
/// Pure projection anchored at [MiningSave.lastAccruedAtUtc]: no clock
/// parameter, no accrual, mutation, or persistence. The shell calls this only
/// after the queued lifecycle checkpoint completes.
({MiningSiteId site, DateTime atUtc})? nextStorageFull(
  MiningContentRegistry content,
  MiningSave state,
) {
  final anchor = state.lastAccruedAtUtc.toUtc();
  ({MiningSiteId site, DateTime atUtc})? next;
  for (final entry in content.planets.entries) {
    if (!state.unlockedPlanetIds.contains(entry.key)) continue;
    for (final definition in entry.value.sites) {
      final progress = state.sites[definition.id]!;
      final metrics = SiteMetrics.of(
        content: content,
        site: definition,
        progress: progress,
        technology: state.technology,
      );
      final timeToFull = metrics.timeToFull(progress.storedAmount);
      if (timeToFull == null) continue;
      final atUtc = anchor.add(timeToFull);
      if (next == null || atUtc.isBefore(next.atUtc)) {
        next = (site: definition.id, atUtc: atUtc);
      }
    }
  }
  return next;
}

class MiningSaleAffordance {
  const MiningSaleAffordance._({
    required this.canSell,
    required this.hasUnsellableCargo,
    required this.label,
  });

  factory MiningSaleAffordance.from({
    required bool isBusy,
    required double cargo,
    required int projectedValue,
  }) {
    final canSell = !isBusy && projectedValue > 0;
    final hasUnsellableCargo = !isBusy && cargo > 0 && projectedValue == 0;
    final label = isBusy
        ? 'Finishing previous action…'
        : canSell
        ? 'Sell all cargo for ${formatMiningCash(projectedValue)} cash.'
        : hasUnsellableCargo
        ? 'Keep mining until cargo is worth at least 1 cash.'
        : 'No cargo to sell.';
    return MiningSaleAffordance._(
      canSell: canSell,
      hasUnsellableCargo: hasUnsellableCargo,
      label: label,
    );
  }

  final bool canSell;
  final bool hasUnsellableCargo;
  final String label;
}

/// Presentation projection for the active planet's Site Deck.
class SiteDeckView {
  const SiteDeckView({
    required this.activePlanetId,
    required this.planetName,
    required this.planetAsset,
    required this.sites,
    required this.cards,
    required this.commissionedCount,
    required this.siteCount,
    required this.totalCargo,
    required this.totalCapacity,
    required this.totalRate,
    required this.projectedValue,
    required this.isBusy,
  });

  final MiningPlanetId activePlanetId;
  final String planetName;
  final String planetAsset;
  final List<MiningSiteCardView> sites;
  final Map<MiningSiteId, MiningSiteCardView> cards;
  final int commissionedCount;
  final int siteCount;
  final double totalCargo;
  final double totalCapacity;
  final double totalRate;
  final int projectedValue;
  final bool isBusy;

  MiningPlanetId get planetId => activePlanetId;
  int get totalSites => siteCount;
  int get commissionedSites => commissionedCount;
  double get cargo => totalCargo;
  double get capacity => totalCapacity;
  double get rate => totalRate;
  int get projectedSale => projectedValue;

  MiningSaleAffordance get sale => MiningSaleAffordance.from(
    isBusy: isBusy,
    cargo: totalCargo,
    projectedValue: projectedValue,
  );

  MiningSiteCardView card(MiningSiteId id) => cards[id]!;

  static SiteDeckView from({
    required MiningSave state,
    required MiningContentRegistry content,
    required bool isBusy,
  }) {
    final planet = content.planet(state.activePlanetId);
    final cardList = <MiningSiteCardView>[];
    var commissionedCount = 0;
    var totalCargo = 0.0;
    var totalCapacity = 0.0;
    var totalRate = 0.0;

    for (final definition in planet.sites) {
      final progress = state.sites[definition.id]!;
      final metrics = SiteMetrics.of(
        content: content,
        site: definition,
        progress: progress,
        technology: state.technology,
      );
      final siteProjectedValue = content
          .cargoValue(definition.id, progress.storedAmount, state.relaunchCount)
          .floor();
      final unlockDisabledReason = isBusy
          ? 'Finishing previous action…'
          : _unlockDisabledReason(
              state,
              content,
              definition,
              progress.unlocked,
            );
      if (progress.commissioned) commissionedCount++;
      totalCargo += progress.storedAmount;
      totalCapacity += metrics.capacity;
      totalRate += metrics.rate;
      cardList.add(
        MiningSiteCardView(
          id: definition.id,
          definition: definition,
          metrics: metrics,
          isUnlocked: progress.unlocked,
          isCommissioned: progress.commissioned,
          cargo: progress.storedAmount,
          projectedValue: siteProjectedValue,
          canEnter: progress.unlocked,
          canUnlock:
              !isBusy && !progress.unlocked && unlockDisabledReason == null,
          unlockCost: definition.unlockCost,
          unlockDisabledReason: unlockDisabledReason,
          isBusy: isBusy,
        ),
      );
    }

    final cards = <MiningSiteId, MiningSiteCardView>{
      for (final card in cardList) card.id: card,
    };
    return SiteDeckView(
      activePlanetId: state.activePlanetId,
      planetName: planet.name,
      planetAsset: planet.planetAsset,
      sites: List<MiningSiteCardView>.unmodifiable(cardList),
      cards: Map<MiningSiteId, MiningSiteCardView>.unmodifiable(cards),
      commissionedCount: commissionedCount,
      siteCount: planet.sites.length,
      totalCargo: totalCargo,
      totalCapacity: totalCapacity,
      totalRate: totalRate,
      projectedValue: state.saleValue(content, state.activePlanetId),
      isBusy: isBusy,
    );
  }

  static String? _unlockDisabledReason(
    MiningSave state,
    MiningContentRegistry content,
    MiningSiteDefinition definition,
    bool isUnlocked,
  ) {
    if (isUnlocked) return null;
    final requiredSite = definition.requiredSite;
    if (requiredSite != null && !state.sites[requiredSite]!.unlocked) {
      return 'Unlock ${content.site(requiredSite).name} first.';
    }
    if (state.technology.surveying < definition.requiredSurveyingLevel) {
      return 'Requires Surveying ${definition.requiredSurveyingLevel}.';
    }
    if (state.cash < definition.unlockCost) {
      return 'Need ${formatMiningCash(definition.unlockCost)} cash.';
    }
    return null;
  }
}
