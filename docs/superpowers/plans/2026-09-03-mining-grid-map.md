# Mining Grid Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every fixed four-node Mine Site with a pannable authored grid where up to four player-placed rigs mine orthogonally adjacent deposits, while preserving current progression/economy, HPA-451 Landing Basin animation, PR #26 non-grid UI parity, and the latest shell modal-HUD rebuild contract.

**Architecture:** Keep `MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository` as the ownership boundary. Put pure geometry plus one shared placement predicate in `mining_grid.dart`; add the grid contract first while the node runtime stays green, then atomically cut state/controller/views/presentation from `rigByNode` to immutable `rigPlacements`. `MiningGridMap` owns one explicit site-object branch: static visuals for eight sites or `LandingBasinGridVisualLayer` for Landing Basin, never both.

**Tech Stack:** Flutter/Dart, SharedPreferences mining repository, `InteractiveViewer`, `CustomPainter`, existing Landing Basin PNG frame/body/arm assets, repository-managed Cloud Agent Flutter 3.32.5 environment, Flutter unit/widget/golden/integration tests.

**Spec:** `docs/superpowers/specs/2026-09-03-mining-grid-map-design.md`

## Global Constraints

- Continue implementation on draft PR #23; do not open another implementation PR.
- Ground implementation on current `main` commit `e1e8b394626622f43dce05fd13f206d5de5b0c1b`; if `main` moves first, repeat the assumption check before production edits.
- Keep one site = one resource map and one mining runtime.
- Every current site starts at `24 x 18` cells with four authored deposits.
- Footprints/caps are d1=`1x1/1`, d2=`1x1/1`, d3=`2x2/1`, d4=`3x3/3`.
- Keep at most four deployed rigs per site.
- Rigs occupy one cell, do not move, and mine the unique orthogonally adjacent deposit. Diagonals never count.
- Built-in maps guarantee every empty cell is adjacent to at most one deposit.
- Preserve `RigTier`, Fleet Dock, spawn/merge, economy multipliers, offline caps, selling, commissioning, planet mastery, and Technology progression.
- Deposits are infinite; `maxMiners` is a simultaneous-rig cap, not a reserve.
- Replace `rigByNode` with `rigPlacements` as an intentional breaking save shape. No schema version, compatibility decoder, or migration.
- Preserve HPA-451: `_landingBasinImpactSequence`, S1-S4 stages, idle/hit/exhaust frames, T1-T5 articulated assets, reduced motion, finite-frame precache, 200ms stalled-impact drop, and no replay.
- Preserve PR #26 non-grid Mine Site chrome and `_displayNotifier` as a rebuild channel only.
- Use Flutter `InteractiveViewer`; no Flame, ECS, pathfinding, tile engine, or new dependency.
- No drag placement/movement, procedural maps, finite depletion, conveyors, power, multi-resource sites, diagonal mining, or persisted camera/target/facing.
- `AGENTS.md` follows `CLAUDE.md`; edit only `CLAUDE.md`.

---

## Final File Map

Create:

```text
lib/mining/mining_grid.dart
lib/mining/presentation/mining_grid_map.dart
lib/mining/presentation/landing_basin_grid_visual_layer.dart
test/mining/mining_grid_test.dart
test/mining/presentation/mining_grid_map_test.dart
test/mining/presentation/landing_basin_grid_visual_layer_test.dart
```

Delete after replacement tests are green:

```text
lib/mining/presentation/landing_basin_mining_node_visual.dart
test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Modify during the atomic cutover:

```text
lib/mining/mining_content.dart
lib/mining/mining_state.dart
lib/mining/mining_save_repository.dart
lib/mining/mining_controller.dart
lib/mining/mining_simulation.dart
lib/mining/mine_site_view.dart
lib/mining/site_deck_view.dart
lib/mining/mining_progression_views.dart
lib/mining/presentation/mining_shell.dart
lib/mining/presentation/mine_site_screen.dart
lib/mining/presentation/mining_visuals.dart
lib/mining/presentation/site_deck_screen.dart
lib/mining/presentation/stellar_map_screen.dart

test/mining/mining_content_test.dart
test/mining/mining_state_test.dart
test/mining/mining_save_repository_test.dart
test/mining/mining_controller_test.dart
test/mining/mining_simulation_test.dart
test/mining/mine_site_view_test.dart
test/mining/site_deck_view_test.dart
test/mining/mining_progression_views_test.dart
test/mining/presentation/mining_shell_test.dart
test/mining/presentation/mine_site_screen_test.dart
test/mining/presentation/mining_visuals_test.dart
test/mining/presentation/site_deck_screen_test.dart
test/mining/presentation/stellar_map_screen_test.dart
test/mining/presentation/visual_parity_golden_test.dart
test/integration/merge_mining_journey_test.dart
```

Modify only in final verification:

```text
test/mining/presentation/goldens/mine_site_430x932.png
test/mining/presentation/goldens/mine_site_874x402.png
CLAUDE.md
```

Do **not** modify for this feature:

```text
lib/mining/presentation/fleet_dock.dart
lib/mining/presentation/mining_hud.dart
lib/mining/presentation/mining_sheet_frame.dart
lib/mining/presentation/technology_sheet.dart
lib/mining/presentation/mining_settings_sheet.dart
lib/mining/presentation/offline_return_sheet.dart
.cursor/install.sh
.cursor/environment.json
```

---

### Task 1: Add the Grid Contract Without Switching the Runtime

**Files:**
- Create: `lib/mining/mining_grid.dart`
- Create: `test/mining/mining_grid_test.dart`
- Modify: `lib/mining/mining_content.dart`
- Modify: `test/mining/mining_content_test.dart`

**Interfaces:**
- Produces: `MiningGridCell`, `MiningDepositId`, `MiningDepositDefinition`.
- Produces: `MiningPlacementRejection`, `MiningPlacementResult`, `uniqueAdjacentDeposit(...)`, `evaluateMiningPlacement(...)`.
- Adds to `MiningSiteDefinition`: `gridWidth`, `gridHeight`, `deposits`, `depositAsset` while keeping node fields temporarily.
- Adds `MiningContentRegistry.maxDeployedRigsPerSite = 4`.
- No production consumer switches to the grid in this task.

- [ ] **Step 1: Write RED geometry and predicate tests**

Create `test/mining/mining_grid_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_grid.dart';

