# HPA-1243 — Progressive Mine Site map (design specification)

Linear: https://linear.app/cwchanap/issue/HPA-1243/mining-map-progressive-site-map-pockets-seams-lodes-motherlode  
Baseline: `main` @ `c5c0a351fcd94881a3c6abf256a07bd6ce2eac09` (2026-11-22)  
Visual reference: HPA-1243 attached `map-mockup.png` (Mine Site frames A–C) and self-contained HTML. Frame D belongs to HPA-1244.  
Delivery: **one draft PR for the ticket**, initially planning-only; future implementation commits go into this very PR.

## Outcome and strict scope

Replace the generated 50×50 / 100-deposit Mine Site field on **all fifteen sites** with the same compact, vertically navigable 8×22 / ten-mine map. The player sees pockets at the bottom, then seams, lodes and the Motherlode at the top. Locked bands remain visible and explain the *existing* Surveying requirement. A four-stop depth rail navigates between bands. The map fits the width of a phone, and scrolling (not pinch-zoom or free pan) exposes its height.

**Preserve the economy, controller actions, shared storage, rig rules, save shape, commissioning/mastery, tech prices, and public-action journey timing.** Size is presentation only here. HPA-1241 implements real HP/exhaustion/refill, HPA-1240 drag/drop and move, and HPA-1244 yield/HP economics, band-exhaustion gates and Site Deck depth. No painted art or sound is needed.

## Evidence and reuse audit on main

| Existing owner | Keep / adapt |
| --- | --- |
| `lib/mining/mining_content.dart` | `_denseResourceField` authors 100 bodies keyed by site; `_surveyingProgressionLevels` already has four levels per site. Replace only geometry generation; keep the per-site levels, site definitions and numeric content unchanged. |
| `lib/mining/mining_grid.dart` | Retain `evaluateMiningPlacement`, `uniqueAdjacentDeposit` and `miningPerimeterCells` as the **only** placement/adjacency contract. Add one small `miningPlacementRejectionMessage` helper so expected ambiguous cells produce normal UI/controller feedback, not exceptions. |
| `lib/mining/mine_site_view.dart` and `lib/mining/mining_controller.dart` | Keep all existing actions and state ownership. Replace their duplicate `StateError` handling for `ambiguousAdjacentDeposit` with the shared rejection message; `MineSiteView` wraps it as a blocked tap, controller returns an ordinary failed action. |
| `lib/mining/presentation/mining_grid_map.dart` | `MiningGridMap` already owns map painting, semantic overlays, tap translation and animated-vs-static layer selection. Replace the `InteractiveViewer` camera with one vertical scroll; retain those overlays. |
| `lib/mining/presentation/mine_site_screen.dart` | Preserve HUD/Sell/dock/nav layout, but compute portrait scroll clearance from existing `portraitMineSellTop` (including text scale) and bound depth-rail buttons between cargo and Sell/bottom chrome; current portrait `viewportInsets.bottom` accounts for dock/nav but **not** Sell. |
| `lib/mining/presentation/animated_mining_grid_visual_layer.dart` | The three approved animated sites are Landing Basin, Carbon Ridge and Frozen Basin. Keep transient strike HP and cargo-stage frames until HPA-1241; handle 4×4 sizing without adding an economy clock. |
| `lib/mining/mining_save_repository.dart` | Strict validation already rejects grid-outside / invalid persisted placements and triggers recovered-load behavior. Do not add migration or schema/version fields. |
| `test/mining/presentation/mining_shell_harness.dart` | Shared `tapGridCell` hardcodes `50 * miningGridCellSize` and pans `mining-grid-interactive`. Replace it **once in the atomic cutover** with a scroll-to-cell tap; do not first make a throwaway InteractiveViewer-width edit. `_cellPoint` in `mine_site_screen_test.dart` needs the same direct scroll update. |
| `test/mining/mine_site_view_test.dart`, `test/mining/presentation/mining_shell_test.dart`, `test/mining/mining_controller_test.dart`, `test/mining/mining_save_repository_test.dart`, `test/mining/presentation/animated_mining_grid_visual_layer_test.dart` | Their hardcoded cells such as `(3,2)`, `(4,2)`, `(2,3)` and `deposits[2]/[3]` are invalid or change meaning on the new map. **Pre-migrate** geometry-coupled fixtures to existing content-derived helpers while the 50×50 implementation is still green. |
| `test/integration/merge_mining_journey_test.dart` | Public-action progression under injected time is the pacing oracle. It already finds legal cells through `firstPlayableCell` / `deployableMiningCells`, so **run it unchanged** and require zero timing/regression diff. |

