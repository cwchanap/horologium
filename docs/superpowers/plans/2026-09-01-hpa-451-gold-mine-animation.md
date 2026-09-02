# HPA-451 Hit-Synchronized Gold Mine Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one Landing Basin vertical slice where passive foreground production, robot contact, and gold-deposit reaction are presented together, with five robot tiers and four deterministic gold-deposit variants.

**Architecture:** Keep `MiningController`, `MiningSimulation`, `MineSiteView`, persistence, and authoritative `_displayState` unchanged. `MiningShell` adds only one transient `int _landingBasinImpactSequence`; the existing one-second refresh compares authoritative Landing Basin cargo before/after `refresh()` and increments the sequence when an open, rigged Landing Basin actually produces. One node-local Flutter widget owns robot + deposit motion. Prototype T1/N1 at real Mine Site size before generating the rest of the asset family.

**Tech Stack:** Flutter/Dart, existing `Timer.periodic` shell refresh, `AnimationController`, PNG assets, existing SharedPreferences mining repository, Flutter widget tests, injected clocks/repositories.

**Spec:** `docs/superpowers/specs/2026-09-01-hpa-451-gold-mine-animation-design.md`

## Global Constraints

- Deliver HPA-451 through exactly one implementation PR.
- Animate only `MiningSiteId.landingBasin`; every non-gold site keeps its current presentation.
- Keep `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `MineSiteView`, save schema, rates, capacities, sale values, technology, planet progression, and offline caps unchanged.
- `MiningShell` remains the only foreground timer/presentation owner.
- Add exactly one new shell state value: `_landingBasinImpactSequence`.
- Passive one-second foreground production is hit-synchronized; user-initiated mutation results remain authoritative/immediate and do not fabricate mining impacts.
- UI/animation never grants resources and never calls a controller mutation from an animation callback.
- Cold-load/resume publish authoritative production immediately without replaying impacts.
- Add no save field/version/migration for animation or visual variants.
- Final art is five robot PNGs plus four deterministic N1–N4 gold-deposit PNGs. Reuse existing `MiningVisuals.mergeBurst` for contact when it passes the real-size prototype check; add one dedicated `impact.png` only if reuse fails.
- Do not add a generic resource visual registry, string resource IDs, randomized/persisted variants, sprite sheets, Rive, Lottie, Flame, physics, audio, new haptics, event buses, or state-management packages.
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
test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Create only if the existing effect fails the prototype reuse gate:

```text
assets/images/mining/landing_basin/impact.png
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
lib/mining/mine_site_view.dart
lib/mining/mining_content.dart
lib/mining/mining_state.dart
lib/mining/mining_controller.dart
lib/mining/mining_simulation.dart
lib/mining/mining_save_repository.dart
```

---

### Task 1: Prototype One Robot/Deposit Pair and Decide Contact-Effect Reuse

**Files:**
- Create: `assets/images/mining/landing_basin/robot_t1.png`
- Create: `assets/images/mining/landing_basin/deposit_n1.png`
- Modify: `lib/mining/presentation/mining_visuals.dart`
- Modify: `pubspec.yaml`
- Modify: `test/mining/presentation/mining_visuals_test.dart`

**Interfaces:**
- Produces: naming helpers `MiningVisuals.landingBasinRobotAsset(RigTier)` and `MiningVisuals.landingBasinDepositAsset(MiningNodeId)`.
- Reuse candidate: existing `MiningVisuals.mergeBurst`.
- Consumed by: `LandingBasinMiningNodeVisual` in Task 3.

- [ ] **Step 1: Add failing prototype path tests**

Add to `test/mining/presentation/mining_visuals_test.dart`:

```dart
test('maps the Landing Basin prototype assets by closed identity', () {
  expect(
    MiningVisuals.landingBasinRobotAsset(RigTier.t1),
    'assets/images/mining/landing_basin/robot_t1.png',
  );
  expect(
    MiningVisuals.landingBasinDepositAsset(MiningNodeId.n1),
    'assets/images/mining/landing_basin/deposit_n1.png',
  );
  expect(
    MiningVisuals.mergeBurst,
    'assets/images/mining/effects/merge_burst.png',
  );
});
```

- [ ] **Step 2: Run and verify RED**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: FAIL because the Landing Basin mapping helpers do not exist.

- [ ] **Step 3: Add the narrow naming helpers**

In `MiningVisuals`, keep `rigAsset(...)` unchanged and add:

```dart
static String landingBasinRobotAsset(RigTier tier) =>
    'assets/images/mining/landing_basin/robot_${tier.name}.png';

