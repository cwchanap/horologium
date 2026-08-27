# HPA-285 Horologium Mobile Merge-Mining Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remodel the existing mining runtime in place into one production-ready mobile merge-mining loop spanning Site Deck, responsive Mine Site, full-screen Stellar Map, deterministic live/offline production, and all three authored planets.

**Architecture:** Modify the existing `lib/mining/mining_*.dart` domain files in place so there is never a second `MiningContentRegistry`, `MiningSave`, `MiningSimulation`, `MiningSaveRepository`, or `MiningController`. Keep globally unique site IDs in one flat save map, add per-planet docks, extend the current progression projections, then rename/evolve `MiningScreen` into the sole `MiningShell` and delete Flame only after import closure.

**Tech Stack:** Flutter/Dart, SharedPreferences, audioplayers, Flutter widget tests, deterministic pure-Dart tests, existing GitHub Actions/build targets.

**Spec:** `docs/superpowers/specs/2026-08-26-hpa-285-mobile-merge-mining-redesign-design.md`

## Global Constraints

- Deliver planning, implementation, review, cutover, cleanup, and verification on this one HPA-285 branch and PR.
- Modify the existing mining domain in place; do not create `lib/mining/domain/` or duplicate catalog/state/controller types.
- Use one `MiningShell`, controller, simulation, repository, audio manager, timer, and lifecycle observer.
- Use Flutter for all new surfaces; do not build a replacement Flame world.
- Use `horologium.mergeMining.save`; ignore `horologium.mining.save`; add no migration/version/compatibility path.
- Keep globally unique `MiningSiteId` values, a flat `sites` save map, and a separate `docks` map keyed by planet.
- Keep four planet-local dock bays, four nodes per site, and reuse the existing `MiningContentRegistry.rateMultipliers` values `1.00, 1.50, 2.25, 3.25, 4.50` for T1-T5 throughput.
- Seed two T1 rigs and the first site when a planet first becomes unlocked.
- Rig count/tier affect rate only. Site capacity is `baseCapacity * logisticsCapacityMultiplier`; Logistics is the only multiplicative capacity progression.
- Preserve deterministic elapsed-time production, `MiningController.refresh()`, initial missing/recovered-save persistence, active-planet selling, technology, planet requirements, and the 25,000 Mars reward.
- Do not add finite depletion, drag-and-drop, rig IDs, workers, crafting, processing, dynamic prices, another currency, retention systems, server/account/cloud features, state-management packages, routing packages, repository interfaces, or generic frameworks.
- Keep controls at least 48x48; support 360x640, 402x874, 430x932, 874x402, text scale 1.3, reduced motion, muted audio, and safe areas.
- Use system typography; remove undeclared Orbitron.
- The coding task must not invent the twelve missing Lunar/Mars cavern/node PNGs. They are an external input gate.
- Final production has no Lunar/Mars fallback, old save consumer, old action sheet, Flame mining runtime, or duplicate domain.
- Intermediate in-place domain commits may make the old Flame route fail to compile. Run focused tests for those tasks; the full Flutter suite is mandatory from the production cutover task onward.

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

Existing file names are retained wherever they still own the same job. `mining_screen.dart` is renamed to `mining_shell.dart` only when the new presentation is cut over.

---

### Task 1: Remodel the Existing Catalog and State In Place

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_state.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_state_test.dart`

**Interfaces:**
- Produces: `MiningSiteId`, `MiningNodeId`, `RigTier`, updated site/planet definitions, flat `MiningSave.sites`, and `MiningSave.docks`.
- Preserves: `MiningPlanetId`, `TechnologyTrack`, `TechnologyLevels`, technology/offline tables, planet requirements, resource identities.

- [ ] **Step 1: Rename the closed site identity in tests and freeze authored values**

Update catalog tests from `MiningSectorId` to `MiningSiteId` and assert all nine current resource/rate/capacity/sale/unlock values remain unchanged.

Add exact assertions:

```dart
test('reuses the current rate multiplier table as the rig ladder', () {
  expect(
    MiningContentRegistry.rateMultipliers,
    [1.0, 1.5, 2.25, 3.25, 4.5],
  );
});

test('authors four Surveying-gated nodes on every site', () {
  final content = MiningContentRegistry.stellarMining();
  for (final site in content.planets.values.expand((p) => p.sites)) {
    expect(site.nodes.map((node) => node.id), MiningNodeId.values);
  }
});
```

Freeze the node Surveying table from the spec and per-planet spawn costs 25 / 500 / 5000.

- [ ] **Step 2: Run the catalog test and confirm the old types fail**

Run: `flutter test test/mining/mining_content_test.dart`

Expected: FAIL because `MiningSiteId`, nodes, and spawn costs do not exist yet.

- [ ] **Step 3: Remodel `mining_content.dart` rather than copying it**

Rename:

```dart
MiningSectorId -> MiningSiteId
MiningSectorDefinition -> MiningSiteDefinition
requiredSector -> requiredSite
revealCost -> unlockCost
sector(...) -> site(...)
planetForSector(...) -> planetForSite(...)
isPlanetMastered(... minedSectorIds) -> isPlanetMastered(... commissionedSiteIds)
```

Add:

```dart
enum MiningNodeId { n1, n2, n3, n4 }
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

Each `MiningPlanetDefinition` gains only:

```dart
final int rigSpawnCost;
final List<MiningSiteDefinition> sites;
```

