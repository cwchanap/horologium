# HPA-631 One-Planet Mining MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship and validate Horologium's complete one-planet mining-idle MVP: reveal fixed deposits, build and upgrade mines, accrue deterministic cargo, sell it for cash, reveal all three sectors, and restore capped offline production in a portrait-first Flutter/Flame experience.

**Architecture:** Add one isolated `lib/mining/` vertical slice beside the city runtime. Pure Dart content/state/simulation/save/controller/sheet-model code owns mining rules; Flutter owns screen state, lifecycle and sheets; a separate Flame `MiningGame` owns world rendering, camera and effects. Reuse existing `ResourceType`, `Assets`, `ResourceIcon`, terrain, audio preferences, and camera math, but do not reuse the city economy (`Resources`, `Building`, `GameStateManager`, `Planet`, `ActivePlanet`, `SaveService`). Serialize every asynchronous mining mutation through one controller future chain.

**Tech Stack:** Dart 3.8+, Flutter 3.32.5, Flame 1.30, SharedPreferences 2.5, existing Flutter/Flame test infrastructure, existing terrain/mine/resource assets.

**Spec:** `docs/superpowers/specs/2026-08-18-hpa-631-one-planet-mining-mvp-design.md`

## Global Constraints

- Deliver HPA-631 in **one implementation PR** on `jack65786656/hpa-631-build-and-validate-the-one-planet-mining-mvp`.
- Linear HPA-630/HPA-631 are authoritative when older pivot documentation differs.
- Keep `Resources`, `Building`, `GameStateManager`, `Planet`, `ActivePlanet`, worker/research/quest systems, and `SaveService` out of mining economics and persistence.
- Reuse `ResourceType.gold|coal|stone`, `Assets.goldMine|coalMine|quarry`, `ResourceIcon`, `ParallaxTerrainComponent`, and `AudioManager`.
- Use `MiningSectorId` as the only Phase 1 sector/deposit identity.
- Keep immutable content separate from mutable progress.
- Cash is the only spendable currency.
- Use five mine levels with visibly distinct structures at levels 1, 3, and 5.
- Use elapsed UTC time as production truth; cap offline production at 8 hours; clock rollback produces zero.
- Serialize async Reveal/Build/Upgrade/Sell/checkpoint/resume operations; a successful mutation must never be overwritten by a concurrent call.
- Do not persist one-second foreground refreshes.
- Persist one strict unversioned JSON document at `horologium.mining.save`; no schema migration, backup rotation, legacy conversion, or speculative future-field handling.
- Structural save corruption resets; positive stored cargo above newly tuned capacity clamps to current capacity without a recovery warning.
- `MiningController` stays plain Dart; no `ChangeNotifier`, Provider, Riverpod, Bloc, command bus, or service locator.
- Derive contextual sheet affordance through pure `MiningSheetView.from(...)`, including busy state and tiny-sale copy.
- Floor Sell All Cargo once on the total gross value, not once per sector.
- Flutter owns HUD/sheets/actions/lifecycle/recovery/offline summaries; Flame owns terrain/sectors/facilities/camera/effects.
- Mining world geometry is 36×36 terrain cells × 50 world px = 1800×1800, centered at world origin.
- Explicitly size terrain before camera-fit math; do not depend on asynchronous terrain `onLoad()` ordering.
- Copy only minimum camera behavior from `MainGame`; no shared camera framework.
- Portrait is canonical. Primary touch actions are at least 56 logical px. Automated layout checks cover 360×640 and 430×932 for both `MiningScreen` and the modified `MainMenu`.
- Primary actions remain understandable with audio disabled and `MediaQueryData.disableAnimations == true`.
- Stop after the Task 7 portrait playtest if the core loop is not worth finishing.
- No technology, second planet, processing, dynamic market, resource buying, worker/housing/service mechanics, cloud save, or generic framework work.

---

## Risks and Gates

| Risk | Mitigation / proof |
| --- | --- |
| Overlapping async actions compute from stale state | One controller future chain + `isBusy`; delayed-save and double-action tests in Task 4 |
| Balance tuning makes a valid playtest save look corrupt | Structural reset vs current-capacity clamp split in Task 3 |
| Terrain size/anchor units produce a blank or badly fitted portrait world | Explicit 1800×1800 world-pixel contract + terrain sizing before fit + initial-visibility test in Task 6 |
| Product invalidation arrives only after polish work | Mandatory real-device stop/continue gate after Task 7 |
| Per-sector rounding or tiny cargo makes selling confusing | Sum gross value, floor once; pure sheet disables sub-1-cash sales |
| Sixth menu button overflows small portrait screens | 360×640 and 430×932 menu tests in Task 7 |

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

Do not modify `pubspec.yaml`, CI workflows, `lib/game/main_game.dart`, `lib/game/scene_widget.dart`, `lib/game/resources/resources.dart`, `lib/game/building/`, `lib/game/planet/`, or `lib/game/services/save_service.dart` unless a concrete compile/runtime blocker is demonstrated first.

---

## Task 1: Lock Typed Content, State, and World Units

**Files:**
- Create: `lib/mining/mining_content.dart`
- Create: `lib/mining/mining_state.dart`
- Test: `test/mining/mining_content_test.dart`

