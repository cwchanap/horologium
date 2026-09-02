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

Run:

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

Use 512×512 RGBA source canvases with transparent backgrounds and keep the subject inside the central ~80% so Flutter scaling does not clip the art.

Use this shared visual brief for all robot images:

```text
Stylized mobile-game sci-fi mining robot, readable at small size, three-quarter side view, facing left toward a resource deposit, transparent background, hard-surface industrial design, dark steel body with warm work lights, clean silhouette, no text, no scenery, no floor shadow outside the transparent canvas, consistent camera and lighting across the full tier family.
```

Tier-specific additions:

```text
T1: compact two-track starter rig, one simple hydraulic pick/drill arm, exposed utility frame.
T2: reinforced chassis, larger arm linkage, added work light and protective plating.
T3: medium heavy rig, dual hydraulic joints, larger mining head, visible cooling/energy module.
T4: heavy multi-actuator rig, broad armored chassis, stronger mining head and auxiliary stabilizer.
T5: premium massive automated rig, dense reinforced tooling, largest mining head, advanced energy/tooling modules; clearly the strongest tier without relying on recolor alone.
```

Use this shared gold-deposit brief:

```text
Stylized mobile-game gold-bearing rock deposit, three-quarter side view matching the mining robot camera, transparent background, dark volcanic/stone matrix with clearly exposed metallic gold veins and chunks, readable at small size, no text, no scenery, consistent lighting and material style across all four variants.
```

Variant-specific additions:

```text
N1: squat rounded boulder cluster with one broad diagonal gold vein.
N2: taller split-rock silhouette with exposed gold in the central fracture.
N3: low wide layered rock shelf with several smaller gold seams.
N4: angular high-grade deposit with the largest visible gold chunks while keeping the same approximate footprint.
```

Use this impact brief for `impact.png`:

```text
Small stylized mining impact burst for a mobile game: bright gold-white sparks, two or three tiny rock/gold chips, compact radial shape, transparent background, no smoke cloud, no text, designed to overlay a gold deposit at small size.
```

Review the generated files together before commit. Reject any set where camera angle, ground line, lighting, or robot facing direction changes between tiers.

- [ ] **Step 6: Run the asset tests and verify GREEN**

Run:

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: PASS, including bundle loads on the host test runner.

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
- Modify: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Produces: shell-local `_landingBasinImpactSequence`, `MineSiteScreen.impactSequence`, and a presentation helper that can allow/hold upward Landing Basin cargo.
- Consumes: existing `MiningController.refresh()`, `_displayState`, `_openSiteId`, `MiningSave.copyWith`, and `SiteProgress.copyWith`.
- Preserves: controller/simulation state and all persistence behavior.

- [ ] **Step 1: Write the failing impact/publication test**

Import `mine_site_screen.dart` in `mining_shell_test.dart`, then add:

```dart
testWidgets('Landing Basin timer publishes cargo and impact together', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingBasin(_start));
  await pumpShell(tester, repository: repository, clock: clock);

  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence, 0);

  clock.now = _start.add(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));

  final screen = tester.widget<MineSiteScreen>(find.byType(MineSiteScreen));
  final gauge = tester.widget<MiningCargoGauge>(
    find.byKey(const Key('mining-cargo-gauge')),
  );
  expect(screen.impactSequence, 1);
  expect(gauge.cargo, 1);
  expect(repository.saveCount, 1);
});
```

