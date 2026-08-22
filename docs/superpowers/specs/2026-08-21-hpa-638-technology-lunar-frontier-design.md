# HPA-638 Technology and Lunar Frontier Design

## Status

Implementation design for Linear HPA-638, **Add simple technology and launch the Lunar Frontier**.

HPA-636 is complete and PR #15 has merged the mining-only cutover, so the HPA-638 start gate is satisfied. This task uses one branch and one PR for planning and implementation. Do not split technology, persistence, Stellar Map, Lunar Frontier content, multi-planet accrual, presentation, or tests into separate implementation PRs unless explicitly approved later.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the Horologium mining roadmap.
2. Linear HPA-638, the technology + Lunar Frontier acceptance contract.
3. This task-specific design.
4. The merged HPA-631 and HPA-636 designs as implementation history.
5. Older city-building documentation only as historical context.

HPA-638 creates the first real mining-save compatibility obligation. The HPA-631 rule to avoid migration machinery applied while no mining save had shipped. The current first-planet mining save has now shipped and HPA-638 explicitly requires preserving it, so this design adds one narrow legacy-v1 decoder and v2 rewrite without introducing a migration framework.

## Goal

Ship one complete long-term progression step on top of the validated mining-only product:

> Mine and sell on the Homeworld → buy simple permanent technology with cash → reach Surveying 3 → unlock the Stellar Map destination → land on Lunar Frontier → reveal and mine Water Ice → progress through Titanium Ore and Helium-3 → leave → return to production from both planets.

The task must prove that permanent technology and a second planet can extend the current idle loop without turning Horologium back into a simulation-heavy game.

## Non-goals

Do not add:

- a third planet;
- technology points, research time, laboratories, staff, claims, branching trees, respec, or a separate technology currency;
- quests, contracts, shipping, manual resource transfer, planet-specific currencies, resource buying, dynamic markets, or processing;
- a generic modifier engine, requirement DSL, planet plugin registry, navigation framework, state-management framework, command bus, event bus, or package split;
- procedural planet generation or a new asset-generation pipeline;
- per-resource controllers or resource-specific economy branches;
- cloud save, accounts, server-authoritative time, or retention systems.

HPA-641 is the point where another planet will show whether any further content abstraction is justified. HPA-638 should implement only the seams needed by the concrete Homeworld and Lunar Frontier content.

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

Current important contracts:

- `MiningContentRegistry` owns three first-planet sector definitions, five-level mine multipliers, a fixed eight-hour offline cap, and world coordinates.
- `MiningSave` owns global cash, one global UTC accrual timestamp, and a flat map of the three first-planet sectors.
- `MiningSimulation` accrues all active mines from elapsed UTC time and clamps them to storage.
- `MiningSaveRepository` strictly decodes the complete first-planet JSON shape stored at `horologium.mining.save`.
- `MiningController` is the single serialized mutation owner for reveal, build, upgrade, sell, checkpoint, and resume.
- `MiningScreen` owns Flutter presentation, lifecycle, one-second repaint refresh, modal sheets, audio, reduced motion, and the `MiningGame` bridge.
- `MiningGame` receives read-only state snapshots and owns terrain, sectors, camera, selection, and reward effects.
- `ResourceType` currently contains only `gold`, `coal`, and `stone`.

Preserve these ownership boundaries. HPA-638 extends them; it does not add a second state owner or a parallel economy path.

## Selected architecture

Evolve the existing mining vertical slice in place:

```text
Flutter MiningScreen
    -> plain MiningController
        -> MiningSimulation
        -> MiningSaveRepository
        -> MiningContentRegistry
    -> TechnologySheet
    -> StellarMapSheet
    -> existing MiningActionSheet / OfflineReturnSheet

Flame MiningGame(active planet definition)
    <- read-only active-planet state snapshot
    -> typed sector selection callback
```

`MiningController`, `MiningSimulation`, and `MiningSaveRepository` remain singletons per `MiningScreen` session. Planet switching changes which planet is projected by Flutter/Flame; it does not create a second controller, repository, save, or simulation.

## Identity and content model

### Planet identity

Add one closed planet identity:

```dart
enum MiningPlanetId {
  homeworld,
  lunarFrontier,
}
```

The player-facing display names are **Homeworld** and **Lunar Frontier**.

