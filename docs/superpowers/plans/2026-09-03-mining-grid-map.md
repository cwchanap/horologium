# Mining Grid Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every fixed four-node Mine Site with a pannable authored grid where up to four player-placed rigs mine orthogonally adjacent deposits, while preserving current progression/economy, HPA-451 Landing Basin animation, and PR #26 non-grid UI parity.

**Architecture:** Keep `MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository` as the ownership boundary. Put grid geometry plus one shared placement predicate in `mining_grid.dart`; add the grid contract first while the node runtime stays green, then atomically cut state/controller/views/presentation from `rigByNode` to `rigPlacements`. Render with `InteractiveViewer` + one grid painter and port the existing Landing Basin animation into one site-level grid visual layer.

**Tech Stack:** Flutter/Dart, SharedPreferences mining repository, `InteractiveViewer`, `CustomPainter`, existing Landing Basin PNG frame/body/arm assets, repository-managed Cloud Agent Flutter 3.32.5 environment, Flutter unit/widget/golden/integration tests.

**Spec:** `docs/superpowers/specs/2026-09-03-mining-grid-map-design.md`

## Global Constraints

- Continue implementation on draft PR #23; do not open another implementation PR.
- Ground implementation on `main` commit `c88ec833c48392781e09114c674011d8ba377f2a`; if `main` moves again first, repeat the same assumption check.
- Keep one site = one resource map and one mining runtime.
- Every current site starts at `24 x 18` cells with four authored deposits.
- Footprints/caps are d1=`1x1/1`, d2=`1x1/1`, d3=`2x2/1`, d4=`3x3/3`.
- Keep at most four deployed rigs per site.
- Rigs occupy one cell, do not move, and mine the unique orthogonally adjacent deposit. Diagonals never count.
- Built-in maps must guarantee every empty cell is adjacent to at most one deposit.
- Preserve existing `RigTier`, Fleet Dock, spawn/merge, economy multipliers, offline caps, selling, commissioning, planet mastery, and Technology progression.
- Deposits are infinite; `maxMiners` is a simultaneous-rig cap, not a reserve.
- Replace `rigByNode` with `rigPlacements` as an intentional breaking save shape. No schema version, compatibility decoder, or migration.
- Preserve HPA-451: `_landingBasinImpactSequence`, S1-S4 stages, idle/hit/exhaust frames, T1-T5 articulated assets, reduced motion, finite-frame precache, 200ms stalled-impact drop, and no replay.
- Preserve PR #26 non-grid Mine Site chrome and the shell's `_displayNotifier` live-sheet HUD rebuild channel.
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

Those files are latest-main presentation/tooling baselines. Their existing tests must stay green.

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
- Adds to `MiningSiteDefinition`: `gridWidth`, `gridHeight`, `deposits`, `depositAsset` while keeping current node fields temporarily.
- Adds `MiningContentRegistry.maxDeployedRigsPerSite = 4`.
- No production consumer switches to the grid in this task.

- [ ] **Step 1: Add RED geometry tests**

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

  test('deposit footprints and orthogonal adjacency are exact', () {
    expect(d1.contains(const MiningGridCell(3, 3)), isTrue);
    expect(d1.isOrthogonallyAdjacent(const MiningGridCell(3, 2)), isTrue);
    expect(d1.isOrthogonallyAdjacent(const MiningGridCell(2, 2)), isFalse);
    expect(d3.contains(const MiningGridCell(6, 12)), isTrue);
    expect(d3.isOrthogonallyAdjacent(const MiningGridCell(5, 10)), isTrue);
  });
}
```

- [ ] **Step 2: Verify RED**

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: FAIL because the grid types do not exist.

- [ ] **Step 3: Implement the pure grid types**

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
```

Do not import `mining_content.dart` or `mining_state.dart` here.

- [ ] **Step 4: Add RED shared-predicate tests**

Add cases for:

```dart
expect(
  evaluateMiningPlacement(
    gridWidth: 24,
    gridHeight: 18,
    deposits: const [d1, d3],
    occupiedRigCells: const [],
    candidate: const MiningGridCell(3, 2),
    surveyingLevel: 0,
    maxRigCount: 4,
  ).target?.id,
  MiningDepositId.d1,
);

expect(
  evaluateMiningPlacement(
    gridWidth: 24,
    gridHeight: 18,
    deposits: const [d1, d3],
    occupiedRigCells: const [],
    candidate: const MiningGridCell(5, 10),
    surveyingLevel: 0,
    maxRigCount: 4,
  ).rejection,
  MiningPlacementRejection.surveyingLocked,
);
```

Also cover site cap, out-of-bounds, deposit cell, rig-occupied cell, no adjacency, ambiguous adjacency, and target miner cap.

For a candidate inside d3 at Surveying 0 assert:

```dart
final result = evaluateMiningPlacement(
  gridWidth: 24,
  gridHeight: 18,
  deposits: const [d1, d3],
  occupiedRigCells: const [],
  candidate: const MiningGridCell(5, 11),
  surveyingLevel: 0,
  maxRigCount: 4,
);
expect(result.rejection, MiningPlacementRejection.depositCell);
expect(result.target?.id, MiningDepositId.d3);
```

- [ ] **Step 5: Implement the shared predicate**

```dart
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

- [ ] **Step 6: Make the predicate GREEN**

```sh
flutter test test/mining/mining_grid_test.dart
```

Expected: PASS.

- [ ] **Step 7: Add grid fields alongside node fields and author all maps**

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

Author all nine sites with the spec's exact coordinate/Surveying tables and caps `1,1,1,3`. `depositAsset` equals the current `nodeAsset` path. Do not switch a runtime consumer yet.

- [ ] **Step 8: Freeze exact authored data and pacing**

For every site, assert `(x,y,size,maxMiners,surveying)` in d1-d4 order. Landing Basin must be:

```dart
[
  (3, 3, 1, 1, 0),
  (16, 3, 1, 1, 0),
  (5, 11, 2, 1, 1),
  (16, 10, 3, 3, 2),
]
```

Also sweep all 432 cells/site and assert bounds, no deposit overlap, >= `maxMiners` legal perimeter cells, and at most one adjacent deposit per empty cell.

Lock the spec's max-rigs-by-Surveying table for levels 0..5.

- [ ] **Step 9: Prove the additive tree is actually green**

```sh
dart format lib/mining/mining_grid.dart lib/mining/mining_content.dart \
  test/mining/mining_grid_test.dart test/mining/mining_content_test.dart
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Expected: all PASS; runtime still uses nodes.

- [ ] **Step 10: Commit the additive contract**

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

This task is intentionally large. Do not split the identity removal into non-compiling commits and do not introduce a node/grid compatibility adapter.

**Files:** all runtime/test files listed in the Final File Map except golden PNG bytes and `CLAUDE.md`.

**Interfaces:**
- `SiteProgress.rigPlacements: List<MiningRigPlacement>` replaces `rigByNode`.
- Controller deploy/recall use `MiningGridCell`.
- `SiteMetrics` and simulation read placement tiers.
- `TechnologyTrackView` uses deposit vocabulary.
- `MineSiteView` exposes deposits/rigs/deployable cells and `gridTapOutcome(cell)`.
- `MineSiteScreen` uses `onGridCellTap`.
- `MiningGridMap` owns pan/zoom, grid painting, tap mapping, object semantics, and lock badges.
- `LandingBasinGridVisualLayer` owns the HPA-451 presentation path.

- [ ] **Step 1: Write RED state/repository tests**

Update `mining_state_test.dart`:

```dart
test('site progress serializes grid placements', () {
  const progress = SiteProgress(
    unlocked: true,
    commissioned: true,
    storedAmount: 12.5,
    rigPlacements: [
      MiningRigPlacement(
        tier: RigTier.t2,
        cell: MiningGridCell(3, 2),
      ),
    ],
  );

  expect(progress.toJson()['rigPlacements'], [
    {'tier': 't2', 'x': 3, 'y': 2},
  ]);
});
```

Repository tests cover a valid placement plus duplicate cell, deposit cell, Surveying lock, d4 fourth miner, fifth site placement, unknown tier, non-int coordinates, and old `rigByNode` strict recovery.

