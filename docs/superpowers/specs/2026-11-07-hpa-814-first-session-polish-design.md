# HPA-814 — First-session polish: design

- Status: Proposed, design-only draft (2026-11-07)
- Linear: https://linear.app/cwchanap/issue/HPA-814/first-session-polish-reachable-rig-cells-clearer-hints-quieter-return
- Implementation: [2026-11-07-hpa-814-first-session-polish.md](../plans/2026-11-07-hpa-814-first-session-polish.md)
- Baseline: `main` at `5bc1afe6a52d92b97828a3ea8276cc9a5170a8c4` (the ticket's 2026-11-07 fresh-save UAT)
- Delivery: ONE draft PR for this ticket. Review these documents, then add implementation and tests to this same PR; do not open follow-up PRs for layers.

## Player outcome and boundaries

A new player can reach every legal rig cell without fighting HUD overlays; progression cards, hints, and the next-goal strip explain the immediate action; a research goal navigates to the correct Technology track; purchases update in place; a short app interruption does not raise a “FLEET RETURNED” sheet. Existing economic behavior and journey times remain unchanged.

Presentation/projection only: no `MiningController` public action changes, no `MiningSimulation`, save format/repository, prices, rig stats, placement legality, or additional state owner. Reuse `MiningShell` for navigation/lifecycle, `MiningGridMap` for viewport transformation, `TechnologySheetView`/`SiteDeckView`/`StellarMapPlanetView` for read models, and `OfflineProductionSummary` for away duration/full-site data. No new art or SFX. HPA-813's sell-all-planets, in-place upgrades, and one-tap build are deliberately separate.

## 1. Mine Site: reach and sensible initial framing

Current `lib/mining/presentation/mining_grid_map.dart` uses a 50×50 grid in an `InteractiveViewer` (0.8–1.6 scale, unconstrained child, top-left alignment) without a boundary margin. The portrait cash/back/cargo HUD and bottom Fleet Dock cover part of its reachable edge cells.

- Retain `InteractiveViewer` and `MiningGridCell` hit mapping. Add viewport-safe margins corresponding to the actual portrait HUD, system padding, and Fleet Dock/navigation footprints. Pass these presentation insets from the Mine Site layout instead of creating a second geometry/placement model. Use the 2026-11-07 UAT's approximate LTRB 60/150/60/230 at 390×844 only as a starting point, not a universal constant.
- Give `MiningGridMap` one owned `TransformationController` (widget-local state) to frame existing rig coordinates on initial site entry; when none exist, frame a deterministic first legal placement cell. Center within the unobscured rectangle and clamp to pan boundaries. Prefer a group framing when rigs fit, otherwise frame their center/nearest useful rig without requiring zoom below the existing 0.8 minimum. The viewport must permit reaching every other legal cell by normal panning.
- Initialize the transform when the site or viewport dimensions change, **not** when a one-second refreshed view model arrives. Preserve player pan/zoom during foreground production. Dispose the transformation controller with the widget. Keep landscape behavior intact and cover safe margins there only if its actual overlays require them.
- Preserve resource/rig semantics overlays and the existing legal-cell calculation in `mining_grid.dart`. A legal cell and its visible rig/HP indication must be brought into an unoccluded, tappable area at 360×640, 390×844, and 430×932.

## 2. Site Deck and fleet copy

- In `site_deck_screen.dart`, the locked-card overlay (`_LockedSite`) names the authored site and its resource prominently above the existing lock pill; do not alter lock/unlock conditions. This makes “Unlock Carbon Ridge first” discoverable. Show the planet title fully via scale-down text, not ellipsis, at 360 px. In `mining_next_goal_strip.dart` allow the portrait detail to occupy two lines with enough vertical room; keep the compact landscape strip compact.
- In `fleet_dock_view.dart`, replace “NODE” instructions with “HIGHLIGHTED CELL”: unselected “TAP A RIG, THEN A HIGHLIGHTED CELL”; selected “TAP A HIGHLIGHTED CELL” (with a truthful dock-only merge cue if needed). Highlighting and rig actions remain unchanged. Do not imply that a dock rig can merge into a placed rig until HPA-813 ships.

## 3. Research deep link and live Technology sheet

- The present next-goal ladder emits a Technology target for `Research Surveying N`. Route that goal to `openTechnology` with `TechnologyTrack.surveying` as its initial selection; the regular nav action can still default to Extraction. Use the existing target/read model; no generic deep-link router or persistent selection preference.
- `TechnologySheet` currently defaults `_selected` to Extraction and pops before calling `onPurchase`. Accept an initial track, keep its State-owned selected track, and remove the pop after a purchase.
- `MiningShell._showMiningSheet` already listens to `_displayNotifier` but passes the same, initially constructed `TechnologySheet(view: ...)`. When its notifier changes, rebuild the **TechnologySheetView** from the latest displayed state under the same sheet element so level, price, gate, and button state update without resetting selection or closing the route. Keep purchases routed only through the existing `_purchaseTechnology` / `_runSheetAction` / controller.
- Surveying's next-level description should describe **what the next level actually reveals**: new deposits/sites on the active planet and named frontier requirements, derived from `MiningContentRegistry`'s existing Surveying thresholds. Avoid the repeated “N of N sites revealable” as the only text and avoid a new progression subsystem. Levels with no new local deposit should say so rather than promising one; max level remains unpurchasable.

## 4. Quiet, useful Fleet Returned sheet

- `MiningShell` is the single visibility owner for the sheet, for **both** cold initialization (`takePendingReturnSummary`) and foreground resume. Only show when the existing produced-summary condition is met, `summary.elapsedAway >= const Duration(minutes: 5)`, and for resumed sessions `wasBackgrounded` is true. Shorter absence still accrues and persists normally; do not add a new timer or change `MiningSimulation`'s elapsed window.
- Pass the post-accrual `MiningSave` snapshot into `OfflineReturnSheet` so a planet header can show `state.saleValue(content, planetId)` with existing `formatMiningCash`. This is **current sellable cargo value**, not a dollar estimate of only the newly-produced units; it already includes the relaunch multiplier. Scope labels to planets already present in the offline production summary.
- Use `summary.fullSites` and the authored site's complete ID list: when every site on a planet is full, show **one** “All N sites full · sell to resume” warning rather than three per-site full warnings. Retain the resource production amounts. For a partially full planet keep its individual full-site warnings. Do not change accrual or full-site detection.
- HPA-813 will later change the action(s) on this sheet; whichever code lands second must rebase and retain both the five-minute visibility rule and the new selling behavior.

## 5. Two isolated read-model corrections

- In `mining_progression_views.dart`, the Stellar Map's **display** cash requirement for a planet already in `state.unlockedPlanetIds` is satisfied regardless of current cash. Change the related displayed `hasCash`/requirement projection only; do **not** change unlock action legality or refund cash.
- `MiningSheetScene` currently constructs the sheet's `MiningCargoGauge` with `projectedValue: 0`. Pass the live, active-planet projected sale value already available from `SiteDeckView`/`MiningSave` along with its existing active-planet cargo/capacity, so screen reader semantics report the true cash value. Do not substitute an all-planet value.

## Acceptance and verification

Test against the Linear issue's complete checkbox list:

1. At 360×640, 390×844, 430×932, pan/tap top- and bottom-edge legal cells (including rig/HP overlay) on fresh Landing Basin and Carbon Ridge at Surveying 0. Verify initial focus for empty and rigged sites; one-second foreground updates must not jump the camera.
2. Locked-card site name/resource, full planet titles, two-line next-goal detail, and highlighted-cell hint without any “node” instruction.
3. A Surveying research goal opens the Surveying track; consecutive purchases keep the sheet open, retain selection, and display updated levels and prices. The Surveying explanation changes with level/content.
4. Fake-clock cold-start and paused/resumed cases at just below/exactly five minutes, no sheet for transient inactive; report per-planet cash values and one full warning for an all-full planet.
5. Unlocked planet cash gate stays checked after payment; sheet cargo-ring accessibility label reflects actual active-planet cash value.
6. Existing public-action journey milestones and both visit cadences remain identical to baseline; no economy or save changes.

Follow the repository's `CLAUDE.md` tests/build gates on the implementation commit and add one sentence there describing the minimum away interval. Real Orbitron fonts are required for widget tests asserting visible text width. No new dependency or assets.