Keep the existing `rateMultipliers` constant and use ordinal tier indexing against it. Keep `extractionRateMultipliers`, `logisticsCapacityMultipliers`, `offlineCapsByLogistics`, technology costs/gates, unlock requirements, and mastery reward.

Remove `capacityMultipliers` because tier no longer scales storage. Remove build/upgrade costs and Flame-only world metadata when current consumers are updated within this task or a following cutover step.

Required helpers:

```dart
MiningPlanetDefinition planet(MiningPlanetId id);
MiningSiteDefinition site(MiningSiteId id);
MiningPlanetId planetForSite(MiningSiteId id);
double rigMultiplier(RigTier tier);
double effectiveSiteRate(
  MiningSiteId siteId,
  Iterable<RigTier> deployedRigs,
  int extractionLevel,
);
double effectiveSiteCapacity(MiningSiteId siteId, int logisticsLevel);
Duration offlineCapFor(int logisticsLevel);
bool isPlanetMastered(
  MiningPlanetId planetId,
  Iterable<MiningSiteId> commissionedSiteIds,
);
```

`effectiveSiteCapacity` must use only `baseCapacity * logisticsCapacityMultipliers[logisticsLevel]`.

- [ ] **Step 4: Replace old mine state tests with flat docks/sites tests**

Add tests equivalent to:

```dart
test('fresh state is flat and seeds only Homeworld', () {
  final now = DateTime.utc(2026, 8, 26, 12);
  final state = MiningSave.initial(nowUtc: now);

  expect(state.cash, 100);
  expect(state.unlockedPlanetIds, {MiningPlanetId.homeworld});
  expect(state.activePlanetId, MiningPlanetId.homeworld);
  expect(
    state.docks[MiningPlanetId.homeworld],
    [RigTier.t1, RigTier.t1, null, null],
  );
  expect(state.docks[MiningPlanetId.lunarFrontier], everyElement(isNull));
  expect(state.sites, hasLength(MiningSiteId.values.length));
  expect(state.sites[MiningSiteId.landingBasin]!.unlocked, isTrue);
  expect(state.sites[MiningSiteId.landingBasin]!.commissioned, isFalse);
});
```

Also assert every site has exactly n1-n4, all maps/lists are unmodifiable copies, equality/hash include docks/sites, and locked planet sites are pristine.

- [ ] **Step 5: Remodel `mining_state.dart` in place**

Delete `MineState` and replace `SectorProgress` with:

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

`MiningSave` becomes:

```dart
class MiningSave {
  final int cash;
  final DateTime lastAccruedAtUtc;
  final TechnologyLevels technology;
  final Set<MiningPlanetId> unlockedPlanetIds;
  final MiningPlanetId activePlanetId;
  final Map<MiningPlanetId, List<RigTier?>> docks;
  final Map<MiningSiteId, SiteProgress> sites;
}
```

Use defensive unmodifiable copies in constructors/copy paths. Keep `TechnologyLevels` unchanged.

- [ ] **Step 6: Run focused state/catalog tests**

```sh
flutter test test/mining/mining_content_test.dart test/mining/mining_state_test.dart
```

Expected: PASS. Do not run the full suite yet; old presentation/controller imports may still use the removed mine model.

- [ ] **Step 7: Commit**

```sh
git add lib/mining/mining_content.dart lib/mining/mining_state.dart \
  test/mining/mining_content_test.dart test/mining/mining_state_test.dart
git commit -m "feat(mining): remodel mining state for merge rigs"
```

---

### Task 2: Retarget the Existing Strict Save Repository

**Files:**
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `test/mining/mining_save_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 flat state/content.
- Produces: strict `horologium.mergeMining.save` load/save and current recovery semantics.

- [ ] **Step 1: Replace the old-key/payload tests before implementation**

Add:

```dart
test('presence ignores the retired save key', () async {
  SharedPreferences.setMockInitialValues({'horologium.mining.save': '{}'});
  final repository = MiningSaveRepository();
  expect(MiningSaveRepository.saveKey, 'horologium.mergeMining.save');
  expect(await repository.hasSave(), isFalse);
});
```

Define a local `_progressedState(DateTime now)` in this test file **before** the round-trip test. Build it from `MiningSave.initial()` with immutable `copyWith` operations; do not reference a fixture introduced by a later task.

The progressed payload must contain:

- Homeworld + Lunar unlocked;
- active Lunar;
- non-empty Homeworld/Lunar docks;
- commissioned Landing Basin and Frozen Basin;
- one deployed rig;
- non-zero cargo;
- non-zero technology levels.

- [ ] **Step 2: Add exact structural tests for the flat document**

The root key set is exactly:

```text
cash
lastAccruedAtUtc
technology
unlockedPlanetIds
activePlanetId
docks
sites
```

Test:

- docks contain exactly all three planet names;
- each dock is exactly four nullable valid tiers;
- sites contain exactly all nine site names;
- each site contains exactly `unlocked`, `commissioned`, `storedAmount`, `rigByNode`;
- `rigByNode` contains exactly n1-n4;
- locked planet docks/sites must be pristine;
- first site must be unlocked for each unlocked planet;
- later-site prerequisite order is valid;
- commissioned implies unlocked;
- locked site has zero cargo/no rigs;
- deployed node satisfies saved Surveying;
- active planet is unlocked/Homeworld is unlocked;
- malformed/raw-type/UTC/cash/technology/enum/negative-cargo failures recover cleanly.

Add one valid over-capacity test proving cargo clamps with no recovery and uses `effectiveSiteCapacity`, not rig tier/count.

- [ ] **Step 3: Run repository tests and confirm the old decoder fails**

Run: `flutter test test/mining/mining_save_repository_test.dart`

Expected: FAIL on key/document shape.

- [ ] **Step 4: Modify the existing repository in place**

Keep the current concrete class and helpers:

```dart
class MiningSaveRepository {
  static const saveKey = 'horologium.mergeMining.save';
  MiningSaveRepository({MiningContentRegistry? content});
  Future<bool> hasSave();
  Future<MiningLoadResult> load({required DateTime nowUtc});
  Future<void> save(MiningSave state);
}
```

Preserve:

- generic `prefs.get(saveKey)` before String validation;
- `hasExactKeys` strictness;
- `wasMissing` and `recoveredFromInvalidSave` semantics;
- clean initial-state recovery;
- write rejection error behavior.

Replace `_decodeSectors`/`_decodeMine` with `_decodeDocks` and `_decodeSites` without adding a schema version or compatibility branch.

- [ ] **Step 5: Run repository tests**

Run: `flutter test test/mining/mining_save_repository_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```sh
git add lib/mining/mining_save_repository.dart test/mining/mining_save_repository_test.dart
git commit -m "feat(mining): persist flat merge-mining saves"
```

