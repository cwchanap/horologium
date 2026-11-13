# HPA-855 — Milestone feedback and small-screen polish: implementation plan

- Status: **Revised after design review #5855384584**; documentation only, implementation not started.
- Linear: https://linear.app/cwchanap/issue/HPA-855/make-milestones-land-mastery-card-rig-tiers-on-the-map-small-screen
- Design: [2026-11-11-hpa-855-milestone-polish-design.md](../specs/2026-11-11-hpa-855-milestone-polish-design.md)
- Baseline: `main` at `92ddcacc56c70c8a298f6fd79b4870c6366bb83b`.
- PR policy: **one HPA-855 PR only**. Get design approval first, then implement/test in subsequent commits on the **same branch**. Do not open a second implementation PR.
- Runtime scope: Flutter presentation plus a **nullable result field** on the existing `MiningActionResult` (reusing mastery already calculated by `deployRig`), corresponding tests and one sentence in `CLAUDE.md`. No new actions/services, save keys, migrations, gameplay/economy changes, assets or SFX.

## 0. Preflight and reusable contracts

Before changing runtime code:

1. Confirm the branch is based on HPA-813/PR #54 and HPA-814/PR #53 already merged in `main`, and reread `CLAUDE.md`. The baseline here is `92ddcac`.
2. Verify `MiningController.deployRig`'s existing `wasMastered/isMastered` and successful save-before-result boundary, `MiningActionResult`, `_runSheetAction`, `StellarMapView.from`, `RelaunchSheet`, `MiningGridMap`, `AnimatedMiningGridVisualLayer`, `MiningSheetFrame`, and their existing tests.
3. Keep existing widget keys/semantic labels and explicit `MiningController` calls. There is no game-state owner or new service to introduce.
4. Record baseline results for the public-action journey, layout tests and widget tests; if local Flutter tooling is unavailable, mark that as **not run** rather than inferring success.

## 1. Mastery transition, card and navigation (first implementation commit)

Files:
- `lib/mining/mining_controller.dart` (`MiningActionResult` metadata and `deployRig` result only)
- `lib/mining/presentation/mining_shell.dart`
- new `lib/mining/presentation/planet_mastered_card.dart`
- `test/mining/presentation/mining_shell_test.dart`
- `test/integration/merge_mining_journey_test.dart` (action-result contract across all five planets and both runs)
- new `test/mining/presentation/planet_mastered_card_test.dart` if focused UI coverage materially simplifies the shell tests

Work:

1. Extend `MiningActionResult.success` with nullable `MiningPlanetId? masteredPlanetId` (same pattern as `dockBayId`); failure constructor sets it to `null`. `MiningController.deployRig` **already** calculates `!wasMastered && isMastered` from the candidate and new commissioned sites. After `await repository.save(next)` and `_state = next`, return `masteredPlanetId: !wasMastered && isMastered ? planetId : null`. No new detection helper, controller action or state. On failed validation/save, no successful result is emitted.
2. In `MiningShell._runSheetAction`'s successful result branch, test `result.masteredPlanetId`. If non-null, show the mastery card instead of `_showResult(message)` (especially Io's existing reward text); otherwise keep existing SnackBars. **Keep** the current `before` commission-diff code solely for milestone SFX and first-commissioning permissions; do not add any shell mastery comparison. Failure flow unchanged.
3. For nonfinal mastery, use `result.masteredPlanetId` to find the authored successor (`unlockRequiredMasteryPlanetId`), then select its `StellarMapPlanetView` from `StellarMapView.from(state: _controller.state, content: _content)`. Pass the already-projected `requirements` to the card; never recalculate or hardcode gate state.
4. Reuse the authored planet image `planetAsset`, `MiningSheetFrame`, `MiningTheme` colors, and scrollable modal geometry. Show **PLANET MASTERED**, the mastered planet, the successor's name and each requirement with satisfied/required marks. Provide stable keys (e.g. `planet-mastery-card`, `planet-mastery-open-map`, `planet-mastery-continue`).
5. Io uses the same widget in a final variant: **FINAL PLANET MASTERED**, `formatMiningCash(_content.planet(finalId).masteryRewardCash)` and `RELAUNCH…`. The card does **not** mutate any state. On Relaunch, pop the mastery card first, then call the existing `_openRelaunchSheet`; Cancel must preserve state, Confirm follows the old `_confirmRelaunch` logic.
6. Open Map pops the card first, then invokes `_handleNavigation(MiningNavigationDestination.stellarMap)`. Continue only pops. Use the current shell's guarded mount/navigation paths; do not leave a hidden card over a new screen.
7. Apply `sheetAnimationStyle: _reducedMotion ? AnimationStyle.noAnimation : null` **inside both** `_showModalSheet` and `_showMiningSceneSheet`; do not introduce a per-caller opt-in argument. This handles card → Relaunch and Technology/Settings transitions consistently.

