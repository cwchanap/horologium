# HPA-638 Technology and Lunar Frontier Design

## Status

Implementation design for Linear HPA-638, **Add simple technology and launch the Lunar Frontier**.

HPA-636 is complete and PR #15 has merged the mining-only cutover, so the HPA-638 start gate is satisfied. HPA-638 uses one branch and one PR for design, implementation, and verification.

This revision incorporates the second planning review. The goal is the same product outcome with less state ceremony and no compatibility work before a real release exists.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the Horologium mining roadmap.
2. Linear HPA-638, updated to match this reviewed scope.
3. This task-specific design.
4. HPA-631/HPA-636 designs as implementation history.

HPA-630 explicitly says not to add migration machinery before a released mining save creates a real compatibility requirement. The repository has CI build artifacts but no distribution workflow. Therefore HPA-638 does **not** migrate the current three-key development save; incompatible data continues through the existing clean-reset recovery boundary.

## Goal

Ship one complete progression step:

> Mine and sell on Homeworld → buy permanent technology with cash → reach Surveying 3 → unlock Lunar Frontier → reveal and mine Water Ice → progress through Titanium Ore and Helium-3 → leave → return to production from both planets.

The feature must extend the existing idle loop without adding a second economy, generic planet framework, or new state owner.

## Non-goals

Do not add:

- a third planet;
- technology points, research timers, laboratories, staff, claims, branching trees, or respec;
- shipping, manual cargo transfer, planet currencies, resource buying, dynamic markets, or processing;
- generic modifier/requirement/planet/biome frameworks;
- Provider/Riverpod/Bloc, command buses, event buses, new navigation infrastructure, or a package split;
- cloud save, accounts, server-authoritative time, or retention systems;
- a migration framework or legacy-save converter before a real release exists;
- a new asset-generation pipeline.

HPA-641 is the evidence point for whether a third planet needs more abstraction.

## Architecture

Preserve the existing ownership chain:

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
      -> MiningGame(active planet)
```

There is still exactly one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, and `horologium.mining.save` key per mining session.

Planet separation is enforced by **content-side iteration**, not by nesting mutable state. Sector IDs remain globally unique, so `MiningSave.sectors` stays the existing flat map.

## Identity and content catalog

Add closed identities:

```dart
enum MiningPlanetId { homeworld, lunarFrontier }

enum MiningSectorId {
  landingBasin,
  carbonRidge,
  graniteCrater,
  frozenBasin,
  titaniumHighlands,
  heliumMare,
}

enum TechnologyTrack { extraction, logistics, surveying }
```

Extend `ResourceType` with:

```dart
waterIce,
titaniumOre,
helium3,
```

Add:

```dart
class MiningPlanetDefinition {
  const MiningPlanetDefinition({
    required this.id,
    required this.name,
    required this.sectors,
    required this.terrainSeed,
  });

  final MiningPlanetId id;
  final String name;
  final List<MiningSectorDefinition> sectors;
  final int terrainSeed;
}
```

Extend `MiningSectorDefinition` only with:

```dart
final int requiredSurveyingLevel;
```

Homeworld sectors use `0`; Frozen Basin/Titanium Highlands/Helium Mare use `3/4/5`.

### Registry contract

`MiningContentRegistry` becomes the two-planet catalog:

```dart
final Map<MiningPlanetId, MiningPlanetDefinition> planets;

factory MiningContentRegistry.stellarMining();

MiningPlanetDefinition planet(MiningPlanetId id);
MiningSectorDefinition sector(MiningSectorId id);
MiningPlanetId planetForSector(MiningSectorId id);
```

The final implementation has **no public flat `content.sectors` getter** and no `phaseOne()` compatibility alias. Any iteration must first choose a planet.

Iteration rules:

- simulation: `unlockedPlanetIds` → `content.planet(id).sectors`;
- sell/HUD/tabs/action sheet: `content.planet(state.activePlanetId).sectors`;
- Flame: the `MiningPlanetDefinition.sectors` passed to that game instance;
- cross-planet direct lookup: `content.sector(id)` / `planetForSector(id)`.

This is the wrong-planet safety boundary.

## Technology model

`TechnologyLevels` remains three named integers, levels `0...5`, but it must centralize track access:

```dart
class TechnologyLevels {
  final int extraction;
  final int logistics;
  final int surveying;

