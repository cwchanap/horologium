# HPA-1243 — Implementation plan: progressive Mine Site map

Linear: https://linear.app/cwchanap/issue/HPA-1243/mining-map-progressive-site-map-pockets-seams-lodes-motherlode  
Design: [2026-11-22-hpa-1243-progressive-site-map-design.md](../specs/2026-11-22-hpa-1243-progressive-site-map-design.md)  
Baseline: `main` @ `c5c0a351fcd94881a3c6abf256a07bd6ce2eac09`

**One Linear ticket, one draft PR.** This PR contains planning first; implement and test on **the same PR #57**, with no second implementation PR. No new art/SFX assets or separate generation work.

## Reuse map and implementation boundaries

| Existing file | Minimal work |
| --- | --- |
| `lib/mining/mining_content.dart` | Add closed `MiningBand` enum (label + row), shared deposit-to-band lookup, and one immutable 8×22 map authored by band. Reuse each site's four Surveying levels. |
| `lib/mining/mining_grid.dart` | Leave `evaluateMiningPlacement` and `uniqueAdjacentDeposit` legality unchanged; add one `miningPlacementRejectionMessage` mapping to make the six ambiguous cells a normal user-facing rejection, shared by view/controller. |
| `lib/mining/mine_site_view.dart`, `lib/mining/mining_controller.dart` | Preserve all actions/state ownership; replace their duplicate `StateError` on ambiguous adjacency with the shared rejection helper. Keep `isSurveyed` as the only view-level lock truth. |
| `lib/mining/presentation/mining_grid_map.dart` | Full-bleed cavern image **behind** vertical scroll, centered `FittedBox(scaleDown)`, scale-correct rail scroll targets, labels/chips/dimming and one static Motherlode glow behind `_objectLayer()`; preserve logical tap coordinates and visual layers. |
| `lib/mining/presentation/mine_site_screen.dart` | Derive portrait bottom scroll clearance from existing `portraitMineSellTop` with actual text scale, not dock/nav alone. Constrain depth rail vertically to avoid cargo, Sell, toolbar and safe-area regions; preserve their layout. |
| `lib/mining/presentation/animated_mining_grid_visual_layer.dart` | **Only if necessary** for 4×4 bounds. Keep transient HP and impacts visual-only. |
| `test/mining/presentation/mining_shell_harness.dart` | **One update in Task 2**: replace hardcoded 50 / InteractiveViewer dragging with content-width-based scroll-to-cell tap, preserving its ~27 call sites. No throwaway intermediate edit. |
| `test/mining/presentation/mine_site_screen_test.dart` | Replace `_cellPoint`'s hardcoded 50 and pan/zoom with scrolling in Task 2; assert `(7,21)` clears portrait Sell and depth rail clears HUD rectangles. |
| `test/mining/mining_content_test.dart`, `test/mining/mining_grid_test.dart` | Fixed map topology/Surveying/labels; replace the old `adjacent.length <= 1` assertion with explicit **six expected ambiguous cells**, never deployable, while every mine still has unique legal perimeter cells. |
| `test/mining/presentation/mining_grid_map_test.dart`, `test/mining/presentation/mine_site_screen_test.dart` | Replace hardcoded `(3,2)`/old camera assumptions; verify scale-aware scroll, full-bleed backdrop, rail/HUD collision geometry, Sell clearance, hit tests, live Surveying gates, 4×4 art and reduced motion. |
| `test/mining/presentation/mining_shell_test.dart` | **One reusable full UI case**: spawn → pocket deploy → ambiguous rejection → lock rejection → Surveying research → rail → lode deploy → sell/reload. Prepare existing hardcoded rig cells in Task 1. |
| `test/mining/mine_site_view_test.dart`, `test/mining/mining_controller_test.dart`, `test/mining/mining_save_repository_test.dart` | **Task 1:** change fixture cells and old `deposits[2]/[3]` assumptions to content-derived legal targets. **Task 2:** test both view and controller ambiguous-cell rejection with no throw/mutation, plus save recovery. |
| `test/mining/presentation/animated_mining_grid_visual_layer_test.dart` | **Task 1:** remove hardcoded `(2,3)` and geometric `_minedDeposit` assumptions; keep intent of existing animation tests through content-derived deposit and rig selections. **Task 2:** update old 50×50-specific graphics tests alongside the presenter. |
| `test/integration/merge_mining_journey_test.dart`, `test/support/mining_grid_fixtures.dart` | **Do not edit.** These already query legal cells from authored content. Run the existing journey unchanged as the pacing oracle. |
| `CLAUDE.md` | Update only active Mine Site paragraph after implementation; leave historical specs intact. |