---

### Task 3: Retarget Deterministic Accrual to Deployed Rigs

**Files:**
- Modify: `lib/mining/mining_simulation.dart`
- Modify: `test/mining/mining_simulation_test.dart`

**Interfaces:**
- Preserves: `AccrualResult`, `OfflineProductionSummary`, deterministic elapsed-time window behavior.
- Changes: `fullSectors -> fullSites`; production source is deployed rigs rather than `MineState`.

- [ ] **Step 1: Replace old mine-rate tests with deployed-rig tests**

Add:

```dart
test('deployed tiers sum throughput while docked rigs do nothing', () {
  final state = stateWithSiteRigs(
    siteId: MiningSiteId.landingBasin,
    rigs: {
      MiningNodeId.n1: RigTier.t1,
      MiningNodeId.n2: RigTier.t2,
    },
  );
  final result = MiningSimulation(content).accrue(
    state,
    state.lastAccruedAtUtc.add(const Duration(seconds: 10)),
  );

  expect(
    result.state.sites[MiningSiteId.landingBasin]!.storedAmount,
    closeTo((0.50 * 1.0 + 0.50 * 1.5) * 10, 0.0001),
  );
});
```

Add coverage for:

- four T5 rigs + Extraction 5 rate;
- capacity unaffected by rig tiers/count;
- Logistics capacity only;
- inactive unlocked planet accrual;
- locked/empty site no production;
- full-site reporting;
- zero/negative elapsed behavior;
- offline cap;
- deterministic equal-input result.

- [ ] **Step 2: Run and confirm the old simulation model fails**

Run: `flutter test test/mining/mining_simulation_test.dart`

Expected: FAIL because it still reads `SectorProgress.mine`.

- [ ] **Step 3: Modify the current simulation loop**

For each unlocked planet in content order, iterate `planet.sites`, resolve flat `state.sites[site.id]`, collect non-null `rigByNode.values`, and calculate:

```dart
final rate = content.effectiveSiteRate(
  definition.id,
  deployedRigs,
  state.technology.extraction,
);
final capacity = content.effectiveSiteCapacity(
  definition.id,
  state.technology.logistics,
);
```

Keep current elapsed-window, rollback, clamp, timestamp, production-by-resource, and production-by-planet behavior. Rename the summary set to `fullSites`.

- [ ] **Step 4: Run simulation tests**

Run: `flutter test test/mining/mining_simulation_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add lib/mining/mining_simulation.dart test/mining/mining_simulation_test.dart
git commit -m "feat(mining): accrue deployed rig production"
```

---

### Task 4: Remodel the Existing Controller Without Losing Refresh or Initial Persistence

**Files:**
- Modify: `lib/mining/mining_controller.dart`
- Modify: `test/mining/mining_controller_test.dart`

**Interfaces:**
- Preserves: one `_enqueueMutation`, `initialize`, `refresh`, `takePendingReturnSummary`, technology, planet unlock/travel, sell, checkpoint, resume.
- Replaces: reveal/build/upgrade with site unlock/spawn/merge/deploy/recall.

- [ ] **Step 1: Reuse the existing controller-test seams**

Keep and rename only as needed:

```dart
class TestClock {
  TestClock(this.now);
  DateTime now;
  DateTime call() => now;
}

class DelayedMiningSaveRepository extends MiningSaveRepository { ... }
class ThrowingFirstSaveRepository extends MiningSaveRepository { ... }
class AlwaysFailingSaveRepository extends MiningSaveRepository { ... }
class CountingMiningSaveRepository extends MiningSaveRepository { ... }
```

Do **not** add `MemoryMiningSaveRepository implements MiningSaveRepository` and do not create a repository interface. Seed SharedPreferences through the concrete repository just as the current `controllerOver` helper does.

Replace `seededSave` with a flat-state helper that can set cash, technology, docks, sites, unlocked planets, and active planet.

- [ ] **Step 2: Preserve initialization and live refresh with explicit regression tests**