**Interfaces:**
- Consumes: existing `ResourceType`, `Assets`.
- Produces: `MiningSectorId`, `MiningWorldAnchor`, `MiningSectorDefinition`, `MiningContentRegistry`, `MiningSave`, `SectorProgress`, `MineState`.
- Later tasks use sector IDs as the sole mining identity.

- [ ] **Step 1: Write the failing content/state/world-contract test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

void main() {
  test('phase one reuses existing resource and mine identities', () {
    final content = MiningContentRegistry.phaseOne();

    expect(content.sectors.map((s) => s.id), MiningSectorId.values);
    expect(content.sector(MiningSectorId.landingBasin).resource, ResourceType.gold);
    expect(content.sector(MiningSectorId.landingBasin).mineAsset, Assets.goldMine);
    expect(content.sector(MiningSectorId.carbonRidge).resource, ResourceType.coal);
    expect(content.sector(MiningSectorId.carbonRidge).mineAsset, Assets.coalMine);
    expect(content.sector(MiningSectorId.graniteCrater).resource, ResourceType.stone);
    expect(content.sector(MiningSectorId.graniteCrater).mineAsset, Assets.quarry);
  });

  test('world units are explicit and every authored anchor is in bounds', () {
    final content = MiningContentRegistry.phaseOne();
    expect(MiningContentRegistry.terrainGridSize, 36);
    expect(MiningContentRegistry.terrainCellSize, 50);
    expect(MiningContentRegistry.worldExtent, 1800);
    expect(MiningContentRegistry.worldHalfExtent, 900);

    for (final sector in content.sectors) {
      expect(sector.anchor.x, inInclusiveRange(-900, 900));
      expect(sector.anchor.y, inInclusiveRange(-900, 900));
    }
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

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/mining_content_test.dart
```

Expected: FAIL because mining core files do not exist.

- [ ] **Step 3: Implement the content table with explicit world-pixel anchors**

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

  static const int terrainGridSize = 36;
  static const double terrainCellSize = 50;
  static const double worldExtent = terrainGridSize * terrainCellSize;
  static const double worldHalfExtent = worldExtent / 2;
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
          anchor: MiningWorldAnchor(-72, 396),
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
          anchor: MiningWorldAnchor(-396, -72),
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
          anchor: MiningWorldAnchor(324, -360),
        ),
      ]);

  MiningSectorDefinition sector(MiningSectorId id) =>
      sectors.singleWhere((sector) => sector.id == id);

  double rateFor(MiningSectorId id, int level) =>
      sector(id).baseRatePerSecond * rateMultipliers[level - 1];

  double capacityFor(MiningSectorId id, int level) =>
      sector(id).baseCapacity * capacityMultipliers[level - 1];
}
```

The anchor comment in the file must state: **world-pixel offset from centered 1800×1800 terrain origin**.

- [ ] **Step 4: Implement immutable enum-keyed state**

```dart
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

  SectorProgress copyWith({bool? revealed, MineState? mine, bool clearMine = false}) =>
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
  }) => MiningSave(
        cash: cash ?? this.cash,
        lastAccruedAtUtc: lastAccruedAtUtc ?? this.lastAccruedAtUtc,
        sectors: Map.unmodifiable(sectors ?? this.sectors),
      );

  Map<String, Object?> toJson() => {
        'cash': cash,
        'lastAccruedAtUtc': lastAccruedAtUtc.toUtc().toIso8601String(),
        'sectors': sectors.map((id, progress) => MapEntry(id.name, progress.toJson())),
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
  });

  test('clock rollback produces zero and does not move time backward', () {
    final state = goldState(start, stored: 10);
    final result = simulation.accrue(state, start.subtract(const Duration(minutes: 1)));
    expect(result.state.toJson(), state.toJson());
    expect(result.summary.totalProduced, 0);
  });

  test('twelve hours uses at most the eight hour cap', () {
    final result = simulation.accrue(
      goldState(start),
      start.add(const Duration(hours: 12)),
    );
    expect(result.summary.elapsedUsed, const Duration(hours: 8));
    expect(result.summary.wasOfflineCapped, isTrue);
  });
}
```

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/mining_simulation_test.dart
```

Expected: FAIL because simulation classes do not exist.

- [ ] **Step 3: Implement pure accrual and summary**

```dart
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

  double get totalProduced => produced.values.fold(0, (sum, value) => sum + value);
}

class AccrualResult {
  const AccrualResult({required this.state, required this.summary});
  final MiningSave state;
  final OfflineProductionSummary summary;
}

class MiningSimulation {
  const MiningSimulation(this.content);
  final MiningContentRegistry content;

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
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final produced = <ResourceType, double>{};
    final full = <MiningSectorId>{};
    final sectors = <MiningSectorId, SectorProgress>{...state.sectors};

    for (final definition in content.sectors) {
      final progress = sectors[definition.id]!;
      final mine = progress.mine;
      if (!progress.revealed || mine == null) continue;

      final capacity = content.capacityFor(definition.id, mine.level);
      final remaining = (capacity - mine.storedAmount).clamp(0.0, capacity);
      final amount = (content.rateFor(definition.id, mine.level) * seconds)
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

- [ ] **Step 4: Add equal-input/equal-time coverage**

Call `accrue()` twice from the same `MiningSave` and identical `nowUtc`; assert state JSON and summary fields match exactly. This pins foreground/resume/cold launch to one deterministic function.

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

## Task 3: Persist One Strict Save Without Resetting Tuned Cargo

**Files:**
- Create: `lib/mining/mining_save_repository.dart`
- Test: `test/mining/mining_save_repository_test.dart`

**Interfaces:**
- Consumes: `MiningSave`, `MiningContentRegistry`.
- Produces: `MiningSaveRepository.load`, `save`, `MiningLoadResult`.
- Writes only `horologium.mining.save`.

- [ ] **Step 1: Write failing repository tests**

```dart
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

  test('positive cargo above newly tuned capacity clamps without recovery', () async {
    final raw = <String, Object?>{
      'cash': 100,
      'lastAccruedAtUtc': now.toIso8601String(),
      'sectors': {
        'landingBasin': {
          'revealed': true,
          'mine': {'level': 1, 'storedAmount': 120.0},
        },
        'carbonRidge': {'revealed': false, 'mine': null},
        'graniteCrater': {'revealed': false, 'mine': null},
      },
    };
    SharedPreferences.setMockInitialValues({key: jsonEncode(raw)});

    final result = await MiningSaveRepository().load(nowUtc: now);

    expect(result.recoveredFromInvalidSave, isFalse);
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      90,
    );
  });
}
```

Add table-driven **reset** cases for negative/non-int cash, missing root fields, unknown/missing sector keys, malformed/non-UTC timestamp, non-bool `revealed`, mine level outside 1–5, negative/non-numeric cargo, and extra structural keys.

Do **not** add a schema-version case, future-field case, missing-sector default-fill case, or over-capacity reset case.

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/mining_save_repository_test.dart
```

Expected: FAIL because repository code does not exist.

- [ ] **Step 3: Implement strict decode plus balance clamp**

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

1. require the root object to contain exactly `cash`, `lastAccruedAtUtc`, `sectors`;
2. require the sector key set to equal `MiningSectorId.values.map((id) => id.name).toSet()`;
3. require each sector object to contain exactly `revealed`, `mine`;
4. require mine `null` or exactly `{level, storedAmount}`;
5. require `level` in 1–5 and `storedAmount` numeric + non-negative;
6. decode UTC timestamp and non-negative integer cash;
7. normalize a valid mine with:

```dart
final capacity = content.capacityFor(sectorId, level);
final normalizedStored = math.min(storedAmount, capacity);
```

Clamping current configured capacity is not a recovery event.

Use one exact-key helper:

```dart
bool hasExactKeys(Map<String, Object?> map, Set<String> expected) =>
    map.keys.toSet().length == expected.length &&
    map.keys.toSet().containsAll(expected);
```

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

## Task 4: Serialize Atomic Controller Mutations and Fix Sale Rounding

**Files:**
- Create: `lib/mining/mining_controller.dart`
- Test: `test/mining/mining_controller_test.dart`

**Interfaces:**
- Consumes: content, simulation, repository, injectable UTC clock.
- Produces: plain controller state, `isBusy`, `MiningActionResult`, `MiningSaleResult`.
- Does not import Flutter or call `notifyListeners()`.

- [ ] **Step 1: Write normal action tests**

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
    expect(controller.state.sectors[MiningSectorId.landingBasin]!.mine!.level, 1);
  });
}
```

Add normal tests for Reveal, duplicate Build, Upgrade, max level, zero-cargo Sell, checkpoint, resume, and passive refresh.

- [ ] **Step 2: Add a delayed repository that can expose interleaving**

```dart
class DelayedMiningSaveRepository extends MiningSaveRepository {
  final saveStarted = Completer<void>();
  final allowFirstSave = Completer<void>();
  var saveCount = 0;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    if (saveCount == 1) {
      if (!saveStarted.isCompleted) saveStarted.complete();
      await allowFirstSave.future;
    }
    await super.save(state);
  }
}
```

- [ ] **Step 3: Write the two concurrency regressions**

```dart
test('build then sell issued without awaiting cannot erase the build', () async {
  SharedPreferences.setMockInitialValues({});
  final repository = DelayedMiningSaveRepository();
  final controller = MiningController(
    content: MiningContentRegistry.phaseOne(),
    repository: repository,
    nowUtc: clock.call,
  );
  await controller.initialize();

  final buildFuture = controller.buildMine(MiningSectorId.landingBasin);
  await repository.saveStarted.future;
  final sellFuture = controller.sellAllCargo();

  expect(controller.isBusy, isTrue);
  repository.allowFirstSave.complete();

  expect((await buildFuture).isSuccess, isTrue);
  expect((await sellFuture).isSuccess, isFalse); // built mine has zero cargo
  expect(
    controller.state.sectors[MiningSectorId.landingBasin]!.mine,
    isNotNull,
  );
  expect(controller.state.cash, 50);
});

test('double reveal queues and deducts exactly once', () async {
  final seeded = MiningSave.initial(nowUtc: clock.now).copyWith(cash: 1000);
  await MiningSaveRepository().save(seeded);
  final repository = DelayedMiningSaveRepository();
  final controller = MiningController(
    content: MiningContentRegistry.phaseOne(),
    repository: repository,
    nowUtc: clock.call,
  );
  await controller.initialize();

  final first = controller.revealSector(MiningSectorId.carbonRidge);
  await repository.saveStarted.future;
  final second = controller.revealSector(MiningSectorId.carbonRidge);
  repository.allowFirstSave.complete();

  expect((await first).isSuccess, isTrue);
  expect((await second).isSuccess, isFalse);
  expect(controller.state.cash, 750);
  expect(controller.state.sectors[MiningSectorId.carbonRidge]!.revealed, isTrue);
});
```

- [ ] **Step 4: Run RED**

```bash
flutter test test/mining/mining_controller_test.dart
```

Expected: FAIL because the controller/serialization does not exist.

- [ ] **Step 5: Implement the plain future-chain queue**

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

  Future<void> _mutationChain = Future<void>.value();
  int _pendingMutations = 0;
  bool get isBusy => _pendingMutations > 0;

  bool recoveredFromInvalidSave = false;
  OfflineProductionSummary? _pendingReturnSummary;

  Future<T> _enqueueMutation<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _pendingMutations++;
    _mutationChain = _mutationChain.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingMutations--;
      }
    });
    return completer.future;
  }
}
```

The queue body catches operation failures rather than rethrowing them, so one failed save does not poison later queued operations.

- [ ] **Step 6: Implement initialize and busy-safe refresh**

```dart
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
  if (isBusy) {
    return simulation.accrue(_state, _state.lastAccruedAtUtc);
  }
  final accrued = simulation.accrue(_state, _nowUtc().toUtc());
  _state = accrued.state;
  return accrued;
}
```

Do not persist from `refresh()`.

- [ ] **Step 7: Put each explicit action inside `_enqueueMutation`**

Inside each queued operation:

```dart
final candidate = simulation.accrue(_state, _nowUtc().toUtc());
// validate candidate without assigning _state
// build next immutable state
await repository.save(next);
_state = next;
return result;
```

Reveal/Build/Upgrade all use `MiningSectorId`. A queued duplicate evaluates after the previous operation has published.

- [ ] **Step 8: Implement Sell All Cargo with one final floor**

```dart
var totalCargo = 0.0;
var grossValue = 0.0;
final sold = <ResourceType, double>{};
final sectors = <MiningSectorId, SectorProgress>{...candidate.state.sectors};