One concrete required fix: `depositVisualSize` currently throws for footprint 4. Support the 4×4 Motherlode explicitly in the **existing** visual helper; preserve its existing 1–3 sizes and asset families.

## Decision 1 — one stable typed layout, four bands and four clear label rows

A closed `enum MiningBand { pockets, seams, lodes, motherlode }` in `mining_content.dart` is the **single band identity** for content, UI, tests and later HPA-1244. Give it a display label and an authored label-row coordinate. Keep **one** immutable geometry map keyed by `MiningBand`, plus one **non-UI** lookup `bandForDeposit(MiningDepositDefinition)` derived from the author's unique footprint sizes 1–4. This avoids an extra stored field on `MiningDepositDefinition`, a second interpretation in the widget, a custom registry, and all schema/state changes. Its values are progression-ordered (pockets → seams → lodes → Motherlode), independent of the visual top-to-bottom order.

The field is **8 columns × 22 rows**, row 0 at the top. This uses the ticket's allowed approximate geometry, adding one label row to remove the collision in the original 8×21 proposal. The exact authored geometry is:

| Band, low → high | Geometry `(x, y, size)` | Full-width label row | Surveying requirement |
| --- | --- | --- | --- |
| Pockets (4 × 1×1) | `(0,20,1)` `(2,20,1)` `(5,20,1)` `(7,20,1)` | 18 | Existing step 0 |
| Seams (3 × 2×2) | `(0,15,2)` `(3,15,2)` `(6,15,2)` | 13 | Existing step 1 |
| Lodes (2 × 3×3) | `(0,9,3)` `(5,9,3)` | 7 | Existing step 2 |
| Motherlode (1 × 4×4) | `(2,2,4)` | 0 | Existing step 3 |

Every label row (0, 7, 13, 18) is entirely clear of **both deposits and all legal unique rig-perimeter cells**. The 22nd row keeps bottom pocket perimeters in bounds. The map keeps every mine's **unique legal perimeter** intact and no deposits overlap. **Six intentionally unplaceable empty cells are adjacent to two mines**, however: pockets `(1,20)` and `(6,20)`; seams `(2,15)`, `(2,16)`, `(5,15)`, `(5,16)`. These are ordinary **ambiguous-adjacency placement rejections**, never deployable slots and never fatal authoring errors. Do not widen or stagger the compact bands just to eliminate these harmless gaps. Derive `requiredSurveyingLevel` from `_surveyingProgressionLevels[siteId]![band.index]`; retain the existing per-deposit field as the **only** placement-legality input. No persisted unlock flags.

Landing Basin remains `[0,0,1,2]`, Frozen Basin `[3,3,4,5]` and Titanium Highlands `[4,4,5,5]`. **Ten** late sites have all four steps at Surveying 5; when they unlock, all four bands are already open, no lock chip is shown, and first framing targets the Motherlode. A locked band shows dimmed mines and one chip reading the required Surveying level (for example, **“Surveying 1 opens the lodes”**); do not introduce HPA-1244's later “Exhaust 2 pockets” wording. The current site limit of four rigs and each rig's unique orthogonal target remain unchanged.

Keep this to an enum, its label/row, one geometry constant and one lookup. No configurable map engine, per-site layout copies, new controller state or extra save data.

## Decision 2 — a native vertical scroll with Flutter's existing scaling

Keep one `MiningGridMap` StatefulWidget. Replace `InteractiveViewer` / `TransformationController` with a `ScrollController` and `SingleChildScrollView`: scrolling vertically reveals the full map, while pinch zoom, free pan and horizontal scroll go away.

Use Flutter's built-in `FittedBox(fit: BoxFit.scaleDown)`, centered inside the width-constrained scroll content, around the logical `SizedBox(width: 8 × 56, height: 22 × 56)`. This uniformly scales the **entire scene**, including painter, labels, overlays and pointer transformation, without hand-building matrices or separately scaling hit tests. **Scroll offsets must be scaled**: the visual top of row `y` is `topPadding + y * 56 * min(1, availableWidth / 448)` rather than `topPadding + y * 56`. Use this when clamping `_scrollToBand` targets at phone widths. The fixed logical `miningGridCellSize = 56` and existing map-level `onTapUp` local position conversion remain authoritative. At 360 dp of map width, displayed cells are 45 dp (≥44); at viewport widths ≥448 dp, they stay ≤56 dp and the scene is centered. **Do not subtract the existing HUD's horizontal left/right clearance from available map width** or make a second zoom state. Verify `FittedBox` constraints, scroll extent and logical hit testing under the actual Flutter widget tests, rather than assuming the layout.

