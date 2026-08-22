# HPA-638 Technology and Lunar Frontier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the shipped mining-only game with three cash-funded technology tracks, a strict two-planet save, Lunar Frontier, active-planet selling, and deterministic two-planet offline production without adding a second economy or generic planet framework.

**Architecture:** Evolve the existing `MiningScreen -> MiningController -> MiningSimulation/MiningSaveRepository/MiningContentRegistry` vertical slice in place. Replace flat sector iteration with an explicit two-planet content catalog and nested save state; simulation iterates unlocked planets, while HUD/sell/sheets/Flame iterate only the active planet. Keep one controller/repository/save key and recreate only the `MiningGame` projection when the active planet changes.

**Tech Stack:** Dart 3.8, Flutter, Flame 1.30, SharedPreferences 2.5, existing `flutter_test` suites.

**Spec:** `docs/superpowers/specs/2026-08-21-hpa-638-technology-lunar-frontier-design.md`

## Global Constraints

- One PR for HPA-638; continue implementation on PR #16.
- Cash is the only spendable progression currency.
- Keep one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, and `horologium.mining.save` key.
- No `schemaVersion`; distinguish shipped v1 and current format by exact root keys.
- No flat `MiningContentRegistry.sectors` or `MiningSave.sectors` after Task 1.
- No modifier engine, requirement DSL, planet/theme/biome framework, state-management framework, command bus, event bus, or new E2E harness.
- Homeworld mastery is derived from the three Homeworld mines being built; mine levels do not need to be maxed.
- Lunar unlock requires Homeworld mastery + Surveying 3 + 2,500 cash.
- Sell All Cargo sells the active planet only; cash remains global.
- One global UTC accrual window advances every unlocked planet.
- Stellar Map is visible at Surveying 0.
- Portrait checks cover 360×640 and 430×932; primary controls stay at least 48 logical pixels.
- Reduced motion must keep confirmations clear while skipping nonessential motion.

## File Map

**Core domain**
- `lib/mining/mining_content.dart` — two-planet catalog, technology tables, effective rate/capacity/offline helpers, mastery/unlock helpers.
- `lib/mining/mining_state.dart` — nested planet progress, technology state, minimal `progressFor` / `withSector` helpers.
- `lib/game/resources/resource_type.dart` — six closed mining resource identities.
- `lib/mining/mining_save_repository.dart` — exact current decode, exact shipped-v1 conversion, Logistics-aware capacity normalization.
- `lib/mining/mining_simulation.dart` — one-window multi-planet accrual and grouped return summary.
- `lib/mining/mining_controller.dart` — serialized tech/unlock/switch mutations and active-planet selling.

**Pure presentation**
- `lib/mining/mining_sheet_view.dart` — active-planet sell/reveal/build/upgrade affordances with effective values.
- `lib/mining/mining_progression_views.dart` — concrete Technology and Stellar Map view models.

**Flutter**
- `lib/mining/presentation/technology_sheet.dart` — renders technology cards and delegates purchase callbacks.
- `lib/mining/presentation/stellar_map_sheet.dart` — renders Homeworld/Lunar cards and delegates unlock/travel callbacks.
- `lib/mining/presentation/mining_screen.dart` — owns both sheets, active-planet HUD/tabs, and replaceable `MiningGame` projection.
- `lib/mining/presentation/mining_status_bar.dart` — active planet label plus active-planet progress/cargo.
- `lib/mining/presentation/offline_return_sheet.dart` — grouped planet sections and six exhaustive resource mappings.

**Flame/assets**
- `lib/mining/world/mining_game.dart` — one planet definition/progress at a time, authored seed, planet-ID tint, no dynamic teardown framework.
- `lib/mining/world/mining_components.dart` — concrete mining-world atmosphere overlay used for the Lunar tint.
- `lib/constants/assets_path.dart` — concrete Lunar mine/resource paths.
- `assets/images/building/water_ice_mine.png`
- `assets/images/building/titanium_mine.png`
- `assets/images/building/helium3_extractor.png`
- `assets/images/resource/water_ice.png`
- `assets/images/resource/titanium_ore.png`
- `assets/images/resource/helium3.png`

**Tests**
- `test/mining/mining_content_test.dart`
- `test/mining/mining_state_test.dart` — new focused nested-state suite.
- `test/mining/mining_save_repository_test.dart`
- `test/mining/mining_simulation_test.dart`
- `test/mining/mining_controller_test.dart`
- `test/mining/mining_sheet_view_test.dart`
- `test/mining/mining_progression_views_test.dart` — new pure progression-view suite.
- `test/mining/presentation/mining_screen_test.dart`
- `test/mining/world/mining_game_test.dart`
- `test/integration/mining_multi_planet_journey_test.dart` — new tests using the existing Flutter/SharedPreferences integration style, not a new driver.

---

### Task 1: Replace the flat world with a two-planet catalog and nested state

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_state.dart`
- Modify: `lib/game/resources/resource_type.dart`
- Modify: `test/mining/mining_content_test.dart`
- Create: `test/mining/mining_state_test.dart`

**Interfaces:**
- Produces: `MiningPlanetId`, `MiningPlanetDefinition`, `TechnologyTrack`, `TechnologyLevels`, `MiningPlanetProgress`, `MiningContentRegistry.stellarMining()`, `planet()`, `sector()`, `planetForSector()`, `effectiveRate()`, `effectiveCapacity()`, `offlineCapFor()`, `technologyCost()`, `technologyRequirement()`, `MiningSave.progressFor()`, `MiningSave.withSector()`.
- Consumes: existing `MiningSectorDefinition`, `SectorProgress`, `MineState`, mine-level multipliers and first-planet balance.

- [ ] **Step 1: Write failing catalog tests**

Add tests that require exactly two planets, three sectors per planet, global sector lookup, and the technology tables:

```dart
final content = MiningContentRegistry.stellarMining();