Add a concrete planet definition that owns its sector list and presentation identity:

```dart
class MiningPlanetDefinition {
  const MiningPlanetDefinition({
    required this.id,
    required this.name,
    required this.sectors,
    required this.terrainSeed,
    required this.visualTheme,
  });

  final MiningPlanetId id;
  final String name;
  final List<MiningSectorDefinition> sectors;
  final int terrainSeed;
  final MiningPlanetVisualTheme visualTheme;
}

enum MiningPlanetVisualTheme { homeworld, lunar }
```

This is deliberately a closed two-value presentation seam, not a generic biome or theme framework. `MiningGame` may switch on this enum for the small number of concrete terrain/atmosphere differences required by HPA-638.

### Sector identity

Keep one deposit per sector and continue using the sector as the stable deposit identity. Extend the closed enum:

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

All sector IDs remain globally unique, so controller actions do not need a second deposit ID or `(planetId, sectorId)` composite key. `MiningContentRegistry` can resolve the owning planet for any sector.

Extend `MiningSectorDefinition` only with the concrete progression information HPA-638 needs:

```dart
final int requiredSurveyingLevel;
```

Keep the existing `requiredSector` field. Do not replace these two simple fields with a generic requirement object, expression tree, predicate registry, or DSL.

### Resource identity

Extend the existing closed enum:

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

Add exhaustive resource display mappings and concrete assets for the three lunar resources. Do not introduce string resource IDs or a generic runtime resource registry.

## Authored technology model

Add one closed technology identity:

```dart
enum TechnologyTrack {
  extraction,
  logistics,
  surveying,
}
```

Each track has levels **0 through 5**. Level 0 means unpurchased. Cash is the only spendable currency.

### Shared cash costs

Use one authored cost curve for the next level of any track:

| Target level | Cash cost |
| ---: | ---: |
| 1 | 300 |
| 2 | 700 |
| 3 | 1,500 |
| 4 | 4,000 |
| 5 | 9,000 |

Keeping the initial curve shared avoids fake complexity while still allowing track-specific effects. Balance values remain content data and may be tuned during HPA-638 if playtesting shows a clear pacing problem.

### Tier-access requirements

Technology levels are unlocked by concrete mine progress, not another currency:

| Target level | Required progress |
| ---: | --- |
| 1 | Landing Basin mine built |
| 2 | Carbon Ridge mine built |
| 3 | Granite Crater mine built |
| 4 | Frozen Basin mine built |
| 5 | Titanium Highlands mine built |

The requirement applies independently to each track. A purchase must validate the required mine and cash, then increment exactly one track and debit cash in the same serialized controller mutation.

### Extraction effects

Extraction multiplies production globally:

| Level | Production multiplier |
| ---: | ---: |
| 0 | 1.00× |
| 1 | 1.10× |
| 2 | 1.25× |
| 3 | 1.45× |
| 4 | 1.70× |
| 5 | 2.00× |

The multiplier applies to Homeworld and Lunar Frontier, foreground refresh, resume, cold launch, and displayed production values through the same pure content helper.

### Logistics effects

Logistics increases global mine storage and the global offline-duration cap:

| Level | Storage multiplier | Offline cap |
| ---: | ---: | ---: |
| 0 | 1.00× | 8h |
| 1 | 1.15× | 10h |
| 2 | 1.30× | 12h |
| 3 | 1.50× | 16h |
| 4 | 1.75× | 20h |
| 5 | 2.00× | 24h |

The storage multiplier is applied after the existing mine-level capacity multiplier. The offline cap is selected from the current Logistics level once for the accrual operation and applies equally to all unlocked planets.

### Surveying effects

Surveying has no generic numeric modifier. It is an integer progression requirement consumed directly by authored unlock checks:

- Surveying 1: Stellar Map becomes meaningfully actionable and shows the Lunar Frontier requirement.
- Surveying 3: satisfies the technology portion of the Lunar Frontier planet unlock.
- Surveying 4: satisfies the Surveying requirement for Titanium Highlands.
- Surveying 5: satisfies the Surveying requirement for Helium Mare.

Surveying 2 intentionally has no separate subsystem reward; it is a visible step toward the Surveying 3 planet-unlock threshold.

## Homeworld mastery and Lunar Frontier unlock

