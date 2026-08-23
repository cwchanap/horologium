# HPA-641 Mars Frontier Content Pack Design

## Status

Implementation design for Linear HPA-641, **Ship one additional planet content pack**.

HPA-638 is complete and PR #16 established the two-planet technology/Stellar Map architecture. HPA-641 extends that architecture with one authored third planet and no new gameplay subsystem. Planning, implementation, and verification stay on the same PR.

The Linear content brief is frozen before implementation.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630 mining roadmap.
2. Linear HPA-641 and its frozen content-brief comment.
3. This task-specific design.
4. HPA-638 design/implementation as the architecture baseline.
5. `CLAUDE.md` repository guidance.

## Goal

Ship one repeatable content-expansion unit:

> Master Lunar Frontier → unlock Mars Frontier → reveal three authored sectors → discover Iron Ore, Silica, and Cobalt Ore → build and upgrade the familiar mines → sell cargo → complete Mars mastery and receive a modest cash flourish.

The player should learn new content, not a new control scheme or economy.

## Frozen content brief

### Planet

- ID: `MiningPlanetId.marsFrontier`
- Display name: `Mars Frontier`
- Terrain seed: `641`
- Planet tint: `Color(0xFF2A1512)`
- Visual fantasy: rust-red industrial mining world with warm machinery and blue cobalt contrast.
- Unlock: Lunar Frontier mastery + Surveying 5 + 20,000 cash.
- Mastery: all three Mars mines built.
- Mastery reward: 25,000 cash on the false → true mastery transition.

The 25,000 reward is intentionally a small completion flourish/rebate, not funding for another progression tier. Do not increase it merely to create a larger economy spike without play/balance evidence.

### Sectors and economy

| Sector | Resource | Facility | `mineAsset` | Surveying | Reveal | Build | Rate/s | Capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Ochre Basin | Iron Ore | Iron Rig | `Assets.woodFactory` | 5 | 0 | 5,000 | 0.75 | 180 | 32 | 7,000 / 14,000 / 28,000 / 56,000 |
| Silica Dunes | Silica | Silica Extractor | `Assets.riceHuller` | 5 | 12,000 | 9,000 | 0.55 | 160 | 55 | 12,000 / 24,000 / 48,000 / 96,000 |
| Cobalt Chasm | Cobalt Ore | Cobalt Drill | `Assets.sawmill` | 5 | 30,000 | 18,000 | 0.35 | 130 | 110 | 24,000 / 48,000 / 96,000 / 192,000 |

Fixed anchors:

- Ochre Basin: `MiningWorldAnchor(-360, 330)`
- Silica Dunes: `MiningWorldAnchor(280, -60)`
- Cobalt Chasm: `MiningWorldAnchor(-80, -400)`

Discovery chain:

```text
Ochre Basin
  -> Silica Dunes
      -> Cobalt Chasm
```

All three require Surveying 5. Do not add Surveying 6 simply to create a Mars-only gate.

### Resource identities

Reuse `ResourceSilhouette` with built-in Material icons; add no resource PNGs.

- Iron Ore: industrial/construction silhouette, deep-orange identity.
- Silica: granular/material silhouette, amber identity.
- Cobalt Ore: science/crystal silhouette, blue identity.

### Authored discovery copy

Add optional `facilityName` and `discoveryText` fields to `MiningSectorDefinition`; existing sectors may keep defaults.

Mars copy:

- Ochre Basin: iron-rich regolith supports the first heavy extraction rig.
- Silica Dunes: glassy dune deposits trade lower throughput for stronger sale value.
- Cobalt Chasm: deep cobalt seams are the final high-value Mars target.

No discovery log, codex, or facility model is added.

## Visual identity contract

The existing `MiningPlanetDefinition.tint` currently affects only `MiningGame.backgroundColor()`, while the playable 1800×1800 terrain uses the same shared terrain tile/feature palette for every planet. A different seed changes terrain generation/layout but does not provide Mars with the promised rust palette by itself.

HPA-641 therefore reuses the existing authored `planet.tint` as both atmosphere and terrain identity. Do **not** add a second `terrainTint` field.

`MiningGame.onLoad()` adds one lightweight world-space `RectangleComponent`:

- size: `worldSize`;
- anchor/position: centered on the terrain;
- color: `planet.tint.withAlpha(96)`;
- blend mode: `BlendMode.color`;
- render order: above `ParallaxTerrainComponent`, below all `MiningSectorComponent`s.