The saved seed already accounts for the one setup write; keep the assertion aligned with the existing repository-counting helper rather than introducing a new repository fake.

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
  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence, 0);

  clock.now = _start.add(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 700));

  expect(
    tester
        .widget<MiningCargoGauge>(find.byKey(const Key('mining-cargo-gauge')))
        .cargo,
    closeTo(.5, .0001),
  );
  expect(tester.widget<MineSiteScreen>(find.byType(MineSiteScreen)).impactSequence, 1);
});
```

This is the regression that prevents controller action accrual from leaking into the open Landing Basin presentation before a hit.

- [ ] **Step 3: Add failing immediate-decrease and leave-site synchronization coverage**

Add one test that seeds cargo, advances the clock by less than one timer interval, sells cargo, and proves the visible gauge becomes zero immediately with no impact increment.

Add one test that creates held authoritative cargo, taps Back, and proves the Site Deck gauge immediately synchronizes to authoritative cargo without incrementing an impact sequence.

Use the existing keys:

```text
mine-site-sell
mine-site-back
mining-cargo-gauge
```

- [ ] **Step 4: Run focused shell tests and verify RED**

Run:

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: FAIL because `MineSiteScreen` has no `impactSequence` and `_refreshPresentation()` currently copies controller state directly.

- [ ] **Step 5: Add the transient shell sequence and a pure presentation projection helper**

In `_MiningShellState` add:

```dart
int _landingBasinImpactSequence = 0;
```

Add a helper with this exact behavior:

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

This copies all authoritative state changes except the one held upward cargo field.

- [ ] **Step 6: Make `_refreshPresentation` explicit about whether an upward gold delta may publish**

Change the helper to:

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

Existing mutation paths continue calling `_refreshPresentation()` with the default `false`.

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

Then keep the existing timer cadence but delegate:

```dart
_refreshTimer = Timer.periodic(
  const Duration(seconds: 1),
  (_) => _refreshForegroundProduction(),
);
```

Do not add a second timer.

- [ ] **Step 8: Make non-replayed synchronization paths explicit**

After initialization/resume, call:

```dart
_refreshPresentation(allowLandingBasinProductionIncrease: true);
```

Do **not** increment `_landingBasinImpactSequence` on those paths.

When leaving a site or navigating to another primary surface, clear `_openSiteId` and synchronize authoritative presentation immediately without an impact. Keep that change inside one `setState`/refresh sequence; do not wait for the next timer tick.

- [ ] **Step 9: Add `impactSequence` to `MineSiteScreen` and pass the shell value**

In `MineSiteScreen` add a deterministic default for direct fixtures:

```dart
const MineSiteScreen({
  // existing arguments...
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

Do not add this value to `MiningSave` or any controller/view model.

- [ ] **Step 10: Run shell tests and verify GREEN**

Run:

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: PASS, including the existing `timer refresh accrues cargo without persisting` behavior.

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

- [ ] **Step 1: Write the resting/asset-selection tests first**

Create `landing_basin_mining_node_visual_test.dart` with a helper that pumps the widget inside `MaterialApp`.

Assert:

```dart
expect(
  find.byKey(const Key('landing-basin-deposit-n2')),
  findsOneWidget,
);
expect(
  find.byKey(const Key('landing-basin-robot-n2')),
  findsOneWidget,
);
```

Inspect the two `Image` widgets and assert their `AssetImage.assetName` values equal:

```dart
MiningVisuals.landingBasinDepositAsset(MiningNodeId.n2)
MiningVisuals.landingBasinRobotAsset(RigTier.t3)
```

Pump with `rig: null` and assert the deposit exists while the robot and impact keys do not.

- [ ] **Step 2: Write failing sequence behavior tests**

Pump `impactSequence: 0`, record the robot transform, rebuild with `impactSequence: 1`, and assert:

```text
immediate frame: impact accent exists and robot is at contact
~100 ms: robot transform differs from rest/contact (recoil)
1 second: robot returns to stable rest/contact-ready pose; impact accent is gone
```

Rebuild again with sequence `1` and prove the transform does not restart.

Rebuild from sequence `1` directly to `4` and prove only one one-second animation occurs.

- [ ] **Step 3: Write failing reduced-motion coverage**

With `reducedMotion: true`, rebuild from sequence `0` to `1` and compare the robot/deposit `Transform` matrices before, during, and after pumping 100 ms. They must remain identical.

The impact accent may exist briefly; spatial transforms must not change.

- [ ] **Step 4: Run the new widget test and verify RED**

Run:

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: FAIL because the widget does not exist.

- [ ] **Step 5: Implement the public widget and stable test keys**

Create a `StatefulWidget` using `SingleTickerProviderStateMixin` and one controller:

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

Use these keys:

```dart
Key('landing-basin-deposit-${widget.nodeId.name}')
Key('landing-basin-robot-${widget.nodeId.name}')
Key('landing-basin-impact-${widget.nodeId.name}')
```

Initialize the animation controller at `value: 1` so first mount is a deterministic rest/contact-ready pose, not an impact.

- [ ] **Step 6: Restart only on a new sequence with an occupied rig**

Implement `didUpdateWidget`:

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

A jump from 1 to 4 still invokes `forward(from: 0)` once.

- [ ] **Step 7: Implement one shared animation value for robot, deposit, and accent**

Inside an `AnimatedBuilder`, derive transforms from `_controller.value`.

Use these phase boundaries:

```dart
const recoilEnd = .14;
const windupEnd = .70;
```

For normal motion:

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

Use `ui.lerpDouble`/a small local interpolation helper rather than adding an animation package.

For reduced motion:

```dart
robotDx = 0;
depositScale = 1;
```

The impact opacity may still use the first 18% of the controller timeline.

- [ ] **Step 8: Reproduce the current node/rig geometry inside fixed bounds**

Render the deposit and robot in the same side-by-side structure as `_MineNodeButton` currently uses:

```text
deposit(nodeSize)
2 px gap
robot column:
  robot(rigSize)
  3 px gap
  existing TIER badge styling
```

Keep the outer dimensions stable while the child images use `Transform.translate`/`Transform.scale`. Do not animate width, height, padding, margin, or the outer Row/Column size.

When `rig == null`, render only the deposit at the existing `.62` opacity treatment and omit the tier badge.

- [ ] **Step 9: Dispose the ticker cleanly**

```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

The widget test teardown must report no active ticker exception.

- [ ] **Step 10: Run widget tests and verify GREEN**

Run:

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: PASS.

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

**Interfaces:**
- Consumes: Task 2 `MineSiteScreen.impactSequence`, Task 3 `LandingBasinMiningNodeVisual`.
- Produces: Landing Basin-only branch in `_MineNodeButton`; all non-gold paths remain unchanged.

- [ ] **Step 1: Add failing Mine Site assertions for Landing Basin visual selection**

Extend the existing Mine Site test helper so it can pass `impactSequence` when needed.

For an unlocked Landing Basin view with a T1 rig on N1, assert:

```dart
expect(find.byKey(const Key('landing-basin-deposit-n1')), findsOneWidget);
expect(find.byKey(const Key('landing-basin-robot-n1')), findsOneWidget);
expect(find.byKey(const Key('mine-site-node-n1')), findsOneWidget);
```

For an unlocked empty N2, assert the deterministic N2 deposit exists and no N2 robot exists.

For a non-gold site, assert no `landing-basin-*` keys render and the existing site `nodeAsset`/global rig asset path remains in use.

- [ ] **Step 2: Add failing synchronized-contact integration coverage**

Pump Landing Basin with `impactSequence: 0`, rebuild with `1`, and assert both:

```text
landing-basin-impact-n1 exists
mine-site cargo/progress reflects the already-published new view value
```

This test proves the screen consumes one shared sequence; it does not simulate economy inside the presentation test.

- [ ] **Step 3: Run focused Mine Site tests and verify RED**

Run:

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart
```

Expected: FAIL because `_MineNodeButton` still renders the shared node/rig images directly.

- [ ] **Step 4: Thread `impactSequence` through the private Mine Site composition**

Add `required int impactSequence` through:

```text
_PortraitMineSite
_LandscapeMineSite
_CavernScene
_MineCavern
_MineNodeButton
```

Pass the public `MineSiteScreen.impactSequence` unchanged. Do not add local counters in any child widget.

Also pass `view.siteId` into `_MineNodeButton` so the leaf can make one closed branch.

- [ ] **Step 5: Replace only the Landing Basin unlocked visual subtree**

Inside `_MineNodeButton`, keep the existing locked branch untouched.

For unlocked nodes, choose:

```dart
final isLandingBasin = siteId == MiningSiteId.landingBasin;
```

If true, render:

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

If false, retain the existing `Row` with:

```dart
Image.asset(nodeAsset, ...)
Image.asset(MiningVisuals.rigAsset(view.rig!), ...)
```

Do not create a resource-widget registry for this one branch.

- [ ] **Step 6: Preserve the existing outer interaction and progress structure verbatim**

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

The `InkWell`, semantics label, enabled/disabled logic, callback forwarding, and progress bar width/height remain as they are.

- [ ] **Step 7: Re-run narrow-landscape geometry tests before touching goldens**

Run the existing focused Mine Site test file and specifically confirm the 667×375 occupied N3/N4 assertions still pass.

Run:

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart
```

Expected: PASS with no relaxed tolerance and no changed authored node positions.

- [ ] **Step 8: Keep visual-parity goldens deterministic**

Update direct `MineSiteScreen` calls only as needed for the new argument. Leave `impactSequence` at the default `0` so goldens capture a stable resting pose.

Regenerate a golden only if the intentionally new Landing Basin authored art changes the expected image. Do not accept geometry drift as an incidental golden update.

Run the repository's existing visual-parity golden command/test target used by the suite.

- [ ] **Step 9: Commit the Mine Site integration**

```sh
git add \
  lib/mining/presentation/mine_site_screen.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/visual_parity_golden_test.dart \
  test/goldens
git commit -m "feat(mining): integrate hit-synchronized Landing Basin visuals"
```

If the repository stores goldens outside `test/goldens`, stage only the exact files reported changed by the existing golden test command; do not create a second golden directory.

---

### Task 5: Pin Full/Resume/Reduced-Motion Regressions and Repository Guidance

**Files:**
- Modify: `test/mining/presentation/mining_shell_test.dart`
- Modify: `test/mining/presentation/landing_basin_mining_node_visual_test.dart`
- Modify: `CLAUDE.md`

**Interfaces:**
- Verifies: HPA-451 complete player-visible contract.
- Changes no domain/public economy interface.

- [ ] **Step 1: Add final-shell impact edge-case tests**

Add focused tests proving:

```text
already-full Landing Basin -> timer sequence does not increment
final partial fill reaching capacity -> one sequence increment, then no more
no deployed rig -> held authoritative increase does not fabricate an impact
lifecycle resume -> visible cargo synchronizes immediately, sequence unchanged
opening another site -> no Landing Basin impact sequence is consumed by that site
```

Use existing injected `TestClock`, `CountingMiningSaveRepository`, lifecycle APIs, and current site-entry keys. Do not add wall-clock sleeps.

- [ ] **Step 2: Add final reduced-motion assertions**

In `landing_basin_mining_node_visual_test.dart`, verify for a sequence change with `reducedMotion: true`:

```text
robot transform matrix unchanged
deposit transform matrix unchanged
impact accent may appear briefly
no active ticker remains after disposal
```

- [ ] **Step 3: Run the complete mining presentation slice**

Run:

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: PASS.

- [ ] **Step 4: Update the active repository guidance narrowly**

In `CLAUDE.md`, extend the existing economy/presentation guidance with these rules:

```markdown
- Landing Basin is the first authored animated resource-site slice. Its robot/deposit impacts are presentation of deterministic elapsed-time production, not an economy clock.
- `MiningShell` owns the transient Landing Basin impact sequence. While Landing Basin is open, upward passive cargo publication may be held until the next eligible foreground impact; the authoritative controller state is never rewritten to match animation timing.
- Animation widgets never call `MiningController`, write the repository, or persist animation/variant state.
- Cold-load/resume/offline production is published directly and is never replayed as historical strikes.
- Add another resource/site visual variant only when a concrete second site needs one; do not pre-build a generic resource visual registry.
```

Do not edit `AGENTS.md` separately because it follows this guidance file.

- [ ] **Step 5: Run format/analyze before the expensive gates**

Run:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: PASS.

- [ ] **Step 6: Run the full repository verification gates**

Run exactly the documented repository commands:

```sh
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Expected: all PASS. The existing Chrome rootBundle skip remains unchanged.

- [ ] **Step 7: Review the diff for prohibited scope**

Run:

```sh
git diff --stat main...HEAD
git diff main...HEAD -- \
  lib/mining/mining_content.dart \
  lib/mining/mining_state.dart \
  lib/mining/mining_controller.dart \
  lib/mining/mining_simulation.dart \
  lib/mining/mining_save_repository.dart
```

Expected: the second command has no output. If it does, remove the domain/save changes unless they are required by a newly discovered contradiction and have been explicitly approved.

- [ ] **Step 8: Commit guidance and final regression coverage**

```sh
git add \
  CLAUDE.md \
  test/mining/presentation/mining_shell_test.dart \
  test/mining/presentation/landing_basin_mining_node_visual_test.dart
git commit -m "test(mining): verify Landing Basin impact presentation"
```

- [ ] **Step 9: Final PR readiness check**

Confirm the final PR contains exactly one coherent HPA-451 feature outcome:

```text
assets + narrow mappings
shell presentation gate + impact sequence
one node-local robot/deposit animation widget
Landing Basin-only Mine Site integration
focused regression tests + deterministic goldens
CLAUDE.md guidance
```

Do not split any of these into another PR.

---

## Spec Coverage Self-Review

- One Landing Basin-only authored slice: Tasks 1, 4.
- Five robot tiers / four deposit variants / hit accent: Task 1.
- Deterministic elapsed-time economy unchanged: Tasks 2, 5 diff guard.
- Upward visible cargo only on impact while site is open: Task 2.
- Controller-action accrual does not leak between hits: Task 2 regression.
- One shared robot/deposit contact owner: Task 3.
- Final fill animates once, full site stops: Task 5.
- Resume/cold-load no replay: Tasks 2, 5.
- Reduced motion non-spatial: Tasks 3, 5.
- Non-gold sites unchanged: Tasks 1, 4.
- Mine Site interaction/layout/N3-N4 geometry preserved: Task 4.
- No generic framework/save/domain change: Global Constraints + Task 5 diff guard.
- Full repository verification: Task 5.

No additional subsystem, ticket, or pull request is required for HPA-451.