Do not change the **public** `MiningController` API, `MiningSimulation`, `MiningSave` JSON/schema, costs, rates, capacity, commissioning/mastery, Surveying price gates, Site Deck or alerts. The only internal controller/view adjustment is to reuse the shared rejection message for ambiguous adjacency (normal failure, never `StateError`). No new controller action, generic map engine, migration or band-unlocked save field.

## Task 1 — Durable test-fixture preparation while the old map is still green

1. Migrate **hardcoded legal rig coordinates** in existing tests to the already-shared helpers in `test/support/mining_grid_fixtures.dart` (`firstPlayableCell`, `deployableMiningCells`) or a focused content-derived lookup. This includes `mine_site_view_test.dart`'s many `(3,2)` / `(4,2)` fixtures; `mining_shell_test.dart`'s `landingRigCell` / `frozenRigCell`; `mining_save_repository_test.dart`'s `(3,2)`, `(5,1)`, `(4,2)` saved placements; and `animated_mining_grid_visual_layer_test.dart`'s `_defaultCell = (2,3)` / `_minedDeposit = (1,1,2)` assumptions. Preserve the **original test intent** (selected tier, site, rig count, accessibility, animation target, locked reason and progression level), not literal old coordinates.
2. Replace `deposits[2]` / `deposits[3]` as proxies for Surveying-locked deposits in `mine_site_view_test.dart`, `mining_controller_test.dart`, `mining_save_repository_test.dart`, and other affected fixtures. Find the authored deposit with the required Surveying level and an actually unique perimeter cell, rather than assuming its position in the list. For tests that verify a specific footprint or side rig, query content geometry / target relationship instead of a static coordinate.
3. **Do not** separately rewrite `tapGridCell` or `_cellPoint` for the old InteractiveViewer. Task 2 will replace their entire pan logic once, alongside the new presenter. No throwaway helper commit.
4. Run **full `flutter test`** with the current 50×50 runtime and keep it green. This prep commit stays on the same PR #57.

## Task 2 — Atomic content, rejection-path and presenter cutover

1. Add closed `enum MiningBand { pockets, seams, lodes, motherlode }` to `mining_content.dart` (display labels, full-width label rows, one content-level `bandForDeposit` from unique footprints 1–4). Author **one 8×22 layout**, all 15 sites, and preserve every site's `_surveyingProgressionLevels`:

   | Band | Mines `(x,y,size)` | Empty label row |
   | --- | --- | --- |
   | Pockets | `(0,20,1)`, `(2,20,1)`, `(5,20,1)`, `(7,20,1)` | 18 |
   | Seams | `(0,15,2)`, `(3,15,2)`, `(6,15,2)` | 13 |
   | Lodes | `(0,9,3)`, `(5,9,3)` | 7 |
   | Motherlode | `(2,2,4)` | 0 |

   Keep `MiningDepositDefinition.requiredSurveyingLevel`, cached unique-perimeter legality, and four-rig site cap unchanged. Test the 4 label rows are clear of deposits and legal cells.

