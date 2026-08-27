import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_state.dart';

SiteProgress progress({bool unlocked = false, bool commissioned = false}) =>
    SiteProgress(
      unlocked: unlocked,
      commissioned: commissioned,
      storedAmount: 0,
      rigByNode: {for (final node in MiningNodeId.values) node: null},
    );

MiningSave stateWith({
  required DateTime now,
  int? cash,
  TechnologyLevels? technology,
  Set<MiningPlanetId>? unlockedPlanets,
  Map<MiningSiteId, SiteProgress>? sites,
}) {
  var base = MiningSave.initial(nowUtc: now);
  if (unlockedPlanets != null) {
    base = base.copyWith(unlockedPlanetIds: unlockedPlanets);
  }
  return base.copyWith(
    cash: cash,
    technology: technology,
    sites: sites == null ? null : {...base.sites, ...sites},
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();
  final now = DateTime.utc(2026, 8, 18, 12);

  group('TechnologySheetView', () {
    test(
      'exposes level, effects, cost, commissioned gate, and affordability',
      () {
        final view = TechnologySheetView.from(
          state: stateWith(
            now: now,
            cash: 500,
            sites: {
              MiningSiteId.landingBasin: progress(
                unlocked: true,
                commissioned: true,
              ),
            },
          ),
          content: content,
        );
        final extraction = view.track(TechnologyTrack.extraction);
        expect(extraction.level, 0);
        expect(extraction.currentEffect, 'Mining rate ×1.00');
        expect(extraction.nextEffect, 'Mining rate ×1.10');
        expect(extraction.cost, 300);
        expect(extraction.gateSiteName, 'Landing Basin');
        expect(extraction.isGateSatisfied, isTrue);
        expect(extraction.isAffordable, isTrue);
        expect(extraction.canPurchase, isTrue);
        expect(extraction.disabledReason, isNull);
      },
    );

    test('uncommissioned gate blocks purchase even with cash', () {
      final view = TechnologySheetView.from(
        state: stateWith(now: now, cash: 500),
        content: content,
      );
      final extraction = view.track(TechnologyTrack.extraction);
      expect(extraction.isGateSatisfied, isFalse);
      expect(extraction.canPurchase, isFalse);
      expect(
        extraction.disabledReason,
        'Commission the Landing Basin site first.',
      );
    });

    test('insufficient cash blocks purchase when gate is commissioned', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          cash: 200,
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
            ),
          },
        ),
        content: content,
      );
      final extraction = view.track(TechnologyTrack.extraction);
      expect(extraction.isAffordable, isFalse);
      expect(extraction.canPurchase, isFalse);
      expect(extraction.disabledReason, 'Need 300 cash.');
    });

    test('gate and cost advance with the current level', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          cash: 800,
          technology: const TechnologyLevels(extraction: 1),
          sites: {
            MiningSiteId.carbonRidge: progress(
              unlocked: true,
              commissioned: true,
            ),
          },
        ),
        content: content,
      );
      final extraction = view.track(TechnologyTrack.extraction);
      expect(extraction.level, 1);
      expect(extraction.cost, 700);
      expect(extraction.gateSiteName, 'Carbon Ridge');
      expect(extraction.currentEffect, 'Mining rate ×1.10');
      expect(extraction.nextEffect, 'Mining rate ×1.25');
      expect(extraction.canPurchase, isTrue);
    });

    test('max level exposes max state without cost or next effect', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          cash: 99999,
          technology: const TechnologyLevels(extraction: 5),
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
            ),
          },
        ),
        content: content,
      );
      final extraction = view.track(TechnologyTrack.extraction);
      expect(extraction.isMaxLevel, isTrue);
      expect(extraction.cost, isNull);
      expect(extraction.nextEffect, isNull);
      expect(extraction.gateSiteName, isNull);
      expect(extraction.canPurchase, isFalse);
      expect(extraction.disabledReason, 'Technology is at max level.');
    });

    test('logistics effect strings reflect multipliers and offline cap', () {
      final view = TechnologySheetView.from(
        state: stateWith(now: now),
        content: content,
      );
      final logistics = view.track(TechnologyTrack.logistics);
      expect(logistics.currentEffect, 'Mine capacity ×1.00, offline cap 8h');
      expect(logistics.nextEffect, 'Mine capacity ×1.15, offline cap 10h');
    });

    test(
      'surveying effect counts unlockable sites on currently unlocked planets',
      () {
        final view = TechnologySheetView.from(
          state: stateWith(now: now),
          content: content,
        );
        expect(
          view.track(TechnologyTrack.surveying).currentEffect,
          '3 of 3 sites revealable',
        );

        final advanced = TechnologySheetView.from(
          state: stateWith(
            now: now,
            technology: const TechnologyLevels(surveying: 3),
            unlockedPlanets: {
              MiningPlanetId.homeworld,
              MiningPlanetId.lunarFrontier,
            },
          ),
          content: content,
        );
        expect(
          advanced.track(TechnologyTrack.surveying).currentEffect,
          '4 of 6 sites revealable',
        );

        final mars = TechnologySheetView.from(
          state: stateWith(
            now: now,
            technology: const TechnologyLevels(surveying: 5),
            unlockedPlanets: {
              MiningPlanetId.homeworld,
              MiningPlanetId.lunarFrontier,
              MiningPlanetId.marsFrontier,
            },
          ),
          content: content,
        );
        expect(
          mars.track(TechnologyTrack.surveying).currentEffect,
          '9 of 9 sites revealable',
        );
      },
    );
  });

  group('StellarMapView', () {
    Map<MiningSiteId, SiteProgress> commissionedSites(MiningPlanetId planetId) {
      final sites = <MiningSiteId, SiteProgress>{};
      for (final definition in content.planet(planetId).sites) {
        sites[definition.id] = progress(unlocked: true, commissioned: true);
      }
      return sites;
    }

    test('fresh save shows Homeworld and Lunar but not Mars', () {
      final view = StellarMapView.from(
        state: MiningSave.initial(nowUtc: now),
        content: content,
      );

      expect(view.planets.map((planet) => planet.id), [
        MiningPlanetId.homeworld,
        MiningPlanetId.lunarFrontier,
      ]);
      expect(
        view.planets.any((planet) => planet.id == MiningPlanetId.marsFrontier),
        isFalse,
      );
      expect(view.planet(MiningPlanetId.lunarFrontier).canUnlock, isFalse);
    });

    test('Lunar unlock reveals a locked Mars entry', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
        ),
        content: content,
      );

      expect(view.planets.map((planet) => planet.id), [
        MiningPlanetId.homeworld,
        MiningPlanetId.lunarFrontier,
        MiningPlanetId.marsFrontier,
      ]);
      expect(view.planet(MiningPlanetId.marsFrontier).isUnlocked, isFalse);
      expect(view.planet(MiningPlanetId.marsFrontier).canUnlock, isFalse);
    });

    test('each planet reports commissioned progress from its own sites', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
            MiningPlanetId.marsFrontier,
          },
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
            ),
            MiningSiteId.frozenBasin: progress(
              unlocked: true,
              commissioned: true,
            ),
            MiningSiteId.titaniumHighlands: progress(
              unlocked: true,
              commissioned: true,
            ),
            MiningSiteId.ochreBasin: progress(
              unlocked: true,
              commissioned: true,
            ),
          },
        ),
        content: content,
      );

      expect(view.planet(MiningPlanetId.homeworld).sitesCommissioned, 1);
      expect(view.planet(MiningPlanetId.homeworld).siteTotal, 3);
      expect(view.planet(MiningPlanetId.lunarFrontier).sitesCommissioned, 2);
      expect(view.planet(MiningPlanetId.lunarFrontier).siteTotal, 3);
      expect(view.planet(MiningPlanetId.marsFrontier).sitesCommissioned, 1);
      expect(view.planet(MiningPlanetId.marsFrontier).siteTotal, 3);
    });

    test('locked Lunar references Homeworld commissioned mastery', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          sites: commissionedSites(MiningPlanetId.homeworld),
        ),
        content: content,
      );

      final lunar = view.planet(MiningPlanetId.lunarFrontier);
      expect(lunar.requiredMasteryPlanetId, MiningPlanetId.homeworld);
      expect(lunar.hasRequiredMastery, isTrue);
      expect(lunar.sitesCommissioned, 0);
      expect(lunar.siteTotal, 3);
      expect(lunar.canUnlock, isFalse);
    });

    test('locked Mars references Lunar mastery and authored requirements', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 20000,
          technology: const TechnologyLevels(surveying: 5),
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          sites: {
            ...commissionedSites(MiningPlanetId.homeworld),
            ...commissionedSites(MiningPlanetId.lunarFrontier),
          },
        ),
        content: content,
      );

      final mars = view.planet(MiningPlanetId.marsFrontier);
      expect(mars.requiredMasteryPlanetId, MiningPlanetId.lunarFrontier);
      expect(mars.hasRequiredMastery, isTrue);
      expect(mars.requiredSurveyingLevel, 5);
      expect(mars.hasSurveying, isTrue);
      expect(mars.unlockCashCost, 20000);
      expect(mars.hasCash, isTrue);
      expect(mars.canUnlock, isTrue);
    });

    test('unlocked planet is not unlockable when requirements are met', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 20000,
          technology: const TechnologyLevels(surveying: 5),
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
            MiningPlanetId.marsFrontier,
          },
          sites: {
            ...commissionedSites(MiningPlanetId.homeworld),
            ...commissionedSites(MiningPlanetId.lunarFrontier),
          },
        ),
        content: content,
      );

      final mars = view.planet(MiningPlanetId.marsFrontier);
      expect(mars.isUnlocked, isTrue);
      expect(mars.isActive, isFalse);
      expect(mars.canUnlock, isFalse);
    });
  });
}
