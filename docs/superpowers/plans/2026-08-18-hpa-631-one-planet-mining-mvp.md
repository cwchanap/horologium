# HPA-631 One-Planet Mining MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship and validate Horologium's complete one-planet mining-idle MVP: reveal fixed deposits, build and upgrade mines, accrue deterministic cargo, sell it for cash, reveal all three sectors, and restore capped offline production in a portrait-first Flutter/Flame experience.

**Architecture:** Add one isolated `lib/mining/` vertical slice alongside the existing city runtime. Pure Dart content/state/simulation/controller code owns economics; one mining-specific SharedPreferences JSON document owns persistence; Flutter owns HUD/sheets/lifecycle; a separate Flame `MiningGame` owns terrain, authored sector/deposit/mine presentation, camera behavior, and reward effects. The only legacy gameplay change is a temporary **MINING MVP** menu entry; HPA-636 owns cutover.

**Tech Stack:** Dart 3.8+, Flutter 3.32.5, Flame 1.30, SharedPreferences 2.5, existing Flutter test/Flame test infrastructure, existing terrain/resource/building assets.

**Spec:** `docs/superpowers/specs/2026-08-18-hpa-631-one-planet-mining-mvp-design.md`

## Global Constraints

- Deliver HPA-631 in **one implementation PR**. Use focused commits, not child PRs or child Linear issues.
- Linear HPA-630/HPA-631 are authoritative when older documentation differs.
- Keep legacy `MainGame`, `Planet`, `Resources`, `Building`, worker/research/quest systems, and `SaveService` out of the mining economy.
- Keep immutable content separate from mutable mining progress.
- Cash is the only spendable currency.
- Landing Basin / Gold, Carbon Ridge / Coal, and Granite Crater / Stone share one domain path.
- Use five mine levels with visible presentation tiers at levels 1, 3, and 5.
- Use elapsed UTC time as the production source of truth; cap offline production at 8 hours; clock rollback produces zero.
- Failed Reveal, Build, Upgrade, and Sell actions do not partially mutate cash, sectors, mine levels, cargo, or persistence.
- Persist one JSON document at `horologium.mining.save.v2`; ignore legacy city keys; no backup/recovery-key framework.
- Do not write persistence on one-second foreground refreshes.
- Flutter owns HUDs, sheets, actions, lifecycle, recovery/offline summaries; Flame owns world rendering, selection, camera, and effects.
- Reuse current terrain, audio preference, resource icon, `gold_mine.png`, `coal_mine.png`, and `quarry.png` assets; do not add an asset-generation pipeline.
- Portrait is canonical. Primary touch actions are at least 56 logical px high. Automated layout checks cover 360×640 and 430×932.
- Primary actions remain understandable with audio disabled and with `MediaQueryData.disableAnimations == true`.
- No technology, second planet, processing, dynamic market, resource buying, worker/housing/service mechanics, cloud save, or generic framework work.

---

## File map

### Create

```text
lib/mining/domain/mining_content.dart
lib/mining/domain/mining_state.dart
lib/mining/domain/mining_simulation.dart
lib/mining/domain/mining_controller.dart
lib/mining/persistence/mining_save_repository.dart
lib/mining/presentation/mining_screen.dart
lib/mining/presentation/mining_status_bar.dart
lib/mining/presentation/mining_action_sheet.dart
lib/mining/presentation/offline_return_sheet.dart
lib/mining/world/mining_game.dart
lib/mining/world/mining_components.dart

test/mining/domain/mining_content_test.dart
test/mining/domain/mining_simulation_test.dart
test/mining/domain/mining_controller_test.dart
test/mining/persistence/mining_save_repository_test.dart
test/mining/world/mining_game_test.dart
test/mining/presentation/mining_screen_test.dart
test/integration/mining_mvp_journey_test.dart
test/main_menu_test.dart
```

### Modify

```text
lib/main_menu.dart
```

Do not modify `pubspec.yaml`, CI workflows, `lib/game/main_game.dart`, `lib/game/scene_widget.dart`, or the legacy `SaveService` unless implementation reveals a concrete compile/runtime need that cannot be solved inside `lib/mining/`.

---

### Task 1: Lock Phase 1 content and immutable save state

**Files:**
- Create: `lib/mining/domain/mining_content.dart`
- Create: `lib/mining/domain/mining_state.dart`
- Create: `test/mining/domain/mining_content_test.dart`

**Interfaces:**
- Produces: `MiningResourceType`, `MiningWorldAnchor`, `MiningDepositDefinition`, `MiningSectorDefinition`, `MiningContentRegistry`, `MiningSaveV2`, `SectorProgress`, `MineState`.
- Consumed by: all later tasks.

- [ ] **Step 1: Write a failing registry/state test**

Create `test/mining/domain/mining_content_test.dart` with assertions for exact content and clean initial progress:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/domain/mining_content.dart';
import 'package:horologium/mining/domain/mining_state.dart';

void main() {
  test('phase one content contains exactly three authored sectors', () {
    final registry = MiningContentRegistry.phaseOne();

    expect(registry.sectors.map((sector) => sector.id), [
      'landing_basin',
      'carbon_ridge',
      'granite_crater',
    ]);
    expect(registry.sector('landing_basin').deposit.resource, MiningResourceType.gold);
    expect(registry.sector('carbon_ridge').deposit.resource, MiningResourceType.coal);
    expect(registry.sector('granite_crater').deposit.resource, MiningResourceType.stone);
    expect(registry.sector('carbon_ridge').revealCost, 250);
    expect(registry.sector('granite_crater').revealCost, 700);
    expect(registry.offlineCap, const Duration(hours: 8));
  });

  test('clean save reveals only Landing Basin with 100 cash', () {
    final now = DateTime.utc(2026, 8, 18, 12);
    final state = MiningSaveV2.initial(nowUtc: now);

    expect(state.schemaVersion, 2);
    expect(state.cash, 100);
    expect(state.lastAccruedAtUtc, now);
    expect(state.sectors['landing_basin']!.revealed, isTrue);
    expect(state.sectors['carbon_ridge']!.revealed, isFalse);
    expect(state.sectors['granite_crater']!.revealed, isFalse);
    expect(state.sectors.values.every((progress) => progress.mine == null), isTrue);
  });
}
```

- [ ] **Step 2: Run the test and verify the missing mining domain fails**

Run:

```bash
flutter test test/mining/domain/mining_content_test.dart
```

Expected: FAIL because `lib/mining/domain/mining_content.dart` and `mining_state.dart` do not exist.

- [ ] **Step 3: Implement the immutable content registry**

Create `lib/mining/domain/mining_content.dart` around these concrete values:

```dart
enum MiningResourceType { gold, coal, stone }