Keep the existing missing/recovered-save tests and update only their expected new payload.

Add:

```dart
test('refresh accrues in memory without saving', () async {
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

Initialization must still best-effort save when `loaded.wasMissing || loaded.recoveredFromInvalidSave`, even if that convenience save fails.

- [ ] **Step 3: Write failing spawn/merge tests**

Cover:

- spawn into first empty active-planet bay;
- exact per-planet cost deduction;
- full dock / insufficient cash;
- same-tier merge into tapped destination;
- distinct-index requirement;
- empty/mismatched/T5 rejection;
- delayed duplicate action revalidates after first publish;
- save failure leaves controller state unchanged.

- [ ] **Step 4: Write failing site unlock/deploy/recall tests**

Cover:

- prerequisite, Surveying, cash, and active-planet ownership for `unlockSite`;
- deploy moves one dock rig into one empty Surveying-available node;
- first deploy flips `commissioned` once;
- unavailable/occupied node and empty source fail unchanged;
- recall moves to first empty active dock bay;
- full dock recall fails unchanged;
- recall never clears `commissioned`.

- [ ] **Step 5: Retarget progression/sale/mastery tests**

Technology tests gate on commissioned sites rather than mine existence.

Planet tests prove Lunar/Mars unlock seed `[T1, T1, null, null]` and their first site, retain current Surveying/cash/mastery rules, and travel accrues before switching.

Sale tests preserve active-planet-only clearing and floor-once revenue.

Mars reward test:

```dart
test('final first commission grants Mars reward exactly once', () async {
  final mars = await controllerOver(
    MiningSaveRepository(),
    seed: marsWithOnlyCobaltUncommissioned(clock.now),
  );

  final first = await mars.deployRig(
    0,
    MiningSiteId.cobaltChasm,
    MiningNodeId.n1,
  );
  expect(first.isSuccess, isTrue);
  expect(mars.state.cash, startingCash + 25000);

  await mars.recallRig(MiningSiteId.cobaltChasm, MiningNodeId.n1);
  await mars.deployRig(0, MiningSiteId.cobaltChasm, MiningNodeId.n1);
  expect(mars.state.cash, startingCash + 25000);
});
```

- [ ] **Step 6: Run and confirm the old controller API fails**

Run: `flutter test test/mining/mining_controller_test.dart`

Expected: FAIL until actions/state access are retargeted.

- [ ] **Step 7: Modify `MiningController` in place**

Required public actions:

```dart
Future<MiningActionResult> unlockSite(MiningSiteId siteId);
Future<MiningActionResult> spawnRig();
Future<MiningActionResult> mergeDockRigs(int sourceBay, int targetBay);
Future<MiningActionResult> deployRig(
  int sourceBay,
  MiningSiteId siteId,
  MiningNodeId nodeId,
);
Future<MiningActionResult> recallRig(
  MiningSiteId siteId,
  MiningNodeId nodeId,
);
Future<MiningActionResult> purchaseTechnology(TechnologyTrack track);
Future<MiningActionResult> unlockPlanet(MiningPlanetId id);
Future<MiningActionResult> switchPlanet(MiningPlanetId id);
Future<MiningSaleResult> sellAllCargo();
Future<void> checkpoint({bool accrue = true});
Future<OfflineProductionSummary?> resume();
```

Keep the current `_enqueueMutation` implementation shape. Each persisted action accrues candidate -> validates -> copies one next state -> saves once -> publishes.

Keep `refresh()` non-queued/non-persisting and skip advancement while busy exactly as current behavior.

Move the current mastery-reward false->true logic from `buildMine` into the first-commission branch inside `deployRig`.

- [ ] **Step 8: Run controller tests**

Run: `flutter test test/mining/mining_controller_test.dart`

Expected: PASS.

- [ ] **Step 9: Commit**

```sh
git add lib/mining/mining_controller.dart test/mining/mining_controller_test.dart
git commit -m "feat(mining): serialize merge-rig actions"
```

---

### Task 5: Add New Views and Extend the Existing Progression Projections

**Files:**
- Create: `lib/mining/fleet_dock_view.dart`
- Create: `lib/mining/site_deck_view.dart`
- Create: `lib/mining/mine_site_view.dart`
- Modify: `lib/mining/mining_progression_views.dart`
- Create: `test/mining/fleet_dock_view_test.dart`
- Create: `test/mining/site_deck_view_test.dart`
- Create: `test/mining/mine_site_view_test.dart`
- Modify: `test/mining/mining_progression_views_test.dart`

**Interfaces:**
- Produces: presentation-ready fleet/site/node/planet/technology state; widgets calculate no game rules.
- Preserves: current `StellarMapView._isVisible` progressive disclosure.

- [ ] **Step 1: Write Fleet Dock projection tests**

Freeze:

```dart
final view = FleetDockView.from(
  state: MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26)),
  content: MiningContentRegistry.stellarMining(),
  selectedBayIndex: 0,
  isBusy: false,
);
expect(view.bays, hasLength(4));
expect(view.bays[0].isSelected, isTrue);
expect(view.bays[1].canMergeWithSelection, isTrue);
expect(view.spawnCost, 25);
```

Also cover full/poor/busy spawn reasons and state-derived hints:

- `Tap two matching rigs to merge`
- `Tap an open node to deploy`
- `Merge or deploy a rig to free a bay`
- `Tap cargo to sell`

- [ ] **Step 2: Write Site Deck projection tests**

`MiningSiteCardState` is exactly:

```dart
enum MiningSiteCardState { locked, available, idle, operational }
```

Assert fresh Landing Basin idle, Carbon locked, affordable Carbon available, deployed Landing operational, and active-planet totals for commissioned count, cargo, capacity, projected sale value, and production rate.

- [ ] **Step 3: Write Mine Site projection tests**

Assert:

- Landing n1/n2 available at Surveying 0 and n3/n4 gated;
- node tier/rate/semantic label;
- selected rig deployability;
- occupied node recallability/full-dock reason;
- site cargo/capacity separate from active-planet sale total;
- projected sale floor-once behavior.

- [ ] **Step 4: Retarget the existing progression view tests**

Modify `test/mining/mining_progression_views_test.dart`, do not replace it with a second module.

Technology assertions use commissioned gate sites.

Stellar Map assertions keep current disclosure:

```text
fresh save: Homeworld + Lunar visible
Lunar unlocked: Homeworld + Lunar + Mars visible
```

Add commissioned site progress, active planet rate/cargo/capacity/value, site indicators, requirements, busy reason, and exact `Mars Frontier` copy.

- [ ] **Step 5: Run projection tests and confirm missing/old behavior**

```sh
flutter test test/mining/fleet_dock_view_test.dart \
  test/mining/site_deck_view_test.dart \
  test/mining/mine_site_view_test.dart \
  test/mining/mining_progression_views_test.dart