for (final definition in content.sectors) {
  final progress = sectors[definition.id]!;
  final mine = progress.mine;
  if (mine == null || mine.storedAmount <= 0) continue;

  totalCargo += mine.storedAmount;
  grossValue += mine.storedAmount * definition.saleValuePerUnit;
  sold.update(
    definition.resource,
    (value) => value + mine.storedAmount,
    ifAbsent: () => mine.storedAmount,
  );
  sectors[definition.id] = progress.copyWith(
    mine: mine.copyWith(storedAmount: 0),
  );
}

if (totalCargo <= 0) {
  return MiningSaleResult.failure('No cargo to sell.');
}

final revenue = grossValue.floor();
final next = candidate.state.copyWith(
  cash: candidate.state.cash + revenue,
  sectors: sectors,
);
await repository.save(next);
_state = next;
return MiningSaleResult.success(revenue: revenue, sold: sold);
```

Add a test with 0.9 units at sale values 4, 3, and 5 and assert revenue is `floor(3.6 + 2.7 + 4.5) == 10`, not 9.

- [ ] **Step 9: Serialize checkpoint and resume**

```dart
Future<void> checkpoint() => _enqueueMutation(() async {
      final accrued = simulation.accrue(_state, _nowUtc().toUtc());
      await repository.save(accrued.state);
      _state = accrued.state;
    });

