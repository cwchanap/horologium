# Mining Grid Map Design

## Status

Implementation design for replacing each Mine Site's four fixed deployment nodes with a pannable authored grid containing static resource deposits and player-placed mining rigs.

Planning, implementation, review, and verification stay on **one branch and one pull request**. Continue on draft PR #23; do not open a second implementation PR.

This revision is grounded on `main` commit `c88ec833c48392781e09114c674011d8ba377f2a` after:

- PR #22 / HPA-451 landed the Landing Basin hit-synchronized robot/deposit animation;
- PR #26 aligned gameplay presentation with the latest UI mock and regenerated the Mine Site Linux goldens;
- PR #25 added the repository-managed Cloud Agent environment pinned to Flutter 3.32.5.

## Latest-main review disposition

The grid/domain direction remains valid. The eight commits since the previous baseline did **not** modify `mining_content.dart`, `mining_state.dart`, `mining_save_repository.dart`, `mining_controller.dart`, `mining_simulation.dart`, or `mine_site_view.dart`; all new movement is presentation, tests, and development tooling.

Keep the existing design decisions:

- one site = one resource map;
- static authored `24 x 18` grids;
- one small shared placement predicate in `mining_grid.dart`;
- `rigByNode` -> `rigPlacements` as an intentional strict-save break with no migration;
- max four deployed rigs per site;
- target/facing derived rather than persisted;
- infinite deposits; `maxMiners` is a simultaneous-rig cap;
- aggregate deterministic `MiningSimulation` math;
- Flutter `InteractiveViewer`, not Flame/ECS/pathfinding/tile-engine infrastructure;
- one Landing Basin-specific animation layer, not a generic animation registry.

Latest `main` adds four baseline contracts the implementation must preserve:

1. `MiningShell` now owns `_displayNotifier` solely as a rebuild channel for live modal-sheet HUD values. `_displayState` and `MiningController.state` remain authoritative. The grid cutover may change the Landing Basin `hasRig` query and map tap handler, but it must not remove or bypass this notifier.
2. PR #26 established the current Mine Site UI-mock parity baseline. The grid intentionally replaces fixed node geometry, but current cash/cargo/back/Sell/Fleet Dock/navigation chrome remains authoritative.
3. `_landscapeX(...)` in `mine_site_screen.dart` now positions the **Sell** control as well as fixed nodes. Removing node geometry must not delete that responsive Sell interpolation.
4. Linux golden setup is no longer an undefined external prerequisite: `.cursor/install.sh` installs Flutter 3.32.5 in the repository-managed Cloud Agent environment. Prefer that environment for Mine Site golden regeneration; do not re-add a temporary golden-regeneration workflow.

## Goal

Turn Mine Site from four fixed deployment buttons into a spatial mining surface:

```text
Site Deck
  -> Mine Site
      -> pan / pinch across one authored grid
      -> inspect static deposits
      -> select a rig in the existing Fleet Dock
      -> tap one legal 1x1 grid cell
      -> rig mines the unique orthogonally adjacent deposit
      -> multiple rigs may mine a large deposit up to its cap
      -> rig tier continues to determine mining speed
      -> tap a deployed rig to recall it
```

The spatial layer adds placement decisions without turning Horologium into an RTS. Rigs do not walk, pathfind, choose jobs autonomously, consume power, connect conveyors, or run a second simulation clock.

## Product boundary

### One existing Mine Site equals one grid map

Keep the current hierarchy:

```text
Planet
  -> Site Deck
      -> Landing Basin (Gold grid)
      -> Carbon Ridge (Coal grid)
      -> Granite Crater (Stone grid)
      -> ...
```

Do not combine every resource on a planet into one world map in this slice.

`MiningSiteDefinition.resource`, site unlock progression, site cargo, sale value, capacity, commissioning, Technology gates, planet mastery, Stellar Map travel, and active-planet selling remain site-oriented.

### Existing rigs are the mining robots

Keep `RigTier { t1, t2, t3, t4, t5 }`, Fleet Dock, spawn, merge, rate/capacity multipliers, and current user-facing vocabulary. Do not combine this placement cutover with a Rig -> Robot domain rename.

### Preserve peak throughput and Surveying pacing

