# HPA-814 — First-session polish: implementation plan

- Status: Proposed; **planning only** on this draft PR (2026-11-07)
- Linear: https://linear.app/cwchanap/issue/HPA-814/first-session-polish-reachable-rig-cells-clearer-hints-quieter-return
- Design: [2026-11-07-hpa-814-first-session-polish-design.md](../specs/2026-11-07-hpa-814-first-session-polish-design.md)
- Baseline: `main` @ `5bc1afe6a52d92b97828a3ea8276cc9a5170a8c4`
- **Delivery: one PR for HPA-814.** Review plan here, then commit implementation/tests to this branch and PR. The steps below are sequencing within one PR, **not** PR or Linear ticket boundaries.

## Reuse survey

| Existing implementation | Reuse / narrow change |
| --- | --- |
| `MiningGridMap` / `InteractiveViewer`, `MineSiteView.rigs` and `deployableCells` | Add widget-local transform, initial focus, and safe panning; keep grid data, hit mapping, placement rules unchanged |
| `MineSiteScreen` / `_CavernScene` | Supply real HUD/dock clearance to the map; no new screen-level coordinate owner |
| `_LockedSite`, `_PlanetProgress`, `MiningNextGoalStrip` | Fix copy and text layout in place; no second site-card/read model |
| `FleetDockView.dockHint` | Change instructions only; preserve dock interactions |
| `MiningGoalTarget.technology`, `MiningShell.openTechnology` | Direct research goals to Surveying; existing navigation and controller actions remain authoritative |
| `TechnologySheetView.from` and `_displayNotifier` | Recompute the live view in the existing bottom-sheet route and preserve one local selected-track state |
| `OfflineProductionSummary.elapsedAway/fullSites` and `MiningSave.saleValue` | Five-minute threshold and per-planet cash label; no new timer, savings state, or accrual |
| `StellarMapPlanetView` and `MiningSheetScene` | Fix the already-unlocked cash check and cargo ring's real projected value |
| Existing presentation tests and test clocks | Add targeted cases rather than new harness or integration framework |

## Step 1 — Mine Site viewport and interaction

**Production:** `lib/mining/presentation/mining_grid_map.dart` and `mine_site_screen.dart`.

1. Add the smallest stateful viewport wrapper needed for an owned `TransformationController`. Keep scale range, child dimensions, object overlays, semantics, and current `MiningGridCell` hit translation.
2. Derive portrait top/bottom/side clearances from the existing HUD, Fleet Dock and safe-area layout; route them to the map as viewport margins. Do not hardcode one 390×844 margin for all phones. Preserve landscape and pan bounds.
3. On first mount/site switch or real viewport resize, choose a deterministic focus rectangle from existing placed rigs; without rigs choose the first legal deployment cell. Fit/center within the unobscured area at supported scale. Do not reset the matrix when a new `MineSiteView` arrives from the one-second refresh.
4. Check that physical taps and accessibility taps still resolve the original legal cell. Existing HP bars/overlay art move with the scene, never into a separate fixed overlay.

**Tests:** extend `test/mining/presentation/mining_grid_map_test.dart` and `mine_site_screen_test.dart` using 360×640, 390×844, 430×932. Cover first legal cell on fresh Landing Basin, edge cells on Carbon Ridge at Surveying 0, initially deployed rig, pan/zoom persistence on a refreshed view, and site change reframe. Assert visible target rectangle avoids HUD/dock, and callback receives the intended grid coordinate. Use semantics tests for rig labels/actions. Keep the existing 100-deposit test and map hit-test regression.

Gate: `flutter test test/mining/presentation/mining_grid_map_test.dart test/mining/presentation/mine_site_screen_test.dart`.

## Step 2 — Site Deck/next goal and Fleet Dock copy

**Production:** `site_deck_screen.dart` (`_LockedSite` and `_PlanetProgress`), `mining_next_goal_strip.dart`, `fleet_dock_view.dart`.