Future<OfflineProductionSummary?> resume() => _enqueueMutation(() async {
      final accrued = simulation.accrue(_state, _nowUtc().toUtc());
      _state = accrued.state;
      if (accrued.summary.totalProduced > 0) {
        _pendingReturnSummary = accrued.summary;
      }
      return takePendingReturnSummary();
    });
```

Resume need not write immediately; pause/explicit actions/next checkpoint persist, and a killed process recomputes from the last persisted timestamp.

- [ ] **Step 10: Prove refresh does not persist**

After one successful action, read the raw SharedPreferences payload, advance the clock, call `refresh()`, and assert the payload is unchanged while in-memory state accrues. Also call refresh while the delayed first save is blocked and assert it does not change `_state`.

- [ ] **Step 11: Run GREEN**

```bash
flutter test test/mining/mining_controller_test.dart
```

Expected: PASS.

- [ ] **Step 12: Commit**

```bash
git add lib/mining/mining_controller.dart test/mining/mining_controller_test.dart
git commit -m "feat: serialize mining controller actions"
```

---

## Task 5: Derive Busy, Affordability, and Sale State in One Pure Sheet Model

**Files:**
- Create: `lib/mining/mining_sheet_view.dart`
- Test: `test/mining/mining_sheet_view_test.dart`

**Interfaces:**
- Consumes: `MiningSave`, `MiningContentRegistry`, `MiningSectorId?`, `isBusy`.
- Produces: `MiningSheetView`, `MiningSheetAction`.
- No Flutter widgets, contexts, callbacks, or controller calls.

- [ ] **Step 1: Write failing view-model tests**

```dart
void main() {
  final content = MiningContentRegistry.phaseOne();
  final now = DateTime.utc(2026, 8, 18, 12);

  test('no cargo disables Sell All', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: null,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.sell);
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, contains('No cargo'));
  });

  test('busy controller disables otherwise available action', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: MiningSectorId.landingBasin,
      isBusy: true,
    );
    expect(view.action, MiningSheetAction.build);
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, 'Finishing previous action…');
  });

  test('tiny non-zero cargo explains why sale waits', () {
    final base = MiningSave.initial(nowUtc: now);
    final state = base.copyWith(sectors: {
      ...base.sectors,
      MiningSectorId.landingBasin: const SectorProgress(
        revealed: true,
        mine: MineState(level: 1, storedAmount: 0.2),
      ),
    });
    final view = MiningSheetView.from(
      state: state,
      content: content,
      selectedSectorId: null,
      isBusy: false,
    );
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, contains('worth at least 1 cash'));
  });
}
```

Add cases for prerequisite, insufficient cash, revealed empty sector, active upgrade, max level, mixed cargo, and normal sellable cargo.

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
    required bool isBusy,
  }) {
    final base = selectedSectorId == null
        ? _sellView(state, content)
        : _sectorView(state, content, selectedSectorId);

    if (!isBusy) return base;
    return base.copyWith(
      primaryEnabled: false,
      disabledReason: 'Finishing previous action…',
    );
  }
}
```