void main() {
  const d1 = MiningDepositDefinition(
    id: MiningDepositId.d1,
    x: 3,
    y: 3,
    size: 1,
    maxMiners: 1,
    requiredSurveyingLevel: 0,
  );
  const d3 = MiningDepositDefinition(
    id: MiningDepositId.d3,
    x: 5,
    y: 11,
    size: 2,
    maxMiners: 1,
    requiredSurveyingLevel: 1,
  );
  const deposits = [d1, d3];

  MiningPlacementResult placement(
    MiningGridCell candidate, {
    Iterable<MiningGridCell> occupied = const [],
    int surveying = 5,
    List<MiningDepositDefinition> authored = deposits,
  }) => evaluateMiningPlacement(
    gridWidth: 24,
    gridHeight: 18,
    deposits: authored,
    occupiedRigCells: occupied,
    candidate: candidate,
    surveyingLevel: surveying,
    maxRigCount: 4,
  );

  test('deposit footprints and orthogonal adjacency are exact', () {
    expect(d1.contains(const MiningGridCell(3, 3)), isTrue);
    expect(d1.isOrthogonallyAdjacent(const MiningGridCell(3, 2)), isTrue);
    expect(d1.isOrthogonallyAdjacent(const MiningGridCell(2, 2)), isFalse);
    expect(d3.contains(const MiningGridCell(6, 12)), isTrue);
    expect(d3.isOrthogonallyAdjacent(const MiningGridCell(5, 10)), isTrue);
  });

  test('placement returns the unique target', () {
    final result = placement(const MiningGridCell(3, 2), surveying: 0);
    expect(result.isAllowed, isTrue);
    expect(result.target, d1);
  });

  test('placement rejection matrix is exact', () {
    expect(
      placement(
        const MiningGridCell(3, 2),
        occupied: const [
          MiningGridCell(1, 1),
          MiningGridCell(2, 1),
          MiningGridCell(3, 1),
          MiningGridCell(4, 1),
        ],
      ).rejection,
      MiningPlacementRejection.siteAtCapacity,
    );
    expect(
      placement(const MiningGridCell(-1, 0)).rejection,
      MiningPlacementRejection.outsideGrid,
    );
    final depositCell = placement(const MiningGridCell(5, 11), surveying: 0);
    expect(depositCell.rejection, MiningPlacementRejection.depositCell);
    expect(depositCell.target, d3);
    expect(
      placement(
        const MiningGridCell(3, 2),
        occupied: const [MiningGridCell(3, 2)],
      ).rejection,
      MiningPlacementRejection.rigOccupied,
    );
    expect(
      placement(const MiningGridCell(10, 8)).rejection,
      MiningPlacementRejection.noAdjacentDeposit,
    );
    const ambiguous = [
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
        x: 3,
        y: 1,
        size: 1,
        maxMiners: 1,
        requiredSurveyingLevel: 0,
      ),
    ];
    expect(
      placement(
        const MiningGridCell(3, 2),
        authored: ambiguous,
      ).rejection,
      MiningPlacementRejection.ambiguousAdjacentDeposit,
    );
    expect(
      placement(const MiningGridCell(5, 10), surveying: 0).rejection,
      MiningPlacementRejection.surveyingLocked,
    );
    expect(
      placement(
        const MiningGridCell(3, 4),
        occupied: const [MiningGridCell(3, 2)],
        surveying: 0,
      ).rejection,
      MiningPlacementRejection.depositAtCapacity,
    );
  });
}
```

- [ ] **Step 2: Verify RED**

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: FAIL because the grid types/functions do not exist.

- [ ] **Step 3: Implement the pure grid types and predicate**

Create `lib/mining/mining_grid.dart`:

```dart
enum MiningDepositId { d1, d2, d3, d4 }

enum MiningPlacementRejection {
  siteAtCapacity,
  outsideGrid,
  depositCell,
  rigOccupied,
  noAdjacentDeposit,
  ambiguousAdjacentDeposit,
  surveyingLocked,
  depositAtCapacity,
}

class MiningGridCell {
  const MiningGridCell(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is MiningGridCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
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
      cell.x >= x && cell.x < x + size &&
      cell.y >= y && cell.y < y + size;

  bool isOrthogonallyAdjacent(MiningGridCell cell) {
    final inColumns = cell.x >= x && cell.x < x + size;
    final inRows = cell.y >= y && cell.y < y + size;
    return (inColumns && (cell.y == y - 1 || cell.y == y + size)) ||
        (inRows && (cell.x == x - 1 || cell.x == x + size));
  }
}

class MiningPlacementResult {
  const MiningPlacementResult.allowed(this.target) : rejection = null;
  const MiningPlacementResult.rejected(this.rejection, {this.target});
  final MiningDepositDefinition? target;
  final MiningPlacementRejection? rejection;
  bool get isAllowed => rejection == null;
}

MiningDepositDefinition? uniqueAdjacentDeposit({
  required List<MiningDepositDefinition> deposits,
  required MiningGridCell cell,
}) {
  final adjacent = deposits
      .where((deposit) => deposit.isOrthogonallyAdjacent(cell))
      .toList(growable: false);
  return adjacent.length == 1 ? adjacent.single : null;
}

MiningPlacementResult evaluateMiningPlacement({
  required int gridWidth,
  required int gridHeight,
  required List<MiningDepositDefinition> deposits,
  required Iterable<MiningGridCell> occupiedRigCells,
  required MiningGridCell candidate,
  required int surveyingLevel,
  required int maxRigCount,
}) {
  final occupied = occupiedRigCells.toList(growable: false);
  if (occupied.length >= maxRigCount) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.siteAtCapacity,
    );
  }
  if (candidate.x < 0 || candidate.x >= gridWidth ||
      candidate.y < 0 || candidate.y >= gridHeight) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.outsideGrid,
    );
  }

  final containing = deposits
      .where((deposit) => deposit.contains(candidate))
      .toList(growable: false);
  if (containing.isNotEmpty) {
    return MiningPlacementResult.rejected(
      MiningPlacementRejection.depositCell,
      target: containing.length == 1 ? containing.single : null,
    );
  }
  if (occupied.contains(candidate)) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.rigOccupied,
    );
  }

  final adjacent = deposits
      .where((deposit) => deposit.isOrthogonallyAdjacent(candidate))
      .toList(growable: false);
  if (adjacent.isEmpty) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.noAdjacentDeposit,
    );
  }
  if (adjacent.length != 1) {
    return const MiningPlacementResult.rejected(
      MiningPlacementRejection.ambiguousAdjacentDeposit,
    );
  }

  final target = adjacent.single;
  if (surveyingLevel < target.requiredSurveyingLevel) {
    return MiningPlacementResult.rejected(
      MiningPlacementRejection.surveyingLocked,
      target: target,
    );
  }
  final miners = occupied.where((cell) {
    return uniqueAdjacentDeposit(deposits: deposits, cell: cell)?.id ==
        target.id;
  }).length;
  if (miners >= target.maxMiners) {
    return MiningPlacementResult.rejected(
      MiningPlacementRejection.depositAtCapacity,
      target: target,
    );
  }
  return MiningPlacementResult.allowed(target);
}
```

Do not import `mining_content.dart` or `mining_state.dart` here.

- [ ] **Step 4: Make predicate tests GREEN**

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: PASS.

- [ ] **Step 5: Add grid fields alongside the live node fields**

In `MiningSiteDefinition`, temporarily keep `nodes` / `nodeAsset` and add:

```dart
required this.gridWidth,
required this.gridHeight,
required this.deposits,
required this.depositAsset,

