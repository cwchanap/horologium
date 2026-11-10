# HPA-813 — Fewer taps: implementation plan

- Status: **Planning only; ready for design review**
- Linear: https://linear.app/cwchanap/issue/HPA-813/fewer-taps-sell-all-planets-upgrade-placed-rigs-one-tap-build
- Design: [2026-11-09-hpa-813-fewer-taps-design.md](../specs/2026-11-09-hpa-813-fewer-taps-design.md)
- Starting point: `main` at `ec95c80769f3ce23bedb1c03d9285b7e4e2fcef9` (HPA-814/PR #53 merged)
- Delivery rule: **ONE PR for this ONE Linear ticket**. First review these two documents; implementation, tests, CLAUDE.md update, and measured journey results land on the same branch/PR. Do not spin out additional PRs or create new tickets.
- No new art or SFX required: reuse existing rig images, merge sound/haptics, and iconography.

## Reuse survey and decisions to preserve

| Need | Existing owner / reuse | Minimal change |
| --- | --- | --- |
| All-planet production and cash | `MiningSimulation.accrue`; `MiningSave.saleValue(content, planet)`; `MiningController.sellAllCargo` | One pass over unlocked authored planets, sum **per-planet floored** values, save once |
| Shared sale read model | `MiningSaleAffordance`, `SiteDeckView`, `MineSiteView`, `MiningNextGoalView` | Two pure all-unlocked-planet projections on `MiningSave`; keep active-planet HUD projections |
| Away report and callbacks | `MiningShell._showOfflineReturn`, `_displayNotifier`, `_sellCargo`; `OfflineReturnSheet` | Live total + shared async sale handler; modal closes on success |
| Rig mutation | `_enqueueMutation`, `spawnRig`, `mergeDockRigs`, `deployRig` and `recallRig` | One placed-upgrade action and one direct best-tier build action |
| Grid semantics/target feedback | `MineSiteView.gridTapOutcome`, `MiningGridPainter`, `MiningGridMap` | One new tap outcome and selected-rig target highlighting |
| Dock UI | `FleetDockView.from`, `FleetDock`, `MineSiteScreen`, `MiningShell._runSheetAction` | One derived BUILD affordance and callback in both orientations |
| Pacing proof | `JourneyPlayer.visit()`, `_build()`, `_investments()` | One sale/visit, upgrade-in-place, use new build at least once, preserve two-run bands |

Do **not** add domain services, another state owner, platform-specific persistence, abstractions for arbitrary tiers/planets, new animations, or a generic command bus. Save/repository schema remains strict and unversioned.

## Step 0 — Establish baseline (before implementation)

1. Confirm `git status` is clean on the implementation branch and `main` includes HPA-814. Focused behavior review: `lib/mining/mining_controller.dart` lines around `spawnRig`/`mergeDockRigs`/`recallRig`/`sellAllCargo`; `lib/mining/mine_site_view.dart` `gridTapOutcome`; `lib/mining/fleet_dock_view.dart`; `lib/mining/presentation/mining_shell.dart`.
2. Run the fresh-save public-action journey at **120- and 360-minute visit cadences** on the baseline and capture first-run Io mastery plus complete second-run relaunch timing. Historic HPA-262 PR #45 reported **86.0h (2h visits)** and **252.1h (6h visits)** for run 1; these are **historical reference numbers, not tests executed for this draft**.
3. Check which assumptions in tests say “active planet only,” “travel to sell,” or “dock-only merge”; expect deliberate assertion updates, not weakened coverage. Leave HPA-814's five-minute return-sheet test contract unchanged.

## Step 1 — Atomic all-planet sale (tests then domain code)

**Files:**
- `test/mining/mining_state_test.dart`
- `test/mining/mining_controller_test.dart`
- `lib/mining/mining_state.dart`
- `lib/mining/mining_controller.dart`

**Test first:**
- Seed two or more unlocked planets with cargo and an inactive planet containing more than the active; one `sellAllCargo` empties all unlocked cargo, preserves active planet ID, returns aggregated resource quantities and exactly the sum of **each planet's floored `saleValue`**, including relaunch multiplier.
- Keep a distinct non-unlocked planet with no sale participation; empty cargo returns failure with no save; partial tiny cargo with 0 floored value still succeeds per the ticket and clears it.
- Use `CountingMiningSaveRepository` to show **one persisted save** on success, none on validation failure, and a reload showing empty cargo; retain existing serialized-mutation/storage-failure coverage.

**Implement:**
- Add read-only `MiningSave.saleValueAcrossUnlockedPlanets(content)` and `storedCargoAcrossUnlockedPlanets(content)` using authored planets and the save's unlocked set. These do not change `toJson`/decoder.
- Extend the **existing** `sellAllCargo` loop across the unlocked planet sites, evaluate revenue from the original accrued state, zero stored cargo in one copied `sites` map, save once. Keep `MiningSaleResult` and existing feedback contract.
- Focused gate: `flutter test test/mining/mining_state_test.dart test/mining/mining_controller_test.dart`.

## Step 2 — Consistent global sale affordance and return sheet

**Files:**
- `lib/mining/site_deck_view.dart`, `lib/mining/mine_site_view.dart`, `lib/mining/next_goal_view.dart`
- `lib/mining/presentation/site_deck_screen.dart`, `lib/mining/presentation/mine_site_screen.dart`
- `lib/mining/presentation/offline_return_sheet.dart`, `lib/mining/presentation/mining_shell.dart`
- Matching `test/mining/*_view_test.dart` and `test/mining/presentation/{site_deck_screen,mine_site_screen,offline_return_sheet,mining_shell}_test.dart`.

**Test first:**
- With cargo only on a different unlocked planet, Site Deck and Mine Site sell controls enable and show its actual cash value; unchanged Site Deck HUD, Mine Site gauge, site cards, and per-planet report still describe the **active/individual planet**.
- Change `MiningSaleAffordance` from `projectedValue > 0` eligibility to `cargo > 0` (unless busy). Ensure labels say “all unlocked planets,” including an exact 0-cash tiny sale. Keep the active HUD read models separate from the global action totals; do **not** overwrite `SiteDeckView.projectedValue`.
- `MiningNextGoalView` receives the global sale total so the “Sell cargo to afford it” decision matches a real sale.
- Offline return's primary button shows `SELL ALL · +X`, sells once and dismisses **after success**. The play hex still dismisses with zero mutations. A failure is visible within the sheet, and double taps while awaiting save cannot submit twice. The 5-minute cold/resume gate, existing full-site summary and per-planet display remain intact.

**Implement:**
- Give Site Deck and Mine Site explicit global sale-value/cargo fields read from the two shared save projections; use these **only** for sell affordances. Change `site_deck_screen.dart` sell chip and `mine_site_screen.dart` sell button visible text/semantics, not their gauges.
- Refactor shell sale orchestration into **one awaitable handler** with existing busy gating, display refresh, selected-bay preservation, success/failure sound and haptic; the current chip callbacks remain void wrappers. For the modal, return the result without showing a SnackBar hidden behind the sheet. Supply `OfflineReturnSheet` a shared async callback; a tiny widget-local pending flag and inline failure text are sufficient.
- Build the return-sheet state through existing `_displayNotifier` to avoid a permanently stale opening-value label; actual revenue remains authoritative after controller accrual. Update the full-site warning that currently says “travel to sell” when a planet is not active.
- Focused gate: `flutter test test/mining/site_deck_view_test.dart test/mining/mine_site_view_test.dart`, then the four presentation test files above.

**Review guard:** the modal state is transient presentation, not a new economy owner. Verify sale feedback is visible and no navigation is popped by a delayed completion from a different action.

## Step 3 — Upgrade a placed rig without recalling it

**Files:**
- `lib/mining/mining_controller.dart`, `lib/mining/mine_site_view.dart`
- `lib/mining/presentation/mining_shell.dart`, `lib/mining/presentation/mining_grid_map.dart`
- `test/mining/mining_controller_test.dart`, `test/mining/mine_site_view_test.dart`
- `test/mining/presentation/mining_grid_map_test.dart`, `test/mining/presentation/mine_site_screen_test.dart`, `test/mining/presentation/mining_shell_test.dart`

**Test first:**
- With a T2 dock rig selected and a placed T2 rig on the active site holding cargo, tapping its cell returns `upgrade` (never `recall`); after one save, that **same cell** holds T3, the bay is empty, cargo and commissioned state persist, and capacity is greater or equal after reload.
- Selected dock T1 + placed T2 reports “Rigs must be the same tier.” and **does not** invoke recall; T5+T5 reports “T5 rigs cannot merge.” The old no-selection recall and cargo capacity errors still work. Wrong planet, empty dock source, missing placement, busy action, and rejected save do not partially publish.
- Grid highlight and rig semantics distinguish same-tier upgrade targets from plain recall/deploy, including with full cargo.

**Implement:**
- Add `MiningController.upgradePlacedRig(sourceBay, siteId, cell)` using the existing queued accrue → copy → save pattern; only replace a tier and empty source bay. Do not call `recallRig` or touch placement legality.
- Extend `MineSiteGridTapAction` by `upgrade`; choose upgrade-or-block for occupied cells **before** recall if a dock rig is selected, then route through shell `_runSheetAction` with existing merge sound. Clear the selection by `_preserveDockSelection` after the bay empties.
- Derive same-tier target cells in `MineSiteView` and paint them with the existing `MiningGridPainter`. Semantic action/label must not continue advertising “recall” when a matching dock rig is selected.
- Focused gate: controller, MineSite view, grid map and Mine Site screen/shell tests.

## Step 4 — One-tap best-affordable build (no intermediate merges)

**Files:**
- `lib/mining/mining_controller.dart`, `lib/mining/fleet_dock_view.dart`
- `lib/mining/presentation/fleet_dock.dart`, `lib/mining/presentation/mine_site_screen.dart`, `lib/mining/presentation/mining_shell.dart`
- `test/mining/mining_controller_test.dart`, `test/mining/fleet_dock_view_test.dart`
- `test/mining/presentation/mine_site_screen_test.dart`, `test/mining/presentation/mining_shell_test.dart`

**Test first:**
- At each threshold (below T2, exactly T2, T3, T4, T5, above T5), the read model shows the correct highest tier/price or hides BUILD. Exercise every planet's authored spawn cost, a full dock, pending mutation, and successful save/reload.
- Building T5 consumes **16 × active-planet spawn cost** in one action and one write, fills one free dock bay with a T5 rig even though 16 step-by-step spawns could not fit into four bays. Existing dock rigs stay untouched. Failure never debits cash.
- UI at **360×640, 390×844, 430×932 and 874×402** keeps the Build pill, four bays, existing Spawn hex and accessible hint reachable, with no overflow; tapping builds and selects the new bay.

**Implement:**
- In `MiningController.buildBestAffordableRig()` find the first empty bay; choose highest affordable tier in `RigTier.values.reversed` with index ≥1 and cost `rigSpawnCost * (1 << tier.index)`, then save the direct dock replacement and debit once. Return a normal `MiningActionResult` with bay ID and built tier message. Never call `spawnRig`/`mergeDockRigs` internally.
- `FleetDockView.from` projects Build tier/cost/eligibility, and `fleet_dock.dart` renders a compact header action. Keep original Spawn and manual merge actions. Use the current horizontal dock height and a compact vertical layout rather than expanding the Mine Site overlay.
- Wire `onBuildRig` through both `MineSiteScreen` orientations to the shell; call `_runSheetAction`, select returned bay, reuse `GameSound.merge` and existing feedback.
- Focused gate: controller, dock view and Mine Site/shell widget tests.

## Step 5 — Journey, repo guidance, and release checks

**Files:**
- `test/integration/merge_mining_journey_test.dart` and any assertions genuinely impacted by the contract change
- `CLAUDE.md` (only after implementation is reviewed)

**Journey adjustments:**
1. In `JourneyPlayer.visit()` advance the injected clock, refresh, compute global sale eligibility and call `sellAllCargo()` **once**, without round-tripping planets. Keep the current active planet unchanged. Record the number of sale calls/visits.
2. In `_investments()`, keep traveling to a site **to build/deploy**; for in-place upgrade buy/prepare the matching dock rig, then call `upgradePlacedRig` (remove recall/merge/redeploy on that path). Keep `_build(RigTier)` when a specific lower tier is necessary; use `buildBestAffordableRig` when its highest affordable tier matches the actual intended investment. Demonstrate each new action at least once on the journey's public-controller path; assert the usage instead of assuming it happened.
3. Re-run both 2-hour and 6-hour cadences through Io mastery, persistence/reload, relaunch and full second run. Capture **before/after first-run Io mastery hours and second-run ratios** in the PR description. Preserve existing milestone bands and the required Ceres→Io phase ratio; do not reprice content to compensate for implementation bugs.
4. Edit `CLAUDE.md` to replace “selling empties only the active planet's cargo” with the unlocked-planets contract, clarify Mine Site sell actions and add `upgradePlacedRig` / `buildBestAffordableRig` to the controller action list. Preserve strict save and ownership rules.

**Full repository gates (on implementation commit, not this documentation-only draft):**

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

The PR must report actual commands/results, tested commit SHA, both before/after pacing logs, and any host-unavailable platform checks clearly. Do not mark tests or builds as passed based on source review alone.

## Acceptance checklist for the single PR

- [ ] Global sell: each unlocked planet emptied, each planet's floored price credited, exactly one write, failed/no-cargo path unchanged
- [ ] Site Deck and Mine Site sale actions display/pay the **same global** amount; active HUD and per-planet breakdown unchanged
- [ ] Return sheet: primary SELLS then closes; hex only continues; failures visible; five-minute gate retained
- [ ] Selected dock + placed same-tier rig upgrades the same cell without cargo loss; mismatch never recalls
- [ ] Best affordable tier builds directly for 2^index × spawn cost; T5 possible with one free bay; four-bay limit unchanged
- [ ] Portrait and landscape UI/semantics tests, injected-clock/journey/relaunch tests, and `CLAUDE.md` gates green
- [ ] One implementation PR (this draft), no new assets, sound files, save schema, services, or extra tickets

## Review focus and risks

1. **Sale contract:** global action amount is the **sum of planet-level floors**, not the floor of a global floating total. Active-only gauges remain active-only even though Sell is global.
2. **Modal lifecycle:** avoid hidden behind-modal SnackBars and double sells; closing a sheet happens only after successful persistence.
3. **Tap precedence:** occupied grid cell with dock selection is upgrade-or-message, never recall; ensure accessible semantic taps follow the same path.
4. **Dock space:** BUILD is not recursive merging, does not require 4+ empty bays, and must remain tappable in a narrow landscape rail.
5. **Journey economics:** the shortcut removes interaction friction, not elapsed-time production or costs. A measured timing regression is a blocking bug, not permission to tune prices.

This PR is a docs-only proposal until implementation is committed to the **same PR** after review. No Flutter commands were run as part of writing these planning documents.
