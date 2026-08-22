# HPA-638 Technology and Lunar Frontier Design

## Status

Implementation design for Linear HPA-638, **Add simple technology and launch the Lunar Frontier**.

HPA-636 is complete and PR #15 has merged the mining-only cutover, so the HPA-638 start gate is satisfied. HPA-638 uses one branch and one PR for design, implementation, and verification. Do not split technology, persistence, Stellar Map, Lunar content, multi-planet accrual, presentation, or tests into separate implementation PRs unless explicitly approved later.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the Horologium mining roadmap.
2. Linear HPA-638, the technology + Lunar Frontier acceptance contract.
3. This task-specific design.
4. The merged HPA-631 and HPA-636 designs as implementation history.
5. Older city-building documentation only as historical context.

HPA-638 creates the first real mining-save compatibility obligation. HPA-631 intentionally avoided migration machinery because no mining save had shipped. The first-planet mining save has now shipped and HPA-638 explicitly requires preserving it, so this design adds one direct shipped-v1 decoder and current-format rewrite without adding a migration framework or version field.

## Goal

Ship one complete long-term progression step:

> Mine and sell on the Homeworld → buy permanent technology with cash → reach Surveying 3 → unlock Lunar Frontier → reveal and mine Water Ice → progress through Titanium Ore and Helium-3 → leave → return to production from both planets.

The task must prove that technology and a second planet extend the current idle loop without turning Horologium back into a simulation-heavy game.

## Non-goals

Do not add:

- a third planet;
- technology points, research time, laboratories, staff, claims, branching trees, respec, or another spendable currency;
- quests, contracts, shipping, manual cargo transfer, planet-specific currencies, resource buying, dynamic markets, or processing;
- a generic modifier engine, requirement DSL, planet plugin registry, biome framework, navigation framework, state-management framework, command bus, event bus, or package split;
- procedural planets or a new asset-generation pipeline;
- per-resource controllers or resource-specific economy branches;
- cloud save, accounts, server-authoritative time, or retention systems.

HPA-641 is the next evidence point for whether another planet needs more abstraction. HPA-638 implements only the concrete Homeworld and Lunar Frontier seams.

## Current repository baseline

The merged mining-only architecture is deliberately small:

```text
MainMenu
  -> MiningScreen
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
          -> MiningContentRegistry
      -> MiningSheetView.from(...)
      -> MiningGame
          -> ParallaxTerrainComponent
```

Today the first planet is implicit everywhere:

- `MiningContentRegistry.sectors` is the whole authored world.
- `MiningSave.sectors` is the whole mutable world.
- simulation, selling, sheet derivation, HUD totals, tabs, and `MiningGame` iterate those flat collections.

That contract must end before Lunar content is added. Appending Lunar sectors to the existing flat lists would silently create six Homeworld tabs, mix cargo, and let active-planet selling touch the wrong planet.

Preserve the existing ownership boundaries: one controller, one simulation, one repository, one mining save key, Flutter presentation ownership, and Flame world projection. HPA-638 changes the data shape, not the number of state owners.

## Selected architecture

Evolve the mining vertical slice in place:

```text
Flutter MiningScreen
    -> plain MiningController
        -> MiningSimulation
        -> MiningSaveRepository
        -> MiningContentRegistry
    -> MiningSheetView.from(...)
    -> TechnologySheetView.from(...)
    -> StellarMapView.from(...)
    -> TechnologySheet / StellarMapSheet
    -> existing MiningActionSheet / OfflineReturnSheet

Flame MiningGame(active planet definition)
    <- read-only MiningPlanetProgress snapshot
    -> typed sector selection callback
```

`MiningController`, `MiningSimulation`, and `MiningSaveRepository` remain singletons per `MiningScreen` session. Planet switching changes only the active projection.

`MiningGame` receives one active `MiningPlanetProgress` snapshot at construction and `applyState(...)` accepts later active-planet snapshots. Flame does not receive technology, inactive planets, or persistence state. The constructor snapshot is applied from `onLoad()` after sector components exist so a newly replaced game cannot lose state because Flutter refreshed before Flame finished loading.

## Identity and content catalog

### Planet identity

Add one closed identity:

```dart
enum MiningPlanetId {
  homeworld,
  lunarFrontier,
}
```

Player-facing names are **Homeworld** and **Lunar Frontier**.