Pass only **vertical** clearance into `MiningGridMap`, but **increase portrait bottom padding beyond the current dock/nav-only inset**: in `MineSiteScreen`, derive the Sell panel's top via the already-shared `portraitMineSellTop(height, bottomInset, textScaler)` and reserve enough scroll extent to move bottom-row rig `(7,21)` **above Sell**, including 1.3× text scale and bottom safe-area. Landscape keeps its existing chrome clearance. Do not shrink scene width or rely on the old horizontal pan. A test must physically tap `(7,21)` at the scroll limit on 360×640, 390×844 and 430×932.

Four small depth-rail buttons sit on the viewport's right edge and reflect `MiningBand` / `MineSiteView`'s Surveying-derived lock state. **Constrain their vertical hit regions** between the cargo gauge bottom and Sell top (portrait), and between cargo gauge bottom and the bottom safe area (landscape); scale the gaps, not the minimum actionable tap targets, on a short screen. Only actual buttons intercept pointers, and the rest of the rail is pass-through. Assert no overlap with real cash/cargo/Sell/dock/nav rectangles at **360×640 / 1.3 text scale** and **874×402**, then prove right-edge legal cell taps remain reachable.

**Frame once**, after the scroll controller has laid out, at the **highest open band**; clamp the offset to valid scroll extents. Reuse a single `_scrollToBand(MiningBand, {required bool animate})` function for that initial jump and depth-rail taps. Remove old `_initialFocus`/rig-bounding-box focus and `_initialCamera` entirely. On a newly opened band **do not** auto-reframe; its rail becomes enabled/updated and the player may tap it. New site entry creates a fresh keyed state, while the one-second screen refresh preserves current scroll by construction. Rail buttons animate scroll normally and use `jumpTo` under `reducedMotion` / `MediaQuery.disableAnimations`.

## Decision 3 — present the authored hierarchy with existing assets

- Put the four band labels **only** on the dedicated, non-interactive gutter rows 0, 7, 13 and 18; labels and locked-band chips are `IgnorePointer` overlays, with accessible rail labels separately. **Move the repeating cavern `Image.asset` out of the 448×1232 logical scene and behind the whole `SingleChildScrollView`** inside `MiningGridMap`. This keeps the background full-bleed on tablets/landscape and behind vertical scroll padding rather than exposing flat dark side bars.
- Dim mines in locked bands while retaining their silhouettes, and render **one** Surveying requirement chip per locked band. Reading the current `MineSiteView` after buying Surveying makes that band usable without leaving the site. For the ten all-5 late sites, there are no locked chips at their unlock level.
- Reuse the existing node/cavern art and the three approved frame families. Add explicit `4 => 224` footprint support to `depositVisualSize` so the 4×4 Motherlode works in the static and animated layers; verify that overlays, rig/HP labels and hit regions stay visible.
- Render the Motherlode's gold emphasis **once in `MiningGridMap`'s scene Stack, behind `_objectLayer()`**, as a static code-drawn `BoxShadow` or radial-gradient halo. That covers both the static and animated site layers without duplicate halo code or a ticker. Hide it under reduced motion; rail scrolls jump in that mode.
- Keep transient visual strike HP, cargo-driven frame stage and existing SFX/impact ownership on animated sites unchanged until HPA-1241. No real HP, exhausted/IDLE state, new sprites, shaders, particle system or new audio.
- Keep Site Deck, Sell, Technology, Fleet Dock, navigation and the existing Mine Site chrome unchanged. Mockup frame D belongs to HPA-1244.

## Decision 4 — preserve gameplay and recovery