class MiningWorldAnchor {
  const MiningWorldAnchor(this.x, this.y);
  final double x;
  final double y;
}

class MiningDepositDefinition {
  const MiningDepositDefinition({
    required this.id,
    required this.resource,
    required this.buildCost,
    required this.baseRatePerSecond,
    required this.baseCapacity,
    required this.saleValuePerUnit,
    required this.upgradeCosts,
    required this.anchor,
  });

  final String id;
  final MiningResourceType resource;
  final int buildCost;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<int> upgradeCosts;
  final MiningWorldAnchor anchor;
}

class MiningSectorDefinition {
  const MiningSectorDefinition({
    required this.id,
    required this.name,
    required this.revealCost,
    required this.requiredSectorId,
    required this.deposit,
  });

  final String id;
  final String name;
  final int revealCost;
  final String? requiredSectorId;
  final MiningDepositDefinition deposit;
}

class MiningContentRegistry {
  MiningContentRegistry._(this.sectors);

  static const offlineCap = Duration(hours: 8);
  static const rateMultipliers = <double>[1.0, 1.5, 2.25, 3.25, 4.5];
  static const capacityMultipliers = <double>[1.0, 1.5, 2.0, 3.0, 4.0];

  final List<MiningSectorDefinition> sectors;

  factory MiningContentRegistry.phaseOne() => MiningContentRegistry._(const [
        MiningSectorDefinition(
          id: 'landing_basin',
          name: 'Landing Basin',
          revealCost: 0,
          requiredSectorId: null,
          deposit: MiningDepositDefinition(
            id: 'landing_gold',
            resource: MiningResourceType.gold,
            buildCost: 50,
            baseRatePerSecond: 0.50,
            baseCapacity: 90,
            saleValuePerUnit: 4,
            upgradeCosts: [80, 160, 320, 640],
            anchor: MiningWorldAnchor(0.46, 0.72),
          ),
        ),
        MiningSectorDefinition(
          id: 'carbon_ridge',
          name: 'Carbon Ridge',
          revealCost: 250,
          requiredSectorId: 'landing_basin',
          deposit: MiningDepositDefinition(
            id: 'carbon_coal',
            resource: MiningResourceType.coal,
            buildCost: 100,
            baseRatePerSecond: 0.75,
            baseCapacity: 120,
            saleValuePerUnit: 3,
            upgradeCosts: [150, 300, 600, 1200],
            anchor: MiningWorldAnchor(0.28, 0.46),
          ),
        ),
        MiningSectorDefinition(
          id: 'granite_crater',
          name: 'Granite Crater',
          revealCost: 700,
          requiredSectorId: 'carbon_ridge',
          deposit: MiningDepositDefinition(
            id: 'granite_stone',
            resource: MiningResourceType.stone,
            buildCost: 250,
            baseRatePerSecond: 0.60,
            baseCapacity: 120,
            saleValuePerUnit: 5,
            upgradeCosts: [350, 700, 1400, 2800],
            anchor: MiningWorldAnchor(0.68, 0.30),
          ),
        ),
      ]);

  MiningSectorDefinition sector(String id) =>
      sectors.singleWhere((sector) => sector.id == id);

  MiningDepositDefinition deposit(String id) =>
      sectors.map((sector) => sector.deposit).singleWhere((deposit) => deposit.id == id);
}
```

Use `List.unmodifiable` / `Map.unmodifiable` at construction boundaries where needed so callers cannot mutate registry or save collections accidentally.

- [ ] **Step 4: Implement the immutable save objects**

Create `lib/mining/domain/mining_state.dart` with concrete copy/JSON behavior. Keep serialization mechanical; validation belongs to the repository.

```dart
class MineState {
  const MineState({
    required this.depositId,
    required this.level,
    required this.storedAmount,
  });

  final String depositId;
  final int level;
  final double storedAmount;

  MineState copyWith({int? level, double? storedAmount}) => MineState(
        depositId: depositId,
        level: level ?? this.level,
        storedAmount: storedAmount ?? this.storedAmount,
      );

  Map<String, Object?> toJson() => {
        'depositId': depositId,
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
        if (mine != null) 'mine': mine!.toJson(),
      };
}

class MiningSaveV2 {
  const MiningSaveV2({
    required this.cash,
    required this.lastAccruedAtUtc,
    required this.sectors,
  });

  static const schemaVersion = 2;
  final int cash;
  final DateTime lastAccruedAtUtc;
  final Map<String, SectorProgress> sectors;

  factory MiningSaveV2.initial({required DateTime nowUtc}) => MiningSaveV2(
        cash: 100,
        lastAccruedAtUtc: nowUtc.toUtc(),
        sectors: const {
          'landing_basin': SectorProgress(revealed: true),
          'carbon_ridge': SectorProgress(revealed: false),
          'granite_crater': SectorProgress(revealed: false),
        },
      );

  MiningSaveV2 copyWith({
    int? cash,
    DateTime? lastAccruedAtUtc,
    Map<String, SectorProgress>? sectors,
  }) => MiningSaveV2(
        cash: cash ?? this.cash,
        lastAccruedAtUtc: lastAccruedAtUtc ?? this.lastAccruedAtUtc,
        sectors: Map.unmodifiable(sectors ?? this.sectors),
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'cash': cash,
        'lastAccruedAtUtc': lastAccruedAtUtc.toUtc().toIso8601String(),
        'sectors': sectors.map((id, progress) => MapEntry(id, progress.toJson())),
      };
}
```

- [ ] **Step 5: Run the content/state tests**

Run:

```bash
flutter test test/mining/domain/mining_content_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit the foundation inside the single HPA-631 branch**

