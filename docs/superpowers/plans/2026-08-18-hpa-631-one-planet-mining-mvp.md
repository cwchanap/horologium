# HPA-631 One-Planet Mining MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship and validate Horologium's complete one-planet mining-idle MVP: reveal fixed deposits, build and upgrade mines, accrue deterministic cargo, sell it for cash, reveal all three sectors, and restore capped offline production in a portrait-first Flutter/Flame experience.

**Architecture:** Add one isolated `lib/mining/` vertical slice beside the city runtime. Pure Dart content/state/simulation/save/controller/sheet-model code owns the mining rules; Flutter owns screen state, lifecycle and sheets; a separate Flame `MiningGame` owns world rendering, camera and effects. Reuse the existing `ResourceType`, `Assets`, terrain, audio preferences and icons, but do not reuse the city economy (`Resources`, `Building`, `GameStateManager`, `Planet`, `SaveService`).

**Tech Stack:** Dart 3.8+, Flutter 3.32.5, Flame 1.30, SharedPreferences 2.5, existing Flutter/Flame test infrastructure and existing terrain/mine/resource assets.

**Spec:** `docs/superpowers/specs/2026-08-18-hpa-631-one-planet-mining-mvp-design.md`

## Global Constraints

- Deliver HPA-631 in **one implementation PR** on `jack65786656/hpa-631-build-and-validate-the-one-planet-mining-mvp`.
- Linear HPA-630/HPA-631 are authoritative when older pivot documentation differs.
- Keep `Resources`, `Building`, `GameStateManager`, `Planet`, `ActivePlanet`, worker/research/quest systems, and `SaveService` out of mining economics and persistence.
- Reuse `ResourceType.gold|coal|stone`, `Assets.goldMine|coalMine|quarry`, `ResourceIcon`, `ParallaxTerrainComponent`, and `AudioManager` where useful.
- Keep immutable content separate from mutable mining progress.
- Cash is the only spendable currency.
- Landing Basin / Gold, Carbon Ridge / Coal, and Granite Crater / Stone share one typed domain path.
- Use five mine levels with visibly distinct presentation structures at levels 1, 3, and 5.
- Use elapsed UTC time as the production source of truth; cap offline production at 8 hours; clock rollback produces zero.
- Failed Reveal, Build, Upgrade, and Sell actions do not partially mutate in-memory or persisted state.
- Persist one strict JSON document at `horologium.mining.save`; there is no schema-version envelope, migration layer, backup rotation, or missing-sector default-fill in this first unshipped mining format.
- Do not write persistence on one-second foreground refreshes.
- `MiningController` stays plain Dart; do not add `ChangeNotifier`, Provider, Riverpod, Bloc, a command bus, or service locator.
- Derive contextual sheet affordance through pure `MiningSheetView.from(...)`, not inside widget `build()` logic.
- Flutter owns HUD/sheets/actions/lifecycle/recovery/offline summaries; Flame owns terrain/sectors/facilities/camera/effects.
- Copy only the minimum camera behavior needed from `MainGame`; do not extract a shared camera framework.
- Portrait is canonical. Primary touch actions are at least 56 logical px high. Automated layout checks cover 360×640 and 430×932.
- Primary actions remain understandable with audio disabled and with `MediaQueryData.disableAnimations == true`.
- No technology, second planet, processing, dynamic market, resource buying, worker/housing/service mechanics, cloud save, or generic framework work.

---

## File Map

### Create

```text
lib/mining/mining_content.dart
lib/mining/mining_state.dart
lib/mining/mining_simulation.dart
lib/mining/mining_save_repository.dart
lib/mining/mining_controller.dart
lib/mining/mining_sheet_view.dart
lib/mining/presentation/mining_screen.dart
lib/mining/presentation/mining_status_bar.dart
lib/mining/presentation/mining_action_sheet.dart
lib/mining/presentation/offline_return_sheet.dart
lib/mining/world/mining_game.dart
lib/mining/world/mining_components.dart

test/mining/mining_content_test.dart
test/mining/mining_simulation_test.dart
test/mining/mining_save_repository_test.dart
test/mining/mining_controller_test.dart
test/mining/mining_sheet_view_test.dart
test/mining/world/mining_game_test.dart
test/mining/presentation/mining_screen_test.dart
test/integration/mining_mvp_journey_test.dart
test/main_menu_test.dart
```

### Modify

```text
lib/main_menu.dart
```

Do not modify `pubspec.yaml`, CI workflows, `lib/game/main_game.dart`, `lib/game/scene_widget.dart`, `lib/game/resources/resources.dart`, `lib/game/building/`, `lib/game/planet/`, or `lib/game/services/save_service.dart` unless a concrete compile/runtime blocker is proven first.

---

## Task 1: Lock Typed Phase 1 Content and State

**Files:**
- Create: `lib/mining/mining_content.dart`
- Create: `lib/mining/mining_state.dart`
- Test: `test/mining/mining_content_test.dart`

**Interfaces:**
- Consumes: existing `ResourceType`, existing `Assets`.
- Produces: `MiningSectorId`, `MiningWorldAnchor`, `MiningSectorDefinition`, `MiningContentRegistry`, `MiningSave`, `SectorProgress`, `MineState`.
- Later tasks use sector IDs as the single identity; do not add deposit IDs.

- [ ] **Step 1: Write the failing content/state test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

void main() {
  test('phase one has exactly three typed sectors using existing identities', () {
    final content = MiningContentRegistry.phaseOne();

    expect(content.sectors.map((s) => s.id), MiningSectorId.values);
    expect(content.sector(MiningSectorId.landingBasin).resource, ResourceType.gold);
    expect(content.sector(MiningSectorId.landingBasin).mineAsset, Assets.goldMine);
    expect(content.sector(MiningSectorId.carbonRidge).resource, ResourceType.coal);
    expect(content.sector(MiningSectorId.carbonRidge).mineAsset, Assets.coalMine);
    expect(content.sector(MiningSectorId.graniteCrater).resource, ResourceType.stone);
    expect(content.sector(MiningSectorId.graniteCrater).mineAsset, Assets.quarry);
    expect(MiningContentRegistry.offlineCap, const Duration(hours: 8));
  });

  test('clean mining state reveals only Landing Basin', () {
    final now = DateTime.utc(2026, 8, 18, 12);
    final state = MiningSave.initial(nowUtc: now);

    expect(state.cash, 100);
    expect(state.lastAccruedAtUtc, now);
    expect(state.sectors.keys.toSet(), MiningSectorId.values.toSet());
    expect(state.sectors[MiningSectorId.landingBasin]!.revealed, isTrue);
    expect(state.sectors[MiningSectorId.carbonRidge]!.revealed, isFalse);
    expect(state.sectors[MiningSectorId.graniteCrater]!.revealed, isFalse);
    expect(state.sectors.values.every((p) => p.mine == null), isTrue);
  });
}
```

- [ ] **Step 2: Run it and confirm RED**

```bash
flutter test test/mining/mining_content_test.dart
```

Expected: FAIL because the mining core files do not exist.

- [ ] **Step 3: Implement the content table using existing `ResourceType` and `Assets`**

Create `lib/mining/mining_content.dart`:

```dart
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';

