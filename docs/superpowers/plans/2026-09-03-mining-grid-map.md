# Mining Grid Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every fixed four-node Mine Site with a pannable authored grid where up to four player-placed rigs mine orthogonally adjacent deposits with 1x1, 2x2, and 3x3 footprints and per-deposit miner caps.

**Architecture:** Keep the existing `MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository` ownership. Add one small pure-Dart grid/deposit model, replace `rigByNode` with at-most-four grid placements, derive each rig's target deposit from static adjacency, and render the map with Flutter `InteractiveViewer` plus one `CustomPainter`. Production remains aggregate elapsed-time math over deployed rig tiers; no movement/pathfinding or per-frame economy is introduced.

**Tech Stack:** Flutter/Dart, existing SharedPreferences mining save repository, built-in `InteractiveViewer`, `CustomPainter`, existing mining asset bundle, Flutter unit/widget/golden tests.

**Spec:** `docs/superpowers/specs/2026-09-03-mining-grid-map-design.md`

## Global Constraints

- Continue planning and implementation on draft PR #23; do not open a second implementation PR.
- Keep `Planet -> Site Deck -> Mine Site`; one existing site equals one grid map and retains one `ResourceType`.
- Every current site starts at exactly `24 x 18` cells with four static authored deposits.
- Initial deposit shapes/caps are `d1=1x1/1`, `d2=1x1/1`, `d3=2x2/2`, `d4=3x3/3` miners.
- Keep at most four deployed rigs per site so maximum site throughput/storage does not silently exceed the current four-node economy.
- Rigs occupy one grid cell, do not move, and mine only an orthogonally adjacent deposit. Diagonals never count.
- Built-in authored maps must guarantee every empty cell is adjacent to at most one deposit; target identity is derived and is not persisted.
- Keep existing `RigTier`, Fleet Dock, spawn/merge flow, rate multipliers, capacity multipliers, Extraction/Logistics modifiers, offline caps, selling, commissioning, planet mastery, and Technology progression.
- Deposits are infinite. `maxMiners` is a simultaneous-rig cap, not a resource reserve.
- Replace `rigByNode` with grid placements as a breaking save shape. Do not add a schema version, migration registry, legacy decoder, or compatibility converter.
- Keep strict save recovery: an old `rigByNode` document is invalid and starts a fresh mining save through the existing recovery boundary.
- Use Flutter `InteractiveViewer`; do not add Flame, ECS, a camera abstraction, a tile-map package, pathfinding, or a new dependency.
- Do not add drag-to-deploy/move, procedural deposits, finite depletion, conveyors, power, multiple resource types per site, diagonal mining, or persisted camera state.
- Do not implement HPA-451 hit-synchronized animation in this PR. PR #22 should be revised/rebased after the grid implementation lands.
- `AGENTS.md` follows `CLAUDE.md`; update only `CLAUDE.md` when repository guidance changes.

---

## Final File Map

Create:

```text
lib/mining/mining_grid.dart
lib/mining/presentation/mining_grid_map.dart
test/mining/mining_grid_test.dart
test/mining/presentation/mining_grid_map_test.dart
```

Modify:

```text
lib/mining/mining_content.dart
lib/mining/mining_state.dart
lib/mining/mining_save_repository.dart
lib/mining/mining_controller.dart
lib/mining/mining_simulation.dart
lib/mining/mine_site_view.dart
lib/mining/site_deck_view.dart
lib/mining/presentation/mining_shell.dart
lib/mining/presentation/mine_site_screen.dart
test/mining/mining_content_test.dart
test/mining/mining_state_test.dart
test/mining/mining_save_repository_test.dart
test/mining/mining_controller_test.dart
test/mining/mining_simulation_test.dart
test/mining/mine_site_view_test.dart
test/mining/site_deck_view_test.dart
test/mining/presentation/mining_shell_test.dart
test/mining/presentation/mine_site_screen_test.dart
test/mining/presentation/visual_parity_golden_test.dart
test/mining/presentation/goldens/mine_site_430x932.png
test/mining/presentation/goldens/mine_site_874x402.png
CLAUDE.md
```

Do not create a second grid/domain package. Keep the new pure geometry in `lib/mining/mining_grid.dart` beside the existing flat mining core.

---

### Task 1: Replace Fixed Nodes with Authored Grid Deposits

**Files:**
- Create: `lib/mining/mining_grid.dart`
- Create: `test/mining/mining_grid_test.dart`
- Modify: `lib/mining/mining_content.dart`
- Modify: `test/mining/mining_content_test.dart`

**Interfaces:**
- Produces: `MiningGridCell`, `MiningDepositId`, `MiningDepositDefinition`.
- Produces on `MiningSiteDefinition`: `gridWidth`, `gridHeight`, `deposits`, `depositAsset`, `containsGridCell(...)`, `isDepositCell(...)`, `adjacentDeposits(...)`.
- Removes: `MiningNodeId`, `MiningNodeDefinition`, `MiningSiteDefinition.nodes`, `MiningSiteDefinition.nodeAsset`.
- Consumed by: persistence in Task 2, controller/view code in Tasks 3-4, presentation in Task 5.

- [ ] **Step 1: Write failing geometry tests**

