# HPA-454 Dense Resource Fields and Multi-Robot Slots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace each four-deposit Mine Site with a deterministic 102-resource field and make distinct free perimeter cells the only per-resource mining-capacity rule while preserving the existing four-rig economy and Surveying pacing.

**Architecture:** Keep `MiningController`, `MiningSaveRepository`, `MineSiteView`, and `MiningSimulation` ownership unchanged. Generate immutable resource geometry from `MiningSiteId` inside `mining_content.dart`, keep `evaluateMiningPlacement(...)` as the single legality predicate, persist only rig tier/cell, and render the dense field with the existing Flutter `Stack`/`InteractiveViewer` path rather than a tile/widget subsystem.

**Tech Stack:** Dart, Flutter, `SharedPreferences`, `flutter_test`; no new package or asset dependency.

**Spec:** `docs/superpowers/specs/2026-09-16-hpa-454-dense-resource-fields-design.md`

## Global Constraints

- One Linear ticket = one implementation PR. All commits below stay on the HPA-454 PR; do not split by domain/view/test layer.
- Grid dimensions are exactly 50×50 and each site generates exactly 102 resource bodies.
- Resource footprints remain only 1×1, 2×2, or 3×3.
- Remove `MiningDepositId`, `maxMiners`, and `MiningPlacementRejection.depositAtCapacity`; do not replace them with a new resource ID/capacity field.
- Preserve `MiningContentRegistry.maxDeployedRigsPerSite == 4`.
- Preserve the current Surveying effective-slot arrays exactly as documented in the spec.
- `MiningSimulation` remains aggregate/deterministic. Do not add per-resource production, reserves, HP, depletion, respawn, or offline state.
- Save JSON remains strict and unversioned with the existing `rigPlacements: [{tier,x,y}]` shape. No migration or compatibility reader.
- Reuse current resource/rig art. No image generation or new asset task is part of HPA-454.
- HPA-455 HP/damage feedback, HPA-452 fleet interaction changes, and HPA-286 cargo/sell polish remain out of scope.
- Follow the repository verification gates in `CLAUDE.md` after focused tests pass.

---

### Task 1: Make perimeter geometry the only resource-level placement rule

**Files:**
- Modify: `lib/mining/mining_grid.dart`
- Modify: `test/mining/mining_grid_test.dart`

**Interfaces:**
- Produces: `MiningDepositDefinition(x, y, size, requiredSurveyingLevel)` with value equality.
- Produces: `miningPerimeterCells(...) -> Set<MiningGridCell>`.
- Preserves: `uniqueAdjacentDeposit(...)` and `evaluateMiningPlacement(...)` as the shared legality API.
- Removes: `MiningDepositId`, `MiningDepositDefinition.maxMiners`, and `MiningPlacementRejection.depositAtCapacity`.

- [ ] **Step 1: Replace the old cap-oriented grid tests with geometry-oriented failing tests**

Use a single 1×1 target at `(3,3)` to prove all four perimeter cells exist, then prove a second and third rig may target that same resource through different cells:

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

Also keep explicit tests for site capacity, bounds, resource footprint, occupied candidate, no adjacency, ambiguous adjacency, and Surveying lock. The former `depositAtCapacity` assertion must become an allowed placement assertion.

- [ ] **Step 2: Run the focused grid test and confirm it fails against the old API**

Run:

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected failure: construction still requires `id`/`maxMiners`, `miningPerimeterCells` does not exist, and/or a second rig is rejected by `depositAtCapacity`.

- [ ] **Step 3: Simplify `MiningDepositDefinition` and add value equality**

Implement the definition with geometry + Surveying only:

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

  bool contains(MiningGridCell cell) =>
      cell.x >= x && cell.x < x + size && cell.y >= y && cell.y < y + size;

  bool isOrthogonallyAdjacent(MiningGridCell cell) {
    final inColumns = cell.x >= x && cell.x < x + size;
    final inRows = cell.y >= y && cell.y < y + size;
    return (inColumns && (cell.y == y - 1 || cell.y == y + size)) ||
        (inRows && (cell.x == x - 1 || cell.x == x + size));
  }

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

- [ ] **Step 4: Add one perimeter helper and remove the resource-level miner-count check**

Compute perimeter candidates from the footprint boundary, then keep only cells that are in bounds, not resource cells, and uniquely resolve back to the requested target:

```dart
Set<MiningGridCell> miningPerimeterCells({
  required int gridWidth,
  required int gridHeight,
  required List<MiningDepositDefinition> deposits,
  required MiningDepositDefinition target,
}) {
  final candidates = <MiningGridCell>{};
  for (var x = target.x; x < target.x + target.size; x++) {
    candidates.add(MiningGridCell(x, target.y - 1));
    candidates.add(MiningGridCell(x, target.y + target.size));
  }
  for (var y = target.y; y < target.y + target.size; y++) {
    candidates.add(MiningGridCell(target.x - 1, y));
    candidates.add(MiningGridCell(target.x + target.size, y));
  }

  return {
    for (final cell in candidates)
      if (cell.x >= 0 &&
          cell.x < gridWidth &&
          cell.y >= 0 &&
          cell.y < gridHeight &&
          !deposits.any((deposit) => deposit.contains(cell)) &&
          uniqueAdjacentDeposit(deposits: deposits, cell: cell) == target)
        cell,
  };
}
```

Delete `depositAtCapacity` from the rejection enum and delete the existing `miners >= target.maxMiners` branch from `evaluateMiningPlacement(...)`. Keep `rigOccupied` unchanged: it is the rule that makes one occupied perimeter cell unavailable without blocking sibling cells.

- [ ] **Step 5: Re-run the domain test**

Run:

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: PASS, including two distinct cells targeting the same resource.

- [ ] **Step 6: Commit the domain contract**

```sh
git add lib/mining/mining_grid.dart test/mining/mining_grid_test.dart
git commit -m "refactor(mining): derive resource capacity from perimeter cells"
```

---

### Task 2: Generate the deterministic 102-resource field and preserve Surveying pacing

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `test/mining/mining_content_test.dart`

**Interfaces:**
- Produces: every `MiningSiteDefinition` with `gridWidth == 50`, `gridHeight == 50`, and 102 generated `deposits`.
- Consumes: the simplified `MiningDepositDefinition` and `miningPerimeterCells(...)` from Task 1.
- Preserves: all economy, progression, planet, asset, and resource-type metadata outside the resource geometry list.

- [ ] **Step 1: Rewrite content invariants as failing dense-field tests**

Keep existing economy/planet/asset assertions. Replace the four-ID/four-authored-deposit assertions with:

```dart
for (final siteId in MiningSiteId.values) {
  final first = MiningContentRegistry.stellarMining().site(siteId);
  final second = MiningContentRegistry.stellarMining().site(siteId);

  expect(first.gridWidth, 50, reason: first.name);
  expect(first.gridHeight, 50, reason: first.name);
  expect(first.deposits, hasLength(102), reason: first.name);
  expect(second.deposits, first.deposits, reason: first.name);
  expect(first.deposits.map((d) => d.size).toSet(), {1, 2, 3});
}
```

Retain the existing exhaustive overlap/ambiguous-adjacency scan but run it over all 102 resources.

Freeze the existing Surveying envelope by counting unique legal perimeter cells whose target is surveyed and clamping to four:

```dart
final expectedBySite = <MiningSiteId, List<int>>{
  MiningSiteId.landingBasin: [2, 3, 4, 4, 4, 4],
  MiningSiteId.carbonRidge: [1, 2, 3, 4, 4, 4],
  MiningSiteId.graniteCrater: [1, 2, 3, 4, 4, 4],
  MiningSiteId.frozenBasin: [0, 0, 0, 2, 3, 4],
  MiningSiteId.titaniumHighlands: [0, 0, 0, 0, 2, 4],
  MiningSiteId.heliumMare: [0, 0, 0, 0, 0, 4],
  MiningSiteId.ochreBasin: [0, 0, 0, 0, 0, 4],
  MiningSiteId.silicaDunes: [0, 0, 0, 0, 0, 4],
  MiningSiteId.cobaltChasm: [0, 0, 0, 0, 0, 4],
};
```

For each level, collect cells from `miningPerimeterCells(...)` only for resources whose `requiredSurveyingLevel <= level`, then assert `min(4, cells.length)` equals the table.

- [ ] **Step 2: Run content tests and confirm the current four-deposit model fails**

```sh
flutter test test/mining/mining_content_test.dart
```

Expected: FAIL on 24×18 dimensions, four-resource count, old IDs/max-miner fields, and the new deterministic-field assertions.

- [ ] **Step 3: Add the four authored Surveying anchor profiles and field constants**

Inside `mining_content.dart`, keep this data private and literal:

```dart
const _denseGridWidth = 50;
const _denseGridHeight = 50;
const _anchorXs = [5, 17, 29, 41];

const _surveyingAnchorLevels = <MiningSiteId, List<int>>{
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

These four integers/site are progression content, not per-resource capacities.

- [ ] **Step 4: Implement the one pure field generator**

Add one private helper; do not create a generator class/strategy/registry:

```dart
List<MiningDepositDefinition> _denseResourceField(MiningSiteId siteId) {
  final levels = _surveyingAnchorLevels[siteId]!;
  final maxLevel = levels.reduce((a, b) => a > b ? a : b);
  final deposits = <MiningDepositDefinition>[];

  for (var index = 0; index < _anchorXs.length; index++) {
    final x = _anchorXs[index];
    deposits.add(
      MiningDepositDefinition(
        x: x - 1,
        y: 0,
        size: 1,
        requiredSurveyingLevel: maxLevel,
      ),
    );
    deposits.add(
      MiningDepositDefinition(
        x: x,
        y: 0,
        size: 1,
        requiredSurveyingLevel: levels[index],
      ),
    );
    deposits.add(
      MiningDepositDefinition(
        x: x + 1,
        y: 0,
        size: 1,
        requiredSurveyingLevel: maxLevel,
      ),
    );
  }

  for (var row = 0; row < 9; row++) {
    for (var column = 0; column < 10; column++) {
      final index = row * 10 + column;
      final value =
          (siteId.index * 31 + index * 17 + index * index * 7) % 97;
      final size = 1 + value % 3;
      final movableSpan = 4 - size;
      final offsetX = 1 + (value ~/ 3) % movableSpan;
      final offsetY = 1 + (value ~/ 11) % movableSpan;
      deposits.add(
        MiningDepositDefinition(
          x: column * 5 + offsetX,
          y: 5 + row * 5 + offsetY,
          size: size,
          requiredSurveyingLevel: maxLevel,
        ),
      );
    }
  }

  return List.unmodifiable(deposits);
}
```

Change `MiningContentRegistry.stellarMining()` from a const-authored registry construction to deterministic runtime construction and replace every old `gridWidth`, `gridHeight`, and four-element `deposits` block with:

```dart
gridWidth: _denseGridWidth,
gridHeight: _denseGridHeight,
deposits: _denseResourceField(MiningSiteId.landingBasin),
```

using the matching site ID at each site.

- [ ] **Step 5: Re-run content invariants**

```sh
flutter test test/mining/mining_content_test.dart
```

Expected: PASS with 102 resources/site, all three sizes on every site, no overlaps, no ambiguous adjacency, deterministic reconstruction, and the exact existing Surveying slot table.

- [ ] **Step 6: Commit generated content**

```sh
git add lib/mining/mining_content.dart test/mining/mining_content_test.dart
git commit -m "feat(mining): generate dense deterministic resource fields"
```

---

### Task 3: Cut controller/save/view code over to geometry identity and shared test fixtures

**Files:**
- Modify: `lib/mining/mining_controller.dart`
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/mining/mine_site_view.dart`
- Create: `test/support/mining_grid_fixtures.dart`
- Modify: `test/mining/mining_controller_test.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Modify: `test/mining/mine_site_view_test.dart`

**Interfaces:**
- `MiningController.deployRig(...)` and save decoding continue calling only `evaluateMiningPlacement(...)`.
- `MineSiteDepositView` produces `minerCount`, `slotCount`, and `isSurveyed` from deterministic geometry.
- Test-only `deployableMiningCells(...)` provides stable legal cells to higher-level tests without copying generator coordinates.
- Save JSON remains unchanged.

- [ ] **Step 1: Add failing view/controller/save tests for multi-robot geometry**

In `mine_site_view_test.dart`, build a state with two rigs on two perimeter cells of the first Surveying-0 Landing Basin anchor and assert both resolve to the same `MiningDepositDefinition`, with `minerCount == 2`.

In `mining_controller_test.dart`, deploy two dock rigs to two distinct perimeter cells around one surveyed resource and assert both actions succeed and both placements persist.

In `mining_save_repository_test.dart`, round-trip that state and assert the reloaded placements still resolve to the same resource geometry. Add a recovery case that encodes the old Landing Basin `(3,2)` cell and expects `recoveredFromInvalidSave == true` under the new field.

- [ ] **Step 2: Run focused integration tests and capture compile/behavior failures**

```sh
flutter test \
  test/mining/mining_controller_test.dart \
  test/mining/mining_save_repository_test.dart \
  test/mining/mine_site_view_test.dart