enum MiningSectorId { landingBasin, carbonRidge, graniteCrater }

class MiningWorldAnchor {
  const MiningWorldAnchor(this.x, this.y);
  final double x;
  final double y;
}

class MiningSectorDefinition {
  const MiningSectorDefinition({
    required this.id,
    required this.name,
    required this.resource,
    required this.mineAsset,
    required this.revealCost,
    required this.requiredSector,
    required this.buildCost,
    required this.baseRatePerSecond,
    required this.baseCapacity,
    required this.saleValuePerUnit,
    required this.upgradeCosts,
    required this.anchor,
  });

  final MiningSectorId id;
  final String name;
  final ResourceType resource;
  final String mineAsset;
  final int revealCost;
  final MiningSectorId? requiredSector;
  final int buildCost;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<int> upgradeCosts;
  final MiningWorldAnchor anchor;
}

class MiningContentRegistry {
  const MiningContentRegistry._(this.sectors);

  static const offlineCap = Duration(hours: 8);
  static const rateMultipliers = <double>[1.0, 1.5, 2.25, 3.25, 4.5];
  static const capacityMultipliers = <double>[1.0, 1.5, 2.0, 3.0, 4.0];

  final List<MiningSectorDefinition> sectors;

  factory MiningContentRegistry.phaseOne() => const MiningContentRegistry._([
        MiningSectorDefinition(
          id: MiningSectorId.landingBasin,
          name: 'Landing Basin',
          resource: ResourceType.gold,
          mineAsset: Assets.goldMine,
          revealCost: 0,
          requiredSector: null,
          buildCost: 50,
          baseRatePerSecond: 0.50,
          baseCapacity: 90,
          saleValuePerUnit: 4,
          upgradeCosts: [80, 160, 320, 640],
          anchor: MiningWorldAnchor(0.46, 0.72),
        ),
        MiningSectorDefinition(
          id: MiningSectorId.carbonRidge,
          name: 'Carbon Ridge',
          resource: ResourceType.coal,
          mineAsset: Assets.coalMine,
          revealCost: 250,
          requiredSector: MiningSectorId.landingBasin,
          buildCost: 100,
          baseRatePerSecond: 0.75,
          baseCapacity: 120,
          saleValuePerUnit: 3,
          upgradeCosts: [150, 300, 600, 1200],
          anchor: MiningWorldAnchor(0.28, 0.46),
        ),
        MiningSectorDefinition(
          id: MiningSectorId.graniteCrater,
          name: 'Granite Crater',
          resource: ResourceType.stone,
          mineAsset: Assets.quarry,
          revealCost: 700,
          requiredSector: MiningSectorId.carbonRidge,
          buildCost: 250,
          baseRatePerSecond: 0.60,
          baseCapacity: 120,
          saleValuePerUnit: 5,
          upgradeCosts: [350, 700, 1400, 2800],
          anchor: MiningWorldAnchor(0.68, 0.30),
        ),
      ]);

  MiningSectorDefinition sector(MiningSectorId id) =>
      sectors.singleWhere((sector) => sector.id == id);
}
```

Keep the values here. Do not read `BuildingRegistry` rows; city mine generation is worker-scaled and is not the mining economy.

- [ ] **Step 4: Implement immutable enum-keyed state with no deposit ID**

Create `lib/mining/mining_state.dart`:

```dart
import 'mining_content.dart';

class MineState {
  const MineState({required this.level, required this.storedAmount});
  final int level;
  final double storedAmount;

  MineState copyWith({int? level, double? storedAmount}) => MineState(
        level: level ?? this.level,
        storedAmount: storedAmount ?? this.storedAmount,
      );

  Map<String, Object?> toJson() => {
        'level': level,
        'storedAmount': storedAmount,
      };
}

class SectorProgress {
  const SectorProgress({required this.revealed, this.mine});
  final bool revealed;
  final MineState? mine;

  SectorProgress copyWith({
    bool? revealed,
    MineState? mine,
    bool clearMine = false,
  }) =>
      SectorProgress(
        revealed: revealed ?? this.revealed,
        mine: clearMine ? null : mine ?? this.mine,
      );

  Map<String, Object?> toJson() => {
        'revealed': revealed,
        'mine': mine?.toJson(),
      };
}

class MiningSave {
  const MiningSave({
    required this.cash,
    required this.lastAccruedAtUtc,
    required this.sectors,
  });

  final int cash;
  final DateTime lastAccruedAtUtc;
  final Map<MiningSectorId, SectorProgress> sectors;

  factory MiningSave.initial({required DateTime nowUtc}) => MiningSave(
        cash: 100,
        lastAccruedAtUtc: nowUtc.toUtc(),
        sectors: const {
          MiningSectorId.landingBasin: SectorProgress(revealed: true),
          MiningSectorId.carbonRidge: SectorProgress(revealed: false),
          MiningSectorId.graniteCrater: SectorProgress(revealed: false),
        },
      );

  MiningSave copyWith({
    int? cash,
    DateTime? lastAccruedAtUtc,
    Map<MiningSectorId, SectorProgress>? sectors,
  }) =>
      MiningSave(
        cash: cash ?? this.cash,
        lastAccruedAtUtc: lastAccruedAtUtc ?? this.lastAccruedAtUtc,
        sectors: Map.unmodifiable(sectors ?? this.sectors),
      );

  Map<String, Object?> toJson() => {
        'cash': cash,
        'lastAccruedAtUtc': lastAccruedAtUtc.toUtc().toIso8601String(),
        'sectors': sectors.map(
          (id, progress) => MapEntry(id.name, progress.toJson()),
        ),
      };
}
```

- [ ] **Step 5: Run GREEN**

```bash
flutter test test/mining/mining_content_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/mining/mining_content.dart lib/mining/mining_state.dart \
  test/mining/mining_content_test.dart
git commit -m "feat: add mining MVP content and state"
```

---

## Task 2: Implement Pure Elapsed-Time Production

**Files:**
- Create: `lib/mining/mining_simulation.dart`
- Test: `test/mining/mining_simulation_test.dart`

**Interfaces:**
- Consumes: `MiningContentRegistry`, `MiningSave`, `MiningSectorId`, `ResourceType`.
- Produces: `MiningSimulation`, `AccrualResult`, `OfflineProductionSummary`.
- No clocks are read inside the simulation; `nowUtc` is always supplied.

- [ ] **Step 1: Write failing deterministic-production tests**

```dart
MiningSave goldState(DateTime now, {double stored = 0, int level = 1}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(sectors: {
    ...base.sectors,
    MiningSectorId.landingBasin: SectorProgress(
      revealed: true,
      mine: MineState(level: level, storedAmount: stored),
    ),
  });
}

