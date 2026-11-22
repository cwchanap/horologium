# HPA-1243 — Progressive Mine Site map (design specification)

Linear: https://linear.app/cwchanap/issue/HPA-1243/mining-map-progressive-site-map-pockets-seams-lodes-motherlode  
Baseline: `main` @ `c5c0a351fcd94881a3c6abf256a07bd6ce2eac09` (2026-11-22)  
Visual reference: HPA-1243 attached `map-mockup.png` (Mine Site frames A–C) and self-contained HTML. Frame D belongs to HPA-1244.  
Delivery: **one draft PR for the ticket**, initially planning-only; future implementation commits go into this very PR.

## Outcome and strict scope

Replace the generated 50×50 / 100-deposit Mine Site field on **all fifteen sites** with the same compact, vertically navigable 8×21 / ten-mine map. The player sees pockets at the bottom, then seams, lodes and the Motherlode at the top. Locked bands remain visible and explain the *existing* Surveying requirement. A four-stop depth rail navigates between bands. The map fits the width of a phone, and scrolling (not pinch-zoom or free pan) exposes its height.

**Preserve the economy, controller actions, shared storage, rig rules, save shape, commissioning/mastery, tech prices, and public-action journey timing.** Size is presentation only here. HPA-1241 implements real HP/exhaustion/refill, HPA-1240 drag/drop and move, and HPA-1244 yield/HP economics, band-exhaustion gates and Site Deck depth. No painted art or sound is needed.

## Evidence and reuse audit on main

| Existing owner | Keep / adapt |
| --- | --- |
| `lib/mining/mining_content.dart` | `_denseResourceField` authors 100 bodies keyed by site; `_surveyingProgressionLevels` already has four levels per site. Replace only geometry generation; keep the per-site levels, site definitions and numeric content unchanged. |
| `lib/mining/mining_grid.dart` | `evaluateMiningPlacement`, `uniqueAdjacentDeposit` and `miningPerimeterCells` are the **one** placement/adjacency contract. Reuse unchanged; geometry must satisfy it. |
| `lib/mining/mine_site_view.dart` | `MineSiteView.from` already derives `isSurveyed`, unique target, perimeter slots, deployable cells and semantic feedback from definitions. Use these; do not create a second lock/placement state owner. |
| `lib/mining/presentation/mining_grid_map.dart` | `MiningGridMap` already owns map painting, semantic overlays, tap translation and animated-vs-static layer selection. Replace the `InteractiveViewer` camera with one vertical scroll; retain those overlays. |
| `lib/mining/presentation/mine_site_screen.dart` | Preserve existing HUD, sell, dock, navigation, safe-area and portrait/landscape chrome; the cavern owns the map viewport. |
| `lib/mining/presentation/animated_mining_grid_visual_layer.dart` | The three approved animated sites are Landing Basin, Carbon Ridge and Frozen Basin. Keep transient strike HP and cargo-stage frames until HPA-1241; handle 4×4 sizing without adding an economy clock. |
| `lib/mining/mining_save_repository.dart` | Strict validation already rejects grid-outside / invalid persisted placements and triggers recovered-load behavior. Do not add migration or schema/version fields. |
| `test/integration/merge_mining_journey_test.dart` | Public-action progression under injected time is the pacing oracle; update only placement selection, not its economics or milestones. |

One concrete required fix: `depositVisualSize` currently throws for footprint 4. Support the 4×4 Motherlode explicitly in the **existing** visual helper; preserve its existing 1–3 sizes and asset families.

## Decision 1 — one stable layout and four band definitions

Coordinates are logical (column, row, square size), row 0 at the top. Author this geometry **once** and reuse it across sites:

| Band, low → high | Geometry `(x, y, size)` | Surveying requirement |
| --- | --- | --- |
| Pockets (4 × 1×1) | `(0,19,1)` `(2,19,1)` `(5,19,1)` `(7,19,1)` | The site's existing step 0 |
| Seams (3 × 2×2) | `(0,14,2)` `(3,14,2)` `(6,14,2)` | Existing step 1 |
| Lodes (2 × 3×3) | `(0,8,3)` `(5,8,3)` | Existing step 2 |
| Motherlode (1 × 4×4) | `(2,1,4)` | Existing step 3 |

