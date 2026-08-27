# HPA-285 Horologium Mobile Merge-Mining Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remodel the existing mining runtime in place into one mobile merge-mining loop with meaningful rig-driven throughput/storage, a responsive Site Deck/Mine Site/Stellar Map UI, deterministic live/offline production, and all three authored planets.

**Architecture:** Keep the current flat mining core files and evolve them in place. Sites remain globally identified and flat in the save; planet docks become exact-key `DockBayId` maps. `MiningScreen` is isolated into a Flame-free `MiningShell` as soon as the core remodel is coherent, restoring the full-suite gate before visual work. Per-site asset paths live on the existing content definitions; shared node anchors and common assets stay in presentation constants.

**Tech Stack:** Flutter/Dart, SharedPreferences, audioplayers, Flutter widget tests, deterministic pure-Dart tests, existing GitHub Actions/build targets.

**Spec:** `docs/superpowers/specs/2026-08-26-hpa-285-mobile-merge-mining-redesign-design.md`

## Global Constraints

- Keep all planning, implementation, cleanup, and verification on PR #19 / HPA-285.
- Modify the existing `lib/mining/mining_*.dart` core in place; do not create `lib/mining/domain/` or duplicate core types/tables.
- Use one `MiningShell`, one controller, one simulation, one repository, one timer, one `AudioManager`, and one lifecycle observer.
- Use Flutter for new surfaces; do not build a replacement Flame world.
- Use `horologium.mergeMining.save`; ignore `horologium.mining.save`; add no migration/version/compatibility branch.
- Keep flat globally unique `MiningSiteId` progress plus per-planet exact-key `DockBayId` maps.
- Use `DockBayId { b1, b2, b3, b4 }`, `MiningNodeId { n1, n2, n3, n4 }`, and `RigTier { t1, t2, t3, t4, t5 }` at public/save boundaries.
- Reuse current `rateMultipliers = [1.0, 1.5, 2.25, 3.25, 4.5]` and `capacityMultipliers = [1.0, 1.5, 2.0, 3.0, 4.0]` per deployed rig.
- Site rate and capacity both scale with the sum of deployed rig shares. Do not divide capacity shares by four.
- Recall must fail when removing a rig would leave stored cargo above post-recall capacity.
- Preserve `MiningController.refresh()` live in-memory accrual and missing/recovered initial-save persistence.
- Preserve active-planet selling, current technology/planet requirements, and the 25,000 Mars false-to-true mastery reward.
- Do not add depletion, drag/drop, rig UUIDs, workers, crafting, processing, dynamic prices, another currency, retention systems, server/account/cloud features, repository interfaces, state-management/routing packages, or generic frameworks.
- Per-site cavern/node/card paths belong on `MiningSiteDefinition`; `mining_visuals.dart` owns shared anchors and common rig/icon/effect paths only.
- Use system typography; remove undeclared Orbitron.
- Controls are >=48x48. Cover 360x640, 402x874, 430x932, 874x402, text scale 1.3, reduced motion, muted audio, and safe areas.
- The twelve missing Lunar/Mars cavern/node PNGs are external inputs. They gate only final Lunar/Mars visual completion and PR merge, not Homeworld/shell implementation.
- Do not stage the unpacked prototype ZIP wholesale.

---

## Final File Map

```text
lib/mining/
  mining_content.dart
  mining_state.dart
  mining_simulation.dart
  mining_save_repository.dart
  mining_controller.dart
  fleet_dock_view.dart
  site_deck_view.dart
  mine_site_view.dart
  mining_progression_views.dart
  presentation/
    mining_shell.dart
    mining_theme.dart
    mining_visuals.dart
    mining_navigation.dart
    mining_hud.dart
    fleet_dock.dart
    site_deck_screen.dart
    mine_site_screen.dart
    stellar_map_screen.dart
    technology_sheet.dart
    mining_settings_sheet.dart
    offline_return_sheet.dart
```

`mining_hud.dart` is a rename/evolution of the existing `mining_status_bar.dart`. Existing file names are retained when ownership is unchanged.

---

### Task 1: Remodel Catalog, Closed IDs, Capacity, and State In Place

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_state.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_state_test.dart`

**Interfaces:**
- Produces: `MiningSiteId`, `MiningNodeId`, `DockBayId`, `RigTier`, updated definitions, flat `MiningSave.sites`, enum-keyed `MiningSave.docks`.
- Preserves: `MiningPlanetId`, `TechnologyTrack`, `TechnologyLevels`, resource identity, technology/offline tables, planet unlock/mastery metadata.

- [ ] **Step 1: Replace identity/catalog assertions first**

Write failing tests that rename `MiningSectorId` to `MiningSiteId` and assert:

```dart
test('keeps closed site, node, bay, and rig identities', () {
  expect(MiningSiteId.values, hasLength(9));
  expect(MiningNodeId.values.map((id) => id.name), ['n1', 'n2', 'n3', 'n4']);
  expect(DockBayId.values.map((id) => id.name), ['b1', 'b2', 'b3', 'b4']);
  expect(RigTier.values.map((tier) => tier.name), ['t1', 't2', 't3', 't4', 't5']);
});

test('reuses current rate and capacity ladders for rigs', () {
  expect(MiningContentRegistry.rateMultipliers, [1.0, 1.5, 2.25, 3.25, 4.5]);
  expect(MiningContentRegistry.capacityMultipliers, [1.0, 1.5, 2.0, 3.0, 4.0]);
});
```

Freeze all nine current resource/unlock/rate/base-capacity/sale values, node Surveying requirements, spawn costs `25/500/5000`, technology tables, planet requirements, and Mars reward.

- [ ] **Step 2: Add failing capacity behavior tests**

```dart
test('one T1 preserves the current Landing Basin base capacity', () {
  final content = MiningContentRegistry.stellarMining();
  expect(
    content.effectiveSiteCapacity(
      MiningSiteId.landingBasin,
      const [RigTier.t1],
      0,
    ),
    90,
  );
});

