# HPA-451 Hit-Synchronized Gold Mine Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one Landing Basin vertical slice where tier-specific mining robots visibly strike varied gold deposits and passive visible gold cargo/progress increases only on the synchronized contact update, while Sell/recall legality and monetary values always use authoritative cargo.

**Architecture:** Keep `MiningController`/`MiningSimulation` authoritative and unchanged. `MiningShell._displayState` remains authoritative; the shell adds only a transient `double _landingBasinVisibleCargo` plus `int _landingBasinImpactSequence`. `MineSiteView.from(...)` accepts an optional visible-cargo override that affects only `view.cargo`; Sell value, `canSell`, recall legality, disabled reasons, and every other interaction field remain authoritative. One node-local Flutter widget owns both robot and deposit motion so contact cannot drift.

**Tech Stack:** Flutter/Dart, existing `Timer.periodic` shell refresh, `AnimationController`, PNG assets, existing SharedPreferences mining repository, Flutter/pure-Dart tests, injected clocks/repositories.

**Spec:** `docs/superpowers/specs/2026-09-01-hpa-451-gold-mine-animation-design.md`

## Global Constraints

- Deliver HPA-451 through exactly one implementation PR.
- Animate only `MiningSiteId.landingBasin`; every non-gold site keeps its current presentation.
- Keep `MiningController`, `MiningSimulation`, `MiningSaveRepository`, save schema, rates, capacities, sale values, technology, planet progression, and offline caps unchanged.
- `MiningShell` remains the only foreground timer/presentation owner.
- `_displayState` always contains authoritative controller values; never clone a fake `MiningSave` to lag `storedAmount`.
- While Landing Basin is open, only `MineSiteView.cargo` / node progress may use `_landingBasinVisibleCargo`; interaction/value fields stay authoritative.
- UI/animation never grants resources and never calls a controller mutation from an animation callback.
- Cold-load/resume/exit may flush visible cargo without replaying impacts.
- Add no save field for animation/variants; `impactSequence` and visible cargo are transient only.
- Add five robot PNGs, four deterministic N1–N4 gold-deposit PNGs, and one hit-accent PNG under one Landing Basin asset directory.
- Do not add a generic resource visual registry, string resource IDs, randomized/persisted variants, sprite sheets, Rive, Lottie, Flame, physics, audio, haptics, event buses, or new state-management packages.
- Preserve existing Mine Site semantics, keys, disabled-reason behavior, tier badge, progress bar, tap targets, portrait/landscape placement, Sell geometry, and 667×375 occupied N3/N4 containment.
- `MediaQuery.disableAnimations` remains the reduced-motion source of truth.
- `AGENTS.md` follows `CLAUDE.md`; update only `CLAUDE.md`.

---

## Final File Map

Create:

```text
lib/mining/presentation/landing_basin_mining_node_visual.dart
assets/images/mining/landing_basin/robot_t1.png
assets/images/mining/landing_basin/robot_t2.png
assets/images/mining/landing_basin/robot_t3.png
assets/images/mining/landing_basin/robot_t4.png
assets/images/mining/landing_basin/robot_t5.png
assets/images/mining/landing_basin/deposit_n1.png
assets/images/mining/landing_basin/deposit_n2.png
assets/images/mining/landing_basin/deposit_n3.png
assets/images/mining/landing_basin/deposit_n4.png
assets/images/mining/landing_basin/impact.png
test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Modify:

```text
lib/mining/mine_site_view.dart
lib/mining/presentation/mining_visuals.dart
lib/mining/presentation/mining_shell.dart
lib/mining/presentation/mine_site_screen.dart
pubspec.yaml
test/mining/mine_site_view_test.dart
test/mining/presentation/mining_visuals_test.dart
test/mining/presentation/mining_shell_test.dart
test/mining/presentation/mine_site_screen_test.dart
test/mining/presentation/visual_parity_golden_test.dart
CLAUDE.md
```

Do not modify:

```text
lib/mining/mining_content.dart
lib/mining/mining_state.dart
lib/mining/mining_controller.dart
lib/mining/mining_simulation.dart
lib/mining/mining_save_repository.dart
```

---

### Task 1: Lock the Landing Basin Asset Contract and Add the Authored PNGs

**Files:**
- Create: `assets/images/mining/landing_basin/robot_t1.png`
- Create: `assets/images/mining/landing_basin/robot_t2.png`
- Create: `assets/images/mining/landing_basin/robot_t3.png`
- Create: `assets/images/mining/landing_basin/robot_t4.png`
- Create: `assets/images/mining/landing_basin/robot_t5.png`
- Create: `assets/images/mining/landing_basin/deposit_n1.png`
- Create: `assets/images/mining/landing_basin/deposit_n2.png`
- Create: `assets/images/mining/landing_basin/deposit_n3.png`
- Create: `assets/images/mining/landing_basin/deposit_n4.png`
- Create: `assets/images/mining/landing_basin/impact.png`
- Modify: `lib/mining/presentation/mining_visuals.dart`
- Modify: `pubspec.yaml`
- Modify: `test/mining/presentation/mining_visuals_test.dart`

**Interfaces:**
- Produces: `MiningVisuals.landingBasinRobotAsset(RigTier)`, `MiningVisuals.landingBasinDepositAsset(MiningNodeId)`, `MiningVisuals.landingBasinImpact`.
- Consumed by: `LandingBasinMiningNodeVisual` in Task 4.
- Preserves: `MiningVisuals.rigAsset(...)` and every existing site `nodeAsset` path for Fleet Dock/non-gold presentation.

- [ ] **Step 1: Write failing path-contract tests**

Add to `test/mining/presentation/mining_visuals_test.dart`:

```dart
test('maps every Landing Basin robot and deposit asset deterministically', () {
  for (final tier in RigTier.values) {
    expect(
      MiningVisuals.landingBasinRobotAsset(tier),
      'assets/images/mining/landing_basin/robot_${tier.name}.png',
    );
  }
  for (final nodeId in MiningNodeId.values) {
    expect(
      MiningVisuals.landingBasinDepositAsset(nodeId),
      'assets/images/mining/landing_basin/deposit_${nodeId.name}.png',
    );
  }
  expect(
    MiningVisuals.landingBasinImpact,
    'assets/images/mining/landing_basin/impact.png',
  );
});
```

Extend the existing host-only root-bundle test:

```dart
for (final tier in RigTier.values) {
  await rootBundle.load(MiningVisuals.landingBasinRobotAsset(tier));
}
for (final nodeId in MiningNodeId.values) {
  await rootBundle.load(MiningVisuals.landingBasinDepositAsset(nodeId));
}
await rootBundle.load(MiningVisuals.landingBasinImpact);
```

- [ ] **Step 2: Run the visual contract test and verify RED**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: FAIL because the Landing Basin helpers/constants do not exist.

- [ ] **Step 3: Add the narrow `MiningVisuals` mappings**

Append without changing `rigAsset(...)`:

```dart
static String landingBasinRobotAsset(RigTier tier) =>
    'assets/images/mining/landing_basin/robot_${tier.name}.png';

