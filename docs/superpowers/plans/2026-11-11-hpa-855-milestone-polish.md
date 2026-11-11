# HPA-855 — Milestone feedback and small-screen polish: implementation plan

- Status: **Planning only**. This commit creates a reviewable execution plan, not an implementation.
- Linear: https://linear.app/cwchanap/issue/HPA-855/make-milestones-land-mastery-card-rig-tiers-on-the-map-small-screen
- Design: [2026-11-11-hpa-855-milestone-polish-design.md](../specs/2026-11-11-hpa-855-milestone-polish-design.md)
- Baseline: `main` at `92ddcacc56c70c8a298f6fd79b4870c6366bb83b`.
- PR policy: **one HPA-855 PR only**. Get design approval first, then implement/test in subsequent commits on the **same branch**. Do not open a second implementation PR.
- Runtime scope: Flutter presentation and its tests only, plus one sentence in `CLAUDE.md`. No new assets/SFX (already authored), controllers, save keys, migrations, or economy changes.

## 0. Preflight and reusable contracts

Before changing runtime code:

1. Confirm the branch is based on HPA-813/PR #54 and HPA-814/PR #53 already merged in `main`, and reread `CLAUDE.md`. The baseline here is `92ddcac`.
2. Verify `_runSheetAction` in `mining_shell.dart`, `isPlanetMastered` in `mining_content.dart`, `StellarMapView.from` in `mining_progression_views.dart`, `RelaunchSheet`, `MiningGridMap`, `AnimatedMiningGridVisualLayer`, `MiningSheetFrame` and their existing tests.
3. Keep existing widget keys/semantic labels and explicit `MiningController` calls. There is no game-state owner or new service to introduce.
4. Record baseline results for the public-action journey, layout tests and widget tests; if local Flutter tooling is unavailable, mark that as **not run** rather than inferring success.

## 1. Mastery transition, card and navigation (first implementation commit)

Files:
- `lib/mining/presentation/mining_shell.dart`
- new `lib/mining/presentation/planet_mastered_card.dart`
- `test/mining/presentation/mining_shell_test.dart`
- new `test/mining/presentation/planet_mastered_card_test.dart` if focused UI coverage materially simplifies the shell tests

Work:

1. Keep `before = _controller.state` before `operation()` and inspect `after = _controller.state` only on `result.isSuccess` **after awaiting persistence**. Form commissioned site-id sets from the two snapshots and locate any planet transitioning from unmastered to mastered with `_content.isPlanetMastered`. In the current authored content only one planet can change on one action; no queue/state machine is needed.
2. Retain existing permission request and **single** commissioning milestone sound. When mastery changed, do not call `_showResult` for that successful action (especially the Io reward message); show a card instead. Retain failure handling unchanged.
3. For nonfinal mastery, derive the successor from `unlockRequiredMasteryPlanetId` in `_content.planets` and look up its `StellarMapPlanetView` from `StellarMapView.from(state: after, content: _content)`. Pass that view's already-projected `requirements` into `PlanetMasteredCard`. Do not recalculate gates in the card or copy gate labels into a second read model.
4. Reuse the authored planet image `planetAsset`, `MiningSheetFrame`, `MiningTheme` colors, and scrollable modal geometry. Show **PLANET MASTERED**, the mastered planet, the successor's name and each requirement with satisfied/required marks. Provide stable keys (e.g. `planet-mastery-card`, `planet-mastery-open-map`, `planet-mastery-continue`).
5. Io uses the same widget in a final variant: **FINAL PLANET MASTERED**, `formatMiningCash(_content.planet(finalId).masteryRewardCash)` and `RELAUNCH…`. The card does **not** mutate any state. On Relaunch, pop the mastery card first, then call the existing `_openRelaunchSheet`; Cancel must preserve state, Confirm follows the old `_confirmRelaunch` logic.
6. Open Map pops the card first, then invokes `_handleNavigation(MiningNavigationDestination.stellarMap)`. Continue only pops. Use the current shell's guarded mount/navigation paths; do not leave a hidden card over a new screen.
7. Apply `AnimationStyle.noAnimation` to the card modal when `_reducedMotion` is true (e.g. a small optional argument to `_showModalSheet`). No new animation controller.

Tests (seed valid repository saves, inject clocks and action failures using existing shell test helpers):

- Commission the last site on each of Homeworld, Lunar, Mars and Ceres via a real shell/controller action: one card; next planet and all three-or-fewer projected requirements match `StellarMapView` (site-mastery, Surveying, optional cash), including met/unmet flags. Validate buttons and no duplicate success SnackBar.
- Commission the last Io site: final card with exactly `90.00M` reward formatting from content, no duplicate toast/grant, no reset; `RELAUNCH…` opens the existing sheet, Cancel leaves `relaunchCount`/cash/commission flags unchanged. Confirm resets only through the controller, then a new completion in the next run shows the card again.
- An unsuccessful/rejected action, rejected repository save, a routine spawn/merge/sale, re-entering a mastered site, repeated one-second refreshes, cold reload of a mastered save, and offline resume show **no** mastery card.
- Reduced-motion media setting results in no card transition animation; card actions and semantics still work.