void main() {
  final content = MiningContentRegistry.phaseOne();
  final simulation = MiningSimulation(content);
  final start = DateTime.utc(2026, 8, 18, 12);

  test('level one gold produces five units in ten seconds', () {
    final result = simulation.accrue(
      goldState(start),
      start.add(const Duration(seconds: 10)),
    );
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      closeTo(5, 0.0001),
    );
  });

  test('storage caps production', () {
    final result = simulation.accrue(
      goldState(start, stored: 89),
      start.add(const Duration(minutes: 1)),
    );
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      90,
    );
    expect(result.summary.fullSectors, contains(MiningSectorId.landingBasin));
  });

  test('clock rollback produces zero and does not move timestamp backward', () {
    final state = goldState(start, stored: 10);
    final result = simulation.accrue(state, start.subtract(const Duration(hours: 1)));
    expect(result.state.toJson(), state.toJson());
    expect(result.summary.totalProduced, 0);
  });

  test('elapsed production is capped at eight hours and excess is discarded', () {
    final result = simulation.accrue(
      goldState(start),
      start.add(const Duration(hours: 12)),
    );
    expect(result.summary.elapsedUsed, const Duration(hours: 8));
    expect(result.summary.wasOfflineCapped, isTrue);
    expect(result.state.lastAccruedAtUtc, start.add(const Duration(hours: 12)));
  });

  test('level multipliers affect rate and capacity', () {
    expect(simulation.rateFor(MiningSectorId.landingBasin, 3), closeTo(1.125, 0.0001));
    expect(simulation.capacityFor(MiningSectorId.landingBasin, 3), 180);
  });
}
```

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/mining_simulation_test.dart
```

Expected: FAIL because simulation types do not exist.

- [ ] **Step 3: Implement pure result types and accrual**

```dart
import 'package:horologium/game/resources/resource_type.dart';

import 'mining_content.dart';
import 'mining_state.dart';

class OfflineProductionSummary {
  const OfflineProductionSummary({
    required this.elapsedUsed,
    required this.produced,
    required this.fullSectors,
    required this.wasOfflineCapped,
  });

  final Duration elapsedUsed;
  final Map<ResourceType, double> produced;
  final Set<MiningSectorId> fullSectors;
  final bool wasOfflineCapped;

  double get totalProduced =>
      produced.values.fold(0, (sum, value) => sum + value);
}

class AccrualResult {
  const AccrualResult({required this.state, required this.summary});
  final MiningSave state;
  final OfflineProductionSummary summary;
}

class MiningSimulation {
  const MiningSimulation(this.content);
  final MiningContentRegistry content;

  double rateFor(MiningSectorId id, int level) =>
      content.sector(id).baseRatePerSecond *
      MiningContentRegistry.rateMultipliers[level - 1];

  double capacityFor(MiningSectorId id, int level) =>
      content.sector(id).baseCapacity *
      MiningContentRegistry.capacityMultipliers[level - 1];

  AccrualResult accrue(MiningSave state, DateTime nowUtc) {
    final now = nowUtc.toUtc();
    final rawElapsed = now.difference(state.lastAccruedAtUtc);
    if (rawElapsed <= Duration.zero) {
      return AccrualResult(
        state: state,
        summary: const OfflineProductionSummary(
          elapsedUsed: Duration.zero,
          produced: {},
          fullSectors: {},
          wasOfflineCapped: false,
        ),
      );
    }

    final elapsed = rawElapsed > MiningContentRegistry.offlineCap
        ? MiningContentRegistry.offlineCap
        : rawElapsed;
    final sectors = <MiningSectorId, SectorProgress>{...state.sectors};
    final produced = <ResourceType, double>{};
    final full = <MiningSectorId>{};

    for (final definition in content.sectors) {
      final progress = sectors[definition.id]!;
      final mine = progress.mine;
      if (!progress.revealed || mine == null) continue;

      final capacity = capacityFor(definition.id, mine.level);
      final remaining = (capacity - mine.storedAmount).clamp(0.0, capacity);
      final amount = (rateFor(definition.id, mine.level) *
              elapsed.inMilliseconds /
              1000.0)
          .clamp(0.0, remaining);
      final stored = mine.storedAmount + amount;

      sectors[definition.id] = progress.copyWith(
        mine: mine.copyWith(storedAmount: stored),
      );
      produced.update(
        definition.resource,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
      if (stored >= capacity) full.add(definition.id);
    }

    return AccrualResult(
      state: state.copyWith(lastAccruedAtUtc: now, sectors: sectors),
      summary: OfflineProductionSummary(
        elapsedUsed: elapsed,
        produced: Map.unmodifiable(produced),
        fullSectors: Set.unmodifiable(full),
        wasOfflineCapped: rawElapsed > MiningContentRegistry.offlineCap,
      ),
    );
  }
}
```

- [ ] **Step 4: Add equal-input/equal-time regression coverage**

Call `accrue()` twice from the same serialized state and `nowUtc`; assert both next-state JSON values and summaries match. This is the single foreground/resume/cold-launch invariant.

- [ ] **Step 5: Run GREEN**

```bash
flutter test test/mining/mining_content_test.dart test/mining/mining_simulation_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/mining/mining_simulation.dart test/mining/mining_simulation_test.dart
git commit -m "feat: add deterministic mining production"
```

---

## Task 3: Persist One Strict Unversioned Mining Document

**Files:**
- Create: `lib/mining/mining_save_repository.dart`
- Test: `test/mining/mining_save_repository_test.dart`

**Interfaces:**
- Consumes: `MiningSave`, content, simulation capacity validation.
- Produces: `MiningSaveRepository.load`, `save`, `MiningLoadResult`.
- Writes only `horologium.mining.save`.

- [ ] **Step 1: Write failing repository tests**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';

void main() {
  const key = 'horologium.mining.save';
  final now = DateTime.utc(2026, 8, 18, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('missing save returns clean state without recovery warning', () async {
    final result = await MiningSaveRepository().load(nowUtc: now);
    expect(result.state.cash, 100);
    expect(result.recoveredFromInvalidSave, isFalse);
  });

  test('round trips the exact first-planet document', () async {
    final repository = MiningSaveRepository();
    final state = MiningSave.initial(nowUtc: now).copyWith(cash: 321);
    await repository.save(state);
    final loaded = await repository.load(nowUtc: now);
    expect(loaded.state.toJson(), state.toJson());
  });

  test('malformed JSON resets and reports recovery', () async {
    SharedPreferences.setMockInitialValues({key: '{not-json'});
    final result = await MiningSaveRepository().load(nowUtc: now);
    expect(result.state.cash, 100);
    expect(result.recoveredFromInvalidSave, isTrue);
  });

  test('legacy city keys are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'cash': 999999.0,
      'planet.earth.resources.cash': 888888.0,
      'buildings': <String>['1,1,Gold Mine'],
    });
    final result = await MiningSaveRepository().load(nowUtc: now);
    expect(result.state.cash, 100);
    expect(result.state.sectors[MiningSectorId.landingBasin]!.mine, isNull);
  });
}
```

Add table-driven reset cases for:

- negative/non-int cash;
- missing `cash`, `lastAccruedAtUtc`, or `sectors`;
- malformed/non-UTC timestamp;
- missing one of the three sector entries;
- unknown sector key;
- non-bool `revealed`;
- mine level outside 1–5;
- negative/non-numeric cargo;
- cargo above that sector's configured capacity.

Do **not** add a `schemaVersion` case, a `futureField` case, or a missing-sector default-fill case.

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/mining_save_repository_test.dart
```

