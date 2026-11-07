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

Current `lib/mining/presentation/mining_grid_map.dart` uses a 50×50 grid in an `InteractiveViewer` (0.8–1.6 scale, unconstrained child, top-left alignment) without a boundary margin. The portrait HUD and Fleet Dock cover reachable edge cells.

- Keep native `InteractiveViewer` and the existing `MiningGridCell` hit mapping. Define named placement constants in `mine_site_screen.dart` for the existing cash/back/cargo chrome, dock, and navigation offsets and dimensions; use those **same constants** for the widgets and computed unoccluded viewport insets. No copied literals, GlobalKey measurements, or post-frame relayout. Cover **portrait and landscape**: the landscape cash chip and 252×54 bottom toolbar also overlay the cavern. Include system padding and use the UAT's LTRB 60/150/60/230 at 390×844 only as a sanity check.
- `InteractiveViewer.boundaryMargin` is in **scene (child) coordinates**, while the clearances above are in screen pixels. Set each scene margin to `screenInset / minScale` (minimum scale is 0.8). At 0.8× a 150 px top clearance still clears 150 px, rather than only 120; excess room at 1.6× is acceptable. Apply the same scale-aware coordinate conversion when clamping the initial camera to its pan bounds.
- Make `MiningGridMap` a `StatefulWidget` with one widget-local `TransformationController`. Key the map by `view.siteId`. Initialize a 1.0× transform **once**, on the first `LayoutBuilder` pass before the `InteractiveViewer` mounts, then retain it throughout ordinary one-second rebuilds. The Site Deck ↔ Mine Site switch remounts the map; portrait ↔ landscape switches also remount because their screen widget types differ. No `didUpdateWidget`, reframe-on-resize logic, or group-fit zoom algorithm.
- Focus at the center of the placed rigs' bounding box if rigs exist (up to four), otherwise focus on the **first** deterministic `view.deposits` entry where `isSurveyed && minerCount < slotCount`. `MineSiteView.deployableCells` is **empty until a dock rig is selected** and must not be used for initial empty-site framing. The first surveyed deposit points the camera near its free perimeter slots without recalculating placement legality in the widget. If no deposit qualifies, leave the identity transform. Clamp the focus against the scale-aware boundaries and center it inside the unoccluded area; far-apart rigs remain reachable by normal panning.
- Preserve the authoritative placement rules in `mining_grid.dart`, physical/semantic hit testing, and rig/HP overlays. Validate both 0.8× and 1.6× zoom at 360×640, 390×844, and 430×932; a legal top/bottom edge cell and its rig/HP bar must be pannable into an unoccluded, tappable rectangle.

## 2. Site Deck and fleet copy

- In `site_deck_screen.dart`, the locked-card overlay (`_LockedSite`) names the authored site and its resource prominently above the existing lock pill; do not alter lock/unlock conditions. This makes “Unlock Carbon Ridge first” discoverable. Show the planet title fully via scale-down text, not ellipsis, at 360 px. In `mining_next_goal_strip.dart` allow the portrait detail to occupy two lines with enough vertical room; keep the compact landscape strip compact.
- In `fleet_dock_view.dart`, replace “NODE” instructions with “HIGHLIGHTED CELL”: unselected “TAP A RIG, THEN A HIGHLIGHTED CELL”; selected “TAP A HIGHLIGHTED CELL” (with a truthful dock-only merge cue if needed). Highlighting and rig actions remain unchanged. Do not imply that a dock rig can merge into a placed rig until HPA-813 ships.

## 3. Research deep link and live Technology sheet