This preserves terrain luminance/detail while giving Homeworld, Lunar Frontier, and Mars Frontier distinct in-world hue. It stays inside the existing `MiningGame` boundary and does not modify shared terrain generation under `lib/game/terrain/`.

No new image/audio payload is allowed.

## Stellar Map disclosure

Use progressive disclosure rather than showing every future world immediately.

- Homeworld is always visible.
- Lunar Frontier is visible from a fresh save because its prerequisite, Homeworld, is already unlocked.
- Mars Frontier becomes visible once Lunar Frontier is unlocked, even before Lunar mastery.
- Therefore a fresh player sees Homeworld + Lunar; a player who has unlocked Lunar sees Homeworld + Lunar + Mars.

This keeps the near-term goal visible without presenting an irrelevant Mars card at game start.

Locked cards show prerequisite mastery, Surveying, and cash. Unlocked cards show the planet's own `Mines x/y` mastery progress plus Travel/current-location state.

## Non-goals

Do not add:

- another technology track or technology level above 5;
- another currency, technology points, research timers, or laboratories as a progression system;
- processing, logistics, shipping, workers, resource transfer, or dynamic markets;
- procedural sectors, randomized deposits, or planet-specific simulation rules;
- a generic requirement engine, reward engine, event bus, or content-management platform;
- downloadable content, remote content, planet asset bundles, or a new preload pipeline;
- a second controller, repository, simulation, save key, or resident Flame world;
- a second terrain-generation/content system;
- a save compatibility/migration framework;
- a performance benchmark harness solely for this content pack.

## Architecture baseline to preserve

```text
MainMenu
  -> MiningScreen
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
          -> MiningContentRegistry
      -> MiningSheetView.from(...)
      -> TechnologySheetView.from(...)
      -> StellarMapView.from(...)
      -> MiningGame(active planet only)
```

Keep exactly one controller, simulation, repository, save key, and active `MiningGame`.

Existing runtime paths already scale correctly:

- simulation iterates unlocked planets and each planet's catalog sectors;
- active selling/HUD/tabs/sheet operate on `activePlanetId`;
- `MiningGame` receives one `MiningPlanetDefinition` and is replaced on travel/unlock;
- sector IDs remain globally unique and mutable progress remains flat `Map<MiningSectorId, SectorProgress>`;
- offline summary already groups by planet.

Do not rewrite these paths for Mars.

## Concrete seams HPA-641 may widen

### 1. Planet-level unlock/reward metadata

Extend `MiningPlanetDefinition` with direct authored fields:

```dart
final MiningPlanetId? unlockRequiredMasteryPlanetId;
final int unlockRequiredSurveyingLevel;
final int unlockCashCost;
final int masteryRewardCash;
```

Values:

| Planet | Required mastery | Surveying | Unlock cash | Mastery reward |
| --- | --- | ---: | ---: | ---: |
| Homeworld | none | 0 | 0 | 0 |
| Lunar Frontier | Homeworld | 3 | 2,500 | 0 |
| Mars Frontier | Lunar Frontier | 5 | 20,000 | 25,000 |

This is not a requirement/reward framework; it is the few fields used by both real authored unlocks.

Keep the old Lunar static unlock constants only until the final Stellar Map consumers are retargeted in the same implementation task. Remove them once there are no remaining callers; do not break intermediate commits merely to delete them earlier.

### 2. Planet mastery helper

Replace `isHomeworldMastered` with:

```dart
bool isPlanetMastered(
  MiningPlanetId planetId,
  Iterable<MiningSectorId> minedSectorIds,
)
```

Mastery is derived from the planet catalog and current mine-bearing sector IDs. Do not store a mastery flag or reward-claimed field.

### 3. Strict current save only

The save root remains exactly:

```text
cash
lastAccruedAtUtc
technology
unlockedPlanetIds
activePlanetId
sectors
```

The HPA-641 current document contains exactly all nine `MiningSectorId` keys.

Do **not** add a six-to-nine decoder branch. `_decodeSectors()` continues to derive the expected set from `MiningSectorId.values`; old six-sector HPA-638 development documents are incompatible and use the existing `recoveredFromInvalidSave` clean-reset path.

Update stale error copy such as “six authored sectors” to current-neutral wording.

Generalize the locked-planet invariant:

```text
for each authored planet not in unlockedPlanetIds:
  every sector on that planet must be unrevealed and have no mine
```

No `schemaVersion`, migration registry, compatibility reader, or legacy conversion flag.

