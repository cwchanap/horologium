# HPA-454 Dense Resource Fields and Multi-Robot Slots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace each four-deposit Mine Site with one deterministic 100-resource field, make distinct free perimeter cells the only per-resource mining-capacity rule, and make same-resource multi-robot placement reachable as soon as each site is playable.

**Architecture:** Keep `MiningController`, `MiningSaveRepository`, `MineSiteView`, and `MiningSimulation` ownership unchanged. Generate immutable resource geometry once from `MiningSiteId`, cache the registry and static perimeter cells, keep `evaluateMiningPlacement(...)` as the sole legality predicate, persist only rig tier/cell, and render the dense field with the existing Flutter `Stack`/`InteractiveViewer` path. Do not add a resource runtime model, slot subsystem, spatial-index framework, or new art to this PR.

**Tech Stack:** Dart, Flutter, `SharedPreferences`, `flutter_test`; no new package dependency.

**Spec:** `docs/superpowers/specs/2026-09-16-hpa-454-dense-resource-fields-design.md`

## Global constraints

- One Linear ticket = one implementation PR. All implementation commits stay on the current HPA-454 PR.
- Grid dimensions are exactly 50×50 and every site has exactly 100 resources from one 10×10 lattice.
- Resource footprints remain only 1×1, 2×2, or 3×3.
- The first four lattice resources retain each site's existing four Surveying levels; remaining resources use that site's maximum level.
- Do **not** preserve the old effective-slot table. The revised table in the spec is intentional so multi-robot placement is reachable at each site's first playable Surveying level.
- Preserve `MiningContentRegistry.maxDeployedRigsPerSite == 4` and all rate/capacity/offline/sale formulas.
- Remove `MiningDepositId`, `maxMiners`, and `MiningPlacementRejection.depositAtCapacity`; do not replace them with a resource ID/capacity field.
- `evaluateMiningPlacement(...)` remains the sole controller/save/view legality predicate.
- Cache `MiningContentRegistry.stellarMining()` and site perimeter geometry; do not recompute static layout in one-second view refreshes or widget animation frames.
- Save JSON remains strict/unversioned with `rigPlacements: [{tier,x,y}]`; no migration or compatibility reader.
- An incompatible persisted rig placement resets the **entire** mining save through the existing invalid-save recovery boundary.
- Reuse existing resource/robot/cavern art. The coding PR tiles existing cavern art; if a new background asset is actually required after visual review, create a separate image-generation task instead of adding art here.
- HPA-455 HP/damage feedback, HPA-452 fleet interaction changes, and HPA-286 cargo/sell polish remain out of scope.

## Intermediate-commit rule

Tasks 1 and 2 remove/change APIs before all consumers are migrated. Their focused tests must pass, but those two intermediate commits are allowed to leave unrelated package files with compile fallout. **Task 3 is the hard compile-recovery checkpoint:** after Task 3, `flutter analyze --fatal-infos` and the focused controller/save/view tests must pass. Only the PR tip is expected to be fully releasable.

## Risks to pin

1. **Placement pacing changes intentionally.** Earlier access to four legal cells is the gameplay result of deleting one-slot resource caps; deployed-rig production math must not change.
2. **Dense static work can become hot-path work.** Cache registry/perimeters, bucket ≤4 rig targets once, and do not scan all 2,500 cells for highlights.
3. **Landing Basin animation can multiply widget rebuilds 25×.** Static unmined resources must live outside the animation builder.
4. **Background/readability is not proven by geometry tests.** Tile existing cavern art and require a manual portrait visual gate.
5. **Save recovery is destructive.** One invalid legacy rig coordinate causes the whole document to recover as `MiningSave.initial(...)`; tests and docs must say so explicitly.

---

### Task 1: Make perimeter geometry the only resource-level placement rule

**Files:**
- Modify: `lib/mining/mining_grid.dart`
- Modify: `test/mining/mining_grid_test.dart`

**Interfaces:**
- Produces: `MiningDepositDefinition(x, y, size, requiredSurveyingLevel)` with value equality/hash code.
- Produces: `miningPerimeterCells(...) -> Set<MiningGridCell>`.
- Preserves: `uniqueAdjacentDeposit(...)` and `evaluateMiningPlacement(...)`.
- Removes: `MiningDepositId`, `MiningDepositDefinition.maxMiners`, `MiningPlacementRejection.depositAtCapacity`.

