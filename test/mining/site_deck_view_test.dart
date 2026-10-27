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
    expect(view.totalCapacity, 4320);
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
              storedAmount: 3600,
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
      expect(card.capacity, 3600);
      expect(card.cargo, 3600);
      expect(card.isCargoFull, isTrue);
    });

    test('keeps an otherwise-identical under-capacity site not full', () {
      final view = SiteDeckView.from(
        state: stateWith(
          sites: {
            MiningSiteId.landingBasin: progress(
              unlocked: true,
              commissioned: true,
              storedAmount: 3599,
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

  group('timeToFull', () {
    MiningSiteCardView landingBasin(SiteProgress site) => SiteDeckView.from(
      state: stateWith(sites: {MiningSiteId.landingBasin: site}),
      content: content,
      isBusy: false,
    ).cards[MiningSiteId.landingBasin]!;

    const rig = [
      MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
    ];

    test('is exact for a partially filled operational card', () {
      final card = landingBasin(
        progress(
          unlocked: true,
          commissioned: true,
          storedAmount: 45,
          rigs: rig,
        ),
      );
      expect(card.state, MiningSiteCardState.operational);
      expect(card.rate, greaterThan(0));
      expect(
        card.timeToFull,
        Duration(
          microseconds: ((card.capacity - 45) / card.rate * 1000000).ceil(),
        ),
      );
    });

    test('is null for full, idle, available, and locked cards', () {
      expect(
        landingBasin(
          progress(
            unlocked: true,
            commissioned: true,
            storedAmount: 3600,
            rigs: rig,
          ),
        ).timeToFull,
        isNull,
      );
      expect(
        landingBasin(progress(unlocked: true, commissioned: true)).timeToFull,
        isNull,
      );
      final view = SiteDeckView.from(
        state: stateWith(),
        content: content,
        isBusy: false,
      );
      for (final card in view.cards.values.where(
        (card) => !card.isOperational,
      )) {
        expect(card.timeToFull, isNull, reason: card.name);
      }
      expect(
        view.cards.values.map((card) => card.state),
        containsAll([
          MiningSiteCardState.available,
          MiningSiteCardState.locked,
        ]),
      );
    });

    test('is null for an operational card with no rate', () {
      final producing = landingBasin(
        progress(
          unlocked: true,
          commissioned: true,
          storedAmount: 45,
          rigs: rig,
        ),
      );
      final card = MiningSiteCardView(
        id: producing.id,
        definition: producing.definition,
        state: producing.state,
        isUnlocked: producing.isUnlocked,
        isCommissioned: producing.isCommissioned,
        deployedRigs: producing.deployedRigs,
        cargo: producing.cargo,
        capacity: producing.capacity,
        rate: 0,
        projectedValue: producing.projectedValue,
        canEnter: producing.canEnter,
        canUnlock: producing.canUnlock,
        unlockCost: producing.unlockCost,
        unlockDisabledReason: producing.unlockDisabledReason,
        isBusy: producing.isBusy,
      );
      expect(card.isOperational, isTrue);
      expect(card.timeToFull, isNull);
    });

    test('is null for a commissioned site with no rig', () {
      expect(
        landingBasin(progress(unlocked: true, commissioned: true)).timeToFull,
        isNull,
      );
    });
  });

  group('nextStorageFull', () {
    final anchor = DateTime.utc(2026, 8, 26, 12);

    const t1 = [
      MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
    ];

    MiningSave save({
      Set<MiningPlanetId> unlockedPlanets = const {MiningPlanetId.homeworld},
      Map<MiningSiteId, SiteProgress> sites = const {},
    }) => stateWith(
      sites: sites,
    ).copyWith(lastAccruedAtUtc: anchor, unlockedPlanetIds: unlockedPlanets);

    SiteProgress producing(double storedAmount) => progress(
      unlocked: true,
      commissioned: true,
      storedAmount: storedAmount,
      rigs: t1,
    );

    test('returns null when no site is producing toward non-full storage', () {
      // Fresh state: landingBasin is available, every other site locked.
      expect(nextStorageFull(content, save()), isNull);
      expect(
        nextStorageFull(
          content,
          save(sites: {MiningSiteId.landingBasin: producing(3600)}),
        ),
        isNull,
      );
    });

    test('projects a single producing site to its anchored fill instant', () {
      final result = nextStorageFull(
        content,
        save(sites: {MiningSiteId.landingBasin: producing(45)}),
      );

      expect(result!.site, MiningSiteId.landingBasin);
      // (3600 - 45) / 0.5 = 7110 s after the anchor.
      expect(result.atUtc, anchor.add(const Duration(seconds: 7110)));
    });

    test('picks the earliest fill across two unlocked planets', () {
      final result = nextStorageFull(
        content,
        save(
          unlockedPlanets: const {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          sites: {
            MiningSiteId.landingBasin: producing(45), // fills in 7110 s
            MiningSiteId.frozenBasin: producing(7150), // fills in 50 s
          },
        ),
      );

      expect(result!.site, MiningSiteId.frozenBasin);
      expect(result.atUtc, anchor.add(const Duration(seconds: 50)));
    });

    test(
      'skips locked planets and locked, available, idle, and full sites',
      () {
        // frozenBasin would fill first, but its planet is locked.
        expect(
          nextStorageFull(
            content,
            save(
              sites: {
                MiningSiteId.landingBasin: producing(45),
                MiningSiteId.frozenBasin: producing(7150),
              },
            ),
          )!.site,
          MiningSiteId.landingBasin,
        );

        // None of these carbonRidge shapes projects a fill instant: the
        // first three never produce (locked, uncommissioned, no rigs) and
        // the last is already at capacity, so landingBasin's 7110 s is the
        // only projection and wins every time.
        final excludedCarbonRidge = [
          progress(
            unlocked: false,
            commissioned: true,
            storedAmount: 3000,
            rigs: t1,
          ), // locked site
          progress(
            unlocked: true,
            commissioned: false,
            storedAmount: 3000,
            rigs: t1,
          ), // not commissioned
          progress(
            unlocked: true,
            commissioned: true,
            storedAmount: 3000,
          ), // idle: no rigs
          progress(
            unlocked: true,
            commissioned: true,
            storedAmount: 5400,
            rigs: t1,
          ), // already full
        ];
        for (final carbonRidge in excludedCarbonRidge) {
          final result = nextStorageFull(
            content,
            save(
              sites: {
                MiningSiteId.landingBasin: producing(45),
                MiningSiteId.carbonRidge: carbonRidge,
              },
            ),
          );
          expect(result!.site, MiningSiteId.landingBasin);
        }
      },
    );

    test('keeps the authored-first site on a fill-time tie', () {
      final result = nextStorageFull(
        content,
        save(
          sites: {
            MiningSiteId.landingBasin: producing(600), // 3000 / 0.5 = 6000 s
            MiningSiteId.carbonRidge: producing(900), // 4500 / 0.75 = 6000 s
          },
        ),
      );

      expect(result!.site, MiningSiteId.landingBasin);
      expect(result.atUtc, anchor.add(const Duration(seconds: 6000)));
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
