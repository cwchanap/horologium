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
- Keep the guidance local to the affected site's existing cargo/status presentation: `FULL` and `SELL TO RESUME`.
- Add one active-planet Sell action to the Site Deck in portrait and landscape.
- Route that action through the existing `MiningShell._sellCargo()` -> `MiningController.sellAllCargo()` path.
- Reuse one sale semantic-label helper across Site Deck and Mine Site so busy/sellable/tiny-sale/empty copy cannot drift.
- Keep the existing active-planet aggregate sale semantics, busy handling, result snackbar, audio, haptics, and persistence ordering.
- Preserve the Site Deck's post-HPA-452 ownership: status/progression/economy only, with no fleet controls.
- Reuse current cargo icon/theme primitives; no new image or audio asset.

## Non-goals

This PR does not:

- add auto-sell, per-site selling, global/multi-planet selling, or a second sale mutation;
- change prices, production rates, capacities, technology multipliers, offline caps, or sale rounding;
- add a new save field, schema version, migration, tutorial state, alert/inbox system, or contextual-hint framework;
- reintroduce Fleet Dock, spawn, select, merge, deploy, or recall controls on Site Deck;
- change `MiningController`, `MiningSimulation`, `MiningSaveRepository`, or `MiningSave`;
- add a fifth `MiningSiteCardState` value;
- extract/share Mine Site's `_SellControl` chrome;
- turn `MiningCargoGauge.onPressed` into the Sell action;
- add new image-generation or SFX work.

## Current ownership to preserve

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> SiteDeckView -> SiteDeckScreen
                         -> MineSiteView -> MineSiteScreen
```

- `MiningController.sellAllCargo()` remains the only sale mutation and sells only the active planet.
- `MiningShell._sellCargo()` remains the one presentation orchestration path for sale busy-state refresh, success/failure feedback, audio, and haptics.
- `SiteDeckView` remains a pure projection of active-planet status.
- `SiteDeckScreen` owns Site Deck presentation only.
- Mine Site keeps its existing dedicated `_SellControl`; only its semantic-label function delegates to the shared copy helper.

## Design decisions

### 1. Cargo-full is an overlay on operational state, not a fifth lifecycle state

`MiningSiteCardState` currently means lifecycle/availability:

- `locked`
- `available`
- `idle`
- `operational`

That enum is also consumed by Stellar Map projections. HPA-286 should not widen it merely to express a storage condition.

Add a derived getter to `MiningSiteCardView`:

```dart
bool get isCargoFull =>
    isOperational && capacity > 0 && cargo >= capacity;
```

A full site remains operational in lifecycle terms: it is commissioned and has rigs. The additional boolean says its current storage headroom is exhausted.

Use the simulation invariant as-is. Simulation already clamps stored cargo to effective capacity, so `cargo >= capacity` is the presentation boundary; do not add epsilon math, hysteresis, or persisted full flags.

### 2. Site Deck sale eligibility stays derived from existing aggregate projection

`SiteDeckView` already exposes:

- `totalCargo`;
- `projectedValue`;
- `isBusy`.

Add derived getters only:

```dart
bool get canSell => !isBusy && projectedValue > 0;

bool get hasUnsellableCargo =>
    !isBusy && totalCargo > 0 && projectedValue == 0;