expect(content.planets.keys.toSet(), {
  MiningPlanetId.homeworld,
  MiningPlanetId.lunarFrontier,
});
expect(
  content.planet(MiningPlanetId.homeworld).sectors.map((s) => s.id),
  [
    MiningSectorId.landingBasin,
    MiningSectorId.carbonRidge,
    MiningSectorId.graniteCrater,
  ],
);
expect(
  content.planet(MiningPlanetId.lunarFrontier).sectors.map((s) => s.id),
  [
    MiningSectorId.frozenBasin,
    MiningSectorId.titaniumHighlands,
    MiningSectorId.heliumMare,
  ],
);
expect(
  content.planetForSector(MiningSectorId.heliumMare),
  MiningPlanetId.lunarFrontier,
);
expect(content.technologyCost(3), 1500);
expect(content.extractionMultiplier(5), 2.0);
expect(content.logisticsStorageMultiplier(3), 1.5);
expect(content.offlineCapFor(5), const Duration(hours: 24));
```

Also assert Lunar values from the spec: Frozen Basin `(Surveying 3, reveal 0, build 500, rate 1.00, capacity 150, sale 6)`, Titanium Highlands `(4, 3000, 1200, 0.80, 140, 12)`, Helium Mare `(5, 8000, 3000, 0.55, 120, 30)` and all four upgrade costs per sector.

- [ ] **Step 2: Write failing nested-state tests**

```dart
final content = MiningContentRegistry.stellarMining();
final save = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 21));

expect(save.activePlanetId, MiningPlanetId.homeworld);
expect(save.unlockedPlanetIds, {MiningPlanetId.homeworld});
expect(
  save.progressFor(content, MiningSectorId.landingBasin).revealed,
  isTrue,
);
expect(
  save.progressFor(content, MiningSectorId.frozenBasin).revealed,
  isFalse,
);

final updated = save.withSector(
  content,
  MiningSectorId.landingBasin,
  const SectorProgress(
    revealed: true,
    mine: MineState(level: 1, storedAmount: 12),
  ),
);
expect(
  updated.progressFor(content, MiningSectorId.landingBasin).mine!.storedAmount,
  12,
);
expect(
  updated.progressFor(content, MiningSectorId.frozenBasin),
  save.progressFor(content, MiningSectorId.frozenBasin),
);
```

- [ ] **Step 3: Run the focused tests and observe RED**

Run:

```sh
flutter test test/mining/mining_content_test.dart test/mining/mining_state_test.dart
```

Expected: compile/test failures because planet/technology identities, `stellarMining()`, and nested state helpers do not exist.

- [ ] **Step 4: Implement the closed identities and catalog**

Replace the flat registry shape with:

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

Add `requiredSurveyingLevel` to every sector definition. Use `0` for all Homeworld sectors, `3/4/5` for Frozen/Titanium/Helium respectively. Keep Homeworld seed `631`; use Lunar seed `638`.

`MiningContentRegistry` stores exactly:

```dart
final Map<MiningPlanetId, MiningPlanetDefinition> planets;

MiningPlanetDefinition planet(MiningPlanetId id) => planets[id]!;

MiningSectorDefinition sector(MiningSectorId id) => planets.values
    .expand((planet) => planet.sectors)
    .singleWhere((sector) => sector.id == id);

MiningPlanetId planetForSector(MiningSectorId id) => planets.values
    .singleWhere((planet) => planet.sectors.any((s) => s.id == id))
    .id;
```

Do not retain a public `sectors` getter.

Add the exact technology arrays:

```dart
static const technologyCosts = <int>[300, 700, 1500, 4000, 9000];
static const extractionMultipliers = <double>[1.0, 1.10, 1.25, 1.45, 1.70, 2.0];
static const logisticsStorageMultipliers = <double>[1.0, 1.15, 1.30, 1.50, 1.75, 2.0];
static const offlineCaps = <Duration>[
  Duration(hours: 8),
  Duration(hours: 10),
  Duration(hours: 12),
  Duration(hours: 16),
  Duration(hours: 20),
  Duration(hours: 24),
];
static const technologyRequirements = <MiningSectorId>[
  MiningSectorId.landingBasin,
  MiningSectorId.carbonRidge,
  MiningSectorId.graniteCrater,
  MiningSectorId.frozenBasin,
  MiningSectorId.titaniumHighlands,
];
```

Extend `ResourceType` to exactly six values: `gold`, `coal`, `stone`, `waterIce`, `titaniumOre`, `helium3`.

- [ ] **Step 5: Implement nested state and helpers**

Use immutable shapes:

```dart
class TechnologyLevels {
  const TechnologyLevels({
    required this.extraction,
    required this.logistics,
    required this.surveying,
  });

  final int extraction;
  final int logistics;
  final int surveying;
}