```

Expected: FAIL until views are implemented/retargeted.

- [ ] **Step 6: Implement the three new flat view files**

Required factories:

```dart
FleetDockView.from({
  required MiningSave state,
  required MiningContentRegistry content,
  required int? selectedBayIndex,
  required bool isBusy,
});

SiteDeckView.from({
  required MiningSave state,
  required MiningContentRegistry content,
  required int? selectedBayIndex,
  required bool isBusy,
});

MineSiteView.from({
  required MiningSave state,
  required MiningContentRegistry content,
  required MiningSiteId siteId,
  required int? selectedBayIndex,
  required bool isBusy,
});
```

Use `MiningContentRegistry` helpers for rates/capacities and controller-equivalent eligibility ordering; do not duplicate formulas in widgets.

- [ ] **Step 7: Extend `mining_progression_views.dart` in place**

Retarget `TechnologySheetView` and `StellarMapView` to `MiningSiteId` / commissioned state. Preserve `_isVisible` semantics from the current file.

- [ ] **Step 8: Run projection tests**

Run the four commands from Step 5.

Expected: PASS.

- [ ] **Step 9: Commit**

```sh
git add lib/mining/fleet_dock_view.dart lib/mining/site_deck_view.dart \
  lib/mining/mine_site_view.dart lib/mining/mining_progression_views.dart \
  test/mining/fleet_dock_view_test.dart test/mining/site_deck_view_test.dart \
  test/mining/mine_site_view_test.dart test/mining/mining_progression_views_test.dart
git commit -m "feat(mining): derive mobile mining views"
```

---

### Task 6: Import Prototype Art and Enforce the Lunar/Mars Input Gate

**Files:**
- Create: `assets/images/mining/{caverns,nodes,rigs,planets,sites,icons,effects,offline}/`
- Create: `lib/mining/presentation/mining_theme.dart`
- Create: `lib/mining/presentation/mining_visuals.dart`
- Create: `test/mining/presentation/mining_visuals_test.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`

**Interfaces:**
- Produces: complete nine-site visual lookup and the shared theme/anchor constants used by Task 7.
- Hard dependency: twelve externally authored Lunar/Mars PNGs listed below.

- [ ] **Step 1: Extract only the supplied production assets from the manually attached ZIP**

Copy these source groups and no duplicate `uploads/` copies/HTML/scripts:

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
art-icon-cash.png, art-icon-cargo.png, art-icon-merge.png,
art-icon-extraction.png, art-icon-logistics.png, art-icon-surveying.png
art-merge-burst.png
art-offline-hero.png
```

Use explicit `git add` paths later; never add the unpacked ZIP wholesale.

- [ ] **Step 2: Hard-stop if any externally authored Lunar/Mars input is missing**

Before completing the visual catalog, require these files to exist as real committed PNGs from the art workflow:

```text
assets/images/mining/caverns/water_ice.png      # 800x1200
assets/images/mining/nodes/water_ice.png        # 512x512 RGBA
assets/images/mining/caverns/titanium_ore.png   # 800x1200
assets/images/mining/nodes/titanium_ore.png     # 512x512 RGBA
assets/images/mining/caverns/helium_3.png       # 800x1200
assets/images/mining/nodes/helium_3.png         # 512x512 RGBA
assets/images/mining/caverns/iron_ore.png        # 800x1200
assets/images/mining/nodes/iron_ore.png          # 512x512 RGBA
assets/images/mining/caverns/silica.png          # 800x1200
assets/images/mining/nodes/silica.png            # 512x512 RGBA
assets/images/mining/caverns/cobalt_ore.png      # 800x1200
assets/images/mining/nodes/cobalt_ore.png        # 512x512 RGBA
```

If any is absent, stop this task. Do not generate it in Dart, use an old mine sprite, or commit a placeholder. Other non-visual review work may continue, but Task 7 cannot declare three-planet presentation complete and the PR cannot merge.

