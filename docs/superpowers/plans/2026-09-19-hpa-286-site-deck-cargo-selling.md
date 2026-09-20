# HPA-286 — Site Deck Cargo-full State and Selling Implementation Plan

- Date: 2026-09-19
- Linear: HPA-286
- Design: `docs/superpowers/specs/2026-09-19-hpa-286-site-deck-cargo-selling-design.md`

## Delivery rule

One ticket = one PR.

Keep planning and implementation on this draft PR. Do not open a second implementation PR for HPA-286.

No image-generation or SFX task is included.

## Task 1 — Add full-state projection and one shared sale affordance

This task is read-model-only. It must finish green before presentation wiring changes.

### Tests first

Extend `test/mining/site_deck_view_test.dart`.

Cover cargo-full projection:

1. commissioned + rigged + exactly at effective capacity -> lifecycle remains `operational`, `isCargoFull == true`;
2. otherwise-identical under-capacity site -> `isCargoFull == false`;
3. commissioned idle site with zero capacity -> `isCargoFull == false`.

Cover `MiningSaleAffordance.from(...)` directly:

- busy + positive projected value -> disabled, not tiny-sale, `Finishing previous action…`;
- non-busy projected value > 0 -> enabled, correct `Sell all cargo for N cash.`;
- non-busy cargo > 0 / projected value == 0 -> disabled + tiny-sale label;
- zero cargo / zero value -> disabled + `No cargo to sell.`.

Cover `SiteDeckView.sale` from aggregate projection:

- normal sellable active-planet cargo;
- tiny-sale aggregate;
- busy state.

Keep existing `test/mining/mine_site_view_test.dart` sale tests unchanged. They are the regression contract for Mine Site's public `canSell` / `hasUnsellableCargo` behavior.

### Production change — `site_deck_view.dart`

Add:

```dart
bool get isCargoFull =>
    isOperational && capacity > 0 && cargo >= capacity;
```

to `MiningSiteCardView`.

Add one value type:

```dart
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
    final hasUnsellableCargo =
        !isBusy && cargo > 0 && projectedValue == 0;
    final label = isBusy
        ? 'Finishing previous action…'
        : canSell
        ? 'Sell all cargo for $projectedValue cash.'
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
```

Add:

```dart
MiningSaleAffordance get sale => MiningSaleAffordance.from(
  isBusy: isBusy,
  cargo: totalCargo,
  projectedValue: projectedValue,
);
```

to `SiteDeckView`.

Do not add separate Site Deck `canSell` / `hasUnsellableCargo` implementations.

### Production change — `mine_site_view.dart`

Remove stored constructor field/argument:

```dart
required this.canSell
```

and remove the `canSell:` calculation from `MineSiteView.from(...)`.

Add:

```dart
MiningSaleAffordance get sale => MiningSaleAffordance.from(
  isBusy: isBusy,
  cargo: isActivePlanet ? activePlanetCargo : 0,
  projectedValue: isActivePlanet ? activePlanetProjectedSale : 0,
);

bool get canSell => sale.canSell;
bool get hasUnsellableCargo => sale.hasUnsellableCargo;
```

Delete the existing standalone `hasUnsellableCargo` predicate.

Keep:

- active-planet cargo aggregation;
- aggregate gross flooring;
- `activePlanetCargo`;
- `activePlanetProjectedSale`;
- all current public caller/test behavior.

Do not touch controller/simulation/save code.

### Focused gate

```sh
dart format --output=none --set-exit-if-changed \
  lib/mining/site_deck_view.dart \
  lib/mining/mine_site_view.dart \
  test/mining/site_deck_view_test.dart
flutter test test/mining/site_deck_view_test.dart
flutter test test/mining/mine_site_view_test.dart
```

## Task 2 — Add shared FULL labeling and an overlap-safe Site Deck Sell layout

This is the highest-risk task because portrait header fit must hold at 360px / text scale 1.3 / long planet names.