  int levelFor(TechnologyTrack track);
  TechnologyLevels withLevel(TechnologyTrack track, int level);
}
```

There should be one exhaustive track switch here rather than repeated track switches in controller and presentation code.

### Costs

| Target level | Cash cost |
| ---: | ---: |
| 1 | 300 |
| 2 | 700 |
| 3 | 1,500 |
| 4 | 4,000 |
| 5 | 9,000 |

### Tier access

| Target level | Required mine |
| ---: | --- |
| 1 | Landing Basin |
| 2 | Carbon Ridge |
| 3 | Granite Crater |
| 4 | Frozen Basin |
| 5 | Titanium Highlands |

Each purchase accrues first, validates the required mine and cash, increments exactly one level, debits cash, saves once, then publishes the new state.

### Extraction

| Level | Production |
| ---: | ---: |
| 0 | 1.00× |
| 1 | 1.10× |
| 2 | 1.25× |
| 3 | 1.45× |
| 4 | 1.70× |
| 5 | 2.00× |

### Logistics

| Level | Storage | Offline cap |
| ---: | ---: | ---: |
| 0 | 1.00× | 8h |
| 1 | 1.15× | 10h |
| 2 | 1.30× | 12h |
| 3 | 1.50× | 16h |
| 4 | 1.75× | 20h |
| 5 | 2.00× | 24h |

### Surveying

The Stellar Map is visible at Surveying 0. Surveying changes eligibility, not visibility.

- 3: Lunar unlock requirement + Frozen Basin reveal.
- 4: Titanium Highlands reveal.
- 5: Helium Mare reveal.

Levels 1 and 2 are visible progress toward 3 and intentionally unlock no separate subsystem.

## Homeworld mastery and Lunar unlock

Homeworld mastery is derived, never stored:

```text
Landing Basin mine exists
AND Carbon Ridge mine exists
AND Granite Crater mine exists
```

Lunar Frontier unlock requires:

```text
Homeworld mastery
AND Surveying >= 3
AND cash >= 2,500
```

A successful unlock debits 2,500 cash, adds Lunar Frontier to the unlocked set, makes it active, persists once, and triggers the existing reward/haptic style. Failure changes nothing.

## Lunar Frontier content

| Sector | Resource | Surveying | Reveal | Build | Rate/s | Capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Frozen Basin | Water Ice | 3 | 0 | 500 | 1.00 | 150 | 6 | 700, 1,400, 2,800, 5,600 |
| Titanium Highlands | Titanium Ore | 4 | 3,000 | 1,200 | 0.80 | 140 | 12 | 1,600, 3,200, 6,400, 12,800 |
| Helium Mare | Helium-3 | 5 | 8,000 | 3,000 | 0.55 | 120 | 30 | 4,000, 8,000, 16,000, 32,000 |

Frozen Basin has no previous-sector requirement. Titanium requires Frozen revealed. Helium Mare requires Titanium revealed. Frozen still uses the shared zero-cost Reveal action so first landing keeps the discovery reward.

## State model

Keep the current flat sector map:

```dart
class MiningSave {
  final int cash;
  final DateTime lastAccruedAtUtc;
  final TechnologyLevels technology;
  final Set<MiningPlanetId> unlockedPlanetIds;
  final MiningPlanetId activePlanetId;
  final Map<MiningSectorId, SectorProgress> sectors;
}
```

`SectorProgress` and `MineState` keep their existing shapes.

No `MiningPlanetProgress`, `progressFor`, `withSector`, or content-registry dependency is added to state.

Initial current-format state contains all six authored sector keys:

- Landing Basin revealed; Carbon Ridge and Granite Crater unrevealed;
- all three Lunar sectors unrevealed/no mine;
- technology `0/0/0`;
- unlocked planets `{homeworld}`;
- active planet `homeworld`;
- cash `100`.

Planet scope is derived from the content catalog. While Lunar is locked, its three flat sector records must remain pristine.

## Persistence

Continue using `horologium.mining.save`. Do not add `schemaVersion`.

Current root keys are exactly:

```text
cash
lastAccruedAtUtc
technology
unlockedPlanetIds
activePlanetId
sectors
```

The `sectors` object contains exactly all six `MiningSectorId` keys.

Strict validation requires:

- non-negative integer cash;
- UTC timestamp;
- technology exactly `extraction/logistics/surveying`, each `0...5`;
- unique known unlocked planet IDs including Homeworld;
- active planet known and unlocked;
- all six sector keys exactly once;
- existing strict revealed/mine/level/cargo validation;
- Lunar sector state pristine while Lunar is locked.

Decode order is:

1. cash/timestamp;
2. technology;
3. unlocked/active planet IDs;
4. sectors/mines;
5. cross-field invariants.

Mine cargo normalization must use:

```dart
content.effectiveCapacity(sectorId, mineLevel, technology.logistics)
```

so Logistics is already known before mine records are clamped.

### No legacy conversion

The old three-key development document (`cash`, `lastAccruedAtUtc`, `sectors`) is not a supported input. It fails current exact-key validation and follows the existing `recoveredFromInvalidSave` clean-reset path with the existing user-readable recovery message.

Do not add `migratedLegacyV1`, `_decodeLegacyV1`, an initialization rewrite, or legacy-conversion tests.

A future released save format creates a real compatibility obligation; that is the point to add the smallest required converter.

## Deterministic multi-planet simulation

Keep one global accrual timestamp and one elapsed UTC window:

```text
usableElapsed = clamp(now - lastAccruedAtUtc,
                      0,
                      offlineCapFor(logistics))

