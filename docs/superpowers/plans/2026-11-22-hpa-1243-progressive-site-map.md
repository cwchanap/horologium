# HPA-1243 — Implementation plan: progressive Mine Site map

Linear: https://linear.app/cwchanap/issue/HPA-1243/mining-map-progressive-site-map-pockets-seams-lodes-motherlode  
Design: [2026-11-22-hpa-1243-progressive-site-map-design.md](../specs/2026-11-22-hpa-1243-progressive-site-map-design.md)  
Baseline: `main` @ `c5c0a351fcd94881a3c6abf256a07bd6ce2eac09`

**Delivery rule: one ticket, one PR.** The draft PR initially contains only these two planning documents. Implement, test and document on **this same branch and PR**, not in a second implementation PR. No new art or sound; therefore no asset-generation task.

## Reuse / file-change map

| Existing file | Minimal intended change |
| --- | --- |
| `lib/mining/mining_content.dart` | Replace `_denseGridWidth/Height` and `_denseResourceField` with one fixed 8×21, ten-body geometry, mapping each site's four existing Surveying steps across the four bands; leave all economy numbers alone. |
| `lib/mining/presentation/mining_grid_map.dart` | Replace `InteractiveViewer` camera with one vertical scroll and scene scaling; derive band labels/chips and scroll targets, pin one accessible depth rail; retain existing object layers and map taps/semantics. Extend `depositVisualSize(4)`. |
| `lib/mining/presentation/mine_site_screen.dart` | Integrate scrolling viewport/rail without moving existing HUD/dock/nav chrome; reuse existing `viewportInsets` for vertical clearance. Only local changes if needed. |
| `lib/mining/presentation/animated_mining_grid_visual_layer.dart` | Update only if needed for 4×4 frame/HP positioning; leave strike trigger, temporary HP, cargo-stage frames and audio callback logic untouched. |
| `CLAUDE.md` | Replace old 50×50 / 100-body / InteractiveViewer paragraph, and document scope boundary vs later exhaustion/balance tickets. |
| `test/mining/mining_content_test.dart`, `test/mining/mining_grid_test.dart` | Replace dense-field counts/50×50 assumptions and four-*body* Surveying assertions with ten-mine geometry, four-*band* gate and unique-perimeter tests. |
| `test/mining/presentation/mining_grid_map_test.dart`, `test/mining/presentation/mine_site_screen_test.dart` | Replace interactive camera/legacy hardcoded-cell checks with responsive scrolling, rail, lock feedback, hit-target semantics, 4×4 visual rendering and reduced-motion tests. |
| `test/mining/presentation/animated_mining_grid_visual_layer_test.dart` | Verify 4×4 retains the same visual-only hit/HP contract; reuse existing frame warm-up helper. |
| `test/mining/mining_save_repository_test.dart`, `test/mining/mining_controller_test.dart` | Reuse existing invalid-placement / controller deployment suites; add focused new-map recovery + locked/unlocked placement cases where necessary. |
| `test/integration/merge_mining_journey_test.dart`, `test/support/mining_grid_fixtures.dart` | Make the journey/fixtures select legal pocket/band cells from the **new content**; preserve all scripted costs, times and pacing assertions. |

Deliberately **do not change** `MiningSimulation`, `MiningSave`/schema, `MiningController` API, `SiteDeckScreen` or economy data. No new route, abstract scene system, grid legality duplicate, migration layer or asset pipeline.

## Task 1 — Freeze the current behavior in tests; author the ten-mine field

1. Update content topology tests first: 8×21, total ten deposits, {size1:4, size2:3, size3:2, size4:1}, identical geometry across all 15 sites, no overlaps or out-of-bounds cells. Iterate every deposit's cached perimeter, assert at least one **unique** adjacent legal rig cell at its required Surveying level, and check the global site cap 4. Preserve determinism/immutable cached perimeter assertions.
2. Replace tests relying on `site.deposits.take(4)` for the old four progression bodies. Assert each **size band** instead has its site's existing Surveying step and that locked mine placement is rejected centrally. Explicitly cover Landing Basin [0,0,1,2], Frozen Basin [3,3,4,5], and all-5 late sites.
3. In `mining_content.dart` replace the 50×50 ten-by-ten procedural generator with one small constant ordered geometry list (pockets, seams, lodes, Motherlode). Generate each site's ten `MiningDepositDefinition` values with the per-site Surveying step indexed by band. Keep the 15 existing site definitions, art references, costs, rates, storage and `MiningSiteDefinition` cache construction.
4. Run focused content, grid and view-model tests. Avoid introducing another “band unlocked” save field: Surveying levels already suffice. **Do not** introduce future exhaustion gates early.