`SiteDeckScreen`, Mine Site sale-label usage, and the `MiningShell` Site Deck constructor change atomically.

### Tests first — Site Deck full-state labels

Update `test/mining/presentation/site_deck_screen_test.dart` helpers so they can:

- set `storedAmount`;
- create busy/non-busy Site Deck projections;
- inject `onSellCargo`;
- exercise a non-Homeworld planet name such as `LUNAR FRONTIER`.

Add assertions:

- portrait full card semantics use `FULL`;
- portrait cargo/progress row shows `FULL · SELL TO RESUME`;
- portrait rig-occupancy dots still exist while full;
- under-capacity operational card remains `OPERATIONAL`;
- landscape full chip reads `FULL`;
- landscape full chip/border still use operational accent;
- landscape full status preserves numbers and adds recovery copy:
  - `FULL · <rate>/s · <cargo> / <capacity>`;
  - `SELL TO RESUME`.

### Tests first — Sell action behavior

Pin:

- `site-deck-sell` exists in portrait and landscape;
- enabled action emits exactly one callback;
- busy/tiny-sale/empty states disable it;
- semantic label comes from `view.sale.label`;
- target is at least 48×48 in both orientations.

The control continues to show projected sale value because the existing cargo gauge does not visibly render projected cash.

### Tests first — structural portrait fit

Replace the previous "one safe rect proves fit" assumption with structural checks.

At 1.3 text scale, cover at least:

- 360×640 with a long planet name;
- 402×874 authored composition;
- 430×932 with a long planet name.

For each portrait case assert:

- no exception/overflow;
- `site-deck-scroll` still starts at y = `164 + safeAreaTop`;
- Sell target >= 48×48;
- Sell does not overlap cargo gauge;
- Sell does not overlap the bounded planet-progress region;
- Sell does not overlap first card;
- Sell remains above bottom navigation.

At 402×874 with zero top inset, the structurally-derived Sell rect may still be pinned to `Rect.fromLTWH(218, 108, 80, 48)` as a composition check.

### Production change — one card-label helper

Edit `lib/mining/presentation/site_deck_screen.dart`.

Replace the portrait global `_siteStateLabel(state)` and landscape private `_SiteCard._stateLabel(state)` with one file-level helper:

```dart
String _siteCardLabel(MiningSiteCardView card) =>
    card.isCargoFull
        ? 'FULL'
        : switch (card.state) {
            MiningSiteCardState.locked => 'LOCKED',
            MiningSiteCardState.available => 'AVAILABLE',
            MiningSiteCardState.idle => 'IDLE',
            MiningSiteCardState.operational => 'OPERATIONAL',
          };
```

Use it for:

- portrait semantics;
- landscape semantics;
- landscape state chip label.

Keep state/color selection based on `card.state`.

### Production change — portrait full copy

Keep the current top-right rig occupancy dots.

In `_SiteProgress`:

- progress bar remains;
- when `card.isCargoFull`, trailing text becomes `FULL · SELL TO RESUME`;
- otherwise keep the existing percentage.

Portrait warning border/shadow for full is allowed; do not add another FULL badge.

### Production change — landscape full copy

For an operational full card, status becomes two-line copy equivalent to:

```text
FULL · 0.55/s · 120 / 120
SELL TO RESUME
```

using the real card rate/cargo/capacity formatting.

Do not replace the numbers with only `FULL — SELL TO RESUME`.

Keep `_StateChip(state: card.state)` and `_borderColor(card.state)`, so full operational remains accent-colored rather than warning-colored.

### Production change — bounded portrait header row

Remove the standalone portrait `Positioned(... _PlanetProgress ...)`.

Add one bounded row:

```dart
Positioned(
  left: 16,
  right: 104,
  top: 108 + pad.top,
  height: 48,
  child: Row(
    children: [
      Expanded(child: _PlanetProgress(view: view)),
      const SizedBox(width: 8),
      SizedBox(
        width: 80,
        height: 48,
        child: _SiteDeckSellAction(
          view: view,
          onSellCargo: onSellCargo,
        ),
      ),
    ],
  ),
)
```