- [ ] **Step 1: Replace the old cap-oriented test with same-resource multi-robot RED tests**

Use one 1×1 resource at `(3,3)`:

```dart
const target = MiningDepositDefinition(
  x: 3,
  y: 3,
  size: 1,
  requiredSurveyingLevel: 0,
);
const deposits = [target];

expect(
  miningPerimeterCells(
    gridWidth: 8,
    gridHeight: 8,
    deposits: deposits,
    target: target,
  ),
  {
    const MiningGridCell(3, 2),
    const MiningGridCell(2, 3),
    const MiningGridCell(4, 3),
    const MiningGridCell(3, 4),
  },
);

final second = evaluateMiningPlacement(
  gridWidth: 8,
  gridHeight: 8,
  deposits: deposits,
  occupiedRigCells: const [MiningGridCell(3, 2)],
  candidate: const MiningGridCell(2, 3),
  surveyingLevel: 0,
  maxRigCount: 4,
);
expect(second.isAllowed, isTrue);
expect(second.target, target);
```

Keep explicit rejection tests for site capacity, bounds, resource footprint, occupied rig cell, no adjacency, ambiguous adjacency, and Surveying lock. Delete the old `depositAtCapacity` expectation.

- [ ] **Step 2: Run the focused test and confirm RED**

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: FAIL because old construction still requires `id`/`maxMiners`, the perimeter helper is missing, and/or the second placement hits `depositAtCapacity`.

- [ ] **Step 3: Simplify `MiningDepositDefinition` and add value equality**

Implement geometry/Surveying only:

```dart
class MiningDepositDefinition {
  const MiningDepositDefinition({
    required this.x,
    required this.y,
    required this.size,
    required this.requiredSurveyingLevel,
  });

  final int x;
  final int y;
  final int size;
  final int requiredSurveyingLevel;

  @override
  bool operator ==(Object other) =>
      other is MiningDepositDefinition &&
      other.x == x &&
      other.y == y &&
      other.size == size &&
      other.requiredSurveyingLevel == requiredSurveyingLevel;

  @override
  int get hashCode => Object.hash(x, y, size, requiredSurveyingLevel);
}
```

Keep the existing `contains(...)` and `isOrthogonallyAdjacent(...)` methods.

- [ ] **Step 4: Add `miningPerimeterCells(...)` and remove resource-cap rejection**

Build only footprint-boundary candidates, then filter to in-bounds non-resource cells whose `uniqueAdjacentDeposit(...)` equals `target`. Delete `depositAtCapacity` and its miner-count branch from `evaluateMiningPlacement(...)`.

Do not introduce a slot object/table.

- [ ] **Step 5: Re-run Task 1 test**

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: PASS, including two occupied sibling perimeter cells targeting the same resource.

- [ ] **Step 6: Commit the focused geometry checkpoint**

```sh
git add lib/mining/mining_grid.dart test/mining/mining_grid_test.dart
git commit -m "refactor(mining): derive resource capacity from perimeter cells"
```

This commit may not make the whole package compile yet; that is explicitly repaired in Task 3.

---

### Task 2: Generate/caches the 100-resource content and precompute static perimeter geometry

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `test/mining/mining_content_test.dart`
- Inspect unchanged caller: `lib/mining/presentation/technology_sheet.dart`
- Regression test: `test/mining/presentation/technology_sheet_test.dart`

**Interfaces:**
- Produces: 50×50, 100-resource `MiningSiteDefinition`s.
- Produces: `MiningSiteDefinition.perimeterCellsByDeposit` as immutable derived geometry.
- Produces: cached `MiningContentRegistry.stellarMining()` singleton.
- Preserves: site/planet economy values, resource types, assets, progression requirements, and four authored Surveying levels/site.

- [ ] **Step 1: Rewrite content invariants as RED dense-field tests**

For every site assert:

```dart
final site = MiningContentRegistry.stellarMining().site(siteId);
expect(site.gridWidth, 50, reason: site.name);
expect(site.gridHeight, 50, reason: site.name);
expect(site.deposits, hasLength(100), reason: site.name);
expect(site.deposits.toSet(), hasLength(100), reason: site.name);
expect(site.deposits.map((d) => d.size).toSet(), {1, 2, 3});
expect(site.perimeterCellsByDeposit.keys.toSet(), site.deposits.toSet());
```