test('four rigs contribute storage shares without normalization', () {
  final content = MiningContentRegistry.stellarMining();
  expect(
    content.effectiveSiteCapacity(
      MiningSiteId.landingBasin,
      const [RigTier.t1, RigTier.t1, RigTier.t1, RigTier.t1],
      0,
    ),
    360,
  );
  expect(
    content.effectiveSiteCapacity(
      MiningSiteId.landingBasin,
      const [RigTier.t5, RigTier.t5, RigTier.t5, RigTier.t5],
      5,
    ),
    2880,
  );
});
```

- [ ] **Step 3: Run catalog tests and verify RED**

Run: `flutter test test/mining/mining_content_test.dart`

Expected: FAIL on the new identities/helpers.

- [ ] **Step 4: Remodel `mining_content.dart` in place**

Rename:

```dart
MiningSectorId -> MiningSiteId
MiningSectorDefinition -> MiningSiteDefinition
requiredSector -> requiredSite
revealCost -> unlockCost
sector(...) -> site(...)
planetForSector(...) -> planetForSite(...)
technologyMineGates -> technologySiteGates
```

Add:

```dart
enum MiningNodeId { n1, n2, n3, n4 }
enum DockBayId { b1, b2, b3, b4 }
enum RigTier { t1, t2, t3, t4, t5 }

class MiningNodeDefinition {
  const MiningNodeDefinition({
    required this.id,
    required this.requiredSurveyingLevel,
  });

  final MiningNodeId id;
  final int requiredSurveyingLevel;
}
```

`MiningSiteDefinition` must own its existing economy plus final asset paths:

```dart
final MiningSiteId id;
final String name;
final ResourceType resource;
final int unlockCost;
final MiningSiteId? requiredSite;
final int requiredSurveyingLevel;
final double baseRatePerSecond;
final double baseCapacity;
final int saleValuePerUnit;
final List<MiningNodeDefinition> nodes;
final String cavernAsset;
final String nodeAsset;
final String cardAsset;
```

`MiningPlanetDefinition` adds `rigSpawnCost` and `planetAsset`. Remove build/upgrade costs and Flame-only world fields after their consumers are removed in Task 5; do not author replacement values.

Implement:

```dart
double rigRateMultiplier(RigTier tier) => rateMultipliers[tier.index];

double rigCapacityMultiplier(RigTier tier) =>
    capacityMultipliers[tier.index];

double effectiveSiteRate(
  MiningSiteId id,
  Iterable<RigTier> rigs,
  int extraction,
) =>
    site(id).baseRatePerSecond *
    rigs.fold<double>(0, (sum, tier) => sum + rigRateMultiplier(tier)) *
    extractionRateMultipliers[extraction];

double effectiveSiteCapacity(
  MiningSiteId id,
  Iterable<RigTier> rigs,
  int logistics,
) =>
    site(id).baseCapacity *
    rigs.fold<double>(0, (sum, tier) => sum + rigCapacityMultiplier(tier)) *
    logisticsCapacityMultipliers[logistics];
```

- [ ] **Step 5: Replace old mine state tests with flat docks/sites tests**

```dart
test('fresh state seeds only Homeworld and two T1 rigs', () {
  final state = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26, 12));

  expect(state.cash, 100);
  expect(state.unlockedPlanetIds, {MiningPlanetId.homeworld});
  expect(state.activePlanetId, MiningPlanetId.homeworld);
  expect(state.docks[MiningPlanetId.homeworld], {
    DockBayId.b1: RigTier.t1,
    DockBayId.b2: RigTier.t1,
    DockBayId.b3: null,
    DockBayId.b4: null,
  });
  expect(state.sites[MiningSiteId.landingBasin]!.unlocked, isTrue);
  expect(state.sites[MiningSiteId.landingBasin]!.commissioned, isFalse);
});
```

Also prove all three dock maps have exact bay keys, all nine sites have exact node keys, locked planets are pristine, and constructor/copy paths defensively copy nested maps.

- [ ] **Step 6: Remodel `mining_state.dart`**

Replace `MineState` / `SectorProgress` with:

```dart
class SiteProgress {
  const SiteProgress({
    required this.unlocked,
    required this.commissioned,
    required this.storedAmount,
    required this.rigByNode,
  });

  final bool unlocked;
  final bool commissioned;
  final double storedAmount;
  final Map<MiningNodeId, RigTier?> rigByNode;
}
```

`MiningSave` stores:

```dart
final int cash;
final DateTime lastAccruedAtUtc;
final TechnologyLevels technology;
final Set<MiningPlanetId> unlockedPlanetIds;
final MiningPlanetId activePlanetId;
final Map<MiningPlanetId, Map<DockBayId, RigTier?>> docks;
final Map<MiningSiteId, SiteProgress> sites;
```

Keep `TechnologyLevels` unchanged.

- [ ] **Step 7: Run focused tests GREEN**

```sh
flutter test test/mining/mining_content_test.dart test/mining/mining_state_test.dart
```

- [ ] **Step 8: Commit**

```sh
git add lib/mining/mining_content.dart lib/mining/mining_state.dart \
  test/mining/mining_content_test.dart test/mining/mining_state_test.dart
git commit -m "feat(mining): remodel mining state for merge rigs"
```

The old presentation may be red after this commit; do not create a duplicate domain to hide that fact.

---

### Task 2: Retarget the Existing Strict Save Repository

**Files:**
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `test/mining/mining_save_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 state/content.
- Produces: strict new-key flat save decode/encode while preserving current recovery semantics.

- [ ] **Step 1: Define a local progressed fixture before using it**

Inside `mining_save_repository_test.dart`, add `_progressedState(DateTime now)` before the tests that call it. Build from `MiningSave.initial()` and include Homeworld+Lunar unlocked, active Lunar, non-empty docks, commissioned sites, deployed rigs, cargo, and technology.

- [ ] **Step 2: Write failing exact-key and old-key tests**