final int gridWidth;
final int gridHeight;
final List<MiningDepositDefinition> deposits;
final String depositAsset;
```

Add:

```dart
static const int maxDeployedRigsPerSite = 4;
```

Author all nine sites with `gridWidth: 24`, `gridHeight: 18`, `depositAsset` equal to the current `nodeAsset` path, and the exact rows below.

- [ ] **Step 6: Freeze every authored tuple and map invariant**

Add to `test/mining/mining_content_test.dart`:

```dart
final expectedDeposits = <MiningSiteId, List<(int, int, int, int, int)>>{
  MiningSiteId.landingBasin: [
    (3, 3, 1, 1, 0), (16, 3, 1, 1, 0),
    (5, 11, 2, 1, 1), (16, 10, 3, 3, 2),
  ],
  MiningSiteId.carbonRidge: [
    (5, 2, 1, 1, 0), (17, 5, 1, 1, 1),
    (13, 12, 2, 1, 2), (2, 11, 3, 3, 3),
  ],
  MiningSiteId.graniteCrater: [
    (2, 5, 1, 1, 0), (18, 2, 1, 1, 1),
    (5, 12, 2, 1, 2), (15, 10, 3, 3, 3),
  ],
  MiningSiteId.frozenBasin: [
    (4, 3, 1, 1, 3), (15, 2, 1, 1, 3),
    (3, 12, 2, 1, 4), (16, 10, 3, 3, 5),
  ],
  MiningSiteId.titaniumHighlands: [
    (2, 2, 1, 1, 4), (19, 6, 1, 1, 4),
    (12, 3, 2, 1, 5), (5, 11, 3, 3, 5),
  ],
  MiningSiteId.heliumMare: [
    (6, 2, 1, 1, 5), (18, 3, 1, 1, 5),
    (3, 10, 2, 1, 5), (14, 11, 3, 3, 5),
  ],
  MiningSiteId.ochreBasin: [
    (2, 4, 1, 1, 5), (17, 2, 1, 1, 5),
    (14, 12, 2, 1, 5), (4, 11, 3, 3, 5),
  ],
  MiningSiteId.silicaDunes: [
    (5, 3, 1, 1, 5), (19, 4, 1, 1, 5),
    (3, 12, 2, 1, 5), (14, 9, 3, 3, 5),
  ],
  MiningSiteId.cobaltChasm: [
    (3, 2, 1, 1, 5), (18, 6, 1, 1, 5),
    (7, 12, 2, 1, 5), (14, 10, 3, 3, 5),
  ],
};

for (final entry in expectedDeposits.entries) {
  final site = content.site(entry.key);
  expect(site.gridWidth, 24, reason: site.name);
  expect(site.gridHeight, 18, reason: site.name);
  expect(
    site.deposits
        .map((d) => (d.x, d.y, d.size, d.maxMiners,
            d.requiredSurveyingLevel))
        .toList(),
    entry.value,
    reason: site.name,
  );

  for (final deposit in site.deposits) {
    expect(deposit.x, greaterThanOrEqualTo(0));
    expect(deposit.y, greaterThanOrEqualTo(0));
    expect(deposit.x + deposit.size, lessThanOrEqualTo(site.gridWidth));
    expect(deposit.y + deposit.size, lessThanOrEqualTo(site.gridHeight));
  }

  for (var x = 0; x < site.gridWidth; x++) {
    for (var y = 0; y < site.gridHeight; y++) {
      final cell = MiningGridCell(x, y);
      final containing = site.deposits.where((d) => d.contains(cell)).toList();
      expect(containing.length, lessThanOrEqualTo(1),
          reason: '${site.name} $cell');
      if (containing.isEmpty) {
        final adjacent = site.deposits
            .where((d) => d.isOrthogonallyAdjacent(cell))
            .toList();
        expect(adjacent.length, lessThanOrEqualTo(1),
            reason: '${site.name} $cell');
      }
    }
  }

  for (final deposit in site.deposits) {
    var legalPerimeter = 0;
    for (var x = 0; x < site.gridWidth; x++) {
      for (var y = 0; y < site.gridHeight; y++) {
        final cell = MiningGridCell(x, y);
        if (deposit.isOrthogonallyAdjacent(cell) &&
            !site.deposits.any((d) => d.contains(cell))) {
          legalPerimeter++;
        }
      }
    }
    expect(legalPerimeter, greaterThanOrEqualTo(deposit.maxMiners),
        reason: '${site.name} ${deposit.id.name}');
  }
}
```

- [ ] **Step 7: Freeze Surveying pacing**

Add:

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

for (final entry in expectedBySite.entries) {
  final site = content.site(entry.key);
  final actual = [
    for (var level = 0; level <= 5; level++)
      site.deposits
          .where((d) => d.requiredSurveyingLevel <= level)
          .fold<int>(0, (sum, d) => sum + d.maxMiners)
          .clamp(0, MiningContentRegistry.maxDeployedRigsPerSite),
  ];
  expect(actual, entry.value, reason: site.name);
}
```

- [ ] **Step 8: Prove the additive tree is green**

```sh
dart format lib/mining/mining_grid.dart lib/mining/mining_content.dart \
  test/mining/mining_grid_test.dart test/mining/mining_content_test.dart
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Expected: all PASS; runtime still uses nodes.

- [ ] **Step 9: Commit the additive contract**

```sh
git add \
  lib/mining/mining_grid.dart \
  lib/mining/mining_content.dart \
  test/mining/mining_grid_test.dart \
  test/mining/mining_content_test.dart