class MiningPlanetProgress {
  const MiningPlanetProgress({required this.sectors});
  final Map<MiningSectorId, SectorProgress> sectors;
}
```

`MiningSave` owns `technology`, `unlockedPlanetIds`, `activePlanetId`, and `planets`. Add only:

```dart
MiningPlanetProgress get activePlanetProgress => planets[activePlanetId]!;

SectorProgress progressFor(
  MiningContentRegistry content,
  MiningSectorId sectorId,
) {
  final planetId = content.planetForSector(sectorId);
  return planets[planetId]!.sectors[sectorId]!;
}

MiningSave withSector(
  MiningContentRegistry content,
  MiningSectorId sectorId,
  SectorProgress progress,
) {
  final planetId = content.planetForSector(sectorId);
  final currentPlanet = planets[planetId]!;
  final nextPlanet = MiningPlanetProgress(
    sectors: Map.unmodifiable({
      ...currentPlanet.sectors,
      sectorId: progress,
    }),
  );
  return copyWith(
    planets: Map.unmodifiable({...planets, planetId: nextPlanet}),
  );
}
```

Initial state includes both planet records, only Homeworld unlocked, Homeworld active, technology 0/0/0, Landing Basin revealed, and every Lunar sector unrevealed.

- [ ] **Step 6: Run focused GREEN and commit**

Run:

```sh
flutter test test/mining/mining_content_test.dart test/mining/mining_state_test.dart
```

Expected: PASS.

Commit:

```sh
git add lib/mining/mining_content.dart lib/mining/mining_state.dart lib/game/resources/resource_type.dart test/mining/mining_content_test.dart test/mining/mining_state_test.dart
git commit -m "feat(mining): add two-planet content and state"
```

---

### Task 2: Replace the shipped flat save with the strict current format and direct v1 conversion

**Files:**
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/mining/mining_controller.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Modify: `test/mining/mining_controller_test.dart`

**Interfaces:**
- Consumes: Task 1 `MiningSave`, technology levels, planet catalog and effective capacity helper.
- Produces: exact current-format decoder/writer and `MiningLoadResult.migratedLegacyV1`.

- [ ] **Step 1: Add RED tests for current-format round trip without a version field**

Save a state with both planet records and assert decoded state matches. Inspect raw JSON and assert exact root keys:

```dart
expect(decoded.keys.toSet(), {
  'cash',
  'lastAccruedAtUtc',
  'technology',
  'unlockedPlanetIds',
  'activePlanetId',
  'planets',
});
expect(decoded.containsKey('schemaVersion'), isFalse);
```

Add rejection cases for an unknown root key, unknown planet ID, active locked planet, missing Lunar record, and progressed Lunar sector while Lunar is locked.

- [ ] **Step 2: Add RED shipped-v1 conversion tests**

Seed SharedPreferences with the exact shipped v1 shape:

```dart
SharedPreferences.setMockInitialValues({
  MiningSaveRepository.saveKey: jsonEncode({
    'cash': 4321,
    'lastAccruedAtUtc': '2026-08-21T10:00:00.000Z',
    'sectors': {
      'landingBasin': {
        'revealed': true,
        'mine': {'level': 3, 'storedAmount': 44.5},
      },
      'carbonRidge': {'revealed': true, 'mine': null},
      'graniteCrater': {'revealed': false, 'mine': null},
    },
  }),
});
```

Assert:

```dart
expect(result.migratedLegacyV1, isTrue);
expect(result.state.cash, 4321);
expect(result.state.technology.extraction, 0);
expect(result.state.activePlanetId, MiningPlanetId.homeworld);
expect(result.state.unlockedPlanetIds, {MiningPlanetId.homeworld});
expect(
  result.state.progressFor(content, MiningSectorId.landingBasin).mine!.level,
  3,
);
expect(
  result.state.progressFor(content, MiningSectorId.frozenBasin).mine,
  isNull,
);
```

Add one malformed-v1 case and assert `recoveredFromInvalidSave == true` and `migratedLegacyV1 == false`.

- [ ] **Step 3: Add RED Logistics-aware clamp test**

Create a current-format document with Logistics 2 and a level-1 Landing Basin mine storing `110`. Base capacity is `90`; effective capacity is `90 * 1.30 = 117`, so decoding must preserve `110`, not prematurely clamp to `90`.

Then set stored amount to `130` and assert decode clamps to `117`.

- [ ] **Step 4: Run RED**

```sh
flutter test test/mining/mining_save_repository_test.dart
```

Expected: failures because repository still expects `{cash,lastAccruedAtUtc,sectors}` only.

- [ ] **Step 5: Implement exact shape dispatch and decode ordering**

Add constants:

```dart
const _legacyV1RootKeys = {'cash', 'lastAccruedAtUtc', 'sectors'};
const _currentRootKeys = {
  'cash',
  'lastAccruedAtUtc',
  'technology',
  'unlockedPlanetIds',
  'activePlanetId',
  'planets',
};
```

After `jsonDecode`, require a map and dispatch only on exact key sets:

```dart
if (hasExactKeys(root, _legacyV1RootKeys)) {
  final state = _decodeLegacyV1(root);
  return MiningLoadResult(
    state: state,
    recoveredFromInvalidSave: false,
    wasMissing: false,
    migratedLegacyV1: true,
  );
}
if (hasExactKeys(root, _currentRootKeys)) {
  return MiningLoadResult(
    state: _decodeCurrent(root),
    recoveredFromInvalidSave: false,
    wasMissing: false,
    migratedLegacyV1: false,
  );
}
throw const FormatException('unknown mining save shape');
```

Decode current state in the required order: cash/timestamp → technology → unlocked/active IDs → planets/mines → cross-field invariants. Pass decoded Logistics into mine decoding:

```dart
MineState? _decodeMine(
  MiningSectorId sectorId,
  Object? raw,
  int logisticsLevel,
) {
  // existing strict level/stored validation
  final capacity = content.effectiveCapacity(
    sectorId,
    level,
    logisticsLevel,
  );
  return MineState(
    level: level,
    storedAmount: math.min(storedAmount.toDouble(), capacity),
  );
}
```

Legacy v1 uses Logistics 0 during its direct conversion.

- [ ] **Step 6: Rewrite converted v1 once during controller initialization**

Extend `MiningLoadResult` with required `migratedLegacyV1`. Change the existing initialization persistence condition to:

```dart
if (loaded.wasMissing ||
    loaded.recoveredFromInvalidSave ||
    loaded.migratedLegacyV1) {
  try {
    await repository.save(_state);
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('Initial mining save persistence failed: $e\n$stackTrace');
    }
  }
}
```

Add a controller test that initializes from v1, then reads SharedPreferences and asserts the persisted root contains `planets` and not `sectors`.

- [ ] **Step 7: Run focused GREEN and commit**

```sh
flutter test test/mining/mining_save_repository_test.dart test/mining/mining_controller_test.dart
```

Expected: PASS for migration/current persistence coverage; controller tests unrelated to later planet actions may still need mechanical fixture updates to the nested state shape in this task.

Commit:

```sh
git add lib/mining/mining_save_repository.dart lib/mining/mining_controller.dart test/mining/mining_save_repository_test.dart test/mining/mining_controller_test.dart
git commit -m "feat(mining): migrate shipped saves to two-planet state"
```

---

### Task 3: Make simulation accrue every unlocked planet over one technology-aware UTC window

**Files:**
- Modify: `lib/mining/mining_simulation.dart`
- Modify: `test/mining/mining_simulation_test.dart`

**Interfaces:**
- Consumes: `MiningSave.progressFor/withSector`, `content.planet()`, `effectiveRate`, `effectiveCapacity`, `offlineCapFor`.
- Produces: grouped `OfflineProductionSummary` and deterministic multi-planet `accrue()`.

- [ ] **Step 1: Write RED two-planet accrual test**

Build a state with Homeworld + Lunar unlocked, a level-1 Gold mine and level-1 Water Ice mine, Extraction 1, Logistics 0, and 10 seconds elapsed. Assert Gold gets `0.50 * 1.10 * 10 = 5.5` and Water Ice gets `1.00 * 1.10 * 10 = 11.0` in one call.

Assert grouped summary:

```dart
expect(
  result.summary.productionByPlanet[MiningPlanetId.homeworld]![ResourceType.gold],
  5.5,
);
expect(
  result.summary.productionByPlanet[MiningPlanetId.lunarFrontier]![ResourceType.waterIce],
  11.0,
);
```

- [ ] **Step 2: Write RED Logistics cap/capacity tests**

With Logistics 2, assert offline elapsed of 20 hours uses 12 hours. Assert capacity uses the `1.30` storage multiplier and independently clamps each mine. Add a locked-Lunar test where a populated but locked Lunar record produces zero.

- [ ] **Step 3: Run RED**

```sh
flutter test test/mining/mining_simulation_test.dart
```

Expected: failures from flat `content.sectors`/`state.sectors` iteration and fixed eight-hour cap.

- [ ] **Step 4: Implement grouped summary and explicit unlocked-planet loops**

Replace flat summary fields with:

```dart
class OfflineProductionSummary {
  const OfflineProductionSummary({
    required this.elapsedUsed,
    required this.productionByPlanet,
    required this.fullSectorsByPlanet,
    required this.wasOfflineCapped,
  });