- [ ] **Step 3: Write asset-resolution tests after the gate is satisfied**

```dart
testWidgets('every authored site and rig resolves final assets', (tester) async {
  final visuals = MiningVisualCatalog.standard();
  for (final id in MiningSiteId.values) {
    final site = visuals.site(id);
    expect(site.portraitNodeAnchors, hasLength(4));
    expect(site.landscapeNodeAnchors, hasLength(4));
    await rootBundle.load(site.cavernAsset);
    await rootBundle.load(site.nodeAsset);
    await rootBundle.load(site.cardAsset);
  }
  for (final tier in RigTier.values) {
    await rootBundle.load(visuals.rigAsset(tier));
  }
});
```

For Lunar/Mars `cardAsset`, reuse the corresponding cavern path; Site Deck crops with `BoxFit.cover`.

- [ ] **Step 4: Lift existing UI tokens and define the visual catalog**

`MiningTheme` takes its cyan/panel/warning values from the current status/offline surfaces. Do not introduce a second palette.

`MiningSiteVisuals` contains:

```dart
final String cavernAsset;
final String nodeAsset;
final String cardAsset;
final List<Alignment> portraitNodeAnchors;
final List<Alignment> landscapeNodeAnchors;
```

Use one shared portrait anchor list and one shared landscape anchor list for all sites, with at most one explicit site override if a real supplied composition proves necessary. No anchor framework.

- [ ] **Step 5: Register only concrete mining asset directories**

```yaml
flutter:
  assets:
    - assets/images/mining/caverns/
    - assets/images/mining/nodes/
    - assets/images/mining/rigs/
    - assets/images/mining/planets/
    - assets/images/mining/sites/
    - assets/images/mining/icons/
    - assets/images/mining/effects/
    - assets/images/mining/offline/
```

Run `flutter pub get`.

- [ ] **Step 6: Run visual tests**

Run: `flutter test test/mining/presentation/mining_visuals_test.dart`

Expected: PASS only when all final inputs resolve.

- [ ] **Step 7: Commit explicit files**

```sh
git add assets/images/mining/ \
  lib/mining/presentation/mining_theme.dart \
  lib/mining/presentation/mining_visuals.dart \
  test/mining/presentation/mining_visuals_test.dart \
  pubspec.yaml pubspec.lock
git commit -m "feat(mining): add final mobile mining visuals"
```

---

### Task 7: Evolve MiningScreen into MiningShell and Cut Production Over