git commit -m "feat(mining): add authored grid contract"
```

---

### Task 2: Atomically Cut the Runtime to Grid Placements

This task is deliberately large. Do not split the identity removal into non-compiling commits and do not introduce a node/grid compatibility adapter.

**Files:**
- Create: `lib/mining/presentation/mining_grid_map.dart`
- Create: `lib/mining/presentation/landing_basin_grid_visual_layer.dart`
- Create: `test/mining/presentation/mining_grid_map_test.dart`
- Create: `test/mining/presentation/landing_basin_grid_visual_layer_test.dart`
- Modify: `lib/mining/mining_state.dart`
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/mining/mining_controller.dart`
- Modify: `lib/mining/mining_simulation.dart`
- Modify: `lib/mining/mine_site_view.dart`
- Modify: `lib/mining/site_deck_view.dart`
- Modify: `lib/mining/mining_progression_views.dart`
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `lib/mining/presentation/mining_visuals.dart`
- Modify: `lib/mining/presentation/site_deck_screen.dart`
- Modify: `lib/mining/presentation/stellar_map_screen.dart`
- Modify: corresponding tests listed in the Final File Map
- Modify: `test/integration/merge_mining_journey_test.dart`
- Delete: old Landing Basin node visual/test only after replacement tests pass

**Interfaces:**
- `SiteProgress.rigPlacements: List<MiningRigPlacement>` replaces `rigByNode`.
- `MiningRigPlacement` is a value object; persisted/copied placement lists are unmodifiable.
- `SiteProgress` intentionally loses its `const` constructor so construction can defensively wrap `rigPlacements` with `List.unmodifiable`; remove `const` from any affected fixtures during this atomic task.
- Controller deploy/recall use `MiningGridCell`.
- `SiteMetrics` and simulation read placement tiers.
- `TechnologyTrackView` uses deposit vocabulary.
- `MineSiteView` stores `isUnlocked`, `surveyingLevel`, deposits/rigs/deployable cells and owns `gridTapOutcome(cell)`.
- `MineSiteScreen` uses `onGridCellTap`.
- `MiningGridMap` owns pan/zoom, tap mapping, shared semantics/lock badges, grid painter, and exactly one site visual layer.
- `LandingBasinGridVisualLayer` owns HPA-451 art/animation only.

- [ ] **Step 1: Write RED value-state tests**

Update `test/mining/mining_state_test.dart`:

```dart
test('rig placement has value equality', () {
  expect(
    const MiningRigPlacement(
      tier: RigTier.t2,
      cell: MiningGridCell(3, 2),
    ),
    const MiningRigPlacement(
      tier: RigTier.t2,
      cell: MiningGridCell(3, 2),
    ),
  );
});

test('site progress serializes and protects rig placements', () {
  const placement = MiningRigPlacement(
    tier: RigTier.t2,
    cell: MiningGridCell(3, 2),
  );
  final progress = SiteProgress(
    unlocked: true,
    commissioned: true,
    storedAmount: 12.5,
    rigPlacements: const [placement],
  );

  expect(progress.toJson()['rigPlacements'], [
    {'tier': 't2', 'x': 3, 'y': 2},
  ]);

  final copy = progress.copyWith();
  expect(copy, progress);
  expect(
    () => copy.rigPlacements.add(
      const MiningRigPlacement(
        tier: RigTier.t1,
        cell: MiningGridCell(16, 2),
      ),
    ),
    throwsUnsupportedError,
  );
});
```

- [ ] **Step 2: Replace state with immutable value placements**

In `mining_state.dart` add:

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
      other is MiningRigPlacement && tier == other.tier && cell == other.cell;

  @override
  int get hashCode => Object.hash(tier, cell);
}

class SiteProgress {
  SiteProgress({
    required this.unlocked,
    required this.commissioned,
    required this.storedAmount,
    required List<MiningRigPlacement> rigPlacements,
  }) : rigPlacements = List<MiningRigPlacement>.unmodifiable(rigPlacements);

  final bool unlocked;
  final bool commissioned;
  final double storedAmount;
  final List<MiningRigPlacement> rigPlacements;

  SiteProgress copyWith({
    bool? unlocked,
    bool? commissioned,
    double? storedAmount,
    List<MiningRigPlacement>? rigPlacements,
  }) => SiteProgress(
    unlocked: unlocked ?? this.unlocked,
    commissioned: commissioned ?? this.commissioned,
    storedAmount: storedAmount ?? this.storedAmount,
    rigPlacements: rigPlacements ?? this.rigPlacements,
  );
}
```

Add:

```dart
bool _listsEqual<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}
```

`SiteProgress ==` uses `_listsEqual(rigPlacements, other.rigPlacements)` and hash uses `Object.hashAll(rigPlacements)`. `_copySites` reconstructs each site through the constructor. Fresh sites pass `rigPlacements: const []`.

Remove `const` from the existing `const SiteProgress(...)` fixture in `test/mining/mining_state_test.dart` and any other compile errors surfaced by the atomic cutover.

- [ ] **Step 3: Write RED repository validation matrix**

After updating the test helper to the new JSON shape, add:

```dart
Map<String, Object?> rawWithLandingPlacements(
  List<Object?> placements, {
  int surveying = 5,
}) {
  final raw = _rawDocument(nowUtc: now);
  final technology = Map<String, Object?>.from(
    raw['technology']! as Map<String, Object?>,
  )..['surveying'] = surveying;
  final sites = Map<String, Object?>.from(
    raw['sites']! as Map<String, Object?>,
  );
  final landing = Map<String, Object?>.from(
    sites[MiningSiteId.landingBasin.name]! as Map<String, Object?>,
  )
    ..['unlocked'] = true
    ..['commissioned'] = true
    ..['rigPlacements'] = placements;
  sites[MiningSiteId.landingBasin.name] = landing;
  raw['technology'] = technology;
  raw['sites'] = sites;
  return raw;
}

Future<void> expectRecovered(Map<String, Object?> raw) async {
  SharedPreferences.setMockInitialValues({
    MiningSaveRepository.saveKey: jsonEncode(raw),
  });
  final result = await MiningSaveRepository().load(nowUtc: now);
  expect(result.recoveredFromInvalidSave, isTrue);
  expect(result.state, MiningSave.initial(nowUtc: now));
}

