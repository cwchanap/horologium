# Mining Grid Map Design

## Status

Implementation design for replacing each Mine Site's four fixed deployment nodes with a pannable authored grid containing static resource deposits and player-placed mining rigs.

Planning, implementation, review, and verification stay on **one branch and one pull request**. Continue on draft PR #23; do not open a second implementation PR.

This revision is grounded on current `main` commit `e1e8b394626622f43dce05fd13f206d5de5b0c1b` after:

- PR #22 / HPA-451 landed the Landing Basin hit-synchronized robot/deposit animation;
- PR #26 aligned gameplay presentation with the latest UI mock and regenerated the Mine Site Linux goldens;
- PR #25 added the repository-managed Cloud Agent environment pinned to Flutter 3.32.5;
- the following `e1e8b394` spec-kit cleanup changed no mining/runtime files.

## Self-review disposition

The grid/domain direction remains valid. The self-review found implementation-contract gaps rather than product-scope problems:

1. `rigPlacements` must preserve the current value-state contract, so `MiningRigPlacement` needs equality/hash and `SiteProgress` must defensively own an unmodifiable placement list;
2. enforcing defensive list ownership means `SiteProgress` intentionally loses its `const` constructor during the atomic cutover; affected test fixtures drop `const` rather than weakening immutability;
3. `MineSiteView.gridTapOutcome(...)` needs instance-level `isUnlocked` and `surveyingLevel`; those fields are part of the view contract rather than hidden factory locals;
4. `MiningGridMap` and `LandingBasinGridVisualLayer` need one explicit composition seam so Landing Basin does not render generic deposits/rigs and animated deposits/rigs at the same time;
5. oversized resource art stays visual-only while logical grid lines/highlights remain visible over it;
6. implementation steps must pin concrete test inputs/results instead of leaving “cover these cases” placeholders.

None of these changes adds a subsystem, dependency, save migration, or gameplay mechanic.

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

### Preserve peak envelope and Surveying pacing

Every site remains capped at four deployed rigs:

```dart
static const int maxDeployedRigsPerSite = 4;
```

Deposit sizes/caps are:

| Deposit | Size | Max miners |
| --- | ---: | ---: |
| d1 | 1x1 | 1 |
| d2 | 1x1 | 1 |
| d3 | 2x2 | 1 |
| d4 | 3x3 | 3 |

`d4` demonstrates multiple rigs mining one resource. Keeping d3 at one miner preserves the current maximum-deployed-rigs-by-Surveying curve:

| Site | Surveying 0..5 max deployable rigs |
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

## Reusable baseline

Keep the current ownership:

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

- `MiningShell` as the foreground refresh and presentation owner;
- `_selectedBayId` as the selected dock rig;
- `_displayState` / `MiningController.state` as authoritative state;
- `_displayNotifier` solely as the live modal-sheet rebuild channel added on current `main`;
- `MiningController._enqueueMutation`, save-before-publish, active-planet guards, commissioning, mastery, spawn/merge/sell/technology/travel;
- `MiningSimulation` deterministic elapsed-time/offline-cap accrual;
- `MiningSaveRepository` strict exact-key decoding, validation, invalid-save recovery, and cargo clamping;
- `MiningContentRegistry` as the only authored mining catalog;
- `SiteMetrics` as the shared site economy/card derivation;
- existing Landing Basin `_landingBasinImpactSequence`, staged gold frames, articulated T1-T5 body/arm assets, reduced-motion behavior, and cold-cache stalled-impact drop/no-replay behavior;
- current PR #26 cash/cargo/back/Sell/Fleet Dock/navigation chrome.

Do not add Provider, Riverpod, Bloc, a service locator, command bus, ECS, Flame, a tile-map/pathfinding package, another save layer, or a generic animation registry.

## Compile-safe delivery sequence

The final runtime has no node/grid dual model, but the first implementation commit is deliberately additive so it can be tested independently.

### Additive contract commit

