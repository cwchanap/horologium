# HPA-641 Mars Frontier Content Pack Design

## Status

Implementation design for Linear HPA-641, **Ship one additional planet content pack**.

HPA-638 is complete and PR #16 merged the two-planet technology/Stellar Map architecture. HPA-641 uses one branch and one PR for planning, implementation, and verification. This PR remains planning-only until implementation starts on the same draft PR.

The Linear content brief is frozen before implementation. Mars Frontier is selected because it is visually distinct from Homeworld and Lunar Frontier and can prove the existing catalog-driven architecture without introducing another game system.

## Review disposition

The planning review is accepted. The approved shape is smaller than the first draft:

1. **No HPA-638 six-sector save converter.** The repository explicitly treats incompatible pre-release saves as clean-reset input until a shipped compatibility obligation exists. Adding the three Mars sector enum values makes the old six-sector document incompatible by design.
2. **Stellar Map uses separate own and prerequisite mastery counts.** Locked Mars must show Lunar mastery progress while unlocked Mars must still show Mars `Mines x/y` progress.
3. **`MiningSave.initial()` derives sector records from `MiningSectorId.values`.** Only Landing Basin is initially revealed; every other authored sector starts pristine.
4. **Task 1 owns full mechanical retarget.** Growing `MiningSectorId` and `ResourceType` must leave the whole repository green in the same task, including persisted fixtures, exact enum pins, integration helpers, and `CLAUDE.md`.
5. **The three Mars facility sprite paths are authored values.** They are frozen in Linear and below; implementation does not choose sprites opportunistically.
6. **Risks are explicit and narrow.** The real sharp edges are Stellar Map unlock-key collisions, own-vs-prerequisite mastery count semantics, and stale six-sector persisted fixtures.

Everything else from the first design remains intentionally lean: one controller/simulation/repository/save key/active world, flat globally unique sector state, four direct unlock/reward fields on the planet definition, derived mastery, list-based Stellar Map cards, optional discovery/facility copy, and characterization rather than simulation/world rewrites.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the Horologium mining roadmap.
2. Linear HPA-641 and its frozen content-brief comment.
3. This task-specific design.
4. `CLAUDE.md`, the repository architecture/persistence contract.
5. HPA-638 design/implementation as the architecture baseline.

## Goal

Ship one complete repeatable content-expansion unit:

> Master Lunar Frontier → unlock Mars Frontier → reveal three authored sectors → discover Iron Ore, Silica, and Cobalt Ore → build and upgrade familiar mines → sell cargo → complete Mars mastery and receive a simple cash reward.

The player learns new content, not a new control scheme, economy, state owner, or simulation path.

## Product decision

Use **Mars Frontier**, a rust-red industrial mining world with exactly three sectors and three raw resources.

Three sectors are enough to prove the content-pack seam while keeping balance, UI, persistence, and regression work small. HPA-641 must not add extra sectors merely to make the planet feel larger.

## Frozen content brief

### Planet

- ID: `MiningPlanetId.marsFrontier`
- Display name: `Mars Frontier`
- Terrain seed: `641`
- Atmosphere tint: `Color(0xFF2A1512)`
- Visual fantasy: dark rust terrain, warm industrial accents, and blue cobalt contrast.
- Unlock: Lunar Frontier mastery + Surveying 5 + 20,000 cash.
- Completion reward: 25,000 cash when Mars moves from not mastered to mastered.

Surveying 5 is already implied by Lunar mastery because Helium Mare requires Surveying 5. Keep the explicit Surveying field anyway: it is part of the frozen brief and the same unlock field remains load-bearing for Lunar Frontier.

### Sectors and economy

| Sector | Resource | Facility identity | `mineAsset` | Surveying | Reveal | Build | Rate/s | Capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Ochre Basin | Iron Ore | Iron Rig | `Assets.woodFactory` | 5 | 0 | 5,000 | 0.75 | 180 | 32 | 7,000 / 14,000 / 28,000 / 56,000 |
| Silica Dunes | Silica | Silica Extractor | `Assets.riceHuller` | 5 | 12,000 | 9,000 | 0.55 | 160 | 55 | 12,000 / 24,000 / 48,000 / 96,000 |
| Cobalt Chasm | Cobalt Ore | Cobalt Drill | `Assets.sawmill` | 5 | 30,000 | 18,000 | 0.35 | 130 | 110 | 24,000 / 48,000 / 96,000 / 192,000 |

Fixed world anchors:

- Ochre Basin: `MiningWorldAnchor(-360, 330)`
- Silica Dunes: `MiningWorldAnchor(280, -60)`
- Cobalt Chasm: `MiningWorldAnchor(-80, -400)`

Discovery chain:

```text
Ochre Basin
  -> Silica Dunes
      -> Cobalt Chasm
```

All three require Surveying 5. Do not raise the technology cap simply to create a Mars-specific gate. Progress inside Mars comes from prior-sector discovery and cash costs.

### Resource identities

Reuse the existing `ResourceSilhouette` mechanism with built-in Material icons. Add no resource PNGs.

- Iron Ore: construction/industrial silhouette, deep-orange identity.
- Silica: granular silhouette, amber identity.
- Cobalt Ore: science/crystal-like silhouette, blue identity.

The three `mineAsset` paths above are frozen authored values. Do not substitute a different sprite during implementation unless the content brief itself is revised first.

### Authored discovery text

HPA-641 needs small content entries, not a discovery-log subsystem. Add a lightweight optional `discoveryText` value to `MiningSectorDefinition` and surface it in the existing sector sheet after reveal.

Mars entries are:

- Ochre Basin: iron-rich regolith supports the first heavy extraction rig.
- Silica Dunes: glassy dune deposits trade lower throughput for stronger sale value.
- Cobalt Chasm: deep cobalt seams are the final high-value Mars target.

Add an optional `facilityName` to `MiningSectorDefinition`, defaulting to `Mine`, so Mars can present Iron Rig / Silica Extractor / Cobalt Drill without forcing a second facility model. This is content display, not a new facility type system.

## Non-goals

Do not add:

- another technology track or technology levels above 5;
- technology points, research timers, laboratories as a progression system, or another currency;
- processing, logistics, shipping, workers, resource transfer, or dynamic markets;
- procedural sectors, randomized deposits, or planet-specific simulation rules;
- a generic requirement engine, reward engine, event bus, or content-management platform;
- downloadable content, remote content, asset packs, or a new preload pipeline;
- a second controller, repository, simulation, save key, or resident Flame world;
- more than one new planet;
- a migration framework or one-off compatibility reader for pre-release HPA-638 data;
- a performance benchmark harness solely for this content pack.

## Architecture baseline to preserve

HPA-638 already established the required ownership model:

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

The existing runtime paths already scale correctly:

- simulation iterates `unlockedPlanetIds` and then `content.planet(id).sectors`;
- active selling/HUD/tabs/sheet iterate only `activePlanetId`;
- `MiningGame` receives one `MiningPlanetDefinition` and is replaced when travel changes the active planet;
- offline production is already grouped by `productionByPlanet`;
- sector IDs are globally unique and mutable progress remains the flat `Map<MiningSectorId, SectorProgress>`.

Do not rewrite these paths for Mars.

## Concrete seams HPA-641 may widen

HPA-638 intentionally left a few two-planet assumptions. HPA-641 is the second real consumer that justifies widening them.

### 1. Planet-level unlock metadata

Extend `MiningPlanetDefinition` directly with the few requirements every authored unlock now uses:

```dart
final MiningPlanetId? unlockRequiredMasteryPlanetId;
final int unlockRequiredSurveyingLevel;
final int unlockCashCost;
final int masteryRewardCash;
```

Use values:

| Planet | Required mastery | Surveying | Unlock cash | Mastery reward |
| --- | --- | ---: | ---: | ---: |
| Homeworld | none | 0 | 0 | 0 |
| Lunar Frontier | Homeworld | 3 | 2,500 | 0 |
| Mars Frontier | Lunar Frontier | 5 | 20,000 | 25,000 |

This is intentionally not a generic condition/reward engine. These four fields match the two real unlocks and the one HPA-641 completion reward.

Remove Lunar-only static unlock constants once their values live on the planet definition.

### 2. Mastery helper

Replace the Homeworld-only helper with:

```dart
bool isPlanetMastered(
  MiningPlanetId planetId,
  Iterable<MiningSectorId> minedSectorIds,
)
```

Mastery remains derived: every authored sector on that planet has a mine. Do not store a mastery flag or milestone record.

### 3. Honest authored planet cards in the Stellar Map

The current `StellarMapView` and `StellarMapSheet` hard-code Homeworld and Lunar Frontier. With three planets, replace the two-card shape with a small list of `StellarMapPlanetView` values containing presentation-ready data.

