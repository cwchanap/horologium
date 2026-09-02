# HPA-451 Hit-Synchronized Gold Mine Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one Landing Basin vertical slice where tier-specific mining robots visibly strike varied gold deposits and passive visible gold cargo/progress increases only on the synchronized contact update.

**Architecture:** Keep `MiningController`/`MiningSimulation` authoritative and unchanged. `MiningShell` adds one transient Landing Basin impact sequence and a presentation-only gate that holds upward Landing Basin cargo while the site is open until the next eligible one-second refresh. One node-local Flutter widget owns both robot and deposit motion so the contact frame cannot drift.

**Tech Stack:** Flutter/Dart, existing `Timer.periodic` shell refresh, `AnimationController`, PNG assets, SharedPreferences-backed existing mining repository, Flutter widget tests, injected clocks/repositories.

**Spec:** `docs/superpowers/specs/2026-09-01-hpa-451-gold-mine-animation-design.md`

## Global Constraints

- Deliver HPA-451 through exactly one implementation PR.
- Animate only `MiningSiteId.landingBasin`; every non-gold site keeps its current presentation.
- Keep `MiningController`, `MiningSimulation`, `MiningSaveRepository`, save schema, rates, capacities, sale values, technology, planet progression, and offline caps unchanged.
- `MiningShell` remains the only foreground timer and presentation-state owner.
- UI/animation never grants resources and never calls a controller mutation from an animation callback.
- While Landing Basin is open, non-impact presentation refreshes must not expose an upward Landing Basin `storedAmount`; decreases and all non-production state changes remain immediate.
- Cold-load/resume may publish authoritative production immediately without replaying impacts.
- Add no save field for animation/variants; `impactSequence` is transient only.
- Add five robot PNGs, four deterministic N1–N4 gold-deposit PNGs, and one hit-accent PNG under one Landing Basin asset directory.
- Do not add a generic resource visual registry, string resource IDs, randomized/persisted variants, sprite sheets, Rive, Lottie, Flame, physics, audio, haptics, or new state-management packages.
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
lib/mining/presentation/mining_visuals.dart
lib/mining/presentation/mining_shell.dart
lib/mining/presentation/mine_site_screen.dart
pubspec.yaml
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
- Consumed later by: `LandingBasinMiningNodeVisual` in Task 3.
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

Extend the existing host-only root-bundle test with:

```dart
for (final tier in RigTier.values) {
  await rootBundle.load(MiningVisuals.landingBasinRobotAsset(tier));
}
for (final nodeId in MiningNodeId.values) {
  await rootBundle.load(MiningVisuals.landingBasinDepositAsset(nodeId));
}
await rootBundle.load(MiningVisuals.landingBasinImpact);
```

- [ ] **Step 2: Run the visual contract tests and verify RED**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: FAIL because the Landing Basin helpers/constants do not exist.

- [ ] **Step 3: Add the narrow `MiningVisuals` mappings**

Append to `MiningVisuals` without changing `rigAsset(...)`:

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

Do not remove or relocate the existing `nodes/` or `rigs/` declarations.

- [ ] **Step 5: Author/generate the ten transparent PNGs**

Use 512×512 RGBA source canvases with transparent backgrounds and keep each subject inside the central ~80%.

Shared robot prompt:

```text
Stylized mobile-game sci-fi mining robot, readable at small size, three-quarter side view, facing left toward a resource deposit, transparent background, hard-surface industrial design, dark steel body with warm work lights, clean silhouette, no text, no scenery, no floor shadow outside the transparent canvas, consistent camera and lighting across the full tier family.
```

Tier additions:

```text
T1: compact two-track starter rig, one simple hydraulic pick/drill arm, exposed utility frame.
T2: reinforced chassis, larger arm linkage, added work light and protective plating.
T3: medium heavy rig, dual hydraulic joints, larger mining head, visible cooling/energy module.
T4: heavy multi-actuator rig, broad armored chassis, stronger mining head and auxiliary stabilizer.
T5: premium massive automated rig, dense reinforced tooling, largest mining head, advanced energy/tooling modules; clearly the strongest tier without relying on recolor alone.
```