2. **Fix the six expected ambiguous cells without changing legality.** `evaluateMiningPlacement` already returns `MiningPlacementRejection.ambiguousAdjacentDeposit` for `(1,20)`, `(6,20)`, `(2,15)`, `(2,16)`, `(5,15)`, `(5,16)`. Add one shared `miningPlacementRejectionMessage(MiningPlacementResult)` in `mining_grid.dart` covering the existing rejection cases and returning e.g. **“Place the rig next to a single resource.”** for ambiguity. In `MineSiteView.gridTapOutcome`, turn that into a normal blocked tap; in `MiningController._placementFailureMessage` (or its call site), return it as a normal action failure. Neither may throw `StateError` for an invalid user tap. Keep the rest of the controller/simulation/save untouched.
3. Replace `InteractiveViewer`, `TransformationController`, zoom, `_initialFocus` and `_initialCamera` with a `SingleChildScrollView` and `ScrollController`. Center `FittedBox(fit: BoxFit.scaleDown)` around the existing 56 dp logical cell scene, now **448×1232**; Flutter transforms pointer coordinates with the scene. **Move the repeating cavern `Image.asset` behind the scroll view**, making background full-bleed on landscape/tablet and padding areas rather than bounded to 448dp.
4. Band labels/chips are non-interactive overlays on rows 0/7/13/18. Rail buttons read `MineSiteView`'s actual surveyed state and are fully semantic; their surrounding region is pointer-transparent. Use one `_scrollToBand(MiningBand, {required bool animate})` for initial entry and rail taps, clamped to valid extent. **Use scaled offsets**: target row `y` maps to `topPadding + y * miningGridCellSize * min(1, availableWidth/448)`; an unscaled logical offset overshoots at 360dp. First frame highest open band once, **never reframe** on Surveying purchase or one-second refresh; reduced motion jumps.
5. In `MineSiteScreen`, compute the **portrait vertical scroll bottom clearance from `portraitMineSellTop(height, bottomInset, textScaler)`** as well as existing dock/nav constraints. At maximum scroll, **`(7,21)` must move above the portrait Sell hit area** on 360×640, 390×844 and 430×932, including text scale 1.3 and bottom inset. Do not rely on horizontal pan or shrink the 8-cell scene width. Constrain the four rail hit regions **between Cargo Gauge bottom and Sell top in portrait**, and Cargo Gauge bottom and bottom-safe-area in landscape; fit compact 44dp targets by reducing gaps rather than overlapping UI. Inspect existing HUD rectangles (`_hudRects`) and assert zero overlap at 360×640 / 1.3× text and 874×402.
6. Add `4 => 224` to `depositVisualSize`. Draw one **static** Motherlode halo in `MiningGridMap`'s scene `Stack` **behind `_objectLayer()`** for all 15 sites; disable under reduced motion. Keep existing static/animated art/HP, audio and cargo-driven stage behavior. Do not duplicate halo code across visual layers or add a ticker.
7. Replace `tapGridCell` in `mining_shell_harness.dart` **once** with a content-width-aware vertical scroll-to-cell helper; update `_cellPoint` in `mine_site_screen_test.dart` in the same cutover. Retain ~27 callers unchanged; remove old `mining-grid-interactive` / 50×50 / camera/100-body expectations from affected tests.

**Task 2 must end with full `flutter test` green**, including these automated checks:

- All 15 sites: in-bounds 8×22, ten mines (4×1, 3×2, 2×3, 1×4), same deterministic layout, original Surveying levels; ten all-5 late sites have all bands open; four clear label rows.
- Each deposit has **unique legal** perimeter cells; the **six shared-adjacency cells are expected and undeployable**, not content-generation failures. Replace `mining_content_test.dart:761–770`'s global `adjacent.length <= 1` assertion with the exact six-cell set plus per-deposit unique-legality tests. Test at least `(1,20)` and `(2,15)` via both `MineSiteView.gridTapOutcome` and `MiningController.deployRig`: explanatory failure, no exception, no lost dock rig/cash/save mutation. All sites have ≥4 unique legal cells at unlock Surveying level.
- Five viewport sizes: **360×640, 390×844, 430×932, 874×402 and 1024×768**. Verify scroll-only map, visible cells ≥44dp on 360 and ≤56dp wide, scale-aware rail positioning, no clipped scene or flat cavern side bars.
- On 360×640, 390×844 and 430×932 portrait, **physically scroll and tap `(7,21)`** at the bottom; it must clear Sell, not just appear theoretically legal. Test text scale **1.3**, real bottom insets, and the rail's 4 buttons versus Sell/cargo HUD rectangles. On 874×402 landscape, rail must clear Cargo Gauge and bottom area. Confirm no hit-region overlaps.
- Live Surveying gate update without scroll reset; once-per-site framing, keyboard/semantic rail targets, right-column touches, reduced-motion jump and no glow.
- The 4×4 Motherlode renders on all static/animated site paths; single halo owner, existing hit/HP timing still intact.

## Task 3 — Reusable user workflow and visual comparison

