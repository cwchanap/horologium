# HPA-401 Time-Away Pacing Implementation Plan

- Date: 2026-10-16
- Linear: [HPA-401](https://linear.app/cwchanap/issue/HPA-401/mining-pacing-make-time-away-pay-with-hour-long-storage)
- Design: `docs/superpowers/specs/2026-10-16-hpa-401-time-away-pacing-design.md`

## Delivery rule

One ticket = one PR. Planning lands first on this draft PR; implementation lands on the same PR after plan review. Do not open a second implementation PR.

Tasks 1 and 2 change no economy number and must be green on their own. Task 3 is the only task that changes authored numbers, and Task 5 is the evidence that accepts them. If the owner picks a different pacing target, only the numbers in Task 3 and the expected values in Tasks 3–5 change.

## Task 1: One compact cash formatter everywhere

### Production

- `lib/mining/mining_content.dart`: `formatMiningCash(int)` keeps thousands separators below 1,000,000; at and above it returns two decimals with `M`, and at and above 1,000,000,000 two decimals with `B`. Truncate rather than round (`999,999,999` → `999.99M`), so a displayed amount never exceeds what the player has.
- Replace raw interpolation with `formatMiningCash` in:
  - `lib/mining/presentation/mining_hud.dart` (cash chip at `:122`, and `:171`; drop the chip's private thousands logic);
  - `lib/mining/presentation/mining_shell.dart:454` (`Sold … cash.`);
  - `lib/mining/presentation/fleet_dock.dart:176` and `lib/mining/fleet_dock_view.dart:82, :124`;
  - `lib/mining/presentation/technology_sheet.dart:378-379` and `lib/mining/mining_progression_views.dart:387`;
  - `lib/mining/presentation/site_deck_screen.dart:565, :665, :1100` and `lib/mining/site_deck_view.dart:125, :276`;
  - `lib/mining/presentation/stellar_map_screen.dart:768`.
- `next_goal_view.dart` and `mining_controller.dart` already call it.

### Tests

- `test/mining/mining_content_test.dart`: formatter table from the design's Testing section, plus `999,999,999`.
- Update view and widget expectations that compare raw numbers. Under today's prices every displayed amount is below 1,000,000, so text changes only where the old code omitted separators (for example `Need 2500 cash.` → `Need 2,500 cash.`).

```sh
flutter test test/mining/mining_content_test.dart test/mining/site_deck_view_test.dart \
  test/mining/fleet_dock_view_test.dart test/mining/mining_progression_views_test.dart \
  test/mining/presentation
```

## Task 2: Time to full and honest away copy

### Production

- `lib/mining/mining_content.dart`: add `String formatMiningDuration(Duration)` (`<1m`, `14m`, `1h 52m`, `24h 00m`), rounding minutes up for durations that are not whole minutes. It replaces `OfflineReturnSheet._formatDuration`; keep that sheet's existing output for whole minutes.
- `lib/mining/site_deck_view.dart`: add `Duration? timeToFull` to `MiningSiteCardView`, computed in `SiteDeckView.from` as `(capacity − cargo) / rate` seconds for an operational card with `rate > 0` and `cargo < capacity`, else `null`.
- `lib/mining/presentation/site_deck_screen.dart` (card status around `:910-921`): an operational, not-full card shows `rate/s · cargo / cap\nFULL IN ${formatMiningDuration(timeToFull).toUpperCase()}`. Full cards keep `FULL … / SELL TO RESUME`. Add the same text to the card's semantics label.
- `lib/mining/presentation/offline_return_sheet.dart`: headline `Away\n{elapsed}`; cap note `Capped at {elapsedUsed}.` with the Logistics suffix and the `logisticsLevel` constructor parameter removed (update the shell call site).

### Tests

- `test/mining/site_deck_view_test.dart`: `timeToFull` is `null` for locked, available, idle, full, and zero-rate cards, and exact for a partially filled operational card.
- `test/mining/presentation/site_deck_screen_test.dart`: the `FULL IN` line appears and the card does not overflow at 360×640 and text scale 1.3.
- `test/mining/presentation/offline_return_sheet_test.dart`: `Away` headline; the cap note without a Logistics level.
- Formatter tests for `formatMiningDuration`.

Commit Tasks 1 and 2 before any number changes.

## Task 3: Authored numbers and the fixed safety cap

### Production

- `lib/mining/mining_content.dart`:
  - each site's `baseCapacity` becomes `baseRatePerSecond × 7200` (table in design section 1);
  - `technologyCosts` becomes `[300, 700, 1500, 300000, 750000]`;
  - Lunar Frontier: unlock 200,000, rig spawn 40,000, Titanium Highlands 250,000, Helium Mare 650,000;
  - Mars Frontier: unlock 16,000,000, rig spawn 4,000,000, Silica Dunes 10,000,000, Cobalt Chasm 25,000,000, mastery reward 20,000,000;
  - replace `offlineCapsByLogistics` and `offlineCapFor(int)` with `static const offlineAccrualCap = Duration(hours: 24)`.
- `lib/mining/mining_simulation.dart:50`: read `MiningContentRegistry.offlineAccrualCap`.
- `lib/mining/mining_progression_views.dart:131-133`: Logistics effect copy becomes `Storage ×{multiplier} · fills in {window}`, where `window = 2h × logisticsMultiplier(level) ÷ extractionMultiplier(current Extraction)`, formatted with `formatMiningDuration`. The view already receives the save, so it reads the current Extraction level from it.
- Confirm that every `int` cash path stays below 2^53 on web (largest authored amount is 25,000,000; a 24-hour Mars haul stays far below).

### Tests

- `test/mining/mining_content_test.dart`: replace price and capacity expectations with the design tables; add the invariant `baseCapacity == baseRatePerSecond * 7200` for all nine sites; assert `offlineAccrualCap`.
- `test/mining/mining_simulation_test.dart`: a T1 Landing Basin fills to 3,600 after exactly 2 h and stops; at Logistics 5 it fills to 7,200 after 4 h; a 30-hour gap accrues 24 h and reports `wasOfflineCapped`. Remove per-Logistics cap cases.
- `test/mining/mining_progression_views_test.dart`: Logistics copy at Extraction 0 / Logistics 1 (`fills in 2h 18m`) and at Extraction 5.
- `test/mining/next_goal_view_test.dart`, controller and shell tests: replace expected costs and the `+25,000` reward copy with the new values.

## Task 4: Re-baseline the public-action journey

- `test/integration/merge_mining_journey_test.dart`:
  - `earnUntil` advances by a parameter `step` (default `Duration(hours: 2)`), and its failure text names the step instead of "five-minute accruals";
  - the route spawns and merges the extra rigs each phase needs through public controller actions (spawn, deploy, merge), stays within the four-rig cap, and buys Logistics before the long phases, so each phase finishes within its iteration bound;
  - Mars mastery expects `+20,000,000` in the goal detail and the `Mars mastered — +20,000,000 cash.` message, and the cash delta is 20,000,000;
  - the `CADENCE` lines remain, now reporting hours.
- Keep the next-goal checkpoints and the reload step unchanged in structure.

```sh
flutter test test/integration/merge_mining_journey_test.dart
```

Record the emitted `CADENCE` totals in the PR. If the journey's total accrued time to Mars mastery falls outside 30–60 hours of storage windows for the route, return to Task 3's numbers before continuing.

## Task 5: Playtest and docs

- Run a fresh-to-Mars playtest on a debug build with a controllable clock where available, otherwise in real time across visits a few hours apart. Record visits, elapsed time, purchases per visit, and any copy or overflow problems in `docs/playtests/2026-10-hpa-401-time-away-pacing.md`.
- `CLAUDE.md`, Economy and progression:
  - storage holds two hours of base production per site; Logistics extends it, Extraction shortens it;
  - offline accrual is capped at a fixed 24 hours as a clock safety net and Logistics no longer changes it;
  - Mars mastery grants exactly one 20,000,000 cash reward;
  - all player-visible cash uses `formatMiningCash`.
- Mark the design `- Status: Implemented`.

## Gates

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

The Flutter SDK is not installed in the planning container; install it before implementation.