The view must keep **own mastery progress** distinct from **unlock prerequisite mastery progress**:

```dart
class StellarMapPlanetView {
  final MiningPlanetId id;
  final String name;
  final bool isUnlocked;
  final bool isActive;

  // This planet's own progress. Render on unlocked cards.
  final int minesBuilt;
  final int mineTotal;

  // Prerequisite progress. Render only while locked.
  final String? requiredMasteryPlanetName;
  final int? requiredMinesBuilt;
  final int? requiredMineTotal;
  final bool hasRequiredMastery;

  final int requiredSurveyingLevel;
  final bool hasSurveying;
  final int unlockCashCost;
  final bool hasCash;

  bool get canUnlock;
}
```

Examples:

- locked Lunar card: own `0/3` is not the displayed gate; prerequisite row shows `Homeworld mines 2/3`;
- locked Mars card: prerequisite row shows `Lunar Frontier mines 2/3`;
- unlocked Mars card: card shows `Mines 2/3` for Mars itself.

`StellarMapView` owns `List<StellarMapPlanetView> planets`. The sheet loops that list and emits one card per authored planet. Callbacks become `onUnlock(MiningPlanetId)` and `onTravel(MiningPlanetId)`.

Use per-planet keys:

```text
mining-stellar-map-unlock-${id.name}
mining-stellar-map-travel-${id.name}
```

The existing single `mining-stellar-map-unlock` key is not valid once more than one planet can be locked.

Do not introduce arbitrary requirement rows or polymorphic map-card types.

### 4. Strict current save only

The save root stays exactly:

```text
cash
lastAccruedAtUtc
technology
unlockedPlanetIds
activePlanetId
sectors
```

The HPA-641 current document contains exactly all nine `MiningSectorId` keys.

Do **not** add a six-to-nine decoder branch. `MiningSaveRepository._decodeSectors()` continues to derive the expected key set from `MiningSectorId.values`; after Mars IDs are added, old six-sector HPA-638 development documents fail exact-key validation and use the existing `recoveredFromInvalidSave` clean-reset path.

Update the current hard-coded error copy from “six authored sectors” to wording that does not become stale, for example:

```text
sector keys must be exactly the authored sectors
```

There is still no `schemaVersion`, migration registry, compatibility reader, or legacy conversion flag.

Generalize the locked-planet invariant instead of adding a Mars-specific branch:

```text
for each authored planet not in unlockedPlanetIds:
  every sector on that planet must be pristine
```

Unreadable, malformed, unknown, old six-sector, or otherwise incompatible data all use the same existing recovery boundary.

### 5. Initial state derives from authored identities

`MiningSave.initial()` must stop hand-listing one sector record per enum value. Keep state independent of `MiningContentRegistry`; derive the initial flat map from the closed sector enum:

```dart
sectors: {
  for (final id in MiningSectorId.values)
    id: SectorProgress(
      revealed: id == MiningSectorId.landingBasin,
    ),
},
```

Landing Basin remains the only initially revealed sector. Every newly added sector identity appears pristine automatically. Strictness remains in repository decode through the exact enum-derived key set.

## Unlock flow

`MiningController.unlockPlanet(id)` becomes data-driven for the two authored unlocks:

1. accrue using the shared clock;
2. reject Homeworld / any planet without an unlock prerequisite;
3. reject an already-unlocked planet;
4. read the target planet definition;
5. require mastery of `unlockRequiredMasteryPlanetId`;
6. require the target's Surveying level;
7. require the target's cash cost;
8. debit global cash, add the target to `unlockedPlanetIds`, make it active;
9. save once, then publish.

No planet-specific controller method or branch is allowed.

## Mars mastery reward

The one-time cash reward needs no stored claim flag because mines cannot be removed and the final missing mine can only be built once.

During `buildMine(id)`:

1. identify the sector's planet through `planetForSector`;
2. evaluate `wasMastered` before changing the sector;
3. construct the normal new mine state and debit build cost;
4. evaluate mastery using the post-build mined-sector set;
5. if `!wasMastered && isMastered`, add `planet.masteryRewardCash`;
6. persist once and return success.

Only Mars has a non-zero reward in this task.

`MiningActionResult` already has a nullable `message`; widen the success constructor so successful mutations may populate it while existing callers continue to get `null`. The existing snackbar path should prefer a successful result message when present. Mars final construction can therefore report `Mars mastered — +25000 cash.` without adding a completion dialog or reward-result hierarchy.

## Deterministic simulation