static String landingBasinDepositAsset(MiningNodeId nodeId) =>
    'assets/images/mining/landing_basin/deposit_${nodeId.name}.png';

static const landingBasinImpact =
    'assets/images/mining/landing_basin/impact.png';
```

- [ ] **Step 4: Register the one new asset directory**

Add under `flutter.assets` in `pubspec.yaml`:

```yaml
- assets/images/mining/landing_basin/
```

Keep existing `nodes/` and `rigs/` declarations.

- [ ] **Step 5: Author/generate the ten transparent PNGs**

Use 512×512 RGBA transparent canvases; keep each subject inside the central ~80% so existing fixed Flutter sizes remain safe.

Shared robot brief:

```text
Stylized mobile-game sci-fi mining robot, readable at small size, three-quarter side view, facing left toward a resource deposit, transparent background, hard-surface industrial design, dark steel body with warm work lights, clean silhouette, no text, no scenery, consistent camera and lighting across all tiers.
```

Tier additions:

```text
T1: compact two-track starter rig, one simple hydraulic pick/drill arm, exposed utility frame.
T2: reinforced chassis, larger arm linkage, added work light and protective plating.
T3: medium heavy rig, dual hydraulic joints, larger mining head, visible cooling/energy module.
T4: heavy multi-actuator rig, broad armored chassis, stronger mining head and auxiliary stabilizer.
T5: premium massive automated rig, dense reinforced tooling, largest mining head, advanced energy/tooling modules; strongest tier without relying on recolor alone.
```

Shared deposit brief:

```text
Stylized mobile-game gold-bearing rock deposit, three-quarter side view matching the mining robot camera, transparent background, dark volcanic/stone matrix with clearly exposed metallic gold veins/chunks, readable at small size, no text, no scenery, consistent lighting/material style across variants.
```

Variant additions:

```text
N1: squat rounded boulder cluster with one broad diagonal gold vein.
N2: taller split-rock silhouette with exposed gold in the central fracture.
N3: low wide layered rock shelf with several smaller gold seams.
N4: angular high-grade deposit with the largest visible gold chunks while keeping the same approximate footprint.
```

Impact brief:

```text
Small stylized mining impact burst for a mobile game: bright gold-white sparks, two or three tiny rock/gold chips, compact radial shape, transparent background, no smoke cloud, no text.
```

Review all ten files together. Reject a set if camera angle, lighting, ground line, robot facing direction, or deposit footprint changes enough to alter the existing node composition.

- [ ] **Step 6: Run the asset test and verify GREEN**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: PASS including host root-bundle loads.

- [ ] **Step 7: Commit the asset contract**

```sh
git add \
  assets/images/mining/landing_basin \
  lib/mining/presentation/mining_visuals.dart \
  pubspec.yaml \
  test/mining/presentation/mining_visuals_test.dart
git commit -m "feat(mining): add Landing Basin robot and gold assets"
```

---

### Task 2: Separate Visible Cargo From Authoritative Mine Site Interaction State

**Files:**
- Modify: `lib/mining/mine_site_view.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `test/mining/mine_site_view_test.dart`
- Modify: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Produces: optional `MineSiteView.from(..., double? visibleCargo)`, and top-level `projectLandingBasinVisibleCargo(...)`.
- Guarantees: `view.cargo` may be visual-only; Sell/revenue/recall/deploy fields remain authoritative.