Do not persist a separate mastery boolean or mastery currency.

Homeworld mastery is derived as:

```text
Landing Basin mine exists
AND Carbon Ridge mine exists
AND Granite Crater mine exists
```

Mine levels do not need to be maxed.

Unlock Lunar Frontier when all of these are true:

```text
Homeworld mastery
AND Surveying >= 3
AND cash >= 2,500
```

`MiningController.unlockPlanet(MiningPlanetId.lunarFrontier)` must accrue first, validate all requirements, debit 2,500 cash, add the planet to the unlocked set, set Lunar Frontier active, and persist once. A failure changes nothing.

The Stellar Map must show each unmet condition explicitly rather than collapsing them into a generic “locked” state.

## Lunar Frontier authored content

Lunar Frontier reuses the same reveal, build, accrue, sell, and five-level upgrade mechanics. The first-pass balance is:

| Sector | Initial state after planet unlock | Resource | Surveying | Reveal | Build | Base rate/s | Base capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Frozen Basin | locked, eligible | Water Ice | 3 | 0 | 500 | 1.00 | 150 | 6 | 700, 1,400, 2,800, 5,600 |
| Titanium Highlands | locked | Titanium Ore | 4 | 3,000 | 1,200 | 0.80 | 140 | 12 | 1,600, 3,200, 6,400, 12,800 |
| Helium Mare | locked | Helium-3 | 5 | 8,000 | 3,000 | 0.55 | 120 | 30 | 4,000, 8,000, 16,000, 32,000 |

Progression requirements:

- Frozen Basin has no previous-sector requirement and requires Surveying 3.
- Titanium Highlands requires Frozen Basin revealed and Surveying 4.
- Helium Mare requires Titanium Highlands revealed and Surveying 5.

Frozen Basin still goes through the shared Reveal action even though its reveal cost is zero, preserving the discovery reward moment on first landing.

The values above are tuning data, not architecture. They may change within this PR after a focused progression playtest, but changes must remain in content data and tests rather than adding dynamic balance logic.

## State model

Evolve the flat first-planet save into one global state plus per-planet progress:

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

Initial v2 state:

- cash = 100;
- all technology levels = 0;
- unlocked planets = `{homeworld}`;
- active planet = `homeworld`;
- Homeworld sectors exactly preserve the existing initial state;
- Lunar Frontier progress exists in the save with all three sectors unrevealed and no mines;
- `lastAccruedAtUtc` is initialization UTC.

Keeping both authored planet records present makes the v2 document strict and simple. Locked planet progress must remain pristine; a save containing progressed Lunar state while Lunar Frontier is not unlocked is invalid.

## Save v2 and one-off v1 migration

Continue using the existing single key:

```text
horologium.mining.save
```

The v2 root shape is exactly:

```json
{
  "schemaVersion": 2,
  "cash": 100,
  "lastAccruedAtUtc": "...Z",
  "technology": {
    "extraction": 0,
    "logistics": 0,
    "surveying": 0
  },
  "unlockedPlanetIds": ["homeworld"],
  "activePlanetId": "homeworld",
  "planets": {
    "homeworld": { "sectors": { "...": "..." } },
    "lunarFrontier": { "sectors": { "...": "..." } }
  }
}
```

### Valid v2 invariants

Strictly require:

- root keys exactly match the v2 contract;
- `schemaVersion == 2`;
- non-negative integer cash;
- a valid UTC timestamp;
- all three technology keys exactly once, each integer 0...5;
- `unlockedPlanetIds` contains unique known planet IDs and always includes Homeworld;
- `activePlanetId` is known and unlocked;
- `planets` contains exactly Homeworld and Lunar Frontier;
- each planet contains exactly its authored sector IDs;
- existing sector/mine validation remains strict;
- Lunar Frontier has no revealed sectors or mines while the planet is locked;
- stored cargo is normalized down to the current effective capacity using the decoded Logistics level, preserving the existing safe capacity-clamp behavior.

Unknown keys, unknown IDs, missing data, bad types, malformed timestamps, invalid technology levels, invalid mine levels/cargo, negative cash, or broken cross-field invariants use the existing clean-reset recovery boundary.

### Legacy v1 recognition

Recognize exactly the shipped first-planet shape:

```text
cash
lastAccruedAtUtc
sectors
  landingBasin
  carbonRidge
  graniteCrater
```

