# HPA-855 — Milestone feedback and small-screen polish: design specification

- Status: **Revised for design review** (review #5855384584 addressed; planning only; runtime implementation has not begun).
- Linear: https://linear.app/cwchanap/issue/HPA-855/make-milestones-land-mastery-card-rig-tiers-on-the-map-small-screen
- Plan: [2026-11-11-hpa-855-milestone-polish.md](../plans/2026-11-11-hpa-855-milestone-polish.md)
- Source: 2026-11-07 fresh-save UAT and 2026-11-11 retest of HPA-813/HPA-814.
- Baseline: `main` at `92ddcacc56c70c8a298f6fd79b4870c6366bb83b` (HPA-813 and HPA-814 merged).
- Delivery: **one PR for HPA-855**. The controller exposes one existing, already-computed mastery fact in its action result; design/plan are reviewed first, then implementation and regression tests are added to this same branch.

## Player outcome

The **third and last commissioned site** on a planet is the mastery milestone. Commissioning a planet's last site produces an unmistakable, one-time **PLANET MASTERED** card with planet art and accurate next-planet requirements. Io's equivalent **FINAL PLANET MASTERED** card shows the already-awarded cash reward and offers Relaunch without resetting anything until the existing confirmation is accepted. Daily surfaces also communicate rig tier and upgrade targets at a glance, and the UI remains readable at 360×640.

This task is **presentation polish plus one action-result field**: add `MiningActionResult.masteredPlanetId`, set by `deployRig` using its existing mastery transition calculation **only after successful persistence**. No new game state, save keys, simulation/economy rules, prices, rewards, rig or unlock logic, assets or SFX. The public-action journey's numerical progression remains authoritative.

## Reuse survey and ownership

- `MiningController.deployRig` already computes `wasMastered`, `isMastered`, and the Io completion reward before saving (`mining_controller.dart`). Return that already-known transition as `MiningActionResult.masteredPlanetId` on a successful persisted deploy. `MiningShell._runSheetAction` uses the result instead of duplicating the mastery calculation; keep the existing commissioned-site comparison **only** for milestone SFX and permission prompts.
- `MiningContentRegistry.isPlanetMastered(planetId, commissionedSiteIds)` remains the single mastery rule inside `deployRig`. `StellarMapView.from(state, content)` projects visible planets and their `StellarMapRequirementView` labels plus `isSatisfied`. **Use this exact read model** for next-planet gates; never duplicate Surveying/cash/mastery checks or hardcode gate strings.
- `MiningShell._openRelaunchSheet` opens the existing `RelaunchSheet`, which is the only place the player confirms resetting the run. `MiningContentRegistry.planet(id).masteryRewardCash` is the authored Io reward; display it without recomputing or awarding it.
- `MiningGridMap` already has a shared scene `Stack` for static and animated sites, a `MiningGridPainter` fed `deployableCells` and `upgradeableCells`, and one semantic node per placed rig. Reuse `MineSiteRigView.placement.tier` and `canUpgradeWithSelection`; no additional targeting or hit-testing model.
- `AnimatedMiningGridVisualLayer` already owns HP labels as transient presentation, separate from deterministic production.
- `MiningSheetFrame` is the existing portrait/landscape sheet shell. Extend it minimally for **one opt-in pinned-footer layout** rather than introducing a second sheet framework.
- `MiningShell._showResult` creates the **only** game `SnackBar` in `lib/`; style it directly with `MiningTheme` colors and Orbitron rather than adding root-theme plumbing solely for one message. The shell already suppresses SnackBar animation for reduced motion.

## 1. Mastery card: transient and post-persistence

1. Add nullable `MiningPlanetId? masteredPlanetId` to `MiningActionResult.success` (parallel to `dockBayId`), with `null` on failures and on other actions. In `MiningController.deployRig` return `masteredPlanetId: !wasMastered && isMastered ? planetId : null` **after `repository.save(next)` succeeds and `_state` is published**. Do not recalculate mastery in the shell: `_runSheetAction` checks `result.masteredPlanetId` only after awaiting the successful action. A failed persistence operation cannot report mastery.
2. If `result.masteredPlanetId == null`, retain existing success SnackBars and audio. Otherwise, **replace that action's generic success SnackBar with the card**, including Io's existing `Io mastered — +90.00M cash.` result message. The shell retains its existing commissioned-site comparison for a **single** milestone SFX and permission request, with no second cue from opening/closing the card.
3. Build a lightweight `PlanetMasteredCard` presentation widget using existing `MiningSheetFrame`/modal primitives, the mastered planet's existing `planetAsset`, and the game colors/fonts. It receives the mastered planet, next planet's **post-action** `StellarMapRequirementView` list, or the final reward, plus close/navigation callbacks. The UI must scroll inside available safe-area height and keep buttons reachable at 360×640; no unbounded card overflow.
4. For the four nonfinal planets, determine the immediate successor from the authored definition whose `unlockRequiredMasteryPlanetId` equals the just-mastered planet (the current content has a linear five-planet route). Read the successor's `requirements` from the already-existing `StellarMapView.from(after, content)` and show each label plus met/unmet indicator. Requirements must match the Stellar Map at the same committed state, even if Surveying/cash is still missing. Do not imply that mastery alone unlocks travel.
5. `Open Stellar Map` dismisses the card before invoking the existing `_handleNavigation(stellarMap)` path. `Continue` only dismisses it. Avoid leaving a modal covering the destination or accidentally reopening the card on the next one-second refresh.
6. For `content.finalPlanetId` (Io), show `FINAL PLANET MASTERED`, the already-awarded `masteryRewardCash` in `formatMiningCash`, and `RELAUNCH…`. Dismiss the card **before** invoking `_openRelaunchSheet`; Cancel leaves all state unchanged. Card creation/dismissal never calls `_controller.relaunch`. A new successfully committed completion after an actual Relaunch produces a fresh `masteredPlanetId` result and card.
7. Card state is **route lifetime only**; no `seen` flag, persisted achievement or event bus. `initialize`, `refresh`, `resume`, offline production and save decode do not return successful deployment results and therefore cannot emit the card. Re-entering a mastered planet or reloading an already-mastered save cannot replay it.

For reduced motion, use the shell's existing `MediaQuery.disableAnimations` value to set `sheetAnimationStyle: _reducedMotion ? AnimationStyle.noAnimation : null` inside **both** `_showModalSheet` and `_showMiningSceneSheet`. This covers the mastery card, the follow-on Relaunch sheet, and Technology/Settings consistently, without an opt-in per-caller parameter or new animation controllers.

## 2. Themed game messages

- Style the sole `SnackBar(content: Text(message))` in `MiningShell._showResult` directly: `backgroundColor` from `MiningTheme.panel`, a cyan-bordered rounded `shape`, appropriate `behavior` and Orbitron/high-contrast text. This covers all in-game success/failure/recovery/sale messages via the existing `_showResult`/`_showActionFailure` paths without modifying `HorologiumApp` or introducing another theme accessor. Maintain a width-safe 360 px layout and the existing reduced-motion `snackBarAnimationStyle`.
- Do **not** create toast services, message stores, or per-call color branches. Avoid changing route dismissal semantics needed to expose failures behind a Technology sheet.
- Assert styled success, rejection, recovery and sale messages in the **existing shell widget harness** (which pumps `MiningShell` in its own `MaterialApp`), not an app-boot test that navigates through `MainMenu`. No light default may remain.

## 3. Mine Site: tiers, distinct upgrades, readable HP

- Render **one** compact pointer-ignoring `ExcludeSemantics` tier chip for every placed rig from the **existing per-rig scene loop**; anchor it at the **top edge of the rig cell** in scene coordinates so it follows pan/zoom and avoids the lower region where an adjacent resource's HP chrome can appear. Keep the existing single actionable semantics node per rig; `_rigLabel` already announces tier and upgrade.
- When a dock rig is selected, existing `view.upgradeableCells` drives a **gold outline/ring** instead of the current gold fill; keep cyan fill only for deployable empty cells. The **same chip** reads `Tn→Tn+1` in gold for eligible cells, otherwise just `Tn`. No second badge/widget. Mismatched/illegal/T5 rigs retain their plain tier chip without upgrade cue.
- Paint the outline in `MiningGridPainter` and the chip in the one per-rig map overlay, with no duplicate upgrade eligibility, hit-testing, or tap route. `MineSiteView.gridTapOutcome` and `MiningController.upgradePlacedRig` retain the behavior; chip paint is noninteractive and excluded from semantics.
- In `AnimatedMiningGridVisualLayer`, move mined-resource `_hpChrome` **after robot/rig visuals** in the existing `Stack` to prevent robots obscuring HP. A chip higher in the parent scene `Stack` can still occlude HP if misplaced, so **geometry matters**: assert that the top-anchored chip rectangle does **not intersect** the HP rectangle for rigs immediately above 1×1 and 3×3 mined deposits. Preserve damage-label timing and HP values.

## 4. Stellar Map: consistent Travel action

- The current active planet already uses a compact `MiningHex`; the non-current unlocked planet uses that same `MiningHex` stretched by an outer `Expanded`. Keep the active control and locked-planet unlock affordance; change the card layout so **unlocked, non-current** planets show a fixed-size, right-aligned hex with a visible `TRAVEL` label and a minimum 48×48 hit area.
- Retain the existing key `mining-stellar-map-travel-<planet>`, busy guard, `onTravel` callback and semantic label. Do not change travel or unlock rules.

## 5. Short-screen layout repairs

**Fleet returned (`offline_return_sheet.dart`).** Portrait currently overlays a bottom `Next:` + action footer over a full-height report scroller, creating an overlap at 360×640. Keep the same hero/gradient and action controls but divide the available portrait body into a scrollable report area and a **separate, pinned footer**. The `Next:` instruction and SELL ALL/continue actions live in that footer, never over planet entries. Provide safe-area bottom padding. Five unlocked planets must remain independently scrollable; the layout should not rely on adding a larger magic bottom spacer.

**Technology (`technology_sheet.dart` / `mining_sheet_frame.dart`).** The shared frame currently scrolls the entire title, tree and detail, while portrait `_tree` has a minimum 500 px height. Add one optional `pinnedFooter` to `MiningSheetFrame`; leave all existing callers/appearance unchanged when null. In the opt-in layout, keep the header and selected-track `_compactDetails` / Upgrade button fixed and give **only the level tree** the remaining scrollable space. Supply a bounded panel height before using `Expanded`, so portrait 360×640, 390×844, and landscape 874×402 have no unbounded constraints or overflow. A selected track remains selected across live view-model updates; purchase/gate state remains driven from `TechnologySheetView`.

**Selected-rig hint (`fleet_dock_view.dart` / `fleet_dock.dart`).** For selected T1–T4 use `DEPLOY · UPGRADE · MERGE`, dropping CELL/RIG/BAY target words because cyan deployment fill and the new gold ring now **visually indicate where to tap**. Keep the T5 deployment-only hint and no-selection hint. Do **not** change `FleetDock`'s `maxLines: 3` fallback: native Orbitron should generally fit one line at 360 px, while Chrome's wider fallback font may wrap. The correctness contract is **no ellipsis, truncation or overflow**, not literally one line on every renderer.

## Accessibility and verification contracts

- New card: screen-reader header, planet name, next gate labels plus satisfied/required status, reward amount, action labels. All controls remain operable without animation. Avoid duplicate semantics for grid chips.
- At **360×640 and 390×844**, use the real Orbitron test font where typography affects geometry (reuse the existing `FontLoader` pattern). Cover the 430×932 baseline/874×402 landscape where relevant.
- Test legal/nonlegal upgrade cues, single-chip semantics, top-row HP paint order, and the nonintersection of chip/HP rectangles for rigs above **both 1×1 and 3×3** deposits. Pan/zoom scales chip and HP geometry together, so no redundant widget layout tests at 0.8/1.6 are needed; manually confirm legibility at both zoom limits.
- Test `masteredPlanetId` for **every planet in both runs** inside the public-action journey, including `null` on nonfinal deployments. Shell widget tests cover a representative nonfinal mastery card and its gates/navigation, Io reward/Relaunch Cancel+Confirm, an ordinary deploy, and a failed save. Reload/refresh/resume cannot report the card by construction; retain targeted checks where useful without duplicating seven negative shell test setups.
- Test the styled `SnackBar` through the existing shell widget harness (success/failure), and reduced-motion behavior for **both** modal helpers plus SnackBars. No full-app theme/`MainMenu` navigation test.
- Preserve the public-action journey numbers; do not rewrite bounds, costs, states or the save contract merely to make these tests pass.

## Non-goals

No artwork or audio generation, new tutorial/achievement flags, extra card for site commissioning or planet unlock, technology level >5 balancing, Extraction/Logistics rebalance, game-state migration, or broad refactoring. If visual review reveals a need for **new** image art or SFX, scope that into a **separate Linear art/audio task**, not this implementation PR.

## Review focus

1. The card must be **post-commit**, driven solely by `MiningActionResult.masteredPlanetId` from `deployRig`, with next gates sourced from `StellarMapView` and the existing milestone SFX retained.
2. No duplicate Io cash grant, SnackBar, or stacked modal on the Relaunch path.
3. Small-height layouts must preserve scroll and visible actions rather than only suppressing overflow in tests.
4. HP and tier chrome must preserve existing animated-layer semantics, tap routing and performance.