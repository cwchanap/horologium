# HPA-285 Horologium Mobile Merge-Mining Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the one-mine-per-sector Flame runtime with one production-ready mobile merge-mining loop spanning Site Deck, responsive Mine Site, full-screen Stellar Map, deterministic offline production, and all three authored planets.

**Architecture:** Add the final replacement domain under `lib/mining/domain/` and pure projections under `lib/mining/views/` while the old route remains green, then build Flutter surfaces, cut `MainMenu` over to one `MiningShell`, and delete the retired flat domain/Flame world in the same PR. `MiningShell` is the only runtime owner; `MiningController` is the only serialized mutation boundary; widgets render immutable projections and forward actions.

**Tech Stack:** Flutter/Dart, SharedPreferences, audioplayers, Flutter widget tests, deterministic pure-Dart tests, existing GitHub Actions/build targets.

**Spec:** `docs/superpowers/specs/2026-08-26-hpa-285-mobile-merge-mining-redesign-design.md`

## Global Constraints

- Deliver planning, implementation, review, cutover, cleanup, and verification on this one HPA-285 branch and PR.
- Use the manually attached HPA-285 prototype ZIP as visual/interaction reference; repository catalog names and the spec remain authoritative.
- Use one `MiningShell`, controller, simulation, repository, audio manager, timer, and lifecycle observer.
- Use Flutter for all new surfaces; do not build a replacement Flame world.
- Use `horologium.mergeMining.save`; ignore `horologium.mining.save`; add no migration/version/compatibility path.
- Keep four planet-local dock bays, four nodes per site, and T1-T5 multipliers `1.00, 1.50, 2.25, 3.25, 4.50`.
- Seed two T1 rigs and the first site when a planet first becomes unlocked.
- Preserve deterministic elapsed-time production, active-planet selling, technology, current planet requirements, and the 25,000 Mars reward.
- Do not add finite depletion, drag-and-drop, rig IDs, workers, crafting, processing, dynamic prices, another currency, retention systems, server/account/cloud features, state-management packages, routing packages, or generic frameworks.
- Keep targets at least 48x48; support 360x640, 402x874, 430x932, 874x402, text scale 1.3, reduced motion, muted audio, and safe areas.
- Use system typography; remove undeclared Orbitron.
- Final production has no Lunar/Mars fallback, old save consumer, or Flame mining runtime.

---

## File Map

Final production ownership:

```text
lib/mining/domain/
  mining_content.dart
  mining_state.dart
  mining_simulation.dart
  mining_save_repository.dart
  mining_controller.dart
lib/mining/views/
  fleet_dock_view.dart
  site_deck_view.dart
  mine_site_view.dart
  progression_views.dart
lib/mining/presentation/
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

Final focused tests mirror `domain/`, `views/`, and `presentation/`, plus `test/integration/merge_mining_journey_test.dart` and shared fixtures under `test/support/`.

---

### Task 1: Define Closed Content and Immutable Merge-Mining State

**Files:**
- Create: `lib/mining/domain/mining_content.dart`
- Create: `lib/mining/domain/mining_state.dart`
- Create: `test/mining/domain/mining_content_test.dart`
- Create: `test/mining/domain/mining_state_test.dart`

**Interfaces:**
- Consumes: `ResourceType` from `lib/game/resources/resource_type.dart`.
- Produces: all closed IDs, authored definitions/helpers, `TechnologyLevels`, `SiteProgress`, `PlanetMiningProgress`, and `MiningSave`.

- [ ] **Step 1: Write failing catalog tests**

```dart
test('authors three planets, nine sites, four nodes, and spawn costs', () {
  final content = MiningContentRegistry.stellarMining();
  expect(content.planets.keys, MiningPlanetId.values.toSet());
  expect(content.planets.values.expand((p) => p.sites), hasLength(9));
  for (final site in content.planets.values.expand((p) => p.sites)) {
    expect(site.nodes.map((n) => n.id), MiningNodeId.values);
  }
  expect(content.planet(MiningPlanetId.homeworld).rigSpawnCost, 25);
  expect(content.planet(MiningPlanetId.lunarFrontier).rigSpawnCost, 500);
  expect(content.planet(MiningPlanetId.marsFrontier).rigSpawnCost, 5000);
});

test('uses the frozen rig multiplier ladder', () {
  final content = MiningContentRegistry.stellarMining();
  expect(
    RigTier.values.map(content.rigMultiplier).toList(),
    [1.0, 1.5, 2.25, 3.25, 4.5],
  );
});
```

Add exact assertions for every site prerequisite, Surveying requirement, unlock cash, base rate, capacity, sale value, node Surveying table, technology costs/gates, planet requirements, and Mars reward from the spec.

- [ ] **Step 2: Run tests and confirm missing types**

Run: `flutter test test/mining/domain/mining_content_test.dart`

Expected: FAIL because `lib/mining/domain/mining_content.dart` does not exist.

- [ ] **Step 3: Implement closed IDs and authored definitions**

```dart
enum MiningPlanetId { homeworld, lunarFrontier, marsFrontier }
enum MiningNodeId { n1, n2, n3, n4 }
enum RigTier { t1, t2, t3, t4, t5 }
enum TechnologyTrack { extraction, logistics, surveying }

enum MiningSiteId {
  landingBasin,
  carbonRidge,
  graniteCrater,
  frozenBasin,
  titaniumHighlands,
  heliumMare,
  ochreBasin,
  silicaDunes,
  cobaltChasm,
}
```

Use concrete `MiningNodeDefinition`, `MiningSiteDefinition`, and `MiningPlanetDefinition` classes. `MiningContentRegistry` must provide:

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
double effectiveSiteCapacity(
  MiningSiteId siteId,
  int logisticsLevel,
);
Duration offlineCapFor(int logisticsLevel);
bool isPlanetMastered(
  MiningPlanetId planetId,
  Iterable<MiningSiteId> commissionedSiteIds,
);
```

- [ ] **Step 4: Write failing initial-state tests**