Decode it with the same strict rules already used on main. Convert it directly to v2 by:

- preserving cash;
- preserving the UTC accrual timestamp;
- preserving all three Homeworld sector/mine records and cargo;
- setting all technology levels to 0;
- unlocking only Homeworld;
- setting Homeworld active;
- creating pristine Lunar Frontier progress.

Expose one `migratedLegacyV1`/`needsRewrite` signal in `MiningLoadResult`. During controller initialization, accrue the converted state normally and rewrite it once as v2. Do not add a migration registry, ordered migration list, generic migrator interface, or old-version writer.

Invalid v1 data still resets cleanly; do not partially salvage malformed legacy mining documents.

## Deterministic multi-planet simulation

Keep one global accrual timestamp because all active mines advance on the same elapsed UTC window.

For each accrual:

```text
rawElapsed = nowUtc - lastAccruedAtUtc
usableElapsed = clamp(rawElapsed, 0, offlineCapFor(logisticsLevel))

for each unlocked planet:
  for each built mine:
    rate = baseRate
           × mineLevelRateMultiplier
           × extractionMultiplier

    capacity = baseCapacity
               × mineLevelCapacityMultiplier
               × logisticsStorageMultiplier

    produced = min(rate × usableElapsedSeconds,
                   capacity - storedAmount)
```

Rules remain:

- clock rollback produces nothing and never moves the timestamp backward;
- elapsed time above the Logistics cap uses only the cap, then advances the save timestamp to `nowUtc` so excess time cannot be reclaimed;
- locked planets never accrue;
- all unlocked planets use exactly the same elapsed window;
- storage never exceeds the effective capacity;
- equal state + equal `nowUtc` produces equal results in foreground, resume, and cold launch;
- switching planets does not create or reset an accrual clock.

## Offline return summary

Evolve `OfflineProductionSummary` to group production and full-storage notices by planet:

```dart
final Map<MiningPlanetId, Map<ResourceType, double>> productionByPlanet;
final Map<MiningPlanetId, Set<MiningSectorId>> fullSectorsByPlanet;
final Duration elapsedUsed;
final bool wasOfflineCapped;
```

Provide `totalProduced` as a derived getter only.

The Flutter return sheet renders one concise sheet, with a short section for each planet that actually produced cargo. Do not show separate modal sheets per planet. The cap message uses the actual Logistics-derived duration rather than hard-coded “8 hours”.

## Controller mutations

Keep the existing future-chain serialization. Every committing operation accrues first, validates against the resulting candidate state, saves the complete next state, then publishes it in memory.

### Existing actions

`revealSector`, `buildMine`, and `upgradeMine` continue to accept globally unique `MiningSectorId` values and operate on the owning planet record. Reveal additionally validates `requiredSurveyingLevel`.

`sellAllCargo()` changes semantics to **sell only the active planet**. It still values all cargo on that planet, floors gross value once, clears all sold mines atomically, credits global cash, and persists once.

### New actions

Add only these progression mutations:

```dart
Future<MiningActionResult> purchaseTechnology(TechnologyTrack track)
Future<MiningActionResult> unlockPlanet(MiningPlanetId id)
Future<MiningActionResult> switchPlanet(MiningPlanetId id)
```

`purchaseTechnology`:

1. accrue all unlocked planets;
2. fail if track is already level 5;
3. derive the target level;
4. fail if the concrete mine-progress requirement is unmet;
5. fail if cash is insufficient;
6. debit cash and increment exactly one level;
7. save once and publish.

`unlockPlanet`:

1. accrue;
2. fail if already unlocked;
3. for Lunar Frontier, validate Homeworld mastery, Surveying 3, and 2,500 cash;
4. debit cash, add Lunar Frontier to unlocked IDs, set it active;
5. save once and publish.

`switchPlanet`:

1. accrue all unlocked planets;
2. fail if target is locked/unknown;
3. set active planet;
4. save once and publish.

No other class may mutate technology, active planet, unlocked planets, or cash directly.

## Pure economy helpers

Keep authoritative formulas out of widgets and Flame components. `MiningContentRegistry` owns pure helpers for:

- base + mine-level rate;
- Extraction multiplier;
- effective rate;
- base + mine-level capacity;
- Logistics storage multiplier;
- effective capacity;
- Logistics offline cap;
- technology cost for a target level;
- technology tier-access requirement;
- owning planet for a sector;
- Homeworld mastery;
- Lunar Frontier unlock eligibility.

These are concrete helpers around the authored content. Do not build a generic “modifier pipeline” or generalized requirement engine.

## Flutter presentation

### MiningScreen remains the owner

Do not add app routes or a navigation/state-management framework. `MiningScreen` continues to own the one controller and presents all progression surfaces.

The top layout becomes:

```text
MiningStatusBar
sector tabs for active planet
[ TECHNOLOGY ] [ STELLAR MAP ] [ SETTINGS ]
```

Use compact 48+ logical-pixel touch targets and verify that the row does not overlap the status bar, sector tabs, or bottom action sheet at 360×640 and 430×932.

The status bar should identify the active planet while preserving cash, active-planet sector progress, and active-planet cargo value. “Sell All Cargo” continues to refer only to the active planet.

### Technology sheet

Add one modal bottom sheet with three cards: Extraction, Logistics, Surveying.

Each card shows:

- current level;
- exact current effect;
- exact next-level effect when below level 5;
- cash cost;
- concrete unmet progress requirement, if any;
- disabled reason when unaffordable/locked/maxed;
- one purchase button.

Examples of effect copy:

- `Extraction Lv 2 — production ×1.25`
- `Next: ×1.45 — 1,500 cash`
- `Requires Granite Crater mine`
- `Logistics Lv 3 — storage ×1.50 • offline 16h`
- `Surveying Lv 2 — 1 level to Lunar requirement`

The widget renders values derived from the domain/content helpers; it does not implement purchase rules itself.

### Stellar Map sheet

Add one portrait-friendly modal bottom sheet with exactly two planet cards.

Homeworld card shows:

- current/available state;
- derived mastery progress (built mines out of three);
- button to switch back when another planet is active.

Lunar Frontier card shows:

- locked/unlocked/current state;
- the exact unmet conditions: Homeworld mastery, Surveying 3, 2,500 cash;
- one unlock button when eligible;
- one travel button when unlocked but not active.

A successful unlock triggers one clear visual/haptic reward. Reduced motion skips motion but keeps the settled confirmation and state change obvious.

## Flame world and planet switching

`MiningGame` is currently constructed around a final sector content set and creates its terrain/sectors in `onLoad()`. Do not complicate it with dynamic teardown/repopulation.

When the active planet changes:

1. controller switch/unlock completes and persists;
2. `MiningScreen` replaces its `MiningGame` instance using the new `MiningPlanetDefinition`;
3. the new game receives the active planet state snapshot;
4. selection resets to the Sell tab (`null`) unless a later concrete UX issue justifies preserving per-planet selection.

Use a `ValueKey(activePlanetId)` or equivalent widget identity so Flutter mounts the replacement `GameWidget` cleanly.

The controller, repository, audio manager, lifecycle observer, and refresh timer stay in place.

## Lunar visual identity

Lunar Frontier must look materially different without adding a general biome system.

Use the concrete `MiningPlanetVisualTheme.lunar` switch to provide:

- a distinct deterministic terrain seed;
- cooler/desaturated terrain atmosphere/tint versus Homeworld;
- three concrete lunar resource/facility assets;
- distinct resource silhouettes/icons for Water Ice, Titanium Ore, and Helium-3;
- the existing level 1/3/5 structural mine-tier language, with the new lunar facility art as its base identity.

Keep visual fallback behavior so missing optional effects do not break gameplay. Do not build procedural theme configuration or generalized art packs before HPA-641 proves the need.

## Selling semantics

Cash remains global. Cargo remains planet-local.

`Sell All Cargo` sells the active planet only. This keeps the player’s mental model simple:

> travel to a planet → see its stored cargo → sell that planet → global cash increases.

Do not add remote selling, shipping, cargo transfer, or a global all-planets sale button in HPA-638. If playtesting clearly shows active-planet selling is confusing, adjust within this issue with the smallest clearer behavior; do not introduce logistics simulation.

## Error handling

Preserve the existing boundaries:

- invalid or incompatible save: clean reset + existing non-blocking recovery message;
- failed controller validation: return a user-readable failure without mutating state;
- SharedPreferences write failure during explicit action: action fails and the previous in-memory state remains authoritative;
- lifecycle checkpoint failure: best-effort debug logging as today;
- asset load failure: existing visual fallback behavior;
- planet switch/unlock failure: keep the current planet/game mounted.

Do not add retry queues, backup rotation, transaction logs, or crash recovery machinery for this hobby-project slice.

## Testing strategy

Extend the existing mining suites rather than adding a new harness.

### Content/state tests

Prove:

- exact planet/sector/resource identity;
- technology costs, access gates, and level effects;
- Homeworld mastery;
- Lunar unlock requirement;
- each Lunar sector’s authored requirement and economy values.

### Persistence tests

Prove:

- strict v2 round-trip;
- exact valid shipped-v1 migration preserving cash, timestamp, sectors, levels, and cargo;
- migrated load rewrites v2 through controller initialization;
- invalid v1 still resets rather than partially migrating;
- unknown/missing v2 keys and IDs reset;
- invalid cross-field states reset;
- locked Lunar progress is rejected;
- cargo above effective Logistics capacity clamps safely.

### Simulation tests

Prove:

- Extraction affects all planets exactly once;
- Logistics affects capacity and offline cap exactly once;
- two unlocked planets accrue over the same elapsed window;
- locked Lunar Frontier does not accrue;
- storage clamps independently per mine;
- clock rollback and cap behavior remain deterministic;
- grouped offline summary is accurate.

### Controller tests

Prove:

- technology purchase success/failure/level-5 behavior;
- atomic cash + level change;
- Lunar unlock success/failure and atomic cash + unlock + active-planet change;
- active-planet-only selling;
- switch accrues before changing active planet and persists once;
- existing future-chain overlap protections continue to prevent stale overwrite across technology, switch, sell, reveal, build, and upgrade mutations.

### Widget/world tests

Prove:

- Technology sheet exact current/next/cost/requirement states;
- Stellar Map exact unmet requirements, unlock, and travel behavior;
- 360×640 and 430×932 top controls remain reachable and non-overlapping;
- reduced-motion unlock confirmation;
- Homeworld and Lunar games mount the correct sector set;
- Lunar visual theme/terrain seed differs from Homeworld;
- active planet switch recreates the game without recreating controller state;
- all three Lunar sectors reuse the existing selection/reveal/build/upgrade presentation path.

### Journey coverage

Keep targeted end-to-end coverage focused on two product journeys:

1. **Progression journey** — load a shipped v1 first-planet save → migrate → purchase Surveying/technology → satisfy Homeworld mastery → unlock Lunar Frontier → reveal Frozen Basin → build the Water Ice mine → switch back to Homeworld without losing either planet.
2. **Two-planet idle journey** — persisted mines on both planets → cold elapsed-time load → one grouped return summary → sell one planet → switch → sell the other → global cash and planet-local cargo remain correct.

Do not add a new E2E driver or screenshot harness.

## Verification gates

Before leaving draft, run the narrowest affected suites during implementation and then the repository gates:

```sh
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Also perform one representative portrait smoke/playtest covering:

- buying technology;
- understanding the Stellar Map requirement;
- unlocking Lunar Frontier;
- visual distinction of the Lunar world;
- building the first lunar mine;
- switching planets;
- returning to production from both planets.

Do not add wall-clock performance assertions or a new performance harness. Use the existing build/profile workflow if a concrete regression appears.

## Documentation updates

When implementation is complete:

- update `CLAUDE.md` to describe the v2 save, technology effects, multi-planet ownership, active-planet selling, and planet-switch projection rule;
- update README’s core loop to mention technology and planet expansion succinctly;
- keep `AGENTS.md` as the existing symlink to `CLAUDE.md`;
- do not revive retired Speckit/Copilot/Windsurf documentation.

## Scope check

This design remains one coherent HPA-638 implementation PR:

- one existing controller;
- one existing simulation;
- one existing save key/repository;
- one concrete v1→v2 conversion;
- three closed technology tracks;
- two closed planet identities;
- three new lunar sectors/resources;
- two small Flutter modal surfaces;
- active planet projected through one replaceable `MiningGame`;
- existing unit/widget/world/journey test structure.

There is no need for a new architecture layer before HPA-641 provides evidence that another planet actually requires one.