`MiningSiteDefinition` temporarily keeps:

```dart
final List<MiningNodeDefinition> nodes;
final String nodeAsset;
```

and adds:

```dart
final int gridWidth;
final int gridHeight;
final List<MiningDepositDefinition> deposits;
final String depositAsset;
```

No production consumer switches to the grid in this commit.

### Atomic runtime cutover

The next commit changes every live consumer together: state, repository, controller, simulation, `SiteMetrics`, Mine Site view, progression views, Site Deck/Stellar Map asset consumers, Mine Site screen, shell, Landing Basin visual path, and the public integration journey.

That commit removes `MiningNodeId`, `MiningNodeDefinition`, `nodes`, `nodeAsset`, `rigByNode`, and node-named public projection fields. There is no committed compatibility adapter or dual persisted model.

## Grid geometry and authored content

### Dimensions

All nine sites start at:

```text
24 columns x 18 rows
56 logical pixels per placement cell
1344 x 1008 logical-pixel map surface
```

Dimensions live on `MiningSiteDefinition`; camera state is presentation-only and not persisted.

### Closed identities

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

class MiningPlacementResult {
  const MiningPlacementResult.allowed(this.target) : rejection = null;
  const MiningPlacementResult.rejected(this.rejection, {this.target});

  final MiningDepositDefinition? target;
  final MiningPlacementRejection? rejection;
  bool get isAllowed => rejection == null;
}
```

Existing image files remain under `assets/images/mining/nodes/`; the final domain field is `depositAsset`. Do not rename asset directories.

### Authored layouts

Coordinates are top-left cells:

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

Surveying requirements map current N1-N4 gates to d1-d4:

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

Content tests freeze every `(x, y, size, maxMiners, surveying)` tuple and prove:

- every footprint lies inside 24x18;
- footprints never overlap;
- every deposit has at least `maxMiners` in-bounds orthogonally adjacent empty cells;
- every empty cell is adjacent to at most one deposit;
- the max-rigs-by-Surveying table above remains exact.

## One shared placement predicate

Keep these pure helpers in `lib/mining/mining_grid.dart`:

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

`ambiguousAdjacentDeposit` remains an enum/invariant failure. Authored content forbids it, so there is no player-facing string.

Active planet, site unlock, selected dock rig, and recall capacity remain controller/view concerns because they are not grid geometry and are not valid save-decoder inputs.

## Mutable state and persistence

Replace `rigByNode` with value placements:

```dart
class MiningRigPlacement {
  const MiningRigPlacement({required this.tier, required this.cell});

  final RigTier tier;
  final MiningGridCell cell;

  @override
  bool operator ==(Object other) =>
      other is MiningRigPlacement && tier == other.tier && cell == other.cell;

  @override
  int get hashCode => Object.hash(tier, cell);
}
```

`SiteProgress` stores:

```dart
final List<MiningRigPlacement> rigPlacements;
```

`SiteProgress` intentionally becomes non-const so its constructor can defensively wrap `rigPlacements` with `List.unmodifiable`. `copyWith`, repository decode, and `MiningSave._copySites` all preserve that ownership. Equality compares placements in order and hash uses `Object.hashAll(rigPlacements)`.

Order is deployment/save order and is preserved exactly; production math does not depend on it.

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

The decoder keeps exact keys, validates list shape/types, and calls `evaluateMiningPlacement(...)` incrementally against already-decoded cells. Old `rigByNode` documents recover through the existing invalid-save boundary. Add no schema version, compatibility reader, converter, or migration registry.

The existing “decoded nested state is unmodifiable” test becomes a placement-list mutation test and must still throw `UnsupportedError`.

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

`MiningSimulation` accrues elapsed time over every unlocked planet and caps aggregate site cargo. It does not tick individual rigs or deposits.

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

`MineSiteView` must retain current economy/HUD fields and expose the context needed by instance tap resolution:

```dart
final bool isUnlocked;
final int surveyingLevel;
final List<MineSiteDepositView> deposits;
final List<MineSiteRigView> rigs;
final Set<MiningGridCell> deployableCells;