test('invalid rig placements recover through the strict boundary', () async {
  final invalid = <Map<String, Object?>>[
    rawWithLandingPlacements([
      {'tier': 't1', 'x': 3, 'y': 2},
      {'tier': 't2', 'x': 3, 'y': 2},
    ]),
    rawWithLandingPlacements([
      {'tier': 't1', 'x': 3, 'y': 3},
    ]),
    rawWithLandingPlacements([
      {'tier': 't1', 'x': 5, 'y': 10},
    ], surveying: 0),
    rawWithLandingPlacements([
      {'tier': 't1', 'x': 16, 'y': 9},
      {'tier': 't1', 'x': 17, 'y': 9},
      {'tier': 't1', 'x': 18, 'y': 9},
      {'tier': 't1', 'x': 15, 'y': 10},
    ], surveying: 2),
    rawWithLandingPlacements([
      {'tier': 't1', 'x': 3, 'y': 2},
      {'tier': 't1', 'x': 16, 'y': 2},
      {'tier': 't1', 'x': 5, 'y': 10},
      {'tier': 't1', 'x': 16, 'y': 9},
      {'tier': 't1', 'x': 17, 'y': 9},
    ], surveying: 2),
    rawWithLandingPlacements([
      {'tier': 't9', 'x': 3, 'y': 2},
    ]),
    rawWithLandingPlacements([
      {'tier': 't1', 'x': 3.5, 'y': 2},
    ]),
  ];

  for (final raw in invalid) {
    await expectRecovered(raw);
  }
});
```

Also mutate one current site document by deleting `rigPlacements` and adding legacy `rigByNode`; assert the same recovery path.

Update the existing decoded-nested-state test so `result.state.sites[...].rigPlacements.add(...)` throws `UnsupportedError`.

- [ ] **Step 4: Implement strict placement decoding**

Site keys become exactly:

```text
unlocked, commissioned, storedAmount, rigPlacements
```

Decode `rigPlacements` as a list with exact `tier/x/y` entry keys. Resolve tier by `RigTier.values.byName`, require integer `x/y`, reject more than four entries, and incrementally call:

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
if (!result.isAllowed) {
  throw FormatException(
    'Invalid rig placement for ${definition.id.name}: ${result.rejection}',
  );
}
```

Return the resulting placements through `SiteProgress`, whose constructor makes the list unmodifiable. Do not add a legacy reader.

- [ ] **Step 5: Cut controller deploy/recall to cells**

Signatures become:

```dart
Future<MiningActionResult> deployRig(
  DockBayId sourceBay,
  MiningSiteId siteId,
  MiningGridCell cell,
)

Future<MiningActionResult> recallRig(
  MiningSiteId siteId,
  MiningGridCell cell,
)
```

Add in `mining_controller.dart`:

```dart
String _placementFailureMessage(MiningPlacementResult result) =>
    switch (result.rejection!) {
      MiningPlacementRejection.siteAtCapacity =>
        'This site already has its maximum rigs.',
      MiningPlacementRejection.outsideGrid => 'Choose a valid grid cell.',
      MiningPlacementRejection.depositCell => 'Resources occupy this cell.',
      MiningPlacementRejection.rigOccupied =>
        'Grid cell is already occupied.',
      MiningPlacementRejection.noAdjacentDeposit =>
        'Place the rig next to a resource.',
      MiningPlacementRejection.surveyingLocked =>
        'Requires Surveying ${result.target!.requiredSurveyingLevel}.',
      MiningPlacementRejection.depositAtCapacity =>
        'This resource already has its maximum miners.',
      MiningPlacementRejection.ambiguousAdjacentDeposit =>
        throw StateError('Authored mining grid has ambiguous adjacency.'),
    };
```

After existing active-planet/site/dock checks call `evaluateMiningPlacement(...)`. On success append `MiningRigPlacement(tier: sourceTier, cell: cell)`, remove the dock tier, keep commissioning/mastery logic unchanged, save before publish.

Recall finds the placement index by cell, preserves `Dock is full.` and `Sell cargo before recalling this rig.`, computes post-recall capacity from all other placement tiers, returns the tier to the first empty dock, removes one list entry, saves, then publishes.

- [ ] **Step 6: Cut aggregate economy and shell rig query to placements**

In `MiningSimulation` and `SiteMetrics` replace node-map tier collection with:

```dart
progress.rigPlacements.map((placement) => placement.tier)
```

In `MiningShell` replace only the Landing Basin eligibility query:

```dart
final landing = _controller.state.sites[MiningSiteId.landingBasin]!;
final hasRig = landing.rigPlacements.isNotEmpty;
```

Do **not** remove `_displayNotifier`, `_displayNotifier.value = _controller.state`, the modal `ValueListenableBuilder`, or notifier disposal.

Update the existing test named exactly:

```text
technology sheet HUD refreshes cargo while the foreground timer accrues
```

by changing only `deployedLandingState(...)` to produce `rigPlacements: [MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3,2))]`. Keep its cargo-before/cargo-after assertions unchanged.

- [ ] **Step 7: Complete the public node-to-deposit identity cutover**

Delete from `mining_content.dart`:

```text
MiningNodeId
MiningNodeDefinition
MiningSiteDefinition.nodes
MiningSiteDefinition.nodeAsset
```

Rename Technology projection fields/functions:

```text
nodeAvailability          -> depositAvailability
nextNodeAvailability      -> nextDepositAvailability
surveyingNodeAvailability -> surveyingDepositAvailability
_nodeAvailability          -> _depositAvailability
```

`_depositAvailability` walks `site.deposits` and returns `'$available of $total deposits available'`.

Change `site_deck_screen.dart` and `stellar_map_screen.dart` from `nodeAsset` to `depositAsset`.

Remove `MiningVisuals.portraitNodeAnchors` / `landscapeNodeAnchors` after their last caller disappears.

- [ ] **Step 8: Implement the grid-aware Mine Site view contract**

Add to `MineSiteView`:

```dart
final bool isUnlocked;
final int surveyingLevel;
final List<MineSiteDepositView> deposits;
final List<MineSiteRigView> rigs;
final Set<MiningGridCell> deployableCells;
```

Use these view types:

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
}

class MineSiteRigView {
  const MineSiteRigView({
    required this.placement,
    required this.target,
    required this.canRecall,
    required this.disabledReason,
  });
  final MiningRigPlacement placement;
  final MiningDepositDefinition target;
  final bool canRecall;
  final String? disabledReason;
}

enum MineSiteGridTapAction { deploy, recall, blocked }

class MineSiteGridTapOutcome {
  const MineSiteGridTapOutcome.deploy()
      : action = MineSiteGridTapAction.deploy,
        message = null;
  const MineSiteGridTapOutcome.recall()
      : action = MineSiteGridTapAction.recall,
        message = null;
  const MineSiteGridTapOutcome.blocked(this.message)
      : action = MineSiteGridTapAction.blocked;