Every site remains capped at four deployed rigs:

```dart
static const int maxDeployedRigsPerSite = 4;
```

Deposit shape/cap rules:

| Deposit | Footprint | Max miners |
| --- | ---: | ---: |
| d1 | 1x1 | 1 |
| d2 | 1x1 | 1 |
| d3 | 2x2 | 1 |
| d4 | 3x3 | 3 |

`d4` demonstrates multi-rig mining. Keeping `d3.maxMiners == 1` preserves the current maximum-deployed-rigs-by-Surveying curve:

| Site | Surveying 0..5 max deployed rigs |
| --- | --- |
| Landing Basin | `2, 3, 4, 4, 4, 4` |
| Carbon Ridge | `1, 2, 3, 4, 4, 4` |
| Granite Crater | `1, 2, 3, 4, 4, 4` |
| Frozen Basin | `0, 0, 0, 2, 3, 4` |
| Titanium Highlands | `0, 0, 0, 0, 2, 4` |
| Helium Mare | `0, 0, 0, 0, 0, 4` |
| Ochre Basin | `0, 0, 0, 0, 0, 4` |
| Silica Dunes | `0, 0, 0, 0, 0, 4` |
| Cobalt Chasm | `0, 0, 0, 0, 0, 4` |

## Ownership boundary

Keep the current runtime:

```text
MiningShell
  -> MiningController
      -> MiningSimulation
      -> MiningSaveRepository
      -> MiningContentRegistry
  -> FleetDockView / SiteDeckView / MineSiteView
  -> SiteDeckScreen / MineSiteScreen / StellarMapScreen
```

Reuse rather than recreate:

- `MiningShell` as the only long-lived presentation, foreground timer, lifecycle, and audio owner;
- `_displayState` as the shell's authoritative presentation snapshot and `_displayNotifier` as a rebuild channel only;
- `_selectedBayId` as the selected dock rig;
- `MiningController._enqueueMutation`, save-before-publish, active-planet guards, commissioning, mastery, spawn/merge/sell/technology/travel;
- `MiningSimulation` deterministic elapsed-time/offline-cap accrual;
- `MiningSaveRepository` strict exact-key decoding, invalid-save recovery, and cargo clamping;
- `MiningContentRegistry` as the only authored catalog;
- `SiteMetrics` as the shared rate/capacity/card derivation;
- Landing Basin `_landingBasinImpactSequence`, staged gold frames, articulated T1-T5 assets, reduced motion, finite-frame precache, and stalled-impact drop/no-replay behavior;
- current PR #26 Mine Site chrome and responsive layout outside fixed-node geometry.

Do not add Provider, Riverpod, Bloc, service locators, command buses, another save layer, Flame, ECS, tile-map/pathfinding packages, or generic animation/requirements frameworks.

## Compile-safe delivery sequence

The final runtime has no dual node/grid model. The implementation still uses two runtime commits so each checkpoint can be genuinely green.

### Additive contract commit

Temporarily keep existing `MiningNodeId`, `MiningNodeDefinition`, `nodes`, `nodeAsset`, and `rigByNode` runtime consumers. Add only the grid/deposit types, authored grid fields, shared predicate, and tests.

No production surface reads the new grid in this commit.

### Atomic identity cutover

The next runtime commit changes every live consumer together: save state, repository, controller, simulation, `SiteMetrics`, progression projections, Mine Site view, Site Deck/Stellar Map asset reads, Mine Site screen, shell, Landing Basin visual path, tests, and the public Mars journey.

That commit removes the node identity and `rigByNode`. There is no committed adapter or parallel save/runtime model.

## Grid geometry and authored content

### Dimensions

All nine current sites start at:

```text
24 columns x 18 rows
56 logical pixels per placement cell
1344 x 1008 logical-pixel map surface
```

Dimensions live on `MiningSiteDefinition`. Camera pan/zoom is presentation-only and is not persisted.

