# HPA-638 Technology and Lunar Frontier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the three cash-funded technology tracks, Lunar Frontier, active-planet selling, and deterministic two-planet idle production while preserving the existing single-controller mining architecture.

**Architecture:** Planet grouping lives in `MiningContentRegistry`; mutable sector progress stays the existing flat `Map<MiningSectorId, SectorProgress>` because sector IDs are globally unique. Simulation iterates unlocked planets, active UI/sell/game iterate the active planet, and `MiningGame` is replaced via `ValueKey(activePlanetId)` when travel changes the projection.

**Tech Stack:** Dart 3.8, Flutter, Flame 1.30, SharedPreferences 2.5, existing `flutter_test` suites.

**Spec:** `docs/superpowers/specs/2026-08-21-hpa-638-technology-lunar-frontier-design.md`

## Global Constraints

- One PR for HPA-638; continue on draft PR #16.
- Cash is the only spendable progression currency.
- Keep one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, and `horologium.mining.save` key.
- No `schemaVersion`, migration registry, or v1 converter; incompatible development saves use the existing clean-reset recovery path.
- Final catalog has no public flat `content.sectors` getter and no `phaseOne()` alias.
- Keep `MiningSave.sectors` flat; do not add `MiningPlanetProgress`, `progressFor`, or `withSector`.
- `TechnologyLevels.levelFor()` and `withLevel()` are required.
- Lunar unlock = Homeworld mastery + Surveying 3 + 2,500 cash.
- Sell All sells the active planet only; cash remains global.
- One UTC accrual window advances all unlocked planets.
- Mining rates render with two decimals.
- No new image files; reuse existing facility PNGs and built-in Material icons for Lunar resource silhouettes.
- Every task finishes with `flutter analyze --fatal-infos` and `flutter test` green before commit.

## Final File Map

**Core:**
- `lib/mining/mining_content.dart` — planet catalog, technology tables/effects, mastery/unlock helpers.
- `lib/mining/mining_state.dart` — flat six-sector save plus `TechnologyLevels`.
- `lib/game/resources/resource_type.dart` — six closed resource IDs.
- `lib/mining/mining_save_repository.dart` — strict current shape, Logistics-aware clamp, no legacy conversion.
- `lib/mining/mining_simulation.dart` — multi-planet accrual and grouped production summary.
- `lib/mining/mining_controller.dart` — technology/unlock/switch mutations and active-only sell.

**Pure presentation:**
- `lib/mining/mining_sheet_view.dart` — active-planet affordances with Surveying/effective values.
- `lib/mining/mining_progression_views.dart` — Technology and Stellar Map view models.

**Flutter/Flame:**
- `lib/mining/presentation/technology_sheet.dart`
- `lib/mining/presentation/stellar_map_sheet.dart`
- `lib/mining/presentation/mining_screen.dart`
- `lib/mining/presentation/mining_status_bar.dart`
- `lib/mining/presentation/offline_return_sheet.dart`
- `lib/mining/world/mining_game.dart`
- `lib/mining/world/mining_components.dart` only if a small Lunar atmosphere overlay is needed.

**No new PNG files.** Reuse `Assets.waterTreatmentPlant`, `Assets.grinderMill`, and `Assets.researchLab` for the three Lunar facilities.

---

### Task 1: Establish the two-planet catalog and flat current save contract, then retarget every existing consumer

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_state.dart`
- Modify: `lib/game/resources/resource_type.dart`
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/mining/mining_simulation.dart`
- Modify: `lib/mining/mining_controller.dart`
- Modify: `lib/mining/mining_sheet_view.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/mining/world/mining_game.dart`
- Modify: existing mining tests/fixtures that construct content or saves
- Create: `test/mining/mining_state_test.dart`

**Produces:** `MiningPlanetId`, `MiningPlanetDefinition`, `TechnologyTrack`, `TechnologyLevels.levelFor/withLevel`, `MiningContentRegistry.stellarMining/planet/sector/planetForSector`, flat six-sector `MiningSave`, strict current save root.