For `_sellView`, calculate:

```dart
var totalCargo = 0.0;
var grossValue = 0.0;
for (final definition in content.sectors) {
  final mine = state.sectors[definition.id]!.mine;
  if (mine == null) continue;
  totalCargo += mine.storedAmount;
  grossValue += mine.storedAmount * definition.saleValuePerUnit;
}

if (totalCargo <= 0) {
  return disabledSell('No cargo to sell yet.');
}
if (grossValue.floor() == 0) {
  return disabledSell('Keep mining until cargo is worth at least 1 cash.');
}
return enabledSell(revenue: grossValue.floor());
```

Keep prerequisite/affordability/rate/capacity helpers in this file; do not mutate state.

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

## Task 6: Add the Authored Flame World with Deterministic Fit

**Files:**
- Create: `lib/mining/world/mining_game.dart`
- Create: `lib/mining/world/mining_components.dart`
- Test: `test/mining/world/mining_game_test.dart`

**Interfaces:**
- Consumes: content + read-only `MiningSave` snapshots.
- Produces: `MiningGame.applyState`, `focusOnSelection`, `playReward`, typed selection callback.
- Does not import controller, repository, `Resources`, `Building`, `Planet`, or `SaveService`.

- [ ] **Step 1: Write a mounted-game helper using an explicit portrait viewport**

```dart
Future<void> pumpMiningGame(
  WidgetTester tester,
  MiningGame game, {
  Size size = const Size(360, 640),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: GameWidget(game: game))),
  );
  for (var i = 0; i < 80 && !game.hasLoaded; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(game.hasLoaded, isTrue);
}
```

This follows the existing `GameWidget` widget-test pattern; do not call `MiningGame.onLoad()` naked.

- [ ] **Step 2: Write failing world-fit and structural-tier tests**

```dart
testWidgets('all authored anchors are visible at initial 360x640 fit', (tester) async {
  final content = MiningContentRegistry.phaseOne();
  final game = MiningGame(content: content);
  await pumpMiningGame(tester, game);

  expect(game.worldSize.x, 1800);
  expect(game.worldSize.y, 1800);
  expect(game.camera.viewfinder.zoom, closeTo(0.2, 0.0001));

  for (final definition in content.sectors) {
    final screenX = 180 + definition.anchor.x * game.camera.viewfinder.zoom;
    final screenY = 320 + definition.anchor.y * game.camera.viewfinder.zoom;
    expect(screenX, inInclusiveRange(0, 360));
    expect(screenY, inInclusiveRange(0, 640));
  }
});

testWidgets('levels one three and five add distinct mounted structure', (tester) async {
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

  final sector = game.sector(MiningSectorId.landingBasin);

  game.applyState(withGoldLevel(1));
  await tester.pump();
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
  expect(sector.children.whereType<EliteRingComponent>(), hasLength(1));
});
```

Add selection/focus test verifying a bottom-obscured fraction shifts target upward and remains clamped inside world bounds.

- [ ] **Step 3: Run RED**

```bash
flutter test test/mining/world/mining_game_test.dart
```

Expected: FAIL because mining world classes do not exist.

- [ ] **Step 4: Implement presentation marker components**

```dart
class OperationLightComponent extends PositionComponent {}
class AdvancedPlatformComponent extends PositionComponent {}
class SecondaryMachineryComponent extends PositionComponent {}
class EliteRingComponent extends PositionComponent {}
```