MineSiteRigView? rigAt(MiningGridCell cell);
MiningPlacementResult placementAt(MiningGridCell cell);
MineSiteGridTapOutcome gridTapOutcome(MiningGridCell cell);
```

`deployableCells` scans 432 cells only while a valid dock rig is selected and site context permits deployment. Do not add an index/cache.

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
      -> MiningGridMap
          -> InteractiveViewer
              -> cavern background
              -> exactly one site object layer
              -> grid/highlight painter
              -> lock badges + semantic overlays
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

The first viewport includes d1. One map-level `GestureDetector` converts local positions to grid cells. A drag pans and never deploys; taps after a transform resolve the intended cell.

### One explicit object-layer seam

`MiningGridMap` owns the branch. There is no registry and no builder abstraction:

```dart
Widget _objectLayer() => view.siteId == MiningSiteId.landingBasin
    ? LandingBasinGridVisualLayer(
        view: view,
        impactSequence: impactSequence,
        reducedMotion: reducedMotion,
        cellSize: miningGridCellSize,
      )
    : StaticMiningGridVisualLayer(
        view: view,
        cellSize: miningGridCellSize,
      );
```

`StaticMiningGridVisualLayer` is a private widget in `mining_grid_map.dart`, not a new file/framework. It renders each static deposit once and each rig once.

`LandingBasinGridVisualLayer` renders each Landing Basin deposit once and each articulated rig once. `MiningGridMap` does **not** also render generic object art for Landing Basin.

`MiningGridMap` separately owns lock badges, object semantics, grid highlights, and tap mapping so those interaction/accessibility rules are identical for Landing Basin and static sites.

### Preserve PR #26 Mine Site chrome

The grid replaces fixed node positioning, but keeps:

- portrait cash/cargo/back/Sell/Fleet Dock/navigation geometry;
- landscape 104px Fleet Dock rail and compact toolbar;
- current `MiningCashChip` formatting/size, including thousands separators;
- current Fleet Dock ordering and spawn control;
- current responsive Sell interpolation through `_landscapeX(...)`.

When deleting fixed-node helpers, remove `_nodeLeft`, N3/N4 overflow/overlap helpers, and node-size/rig-size positioning helpers only when they no longer have callers. **Retain `_landscapeX(...)` while Sell uses it.**

Do not modify `fleet_dock.dart`, `mining_hud.dart`, `mining_sheet_frame.dart`, Technology/Settings/Offline Return surfaces, or their PR #26 behavior. The only Offline Return exceptions are two atomic-cutover mechanical changes: (1) the "Next:" Text literal, whose retired `node` wording was updated to grid `cell` terminology with key/layout/behavior preserved; and (2) the single `Image.asset` asset-field rename `content.site(site).nodeAsset` -> `depositAsset` in `_resourceIcon`, required once the old node field is removed. No other runtime redesign.

### Visual footprint vs placement footprint

Keep 56px as the logical hit/placement unit, but center resource art at:

```text
1x1 -> 80 x 80 px visual
2x2 -> 120 x 120 px visual
3x3 -> 168 x 168 px visual
```

Visual overflow never changes occupancy or tap mapping. Render the grid/highlight painter after object art so logical cell boundaries/highlights remain visible over oversized resource art; lock badges and semantic overlays sit above it.

Locked deposits show an on-screen `Surveying N` badge and a matching semantic label. Deposit and rig semantics use logical footprint/cell bounds; do not create 432 semantic tile widgets.

## Landing Basin animation port

Replace node-local `LandingBasinMiningNodeVisual` with one `LandingBasinGridVisualLayer` receiving:

```dart
final MineSiteView view;
final int impactSequence;
final bool reducedMotion;
final double cellSize;
```

Preserve:

- one shell-owned impact sequence increment per eligible foreground refresh;
- staged gold S1-S4 from `site cargo / site capacity`;
- S1 idle, hit, and exhaust timing;
- finite frame precache and 200ms stalled-first-impact drop/no replay;
- articulated T1-T5 body/arm assets;
- shoulder pivot `Alignment(.33, -.24)`;
- reduced-motion static behavior;
- presentation-only ownership: animation never grants cargo or calls controller mutations.

Current node visuals all receive the same site impact sequence, so the site-level port intentionally drives every actively mined deposit from one impact controller. Do not create per-rig economy/impact clocks.

### Facing

The existing robot art is authored facing left toward the resource. Keep the chassis upright. Mirror the whole composed robot horizontally only when the target center is to the rig's right:

```dart
final rigCenterX = rig.placement.cell.x + .5;
final targetCenterX = rig.target.x + rig.target.size / 2;
final mirror = targetCenterX > rigCenterX;
```

Above/below placements use the same center-X rule; equal centers keep authored left-facing orientation. Do not persist facing.

## Shell integration

`MiningShell` keeps `_landingBasinImpactSequence` and changes only the deployed-rig query from `rigByNode` to `rigPlacements.isNotEmpty`.

The current `_displayNotifier` behavior is mandatory baseline behavior:

```text
controller/display state remains authoritative
-> _refreshPresentation updates _displayState
-> _displayNotifier.value mirrors it
-> modal MiningSheetScene ValueListenableBuilder refreshes HUD
```

The grid cutover must not remove, bypass, or repurpose the notifier.

One `_handleSiteGridCellTap` asks `MineSiteView.gridTapOutcome(cell)` and then deploys, recalls, or surfaces the returned message. Do not duplicate placement-context branching in the shell.

## Accessibility

Do not create semantic nodes for empty grid cells.

Expose:

- four deposit semantics: resource/deposit identity, logical footprint, miner count/cap, and Surveying requirement while locked;
- <=4 rig semantics: tier, grid coordinate, target deposit, recall action or disabled reason;
- visible Surveying lock badges for sighted users.

Physical taps remain owned by the map-level gesture surface. Semantic rig `onTap` forwards the rig's saved cell to the same `onCellTap` callback.

## Golden and verification contract

Mine Site goldens remain skipped on macOS and enabled on Linux. Canonical regeneration uses Linux/amd64 Flutter 3.32.5.

Prefer the repository-managed Cloud Agent environment:

```sh
bash .cursor/install.sh
export PATH="/opt/flutter/bin:$PATH"
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
flutter --version | grep 'Flutter 3.32.5'
```

Do not reintroduce PR #26's temporary golden-regeneration workflow.

Regenerate exactly:

```text
test/mining/presentation/goldens/mine_site_430x932.png
test/mining/presentation/goldens/mine_site_874x402.png
```

PR #26's non-node Mine Site chrome is the comparison baseline; fixed node coordinates are intentionally replaced.

## Non-goals

Do not add:

- robot movement/pathfinding;
- drag deployment or movement;
- procedural deposits;
- finite reserves/respawn;
- mixed resource types in one site;
- conveyors, power, storage buildings, crafting;
- deposit-specific speed modifiers;
- diagonal mining;
- terrain collision/buildability beyond deposit/rig occupancy;
- persisted camera/target/facing;
- a generic tile/world engine;
- more than four deployed rigs/site;
- `rigByNode` migration/backward compatibility;
- a generic site-animation registry.

## Delivery boundary

Keep this one PR. The final implementation leaves one mining runtime:

```text
MiningShell
  -> MiningController
      -> MiningSimulation
      -> MiningSaveRepository
      -> MiningContentRegistry
  -> MineSiteView
      -> MiningGridMap
          -> StaticMiningGridVisualLayer (private, non-Landing sites)
          -> LandingBasinGridVisualLayer (Landing Basin only)
```

with no parallel node runtime, no second state owner, and no second simulation clock.