No changes to `MiningController`'s **public actions or state ownership**, `MiningSimulation`, price/rate/capacity formulas, `MiningSave`, save JSON root/site keys, technology gates or commissioned flags. The **one small internal controller change** is to reuse the shared placement-rejection message rather than throw on valid ambiguous gaps. A rig deployed beside an unlocked deposit produces exactly as it does on main; geometry merely changes which cells are legal. Specifically, `MiningPlacementRejection.ambiguousAdjacentDeposit` maps to **“Place the rig next to a single resource.”** in one shared `miningPlacementRejectionMessage(MiningPlacementResult)` function in `mining_grid.dart`; `MineSiteView.gridTapOutcome` returns a blocked tap, and `MiningController.deployRig` returns a normal failure with no mutation. Keep `evaluateMiningPlacement` itself unchanged. The existing strict save decoder rejects an old placement if it no longer fits the new geometry, then clean-resets with recovered-load status. Do not write a special migration or backward-compatibility path. New saves must round-trip normally.

## Trade-offs and rejected alternatives

- Recoloring 100 bodies retains needless visual noise and free panning.
- Fifteen bespoke layouts produce extra authoring/tests with no payoff.
- An intervening world-map screen adds taps.
- New generic map/scene framework, state store or alternate placement evaluator duplicates proven code.
- Adding HP, refill, ore multipliers, exhaustion gate or extra art here would overlap HPA-1241/HPA-1244 and break the single-ticket scope.

## Acceptance contract (automated; no manual sign-off)

1. **Topology:** all 15 sites use the same in-bounds 8×22 / ten-mine layout (4×1, 3×2, 2×3, 1×4) in stable order, with unique legal perimeters (at least four cells at each site's unlock level), correct Surveying-by-band and collision-free label rows 0/7/13/18. The **six shared-adjacency cells** are expected, never deployable and never crash. Test view and controller rejections specifically at `(1,20)` and `(2,15)`.
2. **Presentation:** 360×640, 390×844 and 430×932 portrait; 874×402 landscape; and a tablet-width viewport fit horizontally with zero pinch/free-pan. Displayed cell ≥44 dp at 360 dp, ≤56 dp at wide sizes. Landscape/tablet canvas is centered.
3. **Interaction:** frame **only on entry** at the highest open band using **scale-aware scroll targets**; a research unlock refreshes rail/locks without stealing scroll. Depth rail navigates to all four bands, remains keyboard/semantic operable and **does not overlap HUD/Sell** at 360×640 / text scale 1.3 or 874×402. Locked or ambiguous cells reject normally. Every legal target, **especially bottom-right `(7,21)` above Sell**, stays physically tappable at the maximum portrait scroll on 360×640, 390×844 and 430×932. Shell tap helpers use real scroll mechanics, not the removed 50×50 viewer.
4. **Visual:** MCP-browser screenshots of Mine Site at Surveying 0/1/2 and landscape captured and compared to HPA-1243 **frames A–C** for full-bleed cavern backdrop (including tablet side margins and scroll padding), layout, depth rail, labels, dimming, single Motherlode glow and responsive chrome. Explicitly ignore “Exhaust 2 pockets”, true HP/IDLE and frame D: later tickets own those. No overflow/intersections or masked required controls.
5. **Animation/recovery:** existing animated sites still strike and show transient HP including 4×4; static sites remain static; reduced motion stops glow/animated rail movement. Off-field saved rig clean-recovers; new-layout save round-trips. No save migration.
6. **Economy:** existing journey controller-action test runs **without changes** under injected time and passes **unchanged pacing bands and milestones** for both visit cadences and relaunch. Rates, capacity, site/planet costs, Surveying, unlock/mastery, rewards and storage alert timing are unchanged.
7. **End to end:** cover the full spawn → pocket deploy → **ambiguous-cell rejection** → locked lode rejection → Surveying 1 purchase → rail → lode deploy → sell/reload flow in **one reusable MiningShell widget test**. Also perform **one short MCP-driven Flutter-web E2E smoke** on a fresh save to prove real-screen touch/navigation/screenshot integration on a single platform. Record actual result and capture screenshot evidence without committing artifacts; no native acceptance is needed absent platform-specific changes.
8. **Repo gates:** all commands in `CLAUDE.md` run as applicable: format, analyze, Flutter VM tests, coverage, Chrome tests, APK/web/iOS simulator builds. Record actual pass/fail/blocked results; do not pre-claim a pass.

## Documentation update

After implementation, update `CLAUDE.md`'s current “Mine Site is an InteractiveViewer over a deterministic 50×50 grid” paragraph to the new deterministic 8×22 ten-mine scroll map. Leave historical specs untouched.