```dart
test('fresh state seeds only Homeworld and two T1 rigs', () {
  final now = DateTime.utc(2026, 8, 26, 12);
  final state = MiningSave.initial(nowUtc: now);
  expect(state.cash, 100);
  expect(state.unlockedPlanetIds, {MiningPlanetId.homeworld});
  expect(state.activePlanetId, MiningPlanetId.homeworld);
  expect(
    state.planets[MiningPlanetId.homeworld]!.dock,
    [RigTier.t1, RigTier.t1, null, null],
  );
  expect(state.site(MiningSiteId.landingBasin).unlocked, isTrue);
  expect(state.site(MiningSiteId.landingBasin).commissioned, isFalse);
  expect(state.planets[MiningPlanetId.lunarFrontier]!.dock, everyElement(isNull));
});
```

Also assert all sites contain exactly n1-n4, locked planets are pristine, `copyWith` does not alias lists/maps, and equality/hash include nested state.

- [ ] **Step 5: Implement immutable state**

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

class PlanetMiningProgress {
  const PlanetMiningProgress({required this.dock, required this.sites});
  final List<RigTier?> dock;
  final Map<MiningSiteId, SiteProgress> sites;
}
```

`MiningSave` stores cash, UTC timestamp, technology, unlocked planets, active planet, and all three planet-progress records. Use unmodifiable copies at every constructor/copy boundary and expose `site(MiningSiteId)` as a read-only convenience.

- [ ] **Step 6: Run focused tests**

Run: `flutter test test/mining/domain/mining_content_test.dart test/mining/domain/mining_state_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```sh
git add lib/mining/domain/mining_content.dart \
  lib/mining/domain/mining_state.dart \
  test/mining/domain/mining_content_test.dart \
  test/mining/domain/mining_state_test.dart
git commit -m "feat(mining): define merge-mining domain state"
```

---

### Task 2: Add the Fresh Strict Save Repository

**Files:**
- Create: `lib/mining/domain/mining_save_repository.dart`
- Create: `test/mining/domain/mining_save_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 state/content.
- Produces: `MiningLoadResult`, `hasSave`, strict load/save, and new-key recovery.

- [ ] **Step 1: Write failing presence and round-trip tests**

```dart
test('uses only the merge-mining key', () async {
  SharedPreferences.setMockInitialValues({'horologium.mining.save': '{}'});
  final repository = MiningSaveRepository();
  expect(MiningSaveRepository.saveKey, 'horologium.mergeMining.save');
  expect(await repository.hasSave(), isFalse);
});

test('round-trips nested docks, sites, nodes, and technology', () async {
  SharedPreferences.setMockInitialValues({});
  final repository = MiningSaveRepository();
  final state = progressedMiningState();
  await repository.save(state);
  final loaded = await repository.load(nowUtc: DateTime.utc(2026, 8, 27));
  expect(loaded.state, state);
  expect(loaded.recoveredFromInvalidSave, isFalse);
});
```

- [ ] **Step 2: Add structural-invalidity tests**

Cover exact-key rejection, malformed JSON, wrong types, invalid UTC/cash/technology, dock length, tier names, active/unlocked invariants, locked planet/site contamination, prerequisite order, first-site invariant, unavailable-node deployment, negative cargo, and unknown/duplicate IDs. Add a valid over-capacity test that clamps cargo without recovery.

- [ ] **Step 3: Run and confirm repository is missing**

Run: `flutter test test/mining/domain/mining_save_repository_test.dart`

Expected: FAIL.

- [ ] **Step 4: Implement repository boundary**

```dart
class MiningSaveRepository {
  static const saveKey = 'horologium.mergeMining.save';
  MiningSaveRepository({MiningContentRegistry? content});
  Future<bool> hasSave();
  Future<MiningLoadResult> load({required DateTime nowUtc});
  Future<void> save(MiningSave state);
}
```

Decode one closed document containing every planet, each authored site, exactly four dock entries, and exactly n1-n4. Read the raw preference generically before type-checking. Missing data creates fresh state; invalid data returns fresh state with recovery; valid cargo clamps through `effectiveSiteCapacity`.

- [ ] **Step 5: Run repository tests**

Run: `flutter test test/mining/domain/mining_save_repository_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```sh
git add lib/mining/domain/mining_save_repository.dart \
  test/mining/domain/mining_save_repository_test.dart
git commit -m "feat(mining): persist strict merge-mining saves"
```

---

### Task 3: Simulate Production from Deployed Rigs

**Files:**
- Create: `lib/mining/domain/mining_simulation.dart`
- Create: `test/mining/domain/mining_simulation_test.dart`

**Interfaces:**
- Consumes: Task 1 content/state.
- Produces: `OfflineProductionSummary`, `AccrualResult`, and pure `accrue`.

- [ ] **Step 1: Write failing production tests**

```dart
test('only deployed rigs produce and rates sum by tier', () {
  final state = stateWithRigs(
    MiningSiteId.landingBasin,
    {MiningNodeId.n1: RigTier.t1, MiningNodeId.n2: RigTier.t2},
  );
  final result = MiningSimulation(content).accrue(
    state,
    state.lastAccruedAtUtc.add(const Duration(seconds: 10)),
  );
  expect(
    result.state.site(MiningSiteId.landingBasin).storedAmount,
    closeTo((0.50 * 1.0 + 0.50 * 1.5) * 10, 0.0001),
  );
});
```

Add tests for docked rigs, Extraction, Logistics capacity, inactive unlocked planets, full-site reporting, offline cap, negative/zero elapsed time, and deterministic repeated inputs.

- [ ] **Step 2: Run and verify missing simulation**

Run: `flutter test test/mining/domain/mining_simulation_test.dart`

Expected: FAIL.

- [ ] **Step 3: Implement summary and accrual**

```dart
class OfflineProductionSummary {
  const OfflineProductionSummary({
    required this.elapsedUsed,
    required this.produced,
    required this.productionByPlanet,
    required this.fullSites,
    required this.wasOfflineCapped,
  });
  final Duration elapsedUsed;
  final Map<ResourceType, double> produced;
  final Map<MiningPlanetId, Map<ResourceType, double>> productionByPlanet;
  final Set<MiningSiteId> fullSites;
  final bool wasOfflineCapped;
}

class MiningSimulation {
  const MiningSimulation(this.content);
  final MiningContentRegistry content;
  AccrualResult accrue(MiningSave state, DateTime nowUtc);
}
```