static String landingBasinDepositAsset(MiningNodeId nodeId) =>
    'assets/images/mining/landing_basin/deposit_${nodeId.name}.png';
```

Do not add a registry/map/string resource type.

- [ ] **Step 4: Register the Landing Basin asset directory**

Under `flutter.assets` in `pubspec.yaml` add:

```yaml
- assets/images/mining/landing_basin/
```

Keep existing `nodes/`, `rigs/`, and `effects/` entries.

- [ ] **Step 5: Author/generate only T1 + N1**

Create `robot_t1.png` from this brief:

```text
Stylized mobile-game sci-fi mining robot, compact two-track starter rig, one hydraulic pick/drill arm, exposed utility frame, three-quarter side view facing left toward a resource deposit, dark steel body with warm work lights, transparent background, clean readable silhouette, no text, no scenery, no external floor shadow. 512x512 RGBA; keep subject in central ~80%.
```

Create `deposit_n1.png` from this brief:

```text
Stylized mobile-game gold-bearing rock deposit, squat rounded boulder cluster with one broad diagonal exposed metallic-gold vein, dark volcanic rock matrix, three-quarter view matching the robot camera, transparent background, no text/scenery. 512x512 RGBA; keep subject in central ~80% and roughly match the current gold node footprint.
```

Do not generate T2–T5 or N2–N4 yet.

- [ ] **Step 6: Add prototype bundle loads and verify GREEN**

Extend the existing host-only asset bundle test:

```dart
await rootBundle.load(
  MiningVisuals.landingBasinRobotAsset(RigTier.t1),
);
await rootBundle.load(
  MiningVisuals.landingBasinDepositAsset(MiningNodeId.n1),
);
```

Run:

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: PASS.

- [ ] **Step 7: Keep `mergeBurst` as the provisional contact asset**

Do not add `impact.png` yet. Task 4 will render `MiningVisuals.mergeBurst` at the real node contact size and decide reuse using the spec's four acceptance criteria.

- [ ] **Step 8: Commit the prototype asset seam**

```sh
git add \
  assets/images/mining/landing_basin/robot_t1.png \
  assets/images/mining/landing_basin/deposit_n1.png \
  lib/mining/presentation/mining_visuals.dart \
  pubspec.yaml \
  test/mining/presentation/mining_visuals_test.dart