- [ ] **Step 1: Add a failing view-model separation test**

Add to `test/mining/mine_site_view_test.dart`:

```dart
test('visible cargo override never changes sale or recall legality', () {
  final view = MineSiteView.from(
    state: stateWith(
      landing: progress(
        commissioned: true,
        storedAmount: 90.5,
        rigs: {
          MiningNodeId.n1: RigTier.t1,
          MiningNodeId.n2: RigTier.t1,
        },
      ),
    ),
    content: content,
    siteId: MiningSiteId.landingBasin,
    selectedBayId: null,
    isBusy: false,
    visibleCargo: 90,
  );

  expect(view.cargo, 90);
  expect(view.projectedSale, 362);
  expect(view.activePlanetCargo, 90.5);
  expect(view.activePlanetProjectedSale, 362);
  expect(view.canSell, isTrue);
  expect(view.node(MiningNodeId.n1).canRecall, isFalse);
  expect(
    view.node(MiningNodeId.n1).disabledReason,
    'Sell cargo before recalling this rig.',
  );
});
```

- [ ] **Step 2: Add pure failing tests for the visible-cargo truth table**

Add non-widget tests near the top of `mining_shell_test.dart`:

```dart
test('Landing Basin visible cargo holds only upward open-site deltas', () {
  expect(
    projectLandingBasinVisibleCargo(
      authoritativeCargo: .25,
      visibleCargo: 0,
      openSiteId: MiningSiteId.landingBasin,
      publishUpwardLandingCargo: false,
    ),
    0,
  );
  expect(
    projectLandingBasinVisibleCargo(
      authoritativeCargo: 0,
      visibleCargo: 10,
      openSiteId: MiningSiteId.landingBasin,
      publishUpwardLandingCargo: false,
    ),
    0,
  );
  expect(
    projectLandingBasinVisibleCargo(
      authoritativeCargo: .25,
      visibleCargo: 0,
      openSiteId: MiningSiteId.landingBasin,
      publishUpwardLandingCargo: true,
    ),
    .25,
  );
  expect(
    projectLandingBasinVisibleCargo(
      authoritativeCargo: .25,
      visibleCargo: 0,
      openSiteId: MiningSiteId.carbonRidge,
      publishUpwardLandingCargo: false,
    ),
    .25,
  );
  expect(
    projectLandingBasinVisibleCargo(
      authoritativeCargo: .25,
      visibleCargo: 0,
      openSiteId: null,
      publishUpwardLandingCargo: false,
    ),
    .25,
  );
});
```

- [ ] **Step 3: Run focused tests and verify RED**