Iterate content order across unlocked planets/sites. Collect non-null deployed tiers, calculate rate through content, clamp to remaining capacity, update immutable site state, and advance timestamp to `nowUtc` after a positive elapsed window.

- [ ] **Step 4: Run tests**

Run: `flutter test test/mining/domain/mining_simulation_test.dart`

Expected: PASS.

- [ ] **Step 5: Run all replacement-domain tests**

Run: `flutter test test/mining/domain`

Expected: PASS.

- [ ] **Step 6: Commit**

```sh
git add lib/mining/domain/mining_simulation.dart \
  test/mining/domain/mining_simulation_test.dart
git commit -m "feat(mining): accrue deployed rig production"
```

---

### Task 4: Serialize Spawn, Merge, Site Unlock, Deploy, and Recall

**Files:**
- Create: `lib/mining/domain/mining_controller.dart`
- Create: `test/mining/domain/mining_controller_test.dart`
- Create: `test/support/merge_mining_fixtures.dart`

**Interfaces:**
- Consumes: repository, simulation, content, injected UTC clock.
- Produces: controller queue, typed results, fleet/site mutations, checkpoint/resume.

- [ ] **Step 1: Create deterministic controller fixtures**

```dart
final class MutableTestClock {
  MutableTestClock(this.now);
  DateTime now;
  DateTime call() => now;
}

final class MemoryMiningSaveRepository implements MiningSaveRepository {
  MemoryMiningSaveRepository({required this.current});
  MiningSave current;
  Object? saveError;
  @override Future<MiningLoadResult> load({required DateTime nowUtc}) async =>
      MiningLoadResult(
        state: current,
        recoveredFromInvalidSave: false,
        wasMissing: false,
      );
  @override Future<void> save(MiningSave state) async {
    if (saveError != null) throw saveError!;
    current = state;
  }
}
```

Add `ControllerHarness.fromState` that wires real content/simulation/controller to these fakes.

- [ ] **Step 2: Write failing spawn/merge tests**

Cover first-empty spawn, cash deduction, full dock, insufficient cash, same-tier merge destination, different-tier rejection, same-index rejection, empty source/target, and T5 rejection.

```dart
test('merges into tapped destination and empties source', () async {
  final harness = ControllerHarness.fresh();
  await harness.controller.initialize();
  final result = await harness.controller.mergeDockRigs(0, 1);
  expect(result.isSuccess, isTrue);
  expect(
    harness.controller.state.activePlanet.dock,
    [null, RigTier.t2, null, null],
  );
});
```

- [ ] **Step 3: Write failing unlock/deploy/recall tests**

Cover prerequisite/Surveying/cash site unlocks, active-planet ownership, unavailable/occupied nodes, empty source bay, first deployment setting `commissioned`, recall to first empty bay, full-dock recall failure, and recall preserving commission.

- [ ] **Step 4: Write queue and failed-save tests**

Use a delayed repository to prove duplicate queued spawn/merge/deploy actions revalidate after the first state publishes. Set `saveError` and prove controller state plus repository state remain unchanged.

- [ ] **Step 5: Run and verify controller is missing**

Run: `flutter test test/mining/domain/mining_controller_test.dart`

Expected: FAIL.

- [ ] **Step 6: Implement controller queue and actions**

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
Future<void> checkpoint({bool accrue = true});
Future<OfflineProductionSummary?> resume();
```

Use one `_enqueueMutation<T>` future chain. Increment pending count synchronously; inside each operation accrue, validate, create one next state, await one save, then publish. Never mutate dock lists or nested maps in place.

- [ ] **Step 7: Run controller tests**

Run: `flutter test test/mining/domain/mining_controller_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit**

```sh
git add lib/mining/domain/mining_controller.dart \
  test/mining/domain/mining_controller_test.dart \
  test/support/merge_mining_fixtures.dart
git commit -m "feat(mining): serialize merge-mining actions"
```

---

### Task 5: Preserve Technology, Planet Progression, Selling, and Mars Mastery

**Files:**
- Modify: `lib/mining/domain/mining_controller.dart`
- Modify: `test/mining/domain/mining_controller_test.dart`

**Interfaces:**
- Consumes: Task 4 queue/actions.
- Produces: complete progression and economy mutations.

- [ ] **Step 1: Add a commissioned-site state helper**

Add `stateWithCommissionedSites(MiningSave state, Set<MiningSiteId> ids)` to shared fixtures using immutable planet/site copies.

- [ ] **Step 2: Write failing technology tests**

Prove commissioned Landing Basin permits level 1, unlocked-but-uncommissioned does not, costs/effects remain current, max level rejects, insufficient cash rejects, and queued purchases do not double-spend.

- [ ] **Step 3: Write failing planet unlock/travel tests**

```dart
test('Lunar unlock seeds first site and two T1 rigs', () async {
  final harness = ControllerHarness.fromState(homeworldMasteredState());
  await harness.controller.initialize();
  final result = await harness.controller.unlockPlanet(
    MiningPlanetId.lunarFrontier,
  );
  expect(result.isSuccess, isTrue);
  expect(harness.controller.state.activePlanetId, MiningPlanetId.lunarFrontier);
  expect(
    harness.controller.state.planets[MiningPlanetId.lunarFrontier]!.dock,
    [RigTier.t1, RigTier.t1, null, null],
  );
  expect(harness.controller.state.site(MiningSiteId.frozenBasin).unlocked, isTrue);
});
```

Also cover mastery, Surveying, cash, locked travel, current-location travel, inactive production accrued before travel, and save failure.

- [ ] **Step 4: Write failing sale and Mars reward tests**

Cover active-planet-only cargo, floor-once aggregate revenue, zero cargo, fractional projected revenue, final Cobalt first deployment granting exactly 25,000, recall/redeploy never paying again, and save failure not publishing reward/commission.