git commit -m "feat(mining): prototype Landing Basin mining art"
```

---

### Task 2: Publish One Passive Foreground Impact Sequence

**Files:**
- Modify: `lib/mining/presentation/mining_shell.dart`
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Produces: shell-local `_landingBasinImpactSequence` and public `MineSiteScreen.impactSequence`.
- Preserves: `_displayState = _controller.state`, all controller/simulation/save behavior, all mutation behavior.

- [ ] **Step 1: Add a timer helper that asserts deltas rather than phase**

In `mining_shell_test.dart` add:

```dart
Future<void> pumpMiningTick(
  WidgetTester tester,
  TestClock clock, {
  Duration elapsed = const Duration(seconds: 1),
}) async {
  clock.now = clock.now.add(elapsed);
  await tester.pump(const Duration(seconds: 1));
}
```

Use this helper only after `pumpShell(...)` has mounted and initialized the shell.

- [ ] **Step 2: Write the failing eligible-impact widget test**

Import `mine_site_screen.dart`, then add:

```dart
testWidgets('passive Landing Basin production increments one impact', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingBasin(clock.now));
  final savesBeforeTick = repository.saveCount;

  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  final before = tester
      .widget<MineSiteScreen>(find.byType(MineSiteScreen))
      .impactSequence;

  await pumpMiningTick(tester, clock);

  final after = tester
      .widget<MineSiteScreen>(find.byType(MineSiteScreen))
      .impactSequence;
  final gauge = tester.widget<MiningCargoGauge>(
    find.byKey(const Key('mining-cargo-gauge')),
  );

  expect(after - before, 1);
  expect(gauge.cargo, closeTo(.5, .0001));
  expect(repository.saveCount, savesBeforeTick);
});
```

The assertion is on `after - before`, not an absolute sequence value.

- [ ] **Step 3: Write a failing delayed-refresh single-impact test**

```dart
testWidgets('delayed foreground accrual still emits one impact', (
  tester,
) async {
  final clock = TestClock(_start);
  final repository = CountingMiningSaveRepository();
  await repository.save(deployedLandingBasin(clock.now));
  await pumpShell(tester, repository: repository, clock: clock);
  await tester.tap(find.byKey(const Key('site-card-landingBasin-enter')));
  await tester.pump();

  final before = tester
      .widget<MineSiteScreen>(find.byType(MineSiteScreen))
      .impactSequence;

  await pumpMiningTick(
    tester,
    clock,
    elapsed: const Duration(seconds: 3),
  );

  final after = tester
      .widget<MineSiteScreen>(find.byType(MineSiteScreen))
      .impactSequence;
  expect(after - before, 1);
  expect(
    shellHandles(tester)
        .controller
        .state
        .sites[MiningSiteId.landingBasin]!
        .storedAmount,
    closeTo(1.5, .0001),
  );
});
```

- [ ] **Step 4: Run shell tests and verify RED**

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: FAIL because `MineSiteScreen.impactSequence` does not exist.

- [ ] **Step 5: Add exactly one transient shell field**

In `_MiningShellState`:

```dart
int _landingBasinImpactSequence = 0;
```

Do not add a cargo overlay or helper state.

- [ ] **Step 6: Add `_refreshForegroundProduction()`**

```dart
void _refreshForegroundProduction() {
  if (_controller.isBusy) return;

  final before = _controller
      .state
      .sites[MiningSiteId.landingBasin]!
      .storedAmount;

  _controller.refresh();

  final landing = _controller.state.sites[MiningSiteId.landingBasin]!;
  final hasRig = landing.rigByNode.values.any((tier) => tier != null);

  if (_openSiteId == MiningSiteId.landingBasin &&
      hasRig &&
      landing.storedAmount > before) {
    _landingBasinImpactSequence++;
  }

  _refreshPresentation();
}
```

- [ ] **Step 7: Keep one timer and one refresh call**

Change `_startRefreshTimer()` to:

```dart
void _startRefreshTimer() {
  _refreshTimer?.cancel();
  _refreshTimer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => _refreshForegroundProduction(),
  );
}
```

Do not change `_refreshPresentation()`.

- [ ] **Step 8: Add `impactSequence` to `MineSiteScreen`**

Extend the public constructor with a deterministic default:

```dart
this.impactSequence = 0,
```

and field:

```dart
final int impactSequence;
```

In `MiningShell.build`, pass it **unconditionally**:

```dart
impactSequence: _landingBasinImpactSequence,
```

Do not add a second Landing Basin gate here.

- [ ] **Step 9: Add no-impact cases with sequence deltas**

Add one table-style widget test or three small tests covering:

```text
Landing Basin closed      -> delta 0
Landing Basin has no rig  -> delta 0
Landing Basin already full -> delta 0
```

For each case, capture sequence before/after `pumpMiningTick` and assert the delta.

- [ ] **Step 10: Run shell tests and verify GREEN**

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: PASS, including the existing `timer refresh accrues cargo without persisting` test.

- [ ] **Step 11: Commit the passive impact seam**

```sh
git add \
  lib/mining/presentation/mining_shell.dart \
  lib/mining/presentation/mine_site_screen.dart \
  test/mining/presentation/mining_shell_test.dart