```sh
flutter test test/mining/mine_site_view_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: FAIL because `visibleCargo` and `projectLandingBasinVisibleCargo` do not exist.

- [ ] **Step 4: Add the optional `MineSiteView` visual override**

Extend the factory signature:

```dart
static MineSiteView from({
  required MiningSave state,
  required MiningContentRegistry content,
  required MiningSiteId siteId,
  required DockBayId? selectedBayId,
  required bool isBusy,
  double? visibleCargo,
}) {
```

Immediately after resolving `progress`:

```dart
final displayedCargo = visibleCargo ?? progress.storedAmount;
```

Change only the return field:

```dart
cargo: displayedCargo,
```

Keep these calculations on authoritative `progress.storedAmount` / authoritative active-site progress exactly as they are now:

```text
projectedSale
activePlanetCargo
activePlanetProjectedSale
canSell
recallCapacity comparison
canRecall
disabledReason
```

- [ ] **Step 5: Add the pure top-level projection helper**

In `mining_shell.dart`, outside `_MiningShellState`, add:

```dart
@visibleForTesting
double projectLandingBasinVisibleCargo({
  required double authoritativeCargo,
  required double visibleCargo,
  required MiningSiteId? openSiteId,
  required bool publishUpwardLandingCargo,
}) {
  if (openSiteId != MiningSiteId.landingBasin ||
      publishUpwardLandingCargo) {
    return authoritativeCargo;
  }
  return authoritativeCargo < visibleCargo
      ? authoritativeCargo
      : visibleCargo;
}
```

Do not pass `MiningSave` into this helper.

- [ ] **Step 6: Run focused tests and verify GREEN**

```sh
flutter test test/mining/mine_site_view_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: the new unit tests PASS; existing shell behavior remains unchanged because wiring comes in Task 3.

- [ ] **Step 7: Commit the view/projection contract**

```sh
git add \
  lib/mining/mine_site_view.dart \
  lib/mining/presentation/mining_shell.dart \
  test/mining/mine_site_view_test.dart \
  test/mining/presentation/mining_shell_test.dart
git commit -m "refactor(mining): separate visible gold cargo from interactions"
```

---

### Task 3: Publish Landing Basin Impact Pulses and Wire All Flush Paths

**Files:**
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Produces: `_landingBasinVisibleCargo`, `_landingBasinImpactSequence`, `MineSiteScreen.impactSequence`.
- Consumes: Task 2 `MineSiteView.visibleCargo` and `projectLandingBasinVisibleCargo(...)`.
- Preserves: authoritative `_displayState`, controller/simulation/persistence behavior.

- [ ] **Step 1: Add a two-rig test seed for recall-boundary cases**

Add beside `deployedLandingState`:

```dart
MiningSave deployedLandingTwoRigState(DateTime now, {double cargo = 0}) {
  final base = MiningSave.initial(nowUtc: now);
  final landing = base.sites[MiningSiteId.landingBasin]!;
  return base.copyWith(
    sites: {
      ...base.sites,
      MiningSiteId.landingBasin: landing.copyWith(
        commissioned: true,
        storedAmount: cargo,
        rigByNode: {
          ...landing.rigByNode,
          MiningNodeId.n1: RigTier.t1,
          MiningNodeId.n2: RigTier.t1,
        },
      ),
    },
    docks: {
      ...base.docks,
      MiningPlanetId.homeworld: {
        ...base.docks[MiningPlanetId.homeworld]!,
        DockBayId.b1: null,
        DockBayId.b2: null,
      },
    },
  );
}
```

- [ ] **Step 2: Write the failing timer impact test**

Import `mine_site_screen.dart` in `mining_shell_test.dart`, then add:

```dart
testWidgets('Landing Basin timer publishes visible cargo and impact together', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingBasin(_start));
  final savesBeforeTicks = repository.saveCount;
  await pumpShell(tester, repository: repository, clock: clock);

  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();
  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence, 0);

  clock.now = _start.add(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));

  final screen = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  expect(screen.impactSequence, 1);
  expect(screen.view.cargo, 1);
  expect(repository.saveCount, savesBeforeTicks);
});
```

- [ ] **Step 3: Write the failing action-hold test**

```dart
testWidgets('action accrual stays visual-only held until the next impact', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingBasin(_start));
  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  clock.now = _start.add(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
  await tester.pump(const Duration(milliseconds: 300));

  final held = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  expect(
    shellHandles(tester).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
    closeTo(.25, .0001),
  );
  expect(held.view.cargo, 0);
  expect(held.impactSequence, 0);

  clock.now = _start.add(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 700));

  final impacted = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  expect(impacted.view.cargo, closeTo(.5, .0001));
  expect(impacted.impactSequence, 1);
});
```

- [ ] **Step 4: Write the failing sell-while-held consistency test**

```dart
testWidgets('sell while cargo is held shows and pays authoritative value', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingState(_start, cargo: 10));
  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  clock.now = _start.add(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
  await tester.pump(const Duration(milliseconds: 300));

  final held = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  expect(held.view.cargo, 10);
  expect(held.view.activePlanetProjectedSale, 41);
  expect(find.text('+41'), findsOneWidget);

  await tester.tap(find.byKey(const Key('mine-site-sell')));
  await tester.pump(const Duration(milliseconds: 300));

  expect(find.text('Sold 41 cash.'), findsOneWidget);
  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).view.cargo,
    0,
  );
  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence,
    0,
  );
});
```

- [ ] **Step 5: Write the failing recall-while-held legality test**

```dart
testWidgets('recall while cargo is held uses authoritative capacity legality', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingTwoRigState(_start, cargo: 90));
  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  clock.now = _start.add(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
  await tester.pump(const Duration(milliseconds: 300));

  final held = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  expect(held.view.cargo, 90);
  expect(
    shellHandles(tester).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
    closeTo(90.5, .0001),
  );
  expect(held.view.node(MiningNodeId.n1).canRecall, isFalse);
  expect(
    held.view.node(MiningNodeId.n1).disabledReason,
    'Sell cargo before recalling this rig.',
  );

  await tester.tap(find.byKey(const Key('mine-site-node-n1')));
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text('Sell cargo before recalling this rig.'), findsOneWidget);
});
```

- [ ] **Step 6: Write the failing successful-recall flush test**

```dart
testWidgets('successful recall flushes held cargo without an impact', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingTwoRigState(_start, cargo: 89));
  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  clock.now = _start.add(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).view.cargo, 89);

  await tester.tap(find.byKey(const Key('mine-site-node-n1')));
  await tester.pump(const Duration(milliseconds: 300));

  final screen = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  expect(screen.view.cargo, closeTo(89.5, .0001));
  expect(screen.impactSequence, 0);
});
```

- [ ] **Step 7: Write failing Back and Stellar Map flush tests**

Back path:

```dart
testWidgets('Back flushes held Landing Basin cargo without an impact', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingBasin(_start));
  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  clock.now = _start.add(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).view.cargo, 0);

  await tester.tap(find.byKey(const Key('mine-site-back')));
  await tester.pump();
  final gauge = tester.widget<MiningCargoGauge>(
    find.byKey(const Key('mining-cargo-gauge')),
  );
  expect(gauge.cargo, closeTo(.25, .0001));
});
```

Stellar Map path:

```dart
testWidgets('Stellar Map navigation flushes held cargo without a strike', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingBasin(_start));
  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  clock.now = _start.add(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('fleet-dock-spawn')));
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).view.cargo, 0);

  await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
  await tester.pump();
  expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
  expect(
    tester.widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge'))).cargo,
    closeTo(.25, .0001),
  );

  await tester.tap(find.byKey(const Key('mining-nav-siteDeck')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();
  final reentered = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  expect(reentered.view.cargo, closeTo(.25, .0001));
  expect(reentered.impactSequence, 0);
});
```

- [ ] **Step 8: Run shell tests and verify RED**

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: FAIL because the shell has no visible overlay/impact sequence wiring and `MineSiteScreen` has no `impactSequence`.

- [ ] **Step 9: Add the shell-local overlay/sequence and authoritative refresh**

In `_MiningShellState` add:

```dart
double _landingBasinVisibleCargo = 0;
int _landingBasinImpactSequence = 0;
```

Replace the current presentation copy with:

```dart
void _refreshPresentation({
  bool publishUpwardLandingCargo = false,
}) {
  if (!_initialized) return;
  final authoritative = _controller.state;
  _displayState = authoritative;
  _landingBasinVisibleCargo = projectLandingBasinVisibleCargo(
    authoritativeCargo:
        authoritative.sites[MiningSiteId.landingBasin]!.storedAmount,
    visibleCargo: _landingBasinVisibleCargo,
    openSiteId: _openSiteId,
    publishUpwardLandingCargo: publishUpwardLandingCargo,
  );
  _reducedMotion =
      MediaQuery.maybeOf(context)?.disableAnimations ?? _reducedMotion;
  if (mounted) setState(() {});
}
```

- [ ] **Step 10: Replace the timer body with one impact publication method**

```dart
void _refreshForegroundProduction() {
  if (_controller.isBusy) return;

  final visibleCargo = _landingBasinVisibleCargo;
  _controller.refresh();
  final landing = _controller.state.sites[MiningSiteId.landingBasin]!;
  final hasRig = landing.rigByNode.values.any((tier) => tier != null);
  final publishImpact =
      _openSiteId == MiningSiteId.landingBasin &&
      hasRig &&
      landing.storedAmount > visibleCargo;

  if (publishImpact) {
    _landingBasinImpactSequence++;
  }
  _refreshPresentation(
    publishUpwardLandingCargo: publishImpact,
  );
}

void _startRefreshTimer() {
  _refreshTimer?.cancel();
  _refreshTimer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => _refreshForegroundProduction(),
  );
}
```

No second timer is added.

- [ ] **Step 11: Flush explicitly on recall/resume/exit; hold other mutations**

Extend `_runSheetAction` with:

```dart
bool syncLandingBasinCargoOnSuccess = false,
```

After a successful operation, call:

```dart
_refreshPresentation(
  publishUpwardLandingCargo:
      result.isSuccess && syncLandingBasinCargoOnSuccess,
);
```

Change only the recall call site to:

```dart
_runSheetAction(
  () => _controller.recallRig(siteId, nodeId),
  successMessage: 'Rig recalled.',
  syncLandingBasinCargoOnSuccess: true,
);
```

Spawn/deploy/technology/unlock/etc. retain the default `false`.

Sale needs no special economy branch: after authoritative cargo becomes 0, the pure helper publishes the decrease immediately. Calling `_refreshPresentation()` remains sufficient.

For resume:

```dart
_refreshPresentation(publishUpwardLandingCargo: true);
```

Do not increment the sequence.

For `_leaveSite()` use one refresh-driven setState:

```dart
void _leaveSite() {
  if (!mounted) return;
  _openSiteId = null;
  _refreshPresentation(publishUpwardLandingCargo: true);
}
```

For `_showPrimarySurface(...)`:

```dart
void _showPrimarySurface(MiningNavigationDestination destination) {
  if (!_initialized) return;
  _selectedDestination = destination;
  _openSiteId = null;
  _refreshPresentation(publishUpwardLandingCargo: true);
}
```

On `_enterSite`, synchronize Landing Basin before opening without an impact:

```dart
if (id == MiningSiteId.landingBasin) {
  _landingBasinVisibleCargo =
      _controller.state.sites[id]!.storedAmount;
}
setState(() => _openSiteId = id);
```

Initialization already has `_openSiteId == null`, so the first `_refreshPresentation()` synchronizes the overlay automatically.

- [ ] **Step 12: Add `impactSequence` to `MineSiteScreen` and supply authoritative view + visual override**

Add:

```dart
this.impactSequence = 0,
...
final int impactSequence;
```

In `MiningShell.build`, construct the Mine Site view with:

```dart
final mineSite = MineSiteView.from(
  state: _displayState,
  content: _content,
  siteId: siteId,
  selectedBayId: _selectedBayId,
  isBusy: _controller.isBusy,
  visibleCargo: siteId == MiningSiteId.landingBasin
      ? _landingBasinVisibleCargo
      : null,
);
```

Pass:

```dart
impactSequence: siteId == MiningSiteId.landingBasin
    ? _landingBasinImpactSequence
    : 0,
```

Do not put visible cargo or sequence into `MiningSave` or `MiningController`.

- [ ] **Step 13: Run shell/view tests and verify GREEN**

```sh
flutter test test/mining/mine_site_view_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: PASS including existing `timer refresh accrues cargo without persisting`.

- [ ] **Step 14: Commit the shell publication contract**

```sh
git add \
  lib/mining/presentation/mining_shell.dart \
  lib/mining/presentation/mine_site_screen.dart \
  test/mining/presentation/mining_shell_test.dart
git commit -m "feat(mining): publish Landing Basin cargo on impact pulses"
```

---

### Task 4: Build One Node-Local Robot + Gold Hit Animation Component

**Files:**
- Create: `lib/mining/presentation/landing_basin_mining_node_visual.dart`
- Create: `test/mining/presentation/landing_basin_mining_node_visual_test.dart`

**Interfaces:**
- Consumes: Task 1 `MiningVisuals` helpers, `MiningNodeId`, `RigTier`.
- Produces:

```dart
LandingBasinMiningNodeVisual({
  required MiningNodeId nodeId,
  required RigTier? rig,
  required double nodeSize,
  required double rigSize,
  required int impactSequence,
  required bool reducedMotion,
})
```

- Owns: exactly one `AnimationController`; no timer/controller/economy dependency.

- [ ] **Step 1: Write resting/asset-selection tests first**

Pump `nodeId: n2`, `rig: t3` and assert:

```dart
expect(find.byKey(const Key('landing-basin-deposit-n2')), findsOneWidget);
expect(find.byKey(const Key('landing-basin-robot-n2')), findsOneWidget);

final deposit = tester.widget<Image>(
  find.descendant(
    of: find.byKey(const Key('landing-basin-deposit-n2')),
    matching: find.byType(Image),
  ),
);
final robot = tester.widget<Image>(
  find.descendant(
    of: find.byKey(const Key('landing-basin-robot-n2')),
    matching: find.byType(Image),
  ),
);
expect(
  (deposit.image as AssetImage).assetName,
  MiningVisuals.landingBasinDepositAsset(MiningNodeId.n2),
);
expect(
  (robot.image as AssetImage).assetName,
  MiningVisuals.landingBasinRobotAsset(RigTier.t3),
);
```

Pump `rig: null`; deposit exists, robot/impact keys do not.

- [ ] **Step 2: Write failing sequence/reduced-motion tests**

Start `impactSequence: 0`, record keyed robot/deposit transform matrices, rebuild with `impactSequence: 1`, then:

```dart
expect(find.byKey(const Key('landing-basin-impact-n2')), findsOneWidget);
await tester.pump(const Duration(milliseconds: 100));
expect(
  tester.widget<Transform>(find.byKey(const Key('landing-basin-robot-n2'))).transform,
  isNot(equals(restRobotMatrix)),
);
await tester.pump(const Duration(milliseconds: 900));
expect(find.byKey(const Key('landing-basin-impact-n2')), findsNothing);
```

Rebuild again with sequence `1`: no restart. Rebuild `1 -> 4`: one strike only. With `reducedMotion: true`, robot/deposit transform matrices remain unchanged while the brief impact accent may appear.

- [ ] **Step 3: Run the new widget test and verify RED**

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: FAIL because the widget does not exist.

- [ ] **Step 4: Implement one public stateful widget and stable keys**

```dart
class LandingBasinMiningNodeVisual extends StatefulWidget {
  const LandingBasinMiningNodeVisual({
    super.key,
    required this.nodeId,
    required this.rig,
    required this.nodeSize,
    required this.rigSize,
    required this.impactSequence,
    required this.reducedMotion,
  });

  final MiningNodeId nodeId;
  final RigTier? rig;
  final double nodeSize;
  final double rigSize;
  final int impactSequence;
  final bool reducedMotion;

  @override
  State<LandingBasinMiningNodeVisual> createState() =>
      _LandingBasinMiningNodeVisualState();
}
```

Stable keyed transform/effect roots:

```dart
Key('landing-basin-deposit-${widget.nodeId.name}')
Key('landing-basin-robot-${widget.nodeId.name}')
Key('landing-basin-impact-${widget.nodeId.name}')
```

Initialize the one-second controller at `value: 1` for a deterministic resting pose.

- [ ] **Step 5: Restart only on a new sequence with a rig**

```dart
@override
void didUpdateWidget(LandingBasinMiningNodeVisual oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.rig == null) {
    _controller.stop();
    _controller.value = 1;
    return;
  }
  if (widget.impactSequence != oldWidget.impactSequence) {
    _controller.forward(from: 0);
  }
}
```

- [ ] **Step 6: Implement one shared phase function**

Use these phase points:

```text
robot dx:
  0.00 -> 0
  0.14 -> +12% rigSize
  0.70 -> +8% rigSize
  1.00 -> 0

