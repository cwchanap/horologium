# HPA-286 — Site Deck Cargo-full State and Selling Implementation Plan

- Date: 2026-09-19
- Linear: HPA-286
- Design: `docs/superpowers/specs/2026-09-19-hpa-286-site-deck-cargo-selling-design.md`

## Delivery rule

One ticket = one PR.

Keep planning and implementation on this draft PR. Do not open a second implementation PR for HPA-286.

No image-generation or SFX task is included.

## Task 1 — Add derived full/sale projection and centralize sale copy

This task stays pure/read-model plus one semantic helper. It must remain green before widget wiring changes.

### Tests first

Extend `test/mining/site_deck_view_test.dart`.

Add a fixture that can set stored cargo on a site with a deployed rig, then cover:

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

5. **shared sale semantics**
   - busy -> `Finishing previous action…`;
   - sellable -> `Sell all cargo for N cash.`;
   - unsellable positive cargo -> `Keep mining until cargo is worth at least 1 cash.`;
   - empty -> `No cargo to sell.`.

### Production change

Edit `lib/mining/site_deck_view.dart`.

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

Add one copy-only helper next to those getters:

```dart
String miningSaleActionLabel({
  required bool isBusy,
  required bool canSell,
  required bool hasUnsellableCargo,
  required int projectedValue,
});
```

It returns the existing Mine Site strings exactly. It must not calculate cargo or mutate state.

Do not:

- add `MiningSiteCardState.full`;
- add constructor fields for these booleans;
- change `SiteMetrics.of(...)`;
- add epsilon/full thresholds;
- add a sale-affordance class/type;
- touch controller/simulation/save code.

### Focused gate

```sh
dart format --output=none --set-exit-if-changed \
  lib/mining/site_deck_view.dart \
  test/mining/site_deck_view_test.dart
flutter test test/mining/site_deck_view_test.dart
```

## Task 2 — Reuse sale semantics, add full-state chrome, and fit one honest Site Deck Sell action

This is the risky task. The primary failure mode is portrait geometry, not sale/controller ownership.

`SiteDeckScreen`, the Mine Site semantic delegate, and the `MiningShell` Site Deck constructor call change atomically so the repository continues compiling.

### Tests first — Mine Site semantic reuse

Keep the existing `mine_site_screen_test.dart` sale-label tests as the behavioral contract. They already pin:

- `Sell all cargo for N cash.`;
- tiny-sale keep-mining feedback;
- enabled/disabled sale behavior.

No new Mine Site widget test is required unless the helper delegation breaks an existing case.

### Tests first — Site Deck

Update the `_progress(...)`, `_deckView(...)`, and `_pumpDeck(...)` helpers in `test/mining/presentation/site_deck_screen_test.dart` so tests can:

- set `storedAmount`;
- construct busy/non-busy `SiteDeckView`;
- inject `onSellCargo`.

Add portrait coverage:

- a full Landing Basin card shows `FULL · SELL TO RESUME` in the cargo/progress row;
- semantics identify the site as full and tell the player to sell;
- the existing rig-occupancy dots remain present while full;
- the full card may use warning border/shadow treatment;
- an under-capacity operational card retains normal operational treatment;
- `site-deck-sell` exists, shows projected active-planet value, and uses the shared sale semantics;
- tapping enabled Sell emits exactly one callback;
- zero cargo disables the action;
- positive cargo with floored aggregate value 0 disables the action with the shared tiny-sale guidance;
- busy view disables the action with the shared pending-action guidance.

Pin the authored 402×874 geometry:

- cargo gauge remains `Rect.fromLTWH(310, 50, 80, 80)`;
- `site-deck-scroll` still starts at y = 164;
- `site-deck-sell` is `Rect.fromLTWH(218, 108, 80, 48)`;
- Sell does not overlap cash, cargo gauge, `_PlanetProgress`, first site card, or bottom navigation.

Add landscape coverage at 874×402:

- `site-deck-sell` is visible/reachable beside the HUD;
- a full card state chip reads `FULL`;
- status reads `FULL — SELL TO RESUME`;
- border/chip remain operational accent, not available-warning;
- no Fleet Dock appears.

Extend the existing accessibility coverage:

- `site-deck-sell` is at least 48×48 in portrait;
- `site-deck-sell` is at least 48×48 in landscape;
- existing card and navigation target-size checks stay green.

Keep the existing 360×640, 430×932, 874×402 text-scale test. The new Sell action must fit without overlap/truncation there too.

### Production change — shared semantic reuse

Edit `lib/mining/presentation/mine_site_screen.dart`:

- import/reuse `miningSaleActionLabel(...)`;
- replace the body of private `_saleLabel(MineSiteView view)` with delegation to that helper;
- do not change `_SellControl`, `MiningCargoGauge`, geometry, keys, value text, or callbacks.

Do not extract a shared Sell widget.

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
- semantic label from `miningSaleActionLabel(...)`;
- minimum 48×48 target;
- no mutation logic;
- do not use `MiningCargoGauge.onPressed`.

Portrait placement is explicit:

```text
right: 104
top: 108 + pad.top
width: 80
height: 48
```

At 402×874 with zero safe-area inset this must equal `Rect.fromLTWH(218, 108, 80, 48)`.

Keep:

- cargo gauge at its existing position;
- `site-deck-scroll top: 164 + pad.top`;
- existing 196px header.

Do not put Sell below the gauge. Do not shrink it below 48px. If the chosen rect fails the compact/text-scale overlap checks, stop and revise the composition explicitly rather than silently moving the list.