1. Expose locked site name and resource above its lock pill with existing textual styles/assets; do not rearrange unlock logic.
2. Scale the planet title down to fit instead of ellipsis. Let portrait next-goal detail wrap to two lines, with enough strip height; retain compact landscape layout.
3. Replace “NODE” in fleet instructions with “HIGHLIGHTED CELL”; preserve selection/merge/deploy mechanics and don't imply HPA-813's placed-rig upgrades.

**Tests:** extend `site_deck_screen_test.dart`, `mining_next_goal_strip_test.dart`, `test/mining/fleet_dock_view_test.dart`. Include full Io Frontier text at 360 px and wrapped long goal details; load real Orbitron font for precise width assertions. Confirm that a prerequisite site referenced by a goal is named on its locked card.

Gate: focused tests above; no visual asset generation.

## Step 3 — Technology deep link and repeat purchases

**Production:** `mining_shell.dart`, `technology_sheet.dart`, and `mining_progression_views.dart`.

1. Pass a single optional `initialTrack` to Technology opening. The current `Research Surveying` goal selects Surveying; normal Technology navigation still opens Extraction. Preserve the existing `MiningGoalTarget` type and shell navigation.
2. Replace the currently frozen `TechnologySheet` view with `TechnologySheetView.from(state: liveState, content: _content)` on `_displayNotifier` updates inside `_showMiningSheet`. Keep the same sheet element and its locally selected track. **This live-reprojection is required**: removing `Navigator.pop` alone leaves stale levels/costs.
3. Let purchase call the existing controller path without closing; when the mutation completes, show the new level, next price, gate, affordability, and max-level state while preserving selection.
4. Replace Surveying's repeated generic site count with short, authored-data-derived next-level benefit copy (newly revealable deposits/sites, required planet levels). No new progression engine and no controller behavior change.

**Tests:** extend `technology_sheet_test.dart`, `mining_shell_test.dart`, and `mining_progression_views_test.dart`. From a goal, open Surveying; make two eligible purchases on the same route; assert still open, selected Surveying, updated level/cost, and no duplicate purchase. Check direct navigation defaults and every authored Surveying level's copy, including no-new-unlock/max-level cases.

Gate: focused tests above.

## Step 4 — Offline return, Stellar Map gate, sheet semantics

**Production:** `mining_shell.dart`, `offline_return_sheet.dart`, `mining_progression_views.dart`, `mining_sheet_frame.dart`.

1. In one shell-owned helper/condition, gate both the initialize-pending-summary and resumed-sheet paths on `elapsedAway >= Duration(minutes: 5)`. Keep the existing `wasBackgrounded` requirement on resume and existing production-summary prerequisite; accrue and persist as before.
2. Pass a post-accrual `MiningSave` snapshot to the offline report. Use `state.saleValue(content, planetId)` for each reported planet's cash worth. If `summary.fullSites` includes all authored sites on that planet, replace multiple site-full warnings with one “All N sites full · sell to resume” warning; keep individual warnings when only some are full and keep all positive resource production rows.
3. For an already unlocked planet, mark its Stellar Map **display requirement** for paid cash satisfied even if remaining cash is low, without changing the underlying unlock operation.
4. Supply `MiningSheetScene`/`MiningCargoGauge` the active planet's live sale projection instead of hardcoded `0`. Keep cargo, capacity, and value on the same active-planet scope.

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
- `lib/mining/`: `fleet_dock_view.dart`, `mining_progression_views.dart`
- Corresponding existing `test/mining/presentation/` and `test/mining/` files; no new framework.
- `CLAUDE.md` and these two planning documents.

## Explicit non-goals and integration risks

No extra tickets, PRs, art, SFX, data model, controller public API, economy, save migration, tutorial engine, state owner, or automated selling/merging. HPA-813 owns those gameplay conveniences. The only known overlap is `offline_return_sheet.dart`: the second implementation must rebase and preserve both tickets' behavior.

Highest-risk behavior to prove in tests: `InteractiveViewer` offset/scale under overlays; camera retention on each second's presentation refresh; keeping a Technology sheet's state and live values together; true absence duration vs transient inactive; current sellable value vs newly produced units; existing paid planet gates.