Tests (seed valid repository saves, inject clocks and action failures using existing shell test helpers):

- Assert `masteredPlanetId` in `test/integration/merge_mining_journey_test.dart` for every deployment in **all five planets × two complete runs**: only the last site reports its planet, all other deployments report `null`. Retain existing reward/message/cash expectations, injected-clock pacing and numeric assertions unchanged. Add a focused controller failure test if the failure-result constructor is not already covered.
- Shell widget tests: **one** representative nonfinal mastery verifies the card's requirement list equals `StellarMapView.from(after).requirements`, including gate status and working Open Map / Continue; **Io** checks the authored reward (not awarded a second time), no duplicate SnackBar, Relaunch → Cancel preserves state, and Confirm uses existing reset behavior. Avoid reconstructing every planet in shell tests; journey coverage handles the complete planet set.
- Verify one normal non-mastering deploy does **not** show a card and a failed persistence operation does not show one. Load/refresh/resume/re-entry cannot surface `masteredPlanetId` because they do not return a successful `deployRig` result; no redundant seven-case shell test matrix.
- Under `MediaQuery.disableAnimations`, verify both sheet helpers suppress their route transitions (including mastery → Relaunch), while buttons and card semantics remain usable.

## 2. Theme every success/failure SnackBar (second implementation commit)