Shared deposit prompt:

```text
Stylized mobile-game gold-bearing rock deposit, three-quarter side view matching the mining robot camera, transparent background, dark volcanic/stone matrix with clearly exposed metallic gold veins and chunks, readable at small size, no text, no scenery, consistent lighting and material style across all four variants.
```

Variant additions:

```text
N1: squat rounded boulder cluster with one broad diagonal gold vein.
N2: taller split-rock silhouette with exposed gold in the central fracture.
N3: low wide layered rock shelf with several smaller gold seams.
N4: angular high-grade deposit with the largest visible gold chunks while keeping the same approximate footprint.
```

Impact prompt:

```text
Small stylized mining impact burst for a mobile game: bright gold-white sparks, two or three tiny rock/gold chips, compact radial shape, transparent background, no smoke cloud, no text, designed to overlay a gold deposit at small size.
```

Review all ten files together. Reject a set if the camera angle, lighting, ground line, robot facing direction, or deposit footprint changes enough to alter the existing node composition.

- [ ] **Step 6: Run the asset tests and verify GREEN**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: PASS, including host root-bundle loads.

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

### Task 2: Gate Visible Landing Basin Production and Publish One Impact Sequence

**Files:**
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Produces: shell-local `_landingBasinImpactSequence`, `MineSiteScreen.impactSequence`, and `_projectPresentationState(...)`.
- Consumes: existing `MiningController.refresh()`, `_displayState`, `_openSiteId`, `MiningSave.copyWith`, and `SiteProgress.copyWith`.
- Preserves: controller/simulation state and all persistence behavior.

- [ ] **Step 1: Write the failing timer impact test**

Import `mine_site_screen.dart` in `mining_shell_test.dart`, then add:

```dart
testWidgets('Landing Basin timer publishes cargo and impact together', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingBasin(_start));
  final savesBeforeTicks = repository.saveCount;
  await pumpShell(tester, repository: repository, clock: clock);

  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence,
    0,
  );

  clock.now = _start.add(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));

  final screen = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  final gauge = tester.widget<MiningCargoGauge>(
    find.byKey(const Key('mining-cargo-gauge')),
  );
  expect(screen.impactSequence, 1);
  expect(gauge.cargo, 1);
  expect(repository.saveCount, savesBeforeTicks);
});
```

- [ ] **Step 2: Write the failing action-accrual presentation-gate test**

```dart
testWidgets('action accrual stays hidden until the next Landing Basin impact', (
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

  expect(
    shellHandles(tester)
        .controller
        .state
        .sites[MiningSiteId.landingBasin]!
        .storedAmount,
    closeTo(.25, .0001),
  );
  expect(
    tester
        .widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge')))
        .cargo,
    0,
  );
  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence,
    0,
  );

  clock.now = _start.add(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 700));

  expect(
    tester
        .widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge')))
        .cargo,
    closeTo(.5, .0001),
  );
  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence,
    1,
  );
});
```

- [ ] **Step 3: Write failing immediate-decrease and leave-site synchronization tests**

Add both tests verbatim, adjusting only expected sale revenue if existing sale rounding makes the snackbar text differ:

```dart
testWidgets('sale decrease is immediate and does not fabricate an impact', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingState(_start, cargo: 10));
  await pumpShell(tester, repository: repository, clock: clock);

  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  clock.now = _start.add(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('mine-site-sell')));
  await tester.pump(const Duration(milliseconds: 300));

  expect(
    tester
        .widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge')))
        .cargo,
    0,
  );
  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence,
    0,
  );
});

testWidgets('leaving Landing Basin publishes held cargo without an impact', (
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

  expect(
    tester
        .widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge')))
        .cargo,
    0,
  );

  await tester.tap(find.byKey(const Key('mine-site-back')));
  await tester.pump();

  expect(
    tester
        .widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge')))
        .cargo,
    closeTo(.25, .0001),
  );

  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();
  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence,
    0,
  );
});
```

