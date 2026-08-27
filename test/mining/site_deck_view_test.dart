import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/site_deck_view.dart';

SiteProgress progress({
  bool unlocked = false,
  bool commissioned = false,
  double storedAmount = 0,
  Map<MiningNodeId, RigTier?>? rigs,
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigByNode: rigs ?? {for (final node in MiningNodeId.values) node: null},
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
            rigs: {MiningNodeId.n1: RigTier.t1},
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
}
