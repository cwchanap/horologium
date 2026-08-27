import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

enum MiningSiteCardState { locked, available, idle, operational }

class MiningSiteCardView {
  const MiningSiteCardView({
    required this.id,
    required this.definition,
    required this.state,
    required this.isUnlocked,
    required this.isCommissioned,
    required this.deployedRigs,
    required this.cargo,
    required this.capacity,
    required this.rate,
    required this.projectedValue,
    required this.canEnter,
    required this.canUnlock,
    required this.unlockCost,
    required this.unlockDisabledReason,
    required this.isBusy,
  });

  final MiningSiteId id;
  final MiningSiteDefinition definition;
  final MiningSiteCardState state;
  final bool isUnlocked;
  final bool isCommissioned;
  final List<RigTier> deployedRigs;
  final double cargo;
  final double capacity;
  final double rate;
  final int projectedValue;
  final bool canEnter;
  final bool canUnlock;
  final int unlockCost;
  final String? unlockDisabledReason;
  final bool isBusy;

  String get name => definition.name;
  String get cardAsset => definition.cardAsset;
  double get storedAmount => cargo;
  double get projectedSale => projectedValue.toDouble();
  int get deployedRigCount => deployedRigs.length;
  bool get isOperational => state == MiningSiteCardState.operational;
  String? get disabledReason => unlockDisabledReason;
  MiningSiteId? get requiredSite => definition.requiredSite;
  int get requiredSurveyingLevel => definition.requiredSurveyingLevel;
}

/// Presentation projection for the active planet's Site Deck.
class SiteDeckView {
  const SiteDeckView({
    required this.activePlanetId,
    required this.planetName,
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
    var projectedValue = 0.0;

    for (final definition in planet.sites) {
      final progress = state.sites[definition.id]!;
      final deployedRigs = progress.rigByNode.values
          .whereType<RigTier>()
          .toList();
      final hasRigs = deployedRigs.isNotEmpty;
      final siteCapacity = hasRigs
          ? content.effectiveSiteCapacity(
              definition.id,
              deployedRigs,
              state.technology.logistics,
            )
          : 0.0;
      final siteRate = hasRigs
          ? content.effectiveSiteRate(
              definition.id,
              deployedRigs,
              state.technology.extraction,
            )
          : 0.0;
      final siteProjectedValue =
          (progress.storedAmount * definition.saleValuePerUnit).floor();
      final cardState = !progress.unlocked
          ? MiningSiteCardState.locked
          : !progress.commissioned
          ? MiningSiteCardState.available
          : hasRigs
          ? MiningSiteCardState.operational
          : MiningSiteCardState.idle;
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
      totalCapacity += siteCapacity;
      totalRate += siteRate;
      projectedValue += progress.storedAmount * definition.saleValuePerUnit;
      cardList.add(
        MiningSiteCardView(
          id: definition.id,
          definition: definition,
          state: cardState,
          isUnlocked: progress.unlocked,
          isCommissioned: progress.commissioned,
          deployedRigs: List<RigTier>.unmodifiable(deployedRigs),
          cargo: progress.storedAmount,
          capacity: siteCapacity,
          rate: siteRate,
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
      sites: List<MiningSiteCardView>.unmodifiable(cardList),
      cards: Map<MiningSiteId, MiningSiteCardView>.unmodifiable(cards),
      commissionedCount: commissionedCount,
      siteCount: planet.sites.length,
      totalCargo: totalCargo,
      totalCapacity: totalCapacity,
      totalRate: totalRate,
      projectedValue: projectedValue.floor(),
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
      return 'Need ${definition.unlockCost} cash.';
    }
    return null;
  }
}

typedef SiteDeckCardView = MiningSiteCardView;