```

Expected initial failures: `depositAtCapacity` switch branches and `.id`/`.maxMiners` references no longer compile, and old fixture coordinates are invalid.

- [ ] **Step 3: Remove obsolete controller/save cap handling without adding replacement state**

Delete only the `MiningPlacementRejection.depositAtCapacity` arms from controller/view error switches. Do not change the `deployRig(...)` save shape or `_decodeRigPlacements(...)` flow; both continue using the shared placement result.

`MiningSaveRepository` should still decode incrementally:

```dart
final result = evaluateMiningPlacement(
  gridWidth: definition.gridWidth,
  gridHeight: definition.gridHeight,
  deposits: definition.deposits,
  occupiedRigCells: decoded.map((placement) => placement.cell),
  candidate: cell,
  surveyingLevel: technology.surveying,
  maxRigCount: MiningContentRegistry.maxDeployedRigsPerSite,
);
```

No resource ID is added to JSON.

- [ ] **Step 4: Make `MineSiteView` derive miner counts and slot counts from geometry**

Build each resource view with equality on the deterministic definition instead of an ID:

```dart
MineSiteDepositView(
  definition: deposit,
  minerCount: progress.rigPlacements.where((placement) {
    return uniqueAdjacentDeposit(
          deposits: definition.deposits,
          cell: placement.cell,
        ) ==
        deposit;
  }).length,
  slotCount: miningPerimeterCells(
    gridWidth: definition.gridWidth,
    gridHeight: definition.gridHeight,
    deposits: definition.deposits,
    target: deposit,
  ).length,
  isSurveyed: surveyingLevel >= deposit.requiredSurveyingLevel,
)
```

`MineSiteRigView.target` continues storing the derived definition only for the in-memory view.

- [ ] **Step 5: Add a small test-only legal-cell helper**

Create `test/support/mining_grid_fixtures.dart`:

```dart
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';

List<MiningGridCell> deployableMiningCells({
  required MiningContentRegistry content,
  required MiningSiteId siteId,
  int surveyingLevel = 5,
}) {
  final site = content.site(siteId);
  return [
    for (var y = 0; y < site.gridHeight; y++)
      for (var x = 0; x < site.gridWidth; x++)
        if (evaluateMiningPlacement(
          gridWidth: site.gridWidth,
          gridHeight: site.gridHeight,
          deposits: site.deposits,
          occupiedRigCells: const [],
          candidate: MiningGridCell(x, y),
          surveyingLevel: surveyingLevel,
          maxRigCount: MiningContentRegistry.maxDeployedRigsPerSite,
        ).isAllowed)
          MiningGridCell(x, y),
  ];
}
```

Higher-level tests may index this deterministic row-major list. Geometry tests in Tasks 1–2 remain the independent protection against the helper masking a generator regression.

- [ ] **Step 6: Replace old coordinate fixtures only where legality matters**

Update the focused controller/save/view tests to use `deployableMiningCells(...)`. Leave `mining_state_test.dart`'s pure `MiningRigPlacement` value-equality coordinate unchanged because it is not a content-validity fixture.

- [ ] **Step 7: Re-run the focused tests**

```sh
flutter test \
  test/mining/mining_controller_test.dart \
  test/mining/mining_save_repository_test.dart \
  test/mining/mine_site_view_test.dart
```

Expected: PASS, including same-resource multi-robot deploy and unchanged save JSON.

- [ ] **Step 8: Commit the integration cutover**

```sh
git add \
  lib/mining/mining_controller.dart \
  lib/mining/mining_save_repository.dart \
  lib/mining/mine_site_view.dart \
  test/support/mining_grid_fixtures.dart \
  test/mining/mining_controller_test.dart \
  test/mining/mining_save_repository_test.dart \
  test/mining/mine_site_view_test.dart