**Files:**
- Rename/modify: `lib/mining/presentation/mining_screen.dart` -> `lib/mining/presentation/mining_shell.dart`
- Create: `lib/mining/presentation/mining_hud.dart`
- Create: `lib/mining/presentation/mining_navigation.dart`
- Create: `lib/mining/presentation/fleet_dock.dart`
- Create: `lib/mining/presentation/site_deck_screen.dart`
- Create: `lib/mining/presentation/mine_site_screen.dart`
- Create: `lib/mining/presentation/stellar_map_screen.dart`
- Modify: `lib/mining/presentation/technology_sheet.dart`
- Modify: `lib/mining/presentation/mining_settings_sheet.dart`
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/main.dart`, `lib/main_menu.dart`
- Rename/modify: `test/mining/presentation/mining_screen_test.dart` -> `test/mining/presentation/mining_shell_test.dart`
- Create: `test/mining/presentation/site_deck_screen_test.dart`
- Create: `test/mining/presentation/mine_site_screen_test.dart`
- Create: `test/mining/presentation/stellar_map_screen_test.dart`
- Modify: existing technology/settings/offline tests
- Delete: `lib/mining/mining_sheet_view.dart`, `test/mining/mining_sheet_view_test.dart`
- Delete after replacement: old action/status/Stellar Map sheet files and corresponding presentation tests

**Interfaces:**
- Produces: the only production route and one responsive Flutter UI.
- Preserves: controller/audio/lifecycle/timer ownership and existing test handle identity contract.

- [ ] **Step 1: Write stateless Site Deck tests**

Use real projections and assert:

- locked/available/idle/operational cards;
- four dock bays and spawn action;
- bay/site/navigation callbacks;
- 360x640 and 430x932 geometry;
- text scale 1.3;
- 48x48 actions and semantics;
- no navigation/dock/card overlap.

- [ ] **Step 2: Implement shared HUD/navigation/fleet and Site Deck**

Create only presentation primitives that format supplied values. They calculate no eligibility/rates/costs.

`SiteDeckScreen` is `SafeArea` + scroll content + bottom navigation and consumes one `SiteDeckView`.

- [ ] **Step 3: Write Mine Site portrait/landscape tests**

At 360x640, 402x874, and 430x932 assert node targets fit the cavern and horizontal dock/navigation do not overlap.

At 874x402 assert cavern/cargo stop before a fixed right rail, the vertical dock/spawn are inside the rail, and compact back/settings controls stay left.

Add tap forwarding for bay, node, sale, back, settings; reduced-motion settled feedback; semantic selected/merge states.

- [ ] **Step 4: Implement one `MineSiteScreen`**

Use `LayoutBuilder` to select private portrait/landscape composition with the same `MineSiteView` and callbacks. Do not create two public screens.

Node widgets use shared `Alignment` constants from `MiningVisualCatalog`. Feedback is transient and non-persisted.

- [ ] **Step 5: Write and implement full-screen Stellar Map tests**

Verify current progressive visibility, active/unlocked/locked cards, commissioned progress, rate/cargo/capacity, three site indicators, requirements, busy actions, travel/unlock callbacks, `Mars Frontier`, geometry, and 48x48 actions.

Implement `StellarMapScreen` using the existing `StellarMapView` projection and shared navigation.

- [ ] **Step 6: Rename/evolve the owner and its test handles**

Rename:

```dart
MiningScreen -> MiningShell
MiningScreenHandles -> MiningShellHandles
```

Keep one controller and one `AudioManager` constructed exactly once in `initState`.

The timer must preserve the current live accrual sequence:

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

`_refreshPresentation()` derives `FleetDockView`, `SiteDeckView`, `MineSiteView`, `TechnologySheetView`, and `StellarMapView` from the current controller state; it does not accrue itself.

- [ ] **Step 7: Retarget shell action orchestration**

Implement local handlers for:

- select-or-merge dock bay;
- spawn;
- unlock/enter site;
- node deploy-or-recall;
- sale;
- back to Site Deck;
- navigation;
- technology purchase;
- planet unlock/travel;
- settings;
- checkpoint/resume.

After a settled persisted action: refresh presentation, clear only invalid selection, emit concise haptic/visual feedback, and show result copy. Child widgets never receive controller/repository references.

- [ ] **Step 8: Preserve initialization/lifecycle/audio behavior in shell tests**

Retarget current `mining_screen_test.dart` cases rather than writing a second owner harness.

Explicitly prove:

- `initialize()` persists a missing new-key save before the user can immediately return to Main Menu;
- recovered new-key save also attempts best-effort persistence;
- timer advances cargo via `refresh()` without writing every second;
- one controller/audio identity survives Site Deck -> Mine Site -> rotation -> Stellar Map;
- first gesture BGM, pause checkpoint/timer stop, resume/offline summary, reduced motion, settings prefs remain intact.

- [ ] **Step 9: Retarget secondary surfaces and Main Menu**

Technology uses commissioned-site projections/copy. Offline Return uses `fullSites` and prototype hero. Settings keeps the same audio preference keys.

Main Menu checks only `MiningSaveRepository.saveKey` and routes to `const MiningShell()`.

Remove `fontFamily: 'Orbitron'` from `lib/main.dart`.

- [ ] **Step 10: Delete retired presentation/view files and all corresponding tests**

Delete `MiningSheetView` and `test/mining/mining_sheet_view_test.dart`.

Delete old action/status/Stellar Map sheet files once their new surfaces own those responsibilities. Delete/retarget their presentation tests in the same commit.

`test/mining/mining_progression_views_test.dart` stays and must already be green from Task 5.

- [ ] **Step 11: Run focused presentation tests, then restore the full-suite gate**

```sh
flutter test test/main_menu_test.dart test/widget_test.dart \
  test/mining/presentation/mining_shell_test.dart \
  test/mining/presentation/site_deck_screen_test.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/stellar_map_screen_test.dart \
  test/mining/presentation/technology_sheet_test.dart \
  test/mining/presentation/mining_settings_sheet_test.dart \
  test/mining/presentation/offline_return_sheet_test.dart
flutter test
```

Expected: PASS. From this point onward every task runs the full suite.

- [ ] **Step 12: Commit without broad ZIP staging**

```sh
git add lib/main.dart lib/main_menu.dart lib/mining/ test/main_menu_test.dart \
  test/widget_test.dart test/mining/
