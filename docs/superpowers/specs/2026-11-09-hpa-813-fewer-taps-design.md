# HPA-813 — Fewer taps: design specification

- Status: **Revised for design review** (planning only; no runtime implementation yet)
- Linear: https://linear.app/cwchanap/issue/HPA-813/fewer-taps-sell-all-planets-upgrade-placed-rigs-one-tap-build
- Implementation plan: [2026-11-09-hpa-813-fewer-taps.md](../plans/2026-11-09-hpa-813-fewer-taps.md)
- Baseline: `main` at `ec95c80769f3ce23bedb1c03d9285b7e4e2fcef9`, after HPA-814/PR #53 was merged
- Delivery: **one draft PR for HPA-813**. Review these documents first, then implement and test on this same PR. No separate implementation PR.
- Review update: incorporated the [2026-11-09 GitHub design review](https://github.com/cwchanap/horologium/pull/54#pullrequestreview-5836416402).

## Player outcome and product tradeoff

A return visit needs **one sale rather than one sale per planet**. A selected dock rig can upgrade a matching placed rig in its current cell. One tap buys the best affordable T2–T5 rig without constructing intermediate merge trees. These are shorter routes through the existing economy, not idle automation.

The 2026-11-07 fresh-save UAT observed ~10 travel/sell taps by Io, mistaken recall attempts with a selected dock rig, and 16 T1 spawns plus 15 manual merges to form T5. The ticket includes mockups and full acceptance criteria.

**Pacing decision: remove the obsolete T4 journey cap.** With explicit-tier builds and upgrade-in-place, T4→T5 is achievable with one free bay and has higher rate/capacity (T4: 3.25×/3.0×, T5: 4.5×/4.0×). The public-action journey must model this, not conceal T5 with an artificial cap. Selling shortcuts alone should leave the income curve unchanged, but usable T5 rigs **can accelerate** Ceres/Io progression.

Measure baseline 2-hour and 6-hour cadence journeys first; re-run after **each** controller/journey step, **before any presentation work**. If newly accessible T5 rigs push Io below the existing minimum journey band, treat that as a product-pacing decision requiring explicit review: propose evidence-based updated bands with before/after logs if the faster run is desirable, or revise the feature if it is not. Do not silently relax tests, reprice content, or assert “pacing unchanged” just because the old journey was capped. The owner must accept the measured tradeoff before implementation proceeds into UI if a band is missed.

## Reuse and ownership

- Keep `MiningController` the sole mutation boundary (`_enqueueMutation` → `MiningSimulation.accrue` → validate → copy → one `MiningSaveRepository.save` → publish). Failed validation never persists or publishes partial state.
- Keep `MiningContentRegistry` the owner of authored prices and rig multipliers. Add a tiny `rigCost(MiningPlanetId planet, RigTier tier)` returning `planet.rigSpawnCost * (1 << tier.index)`, instead of repeating the cost formula in controller, dock read model and journey.
- Keep merge rules beside `RigTier` (e.g. `String? rigMergeFailure(RigTier source, RigTier target)` returns the existing tier-mismatch/T5 failure message, or `null` for legal). Reuse it from `mergeDockRigs`, `upgradePlacedRig`, `FleetDockBayView.canMergeWithSelection`, and `MineSiteView` upgrade targeting. Empty bay/cell, wrong planet and busy checks remain local to the actions.
- Reuse `MiningSave.saleValue(content, planet)` and add the matching pure `MiningSave.storedCargo(content, planet)` projection. Aggregate only unlocked planets with `saleValueAcrossUnlockedPlanets(content)` and `storedCargoAcrossUnlockedPlanets(content)`. These are *read-only* getters/methods; they add no save keys or new owner. Reuse `storedCargo` where other read models already manually sum per-planet cargo when practical.
- Reuse `MineSiteView.gridTapOutcome`, `FleetDockView.from`, `MiningGridPainter`, `MiningShell` callbacks and audio, and HPA-814's five-minute return-sheet gate. No changes to `MiningSimulation`, persistence schema, placement legality, site/planet prices, rig stats, resource art, or navigation architecture.

## 1. Sell all unlocked planets atomically

**Current:** `MiningController.sellAllCargo` accrues every planet but clears only active-planet sites and pays `state.saleValue(content, activePlanetId)`. Site Deck and Mine Site sale buttons therefore show only active-planet value.

**New:**

1. Keep **only** `MiningController.sellAllCargo()`; do not create a parallel sale method. Accrue once; iterate authored planet IDs restricted to `candidate.state.unlockedPlanetIds`. Calculate revenue *before clearing cargo* as the **sum of each unlocked planet's separately floored** `candidate.state.saleValue(content, planetId)`. This matches the previous payoff from traveling to each planet and selling separately, including relaunch multiplier.
2. For all unlocked sites with positive stored cargo, add resource quantities to the existing `MiningSaleResult.sold` and reset stored amounts in a copied sites map. One mutation saves **once** and credits the exact pre-clear revenue. Active planet and all other state stay unchanged. “No cargo to sell.” still fails without a write when *no* unlocked site has any cargo.
3. Eligibility is **any cargo > 0**, even if the floored cash value is 0: it is valid to clear tiny cargo for 0 cash. Remove dead `MiningSaleAffordance.hasUnsellableCargo`, the “Keep mining until cargo is worth at least 1 cash” branch, the matching `MineSiteView` accessor, and obsolete tests. Do not set up a save containing cargo on a locked planet: `MiningSaveRepository` deliberately rejects that invalid state; test unlocked-only cases instead.
4. `SiteDeckView` keeps `projectedValue`, site card values, cargo/capacity and HUD **active-planet only**; its Sell chip and semantics gain a distinct all-unlocked-planets projection. `MineSiteView` keeps its active-planet gauge and site resource stats, while its Sell control shows the **same global action total**. `MiningNextGoalView.sellableValue` receives the global amount, so “Sell cargo to afford it” remains truthful. Both sell controls invoke the existing shell action.
5. Preserve the sale value rounding contract: per-planet floor then sum, not one global floor. Text labels should say “sell all planets” where needed so a local cargo gauge does not imply a local sale. A zero-cash sale still shows `+0` and remains enabled while cargo exists.

## 2. Upgrade a placed rig, never accidentally recall

- Add **one** controller action `upgradePlacedRig(DockBayId sourceBay, MiningSiteId siteId, MiningGridCell cell)`. Validate that the site is on the active planet, the source dock bay has a tier, the cell has a placed rig, and `rigMergeFailure(sourceTier, placedTier) == null`. Replace only the placed tier with its next tier **in the same cell**, empty the selected dock bay, retain site cargo/commissioned status and cash, save once. Existing storage can only have more capacity after upgrading.
- Add `MineSiteGridTapAction.upgrade`. **Selected dock rig + occupied cell** always routes to upgrade or an error; never route to recall. Same tier below T5 upgrades; mismatch says “Rigs must be the same tier.”; T5+T5 says “T5 rigs cannot merge.” **No selection** preserves the original recall checks, including cargo capacity and available dock space. Empty-cell deploy stays as it is.
- Derive `canUpgradeWithSelection`/matching occupied target cells from existing state and the shared merge helper. Feed this as a **second cell set** into `MiningGridPainter` beside `deployableCells`, not an additional overlay framework. Update rig semantic labels and `onTap` routing to match upgrade-vs-recall behavior for assistive technologies.
- Shell handles upgrade through `_runSheetAction`, existing merge audio/haptic, and `_preserveDockSelection` to clear the consumed bay. Do not touch `mining_grid.dart` or change the 50×50 grid geometry.

## 3. One-tap build through the existing spawn action

**Do not add `buildBestAffordableRig()`.** Extend the current controller method to:

```dart
Future<MiningActionResult> spawnRig({RigTier tier = RigTier.t1})
```

- The controller receives an **explicit tier**. It finds the first empty bay as before, checks `content.rigCost(activePlanetId, tier)`, debits that exact cost, places that tier, and saves once. `T1` callers keep the same behavior and signature compatibility; direct T5 costs 16 T1 spawns without requiring more than one empty bay. No recursive `spawnRig`/`mergeDockRigs` calls and no price/stat changes.
- `FleetDockView.from` derives the **best affordable** tier in T2–T5 and price from `state.cash` and `content.rigCost`, but **does not delegate the choice to the controller**. Its compact fleet-header `BUILD Tn · price` button supplies the *displayed* tier to `MiningShell` and onward to `spawnRig(tier: displayedTier)`. If funds change while the tap is in flight, the controller either buys **that exact tier for its displayed cost** or fails “Not enough cash.”; it never silently upgrades the tier due to a queued sale/reward.
- Keep the T1 Spawn hex and existing dock-to-dock merges. The existing shell `_spawnRig` result handling and selected-bay update are reused (or minimally parameterized); `MiningActionResult.dockBayId` continues to describe **any successful `spawnRig`**.
- Hide the BUILD action when the dock is full or only T1 is affordable, and disable it while busy. Fit it in the existing portrait/landscape fleet header without covering the cavern. Reuse existing rig images and merge sound/haptics. The hint distinguishes “empty highlighted cell to deploy” from “matching placed rig to upgrade.”

## 4. Fleet Returned SELL ALL: close first, then call existing sale

- Keep the existing ≥5-minute actual-absence guard and per-planet production/full-site summaries from HPA-814. The primary action becomes `SELL ALL · +X`, where X is the **all-planet sale preview from the existing accrued display snapshot**, not just newly produced offline cargo. The secondary ▶ hex still dismisses with **no sale**.
- Match `RelaunchSheet`: the primary button `Navigator.pop`s its modal **first**, then calls the shell's existing `_sellCargo`. The uncovered Scaffold shows the existing success/failure SnackBar and sale sound/haptic. If the controller is busy at that point, the sheet callback must **explicitly report** “Finishing previous action…” rather than silently returning. Once tapped, the popped modal cannot trigger a second sale. Do **not** add an async-result handler, local pending state, inline modal errors, or another sale mutation method.
- Keep the primary label's X as an accrued-snapshot **preview**; authoritative revenue is calculated at the actual controller mutation and may differ slightly because time advances. A deterministic injected-clock test with no intervening accrual must see X equal the credited cash. The existing SnackBar reports actual revenue after save. No new live-notifier builder is required.
- Update stale “travel to sell” full-site hints to “sell to resume” even when the full planet is not active. Keep other HPA-814 return-sheet behavior unchanged.

## Verification and review gate

- **Sale:** ≥2 unlocked planets with cargo (including inactive-only cargo), per-planet floors, relaunch multiplier, 0-cash tiny cargo, no cargo, one-save success, persistence failure, resource totals, and persisted reload. Keep active HUD local while all sale controls show global cash/canSell.
- **Upgrade:** matching placed/dock tiers with existing cargo, cell preserved and bay consumed after reload, mismatches/T5/empty targets/other planet failures, selected-versus-unselected taps, semantic actions and second-set highlights.
- **Spawn/build:** per-planet tier costs at all thresholds, full dock, not enough cash, one write, specified tier honored under stale read-model/queued income, default T1 Spawn unchanged, dock selection after save, four-bay constraint, portrait/landscape hit targets.
- **Return sheet:** two choices, busy rejection visible, primary close-before-sale, actual success/failure feedback visible, 5-minute gate, per-planet breakdown, snapshot revenue preview versus actual accrued revenue.
- **Journey:** each visit makes one `sellAllCargo` call and avoids sales-only travel; upgrade path uses `upgradePlacedRig`, `_build(tier)` directly calls `spawnRig(tier: tier)`, **remove the artificial T4 cap**, and prove T5 is reachable. Compare both 2h and 6h first- and second-run timings with baseline. Measure before UI; if minimum bands are crossed, obtain explicit approval for updated bands or adjust the feature, **never silently weaken tests or reprice**.
- On implementation commits, run the full `CLAUDE.md` format/analyze, native/Chrome tests and coverage, Android, web and iOS simulator builds. Document genuine results and any unsupported local platform check.

## Explicit non-goals

No autosell, auto-merge, increased dock bays, idle automation, new tutorial, new art/SFX, price or stat changes, save format/migration, additional state owner, new UI feedback framework, or new PR. HPA-827 remains a separate golden-test ticket. This design-only revision does not claim that Flutter tests or builds passed.