git commit -m "refactor(mining): derive rig targets from dense field geometry"
```

---

### Task 4: Render the dense field without per-resource HUD clutter

**Files:**
- Modify: `lib/mining/presentation/mining_grid_map.dart`
- Modify: `lib/mining/presentation/landing_basin_grid_visual_layer.dart`
- Modify: `test/mining/presentation/mining_grid_map_test.dart`
- Modify: `test/mining/presentation/landing_basin_grid_visual_layer_test.dart`
- Modify: `test/mining/presentation/mine_site_screen_test.dart`

**Interfaces:**
- Consumes: `MineSiteDepositView.slotCount`, `minerCount`, `isSurveyed`.
- Preserves: one image per resource, one image per rig, one semantics region per resource, one `CustomPaint` grid/highlight layer.
- Uses geometry-derived widget keys; no runtime resource IDs.

- [ ] **Step 1: Add failing presentation assertions for dense resources and geometry keys**

For a static non-gold site, assert the visual layer renders exactly `view.deposits.length == 102` resource images.

For Landing Basin, find a known generated resource and assert a geometry key of the form:

```dart
Key(
  'landing-basin-deposit-'
  '${deposit.definition.x}-${deposit.definition.y}-${deposit.definition.size}',
)
```

Add a semantics assertion that a mined resource says its footprint, miner count, free/total perimeter slots, and Surveying requirement when locked.

Also assert no `_DepositLockBadge`-style visible badge is repeated across the field; locked state is represented by dimmed art + semantics/tap feedback.

- [ ] **Step 2: Run the three presentation tests and confirm old ID/cap copy fails**

```sh
flutter test \
  test/mining/presentation/mining_grid_map_test.dart \
  test/mining/presentation/landing_basin_grid_visual_layer_test.dart \
  test/mining/presentation/mine_site_screen_test.dart
```

Expected initial failures: `.id.name` and `.maxMiners` references, old keyed finders, and old legal fixture coordinates.

- [ ] **Step 3: Replace ID-based keys and cap copy with geometry-derived presentation**

Use one helper local to `mining_grid_map.dart`:

```dart
String _depositKey(MiningDepositDefinition definition) =>
    '${definition.x}-${definition.y}-${definition.size}';
```

Keys become:

```dart
Key('mining-deposit-${_depositKey(deposit.definition)}')
Key('landing-basin-deposit-${_depositKey(deposit.definition)}')
```

Update resource semantics along these lines:

```dart
final freeSlots = deposit.slotCount - deposit.minerCount;
final locked = deposit.isSurveyed
    ? ''
    : ' Requires Surveying ${definition.requiredSurveyingLevel}.';
return '$resource resource ${definition.size}x${definition.size}, '
    '${deposit.minerCount} miners, '
    '$freeSlots of ${deposit.slotCount} perimeter slots free.$locked';
```

- [ ] **Step 4: Dim unsurveyed art instead of rendering ~100 lock badges**

Remove the per-resource `_DepositLockBadge` overlay. In the static layer, wrap the resource image with opacity determined by `deposit.isSurveyed`. In the Landing Basin layer, combine Surveying dimming with the existing unmined opacity without changing impact timing:

```dart
final opacity = !deposit.isSurveyed
    ? .30
    : deposit.minerCount > 0
    ? 1.0
    : .62;
```

Use that value through `AlwaysStoppedAnimation(opacity)` when it is below 1.0. Keep `onMiningImpact`, reduced motion, and robot strike direction untouched.

- [ ] **Step 5: Migrate presentation fixtures through the shared test helper**

Use `deployableMiningCells(...)` for generic rig placement in `mining_grid_map_test.dart` and `mine_site_screen_test.dart`.

For Landing Basin direction tests, use the fixed progression-anchor slots `(5,1)`, `(17,1)`, `(29,1)`, `(41,1)` only where exact left/right target geometry is itself the subject of the test.

- [ ] **Step 6: Re-run presentation tests on VM and Chrome-sensitive code paths**

```sh
flutter test \
  test/mining/presentation/mining_grid_map_test.dart \
  test/mining/presentation/landing_basin_grid_visual_layer_test.dart \
  test/mining/presentation/mine_site_screen_test.dart
flutter test --platform chrome test/mining/presentation/mine_site_screen_test.dart
```

Expected: PASS. Do not unskip or regenerate the already-skipped stale visual-parity goldens as part of HPA-454.

- [ ] **Step 7: Commit presentation changes**

```sh
git add \
  lib/mining/presentation/mining_grid_map.dart \
  lib/mining/presentation/landing_basin_grid_visual_layer.dart \
  test/mining/presentation/mining_grid_map_test.dart \
  test/mining/presentation/landing_basin_grid_visual_layer_test.dart \
  test/mining/presentation/mine_site_screen_test.dart