- [ ] **Step 1: Add RED catalog/state tests**

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
```

Add exact Lunar balance assertions and assert Homeworld seed `631`, Lunar seed `638`.

Add required technology-state tests:

```dart
const levels = TechnologyLevels(extraction: 1, logistics: 2, surveying: 3);
expect(levels.levelFor(TechnologyTrack.extraction), 1);
expect(levels.levelFor(TechnologyTrack.logistics), 2);
expect(levels.levelFor(TechnologyTrack.surveying), 3);
expect(
  levels.withLevel(TechnologyTrack.extraction, 4),
  const TechnologyLevels(extraction: 4, logistics: 2, surveying: 3),
);
```

Assert `MiningSave.initial()` contains exactly six sector keys, Homeworld unlocked/active, Lunar pristine, and technology 0/0/0.

- [ ] **Step 2: Add RED persistence tests for the current shape and old-shape reset**

Current raw JSON keys must be exactly:

```dart
expect(decoded.keys.toSet(), {
  'cash',
  'lastAccruedAtUtc',
  'technology',
  'unlockedPlanetIds',
  'activePlanetId',
  'sectors',
});
```

Seed the previous three-key development document and assert it uses the existing recovery boundary:

```dart
expect(result.recoveredFromInvalidSave, isTrue);
expect(result.wasMissing, isFalse);
expect(result.state, MiningSave.initial(nowUtc: now));
```

Do **not** add `migratedLegacyV1`.

- [ ] **Step 3: Run RED**

```sh
flutter test test/mining/mining_content_test.dart \
  test/mining/mining_state_test.dart \
  test/mining/mining_save_repository_test.dart
```

Expected: compile/test failure because the new identities/state/save shape do not exist.

- [ ] **Step 4: Implement the catalog, flat state, and current decoder**

Add the final closed IDs and `requiredSurveyingLevel`. `MiningContentRegistry` must expose planet selection but no final flat sectors getter.

Keep mutable sectors flat:

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

`TechnologyLevels` contains the single exhaustive track switch in `levelFor` and `withLevel`.

Repository decode order:

```text
cash/timestamp
→ technology
→ unlocked/active planets
→ six sector records
→ cross-field checks
```

Clamp mine cargo with `effectiveCapacity(..., technology.logistics)`.

- [ ] **Step 5: Mechanically retarget all existing runtime/test consumers before this task commits**

Replace all `MiningContentRegistry.phaseOne()` call sites with `stellarMining()`.

Replace each `content.sectors` iteration according to ownership:

```dart
// simulation
for (final planetId in state.unlockedPlanetIds) {
  for (final definition in content.planet(planetId).sectors) { ... }
}

// sell/HUD/tabs/sheet
for (final definition in content.planet(state.activePlanetId).sectors) { ... }
```

Existing controller sector mutations continue to index the flat map directly:

```dart
final progress = candidate.state.sectors[id]!;
final sectors = <MiningSectorId, SectorProgress>{...candidate.state.sectors};
sectors[id] = nextProgress;
```

For the still-single projected Flame world, make its sector source explicit from a `MiningPlanetDefinition`; Task 5 will add replacement lifecycle semantics.

Update every fixture literal to include the three pristine Lunar sector keys plus technology/unlocked/active fields. Do not postpone this cleanup to the journey task.

- [ ] **Step 6: Full GREEN before commit**

```sh
flutter analyze --fatal-infos
flutter test
```

Expected: both PASS.

Commit:

```sh
git add lib test
git commit -m "feat(mining): establish two-planet catalog and save"
```

---

### Task 2: Apply technology to deterministic multi-planet simulation

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_simulation.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_simulation_test.dart`

**Produces:** `effectiveRate`, `effectiveCapacity`, `offlineCapFor`, `productionByPlanet`, flat `fullSectors`.

- [ ] **Step 1: Add RED economy-helper tests**

Pin all Extraction/Logistics values and exact examples:

```dart
expect(content.effectiveRate(MiningSectorId.landingBasin, 1, 1), 0.55);
expect(content.effectiveCapacity(MiningSectorId.landingBasin, 1, 2), 117.0);
expect(content.offlineCapFor(5), const Duration(hours: 24));
```