- The next-goal read model already owns navigation intent. Extend `MiningGoalTarget.technology(TechnologyTrack track)` to carry its required track; include `track` in equality, `hashCode`, and `toString` (and keep a null track for non-Technology targets). Have the `Research Surveying N` goal emit `TechnologyTrack.surveying` and `MiningShell._openGoal` forward the target's track to `openTechnology(initialTrack: ...)`. Regular Technology navigation defaults to Extraction. Do not teach the shell to guess the track from goal kind/title, or add a generic deep-link router or persistent preference.
- `TechnologySheet` currently owns `_selected` in State, defaults to Extraction, and pops before `onPurchase`. Accept `initialTrack` in its constructor, initialize the State selection from it once, and remove the pop for a successful purchase.
- In `MiningShell`, change `_showMiningSheet` to take a `Widget Function(MiningSave state)` builder rather than a frozen widget. Build `TechnologySheet(view: TechnologySheetView.from(state: liveState, content: _content), initialTrack: ...)` **inside** the existing `ValueListenableBuilder`; preserve the same widget type/key under the route, so its local selected track survives live display refreshes. Settings and the non-scene offline sheet can continue to use the same existing route paths, without a parallel sheet manager. Route purchases solely through the existing `_purchaseTechnology` / `_runSheetAction` / controller.
- Surveying has one existing `_effect` case that supplies `nextEffect`, already shown as “Next: …”. Rewrite only that case to explain new surveyed deposits/sites on the active planet and named frontier Surveying requirements from `MiningContentRegistry`. Levels with no new local deposit must not promise one; max level remains unpurchasable. Remove unused `depositAvailability`, `nextDepositAvailability`, `surveyingDepositAvailability` and the private `_depositAvailability` projection while implementing, rather than adding a third Surveying string. No second progression model.
- **Feedback while the sheet stays open:** The shell's existing `ScaffoldMessenger` SnackBar renders **behind** the full-screen `MiningSheetScene`, so it must not be presented as visible success feedback. Use the newly updated level, price, gate, and enabled state **inside the sheet**, plus the existing upgrade sound/haptic, as success feedback. Expected preflight failures are displayed in the button's existing `disabledReason`. Do not add a separate in-sheet toast/SnackBar framework; test what the player actually sees, not hidden `find.text` matches.

## 4. Quiet, useful Fleet Returned sheet

- Keep the single five-minute guard **inside** `MiningShell._showOfflineReturn`: both cold initialization (`takePendingReturnSummary`) and true foreground resume already call it. Only show when the existing produced-summary condition is met and `summary.elapsedAway >= const Duration(minutes: 5)`; resume additionally requires the existing `wasBackgrounded` gate before calling the method. Shorter absence still accrues and persists normally; no new timer, callback path, or `MiningSimulation` change.
- Pass the post-accrual `MiningSave` snapshot into `OfflineReturnSheet` so a planet header can show `state.saleValue(content, planetId)` with existing `formatMiningCash`. This is **current sellable cargo value**, not a dollar estimate of only the newly-produced units; it already includes the relaunch multiplier. Scope labels to planets already present in the offline production summary.
- Use `summary.fullSites` and the authored site's complete ID list: when every site on a planet is full, show **one** “All N sites full · sell to resume” warning rather than three per-site full warnings. Retain the resource production amounts. For a partially full planet keep its individual full-site warnings. Do not change accrual or full-site detection.
- HPA-813 will later change the action(s) on this sheet; whichever code lands second must rebase and retain both the five-minute visibility rule and the new selling behavior.

## 5. Two isolated read-model corrections

- In `mining_progression_views.dart`, calculate `isUnlocked = state.unlockedPlanetIds.contains(definition.id)` once and use `isUnlocked || state.cash >= definition.unlockCashCost` for **both** the displayed cash requirement and `hasCash`. Already-unlocked planet gates stay ticked after spending; do **not** change unlock action legality or refund cash.
- `MiningSheetScene` currently constructs the sheet's `MiningCargoGauge` with `projectedValue: 0`. Pass `liveDeck.projectedValue` already computed inside `MiningShell._showMiningSheet`, alongside `liveDeck.totalCargo`/`totalCapacity` on the active planet, so screen reader semantics report the real value. No extra projection, and do not substitute an all-planet value.

## Acceptance and verification

Test against the Linear issue's complete checkbox list:

1. At 360×640, 390×844, 430×932, pan/tap top- and bottom-edge legal cells (including rig/HP overlay) on fresh Landing Basin and Carbon Ridge at Surveying 0 **at both 0.8× and 1.6×**. Verify empty-site focus on the first surveyed deposit despite `deployableCells` being empty, rig-group center on populated sites, and no one-second camera jump.
2. Locked-card site name/resource, full planet titles, two-line next-goal detail, and highlighted-cell hint without any “node” instruction.
3. A Surveying research goal carries its selected track in `MiningGoalTarget` and opens Surveying; consecutive purchases keep the sheet open, retain selection, and display updated levels and prices **as visible success feedback**, not merely behind-modal SnackBar text. The Surveying explanation changes with level/content.
4. Fake-clock cold-start and paused/resumed cases at just below/exactly five minutes, no sheet for transient inactive; report per-planet cash values and one full warning for an all-full planet.
5. Unlocked planet cash gate stays checked after payment; sheet cargo-ring accessibility label reflects actual active-planet cash value.
6. Existing public-action journey milestones and both visit cadences remain identical to baseline; no economy or save changes.

Follow the repository's `CLAUDE.md` tests/build gates on the implementation commit and add one sentence there describing the minimum away interval. Real Orbitron fonts are required for widget tests asserting visible text width. No new dependency or assets.