`MiningSectorComponent` loads `definition.mineAsset`, positions itself at `Vector2(definition.anchor.x, definition.anchor.y)`, and rebuilds structural children only when tier changes.

- [ ] **Step 5: Explicitly size terrain before adding and fitting it**

```dart
class MiningGame extends FlameGame with TapCallbacks, ScaleDetector {
  MiningGame({required this.content});

  final MiningContentRegistry content;
  final Map<MiningSectorId, MiningSectorComponent> _sectors = {};
  void Function(MiningSectorId?)? onSelectionChanged;
  bool reducedMotion = false;
  bool hasLoaded = false;
  Vector2 get worldSize => Vector2.all(MiningContentRegistry.worldExtent);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;

    final terrain = ParallaxTerrainComponent(
      gridSize: MiningContentRegistry.terrainGridSize,
      seed: 631,
    )
      ..parallaxEnabled = false
      ..size = Vector2.all(MiningContentRegistry.worldExtent)
      ..anchor = Anchor.center
      ..position = Vector2.zero();

    world.add(terrain);

    for (final definition in content.sectors) {
      final component = MiningSectorComponent(definition: definition)
        ..position = Vector2(definition.anchor.x, definition.anchor.y);
      _sectors[definition.id] = component;
      world.add(component);
    }

    final viewport = camera.viewport.size;
    final fit = math.min(
      viewport.x / MiningContentRegistry.worldExtent,
      viewport.y / MiningContentRegistry.worldExtent,
    );
    _fitZoom = fit;
    camera.viewfinder.zoom = fit.clamp(_minZoom, _maxZoom);
    camera.viewfinder.position = Vector2.zero();
    hasLoaded = true;
  }
}
```

Copy only the minimal pan/zoom clamp and center/focus logic from `MainGame`.

- [ ] **Step 6: Implement state application and typed selection/focus**

`applyState(MiningSave state)` updates every sector component from its typed progress. Taps invoke `onSelectionChanged?.call(definition.id)`.

```dart
void focusOnSelection({
  required MiningSectorId sectorId,
  required double bottomObscuredFraction,
});
```

Reduced motion snaps to the target. Normal mode may use a short Flame movement effect, but the final camera target must be the same.

- [ ] **Step 7: Run GREEN**

```bash
flutter test test/mining/world/mining_game_test.dart
```

Expected: PASS, including initial visibility and structural level checks.

- [ ] **Step 8: Commit**

```bash
git add lib/mining/world test/mining/world/mining_game_test.dart
git commit -m "feat: add authored mining world"
```

---

## Task 7: Add Portrait MiningScreen, Safe Menu Entry, and the Early Product Gate

**Files:**
- Create: `lib/mining/presentation/mining_screen.dart`
- Create: `lib/mining/presentation/mining_status_bar.dart`
- Create: `lib/mining/presentation/mining_action_sheet.dart`
- Test: `test/mining/presentation/mining_screen_test.dart`
- Test: `test/main_menu_test.dart`
- Modify: `lib/main_menu.dart`

**Interfaces:**
- Consumes: plain controller, pure `MiningSheetView`, `MiningGame`.
- `MiningActionSheet` renders the view model + one callback only.

- [ ] **Step 1: Write MiningScreen tests at both portrait sizes**

For each `Size(360, 640)` and `Size(430, 932)`, pump deterministic SharedPreferences + clock and assert:

```dart
expect(find.text('Landing Basin'), findsWidgets);
expect(find.text('SELL ALL CARGO'), findsOneWidget);
expect(tester.takeException(), isNull);
final size = tester.getSize(find.byKey(const Key('mining-primary-action')));
expect(size.height, greaterThanOrEqualTo(56));
```

Select Landing Basin and assert Build; build and assert Level/Upgrade state. Assert status never displays Population, Workers, Happiness, or Research.

- [ ] **Step 2: Write menu-entry and menu-layout tests at the same sizes**

Use the existing menu test convention: pump the app, advance 3 seconds instead of `pumpAndSettle()` because the star animation repeats.

```dart
for (final size in const [Size(360, 640), Size(430, 932)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(const HorologiumApp());
  await tester.pump(const Duration(seconds: 3));

  expect(find.text('START EXPEDITION'), findsOneWidget);
  expect(find.text('MINING MVP'), findsOneWidget);
  expect(find.text('SETTINGS'), findsOneWidget);
  expect(tester.takeException(), isNull);
}
```

Also tap **MINING MVP** and verify `MiningScreen` appears. **START EXPEDITION** must remain unchanged.

- [ ] **Step 3: Run RED**

```bash
flutter test test/mining/presentation/mining_screen_test.dart test/main_menu_test.dart
```

Expected: FAIL because screen/menu entry do not exist.

- [ ] **Step 4: Implement status bar and dumb action-sheet renderer**

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

Primary action uses `SizedBox(height: 56, width: double.infinity)` and key `mining-primary-action`. Disabled copy comes only from `view.disabledReason`.

- [ ] **Step 5: Implement plain-controller screen ownership**