- [ ] **Step 5: Run and confirm missing methods**

Run: `flutter test test/mining/domain/mining_controller_test.dart`

Expected: FAIL on progression/sale methods.

- [ ] **Step 6: Implement progression methods**

```dart
Future<MiningActionResult> purchaseTechnology(TechnologyTrack track);
Future<MiningActionResult> unlockPlanet(MiningPlanetId id);
Future<MiningActionResult> switchPlanet(MiningPlanetId id);
Future<MiningSaleResult> sellAllCargo();
```

Calculate Mars reward inside `deployRig` by comparing mastery before and after the first commission in the same next state. Use commissioned gate sites for technology.

- [ ] **Step 7: Run replacement-domain tests**

Run: `flutter test test/mining/domain`

Expected: PASS.

- [ ] **Step 8: Commit**

```sh
git add lib/mining/domain/mining_controller.dart \
  test/mining/domain/mining_controller_test.dart \
  test/support/merge_mining_fixtures.dart
git commit -m "feat(mining): preserve progression in merge domain"
```

---

### Task 6: Derive Fleet, Site Deck, Mine Site, Technology, and Stellar Map Views

**Files:**
- Create: `lib/mining/views/fleet_dock_view.dart`
- Create: `lib/mining/views/site_deck_view.dart`
- Create: `lib/mining/views/mine_site_view.dart`
- Create: `lib/mining/views/progression_views.dart`
- Create: matching tests under `test/mining/views/`
- Modify: `test/support/merge_mining_fixtures.dart`

**Interfaces:**
- Consumes: replacement state/content plus busy/selection inputs.
- Produces: presentation-ready immutable values; widgets calculate no rules.

- [ ] **Step 1: Write failing Fleet Dock tests**

```dart
test('marks same-tier destination as merge eligible', () {
  final view = FleetDockView.from(
    state: MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 26)),
    content: MiningContentRegistry.stellarMining(),
    selectedBayIndex: 0,
    isBusy: false,
  );
  expect(view.bays[0].isSelected, isTrue);
  expect(view.bays[1].canMergeWithSelection, isTrue);
  expect(view.spawnCost, 25);
});
```

Also freeze full/poor/busy reasons and the four state-derived hints.

- [ ] **Step 2: Write failing Site Deck tests**

Assert Landing Basin idle on fresh state, Carbon locked, affordable Carbon available, deployed Landing operational, and all cash/progress/cargo/value/rate/tier/action/reason fields.

- [ ] **Step 3: Write failing Mine Site tests**

Assert Landing n1/n2 available and n3/n4 locked at Surveying 0, node tier/rate, selected-rig deployability, full-dock recall reason, site cargo separately from active-planet sale totals, zero/fractional sale reasons, and floor-once projected revenue.

- [ ] **Step 4: Write failing progression tests**

Assert commissioned-site technology gates/copy, Surveying node count, fresh map Homeworld+Lunar, Mars disclosure after Lunar unlock, all planet totals/indicators/requirements/actions, and exact `Mars Frontier` copy.

- [ ] **Step 5: Run and verify views are missing**

Run: `flutter test test/mining/views`

Expected: FAIL.

- [ ] **Step 6: Implement exact view factories**

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

TechnologySheetView.from({
  required MiningSave state,
  required MiningContentRegistry content,
});

