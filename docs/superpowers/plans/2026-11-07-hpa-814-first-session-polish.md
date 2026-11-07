# HPA-814 — First-session polish: implementation plan

- Status: Proposed; **planning only** on this draft PR (2026-11-07)
- Linear: https://linear.app/cwchanap/issue/HPA-814/first-session-polish-reachable-rig-cells-clearer-hints-quieter-return
- Design: [2026-11-07-hpa-814-first-session-polish-design.md](../specs/2026-11-07-hpa-814-first-session-polish-design.md)
- Baseline: `main` @ `5bc1afe6a52d92b97828a3ea8276cc9a5170a8c4`
- **Delivery: one PR for HPA-814.** Review plan here, then commit implementation/tests to this branch and PR. The steps below are sequencing within one PR, **not** PR or Linear ticket boundaries.

## Reuse survey

| Existing implementation | Reuse / narrow change |
| --- | --- |
| `MiningGridMap` / `InteractiveViewer`, `MineSiteView.rigs` and surveyed `deposits` | One-time widget-local transform; focus on rig bounding box or first surveyed deposit with a free slot. `deployableCells` is empty until a dock rig is selected |
| `MineSiteScreen` / `_CavernScene` | Named constants shared by both HUD `Positioned`s and portrait/landscape clearances; scene-space `boundaryMargin = screenInsets / minScale` |
| `_LockedSite`, `_PlanetProgress`, `MiningNextGoalStrip` | Fix copy and text layout in place; no second site-card/read model |
| `FleetDockView.dockHint` | Change instructions only; preserve dock interactions |
| `MiningGoalTarget.technology(track)` / `MiningShell.openTechnology` | Carry research track in the goal target's equality/hash/string; forward it to the sheet without guessing in the shell |
| `TechnologySheetView.from` and `_displayNotifier` | State-accepting sheet builder recomputes the live view under the same StatefulWidget; selection survives, success feedback stays visible as level/price |
| `OfflineProductionSummary.elapsedAway/fullSites` and `MiningSave.saleValue` | Five-minute threshold and per-planet cash label; no new timer, savings state, or accrual |
| `StellarMapPlanetView` and `MiningSheetScene` | Fix the already-unlocked cash check and cargo ring's real projected value |
| Existing presentation tests and test clocks | Add targeted cases rather than new harness or integration framework |

## Step 1 — Mine Site viewport and interaction

**Production:** `lib/mining/presentation/mining_grid_map.dart` and `mine_site_screen.dart`.

1. Convert `MiningGridMap` to the smallest `StatefulWidget` that owns and disposes one `TransformationController`; key it by `view.siteId`. Keep the current `InteractiveViewer` scales (0.8–1.6), child, object overlays, semantics, and `MiningGridCell` hit translation.
2. Replace shared HUD magic offsets with named consts in `mine_site_screen.dart`, consumed by both their existing `Positioned` widgets and clearance math. Include real safe-area padding, portrait cash/back/cargo/dock/navigation, and landscape cash chip and 252×54 toolbar. Avoid GlobalKeys, duplicating the offsets, or measuring after first paint.
3. Pass these **screen-space** insets to the map. `InteractiveViewer.boundaryMargin` is in **child-space**: use `boundaryMargin = screenInsets / minScale`, including in the initial transform's clamping math. This ensures 150 px of top clearance at 0.8× rather than only 120 px. A little extra pan room at high zoom is fine.
4. On the **first** `LayoutBuilder` pass, before `InteractiveViewer` mounts, place an initial 1.0× camera at the center of existing rig placements' bounding box; if none, center on the first `view.deposits` item with `isSurveyed && minerCount < slotCount` (deterministic order, points at starter deposit). Do **not** use `view.deployableCells` for the empty-site frame: it is empty until a dock bay is selected. With no qualifying deposit, keep the identity matrix. Clamp inside the unoccluded viewport. No group-fit/autozoom or `didUpdateWidget`/resize reframe logic.
5. Allow the widget-local matrix to persist across one-second foreground refreshes; a site swap remounts the keyed map, and portrait/landscape switch remounts the different screen widget type. Physical taps and semantics actions must still resolve the original legal grid cell. No new placement legality in the widget.