```dart
class _MiningScreenState extends State<MiningScreen> with WidgetsBindingObserver {
  late final MiningContentRegistry _content;
  late final MiningController _controller;
  late final MiningGame _game;
  Timer? _refreshTimer;
  MiningSectorId? _selectedSectorId;
  late MiningSheetView _sheetView;

  void _refreshPresentation() {
    _game.applyState(_controller.state);
    _sheetView = MiningSheetView.from(
      state: _controller.state,
      content: _content,
      selectedSectorId: _selectedSectorId,
      isBusy: _controller.isBusy,
    );
    if (mounted) setState(() {});
  }
}
```

The one-second timer calls:

```dart
if (!_controller.isBusy) {
  _controller.refresh();
  _refreshPresentation();
}
```

- [ ] **Step 6: Route one pure action enum to typed controller calls**

When a primary action is tapped:

1. start the controller future (the queue increments busy synchronously);
2. immediately call `_refreshPresentation()` so the button disables;
3. await the result;
4. call `_refreshPresentation()` again;
5. show visible success/failure copy.

Do not derive a second affordability/prerequisite rule in the widget.

- [ ] **Step 7: Add the temporary menu entry**

```dart
_buildMenuButton(
  'MINING MVP',
  Icons.precision_manufacturing,
  () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const MiningScreen()),
  ),
),
```

Keep **START EXPEDITION** and all legacy routes unchanged.

- [ ] **Step 8: Run GREEN**

```bash
flutter test test/mining/mining_sheet_view_test.dart \
  test/mining/presentation/mining_screen_test.dart \
  test/main_menu_test.dart
```

Expected: PASS with no overflow at either portrait size.

- [ ] **Step 9: Commit the first runnable loop**

```bash
git add lib/mining/presentation lib/main_menu.dart \
  test/mining/presentation/mining_screen_test.dart test/main_menu_test.dart
git commit -m "feat: add mining MVP screen"
```

- [ ] **Step 10: Mandatory early real-device product gate**

Before Task 8, run the committed build on at least one **physical portrait mobile device** and complete (simulator runs may supplement this evidence, never substitute for it):

1. open **MINING MVP**;
2. build Landing Basin gold;
3. accrue enough cargo for a meaningful first sale;
4. sell;
5. upgrade gold;
6. reveal Carbon Ridge.

Record a short checkpoint note answering:

```text
Core loop worth finishing? Yes | No
First-mine clarity: <observation>
First-sale clarity: <observation>
Upgrade/reveal motivation: <observation>
Blocking UX issue, if any: <observation or none>
```

If **No**, stop implementation here and record HPA-631 **Stop/reconsider**. Do not spend time on Task 8 reward/lifecycle polish or Task 9 full-journey coverage.

If **Yes**, proceed to Task 8. This is an interim gate; Task 10 still records the formal final decision.

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
- Effects are presentation-only and run after committed success.

- [ ] **Step 1: Add failing lifecycle/recovery/reduced-motion tests**

Test:

1. active gold mine persisted;
2. pause/checkpoint;
3. clock advances;
4. resume/recreate;
5. one offline sheet reports Gold production;
6. dismiss + rebuild does not repeat it;
7. malformed mining JSON causes one non-blocking recovery SnackBar;
8. `MediaQueryData(disableAnimations: true)` still gives visible Build/Reveal/Upgrade/Sell confirmation.

- [ ] **Step 2: Run RED**

```bash
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: FAIL because lifecycle/reward behavior is incomplete.

- [ ] **Step 3: Implement `OfflineReturnSheet`**

Render elapsed duration used, non-zero Gold/Coal/Stone production, storage-full notes for `fullSectors`, cap note when reached, and one next-action hint. There is no claim button because cargo is already state.

- [ ] **Step 4: Wire lifecycle through the serialized controller**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.inactive:
    case AppLifecycleState.paused:
      _refreshTimer?.cancel();
      unawaited(_controller.checkpoint());
      _refreshPresentation();
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

`_resumeMining()` awaits queued `controller.resume()`, refreshes presentation, shows the returned summary once, and restarts the timer.

- [ ] **Step 5: Show invalid-save recovery once**

When `controller.recoveredFromInvalidSave` is true after initialization, schedule one post-frame SnackBar:

```text
Mining progress could not be loaded, so a fresh mining save was started.
```

- [ ] **Step 6: Implement four reward effects**

```dart
enum MiningRewardEffect { reveal, construction, tierUpgrade, sale }
```

- reveal: scanner line/ring + fog fade;
- construction: scale/fade + dust/glow;
- tier upgrade: pulse newly added level-3/5 structure;
- sale: short cargo/particle movement toward HUD direction.

No effect completion is awaited before economic success.

- [ ] **Step 7: Add reduced-motion branches**

```dart
_game.reducedMotion = MediaQuery.of(context).disableAnimations;
```

Use fades/number transitions and snapped/short camera movement. Keep the same visible confirmation text.

- [ ] **Step 8: Add optional success haptics**

Call `HapticFeedback.lightImpact()` or `mediumImpact()` after successful actions. Do not await it and do not add a platform abstraction.

- [ ] **Step 9: Strengthen mounted world tests after effects**

Re-run structural assertions after `playReward` and reduced-motion changes. Tier children must remain a function of `MiningSave`, not effect timing.

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
- Modify mining source only for integration bugs proven by this journey.

**Interfaces:**
- Exercises menu → real screen → pure sheet model → controller → simulation → persistence → world together.
- Uses visible UI + injected time only; no controller shortcuts or cash injection.

- [ ] **Step 1: Write the journey test**

```dart
await tester.tap(find.text('MINING MVP'));
await tester.pump();

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