git commit -m "feat(mining): render dense multi-robot resource fields"
```

---

### Task 5: Migrate remaining layout-dependent regressions and prove the economy stayed unchanged

**Files:**
- Modify: `test/mining/mining_simulation_test.dart`
- Modify: `test/mining/presentation/site_deck_screen_test.dart`
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Modify: `test/integration/merge_mining_journey_test.dart`
- Modify: `CLAUDE.md`
- Modify any additional test found by the coordinate audit only when it encodes a content-valid rig placement.

**Interfaces:**
- Consumes: `deployableMiningCells(...)` test helper.
- Preserves: existing numeric production/capacity/offline assertions and public controller journey.
- Documents: the new 50×50/102-resource/geometry-slot Mine Site contract.

- [ ] **Step 1: Audit remaining old authored-coordinate assumptions**

Run:

```sh
grep -R "MiningGridCell(" test/mining test/integration
```

For each match, classify it:

- content-valid placement fixture → switch to `deployableMiningCells(...)` or a deliberate progression-anchor cell;
- pure grid/value-object unit test → keep its local coordinate;
- expected invalid-placement test → keep or change it only to preserve the intended rejection reason.

Do not mass-replace coordinates blindly.

- [ ] **Step 2: Migrate economy and integration fixtures without changing expected numbers**

`mining_simulation_test.dart`, `site_deck_screen_test.dart`, and `merge_mining_journey_test.dart` should source legal rig cells from the helper. Keep all existing rate, capacity, cargo, sale, offline, unlock, mastery, and reward expected values unchanged.

The public journey must still use controller actions only; change its site→cell fixture, not its behavior.

In `visual_parity_golden_test.dart`, change only `_operationalState()`'s rig placement so the skipped golden fixture remains constructible. Keep the Mine Site golden tests skipped as they are today; HPA-454 does not turn stale cross-platform image baselines into a delivery dependency.

- [ ] **Step 3: Run the full mining test slice before documentation**

```sh
flutter test test/mining test/integration/merge_mining_journey_test.dart
```

Expected: PASS with existing economy assertions unchanged.

- [ ] **Step 4: Update repository architecture guidance to the new contract**

Replace the obsolete `CLAUDE.md` paragraph describing an authored 24×18/four-deposit grid with a concise statement equivalent to:

```text
Mine Site is a Flutter InteractiveViewer over a deterministic 50×50 grid.
Each site derives 102 1×1/2×2/3×3 resource bodies from its site ID; resources
are not persisted. Rigs occupy one cell and mine their unique orthogonally
adjacent resource. Free unique perimeter cells are the only resource-level
placement capacity, sites remain capped at four rigs, placement legality stays
centralized in mining_grid.dart, and production remains aggregate/deterministic
in MiningSimulation. Landing Basin remains the only site-specific animated
visual layer.
```

Also remove guidance that refers to four static deposits or `maxMiners`.

- [ ] **Step 5: Run format/analyze and the repository gate**

Run exactly:

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

Expected: every command exits 0. If a failure reveals application behavior outside HPA-454, do not broaden the ticket; fix only regressions caused by this cutover or record the unrelated failure separately.

- [ ] **Step 6: Verify the intended removals and no accidental persistence/art expansion**

Run:

```sh
! grep -R "maxMiners\|depositAtCapacity\|MiningDepositId" lib test/mining test/integration
git diff --check
git status --short
```

Inspect `git diff main...HEAD -- pubspec.yaml pubspec.lock assets/` and require no dependency or asset changes.

- [ ] **Step 7: Commit the regression/documentation pass**

```sh
git add CLAUDE.md test/mining test/integration/merge_mining_journey_test.dart
git commit -m "test(mining): lock dense field progression and regressions"
```

---

## PR completion checklist

Before marking the same HPA-454 PR ready for review, confirm all of the following in the PR description or test evidence:

- 50×50, exactly 102 resources/site, all 1×1/2×2/3×3;
- deterministic repeated construction and no overlapping/ambiguous geometry;
- exact existing Surveying-to-four-rig slot arrays preserved;
- two or more rigs can mine one resource from distinct free perimeter cells;
- no `maxMiners`, `depositAtCapacity`, replacement resource ID, or slot registry;
- strict save JSON unchanged and invalid old geometry uses existing recovery;
- `MiningSimulation` numeric behavior unchanged;
- Landing Basin animation remains presentation-only;
- no new image assets, packages, framework, schema, or migration;
- full repository gate passes.

This ticket is complete in one implementation PR. HPA-455 starts only after this geometry contract lands.