Create `test/mining/mining_grid_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_grid.dart';

void main() {
  const one = MiningDepositDefinition(
    id: MiningDepositId.d1,
    x: 5,
    y: 5,
    size: 1,
    maxMiners: 1,
    requiredSurveyingLevel: 0,
  );
  const large = MiningDepositDefinition(
    id: MiningDepositId.d4,
    x: 10,
    y: 8,
    size: 3,
    maxMiners: 3,
    requiredSurveyingLevel: 2,
  );

  test('deposit footprint uses square grid cells', () {
    expect(one.contains(const MiningGridCell(5, 5)), isTrue);
    expect(one.contains(const MiningGridCell(6, 5)), isFalse);
    expect(large.contains(const MiningGridCell(10, 8)), isTrue);
    expect(large.contains(const MiningGridCell(12, 10)), isTrue);
    expect(large.contains(const MiningGridCell(13, 10)), isFalse);
  });

  test('only edge-sharing cells are adjacent', () {
    expect(one.isOrthogonallyAdjacent(const MiningGridCell(5, 4)), isTrue);
    expect(one.isOrthogonallyAdjacent(const MiningGridCell(4, 5)), isTrue);
    expect(one.isOrthogonallyAdjacent(const MiningGridCell(4, 4)), isFalse);
    expect(one.isOrthogonallyAdjacent(const MiningGridCell(5, 5)), isFalse);

    expect(large.isOrthogonallyAdjacent(const MiningGridCell(11, 7)), isTrue);
    expect(large.isOrthogonallyAdjacent(const MiningGridCell(13, 9)), isTrue);
    expect(large.isOrthogonallyAdjacent(const MiningGridCell(13, 11)), isFalse);
  });
}
```

- [ ] **Step 2: Run the new test and verify RED**

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: FAIL because the grid types do not exist.

- [ ] **Step 3: Add the minimal pure-Dart grid types**

Create `lib/mining/mining_grid.dart`:

```dart
enum MiningDepositId { d1, d2, d3, d4 }

class MiningGridCell {
  const MiningGridCell(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is MiningGridCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class MiningDepositDefinition {
  const MiningDepositDefinition({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.maxMiners,
    required this.requiredSurveyingLevel,
  });

  final MiningDepositId id;
  final int x;
  final int y;
  final int size;
  final int maxMiners;
  final int requiredSurveyingLevel;

  bool contains(MiningGridCell cell) =>
      cell.x >= x &&
      cell.x < x + size &&
      cell.y >= y &&
      cell.y < y + size;

  bool isOrthogonallyAdjacent(MiningGridCell cell) {
    final withinColumns = cell.x >= x && cell.x < x + size;
    final withinRows = cell.y >= y && cell.y < y + size;
    return (withinColumns && (cell.y == y - 1 || cell.y == y + size)) ||
        (withinRows && (cell.x == x - 1 || cell.x == x + size));
  }
}
```

Do not add a generic rectangle/tile abstraction.

- [ ] **Step 4: Run the geometry tests and verify GREEN**

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write failing content-layout invariants**

Add to `test/mining/mining_content_test.dart`:

```dart
test('all mine sites have valid unambiguous authored grids', () {
  final content = MiningContentRegistry.stellarMining();

  for (final planet in content.planets.values) {
    for (final site in planet.sites) {
      expect(site.gridWidth, 24, reason: site.name);
      expect(site.gridHeight, 18, reason: site.name);
      expect(site.deposits.map((d) => d.id).toSet(), MiningDepositId.values.toSet());
      expect(site.deposits.map((d) => d.size).toList(), [1, 1, 2, 3]);
      expect(site.deposits.map((d) => d.maxMiners).toList(), [1, 1, 2, 3]);

      for (final deposit in site.deposits) {
        expect(deposit.size, inInclusiveRange(1, 3));
        expect(deposit.x, greaterThanOrEqualTo(0));
        expect(deposit.y, greaterThanOrEqualTo(0));
        expect(deposit.x + deposit.size, lessThanOrEqualTo(site.gridWidth));
        expect(deposit.y + deposit.size, lessThanOrEqualTo(site.gridHeight));
      }

      for (var x = 0; x < site.gridWidth; x++) {
        for (var y = 0; y < site.gridHeight; y++) {
          final cell = MiningGridCell(x, y);
          final containing = site.deposits.where((d) => d.contains(cell)).toList();
          expect(containing.length, lessThanOrEqualTo(1), reason: '${site.name} $cell');
          if (containing.isNotEmpty) continue;
          final adjacent = site.adjacentDeposits(cell).toList();
          expect(adjacent.length, lessThanOrEqualTo(1), reason: '${site.name} $cell');
        }
      }

      for (final deposit in site.deposits) {
        var availablePerimeter = 0;
        for (var x = 0; x < site.gridWidth; x++) {
          for (var y = 0; y < site.gridHeight; y++) {
            final cell = MiningGridCell(x, y);
            if (deposit.isOrthogonallyAdjacent(cell) && !site.isDepositCell(cell)) {
              availablePerimeter++;
            }
          }
        }
        expect(availablePerimeter, greaterThanOrEqualTo(deposit.maxMiners));
      }
    }
  }
});
```

Give `MiningGridCell.toString()` a compact `($x,$y)` implementation if the failure output is unreadable; do not add more behavior for tests.

- [ ] **Step 6: Evolve `MiningSiteDefinition` and author the nine maps**

In `mining_content.dart`, remove `MiningNodeId` / `MiningNodeDefinition`, import `mining_grid.dart`, and replace `nodes` / `nodeAsset` with:

```dart
required this.gridWidth,
required this.gridHeight,
required this.deposits,
required this.depositAsset,

final int gridWidth;
final int gridHeight;
final List<MiningDepositDefinition> deposits;
final String depositAsset;

bool containsGridCell(MiningGridCell cell) =>
    cell.x >= 0 && cell.x < gridWidth && cell.y >= 0 && cell.y < gridHeight;

bool isDepositCell(MiningGridCell cell) => deposits.any((d) => d.contains(cell));

Iterable<MiningDepositDefinition> adjacentDeposits(MiningGridCell cell) =>
    deposits.where((d) => d.isOrthogonallyAdjacent(cell));
```

Add to `MiningContentRegistry`:

```dart
static const int maxDeployedRigsPerSite = 4;
```

Author every site with `gridWidth: 24`, `gridHeight: 18`, and the exact coordinates/Surveying levels from the design spec. For Landing Basin, the concrete row is:

```dart
deposits: const [
  MiningDepositDefinition(
    id: MiningDepositId.d1,
    x: 3,
    y: 3,
    size: 1,
    maxMiners: 1,
    requiredSurveyingLevel: 0,
  ),
  MiningDepositDefinition(
    id: MiningDepositId.d2,
    x: 16,
    y: 3,
    size: 1,
    maxMiners: 1,
    requiredSurveyingLevel: 0,
  ),
  MiningDepositDefinition(
    id: MiningDepositId.d3,
    x: 5,
    y: 11,
    size: 2,
    maxMiners: 2,
    requiredSurveyingLevel: 1,
  ),
  MiningDepositDefinition(
    id: MiningDepositId.d4,
    x: 16,
    y: 10,
    size: 3,
    maxMiners: 3,
    requiredSurveyingLevel: 2,
  ),
],
depositAsset: 'assets/images/mining/nodes/gold.png',
```

Apply the remaining eight coordinate rows and existing N1-N4 Surveying values exactly from the spec; keep each site's current asset path, resource, rate, capacity, sale value, unlock data, and planet metadata unchanged.

- [ ] **Step 7: Run content and geometry tests**

```sh
flutter test test/mining/mining_grid_test.dart test/mining/mining_content_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit the authored grid model**

```sh
git add \
  lib/mining/mining_grid.dart \
  lib/mining/mining_content.dart \
  test/mining/mining_grid_test.dart \
  test/mining/mining_content_test.dart
git commit -m "feat(mining): author mine site grids"
```

---

### Task 2: Persist Up to Four Rig Grid Placements

**Files:**
- Modify: `lib/mining/mining_state.dart`
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `test/mining/mining_state_test.dart`
- Modify: `test/mining/mining_save_repository_test.dart`

**Interfaces:**
- Produces: `MiningRigPlacement { RigTier tier; MiningGridCell cell; }`.
- Changes `SiteProgress.rigByNode` -> `SiteProgress.rigPlacements`.
- Save shape: `rigPlacements: [{"tier":"t1","x":3,"y":2}, ...]`.
- Consumed by: controller/simulation in Task 3 and views in Task 4.

- [ ] **Step 1: Write failing state serialization tests**

Add to `test/mining/mining_state_test.dart`:

```dart
test('site progress serializes rig placements by tier and cell', () {
  const progress = SiteProgress(
    unlocked: true,
    commissioned: true,
    storedAmount: 12.5,
    rigPlacements: [
      MiningRigPlacement(
        tier: RigTier.t1,
        cell: MiningGridCell(3, 2),
      ),
      MiningRigPlacement(
        tier: RigTier.t3,
        cell: MiningGridCell(16, 2),
      ),
    ],
  );

  expect(progress.toJson()['rigPlacements'], [
    {'tier': 't1', 'x': 3, 'y': 2},
    {'tier': 't3', 'x': 16, 'y': 2},
  ]);
});
```

Update existing initial-state expectations so every site starts with `rigPlacements: const []` rather than exact N1-N4 null entries.

- [ ] **Step 2: Run the state test and verify RED**

```sh
flutter test test/mining/mining_state_test.dart
```

Expected: FAIL because `MiningRigPlacement` / `rigPlacements` do not exist.

- [ ] **Step 3: Replace the node map in `mining_state.dart`**

Add:

```dart
class MiningRigPlacement {
  const MiningRigPlacement({required this.tier, required this.cell});

  final RigTier tier;
  final MiningGridCell cell;

  Map<String, Object?> toJson() => {
    'tier': tier.name,
    'x': cell.x,
    'y': cell.y,
  };

  @override
  bool operator ==(Object other) =>
      other is MiningRigPlacement && other.tier == tier && other.cell == cell;

  @override
  int get hashCode => Object.hash(tier, cell);
}
```

Change `SiteProgress` to:

```dart
final List<MiningRigPlacement> rigPlacements;
```

Copy it with `List<MiningRigPlacement>.unmodifiable(...)`, include it in equality/hash/toJson, and initialize every fresh site with `rigPlacements: const []`.

The existing `commissioned` flag remains sticky after first deployment.

- [ ] **Step 4: Make state tests GREEN**

```sh
flutter test test/mining/mining_state_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write failing strict-decode and invariant tests**

In `test/mining/mining_save_repository_test.dart`, add focused cases covering:

```dart
// Valid placement beside Landing Basin d1.
'rigPlacements': [
  {'tier': 't1', 'x': 3, 'y': 2},
],
```

and assert recovery for each invalid document:

```dart
// duplicate cell
'rigPlacements': [
  {'tier': 't1', 'x': 3, 'y': 2},
  {'tier': 't2', 'x': 3, 'y': 2},
],

// inside the d1 deposit
'rigPlacements': [
  {'tier': 't1', 'x': 3, 'y': 3},
],

// diagonal/not adjacent
'rigPlacements': [
  {'tier': 't1', 'x': 2, 'y': 2},
],

// d1 maxMiners=1 exceeded
'rigPlacements': [
  {'tier': 't1', 'x': 3, 'y': 2},
  {'tier': 't1', 'x': 2, 'y': 3},
],
```

Also add one old-shape regression fixture where a site's exact keys contain `rigByNode` rather than `rigPlacements`; expect `recoveredFromInvalidSave == true` and a fresh state. This locks the intentional no-migration decision.

- [ ] **Step 6: Replace `_decodeRigByNode` with `_decodeRigPlacements`**

In `mining_save_repository.dart`, change each site exact-key set to:

```dart
const {
  'unlocked',
  'commissioned',
  'storedAmount',
  'rigPlacements',
}
```

Decode placements with exact keys:

```dart
List<MiningRigPlacement> _decodeRigPlacements(
  Object? raw,
  MiningSiteId siteId,
) {
  if (raw is! List<Object?>) {
    throw FormatException('site ${siteId.name} rigPlacements must be a list');
  }
  if (raw.length > MiningContentRegistry.maxDeployedRigsPerSite) {
    throw FormatException('site ${siteId.name} has too many deployed rigs');
  }

  final result = <MiningRigPlacement>[];
  for (final item in raw) {
    if (item is! Map<String, Object?> ||
        !hasExactKeys(item, const {'tier', 'x', 'y'})) {
      throw FormatException(
        'site ${siteId.name} rig placement keys must be exactly tier, x, y',
      );
    }
    final x = item['x'];
    final y = item['y'];
    if (x is! int || y is! int) {
      throw FormatException('site ${siteId.name} rig coordinates must be ints');
    }
    result.add(
      MiningRigPlacement(
        tier: _decodeRigTier(item['tier'])!,
        cell: MiningGridCell(x, y),
      ),
    );
  }
  return List.unmodifiable(result);
}
```

Do not allow null tier inside a deployed placement.

- [ ] **Step 7: Validate geometry/miner caps and keep capacity clamp**

Inside `_validateInvariants`, for each site's placements:

```dart
final seenCells = <MiningGridCell>{};
final minersByDeposit = <MiningDepositId, int>{};
for (final placement in progress.rigPlacements) {
  if (!seenCells.add(placement.cell)) {
    throw FormatException('${definition.name} has duplicate rig cells');
  }
  if (!definition.containsGridCell(placement.cell) ||
      definition.isDepositCell(placement.cell)) {
    throw FormatException('${definition.name} has an invalid rig cell');
  }
  final adjacent = definition.adjacentDeposits(placement.cell).toList();
  if (adjacent.length != 1) {
    throw FormatException('${definition.name} rig must border one deposit');
  }
  final deposit = adjacent.single;
  if (technology.surveying < deposit.requiredSurveyingLevel) {
    throw FormatException(
      '${definition.name} ${deposit.id.name} requires Surveying '
      '${deposit.requiredSurveyingLevel}',
    );
  }
  final count = (minersByDeposit[deposit.id] ?? 0) + 1;
  if (count > deposit.maxMiners) {
    throw FormatException('${definition.name} ${deposit.id.name} has too many rigs');
  }
  minersByDeposit[deposit.id] = count;
}
```

In `_decodeSites`, keep the existing capacity normalization but derive tiers from:

```dart
final deployedRigs = rigPlacements.map((placement) => placement.tier);
```

Update all locked-planet/site pristine checks to use `rigPlacements.isNotEmpty`.

- [ ] **Step 8: Run persistence tests**

```sh
flutter test \
  test/mining/mining_state_test.dart \
  test/mining/mining_save_repository_test.dart
```

Expected: PASS, including old `rigByNode` recovery.

- [ ] **Step 9: Commit the breaking placement save**

```sh
git add \
  lib/mining/mining_state.dart \
  lib/mining/mining_save_repository.dart \
  test/mining/mining_state_test.dart \
  test/mining/mining_save_repository_test.dart
git commit -m "feat(mining): persist grid rig placements"
```

---

### Task 3: Validate Grid Deployment and Keep Aggregate Production

**Files:**
- Modify: `lib/mining/mining_controller.dart`
- Modify: `lib/mining/mining_simulation.dart`
- Modify: `lib/mining/site_deck_view.dart`
- Modify: `test/mining/mining_controller_test.dart`
- Modify: `test/mining/mining_simulation_test.dart`
- Modify: `test/mining/site_deck_view_test.dart`

**Interfaces:**
- Replaces: `deployRig(DockBayId, MiningSiteId, MiningNodeId)`.
- Produces: `deployRig(DockBayId sourceBay, MiningSiteId siteId, MiningGridCell cell)`.
- Replaces: `recallRig(MiningSiteId, MiningNodeId)`.
- Produces: `recallRig(MiningSiteId siteId, MiningGridCell cell)`.
- Preserves: `spawnRig`, merge, commissioning/mastery, save-before-publish, capacity checks, aggregate rate/capacity formulas.

- [ ] **Step 1: Add controller fixtures for grid placements**

In `test/mining/mining_controller_test.dart`, add a small helper that replaces one site's progress without bypassing the real controller mutation under test:

```dart
SiteProgress landingProgress({
  bool commissioned = false,
  double storedAmount = 0,
  List<MiningRigPlacement> placements = const [],
}) => SiteProgress(
  unlocked: true,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigPlacements: placements,
);
```

Use existing in-memory repository/test-clock helpers rather than adding another fake repository type.

- [ ] **Step 2: Write failing deployment rule tests**

Cover these exact Landing Basin cells:

```text
(3,2)  -> adjacent to d1, valid at Surveying 0
(2,3)  -> also adjacent to d1, but d1 maxMiners=1
(16,2) -> adjacent to d2, valid at Surveying 0
(5,10) -> adjacent to d3, requires Surveying 1
(3,3)  -> inside d1, invalid
(2,2)  -> diagonal to d1, invalid
```

Add tests that assert:

```dart
final result = await controller.deployRig(
  DockBayId.b1,
  MiningSiteId.landingBasin,
  const MiningGridCell(3, 2),
);
expect(result.isSuccess, isTrue);
expect(controller.state.sites[MiningSiteId.landingBasin]!.rigPlacements, [
  const MiningRigPlacement(
    tier: RigTier.t1,
    cell: MiningGridCell(3, 2),
  ),
]);
expect(controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b1], isNull);
```

Then assert failures for deposit cell, diagonal cell, locked d3 Surveying, d1 second miner, duplicate rig cell, and a fifth placement when four rigs are already deployed.

Use these stable messages in implementation/tests:

```text
Choose a valid grid cell.
Resources occupy this cell.
Grid cell is already occupied.
Place the rig next to a resource.
Requires Surveying N.
This resource already has its maximum miners.
This site already has its maximum rigs.
```

- [ ] **Step 3: Run controller tests and verify RED**

