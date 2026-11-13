import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/site_deck_view.dart';

SiteProgress progress({bool unlocked = false, bool commissioned = false}) =>
    SiteProgress(
      unlocked: unlocked,
      commissioned: commissioned,
      storedAmount: 0,
      rigPlacements: const [],
    );

MiningSave stateWith({
  required DateTime now,
  int? cash,
  TechnologyLevels? technology,
  Set<MiningPlanetId>? unlockedPlanets,
  MiningPlanetId? activePlanetId,
  Map<MiningSiteId, SiteProgress>? sites,
}) {
  var base = MiningSave.initial(nowUtc: now);
  if (unlockedPlanets != null) {
    base = base.copyWith(unlockedPlanetIds: unlockedPlanets);
  }
  return base.copyWith(
    cash: cash,
    technology: technology,
    activePlanetId: activePlanetId,
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

    test('logistics effect strings show storage and its fill window', () {
      final view = TechnologySheetView.from(
        state: stateWith(now: now),
        content: content,
      );
      final logistics = view.track(TechnologyTrack.logistics);
      expect(logistics.currentEffect, 'Storage ×1.00 · fills in 2h 00m at T1');
      expect(logistics.nextEffect, 'Storage ×1.15 · fills in 2h 18m at T1');
    });

    test('logistics fill window shortens with current Extraction', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          technology: const TechnologyLevels(extraction: 5, logistics: 1),
        ),
        content: content,
      );
      final logistics = view.track(TechnologyTrack.logistics);
      expect(logistics.currentEffect, 'Storage ×1.15 · fills in 1h 09m at T1');
      expect(logistics.nextEffect, 'Storage ×1.30 · fills in 1h 18m at T1');
    });

    test(
      'surveying effect explains what each level adds on the active planet',
      () {
        final view = TechnologySheetView.from(
          state: stateWith(now: now),
          content: content,
        );
        final surveying = view.track(TechnologyTrack.surveying);
        expect(
          surveying.currentEffect,
          'Carbon Ridge revealed · Granite Crater revealed · '
          'Surveys 4 Homeworld deposits',
        );
        expect(surveying.nextEffect, 'Surveys 3 new Homeworld deposits');
      },
    );

    test('surveying effect names the frontier a level unlocks', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          technology: const TechnologyLevels(surveying: 2),
        ),
        content: content,
      );
      final surveying = view.track(TechnologyTrack.surveying);
      expect(surveying.currentEffect, 'Surveys 99 Homeworld deposits');
      expect(
        surveying.nextEffect,
        'Surveys 194 new Homeworld deposits · Needed for Lunar Frontier',
      );
    });

    test(
      'surveying effect follows the active planet and skips unlocked work',
      () {
        final lunar = stateWith(
          now: now,
          technology: const TechnologyLevels(surveying: 3),
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          activePlanetId: MiningPlanetId.lunarFrontier,
        );
        final surveying = TechnologySheetView.from(
          state: lunar,
          content: content,
        ).track(TechnologyTrack.surveying);
        expect(
          surveying.currentEffect,
          'Frozen Basin revealed · Surveys 2 Lunar Frontier deposits',
        );
        expect(
          surveying.nextEffect,
          'Reveals Titanium Highlands · Surveys 3 new Lunar Frontier deposits',
        );

        final siteUnlocked = TechnologySheetView.from(
          state: lunar.copyWith(
            sites: {
              ...lunar.sites,
              MiningSiteId.frozenBasin: progress(unlocked: true),
            },
          ),
          content: content,
        ).track(TechnologyTrack.surveying);
        expect(siteUnlocked.currentEffect, 'Surveys 2 Lunar Frontier deposits');
      },
    );

    test('surveying effect admits when a level adds nothing on the planet', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          technology: const TechnologyLevels(surveying: 3),
        ),
        content: content,
      );
      expect(
        view.track(TechnologyTrack.surveying).nextEffect,
        'No new Homeworld deposits',
      );
    });

    test('surveying effect still describes the max level', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          technology: const TechnologyLevels(surveying: 5),
          unlockedPlanets: MiningPlanetId.values.toSet(),
          activePlanetId: MiningPlanetId.ioFrontier,
          sites: {
            for (final id in MiningSiteId.values)
              id: progress(unlocked: true, commissioned: true),
          },
        ),
        content: content,
      );
      final surveying = view.track(TechnologyTrack.surveying);
      expect(surveying.isMaxLevel, isTrue);
      expect(surveying.nextEffect, isNull);
      expect(surveying.currentEffect, 'Surveys 300 Io Frontier deposits');
    });

    test('isBusy disables track purchase and explains the pending wait', () {
      final view = TechnologySheetView.from(
        state: stateWith(now: now, cash: 1000000),
        content: content,
        isBusy: true,
      );
      final track = view.track(TechnologyTrack.extraction);
      expect(track.canPurchase, isFalse);
      expect(track.disabledReason, 'Finishing previous action…');
    });
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

    test('Ceres stays hidden until Mars is unlocked', () {
      final lunar = StellarMapView.from(
        state: stateWith(
          now: now,
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
        ),
        content: content,
      );
      expect(
        lunar.planets.any(
          (planet) => planet.id == MiningPlanetId.ceresFrontier,
        ),
        isFalse,
      );

      final mars = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 30000000,
          technology: const TechnologyLevels(surveying: 5),
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
            MiningPlanetId.marsFrontier,
          },
          sites: {
            ...commissionedSites(MiningPlanetId.homeworld),
            ...commissionedSites(MiningPlanetId.lunarFrontier),
            ...commissionedSites(MiningPlanetId.marsFrontier),
          },
        ),
        content: content,
      );
      expect(mars.planets.map((planet) => planet.id), [
        MiningPlanetId.homeworld,
        MiningPlanetId.lunarFrontier,
        MiningPlanetId.marsFrontier,
        MiningPlanetId.ceresFrontier,
      ]);
      final ceres = mars.planet(MiningPlanetId.ceresFrontier);
      expect(ceres.isUnlocked, isFalse);
      expect(ceres.requiredMasteryPlanetId, MiningPlanetId.marsFrontier);
      expect(ceres.hasRequiredMastery, isTrue);
      expect(ceres.requiredSurveyingLevel, 5);
      expect(ceres.unlockCashCost, 30000000);
      expect(ceres.siteTotal, 3);
      expect(ceres.canUnlock, isTrue);
    });

    test('Io stays hidden until Ceres is unlocked, then shows its gates', () {
      final mars = StellarMapView.from(
        state: stateWith(
          now: now,
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
            MiningPlanetId.marsFrontier,
          },
        ),
        content: content,
      );
      expect(
        mars.planets.any((planet) => planet.id == MiningPlanetId.ioFrontier),
        isFalse,
      );

      final ioUnlockCost = content
          .planet(MiningPlanetId.ioFrontier)
          .unlockCashCost;
      final ceres = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: ioUnlockCost,
          technology: const TechnologyLevels(surveying: 5),
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
            MiningPlanetId.marsFrontier,
            MiningPlanetId.ceresFrontier,
          },
          sites: {
            ...commissionedSites(MiningPlanetId.homeworld),
            ...commissionedSites(MiningPlanetId.lunarFrontier),
            ...commissionedSites(MiningPlanetId.marsFrontier),
            ...commissionedSites(MiningPlanetId.ceresFrontier),
          },
        ),
        content: content,
      );
      expect(ceres.planets.map((planet) => planet.id), [
        MiningPlanetId.homeworld,
        MiningPlanetId.lunarFrontier,
        MiningPlanetId.marsFrontier,
        MiningPlanetId.ceresFrontier,
        MiningPlanetId.ioFrontier,
      ]);
      final io = ceres.planet(MiningPlanetId.ioFrontier);
      expect(io.isUnlocked, isFalse);
      expect(io.requiredMasteryPlanetId, MiningPlanetId.ceresFrontier);
      expect(io.hasRequiredMastery, isTrue);
      expect(io.requiredSurveyingLevel, 5);
      expect(io.hasSurveying, isTrue);
      expect(io.unlockCashCost, ioUnlockCost);
      expect(io.hasCash, isTrue);
      expect(io.siteTotal, 3);
      expect(io.canUnlock, isTrue);
      expect(io.requirements.map((requirement) => requirement.label), [
        'Ceres Frontier sites 3/3',
        'Surveying 5',
        '90.00M cash',
      ]);
      expect(io.requirements.map((requirement) => requirement.isSatisfied), [
        true,
        true,
        true,
      ]);
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
          cash: 16000000,
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
      expect(mars.unlockCashCost, 16000000);
      expect(mars.hasCash, isTrue);
      expect(mars.canUnlock, isTrue);
    });

    test('unlocked planet is not unlockable when requirements are met', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 16000000,
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

    test('an unlocked paid planet keeps its cash gate satisfied', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 0,
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
      expect(mars.hasCash, isTrue);
      expect(mars.canUnlock, isFalse);
      expect(
        mars.requirements
            .singleWhere((requirement) => requirement.label == '16.00M cash')
            .isSatisfied,
        isTrue,
      );
    });

    test('reports planet totals, requirements, indicators, and busy state', () {
      final view = StellarMapView.from(
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
        isBusy: true,
      );

      final homeworld = view.planet(MiningPlanetId.homeworld);
      expect(homeworld.isBusy, isTrue);
      expect(homeworld.commissionedCount, 1);
      expect(homeworld.siteIndicators, hasLength(3));
      expect(homeworld.siteIndicators.first.state, MiningSiteCardState.idle);
      expect(homeworld.cargo, 0);
      expect(homeworld.capacity, 0);
      expect(homeworld.rate, 0);
      expect(homeworld.projectedValue, 0);
      expect(homeworld.requirements, isEmpty);
      expect(
        () => homeworld.siteIndicators.add(homeworld.siteIndicators.first),
        throwsUnsupportedError,
      );
      expect(() => view.planets.add(homeworld), throwsUnsupportedError);
    });

    test(
      'locked planet requirements use commissioned mastery, surveying, and cash',
      () {
        final view = StellarMapView.from(
          state: stateWith(now: now, cash: 100),
          content: content,
        );
        final lunar = view.planet(MiningPlanetId.lunarFrontier);

        expect(
          lunar.requirements.map((requirement) => requirement.isSatisfied),
          [false, false, false],
        );
        expect(lunar.requirements.map((requirement) => requirement.label), [
          'Homeworld sites 0/3',
          'Surveying 3',
          '200,000 cash',
        ]);
      },
    );

    test('unmet successor gates project current cash and Surveying values', () {
      final view = StellarMapView.from(
        state: stateWith(now: now, cash: 100),
        content: content,
      );
      final lunar = view.planet(MiningPlanetId.lunarFrontier);

      expect(lunar.requirements.map((requirement) => requirement.label), [
        'Homeworld sites 0/3',
        'Surveying 3',
        '200,000 cash',
      ]);
      expect(lunar.requirements.map((requirement) => requirement.isSatisfied), [
        false,
        false,
        false,
      ]);
      expect(
        lunar.requirements.map((requirement) => requirement.currentValue),
        [null, 'now LV 0', '100'],
      );
    });

    test('met successor gates project their current values', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 200000,
          technology: const TechnologyLevels(surveying: 3),
          sites: commissionedSites(MiningPlanetId.homeworld),
        ),
        content: content,
      );
      final lunar = view.planet(MiningPlanetId.lunarFrontier);

      expect(lunar.canUnlock, isTrue);
      expect(lunar.requirements.map((requirement) => requirement.label), [
        'Homeworld sites 3/3',
        'Surveying 3',
        '200,000 cash',
      ]);
      expect(lunar.requirements.map((requirement) => requirement.isSatisfied), [
        true,
        true,
        true,
      ]);
      expect(
        lunar.requirements.map((requirement) => requirement.currentValue),
        [null, 'now LV 3', '200,000'],
      );
    });

    test('current values follow live cash and Surveying, not thresholds', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 1234567,
          technology: const TechnologyLevels(surveying: 2),
        ),
        content: content,
      );
      final lunar = view.planet(MiningPlanetId.lunarFrontier);

      expect(lunar.requirements.map((requirement) => requirement.label), [
        'Homeworld sites 0/3',
        'Surveying 3',
        '200,000 cash',
      ]);
      expect(lunar.requirements.map((requirement) => requirement.isSatisfied), [
        false,
        false,
        true,
      ]);
      expect(
        lunar.requirements.map((requirement) => requirement.currentValue),
        [null, 'now LV 2', '1.23M'],
      );
    });

    test('unlocked planets keep their gates and project live cash', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 0,
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
      expect(mars.requirements.map((requirement) => requirement.label), [
        'Lunar Frontier sites 3/3',
        'Surveying 5',
        '16.00M cash',
      ]);
      expect(mars.requirements.map((requirement) => requirement.isSatisfied), [
        true,
        true,
        true,
      ]);
      expect(mars.requirements.map((requirement) => requirement.currentValue), [
        null,
        'now LV 5',
        '0',
      ]);
    });

    test('a zero-cost planet invents no cash gate or current value', () {
      expect(content.planet(MiningPlanetId.homeworld).unlockCashCost, 0);
      final view = StellarMapView.from(
        state: MiningSave.initial(nowUtc: now),
        content: content,
      );

      expect(view.planet(MiningPlanetId.homeworld).requirements, isEmpty);
      const requirement = StellarMapRequirementView(
        label: 'Homeworld sites 3/3',
        isSatisfied: true,
      );
      expect(requirement.currentValue, isNull);
    });

    test('relaunch reads derive from final-planet mastery and busy state', () {
      MiningSave masteredSave({int relaunchCount = 0}) => stateWith(
        now: now,
        technology: const TechnologyLevels(surveying: 5),
        unlockedPlanets: MiningPlanetId.values.toSet(),
        sites: {
          for (final id in MiningSiteId.values)
            id: progress(unlocked: true, commissioned: true),
        },
      ).copyWith(relaunchCount: relaunchCount);

      // The final planet one site short of mastery keeps relaunch locked.
      final shortOneSite = StellarMapView.from(
        state: masteredSave().copyWith(
          sites: {
            ...masteredSave().sites,
            MiningSiteId.osmiumCaldera: progress(unlocked: true),
          },
        ),
        content: content,
      );
      expect(shortOneSite.isRelaunchUnlocked, isFalse);
      expect(shortOneSite.canRelaunch, isFalse);

      final mastered = StellarMapView.from(
        state: masteredSave(),
        content: content,
      );
      expect(mastered.isRelaunchUnlocked, isTrue);
      expect(mastered.canRelaunch, isTrue);
      expect(mastered.relaunchCount, 0);
      expect(mastered.nextSaleMultiplier, 1.5);

      // Busy keeps the unlock state but disables the action.
      final busy = StellarMapView.from(
        state: masteredSave(relaunchCount: 1),
        content: content,
        isBusy: true,
      );
      expect(busy.isRelaunchUnlocked, isTrue);
      expect(busy.canRelaunch, isFalse);
      expect(busy.relaunchCount, 1);
      expect(busy.nextSaleMultiplier, 2.0);
    });
  });
}