deposit scale:
  0.00 -> 0.94
  0.14 -> 1.00
  >=0.14 -> 1.00
impact opacity:
  0.00 -> 1.00
  0.18 -> 0.00
  >=0.18 -> 0.00
```

Reduced motion:

```dart
robotDx = 0;
depositScale = 1;
```

- [ ] **Step 7: Copy current deposit/robot/tier-badge geometry exactly**

The component replaces only the existing visual `Row`:

```text
Row(crossAxisAlignment: end)
  deposit(nodeSize)
  if rig != null:
    2 px gap
    Column
      robot(rigSize)
      3 px gap
      existing TIER badge styling
```

Use child transforms only; never animate width/height/padding/margin/Row size/Column size. With `rig == null`, use the current `.62` deposit opacity.

- [ ] **Step 8: Dispose and verify GREEN**

```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

Run:

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: PASS with no ticker exception.

- [ ] **Step 9: Commit the component**

```sh
git add \
  lib/mining/presentation/landing_basin_mining_node_visual.dart \
  test/mining/presentation/landing_basin_mining_node_visual_test.dart
git commit -m "feat(mining): animate Landing Basin robot impacts"
```

---

### Task 5: Integrate the Animated Gold Row Without Moving Mine Site Geometry

**Files:**
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `test/mining/presentation/mine_site_screen_test.dart`
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Potential intentional golden updates: `test/mining/presentation/goldens/mine_site_430x932.png`, `test/mining/presentation/goldens/mine_site_874x402.png`