git commit -m "feat(mining): cut over to the mobile mining shell"
```

---

### Task 8: Remove Flame, Validate the Three-Planet Economy, and Finish Guidance

**Files:**
- Delete: `lib/mining/world/**`, `test/mining/world/**`
- Delete after closure proof: unused `lib/game/terrain/**`, `test/game/terrain/**`, zero-consumer terrain assets
- Delete/retarget: `test/integration/mining_mvp_journey_test.dart`
- Create: `test/integration/merge_mining_journey_test.dart`
- Create after observed playtest: `docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md`
- Modify only if evidence requires: `lib/mining/mining_content.dart`, its tests
- Modify: `lib/constants/assets_path.dart`, `pubspec.yaml`, `pubspec.lock`, `README.md`, `CLAUDE.md`

**Interfaces:**
- Consumes: fully routed shell/domain.
- Produces: public-action-only progression proof, observed balance decision, and one final architecture.

- [ ] **Step 1: Prove Flame/terrain import closure before deletion**

```sh
rg "MiningGame|MiningSectorComponent|ParallaxTerrain|package:flame" lib test
```

Expected: matches only retired world/terrain files/tests. If any new production consumer appears, fix that consumer before deleting anything.

- [ ] **Step 2: Delete retired world/terrain closure and dependency**

Delete old mining world code/tests. Search every `lib/game/terrain` consumer and remove that closure only if zero-consumer.

Then:

```sh
rg "package:flame" lib test
```

When empty, remove `flame: ^1.30.0` and run `flutter pub get`.

Remove old building/terrain asset constants/directories only when `rg` proves zero consumers. Keep `ResourceType` and audio.

- [ ] **Step 3: Replace the integration journey with public actions only**

The new journey may advance the injected `TestClock` and call public controller actions. It must not mutate repository/controller state after initialization.

The sequence must cover:

```text
fresh two T1 rigs
-> merge/deploy Landing Basin
-> accrue/sell/spawn/merge as needed
-> unlock + commission Carbon Ridge
-> unlock + commission Granite Crater
-> buy Surveying 3
-> unlock Lunar (starter rigs/site seeded)
-> commission all Lunar sites
-> buy Surveying 5
-> unlock Mars
-> commission all Mars sites
-> verify one 25,000 mastery reward
-> reload from save
```

Also leave Homeworld production deployed while active planet is Lunar, advance time, and prove inactive Homeworld cargo grows.

- [ ] **Step 4: Run the fresh journey with current authored numbers**

Run: `flutter test test/integration/merge_mining_journey_test.dart`

Expected: PASS or a concrete affordability/cadence failure. Do not bypass a failing economy with state edits.

- [ ] **Step 5: Perform the representative playtest and record throughput/cadence evidence**

Create the playtest document only after observing real results. It must record concrete values for:

- device/simulator and commit;
- 360x640, 402x874, 430x932, 874x402;
- text scale 1.3, reduced motion, muted audio;
- representative early/mid/late site fill time;
- sell cadence / frequency of hitting cap;
- spawn/merge/sell cycles needed for Homeworld -> Lunar and Lunar -> Mars;
- fresh-to-Mars completion result;
- Keep or numeric-change decision.

Do not commit a blank template.

- [ ] **Step 6: Tune existing authored values only when evidence requires**

If fills are unreasonably short, change `baseCapacity` and/or `logisticsCapacityMultipliers` first and rerun exact content/simulation/journey tests.

Other permitted numeric tuning: spawn costs, site unlock costs, base rates, sale values, existing technology costs/effects.

No new mechanic, sink, currency, depletion, processing, contract, or prestige system is authorized.

Document before/after values in the playtest note.

- [ ] **Step 7: Update active architecture guidance**

README: Site Deck -> spawn/merge -> deploy/recall -> deterministic cargo -> sell -> Technology/Stellar Map.

CLAUDE:

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation/MiningSaveRepository
                         -> Flutter Site Deck / Mine Site / Stellar Map
```

Document:

- flat `sites` + planet `docks` save shape;
- `horologium.mergeMining.save`;
- `refresh()` live accrual and one-second timer;
- missing/recovered initial persistence;
- commissioned mastery;
- final asset paths;
- no Flame mining runtime.

- [ ] **Step 8: Run final legacy greps**

```sh
rg "horologium\.mining\.save|MiningGame|MiningSectorId|MineState|SectorProgress|package:flame|ParallaxTerrain" \
  lib test README.md CLAUDE.md pubspec.yaml
```

Expected: no active runtime reference. Historical documents are excluded.

Also verify there is only one current definition of each core type:

```sh
rg "class Mining(ContentRegistry|Save|Simulation|SaveRepository|Controller)" lib/mining
```

Expected: one definition per class.

- [ ] **Step 9: Run final repository gates**

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

- [ ] **Step 10: Commit cleanup/verification**

Stage explicit code/docs paths first; use `git status --short` to inspect deletions before the final commit.

```sh
git add lib test pubspec.yaml pubspec.lock README.md CLAUDE.md docs/playtests
git status --short
git commit -m "chore(mining): finish the mobile merge cutover"
```

---

## Plan Self-Review Checklist

Before implementation begins, verify this document against the spec:

- [ ] No `lib/mining/domain/` duplicate stack appears.
- [ ] Save shape is flat `sites` + per-planet `docks`.
- [ ] `rateMultipliers` is reused; no duplicate tier multiplier table is authored.
- [ ] Rig tiers/count do not scale capacity.
- [ ] `initialize()` missing/recovered persistence is explicitly tested and preserved.
- [ ] Shell timer explicitly calls `controller.refresh()` before projection.
- [ ] Existing `TestClock` / concrete repository subclasses are reused; no repository interface/fake implementation is introduced.
- [ ] `mining_progression_views.dart` is extended in place and `_isVisible` behavior is tested.
- [ ] `mining_sheet_view_test.dart` is explicitly deleted when its production file is removed.
- [ ] Twelve missing Lunar/Mars assets are an external hard gate, not a generation step.
- [ ] Prototype `art-worker-t*.png` mapping to rig tiers is explicit.
- [ ] Playtest records fill time and sell cadence.
- [ ] Risks in the spec cover art, refresh, initial persistence, catalog duplication, and fast fill cadence.
- [ ] Full Flutter suite gate resumes at Task 7 and remains required through Task 8.

## Final PR Verification Checklist

- [ ] HPA-285 is the only active implementation ticket.
- [ ] PR #19 remains the single PR and targets `main`.
- [ ] Prototype ZIP is attached manually to HPA-285.
- [ ] One current mining catalog/state/simulation/repository/controller exists.
- [ ] Fresh-to-Mars and save/reload journeys pass through public actions.
- [ ] All nine final cavern/node mappings resolve; no Lunar/Mars fallback exists.
- [ ] Foreground refresh and first-save persistence regressions are covered.
- [ ] Portrait/landscape/text-scale/reduced-motion/muted-audio gates are recorded.
- [ ] Old key is ignored, not migrated or deleted.
- [ ] Old action sheet, Flame world, unused terrain closure, and dependency are gone.
- [ ] README and CLAUDE describe final architecture.
- [ ] Formatting, analysis, tests, coverage, Chrome tests, APK, web, and available iOS build pass.