```sh
flutter test test/mining/mining_controller_test.dart
```

Expected: FAIL because controller methods still accept `MiningNodeId` and inspect `rigByNode`.

- [ ] **Step 4: Replace node deployment with cell deployment**

In `deployRig`, after existing active-planet/dock/site checks, validate in this order:

```dart
if (progress.rigPlacements.length >=
    MiningContentRegistry.maxDeployedRigsPerSite) {
  return const MiningActionResult.failure(
    'This site already has its maximum rigs.',
  );
}
if (!definition.containsGridCell(cell)) {
  return const MiningActionResult.failure('Choose a valid grid cell.');
}
if (definition.isDepositCell(cell)) {
  return const MiningActionResult.failure('Resources occupy this cell.');
}
if (progress.rigPlacements.any((placement) => placement.cell == cell)) {
  return const MiningActionResult.failure('Grid cell is already occupied.');
}
final adjacent = definition.adjacentDeposits(cell).toList();
if (adjacent.length != 1) {
  return const MiningActionResult.failure('Place the rig next to a resource.');
}
final deposit = adjacent.single;
if (candidate.state.technology.surveying < deposit.requiredSurveyingLevel) {
  return MiningActionResult.failure(
    'Requires Surveying ${deposit.requiredSurveyingLevel}.',
  );
}
final minerCount = progress.rigPlacements.where((placement) {
  final targets = definition.adjacentDeposits(placement.cell).toList();
  return targets.length == 1 && targets.single.id == deposit.id;
}).length;
if (minerCount >= deposit.maxMiners) {
  return const MiningActionResult.failure(
    'This resource already has its maximum miners.',
  );
}
```

After removing the source rig from its dock, append:

```dart
final rigPlacements = <MiningRigPlacement>[
  ...progress.rigPlacements,
  MiningRigPlacement(tier: sourceTier, cell: cell),
];
```

Keep `commissioned: true` and the exact existing planet-mastery reward transition.

- [ ] **Step 5: Replace recall-by-node with recall-by-cell**

Find the placement by cell:

```dart
final placementIndex = progress.rigPlacements.indexWhere(
  (placement) => placement.cell == cell,
);
if (placementIndex < 0) {
  return const MiningActionResult.failure('Grid cell has no rig.');
}
final placement = progress.rigPlacements[placementIndex];
```

Derive post-recall capacity from all other placement tiers, preserve the current `Sell cargo before recalling this rig.` and `Dock is full.` behavior, return `placement.tier` to the first empty dock bay, and remove exactly that list entry.

- [ ] **Step 6: Add a mixed-tier production regression**

In `test/mining/mining_simulation_test.dart`, build Landing Basin with:

```dart
rigPlacements: const [
  MiningRigPlacement(
    tier: RigTier.t1,
    cell: MiningGridCell(3, 2),
  ),
  MiningRigPlacement(
    tier: RigTier.t3,
    cell: MiningGridCell(16, 2),
  ),
],
```

At Extraction 0, Landing Basin rate must remain:

```text
0.50 * (1.00 + 2.25) = 1.625 / second
```

Advance exactly ten seconds and assert `16.25` produced/stored (subject only to the existing capacity cap).

Also keep an offline-cap case to prove grid placement does not introduce per-rig ticking.

- [ ] **Step 7: Update simulation and Site Deck tier collection**

Replace every production/view path equivalent to:

```dart
progress.rigByNode.values.whereType<RigTier>()
```

with:

```dart
progress.rigPlacements.map((placement) => placement.tier)
```

Do not group rates by deposit: each site still has one resource type and deposit caps are already guaranteed by deployment/save invariants.

- [ ] **Step 8: Run controller/simulation/Site Deck tests**

```sh
flutter test \
  test/mining/mining_controller_test.dart \
  test/mining/mining_simulation_test.dart \
  test/mining/site_deck_view_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit placement mutations and production reuse**

```sh
git add \
  lib/mining/mining_controller.dart \
  lib/mining/mining_simulation.dart \
  lib/mining/site_deck_view.dart \
  test/mining/mining_controller_test.dart \
  test/mining/mining_simulation_test.dart \
  test/mining/site_deck_view_test.dart
git commit -m "feat(mining): deploy rigs on grid cells"
```

---

### Task 4: Project Deposits, Rigs, and Deployable Cells in `MineSiteView`

**Files:**
- Modify: `lib/mining/mine_site_view.dart`
- Modify: `test/mining/mine_site_view_test.dart`

**Interfaces:**
- Produces: `MineSiteDepositView`, `MineSiteRigView`.
- Produces on `MineSiteView`: `deposits`, `rigs`, `deployableCells`, `rigAt(...)`, `canDeployAt(...)`.
- Removes: `MineSiteNodeView`, `nodes`, `nodeList`, `node(...)`.
- Consumed by: `MiningGridMap` and `MiningShell` in Task 5.

- [ ] **Step 1: Write failing deposit/miner-count tests**

Add to `test/mining/mine_site_view_test.dart` a state with two placements targeting Landing Basin d3 at Surveying 1:

```dart
const placements = [
  MiningRigPlacement(
    tier: RigTier.t1,
    cell: MiningGridCell(5, 10),
  ),
  MiningRigPlacement(
    tier: RigTier.t2,
    cell: MiningGridCell(6, 10),
  ),
];
```

Build `MineSiteView.from(...)` and assert:

```dart
final d3 = view.deposits.singleWhere(
  (deposit) => deposit.definition.id == MiningDepositId.d3,
);
expect(d3.minerCount, 2);
expect(d3.isSurveyed, isTrue);
expect(d3.isAtMinerLimit, isTrue);
```

At Surveying 0, assert d3 is not surveyed and none of its remaining perimeter cells appear in `deployableCells`.

- [ ] **Step 2: Write failing deployable-cell and recall tests**

With an occupied T1 dock bay selected and no deployed rigs at Surveying 0:

```dart
expect(view.canDeployAt(const MiningGridCell(3, 2)), isTrue);
expect(view.canDeployAt(const MiningGridCell(16, 2)), isTrue);
expect(view.canDeployAt(const MiningGridCell(3, 3)), isFalse);
expect(view.canDeployAt(const MiningGridCell(2, 2)), isFalse);
expect(view.canDeployAt(const MiningGridCell(5, 10)), isFalse);
```

With a rig at `(3,2)`, assert `rigAt(const MiningGridCell(3,2))` returns it and preserves the existing recall-disabled cases for full dock and post-recall capacity.

- [ ] **Step 3: Run the view test and verify RED**

```sh
flutter test test/mining/mine_site_view_test.dart
```

Expected: FAIL because the view still exposes fixed nodes.

- [ ] **Step 4: Replace node projections with deposit/rig projections**

Add:

```dart
class MineSiteDepositView {
  const MineSiteDepositView({
    required this.definition,
    required this.minerCount,
    required this.isSurveyed,
  });