`MiningSimulation` should require no structural change. Mars proves that the existing loop works for a third unlocked planet:

```text
one UTC elapsed window
  -> Homeworld sectors if unlocked
  -> Lunar Frontier sectors if unlocked
  -> Mars Frontier sectors if unlocked
```

Technology multipliers apply exactly once because they are already passed through `effectiveRate`, `effectiveCapacity`, and `offlineCapFor`.

Add characterization coverage for three unlocked planets, full Mars storage, and offline return grouping. If this test exposes a real bug, fix only that concrete bug; do not replace the simulation architecture.

## Active-planet gameplay

Reveal, Build, Upgrade, Sell, target framing, reward effects, and planet switching keep their current contracts.

Mars-specific behavior comes only from content values:

- first sector reveal is free after planet unlock;
- later sectors require the previous reveal plus cash;
- all three sectors require Surveying 5;
- rates/capacities/sale values use the existing technology multipliers;
- Sell All clears only Mars cargo while Mars is active;
- switching away leaves Mars accruing because it remains unlocked.

## Presentation

### Sector sheet

Keep the existing `MiningSheetView` as the affordance authority. Its Mars additions are content display only:

- show the resource display name for revealed deposits;
- include `discoveryText` when present;
- use `facilityName` in build copy when present;
- preserve the same reveal/build/upgrade button and disabled-reason logic.

Do not create a discovery screen or facility-specific action sheet.

### Stellar Map

Render all three authored planets in one scrollable sheet.

For a locked planet, render:

- prerequisite planet mines `requiredMinesBuilt/requiredMineTotal`;
- Surveying target;
- cash target;
- one per-planet Unlock button.

For an unlocked planet, render:

- its own `Mines minesBuilt/mineTotal` mastery progress;
- one Travel button or the current-location disabled state.

The sheet already scrolls, so three cards should not require another navigation pattern.

### World art

Mars uses the existing `MiningGame` terrain size, reveal effect, mine components, tier-upgrade visuals, camera fitting, and reduced-motion behavior. Distinction comes from:

- rust atmosphere tint;
- seed 641 terrain arrangement;
- three authored anchors;
- resource silhouettes/colors;
- the three frozen facility sprites.

No new canvas effect or Mars-specific component is planned.

## Art, loading, memory, and frame budget

The budget is intentionally defined as invariants that can be checked without building a new profiling system.

### Asset payload

- New PNG/JPEG/WebP/audio payload: **0 bytes**.
- New resource graphics: built-in Material icons only.
- Mars facility sprites: `Assets.woodFactory`, `Assets.riceHuller`, `Assets.sawmill`.

### Loading

- One active `MiningGame` only.
- Mars loads at most those three already-shipped facility images through the existing Flame image cache.
- No new preload queue, bundle manifest, or remote fetch.

### Memory

- No inactive planet keeps a Flame world resident.
- Mars adds only one planet definition, three sector definitions, three resource identities, and three `SectorProgress` records to normal state/catalog memory.
- Do not retain duplicate per-planet state projections.

### Frame behavior

- Keep the same 36×36 terrain grid and three sector components as the shipped planets.
- Keep current reward effects and reduced-motion variants.
- Verify representative 360×640 and 430×932 portrait journeys with all three planets available.
- Record any visible loading/frame regression in the PR. Do not add a synthetic benchmark harness unless a reproducible regression is actually found.

## Verification contract

### Unit/content

Prove:

- exact Mars seed, tint, sector order, anchors, resources, costs, rates, capacities, sale values, upgrade curves, `mineAsset`, facility/discovery text, and silhouettes;
- `isPlanetMastered` for Homeworld, Lunar, and Mars;
- technology presentation counts nine sectors and does not introduce Surveying 6;
- `ResourceType.values` contains exactly the nine current mining resource identities.

### Persistence

Prove:

- fresh state has exactly nine enum-derived sector records and only Landing Basin is revealed;
- exact current nine-sector saves round-trip without losing existing Homeworld/Lunar/Mars state;
- an old exact HPA-638 six-sector save uses the existing recovery path and starts fresh current state;
- any locked authored planet containing revealed/mine state is invalid;
- unreadable and malformed data still clean-reset;
- saving current state writes exactly the nine authored sector keys.

### Controller

Prove:

- Mars cannot unlock without Lunar mastery, Surveying 5, and 20,000 cash;
- successful unlock debits once, unlocks once, makes Mars active, and saves once;
- Lunar unlock still uses the same generic mutation and original requirements;
- Mars reveal/build/upgrade uses the existing controller paths;
- building the final Mars mine grants exactly 25,000 cash once;
- switching planets preserves all planet progress;
- selling Mars cargo does not clear Homeworld/Lunar cargo.

### Simulation/offline

Prove:

- one elapsed window accrues all three unlocked planets;
- Extraction/Logistics modifiers apply exactly once to Mars;
- full Mars storage caps without affecting other planets;
- offline summary groups Mars with the other planets;
- locked Mars never accrues.

### Widget/integration

Prove:

- Stellar Map shows three cards and correct lock/travel states;
- locked cards show prerequisite mastery counts;
- unlocked cards show their own `Mines x/y` progress;
- per-planet Unlock keys are unique;
- 360×640 and 430×932 remain usable;
- reduced motion preserves the Mars flow;
- unlock → first Mars reveal → first Mars mine works through `MiningScreen`;
- meaningful Mars mastery progress is visible as mines are built;
- final mastery reward is visible through the existing snackbar path.

### Mechanical retarget

The catalog/state task must leave all existing exact-shape consumers correct in the same commit. At minimum update:

- `test/resources/resource_type_test.dart` exact resource list/name pins;
- `test/mining/mining_save_repository_test.dart` current-sector helper and exact-key assertions;
- `test/mining/presentation/mining_screen_test.dart` any persisted six-sector save fixtures;
- `test/integration/mining_mvp_journey_test.dart` current save helper, Stellar Map key usage, and planet/offline expectations that intentionally cover the full current catalog;
- any other literal `MiningSave`/raw save fixtures found by search;
- `CLAUDE.md`: three planets, nine authored sectors/resources, and the unchanged no-compatibility-reader policy.

Do not defer broken fixtures to a later task.

### Repository gates

Final implementation runs the same gates used by HPA-638:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Also perform the representative portrait/reduced-motion smoke and record asset/loading/memory/frame observations in the PR.

## Risks

Only three implementation risks are material enough to call out:

1. **Stellar Map key collision / hard-coded callback assumptions.** The current single Unlock key and Lunar-specific callback cannot survive two simultaneously locked planets. Mitigation: per-planet keys and generic `onUnlock(MiningPlanetId)` land together with widget/integration retarget.
2. **Own mastery vs prerequisite mastery count overload.** One `minesBuilt/mineTotal` pair cannot truthfully represent both locked requirements and unlocked progress. Mitigation: separate fields in `StellarMapPlanetView` and tests for locked Lunar, locked Mars, and unlocked Mars.
3. **Stale six-sector persisted fixtures.** There is intentionally no converter, so any test that seeds the old current document will reset rather than exercise its intended scenario. Mitigation: Task 1 searches and retargets every current persisted fixture to nine keys, while one dedicated recovery test proves old six-key data clean-resets.

Balance feel and portrait layout remain verification work, but they are not architecture risks and do not justify extra machinery.

## Reuse/change ledger

### Reuse unchanged

- `MiningSimulation` architecture and one-global-clock accrual.
- active-planet Sell All behavior.
- Reveal / Build / Upgrade mutation structure and serialized mutation chain.
- `MiningGame` replacement-on-travel lifecycle.
- sector camera framing and reward effects.
- technology levels/effects/costs.
- global cash + planet-scoped sector/cargo state.
- one strict unversioned SharedPreferences save key.
- invalid/incompatible pre-release save recovery by clean reset.
- terrain generator and current image loading/cache behavior.

### Change because Mars is a real second consumer

- Lunar-only unlock metadata → fields on `MiningPlanetDefinition`.
- Homeworld-only mastery helper → `isPlanetMastered`.
- two-card Stellar Map view/sheet → list of authored planet cards.
- single mastery count concept → distinct own/prerequisite counts.
- single Unlock key/callback → per-planet keys + generic unlock callback.
- Lunar-only locked-sector validation → generic locked-planet validation.
- handwritten initial sector table → enum-derived pristine map with Landing Basin revealed.
- optional sector discovery/facility copy to make authored Mars content visible.
- successful build result may carry the Mars mastery message.

Do not generalize anything else for hypothetical fourth planets.

## Acceptance interpretation

HPA-641 is done when Mars feels like a complete third world while the code still reads like the HPA-638 game with one more authored content pack. A successful implementation should make future content easier primarily because the existing seams survived real reuse, not because HPA-641 built a platform for unknown future requirements.