  final Duration elapsedUsed;
  final Map<MiningPlanetId, Map<ResourceType, double>> productionByPlanet;
  final Map<MiningPlanetId, Set<MiningSectorId>> fullSectorsByPlanet;
  final bool wasOfflineCapped;

  double get totalProduced => productionByPlanet.values
      .expand((resources) => resources.values)
      .fold(0, (sum, value) => sum + value);
}
```

The accrual core must be structurally:

```dart
final extraction = state.technology.extraction;
final logistics = state.technology.logistics;
final cap = content.offlineCapFor(logistics);
final elapsed = rawElapsed > cap ? cap : rawElapsed;

var next = state;
for (final planetId in state.unlockedPlanetIds) {
  final planet = content.planet(planetId);
  for (final definition in planet.sectors) {
    final progress = next.progressFor(content, definition.id);
    final mine = progress.mine;
    if (!progress.revealed || mine == null) continue;

    final capacity = content.effectiveCapacity(
      definition.id,
      mine.level,
      logistics,
    );
    final rate = content.effectiveRate(
      definition.id,
      mine.level,
      extraction,
    );
    // clamp production to remaining capacity and update withSector(...)
  }
}
```

Advance the timestamp once at the end; never per planet.

- [ ] **Step 5: Run GREEN and commit**

```sh
flutter test test/mining/mining_simulation_test.dart
```

Expected: PASS.

Commit:

```sh
git add lib/mining/mining_simulation.dart test/mining/mining_simulation_test.dart
git commit -m "feat(mining): accrue unlocked planets with technology"
```

---

### Task 4: Extend the serialized controller with technology, Lunar unlock, planet switching, and active-planet sell

**Files:**
- Modify: `lib/mining/mining_controller.dart`
- Modify: `test/mining/mining_controller_test.dart`

**Interfaces:**
- Consumes: Task 1 content/state helpers and Task 3 simulation.
- Produces: `purchaseTechnology`, `unlockPlanet`, `switchPlanet`, active-planet-only `sellAllCargo`.

- [ ] **Step 1: Add RED technology tests**

Cover success, insufficient cash, missing required mine, and max level. A successful purchase must change only the selected track and cash:

```dart
final result = await controller.purchaseTechnology(TechnologyTrack.extraction);
expect(result.isSuccess, isTrue);
expect(controller.state.technology.extraction, 1);
expect(controller.state.technology.logistics, 0);
expect(controller.state.cash, startingCash - 300);
```

- [ ] **Step 2: Add RED Lunar unlock tests**

Create an accrued candidate with all three Homeworld mines, Surveying 3, and 2,500 cash. Assert one mutation produces Lunar unlocked + active + cash 0. Add three independent failure tests for missing mastery, Surveying 2, and 2,499 cash; each must preserve state.

- [ ] **Step 3: Add RED active-planet sell and switch tests**

Put Gold cargo on Homeworld and Water Ice cargo on Lunar. With Homeworld active, `sellAllCargo()` must clear/credit Gold only and leave Water Ice unchanged. `switchPlanet(lunarFrontier)` must accrue first, persist active Lunar, and not reset `lastAccruedAtUtc` twice.

- [ ] **Step 4: Add RED overlap regression**

Reuse the existing Completer-backed repository pattern: start `switchPlanet`, then queue `sellAllCargo` or `purchaseTechnology`; release the first save and assert the second action starts from the first action’s committed state rather than stale pre-switch state.

- [ ] **Step 5: Run RED**

```sh
flutter test test/mining/mining_controller_test.dart
```

- [ ] **Step 6: Implement minimal serialized actions**

Use the existing `_enqueueMutation`. Add `TechnologyLevels.levelFor(track)` / `copyWithTrack(track, level)` if that keeps controller switches exhaustive and small; do not introduce commands.

Active sell must start with:

```dart
final candidate = simulation.accrue(_state, _nowUtc().toUtc());
final activePlanet = content.planet(candidate.state.activePlanetId);
var next = candidate.state;