- [ ] **Step 4: Run focused shell tests and verify RED**

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: FAIL because `MineSiteScreen` has no `impactSequence` and `_refreshPresentation()` currently copies controller state directly.

- [ ] **Step 5: Add the transient shell sequence and pure projection helper**

In `_MiningShellState` add:

```dart
int _landingBasinImpactSequence = 0;
```

Add:

```dart
MiningSave _projectPresentationState(
  MiningSave authoritative, {
  required bool allowLandingBasinProductionIncrease,
}) {
  if (_openSiteId != MiningSiteId.landingBasin ||
      allowLandingBasinProductionIncrease) {
    return authoritative;
  }

  final displayedLanding =
      _displayState.sites[MiningSiteId.landingBasin]!;
  final authoritativeLanding =
      authoritative.sites[MiningSiteId.landingBasin]!;

  if (authoritativeLanding.storedAmount <= displayedLanding.storedAmount) {
    return authoritative;
  }

  return authoritative.copyWith(
    sites: {
      ...authoritative.sites,
      MiningSiteId.landingBasin: authoritativeLanding.copyWith(
        storedAmount: displayedLanding.storedAmount,
      ),
    },
  );
}
```

This keeps rig/cash/technology/busy-related presentation changes authoritative while holding only the upward Landing Basin cargo field.

- [ ] **Step 6: Make `_refreshPresentation` explicit about upward cargo publication**

Change it to:

```dart
void _refreshPresentation({
  bool allowLandingBasinProductionIncrease = false,
}) {
  if (!_initialized) return;
  _displayState = _projectPresentationState(
    _controller.state,
    allowLandingBasinProductionIncrease:
        allowLandingBasinProductionIncrease,
  );
  _reducedMotion =
      MediaQuery.maybeOf(context)?.disableAnimations ?? _reducedMotion;
  if (mounted) setState(() {});
}
```

Existing mutation paths keep calling `_refreshPresentation()` with the default `false`.

- [ ] **Step 7: Replace the timer body with one impact-publication method**

Add:

```dart
void _refreshForegroundProduction() {
  if (_controller.isBusy) return;

  final displayedCargo =
      _displayState.sites[MiningSiteId.landingBasin]!.storedAmount;
  _controller.refresh();

  final landing = _controller.state.sites[MiningSiteId.landingBasin]!;
  final hasRig = landing.rigByNode.values.any((tier) => tier != null);
  final publishImpact =
      _openSiteId == MiningSiteId.landingBasin &&
      hasRig &&
      landing.storedAmount > displayedCargo;

  if (publishImpact) {
    _landingBasinImpactSequence++;
  }
  _refreshPresentation(
    allowLandingBasinProductionIncrease: publishImpact,
  );
}
```

Keep one timer:

```dart
void _startRefreshTimer() {
  _refreshTimer?.cancel();
  _refreshTimer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => _refreshForegroundProduction(),
  );
}
```

- [ ] **Step 8: Make initialization/resume/leave synchronization explicit**

After initialization and after `_controller.resume()`, call:

```dart
_refreshPresentation(allowLandingBasinProductionIncrease: true);
```

Do not increment `_landingBasinImpactSequence` on those paths.

For `_leaveSite()` and `_showPrimarySurface(...)`, clear `_openSiteId` first and then synchronize authoritative presentation immediately:

```dart
setState(() => _openSiteId = null);
_refreshPresentation(allowLandingBasinProductionIncrease: true);
```

If implementation combines this into one `setState`, preserve the same ordering: the projection must see `_openSiteId != MiningSiteId.landingBasin` before it decides whether to hold cargo.

- [ ] **Step 9: Add `impactSequence` to `MineSiteScreen` and pass the shell value**

