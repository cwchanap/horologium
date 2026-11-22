# HPA-1243 — Implementation plan: progressive Mine Site map

Linear: https://linear.app/cwchanap/issue/HPA-1243/mining-map-progressive-site-map-pockets-seams-lodes-motherlode  
Design: [2026-11-22-hpa-1243-progressive-site-map-design.md](../specs/2026-11-22-hpa-1243-progressive-site-map-design.md)  
Baseline: `main` @ `c5c0a351fcd94881a3c6abf256a07bd6ce2eac09`

**One Linear ticket, one draft PR.** This PR contains planning first; implement and test on **the same PR #57**, with no second implementation PR. No new art/SFX assets or separate generation work.

## Reuse map and implementation boundaries

| Existing file | Minimal work |
| --- | --- |
| `lib/mining/mining_content.dart` | Add closed `MiningBand` enum (label + row), shared deposit-to-band lookup, and one immutable 8×22 map authored by band. Reuse each site's four Surveying levels. |
| `lib/mining/mining_grid.dart` | **No change.** Existing `evaluateMiningPlacement` and `uniqueAdjacentDeposit` remain the only placement/target legality. |
| `lib/mining/mine_site_view.dart` | **No new owner.** Use existing `isSurveyed` / current view deposits for locked status, rail and chips. |
| `lib/mining/presentation/mining_grid_map.dart` | Swap `InteractiveViewer` for one vertical scroll and centered `FittedBox(fit: BoxFit.scaleDown)`; band labels, dimming, depth rail, 4×4 art size and static glow. Preserve logical tap coordinates and current layers. |
| `lib/mining/presentation/mine_site_screen.dart` | Only local integration with the existing safe-area, HUD, dock and navigation chrome where necessary. |
| `lib/mining/presentation/animated_mining_grid_visual_layer.dart` | **Only if necessary** for 4×4 bounds. Keep transient HP and impacts visual-only. |
| `test/mining/presentation/mining_shell_harness.dart` | Fix `tapGridCell`'s hardcoded 50-cell width, then replace InteractiveViewer dragging with a reusable scroll-to-cell tap. Keep ~27 existing caller sites unchanged. |
| `test/mining/presentation/mine_site_screen_test.dart` | Fix `_cellPoint`'s hardcoded 50 and replace old pan/zoom geometry expectations. |
| `test/mining/mining_content_test.dart`, `test/mining/mining_grid_test.dart` | Fixed map topology, valid unique legal perimeters, Surveying gates and no label-cell collisions. |
| `test/mining/presentation/mining_grid_map_test.dart`, `test/mining/presentation/mine_site_screen_test.dart`, `test/mining/presentation/animated_mining_grid_visual_layer_test.dart` | Scroll, rail, hit tests, live gate changes, 4×4 art, right-edge accessibility, reduced motion and responsive sizes. |
| `test/mining/presentation/mining_shell_test.dart` | **One reusable end-to-end UI widget case**: spawn → pocket deploy → lock rejection → Surveying research → rail → lode deploy → sell/reload. |
| `test/mining/mining_save_repository_test.dart`, `test/mining/mining_controller_test.dart` | Focused recovery/placement regressions only where missing. |
| `test/integration/merge_mining_journey_test.dart`, `test/support/mining_grid_fixtures.dart` | **Do not edit.** These already query legal cells from authored content. Run the existing journey unchanged as the pacing oracle. |
| `CLAUDE.md` | Update only active Mine Site paragraph after implementation; leave historical specs intact. |

Do not touch `MiningController` API, `MiningSimulation`, `MiningSave` JSON/schema, costs, rates, capacity, commissioning/mastery, Surveying price gates, Site Deck or alerts. No new controller action, generic map engine, migration or band-unlocked save field.

## Task 1 — Fix shared test assumptions before geometry changes

1. `tapGridCell` in `mining_shell_harness.dart:132–162` hardcodes `50 * miningGridCellSize` and drags `mining-grid-interactive`. First derive the width from the rendered `MiningGridMap.view.definition.gridWidth` while keeping current InteractiveViewer behavior. Do **not** edit each shell test caller.
2. `_cellPoint` in `mine_site_screen_test.dart:178` also hardcodes 50; replace with the actual site's definition width. Inventory other hardcoded 50×50, 100-resource, camera and deposit-key assertions for the later cutover.
3. Run the **entire `flutter test`** on the still-current geometry and keep it green. Commit on PR #57.