Expected: FAIL because repository code does not exist.

- [ ] **Step 3: Implement strict decode helpers**

```dart
class MiningLoadResult {
  const MiningLoadResult({
    required this.state,
    required this.recoveredFromInvalidSave,
  });

  final MiningSave state;
  final bool recoveredFromInvalidSave;
}

class MiningSaveRepository {
  static const saveKey = 'horologium.mining.save';

  MiningSaveRepository({MiningContentRegistry? content})
      : content = content ?? MiningContentRegistry.phaseOne();

  final MiningContentRegistry content;

  Future<MiningLoadResult> load({required DateTime nowUtc}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(saveKey);
    if (raw == null) {
      return MiningLoadResult(
        state: MiningSave.initial(nowUtc: nowUtc),
        recoveredFromInvalidSave: false,
      );
    }

    try {
      return MiningLoadResult(
        state: _decode(jsonDecode(raw)),
        recoveredFromInvalidSave: false,
      );
    } catch (_) {
      return MiningLoadResult(
        state: MiningSave.initial(nowUtc: nowUtc),
        recoveredFromInvalidSave: true,
      );
    }
  }

  Future<void> save(MiningSave state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(saveKey, jsonEncode(state.toJson()));
  }
}
```

Inside `_decode`:

1. require a JSON object with exactly `cash`, `lastAccruedAtUtc`, `sectors`;
2. require the sector key set to equal `MiningSectorId.values.map((id) => id.name).toSet()`;
3. map each string to `MiningSectorId.values.singleWhere((id) => id.name == rawKey)` only after exact-key validation;
4. require each sector object to contain `revealed` and `mine`;
5. require mine `null` or exactly `{level, storedAmount}`;
6. validate mine level/cargo against that sector's capacity;
7. reject rather than clamp corrupt data.

Use a small helper:

```dart
bool hasExactKeys(Map<String, Object?> map, Set<String> expected) =>
    map.keys.toSet().length == expected.length &&
    map.keys.toSet().containsAll(expected);
```

No migration/version dispatch is added.

- [ ] **Step 4: Assert write scope**

After `save()`, inspect `SharedPreferences.getKeys()` and assert the only new mining key is `horologium.mining.save` and no city key changed.

- [ ] **Step 5: Run GREEN**

```bash
flutter test test/mining/mining_save_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/mining/mining_save_repository.dart test/mining/mining_save_repository_test.dart
git commit -m "feat: persist mining MVP state"
```

---

## Task 4: Add One Plain Atomic MiningController

**Files:**
- Create: `lib/mining/mining_controller.dart`
- Test: `test/mining/mining_controller_test.dart`

**Interfaces:**
- Consumes: content, simulation, repository, injectable UTC clock.
- Produces: plain controller state plus `MiningActionResult` and `MiningSaleResult`.
- Does not import Flutter or call `notifyListeners()`.

- [ ] **Step 1: Write failing action tests with a mutable clock**

```dart
class TestClock {
  TestClock(this.now);
  DateTime now;
  DateTime call() => now;
}

void main() {
  late TestClock clock;
  late MiningController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = TestClock(DateTime.utc(2026, 8, 18, 12));
    controller = MiningController(
      content: MiningContentRegistry.phaseOne(),
      repository: MiningSaveRepository(),
      nowUtc: clock.call,
    );
    await controller.initialize();
  });

  test('build validates before changing state', () async {
    final before = controller.state.toJson();
    final result = await controller.buildMine(MiningSectorId.carbonRidge);
    expect(result.isSuccess, isFalse);
    expect(controller.state.toJson(), before);
  });

  test('gold build deducts once and creates level one mine', () async {
    final result = await controller.buildMine(MiningSectorId.landingBasin);
    expect(result.isSuccess, isTrue);
    expect(controller.state.cash, 50);
    expect(
      controller.state.sectors[MiningSectorId.landingBasin]!.mine!.level,
      1,
    );
  });

  test('failed upgrade leaves accrued candidate unpublished', () async {
    await controller.buildMine(MiningSectorId.landingBasin);
    clock.now = clock.now.add(const Duration(seconds: 30));
    final before = controller.state.toJson();
    final result = await controller.upgradeMine(MiningSectorId.landingBasin);
    expect(result.isSuccess, isFalse); // 50 cash < 80
    expect(controller.state.toJson(), before);
  });
}
```

Add success/failure tests for Reveal, duplicate Build, Upgrade, max level, mixed-resource Sell All Cargo, zero-cargo sale, checkpoint, resume, and passive refresh.

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/mining_controller_test.dart
```

Expected: FAIL because the controller does not exist.

- [ ] **Step 3: Implement a plain controller**

```dart
class MiningController {
  MiningController({
    required this.content,
    required this.repository,
    required DateTime Function() nowUtc,
  })  : _nowUtc = nowUtc,
        simulation = MiningSimulation(content);

  final MiningContentRegistry content;
  final MiningSaveRepository repository;
  final MiningSimulation simulation;
  final DateTime Function() _nowUtc;

  late MiningSave _state;
  MiningSave get state => _state;

  bool recoveredFromInvalidSave = false;
  OfflineProductionSummary? _pendingReturnSummary;

  Future<void> initialize() async {
    final loaded = await repository.load(nowUtc: _nowUtc().toUtc());
    recoveredFromInvalidSave = loaded.recoveredFromInvalidSave;
    final accrued = simulation.accrue(loaded.state, _nowUtc().toUtc());
    _state = accrued.state;
    if (accrued.summary.totalProduced > 0) {
      _pendingReturnSummary = accrued.summary;
    }
  }

  AccrualResult refresh() {
    final accrued = simulation.accrue(_state, _nowUtc().toUtc());
    _state = accrued.state;
    return accrued;
  }
}
```

Do not save in `refresh()`.

- [ ] **Step 4: Implement one candidate/commit path**

```dart
AccrualResult _candidateNow() => simulation.accrue(_state, _nowUtc().toUtc());