git commit -m "feat(mining): publish passive Landing Basin impact sequence"
```

---

### Task 3: Build One Node-Local Robot + Gold Hit Animation

**Files:**
- Create: `lib/mining/presentation/landing_basin_mining_node_visual.dart`
- Create: `test/mining/presentation/landing_basin_mining_node_visual_test.dart`

**Interfaces:**
- Consumes: Task 1 asset helpers and provisional `MiningVisuals.mergeBurst`.
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

- Owns: exactly one `AnimationController`; no timer/controller/repository dependency.

- [ ] **Step 1: Write resting prototype tests**

Pump N1/T1 and assert stable roots:

```dart
expect(
  find.byKey(const Key('landing-basin-deposit-n1')),
  findsOneWidget,
);
expect(
  find.byKey(const Key('landing-basin-robot-n1')),
  findsOneWidget,
);
```

Pump `rig: null` and assert deposit exists while robot/contact accent do not.

- [ ] **Step 2: Write failing sequence tests**

Pump with `impactSequence: 0`, record the keyed robot transform, rebuild with `1`, then:

```dart
expect(
  find.byKey(const Key('landing-basin-impact-n1')),
  findsOneWidget,
);
await tester.pump(const Duration(milliseconds: 100));
expect(
  tester
      .widget<Transform>(
        find.byKey(const Key('landing-basin-robot-n1')),
      )
      .transform,
  isNot(equals(restMatrix)),
);
```

After the full one-second duration, assert the transform returns to rest and the accent is gone.

Rebuild with the same sequence and prove no restart. Rebuild directly from `1` to `4` and prove one animation only.

- [ ] **Step 3: Write failing reduced-motion and stable-bounds tests**

With `reducedMotion: true`, sequence `0 -> 1` must leave robot/deposit transform matrices spatially unchanged while allowing the contact accent/non-spatial feedback.

Capture `tester.getSize(find.byType(LandingBasinMiningNodeVisual))` before contact, at 100 ms, and at one second; all sizes must be equal.

- [ ] **Step 4: Run and verify RED**

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: FAIL because the widget does not exist.

- [ ] **Step 5: Implement the stateful widget**

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

Use one controller:

```dart
late final AnimationController _controller = AnimationController(
  vsync: this,
  duration: const Duration(seconds: 1),
  value: 1,
);
```

- [ ] **Step 6: Restart only on a new sequence with a rig**

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

- [ ] **Step 7: Implement the one-second phase**

Use these phase values:

```text
robot dx:
  t=0.00 -> 0
  t=0.14 -> +12% rigSize
  t=0.70 -> +8% rigSize
  t=1.00 -> 0

deposit scale:
  t=0.00 -> 0.94
  t=0.14 -> 1.00
  t>=0.14 -> 1.00

contact opacity:
  t=0.00 -> 1.00
  t=0.18 -> 0.00
  t>=0.18 -> 0.00
```

Reduced motion forces `robotDx = 0` and `depositScale = 1`; contact opacity may still fade.

- [ ] **Step 8: Reproduce current visual footprint**

Render fixed-size children matching the current Row contract:

```text
Row(crossAxisAlignment: end)
  deposit(nodeSize)
  if rig != null:
    2 px gap
    Column
      robot(rigSize)
      3 px gap
      existing tier badge styling
```

Use `Transform.translate` and `Transform.scale` only inside those fixed bounds. Do not animate width/height/padding/margins.

Contact accent initially uses:

```dart
Image.asset(MiningVisuals.mergeBurst, ...)
```

with a small size local to the deposit contact area.

- [ ] **Step 9: Dispose cleanly**

```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

- [ ] **Step 10: Run and verify GREEN**

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Expected: PASS with no ticker exception.

- [ ] **Step 11: Commit the animation component**

```sh
git add \
  lib/mining/presentation/landing_basin_mining_node_visual.dart \
  test/mining/presentation/landing_basin_mining_node_visual_test.dart
git commit -m "feat(mining): animate Landing Basin mining contact"
```

---

### Task 4: Integrate the Prototype and Prove the Real Footprint

**Files:**
- Modify: `lib/mining/presentation/mine_site_screen.dart`
- Modify: `test/mining/presentation/mine_site_screen_test.dart`
- Potentially create: `assets/images/mining/landing_basin/impact.png`
- Potentially modify: `lib/mining/presentation/mining_visuals.dart`

**Interfaces:**
- Consumes: Task 2 `impactSequence`, Task 3 `LandingBasinMiningNodeVisual`.
- Produces: one Landing Basin-only visual branch.

- [ ] **Step 1: Extend the Mine Site test helper**

Add:

```dart
int impactSequence = 0,
```

to `_pumpMineSite(...)` and pass it into `MineSiteScreen`.

- [ ] **Step 2: Write failing Landing Basin branch assertions**

For Landing Basin with T1 on N1:

```dart
expect(
  find.byKey(const Key('landing-basin-deposit-n1')),
  findsOneWidget,
);
expect(
  find.byKey(const Key('landing-basin-robot-n1')),
  findsOneWidget,
);
expect(find.byKey(const Key('mine-site-node-n1')), findsOneWidget);
```