Keep exhaustive in-bounds, non-overlap, and ambiguous-adjacency scans across all 100 resources.

Pin factory caching explicitly:

```dart
expect(
  identical(
    MiningContentRegistry.stellarMining(),
    MiningContentRegistry.stellarMining(),
  ),
  isTrue,
);
```

Do **not** call two cached factory results a generator-determinism test. Instead freeze the four Landing Basin progression tuples and one later-site progression tuple list directly from the documented formula, then rely on the exhaustive geometry invariants plus the implementation's no-RNG formula.

For Landing Basin, pin:

```dart
expect(
  site.deposits.take(4).map((d) => (d.x, d.y, d.size, d.requiredSurveyingLevel)),
  [(1, 1, 2, 0), (6, 1, 3, 0), (11, 2, 2, 1), (16, 1, 3, 2)],
);
```

- [ ] **Step 2: Pin the revised slot table and headline reachability**

Use cached perimeter sets to compute unique surveyed cells, clamp to four, and assert:

```dart
const expectedBySite = <MiningSiteId, List<int>>{
  MiningSiteId.landingBasin: [4, 4, 4, 4, 4, 4],
  MiningSiteId.carbonRidge: [4, 4, 4, 4, 4, 4],
  MiningSiteId.graniteCrater: [4, 4, 4, 4, 4, 4],
  MiningSiteId.frozenBasin: [0, 0, 0, 4, 4, 4],
  MiningSiteId.titaniumHighlands: [0, 0, 0, 0, 4, 4],
  MiningSiteId.heliumMare: [0, 0, 0, 0, 0, 4],
  MiningSiteId.ochreBasin: [0, 0, 0, 0, 0, 4],
  MiningSiteId.silicaDunes: [0, 0, 0, 0, 0, 4],
  MiningSiteId.cobaltChasm: [0, 0, 0, 0, 0, 4],
};
```

For every site's actual array, also assert each level is `>=` the previous level.

At `site.requiredSurveyingLevel`, assert at least one surveyed resource has:

```dart
site.perimeterCellsByDeposit[deposit]!.length >= 2
```

This directly prevents same-resource multi-robot placement from becoming max-tech-only dark content.

- [ ] **Step 3: Run the content test and confirm RED**

```sh
flutter test test/mining/mining_content_test.dart
```

Expected: FAIL on 24×18/four-resource content, old IDs/caps, missing geometry cache, and uncached/generated content contract.

- [ ] **Step 4: Implement one 10×10 lattice generator**

Keep constants/private data in `mining_content.dart`:

```dart
const _denseGridWidth = 50;
const _denseGridHeight = 50;

const _surveyingProgressionLevels = <MiningSiteId, List<int>>{
  MiningSiteId.landingBasin: [0, 0, 1, 2],
  MiningSiteId.carbonRidge: [0, 1, 2, 3],
  MiningSiteId.graniteCrater: [0, 1, 2, 3],
  MiningSiteId.frozenBasin: [3, 3, 4, 5],
  MiningSiteId.titaniumHighlands: [4, 4, 5, 5],
  MiningSiteId.heliumMare: [5, 5, 5, 5],
  MiningSiteId.ochreBasin: [5, 5, 5, 5],
  MiningSiteId.silicaDunes: [5, 5, 5, 5],
  MiningSiteId.cobaltChasm: [5, 5, 5, 5],
};
```

Implement one loop for all 100 bodies:

```dart
List<MiningDepositDefinition> _denseResourceField(MiningSiteId siteId) {
  final progressionLevels = _surveyingProgressionLevels[siteId]!;
  final maxLevel = progressionLevels.reduce((a, b) => a > b ? a : b);
  final deposits = <MiningDepositDefinition>[];

  for (var row = 0; row < 10; row++) {
    for (var column = 0; column < 10; column++) {
      final index = row * 10 + column;
      final value =
          (siteId.index * 31 + index * 17 + index * index * 7) % 97;
      final isProgressionResource = index < 4;
      final size = isProgressionResource ? 2 + index % 2 : 1 + value % 3;
      final requiredSurveyingLevel = isProgressionResource
          ? progressionLevels[index]
          : maxLevel;
      final movableSpan = 4 - size;
      final offsetX = 1 + (value ~/ 3) % movableSpan;
      final offsetY = 1 + (value ~/ 11) % movableSpan;

      deposits.add(
        MiningDepositDefinition(
          x: column * 5 + offsetX,
          y: row * 5 + offsetY,
          size: size,
          requiredSurveyingLevel: requiredSurveyingLevel,
        ),
      );
    }
  }

  return List.unmodifiable(deposits);
}
```

