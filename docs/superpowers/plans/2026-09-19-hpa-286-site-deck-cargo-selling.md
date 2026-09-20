# HPA-286 — Site Deck Cargo-full State and Selling Implementation Plan

- Date: 2026-09-19
- Linear: HPA-286
- Design: `docs/superpowers/specs/2026-09-19-hpa-286-site-deck-cargo-selling-design.md`

## Delivery rule

One ticket = one PR.

Keep planning and implementation on this draft PR. Do not open a second implementation PR for HPA-286.

No image-generation or SFX task is included.

## Task 1 — Add derived full/sale projection without widening shared state

This task is projection-only and must stay green before widget wiring changes.

### Tests first

Extend `test/mining/site_deck_view_test.dart`.

Add a helper/fixture that can set stored cargo on a site with a deployed rig, then cover:

1. **exactly full**
   - commissioned + one rig;
   - `storedAmount == effective capacity`;
   - `state == MiningSiteCardState.operational`;
   - `isCargoFull == true`.

2. **under capacity**
   - same lifecycle/rate;
   - cargo below capacity;
   - still operational;
   - `isCargoFull == false`.

3. **idle is not full**
   - commissioned with no rig;
   - capacity 0;
   - `isCargoFull == false`.

4. **sale affordance**
   - non-busy projected sale > 0 -> `canSell == true`;
   - busy -> `canSell == false`;
   - zero cargo -> `canSell == false` / no unsellable cargo;
   - positive cargo whose aggregate floored value is 0 -> `canSell == false` and `hasUnsellableCargo == true`.

### Production change

Edit `lib/mining/site_deck_view.dart` only.

Add:

```dart
bool get isCargoFull =>
    isOperational && capacity > 0 && cargo >= capacity;
```

to `MiningSiteCardView`.

Add derived getters to `SiteDeckView`:

```dart
bool get canSell => !isBusy && projectedValue > 0;

bool get hasUnsellableCargo =>
    !isBusy && totalCargo > 0 && projectedValue == 0;
```

Do not:

- add `MiningSiteCardState.full`;
- add constructor fields for these booleans;
- change `SiteMetrics.of(...)`;
- add epsilon/full thresholds;
- touch controller/simulation/save code.

### Focused gate

```sh
dart format --output=none --set-exit-if-changed \
  lib/mining/site_deck_view.dart \
  test/mining/site_deck_view_test.dart
flutter test test/mining/site_deck_view_test.dart
```

## Task 2 — Add Site Deck full-state chrome and one planet-wide Sell action

`SiteDeckScreen` and its `MiningShell` constructor call must change atomically so the repository continues compiling.

### Widget tests first

Update the `_progress(...)`, `_deckView(...)`, and `_pumpDeck(...)` helpers in `test/mining/presentation/site_deck_screen_test.dart` so tests can:

- set `storedAmount`;
- construct busy/non-busy `SiteDeckView`;
- inject `onSellCargo`.

Add portrait coverage:

- a full Landing Basin card shows a visible `FULL` cue;
- its cargo row shows `SELL TO RESUME` instead of the ordinary percent label;
- semantics identify the site as full and tell the player to sell;
- the full card uses warning-state treatment while an under-capacity operational card keeps normal operational treatment;
- `site-deck-sell` exists and shows the projected active-planet value;
- tapping enabled Sell emits exactly one callback;
- zero cargo disables the action;
- positive cargo with floored aggregate value 0 disables the action with the tiny-sale guidance;
- busy view disables the action with pending-action guidance.

Add/extend layout assertions at 402x874:

- cargo gauge keeps its current rect;
- Sell sits below the gauge and above `site-deck-scroll`;
- Sell does not overlap `_PlanetProgress` or the first site card;
- existing Site Deck card and navigation placement remains green.

Add landscape coverage at 874x402:

- `site-deck-sell` is visible/reachable beside the HUD;
- a full card state chip/status reads `FULL` / `FULL — SELL TO RESUME`;
- no Fleet Dock appears.

Keep the existing 360x640, 430x932, 874x402 text-scale test and update only what the new control requires.

### Production change — Site Deck

Edit `lib/mining/presentation/site_deck_screen.dart`.

Add required constructor field:

```dart
final VoidCallback onSellCargo;
```

Pass it through portrait/landscape branches.

Add one private `_SiteDeckSellAction` used by both orientations:

- key: `site-deck-sell`;
- current cargo icon;
- `SELL` + `view.projectedValue`;
- `onPressed: view.canSell ? onSellCargo : null`;
- stable semantic label derived from busy/sellable/unsellable/empty state;
- no mutation logic.

Portrait:

- place the action below the 80px cargo gauge in the existing 196px header;
- keep `site-deck-scroll` top at the current 164px + safe-area inset.

Landscape:

- wrap the current top `MiningHud` in a row;
- keep the HUD expanded;
- place the compact Sell action beside it;
- do not add another toolbar or footer.

Add full-state card presentation without changing `MiningSiteCardState`:

- helper labels take the whole `MiningSiteCardView` when full-state knowledge is needed;
- portrait full card: warning border/shadow, `FULL` badge in the operational-status area, progress label `SELL TO RESUME`;
- landscape full card: warning border/state chip and status `FULL — SELL TO RESUME`;
- card semantics include full/sell guidance;
- idle/available/locked and under-capacity operational visuals remain unchanged.

### Production change — shell wiring

Edit `lib/mining/presentation/mining_shell.dart` in the same task:

```dart
SiteDeckScreen(
  ...
  onSellCargo: _sellCargo,
)
```

Do not change `_sellCargo()` itself.

### Focused gate

```sh
dart format --output=none --set-exit-if-changed \
  lib/mining/site_deck_view.dart \
  lib/mining/presentation/site_deck_screen.dart \
  lib/mining/presentation/mining_shell.dart \
  test/mining/site_deck_view_test.dart \
  test/mining/presentation/site_deck_screen_test.dart
flutter test test/mining/site_deck_view_test.dart
flutter test test/mining/presentation/site_deck_screen_test.dart
flutter analyze --fatal-infos
```

## Task 3 — Pin Site Deck sale through the existing shell/controller path

Do not add controller behavior here; this task proves the new entry point uses what already exists.

### Shell tests first

Extend `test/mining/presentation/mining_shell_test.dart` with public-behavior coverage.

#### Site Deck sell success

1. initialize a save with a commissioned, rigged active-planet site;
2. advance/refresh so active-planet cargo is sellable;
3. remain on Site Deck;
4. tap `site-deck-sell`;
5. wait for persistence;
6. assert active-planet cargo is 0;
7. assert cash increased by the controller-reported sale value;
8. assert Site Deck remains the active primary surface;
9. assert existing `Sold N cash.` feedback and sale sound are emitted.

#### Busy double-tap guard

Use the existing delayed/failing repository fixture pattern:

1. start a Site Deck sale whose save is pending;
2. assert the Site Deck Sell action disables immediately after the shell busy refresh;
3. attempt another tap;
4. release persistence;
5. assert only one sale mutation/result occurred.

Do not inspect private shell fields.

Keep existing Mine Site sale tests unchanged; they prove the same `_sellCargo()` path still works from gameplay.

### Production change

No additional production change should be necessary after Task 2.

If the shell test exposes a real wiring bug, fix only that wiring. Stop and re-evaluate if implementation starts requiring a new sale API, result type, queue, or controller rule.

### Focused gate

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

## Task 4 — Final scope audit and repository gates

Search the intended cut surface:

```sh
rg "site-deck-sell|isCargoFull|canSell|hasUnsellableCargo|onSellCargo" \
  lib/mining \
  test/mining
```

Expected ownership:

- `isCargoFull`, Site Deck sale getters: `site_deck_view.dart`;
- Site Deck sell/full presentation: `site_deck_screen.dart`;
- Site Deck -> `_sellCargo` wiring: `mining_shell.dart`;
- existing Mine Site `onSellCargo` remains;
- `MiningController.sellAllCargo()` is unchanged.

Confirm there is no:

- `MiningSiteCardState.full`;
- new controller sale method;
- save/schema field;
- auto-sell;
- per-card sale mutation;
- Fleet Dock on Site Deck;
- new tutorial/alert framework;
- new image or audio asset.

Run full gates:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
git diff --check
```

Run platform builds only if the normal repository workflow for the branch requires them; HPA-286 changes no platform code.

## Expected files

Production:

- `lib/mining/site_deck_view.dart`
- `lib/mining/presentation/site_deck_screen.dart`
- `lib/mining/presentation/mining_shell.dart`

Tests:

- `test/mining/site_deck_view_test.dart`
- `test/mining/presentation/site_deck_screen_test.dart`
- `test/mining/presentation/mining_shell_test.dart`

Planning:

- `docs/superpowers/specs/2026-09-19-hpa-286-site-deck-cargo-selling-design.md`
- `docs/superpowers/plans/2026-09-19-hpa-286-site-deck-cargo-selling.md`

No controller, simulation, persistence, state-schema, asset, or platform file is expected.

## Completion criteria

- Full sites are unmistakable from Site Deck in portrait and landscape.
- Full-site guidance explicitly says `SELL TO RESUME`.
- Under-capacity operational sites still look operational, not stalled.
- Site Deck has one active-planet Sell action in portrait and landscape.
- Sell eligibility/value matches the existing aggregate projection.
- Site Deck sale routes through the existing `_sellCargo()` / `sellAllCargo()` path.
- Sale disables while a mutation is pending and cannot queue a duplicate tap.
- Existing Mine Site selling still works.
- Fleet controls remain absent from Site Deck.
- No enum widening, save field, economy rule, tutorial state, new asset, or second sale path is introduced.

## Scope guardrail

Stop and re-evaluate if implementation starts requiring:

- `MiningSiteCardState.full` across Stellar Map;
- controller/simulation/persistence changes;
- a second sale orchestration path;
- per-site or global selling;
- auto-sell;
- another state-management/tutorial/alert subsystem;
- Fleet Dock work;
- new image generation or SFX.