for (final definition in activePlanet.sectors) {
  final progress = next.progressFor(content, definition.id);
  // accumulate, clear with next.withSector(...)
}
```

`revealSector` must additionally reject:

```dart
if (candidate.state.technology.surveying < definition.requiredSurveyingLevel) {
  return MiningActionResult.failure(
    'Requires Surveying ${definition.requiredSurveyingLevel}.',
  );
}
```

- [ ] **Step 7: Run GREEN and commit**

```sh
flutter test test/mining/mining_controller_test.dart
```

Expected: PASS.

Commit:

```sh
git add lib/mining/mining_controller.dart test/mining/mining_controller_test.dart
git commit -m "feat(mining): add technology and planet mutations"
```

---

### Task 5: Make every mining/progression affordance a pure active-planet view model

**Files:**
- Modify: `lib/mining/mining_sheet_view.dart`
- Create: `lib/mining/mining_progression_views.dart`
- Modify: `test/mining/mining_sheet_view_test.dart`
- Create: `test/mining/mining_progression_views_test.dart`

**Interfaces:**
- Consumes: state/content helpers and controller eligibility rules.
- Produces: active-planet `MiningSheetView`, `TechnologySheetView`, `TechnologyCardView`, `StellarMapView`, `StellarMapPlanetView`.

- [ ] **Step 1: Add RED `MiningSheetView` tests for wrong-planet prevention and effective values**

With Homeworld active and Lunar cargo present, sell view must report only Homeworld cargo. With Extraction 2, a level-1 Landing Basin mine must show `0.6/s` (`0.50 * 1.25` formatted to one decimal). With Logistics 2, its capacity must show `117.0`. Frozen Basin at Surveying 2 must show disabled reason `Requires Surveying 3.` even though reveal cost is zero.

- [ ] **Step 2: Add RED technology view tests**

Define concrete view types:

```dart
class TechnologyCardView {
  final TechnologyTrack track;
  final String title;
  final String currentEffect;
  final String? nextEffect;
  final int? nextCost;
  final bool purchaseEnabled;
  final String? disabledReason;
}