The 8×21 canvas leaves gutter rows for clear band titles. No mines overlap or extend out of bounds. Expose bands in stable **pockets → seams → lodes → Motherlode** progression order regardless of top-to-bottom painted order; future per-mine save state can use authored deposit order. A small immutable layout constant and derived labels/anchors are enough: do not add a configurable map engine, site-specific copy of the layout, persisted band state or a new repository.

Required Surveying remains **[0,0,1,2] for Landing Basin**, **[3,3,4,5] for Frozen Basin** and each site's existing four-tuple for the rest. For the 12 sites with all four steps at Surveying 5, all bands are open at that level. A locked band uses one dim overlay/chip per band, not ten individual lock badges. The chip says, e.g., **“Surveying 1 opens the lodes”**, not “Exhaust 2 pockets” (reserved for HPA-1244). Each mine remains uniquely reachable by at least one legal orthogonally adjacent cell; assert this over all sites. Existing site cap of 4 rigs and the rule that a rig targets exactly one mine stay unchanged.

## Decision 2 — width-fit scroll, not an alternative camera system

Keep one `MiningGridMap` StatefulWidget. Replace `InteractiveViewer` / `TransformationController` with a single `ScrollController` and vertical `SingleChildScrollView`; no horizontal pan, pinch zoom or gesture-mode toggle.

Reuse the current **56 dp logical cell** in existing static/animated painters and gesture coordinates. Scale the **entire scene** uniformly to `min(1.0, availableWidth / (8 × 56))` and give the surrounding sized box the **scaled** width/height. This preserves all existing logical cell math, painting and hit-test transforms without rewriting every painter. At 360 dp available width the displayed cell is 45 dp (≥44); at widths ≥448 dp it is capped at 56 dp and the map is centered. Do **not** subtract the existing left/right HUD clearance from the scene width, which would unnecessarily shrink the 360 dp case. Reserve the existing `viewportInsets`' vertical top/bottom chrome clearances in the scroll extent / target positioning, so cells and controls can be scrolled out from behind fixed HUD/dock overlays.

The four-node depth rail sits at the viewport's **right edge**, reflects unlocked/locked states derived from `MineSiteView` and uses normal accessible tap/semantic actions to scroll to the corresponding band. On narrow phones it may overlay a small edge strip, but only its actual node hit targets intercept taps; no permanently opaque rail may make an otherwise legal rig cell unreachable. Prove that cells behind the rail can be reached by scrolling. The initial scroll frames the **highest Surveying-unlocked band** (the furthest open band from the dock). Clamp to valid extents and visibly preserve the playable lower band. A new site / newly unlocked band can reframe once; an ordinary one-second `MineSiteView` refresh must **not** reset the user's scroll. Rail taps scroll smoothly normally and jump without animation under `reducedMotion` / `MediaQuery.disableAnimations`.

Keep scene-level tap positions mapped back to integer logical grid coordinates using the transformed child and `miningGridCellSize`; do not multiply by scaling twice. Keep rig/accessibility semantics and the existing controller callback flow.

## Decision 3 — present the authored hierarchy with existing assets

- Label each band in its empty gutter row: **POCKETS / SEAMS / LODES / MOTHERLODE**; show which band is open on the rail. Use existing dark/mining theme typography and contrast. Keep cavern art repeating behind the whole map.
- Render locked-band mines dimmed, retaining their visible silhouettes. Put **one** explicit Surveying requirement chip per locked band. Researching that level recomputes the view and reveals the band without closing/reopening the site.
- Use current static node art for static sites and current approved frame families for the 3 animated sites. Add `4 => 224` (or smaller within the 224 dp logical footprint) to `depositVisualSize` and test animated/static rendering of 4×4. Keep the existing transient visual HP and impact SFX rules; no new resource-health state and no HPA-1241 exhausted/IDLE presentation.
- The Motherlode has a small code-drawn gold halo/glow, disabled in reduced motion; do not add PNGs, shaders, particle systems, frame families or SFX.
- Non-grid Mine Site HUD, Fleet Dock, Site Deck, Technology and navigation do not change. Frame D from the attached mockup is specifically **out of scope**.