Add a deterministic default for direct screen fixtures:

```dart
const MineSiteScreen({
  super.key,
  required this.view,
  required this.fleetDock,
  required this.onNodeTap,
  required this.onBayTap,
  required this.onSpawnRig,
  required this.onSellCargo,
  required this.onBack,
  required this.onSettings,
  this.onDestinationSelected,
  this.cash = 0,
  this.reducedMotion = false,
  this.impactSequence = 0,
});

final int impactSequence;
```

In `MiningShell.build`, pass:

```dart
impactSequence: siteId == MiningSiteId.landingBasin
    ? _landingBasinImpactSequence
    : 0,
```

Do not add the sequence to `MiningSave`, `MiningController`, or `MineSiteView`.

- [ ] **Step 10: Run shell tests and verify GREEN**

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: PASS, including `timer refresh accrues cargo without persisting`.

- [ ] **Step 11: Commit the presentation contract**

```sh
git add \
  lib/mining/presentation/mining_shell.dart \
  lib/mining/presentation/mine_site_screen.dart \
  test/mining/presentation/mining_shell_test.dart
git commit -m "feat(mining): publish Landing Basin cargo on impact pulses"
```

---

### Task 3: Build One Node-Local Robot + Gold Hit Animation Component

**Files:**
- Create: `lib/mining/presentation/landing_basin_mining_node_visual.dart`
- Create: `test/mining/presentation/landing_basin_mining_node_visual_test.dart`

**Interfaces:**
- Consumes: Task 1 `MiningVisuals` mappings, `MiningNodeId`, `RigTier`.
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

Create a helper that pumps `LandingBasinMiningNodeVisual` inside `MaterialApp`. For `nodeId: n2`, `rig: t3`, assert:

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
expect((deposit.image as AssetImage).assetName,
    MiningVisuals.landingBasinDepositAsset(MiningNodeId.n2));
expect((robot.image as AssetImage).assetName,
    MiningVisuals.landingBasinRobotAsset(RigTier.t3));
```

Pump with `rig: null` and assert the deposit exists while the robot and impact keys do not.

- [ ] **Step 2: Write failing sequence behavior tests**

Pump `impactSequence: 0`, record the `Transform` matrix from the keyed robot transform, rebuild with `impactSequence: 1`, then assert:

```dart
expect(find.byKey(const Key('landing-basin-impact-n2')), findsOneWidget);
await tester.pump(const Duration(milliseconds: 100));
expect(
  tester.widget<Transform>(find.byKey(const Key('landing-basin-robot-n2'))).transform,
  isNot(equals(restMatrix)),
);
await tester.pump(const Duration(milliseconds: 900));
expect(find.byKey(const Key('landing-basin-impact-n2')), findsNothing);
```

Rebuild again with sequence `1`, pump 100 ms, and assert the robot remains at the rest matrix. Rebuild from `1` directly to `4`, pump 100 ms, and assert one recoil is active; after a total of one second it is back at rest with no second replay.

- [ ] **Step 3: Write failing reduced-motion coverage**

With `reducedMotion: true`, rebuild from sequence `0` to `1` and compare the keyed robot/deposit `Transform` matrices before and after 100 ms. Both matrices must remain equal to rest. The impact accent may be visible during that interval.

- [ ] **Step 4: Run the new widget test and verify RED**

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: FAIL because the widget does not exist.

- [ ] **Step 5: Implement the public widget and stable keys**

Create:

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

Use keys on the `Transform`/effect roots:

```dart
Key('landing-basin-deposit-${widget.nodeId.name}')
Key('landing-basin-robot-${widget.nodeId.name}')
Key('landing-basin-impact-${widget.nodeId.name}')
```

Initialize the one-second controller with `value: 1` so first mount is a deterministic rest/contact-ready pose.

- [ ] **Step 6: Restart only on a new sequence with an occupied rig**

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

A sequence jump invokes `forward(from: 0)` once.

- [ ] **Step 7: Implement one shared phase function**

Use `dart:ui` `lerpDouble` (or an equivalent local linear helper) with:

```dart
const recoilEnd = .14;
const windupEnd = .70;
```

Normal-motion values:

```text
robot dx:
  t=0.00 -> 0
  t=0.14 -> +12% of rigSize
  t=0.70 -> +8% of rigSize
  t=1.00 -> 0