  final MiningDepositDefinition definition;
  final int minerCount;
  final bool isSurveyed;

  bool get isAtMinerLimit => minerCount >= definition.maxMiners;
}

class MineSiteRigView {
  const MineSiteRigView({
    required this.placement,
    required this.canRecall,
    required this.disabledReason,
  });

  final MiningRigPlacement placement;
  final bool canRecall;
  final String? disabledReason;
}
```

Compute miner counts by deriving the unique adjacent deposit for each persisted placement.

- [ ] **Step 5: Derive `deployableCells` without persisting placement hints**

Only derive highlights when a dock rig is selected, the site is active/unlocked, the controller is not busy, and fewer than four rigs are deployed.

Iterate the small authored grid directly:

```dart
final deployableCells = <MiningGridCell>{};
if (selectedRig != null &&
    active &&
    progress.unlocked &&
    !isBusy &&
    progress.rigPlacements.length < MiningContentRegistry.maxDeployedRigsPerSite) {
  final occupied = progress.rigPlacements.map((placement) => placement.cell).toSet();
  for (var x = 0; x < definition.gridWidth; x++) {
    for (var y = 0; y < definition.gridHeight; y++) {
      final cell = MiningGridCell(x, y);
      if (occupied.contains(cell) || definition.isDepositCell(cell)) continue;
      final adjacent = definition.adjacentDeposits(cell).toList();
      if (adjacent.length != 1) continue;
      final deposit = adjacent.single;
      if (state.technology.surveying < deposit.requiredSurveyingLevel) continue;
      final minerCount = minersByDeposit[deposit.id] ?? 0;
      if (minerCount < deposit.maxMiners) deployableCells.add(cell);
    }
  }
}
```

A 24x18 scan is 432 cells and runs only while building one view; do not introduce an index/cache for this.

- [ ] **Step 6: Preserve recall-capacity behavior per placement**

For every rig, calculate post-recall capacity from the other placement tiers exactly as the current node view does. Keep disabled reasons:

```text
Sell cargo before recalling this rig.
Dock is full.
```

Add helpers:

```dart
MineSiteRigView? rigAt(MiningGridCell cell) {
  for (final rig in rigs) {
    if (rig.placement.cell == cell) return rig;
  }
  return null;
}

bool canDeployAt(MiningGridCell cell) => deployableCells.contains(cell);
```

- [ ] **Step 7: Run view tests**

```sh
flutter test test/mining/mine_site_view_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit the grid view model**

```sh
git add lib/mining/mine_site_view.dart test/mining/mine_site_view_test.dart
git commit -m "feat(mining): project grid placement affordances"
```

---

### Task 5: Render and Pan the Grid, Then Wire Tap-to-Deploy/Recall

**Files:**
- Create: `lib/mining/presentation/mining_grid_map.dart`
- Create: `test/mining/presentation/mining_grid_map_test.dart`
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `test/mining/presentation/mine_site_screen_test.dart`
- Modify: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Produces: `MiningGridMap(view:, reducedMotion:, onCellTap:)`.
- Replaces `MineSiteScreen.onNodeTap` with `ValueChanged<MiningGridCell> onGridCellTap`.
- Replaces `_handleSiteNodeTap` with `_handleSiteGridCellTap`.
- Keeps HUD, Fleet Dock, navigation, cash/cargo/Sell controls outside the transformed map.

- [ ] **Step 1: Write failing focused map geometry tests**

Create `test/mining/presentation/mining_grid_map_test.dart` and pump a Landing Basin `MineSiteView` inside a fixed 430x500 host. Assert:

```dart
expect(find.byKey(const Key('mining-grid-interactive')), findsOneWidget);
expect(find.byKey(const Key('mining-grid-surface')), findsOneWidget);
expect(find.byKey(const Key('mining-deposit-d1')), findsOneWidget);
expect(find.byKey(const Key('mining-deposit-d3')), findsOneWidget);
expect(find.byKey(const Key('mining-deposit-d4')), findsOneWidget);
```

Use `tester.getSize(...)` to lock footprint scaling:

```dart
expect(tester.getSize(find.byKey(const Key('mining-deposit-d1'))), const Size(56, 56));
expect(tester.getSize(find.byKey(const Key('mining-deposit-d3'))), const Size(112, 112));
expect(tester.getSize(find.byKey(const Key('mining-deposit-d4'))), const Size(168, 168));
```

- [ ] **Step 2: Write failing pan and cell-tap tests**

Record d2's position, drag the interactive viewport left, then assert the deposit moved while the widget remains mounted:

```dart
final before = tester.getTopLeft(find.byKey(const Key('mining-deposit-d2')));
await tester.drag(
  find.byKey(const Key('mining-grid-interactive')),
  const Offset(-180, 0),
);
await tester.pumpAndSettle();
final after = tester.getTopLeft(find.byKey(const Key('mining-deposit-d2')));
expect(after.dx, lessThan(before.dx));
```

