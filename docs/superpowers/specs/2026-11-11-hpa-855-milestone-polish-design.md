# HPA-855 — Milestone feedback and small-screen polish: design specification

- Status: **Proposed / planning only**; implementation awaits review on this same draft PR.
- Linear: https://linear.app/cwchanap/issue/HPA-855/make-milestones-land-mastery-card-rig-tiers-on-the-map-small-screen
- Plan: [2026-11-11-hpa-855-milestone-polish.md](../plans/2026-11-11-hpa-855-milestone-polish.md)
- Source: 2026-11-07 fresh-save UAT and 2026-11-11 retest of HPA-813/HPA-814.
- Baseline: `main` at `92ddcacc56c70c8a298f6fd79b4870c6366bb83b` (HPA-813 and HPA-814 merged).
- Delivery: **one PR for HPA-855**. Commit only design and plan for initial review; add implementation, regression tests, and the one-line guidance update to this same branch after review.

## Player outcome

The **third and last commissioned site** on a planet is the mastery milestone. Commissioning a planet's last site produces an unmistakable, one-time **PLANET MASTERED** card with planet art and accurate next-planet requirements. Io's equivalent **FINAL PLANET MASTERED** card shows the already-awarded cash reward and offers Relaunch without resetting anything until the existing confirmation is accepted. Daily surfaces also communicate rig tier and upgrade targets at a glance, and the UI remains readable at 360×640.

This task is presentation polish only: **no new game state, persistence, economy rules, price changes, resource/rig logic, unlock logic, asset generation, or SFX.** Existing `MiningController` actions, `MiningSimulation`, `MiningSaveRepository`, `MiningContentRegistry` and public-action journey remain authoritative.

## Reuse survey and ownership

- `MiningShell._runSheetAction` already snapshots `before`, awaits a persisted mutation, updates `_displayState`, plays the commissioning/milestone sound, and reports through `_showResult`. Extend this one success path; do not create an event bus, achievement system, or notification queue.
- `MiningContentRegistry.isPlanetMastered(planetId, commissionedSiteIds)` determines mastery. The save already holds all commission flags. `StellarMapView.from(state, content)` projects visible planets and their `StellarMapRequirementView` labels plus `isSatisfied`. **Use this exact read model**, not duplicated Surveying/cash/mastery checks or hardcoded gate strings.
- `MiningShell._openRelaunchSheet` opens the existing `RelaunchSheet`, which is the only place the player confirms resetting the run. `MiningContentRegistry.planet(id).masteryRewardCash` is the authored Io reward; display it without recomputing or awarding it.
- `MiningGridMap` already has a shared scene `Stack` for static and animated sites, a `MiningGridPainter` fed `deployableCells` and `upgradeableCells`, and one semantic node per placed rig. Reuse `MineSiteRigView.placement.tier` and `canUpgradeWithSelection`; no additional targeting or hit-testing model.
- `AnimatedMiningGridVisualLayer` already owns HP labels as transient presentation, separate from deterministic production.
- `MiningSheetFrame` is the existing portrait/landscape sheet shell. Extend it minimally for **one opt-in pinned-footer layout** rather than introducing a second sheet framework.
- `HorologiumApp` in `lib/main.dart` owns the global Flutter theme; `MiningTheme` owns the palette. `MiningShell._showResult` already applies reduced-motion SnackBar animation handling.

## 1. Mastery card: transient and post-persistence