There is no blocker strip and no second generator path.

- [ ] **Step 5: Compute `perimeterCellsByDeposit` once in `MiningSiteDefinition`**

Make site construction runtime (the registry itself will be cached) and materialize:

```dart
final Map<MiningDepositDefinition, Set<MiningGridCell>> perimeterCellsByDeposit;
```

Use one private helper called by the constructor:

```dart
Map<MiningDepositDefinition, Set<MiningGridCell>> _perimeterCellsByDeposit({
  required int gridWidth,
  required int gridHeight,
  required List<MiningDepositDefinition> deposits,
}) => Map.unmodifiable({
  for (final deposit in deposits)
    deposit: Set.unmodifiable(
      miningPerimeterCells(
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        deposits: deposits,
        target: deposit,
      ),
    ),
});
```

Do not store a second authored `slotCount`; the set length is the derived count.

- [ ] **Step 6: Cache the generated registry**

Use:

```dart
static final MiningContentRegistry _stellar = _buildStellarMining();

factory MiningContentRegistry.stellarMining() => _stellar;
```

`_buildStellarMining()` owns the existing planet/site literals but replaces old dimensions/deposit lists with `_denseResourceField(siteId)`.

Do not modify `TechnologySheet` merely because it calls `MiningContentRegistry.stellarMining()` in `build()`; the cached factory makes that existing call cheap.

- [ ] **Step 7: Re-run content + Technology presentation regression tests**

```sh
flutter test \
  test/mining/mining_content_test.dart \
  test/mining/presentation/technology_sheet_test.dart
```

Expected: PASS for the focused files, including cached factory identity, 100 unique resources/site, new slot table, and unchanged Technology UI behavior.

- [ ] **Step 8: Commit the generated-content checkpoint**

```sh
git add lib/mining/mining_content.dart test/mining/mining_content_test.dart
git commit -m "feat(mining): generate cached dense resource fields"
```

This commit may still have whole-package compile fallout from consumers migrated in Task 3.

---

### Task 3: Cut controller/save/view code over and remove per-refresh geometry work

**Files:**
- Modify: `lib/mining/mining_controller.dart`
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/mining/mine_site_view.dart`
- Create: `test/support/mining_grid_fixtures.dart`
- Modify: `test/mining/mining_controller_test.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Modify: `test/mining/mine_site_view_test.dart`

**Interfaces:**
- Controller/save decoding continue to call `evaluateMiningPlacement(...)` only.
- `MineSiteDepositView` exposes derived `minerCount`, cached `slotCount`, and `isSurveyed`.
- `MineSiteRigView.target` remains transient geometry only.
- Higher-level tests use a shared legal-cell helper based on cached perimeter candidates + the real evaluator.
- Save JSON remains unchanged.

- [ ] **Step 1: Add RED multi-robot/view/save tests**

Use the first surveyed progression resource's cached perimeter set rather than hard-coded cells:

```dart
final site = content.site(MiningSiteId.landingBasin);
final target = site.deposits.first;
final cells = site.perimeterCellsByDeposit[target]!.toList();
expect(cells.length, greaterThanOrEqualTo(2));
```

Then:

- `mine_site_view_test.dart`: two rigs on two cells resolve to the same `target` and `minerCount == 2`;
- `mining_controller_test.dart`: two dock rigs deploy successfully to those cells and persist;
- `mining_save_repository_test.dart`: round-trip the same state and reconstruct the same target.

Add a destructive cutover test using the old valid Landing Basin placement `(16,2)`. Under the new generated field it is inside the fourth progression resource. Encode a save with non-default cash/technology/progression plus that rig; after `load(...)` assert:

```dart
expect(result.recoveredFromInvalidSave, isTrue);
expect(result.state, MiningSave.initial(nowUtc: now));
```

This proves the invalid-placement boundary resets the complete document, not just rigs.

- [ ] **Step 2: Remove obsolete cap/ID consumers**

Delete `depositAtCapacity` switch arms from controller/view error handling and replace `.id` target equality with `MiningDepositDefinition` value equality.

