import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/site_deck_view.dart';

SiteProgress progress({
  bool unlocked = false,
  bool commissioned = false,
  double storedAmount = 0,
  List<MiningRigPlacement> rigs = const [],
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigPlacements: rigs,
);

MiningSave stateWith({Map<MiningSiteId, SiteProgress>? sites}) {
  final initial = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26));
  return initial.copyWith(
    sites: sites == null ? null : {...initial.sites, ...sites},
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();
  final now = DateTime.utc(2026, 8, 26);

  test('projects active-planet totals and the four card states', () {
    final view = SiteDeckView.from(
      state: stateWith(
        sites: {
          MiningSiteId.landingBasin: progress(unlocked: true),
          MiningSiteId.carbonRidge: progress(
            unlocked: true,
            commissioned: true,
          ),
          MiningSiteId.graniteCrater: progress(
            unlocked: true,
            commissioned: true,
            storedAmount: 3,
            rigs: [
              MiningRigPlacement(
                tier: RigTier.t1,
                cell: const MiningGridCell(2, 4),
              ),
            ],
          ),
        },
      ),
      content: content,
      isBusy: false,
    );

    expect(view.activePlanetId, MiningPlanetId.homeworld);
    expect(view.commissionedCount, 2);
    expect(view.siteCount, 3);
    expect(view.totalCargo, 3);
    expect(view.totalCapacity, 120);
    expect(view.projectedValue, 15);
    expect(view.totalRate, 0.6);
    expect(
      view.cards[MiningSiteId.landingBasin]!.state,
      MiningSiteCardState.available,
    );
    expect(
      view.cards[MiningSiteId.carbonRidge]!.state,
      MiningSiteCardState.idle,
    );
    expect(
      view.cards[MiningSiteId.graniteCrater]!.state,
      MiningSiteCardState.operational,
    );
    expect(view.cards[MiningSiteId.frozenBasin], isNull);
  });

  test('projects an uncommissioned prerequisite site as locked', () {
    final view = SiteDeckView.from(
      state: stateWith(),
      content: content,
      isBusy: false,
    );

    final card = view.cards[MiningSiteId.carbonRidge]!;
    expect(card.state, MiningSiteCardState.locked);
    expect(card.isUnlocked, isFalse);
    expect(card.unlockDisabledReason, 'Need 250 cash.');
  });

  test('keeps card and site outputs immutable and busy', () {
    final view = SiteDeckView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      isBusy: true,
    );

    expect(view.isBusy, isTrue);
    expect(view.sites, hasLength(3));
    expect(view.sites.first.id, MiningSiteId.landingBasin);
    expect(
      () => view.cards[MiningSiteId.landingBasin] =
          view.cards[MiningSiteId.landingBasin]!,
      throwsUnsupportedError,
    );
    expect(() => view.sites.add(view.sites.first), throwsUnsupportedError);
  });

  group('cargo-full projection', () {
    test('flags an operational site at effective capacity as full', () {
      final view = SiteDeckView.from(
        state: stateWith(
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
              storedAmount: 90,
              rigs: const [
                MiningRigPlacement(
                  tier: RigTier.t1,
                  cell: MiningGridCell(3, 2),
                ),
              ],
            ),
          },
        ),
        content: content,
        isBusy: false,
      );

      final card = view.cards[MiningSiteId.landingBasin]!;
      expect(card.state, MiningSiteCardState.operational);
      expect(card.capacity, 90);
      expect(card.cargo, 90);
      expect(card.isCargoFull, isTrue);
    });

    test('keeps an otherwise-identical under-capacity site not full', () {
      final view = SiteDeckView.from(
        state: stateWith(
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
              storedAmount: 89,
              rigs: const [
                MiningRigPlacement(
                  tier: RigTier.t1,
                  cell: MiningGridCell(3, 2),
                ),
              ],
            ),
          },
        ),
        content: content,
        isBusy: false,
      );

      final card = view.cards[MiningSiteId.landingBasin]!;
      expect(card.state, MiningSiteCardState.operational);
      expect(card.isCargoFull, isFalse);
    });

    test('keeps a commissioned idle site with zero capacity not full', () {
      final view = SiteDeckView.from(
        state: stateWith(
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
            ),
          },
        ),
        content: content,
        isBusy: false,
      );

      final card = view.cards[MiningSiteId.landingBasin]!;
      expect(card.state, MiningSiteCardState.idle);
      expect(card.capacity, 0);
      expect(card.isCargoFull, isFalse);
    });
  });

  group('MiningSaleAffordance', () {
    test('disables sale with busy copy while an action is in flight', () {
      final sale = MiningSaleAffordance.from(
        isBusy: true,
        cargo: 10,
        projectedValue: 40,
      );

      expect(sale.canSell, isFalse);
      expect(sale.hasUnsellableCargo, isFalse);
      expect(sale.label, 'Finishing previous action…');
    });

    test('enables sale with the projected cash copy', () {
      final sale = MiningSaleAffordance.from(
        isBusy: false,
        cargo: 10,
        projectedValue: 40,
      );

      expect(sale.canSell, isTrue);
      expect(sale.hasUnsellableCargo, isFalse);
      expect(sale.label, 'Sell all cargo for 40 cash.');
    });

    test('disables sale with tiny-sale copy when cargo floors to zero', () {
      final sale = MiningSaleAffordance.from(
        isBusy: false,
        cargo: 0.1,
        projectedValue: 0,
      );

      expect(sale.canSell, isFalse);
      expect(sale.hasUnsellableCargo, isTrue);
      expect(sale.label, 'Keep mining until cargo is worth at least 1 cash.');
    });

    test('disables sale with empty copy when there is no cargo', () {
      final sale = MiningSaleAffordance.from(
        isBusy: false,
        cargo: 0,
        projectedValue: 0,
      );

      expect(sale.canSell, isFalse);
      expect(sale.hasUnsellableCargo, isFalse);
      expect(sale.label, 'No cargo to sell.');
    });
  });

  group('SiteDeckView.sale', () {
    test('projects a sellable aggregate across active-planet cargo', () {
      final view = SiteDeckView.from(
        state: stateWith(
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
              storedAmount: 10,
            ),
            MiningSiteId.carbonRidge: progress(
              unlocked: true,
              commissioned: true,
              storedAmount: 5,
            ),
          },
        ),
        content: content,
        isBusy: false,
      );

      expect(view.totalCargo, 15);
      // 10 Gold at 4 cash/unit + 5 Coal at 3 cash/unit.
      expect(view.projectedValue, 55);
      expect(view.sale.canSell, isTrue);
      expect(view.sale.hasUnsellableCargo, isFalse);
      expect(view.sale.label, 'Sell all cargo for 55 cash.');
    });

    test('projects a tiny-sale aggregate that floors to zero cash', () {
      // 0.1 Gold (0.4 gross) + 0.1 Coal (0.3 gross) floor to 0 together.
      final view = SiteDeckView.from(
        state: stateWith(
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
              storedAmount: 0.1,
            ),
            MiningSiteId.carbonRidge: progress(
              unlocked: true,
              commissioned: true,
              storedAmount: 0.1,
            ),
          },
        ),
        content: content,
        isBusy: false,
      );

      expect(view.projectedValue, 0);
      expect(view.sale.canSell, isFalse);
      expect(view.sale.hasUnsellableCargo, isTrue);
      expect(
        view.sale.label,
        'Keep mining until cargo is worth at least 1 cash.',
      );
    });

    test('disables the sale while the shell is busy', () {
      final view = SiteDeckView.from(
        state: stateWith(
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
              storedAmount: 10,
            ),
          },
        ),
        content: content,
        isBusy: true,
      );

      expect(view.sale.canSell, isFalse);
      expect(view.sale.hasUnsellableCargo, isFalse);
      expect(view.sale.label, 'Finishing previous action…');
    });
  });
}