For a non-gold site, assert no `landing-basin-*` roots exist and the existing node/rig assets remain rendered.

- [ ] **Step 3: Run Mine Site tests and verify RED**

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart
```

Expected: FAIL because the private composition does not yet consume the sequence/widget.

- [ ] **Step 4: Thread `impactSequence` through the existing private composition**

Add the required `int impactSequence` through:

```text
_PortraitMineSite
_LandscapeMineSite
_CavernScene
_MineCavern
_MineNodeButton
```

Pass the same value unchanged. Do not introduce child-local counters.

- [ ] **Step 5: Keep the single site gate in `_MineNodeButton`**

Pass `view.siteId` into `_MineNodeButton`, then branch:

```dart
if (siteId == MiningSiteId.landingBasin) {
  return LandingBasinMiningNodeVisual(
    nodeId: view.id,
    rig: view.rig,
    nodeSize: nodeSize,
    rigSize: rigSize,
    impactSequence: impactSequence,
    reducedMotion: reducedMotion,
  );
}
```

Keep the current non-gold `Image.asset(nodeAsset)` + `MiningVisuals.rigAsset(...)` subtree unchanged. Keep `_LockedNode` unchanged.

- [ ] **Step 6: Preserve the outer interaction/progress tree**

Do not move/replace:

```text
Semantics
Material
InkWell(key: mine-site-node-*)
6 px node-to-progress gap
progress bar
```

Do not restyle the tier badge; the new widget copies its existing spacing/style exactly.

- [ ] **Step 7: Run the real geometry gates immediately**

Run:

```sh
flutter test test/mining/presentation/mine_site_screen_test.dart
```

The existing assertions must remain unchanged, especially:

```text
402x874 authored node coordinates
667x375 Sell/N3 non-overlap
667x375 occupied N3/N4 disjointness
667x375 occupied N3/N4 containment
```

If T1/N1 art requires changing those geometry assertions, reject/rework the art instead of changing the layout contract.

- [ ] **Step 8: Decide whether to reuse `mergeBurst`**

Render an impact (`impactSequence: 1`) in both portrait and narrow landscape at the actual contact size.

Reuse `MiningVisuals.mergeBurst` only if it:

```text
reads as mining contact
is readable at actual size
keeps robot/deposit silhouettes readable
works for reduced-motion confirmation
```

If it passes, make no new effect asset.

If it fails, create `assets/images/mining/landing_basin/impact.png` from:

```text
Small stylized mobile-game mining impact burst: bright gold-white sparks plus two or three tiny rock/gold chips, compact radial shape, transparent background, no text, no smoke cloud, designed for a small gold-deposit contact overlay.
```

Then add exactly one constant:

```dart
static const landingBasinImpact =
    'assets/images/mining/landing_basin/impact.png';
```

and switch the animation widget to it. Add its root-bundle load to `mining_visuals_test.dart`.

- [ ] **Step 9: Run prototype component + geometry tests**

```sh
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
flutter test test/mining/presentation/mining_visuals_test.dart
```

Expected: PASS.

- [ ] **Step 10: Commit the proven prototype integration**

```sh
git add \
  lib/mining/presentation/mine_site_screen.dart \
  lib/mining/presentation/mining_visuals.dart \
  lib/mining/presentation/landing_basin_mining_node_visual.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/mining_visuals_test.dart \
  assets/images/mining/landing_basin/impact.png