**Interfaces:**
- Consumes: `MineSiteScreen.impactSequence`, Task 4 `LandingBasinMiningNodeVisual`.
- Produces: Landing Basin-only visual branch; all other sites retain current rendering.

- [ ] **Step 1: Extend `_pumpMineSite` and add failing Landing/non-gold assertions**

Add:

```dart
int impactSequence = 0,
```

and pass it to `MineSiteScreen`.

For Landing Basin T1 on N1:

```dart
expect(find.byKey(const Key('landing-basin-deposit-n1')), findsOneWidget);
expect(find.byKey(const Key('landing-basin-robot-n1')), findsOneWidget);
expect(find.byKey(const Key('mine-site-node-n1')), findsOneWidget);
```

For empty N2, deposit exists and robot does not.

Construct a Carbon Ridge `MineSiteView`; assert no `landing-basin-*` keys and verify the existing node/rig asset paths remain.

- [ ] **Step 2: Add failing synchronized-contact screen coverage**

Pump Landing Basin cargo `0`, sequence `0`; repump cargo `.5`, sequence `1`:

```dart
expect(find.byKey(const Key('landing-basin-impact-n1')), findsOneWidget);
final progress = tester.widget<FractionallySizedBox>(
  find.descendant(
    of: find.byKey(const Key('mine-site-node-n1')),
    matching: find.byType(FractionallySizedBox),
  ).last,
);
expect(
  progress.widthFactor,
  closeTo(.5 / _siteView(nextState).capacity, .0001),
);
```