deposit scale:
  t=0.00 -> 0.94
  t=0.14 -> 1.00
  t>=0.14 -> 1.00

impact opacity:
  t=0.00 -> 1.00
  t=0.18 -> 0.00
  t>=0.18 -> 0.00
```

Reduced-motion values:

```dart
robotDx = 0;
depositScale = 1;
```

The impact opacity may still follow the first 18% of the controller timeline.

- [ ] **Step 8: Reproduce the current node/rig geometry inside fixed bounds**

Render exactly this structure:

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

Use child `Transform.translate`/`Transform.scale`; never animate width, height, padding, margin, Row size, or Column size. With `rig == null`, render only the deposit using the current `.62` opacity treatment.

- [ ] **Step 9: Dispose the ticker**

```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

- [ ] **Step 10: Run widget tests and verify GREEN**

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: PASS with no ticker exception during teardown.

- [ ] **Step 11: Commit the animation component**

```sh
git add \
  lib/mining/presentation/landing_basin_mining_node_visual.dart \
  test/mining/presentation/landing_basin_mining_node_visual_test.dart
git commit -m "feat(mining): animate Landing Basin robot impacts"
```

---

### Task 4: Integrate the Animated Gold Path Without Moving Mine Site Geometry

**Files:**
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `test/mining/presentation/mine_site_screen_test.dart`
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Potential intentional golden updates: `test/mining/presentation/goldens/mine_site_430x932.png`, `test/mining/presentation/goldens/mine_site_874x402.png`

**Interfaces:**
- Consumes: Task 2 `MineSiteScreen.impactSequence`, Task 3 `LandingBasinMiningNodeVisual`.
- Produces: Landing Basin-only branch in `_MineNodeButton`; all non-gold paths remain unchanged.

- [ ] **Step 1: Extend the Mine Site test helper and add failing selection assertions**

Add to `_pumpMineSite`:

```dart
int impactSequence = 0,
```

and pass:

```dart
impactSequence: impactSequence,
```

For a Landing Basin view with T1 on N1:

```dart
expect(find.byKey(const Key('landing-basin-deposit-n1')), findsOneWidget);
expect(find.byKey(const Key('landing-basin-robot-n1')), findsOneWidget);
expect(find.byKey(const Key('mine-site-node-n1')), findsOneWidget);
```

For empty N2:

```dart
expect(find.byKey(const Key('landing-basin-deposit-n2')), findsOneWidget);
expect(find.byKey(const Key('landing-basin-robot-n2')), findsNothing);
```

Add a non-gold view helper by constructing `MineSiteView.from(... siteId: MiningSiteId.carbonRidge ...)`, then assert:

```dart
expect(find.byKey(const Key('landing-basin-deposit-n1')), findsNothing);
expect(find.byKey(const Key('landing-basin-robot-n1')), findsNothing);
```

and inspect the existing `Image` assets to confirm `view.definition.nodeAsset` and `MiningVisuals.rigAsset(...)` remain in use.

- [ ] **Step 2: Add failing synchronized-contact screen coverage**

Pump a Landing Basin view with cargo `0`, `impactSequence: 0`, then repump the same occupied-node state with cargo `.5`, `impactSequence: 1`:

```dart
expect(find.byKey(const Key('landing-basin-impact-n1')), findsOneWidget);
final progress = tester.widget<FractionallySizedBox>(
  find.descendant(
    of: find.byKey(const Key('mine-site-node-n1')),
    matching: find.byType(FractionallySizedBox),
  ).last,
);
expect(progress.widthFactor, closeTo(.5 / _siteView(nextState).capacity, .0001));
```