Future<void> _commit(MiningSave next) async {
  await repository.save(next);
  _state = next;
}
```

Every explicit action:

1. gets `_candidateNow()`;
2. validates the action without assigning `_state`;
3. creates one new `MiningSave`;
4. awaits `_commit(next)` once;
5. returns a result carrying presentation data.

If validation fails, return before `_commit()` and leave both memory and persistence unchanged.

- [ ] **Step 5: Implement typed operations**

Use `MiningSectorId` for Reveal/Build/Upgrade. Do not accept string/deposit IDs.

For Sell All Cargo:

```dart
var revenue = 0;
final sold = <ResourceType, double>{};
final sectors = <MiningSectorId, SectorProgress>{...candidate.state.sectors};

for (final definition in content.sectors) {
  final progress = sectors[definition.id]!;
  final mine = progress.mine;
  if (mine == null || mine.storedAmount <= 0) continue;

  revenue += (mine.storedAmount * definition.saleValuePerUnit).floor();
  sold.update(
    definition.resource,
    (value) => value + mine.storedAmount,
    ifAbsent: () => mine.storedAmount,
  );
  sectors[definition.id] = progress.copyWith(
    mine: mine.copyWith(storedAmount: 0),
  );
}
```

If `revenue == 0`, return a non-mutating failure.

- [ ] **Step 6: Implement lifecycle helpers**

```dart
Future<void> checkpoint() async {
  final accrued = simulation.accrue(_state, _nowUtc().toUtc());
  await repository.save(accrued.state);
  _state = accrued.state;
}

Future<OfflineProductionSummary?> resume() async {
  final accrued = simulation.accrue(_state, _nowUtc().toUtc());
  _state = accrued.state;
  if (accrued.summary.totalProduced > 0) {
    _pendingReturnSummary = accrued.summary;
  }
  return takePendingReturnSummary();
}

OfflineProductionSummary? takePendingReturnSummary() {
  final value = _pendingReturnSummary;
  _pendingReturnSummary = null;
  return value;
}
```

Resume does not need a second automatic save; the preceding pause checkpoint, next explicit action, or next lifecycle checkpoint persists state. If the process dies first, deterministic cold launch recalculates from the last persisted timestamp.

- [ ] **Step 7: Prove refresh does not persist**

After one successful action, read the raw save payload, advance the clock, call `refresh()`, and assert the SharedPreferences payload is unchanged while controller state accrued.

- [ ] **Step 8: Run GREEN**

```bash
flutter test test/mining/mining_controller_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/mining/mining_controller.dart test/mining/mining_controller_test.dart
git commit -m "feat: add atomic mining controller"
```

---

## Task 5: Derive Contextual Sheet State in One Pure Model

**Files:**
- Create: `lib/mining/mining_sheet_view.dart`
- Test: `test/mining/mining_sheet_view_test.dart`

**Interfaces:**
- Consumes: `MiningSave`, `MiningContentRegistry`, `MiningSectorId?`.
- Produces: `MiningSheetView`, `MiningSheetAction`.
- No Flutter widgets, contexts, callbacks, or controller calls.

- [ ] **Step 1: Write failing view-model tests**

```dart
void main() {
  final content = MiningContentRegistry.phaseOne();
  final now = DateTime.utc(2026, 8, 18, 12);

  test('no selection exposes sell action but disables it with no cargo', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: null,
    );
    expect(view.action, MiningSheetAction.sell);
    expect(view.primaryLabel, 'SELL ALL CARGO');
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, isNotNull);
  });

  test('Carbon Ridge shows prerequisite while Landing Basin is unrevealed', () {
    final base = MiningSave.initial(nowUtc: now);
    final state = base.copyWith(sectors: {
      ...base.sectors,
      MiningSectorId.landingBasin: const SectorProgress(revealed: false),
    });
    final view = MiningSheetView.from(
      state: state,
      content: content,
      selectedSectorId: MiningSectorId.carbonRidge,
    );
    expect(view.action, MiningSheetAction.reveal);
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, contains('Landing Basin'));
  });

  test('revealed empty Landing Basin exposes Build Mine', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: MiningSectorId.landingBasin,
    );
    expect(view.action, MiningSheetAction.build);
    expect(view.primaryLabel, 'BUILD MINE');
    expect(view.primaryEnabled, isTrue);
  });
}
```

Add cases for insufficient cash, active mine upgrade, max level, and Sell All with mixed cargo.

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/mining_sheet_view_test.dart
```

Expected: FAIL because the pure sheet model does not exist.

- [ ] **Step 3: Implement the closed sheet model**

```dart
enum MiningSheetAction { sell, reveal, build, upgrade, none }

class MiningSheetView {
  const MiningSheetView({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.action,
    required this.primaryEnabled,
    this.disabledReason,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final MiningSheetAction action;
  final bool primaryEnabled;
  final String? disabledReason;

  static MiningSheetView from({
    required MiningSave state,
    required MiningContentRegistry content,
    required MiningSectorId? selectedSectorId,
  }) {
    if (selectedSectorId == null) {
      return _sellView(state, content);
    }

    final definition = content.sector(selectedSectorId);
    final progress = state.sectors[selectedSectorId]!;
    if (!progress.revealed) {
      return _revealView(state, content, definition);
    }
    if (progress.mine == null) {
      return _buildView(state, definition);
    }
    return _upgradeView(state, definition, progress.mine!);
  }
}
```

Keep the helper methods in this file. They may calculate affordability, rate/capacity display values, prerequisite names, and disabled reasons. They do not mutate state.

- [ ] **Step 4: Run GREEN**

```bash
flutter test test/mining/mining_sheet_view_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/mining/mining_sheet_view.dart test/mining/mining_sheet_view_test.dart
git commit -m "feat: derive mining action sheet state"
```

---

## Task 6: Add the Authored Flame World and Structural Tier Verification

**Files:**
- Create: `lib/mining/world/mining_game.dart`
- Create: `lib/mining/world/mining_components.dart`
- Test: `test/mining/world/mining_game_test.dart`

**Interfaces:**
- Consumes: content + read-only `MiningSave` snapshots.
- Produces: `MiningGame.applyState`, `focusOnSelection`, `playReward`, selection callback.
- Does not import controller, repository, `Resources`, `Building`, `Planet`, or `SaveService`.

- [ ] **Step 1: Write failing structural tier tests**

Do not stop at testing `MiningVisualTier.forLevel()`. Mount the real game and inspect the sector component after applying states.