```bash
git add lib/mining/domain/mining_content.dart \
  lib/mining/domain/mining_state.dart \
  test/mining/domain/mining_content_test.dart
git commit -m "feat: add mining MVP content and state"
```

---

### Task 2: Implement pure elapsed-time production

**Files:**
- Create: `lib/mining/domain/mining_simulation.dart`
- Create: `test/mining/domain/mining_simulation_test.dart`

**Interfaces:**
- Consumes: `MiningContentRegistry`, `MiningSaveV2`, `MineState`.
- Produces: `MiningSimulation`, `AccrualResult`, `OfflineProductionSummary`, `ResourceProduction`.
- Later controller code uses the simulation for foreground refresh, actions, resume, and cold launch.

- [ ] **Step 1: Write failing deterministic-production tests**

Create `test/mining/domain/mining_simulation_test.dart` covering a built gold mine:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/domain/mining_content.dart';
import 'package:horologium/mining/domain/mining_simulation.dart';
import 'package:horologium/mining/domain/mining_state.dart';

MiningSaveV2 goldState(DateTime now, {double stored = 0, int level = 1}) {
  final base = MiningSaveV2.initial(nowUtc: now);
  return base.copyWith(sectors: {
    ...base.sectors,
    'landing_basin': SectorProgress(
      revealed: true,
      mine: MineState(
        depositId: 'landing_gold',
        level: level,
        storedAmount: stored,
      ),
    ),
  });
}

void main() {
  final registry = MiningContentRegistry.phaseOne();
  final simulation = MiningSimulation(registry);
  final start = DateTime.utc(2026, 8, 18, 12);

  test('level one gold produces five units in ten seconds', () {
    final result = simulation.accrue(goldState(start), start.add(const Duration(seconds: 10)));
    expect(result.state.sectors['landing_basin']!.mine!.storedAmount, 5);
    expect(result.summary.produced[MiningResourceType.gold], 5);
  });

  test('storage caps and eight-hour limit are deterministic', () {
    final result = simulation.accrue(goldState(start), start.add(const Duration(days: 2)));
    expect(result.state.sectors['landing_basin']!.mine!.storedAmount, 90);
    expect(result.summary.elapsedUsed, const Duration(hours: 8));
    expect(result.summary.wasOfflineCapped, isTrue);
    expect(result.state.lastAccruedAtUtc, start.add(const Duration(days: 2)));
  });

  test('clock rollback produces zero and never moves timestamp backward', () {
    final state = goldState(start, stored: 12);
    final result = simulation.accrue(state, start.subtract(const Duration(minutes: 5)));
    expect(result.state.toJson(), state.toJson());
    expect(result.summary.totalProduced, 0);
  });

  test('level multipliers affect both rate and capacity', () {
    expect(simulation.rateFor('landing_gold', 3), closeTo(1.125, 0.0001));
    expect(simulation.capacityFor('landing_gold', 3), 180);
  });
}
```

- [ ] **Step 2: Run the simulation tests and verify failure**

```bash
flutter test test/mining/domain/mining_simulation_test.dart
```

Expected: FAIL because `MiningSimulation` and result types do not exist.

- [ ] **Step 3: Implement result objects and pure accrual**

Create `lib/mining/domain/mining_simulation.dart` with this shape:

```dart
class OfflineProductionSummary {
  const OfflineProductionSummary({
    required this.elapsedUsed,
    required this.produced,
    required this.fullDepositIds,
    required this.wasOfflineCapped,
  });

  final Duration elapsedUsed;
  final Map<MiningResourceType, double> produced;
  final Set<String> fullDepositIds;
  final bool wasOfflineCapped;

  double get totalProduced => produced.values.fold(0, (sum, value) => sum + value);
}

class AccrualResult {
  const AccrualResult({required this.state, required this.summary});
  final MiningSaveV2 state;
  final OfflineProductionSummary summary;
}

class MiningSimulation {
  const MiningSimulation(this.content);
  final MiningContentRegistry content;

  double rateFor(String depositId, int level) {
    final deposit = content.deposit(depositId);
    return deposit.baseRatePerSecond * MiningContentRegistry.rateMultipliers[level - 1];
  }

  double capacityFor(String depositId, int level) {
    final deposit = content.deposit(depositId);
    return deposit.baseCapacity * MiningContentRegistry.capacityMultipliers[level - 1];
  }