```dart
test('presence ignores retired mining key', () async {
  SharedPreferences.setMockInitialValues({'horologium.mining.save': '{}'});
  final repository = MiningSaveRepository();
  expect(MiningSaveRepository.saveKey, 'horologium.mergeMining.save');
  expect(await repository.hasSave(), isFalse);
});

test('round-trips enum-keyed docks and flat sites', () async {
  SharedPreferences.setMockInitialValues({});
  final now = DateTime.utc(2026, 8, 27, 12);
  final repository = MiningSaveRepository();
  final expected = _progressedState(now);

  await repository.save(expected);
  final loaded = await repository.load(nowUtc: now);

  expect(loaded.state, expected);
  expect(loaded.recoveredFromInvalidSave, isFalse);
});
```

Root keys are exactly `cash`, `lastAccruedAtUtc`, `technology`, `unlockedPlanetIds`, `activePlanetId`, `docks`, `sites`.

Both `docks.<planet>` and `sites.<site>.rigByNode` must use `hasExactKeys` for their four enum names.

Cover wrong/missing/extra keys, enum names, UTC, cash, technology, active/unlocked invariants, locked-planet/site contamination, prerequisite order, commissioned->unlocked, Surveying-gated deployment, negative cargo, and malformed raw preference type.

- [ ] **Step 3: Write capacity-clamp tests against deployed rigs**

Create a valid Landing Basin state with one T1 and cargo above 90. Load must clamp to 90 without recovery. Create another valid state with four T1 rigs and cargo below 360; load must preserve it.

- [ ] **Step 4: Run repository tests RED**

Run: `flutter test test/mining/mining_save_repository_test.dart`

- [ ] **Step 5: Modify the existing repository**

Keep the concrete `MiningSaveRepository`, `MiningLoadResult`, generic `prefs.get`, `hasExactKeys`, `wasMissing`, recovery behavior, and write rejection behavior.

Set:

```dart
static const saveKey = 'horologium.mergeMining.save';
```

Replace sector/mine decoding with `_decodeDocks` and `_decodeSites`. Decode each planet dock as an exact-key object with `b1..b4`, not a positional list.

For cargo normalization call:

```dart
final deployedRigs = rigByNode.values.whereType<RigTier>();
final capacity = content.effectiveSiteCapacity(siteId, deployedRigs, logistics);
final normalizedStored = math.min(storedAmount.toDouble(), capacity);
```

- [ ] **Step 6: Run repository tests GREEN**

Run: `flutter test test/mining/mining_save_repository_test.dart`

- [ ] **Step 7: Commit**

```sh
git add lib/mining/mining_save_repository.dart test/mining/mining_save_repository_test.dart
git commit -m "feat(mining): persist merge-rig saves"
```

---

### Task 3: Retarget Deterministic Accrual to Rig Rate and Capacity Shares

**Files:**
- Modify: `lib/mining/mining_simulation.dart`
- Modify: `test/mining/mining_simulation_test.dart`

**Interfaces:**
- Preserves: `AccrualResult`, `OfflineProductionSummary`, elapsed-window, rollback, cap, per-resource/per-planet summary.
- Changes: deployed rigs drive rate+capacity; `fullSectors` becomes `fullSites`.

- [ ] **Step 1: Write deployed-rig and fill-time tests**

```dart
test('one T1 keeps Landing Basin roughly 180 seconds to full', () {
  final state = stateWithLandingRigs(
    now: DateTime.utc(2026, 8, 26, 12),
    rigs: const {MiningNodeId.n1: RigTier.t1},
  );
  final result = MiningSimulation(content).accrue(
    state,
    state.lastAccruedAtUtc.add(const Duration(seconds: 180)),
  );
  expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 90);
});

test('four max rigs preserve the old max-tier fill curve', () {
  final state = stateWithLandingRigs(
    now: DateTime.utc(2026, 8, 26, 12),
    rigs: const {
      MiningNodeId.n1: RigTier.t5,
      MiningNodeId.n2: RigTier.t5,
      MiningNodeId.n3: RigTier.t5,
      MiningNodeId.n4: RigTier.t5,
    },
    extraction: 5,
    logistics: 5,
  );
  final result = MiningSimulation(content).accrue(
    state,
    state.lastAccruedAtUtc.add(const Duration(seconds: 160)),
  );
  expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 2880);
});
```

Also test docked rigs, mixed tiers, inactive unlocked planets, locked/empty sites, zero/negative elapsed, full-site reporting, offline cap, and deterministic equal inputs.

- [ ] **Step 2: Run simulation tests RED**

Run: `flutter test test/mining/mining_simulation_test.dart`

- [ ] **Step 3: Modify the existing simulation loop**

For each unlocked planet/site:

```dart
final progress = sites[definition.id]!;
final deployedRigs = progress.rigByNode.values.whereType<RigTier>().toList();
if (!progress.unlocked || deployedRigs.isEmpty) continue;

final rate = content.effectiveSiteRate(
  definition.id,
  deployedRigs,
  state.technology.extraction,
);
final capacity = content.effectiveSiteCapacity(
  definition.id,
  deployedRigs,
  state.technology.logistics,
);
```

Keep current timestamp, remaining-capacity, production maps, and offline-cap logic. Rename summary member `fullSectors` -> `fullSites`.

- [ ] **Step 4: Run simulation tests GREEN**

Run: `flutter test test/mining/mining_simulation_test.dart`

- [ ] **Step 5: Commit**

```sh
git add lib/mining/mining_simulation.dart test/mining/mining_simulation_test.dart
git commit -m "feat(mining): accrue rig production and storage"
```

---

### Task 4: Retarget the Existing Controller and Progression Projections

**Files:**
- Modify: `lib/mining/mining_controller.dart`
- Modify: `lib/mining/mining_progression_views.dart`
- Modify: `test/mining/mining_controller_test.dart`
- Modify: `test/mining/mining_progression_views_test.dart`

**Interfaces:**
- Preserves: `_enqueueMutation`, `initialize`, `refresh`, pending offline summary, sell, technology, unlock/travel, checkpoint/resume, progressive map disclosure.
- Replaces: reveal/build/upgrade with unlock/spawn/merge/deploy/recall.

- [ ] **Step 1: Reuse existing test seams**

Keep the existing `TestClock`, `DelayedMiningSaveRepository`, `ThrowingFirstSaveRepository`, `AlwaysFailingSaveRepository`, and `CountingMiningSaveRepository` subclasses. Do not create a repository interface or `implements` fake.