Add one concrete planet definition:

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

Do not add `MiningPlanetVisualTheme`. Homeworld versus Lunar atmosphere/tint is a closed switch on `MiningPlanetId` inside the mining world. `terrainSeed` remains authored content.

### Sector identity

Continue using sector identity as deposit identity because each sector has exactly one fixed deposit:

```dart
enum MiningSectorId {
  landingBasin,
  carbonRidge,
  graniteCrater,
  frozenBasin,
  titaniumHighlands,
  heliumMare,
}
```

All sector IDs are globally unique. Extend `MiningSectorDefinition` only with:

```dart
final int requiredSurveyingLevel;
```

Homeworld sectors use `requiredSurveyingLevel = 0`. Keep `requiredSector`; do not replace the two explicit fields with a generic requirement object or DSL.

### Registry API: no flat world list

`MiningContentRegistry` becomes a two-planet catalog and must not expose a default `sectors` collection.

Required public shape:

```dart
class MiningContentRegistry {
  final Map<MiningPlanetId, MiningPlanetDefinition> planets;

  factory MiningContentRegistry.stellarMining();

  MiningPlanetDefinition planet(MiningPlanetId id);
  MiningSectorDefinition sector(MiningSectorId id);
  MiningPlanetId planetForSector(MiningSectorId id);
}
```

There is no `allSectors`, no six-sector default list, and no `phaseOne()` factory whose name implies a one-planet model. Any code that wants sectors must first choose a planet.

Iteration contracts are explicit:

- simulation: unlocked planets → `content.planet(id).sectors`;
- active-planet sell: `content.planet(state.activePlanetId).sectors`;
- HUD/tabs/sheet/world: active planet only;
- cross-planet lookup by sector ID: `content.sector(id)` / `planetForSector(id)`.

### Resource identity

Extend the closed enum:

```dart
enum ResourceType {
  gold,
  coal,
  stone,
  waterIce,
  titaniumOre,
  helium3,
}
```

Add exhaustive display mappings and concrete assets for Water Ice, Titanium Ore, and Helium-3. Do not introduce runtime string resource IDs or a generic registry.

## Authored technology model

Add one closed identity:

```dart
enum TechnologyTrack {
  extraction,
  logistics,
  surveying,
}
```

Each track has levels 0 through 5. Level 0 is unpurchased. Cash remains the only spendable currency.

### Shared cash costs

| Target level | Cash cost |
| ---: | ---: |
| 1 | 300 |
| 2 | 700 |
| 3 | 1,500 |
| 4 | 4,000 |
| 5 | 9,000 |

The shared curve is intentional. Track-specific costs are not needed yet.

### Tier-access requirements

| Target level | Required progress |
| ---: | --- |
| 1 | Landing Basin mine built |
| 2 | Carbon Ridge mine built |
| 3 | Granite Crater mine built |
| 4 | Frozen Basin mine built |
| 5 | Titanium Highlands mine built |

Each purchase validates the required mine and cash, increments exactly one track, debits cash, and persists once through the existing serialized mutation chain.

### Extraction

| Level | Production multiplier |
| ---: | ---: |
| 0 | 1.00× |
| 1 | 1.10× |
| 2 | 1.25× |
| 3 | 1.45× |
| 4 | 1.70× |
| 5 | 2.00× |

Extraction applies once to every unlocked mine in foreground, resume, cold launch, and displayed production values.

### Logistics

| Level | Storage multiplier | Offline cap |
| ---: | ---: | ---: |
| 0 | 1.00× | 8h |
| 1 | 1.15× | 10h |
| 2 | 1.30× | 12h |
| 3 | 1.50× | 16h |
| 4 | 1.75× | 20h |
| 5 | 2.00× | 24h |

The storage multiplier applies after the existing mine-level capacity multiplier. One Logistics-derived offline cap applies to the whole accrual operation.

### Surveying

Surveying is an integer authored gate, not a generic modifier.

The Stellar Map is visible after `MiningScreen` initializes even at Surveying 0. Surveying changes eligibility, not visibility.

- Surveying 0: Lunar Frontier is visible with the unmet Surveying 3 requirement.
- Surveying 1 and 2: visible steps toward the Lunar requirement only.
- Surveying 3: satisfies the Lunar unlock technology requirement and Frozen Basin reveal requirement.
- Surveying 4: satisfies Titanium Highlands.
- Surveying 5: satisfies Helium Mare.

