# HPA-286 — Site Deck Cargo-full State and Selling Design

- Date: 2026-09-19
- Status: Proposed
- Linear: HPA-286 — [Mining Polish] Clarify cargo-full state and selling
- Baseline: `main` at `3c5f63b72e37734b59f0a312c7088a81e9ceb502` after HPA-455 / PR #32

## Problem

The Site Deck already projects active-planet cargo, capacity, rate, and projected sale value, but a site that has filled its storage still looks like an ordinary operational site. The player must enter a Mine Site to discover the stall and to sell cargo.

HPA-286 should make that stalled state obvious on the Site Deck and expose the existing active-planet sale there without creating another economy path, another lifecycle state, or another management surface.

## Goals

- Make a commissioned, rigged site whose cargo has reached capacity visibly read as full/stalled.
- Keep full guidance local to the affected site's existing cargo/status presentation.
- Add one active-planet Sell action to the Site Deck in portrait and landscape.
- Route that action through the existing `MiningShell._sellCargo()` -> `MiningController.sellAllCargo()` path.
- Give Site Deck and Mine Site one owner for sale eligibility, tiny-sale state, and semantic copy.
- Keep the existing aggregate sale math, busy handling, result snackbar, audio, haptics, and persistence ordering.
- Preserve the Site Deck's post-HPA-452 ownership: status/progression/economy only, with no fleet controls.
- Reuse current cargo icon/theme primitives; no new image or audio asset.

## Non-goals

This PR does not:

- add auto-sell, per-site selling, global/multi-planet selling, or a second sale mutation;
- change prices, production rates, capacities, technology multipliers, offline caps, or sale rounding;
- add a save field, schema version, migration, tutorial state, alert/inbox system, or contextual-hint framework;
- reintroduce Fleet Dock, spawn, select, merge, deploy, or recall controls on Site Deck;
- change `MiningController`, `MiningSimulation`, `MiningSaveRepository`, or `MiningSave`;
- add a fifth `MiningSiteCardState` value;
- extract/share Mine Site's `_SellControl` chrome;
- turn `MiningCargoGauge.onPressed` into the Sell action;
- add image-generation or SFX work.

## Current ownership to preserve

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> SiteDeckView -> SiteDeckScreen
                         -> MineSiteView -> MineSiteScreen
```

- `MiningController.sellAllCargo()` remains the only sale mutation and sells only the active planet.
- `MiningShell._sellCargo()` remains the one presentation orchestration path for sale busy-state refresh, success/failure feedback, audio, and haptics.
- `SiteDeckView` and `MineSiteView` remain pure read models.
- Widgets never derive sale legality independently.

## Design decisions

### 1. Cargo-full is an overlay on operational state, not a fifth lifecycle state

`MiningSiteCardState` remains exactly:

- `locked`
- `available`
- `idle`
- `operational`

Add a derived getter to `MiningSiteCardView`:

```dart
bool get isCargoFull =>
    isOperational && capacity > 0 && cargo >= capacity;
```

A full site remains lifecycle-`operational`: it is commissioned and has rigs. Storage headroom is a snapshot condition, not another lifecycle value.

Use the simulation invariant as-is. Cargo already clamps at effective capacity, so `cargo >= capacity` is the presentation boundary; do not add epsilon math, hysteresis, or persisted full flags.

### 2. One `MiningSaleAffordance` owns sale eligibility and copy

Do not add separate `SiteDeckView.canSell` / `hasUnsellableCargo` predicate implementations and do not centralize only the strings.

Add one tiny immutable value type in `site_deck_view.dart`:

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

This type derives from the three real presentation inputs and cannot represent contradictory `canSell: true` / `hasUnsellableCargo: true` states.

It does not calculate prices or gross sale value. Both views continue passing their existing aggregate, already-floored projected value.

#### Site Deck

`SiteDeckView` exposes:

```dart
MiningSaleAffordance get sale => MiningSaleAffordance.from(
  isBusy: isBusy,
  cargo: totalCargo,
  projectedValue: projectedValue,
);
```

No separate Site Deck sale booleans are needed.

#### Mine Site

`MineSiteView` stops storing `canSell` in its constructor/factory.

It exposes:

```dart
MiningSaleAffordance get sale => MiningSaleAffordance.from(
  isBusy: isBusy,
  cargo: isActivePlanet ? activePlanetCargo : 0,
  projectedValue: isActivePlanet ? activePlanetProjectedSale : 0,
);