- [ ] **Step 2: Replace saved node assignments with placements**

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
}
```

`SiteProgress` stores `List<MiningRigPlacement> rigPlacements`; fresh sites use `const []`.

Repository site keys become exactly:

```text
unlocked, commissioned, storedAmount, rigPlacements
```

Decode entries in order. Validate each placement with `evaluateMiningPlacement(...)` against already-decoded cells. Any rejection becomes `FormatException`. No legacy reader.

- [ ] **Step 3: Cut controller, simulation, `SiteMetrics`, and shell rig queries**

Controller signatures:

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

After existing active-site/dock checks, deploy through the shared predicate. Map reachable rejections to player messages. For `ambiguousAdjacentDeposit`, throw `StateError('Authored mining grid has ambiguous adjacency.')`.

Recall finds exactly one placement by cell, preserves post-recall capacity checks, returns the tier to the first empty dock bay, and removes that placement.

Replace production/view tier collection with:

```dart
progress.rigPlacements.map((placement) => placement.tier)
```

Update shell foreground animation eligibility to:

```dart
final hasRig = landing.rigPlacements.isNotEmpty;
```

**Preserve latest-main shell state ownership:** do not remove `_displayNotifier`, its assignment in `_refreshPresentation()`, the `ValueListenableBuilder` used by modal sheet scenes, or notifier disposal.

- [ ] **Step 4: Add a shell regression for the latest-main notifier contract**

Keep the existing test equivalent to:

```text
open Technology sheet
-> foreground tick accrues cargo
-> MiningSheetScene cargo gauge updates while route remains open
```

Update only its grid-based deployed Landing Basin fixture. Do not weaken/remove the assertion.

- [ ] **Step 5: Remove node identity and retarget all asset/progression consumers**

Delete from `mining_content.dart`:

```text
MiningNodeId
MiningNodeDefinition
MiningSiteDefinition.nodes
MiningSiteDefinition.nodeAsset
```

Keep Task 1 grid fields.

Rename Technology projection fields:

```text
nodeAvailability          -> depositAvailability
nextNodeAvailability      -> nextDepositAvailability
surveyingNodeAvailability -> surveyingDepositAvailability
_nodeAvailability          -> _depositAvailability
```

`_depositAvailability` walks `site.deposits` and returns `'$available of $total deposits available'`.

Change `site_deck_screen.dart` and `stellar_map_screen.dart` from `nodeAsset` to `depositAsset`.

Remove `MiningVisuals.portraitNodeAnchors` / `landscapeNodeAnchors` after their last fixed-node consumer is gone.

- [ ] **Step 6: Replace `MineSiteView` node projections with grid projections**

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

Expose:

```dart
MineSiteRigView? rigAt(MiningGridCell cell);
MiningPlacementResult placementAt(MiningGridCell cell);
MineSiteGridTapOutcome gridTapOutcome(MiningGridCell cell);
```

`deployableCells` scans all 432 cells only when a selected rig exists and site context permits deployment.

`gridTapOutcome` preserves these exact existing strings:

```text
Finishing previous action…
Unlock this site first.
Travel to this planet first.
Select a rig from the dock.
Sell cargo before recalling this rig.
Dock is full.
Requires Surveying N.
```

For a locked deposit cell, inspect the attached `placement.target` before returning generic `Resources occupy this cell.` so the Surveying requirement wins.

- [ ] **Step 7: Add RED focused grid-map tests**

Create `test/mining/presentation/mining_grid_map_test.dart` and assert:

```dart
expect(find.byKey(const Key('mining-grid-interactive')), findsOneWidget);
expect(find.byKey(const Key('mining-deposit-d1')), findsOneWidget);
expect(find.byKey(const Key('mining-deposit-d4')), findsOneWidget);

final viewport = tester.getRect(find.byKey(const Key('mining-grid-interactive')));
final d1 = tester.getRect(find.byKey(const Key('mining-deposit-d1')));
expect(viewport.overlaps(d1), isTrue);
```

Gesture regression:

```dart
final taps = <MiningGridCell>[];
await tester.drag(
  find.byKey(const Key('mining-grid-interactive')),
  const Offset(-600, 0),
);
await tester.pumpAndSettle();
expect(taps, isEmpty);
```

Then tap a known visible position after the pan and assert the mapped grid cell is correct.

- [ ] **Step 8: Implement `MiningGridMap`**

Core viewport:

```dart
const double miningGridCellSize = 56;

