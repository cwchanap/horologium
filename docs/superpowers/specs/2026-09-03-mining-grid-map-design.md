# Mining Grid Map Design

## Status

Implementation design for the next Horologium mining interaction slice: replace each Mine Site's four fixed deployment nodes with a large authored grid containing fixed resource deposits and player-placed mining rigs.

Planning, implementation, review, and verification stay on **one branch and one pull request**. Continue on draft PR #23; do not open a second implementation PR.

This design is grounded on `main` commit `b00e0bcaa3bc4c77e5ae0ebdb0d6c83e51aeaee3`.

## Goal

Turn Mine Site from a fixed four-button cavern composition into a spatial mining surface:

```text
Site Deck
  -> Mine Site
      -> pan / pinch across a large fixed grid
      -> inspect authored deposits
      -> select a rig from the existing Fleet Dock
      -> deploy the rig onto one empty 1x1 grid cell
      -> rig mines the one orthogonally adjacent deposit
      -> multiple rigs may mine the same deposit up to that deposit's cap
      -> rig tier continues to determine mining speed
      -> recall and redeploy to change placement
```

The spatial layer adds placement decisions without turning Horologium into an RTS. Rigs do not walk, pathfind, choose jobs autonomously, consume power, connect to conveyors, or simulate frame-by-frame production.

## Product boundary

### One existing Mine Site equals one grid map

Keep the current navigation and economy hierarchy:

```text
Planet
  -> Site Deck
      -> Landing Basin (Gold grid)
      -> Carbon Ridge (Coal grid)
      -> Granite Crater (Stone grid)
      -> ...
```

Do **not** combine every resource on a planet into one world map in this slice.

`MiningSiteDefinition.resource`, site unlock progression, site cargo, sale value, site capacity, commissioning, Technology gates, planet mastery, Stellar Map travel, and active-planet selling remain site-oriented exactly as today. A site's grid contains multiple deposits of that site's one resource type.

This keeps the current `MiningController -> MiningSimulation / MiningSaveRepository` ownership and avoids rebuilding progression around a new world model.

### Existing rigs are the mining robots

The player's requested "robot" is the existing deployed rig. Keep the existing `RigTier { t1, t2, t3, t4, t5 }`, Fleet Dock, spawn, merge, and tier multiplier vocabulary in this PR.

Do not perform a mechanical `Rig` -> `Robot` rename while changing placement. The rendered rig may visually be a robot, but the established domain identity remains `RigTier` until a separate product-copy decision requires a rename.

### Preserve the current production envelope

Today every site exposes four deployment nodes. Preserve that maximum:

```dart
static const int maxDeployedRigsPerSite = 4;
```

The grid may expose more valid mining positions than four, but a site may never hold more than four deployed rigs at once.

This matters because deploying a rig empties a dock bay and the player can spawn another rig afterward. Without a site cap, replacing four fixed nodes with many perimeter cells would silently increase maximum throughput and storage far beyond the current economy.

## Reusable baseline

Current runtime seams to keep:

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

- `MiningShell` as the only long-lived presentation owner and one-second foreground refresh owner;
- `_selectedBayId` as the selected dock rig;
- `MiningController._enqueueMutation`, save-before-publish, active-planet guards, commissioning, mastery reward, spawn, merge, sell, technology, and planet travel behavior;
- `MiningSimulation` deterministic elapsed-time and offline-cap accrual;
- `MiningSaveRepository` strict exact-key decoding, invariant validation, invalid-save recovery, and capacity clamp behavior;
- `MiningContentRegistry` as the only authored mining catalog;
- `RigTier` rate/capacity multipliers and Extraction/Logistics technology multipliers;
- current site cavern asset as the grid-map background and current rig/resource assets as the first grid visuals;
- current portrait/landscape HUD, Fleet Dock, navigation, Sell control, and safe-area composition outside the pannable map.

Do not add Provider, Riverpod, Bloc, a service locator, command bus, ECS, Flame, a tile-map package, a pathfinding package, or another save/repository layer.