- [ ] **Step 2: Add RED two-planet accrual tests**

Build one mine on each unlocked planet, advance the clock once, and assert both use the same elapsed window and technology exactly once. Repeat with Lunar locked and assert Lunar cargo remains unchanged.

Assert summary shape:

```dart
expect(summary.productionByPlanet[MiningPlanetId.homeworld]![ResourceType.gold], greaterThan(0));
expect(summary.productionByPlanet[MiningPlanetId.lunarFrontier]![ResourceType.waterIce], greaterThan(0));
expect(summary.fullSectors, contains(MiningSectorId.frozenBasin));
```

`fullSectors` is a flat set; do not add `fullSectorsByPlanet`.

- [ ] **Step 3: Run RED, implement minimally, run focused GREEN**

```sh
flutter test test/mining/mining_content_test.dart test/mining/mining_simulation_test.dart
```

Simulation structure:

```dart
for (final planetId in state.unlockedPlanetIds) {
  for (final definition in content.planet(planetId).sectors) {
    final progress = sectors[definition.id]!;
    final mine = progress.mine;
    if (mine == null) continue;
    final rate = content.effectiveRate(
      definition.id,
      mine.level,
      state.technology.extraction,
    );
    final capacity = content.effectiveCapacity(
      definition.id,
      mine.level,
      state.technology.logistics,
    );
    // existing elapsed/clamp math
  }
}
```

- [ ] **Step 4: Full GREEN and commit**

```sh
flutter analyze --fatal-infos
flutter test
git add lib/mining test/mining
git commit -m "feat(mining): accrue technology across planets"
```

---

### Task 3: Add serialized technology purchase, Lunar unlock, travel, and active-only selling

**Files:**
- Modify: `lib/mining/mining_controller.dart`
- Modify: `test/mining/mining_controller_test.dart`

**Produces:** `purchaseTechnology`, `unlockPlanet`, `switchPlanet`, active-only `sellAllCargo`.

- [ ] **Step 1: Add RED technology tests**

Cover success, insufficient cash, unmet mine gate, and level 5. Assert only the selected track changes:

```dart
final result = await controller.purchaseTechnology(TechnologyTrack.extraction);
expect(result.isSuccess, isTrue);
expect(controller.state.technology.extraction, 1);
expect(controller.state.technology.logistics, 0);
```

Use `levelFor/withLevel`; do not add track switches to the controller.

- [ ] **Step 2: Add RED unlock/travel/sell tests**

Pin three Lunar unlock failures independently: missing mastery, Surveying 2, cash 2,499. Pin success as atomic cash + unlock + active change.

With cargo on both planets, Homeworld-active `sellAllCargo()` clears/credits Homeworld only.

`switchPlanet()` accrues before changing active ID and rejects a locked target without mutation.

- [ ] **Step 3: Add RED future-chain overlap regression**

Queue `switchPlanet()` followed by `sellAllCargo()` or `purchaseTechnology()` against the existing delayed repository fake. Release the first save and assert the second mutation starts from the first committed state.

- [ ] **Step 4: Implement using the existing `_enqueueMutation` only**

No commands or new state owner. Reveal additionally rejects insufficient Surveying:

```dart
if (candidate.state.technology.surveying < definition.requiredSurveyingLevel) {
  return MiningActionResult.failure(
    'Requires Surveying ${definition.requiredSurveyingLevel}.',
  );
}
```

- [ ] **Step 5: Focused + full GREEN and commit**

```sh
flutter test test/mining/mining_controller_test.dart
flutter analyze --fatal-infos
flutter test
git add lib/mining/mining_controller.dart test/mining/mining_controller_test.dart
git commit -m "feat(mining): add technology and planet progression"
```

---

### Task 4: Make all affordances pure and pin visible technology numbers

**Files:**
- Modify: `lib/mining/mining_sheet_view.dart`
- Create: `lib/mining/mining_progression_views.dart`
- Modify: `test/mining/mining_sheet_view_test.dart`
- Create: `test/mining/mining_progression_views_test.dart`

**Produces:** technology-aware `MiningSheetView`, `TechnologySheetView.from`, `StellarMapView.from`.

