# HPA-427 Relaunch Design

- Date: 2026-10-22
- Status: Implemented
- Linear: [HPA-427](https://linear.app/cwchanap/issue/HPA-427/mining-endgame-relaunch-after-the-final-frontier-for-a-permanent-cash) — Relaunch after the final frontier for a permanent cash bonus
- Original baseline: `main` at `15fd4c0`, after HPA-403 (Ceres Frontier) and HPA-200 (Ceres caverns)
- Rechecked 2026-10-23 against `main` at `49d8a97` (HPA-184 cleanup landed; relevant mining ownership and sale paths unchanged). Rebase this PR before implementation.
- Related: [HPA-262](https://linear.app/cwchanap/issue/HPA-262/mining-content-ship-io-frontier-as-the-fifth-planet-after-ceres) — Io Frontier, which moves the final planet

## Problem

The game ends. A player who masters Ceres (50 h of play with two-hour visits, six days with four visits a day, per HPA-403's journey) sees `All frontiers mastered`, then `Keep upgrading Extraction and Logistics`, then nothing. Cash keeps piling up with nothing to spend it on, and there is no reason to come back.

## Goal

> Master the final frontier → Relaunch → start again from a fresh Homeworld with a permanent sale-value bonus → the next run is faster → repeat.

The loop reuses every planet, site, and piece of art already shipped. The player learns one new action, not a new system.

## Non-goals

This work does not add:

- a prestige currency, a prestige shop, or a choice of bonuses;
- a partial reset (keeping technology, rigs, or planets);
- a cap on relaunches, a leaderboard, or run statistics;
- a rate, capacity, or offline-cap bonus;
- new art or a new SFX;
- a save version, migration, or compatibility reader.

## Design

### 1. One counter in the save

`MiningSave` gains `relaunchCount` (int, 0 or more). It is the only state that survives a relaunch. The strict root keys become:

```text
cash, lastAccruedAtUtc, technology, unlockedPlanetIds, activePlanetId, docks, sites, relaunchCount
```

`MiningSave.initial` takes `relaunchCount` (default 0). `MiningSaveRepository` decodes it as a non-negative int and rejects anything else. Every save without the key is incompatible and clean-resets through the existing recovery boundary with the recovered-load flag; there is no migration, as with every earlier contract change.

### 2. The bonus is a sale-value multiplier

```dart
static const relaunchSaleBonus = 0.5;
static double saleMultiplier(int relaunchCount) => 1 + relaunchSaleBonus * relaunchCount;
```

Every sale earns `amount × saleValuePerUnit × saleMultiplier(relaunchCount)`. Run 2 sells at ×1.5, run 3 at ×2.0, and so on.

The bonus sits on sale value, not on rate or capacity, because a rate bonus would shrink HPA-401's two-hour storage window (storage holds `rate × window`), and a capacity bonus would only matter to players who are away longer than two hours. A sale bonus changes neither the window nor the offline numbers; it only makes every cash target arrive sooner.

Sale value is computed today in seven places (`sellAllCargo`, and two each in `site_deck_view.dart`, `mine_site_view.dart`, and `mining_progression_views.dart`). Consolidate the per-site multiplication on `MiningContentRegistry` and the four repeated aggregate totals on `MiningSave` (which already imports mining content):

```dart
// MiningContentRegistry: unrounded value for one site.
double cargoValue(MiningSiteId site, double amount, int relaunchCount);

// MiningSave: floored sum for one planet, including relaunchCount.
int saleValue(MiningContentRegistry content, MiningPlanetId planet);
```

`sellAllCargo`, Site Deck, Mine Site, and Stellar Map use `state.saleValue(content, planet)` for their **planet-wide** sale values. Single-site cards use `content.cargoValue(id, amount, state.relaunchCount).floor()`. This keeps the existing contract: sum **unrounded** site values and floor **once** for an aggregate, even when several sites have fractional cargo. Do not sum the floored card labels. Test two fractional sites directly on `MiningSave.saleValue`, then compare controller revenue to that value before selling; do not add three redundant per-view fractional-rounding tests.

A single `formatSaleMultiplier(double multiplier)` helper beside `formatMiningCash` formats the resulting multiplier on the controller message, goal, card, sheet, and status line. Keep up to two decimal places without rounding 1.75 to 1.8; display ×1.5 / ×1.75 / ×2 as appropriate. The number itself remains controlled by `relaunchSaleBonus`.

### 3. Relaunch is a controller action

```dart
Future<MiningActionResult> relaunch();
```

- Unlike every other action it does **not** accrue first: mastery depends only on commissioned flags, which accrual never changes, and the reset discards the accrued state anyway. It gates on current state directly — `content.isPlanetMastered(content.finalPlanetId, _commissionedSiteIds(_state))` — where `finalPlanetId` is the last planet in authored order (`MiningPlanetId.values.last`). When HPA-262 adds Io Frontier, the gate moves to Io with no code change.
- On failure it returns `Master <final planet name> first.` and changes nothing.
- On success the next state is `MiningSave.initial(nowUtc: now, relaunchCount: previous + 1)`: 100 cash, Homeworld only, its two T1 starter rigs, Landing Basin unlocked, technology 0. Cargo on every planet is discarded, not sold. It persists once through the repository and returns `Relaunch <n> — sales ×<multiplier>.`.

The final planet's 30,000,000 mastery reward is unchanged and is paid again in every run, because each run masters the final planet from a fresh state. It is still "once per run".

### 4. Where the player meets it

- **Next goal.** `MiningGoalKind.frontiersMastered` becomes `MiningGoalKind.relaunch`: title `Relaunch`, detail `Start again with sales ×<next multiplier>.`, target the Stellar Map. The old "keep upgrading Extraction and Logistics" step goes away, because a relaunch resets technology anyway.
- **Stellar Map.** Below the planet cards, a Relaunch card appears once the final planet is mastered. `StellarMapView.isRelaunchUnlocked` is derived from mastery and controls visibility; `canRelaunch` additionally checks `!isBusy` and disables the button during a pending action instead of making the card disappear. It shows the next multiplier and a Relaunch button.
- **Confirmation.** The button opens a sheet in the existing `MiningSheetFrame` that lists what resets (cash, technology, rigs, planets, cargo) and what stays (the relaunch count and the new multiplier), with Cancel and Relaunch. Relaunch is the only destructive action in the game, so it is the only one with a confirmation.
- **After relaunch.** The confirmation sheet closes and the shell awaits its existing `_runSheetAction` with the milestone sound. Its `onSuccess` is Mine-Site-local, so this action cannot use that callback for navigation. Compare `relaunchCount` before/after the awaited action; only if it increased, call `_showPrimarySurface(MiningNavigationDestination.siteDeck)`. This explicitly returns to Homeworld after persistence, reusing snackbar and sound handling. The extra navigation tap is lower priority than `milestone` and cannot interrupt it. Cancel never invokes the controller; the controller's serialized mutation gate rejects a second relaunch after the first reset.
- **Current bonus.** Once `relaunchCount > 0`, display `RELAUNCH <n> · SALES ×<multiplier>` as the **first child of the Stellar Map scrolling column**, above the cards, rather than adding a second line to the absolutely positioned `_MapHeader` (which would require conditional offsets). All values use the shared formatter, and every projected and sold total uses `saleValue`.

### 5. Pacing

Rates, storage, and prices are unchanged, so a run's cash income scales with the multiplier. The public-action journey is the pacing proof, but it must preserve the existing 30-hour offline-return assertion **before** relaunch: that check relies on the commissioned Ceres production state. After it, invoke `relaunch()` on the live `returned` controller, then use a fresh `JourneyPlayer(returned, clock, content)` for run 2. Do not continue on the older, stale controller.

Extract the reusable Homeworld-to-final-planet actions into `_playRun`, returning `({Duration opening, Duration mars, Duration last})` relative to **that run's own start**. Keep the existing opening, Mars, and final-planet absolute pacing bands on **run 1 only**; applying their minimums to run 2 would reject the intended speedup. For run 2, assert only a relative improvement: at least 20% faster at two-hour visits and faster at six-hour visits. Compare complete runs rather than an early milestone (run 1 already unlocks Lunar on its first two-hour return).

`JourneyPlayer._siteIncome` should use `cargoValue` instead of raw unit sale value so its income-per-visit diagnostics reflect the relaunch multiplier; this changes no production path. The 0.5 step is a starting point. Raise it if the two-hour speedup is under 20%. Record measured times in the PR; do **not** add an arbitrary lower duration bound for run 2 or a second pacing system. No other economy number changes.

## Touch points

- `lib/mining/mining_state.dart`: `relaunchCount` on `MiningSave` (constructor, `initial`, `copyWith`, `toJson`, `==`, `hashCode`).
- `lib/mining/mining_save_repository.dart`: the eighth root key and its decode.
- `lib/mining/mining_content.dart`: `relaunchSaleBonus`, `saleMultiplier`, `finalPlanetId`, `cargoValue`, and `formatSaleMultiplier`.
- `lib/mining/mining_state.dart`: also owns `saleValue(content, planet)`, the floored aggregate.
- `lib/mining/mining_controller.dart`: `relaunch()`; `sellAllCargo` uses `state.saleValue`.
- `lib/mining/site_deck_view.dart`, `lib/mining/mine_site_view.dart`, `lib/mining/mining_progression_views.dart`: single-site previews use `cargoValue` and planet totals use `state.saleValue`; `StellarMapView` gains `relaunchCount`, `isRelaunchUnlocked`, `canRelaunch`, and `nextSaleMultiplier` as derived fields.
- `lib/mining/next_goal_view.dart`: the `relaunch` kind.
- `lib/mining/presentation/stellar_map_screen.dart`: the Relaunch card and header line; a new `relaunch_sheet.dart` beside the other sheets.
- `lib/mining/presentation/mining_shell.dart`: opens the sheet, calls `relaunch()`, plays the cue, navigates.
- `CLAUDE.md`: the root-key list, the relaunch rule, and the journey description.

No new controller, repository, simulation, save key other than `relaunchCount`, or state owner.

## Testing

- **State and repository:** initial state has `relaunchCount` 0; a save with `relaunchCount` 3 round-trips; a save without the key, with a negative value, or with a non-int clean-resets with the recovered flag.
- **Content/state:** `saleMultiplier` is 1.0 / 1.5 / 2.0 for 0 / 1 / 2; `finalPlanetId` is Ceres today; `formatSaleMultiplier` displays 1.75 precisely; `cargoValue` matches unit economics; `MiningSave.saleValue` floors a sum from two fractional sites only once.
- **Controller:** `relaunch()` fails before final-planet mastery with no save; on success the state equals `MiningSave.initial` at the clock time with `relaunchCount + 1` and saves once; actual sale revenue equals pre-sale `state.saleValue`. Two concurrent `relaunch()` requests produce one success, one failure, and one write.
- **Views:** Existing view tests verify the multiplier is visible; no separate per-view fractional rounding proofs. The next goal after final-planet mastery is `relaunch`; `isRelaunchUnlocked` persists while busy but `canRelaunch` is disabled.
- **Widgets:** the Relaunch card and sheet work at 360×640 and 430×932 with no overflow; simple finder test for the scrolling status line, not an absolute-header font overlap test. Cancel changes nothing; success plays `milestone` and lands on Homeworld.
- **Journey:** update the old goal expectation in Task 2; keep the 30-hour offline-return proof before relaunch in Task 4, drive run 2 from `returned`, assert run-1 absolute bands and run-2 relative speedup, and reload with `relaunchCount` 1.

## Risks

- **Seven call sites.** Missing a per-site `cargoValue` or aggregate `MiningSave.saleValue` call makes a projection disagree with the sale. Verify the raw multiplier only inside `cargoValue`, a two-site fractional aggregate on `MiningSave`, and controller parity before selling; re-use existing view assertions instead of duplicating the rounding tests.
- **Accidental relaunch.** The confirmation sheet is the guard; the action is unreachable before final mastery.
- **Long late runs.** Every run still replays Homeworld from 100 cash. The journey's run-2 time tells us whether the early game feels short enough; if not, the fix is the bonus step, not a new system.

## Assets

None. Uses existing art and the existing milestone cue.