  AccrualResult accrue(MiningSaveV2 state, DateTime nowUtc) {
    final now = nowUtc.toUtc();
    final rawElapsed = now.difference(state.lastAccruedAtUtc);
    if (rawElapsed <= Duration.zero) {
      return AccrualResult(
        state: state,
        summary: const OfflineProductionSummary(
          elapsedUsed: Duration.zero,
          produced: {},
          fullDepositIds: {},
          wasOfflineCapped: false,
        ),
      );
    }

    final elapsed = rawElapsed > MiningContentRegistry.offlineCap
        ? MiningContentRegistry.offlineCap
        : rawElapsed;
    final produced = <MiningResourceType, double>{};
    final full = <String>{};
    final sectors = <String, SectorProgress>{...state.sectors};

    for (final sector in content.sectors) {
      final progress = sectors[sector.id]!;
      final mine = progress.mine;
      if (!progress.revealed || mine == null) continue;

      final capacity = capacityFor(mine.depositId, mine.level);
      final remaining = (capacity - mine.storedAmount).clamp(0.0, capacity);
      final amount = (rateFor(mine.depositId, mine.level) * elapsed.inMilliseconds / 1000.0)
          .clamp(0.0, remaining);
      final stored = mine.storedAmount + amount;
      sectors[sector.id] = progress.copyWith(mine: mine.copyWith(storedAmount: stored));
      produced.update(
        sector.deposit.resource,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
      if (stored >= capacity) full.add(mine.depositId);
    }

    return AccrualResult(
      state: state.copyWith(lastAccruedAtUtc: now, sectors: sectors),
      summary: OfflineProductionSummary(
        elapsedUsed: elapsed,
        produced: Map.unmodifiable(produced),
        fullDepositIds: Set.unmodifiable(full),
        wasOfflineCapped: rawElapsed > MiningContentRegistry.offlineCap,
      ),
    );
  }
}
```

Keep all level bounds validation outside this method; persisted/controller state guarantees levels 1–5.

- [ ] **Step 4: Add an equal-input/equal-time regression test**

Append a test that calls `accrue()` twice from the same serialized state and same `nowUtc`, then compares `toJson()` values. This pins the foreground/resume/cold-launch invariant to one function rather than testing three duplicate implementations.

- [ ] **Step 5: Run simulation and foundation tests**

```bash
flutter test test/mining/domain/mining_content_test.dart \
  test/mining/domain/mining_simulation_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/mining/domain/mining_simulation.dart \
  test/mining/domain/mining_simulation_test.dart
git commit -m "feat: add deterministic mining production"
```

---

### Task 3: Persist one safe V2 mining document

**Files:**
- Create: `lib/mining/persistence/mining_save_repository.dart`
- Create: `test/mining/persistence/mining_save_repository_test.dart`

**Interfaces:**
- Consumes: `MiningContentRegistry`, `MiningSaveV2`, `SectorProgress`, `MineState`.
- Produces: `MiningSaveRepository.load(DateTime nowUtc)`, `save(MiningSaveV2 state)`, `MiningLoadResult`.
- Persisted key: `horologium.mining.save.v2` only.

- [ ] **Step 1: Write failing repository tests**

Create tests that reset SharedPreferences per case:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/mining/domain/mining_state.dart';
import 'package:horologium/mining/persistence/mining_save_repository.dart';

void main() {
  const key = 'horologium.mining.save.v2';
  final now = DateTime.utc(2026, 8, 18, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('missing save returns clean state without recovery warning', () async {
    final result = await MiningSaveRepository().load(nowUtc: now);
    expect(result.state.cash, 100);
    expect(result.recoveredFromInvalidSave, isFalse);
  });

  test('round trips one V2 document', () async {
    final repository = MiningSaveRepository();
    final state = MiningSaveV2.initial(nowUtc: now).copyWith(cash: 321);
    await repository.save(state);
    final loaded = await repository.load(nowUtc: now.add(const Duration(minutes: 1)));
    expect(loaded.state.toJson(), state.toJson());
  });

  test('invalid document resets cleanly and reports recovery', () async {
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
    expect(result.state.sectors['landing_basin']!.mine, isNull);
  });

  test('unknown JSON fields do not break a valid V2 save', () async {
    final json = MiningSaveV2.initial(nowUtc: now).toJson()..['futureField'] = 42;
    SharedPreferences.setMockInitialValues({key: jsonEncode(json)});
    final result = await MiningSaveRepository().load(nowUtc: now);
    expect(result.recoveredFromInvalidSave, isFalse);
  });
}
```

Also add table-driven invalid cases for schema version, negative cash, malformed UTC timestamp, unknown sector/deposit IDs, mine level outside 1–5, negative cargo, and cargo above configured capacity.

- [ ] **Step 2: Verify repository tests fail**

```bash
flutter test test/mining/persistence/mining_save_repository_test.dart
```

Expected: FAIL because repository code does not exist.

- [ ] **Step 3: Implement safe load/save**

Create `lib/mining/persistence/mining_save_repository.dart`:

```dart
class MiningLoadResult {
  const MiningLoadResult({
    required this.state,
    required this.recoveredFromInvalidSave,
  });
  final MiningSaveV2 state;
  final bool recoveredFromInvalidSave;
}

class MiningSaveRepository {
  static const saveKey = 'horologium.mining.save.v2';

  MiningSaveRepository({MiningContentRegistry? content})
      : content = content ?? MiningContentRegistry.phaseOne();

  final MiningContentRegistry content;

  Future<MiningLoadResult> load({required DateTime nowUtc}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(saveKey);
    if (raw == null) {
      return MiningLoadResult(
        state: MiningSaveV2.initial(nowUtc: nowUtc),
        recoveredFromInvalidSave: false,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      final state = _decodeAndValidate(decoded);
      return MiningLoadResult(state: state, recoveredFromInvalidSave: false);
    } catch (_) {
      return MiningLoadResult(
        state: MiningSaveV2.initial(nowUtc: nowUtc),
        recoveredFromInvalidSave: true,
      );
    }
  }

  Future<void> save(MiningSaveV2 state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(saveKey, jsonEncode(state.toJson()));
  }
}
```

Implement `_decodeAndValidate` explicitly, not with unchecked casts. Required root fields are `schemaVersion`, `cash`, and `lastAccruedAtUtc`; sector map entries may be absent and are filled from `MiningSaveV2.initial(...)` defaults so fields introduced during HPA-631 can remain loadable. Reject data that violates domain invariants rather than clamping corrupt saves silently.

- [ ] **Step 4: Add a write-scope assertion**

After `save()`, inspect `SharedPreferences.getKeys()` and assert the repository added only `horologium.mining.save.v2`. This guards against accidental reuse of legacy city persistence.

- [ ] **Step 5: Run persistence tests**

```bash
flutter test test/mining/persistence/mining_save_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/mining/persistence/mining_save_repository.dart \
  test/mining/persistence/mining_save_repository_test.dart
git commit -m "feat: persist mining MVP state"
```

---

### Task 4: Add one atomic MiningController

**Files:**
- Create: `lib/mining/domain/mining_controller.dart`
- Create: `test/mining/domain/mining_controller_test.dart`

**Interfaces:**
- Consumes: registry, simulation, repository, UTC clock.
- Produces: controller state/listener API plus `MiningActionResult` and `MiningSaleResult`.
- Presentation code never calls repository/simulation directly.

- [ ] **Step 1: Write failing atomic-action tests**

Create `test/mining/domain/mining_controller_test.dart` using mocked SharedPreferences and a mutable test clock:

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

  test('build validates before deducting cash', () async {
    final before = controller.state.toJson();
    final result = await controller.buildMine('carbon_coal');
    expect(result.isSuccess, isFalse);
    expect(controller.state.toJson(), before);
  });

  test('gold build deducts once and creates level one mine', () async {
    final result = await controller.buildMine('landing_gold');
    expect(result.isSuccess, isTrue);
    expect(controller.state.cash, 50);
    expect(controller.state.sectors['landing_basin']!.mine!.level, 1);
  });