## Selected grid model

### Fixed dimensions

All nine current sites use the same initial authored dimensions:

```text
24 columns x 18 rows
```

This is deliberately data-backed on `MiningSiteDefinition` rather than hard-coded into the widget so later authored maps may grow without replacing the model.

Presentation uses a fixed logical cell size of `56.0` pixels initially:

```text
24 x 56 = 1344 px map width
18 x 56 = 1008 px map height
```

The map is therefore larger than both current portrait and landscape Mine Site viewports and meaningfully pannable without requiring an enormous content surface.

Camera/pan/zoom state is presentation-only and is not persisted.

### Closed deposit identity

Replace the fixed `MiningNodeId` / `MiningNodeDefinition` concept with four authored deposits per site:

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
  final int size; // 1, 2, or 3; square footprint
  final int maxMiners;
  final int requiredSurveyingLevel;
}
```

`x` / `y` are the deposit footprint's top-left cell.

A deposit occupies exactly `size * size` cells. Rotated or irregular footprints are out of scope.

`MiningSiteDefinition` replaces `nodes` with:

```dart
final int gridWidth;
final int gridHeight;
final List<MiningDepositDefinition> deposits;
final String depositAsset;
```

Rename the current `nodeAsset` field to `depositAsset`; existing asset file paths may stay under `assets/images/mining/nodes/` so this change does not require an asset-directory churn.

### Authored map layouts

Every current site starts as a `24 x 18` map with four deposits. All coordinates below are top-left cells.

Deposit shape/cap rules are shared for the initial content:

| Deposit | Size | Max miners |
| --- | ---: | ---: |
| d1 | 1x1 | 1 |
| d2 | 1x1 | 1 |
| d3 | 2x2 | 2 |
| d4 | 3x3 | 3 |

Coordinates:

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

Surveying levels preserve the current N1-N4 gates by mapping them directly to D1-D4:

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

Built-in content tests must prove:

- every footprint lies inside `0 <= x < 24`, `0 <= y < 18`;
- deposit footprints never overlap;
- sizes are only 1, 2, or 3;
- each deposit has at least `maxMiners` in-bounds orthogonally adjacent empty cells;
- every empty grid cell is orthogonally adjacent to **at most one** deposit.

That last invariant intentionally removes target-selection UI from the first slice. A rig's mining target is always derivable from its position.

## Adjacency and placement rules

### Orthogonal adjacency only

A rig at `(x, y)` mines a deposit when the rig cell shares one edge with any cell of the deposit footprint.

Diagonals do not count.

For a 1x1 deposit there are four possible perimeter cells. A 2x2 deposit exposes eight perimeter cells. A 3x3 deposit exposes twelve.

### Deployment validation

`MiningController.deployRig(...)` accepts a dock bay, site, and grid cell. It derives the target deposit from authored content rather than accepting a deposit ID from presentation.

A deployment succeeds only when all of these are true:

1. the site is on the active planet and unlocked;
2. the selected dock bay contains a rig;
3. the site has fewer than four deployed rigs;
4. the cell is inside the site's grid;
5. the cell is not occupied by any deposit footprint;
6. the cell is not occupied by another rig;
7. exactly one authored deposit is orthogonally adjacent;
8. current Surveying meets that deposit's requirement;
9. the number of rigs already adjacent to that deposit is below `maxMiners`.

A deployed rig stays on that cell until recalled. There is no move action. Repositioning is recall -> deploy.

### One rig mines one resource

Because built-in maps guarantee that one empty cell is adjacent to at most one deposit, the target deposit is derived rather than persisted.

This satisfies "one resource at a time" without another saved identifier or target-selection state.

If future authored content intentionally allows one cell to touch multiple deposits, that is a separate interaction design change. Do not add a hidden automatic priority rule now.

## Mutable state and persistence

Replace `SiteProgress.rigByNode` with a compact list of placements:

```dart
class MiningRigPlacement {
  const MiningRigPlacement({
    required this.tier,
    required this.cell,
  });

