# HPA-813 — Fewer taps: implementation plan

- Status: **Revised planning only; design review changes applied**
- Linear: https://linear.app/cwchanap/issue/HPA-813/fewer-taps-sell-all-planets-upgrade-placed-rigs-one-tap-build
- Design: [2026-11-09-hpa-813-fewer-taps-design.md](../specs/2026-11-09-hpa-813-fewer-taps-design.md)
- Review: [GitHub review 2026-11-09](https://github.com/cwchanap/horologium/pull/54#pullrequestreview-5836416402)
- Baseline: `main` at `ec95c80769f3ce23bedb1c03d9285b7e4e2fcef9`, after HPA-814/PR #53
- Delivery: **ONE PR for this ticket**. Review these docs first; controller, journey, UI, `CLAUDE.md` and tests all land on the **same branch/PR**. Controller/journey changes each get a separate **commit within this PR**, not a new ticket or PR.
- No art/SFX generation: reuse all existing assets, audio and haptics.

## Reuse survey (no speculative architecture)

| Need | Existing owner | Minimal change |
| --- | --- | --- |
| Sale and cash | `MiningController.sellAllCargo`, `MiningSave.saleValue`, `MiningSimulation.accrue` | Loop unlocked planets, sum planet-floored totals, save once |
| Cargo projections | `MiningSave.saleValue(content, planet)` | Add matching `storedCargo(content, planet)`; derive pure global totals from per-planet projections |
| Tier pricing | `MiningContentRegistry`/`planet.rigSpawnCost` | One `rigCost(planetId, tier)` method; formula is `spawnCost * (1 << tier.index)` |
| Merge legality | `mergeDockRigs` + `FleetDockBayView.canMergeWithSelection` | One pure tier check beside `RigTier` shared with placed upgrades/highlights |
| Purchased rigs | `MiningController.spawnRig`, `MiningActionResult.dockBayId` | Extend `spawnRig({RigTier tier = RigTier.t1})`; **no** `buildBestAffordableRig` method |
| Placed rigs | `MineSiteView.gridTapOutcome`, `MiningGridPainter`, `MiningShell._runSheetAction` | One new controller action and one upgrade tap outcome; second painter cell set |
| Returning player UI | `OfflineReturnSheet`, `MiningShell._sellCargo`, `RelaunchSheet` | Dismiss first, call existing shell sale, busy message; **no** new pending/async result machinery |
| Progression evidence | `JourneyPlayer` and injected clock | Update immediately with each domain change; remove obsolete T4 cap and measure two cadences **before UI** |

Do not add a second state owner, save changes, new dependencies, generic builders/services, altered site geometry, gameplay timers, rebalanced costs, extra dock bays, art or SFX.

## Step 0 — Baseline and policy gate

**Before making runtime changes:**

1. Confirm clean branch, current `main`/merged HPA-814; examine `mining_controller.dart` (`spawnRig`, `mergeDockRigs`, `recallRig`, `sellAllCargo`), `mine_site_view.dart` (`gridTapOutcome`), `fleet_dock_view.dart`, `mining_shell.dart`, `MiningSave`, `mining_grid_map.dart` and return-sheet behavior.
2. Run `flutter test test/integration/merge_mining_journey_test.dart` on baseline with **2-hour and 6-hour** injected-clock cadences. Record first-run Mars/Ceres/Io milestone hours, Ceres→Io phase ratio, second-run/relaunch times and test band boundaries. HPA-262 PR #45 historically logged **86.0h** (2h visits) and **252.1h** (6h visits) for first-run Io mastery, **not** measurements from this docs-only review.
3. Preserve test expectations for storage cap (24h), relaunch bonus, five-minute return-sheet gate, strict-save validation and the current busy feedback behavior. Search old “active planet only” and “travel to sell” assertions rather than deleting useful tests wholesale.
4. **Commit and pacing gate:** after each Steps 1–3, commit that controller change **with its journey edit**; run the journey and record the resulting timing difference before UI is started. If T5 crosses an existing minimum band, stop before Step 4 and seek explicit owner disposition: accept faster pacing with new evidence-based bands, or revise the feature. Do not silently move bands, hide T5, or reprice.

## Step 1 — Sell all unlocked planets and update the journey visit

**Domain files:**
- `lib/mining/mining_state.dart`, `lib/mining/mining_controller.dart`
- `test/mining/mining_state_test.dart`, `test/mining/mining_controller_test.dart`
- `test/integration/merge_mining_journey_test.dart`

**Tests first:**

- A valid multi-unlocked-planet state has cargo on two or more planets (including inactive-only cargo); one sale returns summed resources, empties every unlocked site, credits **Σ separately floored `saleValue(content, planetId)`**, preserves the active planet, and persists exactly one save. Verify the relaunch multiplier and reload.
- A tiny positive cargo amount that floors to 0 cash is still a valid sale and clears cargo. No positive cargo means “No cargo to sell.” and **no write**. Simulated save failure does not publish a partially cleared state; queued actions respect existing serialized writes.
- Do **not** seed locked-planet cargo: the save repository rejects non-pristine locked sites. Restricted-to-unlocked iteration stays a code contract, not an impossible persisted fixture.

**Implementation:**

1. Add a pure `MiningSave.storedCargo(content, planet)` symmetric to existing `saleValue(content, planet)` and pure `storedCargoAcrossUnlockedPlanets(content)` / `saleValueAcrossUnlockedPlanets(content)` that sum per-planet results only across `unlockedPlanetIds`. Reuse per-planet `storedCargo` in current read models where that replaces hand-written totals; no new persisted keys.
2. Keep `MiningController.sellAllCargo`, accrue once, compute global revenue on accrued state **before** zeroing, walk all unlocked planet sites and add to existing `MiningSaleResult.sold`, copy/save/publish once. No extra sale entrypoint.
3. Change `JourneyPlayer.visit()` to advance/refresh, consult the new global cargo projection and call `sellAllCargo` once. Remove the tour through unlocked planets **solely to sell**, and keep active planet unchanged. Assert no extra sale per visit using an explicit count.
4. Run focused controller/state tests plus journey **at both cadences now**, record before/after deltas, and commit as one Step-1 commit on this PR.

**Tests:** `flutter test test/mining/mining_state_test.dart test/mining/mining_controller_test.dart` and `flutter test test/integration/merge_mining_journey_test.dart`.

## Step 2 — Upgrade a placed rig and update the journey upgrade path

**Files:**
- `lib/mining/mining_content.dart` (tier rule beside `RigTier`)
- `lib/mining/mining_controller.dart`
- `test/mining/mining_controller_test.dart`
- `test/integration/merge_mining_journey_test.dart`

**Tests first:**

- Existing placed T2 and dock T2 on active planet, with nonzero cargo: `upgradePlacedRig` yields T3 **in the same cell**, consumes the dock bay, keeps cargo and cash, and persists with a single save/reload.
- Mismatch → “Rigs must be the same tier.”, T5+T5 → “T5 rigs cannot merge.”; wrong planet, missing rig/cell, absent source, and failed persistence leave authoritative state unchanged. Do not let recall rules/cargo limits leak into placed upgrades.
- `rigMergeFailure(source, target)` covers all same/mismatched tier pairs and T5 and keeps exact legacy messages; `mergeDockRigs` consumes this helper after its existing bay/null checks.

**Implementation:**

1. Add a small pure helper beside `RigTier` returning `null` when a merge is permitted, else the existing error string. Use it in existing dock-to-dock merge and later in dock hints and placed-rig targeting.
2. Add `MiningController.upgradePlacedRig(DockBayId bay, MiningSiteId site, MiningGridCell cell)` with queued accrue → validate → replace tier/copy sites & docks → persist once → publish. Never call `recallRig` or recalculate/decrease cargo.
3. Change the journey's full-site investment: buy a matching tier, then call `upgradePlacedRig` directly (remove recall/merge/redeploy). **Do not yet lift the T4 cap**; isolate this step's effect from Step 3 and run both cadences. Existing `_build(tier)` can remain recursive until Step 3 so each commit is bisectable.
4. Run controller tests and both journeys, record results, and commit Step 2 on the same PR.

## Step 3 — Explicit-tier spawn and the honest T5 journey

**Files:**
- `lib/mining/mining_content.dart` (one `rigCost` method)
- `lib/mining/mining_controller.dart` (reuse `spawnRig`)
- `test/mining/mining_controller_test.dart`
- `test/integration/merge_mining_journey_test.dart`

**Tests first:**

- Default `spawnRig()` still buys T1 at the existing planet's spawn cost. `spawnRig(tier: RigTier.t5)` buys T5 for **16×** in the first free bay with **one** save; other tiers use the correct 2^index prices. Other existing bays stay untouched. Try a full dock, below-cost cash, each planet cost, and a queued/stale view choice: an explicitly requested T3 must **never** become T4 because income arrives while queued.
- Verify the existing `MiningActionResult.dockBayId` points to the bay filled by **any** successful tier spawn. Preserve default T1 spawn and manual dock merges.

**Implementation:**

1. Add `MiningContentRegistry.rigCost(MiningPlanetId id, RigTier tier)` so controller, `FleetDockView` and journey share exactly one formula (`rigSpawnCost × 2^tier.index`). No pricing registry, cached budget state or extra tier enum.
2. Change signature to `spawnRig({RigTier tier = RigTier.t1})`; use cost helper, debit once, place specified tier in the existing empty bay; return bay ID. Reject insufficient cash rather than picking a different tier.
3. Replace journey `_build(RigTier tier)` recursion with **one** `controller.spawnRig(tier: tier)` call. Investment cost uses `content.rigCost(planet, placement.tier)`. **Remove the artificial `RigTier.t4` upper bound** on upgrading the lowest placed rig; allow upgrading T4 to T5, stopping only at T5 (as the product now allows).
4. **Pacing gate before ANY UI:** run both 120- and 360-minute journeys through first Io mastery, save/reload, relaunch and complete faster second run. Capture before/after milestones and phase ratios. If Io misses the **minimum** (not just maximum) band due to T5, do not reinsert an artificial cap, silently relax the minimum, or change prices. Document the observed acceleration and request explicit owner acceptance of a revised band or feature adjustment. Only continue to Step 4 after this is resolved.
5. Commit Step 3 and journey together on the **same PR**, independent of steps 1/2 for review.

## Step 4 — Global sell affordances and simple Fleet Returned action

**Files:**
- `lib/mining/site_deck_view.dart`, `lib/mining/mine_site_view.dart`, `lib/mining/next_goal_view.dart`
- `lib/mining/presentation/site_deck_screen.dart`, `lib/mining/presentation/mine_site_screen.dart`
- `lib/mining/presentation/offline_return_sheet.dart`, `lib/mining/presentation/mining_shell.dart`
- `test/mining/site_deck_view_test.dart`, `test/mining/mine_site_view_test.dart`
- `test/mining/presentation/site_deck_screen_test.dart`, `test/mining/presentation/mine_site_screen_test.dart`, `test/mining/presentation/offline_return_sheet_test.dart`, `test/mining/presentation/mining_shell_test.dart`

**Tests first:**

- Cargo only on an inactive **unlocked** planet enables Site Deck and Mine Site Sell; button/semantics report all-unlocked-planet revenue, while active-planet HUD, gauges and card values stay local. `MiningNextGoalView` sees the global sale sum.
- Switch `MiningSaleAffordance` eligibility from `projectedValue > 0` to `cargo > 0`. Remove dead `hasUnsellableCargo` field, label and `MineSiteView` accessor plus obsolete tests. Assert 0-value cargo can be sold and 0-cargo cannot.
- Return sheet's primary button displays `SELL ALL · +X`, immediately dismisses the modal, calls the *existing* `_sellCargo` once, then reports real credit or failure on the visible Scaffold. The ▶ continues without a mutation. Busy state is reported explicitly rather than silently swallowed. Keep HPA-814's ≥5-minute gate and per-planet report intact.

**Implementation:**

1. Give Site Deck and Mine Site a separate all-unlocked-planets cargo/sale projection for the **Sell action only**. Keep `SiteDeckView.projectedValue` and Mine Site cargo gauge local. Update sell labels and `MiningNextGoalView` input, with no second sale method.
2. Match the existing `RelaunchSheet` callback pattern: in `OfflineReturnSheet`, `Navigator.pop` **then** invoke an `onSellCargo` shell callback (which calls `_sellCargo`); the callback checks `_controller.isBusy` and reports “Finishing previous action…” explicitly. Existing shell sale action handles persistence, haptics, sounds, success/failure SnackBars on the uncovered Scaffold. Do **not** add awaitable sale result handling, widget pending flags, inline-error state, or a second notifier.
3. Use the existing `_displayState` snapshot for X. Its preview can be fractionally stale due to accruing seconds; the controller's persisted result and SnackBar own the real cash delta. A fake-clock, no-intervening-accrual test must see X equal the sale amount. Remove non-active-planet “travel to sell” copy.
4. Run focused view and presentation tests, then commit this UI step on the **same PR**.

## Step 5 — Grid upgrade targets and BUILD pill

**Files:**
- `lib/mining/mine_site_view.dart`, `lib/mining/fleet_dock_view.dart`
- `lib/mining/presentation/mining_grid_map.dart`, `lib/mining/presentation/fleet_dock.dart`
- `lib/mining/presentation/mine_site_screen.dart`, `lib/mining/presentation/mining_shell.dart`
- `test/mining/mine_site_view_test.dart`, `test/mining/fleet_dock_view_test.dart`
- `test/mining/presentation/mining_grid_map_test.dart`, `test/mining/presentation/mine_site_screen_test.dart`, `test/mining/presentation/mining_shell_test.dart`

**Upgrade UI:**

- Add `MineSiteGridTapAction.upgrade`. A tapped **occupied** cell with a dock selection routes to the shared merge-rule check, **never recall**; without selection it still uses `recallRig`. Empty-cell taps still deploy. Test same-tier success, mismatch, T5, busy, cargo and normal recall.
- Derive `canUpgradeWithSelection` and matching occupied targets from `MineSiteView` using the shared `rigMergeFailure`. Feed targets as a second set into the existing `MiningGridPainter`; update physical hit and screen-reader semantic labels/actions. Shell invokes `upgradePlacedRig` via `_runSheetAction` and clears the consumed selected bay. No additional overlay/UI state owner.

**Build UI:**

- `FleetDockView.from` derives `bestAffordableTier` in T2–T5 using `content.rigCost` and `state.cash`, plus the shown cost/`canBuild`. Hide when no free bay or only T1 can be bought; disable while busy. Share the merge helper with dock-to-dock selection highlights.
- Render a compact `BUILD Tn · price` in `FleetDock`'s existing header and keep four bays and T1 Spawn visible. Pass the **displayed** tier through a new `onBuildRig(RigTier)` callback across portrait/landscape `MineSiteScreen` to shell, where `spawnRig(tier: tier)` is invoked by the same `_runSheetAction` path and result selection as T1 Spawn. Do not let controller recompute “best” after tap.
- Test 360×640, 390×844, 430×932 and 874×402 UI reachability and no overflows; check busy state, wrong tier, selected bay and accessible target labels. Reuse merge effect/sounds.

Run focused view/grid/dock/shell tests and commit within the same PR.

## Step 6 — Guidance, full validation and PR readiness

**Files:** `CLAUDE.md`, amended tests impacted by intentional contract changes and PR description.

- Replace `CLAUDE.md`'s active-planet-only selling rule with all-unlocked-planets one-write sale; note `MiningSave.storedCargo` and the per-planet-floor total, `MiningContentRegistry.rigCost`, `spawnRig(tier)` and `upgradePlacedRig`. Preserve strict unversioned save contract, controller ownership and HPA-814 5-minute rule.
- Re-run the **full public-action journey** after UI wiring and confirm Step 3's timing and two-run consistency; document 2h and 6h before/after Io mastery, phase ratios, relaunch/run-2 results and any explicitly approved changes to bands.
- Verify all acceptance checks and run repository gates on the final implementation commit:

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

Report exact tested SHA/results and any unavailable host-specific gates. Do not claim CI, Flutter tests or builds passed when only docs were edited.

## Acceptance checklist

- [ ] One sell empties all unlocked planets, pays Σ planet-level floored values, writes once; active HUDs remain local.
- [ ] Site Deck, Mine Site and return-sheet SELL ALL controls display global total; cargo>0 eligibility includes 0-cash sale.
- [ ] Return sheet primary pops then sells with visible feedback, ▶ only continues, busy case is explicit, five-minute gate remains.
- [ ] A selected matching dock tier upgrades a placed rig in the same cell with cargo unchanged; mismatches/T5 never recall.
- [ ] `spawnRig()` still buys T1; `spawnRig(tier: Tn)` buys exact displayed tier for `content.rigCost`, with one write and one free bay.
- [ ] Shared price/merge helpers have single sources of truth; no dead `hasUnsellableCargo` or impossible locked-planet test.
- [ ] Journey lifts T4 cap, models T5, sells once per visit, tests both cadences and records before/after numbers **before UI**.
- [ ] Any missed minimum pacing band has **explicit** approval and documented decision before UI work; do not secretly adjust economy/test bounds.
- [ ] Presentation, semantics, injected-clock tests, full `CLAUDE.md` build gates pass on the implementation commit.
- [ ] All work stays on draft PR #54; no new assets, SFX, state owners, save keys or ticket split.

## Reviewer concerns resolved by this design

1. **T4 cap:** lifted in Step 3 so the public-action journey uses T5; pacing measured and an under-minimum outcome requires explicit product disposition.
2. **Duplicate controller method:** use existing `spawnRig({tier})`, with best-affordable selection only in `FleetDockView`; prevents surprising higher-tier purchase on stale screen.
3. **Formula/rule drift:** one `rigCost` and one shared merge validity helper.
4. **Modal complexity:** close first, then call `_sellCargo`; no local async state or new error framework.
5. **Late risk detection:** commit/test controller+journal changes first, run 2h/6h before UI.
6. **Dead/impossible cases:** remove `hasUnsellableCargo`, avoid invalid locked-planet cargo fixture, add per-planet `storedCargo` projection.

**This remains a planning-only PR update. No Flutter tests/builds were run for the review revisions.**