### 4. Initial state from sector identity

`MiningSave.initial()` derives its flat map from the closed enum rather than hand-listing all authored sectors:

```dart
sectors: {
  for (final id in MiningSectorId.values)
    id: SectorProgress(
      revealed: id == MiningSectorId.landingBasin,
    ),
},
```

Landing Basin remains the only initially revealed sector.

### 5. Honest Surveying effect text

`TechnologySheetView` currently counts all authored sectors, including locked future planets, in `x of y sectors revealable`.

HPA-641 changes both numerator and denominator to sectors belonging to `state.unlockedPlanetIds` only. Examples:

- fresh Homeworld save: `3 of 3 sectors revealable` at Surveying 0;
- Lunar unlocked at Surveying 3: `4 of 6 sectors revealable`;
- Mars unlocked at Surveying 5: `9 of 9 sectors revealable`.

This is presentation honesty only; reveal eligibility and technology mechanics do not change.

### 6. Stellar Map projection without duplicated prerequisite counts

The current two-card `StellarMapView` becomes a list projection, but prerequisite names/counts are not copied into the target planet record.

```dart
class StellarMapPlanetView {
  final MiningPlanetId id;
  final String name;
  final bool isUnlocked;
  final bool isActive;
  final int minesBuilt;
  final int mineTotal;

  final MiningPlanetId? requiredMasteryPlanetId;
  final bool hasRequiredMastery;
  final int requiredSurveyingLevel;
  final bool hasSurveying;
  final int unlockCashCost;
  final bool hasCash;

  bool get canUnlock;
}

class StellarMapView {
  final List<StellarMapPlanetView> planets;

  StellarMapPlanetView planet(MiningPlanetId id) =>
      planets.singleWhere((view) => view.id == id);
}
```

A locked card resolves the prerequisite's display name and mine counts from `view.planet(requiredMasteryPlanetId)`. This keeps one source of truth for each planet's `minesBuilt/mineTotal` while preserving presentation-ready data and `canUnlock` booleans.

Use generic callbacks:

```text
onUnlock(MiningPlanetId)
onTravel(MiningPlanetId)
```

Use per-planet keys:

```text
mining-stellar-map-unlock-${id.name}
mining-stellar-map-travel-${id.name}
```

No polymorphic card/requirement hierarchy.

### 7. Optional content/result copy

- `MiningSectorDefinition.facilityName`
- `MiningSectorDefinition.discoveryText`
- `MiningActionResult.success(message: ...)`

`MiningActionResult.message` already exists; successful actions simply gain the ability to populate it. The existing snackbar path should prefer the result message when present.

## Unlock flow

`MiningController.unlockPlanet(id)` becomes data-driven:

1. accrue once using the shared clock;
2. reject already-unlocked or non-unlockable targets;
3. read target `MiningPlanetDefinition`;
4. require prerequisite mastery;
5. require Surveying level;
6. require cash;
7. debit cash, add target to unlocked set, make it active;
8. save once and publish once.

No planet-specific controller branch.

## Mars mastery reward

Inside the existing `buildMine(id)` mutation:

1. resolve the sector's planet with `planetForSector`;
2. compute `wasMastered` from pre-build state;
3. run the normal build/cost mutation;
4. compute post-build mastery;
5. when `!wasMastered && isMastered`, credit `masteryRewardCash`;
6. persist once and return success.

Mines cannot be removed, so the final missing mine can be built only once; no reward-claim state is needed.

Mars completion should surface a concise message such as `Mars mastered — +25,000 cash.` through the existing snackbar path.

## Deterministic simulation

`MiningSimulation` should require no structural change. One supplied UTC elapsed window continues to accrue all unlocked planets through the existing catalog iteration.

Add characterization coverage for:

- three unlocked planets in one elapsed window;
- Extraction/Logistics modifiers applying once;
- full Mars storage;
- locked Mars producing zero;
- offline grouping including Mars.

Modify simulation code only if these tests expose a concrete generic bug.

## Presentation

### Sector sheet

Keep `MiningSheetView` as affordance authority. Mars adds content display only:

- resource display name;
- optional `discoveryText` after reveal;
- optional `facilityName` in build copy;
- unchanged reveal/build/upgrade disabled-reason rules.

### Stellar Map

- fresh save: Homeworld + Lunar cards;
- Lunar unlocked: Homeworld + Lunar + locked Mars card;
- unlocked Mars: Mars card shows own `Mines x/y` and Travel/current-location state;
- locked cards resolve prerequisite mine counts from the prerequisite planet view entry;
- sheet remains one scrollable surface with 48px controls.