```dart
Future<void> pumpMiningGame(WidgetTester tester, MiningGame game) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: GameWidget(game: game))),
  );
  for (var i = 0; i < 80 && !game.hasLoaded; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(game.hasLoaded, isTrue);
}

void main() {
  testWidgets('mounted mining game owns all three authored sectors', (tester) async {
    final game = MiningGame(content: MiningContentRegistry.phaseOne());
    await pumpMiningGame(tester, game);
    expect(game.sectorIds.toSet(), MiningSectorId.values.toSet());
  });

  testWidgets('levels one three and five add distinct visual structure', (tester) async {
    final content = MiningContentRegistry.phaseOne();
    final game = MiningGame(content: content);
    await pumpMiningGame(tester, game);

    final base = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 18, 12));

    MiningSave withGoldLevel(int level) => base.copyWith(sectors: {
          ...base.sectors,
          MiningSectorId.landingBasin: SectorProgress(
            revealed: true,
            mine: MineState(level: level, storedAmount: 0),
          ),
        });

    game.applyState(withGoldLevel(1));
    await tester.pump();
    final sector = game.sector(MiningSectorId.landingBasin);
    expect(sector.children.whereType<OperationLightComponent>(), hasLength(1));
    expect(sector.children.whereType<AdvancedPlatformComponent>(), isEmpty);
    expect(sector.children.whereType<EliteRingComponent>(), isEmpty);

    game.applyState(withGoldLevel(3));
    await tester.pump();
    expect(sector.children.whereType<AdvancedPlatformComponent>(), hasLength(1));
    expect(sector.children.whereType<SecondaryMachineryComponent>(), hasLength(1));
    expect(sector.children.whereType<EliteRingComponent>(), isEmpty);

    game.applyState(withGoldLevel(5));
    await tester.pump();
    expect(sector.children.whereType<AdvancedPlatformComponent>(), hasLength(1));
    expect(sector.children.whereType<SecondaryMachineryComponent>(), hasLength(1));
    expect(sector.children.whereType<EliteRingComponent>(), hasLength(1));
  });
}
```

This uses the `GameWidget` pumping style already proven indirectly by `test/game/scene_widget_test.dart`; `test/game/main_game_test.dart` is useful for injected camera/grid logic but does not boot `MainGame.onLoad()` itself.

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/world/mining_game_test.dart
```

Expected: FAIL because mining world classes do not exist.

- [ ] **Step 3: Implement tier marker/presentation components**

```dart
enum MiningVisualTier {
  base,
  advanced,
  elite;

  static MiningVisualTier forLevel(int level) => switch (level) {
        1 || 2 => MiningVisualTier.base,
        3 || 4 => MiningVisualTier.advanced,
        5 => MiningVisualTier.elite,
        _ => throw ArgumentError.value(level, 'level'),
      };
}

class OperationLightComponent extends PositionComponent {}
class AdvancedPlatformComponent extends PositionComponent {}
class SecondaryMachineryComponent extends PositionComponent {}
class EliteRingComponent extends PositionComponent {}
```

`MiningSectorComponent` loads the base mine sprite from `definition.mineAsset` and rebuilds these structural presentation children when mine level crosses tier boundaries. Do not add a `mineAssetFor()` mapping.

- [ ] **Step 4: Implement `MiningGame` with terrain reuse**

```dart
class MiningGame extends FlameGame with TapCallbacks, ScaleDetector {
  MiningGame({required this.content});

  final MiningContentRegistry content;
  final Map<MiningSectorId, MiningSectorComponent> _sectors = {};
  void Function(MiningSectorId?)? onSelectionChanged;
  bool reducedMotion = false;
  bool hasLoaded = false;

  List<MiningSectorId> get sectorIds => List.unmodifiable(_sectors.keys);
  MiningSectorComponent sector(MiningSectorId id) => _sectors[id]!;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;

    final terrain = ParallaxTerrainComponent(gridSize: 36, seed: 631)
      ..parallaxEnabled = false
      ..anchor = Anchor.center
      ..position = Vector2.zero();
    world.add(terrain);

    for (final definition in content.sectors) {
      final component = MiningSectorComponent(definition: definition);
      _sectors[definition.id] = component;
      world.add(component);
    }

    _fitCameraToWorld();
    hasLoaded = true;
  }

  void applyState(MiningSave state) {
    for (final definition in content.sectors) {
      _sectors[definition.id]!.applyProgress(state.sectors[definition.id]!);
    }
  }
}
```

Copy only the minimum fit/pan/zoom clamping behavior needed from `MainGame`; do not refactor the city camera.

- [ ] **Step 5: Add typed selection and camera focus**

```dart
void focusOnSelection({
  required MiningSectorId sectorId,
  required double bottomObscuredFraction,
});
```

Tapping a sector invokes `onSelectionChanged?.call(definition.id)`. Focus moves the selected anchor into the unobscured upper region and clamps to world bounds. Reduced motion snaps immediately.

Add a test that verifies a non-zero obscured fraction moves the camera target upward compared with centered focus.

- [ ] **Step 6: Run GREEN**

```bash
flutter test test/mining/world/mining_game_test.dart
```

Expected: PASS, including the level 1/3/5 structural assertions.

- [ ] **Step 7: Commit**

```bash
git add lib/mining/world test/mining/world/mining_game_test.dart
git commit -m "feat: add authored mining world"
```

---

## Task 7: Add Portrait MiningScreen and Temporary Menu Entry

**Files:**
- Create: `lib/mining/presentation/mining_screen.dart`
- Create: `lib/mining/presentation/mining_status_bar.dart`
- Create: `lib/mining/presentation/mining_action_sheet.dart`
- Test: `test/mining/presentation/mining_screen_test.dart`
- Test: `test/main_menu_test.dart`
- Modify: `lib/main_menu.dart`

**Interfaces:**
- Consumes: plain controller, pure `MiningSheetView`, `MiningGame`.
- `MiningActionSheet` renders a view model + one callback; it does not derive economy rules.

- [ ] **Step 1: Write failing responsive-screen tests**

Pump 360×640 and 430×932 with deterministic SharedPreferences/clock. Assert:

```dart
expect(find.text('Landing Basin'), findsWidgets);
expect(find.text('SELL ALL CARGO'), findsOneWidget);
expect(tester.takeException(), isNull);

final size = tester.getSize(find.byKey(const Key('mining-primary-action')));
expect(size.height, greaterThanOrEqualTo(56));
```

Select Landing Basin and assert `BUILD MINE`; build and assert Level/Upgrade state. Assert status never displays Population, Workers, Happiness, or Research.

- [ ] **Step 2: Write the menu-entry test**

```dart
expect(find.text('START EXPEDITION'), findsOneWidget);
expect(find.text('MINING MVP'), findsOneWidget);
```

Tap **MINING MVP** and verify `MiningScreen` appears while city Start remains unchanged.

- [ ] **Step 3: Run RED**

```bash
flutter test test/mining/presentation/mining_screen_test.dart test/main_menu_test.dart
```

Expected: FAIL because presentation/menu entry do not exist.

- [ ] **Step 4: Implement the status bar**

```dart
class MiningStatusBar extends StatelessWidget {
  const MiningStatusBar({
    super.key,
    required this.cash,
    required this.revealedSectors,
    required this.totalSectors,
    required this.cargoValue,
  });