- [ ] **Step 1: Add RED MiningSheetView tests**

Use Landing Basin L1 and pin exact Extraction strings:

```text
Lv0 0.50/s
Lv1 0.55/s
Lv2 0.63/s
Lv3 0.73/s
Lv4 0.85/s
Lv5 1.00/s
```

Change the rate formatter to `toStringAsFixed(2)`.

Add Frozen Basin at Surveying 2 and assert Reveal is disabled with `Requires Surveying 3.` even though reveal cost is zero.

Sell-view totals must include only `content.planet(state.activePlanetId).sectors`.

- [ ] **Step 2: Add RED Technology/Stellar Map view tests**

Technology view model exposes current level/effect, next effect, cost, gate, affordability, and max state. Stellar Map exposes Homeworld mastery count plus independent Lunar requirements for mastery, Surveying 3, and 2,500 cash.

- [ ] **Step 3: Implement pure factories only**

Widgets are not part of this task. Use content helpers and `TechnologyLevels.levelFor()`; do not copy controller rules into widgets.

- [ ] **Step 4: Focused + full GREEN and commit**

```sh
flutter test test/mining/mining_sheet_view_test.dart test/mining/mining_progression_views_test.dart
flutter analyze --fatal-infos
flutter test
git add lib/mining test/mining
git commit -m "feat(mining): derive progression affordances"
```

---

### Task 5: Make `MiningGame` safely replaceable before exposing travel in Flutter

**Files:**
- Modify: `lib/mining/world/mining_game.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `test/mining/world/mining_game_test.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`

**Produces:** planet-specific game constructor, post-`onLoad` initial state application, `ValueKey(activePlanetId)` replacement.

- [ ] **Step 1: Add RED pre-`onLoad` state test**

Construct Lunar game with revealed Frozen Basin + built mine, mount/load, and assert the sector reflects that initial state. This proves constructor state is applied after components exist.

- [ ] **Step 2: Add RED cold-start construction regression**

Prove `MiningScreen.initState` can build before controller initialization. The initial game must use `_displayState.sectors`, not `_controller.state`.

- [ ] **Step 3: Add RED replacement-identity tests**

After an injected controller state switches from Homeworld to Lunar, assert:

```dart
expect(find.byKey(const ValueKey(MiningPlanetId.lunarFrontier)), findsOneWidget);
expect(newGame, isNot(same(oldGame)));
expect(controller, same(originalController));
expect(audioManager, same(originalAudioManager));
```

Keep one timer/lifecycle observer and assert old-game selection/reward callbacks cannot receive later actions.

- [ ] **Step 4: Implement the boundary**

```dart
MiningGame({
  required MiningPlanetDefinition planet,
  required Map<MiningSectorId, SectorProgress> initialProgress,
});
```

`onLoad()` creates `planet.sectors`, then applies `initialProgress`.

Screen rules:

```text
initState game → _displayState.sectors
post-unlock/travel replacement → _controller.state.sectors
```

Selection resets to Sell on replacement.

- [ ] **Step 5: Focused + full GREEN and commit**

```sh
flutter test test/mining/world/mining_game_test.dart test/mining/presentation/mining_screen_test.dart
flutter analyze --fatal-infos
flutter test
git add lib/mining/world lib/mining/presentation/mining_screen.dart test/mining
git commit -m "feat(mining): replace planet game projection safely"
```

---

### Task 6: Add Technology/Stellar Map UI, active-planet HUD, Lunar visuals, and grouped return presentation

**Files:**
- Create: `lib/mining/presentation/technology_sheet.dart`
- Create: `lib/mining/presentation/stellar_map_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `lib/mining/presentation/mining_status_bar.dart`
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/world/mining_game.dart`
- Modify: presentation/world tests

- [ ] **Step 1: Add RED modal/chrome tests**

Pin keys for Technology, Stellar Map, and Settings controls. Verify Stellar Map is reachable at Surveying 0. Verify exact unmet Lunar requirements and purchase/unlock/travel callbacks.

Check 360×640 and 430×932 geometry; all controls are at least 48 logical pixels and do not overlap status/tabs/action sheet.

- [ ] **Step 2: Add RED active-planet HUD and grouped return tests**

HUD totals only active-planet sectors. Return sheet renders one section per `productionByPlanet` entry and resolves `fullSectors` by filtering the catalog.

- [ ] **Step 3: Add RED Lunar visual identity tests**

Pin facility mapping without new assets:

```dart
expect(content.sector(MiningSectorId.frozenBasin).mineAsset, Assets.waterTreatmentPlant);
expect(content.sector(MiningSectorId.titaniumHighlands).mineAsset, Assets.grinderMill);
expect(content.sector(MiningSectorId.heliumMare).mineAsset, Assets.researchLab);
```

Pin Homeworld seed 631 vs Lunar 638 and a different mining-world tint.

For resource silhouettes, use built-in Material icons rather than PNGs; test Water Ice/Titanium/Helium map to distinct icon data plus distinct names/colors.

- [ ] **Step 4: Implement widgets as render/delegate surfaces**

`TechnologySheet` and `StellarMapSheet` receive pure view models and callbacks. They do not calculate eligibility.

Successful unlock/travel waits for the controller mutation, then recreates `MiningGame`; failure leaves the current game mounted.

Reduced motion keeps settled confirmation and haptic/state change without nonessential animation.

- [ ] **Step 5: Focused + full GREEN and commit**

```sh
flutter test test/mining/presentation/mining_screen_test.dart \
  test/mining/world/mining_game_test.dart