For tap mapping, use the default viewport where cell `(3,2)` is visible. Tap its center and assert the callback receives:

```dart
const MiningGridCell(3, 2)
```

- [ ] **Step 3: Run the focused widget test and verify RED**

```sh
flutter test test/mining/presentation/mining_grid_map_test.dart
```

Expected: FAIL because `MiningGridMap` does not exist.

- [ ] **Step 4: Create the grid widget with built-in `InteractiveViewer`**

Create `lib/mining/presentation/mining_grid_map.dart` with:

```dart
const double miningGridCellSize = 56.0;

class MiningGridMap extends StatelessWidget {
  const MiningGridMap({
    super.key,
    required this.view,
    required this.onCellTap,
  });

  final MineSiteView view;
  final ValueChanged<MiningGridCell> onCellTap;

  @override
  Widget build(BuildContext context) {
    final definition = view.definition;
    final width = definition.gridWidth * miningGridCellSize;
    final height = definition.gridHeight * miningGridCellSize;
    return InteractiveViewer(
      key: const Key('mining-grid-interactive'),
      constrained: false,
      minScale: .8,
      maxScale: 1.6,
      child: SizedBox(
        key: const Key('mining-grid-surface'),
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            onCellTap(
              MiningGridCell(
                details.localPosition.dx ~/ miningGridCellSize,
                details.localPosition.dy ~/ miningGridCellSize,
              ),
            );
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  definition.cavernAsset,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: MiningGridPainter(
                    width: definition.gridWidth,
                    height: definition.gridHeight,
                    deployableCells: view.deployableCells,
                  ),
                ),
              ),
              // deposit and rig Positioned children
            ],
          ),
        ),
      ),
    );
  }
}
```

Use the existing cavern image error fallback pattern from `_MineCavern`; do not create a new background asset.

- [ ] **Step 5: Render deposits and rigs as positioned overlays**

For each deposit:

```dart
Positioned(
  key: Key('mining-deposit-${deposit.definition.id.name}'),
  left: deposit.definition.x * miningGridCellSize,
  top: deposit.definition.y * miningGridCellSize,
  width: deposit.definition.size * miningGridCellSize,
  height: deposit.definition.size * miningGridCellSize,
  child: IgnorePointer(
    child: Opacity(
      opacity: deposit.isSurveyed ? 1 : .28,
      child: Image.asset(view.definition.depositAsset, fit: BoxFit.contain),
    ),
  ),
)
```

Overlay a small non-interactive `minerCount / maxMiners` badge on surveyed deposits; do not add deposit tap behavior.

For each rig:

```dart
Positioned(
  key: Key(
    'mining-rig-${rig.placement.cell.x}-${rig.placement.cell.y}',
  ),
  left: rig.placement.cell.x * miningGridCellSize,
  top: rig.placement.cell.y * miningGridCellSize,
  width: miningGridCellSize,
  height: miningGridCellSize,
  child: IgnorePointer(
    child: Image.asset(
      MiningVisuals.rigAsset(rig.placement.tier),
      fit: BoxFit.contain,
    ),
  ),
)
```

The map-level gesture owns the tap so deposits/rig visuals cannot steal pan or cell taps.

- [ ] **Step 6: Paint grid lines and deployment highlights in one painter**

`MiningGridPainter` receives only width/height and `Set<MiningGridCell> deployableCells`. Draw the 56px grid and a translucent highlight rectangle for each deployable cell.

Do not create a widget for every empty cell.

Implement `shouldRepaint` by comparing width, height, and `setEquals(oldDelegate.deployableCells, deployableCells)`.

- [ ] **Step 7: Make the focused map tests GREEN**

```sh
flutter test test/mining/presentation/mining_grid_map_test.dart
```

Expected: PASS.

- [ ] **Step 8: Replace `_MineCavern` node composition with `MiningGridMap`**

In `MineSiteScreen`:

```dart
final ValueChanged<MiningGridCell> onGridCellTap;
```

Replace `_MineCavern`'s current manual `_positionedNode`, `_nodeLeft`, narrow N3/N4 overlap calculations, and `_MineNodeButton` placement path with the grid viewport.

Keep all current cash/cargo/Sell/Fleet Dock/navigation overlays outside the map. The map may pan/zoom; those controls must not move.

Delete node-specific overflow workaround code that no longer has a caller rather than carrying dead geometry forward.

- [ ] **Step 9: Wire shell tap behavior through the existing selected dock bay**

Replace `_handleSiteNodeTap` with:

```dart
void _handleSiteGridCellTap(MiningGridCell cell) {
  final siteId = _openSiteId;
  if (!_initialized || siteId == null || _controller.isBusy) return;

  final view = MineSiteView.from(
    state: _controller.state,
    content: _content,
    siteId: siteId,
    selectedBayId: _selectedBayId,
    isBusy: false,
  );
  final rig = view.rigAt(cell);
  if (rig != null) {
    if (rig.canRecall) {
      _runSheetAction(
        () => _controller.recallRig(siteId, cell),
        successMessage: 'Rig recalled.',
      );
    } else if (rig.disabledReason != null) {
      _showResult(rig.disabledReason!);
    }
    return;
  }

  final selectedBayId = _selectedBayId;
  if (selectedBayId != null && view.canDeployAt(cell)) {
    _runSheetAction(
      () => _controller.deployRig(selectedBayId, siteId, cell),
      successMessage: 'Rig deployed.',
    );
  } else if (selectedBayId != null) {
    _showResult('Place the selected rig on a highlighted cell.');
  }
}
```

Pass this callback to `MineSiteScreen`. Keep `_preserveDockSelection()` unchanged so a successful deployment clears selection when the selected bay becomes empty.

- [ ] **Step 10: Update Mine Site and shell interaction tests**