StellarMapView.from({
  required MiningSave state,
  required MiningContentRegistry content,
  required bool isBusy,
});
```

`FleetBayView` exposes index/tier/selected/merge-eligible. `MiningSiteCardView` exposes id/name/resource/resource name/state/status/commissioned/deployed tiers/rate/cargo/capacity/action/enabled/reason. `MiningNodeView` exposes id/Surveying/availability/tier/rate/deploy/recall/reason/semantic label. Planet views expose active/unlocked/progress/rate/cargo/value/three site indicators/requirements/action/reason.

- [ ] **Step 7: Add concrete widget fixtures**

Add:

```dart
SiteDeckView mixedSiteDeckView();
MineSiteView operationalMineSiteView();
StellarMapView lunarUnlockedStellarMapView();
MiningSave progressedMiningState({
  int cash = 100000,
  int surveying = 5,
  MiningPlanetId activePlanetId = MiningPlanetId.homeworld,
});
```

The fixtures must call real projection factories rather than constructing view objects by hand.

- [ ] **Step 8: Run projection tests**

Run: `flutter test test/mining/views`

Expected: PASS.

- [ ] **Step 9: Commit**

```sh
git add lib/mining/views test/mining/views test/support/merge_mining_fixtures.dart
git commit -m "feat(mining): derive merge-mining presentation views"
```

---

### Task 7: Import Final Art and Create the Visual Catalog

**Files:**
- Create: `assets/images/mining/{caverns,nodes,rigs,planets,sites,icons,effects,offline}/`
- Create: `lib/mining/presentation/mining_theme.dart`
- Create: `lib/mining/presentation/mining_visuals.dart`
- Create: `test/mining/presentation/mining_visuals_test.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`

**Interfaces:**
- Consumes: attached prototype ZIP and closed IDs.
- Produces: complete nine-site asset lookup, shared anchors, theme tokens.

- [ ] **Step 1: Copy supplied prototype assets**

Map supplied gold/coal/stone caverns and nodes, T1-T5 rigs, three planets, three Homeworld cards, cash/cargo/merge/technology icons, merge burst, and offline hero into their final `assets/images/mining/` subdirectories. Preserve PNG source quality.

- [ ] **Step 2: Produce the twelve missing final files**

Create 800x1200 caverns and 512x512 transparent nodes at:

```text
caverns/water_ice.png      nodes/water_ice.png
caverns/titanium_ore.png   nodes/titanium_ore.png
caverns/helium_3.png       nodes/helium_3.png
caverns/iron_ore.png       nodes/iron_ore.png
caverns/silica.png         nodes/silica.png
caverns/cobalt_ore.png     nodes/cobalt_ore.png
```

Use consistent sci-fi cavern perspective, dark readable center, four uncluttered shared-anchor zones, no text/UI/rigs. Resource identity is material/color only.

- [ ] **Step 3: Write failing asset-resolution tests**

```dart
testWidgets('every authored site and rig resolves assets', (tester) async {
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

Also resolve planet, HUD, technology, effect, and offline assets.

- [ ] **Step 4: Register every concrete asset subdirectory**

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

- [ ] **Step 5: Implement concrete theme and visual catalog**

```dart
abstract final class MiningTheme {
  static const visorAccent = Color(0xFF18FFFF);
  static const panelBackground = Color(0xF20E1828);
  static const panelBorder = Color(0x8053D4E8);
  static const warning = Colors.orangeAccent;
}

class MiningSiteVisuals {
  const MiningSiteVisuals({
    required this.cavernAsset,
    required this.nodeAsset,
    required this.cardAsset,
    required this.portraitNodeAnchors,
    required this.landscapeNodeAnchors,
  });
  final String cavernAsset;
  final String nodeAsset;
  final String cardAsset;
  final List<Alignment> portraitNodeAnchors;
  final List<Alignment> landscapeNodeAnchors;
}
```

`MiningVisualCatalog.standard()` contains exactly nine site entries, five rigs, three planets, three technology icons, cash/cargo/merge icons, merge burst, and offline hero. Lunar/Mars cards use their cavern path with `BoxFit.cover`. Use shared anchors from the spec.

- [ ] **Step 6: Run asset tests**

```sh
flutter pub get
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```sh
git add assets/images/mining lib/mining/presentation/mining_theme.dart \
  lib/mining/presentation/mining_visuals.dart \
  test/mining/presentation/mining_visuals_test.dart \
  pubspec.yaml pubspec.lock
git commit -m "feat(mining): add mobile merge-mining visuals"
```

---

### Task 8: Build Shared HUD, Navigation, Fleet Dock, and Site Deck

**Files:**
- Create: `lib/mining/presentation/mining_hud.dart`
- Create: `lib/mining/presentation/mining_navigation.dart`
- Create: `lib/mining/presentation/fleet_dock.dart`
- Create: `lib/mining/presentation/site_deck_screen.dart`
- Create: `test/mining/presentation/site_deck_screen_test.dart`

**Interfaces:**
- Consumes: Task 6 projections and Task 7 theme/catalog.
- Produces: stateless Site Deck and shared controls.

- [ ] **Step 1: Write failing action-forwarding test**

```dart
testWidgets('renders site states and forwards actions', (tester) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: SiteDeckScreen(
      view: mixedSiteDeckView(),
      visuals: MiningVisualCatalog.standard(),
      onSitePressed: (id) => calls.add('site:${id.name}'),
      onUnlockSite: (id) => calls.add('unlock:${id.name}'),
      onFleetBayPressed: (i) => calls.add('bay:$i'),
      onSpawnRig: () => calls.add('spawn'),
      onNavigation: (d) => calls.add(d.name),
    ),
  ));
  await tester.tap(find.byKey(const Key('fleet-bay-0')));
  await tester.tap(find.byKey(const Key('site-card-action-carbonRidge')));
  expect(calls, containsAll(['bay:0', 'unlock:carbonRidge']));
});
```

- [ ] **Step 2: Add geometry/semantics/text-scale tests**

Pump 360x640 and 430x932 with text scale 1.3. Assert each bay/control is at least 48x48, cash/spawn have semantic labels, no overflow occurs, and bottom navigation does not overlap fleet dock or final card action using `tester.getRect`.

- [ ] **Step 3: Run and verify widgets are missing**

Run: `flutter test test/mining/presentation/site_deck_screen_test.dart`

Expected: FAIL.

- [ ] **Step 4: Implement shared controls**

Create `MiningCashShard`, `MiningCargoControl`, `MiningPlanetProgressHeader`, and `MiningRateBadge`. They format supplied values and semantics only; they calculate no economy state.

Create:

```dart
enum MiningPrimarySurface { siteDeck, stellarMap }
enum MiningNavigationDestination { siteDeck, technology, stellarMap, settings }
enum FleetDockAxis { horizontal, vertical }
```

`MiningNavigationBar` has four visible 48x48-or-larger destinations. `FleetDock` renders exactly four keyed bays and one spawn control, supports horizontal/vertical axes, uses `AnimatedSwitcher`, and changes to opacity-only under reduced motion.

- [ ] **Step 5: Implement Site Deck**

Use `SafeArea` plus scroll content: top cash/planet/rate/cargo HUD, one card per view, horizontal fleet dock, and bottom navigation. Cards consume `MiningSiteCardView`; direct callbacks separate enter from unlock.

- [ ] **Step 6: Run Site Deck tests**

Run: `flutter test test/mining/presentation/site_deck_screen_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```sh
git add lib/mining/presentation/mining_hud.dart \
  lib/mining/presentation/mining_navigation.dart \
  lib/mining/presentation/fleet_dock.dart \
  lib/mining/presentation/site_deck_screen.dart \
  test/mining/presentation/site_deck_screen_test.dart
git commit -m "feat(mining): build the mobile site deck"
```

---

### Task 9: Build One Responsive Mine Site

**Files:**
- Create: `lib/mining/presentation/mine_site_screen.dart`
- Create: `test/mining/presentation/mine_site_screen_test.dart`

**Interfaces:**
- Consumes: `MineSiteView`, visual catalog, shared HUD/fleet dock.
- Produces: one stateless responsive surface and action callbacks.

- [ ] **Step 1: Write failing interaction tests**

```dart
testWidgets('forwards bay, node, sale, back, and settings taps', (tester) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: MineSiteScreen(
      view: operationalMineSiteView(),
      visuals: MiningVisualCatalog.standard(),
      onFleetBayPressed: (i) => calls.add('bay:$i'),
      onSpawnRig: () => calls.add('spawn'),
      onNodePressed: (id) => calls.add('node:${id.name}'),
      onSell: () => calls.add('sell'),
      onBack: () => calls.add('back'),
      onSettings: () => calls.add('settings'),
    ),
  ));
  await tester.tap(find.byKey(const Key('fleet-bay-0')));
  await tester.tap(find.byKey(const Key('mine-node-n1')));
  await tester.tap(find.byKey(const Key('mine-site-cargo-control')));
  expect(calls, containsAll(['bay:0', 'node:n1', 'sell']));
});
```