- [ ] **Step 3: Run Mine Site tests and verify RED**

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart
```

Expected: FAIL because `_MineNodeButton` still renders shared images.

- [ ] **Step 4: Thread `impactSequence` exactly like `reducedMotion`**

Pass required `int impactSequence` through:

```text
_PortraitMineSite
_LandscapeMineSite
_CavernScene
_MineCavern
_MineNodeButton
```

Also pass `view.siteId` to `_MineNodeButton`.

- [ ] **Step 5: Replace only the Landing Basin unlocked visual Row**

Inside `_MineNodeButton`:

```dart
final isLandingBasin = siteId == MiningSiteId.landingBasin;
```

For unlocked Landing Basin nodes:

```dart
LandingBasinMiningNodeVisual(
  nodeId: view.id,
  rig: view.rig,
  nodeSize: nodeSize,
  rigSize: rigSize,
  impactSequence: impactSequence,
  reducedMotion: reducedMotion,
)
```

For unlocked non-gold nodes keep the existing `Image.asset(nodeAsset)` + `MiningVisuals.rigAsset(view.rig!)` Row. Locked nodes keep `_LockedNode`.

Do not restyle tier badges or chrome; the new component copies the current 2 px robot gap and 3 px badge gap exactly.

- [ ] **Step 6: Preserve the outer interaction/progress structure**

Do not move/replace:

```text
Semantics
  -> Material
    -> InkWell(key: mine-site-node-*)
      -> locked OR Column(
           node visual Row/component,
           6 px gap,
           progress bar,
         )
```

- [ ] **Step 7: Run geometry regressions before goldens**

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart
```

Expected: PASS without relaxing current coordinate/tolerance assertions, including 667×375 occupied N3/N4 and Sell/N3 non-overlap.

- [ ] **Step 8: Verify/update only Mine Site goldens on Linux**

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

If Linux failures show only intended Landing Basin art with unchanged geometry:

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart --update-goldens
```

Mine Site goldens are skipped on macOS; do not manufacture replacements there. Keep direct fixtures at `impactSequence: 0` and `reducedMotion: true`.

- [ ] **Step 9: Commit Mine Site integration**

```sh
git add \
  lib/mining/presentation/mine_site_screen.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/visual_parity_golden_test.dart
