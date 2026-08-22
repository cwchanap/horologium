import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/mining_state.dart';

MiningSave stateWith({
  required DateTime now,
  int? cash,
  TechnologyLevels? technology,
  Set<MiningPlanetId>? unlockedPlanets,
  Map<MiningSectorId, SectorProgress>? sectors,
}) {
  var base = MiningSave.initial(nowUtc: now);
  if (unlockedPlanets != null) {
    base = base.copyWith(unlockedPlanetIds: unlockedPlanets);
  }
  return base.copyWith(cash: cash, technology: technology, sectors: sectors);
}

SectorProgress mined({int level = 1, double stored = 0}) => SectorProgress(
  revealed: true,
  mine: MineState(level: level, storedAmount: stored),
);

void main() {
  final content = MiningContentRegistry.stellarMining();
  final now = DateTime.utc(2026, 8, 18, 12);

  group('TechnologySheetView', () {
    test('exposes level, effects, cost, gate, and affordability', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          cash: 500,
          sectors: {MiningSectorId.landingBasin: mined()},
        ),
        content: content,
      );
      final extraction = view.track(TechnologyTrack.extraction);
      expect(extraction.level, 0);
      expect(extraction.currentEffect, 'Mining rate ×1.00');
      expect(extraction.nextEffect, 'Mining rate ×1.10');
      expect(extraction.cost, 300);
      expect(extraction.gateSectorName, 'Landing Basin');
      expect(extraction.isGateSatisfied, isTrue);
      expect(extraction.isAffordable, isTrue);
      expect(extraction.isMaxLevel, isFalse);
      expect(extraction.canPurchase, isTrue);
      expect(extraction.disabledReason, isNull);
    });

    test('unbuilt gate mine blocks purchase even with cash', () {
      final view = TechnologySheetView.from(
        state: stateWith(now: now, cash: 500),
        content: content,
      );
      final extraction = view.track(TechnologyTrack.extraction);
      expect(extraction.isGateSatisfied, isFalse);
      expect(extraction.canPurchase, isFalse);
      expect(extraction.disabledReason, 'Build the Landing Basin mine first.');
    });

    test('insufficient cash blocks purchase when gate is satisfied', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          cash: 200,
          sectors: {MiningSectorId.landingBasin: mined()},
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
          sectors: {MiningSectorId.carbonRidge: mined()},
        ),
        content: content,
      );
      final extraction = view.track(TechnologyTrack.extraction);
      expect(extraction.level, 1);
      expect(extraction.cost, 700);
      expect(extraction.gateSectorName, 'Carbon Ridge');
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
          sectors: {MiningSectorId.landingBasin: mined()},
        ),
        content: content,
      );
      final extraction = view.track(TechnologyTrack.extraction);
      expect(extraction.isMaxLevel, isTrue);
      expect(extraction.cost, isNull);
      expect(extraction.nextEffect, isNull);
      expect(extraction.gateSectorName, isNull);
      expect(extraction.canPurchase, isFalse);
      expect(extraction.disabledReason, 'Technology is at max level.');
    });

    test('logistics effect strings reflect multipliers and offline cap', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          sectors: {MiningSectorId.landingBasin: mined()},
        ),
        content: content,
      );
      final logistics = view.track(TechnologyTrack.logistics);
      expect(logistics.currentEffect, 'Mine capacity ×1.00, offline cap 8h');
      expect(logistics.nextEffect, 'Mine capacity ×1.15, offline cap 10h');
    });

    test('surveying effect counts revealable sectors', () {
      final view = TechnologySheetView.from(
        state: stateWith(
          now: now,
          sectors: {MiningSectorId.landingBasin: mined()},
        ),
        content: content,
      );
      final surveying = view.track(TechnologyTrack.surveying);
      expect(surveying.currentEffect, '3 of 6 sectors revealable');
      expect(surveying.nextEffect, '3 of 6 sectors revealable');

      final advanced = TechnologySheetView.from(
        state: stateWith(
          now: now,
          technology: const TechnologyLevels(surveying: 3),
          sectors: {MiningSectorId.landingBasin: mined()},
        ),
        content: content,
      );
      expect(
        advanced.track(TechnologyTrack.surveying).currentEffect,
        '4 of 6 sectors revealable',
      );
    });
  });

  group('StellarMapView', () {
    final masteredHomeworld = {
      MiningSectorId.landingBasin: mined(),
      MiningSectorId.carbonRidge: mined(),
      MiningSectorId.graniteCrater: mined(),
    };

    test(
      'initial state has zero mastery and every Lunar requirement unmet',
      () {
        final view = StellarMapView.from(
          state: MiningSave.initial(nowUtc: now),
          content: content,
        );
        expect(view.homeworldMinesBuilt, 0);
        expect(view.homeworldMineTotal, 3);
        expect(view.hasHomeworldMastery, isFalse);
        expect(view.requiredSurveyingLevel, 3);
        expect(view.hasSurveying, isFalse);
        expect(view.lunarUnlockCashCost, 2500);
        expect(view.hasCash, isFalse);
        expect(view.isLunarUnlocked, isFalse);
        expect(view.canUnlockLunar, isFalse);
      },
    );

    test('mastery alone leaves surveying and cash unmet', () {
      final view = StellarMapView.from(
        state: stateWith(now: now, sectors: masteredHomeworld),
        content: content,
      );
      expect(view.homeworldMinesBuilt, 3);
      expect(view.hasHomeworldMastery, isTrue);
      expect(view.hasSurveying, isFalse);
      expect(view.hasCash, isFalse);
      expect(view.canUnlockLunar, isFalse);
    });

    test('surveying and cash alone leave mastery unmet', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 2500,
          technology: const TechnologyLevels(surveying: 3),
        ),
        content: content,
      );
      expect(view.hasHomeworldMastery, isFalse);
      expect(view.hasSurveying, isTrue);
      expect(view.hasCash, isTrue);
      expect(view.canUnlockLunar, isFalse);
    });

    test('all requirements met unlocks the Lunar affordance', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 2500,
          technology: const TechnologyLevels(surveying: 3),
          sectors: masteredHomeworld,
        ),
        content: content,
      );
      expect(view.canUnlockLunar, isTrue);
    });

    test('already unlocked Lunar disables the unlock affordance', () {
      final view = StellarMapView.from(
        state: stateWith(
          now: now,
          cash: 2500,
          technology: const TechnologyLevels(surveying: 3),
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          sectors: masteredHomeworld,
        ),
        content: content,
      );
      expect(view.isLunarUnlocked, isTrue);
      expect(view.canUnlockLunar, isFalse);
    });
  });
}