  final int cash;
  final int revealedSectors;
  final int totalSectors;
  final int cargoValue;
}
```

Render Cash, Sectors, Cargo only.

- [ ] **Step 5: Implement a dumb action-sheet renderer**

```dart
class MiningActionSheet extends StatelessWidget {
  const MiningActionSheet({
    super.key,
    required this.view,
    required this.onPrimaryAction,
  });

  final MiningSheetView view;
  final VoidCallback onPrimaryAction;
}
```

Use `SizedBox(height: 56, width: double.infinity)` with key `mining-primary-action`. Disabled actions render `view.disabledReason`; they do not recompute affordability.

- [ ] **Step 6: Implement plain-controller screen ownership**

```dart
class MiningScreen extends StatefulWidget {
  const MiningScreen({super.key, this.nowUtc});
  final DateTime Function()? nowUtc;

  @override
  State<MiningScreen> createState() => _MiningScreenState();
}

class _MiningScreenState extends State<MiningScreen>
    with WidgetsBindingObserver {
  late final MiningContentRegistry _content;
  late final MiningController _controller;
  late final MiningGame _game;
  Timer? _refreshTimer;
  MiningSectorId? _selectedSectorId;
  late MiningSheetView _sheetView;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _content = MiningContentRegistry.phaseOne();
    _controller = MiningController(
      content: _content,
      repository: MiningSaveRepository(content: _content),
      nowUtc: widget.nowUtc ?? () => DateTime.now().toUtc(),
    );
    _game = MiningGame(content: _content)
      ..onSelectionChanged = _onSelectionChanged;
    _initialize();
  }
}
```

After initialization, set `_sheetView = MiningSheetView.from(...)`, apply controller state to the game, and start a one-second timer.

Use one helper after any controller state/selection change:

```dart
void _refreshPresentation() {
  _game.applyState(_controller.state);
  _sheetView = MiningSheetView.from(
    state: _controller.state,
    content: _content,
    selectedSectorId: _selectedSectorId,
  );
  if (mounted) setState(() {});
}
```

The timer calls `_controller.refresh(); _refreshPresentation();` and never persistence.

- [ ] **Step 7: Route the pure action enum to typed controller calls**

`MiningScreen` switches on `_sheetView.action`. For Reveal/Build/Upgrade, require `_selectedSectorId` and call the corresponding controller method. Sell calls `sellAllCargo()`.

After an awaited success:

1. call `_refreshPresentation()`;
2. show visible success text/number change;
3. call `_game.playReward(...)` for the selected/affected sector(s).

On failure, display the controller result reason. Do not derive a second affordability/prerequisite rule in the widget.

- [ ] **Step 8: Add the temporary menu entry**

```dart
import 'package:horologium/mining/presentation/mining_screen.dart';
```

Add near **START EXPEDITION**:

```dart
_buildMenuButton(
  'MINING MVP',
  Icons.precision_manufacturing,
  () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const MiningScreen()),
  ),
),
```

Do not rename/reroute **START EXPEDITION**.

- [ ] **Step 9: Run GREEN**

```bash
flutter test test/mining/mining_sheet_view_test.dart \
  test/mining/presentation/mining_screen_test.dart \
  test/main_menu_test.dart
```

Expected: PASS with no portrait overflow.

- [ ] **Step 10: Commit**

```bash
git add lib/mining/presentation lib/main_menu.dart \
  test/mining/presentation/mining_screen_test.dart test/main_menu_test.dart
git commit -m "feat: add mining MVP screen"
```

---

## Task 8: Complete Lifecycle, Offline Return, Rewards, and Accessibility

**Files:**
- Create: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `lib/mining/world/mining_game.dart`
- Modify: `lib/mining/world/mining_components.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Modify: `test/mining/world/mining_game_test.dart`

**Interfaces:**
- Consumes controller results + `OfflineProductionSummary`.
- Effects remain presentation-only and run after committed success.

- [ ] **Step 1: Add failing lifecycle/recovery/reduced-motion tests**

Test:

1. active gold mine is persisted;
2. pause/checkpoint;
3. clock advances;
4. resume/recreate;
5. one offline sheet reports Gold production;
6. dismiss and rebuild does not show it again;
7. malformed mining JSON causes one non-blocking recovery `SnackBar`;
8. `MediaQueryData(disableAnimations: true)` still gives visible Build/Reveal/Upgrade/Sell confirmation.

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: FAIL because lifecycle/reward behavior is incomplete.

- [ ] **Step 3: Implement `OfflineReturnSheet`**

Render:

- elapsed duration actually used;
- non-zero Gold/Coal/Stone produced;
- storage-full notes for `fullSectors`;
- offline-limit note when capped;
- one next-action hint.

No claim button; cargo is already authoritative state.

- [ ] **Step 4: Wire pause/resume**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.inactive:
    case AppLifecycleState.paused:
      _refreshTimer?.cancel();
      unawaited(_controller.checkpoint());
      break;
    case AppLifecycleState.resumed:
      unawaited(_resumeMining());
      break;
    default:
      break;
  }
  _audioManager.handleLifecycleChange(state);
}
```

`_resumeMining()` calls `controller.resume()`, refreshes presentation, shows the returned summary once, and restarts the timer. Cold initialization consumes `takePendingReturnSummary()` after first frame.

- [ ] **Step 5: Show invalid-save recovery once**

After initialize, when `controller.recoveredFromInvalidSave` is true, schedule one `SnackBar`:

```text
Mining progress could not be loaded, so a fresh mining save was started.
```

- [ ] **Step 6: Implement four reward effects**

```dart
enum MiningRewardEffect { reveal, construction, tierUpgrade, sale }
```

`MiningGame.playReward(effect, sectorId)`:

- reveal: scanner line/ring + fog fade;
- construction: facility scale/fade + dust/glow;
- tier upgrade: pulse the newly added level 3/5 structural children;
- sale: short cargo/particle movement toward HUD direction.

No effect completion is awaited before economic success.

- [ ] **Step 7: Add reduced-motion branches**

```dart
_game.reducedMotion = MediaQuery.of(context).disableAnimations;
```

When true, use fades/number changes and snapped/short camera movement. Keep visible text confirmation identical.

- [ ] **Step 8: Add optional success haptics**

Call `HapticFeedback.lightImpact()` or `mediumImpact()` after successful primary actions. Do not await it and do not add a platform abstraction.

- [ ] **Step 9: Strengthen world tests after reward implementation**

Re-run structural assertions after `playReward` and reduced-motion state changes. Ensure tier children remain based on authoritative `MiningSave`, not effect timing.

- [ ] **Step 10: Run GREEN**

```bash
flutter test test/mining/world/mining_game_test.dart \
  test/mining/presentation/mining_screen_test.dart
```

Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/mining/presentation lib/mining/world \
  test/mining/presentation/mining_screen_test.dart \
  test/mining/world/mining_game_test.dart
git commit -m "feat: complete mining return and reward UX"
```

---

## Task 9: Prove the Complete First-Session and Offline-Return Journey