**Tests:** extend `test/mining/presentation/mining_grid_map_test.dart` and `mine_site_screen_test.dart`. At **360×640, 390×844, and 430×932**, test both **0.8× and 1.6×**: pan top and bottom legal cells into an area outside the HUD/dock; tap and assert the intended grid coordinate and visible rig/HP. On fresh Landing Basin and Carbon Ridge Surveying 0, assert `deployableCells` is empty on entry but the frame centers on the surveyed starter deposit. Cover an initially rigged site, camera persistence during the next-second view rebuild, and re-entry/site change reframe. Preserve existing resource-count and hit-test regressions.

Gate: `flutter test test/mining/presentation/mining_grid_map_test.dart test/mining/presentation/mine_site_screen_test.dart`.

## Step 2 — Site Deck/next goal and Fleet Dock copy

**Production:** `site_deck_screen.dart` (`_LockedSite` and `_PlanetProgress`), `mining_next_goal_strip.dart`, `fleet_dock_view.dart`.

1. Expose locked site name and resource above its lock pill with existing textual styles/assets; do not rearrange unlock logic.
2. Scale the planet title down to fit instead of ellipsis. Let portrait next-goal detail wrap to two lines, with enough strip height; retain compact landscape layout.
3. Replace “NODE” in fleet instructions with “HIGHLIGHTED CELL”; preserve selection/merge/deploy mechanics and don't imply HPA-813's placed-rig upgrades.

**Tests:** extend `site_deck_screen_test.dart`, `mining_next_goal_strip_test.dart`, `test/mining/fleet_dock_view_test.dart`. Include full Io Frontier text at 360 px and wrapped long goal details; load real Orbitron font for precise width assertions. Confirm that a prerequisite site referenced by a goal is named on its locked card.

Gate: focused tests above; no visual asset generation.

## Step 3 — Technology deep link and repeat purchases

**Production:** `next_goal_view.dart`, `mining_shell.dart`, `technology_sheet.dart`, and `mining_progression_views.dart`.

1. Extend `MiningGoalTarget.technology(TechnologyTrack track)` with a `track` field, and update its equality, `hashCode`, and `toString` along with the other target constructors. The current `Research Surveying` goal passes `TechnologyTrack.surveying`; `MiningShell._openGoal` passes that target through to `openTechnology(initialTrack:)`. Regular Technology navigation defaults to Extraction. No shell-side inference from goal title/type.
2. Change `MiningShell._showMiningSheet(Widget sheet)` to accept `Widget Function(MiningSave state)` and build the Technology widget **inside** the existing `ValueListenableBuilder` so it gets `TechnologySheetView.from(state: liveState, content: _content)` with each notifier update. Preserve Settings and bare offline sheet paths. Keep the Technology widget type/key stable so `TechnologySheet` State retains `_selected`; initialize it once from `initialTrack`. **This live-reprojection is required**: removing `Navigator.pop` alone leaves stale levels and prices.
3. Remove the purchase-time `Navigator.pop`; keep calling the existing controller mutation via `_purchaseTechnology`/`_runSheetAction`. The immediately updated **visible** technology level, next price, gate and availability plus existing sound/haptic are the successful purchase feedback; the shell's normal `ScaffoldMessenger` SnackBar lands behind `MiningSheetScene` and cannot be counted as visible. Expected disabled purchases keep their existing `disabledReason`. Do not build a second in-sheet message channel.
4. Rewrite only the Surveying `_effect` case for current/next effect copy based on `site.deposits[].requiredSurveyingLevel` and `planet.unlockRequiredSurveyingLevel`, including unchanged/no-new-local-unlock and maximum levels. Remove the unused `depositAvailability`, `nextDepositAvailability`, `surveyingDepositAvailability` fields/getter and `_depositAvailability` helper instead of adding more derived state or an extra string.

**Tests:** extend `test/mining/next_goal_view_test.dart`, `technology_sheet_test.dart`, `mining_shell_test.dart`, and `mining_progression_views_test.dart`. Assert a research goal contains the Surveying target track, equality/hash behavior distinguishes tracks, and navigation forwards the selected track. Buy two eligible upgrades on one route; verify the sheet remains present, selection is unchanged, visible level/next cost updates after each, button prevents duplicate purchase, and sound/haptic remain. Do **not** use hidden `find.text('Technology upgraded.')` as evidence of success. Check direct-navigation Extraction default and content-derived Surveying copy across levels, no-change and max cases.