git commit -m "feat(mining): integrate Landing Basin mining prototype"
```

If `mergeBurst` was reused, omit `impact.png` and any unchanged files from `git add`.

---

### Task 5: Complete the Robot and Gold-Deposit Asset Family

**Files:**
- Create: `assets/images/mining/landing_basin/robot_t2.png`
- Create: `assets/images/mining/landing_basin/robot_t3.png`
- Create: `assets/images/mining/landing_basin/robot_t4.png`
- Create: `assets/images/mining/landing_basin/robot_t5.png`
- Create: `assets/images/mining/landing_basin/deposit_n2.png`
- Create: `assets/images/mining/landing_basin/deposit_n3.png`
- Create: `assets/images/mining/landing_basin/deposit_n4.png`
- Modify: `test/mining/presentation/mining_visuals_test.dart`
- Modify: `test/mining/presentation/mine_site_screen_test.dart`
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Intentional Linux-only updates when needed: `test/mining/presentation/goldens/mine_site_430x932.png`, `test/mining/presentation/goldens/mine_site_874x402.png`

**Interfaces:**
- Consumes: already-proven naming helpers and T1/N1 footprint.
- Produces: complete T1–T5 / N1–N4 visual family.

- [ ] **Step 1: Author T2–T5 against the proven T1 camera/footprint**

Shared constraints:

```text
same camera
same facing direction
same ground line
same lighting/material family
transparent 512x512 RGBA
subject remains in the same central footprint envelope as T1
```

Tier additions:

```text
T2: reinforced chassis, larger arm linkage, added work light/protective plating.
T3: medium-heavy rig, dual hydraulic joints, larger mining head, cooling/energy module.
T4: heavy multi-actuator rig, broad armored chassis, stronger mining head, auxiliary stabilizer.
T5: premium massive automated rig, dense reinforced tooling, largest mining head, advanced energy/tooling modules; strongest tier without relying on recolor alone.
```

- [ ] **Step 2: Author N2–N4 against the proven N1 footprint**

Shared constraints:

```text
same camera/material family
transparent 512x512 RGBA
same approximate rendered footprint as N1
clearly gold-bearing
```

Variants:

```text
N2: taller split rock with gold in central fracture.
N3: low wide layered shelf with several smaller gold seams.
N4: angular high-grade deposit with largest visible gold chunks while preserving footprint.
```

- [ ] **Step 3: Expand path tests exhaustively**

Replace prototype-only coverage with:

```dart
for (final tier in RigTier.values) {
  expect(
    MiningVisuals.landingBasinRobotAsset(tier),
    'assets/images/mining/landing_basin/robot_${tier.name}.png',
  );
  await rootBundle.load(MiningVisuals.landingBasinRobotAsset(tier));
}
for (final nodeId in MiningNodeId.values) {
  expect(
    MiningVisuals.landingBasinDepositAsset(nodeId),
    'assets/images/mining/landing_basin/deposit_${nodeId.name}.png',
  );
  await rootBundle.load(MiningVisuals.landingBasinDepositAsset(nodeId));
}
```

Keep the existing host-only bundle-load skip behavior on web.

- [ ] **Step 4: Add tier/node selection screen assertions**

Use Mine Site fixtures to prove multiple occupied nodes resolve different deposit variants and the chosen robot tier asset. Do not add random selection.

- [ ] **Step 5: Run asset + component + geometry tests**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
```

Expected: PASS without relaxing geometry assertions.

- [ ] **Step 6: Verify Mine Site goldens**

First run:

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

On Linux only, if failures show only the intentionally new Landing Basin art with unchanged geometry, regenerate:

```sh
flutter test test/mining/presentation/visual_parity_golden_test.dart --update-goldens
```

Leave direct golden fixtures at `impactSequence: 0` and `reducedMotion: true` for a deterministic resting pose.

Do not manufacture Mine Site golden updates on macOS; those cases are already skipped there.

- [ ] **Step 7: Commit the completed asset family**

```sh
git add \
  assets/images/mining/landing_basin \
  test/mining/presentation/mining_visuals_test.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/visual_parity_golden_test.dart \
  test/mining/presentation/goldens/mine_site_430x932.png \
  test/mining/presentation/goldens/mine_site_874x402.png
git commit -m "feat(mining): complete Landing Basin visual variety"
```

Omit unchanged golden files from `git add`.

---

### Task 6: Pin Full/Resume/Reduced-Motion Regressions and Repository Guidance

**Files:**
- Modify: `test/mining/presentation/mining_shell_test.dart`
- Modify: `test/mining/presentation/landing_basin_mining_node_visual_test.dart`
- Modify: `CLAUDE.md`

**Interfaces:**
- Verifies: final HPA-451 contract.
- Changes no domain/view-model/economy/save interface.

- [ ] **Step 1: Add final-fill and already-full sequence-delta tests**

Seed Landing Basin just below capacity with a deployed T1 rig, enter it, capture sequence, `pumpMiningTick`, and assert:

```dart
expect(after - before, 1);
expect(
  shellHandles(tester)
      .controller
      .state
      .sites[MiningSiteId.landingBasin]!
      .storedAmount,
  90,
);
```