## Task 2 — Change only the existing grid presenter to scroll

1. Replace the `InteractiveViewer` / `TransformationController` / zoom constants / initial camera math in `MiningGridMap` with a `ScrollController` owned by that same widget state. Keep the current logical 56 dp scene, existing painter, static/animated layer, semantic overlays, grid-tap callback and cavern repeat.
2. Use a finite-width outer `LayoutBuilder`, compute scale = `min(1, availableWidth / 448)`, and present a centered scaled scene of logical 448×1176 inside a sized parent with matching scaled dimensions. Transform child and hit tests together, so a physical tap still reports a logical grid cell and `evaluateMiningPlacement` remains authoritative. At 360 dp, scale 360/448 and cell 45 dp; at landscape/tablet width, cap at 56 dp and center.
3. Preserve vertical scroll clearance for fixed cash/cargo/Sell/dock/navigation controls using the existing Mine Site `viewportInsets`. Do not use its horizontal left/right values to reduce map width; test both orientations, actual safe areas and short landscape viewport heights. Add band labels at gutter rows without hiding legal rig cells.
4. Add the pinned four-node depth rail as a small presenter derived from the ten mine definitions and the current `MineSiteView`'s `isSurveyed`. Each semantic/button node reports band and lock status; tapping any node scrolls to its band, including locked ones. The rail has no full-height pointer-catching scrim. Assert rig targets remain physically reachable via scrolling on narrow phones. Do not make a new navigation screen or controller action.
5. Position the initial viewport on the **highest open band** via one post-layout scroll, clamped for small/large viewports. When switching sites or increasing Surveying enough to open a new band, reframe once; on the shell's one-second refresh keep the player's current scroll offset. Under reduced motion, jump rather than animate; no spring/scale transition.
6. Update grid/screen widget tests to use transformed scene coordinates rather than the removed `mining-grid-interactive` key or hardcoded 50×50 cells. Verify 360×640 / 390×844 / 430×932 / 874×402 / 1024×768 sizes, centering, scroll-only interaction, depth rail, semantics, and real target tap/placement coordinates.

## Task 3 — Presentation parity with the Linear Mine Site mockup

1. Reuse existing per-site node/cavern assets, dark theme and current deposit/rig image layers. Add footprint 4 support to `depositVisualSize` (within 224 logical dp) for both static and animated layers; confirm 4×4 doesn't throw, crop, or mask rig/HP overlays.
2. Show an in-field label for each band and one Surveying requirement chip for a locked band; dim its mines. Example: **“Surveying 1 opens the lodes”**. Keep locked mines visible and keep the 4-stage depth rail accurate after purchasing Surveying.
3. Draw a subtle gold Motherlode glow using Flutter decoration/paint only. Disable the glow and rail scroll animations with the **existing** reduced-motion value. Do not create artwork/SFX, extra animation state owner, real mine HP, exhausted rubble or IDLE copy.
4. Compare browser-MCP screenshots against **HPA-1243 map-mockup.png frames A–C**, at initial, intermediate and late gate states. Match four-band hierarchy, labels, rail, locked look, Motherlode emphasis and stable chrome at portrait/landscape sizes. Treat frame D and mockup's exhaustion/IDLE/HP numbers as **HPA-1244 / HPA-1241** context, not targets for this PR.

## Task 4 — Preserve save boundary, placement and full journey

