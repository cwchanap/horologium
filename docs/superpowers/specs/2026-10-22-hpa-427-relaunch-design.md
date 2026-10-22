# HPA-427 Relaunch Design

- Date: 2026-10-22
- Status: Proposed
- Linear: [HPA-427](https://linear.app/cwchanap/issue/HPA-427/mining-endgame-relaunch-after-the-final-frontier-for-a-permanent-cash) — Relaunch after the final frontier for a permanent cash bonus
- Baseline: `main` at `15fd4c0`, after HPA-403 (Ceres Frontier) and HPA-200 (Ceres caverns)
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

Sale value is computed today in seven places (`sellAllCargo`, and two each in `site_deck_view.dart`, `mine_site_view.dart`, and `mining_progression_views.dart`). They all move to one helper on `MiningContentRegistry`:

```dart
double cargoValue(MiningSiteId site, double amount, int relaunchCount);
```

so the Sell button, the cargo gauge, the Site Deck card, the Stellar Map, and the actual sale cannot disagree.

### 3. Relaunch is a controller action

```dart
Future<MiningActionResult> relaunch();
```

- It accrues first, like every action, then requires the final planet to be mastered: `content.isPlanetMastered(content.finalPlanetId, commissioned)`, where `finalPlanetId` is the last planet in authored order (`MiningPlanetId.values.last`). When HPA-262 adds Io Frontier, the gate moves to Io with no code change.
- On failure it returns `Master <final planet name> first.` and changes nothing.
- On success the next state is `MiningSave.initial(nowUtc: now, relaunchCount: previous + 1)`: 100 cash, Homeworld only, its two T1 starter rigs, Landing Basin unlocked, technology 0. Cargo on every planet is discarded, not sold. It persists once through the repository and returns `Relaunch <n> — sales ×<multiplier>.`.

The final planet's 30,000,000 mastery reward is unchanged and is paid again in every run, because each run masters the final planet from a fresh state. It is still "once per run".

### 4. Where the player meets it

- **Next goal.** `MiningGoalKind.frontiersMastered` becomes `MiningGoalKind.relaunch`: title `Relaunch`, detail `Start again with sales ×<next multiplier>.`, target the Stellar Map. The old "keep upgrading Extraction and Logistics" step goes away, because a relaunch resets technology anyway.
- **Stellar Map.** Below the planet cards, a Relaunch card appears once the final planet is mastered. It shows the next multiplier and a Relaunch button.
- **Confirmation.** The button opens a sheet in the existing `MiningSheetFrame` that lists what resets (cash, technology, rigs, planets, cargo) and what stays (the relaunch count and the new multiplier), with Cancel and Relaunch. Relaunch is the only destructive action in the game, so it is the only one with a confirmation.
- **After relaunch.** The shell plays the milestone cue after the save succeeds, shows the controller's message in the usual snackbar, and returns to the Homeworld Site Deck.
- **Current bonus.** Once `relaunchCount > 0`, the Stellar Map header shows `RELAUNCH <n> · SALES ×<multiplier>`. Everywhere else the bonus is already visible in the numbers, since every projected and sold value goes through `cargoValue`.

### 5. Pacing

Rates, storage, and prices are unchanged, so a run's cash income scales with the multiplier. The public-action journey measures it: after the existing Ceres mastery and reload, it relaunches and plays the whole run again with the same player and cadence, then compares run 2's Ceres mastery time with run 1's. The numbers go in the PR.

The comparison uses the whole run, not an early milestone, because the journey moves in whole visits: at the two-hour cadence run 1 already unlocks Lunar Frontier on its first visit (HPA-401's cadence log), so an early milestone cannot get any shorter.

The 0.5 step is a starting point. If run 2 is not at least 20% shorter at the two-hour cadence, raise the step; if run 2 skips whole planets' worth of waiting, lower it. No other number changes.

## Touch points

- `lib/mining/mining_state.dart`: `relaunchCount` on `MiningSave` (constructor, `initial`, `copyWith`, `toJson`, `==`, `hashCode`).
- `lib/mining/mining_save_repository.dart`: the eighth root key and its decode.
- `lib/mining/mining_content.dart`: `relaunchSaleBonus`, `saleMultiplier`, `finalPlanetId`, `cargoValue`.
- `lib/mining/mining_controller.dart`: `relaunch()`; `sellAllCargo` uses `cargoValue`.
- `lib/mining/site_deck_view.dart`, `lib/mining/mine_site_view.dart`, `lib/mining/mining_progression_views.dart`: `cargoValue`; `StellarMapView` gains `relaunchCount`, `canRelaunch`, and `nextSaleMultiplier`.
- `lib/mining/next_goal_view.dart`: the `relaunch` kind.
- `lib/mining/presentation/stellar_map_screen.dart`: the Relaunch card and header line; a new `relaunch_sheet.dart` beside the other sheets.
- `lib/mining/presentation/mining_shell.dart`: opens the sheet, calls `relaunch()`, plays the cue, navigates.
- `CLAUDE.md`: the root-key list, the relaunch rule, and the journey description.

No new controller, repository, simulation, save key other than `relaunchCount`, or state owner.

## Testing

- **State and repository:** initial state has `relaunchCount` 0; a save with `relaunchCount` 3 round-trips; a save without the key, with a negative value, or with a non-int clean-resets with the recovered flag.
- **Content:** `saleMultiplier` is 1.0 / 1.5 / 2.0 for 0 / 1 / 2; `finalPlanetId` is Ceres; `cargoValue` matches `amount × saleValuePerUnit × multiplier`.
- **Controller:** `relaunch()` fails before Ceres mastery with no save; on success the state equals `MiningSave.initial` at the clock time with `relaunchCount + 1`, it saves once, and a following sale pays ×1.5.
- **Views:** Site Deck, Mine Site, and Stellar Map projected values include the multiplier; the next goal after Ceres mastery is `relaunch` with the next multiplier; `canRelaunch` is false until the final planet is mastered.
- **Widgets:** the Relaunch card and sheet at 360×640 and 430×932 with no overflow; Cancel changes nothing; confirming calls the controller once, plays `milestone`, and lands on the Homeworld Site Deck.
- **Journey:** after the existing Ceres reload, relaunch and replay the run to Ceres mastery; assert run 2 is at least 20% shorter at the two-hour cadence and shorter at the six-hour cadence, and that a reload keeps `relaunchCount` 1.

## Risks

- **Seven call sites.** Missing one `cargoValue` call makes a projected value disagree with the sale. The view tests compare each projection to the controller's sale for a relaunched state.
- **Accidental relaunch.** The confirmation sheet is the guard; the action is unreachable before final mastery.
- **Long late runs.** Every run still replays Homeworld from 100 cash. The journey's run-2 time tells us whether the early game feels short enough; if not, the fix is the bonus step, not a new system.

## Assets

None. Uses existing art and the existing milestone cue.