  final RigTier tier;
  final MiningGridCell cell;
}

class SiteProgress {
  final bool unlocked;
  final bool commissioned;
  final double storedAmount;
  final List<MiningRigPlacement> rigPlacements;
}
```

There are at most four placements, so a list keeps persistence and mutation simpler than a coordinate-keyed map. Lookup is trivially cheap.

JSON for one site becomes:

```json
{
  "unlocked": true,
  "commissioned": true,
  "storedAmount": 12.5,
  "rigPlacements": [
    {"tier": "t1", "x": 3, "y": 2},
    {"tier": "t3", "x": 16, "y": 2}
  ]
}
```

`MiningSaveRepository` keeps exact-key decoding and validates placements against the current authored site:

- list length <= 4;
- every placement has exact `tier`, `x`, `y` keys;
- tier is a known `RigTier`;
- coordinates are integer/in-bounds;
- coordinates are unique;
- no placement occupies a deposit;
- every placement has exactly one adjacent deposit;
- every adjacent deposit meets the saved Surveying level;
- each deposit's persisted miner count is <= `maxMiners`;
- locked planets/sites remain pristine;
- stored cargo still clamps to capacity derived from the placement tiers.

This is an intentional breaking save shape. Do not add a schema version, `rigByNode` converter, dual decoder, or migration registry. Existing saves containing `rigByNode` fail strict decoding and use the repository's existing invalid-save recovery path.

## Production and economy

### Rig level keeps determining speed

Do not introduce deposit-specific speed formulas in this slice.

Reuse current math:

```text
siteRate = baseRatePerSecond
         * extractionRateMultiplier
         * Σ rateMultipliers[placement.tier]

siteCapacity = baseCapacity
             * logisticsCapacityMultiplier
             * Σ capacityMultipliers[placement.tier]
```

The only change is that the tier list comes from `rigPlacements` instead of `rigByNode.values`.

A T3 rig therefore mines faster than a T1 rig exactly as it does today.

### Deposits are not finite

`maxMiners` means simultaneous mining-rig limit, **not ore quantity**.

Do not persist remaining deposit reserves. Deposits do not deplete, respawn, refill, or disappear. Site cargo continues to be one aggregate `storedAmount` for the site's resource.

This keeps offline production deterministic and avoids retargeting/respawn state.

### Offline accrual remains aggregate

`MiningSimulation` continues to calculate `elapsed seconds * effective site rate`, capped by site capacity and Logistics offline duration.

It does not tick individual rigs or deposits and does not replay mining actions while offline.

The spatial relationship is a deployment invariant; it is not a second simulation loop.

## Mine Site view model

Evolve `MineSiteView` away from four `MineSiteNodeView`s.

Add narrow presentation projections:

```dart
class MineSiteDepositView {
  final MiningDepositDefinition definition;
  final int minerCount;
  final bool isSurveyed;

  bool get isAtMinerLimit => minerCount >= definition.maxMiners;
}

class MineSiteRigView {
  final MiningRigPlacement placement;
  final bool canRecall;
  final String? disabledReason;
}
```

`MineSiteView` exposes:

```dart
final List<MineSiteDepositView> deposits;
final List<MineSiteRigView> rigs;
final Set<MiningGridCell> deployableCells;
```

`deployableCells` is populated only when:

- a dock rig is selected;
- the site is active/unlocked;
- the controller is not busy;
- the site has fewer than four deployed rigs.

A cell is included when it passes the same static placement rules: in bounds, empty, exactly one adjacent surveyed deposit, and that deposit is below its miner cap.

Recall capacity checks stay the current behavior: tapping a deployed rig may be disabled when the dock is full or removing that rig would make current cargo exceed post-recall capacity.

## Mine Site interaction

### Pannable map, fixed chrome

Replace `_MineCavern`'s four manually-positioned node widgets with a focused `MiningGridMap` widget:

```text
MineSiteScreen Stack
  -> map viewport
      -> InteractiveViewer
          -> 1344 x 1008 map surface
              -> cavern/background image
              -> CustomPainter grid + deployment highlights
              -> deposit visuals
              -> rig visuals
  -> cash chip                         fixed
  -> cargo gauge                       fixed
  -> Sell                              fixed
  -> Fleet Dock                        fixed
  -> navigation / back controls        fixed