### Closed types

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
}
```

`MiningSiteDefinition` final grid fields:

```dart
final int gridWidth;
final int gridHeight;
final List<MiningDepositDefinition> deposits;
final String depositAsset;
```

Existing PNGs remain under `assets/images/mining/nodes/`; this is a domain-field rename, not an asset-directory migration.

### Authored coordinates

All coordinates are top-left grid cells:

| Site | d1 | d2 | d3 | d4 |
| --- | --- | --- | --- | --- |
| Landing Basin | `(3,3)` | `(16,3)` | `(5,11)` | `(16,10)` |
| Carbon Ridge | `(5,2)` | `(17,5)` | `(13,12)` | `(2,11)` |
| Granite Crater | `(2,5)` | `(18,2)` | `(5,12)` | `(15,10)` |
| Frozen Basin | `(4,3)` | `(15,2)` | `(3,12)` | `(16,10)` |
| Titanium Highlands | `(2,2)` | `(19,6)` | `(12,3)` | `(5,11)` |
| Helium Mare | `(6,2)` | `(18,3)` | `(3,10)` | `(14,11)` |
| Ochre Basin | `(2,4)` | `(17,2)` | `(14,12)` | `(4,11)` |
| Silica Dunes | `(5,3)` | `(19,4)` | `(3,12)` | `(14,9)` |
| Cobalt Chasm | `(3,2)` | `(18,6)` | `(7,12)` | `(14,10)` |

Surveying requirements map current N1-N4 values to d1-d4:

| Site | d1 | d2 | d3 | d4 |
| --- | ---: | ---: | ---: | ---: |
| Landing Basin | 0 | 0 | 1 | 2 |
| Carbon Ridge | 0 | 1 | 2 | 3 |
| Granite Crater | 0 | 1 | 2 | 3 |
| Frozen Basin | 3 | 3 | 4 | 5 |
| Titanium Highlands | 4 | 4 | 5 | 5 |
| Helium Mare | 5 | 5 | 5 | 5 |
| Ochre Basin | 5 | 5 | 5 | 5 |
| Silica Dunes | 5 | 5 | 5 | 5 |
| Cobalt Chasm | 5 | 5 | 5 | 5 |

Tests freeze every `(x,y,size,maxMiners,surveying)` tuple and prove:

- every footprint is in bounds;
- footprints do not overlap;
- footprint sizes are only 1/2/3;
- every deposit has at least `maxMiners` legal perimeter cells;
- every empty cell is adjacent to at most one deposit;
- the max-rigs-by-Surveying table above stays unchanged.

## Shared placement predicate

Keep one small pure result in `lib/mining/mining_grid.dart`. It accepts raw geometry/deposit data so the file does not import `mining_content.dart` or `mining_state.dart`.

```dart
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

class MiningPlacementResult {
  const MiningPlacementResult.allowed(this.target) : rejection = null;
  const MiningPlacementResult.rejected(this.rejection, {this.target});

  final MiningDepositDefinition? target;
  final MiningPlacementRejection? rejection;
  bool get isAllowed => rejection == null;
}
```

Helpers:

```dart
MiningDepositDefinition? uniqueAdjacentDeposit({
  required List<MiningDepositDefinition> deposits,
  required MiningGridCell cell,
});

MiningPlacementResult evaluateMiningPlacement({
  required int gridWidth,
  required int gridHeight,
  required List<MiningDepositDefinition> deposits,
  required Iterable<MiningGridCell> occupiedRigCells,
  required MiningGridCell candidate,
  required int surveyingLevel,
  required int maxRigCount,
});
```

The predicate owns only spatial legality:

1. site rig-count cap;
2. bounds;
3. deposit occupancy;
4. rig occupancy;
5. no adjacent deposit;
6. ambiguous adjacency;
7. Surveying gate;
8. target miner cap.

For a candidate inside a deposit footprint, return `depositCell` and attach that deposit as `target` so `MineSiteView` can prefer `Requires Surveying N.` for a locked deposit.

`ambiguousAdjacentDeposit` remains an enum/invariant failure. Authored content forbids the state, so no player-facing copy is required.

Active planet, site unlock, selected dock rig, and recall capacity remain controller/view concerns because they are not grid geometry and are not valid save-decoder inputs.

## Mutable state and persistence

Replace:

```dart
Map<MiningNodeId, RigTier?> rigByNode
```

with:

```dart
class MiningRigPlacement {
  const MiningRigPlacement({required this.tier, required this.cell});
  final RigTier tier;
  final MiningGridCell cell;
}