1. Run/extend controller+repository tests proving one rig still mines its one unique orthogonally adjacent unlocked body; locked placement rejects; more than four site rigs rejects; new-grid placements save/reload unchanged; an old off-field rig causes the existing recovered-load reset. No migration/schema change.
2. Adapt only legal cell selection in `test/support/mining_grid_fixtures.dart` and `merge_mining_journey_test.dart` (prefer helper-generated legal cells over hardcoded pre-change coordinates). Retain the journey's entire public-action flow: fresh start, Surveying purchases, commission/sell/upgrade/travel through Io, single reward, relaunch and a faster second run on injected clock.
3. Keep *every pre-existing pacing band, rate, storage window, price and milestone expectation*. If the map change perturbs journey timing, fix the placement/test path or unintended state logic; do **not** tune numeric content (HPA-1244 owns that).
4. Update only the current Mine Site paragraph in `CLAUDE.md`; keep historical specs/docs and unrelated subsystems untouched.

## Task 5 — Repository and MCP end-to-end verification

### Focused/automated tests

- First run: `flutter test test/mining/mining_content_test.dart test/mining/mining_grid_test.dart`; then updated Mine Site view, screen/map, animated layer, repository, controller and journey tests. Use existing test font/asset helpers and injected clocks. Refresh any expectations that hardcode 50×50, 100 resources, old object keys or `InteractiveViewer`, not unrelated goldens.
- Full repository gates from `CLAUDE.md`:
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze --fatal-infos`
  - `flutter test`
  - `flutter test --coverage`
  - `flutter test --platform chrome`
  - `flutter build apk --debug`
  - `flutter build web`
  - `flutter build ios --simulator --debug` (on macOS-capable runner)
- Record **actual** outcomes in the PR; report an unavailable platform as blocked/not run, never as a pass. Preserve known stale/disabled golden tests rather than claiming visual parity from a skipped test.

### One MCP-driven Flutter web E2E (sufficient platform coverage)

Using browser automation through MCP, open a fresh-save Flutter web build at 390×844 and exercise **one complete, real UI workflow**:

1. Enter Landing Basin. Assert four bands/ten deposits and initial bottom-to-top layout, with two bands open at Surveying 0. Screenshot the initial state for visual comparison to **Linear frame A's map structure** (its exhaustion wording/HP is deliberately out of scope).
2. Spawn/select a T1 rig and tap a legal pocket perimeter cell. Assert a placed rig, its accessible tier chip and producing site rate. Attempt a locked lode cell and verify it is rejected without losing the rig.
3. Open Technology and buy Surveying 1 through the existing UI. Return to/current Mine Site; assert **lodes** unlocked without re-entering the site, inspect the depth rail, tap a node, scroll vertically to the Motherlode, then to the new open band. Verify no pinch/horizontal pan.
4. Tap an unlocked lode perimeter cell with a selected rig; assert deployable geometry and normal controller feedback. Sell cargo, reload, revisit and verify saved rigs/cargo as appropriate.
5. Capture screenshots at Surveying 0, 1, 2 on 390×844 and one 874×402 or wider view; compare visually against **Linear frames A–C** for layout, rail, locked contrast, glow, chrome and responsive widths. Verify reduced-motion rail taps **jump** (no animation) and every needed control remains reachable.
6. Keep screenshots/videos as verification artifacts **outside the tracked repo**. One browser/web e2e is enough; no native app acceptance is required because this ticket makes no native-specific change.

### Automated end-to-end acceptance checklist

- [ ] 15 identical ten-deposit site layouts, correct dimensions/band counts/unique legal placements, four original Surveying band gates.
- [ ] Scroll-only responsive map; ≥44 dp cells on 360 dp phone, ≤56 dp wide; center landscape/tablet; accessibility semantics and direct cell taps work after scrolling.
- [ ] Rail navigation, locked labels and live research unlocks verified by widget tests and MCP browser UI.
- [ ] Animated & static 4×4 Motherlode render correctly; reduced motion disables glow/animated scrolling; old off-field save recovers.
- [ ] Visual screenshot comparison against attached **HPA-1243 frames A–C** completed and evidenced, excluding later-ticket features.
- [ ] MCP web e2e verifies fresh-save spawn → place → reject lock → research → rail → place → sell → reload.
- [ ] Public-action journey remains green under its injected clock for both cadences and relaunch, with unchanged pacing bands/economy.
- [ ] All applicable `CLAUDE.md` gates pass or are individually documented as blocked/not run; no human-approval criterion.

**PR discipline:** after plan review, amend this same draft PR with implementation and test commits. Do not open a second PR for HPA-1243. Do not merge a planning-only PR as if the outcome were implemented.