The presentation test does not call a controller; it proves the screen consumes the new view state and impact sequence in one rebuild.

- [ ] **Step 3: Run focused Mine Site tests and verify RED**

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart
```

Expected: FAIL because `_MineNodeButton` still renders shared node/rig images directly.

- [ ] **Step 4: Thread `impactSequence` and `siteId` through the private composition**

Add `required int impactSequence` through:

```text
_PortraitMineSite
_LandscapeMineSite
_CavernScene
_MineCavern
_MineNodeButton
```

Pass the public value unchanged. Also pass `view.siteId` into `_MineNodeButton`. Add no child-local counter.

- [ ] **Step 5: Branch only the unlocked Landing Basin visual subtree**

Inside `_MineNodeButton`:

```dart
final isLandingBasin = siteId == MiningSiteId.landingBasin;
```

For unlocked Landing Basin nodes render:

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

For unlocked non-gold nodes keep the existing `Image.asset(nodeAsset)` plus `MiningVisuals.rigAsset(view.rig!)` structure. Keep `_LockedNode` unchanged.

- [ ] **Step 6: Preserve the outer interaction/progress structure**

Do not move or replace:

```text
Semantics
  -> Material
    -> InkWell(key: mine-site-node-*)
      -> locked OR Column(
           node visual,
           6 px gap,
           progress bar,
         )
```

The semantics label, enabled/disabled logic, disabled-reason forwarding, progress bar width/height, callback, and outer `InkWell` bounds stay unchanged.

- [ ] **Step 7: Run geometry regression coverage before goldens**

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart
```

Expected: PASS without relaxing existing coordinate/tolerance assertions, including the 667×375 occupied N3/N4 tests and Sell/N3 non-overlap coverage.

- [ ] **Step 8: Verify or update only the two Mine Site goldens**

First run normally:

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

On Linux, the Landing Basin art change is expected to alter the two Mine Site images. If and only if the failures show the intended robot/deposit art with unchanged geometry, regenerate:

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart --update-goldens
```

On macOS the Mine Site golden cases are skipped; do not manufacture replacement goldens there. In all direct `MineSiteScreen` golden fixtures leave `impactSequence` at default `0` and `reducedMotion: true` so the captured pose is deterministic.

- [ ] **Step 9: Commit the Mine Site integration**

```sh
git add \
  lib/mining/presentation/mine_site_screen.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/visual_parity_golden_test.dart \
  test/mining/presentation/goldens/mine_site_430x932.png \
  test/mining/presentation/goldens/mine_site_874x402.png
git commit -m "feat(mining): integrate hit-synchronized Landing Basin visuals"
```

If normal golden verification passes without image updates, omit the two PNGs from `git add` rather than touching them.

---

### Task 5: Pin Full/Resume/Reduced-Motion Regressions and Repository Guidance

**Files:**
- Modify: `test/mining/presentation/mining_shell_test.dart`
- Modify: `test/mining/presentation/landing_basin_mining_node_visual_test.dart`
- Modify: `CLAUDE.md`

**Interfaces:**
- Verifies: full HPA-451 contract.
- Changes no domain/public economy interface.

- [ ] **Step 1: Add final-fill and already-full timer tests**

Create a helper seed with configurable cargo if needed by reusing `deployedLandingState`. Add:

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
  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence,
    1,
  );
  expect(
    shellHandles(tester)
        .controller
        .state
        .sites[MiningSiteId.landingBasin]!
        .storedAmount,
    90,
  );

  clock.now = _start.add(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 1));
  expect(
    tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence,
    1,
  );
});
```

Also seed `cargo: 90`, enter the site, advance one second, and assert `impactSequence` remains `0`.

- [ ] **Step 2: Add no-rig and lifecycle-resume no-replay tests**

For no-rig behavior, copy `deployedLandingState`, replace Landing Basin `rigByNode` with all nulls while keeping a small authoritative/display mismatch setup through an action or direct controller state fixture, then advance the timer and assert the sequence remains unchanged.

