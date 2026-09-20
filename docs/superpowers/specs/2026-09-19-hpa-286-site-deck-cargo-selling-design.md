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

Use the controller/simulation invariant as-is. Simulation already clamps stored cargo to effective capacity, so `cargo >= capacity` is the presentation boundary; do not add epsilon math, hysteresis, or persisted full flags.

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

This mirrors the current Mine Site affordance without adding another stored field or another sale calculation.

`projectedValue` is already the floor of the active planet's aggregate gross value, matching `MiningController.sellAllCargo()`.

### 3. Full guidance lives inside the affected site card

Do not add a banner, tutorial prompt, toast loop, badge registry, or global alert state.

For a full card:

- use warning-colored full-state chrome instead of the normal operational accent;
- expose a compact `FULL` cue;
- replace the ordinary percentage/status copy with `SELL TO RESUME` where the cargo state is already shown;
- include the full/stalled wording in card semantics.

Portrait prototype cards:

- keep the existing card dimensions and art;
- use warning border/shadow treatment when `card.isCargoFull`;
- replace the operational top-right node-dot status cue with a small `FULL` badge while full;
- keep the cargo progress bar at 100%; its right-side label becomes `SELL TO RESUME` instead of `100%`.

Landscape cards:

- state chip label becomes `FULL` while full;
- bottom status becomes `FULL — SELL TO RESUME`;
- warning border/chip color replaces the ordinary operational accent.

Under-capacity operational cards retain the current visuals/copy. Idle/available/locked cards are unchanged.

### 4. One planet-wide Sell action appears in Site Deck header chrome

The sale mutation is active-planet-wide, so the Site Deck gets one Sell action rather than a button on every card.

Add a required `VoidCallback onSellCargo` to `SiteDeckScreen` and one small private `_SiteDeckSellAction` widget.

The action:

- has stable key `site-deck-sell`;
- reuses `MiningVisuals.cargoIcon` and existing theme colors;
- displays `SELL` plus the active planet's projected cash value;
- is enabled only when `view.canSell`;
- exposes semantics equivalent to:
  - busy -> `Finishing previous action…`;
  - sellable -> `Sell all cargo for N cash.`;
  - cargo worth 0 -> `Keep mining until cargo is worth at least 1 cash.`;
  - empty -> `No cargo to sell.`.

Do not duplicate sale mutation/result logic in the widget.

#### Portrait placement

Keep the existing 196px header and 164px site-list top.

Place the compact Sell action directly below the existing 80px cargo gauge on the right, above the site-list boundary. The control must not overlap:

- the cargo gauge;
- the left-side planet progress row;
- the first site card.

No header expansion is needed.

#### Landscape placement

Keep the existing top HUD row. Wrap it in a row and place the compact Sell action beside the HUD.

Do not add a second toolbar/footer or alter bottom navigation geometry.

### 5. Reuse the existing shell sale orchestration unchanged

`MiningShell._sellCargo()` already:

1. rejects while uninitialized/busy;
2. starts `MiningController.sellAllCargo()`;
3. immediately refreshes presentation so busy state disables controls;
4. refreshes again after persistence;
5. preserves dock selection validity;
6. plays existing success/reject sound and success haptic;
7. shows `Sold N cash.` or the existing failure message.

Site Deck should call this same method.

The only shell production change is wiring:

```text
SiteDeckScreen.onSellCargo -> MiningShell._sellCargo
```

Mine Site continues using the same callback. No new sale runner, result type, or controller method is needed.

### 6. Full-state detection remains presentation-only

Do not modify production accrual behavior when a site becomes full.

The existing simulation remains authoritative:

- accrued cargo clamps at capacity;
- production resumes naturally after sale creates headroom;
- foreground refresh already updates Site Deck once per second;
- the existing cargo-full SFX in `MiningShell._announceFullCargo(...)` remains unchanged.

HPA-286 adds readability and access, not a new stall mechanic.

## File-level changes

### `lib/mining/site_deck_view.dart`

- add `MiningSiteCardView.isCargoFull` derived getter;
- add `SiteDeckView.canSell` and `SiteDeckView.hasUnsellableCargo` derived getters;
- keep `MiningSiteCardState` exactly four values;
- change no constructor/state shape.

### `lib/mining/presentation/site_deck_screen.dart`

- add required `onSellCargo` callback;
- add the shared private Site Deck Sell control used by portrait and landscape;
- add full-state visual/semantic treatment in both card variants;
- keep existing card/header/navigation geometry except the small Sell control insertion;
- keep Fleet Dock absent.

### `lib/mining/presentation/mining_shell.dart`

- pass `_sellCargo` to `SiteDeckScreen`;
- do not change `_sellCargo()` behavior.

No production changes are expected in controller, simulation, persistence, state, content, Mine Site, Stellar Map, fleet, or grid files.

## Verification strategy

### Pure projection

Extend `test/mining/site_deck_view_test.dart`:

- a rigged commissioned site exactly at capacity reports `isCargoFull == true`;
- an otherwise identical under-capacity site stays operational but not full;
- an idle site with zero capacity is not full;
- `SiteDeckView.canSell` is true only for non-busy projected value > 0;
- cargo with projected value 0 exposes `hasUnsellableCargo` without enabling Sell.

### Site Deck presentation

Extend `test/mining/presentation/site_deck_screen_test.dart`:

- helper accepts `onSellCargo`;
- full portrait card exposes `FULL` and `SELL TO RESUME` and full semantics;
- under-capacity operational card does not show full guidance;
- landscape full card exposes the same state/guidance;
- `site-deck-sell` appears in portrait and landscape;
- enabled Sell tap emits exactly one callback;
- empty/busy/unsellable sale states disable the control with the expected semantic guidance;
- at 402x874 portrait, Sell does not overlap cargo gauge, planet progress, first card, or bottom navigation;
- existing 360x640 / 430x932 / 874x402 text-scale and Fleet-Dock-absence checks stay green.

### Shell integration

Extend `test/mining/presentation/mining_shell_test.dart`:

- from Site Deck, active-planet cargo accrues and the Sell control becomes enabled;
- tapping Site Deck Sell uses the existing sale path, clears active-planet cargo, increases cash, and stays on Site Deck;
- sale success keeps the existing `Sold N cash.` feedback and sale sound/haptic behavior;
- while persistence is pending, the Site Deck Sell action is disabled so repeated taps do not queue a second sale;
- existing Mine Site sale tests remain authoritative and green.

Do not add new controller tests unless implementation discovers an actual controller regression; HPA-286 does not change controller behavior.

## Acceptance mapping

- **Full/stalled site identifiable from Site Deck**: `isCargoFull` + warning card treatment + `FULL`.
- **Selling resumes headroom is explicit**: local `SELL TO RESUME` copy on full cards.
- **Active-planet cargo sellable from Site Deck**: `site-deck-sell` -> existing `_sellCargo()` -> `sellAllCargo()`.
- **No Fleet controls return**: Site Deck constructor gains only `onSellCargo`; existing Fleet Dock absence tests remain.
- **No new save/economy/tutorial subsystem**: projection/presentation/shell wiring only.
- **Balance unchanged**: no controller/content/simulation edits.

## Assets

No image generation or SFX work is required. Reuse the current cargo icon, card art, theme colors, cargo-full sound, and sale sound.