```

This mirrors the current Mine Site affordance without adding another stored field or sale-affordance type.

`projectedValue` is already the floor of the active planet's aggregate gross value, matching `MiningController.sellAllCargo()`.

### 3. Sale semantic copy has one owner

Mine Site already exposes these player-facing semantics:

- busy -> `Finishing previous action…`
- sellable -> `Sell all cargo for N cash.`
- positive cargo worth 0 -> `Keep mining until cargo is worth at least 1 cash.`
- otherwise -> `No cargo to sell.`

Do not duplicate those literals in `_SiteDeckSellAction`.

Move the branching into one small top-level helper next to the Site Deck sale getters in `site_deck_view.dart`:

```dart
String miningSaleActionLabel({
  required bool isBusy,
  required bool canSell,
  required bool hasUnsellableCargo,
  required int projectedValue,
})
```

The helper owns copy only; it does not calculate cargo/value or mutate state.

- Site Deck calls it with `SiteDeckView`'s derived values.
- Mine Site's existing private `_saleLabel(MineSiteView view)` becomes a one-line delegation to the helper.
- Mine Site's `_SellControl`, layout, key, projected-value text, and callback remain unchanged.

This deliberately widens the production surface by one tiny Mine Site call-site edit to remove duplicate semantics; it is not a Mine Site UX rewrite.

### 4. Full guidance stays in the affected card without deleting occupancy information

Do not add a banner, tutorial prompt, toast loop, badge registry, or global alert state.

Do not replace the portrait top-right node dots. Those dots communicate deployed-rig occupancy and stay visible when a site is full.

#### Portrait prototype cards

A full card remains lifecycle-`operational` but gets local stall treatment:

- keep the existing card dimensions, art, rig badges, and node dots;
- warning border/shadow treatment is allowed here because portrait `available` cards do not use warning chrome;
- keep the cargo progress bar at 100%;
- replace the normal trailing percentage with compact cargo-row copy equivalent to `FULL · SELL TO RESUME`;
- card semantics identify the site as full/stalled and tell the player to sell.

No separate FULL badge is added elsewhere on the card.

#### Landscape cards

Landscape already uses warning chrome for `available`, so a full operational card must retain the normal operational accent border/chip color.

Only the status text changes:

- state chip label: `FULL`, while the chip color still comes from `MiningSiteCardState.operational`;
- bottom status: `FULL — SELL TO RESUME`;
- semantics identify the full/stalled state.

Under-capacity operational cards retain current visuals/copy. Idle/available/locked cards are unchanged.

### 5. One planet-wide Sell action appears in Site Deck chrome

The sale mutation is active-planet-wide, so the Site Deck gets one Sell action rather than a button on every card.

Add a required `VoidCallback onSellCargo` to `SiteDeckScreen` and one small private `_SiteDeckSellAction` widget.

The action:

- has stable key `site-deck-sell`;
- reuses `MiningVisuals.cargoIcon` and existing theme colors;
- displays `SELL` plus the active planet's projected cash value;
- is enabled only when `view.canSell`;
- uses `miningSaleActionLabel(...)` for semantics;
- remains separate from `MiningCargoGauge`;
- has a minimum 48×48 interactive target in every orientation;
- contains no mutation logic.

Do not wire `MiningCargoGauge.onPressed`. The gauge remains a readout, matching Mine Site's separate gauge/action ownership.

#### Portrait placement — explicit no-reflow contract

The current authored portrait geometry at 402×874 is:

- cargo gauge: `Rect.fromLTWH(310, 50, 80, 80)`;
- site list starts at y = 164.

Only 34px exists below the gauge, so a 48px Sell target cannot live there.

Keep the existing 196px header and `site-deck-scroll top: 164 + pad.top`. Place the Sell action in the free band immediately left of the gauge:

```text
right: 104
top: 108 + pad.top
width: 80
height: 48
```

At 402×874 with zero safe-area inset this is:

```text
Rect.fromLTWH(218, 108, 80, 48)
```

That leaves:

- 12px horizontal gap before the gauge;
- 8px vertical gap before the site-list boundary.

Tests must prove it also does not overlap the cash chip or `_PlanetProgress`, including the existing compact/text-scale viewport coverage. If this exact placement cannot satisfy those tests, stop and revise the layout explicitly; do not shrink the tap target below 48px or silently push content under another control.

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
- foreground refresh already updates Site Deck once per second;
- the existing cargo-full SFX crossing detector in `MiningShell._announceFullCargo(...)` remains unchanged.

HPA-286 adds readability and access, not a new stall mechanic.

## File-level changes

### `lib/mining/site_deck_view.dart`

- add `MiningSiteCardView.isCargoFull` derived getter;
- add `SiteDeckView.canSell` and `SiteDeckView.hasUnsellableCargo` derived getters;
- add `miningSaleActionLabel(...)` as the single sale-copy helper;
- keep `MiningSiteCardState` exactly four values;
- change no constructor/state shape.

### `lib/mining/presentation/site_deck_screen.dart`

- add required `onSellCargo` callback;
- add the private Site Deck Sell control used by portrait and landscape;
- use the explicit 80×48 portrait placement left of the gauge;
- add full-state copy/semantics in both card variants;
- keep portrait rig-occupancy dots;
- keep landscape full cards on operational accent chrome;
- keep Fleet Dock absent.

### `lib/mining/presentation/mine_site_screen.dart`

- import/reuse `miningSaleActionLabel(...)`;
- make existing `_saleLabel(MineSiteView view)` delegate to it;
- change no Mine Site widget, geometry, key, callback, or UX behavior.

### `lib/mining/presentation/mining_shell.dart`

- pass `_sellCargo` to `SiteDeckScreen`;
- do not change `_sellCargo()` behavior.

No production changes are expected in controller, simulation, persistence, state, content, Stellar Map, fleet, grid, assets, or platform files.

## Verification strategy

### Pure projection and shared copy

Extend `test/mining/site_deck_view_test.dart`:

- a rigged commissioned site exactly at capacity reports `isCargoFull == true`;
- an otherwise identical under-capacity site stays operational but not full;
- an idle site with zero capacity is not full;
- `SiteDeckView.canSell` is true only for non-busy projected value > 0;
- cargo with projected value 0 exposes `hasUnsellableCargo` without enabling Sell;
- `miningSaleActionLabel(...)` pins all four existing semantic strings.

Existing Mine Site sale-control tests remain the integration evidence that Mine Site still exposes the same shared copy.

### Site Deck presentation

Extend `test/mining/presentation/site_deck_screen_test.dart`:

- helper accepts `onSellCargo`;
- full portrait card exposes `FULL · SELL TO RESUME` on its cargo row and full semantics;
- portrait rig-occupancy dots remain present on a full operational card;
- under-capacity operational card does not show full guidance;
- full landscape card reads `FULL` / `FULL — SELL TO RESUME` while retaining operational accent chrome;
- `site-deck-sell` appears in portrait and landscape;
- enabled Sell tap emits exactly one callback;
- empty/busy/unsellable sale states disable the control with the shared semantic guidance;
- `site-deck-sell` is at least 48×48 in portrait and landscape;
- at 402×874, Sell is pinned to `Rect.fromLTWH(218, 108, 80, 48)`;
- that rect does not overlap cash, cargo gauge, planet progress, first card, or bottom navigation;
- existing 360×640 / 430×932 / 874×402 text-scale and Fleet-Dock-absence checks stay green.

### Shell integration

Extend `test/mining/presentation/mining_shell_test.dart`:

- seed saleable cargo directly with the existing `deployedLandingState(_start, cargo: 10)` fixture pattern; do not wait on the one-second timer to manufacture saleability;
- from Site Deck, tapping `site-deck-sell` clears active-planet cargo, increases cash, and stays on Site Deck;
- sale success keeps the existing `Sold N cash.` feedback and sale sound/haptic behavior;
- with a delayed repository save, the Sell action disables immediately while persistence is pending and a second tap cannot queue another sale;
- existing Mine Site sale tests remain authoritative and green.

Do not add controller tests unless implementation discovers an actual controller regression; HPA-286 does not change controller behavior.

## Acceptance mapping

- **Full/stalled site identifiable from Site Deck**: derived `isCargoFull` plus local cargo-row/chip copy and semantics.
- **Selling resumes headroom is explicit**: `FULL · SELL TO RESUME` / `FULL — SELL TO RESUME`.
- **Active-planet cargo sellable from Site Deck**: `site-deck-sell` -> existing `_sellCargo()` -> `sellAllCargo()`.
- **Sale copy does not drift**: one shared helper, reused by Site Deck and existing Mine Site `_saleLabel`.
- **No occupancy information lost**: portrait rig dots remain.
- **No state-color ambiguity**: landscape full cards stay operational-accent, not available-warning.
- **No Fleet controls return**: Site Deck constructor gains only `onSellCargo`; existing Fleet Dock absence tests remain.
- **No new save/economy/tutorial subsystem**: projection/presentation/shell wiring only.
- **Balance unchanged**: no controller/content/simulation edits.

## Assets

No image generation or SFX work is required. Reuse the current cargo icon, card art, theme colors, cargo-full sound, and sale sound.