1. Only after `result.isSuccess` in `_runSheetAction`, compare the set of commissioned site IDs from `before.sites` and the committed `_controller.state.sites`. For authored planets, detect `!isPlanetMastered(before) && isPlanetMastered(after)`. A single commissioning action can newly master at most its planet in the current content.
2. If none changed, retain existing result SnackBars and audio. If a planet newly mastered, **replace its generic success SnackBar with the card**, including Io's existing `Io mastered — +90.00M cash.` result message. Keep the existing commissioning/milestone sound exactly once; no second cue from opening/closing the card.
3. Build a lightweight `PlanetMasteredCard` presentation widget using existing `MiningSheetFrame`/modal primitives, the mastered planet's existing `planetAsset`, and the game colors/fonts. It receives the mastered planet, next planet's **post-action** `StellarMapRequirementView` list, or the final reward, plus close/navigation callbacks. The UI must scroll inside available safe-area height and keep buttons reachable at 360×640; no unbounded card overflow.
4. For the four nonfinal planets, determine the immediate successor from the authored definition whose `unlockRequiredMasteryPlanetId` equals the just-mastered planet (the current content has a linear five-planet route). Read the successor's `requirements` from the already-existing `StellarMapView.from(after, content)` and show each label plus met/unmet indicator. Requirements must match the Stellar Map at the same committed state, even if Surveying/cash is still missing. Do not imply that mastery alone unlocks travel.
5. `Open Stellar Map` dismisses the card before invoking the existing `_handleNavigation(stellarMap)` path. `Continue` only dismisses it. Avoid leaving a modal covering the destination or accidentally reopening the card on the next one-second refresh.
6. For `content.finalPlanetId` (Io), show `FINAL PLANET MASTERED`, the already-awarded `masteryRewardCash` in `formatMiningCash`, and `RELAUNCH…`. Dismiss the card **before** invoking `_openRelaunchSheet`; the existing sheet's Cancel leaves all state unchanged. Card creation and dismissal never call `_controller.relaunch`. A new completion after an actual Relaunch produces a fresh card, as it is a new successful before/after transition.
7. Card state is **route lifetime only**. Do not store a seen flag, track a persisted achievement, or inspect mastery in `_initialize`, `refresh`, `resume`, offline production, or save decode. Re-entering a mastered planet or reloading an already-mastered save cannot show this card.

For reduced motion, use `MediaQuery.disableAnimations` already forwarded by the shell and the modal API's no-animation option for this new card. Avoid introducing card-specific animation controllers or timers. Preserve focus/semantic button labels.

## 2. Themed game messages

- Set a single `snackBarTheme` in `HorologiumApp` (`ThemeData`) with `MiningTheme.panel` dark background, cyan accent/border treatment, high-contrast game font, and a width-safe layout on 360 px. Keep `_showResult` and `_showActionFailure` as the single message delivery path and the existing `snackBarAnimationStyle: AnimationStyle.noAnimation` behavior.
- Do **not** create toast services, message stores, or per-call color branches. Avoid changing route dismissal semantics needed to expose failures behind a Technology sheet.
- Verify success, rejection, recovery, and sale messages inherit the same dark styling; no light default remains when the app uses its real root theme.

## 3. Mine Site: tiers, distinct upgrades, readable HP

- Add a compact, pointer-ignoring **T1–T5 tier chip for every placed rig** in the existing map scene, anchored to its grid cell so it follows pan/zoom and works for both the static and animated object layers. Keep the existing single semantic node per rig; `_rigLabel` already announces the tier and valid upgrade.
- When a dock rig is selected, use existing `view.upgradeableCells` to draw a **gold outline/ring**, instead of merely tinting these cells like the cyan deployment targets. Beside matching placed rigs, show a compact `Tn → Tn+1` badge derived from their actual tier. Do not show the ring/badge for mismatched tiers, an illegal target, or T5. Keep cyan fill exclusively for deployable empty cells.
- Paint these visual accents with existing `MiningGridPainter` plus the single shared map overlay; do not duplicate rule checks, add a second grid, or route taps through the chip/badge. `MineSiteView.gridTapOutcome` and `MiningController.upgradePlacedRig` keep the behavior.
- In `AnimatedMiningGridVisualLayer`, render mined-resource `_hpChrome` **after robot/rig visuals** in the existing `Stack`, preserving the hit/damage-label timeline and current HP values. Do not change animation timing, the contact latch, or economy. Place the rig tier chip away from HP chrome so a top-row rig cannot obscure HP; verify visually and geometrically.