  final MineSiteGridTapAction action;
  final String? message;
}
```

Store `isUnlocked: progress.unlocked` and `surveyingLevel: state.technology.surveying` in `MineSiteView.from(...)`.

Implement:

```dart
MineSiteRigView? rigAt(MiningGridCell cell) {
  for (final rig in rigs) {
    if (rig.placement.cell == cell) return rig;
  }
  return null;
}

MiningPlacementResult placementAt(MiningGridCell cell) =>
    evaluateMiningPlacement(
      gridWidth: definition.gridWidth,
      gridHeight: definition.gridHeight,
      deposits: definition.deposits,
      occupiedRigCells: rigs.map((rig) => rig.placement.cell),
      candidate: cell,
      surveyingLevel: surveyingLevel,
      maxRigCount: MiningContentRegistry.maxDeployedRigsPerSite,
    );
```

`deployableCells` is empty unless `!isBusy && isUnlocked && isActivePlanet && selectedRig != null`; otherwise scan 24x18 and include cells whose `placementAt(cell).isAllowed` is true.

Implement `gridTapOutcome` in this order:

```dart
MineSiteGridTapOutcome gridTapOutcome(MiningGridCell cell) {
  if (isBusy) {
    return const MineSiteGridTapOutcome.blocked('Finishing previous action…');
  }
  if (!isUnlocked) {
    return const MineSiteGridTapOutcome.blocked('Unlock this site first.');
  }

  final containing = definition.deposits
      .where((deposit) => deposit.contains(cell))
      .toList(growable: false);
  if (containing.length == 1 &&
      surveyingLevel < containing.single.requiredSurveyingLevel) {
    return MineSiteGridTapOutcome.blocked(
      'Requires Surveying ${containing.single.requiredSurveyingLevel}.',
    );
  }

  if (!isActivePlanet) {
    return const MineSiteGridTapOutcome.blocked(
      'Travel to this planet first.',
    );
  }

  final rig = rigAt(cell);
  if (rig != null) {
    if (rig.canRecall) return const MineSiteGridTapOutcome.recall();
    return MineSiteGridTapOutcome.blocked(
      rig.disabledReason ?? 'Finishing previous action…',
    );
  }

  if (selectedRig == null) {
    return const MineSiteGridTapOutcome.blocked(
      'Select a rig from the dock.',
    );
  }

  final placement = placementAt(cell);
  if (placement.isAllowed) return const MineSiteGridTapOutcome.deploy();

  return switch (placement.rejection!) {
    MiningPlacementRejection.siteAtCapacity =>
      const MineSiteGridTapOutcome.blocked(
        'This site already has its maximum rigs.',
      ),
    MiningPlacementRejection.outsideGrid =>
      const MineSiteGridTapOutcome.blocked('Choose a valid grid cell.'),
    MiningPlacementRejection.depositCell =>
      const MineSiteGridTapOutcome.blocked('Resources occupy this cell.'),
    MiningPlacementRejection.rigOccupied =>
      const MineSiteGridTapOutcome.blocked('Grid cell is already occupied.'),
    MiningPlacementRejection.noAdjacentDeposit =>
      const MineSiteGridTapOutcome.blocked(
        'Place the rig next to a resource.',
      ),
    MiningPlacementRejection.surveyingLocked =>
      MineSiteGridTapOutcome.blocked(
        'Requires Surveying ${placement.target!.requiredSurveyingLevel}.',
      ),
    MiningPlacementRejection.depositAtCapacity =>
      const MineSiteGridTapOutcome.blocked(
        'This resource already has its maximum miners.',
      ),
    MiningPlacementRejection.ambiguousAdjacentDeposit =>
      throw StateError('Authored mining grid has ambiguous adjacency.'),
  };
}
```

Keep existing recall-capacity calculation per rig and existing disabled strings.

- [ ] **Step 9: Write RED Mine Site view behavior tests**

In `test/mining/mine_site_view_test.dart`, build Landing Basin states and assert:

```dart
expect(view.isUnlocked, isTrue);
expect(view.surveyingLevel, 0);
expect(view.deployableCells, contains(const MiningGridCell(3, 2)));
expect(view.deployableCells, contains(const MiningGridCell(16, 2)));
expect(view.deployableCells, isNot(contains(const MiningGridCell(5, 10))));

expect(
  view.gridTapOutcome(const MiningGridCell(5, 11)).message,
  'Requires Surveying 1.',
);
expect(
  view.gridTapOutcome(const MiningGridCell(10, 8)).message,
  'Place the rig next to a resource.',
);
```

Keep/retarget existing tests for the exact busy/unlock/travel/select/recall-capacity/dock-full strings.

- [ ] **Step 10: Write RED grid-map gesture/object-layer tests**

Create `test/mining/presentation/mining_grid_map_test.dart`. Pump Landing Basin in a fixed 430x500 host with a callback sink:

```dart
final taps = <MiningGridCell>[];

expect(find.byKey(const Key('mining-grid-interactive')), findsOneWidget);
expect(find.byKey(const Key('mining-grid-surface')), findsOneWidget);
expect(find.byKey(const Key('landing-basin-grid-visual-layer')), findsOneWidget);
expect(find.byKey(const Key('static-mining-grid-visual-layer')), findsNothing);
expect(find.byKey(const Key('mining-deposit-d1')), findsOneWidget);

final viewport = tester.getRect(find.byKey(const Key('mining-grid-interactive')));
final d1 = tester.getRect(find.byKey(const Key('mining-deposit-d1')));
expect(viewport.overlaps(d1), isTrue);
```

Prove drag vs tap after transform:

```dart
await tester.drag(
  find.byKey(const Key('mining-grid-interactive')),
  const Offset(-600, 0),
);
await tester.pumpAndSettle();
expect(taps, isEmpty);

final d2 = tester.getRect(find.byKey(const Key('mining-deposit-d2')));
await tester.tapAt(Offset(d2.center.dx, d2.top - 28));
await tester.pump();
expect(taps.single, const MiningGridCell(16, 2));
```

Pump Carbon Ridge separately and assert the inverse object-layer keys: static layer present, Landing layer absent.

- [ ] **Step 11: Implement `MiningGridMap` with exactly one object layer**

In `mining_grid_map.dart`:

```dart
const double miningGridCellSize = 56;

class MiningGridMap extends StatelessWidget {
  const MiningGridMap({
    super.key,
    required this.view,
    required this.onCellTap,
    required this.impactSequence,
    required this.reducedMotion,
  });