InteractiveViewer(
  key: const Key('mining-grid-interactive'),
  constrained: false,
  alignment: Alignment.topLeft,
  minScale: .8,
  maxScale: 1.6,
  child: SizedBox(
    key: const Key('mining-grid-surface'),
    width: view.definition.gridWidth * miningGridCellSize,
    height: view.definition.gridHeight * miningGridCellSize,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => onCellTap(
        MiningGridCell(
          details.localPosition.dx ~/ miningGridCellSize,
          details.localPosition.dy ~/ miningGridCellSize,
        ),
      ),
      child: Stack(children: mapChildren),
    ),
  ),
)
```

`mapChildren` contains cavern background, one grid/highlight `CustomPaint`, four positioned deposits, and <=4 rigs. No empty-cell widgets.

Visual sizes:

```dart
double depositVisualSize(int footprint) => switch (footprint) {
  1 => 80,
  2 => 120,
  3 => 168,
  _ => throw ArgumentError.value(footprint),
};
```

Center the visual over its logical footprint; visual overflow does not change hit testing.

Locked deposits render a visible `Surveying N` badge and a semantics label. Rigs receive button semantics and the recall disabled reason when blocked.

- [ ] **Step 9: Replace Mine Site node composition while preserving PR #26 chrome**

In `MineSiteScreen`, replace `onNodeTap` with:

```dart
final ValueChanged<MiningGridCell> onGridCellTap;
```

Replace `_MineCavern`'s fixed node children with `MiningGridMap`. Keep cash, cargo, back, Sell, Fleet Dock, toolbar/navigation outside the transform.

Delete fixed-node-only helpers after confirming they have no callers:

```text
_nodeLeft
_landscapeN4Overflows
_landscapeN4OverlapsOccupiedN3
_landscapeN3ShiftedLeft
_nodeTop
_nodeSize
_rigSize
_MineNodeButton
_LockedNode (only after grid locked-deposit UI replaces it)
```

**Do not delete `_landscapeX(...)`: PR #26 uses it to place the landscape Sell control.**

Do not edit `fleet_dock.dart` or `mining_hud.dart`; preserve the current Fleet Dock order, portrait cash-chip height, thousands separators, and current compact/portrait HUD behavior.

- [ ] **Step 10: Port current non-node Mine Site parity assertions**

In `mine_site_screen_test.dart`, keep the existing PR #26 chrome checks that do not depend on fixed nodes:

```text
402x874:
- cash chip top-left remains (0,54)
- cargo remains Rect.fromLTWH(306,50,84,84)
- back remains Rect.fromLTWH(14,146,44,48)
- Sell stays at the current portrait position

landscape:
- right Fleet Dock rail remains 104px
- toolbar stays outside the grid transform
- Sell keeps responsive _landscapeX interpolation
```

Remove only fixed N1/N2 coordinate assertions and replace them with grid viewport/deposit assertions.

Also keep the full-bleed cavern, active-planet aggregate sale, small-cargo unsellable feedback, Fleet Dock semantics, and navigation callback tests.

- [ ] **Step 11: Wire one shell grid-tap entry point**

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
    case MineSiteGridTapAction.recall:
      _runSheetAction(
        () => _controller.recallRig(siteId, cell),
        successMessage: 'Rig recalled.',
      );
    case MineSiteGridTapAction.blocked:
      _showResult(outcome.message!);
  }
}
```

Pass it to `MineSiteScreen`. Keep `_preserveDockSelection()` and latest-main `_displayNotifier` behavior unchanged.

- [ ] **Step 12: Port HPA-451 into `LandingBasinGridVisualLayer`**

Create one `StatefulWidget` receiving:

```dart
final MineSiteView view;
final int impactSequence;
final bool reducedMotion;
```

It owns one impact controller, one S1 idle controller, finite-frame precache state, and the same 200ms stalled-first-impact timer semantics as the current node visual.

For each deposit:

```text
no miners / reduced motion -> static stage
occupied S1                -> idle frames except hit window
crossing .90 on impact     -> exhaust frames then S4
```

Progress remains `view.cargo / view.capacity`.