final List<MiningRigPlacement> rigPlacements;
```

At most four placements exist, so a list is simpler than a coordinate-keyed map.

JSON per site:

```json
{
  "unlocked": true,
  "commissioned": true,
  "storedAmount": 12.5,
  "rigPlacements": [
    {"tier":"t1","x":3,"y":2}
  ]
}
```

The decoder keeps exact keys, validates list shape/types, and calls `evaluateMiningPlacement(...)` incrementally against already-decoded cells. Invalid current or old `rigByNode` documents recover through the existing invalid-save boundary. Add no schema version, compatibility reader, converter, or migration registry.

## Production and progression

Production math is unchanged:

```text
siteRate = baseRatePerSecond
         * extractionRateMultiplier
         * Σ rateMultipliers[placement.tier]

siteCapacity = baseCapacity
             * logisticsCapacityMultiplier
             * Σ capacityMultipliers[placement.tier]
```

`MiningSimulation` continues to accrue elapsed time over every unlocked planet and caps aggregate site cargo. It does not tick individual rigs or deposits.

Technology Surveying projection renames all node vocabulary:

```text
nodeAvailability          -> depositAvailability
nextNodeAvailability      -> nextDepositAvailability
surveyingNodeAvailability -> surveyingDepositAvailability
_nodeAvailability(...)    -> _depositAvailability(...)
```

The count walks `site.deposits` and keeps the same availability semantics.

## Mine Site view model

Replace node projections with:

```dart
class MineSiteDepositView {
  final MiningDepositDefinition definition;
  final int minerCount;
  final bool isSurveyed;
}

class MineSiteRigView {
  final MiningRigPlacement placement;
  final MiningDepositDefinition target;
  final bool canRecall;
  final String? disabledReason;
}
```

`MineSiteView` exposes:

```dart
final List<MineSiteDepositView> deposits;
final List<MineSiteRigView> rigs;
final Set<MiningGridCell> deployableCells;

MineSiteRigView? rigAt(MiningGridCell cell);
MiningPlacementResult placementAt(MiningGridCell cell);
MineSiteGridTapOutcome gridTapOutcome(MiningGridCell cell);
```

`deployableCells` scans the 432 cells only while a valid dock rig is selected and the site context permits deployment. Do not add an index/cache.

`gridTapOutcome(...)` is the single shell-facing tap interpretation and preserves current strings:

```text
Finishing previous action…
Unlock this site first.
Travel to this planet first.
Select a rig from the dock.
Sell cargo before recalling this rig.
Dock is full.
Requires Surveying N.
```

It also maps placement failures for site cap, invalid cell, occupied cell, empty floor, and target miner cap.

## Grid presentation

### Transform only the mining map

Keep fixed chrome outside the transformed surface:

```text
MineSiteScreen
  -> cavern/map viewport
      -> InteractiveViewer
          -> cavern background
          -> one grid CustomPainter
          -> four deposits
          -> <=4 rigs
  -> cash chip
  -> cargo gauge
  -> Sell
  -> Fleet Dock
  -> navigation/back