Do **not** use `right: 12`; that would put the Sell control in the gauge's rightmost 80px column and overlap the gauge from y=108..130.

Update `_PlanetProgress`:

- make its text/progress column flexible;
- planet name gets `maxLines: 1` and `TextOverflow.ellipsis`;
- preserve the 34px planet image and commissioned-site progress bars.

Keep:

- gauge `top: 50, right: 12, size: 80`;
- list `top: 164`;
- header height 196;
- 8px gap from the row bottom (156) to list top (164).

### Production change — Site Deck Sell action

Add required `onSellCargo` to `SiteDeckScreen` and pass through portrait/landscape.

Add one private `_SiteDeckSellAction`:

- stable key `site-deck-sell`;
- current cargo icon;
- `SELL` + `view.projectedValue`;
- `onPressed: view.sale.canSell ? onSellCargo : null`;
- semantic label `view.sale.label`;
- minimum 48×48;
- no mutation logic.

Do not use `MiningCargoGauge.onPressed`.

Landscape:

- wrap existing `MiningHud` in a Row;
- `Expanded(child: MiningHud(...))`;
- Sell action beside it;
- no `MiningHud` API changes.

### Production change — Mine Site copy reuse

Edit `lib/mining/presentation/mine_site_screen.dart`:

- delete private `_saleLabel`;
- semantic label uses `view.sale.label`;
- keep `view.canSell` for enabled state if that avoids unrelated caller churn;
- no `_SellControl`, gauge, geometry, key, projected-value, or callback changes.

### Production change — shell wiring

Edit `lib/mining/presentation/mining_shell.dart`:

```dart
SiteDeckScreen(
  ...
  onSellCargo: _sellCargo,
)
```

Do not change `_sellCargo()`.

### Focused gate

```sh
dart format --output=none --set-exit-if-changed \
  lib/mining/site_deck_view.dart \
  lib/mining/mine_site_view.dart \
  lib/mining/presentation/site_deck_screen.dart \
  lib/mining/presentation/mine_site_screen.dart \
  lib/mining/presentation/mining_shell.dart \
  test/mining/site_deck_view_test.dart \
  test/mining/presentation/site_deck_screen_test.dart
flutter test test/mining/site_deck_view_test.dart
flutter test test/mining/mine_site_view_test.dart
flutter test test/mining/presentation/site_deck_screen_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
flutter analyze --fatal-infos
```

## Task 3 — Prove Site Deck sale and queued-double-tap prevention through observables

Do not add controller behavior. This task proves the new entry point reuses the existing shell/controller path.

### Site Deck sale success

Seed:

```dart
await repository.save(deployedLandingState(_start, cargo: 10));
```

Do not wait for the one-second foreground timer.

Then:

1. pump shell and stay on Site Deck;
2. tap `site-deck-sell`;
3. wait for persistence;
4. assert cargo is zero;
5. assert cash increased by exactly the expected one-sale revenue;
6. assert Site Deck remains active;
7. assert `Sold N cash.` is shown;
8. assert sale success sound is emitted once.

### Busy double-tap guard

Use the existing delayed repository fixture with the same seeded cargo.

1. tap Site Deck Sell;
2. pump the immediate busy refresh;
3. assert `site-deck-sell` is disabled;
4. attempt a second tap;
5. release persistence;
6. settle.

Assert public observables:

- cash increased by exactly one expected sale;
- exactly one success result `Sold N cash.`;
- no `No cargo to sell.`;
- no `Sale failed.`;
- sale success sound appears once.

This catches a second queued `sellAllCargo()` because a slipped-through second operation would run after the first and produce the existing no-cargo failure path.

Do not inspect shell private fields or controller queue internals.

Keep existing Mine Site sale tests unchanged.

### Focused gate

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

## Task 4 — Final scope audit and repository gates

Search:

```sh
rg "MiningSaleAffordance|site-deck-sell|isCargoFull|_siteCardLabel|onSellCargo|hasUnsellableCargo|canSell" \
  lib/mining \
  test/mining
```

Expected ownership:

- `MiningSaleAffordance`, `MiningSiteCardView.isCargoFull`, `SiteDeckView.sale`: `site_deck_view.dart`;
- `MineSiteView.sale` + derived compatibility getters: `mine_site_view.dart`;
- full labels/layout/Sell chrome: `site_deck_screen.dart`;
- Mine Site reads `view.sale.label`: `mine_site_screen.dart`;
- Site Deck callback wiring only: `mining_shell.dart`;
- `MiningController.sellAllCargo()` unchanged.

Confirm there is no:

- `MiningSiteCardState.full`;
- separate Site Deck sale predicate logic;
- four-boolean/string sale-label helper;
- new controller sale API/result/queue;
- save/schema field;
- auto-sell or per-card sale mutation;
- `MiningCargoGauge.onPressed` sale wiring;
- extracted shared Sell widget;
- Fleet Dock on Site Deck;
- portrait occupancy-dot removal;
- landscape warning chrome for a full operational card;
- portrait Sell target smaller than 48×48;
- unbounded planet-name text adjacent to Sell;
- new image/audio asset.

Run:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
git diff --check
```

Run platform builds only if the normal repository workflow requires them; no platform code is planned.

## Expected files

Production:

- `lib/mining/site_deck_view.dart`
- `lib/mining/mine_site_view.dart`
- `lib/mining/presentation/site_deck_screen.dart`
- `lib/mining/presentation/mine_site_screen.dart`
- `lib/mining/presentation/mining_shell.dart`

Tests:

- `test/mining/site_deck_view_test.dart`
- `test/mining/presentation/site_deck_screen_test.dart`
- `test/mining/presentation/mining_shell_test.dart`

Existing `test/mining/mine_site_view_test.dart` and `test/mining/presentation/mine_site_screen_test.dart` should remain green without edits unless implementation exposes a concrete missing assertion.

Planning:

- `docs/superpowers/specs/2026-09-19-hpa-286-site-deck-cargo-selling-design.md`
- `docs/superpowers/plans/2026-09-19-hpa-286-site-deck-cargo-selling.md`

No controller, simulation, persistence, state-schema, content, Stellar Map, HUD, asset, or platform file is expected.

## Completion criteria

- Full sites are unmistakable from Site Deck.
- `MiningSiteCardState` remains four lifecycle values.
- Portrait retains occupancy dots and shows `FULL · SELL TO RESUME`.
- Landscape full status retains rate + cargo/capacity and adds `SELL TO RESUME`.
- Landscape full cards retain operational accent chrome.
- One `MiningSaleAffordance` owns sale enablement, tiny-sale state, and semantic copy for Site Deck and Mine Site.
- Site Deck has one active-planet Sell action in portrait and landscape.
- Portrait Sell is an honest >=48px target inside a bounded progress+Sell band that reserves the gauge column.
- Long planet names ellipsize instead of painting underneath Sell.
- Site Deck sale reuses `_sellCargo()` / `sellAllCargo()`.
- Busy state prevents a second queued sale, proved by cash/result/sound observables.
- Existing Mine Site selling remains behaviorally unchanged.
- Fleet controls stay absent from Site Deck.
- No save/economy/controller/tutorial/asset/SFX subsystem is added.

## Scope guardrail

Stop and re-evaluate if implementation starts requiring:

- a second sale predicate/copy owner;
- a portrait Sell target smaller than 48×48;
- overlapping gauge/progress/Sell geometry;
- an undeclared `site-deck-scroll` top shift;
- `MiningSiteCardState.full`;
- controller/simulation/persistence changes;
- a second sale orchestration path;
- shared/extracted Sell-control chrome;
- per-site/global/auto selling;
- another state-management/tutorial/alert subsystem;
- Fleet Dock work;
- image generation or new SFX.