- [ ] **Step 2: Add portrait geometry tests**

At 360x640, 402x874, and 430x932 assert cavern/dock/navigation do not overlap, all node centers lie within cavern, all nodes are at least 48x48, and no exception/overflow occurs.

- [ ] **Step 3: Add landscape rail tests**

At 874x402 assert cavern and cargo end at or before the right rail, vertical dock exists inside the rail, compact navigation stays left, and no system inset overlaps.

- [ ] **Step 4: Add reduced-motion/selected-state tests**

Pump `MediaQueryData(disableAnimations: true)` and prove tier/feedback settles without translation/scale. Selected and merge-eligible bays must expose text/semantics in addition to color.

- [ ] **Step 5: Run and verify screen is missing**

Run: `flutter test test/mining/presentation/mine_site_screen_test.dart`

Expected: FAIL.

- [ ] **Step 6: Implement one responsive public widget**

```dart
class MineSiteScreen extends StatelessWidget {
  const MineSiteScreen({
    super.key,
    required this.view,
    required this.visuals,
    required this.onFleetBayPressed,
    required this.onSpawnRig,
    required this.onNodePressed,
    required this.onSell,
    required this.onBack,
    required this.onSettings,
    this.feedback,
  });
  final MineSiteView view;
  final MiningVisualCatalog visuals;
  final ValueChanged<int> onFleetBayPressed;
  final VoidCallback onSpawnRig;
  final ValueChanged<MiningNodeId> onNodePressed;
  final VoidCallback onSell;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final MiningSiteFeedback? feedback;
}
```

`LayoutBuilder` selects private portrait/landscape compositions with the same fields/callbacks. Portrait: top HUD, expanded cavern stack, horizontal dock, compact controls. Landscape: expanded cavern plus fixed 152-pixel right rail containing cargo, vertical dock, spawn, settings. Node widgets consume only node view state.

- [ ] **Step 7: Implement feedback**

```dart
enum MiningSiteFeedbackKind { merge, deploy, recall, sale }

class MiningSiteFeedback {
  const MiningSiteFeedback({
    required this.sequence,
    required this.kind,
    this.nodeId,
    this.bayIndex,
  });
  final int sequence;
  final MiningSiteFeedbackKind kind;
  final MiningNodeId? nodeId;
  final int? bayIndex;
}
```

Normal feedback <=550 ms; reduced-motion feedback <=200 ms opacity; never persist it.

- [ ] **Step 8: Run tests**

Run: `flutter test test/mining/presentation/mine_site_screen_test.dart`

Expected: PASS.

- [ ] **Step 9: Commit**

```sh
git add lib/mining/presentation/mine_site_screen.dart \
  test/mining/presentation/mine_site_screen_test.dart
git commit -m "feat(mining): build responsive mine site"
```

---

### Task 10: Build the Full-Screen Stellar Map

**Files:**
- Create: `lib/mining/presentation/stellar_map_screen.dart`
- Create: `test/mining/presentation/stellar_map_screen_test.dart`

**Interfaces:**
- Consumes: `StellarMapView`, visuals, shared navigation.
- Produces: full-screen cards and direct unlock/travel callbacks.

- [ ] **Step 1: Write failing visibility/action test**

```dart
testWidgets('renders progressive planets and forwards travel/unlock', (tester) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: StellarMapScreen(
      view: lunarUnlockedStellarMapView(),
      visuals: MiningVisualCatalog.standard(),
      onUnlock: (id) => calls.add('unlock:${id.name}'),
      onTravel: (id) => calls.add('travel:${id.name}'),
      onNavigation: (d) => calls.add(d.name),
    ),
  ));
  expect(find.byKey(const Key('stellar-map-planet-homeworld')), findsOneWidget);
  expect(find.byKey(const Key('stellar-map-planet-marsFrontier')), findsOneWidget);
  await tester.tap(find.byKey(const Key('stellar-map-action-homeworld')));
  expect(calls, contains('travel:homeworld'));
});
```

- [ ] **Step 2: Add locked/active/geometry/accessibility tests**

Assert card progress/rate/cargo/site indicators, locked requirement rows, disabled reasons, busy state, 360x640 and 430x932 geometry, text scale 1.3, 48x48 actions, and `Mars Frontier` copy.

- [ ] **Step 3: Run and verify screen is missing**

Run: `flutter test test/mining/presentation/stellar_map_screen_test.dart`

Expected: FAIL.

- [ ] **Step 4: Implement full-screen map**

Use `SafeArea` plus scroll cards and shared bottom navigation. Cards render projections only. Active cards show current location; unlocked inactive cards travel; locked cards show mastery/Surveying/cash and unlock state.

- [ ] **Step 5: Run tests**

Run: `flutter test test/mining/presentation/stellar_map_screen_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```sh
git add lib/mining/presentation/stellar_map_screen.dart \
  test/mining/presentation/stellar_map_screen_test.dart
git commit -m "feat(mining): promote stellar map to full screen"
```

---

### Task 11: Cut Production Over to MiningShell and Retarget Secondary Surfaces

**Files:**
- Create: `lib/mining/presentation/mining_shell.dart`
- Modify: `lib/main.dart`, `lib/main_menu.dart`
- Rewrite: `technology_sheet.dart`, `offline_return_sheet.dart`
- Modify: `mining_settings_sheet.dart`
- Delete: old `mining_screen.dart`, action/status/map sheet, `mining_sheet_view.dart`, and corresponding presentation tests
- Create/modify: shell, menu, app, and secondary-surface tests

**Interfaces:**
- Consumes: all replacement domain/views/screens.
- Produces: only production route and lifecycle/audio/action orchestration.

- [ ] **Step 1: Write failing Main Menu key tests**

```dart
testWidgets('old key does not show Continue', (tester) async {
  SharedPreferences.setMockInitialValues({'horologium.mining.save': '{}'});
  await tester.pumpWidget(const HorologiumApp());
  await tester.pumpAndSettle();
  expect(find.text('START MINING'), findsOneWidget);
});