```

Use:

```dart
InteractiveViewer(
  key: const Key('mining-grid-interactive'),
  constrained: false,
  alignment: Alignment.topLeft,
  minScale: .8,
  maxScale: 1.6,
  child: ...,
)
```

The first viewport must include d1. One map-level `GestureDetector` converts local positions to grid cells. A drag pans and must never deploy; taps after a transform must resolve the intended cell.

### Preserve PR #26 Mine Site chrome

The grid intentionally replaces fixed node positioning, but keep all non-node behavior from current `main`:

- portrait cash/cargo/back/Sell/Fleet Dock/navigation geometry;
- landscape 104px Fleet Dock rail and compact toolbar;
- current `MiningCashChip` formatting/size, including thousands separators;
- current Fleet Dock ordering and spawn control;
- current responsive Sell interpolation through `_landscapeX(...)`.

When deleting fixed-node helpers, remove `_nodeLeft`, N3/N4 overflow/overlap helpers, and node-size/rig-size positioning helpers only when they no longer have callers. **Retain `_landscapeX(...)` while Sell uses it.**

Do not modify `fleet_dock.dart`, `mining_hud.dart`, `mining_sheet_frame.dart`, Technology/Settings/Offline Return surfaces, or their PR #26 behavior for this feature.

### Visual footprint vs placement footprint

Keep 56px as the grid hit/placement unit, but center resource art over the footprint at:

```text
1x1 -> 80 x 80 px visual
2x2 -> 120 x 120 px visual
3x3 -> 168 x 168 px visual
```

This avoids shrinking the current gold art below its proven size while keeping logical geometry unchanged. Visual overflow does not change occupancy or tap mapping.

Locked deposits show an on-screen `Surveying N` badge and a matching semantic label. Do not make lock information semantics-only.

Deposit and rig objects receive semantics; do not create 432 semantic tile widgets.

## Landing Basin animation port

Replace node-local `LandingBasinMiningNodeVisual` with one `LandingBasinGridVisualLayer` that receives `MineSiteView`, `impactSequence`, and `reducedMotion`.

Preserve:

- one shell-owned impact sequence increment per eligible foreground refresh;
- staged gold S1-S4 from `site cargo / site capacity`;
- S1 idle, hit, and exhaust frame timing;
- finite frame precache and 200ms stalled-first-impact drop/no replay;
- articulated T1-T5 body/arm assets;
- shoulder pivot `Alignment(.33, -.24)`;
- reduced-motion static behavior;
- presentation-only ownership: animation never grants cargo or calls controller mutations.

Render each deposit once, then render all rigs targeting it. Do not duplicate a deposit per rig.

### Facing

The existing robot art is authored facing left toward the resource.

Keep chassis upright. Mirror the whole composed robot horizontally only when the target center is to the rig's right:

```dart
final mirror = targetCenterX > rigCenterX;
```

Above/below placements use the same deterministic center-X rule; equal X keeps the authored left-facing orientation. Do not rotate the chassis 90/180 degrees and do not persist facing.

## Shell presentation invariants from latest main

`MiningShell` now mirrors `_displayState` into `_displayNotifier` so Technology/Settings sheet HUDs continue to update while the separate bottom-sheet route is open.

The grid cutover must preserve:

```text
_controller.state / _displayState  = authoritative data
_displayNotifier                   = rebuild channel only
```

Keep `_displayNotifier.value = _controller.state` in `_refreshPresentation()` and dispose the notifier with the shell. Keep the existing widget regression proving a Technology sheet cargo gauge advances during foreground production.

Only update the Landing Basin `hasRig` query from `rigByNode` to `rigPlacements.isNotEmpty`; do not create another notifier or state owner.

## Golden and environment contract

Mine Site goldens remain skipped on macOS and enabled on Linux. PR #26 regenerated them on Linux/amd64 Flutter 3.32.5, so that is the canonical renderer.

Preferred regeneration route after the grid cutover:

1. use the repository-managed Cloud Agent environment;
2. run `bash .cursor/install.sh` if needed;
3. verify `uname -s == Linux`, `uname -m == x86_64`, and Flutter 3.32.5;
4. update exactly the two Mine Site goldens;
5. rerun the golden test without update mode.

Do not re-add the temporary golden-regeneration workflow used during PR #26. `.cursor/install.sh` and `.cursor/environment.json` are infrastructure inputs for verification, not files this feature modifies.

The new goldens must retain current PR #26 non-grid chrome while showing the new grid/deposit/rig composition.

## Non-goals

Do not add:

- robot movement/pathfinding;
- drag-to-deploy or drag-to-move;
- procedural resources;
- finite/depleting deposits or respawn;
- multiple resource types inside one site;
- conveyors, power, crafting, routing;
- deposit-specific rate modifiers;
- diagonal mining;
- persisted camera/target/facing;
- a generic tile engine, ECS, animation registry, or placement service;
- more than four deployed rigs per site;
- save migration/backward compatibility;
- secondary-surface UI changes unrelated to the grid.

## Final architecture

```text
MiningShell
  -> MiningController
      -> MiningSimulation
      -> MiningSaveRepository
      -> MiningContentRegistry
  -> MineSiteView
      -> MiningGridMap
          -> LandingBasinGridVisualLayer   # Landing Basin only
```

One mining runtime, one save, one controller, one simulation, one grid geometry/predicate file.