## Homeworld mastery and Lunar unlock

Do not persist mastery as a boolean or currency.

Homeworld mastery is derived as:

```text
Landing Basin mine exists
AND Carbon Ridge mine exists
AND Granite Crater mine exists
```

Mine levels do not need to be maxed.

Unlock Lunar Frontier when all are true:

```text
Homeworld mastery
AND Surveying >= 3
AND cash >= 2,500
```

`MiningController.unlockPlanet(MiningPlanetId.lunarFrontier)` accrues first, validates the three requirements, debits 2,500 cash, adds Lunar Frontier to the unlocked set, sets it active, persists once, then publishes the new state. Failure changes nothing.

The Stellar Map shows each unmet condition independently.

## Lunar Frontier content

Lunar Frontier reuses the existing reveal/build/accrue/sell/five-level-upgrade loop.

| Sector | State after planet unlock | Resource | Surveying | Reveal | Build | Base rate/s | Base capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Frozen Basin | locked, eligible | Water Ice | 3 | 0 | 500 | 1.00 | 150 | 6 | 700, 1,400, 2,800, 5,600 |
| Titanium Highlands | locked | Titanium Ore | 4 | 3,000 | 1,200 | 0.80 | 140 | 12 | 1,600, 3,200, 6,400, 12,800 |
| Helium Mare | locked | Helium-3 | 5 | 8,000 | 3,000 | 0.55 | 120 | 30 | 4,000, 8,000, 16,000, 32,000 |

Requirements:

- Frozen Basin: no prior sector, Surveying 3.
- Titanium Highlands: Frozen Basin revealed, Surveying 4.
- Helium Mare: Titanium Highlands revealed, Surveying 5.

Frozen Basin still uses the shared Reveal action even at zero cash cost so first landing keeps the discovery reward moment.

These values are tuning data. Balance changes stay in content tables and tests.

## State model

Replace the flat `MiningSave.sectors` model with global state plus nested planet progress:

```dart
class MiningSave {
  final int cash;
  final DateTime lastAccruedAtUtc;
  final TechnologyLevels technology;
  final Set<MiningPlanetId> unlockedPlanetIds;
  final MiningPlanetId activePlanetId;
  final Map<MiningPlanetId, MiningPlanetProgress> planets;
}

class TechnologyLevels {
  final int extraction;
  final int logistics;
  final int surveying;
}

class MiningPlanetProgress {
  final Map<MiningSectorId, SectorProgress> sectors;
}
```

`SectorProgress` and `MineState` keep their existing shapes.

### Minimal nested-state helpers

Do not make every controller/test reimplement nested copies. Add only these convenience helpers on `MiningSave`:

```dart
MiningPlanetProgress get activePlanetProgress;

SectorProgress progressFor(
  MiningContentRegistry content,
  MiningSectorId sectorId,
);

MiningSave withSector(
  MiningContentRegistry content,
  MiningSectorId sectorId,
  SectorProgress progress,
);
```

`progressFor` resolves the owning planet through `content.planetForSector`. `withSector` copies only the owning planet’s sector map and then the root planet map. Do not add a general state query/update framework.

After HPA-638, production code and tests must stop reading or writing `state.sectors[...]`; that flat field no longer exists.

Initial current-format state:

- cash = 100;
- all technology levels = 0;
- unlocked planets = `{homeworld}`;
- active planet = `homeworld`;
- Homeworld has the existing initial sector state;
- Lunar Frontier progress exists with all three sectors unrevealed and no mines;
- `lastAccruedAtUtc` is initialization UTC.

Both authored planet records always exist. Locked Lunar progress must remain pristine; progressed Lunar state while Lunar is locked is invalid.

## Current save shape and one-off shipped-v1 conversion

Continue using the one key:

```text
horologium.mining.save
```

Do not add `schemaVersion`. The exact root keys already distinguish the shipped v1 document from the current HPA-638 document.

### Current root shape

The current root keys are exactly:

```text
cash
lastAccruedAtUtc
technology
unlockedPlanetIds
activePlanetId
planets
```

Representative valid initial JSON:

```json
{
  "cash": 100,
  "lastAccruedAtUtc": "2026-08-21T20:00:00.000Z",
  "technology": {
    "extraction": 0,
    "logistics": 0,
    "surveying": 0
  },
  "unlockedPlanetIds": ["homeworld"],
  "activePlanetId": "homeworld",
  "planets": {
    "homeworld": {
      "sectors": {
        "landingBasin": {"revealed": true, "mine": null},
        "carbonRidge": {"revealed": false, "mine": null},
        "graniteCrater": {"revealed": false, "mine": null}
      }
    },
    "lunarFrontier": {
      "sectors": {
        "frozenBasin": {"revealed": false, "mine": null},
        "titaniumHighlands": {"revealed": false, "mine": null},
        "heliumMare": {"revealed": false, "mine": null}
      }
    }
  }
}
```

### Current-format invariants

Strictly require:

- root keys exactly match the current contract;
- non-negative integer cash;
- valid UTC timestamp;
- technology keys exactly `extraction`, `logistics`, `surveying`, each integer 0...5;
- unique known `unlockedPlanetIds`, always including Homeworld;
- known `activePlanetId` that is also unlocked;
- `planets` contains exactly Homeworld and Lunar Frontier;
- each planet contains exactly its authored sector IDs;
- existing sector/mine validation remains strict;
- Lunar has no revealed sectors or mines while locked.

Serialize unlocked planet IDs in `MiningPlanetId.values` order for deterministic output. Decoder ordering of known IDs is not semantically significant.

### Decode order and capacity normalization

Decode in this order:

1. root/cash/timestamp;
2. technology;
3. unlocked + active planet IDs;
4. planet/sector/mine progress;
5. cross-field invariants.

Technology must be decoded before mines because load-time stored cargo normalization uses:

```dart
content.effectiveCapacity(
  sectorId,
  mineLevel,
  logisticsLevel,
)
```

This preserves the existing safe capacity clamp while making it Logistics-aware. It must not clamp against base capacity and then apply Logistics afterward.

Unknown keys/IDs, missing data, bad types, malformed timestamps, invalid technology or mine levels, negative cash/cargo, or broken cross-field invariants use the existing clean-reset recovery boundary.

### Shipped v1 recognition

Recognize exactly the shipped root keys:

```text
cash
lastAccruedAtUtc
sectors
```

The sector object must still contain exactly Landing Basin, Carbon Ridge, and Granite Crater and pass the same strict validation as main today.

Convert valid v1 directly to the current shape by:

- preserving cash and UTC timestamp;
- preserving all three Homeworld sector/mine records and cargo;
- technology = 0/0/0;
- unlocked planets = Homeworld only;
- active planet = Homeworld;
- pristine Lunar progress.

Add exactly one `migratedLegacyV1` boolean to `MiningLoadResult`. During controller initialization, accrue the converted state normally and rewrite it once in the current shape when `migratedLegacyV1` is true. Existing `wasMissing` and `recoveredFromInvalidSave` semantics stay intact.

Do not add a migrator registry, ordered migration table, version dispatch framework, generic migrator interface, or old-format writer. Invalid v1 resets; do not partially salvage malformed legacy data.

## Pure content/economy helpers

`MiningContentRegistry` is the authoritative place for concrete formulas and progression checks:

```dart
MiningPlanetDefinition planet(MiningPlanetId id);
MiningSectorDefinition sector(MiningSectorId id);
MiningPlanetId planetForSector(MiningSectorId id);

double rateFor(MiningSectorId id, int mineLevel);
double extractionMultiplier(int extractionLevel);
double effectiveRate(
  MiningSectorId id,
  int mineLevel,
  int extractionLevel,
);

double capacityFor(MiningSectorId id, int mineLevel);
double logisticsStorageMultiplier(int logisticsLevel);
double effectiveCapacity(
  MiningSectorId id,
  int mineLevel,
  int logisticsLevel,
);

Duration offlineCapFor(int logisticsLevel);
int technologyCost(int targetLevel);
MiningSectorId technologyRequirement(int targetLevel);
bool isHomeworldMastered(MiningSave state);
bool canUnlockLunarFrontier(MiningSave state);
```

Do not build a modifier pipeline, generic requirement engine, or generic planet rules system.

## Deterministic multi-planet simulation

Keep one global UTC accrual timestamp.

For each accrual:

```text
rawElapsed = nowUtc - lastAccruedAtUtc
usableElapsed = clamp(rawElapsed, 0, offlineCapFor(logisticsLevel))

for each planetId in state.unlockedPlanetIds:
  planet = content.planet(planetId)
  for each definition in planet.sectors:
    mine = state.progressFor(content, definition.id).mine
    if mine exists:
      rate = effectiveRate(definition.id, mine.level, extractionLevel)
      capacity = effectiveCapacity(definition.id, mine.level, logisticsLevel)
      produced = min(rate * usableElapsedSeconds,
                     capacity - storedAmount)
```

Rules:

- clock rollback produces nothing and never moves the timestamp backward;
- elapsed above the Logistics cap uses only the cap, then advances timestamp to `nowUtc`;
- simulation iterates `unlockedPlanetIds` only, so a valid locked Lunar record remains pristine and contributes no production or summary entry;
- every unlocked planet uses the same elapsed window;
- storage never exceeds effective capacity;
- equal state + equal `nowUtc` produces equal results for foreground, resume, and cold launch;
- switching planets never creates or resets an accrual clock.

## Offline return summary

Evolve the summary to group by planet:

```dart
final Map<MiningPlanetId, Map<ResourceType, double>> productionByPlanet;
final Map<MiningPlanetId, Set<MiningSectorId>> fullSectorsByPlanet;
final Duration elapsedUsed;
final bool wasOfflineCapped;
```

`totalProduced` remains a derived getter.

The Flutter return sheet renders one modal with a short section for each planet that actually produced cargo. The cap message uses the Logistics-derived duration, not a hard-coded eight hours.

## Controller mutations

Keep the existing future-chain serialization. Every committing action accrues first, validates the accrued candidate, persists the complete next state, then publishes it in memory.

### Existing actions

`revealSector`, `buildMine`, and `upgradeMine` continue to accept globally unique `MiningSectorId` values and use `state.progressFor(...)` / `state.withSector(...)` rather than direct nested-map edits.

Reveal validates both `requiredSector` and `requiredSurveyingLevel`.

`sellAllCargo()` becomes active-planet-only:

```text
active = content.planet(candidate.state.activePlanetId)
for definition in active.sectors:
  read/clear only that sector’s cargo
floor total gross value once
credit global cash once
save once
```

### New actions

Add only:

```dart
Future<MiningActionResult> purchaseTechnology(TechnologyTrack track);
Future<MiningActionResult> unlockPlanet(MiningPlanetId id);
Future<MiningActionResult> switchPlanet(MiningPlanetId id);
```

`purchaseTechnology`:

1. accrue all unlocked planets;
2. fail at level 5;
3. derive target level;
4. validate the concrete required mine;
5. validate cash;
6. debit cash + increment exactly one track;
7. save once and publish.

`unlockPlanet`:

1. accrue;
2. fail if already unlocked;
3. validate Homeworld mastery, Surveying 3, and 2,500 cash;
4. debit cash + add Lunar + set Lunar active;
5. save once and publish.

`switchPlanet`:

1. accrue all unlocked planets;
2. fail if target is locked/unknown;
3. set active planet;
4. save once and publish.

No widget or Flame component mutates technology, planet unlocks, active planet, or cash.

## Pure presentation models

The controller remains authoritative for mutations, but widgets must not present stale or contradictory eligibility.

### MiningSheetView

Extend `MiningSheetView.from(...)` so it derives only the active planet:

- Sell Cargo iterates `content.planet(state.activePlanetId).sectors`.
- sector lookup uses `state.progressFor(content, sectorId)`.
- Reveal considers `requiredSector`, `requiredSurveyingLevel`, cash, and busy state.
- displayed production uses `content.effectiveRate(...)` with current Extraction.
- displayed capacity uses `content.effectiveCapacity(...)` with current Logistics.

Frozen Basin must be visibly disabled at Surveying 0–2 even though reveal cost is zero.

### TechnologySheetView

Add a small pure model in `lib/mining/mining_progression_views.dart` that derives three concrete track cards from state/content. Each card contains:

- track;
- current level/effect text;
- next level/effect text when below 5;
- next cash cost;
- unmet mine requirement text when locked;
- `purchaseEnabled`;
- disabled reason.

The Flutter `TechnologySheet` renders this model and invokes the controller only when the model enables the action.

### StellarMapView

In the same pure file, derive exactly two planet cards:

- Homeworld: current/available, built-mine mastery count 0...3, travel affordance when inactive.
- Lunar Frontier: current/locked/unlocked, exact unmet mastery/Surveying/cash conditions, unlock or travel affordance.

`StellarMapSheet` renders the derived model. It does not recompute unlock eligibility inside `build()`.

These are concrete view models, not a generic UI-state framework.

## Flutter presentation

`MiningScreen` remains the one Flutter owner. Do not add routes or app-wide state management.

Top layout:

```text
MiningStatusBar
active-planet sector tabs
[ TECHNOLOGY ] [ STELLAR MAP ] [ SETTINGS ]
```

Use 48+ logical-pixel touch targets and verify non-overlap at 360×640 and 430×932.

HUD values are active-planet values:

- active planet name;
- cash;
- revealed sectors / authored sectors for the active planet;
- active-planet cargo value.

The Stellar Map remains visible at Surveying 0.

## MiningGame replacement boundary

`MiningGame` is currently created once as a `late final` field and owns a final sector content set. HPA-638 must make game replacement an explicit tested boundary rather than adding dynamic world teardown/repopulation.

Required shape:

```dart
late MiningGame _game;

MiningGame _createGame(MiningPlanetId planetId) {
  final game = MiningGame(
    planet: _content.planet(planetId),
    initialProgress: _controller.state.planets[planetId]!,
  );
  game.onSelectionChanged = _handleSelectionChanged;
  game.reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return game;
}
```

After a successful `switchPlanet` or Lunar unlock:

1. controller has already accrued/persisted the new state;
2. reset selected sector to Sell (`null`);
3. replace `_game` with `_createGame(newActivePlanetId)`;
4. rebuild `GameWidget` with `ValueKey(newActivePlanetId)`;
5. `MiningGame.onLoad()` creates the new planet’s terrain/sectors and applies its constructor `initialProgress` after those components exist;
6. later presentation refreshes call `applyState(state.activePlanetProgress)` on the new loaded projection;
7. all later rewards/selections target the new game instance only.

The old `GameWidget` is unmounted through Flutter/Flame lifecycle when the key changes. Do not add a speculative second game-disposal subsystem; tests must prove the old game is no longer the mounted projection and cannot receive later selection/reward callbacks.

The controller, repository, `AudioManager`, lifecycle observer, and refresh timer are reused across the replacement. Do not preserve per-planet camera or sector selection in HPA-638.

For deterministic widget tests, `MiningScreen` may accept one optional `MiningGame Function(MiningPlanetDefinition, MiningPlanetProgress)` factory seam, consistent with its existing injected repository/clock/audio seams. Do not add a general dependency-injection container.

## Lunar visual identity

Use `MiningPlanetId` directly:

- Homeworld retains terrain seed 631 and existing atmosphere.
- Lunar Frontier uses a distinct deterministic seed.
- `MiningGame` switches on `planet.id` for a cooler/desaturated mining-world tint/atmosphere.
- add concrete Water Ice, Titanium Ore, and Helium-3 resource/facility assets.
- reuse the existing level 1/3/5 structural mine-tier language.

Prefer tint/atmosphere at the mining-world layer. Do not route Lunar through `BiomeRegistry`/`BiomeType` or add generic theme plumbing to shared terrain code unless a concrete rendering blocker proves necessary.

## Selling semantics

Cash is global. Cargo is planet-local.

`Sell All Cargo` sells only the active planet. Do not add remote selling, shipping, cargo transfer, or a global all-planets sale button.

## Error handling

Preserve existing boundaries:

- invalid/incompatible save → clean reset + existing non-blocking recovery message;
- controller validation failure → user-readable failure, no mutation;
- explicit SharedPreferences write failure → action fails and prior in-memory state stays authoritative;
- lifecycle checkpoint failure → best-effort debug logging;
- asset load failure → existing visual fallback;
- failed switch/unlock → keep current planet/game mounted.

Do not add retry queues, backup rotation, transaction logs, or crash-recovery machinery.

## Testing strategy

Extend existing suites; do not add a new harness.

### Content/state

Prove:

- exact planet/sector/resource identity;
- registry has no flat world iteration API;
- `planet`, `sector`, `planetForSector` resolve correctly;
- technology tables/effects/gates;
- nested `progressFor` / `withSector` update only the owning planet;
- Homeworld mastery and Lunar unlock eligibility.