  test('failed upgrade preserves accrued cargo and cash', () async {
    await controller.buildMine('landing_gold');
    clock.now = clock.now.add(const Duration(seconds: 30));
    controller.refresh();
    final before = controller.state.toJson();
    final result = await controller.upgradeMine('landing_gold');
    expect(result.isSuccess, isFalse); // 50 cash < 80
    expect(controller.state.toJson(), before);
  });
}
```

Add success-path tests for Reveal, Upgrade, mixed-resource Sell All Cargo, max-level rejection, duplicate build rejection, and zero-cargo sell rejection.

- [ ] **Step 2: Verify controller tests fail**

```bash
flutter test test/mining/domain/mining_controller_test.dart
```

Expected: FAIL because `MiningController` does not exist.

- [ ] **Step 3: Implement controller construction and initialization**

Use this concrete dependency shape:

```dart
class MiningController extends ChangeNotifier {
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

  late MiningSaveV2 _state;
  MiningSaveV2 get state => _state;
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
    notifyListeners();
  }

  void refresh() {
    final accrued = simulation.accrue(_state, _nowUtc().toUtc());
    if (!identical(accrued.state, _state)) {
      _state = accrued.state;
      notifyListeners();
    }
  }
}
```

Do **not** call `repository.save()` from `refresh()`.

- [ ] **Step 4: Implement all explicit actions with a candidate-state helper**

Use one private helper to accrue without publishing:

```dart
AccrualResult _candidateNow() => simulation.accrue(_state, _nowUtc().toUtc());

Future<void> _commit(MiningSaveV2 next) async {
  _state = next;
  notifyListeners();
  await repository.save(next);
}
```

For each action, validate the complete candidate before `_commit`. Do not mutate `_state` during validation.

For Sell All Cargo, calculate revenue against the accrued candidate and build one final sector map with every mine's `storedAmount` set to `0`. Return a `MiningSaleResult` carrying the revenue and sold resource amounts so presentation can animate confirmation without re-deriving economics.

- [ ] **Step 5: Implement checkpoint and one-shot return summary**

```dart
Future<void> checkpoint() async {
  final accrued = simulation.accrue(_state, _nowUtc().toUtc());
  _state = accrued.state;
  notifyListeners();
  await repository.save(_state);
}

OfflineProductionSummary? takePendingReturnSummary() {
  final summary = _pendingReturnSummary;
  _pendingReturnSummary = null;
  return summary;
}
```

Add a `resume()` method that accrues, publishes, sets `_pendingReturnSummary` when production > 0, and performs one checkpoint save. The same simulation function remains authoritative.

- [ ] **Step 6: Prove passive refresh does not persist**

In a test, build/save once, read the raw SharedPreferences payload, advance the test clock, call `refresh()`, and assert the raw payload is unchanged even though in-memory cargo increased. Then call `checkpoint()` and assert the payload changes.

- [ ] **Step 7: Run all mining domain/persistence tests**

```bash
flutter test test/mining/domain test/mining/persistence
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/mining/domain/mining_controller.dart \
  test/mining/domain/mining_controller_test.dart
git commit -m "feat: add atomic mining controller"
```

---

### Task 5: Build the authored Flame mining world

**Files:**
- Create: `lib/mining/world/mining_game.dart`
- Create: `lib/mining/world/mining_components.dart`
- Create: `test/mining/world/mining_game_test.dart`

**Interfaces:**
- Consumes: registry and read-only `MiningSaveV2` snapshots.
- Produces: `MiningGame.applyState`, `MiningGame.focusOnSelection`, `MiningGame.playReward`, `MiningGame.onSelectionChanged`.
- Does not import controller, repository, legacy `Planet`, `Building`, or `Resources`.

- [ ] **Step 1: Write failing world mapping tests**

Test stable sector IDs and visual-tier mapping without checking economic behavior:

```dart
void main() {
  test('mine visual tiers change at levels one three and five', () {
    expect(MiningVisualTier.forLevel(1), MiningVisualTier.base);
    expect(MiningVisualTier.forLevel(2), MiningVisualTier.base);
    expect(MiningVisualTier.forLevel(3), MiningVisualTier.advanced);
    expect(MiningVisualTier.forLevel(4), MiningVisualTier.advanced);
    expect(MiningVisualTier.forLevel(5), MiningVisualTier.elite);
  });

  test('phase one world owns all three authored sector components', () async {
    final game = MiningGame(content: MiningContentRegistry.phaseOne());
    await game.onLoad();
    expect(game.sectorIds, containsAll([
      'landing_basin',
      'carbon_ridge',
      'granite_crater',
    ]));
  });
}
```

If direct `onLoad()` needs a Flutter/Flame harness, use the same `GameWidget`/tester pattern already used by repository tests for `MainGame`; do not introduce a mocking framework just for Flame.

- [ ] **Step 2: Verify world tests fail**

```bash
flutter test test/mining/world/mining_game_test.dart
```

Expected: FAIL because mining world classes do not exist.

- [ ] **Step 3: Implement mining presentation components**

Create `mining_components.dart` with:

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

String mineAssetFor(MiningResourceType resource) => switch (resource) {
      MiningResourceType.gold => 'building/gold_mine.png',
      MiningResourceType.coal => 'building/coal_mine.png',
      MiningResourceType.stone => 'building/quarry.png',
    };
```

Implement `MiningSectorComponent` so it owns only stable IDs and display state. Locked sectors render authored fog/cover; revealed empty sectors render the resource icon/deposit marker; active mines render the resource-specific existing building sprite plus tier-specific platform/light/machinery layers.

Use component colors/effects as presentation constants, not as data consumed by the economy.

- [ ] **Step 4: Implement `MiningGame` with terrain reuse and authored anchors**

Create a separate Flame game:

```dart
class MiningGame extends FlameGame with TapCallbacks, ScaleDetector {
  MiningGame({required this.content});

  final MiningContentRegistry content;
  final Map<String, MiningSectorComponent> _sectors = {};
  ValueChanged<String?>? onSelectionChanged;
  bool reducedMotion = false;

  List<String> get sectorIds => List.unmodifiable(_sectors.keys);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;

    final terrain = ParallaxTerrainComponent(gridSize: 36, seed: 631)
      ..parallaxEnabled = false
      ..anchor = Anchor.center
      ..position = Vector2.zero();
    world.add(terrain);

    for (final sector in content.sectors) {
      final component = MiningSectorComponent(definition: sector);
      _sectors[sector.id] = component;
      world.add(component);
    }

    _fitCameraToWorld();
  }

  void applyState(MiningSaveV2 state) {
    for (final sector in content.sectors) {
      _sectors[sector.id]!.applyProgress(state.sectors[sector.id]!);
    }
  }
}
```

Convert normalized content anchors into the chosen fixed world bounds inside the game/component. Copy only the minimum fit/pan/zoom clamping behavior needed from `MainGame`; do not refactor the city camera in this task.

- [ ] **Step 5: Add selection and camera focus**

Tapping a sector/deposit calls `onSelectionChanged` with the stable sector ID. Add:

```dart
void focusOnSelection({
  required String sectorId,
  required double bottomObscuredFraction,
});
```

Move the camera so the selected sector's anchor lands in the unobscured upper portion of the viewport. Clamp to world bounds. With `reducedMotion == true`, set the position immediately.

Add a test that calls the method with a non-zero obscured fraction and verifies the resulting camera target is shifted upward relative to a centered target.

- [ ] **Step 6: Run world tests**

```bash
flutter test test/mining/world/mining_game_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/mining/world/mining_game.dart \
  lib/mining/world/mining_components.dart \
  test/mining/world/mining_game_test.dart
git commit -m "feat: add authored mining world"
```

---

### Task 6: Add the portrait mining screen and temporary menu entry

**Files:**
- Create: `lib/mining/presentation/mining_screen.dart`
- Create: `lib/mining/presentation/mining_status_bar.dart`
- Create: `lib/mining/presentation/mining_action_sheet.dart`
- Create: `test/mining/presentation/mining_screen_test.dart`
- Create: `test/main_menu_test.dart`
- Modify: `lib/main_menu.dart`

**Interfaces:**
- Consumes: controller + game.
- Produces: complete active-session player controls.
- `MiningActionSheet` receives display data and callbacks only; it never calculates costs, production, or sale value.

- [ ] **Step 1: Write failing responsive-screen tests**

Create a helper that pumps `MiningScreen` with deterministic SharedPreferences and surface sizes 360×640 and 430×932. Assert:

```dart
expect(find.text('Landing Basin'), findsWidgets);
expect(find.text('SELL ALL CARGO'), findsOneWidget);
expect(tester.takeException(), isNull);

final primaryButton = tester.getSize(find.byKey(const Key('mining-primary-action')));
expect(primaryButton.height, greaterThanOrEqualTo(56));
```

Add interaction checks that selecting Landing Basin shows Gold/Build, building switches the sheet to level/rate/storage/Upgrade, and status bar never contains `Population`, `Workers`, `Happiness`, or `Research`.

- [ ] **Step 2: Write a failing menu-entry test**

Create `test/main_menu_test.dart` and assert both old and new paths remain:

```dart
expect(find.text('START EXPEDITION'), findsOneWidget);
expect(find.text('MINING MVP'), findsOneWidget);
```

Tap **MINING MVP** and verify the `MiningScreen` route appears without requiring a city building action.

- [ ] **Step 3: Verify both tests fail**

```bash
flutter test test/mining/presentation/mining_screen_test.dart test/main_menu_test.dart
```

Expected: FAIL because the mining presentation and menu entry do not exist.

- [ ] **Step 4: Implement the status bar**

`MiningStatusBar` receives only already-derived values:

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

Render the three values as Cash, Sectors, and Cargo. Keep the bar compact and SafeArea-aware.

- [ ] **Step 5: Implement the contextual action sheet**

Define a simple selection value in presentation code (`String? selectedSectorId`). Compute the sheet model in `MiningScreen` from controller state + registry, then pass text/buttons into `MiningActionSheet`.

Use `SizedBox(height: 56, width: double.infinity)` for primary actions and the key `mining-primary-action`.

Sheet states:

- none: next objective + Sell All Cargo;
- locked: reveal cost/prerequisite + Reveal Sector;
- revealed/no mine: resource/rate/capacity/build cost + Build Mine;
- mine: level/storage/rate/upgrade delta + Upgrade.

Disabled actions still explain why they are unavailable; do not hide the next useful action.

- [ ] **Step 6: Implement `MiningScreen` ownership and one-second visual refresh**

The state object should create exactly one controller and one game:

```dart
class MiningScreen extends StatefulWidget {
  const MiningScreen({super.key, this.nowUtc});
  final DateTime Function()? nowUtc;

  @override
  State<MiningScreen> createState() => _MiningScreenState();
}

class _MiningScreenState extends State<MiningScreen> with WidgetsBindingObserver {
  late final MiningContentRegistry _content;
  late final MiningController _controller;
  late final MiningGame _game;
  Timer? _refreshTimer;
  String? _selectedSectorId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _content = MiningContentRegistry.phaseOne();
    _controller = MiningController(
      content: _content,
      repository: MiningSaveRepository(content: _content),
      nowUtc: widget.nowUtc ?? () => DateTime.now().toUtc(),
    )..addListener(_onMiningStateChanged);
    _game = MiningGame(content: _content)
      ..onSelectionChanged = _onSelectionChanged;
    _initialize();
  }
}
```

After initialization, call `_game.applyState(_controller.state)` and start:

```dart
_refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
  _controller.refresh();
});
```

The timer must not call persistence.

- [ ] **Step 7: Wire successful actions from Flutter to controller**

Each callback awaits the controller result. On success:

1. apply state to `_game` via the controller listener;
2. show visible confirmation;
3. ask the game to play the corresponding reward effect (Task 7 fills the visual details).

On failure, show the controller's short reason in the sheet or `SnackBar`; do not derive a second affordability rule in Flutter.

- [ ] **Step 8: Add the temporary menu entry without changing city Start**

Modify `lib/main_menu.dart`:

```dart
import 'package:horologium/mining/presentation/mining_screen.dart';
```

Add a button near **START EXPEDITION**:

```dart
_buildMenuButton(
  'MINING MVP',
  Icons.precision_manufacturing,
  () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const MiningScreen()),
  ),
),
```

Do not rename or reroute **START EXPEDITION**.

- [ ] **Step 9: Run presentation/menu tests at both portrait sizes**

```bash
flutter test test/mining/presentation/mining_screen_test.dart test/main_menu_test.dart
```

Expected: PASS with no render overflow.

- [ ] **Step 10: Commit**

```bash
git add lib/mining/presentation \
  lib/main_menu.dart \
  test/mining/presentation/mining_screen_test.dart \
  test/main_menu_test.dart
git commit -m "feat: add mining MVP screen"
```

---

### Task 7: Complete lifecycle, offline return, rewards, and accessibility

**Files:**
- Create: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `lib/mining/world/mining_game.dart`
- Modify: `lib/mining/world/mining_components.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Modify: `test/mining/world/mining_game_test.dart`

**Interfaces:**
- Consumes: `MiningActionResult`, `MiningSaleResult`, `OfflineProductionSummary`.
- Produces: presentation-only reward effects and one-shot return/recovery UI.
- No effect completion is awaited before domain success is committed.

- [ ] **Step 1: Add failing lifecycle/offline/recovery tests**

Add tests that:

1. seed an active gold mine in SharedPreferences;
2. construct a `MiningScreen` at T0 and dispose/checkpoint;
3. advance injected clock;
4. recreate/resume at T1;
5. assert one offline sheet appears with Gold produced;
6. dismiss it and assert it does not reappear on rebuild;
7. seed malformed mining JSON and assert one non-blocking recovery `SnackBar` appears.

Also pump with:

```dart
MediaQuery(
  data: const MediaQueryData(disableAnimations: true),
  child: MaterialApp(home: MiningScreen(nowUtc: clock.call)),
)
```

and assert Build/Reveal/Upgrade/Sell still show text/number confirmation.

- [ ] **Step 2: Verify the new tests fail**

```bash
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: FAIL because lifecycle summary/recovery/reduced-motion handling is incomplete.

- [ ] **Step 3: Implement `OfflineReturnSheet`**

Create a compact bottom sheet/dialog that takes the summary plus content registry and renders:

- formatted elapsed duration actually used;
- non-zero Gold/Coal/Stone produced;
- `Storage full` for deposits present in `fullDepositIds`;
- `Offline limit reached` when `wasOfflineCapped` is true;
- one next-action sentence based on current state.

Do not add claim buttons. Offline cargo is already authoritative state before the sheet appears.

- [ ] **Step 4: Wire app lifecycle to one checkpoint/resume path**

In `MiningScreen.didChangeAppLifecycleState`:

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

`_resumeMining()` awaits `controller.resume()`, restarts the one-second timer, and consumes `takePendingReturnSummary()` exactly once.

On cold initialization, perform the same one-shot summary display after the first frame.

- [ ] **Step 5: Show invalid-save recovery once**

After initialize, if `controller.recoveredFromInvalidSave`, schedule a post-frame `SnackBar` with copy such as:

```text
Mining progress could not be loaded, so a fresh mining save was started.
```

Do not block entry and do not expose raw JSON/error details.

- [ ] **Step 6: Implement four presentation-only reward effects**

Add a small enum:

```dart
enum MiningRewardEffect { reveal, construction, tierUpgrade, sale }
```

`MiningGame.playReward(effect, sectorId)` drives effects only:

- reveal: scanner line/ring + fog fade;
- construction: scale/fade facility in with dust/glow;
- tier upgrade: pulse and reveal added platform/light layers at level 3/5;
- sale: short particles/cargo indicators from active mines toward the HUD direction.

The controller result is already committed before this method is called.

- [ ] **Step 7: Add reduced-motion branches**

Set before rendering:

```dart
final reducedMotion = MediaQuery.of(context).disableAnimations;
_game.reducedMotion = reducedMotion;
```

When true, replace scanner/camera/particle movement with immediate state application plus short opacity/number transitions. Keep the same visible confirmation text.

- [ ] **Step 8: Add success haptics without making them required**

After successful Reveal/Build/Upgrade/Sell calls, use `HapticFeedback.lightImpact()` or `mediumImpact()` without awaiting it as part of the economic transaction. No vibration availability check or platform abstraction is required.

- [ ] **Step 9: Run world and presentation tests**

```bash
flutter test test/mining/world/mining_game_test.dart \
  test/mining/presentation/mining_screen_test.dart
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/mining/presentation/offline_return_sheet.dart \
  lib/mining/presentation/mining_screen.dart \
  lib/mining/world/mining_game.dart \
  lib/mining/world/mining_components.dart \
  test/mining/presentation/mining_screen_test.dart \
  test/mining/world/mining_game_test.dart
git commit -m "feat: complete mining return and reward UX"
```

---

### Task 8: Prove the complete first-session and offline-return journey

**Files:**
- Create: `test/integration/mining_mvp_journey_test.dart`
- Modify only if a discovered testability bug requires it: mining files from Tasks 1–7.

**Interfaces:**
- Exercises the real mining registry, simulation, controller, repository, presentation, and navigation path together.
- Uses existing Flutter test runtime; no new dependency or CI job.

- [ ] **Step 1: Write the full-journey test with a deterministic clock**

Use mocked SharedPreferences and `MiningScreen(nowUtc: clock.call)`. Walk the real UI. The balance is intentionally deterministic, so advance the clock enough to make each action affordable instead of injecting cash shortcuts.

Representative flow:

```dart
await tester.tap(find.text('MINING MVP'));
await tester.pumpAndSettle();

// Landing Basin / Gold
await tester.tap(find.text('Landing Basin').first);
await tester.tap(find.text('BUILD MINE'));
await tester.pump();

clock.now = clock.now.add(const Duration(minutes: 2));
await tester.pump(const Duration(seconds: 1));
await tester.tap(find.text('SELL ALL CARGO'));
await tester.pump();

await tester.tap(find.text('UPGRADE'));
await tester.pump();

// Continue earning/selling until Carbon Ridge reveal/build is affordable.
// Repeat the same real UI path for Granite Crater.
```

Do not call controller methods directly from this integration test. Use visible buttons and injected time only.