### Mining world

Mars reuses:

- 36×36 terrain;
- three sector components;
- camera fitting;
- reveal/construction/upgrade/sale effects;
- reduced-motion behavior;
- existing facility sprites.

The one added visual element is the tint overlay derived from `planet.tint`.

## Art/loading/memory/frame budget

- New PNG/JPEG/WebP/audio payload: **0 bytes**.
- Resource visuals: Material icons only.
- Facility sprites: existing `Assets.woodFactory`, `Assets.riceHuller`, `Assets.sawmill`.
- One active `MiningGame` only.
- No inactive resident Flame world.
- One additional lightweight rectangle tint component in the active world.
- Same 36×36 terrain and three sectors.
- Verify 360×640 and 430×932 portrait flows and reduced motion.
- Confirm world tint is visible but sector/facility readability remains acceptable.
- Do not add a benchmark framework without a reproducible regression.

## Verification contract

### Content/state/repository

Prove:

- exact Mars content values, sprites, anchors, seed, tint, resource identities, and authored copy;
- exactly nine current resource/sector identities;
- enum-derived initial state with only Landing Basin revealed;
- exact-nine save round trip;
- old exact-six document clean-resets as incompatible;
- generic locked-planet pristine validation;
- `CLAUDE.md` documents three planets/nine sectors/no compatibility reader.

### Technology

Prove Surveying display counts unlocked planets only and all catalog-count/exhaustive-enum assertions are retargeted.

### Controller

Prove:

- Lunar requirements unchanged;
- Mars requires Lunar mastery + Surveying 5 + 20,000 cash;
- successful unlock debits/unlocks/activates/saves once;
- final Mars mine grants exactly 25,000 once;
- successful result may carry the completion message;
- active-only selling remains unchanged.

### Stellar Map/UI

Prove:

- fresh save hides Mars;
- Lunar unlock reveals the locked Mars card;
- prerequisite progress and own progress cannot disagree because counts live only on each planet's own view entry;
- generic callbacks return the target planet ID;
- per-planet keys are unique;
- 360×640 and 430×932 remain usable;
- reduced motion completes the Mars journey.

### Mining world

Prove the world contains exactly one terrain tint overlay between terrain and sector components, derived from `planet.tint`, and smoke the Mars world for visible rust identity/readability.

### Repository gates

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

## Risks

1. **Intermediate compile break:** reshaping `StellarMapView` without its sheet/screen consumers makes the package fail before the next task. The entire view-model + widget + screen retarget belongs to one task/commit.
2. **Stale catalog-wide assertions:** enum growth breaks exact resource lists and technology `x of y` strings that are not found by save-fixture searches. Search for exhaustive enum lists and catalog-wide counts explicitly.
3. **Visual promise vs renderer:** a new seed/background tint alone does not make the playable terrain rust-toned. The world-space tint overlay is a required implementation item, not a late smoke-test discovery.
4. **Stale persisted fixtures:** with no converter, any six-key fixture silently tests recovery instead of its intended state. Retarget all current-shape fixtures in Task 1 and keep only one intentional old-six recovery case.

## Reuse/change ledger

### Reuse unchanged

- one `MiningController` / `MiningSimulation` / `MiningSaveRepository`;
- one strict unversioned `horologium.mining.save`;
- flat globally unique sector progress;
- deterministic multi-planet simulation;
- active-only Sell All;
- `MiningGame` replacement on travel;
- technology levels/effects/costs;
- terrain generator and existing terrain assets;
- offline grouping;
- reward effects and reduced motion.

### Widen because Mars is a real consumer

- Lunar-only unlock statics → planet metadata;
- Homeworld-only mastery → planet mastery;
- handwritten initial sectors → enum-derived current state;
- Lunar-only locked validation → generic locked-planet validation;
- two-card Stellar Map → list projection with prerequisite-by-ID lookup;
- single widget unlock key → per-planet keys;
- Surveying display → unlocked-planet counts;
- background-only tint → same authored tint also colors the playable terrain;
- optional sector/content success copy.

Do not generalize anything else for hypothetical future planets.

## Acceptance interpretation

HPA-641 is done when Mars feels like a distinct complete third world while the code still reads like the HPA-638 game with one more authored content pack. The success criterion is reuse surviving a real third consumer, not building a content platform.