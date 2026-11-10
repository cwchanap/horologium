# HPA-813 — Fewer taps: design specification

- Status: **Proposed for review** (planning-only; runtime changes have not begun)
- Linear: https://linear.app/cwchanap/issue/HPA-813/fewer-taps-sell-all-planets-upgrade-placed-rigs-one-tap-build
- Implementation plan: [2026-11-09-hpa-813-fewer-taps.md](../plans/2026-11-09-hpa-813-fewer-taps.md)
- Baseline: `main` at `ec95c80769f3ce23bedb1c03d9285b7e4e2fcef9`, after HPA-814/PR #53 was merged
- Delivery: **one draft PR for HPA-813**. Review the plan first, then implement and test on this same branch. No separate implementation PR.

## Player outcome

A return visit needs **one sale, not one sale per planet**. A selected dock rig can upgrade an equally tiered placed rig in its current cell. One tap buys the best affordable T2–T5 rig without constructing an intermediate merge tree. These are shorter paths through the **same** economy, not passive automation.

The 2026-11-07 fresh-save UAT observed ~10 travel/sell taps per Io return, mistaken recall attempts when dragging a dock rig onto a placed rig, and 16 spawns + 15 manual merges to form T5. Existing mockups and full acceptance criteria live on HPA-813. HPA-827 (three skipped Linux goldens) is separate and nonblocking.

## Reuse and architecture boundary

- **Reuse** `MiningController._enqueueMutation`, `MiningSimulation.accrue`, `MiningSaveRepository.save`, `MiningSave.saleValue`, `MiningContentRegistry`, `MiningActionResult` and `MiningSaleResult`. Every new action accrues at the injected UTC time, validates, makes a copied state, saves **once**, then publishes it; failed validations never write.
- **Reuse** `SiteDeckView` / `MiningSaleAffordance`, `MineSiteView.gridTapOutcome`, `FleetDockView`, `MiningGridPainter`, and `MiningShell`'s existing action, feedback, audio, and selected-dock behavior. Widgets read state, but never mutate saves.
- **Reuse** the HPA-814 return-sheet gate (at least five minutes of actual absence), per-planet sale report, and `_displayNotifier`. Do not regress its safe Mine Site camera or changed Technology sheet behavior.
- Do not modify `MiningSimulation` economy formulas, `MiningSaveRepository` decode contract, placement legality, planet unlocks, rig stats, or save JSON shape. No new state owner, currencies, generic event bus, new dependencies, art, or SFX.

## 1. Sell all unlocked planets — one atomic controller action

**Existing behavior:** `MiningController.sellAllCargo()` accrues every planet but clears only `content.planet(activePlanetId).sites` and credits `state.saleValue(content, activePlanetId)`. The Site Deck and Mine Site sale controls also project only active-planet value, and `JourneyPlayer.visit()` travels across every unlocked planet solely to sell.

**New behavior:**

1. Keep the public method name `sellAllCargo` (no parallel sale mutation). After a single accrual, iterate authored `MiningPlanetId.values` **restricted to `candidate.state.unlockedPlanetIds`**. Aggregate `sold` by `ResourceType` and clear cargo on the corresponding authored sites. No cargo elsewhere is touched.
2. Determine revenue **before clearing** as the **sum of `candidate.state.saleValue(content, planetId)` for each unlocked planet**. Each planet is floored once, matching the cash previously earned from visiting and selling every planet; do not floor only once after adding raw values across planets. The existing relaunch multiplier stays in `saleValue`.
3. If no unlocked site holds positive cargo, return the existing “No cargo to sell.” failure, without persistence. Otherwise copy cash/sites, persist exactly once, publish after save, and return actual revenue and resource totals. A positive but sub-cash-unit haul can legitimately sell for 0; the ticket explicitly enables sale when **any** unlocked planet has cargo.
4. Put two small **pure projections** on `MiningSave` (or equivalently reuse a single shared read-only helper): `saleValueAcrossUnlockedPlanets(content)` and `storedCargoAcrossUnlockedPlanets(content)`. All three selling surfaces and the controller use the same projection; do not create another mutable store or a generic economy service.

**Presentation:**

- Site Deck `SELL` chip and semantics show the **all-unlocked-planets** total and enable when global stored cargo is positive and the controller is idle. Keep `SiteDeckView.projectedValue`, its HUD cargo gauge, and the three site cards **active-planet only**; introduce an explicit global sale projection for the sale action. `MiningNextGoalView` receives the global sellable value so “Sell cargo to afford it” reflects the action's actual yield.
- The Mine Site sell control uses the **same global sale total and eligibility**, because it invokes that same controller method. Its cavern/site and active-planet cargo gauge remain local; label the sell action clearly as all planets to avoid displaying one value and crediting another.
- In `OfflineReturnSheet`, the **primary** action becomes `SELL ALL · +X`; the secondary play/hex button stays “Continue mining” without selling. X is the live, all-planet projected revenue (including previously stored cargo, even on planets without new offline production). The per-planet report remains per-planet. Update the “travel to sell” warning/copy to “sell to resume,” without changing which sites are full or the ≥5-minute rule.
- Route the sheet action through the **same shell sale handler** that backs Site Deck/Mine Site; return a success/failure result to the sheet. On success dismiss the sheet **after** persistence; prevent a second tap while saving. On failure keep a visible inline error in the sheet (a shell SnackBar sits behind the opaque modal). No second sale path. Reuse `_displayNotifier` for a fresh displayed X rather than freezing the opening snapshot.