testWidgets('new key shows Continue', (tester) async {
  SharedPreferences.setMockInitialValues({MiningSaveRepository.saveKey: '{}'});
  await tester.pumpWidget(const HorologiumApp());
  await tester.pumpAndSettle();
  expect(find.text('CONTINUE MINING'), findsOneWidget);
});
```

- [ ] **Step 2: Write failing shell ownership/lifecycle tests**

Expose read-only test handles:

```dart
abstract class MiningShellHandles implements State<MiningShell> {
  MiningController get controller;
  AudioManager get audioManager;
}
```

Assert one controller/audio survives Site Deck -> Mine Site -> rotation -> Stellar Map; initialization order; first-gesture BGM; pause checkpoint/timer stop; resume accrual/offline sheet; invalid-new-save recovery; busy disables callbacks; selection is cleared only when invalid after a settled action.

- [ ] **Step 3: Write a failing fresh player-flow test**

```dart
testWidgets('fresh shell merges, enters site, and deploys', (tester) async {
  final harness = await pumpMiningShell(tester);
  await tester.tap(find.byKey(const Key('fleet-bay-0')));
  await tester.tap(find.byKey(const Key('fleet-bay-1')));
  await harness.settle(tester);
  await tester.tap(find.byKey(const Key('site-card-action-landingBasin')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('fleet-bay-1')));
  await tester.tap(find.byKey(const Key('mine-node-n1')));
  await harness.settle(tester);
  expect(find.bySemanticsLabel(RegExp('T2 rig')), findsOneWidget);
});
```

- [ ] **Step 4: Run and verify cutover is missing**

```sh
flutter test test/main_menu_test.dart \
  test/mining/presentation/mining_shell_test.dart
```

Expected: FAIL.

- [ ] **Step 5: Implement MiningShell ownership**

```dart
class MiningShell extends StatefulWidget {
  const MiningShell({
    super.key,
    this.content,
    this.repository,
    this.nowUtc,
    this.audioManager,
    this.visuals,
  });
  final MiningContentRegistry? content;
  final MiningSaveRepository? repository;
  final DateTime Function()? nowUtc;
  final AudioManager? audioManager;
  final MiningVisualCatalog? visuals;
}
```

State owns controller/audio/visuals/display save/timer/primary surface/open site/selected bay/feedback/initialized. Derive all child views in one `_refreshPresentation()`. Child widgets never receive controller references.

- [ ] **Step 6: Implement shell orchestration**

Add handlers for bay select-or-merge, spawn, unlock site, node deploy-or-recall, sell, site entry/back, navigation, technology purchase, planet unlock/travel, settings, checkpoint/resume, and generic typed action settlement. After success refresh, clear invalid selection, set feedback/haptic, and show concise snackbar.

- [ ] **Step 7: Retarget secondary surfaces**

Technology consumes replacement projections and commissioned-site copy. Settings keeps the same `AudioManager` and preference keys while using new theme. Offline Return consumes `fullSites`, shows hero art, and preserves per-planet/resource/cap/storage warning/next action.

- [ ] **Step 8: Change Main Menu and app theme**

Route Start/Continue to `const MiningShell()`, import only the new repository, and remove undeclared `fontFamily: 'Orbitron'`.

- [ ] **Step 9: Delete old presentation files/tests**

Delete exact retired screen/action/status/map/sheet-view files. Keep old flat domain/world temporarily until final cleanup so intermediate full-suite commits remain green.

- [ ] **Step 10: Run shell/menu/secondary tests**

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

Expected: PASS.

- [ ] **Step 11: Commit**

```sh
git add -A
git commit -m "feat(mining): cut over to the mobile mining shell"
```

---

### Task 12: Replace the Integration Journey and Tune the Three-Planet Economy

**Files:**
- Create: `test/integration/merge_mining_journey_test.dart`
- Create: `test/support/merge_mining_journey_harness.dart`
- Delete: `test/integration/mining_mvp_journey_test.dart`
- Add after observed pass: `docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md`
- Modify content/tests only when evidence requires tuning

**Interfaces:**
- Consumes: final routed domain/shell.
- Produces: deterministic fresh-to-Mars proof and recorded balance/device gate.

- [ ] **Step 1: Implement a public-action-only journey harness**

```dart
final class MergeMiningJourneyHarness {
  MergeMiningJourneyHarness({required DateTime startUtc});
  MiningSave get state => controller.state;
  Future<void> initialize();
  Future<void> merge(int sourceBay, int targetBay);
  Future<void> deploy(
    MiningSiteId siteId,
    MiningNodeId nodeId, {
    required int bay,
  });
  Future<void> accrueAndSell(Duration elapsed);
  Future<void> unlockAndCommission(MiningSiteId siteId);
  Future<void> raiseSurveyingTo(int target);
  Future<void> unlockPlanet(MiningPlanetId planetId);
  Future<void> commissionLunarFrontier();
  Future<void> commissionMarsFrontier();
  Future<void> reload();
  bool isMastered(MiningPlanetId planetId);
}
```

Helpers may advance the injected clock and choose public spawn/merge/deploy/sell order. They must not edit controller/repository state directly after initialization.

- [ ] **Step 2: Write the fresh journey**

```dart
test('fresh save reaches Mars mastery through merge-mining', () async {
  final journey = MergeMiningJourneyHarness(
    startUtc: DateTime.utc(2026, 8, 26, 12),
  );
  await journey.initialize();
  await journey.merge(0, 1);
  await journey.deploy(MiningSiteId.landingBasin, MiningNodeId.n1, bay: 1);
  await journey.accrueAndSell(const Duration(minutes: 10));
  await journey.unlockAndCommission(MiningSiteId.carbonRidge);
  await journey.unlockAndCommission(MiningSiteId.graniteCrater);
  await journey.raiseSurveyingTo(3);
  await journey.unlockPlanet(MiningPlanetId.lunarFrontier);
  await journey.commissionLunarFrontier();
  await journey.raiseSurveyingTo(5);
  await journey.unlockPlanet(MiningPlanetId.marsFrontier);
  await journey.commissionMarsFrontier();
  expect(journey.isMastered(MiningPlanetId.marsFrontier), isTrue);
  expect(journey.marsMasteryRewardCount, 1);
});
```

- [ ] **Step 3: Add inactive-planet and reload proof**

Leave Homeworld rigs deployed, travel to Lunar, advance time, assert Homeworld cargo grows, recreate controller from saved repository, and assert active planet, docks, nodes, commissions, cargo, technology, unlocks, and offline summary survive.

- [ ] **Step 4: Run journey without fixture cheats**

Run: `flutter test test/integration/merge_mining_journey_test.dart`

Expected: PASS or a concrete affordability/repetition failure using authored values. Do not bypass with state edits.

- [ ] **Step 5: Perform representative mobile playtest and write observed evidence**

After the pass, create the playtest document with actual commit/device or simulator, four target sizes, text scale, reduced motion, muted audio, all three planets, sell/return-cycle counts, and a Keep-or-change balance decision. Commit no blank template or placeholder fields.

- [ ] **Step 6: Tune only authorized authored numbers when evidence requires**

Allowed: spawn costs, site unlock costs, site rate/capacity/sale value, current technology costs/modifiers. Record before/after evidence and update exact content tests. Add no mechanic.

- [ ] **Step 7: Run journey and replacement suites**

```sh
flutter test test/integration/merge_mining_journey_test.dart
flutter test test/mining/domain test/mining/views test/mining/presentation
```

Expected: PASS.

- [ ] **Step 8: Commit**

```sh
git add test/integration test/support/merge_mining_journey_harness.dart \
  docs/playtests lib/mining/domain/mining_content.dart \
  test/mining/domain/mining_content_test.dart