Render every deposit once and every rig separately. Keep the arm pivot:

```dart
alignment: const Alignment(.33, -.24)
```

Facing:

```dart
final rigCenterX = rig.placement.cell.x + .5;
final targetCenterX = rig.target.x + rig.target.size / 2;
final mirror = targetCenterX > rigCenterX;
```

Mirror the whole composed robot only when `mirror == true`; never rotate the chassis vertically.

Port the existing tests for stage boundaries, S1 loop, hit/exhaust frames, cold-cache drop/no replay, reduced motion, controller disposal, all T1-T5 assets, shoulder pivot, and concrete left/right/above/below facing.

Delete the old node visual/test only after the replacement suite passes.

- [ ] **Step 13: Update integration journey and all node-shaped fixtures**

Use legal d1-adjacent cells:

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

Replace every journey `deployRig(..., MiningNodeId.n1)` call. Keep all economic/progression assertions unchanged.

Update every listed fixture from `rigByNode` maps to `rigPlacements`, including latest-main Mine Site golden fixture and the shell live-sheet-HUD test fixture.

- [ ] **Step 14: Remove all live node vocabulary**

```sh
rg "MiningNodeId|MiningNodeDefinition|rigByNode|nodeAsset|onNodeTap|_MineNodeButton|nodeAvailability|nextNodeAvailability|surveyingNodeAvailability|portraitNodeAnchors|landscapeNodeAnchors|mine-site-node-" lib test
```

Expected: no matches.

Do not grep historical planning/evidence docs for this gate.

- [ ] **Step 15: Run full runtime verification before committing**

```sh
dart format lib/mining test/mining test/integration/merge_mining_journey_test.dart
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
```

Expected: all PASS. On macOS the two Mine Site goldens remain skipped; Task 3 provides Linux evidence.

Pay explicit attention to these latest-main regressions remaining green:

```text
- Technology/Settings sheet HUD updates while foreground cargo accrues
- MiningSheetFrame safe-area/close behavior
- PR #26 cash formatting and Fleet Dock behavior
- Mine Site non-node chrome/layout tests
```

- [ ] **Step 16: Commit the atomic cutover**

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
- No production API changes.

**Interfaces:** final verification/guidance only.

- [ ] **Step 1: Use the repository-managed Linux/Flutter environment**

Preferred route: run this task in the repo-managed Cloud Agent environment from PR #25. Bootstrap if necessary:

```sh
bash .cursor/install.sh
export PATH="/opt/flutter/bin:$PATH"
```

Then prove canonical renderer prerequisites:

```sh
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
flutter --version | grep 'Flutter 3.32.5'
```

Expected: all exit 0.

Do not re-add the temporary golden-regeneration workflow used by PR #26. Do not use a macOS `--update-goldens` no-op as evidence.

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

- [ ] **Step 4: Inspect the regenerated images against both baselines**

Confirm:

```text
430x932
- d1 area visible on first viewport
- visible grid and locked Surveying badge
- 1x1 art readable at 80px
- PR #26 cash/cargo/back/Sell/Fleet Dock/navigation chrome retained

874x402
- grid remains left of the 104px Fleet Dock rail
- Sell retains PR #26 responsive placement
- toolbar/chrome remain fixed
- no old N3/N4 geometry remains
- Landing Basin rigs stay upright and do not clip
```

If the grid fails, edit only Task 2 grid/Mine Site visual files and repeat focused tests + this Linux golden cycle.

- [ ] **Step 5: Update `CLAUDE.md`**

Replace node-assignment guidance with:

```text
Mine Site is a Flutter InteractiveViewer over an authored 24x18 grid. Each site owns four static deposits; rigs occupy one cell and mine the unique orthogonally adjacent deposit. Placement legality is centralized in mining_grid.dart, state persists rigPlacements, and production remains aggregate/deterministic in MiningSimulation. Sites remain capped at four rigs. Landing Basin owns the only site-specific animated grid layer; its shell impact sequence is presentation-only.
```

Also document:

- old `rigByNode` saves intentionally recover fresh through the existing invalid-save boundary;
- `_displayNotifier` remains a shell rebuild channel for live modal HUDs, not another state owner;
- PR #26 non-grid Mine Site chrome remains the presentation baseline.

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