class TechnologySheetView {
  final List<TechnologyCardView> cards;
  factory TechnologySheetView.from({
    required MiningSave state,
    required MiningContentRegistry content,
    required bool isBusy,
  });
}
```

Test Extraction 2 copy exactly: current `production ×1.25`, next `production ×1.45`, cost `1500`, and `Requires Granite Crater mine.` when the level-3 access mine is absent.

- [ ] **Step 3: Add RED Stellar Map view tests**

Define two concrete card states and assert Lunar at Surveying 0 exposes three unmet conditions: Homeworld mastery, Surveying 3, and 2,500 cash. With all requirements satisfied, `unlockEnabled == true`. After unlock with Lunar active, Lunar is current and Homeworld exposes travel.

- [ ] **Step 4: Run RED**

```sh
flutter test test/mining/mining_sheet_view_test.dart test/mining/mining_progression_views_test.dart
```

- [ ] **Step 5: Implement pure models only**

`MiningSheetView._sellView` iterates:

```dart
final active = content.planet(state.activePlanetId);
for (final definition in active.sectors) {
  final mine = state.progressFor(content, definition.id).mine;
  // derive total and value
}
```

Rate/capacity strings use `effectiveRate`/`effectiveCapacity` and state technology. Reveal checks previous sector, Surveying, then cash in that order so the most actionable unmet requirement is stable.

`TechnologySheetView` and `StellarMapView` derive eligibility/copy only; no controller calls or Flutter imports.

- [ ] **Step 6: Run GREEN and commit**

```sh
flutter test test/mining/mining_sheet_view_test.dart test/mining/mining_progression_views_test.dart
```

Expected: PASS.

Commit:

```sh
git add lib/mining/mining_sheet_view.dart lib/mining/mining_progression_views.dart test/mining/mining_sheet_view_test.dart test/mining/mining_progression_views_test.dart
git commit -m "feat(mining): derive technology and planet affordances"
```

---

### Task 6: Add Technology/Stellar Map sheets and active-planet HUD chrome

**Files:**
- Create: `lib/mining/presentation/technology_sheet.dart`
- Create: `lib/mining/presentation/stellar_map_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `lib/mining/presentation/mining_status_bar.dart`
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`

**Interfaces:**
- Consumes: Task 5 pure views and Task 4 controller actions.
- Produces: reachable portrait UI for tech/map and planet-grouped return presentation; game replacement itself remains Task 7.

- [ ] **Step 1: Add RED Technology sheet interaction test**

Pump `MiningScreen` with a deterministic repository/clock, tap key `mining-technology-button`, assert three cards and exact derived copy, tap the enabled Extraction purchase button, await completion, and assert updated level/cash copy after sheet rebuild.

Use stable keys:

```text
mining-technology-button
technology-sheet
technology-extraction-card
technology-logistics-card
technology-surveying-card
technology-extraction-purchase
```

- [ ] **Step 2: Add RED Stellar Map visibility/requirements test**

At Surveying 0, key `mining-stellar-map-button` must be visible and open `stellar-map-sheet`. Assert Lunar card includes `Surveying 3`, Homeworld mastery progress, and `2,500 cash` requirement copy.

Use keys:

```text
stellar-map-homeworld-card
stellar-map-lunarFrontier-card
stellar-map-lunarFrontier-unlock
stellar-map-homeworld-travel
stellar-map-lunarFrontier-travel
```

- [ ] **Step 3: Add RED portrait geometry tests**

For 360×640 and 430×932, pump the screen and compare rectangles for status bar, sector tabs, progression-control row, and bottom action sheet. Assert no overlap and every progression/settings button has width/height at least 48 where applicable.

- [ ] **Step 4: Add RED grouped offline-return test**

Pass a summary containing Gold on Homeworld and Water Ice on Lunar. Assert one modal renders both planet headings and both resource names, plus the actual Logistics cap message (for example `Offline production was capped at 12 hours.`).

- [ ] **Step 5: Run RED**

```sh
flutter test test/mining/presentation/mining_screen_test.dart
```

- [ ] **Step 6: Implement the two modal widgets and screen callbacks**

`TechnologySheet` accepts the pure view and `Future<void> Function(TechnologyTrack)` callback. `StellarMapSheet` accepts pure view plus unlock/travel callbacks. Widgets do not recalculate domain eligibility.

In `MiningScreen`, add `_openTechnology`, `_openStellarMap`, `_purchaseTechnology`, `_unlockLunar`, and `_switchPlanet` wrappers. Each controller action follows the existing action pattern: start BGM from user gesture, show busy presentation, await, refresh, then show a concise result.

Update tabs/HUD/cargo to use only:

```dart
final activePlanet = _content.planet(_displayState.activePlanetId);
final activeProgress = _displayState.activePlanetProgress;
```

Update `OfflineReturnSheet` exhaustive resource names/colors for all six resources and group rows by planet.

- [ ] **Step 7: Run GREEN and commit**

```sh
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: PASS for sheets, copy, grouped return, and portrait chrome. Planet travel may update controller state while the Flame projection remains Task 7.

Commit:

```sh
git add lib/mining/presentation/technology_sheet.dart lib/mining/presentation/stellar_map_sheet.dart lib/mining/presentation/mining_screen.dart lib/mining/presentation/mining_status_bar.dart lib/mining/presentation/offline_return_sheet.dart test/mining/presentation/mining_screen_test.dart
git commit -m "feat(mining): add technology and stellar map UI"
```

---

### Task 7: Make planet switching replace only `MiningGame`, then land Lunar visuals/assets