  final MineSiteView view;
  final ValueChanged<MiningGridCell> onCellTap;
  final int impactSequence;
  final bool reducedMotion;

  Widget _objectLayer() => view.siteId == MiningSiteId.landingBasin
      ? LandingBasinGridVisualLayer(
          key: const Key('landing-basin-grid-visual-layer'),
          view: view,
          impactSequence: impactSequence,
          reducedMotion: reducedMotion,
          cellSize: miningGridCellSize,
        )
      : _StaticMiningGridVisualLayer(
          key: const Key('static-mining-grid-visual-layer'),
          view: view,
          cellSize: miningGridCellSize,
        );

  @override
  Widget build(BuildContext context) {
    final width = view.definition.gridWidth * miningGridCellSize;
    final height = view.definition.gridHeight * miningGridCellSize;
    return InteractiveViewer(
      key: const Key('mining-grid-interactive'),
      constrained: false,
      alignment: Alignment.topLeft,
      minScale: .8,
      maxScale: 1.6,
      child: SizedBox(
        key: const Key('mining-grid-surface'),
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => onCellTap(
            MiningGridCell(
              details.localPosition.dx ~/ miningGridCellSize,
              details.localPosition.dy ~/ miningGridCellSize,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Image.asset(
                  view.definition.cavernAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1D2B3D), Color(0xFF0B1420)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.terrain_rounded,
                        color: Colors.white24,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: IgnorePointer(child: _objectLayer())),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: MiningGridPainter(
                      width: view.definition.gridWidth,
                      height: view.definition.gridHeight,
                      deployableCells: view.deployableCells,
                    ),
                  ),
                ),
              ),
              // Add exactly four deposit lock/semantics overlays and <=4 rig
              // semantics overlays; these are object overlays, not tile widgets.
            ],
          ),
        ),
      ),
    );
  }
}
```

Keep `_StaticMiningGridVisualLayer` private in this file. It renders each `depositAsset` once and each `MiningVisuals.rigAsset(tier)` once.

Use:

```dart
double depositVisualSize(int footprint) => switch (footprint) {
  1 => 80,
  2 => 120,
  3 => 168,
  _ => throw ArgumentError.value(footprint),
};
```

Center art over the logical footprint. The foreground grid/highlight painter intentionally keeps logical 56px cells visible over oversized art. Lock badges and semantic overlays sit above the painter. No empty-cell widgets.

Deposit semantics include resource/deposit id, footprint, miner count/cap, and `Requires Surveying N` when locked. Rig semantics include tier/cell/target and call `onCellTap(rig.placement.cell)` for semantic recall.

- [ ] **Step 12: Replace fixed-node Mine Site composition and preserve PR #26 chrome**

`MineSiteScreen` replaces `onNodeTap` with:

```dart
final ValueChanged<MiningGridCell> onGridCellTap;
```

Replace `_MineCavern` node children with `MiningGridMap(view:, onCellTap:, impactSequence:, reducedMotion:)`. Keep cash, cargo, back, Sell, Fleet Dock, toolbar/navigation outside the transform.

Delete fixed-node-only helpers after their callers are gone:

```text
_nodeLeft
_landscapeN4Overflows
_landscapeN4OverlapsOccupiedN3
_landscapeN3ShiftedLeft
_nodeTop
_nodeSize
_rigSize
_MineNodeButton
_LockedNode
```

**Do not delete `_landscapeX(...)`; PR #26 uses it for landscape Sell placement.** Do not edit `fleet_dock.dart` or `mining_hud.dart`.

In `mine_site_screen_test.dart`, retain these current non-node assertions:

```text
402x874 cash top-left = (0,54)
402x874 cargo = Rect.fromLTWH(306,50,84,84)
402x874 back = Rect.fromLTWH(14,146,44,48)
landscape right rail width = 104
Sell uses current portrait position and landscape interpolation
full-bleed cavern, aggregate sale, sub-1-cash feedback, Fleet Dock semantics,
navigation callbacks remain green
```

Replace only fixed N1/N2 position assertions with grid viewport/object assertions.

- [ ] **Step 13: Wire the shell through one tap outcome**

Replace `_handleSiteNodeTap` with:

```dart
void _handleSiteGridCellTap(MiningGridCell cell) {
  final siteId = _openSiteId;
  if (!_initialized || siteId == null) return;

  final view = MineSiteView.from(
    state: _controller.state,
    content: _content,
    siteId: siteId,
    selectedBayId: _selectedBayId,
    isBusy: _controller.isBusy,
  );
  final outcome = view.gridTapOutcome(cell);

  switch (outcome.action) {
    case MineSiteGridTapAction.deploy:
      final bay = _selectedBayId!;
      _runSheetAction(
        () => _controller.deployRig(bay, siteId, cell),
        successMessage: 'Rig deployed.',
      );
      break;
    case MineSiteGridTapAction.recall:
      _runSheetAction(
        () => _controller.recallRig(siteId, cell),
        successMessage: 'Rig recalled.',
      );
      break;
    case MineSiteGridTapAction.blocked:
      _showResult(outcome.message!);
      break;
  }
}
```

Pass it to `MineSiteScreen`. Keep `_preserveDockSelection()` and `_displayNotifier` behavior unchanged.

- [ ] **Step 14: Port HPA-451 to one Landing Basin object layer**

Create `LandingBasinGridVisualLayer` with:

```dart
class LandingBasinGridVisualLayer extends StatefulWidget {
  const LandingBasinGridVisualLayer({
    super.key,
    required this.view,
    required this.impactSequence,
    required this.reducedMotion,
    required this.cellSize,
  });

  final MineSiteView view;
  final int impactSequence;
  final bool reducedMotion;
  final double cellSize;
}
```

It owns one impact controller, one S1 idle controller, finite-frame precache state, and the same 200ms stalled-first-impact timer semantics as the current node visual. It renders each deposit once and each articulated rig once; `MiningGridMap` does not render generic object art for Landing Basin.

Progress remains:

```dart
final progress = widget.view.capacity <= 0
    ? 0.0
    : (widget.view.cargo / widget.view.capacity).clamp(0.0, 1.0).toDouble();