git add -u test/mining/presentation/goldens
git commit -m "feat(mining): integrate hit-synchronized Landing Basin visuals"
```

---

### Task 6: Pin Full/Resume/Reduced-Motion Regressions and Repository Guidance

**Files:**
- Modify: `test/mining/presentation/mining_shell_test.dart`
- Modify: `test/mining/presentation/landing_basin_mining_node_visual_test.dart`
- Modify: `CLAUDE.md`

**Interfaces:**
- Verifies: full HPA-451 contract.
- Changes no economy/save interface.

- [ ] **Step 1: Add final-fill and already-full tests**

```dart
testWidgets('final Landing Basin fill impacts once and then stops', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingState(_start, cargo: 89.75));
  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  clock.now = _start.add(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence, 1);
  expect(
    shellHandles(tester).controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
    90,
  );

  clock.now = _start.add(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 1));
  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence, 1);
});
```

Also seed `cargo: 90`, enter, advance one second, and assert sequence remains `0`.

- [ ] **Step 2: Add lifecycle-resume no-replay test**

Use injected time only:

```dart
final before = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence;
await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
clock.now = _start.add(const Duration(seconds: 10));
await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
await tester.pump();
await tester.pump();
final after = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence;
expect(after, before);
expect(
  tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).view.cargo,
  greaterThan(0),
);
```

- [ ] **Step 3: Finish reduced-motion/disposal assertions**

In the component test, capture keyed robot/deposit matrices at sequence `0`, rebuild to `1`, pump 100 ms, assert both matrices unchanged, impact accent present, then remove the widget tree and assert `tester.takeException()` is null.

- [ ] **Step 4: Run the complete focused slice**

```sh
flutter test test/mining/mine_site_view_test.dart
flutter test test/mining/presentation/mining_visuals_test.dart
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: PASS on the current platform; macOS retains the existing Mine Site golden skip.

- [ ] **Step 5: Update `CLAUDE.md` with the final ownership contract**

Add under economy/presentation guidance:

```markdown
- Landing Basin is the first authored animated resource-site slice. Robot/deposit impacts present deterministic elapsed-time production; they are not an economy clock.
- `MiningShell._displayState` remains authoritative. The shell may hold only a transient Landing Basin visible-cargo overlay for Mine Site gauge/progress until the next eligible impact; Sell value/legality and recall legality always use authoritative cargo through `MineSiteView`.
- `MiningShell` owns the transient Landing Basin impact sequence. Animation widgets never call `MiningController`, write the repository, or persist animation/variant state.
- Cold-load/resume/exit paths may flush visible cargo directly and never replay historical strikes.
- Add another resource/site visual variant only when a concrete second site needs one; do not pre-build a generic resource visual registry.
```

Do not edit `AGENTS.md` separately.

- [ ] **Step 6: Run format/analyze**

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: PASS.

- [ ] **Step 7: Run full repository gates**

```sh
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Expected: PASS; existing host-only Chrome asset-test behavior remains unchanged.

- [ ] **Step 8: Prove no prohibited domain/save scope entered the PR**

```sh
git diff main...HEAD -- \
  lib/mining/mining_content.dart \
  lib/mining/mining_state.dart \
  lib/mining/mining_controller.dart \
  lib/mining/mining_simulation.dart \
  lib/mining/mining_save_repository.dart
```

Expected: no diff.

- [ ] **Step 9: Commit final verification/guidance**

```sh
git add \
  CLAUDE.md \
  test/mining/presentation/mining_shell_test.dart \
  test/mining/presentation/landing_basin_mining_node_visual_test.dart
git commit -m "test(mining): verify Landing Basin impact presentation"
```

- [ ] **Step 10: Final PR readiness check**

```sh
git status --short
git log --oneline main..HEAD
```

Expected: clean tree and one HPA-451 PR containing assets, view/pulse separation, animation, integration, tests, and guidance.

---

## Risks and Mitigations

### Display / interaction desynchronization

**Risk:** visible cargo intentionally lags authoritative cargo.

**Mitigation:** `_displayState` stays authoritative; `MineSiteView.visibleCargo` changes only `view.cargo`. Explicit view/shell tests cover Sell and recall while held.

### Linux-only Mine Site goldens

**Risk:** art changes require Linux golden updates while macOS skips those cases.

**Mitigation:** deterministic resting fixtures; update only the two Mine Site goldens on Linux after geometry tests pass.

### Ten new PNGs may disturb visual footprint

**Risk:** inconsistent subject bounds/camera/lighting can visually overflow fixed node composition.

**Mitigation:** 512×512 transparent canvases, central ~80% subject bounds, consistent camera/facing/lighting, similar deposit footprints, and existing 402×874 / 667×375 geometry gates.

### Shell timer alignment in widget tests

**Risk:** `pumpShell` advances fake time during initialization, so exact timer timing can be brittle.

**Mitigation:** pure projection tests own the hold/decrease/flush truth table; shell tests cover only concrete timer/action/navigation wiring.

---

## Spec Coverage Self-Review

- Landing Basin-only slice: Tasks 1/5.
- Five robot tiers, four deposits, hit accent: Task 1.
- Authoritative economy/save untouched: Global Constraints + Task 6 diff guard.
- Visible cargo separated from interaction state: Task 2.
- Pure hold/decrease/flush function: Task 2.
- Sell-while-held consistency: Task 3.
- Recall-while-held legality + successful recall flush: Task 3.
- Back + Stellar Map flush without impact: Task 3.
- One shell timer/impact sequence: Task 3.
- One robot/deposit animation owner: Task 4.
- Existing geometry/chrome preserved: Task 5.
- Full/full-stop, resume, reduced motion: Task 6.
- Risks explicitly covered: Risks and Mitigations.
- Full repository verification: Task 6.

No additional subsystem, Linear ticket, or pull request is required for HPA-451.