for each unlocked planet:
  for each definition in content.planet(planetId).sectors:
    progress = state.sectors[definition.id]
    rate = effectiveRate(definition.id, mine.level, extraction)
    capacity = effectiveCapacity(definition.id, mine.level, logistics)
    produced = min(rate * elapsedSeconds, capacity - storedAmount)
```

Locked planets never accrue. Switching planets does not create a second clock.

`OfflineProductionSummary` contains:

```dart
Map<MiningPlanetId, Map<ResourceType, double>> productionByPlanet;
Set<MiningSectorId> fullSectors;
Duration elapsedUsed;
bool wasOfflineCapped;
```

`productionByPlanet` is grouped because the return sheet displays planet sections. `fullSectors` stays flat because sector IDs are globally unique; presentation can resolve/filter them through the catalog.

## Controller mutations

Keep the existing serialized future chain.

Existing `revealSector`, `buildMine`, and `upgradeMine` continue indexing `state.sectors[id]`. Reveal additionally validates `requiredSurveyingLevel`.

`sellAllCargo()` changes to active-planet-only:

```text
candidate = accrue(state)
for definition in content.planet(candidate.activePlanetId).sectors:
  value and clear candidate.sectors[definition.id]
credit global cash
save once
```

Add only:

```dart
purchaseTechnology(TechnologyTrack track)
unlockPlanet(MiningPlanetId id)
switchPlanet(MiningPlanetId id)
```

Every committing action accrues first, validates, saves the complete next state once, then publishes it.

## Pure presentation models

`MiningSheetView.from(...)` remains the authoritative action-affordance layer. It must:

- sell only active-planet cargo;
- validate Surveying before enabling Lunar Reveal;
- display `effectiveRate` and `effectiveCapacity` using current technology;
- render rates with **two decimal places** so Extraction 1 and 2 are visibly distinct on Landing Basin level 1.

Pin these exact Landing Basin L1 strings in tests:

```text
Extraction 0: 0.50/s
Extraction 1: 0.55/s
Extraction 2: 0.63/s
Extraction 3: 0.73/s
Extraction 4: 0.85/s
Extraction 5: 1.00/s
```

Add small pure `TechnologySheetView.from(...)` and `StellarMapView.from(...)` models. Widgets render their values and delegate mutations; they do not reimplement eligibility.

## Flutter presentation

`MiningScreen` remains the only Flutter owner.

Top layout:

```text
MiningStatusBar
active-planet sector tabs
[ TECHNOLOGY ] [ STELLAR MAP ] [ SETTINGS ]
```

The status bar shows active planet name, cash, active-planet revealed count, and active-planet cargo value. `Sell All Cargo` always means the active planet.

Verify 360×640 and 430×932 layouts with 48+ logical-pixel controls and reduced-motion confirmation.

## MiningGame replacement boundary

`MiningGame` becomes planet-specific without dynamic teardown/repopulation:

```dart
MiningGame({
  required MiningPlanetDefinition planet,
  required Map<MiningSectorId, SectorProgress> initialProgress,
});
```

`onLoad()` creates only `planet.sectors`, then applies `initialProgress` after components exist. Later `applyState(...)` updates only those same planet definitions.

`MiningScreen` must distinguish cold start from post-switch construction:

- in `initState`, create the first game from `_displayState.sectors`; `_controller.state` is not initialized yet;
- after successful unlock/travel, create the replacement from `_controller.state.sectors`.

Use `ValueKey(activePlanetId)` on the mounted `GameWidget`. Controller, repository, audio manager, lifecycle observer, and refresh timer are reused. Selection resets to Sell on switch. Old game callbacks/rewards must not receive later interactions.

Homeworld keeps terrain seed `631`; Lunar uses `638`. Planet atmosphere/tint switches directly on `MiningPlanetId`; do not add a theme or biome enum.

## Lunar visuals and asset reuse

Do not add six new PNG assets in HPA-638.

Reuse already-shipped, now-unused building sprites as Lunar facility identities:

- Frozen Basin / Water Ice → `Assets.waterTreatmentPlant`;
- Titanium Highlands → `Assets.grinderMill`;
- Helium Mare → `Assets.researchLab`.

These files are already covered by the directory-level asset declaration. The existing L1/L3/L5 structural overlays still provide tier progression.

Do not add resource PNGs or new `Assets.*Icon` constants. For distinct Lunar resource silhouettes in the return sheet, use built-in Material icons with exhaustive `ResourceType` mapping, e.g. water drop / hexagon / bubbles, plus the existing distinct names/colors. This satisfies the visual distinction without creating unused assets.

## Testing

Extend existing suites only.

Prove:

- exact two-planet catalog and Lunar content tables;
- `TechnologyLevels.levelFor/withLevel` for all three tracks;
- strict current save round trip and incompatible old save clean reset;
- Logistics-aware load clamp;
- Extraction/Logistics applied exactly once across both unlocked planets;
- locked Lunar does not accrue;
- grouped production plus flat full-sector summary;
- atomic tech purchase/Lunar unlock/switch and active-only sell;
- future-chain overlap cannot stale-overwrite switch/tech/sell;
- two-decimal MiningSheetView values and Surveying-disabled Reveal;
- Stellar Map visible at Surveying 0 with exact unmet conditions;
- cold-start game uses `_displayState`, post-switch game uses controller state;
- `ValueKey` game replacement preserves controller/audio/timer and prevents stale-game callbacks;
- Homeworld and Lunar mount only their own three sectors;
- two product journeys: progression to first Lunar mine, and two-planet offline return/sell.

## Delivery quality rule

Implementation tasks must not leave the branch uncompilable between commits. Each task ends with:

```sh
flutter analyze --fatal-infos
flutter test
```

plus the narrow RED/GREEN suite for that task.

Do not defer broad mechanical retargeting to the final journey task. The catalog/state/save contract task owns the call-site retarget required to restore full green before it commits.

Before leaving draft, also run:

```sh
dart format --output=none --set-exit-if-changed .
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

and one representative portrait smoke covering technology, Stellar Map, Lunar unlock, first Lunar mine, switching, and two-planet return.

## Documentation

After implementation is green, update `CLAUDE.md` and README for:

- flat six-sector current save;
- technology effects;
- catalog-scoped planet iteration;
- active-planet selling;
- keyed game replacement;
- no compatibility reader until a real release requires one.

## Scope check

This remains one HPA-638 PR with:

- one controller/simulation/repository/save key;
- one flat sector-state map;
- one two-planet content catalog;
- three technology tracks;
- three Lunar sectors/resources;
- two small pure progression view models and modal sheets;
- one replaceable planet-specific `MiningGame`;
- no new asset files and no legacy converter.