Do not change controller/save mutation ownership or add resource identity to JSON.

- [ ] **Step 3: Bucket rig targets once per view build**

Before constructing deposit/rig views:

```dart
final targetByRigCell = <MiningGridCell, MiningDepositDefinition>{};
final minerCountByDeposit = <MiningDepositDefinition, int>{};
for (final placement in progress.rigPlacements) {
  final target = uniqueAdjacentDeposit(
    deposits: definition.deposits,
    cell: placement.cell,
  );
  if (target == null) {
    throw StateError('Saved rig placement without a unique adjacent resource.');
  }
  targetByRigCell[placement.cell] = target;
  minerCountByDeposit[target] = (minerCountByDeposit[target] ?? 0) + 1;
}
```

Each `MineSiteDepositView` reads:

```dart
minerCount: minerCountByDeposit[deposit] ?? 0,
slotCount: definition.perimeterCellsByDeposit[deposit]!.length,
isSurveyed: surveyingLevel >= deposit.requiredSurveyingLevel,
```

Each `MineSiteRigView` reuses `targetByRigCell[placement.cell]!`.

Do not call `miningPerimeterCells(...)` once per resource per one-second refresh.

- [ ] **Step 4: Build deployable highlights from cached surveyed perimeter candidates**

Do not scan all 2,500 grid cells. Build:

```dart
final candidateCells = <MiningGridCell>{
  for (final deposit in definition.deposits)
    if (surveyingLevel >= deposit.requiredSurveyingLevel)
      ...definition.perimeterCellsByDeposit[deposit]!,
};
```

When deployable highlighting is active, filter only those cells through the existing `evaluateMiningPlacement(...)`; the evaluator remains authoritative for site capacity, occupied cells, and Surveying legality.

- [ ] **Step 5: Add efficient shared test fixture helper**

`test/support/mining_grid_fixtures.dart` should use the same cached candidate union, evaluate every candidate with no occupied rigs, then sort row-major:

```dart
final legal = candidates.where((cell) => evaluateMiningPlacement(...).isAllowed).toList();
legal.sort((a, b) {
  final row = a.y.compareTo(b.y);
  return row != 0 ? row : a.x.compareTo(b.x);
});
return legal;
```

Do not scan 50×50 in the helper.

- [ ] **Step 6: Replace old legality-dependent fixture coordinates**

Update the focused controller/save/view tests to use the helper/cached target perimeters. Leave pure `MiningGridCell` value-object tests alone.

- [ ] **Step 7: Run the hard compile-recovery checkpoint**

```sh
flutter test \
  test/mining/mining_controller_test.dart \
  test/mining/mining_save_repository_test.dart \
  test/mining/mine_site_view_test.dart
flutter analyze --fatal-infos
```

Expected: PASS. From this commit onward the package must compile as a whole.

- [ ] **Step 8: Commit integration/performance cutover**

```sh
git add \
  lib/mining/mining_controller.dart \
  lib/mining/mining_save_repository.dart \
  lib/mining/mine_site_view.dart \
  test/support/mining_grid_fixtures.dart \
  test/mining/mining_controller_test.dart \
  test/mining/mining_save_repository_test.dart \
  test/mining/mine_site_view_test.dart
git commit -m "refactor(mining): project dense field geometry efficiently"
```

---

### Task 4: Render 100 resources without per-frame rebuilds or stretched cavern art

**Files:**
- Modify: `lib/mining/presentation/mining_grid_map.dart`
- Modify: `lib/mining/presentation/landing_basin_grid_visual_layer.dart`
- Modify: `test/mining/presentation/mining_grid_map_test.dart`
- Modify: `test/mining/presentation/landing_basin_grid_visual_layer_test.dart`
- Modify: `test/mining/presentation/mine_site_screen_test.dart`

**Interfaces:**
- Consumes: cached `slotCount`, `minerCount`, `isSurveyed`.
- Preserves: image/semantics-based resource rendering, one `CustomPaint` grid/highlight layer, HPA-451 impact ownership.
- Static unmined Landing Basin resources are `AnimatedBuilder.child`; only ≤4 mined resources + rigs rebuild per animation tick.
- Cavern background repeats existing art instead of stretching one frame over 2800×2800.

- [ ] **Step 1: Add RED presentation assertions**

Pin:

```text
static non-gold site renders exactly 100 resource images
resource keys use x-y-size geometry
semantics report footprint + miner count + free/total perimeter slots
no floating lock badge is repeated across the dense field
background Image uses ImageRepeat.repeat + BoxFit.none
Landing Basin can render two rigs targeting one resource
```

For Landing Basin widget tests, use cached/perimeter fixture cells rather than old IDs.

- [ ] **Step 2: Replace ID/cap presentation copy**

Use:

```dart
String _depositKey(MiningDepositDefinition definition) =>
    '${definition.x}-${definition.y}-${definition.size}';
```

Keys:

```dart
Key('mining-deposit-${_depositKey(deposit.definition)}')
Key('landing-basin-deposit-${_depositKey(deposit.definition)}')
```

Semantics:

```dart
final freeSlots = deposit.slotCount - deposit.minerCount;
return '$resource resource ${definition.size}x${definition.size}, '
    '${deposit.minerCount} miners, '
    '$freeSlots of ${deposit.slotCount} perimeter slots free.$locked';
```

Remove `_DepositLockBadge`; unsurveyed resources are dimmed and retain Surveying semantics/tap feedback.

- [ ] **Step 3: Tile the existing cavern background**

Replace `BoxFit.cover` on the full 50×50 surface with:

```dart
Image.asset(
  view.definition.cavernAsset,
  fit: BoxFit.none,
  alignment: Alignment.topLeft,
  repeat: ImageRepeat.repeat,
  errorBuilder: ...,
)
```

Keep the existing fallback decoration. Do not add a background asset in this PR.

- [ ] **Step 4: Hoist static Landing Basin resources out of `AnimatedBuilder.builder`**

Build `AnimatedBuilder.child` from resources whose `minerCount == 0`. Inside `builder`, compose:

```text
child static resource layer
mined resources only (minerCount > 0), using _depositAsset(deposit, t)
rigs only
```

At most four resources can be mined because the site rig cap remains four. Parent rebuilds caused by gameplay state naturally reconstruct static vs animated membership.

Do not add an animation registry/cache abstraction.

- [ ] **Step 5: Re-run presentation tests on VM + Chrome-sensitive path**

```sh
flutter test \
  test/mining/presentation/mining_grid_map_test.dart \
  test/mining/presentation/landing_basin_grid_visual_layer_test.dart \
  test/mining/presentation/mine_site_screen_test.dart
flutter test --platform chrome test/mining/presentation/mine_site_screen_test.dart
```

Expected: PASS. Leave already-skipped stale visual-parity goldens skipped.

- [ ] **Step 6: Perform the manual visual/readability gate**

Run the app on a portrait target and inspect:

1. **Landing Basin at initial Surveying** with a rig selected;
2. **Ochre Basin at Surveying 5**.

Require:

```text
initial top-left viewport exposes at least one highlighted legal perimeter cell
same-resource multi-robot placement is visibly understandable
~100 resource bodies read as a mining field rather than visual noise
pan/zoom remains usable
resource sprites do not visibly collide
repeated cavern background has no unacceptable seams/repetition
locked resources remain understandable without ~100 lock badges
```

If the repeated cavern image is visually unacceptable, stop the art portion here. Do not generate or add new art on HPA-454; create a separate image-generation ticket and keep that work independent.

- [ ] **Step 7: Commit presentation changes**

```sh
git add \
  lib/mining/presentation/mining_grid_map.dart \
  lib/mining/presentation/landing_basin_grid_visual_layer.dart \
  test/mining/presentation/mining_grid_map_test.dart \
  test/mining/presentation/landing_basin_grid_visual_layer_test.dart \
  test/mining/presentation/mine_site_screen_test.dart
git commit -m "feat(mining): render dense multi-robot fields efficiently"
```

---

### Task 5: Migrate remaining regressions, document the breaking cutover, and run the full gate

**Files:**
- Modify as needed: `test/mining/mining_simulation_test.dart`
- Modify as needed: `test/mining/mining_progression_views_test.dart`
- Modify as needed: `test/mining/presentation/site_deck_screen_test.dart`
- Modify as needed: `test/mining/presentation/visual_parity_golden_test.dart`
- Modify: `test/integration/merge_mining_journey_test.dart`
- Modify: `CLAUDE.md`
- Modify additional tests only when the audit proves they encode old content-valid coordinates/IDs/caps.