Advance another tick and assert sequence delta is `0`.

Seed already-full cargo, advance a tick, assert delta `0`.

- [ ] **Step 2: Add lifecycle-resume no-replay coverage**

Use the existing injected lifecycle pattern:

```dart
final before = tester
    .widget<MineSiteScreen>(find.byType(MineSiteScreen))
    .impactSequence;

await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
clock.now = clock.now.add(const Duration(seconds: 10));
await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
await tester.pump();
await tester.pump();

final after = tester
    .widget<MineSiteScreen>(find.byType(MineSiteScreen))
    .impactSequence;
expect(after - before, 0);
```

Also assert authoritative cargo increased through resume.

- [ ] **Step 3: Keep user-action behavior authoritative rather than adding strike tests**

Retain existing deploy/recall/spawn/sale tests. Do not add overlay/flush or mutation-impact classification tests. HPA-451 intentionally synchronizes the passive timer path only.

- [ ] **Step 4: Re-run reduced-motion component coverage**

Verify sequence change produces no spatial robot/deposit transform in reduced motion and no ticker exception after disposal.

- [ ] **Step 5: Update `CLAUDE.md` narrowly**

Add:

```markdown
- Landing Basin is the first authored animated mining site. Its transient shell-owned `impactSequence` presents passive one-second deterministic production; animation is not an economy clock.
- `MiningController`, `MiningSimulation`, `MineSiteView`, and `_displayState` remain authoritative. User-initiated mutations may publish their accrued state immediately and do not fabricate mining impacts.
- Landing Basin robot/deposit animation never calls the controller or persists animation/variant state. Cold-load/resume production is never replayed as historical strikes.
- Add another site-specific visual path only when a concrete second animated site needs it; do not pre-build a generic resource visual registry.
```

Do not edit `AGENTS.md` separately.

- [ ] **Step 6: Run focused presentation tests**

```sh
flutter test test/mining/presentation/mining_visuals_test.dart
flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: PASS on the current platform; existing macOS Mine Site golden skips remain.

- [ ] **Step 7: Run format/analyze**

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: PASS.

- [ ] **Step 8: Run full repository gates**

```sh
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Expected: all PASS.

- [ ] **Step 9: Enforce the executable scope guard**

```sh
git diff main...HEAD -- \
  lib/mining/mine_site_view.dart \
  lib/mining/mining_content.dart \
  lib/mining/mining_state.dart \
  lib/mining/mining_controller.dart \
  lib/mining/mining_simulation.dart \
  lib/mining/mining_save_repository.dart
```

Expected: no output.

- [ ] **Step 10: Commit final regression coverage/guidance**

```sh
git add \
  CLAUDE.md \
  test/mining/presentation/mining_shell_test.dart \
  test/mining/presentation/landing_basin_mining_node_visual_test.dart
git commit -m "test(mining): verify Landing Basin impact presentation"
```

- [ ] **Step 11: Final PR readiness check**

```sh
git status --short
git log --oneline main..HEAD
```

Expected: clean working tree and one HPA-451 PR containing the prototype, passive sequence, node animation, proven integration, full asset family, and verification commits.

---

## Spec Coverage Self-Review

- Landing Basin-only vertical slice: Tasks 1–5.
- Five robot tiers / four deterministic deposits: Tasks 1 and 5.
- Reuse existing contact effect before adding another: Tasks 1 and 4.
- One existing shell timer / one transient sequence: Task 2.
- Authoritative economy/state unchanged: Global Constraints + Task 6 scope guard.
- Passive production update and hit share the same callback/rebuild: Task 2.
- User mutations remain immediate without synthetic hits: Task 6.
- One robot+deposit animation owner: Task 3.
- Prototype art before bulk generation: Tasks 1 and 4 before Task 5.
- Geometry/N3-N4 containment preserved: Task 4 and Task 5.
- Reduced motion: Tasks 3 and 6.
- Full site and resume no replay: Task 6.
- Non-gold path unchanged: Task 4.
- Linux-only golden handling: Task 5.
- Timer tests use sequence deltas/tick helper instead of brittle absolute phase assumptions: Tasks 2 and 6.
- Full repository verification and domain/view-model scope guard: Task 6.

No visible-cargo overlay, `MineSiteView` override, mutation classification flag, extra Linear ticket, or additional PR is required.