## 2. Merge a dock rig into a placed rig

**Current trap:** `MineSiteView.gridTapOutcome` prefers `recall` for any occupied cell, so selecting a dock rig and tapping an existing rig can trigger the cargo-capacity recall rejection.

- Add **one** enqueued controller mutation, e.g. `upgradePlacedRig(DockBayId sourceBay, MiningSiteId siteId, MiningGridCell cell)`. Check active planet, commissioned/unlocked target site, occupied cell, nonempty source bay, same tier, and tier below T5; use existing “Rigs must be the same tier.” and “T5 rigs cannot merge.” messages. The placed rig is replaced **in place** by `RigTier.values[tier.index + 1]`, the selected dock bay becomes empty, site cargo/commissioned flag/cell stay unchanged, and cash is not charged again. Increased rig capacity cannot invalidate stored cargo.
- Add `MineSiteGridTapAction.upgrade`. With a dock selection, an occupied rig **always** takes the upgrade-or-reject branch: same tier < T5 upgrades; mismatch reports the same-tier error; T5+T5 reports the tier cap. It **never** falls through to recall. With no dock selection, existing recall rules and cargo-capacity rejection remain intact. Empty-cell placement behavior remains unchanged.
- Derive upgrade targets from `MineSiteView`'s existing selected dock tier and rig list; do not mutate placement geometry or add saved selection state. Highlight same-tier placed rig cells (below T5) using the existing grid overlay/painter rather than a new overlay subsystem. Update semantic labels/actions so assistive technology can discover upgrades and meaningful blocked reasons.
- Shell routes `upgrade` through `_runSheetAction`, reuses the merge sound and haptic, and clears the now-empty selected bay through existing `_preserveDockSelection`. A saved/reloaded rig remains in its original cell.

## 3. One-tap best-affordable build

- Add **one** enqueued controller action, e.g. `buildBestAffordableRig()`. On the active planet, find the first empty dock bay and the highest tier in **T2..T5** affordable using `planet.rigSpawnCost * (1 << tier.index)`. The index corresponds to T1=0, T2=1, ..., T5=4. A T5 rig therefore costs exactly 16 T1 spawns.
- Do **not** call `spawnRig`/`mergeDockRigs` recursively, make intermediate bays, or save more than once. Debit cash once, place the resulting tier directly in that bay, return its `dockBayId` and a useful success message using existing `MiningActionResult`. Reject full docks and budgets below T2 without writing. Existing T1 spawn and manual bay-to-bay merge remain available.
- Derive `bestAffordableTier`, `buildCost` and `canBuild` in `FleetDockView.from`. Render a compact `BUILD Tn · price` action in the fleet header only with a free bay and an affordable T2+. Disable it during a pending mutation. Wire one `onBuildRig` callback through portrait/landscape `MineSiteScreen` and `FleetDock` into `MiningShell`. On success select the newly filled bay, as for spawning. Reuse existing rig/merge visual and audio assets.
- Keep the fixed four-bay dock and its current size/layout. At 360×640/390×844/430×932 and 874×402, the build action and existing hint, spawn and bays must remain visible, legible, and tappable; use a compact landscape treatment rather than adding a taller dock that covers the cavern. The hint must explicitly distinguish “tap an empty highlighted cell to deploy” from “tap a matching placed rig to upgrade.”

## Verification contract

- **Sale:** two or more unlocked planets with cargo, inactive-planet-only cargo, per-planet rounding, relaunch multiplier, 0-cash tiny cargo, no cargo, successful one-write persistence/reload, rejected write/queued mutation, and resource totals. Active HUDs remain local while every sale control shows the global amount.
- **Upgrade:** matching tiers with nonzero cargo, unchanged placement/cargo and increased tier/capacity after reload; mismatched tiers, T5, empty bay/cell, other planet, and no-dock-selection recall; physical and semantic cell taps and highlights.
- **Build:** correct highest tier and cost for each affordability boundary, T5/16× price, bay choice, full dock, less than T2 budget, repeated taps/serialization, selected bay after save, and portrait/landscape layout.
- **Return sheet:** both choices, success versus failure, busy protection, true cash delta, previously stored other-planet cargo, per-planet report, ≥5-minute visibility, and no hidden feedback.
- **Journey:** exactly one `sellAllCargo` attempt per visit, no sales-only travel, public-action use of upgrade-in-place and best-affordable build, same milestone timing bands at 2h/6h cadences and full two-run/reload/relaunch coverage. Log before/after measured hours; a changed economy or missed band blocks merge.
- Run the entire `CLAUDE.md` gate suite after implementation, including Flutter format/analyze, native/Chrome tests and coverage, Android debug APK, web build, and iOS simulator debug build.

## Explicit non-goals and tradeoffs

No autosell, auto-merge, idle assistant, bay expansion, prices/stats changes, new tutorial, artwork or SFX. The extra pure read projection and one UI-only in-flight flag are not additional authoritative state owners. The docs-only draft does **not** claim a Flutter test/build pass. HPA-814's merged implementation is the baseline; HPA-827's Linux golden restoration remains a separate task.