In `mine_site_screen_test.dart`, remove fixed N1-N4 anchor/overflow assertions and replace them with:

- `InteractiveViewer` is present in portrait and landscape;
- map surface is larger than viewport;
- HUD/Fleet Dock/Sell controls remain visible outside the map;
- 1x1, 2x2, and 3x3 deposits render at expected sizes;
- an occupied rig renders in its saved cell.

In `mining_shell_test.dart`, keep the real flow:

```text
enter Landing Basin
-> select occupied dock b1
-> tap grid cell (3,2)
-> assert b1 empty and placement persisted
-> tap rig at (3,2)
-> assert rig returns to an empty dock bay
```

Also assert tapping `(2,2)` with a selected rig shows `Place the selected rig on a highlighted cell.` and does not mutate state.

- [ ] **Step 11: Run focused presentation/shell tests**

```sh
flutter test \
  test/mining/presentation/mining_grid_map_test.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/mining_shell_test.dart
```

Expected: PASS.

- [ ] **Step 12: Commit the pannable Mine Site**

```sh
git add \
  lib/mining/presentation/mining_grid_map.dart \
  lib/mining/presentation/mine_site_screen.dart \
  lib/mining/presentation/mining_shell.dart \
  test/mining/presentation/mining_grid_map_test.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/mining_shell_test.dart
git commit -m "feat(mining): render pannable mining grids"
```

---

### Task 6: Refresh Mine Site Visual Contract and Finish Repository Verification

**Files:**
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Modify: `test/mining/presentation/goldens/mine_site_430x932.png`
- Modify: `test/mining/presentation/goldens/mine_site_874x402.png`
- Modify: `CLAUDE.md`
- Modify any existing mining tests that still construct the removed node shape; do not create compatibility adapters to keep them unchanged.

**Interfaces:**
- Final gate only; produces no new production API.
- Confirms fixed-node identifiers are gone from production/test code.
- Records that HPA-451 animation must target grid placements after this PR.

- [ ] **Step 1: Update only the two Mine Site golden fixtures**

Keep existing Site Deck/Stellar Map golden contracts unchanged. Run:

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart --update-goldens
```

Expected changed images:

```text
test/mining/presentation/goldens/mine_site_430x932.png
test/mining/presentation/goldens/mine_site_874x402.png
```

Reject unexpected Site Deck or Stellar Map golden churn.

- [ ] **Step 2: Inspect the golden contract at both viewports**

Verify visually that:

```text
430x932 portrait
- map is visibly gridded and larger than viewport
- d1 is visible in the initial upper-left area
- fixed cash/cargo/Sell/Fleet Dock/navigation do not scale or pan with the map
- deployment highlight remains readable over cavern art

874x402 landscape
- map fills the left gameplay area without entering the right Fleet Dock rail
- fixed chrome remains fully visible
- no old N3/N4 overflow workaround geometry remains
```

If contrast is insufficient, adjust only painter/background opacity constants in `mining_grid_map.dart`; do not author a second terrain/background system.

- [ ] **Step 3: Update repository guidance**

In the current mining section of `CLAUDE.md`, replace fixed-node wording with this concise contract:

```text
Mine Site is a Flutter `InteractiveViewer` grid. Each authored site is 24x18 with four static deposits (1x1/1x1/2x2/3x3); deployed rigs occupy one cell, target the unique orthogonally adjacent deposit, and remain capped at four rigs per site. Spatial placement is persisted, but production stays aggregate/deterministic in `MiningSimulation`; there is no movement/pathfinding or frame-authoritative economy.
```

Also note that `rigByNode` saves are intentionally incompatible and recover through the existing invalid-save boundary. Do not edit `AGENTS.md` separately.

- [ ] **Step 4: Remove legacy fixed-node references from live code/tests**

Run:

```sh
rg "MiningNodeId|MiningNodeDefinition|rigByNode|nodeAsset|onNodeTap|_MineNodeButton" lib test
```

Expected: no matches.

Historical design/planning docs may continue describing the old system; do not rewrite old evidence merely to satisfy a repository-wide grep.

- [ ] **Step 5: Format and run the focused mining suite**

```sh
dart format lib/mining test/mining
dart format --output=none --set-exit-if-changed lib/mining test/mining
flutter test test/mining
```

Expected: PASS.

- [ ] **Step 6: Run repository-wide static analysis and tests**

```sh
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
```

Expected: PASS. Preserve any already-documented host/web asset-byte skip behavior rather than adding a new skip for the grid.

- [ ] **Step 7: Review the complete PR diff against the design**

Run:

```sh
git diff main...HEAD --stat
git diff main...HEAD -- \
  lib/mining \
  test/mining \
  CLAUDE.md \
  docs/superpowers/specs/2026-09-03-mining-grid-map-design.md \
  docs/superpowers/plans/2026-09-03-mining-grid-map.md
```

Confirm all of these before declaring implementation complete:

```text
- one grid model, not a second mining subsystem
- exactly four authored deposits per current site
- max four deployed rigs per site
- orthogonal adjacency only
- deposit miner caps enforced by controller and save decoder
- no persisted target deposit
- no finite reserve/depletion state
- no new dependency
- aggregate offline/foreground production still comes from MiningSimulation
- Mine Site map pans independently of fixed HUD/Fleet Dock chrome
- old rigByNode save intentionally recovers fresh
- HPA-451 animation not implemented in this PR
```

- [ ] **Step 8: Commit final visual/docs/test cleanup on the same PR**

```sh
git add \
  test/mining/presentation/visual_parity_golden_test.dart \
  test/mining/presentation/goldens/mine_site_430x932.png \
  test/mining/presentation/goldens/mine_site_874x402.png \
  CLAUDE.md \
  lib/mining \
  test/mining
git commit -m "test(mining): lock grid map behavior"
```

Do not open another PR. Push the commits to the existing PR #23 and keep it draft until the full verification above is green.