**Files:**
- Create: `test/integration/mining_mvp_journey_test.dart`
- Modify mining source only for testability bugs proven by this journey.

**Interfaces:**
- Exercises menu → real screen → pure sheet model → controller → simulation → persistence → world together.
- Uses visible UI + injected time only; no controller shortcuts.

- [ ] **Step 1: Write the journey test**

```dart
await tester.tap(find.text('MINING MVP'));
await tester.pumpAndSettle();

await tester.tap(find.text('Landing Basin').first);
await tester.tap(find.text('BUILD MINE'));
await tester.pump();

clock.now = clock.now.add(const Duration(minutes: 2));
await tester.pump(const Duration(seconds: 1));
await tester.tap(find.text('SELL ALL CARGO'));
await tester.pump();

await tester.tap(find.text('UPGRADE'));
await tester.pump();
```

Continue earning/selling through visible controls until Carbon Ridge is revealed/built, then Granite Crater is revealed/built. Do not inject cash or call controller methods.

- [ ] **Step 2: Verify mixed-cargo sale**

Through visible UI state, verify:

- all three mines exist;
- gold mine has upgraded;
- more than one resource contributes cargo value;
- one **SELL ALL CARGO** clears every active mine's cargo and increases cash once.

- [ ] **Step 3: Verify offline return against the pure simulation**

After a persisted checkpoint:

1. read `horologium.mining.save` without modifying it;
2. advance clock by two hours;
3. recreate `MiningScreen`;
4. verify the offline summary appears;
5. compare restored storage to `MiningSimulation.accrue(savedState, T1)`;
6. separately prove 12 hours uses at most 8 hours before storage caps.

- [ ] **Step 4: Run RED/GREEN on the integration seam**

```bash
flutter test test/integration/mining_mvp_journey_test.dart
```

Expected first run: a concrete integration failure or PASS if all seams align. If it fails, fix only the demonstrated seam and keep the same production path.

- [ ] **Step 5: Run all mining tests together**

```bash
flutter test test/mining test/integration/mining_mvp_journey_test.dart test/main_menu_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add test/integration/mining_mvp_journey_test.dart lib/mining
git commit -m "test: cover complete mining MVP journey"
```

Only source files actually changed for a proven integration gap belong in this commit.

---

## Task 10: Run Repository Verification and Record Product Evidence

**Files:**
- No planned source changes.
- Linear HPA-631 gets the final review comment only after implementation/playtest evidence exists.

- [ ] **Step 1: Run formatting**

```bash
dart format --output=none --set-exit-if-changed .
```

Expected: exit 0.

- [ ] **Step 2: Run static analysis**

```bash
flutter analyze --fatal-infos
```

Expected: exit 0.

- [ ] **Step 3: Run the full test suite with coverage**

```bash
flutter test --coverage
```

Expected: exit 0.

- [ ] **Step 4: Run the web test target already used by CI**

```bash
flutter test --reporter=expanded --platform chrome
```

Expected: exit 0.

- [ ] **Step 5: Build representative artifacts**

```bash
flutter build apk --debug
flutter build web
```

Expected: both exit 0.

On macOS with the normal iOS toolchain, also run the development build used for the portrait playtest. This is acceptance evidence, not a new CI job.

- [ ] **Step 6: Perform narrow/tall portrait smoke**

Verify on representative portrait targets:

- fresh player identifies gold and builds within one minute;
- selected sector stays visible above the sheet;
- primary actions are comfortable to tap;
- scanner/build/upgrade/sale rewards are readable;
- levels 1/3/5 are visibly different in actual rendering;
- audio-off still confirms success;
- reduced-motion remains understandable;
- return summary makes the next useful action obvious;
- no city page is required for the mining loop.

Record device/simulator, OS/runtime, build SHA, first-mine/first-sale timing, and observations.

- [ ] **Step 7: Verify the isolation boundary with a narrow grep**

Allow `game/resources/resource_type.dart`; reject actual city economy dependencies:

```bash
grep -R -E \
  "game/(building|managers/game_state_manager|services/save_service|planet)|game/resources/resources\.dart" \
  lib/mining || true
```

Expected: no output.

Also verify no listener framework slipped in:

```bash
grep -R "ChangeNotifier\|notifyListeners" lib/mining || true
```

Expected: no output.

- [ ] **Step 8: Check the spec acceptance list line by line**

Use `docs/superpowers/specs/2026-08-18-hpa-631-one-planet-mining-mvp-design.md`. Do not substitute “tests passed” for the portrait/product evidence items.

- [ ] **Step 9: Post the HPA-631 product conclusion**

After human/product review, add exactly one decision:

```text
Reviewed build: <commit SHA>
Device/runtime: <actual device or simulator>
Observed opening loop: <measured first-mine and first-sale notes>
Offline-return notes: <observations>
Visual/reward notes: <observations>
Decision: Proceed to cutover | Revise once | Stop/reconsider
```

Do not start HPA-636 unless the decision is **Proceed to cutover**.

- [ ] **Step 10: Fix any verification gap in the same PR**

If verification reveals a real bug, add its regression test, fix it on this branch, and commit:

```bash
git add <changed source and tests>
git commit -m "fix: close mining MVP verification gap"
```

Do not create a second PR.

---

## Plan Self-Review

### Spec coverage

- Three typed sectors, reused resource/assets, five levels: Tasks 1 and 6.
- Deterministic production, rollback/storage/8-hour cap: Task 2.
- Strict single document, invalid reset, no speculative compatibility: Task 3.
- Atomic Reveal/Build/Upgrade/Sell with plain controller: Task 4.
- Pure action-sheet derivation outside widgets: Task 5.
- Mounted Flame world + structural level 1/3/5 proof + copied camera: Task 6.
- Portrait UI, typed actions, temporary menu entry: Task 7.
- Offline return/recovery/reduced motion/four reward moments: Task 8.
- Real first-session + three-sector + mixed-sale + offline journey: Task 9.
- Format/analyze/tests/web/APK/build/manual/isolation/product decision: Task 10.

### Placeholder scan

There are no `TBD`, `TODO`, “similar to another task”, future compatibility hooks, missing sector defaults, schema migration steps, generic “add tests” steps, or unspecified framework seams.

### Type consistency

- `MiningSectorId` is the single sector/deposit identity across content, state, persistence, controller, sheet, and world.
- `ResourceType` is reused for Gold/Coal/Stone identity and production summaries.
- `MiningSave` is the single mutable-progress document; there is no `MiningSaveV2`.
- `MineState` is only `{level, storedAmount}`.
- `MiningController` is plain Dart and is the sole mutation boundary exposed to `MiningScreen`.
- `MiningSheetView` is pure derived presentation state.
- `MiningGame.applyState()` consumes read-only snapshots and owns no economics.

## Execution Handoff

Implement this plan on the existing HPA-631 branch and draft PR #14. Keep all implementation and review fixes in that one PR unless the user explicitly changes the delivery policy.