bool get canSell => sale.canSell;
bool get hasUnsellableCargo => sale.hasUnsellableCargo;
```

Zeroing the inputs for a non-active site preserves today's behavior exactly: no sale and `No cargo to sell.`.

The existing `MineSiteView.canSell` / `hasUnsellableCargo` API remains as derived aliases, so current tests and widget call sites do not need churn.

### 3. One site-card label helper owns `FULL`

The current Site Deck has separate state-label helpers in the portrait/landscape card implementations. Replace them with one helper taking the whole card:

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

- portrait card semantics;
- landscape card semantics;
- landscape state chip label.

The chip/border still receive `card.state`, not the label, so a full operational card retains operational accent color.

### 4. Full guidance stays in the affected card without deleting existing information

Do not add a banner, tutorial prompt, toast loop, badge registry, or global alert state.

Do not replace portrait top-right node dots. Those dots communicate deployed-rig occupancy and remain visible while full.

#### Portrait prototype cards

A full card:

- keeps current dimensions, art, rig badges, and occupancy dots;
- may use warning border/shadow treatment because portrait available cards do not use warning as their primary operational chrome;
- keeps the cargo progress bar at 100%;
- changes the trailing cargo-row copy to `FULL · SELL TO RESUME`;
- uses `_siteCardLabel(card)` in semantics.

No second FULL badge is introduced.

#### Landscape cards

A full card keeps operational accent border/chip color.

Its text becomes:

```text
FULL · <rate>/s · <cargo> / <capacity>
SELL TO RESUME
```

This preserves the existing production rate and cargo/capacity readout while adding the stall/recovery instruction.

The state chip uses `FULL`, but its color still comes from `MiningSiteCardState.operational`.

Under-capacity operational cards retain current visuals/copy. Idle/available/locked cards are unchanged.

### 5. One planet-wide Sell action appears in Site Deck chrome

The sale mutation is active-planet-wide, so the Site Deck gets one Sell action rather than a button on every card.

Add a required `VoidCallback onSellCargo` to `SiteDeckScreen` and one private `_SiteDeckSellAction`.

The action:

- has stable key `site-deck-sell`;
- reuses `MiningVisuals.cargoIcon` and existing theme colors;
- displays `SELL` plus the active planet's projected cash value;
- is enabled only when `view.sale.canSell`;
- uses `view.sale.label` for semantics;
- remains separate from `MiningCargoGauge`;
- has a minimum 48×48 interactive target;
- contains no mutation logic.

Do not wire `MiningCargoGauge.onPressed`. The gauge remains a readout.

The Sell action keeps the projected value visibly. `MiningCargoGauge` receives `projectedValue` for semantics but its visible center renders cargo amount (and optional rate), not projected cash, so removing the Sell value would lose visible sale-value feedback.

#### Portrait placement — bounded structural row

Do not pin a standalone Sell rect against an unbounded planet label.

Replace the separate `_PlanetProgress` positioning with one bounded row that reserves the gauge column:

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
        child: _SiteDeckSellAction(...),
      ),
    ],
  ),
)
```

Why `right: 104`, not `right: 12`:

- the 80px gauge starts 12px from the right edge;
- reserving 104px leaves a structural 12px gap before the gauge;
- the Sell control therefore cannot sit underneath the gauge.

At 402px wide, the Sell control still lands at x = 218..298, matching the previous authored target, but the planet-progress region is now bounded instead of painting underneath it.

Update `_PlanetProgress` so its text column is flexible and the planet name uses `maxLines: 1` + ellipsis. This makes long names such as `LUNAR FRONTIER` safe at 360px and text scale 1.3.

Keep:

- cargo gauge at its existing position;
- `site-deck-scroll top: 164 + pad.top`;
- the existing 196px header;
- the 8px gap between the 48px band ending at y=156 and the list beginning at y=164.

#### Landscape placement

Keep the existing top HUD row. Wrap the HUD and Sell action in one row:

- HUD remains `Expanded`;
- Sell action sits beside it;
- no second toolbar/footer;
- no `MiningHud` API change;
- bottom navigation geometry stays unchanged.

### 6. Reuse the existing shell sale orchestration unchanged

`MiningShell._sellCargo()` already:

1. rejects while uninitialized/busy;
2. starts `MiningController.sellAllCargo()`;
3. immediately refreshes presentation so busy state disables controls;
4. refreshes again after persistence;
5. preserves dock selection validity;
6. plays existing success/reject sound and success haptic;
7. shows `Sold N cash.` or the existing failure message.

Site Deck calls this same method:

```text
SiteDeckScreen.onSellCargo -> MiningShell._sellCargo
```

Mine Site continues using the same callback. No new sale runner, result type, or controller method is needed.

### 7. Full-state detection remains presentation-only

Do not modify production accrual behavior when a site becomes full.

The existing simulation remains authoritative:

- accrued cargo clamps at capacity;
- production resumes naturally after sale creates headroom;
- foreground refresh updates Site Deck once per second;
- the existing cargo-full SFX crossing detector remains unchanged.

HPA-286 adds readability and access, not a new stall mechanic.

## File-level changes

### `lib/mining/site_deck_view.dart`

- add `MiningSiteCardView.isCargoFull`;
- add `MiningSaleAffordance`;
- add `SiteDeckView.sale`;
- keep `MiningSiteCardState` exactly four values;
- change no save/state schema.