## Task 2 — Atomic content and map-presenter cutover

1. Create `enum MiningBand { pockets, seams, lodes, motherlode }` in `mining_content.dart`. Keep its display label and one **full-width label row** with the enum, plus a **single content-level** `bandForDeposit(MiningDepositDefinition)` helper derived from the authored unique sizes 1–4. UI, topology tests and future HPA-1244 logic must reuse this identity, not repeat their own mapping.
2. Replace `_denseResourceField` with one **8 columns × 22 rows** immutable geometry constant keyed by `MiningBand`, ordered for future progression as pockets → seams → lodes → Motherlode:

   | Band | Mines `(x,y,size)` | Clear label row |
   | --- | --- | --- |
   | Pockets | `(0,20,1)`, `(2,20,1)`, `(5,20,1)`, `(7,20,1)` | 18 |
   | Seams | `(0,15,2)`, `(3,15,2)`, `(6,15,2)` | 13 |
   | Lodes | `(0,9,3)`, `(5,9,3)` | 7 |
   | Motherlode | `(2,2,4)` | 0 |

   Assign `requiredSurveyingLevel` using the unchanged `_surveyingProgressionLevels[siteId]![band.index]`. Every label row is free of any deposit **or legal rig-perimeter cell**; assert it. Keep cached perimeter logic and the four-rig site cap unchanged.

3. Replace `InteractiveViewer`, `TransformationController`, zoom, `_initialFocus` and `_initialCamera` with a `SingleChildScrollView` + `ScrollController`. Inside, center `FittedBox(fit: BoxFit.scaleDown)` around the existing **56 dp logical cell scene**, now **448×1232**. Flutter supplies uniform scaling and transformed hit tests; preserve `details.localPosition ~/ miningGridCellSize` and existing static/animated object layers. Do **not** shrink width using HUD left/right clearance. Keep vertical scroll padding/targets clear of the current fixed chrome.
4. Add non-interactive labels/chips on rows 0/7/13/18 and dim locked bands, using current `MineSiteView` Surveying state. Add one compact four-node depth rail with actual semantic buttons; its surrounding region passes pointer events so rightmost column 7 stays accessible. Locked rail targets may preview a band but must not make locked deposits deployable.
5. Use **one** `_scrollToBand(MiningBand, {required bool animate})` function. On initial layout, `jumpTo` the highest open band, clamped to scroll extent; when the user taps a rail node, animate unless reduced motion. **Never auto-reframe when Surveying changes**, and do not reframe on the one-second shell refresh. Site switches already use `ValueKey(view.siteId)` to create fresh state.
6. Add `4 => 224` to `depositVisualSize`, verify static and animated Motherlode art, and add one **static**, code-only gold halo (`BoxShadow` or gradient); omit it under reduced motion. No pulsing ticker, new frames, painted art, sound or HP/exhaustion mechanics.

**Tests before finishing Task 2:** update content, view, screen/map, animation and shell helper assumptions together, then run **full `flutter test` green** on the atomic cutover; a half-migrated red suite is not a deliverable. Key assertions:

- All 15 sites: exactly ten mines (4×1, 3×2, 2×3, 1×4), in-bounds 8×22, identical deterministic geometry and Surveying-by-band behavior.
- All deposits have **unique legal** placement cells (pocket 2–3, seam 4, lode 9, Motherlode 16) and at least **four legal deploy cells** at each site's unlock Surveying level; no label rect overlaps any valid target.
- Landing Basin at level 0 has pockets and seams open; Surveying 1 opens lodes and Surveying 2 the Motherlode. Frozen Basin keeps `[3,3,4,5]`. Titanium Highlands remains `[4,4,5,5]`; the **ten all-5** late sites arrive fully open with no lock chips and Motherlode framing.
- 360×640, 390×844, 430×932, 874×402 and 1024×768: vertical scroll only, **≥44 dp** cells at 360, **≤56 dp** at wide sizes, centered wide layout, correct transformed taps, no right-rail or HUD obstruction.
- Initial framing is once per site; rail/keyboard/semantic controls work; research refreshes locks without stealing scroll. Reduced motion uses jump-to-band and removes halo.
- Static and animated 4×4 drawing works without missing frame, cropped rig or HP/chip collision.

## Task 3 — Reusable user workflow and visual comparison