flutter analyze --fatal-infos
flutter test
git add lib test
git commit -m "feat(mining): add technology and Stellar Map UI"
```

---

### Task 7: Prove the two product journeys without a new harness

**Files:**
- Modify: `test/integration/mining_mvp_journey_test.dart` or create `test/integration/mining_multi_planet_journey_test.dart` if separation is clearer.

- [ ] **Step 1: Add progression journey**

Start from a valid **current-format** seeded state with the three Homeworld mines and enough cash; do not test legacy migration. Purchase Surveying 1→3, unlock Lunar Frontier, reveal Frozen Basin, build Water Ice, switch back Homeworld, and assert both planet states remain intact.

- [ ] **Step 2: Add two-planet offline journey**

Persist built mines on both unlocked planets, advance UTC, initialize once, assert one grouped return summary contains both planets, sell active planet, switch, sell the other, and assert global cash + planet-local cargo are correct.

- [ ] **Step 3: Full GREEN and commit**

```sh
flutter analyze --fatal-infos
flutter test
git add test/integration
git commit -m "test(mining): cover Lunar progression journeys"
```

---

### Task 8: Update authoritative docs and run final repository gates

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: PR #16 description only after code/test state is known.

- [ ] **Step 1: Update docs after implementation behavior is green**

Document:

- two-planet catalog + flat six-sector state;
- technology effects;
- active-planet selling;
- one-window multi-planet accrual;
- keyed `MiningGame` replacement;
- incompatible pre-release save data clean-resets; no migration reader exists.

Do not revive retired agent docs.

- [ ] **Step 2: Run all final gates**

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Expected: all PASS.

- [ ] **Step 3: Representative portrait smoke**

Exercise technology purchase, Stellar Map requirement, Lunar unlock, visual distinction, first Lunar mine, switch back, and two-planet return on a representative portrait target. Record only concrete issues; do not add a new performance/screenshot harness.

- [ ] **Step 4: Commit docs/verification metadata**

```sh
git add CLAUDE.md README.md
git commit -m "docs: describe technology and Lunar progression"
```

## Self-review checklist

Before execution, the plan must satisfy all of these:

- no nested planet progress type or state helper remains;
- no `migratedLegacyV1`/legacy converter remains;
- no new PNG path remains;
- rate formatting is pinned to two decimals;
- cold start uses `_displayState`, post-switch uses controller state;
- `fullSectors` is flat;
- `TechnologyLevels.levelFor/withLevel` is mandatory;
- Task 1 owns mechanical retargeting;
- every task ends with full analyze + test green;
- journey fixtures use only current save shape.