**Files:**
- Modify: `lib/mining/world/mining_game.dart`
- Modify: `lib/mining/world/mining_components.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `lib/constants/assets_path.dart`
- Add: `assets/images/building/water_ice_mine.png`
- Add: `assets/images/building/titanium_mine.png`
- Add: `assets/images/building/helium3_extractor.png`
- Add: `assets/images/resource/water_ice.png`
- Add: `assets/images/resource/titanium_ore.png`
- Add: `assets/images/resource/helium3.png`
- Modify: `test/mining/world/mining_game_test.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`

**Interfaces:**
- Consumes: active planet definition/progress and successful Task 4 switch/unlock.
- Produces: `MiningGame` that owns exactly one planet and a tested `ValueKey(activePlanetId)` replacement boundary.

- [ ] **Step 1: Add RED world ownership tests**

Construct Homeworld game and Lunar game separately. Assert Homeworld exposes only Landing/Carbon/Granite and Lunar exposes only Frozen/Titanium/Helium. Assert terrain seeds are 631 and 638 respectively and Lunar atmosphere color differs from Homeworld.

Change `MiningGame.applyState` test fixtures to pass `MiningPlanetProgress`, never full `MiningSave`.

- [ ] **Step 2: Add RED replacement lifecycle test**

Use an injected `gameFactory` in `MiningScreen` that records every `MiningGame` instance. Pump Homeworld, unlock/switch Lunar, and assert:

```dart
expect(createdGames.length, 2);
expect(createdGames[0].planet.id, MiningPlanetId.homeworld);
expect(createdGames[1].planet.id, MiningPlanetId.lunarFrontier);
expect(
  tester.widget<GameWidget>(find.byKey(const ValueKey(MiningPlanetId.lunarFrontier))).game,
  same(createdGames[1]),
);
```

Capture the injected `AudioManager` and repository references and assert they are still the same objects. Advance one refresh tick after switch and assert no third game is created.

Trigger a sector selection/reward after switch and assert the new game’s selected/reward state changes while the old game’s recorded state does not.

- [ ] **Step 3: Add RED pre-onLoad state test**

Prevent the new game from losing the active snapshot when replacement occurs before `onLoad` completes. Give `MiningGame` an `initialProgress` constructor value and apply it after sector components are created:

```dart
MiningGame({
  required this.planet,
  required this.initialProgress,
});
```

Test a Lunar initial progress with Frozen Basin already revealed/built, mount the game, await load, and assert Frozen component shows that state without requiring an external second `applyState` call.

- [ ] **Step 4: Run RED**

```sh
flutter test test/mining/world/mining_game_test.dart test/mining/presentation/mining_screen_test.dart
```

- [ ] **Step 5: Implement one-planet `MiningGame` and atmosphere component**

Use:

```dart
class MiningGame extends FlameGame
    with flame_events.TapCallbacks, flame_events.ScaleDetector {
  MiningGame({
    required this.planet,
    required this.initialProgress,
  });

  final MiningPlanetDefinition planet;
  final MiningPlanetProgress initialProgress;
}
```

`onLoad` uses `planet.terrainSeed`, iterates only `planet.sectors`, then calls `applyState(initialProgress)` after sector components exist.

Add a small `MiningPlanetAtmosphereComponent` in mining components that draws a transparent world-sized overlay. Choose color directly from planet ID in `MiningGame`:

```dart
final atmosphereColor = switch (planet.id) {
  MiningPlanetId.homeworld => const Color(0x00000000),
  MiningPlanetId.lunarFrontier => const Color(0x183A5A78),
};
```

Add atmosphere after terrain and before sector components so it tints terrain but not facility art. Do not touch `BiomeRegistry` or `BiomeType`.

- [ ] **Step 6: Replace the game in `MiningScreen` only after successful active-planet change**

Change `late final MiningGame _game` to `late MiningGame _game`. Use an optional factory:

```dart
typedef MiningGameFactory = MiningGame Function(
  MiningPlanetDefinition planet,
  MiningPlanetProgress initialProgress,
);
```

The default factory constructs `MiningGame(planet: planet, initialProgress: initialProgress)`.

After successful unlock/travel:

```dart
_selectedSectorId = null;
_game = _gameFactory(
  _content.planet(_controller.state.activePlanetId),
  _controller.state.activePlanetProgress,
)..onSelectionChanged = _handleSelectionChanged;
_refreshPresentation();
```

Render:

```dart
GameWidget(
  key: ValueKey(_displayState.activePlanetId),
  game: _game,
)
```

Do not manually create another controller/audio manager/timer and do not add a custom game-disposal manager; the keyed old `GameWidget` unmount is the lifecycle boundary.

- [ ] **Step 7: Land concrete Lunar asset paths and files**

Add constants:

```dart
static const String waterIceMine = 'building/water_ice_mine.png';
static const String titaniumMine = 'building/titanium_mine.png';
static const String helium3Extractor = 'building/helium3_extractor.png';
static const String waterIceIcon = 'resource/water_ice.png';
static const String titaniumOreIcon = 'resource/titanium_ore.png';
static const String helium3Icon = 'resource/helium3.png';
```

Land six transparent PNGs at the exact listed paths. Facility art must be visually distinct from the deleted city-building leftovers and readable at the existing mining component size; resource icons must remain recognizable at 24–32 logical pixels. Wire the three Lunar sector definitions to the new facility assets.

- [ ] **Step 8: Run GREEN and commit**

```sh
flutter test test/mining/world/mining_game_test.dart test/mining/presentation/mining_screen_test.dart
```

Expected: PASS, including pre-onLoad state application and replacement identity tests.

Commit:

```sh
git add lib/mining/world/mining_game.dart lib/mining/world/mining_components.dart lib/mining/presentation/mining_screen.dart lib/constants/assets_path.dart assets/images/building/water_ice_mine.png assets/images/building/titanium_mine.png assets/images/building/helium3_extractor.png assets/images/resource/water_ice.png assets/images/resource/titanium_ore.png assets/images/resource/helium3.png test/mining/world/mining_game_test.dart test/mining/presentation/mining_screen_test.dart
git commit -m "feat(mining): launch the Lunar Frontier world"
```

---

### Task 8: Prove the two product journeys, update docs, and run the full gate

**Files:**
- Create: `test/integration/mining_multi_planet_journey_test.dart`
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Modify: `test/mining/mining_simulation_test.dart`
- Modify: `test/mining/mining_controller_test.dart`
- Modify: `test/mining/mining_sheet_view_test.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Modify: `test/mining/world/mining_game_test.dart`