- [ ] **Step 2: Finish the three-sector active progression in the test**

The test must verify, through visible UI state:

- gold mine exists and upgrades;
- Carbon Ridge becomes revealed and coal mine is built;
- Granite Crater becomes revealed and stone mine is built;
- cargo display includes value from multiple active mines;
- one Sell All Cargo clears all active cargo and increases cash.

If a timing interval hits storage capacity, assert the cap rather than bypassing it.

- [ ] **Step 3: Finish the offline-return portion**

Checkpoint by simulating `AppLifecycleState.paused` or disposing the screen after a persisted action, then:

1. read the saved payload and keep it unchanged;
2. advance the deterministic clock by 2 hours;
3. recreate `MiningScreen`;
4. assert `OfflineReturnSheet` reports produced cargo;
5. assert restored storage equals a direct `MiningSimulation.accrue(savedState, T1)` expectation.

Add a second calculation with 12 hours elapsed and assert only 8 hours are considered before storage caps.

- [ ] **Step 4: Verify the journey test fails before fixing any integration gaps**

```bash
flutter test test/integration/mining_mvp_journey_test.dart
```

Expected on first run: either PASS if seams align or a specific failure showing a real integration mismatch. Fix only the mismatch; do not add parallel test-only production paths.

- [ ] **Step 5: Run all mining tests together**

```bash
flutter test test/mining test/integration/mining_mvp_journey_test.dart test/main_menu_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit the full journey coverage**

```bash
git add test/integration/mining_mvp_journey_test.dart
git commit -m "test: cover complete mining MVP journey"
```

---

### Task 9: Run repository verification and record product-review evidence

**Files:**
- No planned source file changes.
- Linear HPA-631 receives the final reviewed-build comment only after implementation/playtest evidence exists.

**Interfaces:**
- Produces the merge gate for the single HPA-631 PR and the HPA-631 product decision.

- [ ] **Step 1: Run formatting**

```bash
dart format --output=none --set-exit-if-changed .
```

Expected: exit 0.

- [ ] **Step 2: Run static analysis**

```bash
flutter analyze --fatal-infos
```

Expected: exit 0 with no infos/warnings/errors promoted by the repository configuration.

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

- [ ] **Step 5: Build representative application artifacts**

```bash
flutter build apk --debug
flutter build web
```

Expected: both exit 0.

On a Mac with the normal iOS toolchain available, also run a simulator/device development build during the portrait playtest. This is acceptance evidence, not a new CI requirement.

- [ ] **Step 6: Perform the narrow/tall portrait smoke**

On representative portrait targets, verify:

- fresh player identifies gold and builds within one minute;
- selected deposit stays visible above the sheet;
- primary actions are comfortable to tap;
- scanner/build/upgrade/sale rewards are readable rather than noisy;
- level 1/3/5 mine presentations are visibly different;
- audio off still leaves clear confirmation;
- reduced-motion mode remains understandable;
- leave/return summary makes the next useful action obvious;
- no legacy city page is required to complete the mining loop.

Record exact device/simulator model, OS/runtime, build SHA, and observations.

- [ ] **Step 7: Self-review against the HPA-631 spec before changing PR status**

Check every acceptance item in `docs/superpowers/specs/2026-08-18-hpa-631-one-planet-mining-mvp-design.md`. In particular, search for accidental dependencies on legacy economy classes:

```bash
grep -R "game/building\|game/resources\|GameStateManager\|SaveService\|ActivePlanet" lib/mining || true
```

Expected: no legacy economy imports/usages. Imports of shared terrain/audio infrastructure outside those forbidden economy classes are allowed.

- [ ] **Step 8: Keep the PR as one HPA-631 PR and post the Linear conclusion**

After a human/product review of the completed build, add one HPA-631 comment containing:

```text
Reviewed build: <commit SHA>
Device/runtime: <actual device or simulator>
Observed opening loop: <measured first-mine and first-sale notes>
Offline-return notes: <observations>
Visual/reward notes: <observations>
Decision: Proceed to cutover | Revise once | Stop/reconsider
```

Choose exactly one decision from the three HPA-631 options. Do not move to HPA-636 unless the decision is **Proceed to cutover**.

- [ ] **Step 9: Final commit only if verification required source/test fixes**

If verification exposed a real bug, fix it with its regression test and commit it on the same branch:

```bash
git add <changed source and test files>
git commit -m "fix: close mining MVP verification gap"
```

Do not create a second PR.

---

## Plan self-review

### Spec coverage

- Three sectors/resources, fixed deposits, five levels: Tasks 1, 5, 6.
- Deterministic foreground/resume/cold-launch production, storage cap, rollback, 8-hour cap: Tasks 2, 4, 7, 8.
- Atomic Reveal/Build/Upgrade/Sell and mixed cargo: Task 4 + Task 8.
- One safe V2 document, legacy-key isolation, non-blocking recovery, no per-refresh writes: Tasks 3, 4, 7.
- Portrait status/world/sheet, 56 px targets, selected content visible: Tasks 5, 6.
- Four reward moments, reduced motion, no-audio confirmation: Task 7.
- Full first-session/offline-return journey: Task 8.
- Analysis/format/tests/builds + product decision evidence: Task 9.
- No city cutover/technology/processing/multi-planet work: global constraints and file map keep those out.

### Placeholder scan

The plan contains no `TBD`, deferred implementation placeholder, generic “add tests” step, or unspecified architecture seam. Balance values, save key, IDs, public method names, asset paths, test sizes, and verification commands are explicit.

### Type consistency

- `MiningContentRegistry` is used by simulation, repository validation, controller, world, and presentation.
- `MiningSaveV2` is the single mutable-progress document across simulation/controller/repository/world snapshots.
- `OfflineProductionSummary` is produced by simulation and consumed by controller/presentation.
- `MiningController` is the only presentation-facing mutation boundary.
- `MiningGame.applyState()` consumes read-only state and does not own economics.

## Execution handoff

Implement this plan on `jack65786656/hpa-631-build-and-validate-the-one-planet-mining-mvp` inside the same draft PR. Use subagent-driven development or inline plan execution with review checkpoints, but keep the complete ticket in one PR unless the user explicitly approves a change to that policy.