Continue through visible controls until Carbon Ridge is revealed/built, then Granite Crater is revealed/built.

- [ ] **Step 2: Verify mixed-cargo sale and one-floor rounding**

Through visible state verify all three mines exist, gold has upgraded, multiple resources contribute cargo, one Sell All clears all active cargo, and the cash increase matches `floor(total gross value)` from all resource cargo combined.

- [ ] **Step 3: Verify offline return against the pure simulation**

After a persisted checkpoint:

1. read `horologium.mining.save` unchanged;
2. advance clock two hours;
3. recreate `MiningScreen`;
4. verify one offline summary;
5. compare restored storage to `MiningSimulation.accrue(savedState, T1)`;
6. separately prove 12 hours uses at most 8 hours before capacity caps.

- [ ] **Step 4: Run the integration seam**

```bash
flutter test test/integration/mining_mvp_journey_test.dart
```

Expected first run: either PASS or one concrete integration mismatch. Fix only demonstrated production seams; do not add test-only alternate paths.

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

Only source files changed for a proven integration bug belong in this commit.

---

## Task 10: Run Repository Verification and Record Final Product Evidence

**Files:**
- No planned source changes.
- Linear HPA-631 receives the final review comment only after implementation/playtest evidence exists.

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

- [ ] **Step 4: Run the web test target used by CI**

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

- [ ] **Step 6: Perform final narrow/tall portrait smoke**

Verify:

- fresh player identifies gold and builds within one minute;
- selected sector stays visible above the sheet;
- primary actions are comfortable to tap;
- scanner/build/upgrade/sale rewards are readable;
- levels 1/3/5 are visibly different in actual rendering;
- audio-off still confirms success;
- reduced-motion remains understandable;
- return summary makes the next useful action obvious;
- modified MainMenu fits the supported narrow/tall portrait targets;
- no city page is required for the mining loop.

Record exact device/simulator, OS/runtime, build SHA, first-mine/first-sale timing, and observations.

- [ ] **Step 7: Verify isolation and forbidden framework dependencies**

```bash
grep -R -E \
  "game/(building|managers/game_state_manager|services/save_service|planet)|game/resources/resources\.dart" \
  lib/mining || true
```

Expected: no output. `game/resources/resource_type.dart` is allowed.

```bash
grep -R "ChangeNotifier\|notifyListeners" lib/mining || true
```

Expected: no output.

- [ ] **Step 8: Check the spec acceptance list line by line**

Use `docs/superpowers/specs/2026-08-18-hpa-631-one-planet-mining-mvp-design.md`. Do not substitute passing tests for real portrait/product evidence.

- [ ] **Step 9: Post the HPA-631 final conclusion**

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

If verification reveals a real bug, add its regression test, fix it on this branch, and commit it. Do not create a second PR.

---

## Plan Self-Review

### Spec coverage

- Typed sectors, reused resource/assets, explicit world units: Task 1.
- Deterministic production, rollback/storage/8-hour cap: Task 2.
- Strict structural save + tunable capacity clamp: Task 3.
- Serialized atomic Reveal/Build/Upgrade/Sell/checkpoint/resume + one-floor sale: Task 4.
- Pure busy/affordability/tiny-sale sheet derivation: Task 5.
- Mounted Flame world, explicit terrain size, initial visibility, structural level 1/3/5 proof: Task 6.
- Portrait UI, typed actions, temporary menu, both-size menu checks, early product gate: Task 7.
- Offline return/recovery/reduced motion/four reward moments: Task 8.
- Real first-session + three-sector + mixed-sale + offline journey: Task 9.
- Format/analyze/tests/web/APK/manual/isolation/final decision: Task 10.

### Placeholder scan

There are no `TBD`, `TODO`, future compatibility hooks, missing-sector defaults, schema migration steps, generic framework seams, or test-only alternate production paths.

### Type consistency

- `MiningSectorId` is the single sector/deposit identity across content, state, persistence, controller, sheet, and world.
- `ResourceType` is reused for Gold/Coal/Stone identity and production summaries.
- `MiningContentRegistry.rateFor/capacityFor` is the shared balance calculation seam.
- `MiningSave` is the single progress document.
- `MineState` is only `{level, storedAmount}`.
- `MiningController` is plain Dart, serializes async mutations, and is the sole mutation boundary exposed to `MiningScreen`.
- `MiningSheetView` is pure derived presentation state and receives `isBusy` explicitly.
- `MiningGame.applyState()` consumes read-only snapshots and owns no economics.

## Execution Handoff

Implement this plan on the existing HPA-631 branch and draft PR #14. Keep all implementation and review fixes in that one PR unless the user explicitly changes the delivery policy.