Landscape:

- wrap the current top `MiningHud` in a row;
- keep the HUD `Expanded`;
- place the compact Sell action beside it;
- do not change `MiningHud` or create another toolbar/footer.

Full-card behavior without enum changes:

- portrait: keep node dots; keep 100% bar; trailing cargo-row copy becomes `FULL · SELL TO RESUME`; semantics become full/stalled; warning border/shadow is allowed;
- landscape: state label becomes `FULL`, status becomes `FULL — SELL TO RESUME`, but `_StateChip` and border still receive `MiningSiteCardState.operational` so accent chrome remains;
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
  lib/mining/presentation/mine_site_screen.dart \
  lib/mining/presentation/mining_shell.dart \
  test/mining/site_deck_view_test.dart \
  test/mining/presentation/site_deck_screen_test.dart
flutter test test/mining/site_deck_view_test.dart
flutter test test/mining/presentation/site_deck_screen_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
flutter analyze --fatal-infos
```

## Task 3 — Pin Site Deck sale through the existing shell/controller path

Do not add controller behavior here; this task proves the new entry point uses what already exists.

### Shell tests first

Extend `test/mining/presentation/mining_shell_test.dart` with public-behavior coverage.

#### Site Deck sell success

Seed saleable state directly; do not wait on the one-second foreground timer:

```dart
await repository.save(deployedLandingState(_start, cargo: 10));
```

Then:

1. pump the shell and remain on Site Deck;
2. tap `site-deck-sell`;
3. wait for persistence;
4. assert active-planet cargo is 0;
5. assert cash increased by the existing controller sale value;
6. assert Site Deck remains the active primary surface;
7. assert existing `Sold N cash.` feedback and sale sound/haptic behavior.

#### Busy double-tap guard

Use the existing delayed repository fixture pattern with seeded cargo:

1. start a Site Deck sale whose save is pending;
2. pump the immediate shell busy refresh;
3. assert `site-deck-sell` is disabled;
4. attempt another tap;
5. release persistence;
6. assert only one sale mutation/result occurred.

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
rg "site-deck-sell|isCargoFull|canSell|hasUnsellableCargo|onSellCargo|miningSaleActionLabel" \
  lib/mining \
  test/mining
```

Expected ownership:

- `isCargoFull`, Site Deck sale getters, shared sale-copy helper: `site_deck_view.dart`;
- Site Deck sell/full presentation: `site_deck_screen.dart`;
- Mine Site semantic delegation only: `mine_site_screen.dart`;
- Site Deck -> `_sellCargo` wiring: `mining_shell.dart`;
- existing Mine Site `onSellCargo` remains;
- `MiningController.sellAllCargo()` is unchanged.

Confirm there is no:

- `MiningSiteCardState.full`;
- new controller sale method;
- save/schema field;
- auto-sell;
- per-card sale mutation;
- `MiningCargoGauge.onPressed` sale wiring;
- shared/extracted Sell-control widget;
- Fleet Dock on Site Deck;
- new tutorial/alert framework;
- new image or audio asset;
- portrait removal of rig-occupancy dots;
- landscape warning chrome used for a full operational card.

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
- `lib/mining/presentation/mine_site_screen.dart` — sale semantic helper delegation only
- `lib/mining/presentation/mining_shell.dart`

Tests:

- `test/mining/site_deck_view_test.dart`
- `test/mining/presentation/site_deck_screen_test.dart`
- `test/mining/presentation/mining_shell_test.dart`

Existing `test/mining/presentation/mine_site_screen_test.dart` should remain green without edits unless implementation exposes a concrete missing assertion.

Planning:

- `docs/superpowers/specs/2026-09-19-hpa-286-site-deck-cargo-selling-design.md`
- `docs/superpowers/plans/2026-09-19-hpa-286-site-deck-cargo-selling.md`

No controller, simulation, persistence, state-schema, content, Stellar Map, asset, or platform file is expected.

## Completion criteria

- Full sites are unmistakable from Site Deck in portrait and landscape.
- Full-site guidance explicitly says `FULL · SELL TO RESUME` / `FULL — SELL TO RESUME`.
- Portrait rig-occupancy dots remain visible while full.
- Landscape full cards retain operational accent chrome.
- Under-capacity operational sites still look operational, not stalled.
- Site Deck has one active-planet Sell action in portrait and landscape.
- Portrait Sell is an honest 80×48 target at the pinned authored rect and does not overlap existing header/list controls.
- Sell is at least 48×48 in both orientations.
- Site Deck and Mine Site reuse one sale semantic-label helper.
- Sell eligibility/value matches the existing aggregate projection.
- Site Deck sale routes through the existing `_sellCargo()` / `sellAllCargo()` path.
- Sale disables while a mutation is pending and cannot queue a duplicate tap.
- Existing Mine Site selling still works.
- Fleet controls remain absent from Site Deck.
- No enum widening, save field, economy rule, tutorial state, new asset, or second sale path is introduced.

## Scope guardrail

Stop and re-evaluate if implementation starts requiring:

- a portrait Sell target smaller than 48×48 or overlapping current header/list controls;
- an undeclared shift of the `site-deck-scroll` top away from 164;
- `MiningSiteCardState.full` across Stellar Map;
- controller/simulation/persistence changes;
- a second sale orchestration path;
- duplicated sale semantic strings;
- a shared/extracted Sell-control widget;
- per-site or global selling;
- auto-sell;
- another state-management/tutorial/alert subsystem;
- Fleet Dock work;
- new image generation or SFX.