```

Use Flutter's built-in `InteractiveViewer`; do not reintroduce Flame or a camera abstraction.

Initial interaction constants:

```dart
static const double miningGridCellSize = 56.0;
minScale: 0.8;
maxScale: 1.6;
constrained: false;
```

The authored first deposit is near the upper-left portion of every map, so the default initial viewport remains immediately playable without adding camera-centering state.

### One map-level tap surface

Do not create 432 empty-cell widgets.

`MiningGridMap` uses one `GestureDetector`/tap callback on the map surface and converts local coordinates to a cell:

```dart
final cell = MiningGridCell(
  details.localPosition.dx ~/ miningGridCellSize,
  details.localPosition.dy ~/ miningGridCellSize,
);
```

Deposits and rigs render as positioned visual children. The map-level tap resolves behavior from `MineSiteView`.

### Deploy flow

Keep the current Fleet Dock selection flow:

```text
tap occupied dock bay
  -> selected bay remains highlighted
  -> valid empty cells around surveyed/non-full deposits highlight
  -> tap one highlighted cell
  -> MiningController.deployRig(selectedBay, siteId, cell)
  -> rig leaves dock and appears at that cell
```

Do not add drag-and-drop deployment in this slice. Pan is already a drag gesture, so tap-to-place avoids gesture ambiguity.

### Recall flow

```text
tap deployed rig cell
  -> if recall is allowed: recall to first empty dock bay
  -> otherwise show existing disabled-reason feedback
```

There is no direct grid move operation.

### Resource footprint rendering

Reuse the site's `depositAsset` once per authored deposit and size its visual box to the footprint:

```text
1x1 -> 56 x 56
2x2 -> 112 x 112
3x3 -> 168 x 168
```

Reuse `MiningVisuals.rigAsset(tier)` in a 1x1 `56 x 56` cell.

The grid painter is responsible for empty-cell lines and selected deployment highlights. Do not introduce one widget per empty tile.

## Interaction with draft PR #22 / HPA-451

Draft PR #22 plans hit-synchronized Landing Basin animation against the current fixed `MiningNodeId` / `_MineNodeButton` geometry. Implementing that fixed-node presentation first would create throwaway work because this grid slice removes those anchors and node identities.

Ordering:

1. land the grid-map implementation from PR #23;
2. rebase/revise HPA-451's implementation plan onto `MiningGridMap`;
3. attach mining-hit animation to rendered `MiningRigPlacement` + derived adjacent deposit rather than to N1-N4 buttons.

The useful HPA-451 principle still survives: UI animation remains presentation-only and never grants resources. This grid PR does **not** add the hit-synchronization sequence or new animation assets.

## Non-goals

Do not add in this slice:

- robot movement or pathfinding;
- drag-to-move or drag-to-deploy rigs;
- procedural resource placement;
- finite/depleting deposits;
- deposit respawn;
- multiple resource types inside one site;
- conveyors, logistics routes, power grids, storage buildings, or crafting;
- resource-specific mining speed modifiers;
- diagonal mining;
- terrain collision/buildability rules beyond occupied deposit/rig cells;
- persisted camera position/zoom;
- a generic tile engine, world ECS, or simulation clock;
- more than four deployed rigs per site;
- save migration/backward compatibility for `rigByNode`.

## Delivery boundary

The implementation remains one coherent PR because the domain, save, controller, view, and presentation changes are not independently shippable: a grid map without persisted placement cannot resume correctly, and persisted grid placement without the Mine Site map is not player-usable.

The final implementation should leave:

```text
MiningShell
  -> MiningController
      -> MiningSimulation
      -> MiningSaveRepository
      -> MiningContentRegistry
  -> MineSiteView
      -> MiningGridMap
```

with no parallel mining model and no second runtime.