```

Keep shoulder pivot:

```dart
alignment: const Alignment(.33, -.24)
```

Facing is:

```dart
final rigCenterX = rig.placement.cell.x + .5;
final targetCenterX = rig.target.x + rig.target.size / 2;
final mirror = targetCenterX > rigCenterX;
```

Mirror the whole composed robot only when `mirror`; never rotate the chassis vertically.

Retarget the existing HPA-451 test cases by exact behavior name: staged boundaries, S1 idle loop, S1 hit frames/chassis fixed, S4 exhaust crossing, cold-cache stalled-impact drop/no replay, reduced motion, controller disposal, all T1-T5 body/arm assets, shoulder pivot. Add a table-driven facing test with left/right/above/below placements and expected mirror booleans `[false, true, false, false]` for targets whose center-X is respectively left/right/equal/equal.

Delete `landing_basin_mining_node_visual.dart` and its test only after the replacement suite passes.

- [ ] **Step 15: Update public journey and every node-shaped fixture**

Use:

```dart
const journeyCell = <MiningSiteId, MiningGridCell>{
  MiningSiteId.landingBasin: MiningGridCell(3, 2),
  MiningSiteId.carbonRidge: MiningGridCell(5, 1),
  MiningSiteId.graniteCrater: MiningGridCell(2, 4),
  MiningSiteId.frozenBasin: MiningGridCell(4, 2),
  MiningSiteId.titaniumHighlands: MiningGridCell(2, 1),
  MiningSiteId.heliumMare: MiningGridCell(6, 1),
  MiningSiteId.ochreBasin: MiningGridCell(2, 3),
  MiningSiteId.silicaDunes: MiningGridCell(5, 2),
  MiningSiteId.cobaltChasm: MiningGridCell(3, 1),
};
```

Replace every journey `deployRig(..., MiningNodeId.n1)` call with the mapped cell and keep economic/progression assertions unchanged.

Update every test fixture from node maps to placement lists, including Site Deck/Stellar Map screen fixtures, Mine Site golden fixture, shell helpers, and the live Technology-sheet HUD fixture.

- [ ] **Step 16: Remove all live node vocabulary**

```sh
rg "MiningNodeId|MiningNodeDefinition|rigByNode|nodeAsset|onNodeTap|_MineNodeButton|nodeAvailability|nextNodeAvailability|surveyingNodeAvailability|portraitNodeAnchors|landscapeNodeAnchors|mine-site-node-" lib test
```

Expected: no matches. Do not grep historical planning/evidence docs.

- [ ] **Step 17: Run full runtime verification before committing**

```sh
dart format lib/mining test/mining test/integration/merge_mining_journey_test.dart
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
```

Expected: all PASS. On macOS Mine Site goldens remain skipped; Task 3 provides Linux evidence.

Explicit latest-main regressions that must remain green:

```text
technology sheet HUD refreshes cargo while the foreground timer accrues
MiningSheetFrame safe-area/close tests
PR #26 cash formatting/Fleet Dock tests
Mine Site non-node chrome/layout tests
```

- [ ] **Step 18: Commit the atomic cutover**

```sh
git add \
  lib/mining \
  test/mining \
  test/integration/merge_mining_journey_test.dart
git commit -m "feat(mining): cut mine sites over to spatial grids"
```

---

### Task 3: Regenerate Canonical Linux Goldens and Finish Verification

**Files:**
- Modify: `test/mining/presentation/goldens/mine_site_430x932.png`
- Modify: `test/mining/presentation/goldens/mine_site_874x402.png`
- Modify: `CLAUDE.md`

**Interfaces:** final verification/guidance only; no production API changes.

- [ ] **Step 1: Use the repository-managed Linux/Flutter environment**

Preferred route: repo-managed Cloud Agent from PR #25.

```sh
bash .cursor/install.sh
export PATH="/opt/flutter/bin:$PATH"
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
flutter --version | grep 'Flutter 3.32.5'
```

Expected: all exit 0.

Do not re-add PR #26's temporary golden workflow and do not use a macOS `--update-goldens` no-op as evidence.

- [ ] **Step 2: Regenerate exactly the two Mine Site goldens**

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart --update-goldens
git status --short test/mining/presentation/goldens
```

Expected changed files only:

```text
test/mining/presentation/goldens/mine_site_430x932.png
test/mining/presentation/goldens/mine_site_874x402.png
```

Reject Site Deck or Stellar Map golden churn.

- [ ] **Step 3: Verify goldens without update mode**

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: both Mine Site contracts PASS on Linux/amd64 Flutter 3.32.5.

- [ ] **Step 4: Inspect the regenerated images**

Confirm:

```text
430x932
- d1 area visible on first viewport
- visible logical grid/highlights and locked Surveying badge
- 1x1 art readable at 80px
- PR #26 cash/cargo/back/Sell/Fleet Dock/navigation chrome retained

874x402
- grid remains left of the 104px Fleet Dock rail
- Sell retains PR #26 responsive placement
- toolbar/chrome remain fixed
- no old N3/N4 geometry remains
- Landing Basin rigs stay upright and do not clip
```

If the grid fails, edit only Task 2 grid/Mine Site visual files and repeat focused tests plus this Linux golden cycle.

- [ ] **Step 5: Update `CLAUDE.md`**

Replace node-assignment guidance with:

```text
Mine Site is a Flutter InteractiveViewer over an authored 24x18 grid. Each site owns four static deposits; rigs occupy one cell and mine the unique orthogonally adjacent deposit. Placement legality is centralized in mining_grid.dart, state persists immutable rigPlacements, and production remains aggregate/deterministic in MiningSimulation. Sites remain capped at four rigs. Landing Basin owns the only site-specific animated grid layer; its shell impact sequence is presentation-only.
```

Also document:

```text
- old rigByNode saves intentionally recover fresh through the invalid-save boundary
- _displayNotifier remains a shell rebuild channel for live modal HUDs, not state ownership
- PR #26 non-grid Mine Site chrome remains the presentation baseline
```

Do not edit `AGENTS.md` separately.

- [ ] **Step 6: Run final legacy grep**

```sh
rg "MiningNodeId|MiningNodeDefinition|rigByNode|nodeAsset|onNodeTap|_MineNodeButton|nodeAvailability|nextNodeAvailability|surveyingNodeAvailability|portraitNodeAnchors|landscapeNodeAnchors|mine-site-node-" lib test CLAUDE.md
```

Expected: no matches.

- [ ] **Step 7: Run repository gates**

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

On macOS also run:

```sh
flutter build ios --simulator --debug
```

The Linux golden PASS from Step 3 is required in addition to these host gates.

- [ ] **Step 8: Commit final evidence/guidance**

```sh
git add \
  test/mining/presentation/goldens/mine_site_430x932.png \
  test/mining/presentation/goldens/mine_site_874x402.png \
  CLAUDE.md
git commit -m "test(mining): lock spatial grid presentation"
```

Keep PR #23 draft until Task 3 gates are green.