For resume, use the existing lifecycle test pattern:

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
  tester
      .widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge')))
      .cargo,
  greaterThan(0),
);
```

Use only injected clock advancement; do not add real sleeps.

- [ ] **Step 3: Add final reduced-motion transform assertions**

In `landing_basin_mining_node_visual_test.dart`, capture both keyed transform matrices at sequence `0`, rebuild with sequence `1`, pump 100 ms, then assert:

```dart
expect(robotTransformAfter, equals(robotTransformBefore));
expect(depositTransformAfter, equals(depositTransformBefore));
expect(find.byKey(const Key('landing-basin-impact-n1')), findsOneWidget);
```

After removing the widget tree, `expect(tester.takeException(), isNull)`.

- [ ] **Step 4: Run the complete mining presentation slice**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: PASS on the current platform; macOS keeps the existing Mine Site golden skip.

- [ ] **Step 5: Update `CLAUDE.md` with the active impact contract**

Add under the current economy/presentation guidance:

```markdown
- Landing Basin is the first authored animated resource-site slice. Its robot/deposit impacts present deterministic elapsed-time production; they are not an economy clock.
- `MiningShell` owns the transient Landing Basin impact sequence. While Landing Basin is open, upward passive cargo publication may be held until the next eligible foreground impact; authoritative controller state is never rewritten to match animation timing.
- Animation widgets never call `MiningController`, write the repository, or persist animation/variant state.
- Cold-load/resume/offline production publishes directly and is never replayed as historical strikes.
- Add another resource/site visual variant only when a concrete second site needs one; do not pre-build a generic resource visual registry.
```

Do not edit `AGENTS.md` separately.

- [ ] **Step 6: Run format/analyze**

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: PASS.

- [ ] **Step 7: Run the full repository verification gates**

```sh
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Expected: all PASS. The existing Chrome host-only asset-test skip remains unchanged.

- [ ] **Step 8: Prove no prohibited domain/save scope entered the PR**

```sh
git diff --stat main...HEAD
git diff main...HEAD -- \
  lib/mining/mining_content.dart \
  lib/mining/mining_state.dart \
  lib/mining/mining_controller.dart \
  lib/mining/mining_simulation.dart \
  lib/mining/mining_save_repository.dart
```

Expected: the second command prints no diff.

- [ ] **Step 9: Commit final regression coverage and guidance**

```sh
git add \
  CLAUDE.md \
  test/mining/presentation/mining_shell_test.dart \
  test/mining/presentation/landing_basin_mining_node_visual_test.dart
git commit -m "test(mining): verify Landing Basin impact presentation"
```

- [ ] **Step 10: Final PR readiness check**

Run:

```sh
git status --short
git log --oneline main..HEAD
```

Expected: clean working tree and a small sequence of HPA-451 commits covering assets, pulse publication, animation, integration, and final verification. Keep all of them in the same pull request.

---

## Spec Coverage Self-Review

- One Landing Basin-only authored slice: Tasks 1 and 4.
- Five robot tiers / four deposit variants / hit accent: Task 1.
- Deterministic elapsed-time economy unchanged: Task 2 and Task 5 diff guard.
- Upward visible cargo only on impact while the site is open: Task 2.
- Controller-action accrual does not leak between hits: Task 2 regression.
- One shared robot/deposit contact owner: Task 3.
- Final fill animates once; full site stops: Task 5.
- Resume/cold-load no replay: Tasks 2 and 5.
- Reduced motion non-spatial: Tasks 3 and 5.
- Non-gold sites unchanged: Tasks 1 and 4.
- Mine Site interaction/layout/N3-N4 geometry preserved: Task 4.
- No generic framework/save/domain change: Global Constraints plus Task 5 diff guard.
- Full repository verification: Task 5.

No additional subsystem, Linear ticket, or pull request is required for HPA-451.