Files:
- `lib/mining/presentation/mining_shell.dart` (`_showResult`'s one `SnackBar` constructor)
- `test/mining/presentation/mining_shell_test.dart` (existing harness)

Work:
- Set `backgroundColor`, `shape` (cyan rounded border), `behavior` and high-contrast Orbitron text **directly at the sole `SnackBar(content: Text(message))` inside `_showResult`**. The app has only one production `SnackBar` call; avoid a root theme accessor or whole-app boot just to test one widget. Do not introduce a new message service.
- Preserve `_showResult`'s removal of previous SnackBar and reduced-motion `snackBarAnimationStyle`. Do not alter Technology failure-sheet routing.
- Assert success/rejection/recovery messages inherit the dark style using the **existing MiningShell-under-MaterialApp harness**, at 360×640/390×844, with no `HorologiumApp`/`MainMenu` navigation test. Existing reduced-motion SnackBar handling remains.

## 3. Rig chips, matching-target cue and HP paint priority (third implementation commit)

Files:
- `lib/mining/presentation/mining_grid_map.dart`
- `lib/mining/presentation/animated_mining_grid_visual_layer.dart`
- `test/mining/presentation/mining_grid_map_test.dart`
- `test/mining/presentation/animated_mining_grid_visual_layer_test.dart`
- `test/mining/presentation/mine_site_screen_test.dart` as needed for end-to-end visual positioning

Work:
- In `MiningGridMap`'s **existing per-rig scene loop**, render exactly **one** `IgnorePointer`/`ExcludeSemantics` chip for every placed rig, along with its single pre-existing actionable rig semantics node. Default chip text: `Tn`. Only if that rig's cell is in `view.upgradeableCells`, render the **same chip** as gold `Tn→Tn+1` (not a separate badge widget). The overlay works for static and animated sites without an extra targeting/read model or gesture handler.
- In `MiningGridPainter`, replace the current gold-filled upgradeable-cell highlight with a **gold outlined ring** for `upgradeableCells`, visibly different from cyan deployable-cell fill. Do not compute upgrade eligibility in the painter; it receives the existing set.
- Anchor the chip to the **top edge** of each rig cell in scene coordinates. A chip in the parent `Stack` paints above HP even after the animated-layer reorder, so add **nonintersection tests** between top-anchored chip and resource HP chrome for rigs directly above mined 1×1 and 3×3 deposits. Illegal, mismatched, unselected and T5 rigs never receive the gold ring or upgrade chip state; all still show their tier.
- Move `_hpChrome` after the robot/rig build loop in `AnimatedMiningGridVisualLayer` so an upper-row robot cannot paint over HP or its label. Preserve per-resource HP, impact latch, and existing damage label behavior; retain one semantics target per rig.
- Tests: exactly one chip per rig and one actionable semantics node; gold ring/`Tn→Tn+1` only for eligible targets; unchanged cyan deploy fill; no new gesture handlers; robot/HP paint order; chip/HP rects disjoint for 1×1 and 3×3 mined resources; existing animation/impact tests green. Since InteractiveViewer scales both rectangles together, **drop duplicate 0.8/1.6 widget layout tests** and inspect zoom-limit readability manually.

## 4. Uniform hex Travel on Stellar Map (fourth implementation commit)

Files:
- `lib/mining/presentation/stellar_map_screen.dart`
- `test/mining/presentation/stellar_map_screen_test.dart`

Work:
- Keep `_PlanetAction` and `MiningHex`, but change the unlocked non-current card's parent from stretch-to-fill `Expanded` to a right-aligned **fixed hex**. Include visible `TRAVEL` text within the hex; keep a readable 48 px or larger tap target. The active-planet hex remains as it is; locked planets retain full-width unlock affordances.
- Preserve `mining-stellar-map-travel-<id>` keys, the `!isActive && !isBusy` guard, semantics and `onTravel(view.id)`.
- Tests: non-current unlocked planets use the same non-stretched hex motif; Travel callback targets correct planet; active disabled, busy disabled, locked-planet unlock still behaves as before; check 360×640 and 390×844.

## 5. Offline return footer and Technology pinned details (fifth implementation commit)

Files:
- `lib/mining/presentation/offline_return_sheet.dart`
- `lib/mining/presentation/mining_sheet_frame.dart`
- `lib/mining/presentation/technology_sheet.dart`
- `test/mining/presentation/offline_return_sheet_test.dart`
- `test/mining/presentation/mining_sheet_frame_test.dart`
- `test/mining/presentation/technology_sheet_test.dart`

Work:
- For the portrait return sheet, replace the scroll-behind-footer `Positioned.fill` + overlaid footer construction with a height-bounded `Column`: `Expanded` scrollable heading and planet reports, then a pinned `Next:` + SELL ALL/continue footer. Keep the background hero/gradient, visible cash chip, original keys and sale semantics. Account for bottom safe-area padding. The list may scroll under the hero graphic but must **never** paint under the action/footer controls.
- In `MiningSheetFrame` add only one optional `pinnedFooter` field; existing no-footer callers follow the **unchanged current layout**. For the footer variant, constrain the panel height and arrange header, `Expanded` scrollable body, and fixed padded footer. This avoids an `Expanded` in an unbounded `SingleChildScrollView`.
- `TechnologySheet` passes `_tree(landscape)` as the sole scrolling body and `_compactDetails(selected)` as the footer. The selected track's details and Upgrade button remain visible while scrolling level nodes, with existing callback and live `TechnologySheetView` updates unchanged. Preserve the horizontal tree in landscape.
- Tests at 360×640 (critical) and 390×844: the footer and report content have nonoverlapping render rectangles; all five planet reports remain scrollable; Sell All/Continue callback unchanged. Technology purchase button is in the viewport **before any scroll**, remains visible after scrolling the tree, updates cost/level following a purchase, and stays reachable on track switch; include 874×402 landscape. Load the actual Orbitron font where line fitting matters, and assert zero overflow exceptions.

## 6. Compact selected fleet hint and guidance (sixth implementation commit)

Files:
- `lib/mining/fleet_dock_view.dart` (`dockHint` text only; **keep** `fleet_dock.dart`'s `maxLines: 3`)
- `test/mining/fleet_dock_view_test.dart`
- `test/mining/presentation/mine_site_screen_test.dart`
- `CLAUDE.md`

Work:
- Replace selected T1–T4 `dockHint` with `DEPLOY · UPGRADE · MERGE`, dropping CELL/RIG/BAY because new gold upgrade rings and cyan empty-cell highlights visually identify the target. Keep `FleetDock`'s `maxLines: 3` fallback for Chrome's wider fallback font; retain T5 deploy-only and no-selection hints. No tutorial or manual typography skip.
- Check native Orbitron at 360×640 for the desired **single-line appearance**, but assert **no ellipsis, truncation or overflow** as the cross-platform correctness contract (including `flutter test --platform chrome`); wrapping up to three lines is acceptable on Chrome. Verify selected T1–T4 semantics still cover deploy/upgrade/merge and T5 does not offer impossible upgrades.
- Add **one line** under shell ownership in `CLAUDE.md`: "Planet mastery feedback is a transient shell card driven by `MiningActionResult.masteredPlanetId`; it is not persisted." No broader architecture rewrite.

## 7. Final regression, review and delivery on the same PR

- Run focused tests first: mastery card/shell, grid map and animated layer, Technology, offline return, Stellar Map, fleet hints and the unchanged public-action journey.
- Run and record all repository gates from `CLAUDE.md`:
  1. `dart format --output=none --set-exit-if-changed .`
  2. `flutter analyze --fatal-infos`
  3. `flutter test`
  4. `flutter test --coverage`
  5. `flutter test --platform chrome`
  6. `flutter build apk --debug`
  7. `flutter build web`
  8. `flutter build ios --simulator --debug`
- Perform manual visual acceptance at 360×640, 390×844 and 430×932, plus 874×402 landscape where applicable, using the ticket's three mockups. Check a top-row animated site, both map zoom endpoints, all five mastery transitions, a five-planet offline-return list, and selected Technology tracks.
- Re-run `test/integration/merge_mining_journey_test.dart` on its injected clock. Completion reward, relaunch multiplier, save structure and numeric progression must be unchanged; do not relax tests, introduce persistence, or alter prices in this PR.
- Update this **same draft PR** with implementation commits and a verification summary, address review findings there, and mark it ready only after review. Do not create new tickets unless new artwork/audio is explicitly needed (in which case that creative work must be **separate**).

## Acceptance checklist for review

- [ ] The public-action journey reports `masteredPlanetId` only for the **last deploy on each of the five planets across both runs**, with numerical pacing and rewards unchanged. A representative nonfinal shell card displays live next-planet gates and working Open Map/Continue.
- [ ] Io shows the existing reward and Relaunch route; no duplicate award/message; Cancel does not reset; another run can show mastery again.
- [ ] No mastery card on load, refresh, resume, failed action or already-mastered state; reduced motion suppresses card and message transitions.
- [ ] Every shell message is dark themed directly at the single `SnackBar` constructor (success and failure); both sheet helpers and SnackBars honor reduced motion.
- [ ] Every placed rig has **one** top-anchored chip; eligible selected rigs show a gold ring and gold `Tn→Tn+1` in **that same chip**; 1×1/3×3 HP geometry never intersects the chip and HP paints after robots.
- [ ] Every non-current unlocked Stellar Map planet has a compact labeled hex Travel action.
- [ ] At 360×640: return-sheet `Next:` never overlaps reports, Technology Buy is pinned and visible, HP readable; selected hint prefers one line with native Orbitron and never truncates/ellipsizes on Chrome (preserve `maxLines: 3`).
- [ ] Existing art/audio reused; only nullable controller result metadata added (no save, simulation, reward or economy changes); public-action journey unchanged, repository gates recorded.