## Decision 4 — preserve gameplay and recovery

No changes to `MiningController`'s public actions, `MiningSimulation`, price/rate/capacity formulas, `MiningSave`, save JSON root/site keys, technology gates or commissioned flags. A rig deployed beside an unlocked deposit produces exactly as it does on main; geometry merely changes which cells are legal. The existing strict save decoder rejects an old placement if it no longer fits the new geometry, then clean-resets with recovered-load status. Do not write a special migration or backward-compatibility path. New saves must round-trip normally.

## Trade-offs and rejected alternatives

- Recoloring 100 bodies retains needless visual noise and free panning.
- Fifteen bespoke layouts produce extra authoring/tests with no payoff.
- An intervening world-map screen adds taps.
- New generic map/scene framework, state store or alternate placement evaluator duplicates proven code.
- Adding HP, refill, ore multipliers, exhaustion gate or extra art here would overlap HPA-1241/HPA-1244 and break the single-ticket scope.

## Acceptance contract (automated; no manual sign-off)

1. **Topology:** all 15 sites use exactly the same in-bounds 8×21 map and ten unique deposits (4×1, 3×2, 2×3, 1×4) in stable authored order. Each has legal unique perimeters; four Surveying steps map by band, not by individual mine.
2. **Presentation:** 360×640, 390×844 and 430×932 portrait; 874×402 landscape; and a tablet-width viewport fit horizontally with zero pinch/free-pan. Displayed cell ≥44 dp at 360 dp, ≤56 dp at wide sizes. Landscape/tablet canvas is centered.
3. **Interaction:** deterministic initial framing at highest unlocked band; depth rail jumps to all four bands, announces lock status and remains keyboard/semantic operable; no one-second recenter; locked bands cannot accept rigs; researching Surveying reveals the right band live; every legal target can be tapped after scrolling.
4. **Visual:** browser-MCP screenshots of Mine Site at initial, intermediate and late Surveying states visually compared to the attached HPA-1243 **frames A–C** for layout, depth rail, labels, dimming, Motherlode glow and responsive chrome. Explicitly ignore “Exhaust 2 pockets”, true HP/IDLE and frame D: later tickets own those. No overflow/intersections or masked required controls.
5. **Animation/recovery:** existing animated sites still strike and show transient HP including 4×4; static sites remain static; reduced motion stops glow/animated rail movement. Off-field saved rig clean-recovers; new-layout save round-trips. No save migration.
6. **Economy:** journey controller-action test under injected time passes **unchanged pacing bands and milestones** for both visit cadences and relaunch. Rates, capacity, site/planet costs, Surveying, unlock/mastery, rewards and storage alert timing are unchanged.
7. **End to end:** MCP-driven browser automation of **Flutter web** on one platform, with a fresh save, places a rig on a pocket, rejects locked-band placement, researches Surveying, verifies the band opens, navigates with the depth rail, places on an unlocked band, sells, reloads, and checks persisted actions. Collect screenshots as test evidence, not committed artwork. Mobile-native e2e is unnecessary absent platform-specific behavior.
8. **Repo gates:** all commands in `CLAUDE.md` run as applicable: format, analyze, Flutter VM tests, coverage, Chrome tests, APK/web/iOS simulator builds. Record actual pass/fail/blocked results; do not pre-claim a pass.

## Documentation update

After implementation, update `CLAUDE.md`'s current “Mine Site is an InteractiveViewer over a deterministic 50×50 grid” paragraph to the new deterministic 8×21 ten-mine scroll map. Leave historical specs untouched.
