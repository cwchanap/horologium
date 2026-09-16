# HPA-454 Dense Resource Fields and Multi-Robot Mining Slots Design

## Goal

Implement [HPA-454](https://linear.app/cwchanap/issue/HPA-454/mining-polish-add-dense-resource-fields-and-multi-robot-mining-slots) as one focused gameplay PR:

- make every Mine Site read as a dense field with roughly 100 resources;
- support 1×1, 2×2, and 3×3 resource footprints;
- allow multiple robots to mine one resource whenever different valid perimeter cells are free;
- remove authored `maxMiners` as a second capacity rule;
- preserve the existing four-rig site cap, Surveying progression, deterministic/offline economy, and current save ownership boundaries.

This is a content/placement cutover, not a new resource simulation. Resources remain effectively infinite and `MiningSimulation` remains authoritative for production.

## Current baseline

The design is based on `main` at `de23a3693497fc9d1ef6f24211b5f580957bd4ab`.

Today:

- every `MiningSiteDefinition` owns a 24×18 grid with four authored `MiningDepositDefinition`s;
- every deposit carries `MiningDepositId`, `size`, `maxMiners`, and `requiredSurveyingLevel`;
- `evaluateMiningPlacement(...)` is the shared legality predicate used by controller deployment, save decoding, and Mine Site highlights;
- rig persistence stores only tier plus grid cell, and the target deposit is reconstructed from geometry;
- the site economy already uses only deployed rig tiers, not deposit identity;
- Landing Basin owns a presentation-only animated layer on top of the same grid contract.

Those seams are already the right ownership model. HPA-454 should replace the four-deposit content contract without creating another placement, persistence, or economy subsystem.

## Decision

Use one small deterministic resource-field generator inside the existing mining content module. Keep the current `MiningDepositDefinition` type name to avoid unrelated rename churn, but remove persistent/authored identity and capacity from it.

The new definition is geometry plus Surveying only:

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
}
```

Do not replace `MiningDepositId` with another stored/string/UUID identity. When presentation needs a widget key, derive it from deterministic geometry (`x`, `y`, and `size`). HPA-455 may use the same transient geometry identity for local HP state later; it must not become save data.

## Field layout

### Fixed dimensions

Every site moves to a **50×50 logical grid**.

Keep the existing `miningGridCellSize = 56` and `InteractiveViewer`. The field remains pan/zoom content rather than trying to fit all 50×50 cells on screen.

### Resource count

Each site contains exactly **102 resources**:

- 12 resources in four Surveying progression anchor groups;
- 90 deterministic filler resources in a 10×9 lattice.

102 is intentionally fixed rather than random. It is inside HPA-454's accepted 80–120 range, is close to the desired ~100, and makes performance and tests predictable.

### Surveying progression anchors

The existing four authored deposits also encode the number of simultaneous mining opportunities unlocked by Surveying. Preserve that player-facing pacing without preserving `maxMiners`.

Use four one-slot anchor groups on the top boundary. Anchor X coordinates are:

```text
5, 17, 29, 41
```

For each anchor at `(x, 0)` generate three adjacent 1×1 resources:

```text
(x - 1, 0)  blocker
(x,     0)  progression anchor
(x + 1, 0)  blocker
```

Because the anchor is on the top boundary and its left/right cells are occupied by resources, its only valid perimeter slot is `(x, 1)`.

The four anchor Surveying levels preserve the current site progression exactly:

| Site | Anchor levels | Existing effective slots by Surveying 0→5 |
| --- | --- | --- |
| Landing Basin | `0, 0, 1, 2` | `2, 3, 4, 4, 4, 4` |
| Carbon Ridge | `0, 1, 2, 3` | `1, 2, 3, 4, 4, 4` |
| Granite Crater | `0, 1, 2, 3` | `1, 2, 3, 4, 4, 4` |
| Frozen Basin | `3, 3, 4, 5` | `0, 0, 0, 2, 3, 4` |
| Titanium Highlands | `4, 4, 5, 5` | `0, 0, 0, 0, 2, 4` |
| Helium Mare | `5, 5, 5, 5` | `0, 0, 0, 0, 0, 4` |
| Ochre Basin | `5, 5, 5, 5` | `0, 0, 0, 0, 0, 4` |
| Silica Dunes | `5, 5, 5, 5` | `0, 0, 0, 0, 0, 4` |
| Cobalt Chasm | `5, 5, 5, 5` | `0, 0, 0, 0, 0, 4` |

The two blockers in each group use the maximum anchor level for that site. They are therefore unavailable before the site's final current Surveying gate. At that final gate the site already has four anchor slots, so the global four-rig cap keeps the economy envelope unchanged even though many more perimeter cells become legal.

This is deliberately geometry-driven: the anchor contributes one slot because of where resources are placed, not because a `maxMiners = 1` property says so.

### Dense filler field

Below the anchor strip, generate a 10×9 set of 5×5 tiles beginning at logical Y=5. Each tile contains one resource with a one-cell minimum margin from tile edges.

For row-major filler index `i` and `siteId.index`, compute:

```dart
final value = (siteId.index * 31 + i * 17 + i * i * 7) % 97;
final size = 1 + value % 3;
final movableSpan = 4 - size; // 3 for 1×1, 2 for 2×2, 1 for 3×3
final offsetX = 1 + (value ~/ 3) % movableSpan;
final offsetY = 1 + (value ~/ 11) % movableSpan;
```

Then:

```dart
x = column * 5 + offsetX;
y = 5 + row * 5 + offsetY;
```

Every filler resource uses the site's maximum anchor Surveying level.

This formula is intentionally boring. It is deterministic across platforms, varies all three resource sizes and placement offsets by site, and does not justify a random-number abstraction, seed object, generator registry, or procgen framework.

The 5×5 tile envelope guarantees that even two neighboring 3×3 resources retain two empty columns/rows between footprints. That prevents a single empty cell from becoming orthogonally adjacent to two filler resources. The top anchor strip is separated from filler by several rows, so it also cannot create ambiguous adjacency.

## Placement contract

Keep `evaluateMiningPlacement(...)` as the one legality predicate consumed by:

- `MiningController.deployRig(...)`;
- `MiningSaveRepository` rig-placement decoding;
- `MineSiteView.placementAt(...)` and deployable-cell highlights.

The evaluation order remains:

1. reject when the site already has four rigs;
2. reject outside-grid cells;
3. reject cells occupied by a resource footprint;
4. reject cells occupied by another rig;
5. find the unique orthogonally adjacent resource;
6. reject no-resource or ambiguous-resource cells;
7. reject when that resource's Surveying requirement is not met;
8. otherwise allow placement.

Remove `MiningPlacementRejection.depositAtCapacity` entirely. There is no resource-level count check after Surveying.

A resource's capacity is now exactly the number of its valid perimeter cells. Multiple rigs target the same resource naturally because each rig occupies a different grid cell and `rigOccupied` only rejects the candidate cell itself.

Add one geometry helper for production code and tests:

```dart
Set<MiningGridCell> miningPerimeterCells({
  required int gridWidth,
  required int gridHeight,
  required List<MiningDepositDefinition> deposits,
  required MiningDepositDefinition target,
});
```

It returns in-bounds, non-resource cells for which `uniqueAdjacentDeposit(...)` resolves to `target`. Do not create a `MiningSlot`, assignment table, reservation object, or second placement evaluator.

## View model and presentation

`MineSiteView` continues deriving rig targets from geometry. For each resource expose:

- `minerCount`: rigs whose unique adjacent target is this resource;
- `slotCount`: geometry-derived perimeter slot count;
- `isSurveyed`.

No resource runtime model or controller mutation is added.

### Dense rendering

Keep the current `Stack`/`CustomPaint` architecture:

- one background image;
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

Update semantics copy from `N of maxMiners miners` to geometry, for example:

```text
Gold resource 1x1, 2 miners, 2 of 4 perimeter slots free.
```

For unsurveyed resources, dim the resource art and keep the Surveying requirement in semantics/tap feedback. Remove the per-resource floating lock badge: a badge repeated across ~100 objects creates visual clutter and unnecessary widget work. This is presentation simplification, not a new interaction.

### Landing Basin animation

Preserve the HPA-451 ownership contract:

- `impactSequence` remains shell-owned/presentation-only;
- animation never owns production or persistence;
- only resources with `minerCount > 0` use the active idle/hit sequence;
- robot strike direction still derives from the target resource geometry;
- cold-load/resume production is not replayed as historical strikes.

HPA-454 does not add per-resource HP, damage, depletion, break, or respawn state. Those remain HPA-455.

## Save and economy cutover

The JSON save shape does **not** change. `rigPlacements` still persist only:

```json
{"tier":"t2","x":5,"y":1}
```

Save decoding already revalidates rig cells against current content through `evaluateMiningPlacement(...)`. Keep that boundary.

Because the resource layout intentionally changes, old rig coordinates may fail validation and clean-reset through the existing invalid-save recovery path. Add no migration, schema version, legacy four-deposit decoder, target ID, or coordinate converter. A coincidentally still-valid old placement may remain valid; no compatibility work is required either way.

`MiningSimulation`, rate multipliers, capacity multipliers, cargo math, offline caps, selling, site commissioning, planet mastery, and technology costs remain unchanged. At a given Surveying level the number of usable slots up to the four-rig cap stays identical to the current contract.

## Test fixture strategy

Many tests currently hard-code the old authored cells (`(3,2)`, `(16,2)`, etc.). Do not replace those with a second set of copied magic coordinates in every file.

Add a small test-only helper under `test/support/` that asks the real content and placement predicate for deterministic legal cells. Domain tests still freeze the generator geometry separately, so higher-level controller/simulation/presentation tests can focus on their own behavior instead of duplicating layout knowledge.

Tests that specifically verify geometry or Landing Basin robot direction may assert exact anchor cells. General economy/save/journey tests should use the helper.

## Alternatives rejected

### Hand-author ~100 resources per site

This would produce nearly 900 coordinates to maintain, review, and adjust. It buys no gameplay value because resource identity is not persisted and sites already share the same placement rules.

### Persist generated resource IDs / slot assignments

This would require a resource entity model, save schema changes, migration logic, and a second ownership layer for data that can be reproduced from site ID and geometry. HPA-454 explicitly does not need that.

### Generic procgen strategies / registries

There is one field shape and nine fixed site seeds. A strategy interface, pluggable generator, PRNG abstraction, or content DSL would be speculative infrastructure. Keep one pure helper until a second genuinely different generation rule exists.

## Non-goals

Do not include:

- HPA-455 HP bars, damage text, break/refresh state, or presentation damage values;
- finite reserves, resource depletion, respawn, or economy changes;
- more than four deployed rigs per site;
- drag-and-drop or a new input system;
- new resource or robot artwork;
- new persistence fields or migrations;
- a second mining simulation, placement subsystem, resource registry, or generic procgen framework;
- Fleet Dock interaction changes from HPA-452;
- cargo/selling polish from HPA-286.

## Validation

Focused tests must prove:

- each site generates exactly 102 resources on a 50×50 grid;
- layouts are identical across repeated registry construction;
- every site contains 1×1, 2×2, and 3×3 resources;
- no resource footprints overlap;
- no empty cell is ambiguously adjacent to two resources;
- the Surveying effective-slot arrays remain exactly the table above after clamping to four rigs;
- two or more rigs can target one resource through different perimeter cells;
- occupying one perimeter cell does not block another valid perimeter cell;
- save reload reconstructs the same targets from geometry;
- incompatible old coordinates recover through the existing invalid-save boundary;
- aggregate production/offline tests retain the same numeric results;
- dense Mine Site rendering remains image/semantics based, with no per-cell widget grid;
- Landing Basin visual feedback still follows the visible impact sequence.

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

HPA-454 is complete when every Mine Site shows the deterministic 102-resource field, the existing Surveying-to-four-rig progression is unchanged, multiple robots can occupy distinct perimeter slots around one resource, `maxMiners`/`depositAtCapacity`/`MiningDepositId` are gone, saves still persist only rig placements, the deterministic/offline economy is unchanged, and HPA-455 can build transient per-resource hit feedback on top without another data model.