Update `seededSave` to accept enum-keyed docks and flat sites.

- [ ] **Step 2: Preserve initialization and refresh with regression tests**

Keep the existing missing/recovered initial-save tests.

Add:

```dart
test('refresh accrues in memory without persisting', () async {
  final repository = CountingMiningSaveRepository();
  final live = await controllerOver(
    repository,
    seed: deployedLandingBasinState(clock.now),
  );
  final savesBefore = repository.saveCount;
  clock.now = clock.now.add(const Duration(seconds: 10));

  live.refresh();

  expect(live.state.sites[MiningSiteId.landingBasin]!.storedAmount, 5.0);
  expect(repository.saveCount, savesBefore);
});
```

- [ ] **Step 3: Write spawn/merge/deploy/recall tests with closed bay IDs**

Cover spawn first empty bay, planet spawn cost, full dock, insufficient cash, same-tier merge into target, same bay rejection, mismatched/empty/T5 rejection, site unlock prerequisites, node Surveying, occupied nodes, first commission, full-dock recall, duplicate queued actions, and save failure.

Use signatures:

```dart
Future<MiningActionResult> mergeDockRigs(
  DockBayId sourceBay,
  DockBayId targetBay,
);

Future<MiningActionResult> deployRig(
  DockBayId sourceBay,
  MiningSiteId siteId,
  MiningNodeId nodeId,
);
```

- [ ] **Step 4: Write recall-capacity safety tests**

```dart
test('recall rejects cargo above post-recall capacity', () async {
  final controller = await controllerOver(
    MiningSaveRepository(),
    seed: landingWithTwoT1RigsAndCargo(clock.now, storedAmount: 150),
  );

  final result = await controller.recallRig(
    MiningSiteId.landingBasin,
    MiningNodeId.n2,
  );

  expect(result.isSuccess, isFalse);
  expect(result.message, 'Sell cargo before recalling this rig.');
  expect(
    controller.state.sites[MiningSiteId.landingBasin]!.rigByNode[MiningNodeId.n2],
    RigTier.t1,
  );
});
```

After Sell All, the same recall must succeed.

- [ ] **Step 5: Retarget progression/sale/mastery tests**

Technology gates use commissioned sites. Lunar/Mars unlock seed `{b1:T1,b2:T1,b3:null,b4:null}` and first site. Travel accrues before active-planet change. Selling remains active-planet-only and floors once. Final first commission on Mars grants exactly 25,000 once; recall/redeploy cannot repay it.

- [ ] **Step 6: Run controller tests RED**

Run: `flutter test test/mining/mining_controller_test.dart`

- [ ] **Step 7: Modify `MiningController` in place**

Keep `_enqueueMutation`, `initialize`, `refresh`, `checkpoint`, `resume`, and save-before-publish ordering.

Required actions:

```dart
Future<MiningActionResult> unlockSite(MiningSiteId siteId);
Future<MiningActionResult> spawnRig();
Future<MiningActionResult> mergeDockRigs(DockBayId sourceBay, DockBayId targetBay);
Future<MiningActionResult> deployRig(
  DockBayId sourceBay,
  MiningSiteId siteId,
  MiningNodeId nodeId,
);
Future<MiningActionResult> recallRig(MiningSiteId siteId, MiningNodeId nodeId);
```

For recall, derive post-recall deployed tiers, compute `effectiveSiteCapacity`, and reject before state copy/save when stored cargo exceeds it.

Move mastery reward transition from `buildMine` to first commission in `deployRig`.

- [ ] **Step 8: Retarget `mining_progression_views.dart` just enough for the new domain**

Keep `TechnologySheetView` and `StellarMapView` in this file. Preserve `_isVisible` behavior:

```text
fresh -> Homeworld + Lunar
Lunar unlocked -> Homeworld + Lunar + Mars
```

Replace mine gates/progress with commissioned-site gates/progress. Rich Site Deck/Mine Site projections arrive in Task 6.

- [ ] **Step 9: Run focused tests GREEN**

```sh
flutter test test/mining/mining_controller_test.dart \
  test/mining/mining_progression_views_test.dart
```

- [ ] **Step 10: Commit**

```sh
git add lib/mining/mining_controller.dart lib/mining/mining_progression_views.dart \
  test/mining/mining_controller_test.dart test/mining/mining_progression_views_test.dart
git commit -m "feat(mining): serialize merge-rig progression"
```

---

### Task 5: Isolate MiningShell Ownership and Retire Flame Early