1. Add **one `mining_shell_test.dart` workflow** using the existing shell harness, actual user actions and controller-owned persistence: fresh Landing Basin → spawn/select T1 → pocket deploy → tap an **ambiguous** gap (normal rejection, no crash) → locked lode rejection → research Surveying 1 → live unlock → rail navigation → deploy on lode → sell → reload. Reuse existing helper cases rather than duplicating the suite.
2. Keep accessibility/touch semantics tests at the rail and rightmost rig cells. Specifically check Surveying 1 updates rail/lock state without reframe; assert the right-edge bottom pocket cell is physically tappable after scroll.
3. Browser MCP screenshots: Surveying **0/1/2** at **390×844** and one **874×402** landscape shot, compared to Linear `map-mockup.png` frames **A–C** for four bands, collision-free labels, rail/HUD, full-bleed cavern, Motherlode halo, dimming and Sell clearance. Exhausted/IDLE, true HP, later “Exhaust 2 pockets” copy and frame D remain **out of scope**. Comparison is an automated acceptance evidence check with **no human sign-off**.
4. Keep screenshots out of tracked Git. Correct any visual mismatch in PR #57 and repeat the screenshot.

## Task 4 — Save/economy regression and documentation

1. Reuse save/controller tests; add only new-field round-trip, off-field old placement clean-recovery and locked/unlocked placement cases if existing suites lack them. The strict decoder already checks placement; do **not** add migration or a compatibility reader.
2. Run `test/integration/merge_mining_journey_test.dart` **unchanged**. It already uses `firstPlayableCell` and `deployableMiningCells` from content, and production has no deposit-size term. Require all existing cadences, milestones, pacing bands, Io completion, rewards and relaunch to pass **without retuning**. If this fails, fix a placement/geometry regression, not numeric economy content.
3. Update the active paragraph in `CLAUDE.md` from “50×50 InteractiveViewer, 100 resources” to “8×22, ten deposits in four Surveying-gated bands, native vertical scroll and unchanged placement/save ownership.” Do not revise historical PR docs.
4. Run `flutter test` green again.

## Task 5 — Repository gates and small MCP browser E2E

Run each `CLAUDE.md` gate and record real **pass / fail / blocked / not run** status in PR #57 (never claim an unrun check passed): `dart format --output=none --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test`, `flutter test --coverage`, `flutter test --platform chrome`, `flutter build apk --debug`, `flutter build web`, and `flutter build ios --simulator --debug` (macOS runner).

**One MCP-driven Flutter web E2E, one platform, no native acceptance.** Keep the browser smoke shorter than the committed widget regression but do not delete the MCP E2E criterion: this project requires it. On a fresh save at **390×844**, use the real UI to enter Landing Basin, spawn/select and place a pocket rig; verify a locked lode rejects placement; purchase Surveying 1; tap a rail node; deploy in the unlocked band; sell/reload and confirm state. Capture actual screenshot evidence from this run, including the Surveying and landscape frames listed in Task 3. This validates real-screen tap alignment and responsive rendering; do not create a large separate E2E framework.

### End-to-end acceptance (automated; no human sign-off)

- [ ] Exactly **8×22 / 10 mines / 4 bands** on all 15 sites, with unique legal placements, **six expected ambiguous nondeployable cells**, normal view/controller rejections and four collision-free label rows.
- [ ] Site unlock-level legal cells ≥4; **10** all-5 late sites fully open; band lock copy uses current Surveying (no exhaustion yet).
- [ ] Scroll-only map fits 360 dp without cell shrinking below 44 dp; wide layout centered/capped at 56 dp with **full-bleed cavern**, **scale-aware scroll targets**; all five viewport test sizes and safe areas pass.
- [ ] One-time initial framing, semantic depth rail bounded **between Cargo Gauge and Sell/bottom** without HUD overlap at 360×640 / 1.3 text scale and 874×402; live Surveying unlock without reframe; **physical `(7,21)` tap above Sell** at 360/390/430 portrait widths; reduced motion all pass.
- [ ] 4×4 Motherlode static/animated artwork renders correctly; current visual HP and SFX remain unaffected.
- [ ] Reusable MiningShell user workflow test passes through **ambiguous-cell rejection** and real shell actions/reload; strict invalid placement recovery passes.
- [ ] Existing public-action journey runs **unchanged** through Io + relaunch with identical economic pacing bands and costs.
- [ ] **MCP web E2E** passes on one platform and visual screenshots are checked against attached Linear mockup frames A–C; evidence kept untracked.
- [ ] All applicable repository gates recorded; no pending implementation is misrepresented as passed.

**PR discipline:** keep all code, tests, evidence summaries and documentation in this **same** draft PR; do not create a second PR for HPA-1243 or merge a planning-only change.