Gate: focused tests above.

## Step 4 — Offline return, Stellar Map gate, sheet semantics

**Production:** `mining_shell.dart`, `offline_return_sheet.dart`, `mining_progression_views.dart`, `mining_sheet_frame.dart`.

1. Put the single `elapsedAway >= const Duration(minutes: 5)` guard **inside** `MiningShell._showOfflineReturn` so both cold initialization and true background/resume inherit it. Keep the existing `wasBackgrounded` check on resume and production-summary prerequisite; short absences still accrue/persist silently.
2. Pass a post-accrual `MiningSave` snapshot to the offline report. Use `state.saleValue(content, planetId)` for each reported planet's cash worth. If `summary.fullSites` includes all authored sites on that planet, replace multiple site-full warnings with one “All N sites full · sell to resume” warning; keep individual warnings when only some are full and keep all positive resource production rows.
3. In `StellarMapPlanetView` projection, reuse `isUnlocked || state.cash >= definition.unlockCashCost` for both cash requirement tick and `hasCash` display. Do not touch the unlock operation.
4. Pass the already available `liveDeck.projectedValue` from the shell's sheet builder into `MiningSheetScene`/`MiningCargoGauge` instead of hardcoded `0`. Keep `totalCargo`, `totalCapacity`, and cash value on the same active planet.

**Tests:** extend `mining_shell_test.dart` with injected clock: cold load and true background 4:59 vs 5:00; transient inactive must not display; offline production still accrues below threshold. Extend `offline_return_sheet_test.dart` for per-planet sellable value (including relaunch multiplier), all-full single warning and partially-full rows. Add `stellar_map_screen_test.dart`/`mining_progression_views_test.dart` for already-unlocked paid cash gate, and `mining_sheet_frame_test.dart` for meaningful cargo-ring semantics.

Gate: focused tests above.

## Step 5 — Documentation, full validation, and PR review

- Add a short rule to `CLAUDE.md`: the Fleet Returned sheet requires at least five minutes of actual absence (and production); shorter absences accrue silently. Keep the existing controller ownership and active-planet selling contract.
- Confirm `test/integration/merge_mining_journey_test.dart` produces the **same** milestone hours and visit-cadence results as main; list only deviations if any (none expected). This is presentation-only work, so a journey difference blocks merge.
- Review UI at the three requested portrait sizes with the ticket's existing mockups; check Homeworld first-site, Carbon Ridge, unlocked Mars cash gate, and cold/background returns.
- Run **all** repository `CLAUDE.md` gates when implementation lands:

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

Use current CI/macOS runner for the iOS simulator build where needed. The *planning-only* commit does not claim these tests were run or passed. Mark status Implemented only after code and gates complete.

## Expected changed paths

- `lib/mining/presentation/`: `mining_grid_map.dart`, `mine_site_screen.dart`, `site_deck_screen.dart`, `mining_next_goal_strip.dart`, `technology_sheet.dart`, `mining_shell.dart`, `offline_return_sheet.dart`, `mining_sheet_frame.dart`
- `lib/mining/`: `fleet_dock_view.dart`, `mining_progression_views.dart`, `next_goal_view.dart`
- Corresponding existing `test/mining/presentation/` and `test/mining/` files; no new framework.
- `CLAUDE.md` and these two planning documents.

## Explicit non-goals and integration risks

No extra tickets, PRs, art, SFX, data model, controller public API, economy, save migration, tutorial engine, state owner, or automated selling/merging. HPA-813 owns those gameplay conveniences. The only known overlap is `offline_return_sheet.dart`: the second implementation must rebase and preserve both tickets' behavior.

Highest-risk behavior to prove in tests: **empty `deployableCells` on first entry** (initial focus must use surveyed deposits), **scene-space `boundaryMargin` under minimum 0.8× zoom** (clearance is screen inset divided by minScale), correct initial camera without resets during each-second updates, preservation of Technology selection and live level/cost, **behind-modal SnackBar not counted as success feedback**, true absence duration vs transient inactive, current sellable value vs newly produced units, and already-paid planet cash gates.