**Files:**
- Rename/modify: `lib/mining/presentation/mining_screen.dart` -> `lib/mining/presentation/mining_shell.dart`
- Rename/modify: `lib/mining/presentation/mining_status_bar.dart` -> `lib/mining/presentation/mining_hud.dart`
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/main.dart`, `lib/main_menu.dart`
- Rename/modify: `test/mining/presentation/mining_screen_test.dart` -> `test/mining/presentation/mining_shell_test.dart`
- Modify: `test/main_menu_test.dart`, `test/widget_test.dart`, offline/settings/technology tests as needed
- Delete: `lib/mining/mining_sheet_view.dart`, `test/mining/mining_sheet_view_test.dart`
- Delete: old `mining_action_sheet.dart`, `stellar_map_sheet.dart`, their tests
- Delete: `lib/mining/world/**`, `test/mining/world/**`
- Delete after closure search: `lib/game/terrain/**`, `test/game/terrain/**`, unused terrain assets
- Modify: `pubspec.yaml`, `pubspec.lock`

**Interfaces:**
- Produces: one Flame-free `MiningShell` owner with current lifecycle/audio/timer semantics and a thin temporary Scaffold body.
- Restores: full repository analysis/test gate from this task onward.

- [ ] **Step 1: Rename owner/test handles without changing lifecycle semantics**

Rename:

```dart
MiningScreen -> MiningShell
MiningScreenHandles -> MiningShellHandles
```

Keep constructor injection for content/repository/clock/audio. Remove all `MiningGame` state/imports.

- [ ] **Step 2: Preserve the timer exactly**

```dart
void _startRefreshTimer() {
  _refreshTimer?.cancel();
  _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!_controller.isBusy) {
      _controller.refresh();
      _refreshPresentation();
    }
  });
}
```

Shell tests must prove cargo advances and `CountingMiningSaveRepository.saveCount` does not change on timer ticks.

- [ ] **Step 3: Preserve initialization/lifecycle/audio tests**

Retarget existing owner tests to prove:

- missing new-key save attempts initial persistence;
- recovered new-key save attempts initial persistence;
- one controller/audio identity survives rebuild/rotation;
- first gesture BGM behavior remains;
- pause stops timer and checkpoints;
- resume accrues and shows Offline Return;
- reduced motion and settings preferences remain.

- [ ] **Step 4: Evolve status bar into the temporary/final HUD owner**

Rename the file/class and fields:

```dart
MiningStatusBar -> MiningHud
revealedSectors -> commissionedSites
totalSectors -> totalSites
```

Keep the current cyan/panel token values. Task 6 lifts them into `MiningTheme` without creating another status widget.

- [ ] **Step 5: Render a thin Flame-free shell body**

Until Task 7 replaces the body with Site Deck, render a compilable `Scaffold` using current controller state and `MiningHud`:

```dart
return Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        MiningHud(
          planetName: _activePlanet.name,
          cash: _displayState.cash,
          commissionedSites: _commissionedSiteCount(),
          totalSites: _activePlanet.sites.length,
          cargoValue: _cargoValue(),
        ),
        const Expanded(
          child: Center(
            key: Key('mining-shell-placeholder'),
            child: Text('Mining operation ready'),
          ),
        ),
      ],
    ),
  ),
);
```

This placeholder exists only on the implementation branch between commits; it is replaced by Site Deck in Task 7.

- [ ] **Step 6: Cut Main Menu and typography now**

Route Start/Continue to `const MiningShell()` and import the same in-place `MiningSaveRepository`. Remove `fontFamily: 'Orbitron'` from `lib/main.dart`.

- [ ] **Step 7: Delete old action/world/terrain closure**

Before deleting terrain, run:

```sh
rg "ParallaxTerrain|package:horologium/game/terrain|package:flame" lib test
```

Expected production terrain consumer: old `lib/mining/world/mining_game.dart` only.

Delete old action sheet, old Stellar Map sheet, `mining_sheet_view.dart`, mining world/tests, then the zero-consumer terrain closure/tests/assets. Remove `flame` only when:

```sh
rg "package:flame" lib test
```

returns no matches.

- [ ] **Step 8: Retarget Offline Return to `fullSites`**

Keep per-planet/resource summary and current warning/cap behavior. Rename only sector terminology required by the new summary.

- [ ] **Step 9: Run full repository gates GREEN**

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

These become mandatory after every later task.

- [ ] **Step 10: Commit the isolated ownership/cutover**

```sh
git add lib/main.dart lib/main_menu.dart lib/mining lib/game pubspec.yaml pubspec.lock \
  test/main_menu_test.dart test/widget_test.dart test/mining test/game
git status --short
git commit -m "refactor(mining): cut over to a Flame-free mining shell"
```

---

### Task 6: Add Pure Views and Supplied Homeworld/Common Visuals

**Files:**
- Create: `lib/mining/fleet_dock_view.dart`
- Create: `lib/mining/site_deck_view.dart`
- Create: `lib/mining/mine_site_view.dart`
- Extend: `lib/mining/mining_progression_views.dart`
- Create/modify matching tests under `test/mining/`
- Create: `assets/images/mining/{caverns,nodes,rigs,planets,sites,icons,effects,offline}/`
- Create: `lib/mining/presentation/mining_theme.dart`
- Create: `lib/mining/presentation/mining_visuals.dart`
- Create: `test/mining/presentation/mining_visuals_test.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`

**Interfaces:**
- Produces: presentation-ready view factories, shared anchors/common asset helpers, supplied asset bundle.
- Does not require the missing Lunar/Mars cavern/node binaries.

- [ ] **Step 1: Write Fleet Dock view tests using closed bay IDs**

```dart
final view = FleetDockView.from(
  state: MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26)),
  content: MiningContentRegistry.stellarMining(),
  selectedBayId: DockBayId.b1,
  isBusy: false,
);

expect(view.bays[DockBayId.b1]!.isSelected, isTrue);
expect(view.bays[DockBayId.b2]!.canMergeWithSelection, isTrue);
expect(view.spawnCost, 25);
```

Cover full/poor/busy spawn reasons and contextual hints.

- [ ] **Step 2: Write Site Deck and Mine Site projection tests**

`MiningSiteCardState` is exactly `locked`, `available`, `idle`, `operational`.

Site Deck tests cover active planet commissioned count, cargo, capacity, projected value, rate, and each card state.

Mine Site tests cover four node availability states, rig rate, selected-bay deployability, recall capacity-disabled copy, site cargo/capacity, and active-planet projected sale.

- [ ] **Step 3: Extend current progression projections**

Add richer planet totals/requirements/site indicators while preserving `_isVisible`. Technology copy reflects commissioned gates and Surveying node availability.

- [ ] **Step 4: Extract only supplied prototype assets**

Map explicitly:

```text
art-cavern-gold.png   -> caverns/gold.png
art-cavern-coal.png   -> caverns/coal.png
art-cavern-stone.png  -> caverns/stone.png
art-node-gold.png     -> nodes/gold.png
art-node-coal.png     -> nodes/coal.png
art-node-stone.png    -> nodes/stone.png
art-site-basin.png    -> sites/landing_basin.png
art-site-ridge.png    -> sites/carbon_ridge.png
art-site-crater.png   -> sites/granite_crater.png
art-planet-home.png   -> planets/homeworld.png
art-planet-lunar.png  -> planets/lunar_frontier.png
art-planet-mars.png   -> planets/mars_frontier.png
art-worker-t1.png     -> rigs/t1.png
art-worker-t2.png     -> rigs/t2.png
art-worker-t3.png     -> rigs/t3.png
art-worker-t4.png     -> rigs/t4.png
art-worker-t5.png     -> rigs/t5.png
art-merge-burst.png   -> effects/merge_burst.png
art-offline-hero.png  -> offline/hero.png
```

Copy supplied cash/cargo/merge/extraction/logistics/surveying icons into `icons/`. Do not copy HTML/scripts/duplicate upload folders.

- [ ] **Step 5: Create shared presentation constants, not a second site table**

`mining_visuals.dart` defines:

```dart
abstract final class MiningVisuals {
  static const portraitNodeAnchors = <Alignment>[
    Alignment(-0.55, -0.30),
    Alignment(0.50, -0.24),
    Alignment(-0.42, 0.36),
    Alignment(0.48, 0.40),
  ];

  static const landscapeNodeAnchors = <Alignment>[
    Alignment(-0.56, -0.38),
    Alignment(0.34, -0.34),
    Alignment(-0.40, 0.35),
    Alignment(0.40, 0.36),
  ];

  static String rigAsset(RigTier tier) =>
      'assets/images/mining/rigs/${tier.name}.png';

  static const cashIcon = 'assets/images/mining/icons/cash.png';
  static const cargoIcon = 'assets/images/mining/icons/cargo.png';
  static const mergeIcon = 'assets/images/mining/icons/merge.png';
  static const mergeBurst = 'assets/images/mining/effects/merge_burst.png';
  static const offlineHero = 'assets/images/mining/offline/hero.png';
}
```

If one real site later needs anchor overrides, add one explicit conditional/map entry then; do not pre-author nine rows.

`MiningTheme` lifts the current HUD/offline cyan/panel/warning tokens.

- [ ] **Step 6: Split visual tests so missing external art does not block**

Structural test: every `MiningSiteDefinition` has non-empty cavern/node/card paths and every planet has a non-empty planet path.

Bundle-resolution test in this task loads:

- all Homeworld cavern/node/card paths;
- all five rig paths;
- all three planet paths;
- all supplied shared icons/effect/offline hero.

Do **not** `rootBundle.load` the six Lunar/Mars cavern/node pairs yet.

- [ ] **Step 7: Register asset directories and run gates**

```sh
flutter pub get
flutter test test/mining/fleet_dock_view_test.dart \
  test/mining/site_deck_view_test.dart \
  test/mining/mine_site_view_test.dart \
  test/mining/mining_progression_views_test.dart \
  test/mining/presentation/mining_visuals_test.dart
flutter analyze --fatal-infos
flutter test
```

- [ ] **Step 8: Commit**

```sh
git add lib/mining/fleet_dock_view.dart lib/mining/site_deck_view.dart \
  lib/mining/mine_site_view.dart lib/mining/mining_progression_views.dart \
  lib/mining/presentation/mining_theme.dart lib/mining/presentation/mining_visuals.dart \
  assets/images/mining pubspec.yaml pubspec.lock test/mining
git commit -m "feat(mining): add mobile projections and Homeworld visuals"
```

---

### Task 7: Build and Wire Site Deck

**Files:**
- Create: `lib/mining/presentation/mining_navigation.dart`
- Create: `lib/mining/presentation/fleet_dock.dart`
- Create: `lib/mining/presentation/site_deck_screen.dart`
- Create: `test/mining/presentation/site_deck_screen_test.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Consumes: `SiteDeckView`, `FleetDockView`, `MiningHud`, `MiningTheme`, site asset paths.
- Replaces: the Task 5 placeholder body with the first real production surface.

- [ ] **Step 1: Write stateless Site Deck tests**

Cover four card states, enum-keyed four-bay dock, spawn, merge selection callback, unlock/enter action, bottom navigation, 360x640 / 430x932, text scale 1.3, 48x48 targets, semantics, and non-overlap geometry.

- [ ] **Step 2: Implement shared navigation and Fleet Dock**

```dart
enum MiningNavigationDestination {
  siteDeck,
  technology,
  stellarMap,
  settings,
}

enum FleetDockAxis { horizontal, vertical }
```

`FleetDock` iterates `DockBayId.values`, keys controls by bay name, and receives presentation-ready view state/callbacks only.

- [ ] **Step 3: Implement Site Deck**

Use `SafeArea`, scrollable cards, `MiningHud`, horizontal Fleet Dock, and bottom navigation. Card image comes from `MiningSiteDefinition.cardAsset`.

- [ ] **Step 4: Wire shell Site Deck actions**

Shell derives `SiteDeckView` from controller state. A bay tap selects or merges; spawn/unlock actions call controller; site entry is local navigation only.

- [ ] **Step 5: Run focused + full suite GREEN**

```sh
flutter test test/mining/presentation/site_deck_screen_test.dart \
  test/mining/presentation/mining_shell_test.dart
flutter analyze --fatal-infos
flutter test
```

- [ ] **Step 6: Commit**

```sh
git add lib/mining/presentation/mining_navigation.dart \
  lib/mining/presentation/fleet_dock.dart \
  lib/mining/presentation/site_deck_screen.dart \
  lib/mining/presentation/mining_shell.dart \
  test/mining/presentation/site_deck_screen_test.dart \
  test/mining/presentation/mining_shell_test.dart
git commit -m "feat(mining): build the mobile site deck"
```

---

### Task 8: Build One Responsive Mine Site

**Files:**
- Create: `lib/mining/presentation/mine_site_screen.dart`
- Create: `test/mining/presentation/mine_site_screen_test.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Consumes: `MineSiteView`, shared anchors, rig/common assets, vertical/horizontal Fleet Dock.
- Produces: one public portrait/landscape Mine Site and shell deploy/recall/sell orchestration.

- [ ] **Step 1: Write interaction tests**

Verify bay/node/sale/back/settings callbacks, selected bay semantics, node semantic labels, merge/deploy/recall feedback, and recall-capacity disabled copy.

- [ ] **Step 2: Write geometry tests**

Portrait: 360x640, 402x874, 430x932; nodes stay in cavern, dock/nav do not overlap.

Landscape: 874x402; cavern stops before fixed right rail, cargo control and vertical dock fit rail, back/settings stay left.

Test text scale 1.3 and reduced-motion settled feedback.

- [ ] **Step 3: Implement one public `MineSiteScreen`**

`LayoutBuilder` selects private portrait/landscape widget trees using the same `MineSiteView` and callbacks. Use `MiningVisuals.portraitNodeAnchors` / `landscapeNodeAnchors`; use `definition.cavernAsset` and `definition.nodeAsset`.

- [ ] **Step 4: Wire shell node actions**

- empty available node + selected dock rig -> `deployRig`;
- occupied node -> `recallRig`;
- cargo control -> `sellAllCargo`;
- back -> local Site Deck;
- successful actions refresh view, preserve valid selection, emit haptic/transient feedback.

- [ ] **Step 5: Run focused + full suite GREEN**

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/mining_shell_test.dart
flutter analyze --fatal-infos
flutter test
```

- [ ] **Step 6: Commit**

```sh
git add lib/mining/presentation/mine_site_screen.dart \
  lib/mining/presentation/mining_shell.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/mining_shell_test.dart
git commit -m "feat(mining): build responsive mine sites"
```

---

### Task 9: Build Full-Screen Stellar Map and Retarget Secondary Surfaces

**Files:**
- Create: `lib/mining/presentation/stellar_map_screen.dart`
- Create: `test/mining/presentation/stellar_map_screen_test.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `lib/mining/presentation/technology_sheet.dart`
- Modify: `lib/mining/presentation/mining_settings_sheet.dart`
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: corresponding tests

**Interfaces:**
- Consumes: existing `TechnologySheetView` / `StellarMapView`, planet assets, shared nav/theme.
- Produces: third primary surface and polished secondary sheets.

- [ ] **Step 1: Write Stellar Map tests**

Fresh state shows Homeworld+Lunar. Lunar unlocked also shows Mars. Cards render active/unlocked/locked, commissioned progress, rate/cargo/capacity/value, three site indicators, requirements, busy state, and direct travel/unlock action. Assert exact `Mars Frontier` copy, 48x48 targets, 360x640 / 430x932 / text scale 1.3.

- [ ] **Step 2: Implement `StellarMapScreen`**

Use current `StellarMapView`; widgets do not recalculate requirements. Use `MiningPlanetDefinition.planetAsset` for card art and shared bottom navigation.

- [ ] **Step 3: Retarget Technology**

Keep Extraction/Logistics/Surveying and current purchase callbacks. Render commissioned site gate, current/next effect, cost, and disabled reason from projection.

- [ ] **Step 4: Retarget Settings and Offline Return**

Settings keeps the same `AudioManager` and preference keys. Offline Return uses `fullSites`, site terminology, existing per-planet/resource summary, cap warning, next action, and supplied hero asset.

- [ ] **Step 5: Wire shell Stellar Map/secondary actions**

Navigation changes local primary surface or opens sheets. Unlock/travel/purchase remain serialized controller mutations and refresh after settlement.

- [ ] **Step 6: Run focused + full suite GREEN**

```sh
flutter test test/mining/presentation/stellar_map_screen_test.dart \
  test/mining/presentation/technology_sheet_test.dart \
  test/mining/presentation/mining_settings_sheet_test.dart \
  test/mining/presentation/offline_return_sheet_test.dart \
  test/mining/presentation/mining_shell_test.dart
flutter analyze --fatal-infos
flutter test
```

- [ ] **Step 7: Commit**

```sh
git add lib/mining/presentation test/mining/presentation
git commit -m "feat(mining): finish mobile mining navigation"
```

---

### Task 10: Satisfy the Lunar/Mars Art Gate and Resolve All Nine Sites

**Files:**
- Add externally authored PNGs under `assets/images/mining/caverns/` and `nodes/`
- Modify: `test/mining/presentation/mining_visuals_test.dart`

**Interfaces:**
- Consumes: external art workflow output.
- Produces: no-fallback all-nine site bundle-resolution proof.

- [ ] **Step 1: Hard-stop until all twelve real files exist**

Required:

```text
caverns/water_ice.png      800x1200
nodes/water_ice.png        512x512 RGBA
caverns/titanium_ore.png   800x1200
nodes/titanium_ore.png     512x512 RGBA
caverns/helium_3.png       800x1200
nodes/helium_3.png         512x512 RGBA
caverns/iron_ore.png       800x1200
nodes/iron_ore.png         512x512 RGBA
caverns/silica.png         800x1200
nodes/silica.png           512x512 RGBA
caverns/cobalt_ore.png     800x1200
nodes/cobalt_ore.png       512x512 RGBA
```

Do not generate placeholders or reuse old mine sprites.

- [ ] **Step 2: Extend the bundle-resolution test to all nine sites**

```dart
testWidgets('every site cavern node and card resolves', (tester) async {
  final content = MiningContentRegistry.stellarMining();

  for (final site in content.planets.values.expand((planet) => planet.sites)) {
    await rootBundle.load(site.cavernAsset);
    await rootBundle.load(site.nodeAsset);
    await rootBundle.load(site.cardAsset);
  }
});
```

Lunar/Mars `cardAsset` may equal the cavern path; Site Deck crops with `BoxFit.cover`.

- [ ] **Step 3: Run all visual/layout tests and full suite GREEN**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart \
  test/mining/presentation/site_deck_screen_test.dart \
  test/mining/presentation/mine_site_screen_test.dart
flutter analyze --fatal-infos
flutter test
```

- [ ] **Step 4: Commit explicit art files**

```sh
git add assets/images/mining/caverns/water_ice.png \
  assets/images/mining/nodes/water_ice.png \
  assets/images/mining/caverns/titanium_ore.png \
  assets/images/mining/nodes/titanium_ore.png \
  assets/images/mining/caverns/helium_3.png \
  assets/images/mining/nodes/helium_3.png \
  assets/images/mining/caverns/iron_ore.png \
  assets/images/mining/nodes/iron_ore.png \
  assets/images/mining/caverns/silica.png \
  assets/images/mining/nodes/silica.png \
  assets/images/mining/caverns/cobalt_ore.png \
  assets/images/mining/nodes/cobalt_ore.png \
  test/mining/presentation/mining_visuals_test.dart
git commit -m "feat(mining): complete Lunar and Mars visuals"
```

---

### Task 11: Validate Fresh-to-Mars Economy, Playtest Cadence, and Finish Guidance

**Files:**
- Replace: `test/integration/mining_mvp_journey_test.dart` -> `test/integration/merge_mining_journey_test.dart`
- Create after observation: `docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md`
- Modify only when evidence requires: `lib/mining/mining_content.dart`, its tests
- Modify: `README.md`, `CLAUDE.md`, zero-consumer asset constants/docs as appropriate

**Interfaces:**
- Produces: public-action progression proof, observed balance decision, final active architecture documentation.

- [ ] **Step 1: Write a public-action-only fresh journey**

Use injected `TestClock` plus public controller actions after initialization. Do not mutate controller/repository state directly.

Required sequence:

```text
fresh two T1 rigs
-> merge/deploy Landing Basin
-> accrue/sell/spawn/merge as needed
-> unlock + commission Carbon Ridge
-> unlock + commission Granite Crater
-> raise Surveying to 3
-> unlock Lunar and verify starter dock/site
-> commission all Lunar sites
-> raise Surveying to 5
-> unlock Mars and verify starter dock/site
-> commission all Mars sites
-> verify 25,000 reward exactly once
-> reload new save and verify docks/sites/cargo/technology/active planet
```

Also leave Homeworld production deployed while active planet is Lunar, advance the clock, and prove Homeworld cargo grows.

- [ ] **Step 2: Run journey with authored values**

Run: `flutter test test/integration/merge_mining_journey_test.dart`

Expected: PASS or a concrete affordability/cadence failure. Do not bypass the economy with state edits.

- [ ] **Step 3: Perform representative device/simulator playtest**

Record concrete observed values:

- commit + device/simulator;
- 360x640, 402x874, 430x932, 874x402;
- text scale 1.3, reduced motion, muted audio;
- early/mid/late site fill times;
- sell cadence / cap frequency;
- spawn/merge/sell cycles Homeworld->Lunar and Lunar->Mars;
- fresh-to-Mars completion;
- Keep or numeric-change decision.

Do not commit a blank template.

- [ ] **Step 4: Tune only existing authored numeric values when evidence requires**

Allowed: spawn cost, site unlock cost, base rate, base capacity, sale value, technology costs/effects, rate/capacity multiplier tables.

Add or update exact content/simulation/journey assertions for every changed number. Do not add a new sink/mechanic/currency/depletion/processing layer.

- [ ] **Step 5: Update README and CLAUDE**

Document:

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> Flutter Site Deck / Mine Site / Stellar Map
```

Include new key, flat sites + enum-keyed docks, commissioned mastery, rate/capacity rig shares, recall cargo safety, foreground `refresh()`, missing/recovered initial persistence, final asset paths, and no Flame runtime.

- [ ] **Step 6: Run legacy/uniqueness greps**

```sh
rg "horologium\.mining\.save|MiningGame|MiningSectorId|MineState|SectorProgress|package:flame|ParallaxTerrain" \
  lib test README.md CLAUDE.md pubspec.yaml
rg "class Mining(ContentRegistry|Save|Simulation|SaveRepository|Controller)" lib/mining
```

Expected: no active legacy runtime references; exactly one definition of each core class.

- [ ] **Step 7: Run final repository gates**

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Where Xcode is available:

```sh
flutter build ios --simulator --debug
```

- [ ] **Step 8: Commit final validation/docs**

```sh
git add test/integration docs/playtests README.md CLAUDE.md \
  lib/mining/mining_content.dart test/mining/mining_content_test.dart \
  test/mining/mining_simulation_test.dart
git status --short
git commit -m "test(mining): validate the mobile merge economy"
```

---

## Plan Self-Review Checklist

- [ ] No duplicate core mining stack exists.
- [ ] Save uses flat `sites` + planet -> `DockBayId` maps.
- [ ] Public controller/view APIs use `DockBayId`, not raw bay integers.
- [ ] Current rate and capacity multiplier tables are reused.
- [ ] Capacity shares are summed without `/4` normalization.
- [ ] Recall cargo safety is specified and tested.
- [ ] `initialize()` missing/recovered persistence is preserved.
- [ ] Shell timer calls `controller.refresh()` before projection.
- [ ] Existing repository subclasses/TestClock are reused.
- [ ] Existing `mining_progression_views.dart` / `_isVisible` are preserved.
- [ ] `mining_status_bar.dart` is evolved/renamed rather than replaced by a parallel HUD.
- [ ] Per-site assets live on `MiningSiteDefinition`; shared anchors are constants.
- [ ] Supplied Homeworld/common asset tests can pass without Lunar/Mars cavern/node binaries.
- [ ] All-nine bundle resolution is isolated to the final art gate.
- [ ] Flame/terrain/old action UI are deleted before visual work and full-suite green resumes at Task 5.
- [ ] Shell ownership, Site Deck, Mine Site, Stellar Map/secondary surfaces are separate reviewable commits.
- [ ] Playtest records fill time and sell cadence, not just reachability.
- [ ] No plan code block contains undefined placeholder classes/interfaces.

## Final PR Verification Checklist

- [ ] HPA-285 / PR #19 remain the only implementation ticket/PR.
- [ ] One current mining catalog/state/simulation/repository/controller exists.
- [ ] New save key only; old key ignored.
- [ ] Spawn/merge/deploy/recall/recall-capacity rejection/sale/progression/mastery reward are deterministic and save-backed.
- [ ] Foreground refresh and initial persistence regressions are covered.
- [ ] All nine final cavern/node/card paths resolve with no fallback.
- [ ] Portrait/landscape/text-scale/reduced-motion/muted-audio gates pass.
- [ ] Fresh public-action journey reaches and reloads Mars mastery.
- [ ] Playtest records fill/sell cadence and balance decision.
- [ ] Old Flame/terrain/action runtime and dependency are gone.
- [ ] README/CLAUDE describe final architecture.
- [ ] Formatting, analysis, tests, coverage, Chrome, APK, web, and available iOS build pass.