**Interfaces:**
- Consumes: all HPA-638 behavior.
- Produces: end-to-end evidence, fully retargeted legacy fixtures, and updated repository guidance.

- [ ] **Step 1: Write the progression journey**

Use existing SharedPreferences/mock-clock/widget integration style. Seed a valid shipped-v1 document with all three Homeworld mines built and enough cash. Open `MiningScreen`, assert the stored document rewrites to current format, purchase Surveying through level 3 using cash, open Stellar Map, unlock Lunar, reveal Frozen Basin, build Water Ice, switch Homeworld, then reopen Stellar Map/Lunar and assert both planet progress records are preserved.

The test must assert the UI never exposes six sector tabs at once: Homeworld shows exactly its three sector tabs; Lunar shows exactly its three sector tabs.

- [ ] **Step 2: Write the two-planet idle journey**

Seed current-format state with Homeworld + Lunar unlocked and a built mine on each planet. Advance the injected UTC clock, initialize, and assert one grouped return sheet contains both planets. Dismiss, sell the active planet, switch, sell the second planet, and assert:

- first sale leaves second-planet cargo intact;
- second sale clears it;
- global cash equals starting cash + both floored sale revenues;
- no duplicate production appears from the switch.

- [ ] **Step 3: Run integration RED/GREEN until both journeys pass**

```sh
flutter test test/integration/mining_multi_planet_journey_test.dart
```

Expected final result: PASS.

- [ ] **Step 4: Retarget every remaining first-planet fixture to explicit planet APIs**

Search the changed test/runtime tree:

```sh
rg 'phaseOne\(|content\.sectors|state\.sectors|\.sectors\[' lib/mining test/mining test/integration
```

Expected after cleanup:

- no `MiningContentRegistry.phaseOne()`;
- no `content.sectors`;
- no `state.sectors`;
- `.sectors[...]` appears only when the code has already selected a concrete `MiningPlanetProgress` or authored `MiningPlanetDefinition`.

Convert remaining fixtures to `MiningContentRegistry.stellarMining()`, `state.progressFor(...)`, `state.withSector(...)`, `state.activePlanetProgress`, or explicit `content.planet(id).sectors` as appropriate. Do not add compatibility aliases just to keep old tests compiling.

- [ ] **Step 5: Update repository guidance**

Update `CLAUDE.md` ownership boundary to describe:

```text
MiningScreen
  -> one MiningController
      -> one MiningSimulation
      -> one MiningSaveRepository
  -> active MiningGame projection
```

Document the current exact save root keys, direct shipped-v1 conversion, technology effects, nested planet records, active-planet sell rule, and keyed game replacement. Explicitly remove the old statement that current root keys are `cash,lastAccruedAtUtc,sectors` and the old `phaseOne()`/flat-sector assumptions.

Update README core loop to:

```text
reveal -> build -> mine -> sell -> upgrade -> technology -> unlock planet
```

Keep README short; do not duplicate the full spec.

- [ ] **Step 6: Run all focused HPA-638 suites**

```sh
flutter test test/mining/mining_content_test.dart
flutter test test/mining/mining_state_test.dart
flutter test test/mining/mining_save_repository_test.dart
flutter test test/mining/mining_simulation_test.dart
flutter test test/mining/mining_controller_test.dart
flutter test test/mining/mining_sheet_view_test.dart
flutter test test/mining/mining_progression_views_test.dart
flutter test test/mining/presentation/mining_screen_test.dart
flutter test test/mining/world/mining_game_test.dart
flutter test test/integration/mining_multi_planet_journey_test.dart
```

Expected: all PASS.

- [ ] **Step 7: Run repository quality/build gates**

```sh
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Expected: all commands exit 0.

- [ ] **Step 8: Perform the representative portrait smoke**

On a representative portrait build, verify in order:

1. Technology sheet is understandable before buying anything.
2. Stellar Map is visible at Surveying 0 and explains Lunar requirements.
3. Surveying 3 + mastery + cash unlock Lunar in one action.
4. Lunar terrain/facilities/resources are visibly distinct from Homeworld.
5. Frozen Basin reveal → build uses the same primary interaction model.
6. Switching Homeworld/Lunar does not reset controller/audio state or duplicate production.
7. Leaving and returning shows one grouped two-planet production summary.
8. Reduced motion keeps unlock/reveal confirmations clear without relying on animation.

Record any balance-only tuning by changing authored numbers/tests in this same PR; do not add dynamic balance infrastructure.

- [ ] **Step 9: Final diff review and commit**

Confirm the final diff contains no `schemaVersion`, `MiningPlanetVisualTheme`, `content.sectors`, `state.sectors`, new state-management dependency, or generic planet/modifier framework.

Commit:

```sh
git add test/integration/mining_multi_planet_journey_test.dart CLAUDE.md README.md lib test
git commit -m "test(mining): prove multi-planet progression journeys"
```

Keep PR #16 draft until the repository gates and portrait smoke evidence are recorded.