**Interfaces:**
- Consumes: `deployableMiningCells(...)`.
- Preserves: numeric simulation formulas/results for the same deployed-rig set and the public controller journey.
- Documents: 50×50 / 100-resource / geometry-slot / cached-perimeter contract and full invalid-save reset behavior.

- [ ] **Step 1: Audit old coordinate/ID/cap assumptions**

```sh
grep -R "MiningGridCell(" test/mining test/integration
grep -R "maxMiners\|depositAtCapacity\|MiningDepositId" lib test/mining test/integration
```

Classify every hit:

- content-valid placement fixture → use shared helper/cached perimeter;
- pure value/grid test → keep local coordinates;
- intentional invalid-placement test → keep/change only to preserve its rejection reason;
- obsolete ID/cap expectation → delete or rewrite around geometry.

Do not mass-replace coordinates.

- [ ] **Step 2: Migrate economy/progression/integration fixtures without changing formulas**

Use shared legal cells in simulation, Site Deck, and journey fixtures. Preserve existing rate/capacity/cargo/sale/offline/mastery/reward expected numbers **for the same deployed rig tiers**.

If Surveying UI tests expose resource-count copy, update only the expected resource availability counts to the new 100-resource content; do not change site reveal/technology cost/gate logic.

In skipped `visual_parity_golden_test.dart`, update only fixture legality as needed. Do not regenerate stale cross-platform goldens.

- [ ] **Step 3: Run the mining/integration slice**

```sh
flutter test test/mining test/integration/merge_mining_journey_test.dart
```

Expected: PASS.

- [ ] **Step 4: Update `CLAUDE.md` architecture guidance**

Replace the authored 24×18/four-deposit paragraph with:

```text
Mine Site is a Flutter InteractiveViewer over a deterministic 50×50 grid.
Each site derives 100 1×1/2×2/3×3 resource bodies from its site ID; resources
are not persisted. Rigs occupy one cell and mine their unique orthogonally
adjacent resource. Free unique perimeter cells are the only resource-level
placement capacity, sites remain capped at four rigs, static perimeter geometry
is cached with content, placement legality stays centralized in mining_grid.dart,
and production remains aggregate/deterministic in MiningSimulation. Landing
Basin remains the only site-specific animated visual layer and only mined
resources participate in its per-frame animation builder.
```

Also document that an invalid persisted placement resets the complete mining save through the existing recovery boundary.

- [ ] **Step 5: Run the full repository gate**

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

Expected: every command exits 0. Fix only regressions caused by HPA-454; record unrelated failures separately rather than broadening the ticket.

- [ ] **Step 6: Verify removals/scope and clean diff**

```sh
! grep -R "maxMiners\|depositAtCapacity\|MiningDepositId" lib test/mining test/integration
git diff --check
git status --short
git diff main...HEAD -- pubspec.yaml pubspec.lock assets/
```

Require:

```text
no package changes
no new/modified image assets
no save schema/version/migration
no resource ID/slot registry
no HPA-455 HP/damage work
```

- [ ] **Step 7: Commit the regression/documentation pass**

```sh
git add CLAUDE.md test/mining test/integration/merge_mining_journey_test.dart
git commit -m "test(mining): lock dense field regressions and cutover"
```

---

## PR completion checklist

Before marking the same HPA-454 PR ready for review, confirm all of the following:

- 50×50, exactly 100 unique resources/site, all 1×1/2×2/3×3;
- no overlaps, out-of-bounds footprints, or ambiguous adjacent cells;
- original four Surveying levels/site remain content;
- revised effective-slot table is pinned and monotonic;
- at each site's first playable Surveying level, one resource has at least two legal perimeter cells;
- two or more rigs can mine one resource from distinct cells;
- no `MiningDepositId`, `maxMiners`, `depositAtCapacity`, replacement resource ID, or slot registry;
- `stellarMining()` returns one cached instance;
- perimeter cells are cached with site content, rig miner counts are bucketed once, and deployable highlights do not scan all 2,500 cells;
- Landing Basin per-frame builder handles only mined resources + rigs, not all 100 resources;
- cavern background is tiled existing art and passes the manual visual gate;
- incompatible legacy geometry triggers full-save recovery and no migration exists;
- `MiningSimulation` formulas/numeric behavior stay unchanged for equal deployed rigs;
- no new art/package/framework/schema work is bundled;
- full repository gate passes.

HPA-455 starts only after this geometry/presentation contract lands.