## 2. Theme every success/failure SnackBar (second implementation commit)

Files:
- `lib/main.dart` (root `ThemeData.snackBarTheme`)
- `test/mining/presentation/mining_shell_test.dart` or existing root app widget test

Work:
- Use `MiningTheme.panel`, cyan border/accent and existing Orbitron/text palette for a dark readable message; keep `_showResult` and `_showActionFailure` as the sole delivery path. Do not turn messages into a new widget service.
- Preserve `_showResult`'s removal of previous SnackBar and reduced-motion `snackBarAnimationStyle`. Do not alter Technology failure-sheet routing.
- Test with the **actual HorologiumApp theme**, not a bare default `MaterialApp`: successful action, blocked action/failure and recovery warning all inherit dark styling; no light-grey SnackBar at 360×640/390×844, and reduced-motion messages do not animate.

## 3. Rig chips, matching-target cue and HP paint priority (third implementation commit)

Files:
- `lib/mining/presentation/mining_grid_map.dart`
- `lib/mining/presentation/animated_mining_grid_visual_layer.dart`
- `test/mining/presentation/mining_grid_map_test.dart`
- `test/mining/presentation/animated_mining_grid_visual_layer_test.dart`
- `test/mining/presentation/mine_site_screen_test.dart` as needed for end-to-end visual positioning

Work:
- In the map scene's existing `Stack`, add one `IgnorePointer` visual overlay per **placed rig** using `view.rigs`. Show the tier chip without selecting a dock rig. A matching selected dock rig adds `Tn → Tn+1`; otherwise show only the tier chip. The same overlay handles static and animated sites; the authoritative semantics node and map tap handler stay untouched.
- In `MiningGridPainter`, replace the current gold-filled upgradeable-cell highlight with a **gold outlined ring** for `upgradeableCells`, visibly different from cyan deployable-cell fill. Do not compute upgrade eligibility in the painter; it receives the existing set.
- Anchor chip and badge in scene coordinates with sufficient text contrast and a layout clear of the resource HP chrome, including at min/max scale (0.8/1.6). Non-matching tiers, illegal targets, unselected state and T5 never receive an upgrade ring/badge; **all placed rigs** still get tier chips.
- Move `_hpChrome` after the robot/rig build loop in `AnimatedMiningGridVisualLayer` so an upper-row robot cannot paint over HP or its label. Preserve per-resource HP, impact latch, and existing damage label behavior; retain one semantics target per rig.
- Tests: tier chip count/labels match rig placements on animated/static sites, visible at zoom bounds; gold ring/cue only for legal matching targets; cyan deploy cells unchanged; no new gesture recognizers or duplicate semantics; top-row robot no longer paints over its resource HP/label. Existing animation/impact tests stay green.

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

## 6. One-line selected fleet hint and guidance (sixth implementation commit)

Files:
- `lib/mining/fleet_dock_view.dart`
- `test/mining/fleet_dock_view_test.dart`
- `test/mining/presentation/mine_site_screen_test.dart`
- `CLAUDE.md`

Work:
- Replace the selected T1–T4 `dockHint` with `DEPLOY · UPGRADE · MERGE`. Retain T5's deploy-only hint and the unselected hint; do not add a tutorial surface.
- With actual Orbitron, assert that selected T1–T4 instructions do not wrap or overflow at 360×640 while still covering deploy, upgrade, merge semantics; confirm T5 is not promised an upgrade.
- Add **one line** under shell ownership in `CLAUDE.md`: "Planet mastery feedback is a transient shell card detected by a successful before/after commissioned-state comparison; it is not persisted or emitted on load, refresh, or resume." Do not broaden architecture guidance.

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

- [ ] Four nonfinal planets show a single correct mastery card with **live** Stellar Map gate status and working Open Map/Continue.
- [ ] Io shows the existing reward and Relaunch route; no duplicate award/message; Cancel does not reset; another run can show mastery again.
- [ ] No mastery card on load, refresh, resume, failed action or already-mastered state; reduced motion suppresses card and message transitions.
- [ ] Every actual app message is dark themed for success and failure.
- [ ] Every placed rig has a tier chip; only legal selected targets have gold ring plus `Tn → Tn+1`; deposit HP paints above robots.
- [ ] Every non-current unlocked Stellar Map planet has a compact labeled hex Travel action.
- [ ] 360×640: return-sheet `Next:` never overlaps reports, Technology Buy stays pinned and visible, HP remains readable, hint stays one line.
- [ ] All authored assets/sounds reused, no new save/controller/economy changes, public-action journey unchanged, repository checks recorded.