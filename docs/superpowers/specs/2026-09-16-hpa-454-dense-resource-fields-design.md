# HPA-454 Dense Resource Fields and Multi-Robot Mining Slots Design

## Goal

Implement [HPA-454](https://linear.app/cwchanap/issue/HPA-454/mining-polish-add-dense-resource-fields-and-multi-robot-mining-slots) as one focused gameplay PR:

- make every Mine Site read as a dense field with roughly 100 resources;
- support 1×1, 2×2, and 3×3 resource footprints;
- make multi-robot mining visible as soon as a site is playable;
- remove authored `maxMiners` as a second capacity rule;
- preserve the four-rig site cap, existing Surveying requirements, deterministic/offline economy formulas, and current save ownership boundaries.

This is a content/placement cutover, not a new resource simulation. Resources remain effectively infinite and `MiningSimulation` remains authoritative for production.

## Review resolution

The first draft over-constrained HPA-454 by reproducing the old `maxMiners`-driven effective-slot table exactly. Doing that required blocker resources whose only purpose was to recreate the capacity concept being deleted, and it delayed same-resource multi-robot placement until max Surveying on most later sites.

The revised design removes that constraint:

- keep the existing four per-site Surveying levels as content;
- place those four progression resources in the same dense lattice as every other resource;
- let their normal geometry expose multiple perimeter cells;
- re-baseline placement availability to the new geometry instead of emulating the old one-slot anchors;
- keep the global four-rig cap and every production/capacity formula unchanged.

This intentionally changes **when four placement slots become available**, not how deployed rigs produce. The ticket is gameplay polish; making its headline interaction usable at the site's first playable Surveying level is more valuable than preserving an untuned pre-1.0 slot curve.

The review also exposed three avoidable hot paths in the first draft. The revised design therefore:

- caches the generated `MiningContentRegistry` instead of rebuilding ~900 resources per call;
- precomputes static resource perimeter cells once with the site definition;
- buckets the at-most-four rig targets once per `MineSiteView` build;
- derives deployable highlights from the surveyed perimeter candidate set instead of scanning all 2,500 grid cells;
- keeps static Landing Basin resources outside the animation-frame builder.

## Current baseline

The design is based on the HPA-454 draft PR's `main` baseline. Today:

- every `MiningSiteDefinition` owns a 24×18 grid with four authored `MiningDepositDefinition`s;
- every deposit carries `MiningDepositId`, `size`, `maxMiners`, and `requiredSurveyingLevel`;
- `evaluateMiningPlacement(...)` is the shared legality predicate used by controller deployment, save decoding, and Mine Site highlights;
- rig persistence stores only tier plus grid cell, and the target deposit is reconstructed from geometry;
- the site economy uses deployed rig tiers, not deposit identity;
- Landing Basin owns a presentation-only animated layer over the same grid contract.

Those ownership seams remain correct. HPA-454 replaces content and derived geometry without adding another state owner, simulation, slot subsystem, or save model.

## Resource identity and placement model

Keep the current `MiningDepositDefinition` name to avoid unrelated rename churn, but reduce it to geometry + Surveying:

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

Delete:

- `MiningDepositId`;
- `MiningDepositDefinition.maxMiners`;
- `MiningPlacementRejection.depositAtCapacity`.

Do not replace them with another ID, slot entity, reservation table, UUID, string key, or persisted target.

When widgets or transient presentation state need identity, use deterministic geometry (`x`, `y`, `size`, `requiredSurveyingLevel`). HPA-455 may use the same transient geometry key for local HP state later; it must not become save data.

## Field layout

### Fixed dimensions and count

Every site moves to a **50×50 logical grid** containing exactly **100 resources**.

Use one 10×10 lattice of 5×5 tiles. Every tile owns exactly one resource. This is simpler than the first draft's separate 12-resource anchor strip + 90-resource filler path, remains inside HPA-454's accepted 80–120 range, and keeps geometry/performance predictable.

Keep `miningGridCellSize = 56` and the current `InteractiveViewer`; the field remains pannable/zoomable rather than fitting 50×50 cells on screen.

### Existing Surveying content

Keep the existing four Surveying levels for each site:

| Site | Progression resource levels |
| --- | --- |
| Landing Basin | `0, 0, 1, 2` |
| Carbon Ridge | `0, 1, 2, 3` |
| Granite Crater | `0, 1, 2, 3` |
| Frozen Basin | `3, 3, 4, 5` |
| Titanium Highlands | `4, 4, 5, 5` |
| Helium Mare | `5, 5, 5, 5` |
| Ochre Basin | `5, 5, 5, 5` |
| Silica Dunes | `5, 5, 5, 5` |
| Cobalt Chasm | `5, 5, 5, 5` |

The first four row-major lattice resources use those four levels. All remaining resources use the site's maximum level. Surveying still visibly reveals additional resource bodies; it no longer exists to emulate the deleted per-resource miner cap.

### One generator path

For row-major index `i` (`0..99`) and `siteId.index`:

```dart
final value = (siteId.index * 31 + i * 17 + i * i * 7) % 97;
final isProgressionResource = i < 4;
final size = isProgressionResource ? 2 + i % 2 : 1 + value % 3;
final requiredSurveyingLevel = isProgressionResource
    ? progressionLevels[i]
    : maxSurveyingLevel;
final movableSpan = 4 - size;
final offsetX = 1 + (value ~/ 3) % movableSpan;
final offsetY = 1 + (value ~/ 11) % movableSpan;

final x = column * 5 + offsetX;
final y = row * 5 + offsetY;
```

The four progression bodies therefore alternate 2×2 / 3×3 and expose multiple perimeter cells naturally. They use the same lattice placement rule as filler resources; there are no blocker bodies or separate top-edge strip.

The 5×5 envelope keeps at least two logical cells between neighboring maximum-size footprints. That is enough to keep resource footprints non-overlapping and prevent one empty cell from being orthogonally adjacent to two resources.

This formula is intentionally boring and contains no RNG, seed object, generator registry, strategy interface, or procgen framework.

### Re-baselined placement availability

With normal 2×2/3×3 progression resources, a site's first surveyed progression body already exposes more than one perimeter cell. After the global four-rig cap, the effective placement-slot table becomes:

| Site | Effective slots by Surveying 0→5 |
| --- | --- |
| Landing Basin | `4, 4, 4, 4, 4, 4` |
| Carbon Ridge | `4, 4, 4, 4, 4, 4` |
| Granite Crater | `4, 4, 4, 4, 4, 4` |
| Frozen Basin | `0, 0, 0, 4, 4, 4` |
| Titanium Highlands | `0, 0, 0, 0, 4, 4` |
| Helium Mare | `0, 0, 0, 0, 0, 4` |
| Ochre Basin | `0, 0, 0, 0, 0, 4` |
| Silica Dunes | `0, 0, 0, 0, 0, 4` |
| Cobalt Chasm | `0, 0, 0, 0, 0, 4` |

This is an intentional HPA-454 gameplay change. Tests should pin the table and monotonicity, but must not attempt to reconstruct the old one-slot capacity rule.

For every site, at `site.requiredSurveyingLevel`, at least one surveyed resource must expose two or more valid perimeter cells. This is the direct acceptance condition that keeps multi-robot mining reachable rather than technically present but hidden behind later tech.

## Static geometry cache

A 100-resource field makes repeated geometry scans unnecessary work. Keep the cache as derived immutable content, not runtime state.

`MiningSiteDefinition` stores:

```dart
final List<MiningDepositDefinition> deposits;
final Map<MiningDepositDefinition, Set<MiningGridCell>> perimeterCellsByDeposit;
```

Build `perimeterCellsByDeposit` once when constructing the site using the same production `miningPerimeterCells(...)` helper. Sets/maps are unmodifiable.

This is not another capacity rule. The cache is only the materialized result of deterministic geometry; controller/save legality still goes through `evaluateMiningPlacement(...)`.

## Cached registry construction

The old registry is effectively free because it is const. The generated field must not turn `MiningContentRegistry.stellarMining()` into repeated construction.

Use one cached instance:

```dart
static final MiningContentRegistry _stellar = _buildStellarMining();

factory MiningContentRegistry.stellarMining() => _stellar;
```

`_buildStellarMining()` generates all nine site fields once. Existing call sites such as `MiningSaveRepository`, `MiningShell`, and `TechnologySheet` remain unchanged and cheap.

Tests should explicitly prove the factory returns the identical cached instance. Do not use two factory calls as a generator-determinism test; that would only test the cache. Generator correctness is pinned by exact progression-resource geometry plus exhaustive count/size/bounds/overlap/ambiguity/uniqueness invariants.

## Placement contract

Keep `evaluateMiningPlacement(...)` as the sole legality predicate consumed by:

- `MiningController.deployRig(...)`;
- `MiningSaveRepository` rig-placement decoding;
- `MineSiteView.placementAt(...)`;
- deployable-cell highlight filtering.

Evaluation remains:

1. site four-rig capacity;
2. bounds;
3. resource footprint;
4. occupied rig cell;
5. unique orthogonally adjacent resource;
6. no/ambiguous adjacency;
7. Surveying requirement;
8. allow.

There is no resource miner-count check after Surveying.

Add/keep one geometry helper:

```dart
Set<MiningGridCell> miningPerimeterCells({
  required int gridWidth,
  required int gridHeight,
  required List<MiningDepositDefinition> deposits,
  required MiningDepositDefinition target,
});
```

It returns in-bounds, non-resource cells whose unique adjacent resource equals `target`.

## MineSiteView projection without repeated static work

`MineSiteView.from(...)` runs during foreground refresh, so it must not recompute static geometry for all 100 resources each time.

### Rig target/miner-count projection

Resolve each of the at-most-four rig placements once:

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

Then each `MineSiteDepositView` reads:

- `minerCount` from `minerCountByDeposit[deposit] ?? 0`;
- `slotCount` from `definition.perimeterCellsByDeposit[deposit]!.length`;
- `isSurveyed` from current Surveying.

Each `MineSiteRigView` reuses `targetByRigCell[placement.cell]!` rather than resolving the target again.

### Deployable highlights

Do not scan every 50×50 grid cell.

Build the candidate set from the cached perimeter sets of surveyed resources, remove obviously occupied cells, then filter candidates through `evaluateMiningPlacement(...)`. The shared evaluator remains authoritative while the view stops asking it about cells that can never be legal.

## Dense rendering

Keep the existing `Stack`/`CustomPaint` architecture:

- one repeated cavern background;
- one image per resource;
- one image per rig;
- one semantics region per resource;
- grid/highlight lines in `MiningGridPainter`.

Do **not** build 2,500 grid-cell widgets.

Use geometry-derived keys such as:

```text
mining-deposit-<x>-<y>-<size>
landing-basin-deposit-<x>-<y>-<size>
```

Semantics use geometry-derived slot counts, for example:

```text
Gold resource 2x2, 2 miners, 6 of 8 perimeter slots free.
```

For unsurveyed resources, dim the art and preserve the Surveying requirement in semantics/tap feedback. Do not render ~100 floating lock badges.

## Background treatment

A 50×50 surface is 2800×2800 logical pixels at the current cell size. Do not stretch one existing cavern frame across that full square.

Reuse the existing cavern art as a repeated background:

```dart
Image.asset(
  view.definition.cavernAsset,
  fit: BoxFit.none,
  alignment: Alignment.topLeft,
  repeat: ImageRepeat.repeat,
)
```

This keeps HPA-454 code-only and avoids forced upscale/crop. A manual visual gate must check for obvious seams/repetition. If the existing cavern frames cannot tile acceptably, do **not** add generated art to this coding ticket: create a separate image-generation task and keep that asset decision isolated, per project workflow.

## Landing Basin animation cost

The current Landing Basin `AnimatedBuilder` rebuilds every resource on every animation tick. That is acceptable at four resources but not at 100.

Split the visual layer:

- pass all resources with `minerCount == 0` as the `AnimatedBuilder.child` static layer;
- rebuild only resources with `minerCount > 0` (maximum four) and rigs inside the animation builder;
- preserve current impact, idle, exhaust, reduced-motion, and strike-direction timing.

When rig placement changes, the parent rebuild naturally reconstructs which deposits belong to static vs animated layers. No resource animation registry is needed.

## Save cutover

The save JSON remains unchanged:

```json
{"tier":"t2","x":5,"y":1}
```

There is no migration, schema version, legacy decoder, target ID, or coordinate converter.

The recovery consequence must be explicit: `MiningSaveRepository` validates every persisted rig coordinate through `evaluateMiningPlacement(...)`. If **any** persisted placement is invalid under the new generated geometry, `_decode(...)` throws and `load(...)` returns an entirely fresh `MiningSave.initial(...)`. That resets cash, technology, unlocked planets, docks, cargo, and site progress — not only rig positions.

Some legacy coordinates may happen to remain valid under the new lattice; that survival is incidental and unsupported. Tests should use one known old valid Landing Basin coordinate that becomes invalid under the new geometry (for example the old `(16,2)` placement, which falls inside a new progression resource) and prove the whole invalid-save recovery boundary activates.

This is acceptable for the current pre-1.0 project; it simply must not be described as a partial rig reset.

## Economy boundary

Keep unchanged:

- `MiningSimulation` and elapsed-time accrual;
- rig tier/extraction rate formulas;
- logistics capacity formulas and offline caps;
- cargo/selling;
- site commissioning;
- planet mastery/reward logic;
- technology costs and site/planet requirements.

HPA-454 intentionally permits filling the existing four-rig site cap earlier than the old resource-cap geometry. That placement-pacing change is part of this feature; once rigs are deployed, production math is unchanged.

## Test fixture strategy

Many tests hard-code the old authored cells. Do not replace those with another copied coordinate table in every file.

Add a test-only helper under `test/support/` that:

1. reads the real site definition;
2. unions cached perimeter cells for resources available at the requested Surveying level;
3. filters candidates through `evaluateMiningPlacement(...)`;
4. returns deterministic row-major legal cells.

Geometry/content tests independently freeze the generator, so higher-level controller/simulation/presentation tests can focus on behavior without hiding a geometry regression.

Exact coordinates remain appropriate only where geometry itself is under test (for example one Landing Basin strike-direction case).

## Alternatives rejected

### Preserve the old effective-slot table with blocker resources

Rejected. It rebuilds the deleted one-miner capacity rule through geometry, adds fake visual bodies, and hides same-resource multi-robot play until late Surveying on most sites.

### Hand-author ~100 resources per site

Rejected. Nearly 900 coordinates add maintenance without gameplay value.

### Persist resource IDs / slot assignments

Rejected. Generated geometry is deterministic and persistence only needs rig tier/cell.

### Generic procgen strategies / registries

Rejected. There is one field rule and nine fixed site IDs. One pure helper is enough.

## Risks and gates

### Placement pacing intentionally changes

Earlier access to four legal cells can accelerate when a player is able to deploy four rigs. This is intentional HPA-454 behavior; numeric production per deployed rig remains unchanged. Tests pin the new table so it cannot drift accidentally.

### Dense-field CPU/widget cost

100 resources magnify work that was trivial at four. Cache registry/static perimeters, bucket rig targets, avoid the 2,500-cell scan, and keep static Landing Basin deposits out of the animation-frame builder. Do not add a general spatial index unless profiling after these cuts proves it necessary.

### Visual readability/background scaling

A deterministic field can still look noisy. Before completion, manually inspect Landing Basin and one max-Surveying site on a portrait viewport. Verify resource density, background tiling, initial deployability, pan/zoom readability, and that dimmed locks are understandable without 100 badges. If existing background art cannot be reused acceptably, split new art into a separate image-generation task.

### Breaking save recovery

Any incompatible rig coordinate invalidates the complete save document and resets all mining progress. No migration is added; document and test this boundary explicitly.

### Intermediate commits

Removing `MiningDepositId` / `maxMiners` creates temporary compile fallout in dependent files. The first two focused commits may only have their targeted tests green; the whole repository is required to compile again in the integration cutover commit and must remain green at the PR tip. Do not represent intermediate commits as independently releasable.

## Validation

Focused automated validation must prove:

- every site has exactly 100 resources on a 50×50 grid;
- every site's resource definitions are unique (`site.deposits.toSet().length == 100`);
- all three sizes exist at every site;
- all footprints are in bounds and non-overlapping;
- no empty cell is ambiguously adjacent to two resources;
- the cached `stellarMining()` factory returns the identical instance;
- progression resource levels remain the existing four-level lists;
- computed effective slots match the revised table and are monotonic;
- at each site's first playable Surveying level, at least one resource exposes ≥2 valid perimeter cells;
- two or more rigs can target the same resource through distinct perimeter cells;
- occupying one perimeter cell does not block another valid cell;
- static perimeter counts are read from the site cache;
- miner counts come from one rig-target bucketing pass;
- deployable-cell candidates come from surveyed perimeter sets and still pass the shared placement predicate;
- a known incompatible legacy placement triggers full invalid-save recovery;
- aggregate production/offline numeric tests retain their formulas/results for the same deployed rig set;
- dense rendering stays image/semantics based with no per-cell widget grid;
- Landing Basin animation rebuilds only mined resources/rigs per animation tick;
- existing cavern art is tiled rather than stretched across the 2800×2800 field.

Manual visual validation must open:

1. Landing Basin at its initial Surveying level with a rig selected;
2. one Surveying-5 site (prefer Ochre Basin).

Verify:

- at least one deployable perimeter cell is reachable from the initial top-left viewport;
- two rigs can visibly target the same resource;
- ~100 bodies read as a field rather than noise;
- pan/zoom remains usable;
- resource sprites do not visibly collide;
- tiled cavern art is not distractingly repetitive/seamed;
- locked resources remain understandable without floating lock badges.

Then run the repository gate from `CLAUDE.md`:

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

## Acceptance criteria

HPA-454 is complete when:

- every Mine Site shows the deterministic 100-resource field;
- multi-robot placement on one resource is reachable at the site's first playable Surveying level;
- the four existing progression Surveying levels remain authored content;
- the revised effective-slot table is pinned and monotonic;
- `MiningDepositId`, `maxMiners`, and `depositAtCapacity` are gone with no replacement capacity/identity subsystem;
- `evaluateMiningPlacement(...)` remains the sole legality predicate;
- generated registry/static perimeter geometry is cached rather than rebuilt on refresh/render paths;
- Landing Basin does not rebuild all 100 static resources per animation frame;
- strict save JSON remains rig tier + cell only, with full invalid-save reset documented/tested;
- production/offline formulas remain unchanged;
- existing art is reused via tiling, with any required new art split into a separate image-generation task;
- the automated repository gate and manual visual gate both pass.