## 4. Stellar Map: consistent Travel action

- The current active planet already uses a compact `MiningHex`; the non-current unlocked planet uses that same `MiningHex` stretched by an outer `Expanded`. Keep the active control and locked-planet unlock affordance; change the card layout so **unlocked, non-current** planets show a fixed-size, right-aligned hex with a visible `TRAVEL` label and a minimum 48×48 hit area.
- Retain the existing key `mining-stellar-map-travel-<planet>`, busy guard, `onTravel` callback and semantic label. Do not change travel or unlock rules.

## 5. Short-screen layout repairs

**Fleet returned (`offline_return_sheet.dart`).** Portrait currently overlays a bottom `Next:` + action footer over a full-height report scroller, creating an overlap at 360×640. Keep the same hero/gradient and action controls but divide the available portrait body into a scrollable report area and a **separate, pinned footer**. The `Next:` instruction and SELL ALL/continue actions live in that footer, never over planet entries. Provide safe-area bottom padding. Five unlocked planets must remain independently scrollable; the layout should not rely on adding a larger magic bottom spacer.

**Technology (`technology_sheet.dart` / `mining_sheet_frame.dart`).** The shared frame currently scrolls the entire title, tree and detail, while portrait `_tree` has a minimum 500 px height. Add one optional `pinnedFooter` to `MiningSheetFrame`; leave all existing callers/appearance unchanged when null. In the opt-in layout, keep the header and selected-track `_compactDetails` / Upgrade button fixed and give **only the level tree** the remaining scrollable space. Supply a bounded panel height before using `Expanded`, so portrait 360×640, 390×844, and landscape 874×402 have no unbounded constraints or overflow. A selected track remains selected across live view-model updates; purchase/gate state remains driven from `TechnologySheetView`.

**Selected-rig hint (`fleet_dock_view.dart`).** For selected T1–T4 use one readable line: `DEPLOY · UPGRADE · MERGE`. Keep the T5 deployment-only hint and no-selection hint. No new instructional overlay or tutorial system.

## Accessibility and verification contracts

- New card: screen-reader header, planet name, next gate labels plus satisfied/required status, reward amount, action labels. All controls remain operable without animation. Avoid duplicate semantics for grid chips.
- At **360×640 and 390×844**, use the real Orbitron test font where typography affects geometry (reuse the existing `FontLoader` pattern). Cover the 430×932 baseline/874×402 landscape where relevant.
- Test both tier-map zoom limits (`miningGridMinScale = 0.8`, `miningGridMaxScale = 1.6`); test the full set of legal/nonlegal upgrade targets and the top-row HP order.
- Test transient-only behavior: success shows exactly one card; failed persistence/no-op/reload/offline/foreground refresh shows none; Io reward is not paid twice; Cancel on Relaunch leaves save untouched; replay after Relaunch can show the card again.
- Test message theming at app root for both success and failure, and no modal/SnackBar transition in reduced-motion mode.
- Preserve the public-action journey numbers; do not rewrite bounds, costs, states or the save contract merely to make these tests pass.

## Non-goals

No artwork or audio generation, new tutorial/achievement flags, extra card for site commissioning or planet unlock, technology level >5 balancing, Extraction/Logistics rebalance, game-state migration, or broad refactoring. If visual review reveals a need for **new** image art or SFX, scope that into a **separate Linear art/audio task**, not this implementation PR.

## Review focus

1. The card must be **post-commit**, with true mastery transitions and gate labels sourced from `StellarMapView`.
2. No duplicate Io cash grant, SnackBar, or stacked modal on the Relaunch path.
3. Small-height layouts must preserve scroll and visible actions rather than only suppressing overflow in tests.
4. HP and tier chrome must preserve existing animated-layer semantics, tap routing and performance.