### Persistence

Prove:

- strict current-format round-trip without `schemaVersion`;
- exact shipped-v1 conversion preserving cash/timestamp/Homeworld mines/cargo;
- migrated initialization rewrites current format once;
- invalid v1 resets instead of partially migrating;
- unknown/missing current keys/IDs reset;
- locked Lunar progress is rejected;
- technology is decoded before planet cargo normalization;
- cargo above Logistics-aware effective capacity clamps safely.

### Simulation

Prove:

- Extraction applies once to all unlocked planets;
- Logistics capacity/offline cap applies once;
- two planets accrue over one elapsed window;
- a valid locked Lunar record remains pristine and absent from the production summary;
- independent storage clamps;
- rollback/cap determinism;
- grouped summary correctness.

### Controller

Prove:

- technology purchase success/fail/max;
- atomic cash + level mutation;
- Lunar unlock success/failure and atomic cash + unlock + active planet;
- active-planet-only selling;
- switch accrues before active planet changes and persists once;
- future-chain overlap protection across technology/switch/sell/reveal/build/upgrade.

### Pure view models

Prove:

- active-planet sell totals only active cargo;
- Frozen Basin reveal disabled below Surveying 3;
- Extraction/Logistics values shown by `MiningSheetView` match simulation helpers;
- Technology view exact current/next/cost/requirement state;
- Stellar Map exact unmet requirements and action states.

### Widget/world

Prove:

- Technology and Stellar Map sheets render derived models and invoke controller actions;
- Stellar Map visible at Surveying 0;
- 360×640 and 430×932 controls remain reachable/non-overlapping;
- reduced-motion Lunar unlock confirmation;
- Homeworld and Lunar `MiningGame` instances mount only their own sectors;
- Lunar seed/tint differs from Homeworld;
- switch/unlock creates a new `MiningGame` + `ValueKey` while controller/audio/timer remain reused;
- constructor progress is applied after `onLoad()` component creation;
- old game is not the mounted target for later selection/reward callbacks;
- all Lunar sectors reuse existing reveal/build/upgrade presentation.

### Journey coverage

Keep two focused journeys:

1. **Progression journey** — shipped v1 save → direct conversion/rewrite → buy technology → Homeworld mastery → Surveying 3 → unlock Lunar → reveal Frozen Basin → build Water Ice → switch Homeworld → both planet states preserved.
2. **Two-planet idle journey** — mines on both planets → cold elapsed load → one grouped summary → sell active planet → switch → sell second planet → global cash + planet-local cargo correct.

Do not add a new E2E driver or screenshot harness.

## Implementation order

Production work follows this TDD spine:

1. content catalog + nested state helpers;
2. current save + shipped-v1 conversion, including Logistics-aware decode order;
3. multi-planet simulation;
4. serialized controller mutations;
5. pure mining/technology/Stellar Map view models;
6. Flutter Technology/Stellar Map/HUD chrome;
7. `MiningGame` replacement boundary + Lunar visuals/assets;
8. the two integration journeys + docs + full verification.

Do not start with UI or Flame changes before the data and mutation contracts are green.

## Verification gates

Before leaving draft:

```sh
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Also run one representative portrait smoke/playtest covering technology purchase, Stellar Map requirements, Lunar unlock, Lunar visual distinction, first lunar mine, planet switching, and two-planet return.

Do not add wall-clock performance assertions or a new performance harness.

## Documentation updates

When implementation is complete:

- update `CLAUDE.md` for the current exact save shape, direct shipped-v1 conversion, technology effects, nested planet ownership, active-planet selling, and game replacement rule;
- update README’s core loop to mention technology and planet expansion succinctly;
- keep `AGENTS.md` as the existing symlink to `CLAUDE.md`;
- do not revive retired Speckit/Copilot/Windsurf documentation.

## Scope check

This remains one coherent HPA-638 PR:

- one controller;
- one simulation;
- one repository/save key;
- one direct shipped-v1 conversion;
- one two-planet content catalog with no flat world list;
- three closed technology tracks;
- three new Lunar sectors/resources;
- two small pure progression view models + two modal widgets;
- one replaceable active-planet `MiningGame`;
- existing unit/widget/world/journey test structure.

There is no need for another architecture layer before HPA-641 proves one is needed.