1. Add **one `mining_shell_test.dart` workflow** using the existing shell harness, actual user actions and controller-owned persistence: fresh Landing Basin → spawn/select T1 → pocket deploy → locked lode rejection → research Surveying 1 → live unlock → rail navigation → deploy on lode → sell → reload. Reuse existing helper cases instead of duplicating the whole suite.
2. Keep accessibility/touch semantics tests at the rail and rightmost rig cells. Specifically check that Surveying 1 research updates the rail/lock state but **does not** unexpectedly reframe.
3. In browser MCP, collect screenshots for Surveying **0/1/2** at **390×844** and one **874×402** landscape shot. Compare the screenshots to Linear's attached `map-mockup.png` frames **A–C** for bands, labels, chips, rail, Motherlode emphasis and safe-area chrome. The mockup's “Exhaust 2 pockets”, true HP/IDLE and frame D belong to later tickets; **do not implement them**. Screenshot comparison is acceptance evidence—**no human approval criterion**.
4. Keep screenshots out of the tracked repo. If the visual check finds a mismatch, fix within PR #57 and repeat capture.

## Task 4 — Save/economy regression and documentation

1. Reuse save/controller tests; add only new-field round-trip, off-field old placement clean-recovery and locked/unlocked placement cases if existing suites lack them. The strict decoder already checks placement; do **not** add migration or a compatibility reader.
2. Run `test/integration/merge_mining_journey_test.dart` **unchanged**. It already uses `firstPlayableCell` and `deployableMiningCells` from content, and production has no deposit-size term. Require all existing cadences, milestones, pacing bands, Io completion, rewards and relaunch to pass **without retuning**. If this fails, fix a placement/geometry regression, not numeric economy content.
3. Update the active paragraph in `CLAUDE.md` from “50×50 InteractiveViewer, 100 resources” to “8×22, ten deposits in four Surveying-gated bands, native vertical scroll and unchanged placement/save ownership.” Do not revise historical PR docs.
4. Run `flutter test` green again.

## Task 5 — Repository gates and small MCP browser E2E

Run each `CLAUDE.md` gate and record real **pass / fail / blocked / not run** status in PR #57 (never claim an unrun check passed): `dart format --output=none --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test`, `flutter test --coverage`, `flutter test --platform chrome`, `flutter build apk --debug`, `flutter build web`, and `flutter build ios --simulator --debug` (macOS runner).

**One MCP-driven Flutter web E2E, one platform, no native acceptance.** Keep the browser smoke shorter than the committed widget regression but do not delete the MCP E2E criterion: this project requires it. On a fresh save at **390×844**, use the real UI to enter Landing Basin, spawn/select and place a pocket rig; verify a locked lode rejects placement; purchase Surveying 1; tap a rail node; deploy in the unlocked band; sell/reload and confirm state. Capture actual screenshot evidence from this run, including the Surveying and landscape frames listed in Task 3. This validates real-screen tap alignment and responsive rendering; do not create a large separate E2E framework.

### End-to-end acceptance (automated; no human sign-off)

- [ ] Exactly **8×22 / 10 mines / 4 bands** on all 15 sites, with unique legal placements and four collision-free label rows.
- [ ] Site unlock-level legal cells ≥4; **10** all-5 late sites fully open; band lock copy uses current Surveying (no exhaustion yet).
- [ ] Scroll-only map fits 360 dp without cell shrinking below 44 dp; wide layout centered/capped at 56 dp; all five viewport test sizes and safe areas pass.
- [ ] One-time initial framing, semantic depth rail, live Surveying unlock without reframe, right-edge cell hit-testing and reduced motion all pass.
- [ ] 4×4 Motherlode static/animated artwork renders correctly; current visual HP and SFX remain unaffected.
- [ ] Reusable MiningShell user workflow test passes through real shell actions and reload; strict invalid placement recovery passes.
- [ ] Existing public-action journey runs **unchanged** through Io + relaunch with identical economic pacing bands and costs.
- [ ] **MCP web E2E** passes on one platform and visual screenshots are checked against attached Linear mockup frames A–C; evidence kept untracked.
- [ ] All applicable repository gates recorded; no pending implementation is misrepresented as passed.

**PR discipline:** keep all code, tests, evidence summaries and documentation in this **same** draft PR; do not create a second PR for HPA-1243 or merge a planning-only change.