git commit -m "test(mining): validate three-planet merge journey"
```

---

### Task 13: Retire the Old Runtime, Dependencies, and Guidance

**Files:**
- Delete: old flat `lib/mining/mining_*.dart`, `lib/mining/world/**`, corresponding tests
- Delete after closure proof: mining-only `lib/game/terrain/**`, tests, and terrain assets
- Modify: `lib/constants/assets_path.dart`, `pubspec.yaml`, `pubspec.lock`, `README.md`, `CLAUDE.md`

**Interfaces:**
- Consumes: fully routed replacement and green integration journey.
- Produces: one authoritative architecture with no compatibility stack.

- [ ] **Step 1: Prove no replacement import uses retired code**

```sh
rg "package:horologium/mining/(mining_|world/)" lib test
rg "MiningGame|MiningSectorComponent|ParallaxTerrain" lib test
rg "package:flame" lib test
```

Expected: matches only exact retired files/tests and terrain closure. Fix any replacement import first.

- [ ] **Step 2: Delete old flat domain/world/tests**

Remove old content/state/simulation/repository/controller/progression views, world components, and matching tests. Leave no exports, typedefs, flags, or shims.

- [ ] **Step 3: Delete mining-only terrain closure**

Search every file under `lib/game/terrain/`, `test/game/terrain/`, and `assets/images/terrain/`; delete the closure only after no new consumer remains.

- [ ] **Step 4: Remove unused constants/assets and Flame**

```sh
rg "Assets\." lib test
rg "assets/images/(building|terrain|resource)" lib test pubspec.yaml
```

Remove only zero-consumer declarations/directories. Keep audio and `ResourceType`. Delete `flame: ^1.30.0`, run `flutter pub get`, and verify lockfile no longer contains Flame.

- [ ] **Step 5: Update active documentation**

README describes Site Deck -> spawn/merge -> deploy/recall -> deterministic cargo -> sell -> Technology/Stellar Map. CLAUDE documents `MainMenu -> MiningShell -> controller -> simulation/repository -> Flutter surfaces`, new key, nested planet/site/node state, planet-local docks, commissioned mastery, projections, asset paths, and new tests. Remove active guidance that makes Flame/terrain/flat sectors authoritative.

- [ ] **Step 6: Run final legacy greps**

```sh
rg "horologium\.mining\.save|MiningGame|MiningSectorId|MineState|SectorProgress|package:flame|ParallaxTerrain" \
  lib test README.md CLAUDE.md pubspec.yaml
```

Expected: no active runtime reference. Historical planning docs are excluded.

- [ ] **Step 7: Run formatting, analysis, tests, and builds**

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Where Xcode is available: `flutter build ios --simulator --debug`.

- [ ] **Step 8: Verify final visual/device matrix**

Confirm the playtest records 360x640, 402x874, 430x932, 874x402, text scale 1.3, reduced motion, muted audio, Homeworld/Lunar/Mars visuals, and Offline Return. Fix any issue in its owning widget and rerun the focused test.

- [ ] **Step 9: Commit cleanup**

```sh
git add -A
git commit -m "chore(mining): retire the Flame mining runtime"
```

- [ ] **Step 10: Verify one coherent branch/PR**

```sh
git diff --stat main...HEAD
git log --oneline main..HEAD
```

Expected: planning docs plus ordered implementation commits, no second architecture, no unrelated work, and one HPA-285 PR.

---

## Final PR Verification Checklist

- [ ] HPA-285 is the only active implementation ticket.
- [ ] This draft PR remains the single PR and targets `main`.
- [ ] Prototype ZIP is attached manually to HPA-285.
- [ ] Spec and plan match final interfaces after review revisions.
- [ ] Fresh-to-Mars and save/reload journeys pass.
- [ ] All nine site visual mappings resolve.
- [ ] Portrait/landscape/text-scale/reduced-motion/muted-audio gates are recorded.
- [ ] Old key is ignored, not migrated or deleted.
- [ ] Old flat domain, Flame world, terrain closure, and dependency are gone.
- [ ] README and CLAUDE describe final architecture.
- [ ] Formatting, analysis, tests, coverage, Chrome tests, APK, web, and available iOS build pass.