### `lib/mining/mine_site_view.dart`

- remove stored/constructor `canSell`;
- add derived `sale`;
- keep `canSell` and `hasUnsellableCargo` as aliases of `sale`;
- keep aggregate cargo/value calculation unchanged.

### `lib/mining/presentation/site_deck_screen.dart`

- add required `onSellCargo`;
- add private Site Deck Sell control;
- replace duplicate state-label helpers with `_siteCardLabel(card)`;
- use the bounded portrait progress+Sell row with `right: 104`;
- make planet-name text bounded/ellipsized;
- keep portrait occupancy dots;
- preserve landscape numbers when full;
- keep landscape full cards on operational accent chrome;
- keep Fleet Dock absent.

### `lib/mining/presentation/mine_site_screen.dart`

- delete private `_saleLabel`;
- read `view.sale.label` directly;
- change no Mine Site control, geometry, key, value text, or callback.

### `lib/mining/presentation/mining_shell.dart`

- pass `_sellCargo` to `SiteDeckScreen`;
- do not change `_sellCargo()`.

No production changes are expected in controller, simulation, persistence, state, content, Stellar Map, fleet, grid, HUD, assets, or platform files.

## Verification strategy

### Sale/full projection

Extend `test/mining/site_deck_view_test.dart`:

- exactly-full operational site -> `isCargoFull == true`;
- under-capacity operational -> false;
- idle zero-capacity -> false;
- `MiningSaleAffordance.from(...)` pins busy, sellable, tiny-sale, and empty states including exact labels;
- `SiteDeckView.sale` maps aggregate cargo/value/busy correctly.

Keep existing `test/mining/mine_site_view_test.dart` sale tests green unchanged:

- active-planet aggregate sale remains sellable;
- tiny cargo remains unsellable;
- busy remains unsellable.

Those tests now exercise the shared affordance through the existing aliases.

### Site Deck presentation/layout

Extend `test/mining/presentation/site_deck_screen_test.dart`:

- full portrait card shows `FULL · SELL TO RESUME` and full semantics;
- portrait occupancy dots remain;
- landscape chip uses `FULL` with operational accent;
- landscape full status preserves rate + cargo/capacity and adds `SELL TO RESUME`;
- `site-deck-sell` appears in portrait and landscape and emits one callback;
- empty/busy/tiny-sale controls disable with `view.sale.label`;
- Sell is at least 48×48 in both orientations.

For portrait no-overlap, use the existing 1.3 text-scale matrix and include a long non-Homeworld name:

- 360×640;
- 430×932;
- 402×874 authored layout;
- `LUNAR FRONTIER` (or another non-Homeworld name).

At each relevant portrait size assert the Sell rect does not overlap:

- cargo gauge;
- bounded planet-progress region;
- first site card;
- bottom navigation.

At 402×874, it is still acceptable to pin the Sell rect to `Rect.fromLTWH(218, 108, 80, 48)` as an authored-composition check, but structural bounds are the primary safety guarantee.

### Shell integration

Extend `test/mining/presentation/mining_shell_test.dart`:

- seed saleable cargo directly with `deployedLandingState(_start, cargo: 10)`;
- from Site Deck, Sell clears active-planet cargo, increases cash, stays on Site Deck, and emits the existing success feedback.

For the delayed-save double-tap test, name public observables:

- cash increases by exactly one expected sale revenue;
- exactly one `Sold N cash.` success snackbar is present/emitted;
- no `No cargo to sell.` snackbar appears;
- no `Sale failed.` snackbar appears;
- sale success sound is emitted once.

These assertions catch a second queued sale without inspecting private shell/controller queue state.

Do not add controller tests unless implementation exposes a real controller regression.

## Acceptance mapping

- **Full/stalled site identifiable**: `isCargoFull` + shared `_siteCardLabel(card)` + local full copy.
- **Selling resumes headroom is explicit**: portrait cargo row and landscape second-line `SELL TO RESUME`.
- **No status information lost**: portrait occupancy dots stay; landscape retains rate and cargo/capacity.
- **One sale decision owner**: `MiningSaleAffordance` owns eligibility, tiny-sale state, and semantic copy for both views.
- **Active-planet sale from Site Deck**: `site-deck-sell` -> existing `_sellCargo()` -> `sellAllCargo()`.
- **Portrait fit is structural**: bounded progress+Sell row reserves the gauge column and ellipsizes long planet names.
- **No state-color ambiguity**: landscape full cards stay operational-accent.
- **No Fleet controls return**: Site Deck gains only the Sell callback/action.
- **No save/economy/tutorial subsystem**: read-model/presentation/shell wiring only.
- **Balance unchanged**: no controller/content/simulation edits.

## Assets

No image generation or SFX work is required. Reuse the current cargo icon, card art, theme colors, cargo-full sound, and sale sound.
