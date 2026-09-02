# HPA-451 Hit-Synchronized Gold Mine Animation Design

## Status

Approved implementation design for Linear HPA-451, **Ship hit-synchronized gold mine animation and visual variety**.

Planning, implementation, review, and verification stay on **one branch and one pull request**. This design is intentionally limited to one authored resource site: `MiningSiteId.landingBasin`.

This design is grounded on `main` commit `b00e0bcaa3bc4c77e5ae0ebdb0d6c83e51aeaee3`.

## Goal

Make Landing Basin read as a physical mining scene rather than a continuously ticking number:

```text
robot reaches contact
    -> gold deposit reacts
    -> visible Landing Basin cargo/progress increases
    -> robot recoils, winds up, and approaches the next hit
```

At the same time, increase the visual variety of the gold site with five robot-tier images, four deterministic gold-deposit variants, and one authored hit accent.

The underlying economy remains deterministic elapsed-time production. Animation presents authoritative results; it never owns or calculates them.

## Current reusable baseline

The active runtime already has the correct ownership seams:

```text
MainMenu
  -> MiningShell
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
      -> Site Deck / Mine Site / Stellar Map
```

Reuse rather than recreate:

- `MiningShell` as the single owner of the one-second foreground timer, `_displayState`, lifecycle, navigation, and reduced-motion propagation;
- `MiningController.refresh()` as the in-memory foreground accrual seam;
- `MiningController` mutation methods, which accrue to the injected clock before changing state and persisting;
- `MiningSimulation` as the pure elapsed-time production source of truth;
- `MineSiteScreen` and its existing responsive cavern/node composition;
- `MiningVisuals` for authored presentation paths;
- `MiningNodeId`, `RigTier`, and `MiningSiteId` as closed identities;
- the existing `test/mining/presentation/mining_shell_test.dart`, `mine_site_screen_test.dart`, `mining_visuals_test.dart`, and visual-parity coverage.

The current Mine Site renders one site-wide `nodeAsset` and one shared rig image per `RigTier`. Landing Basin currently points at `assets/images/mining/nodes/gold.png`; deployed rigs use `assets/images/mining/rigs/t1.png` through `t5.png`.

Do not add a second controller, simulation, repository, timer, or persisted animation state.

## Selected architecture

### 1. Preserve authoritative economy; gate only visible Landing Basin increases

The production model does not change.

`MiningController.refresh()` and every existing mutation continue to accrue authoritative state to the supplied UTC clock. Offline, resume, cold-load, action ordering, persistence, rates, capacity, and sale semantics remain unchanged.

The new rule exists only in `MiningShell` presentation state:

> While Landing Basin is open, passive upward cargo/progress changes are published only on an eligible foreground impact pulse.

This matters because controller actions also accrue to `now`. Without a presentation gate, a deploy, recall, spawn, technology purchase, or other action could expose an upward cargo delta between robot strikes.

`MiningShell` therefore keeps two concepts distinct:

```text
_controller.state   authoritative current mining state
_displayState       currently published player-visible snapshot
```

When Landing Basin is open and a non-impact presentation refresh sees:

```text
authoritativeLandingCargo > displayedLandingCargo
```

copy every new field from `_controller.state` **except** keep Landing Basin `storedAmount` at its previously displayed value.

This preserves immediate UI updates for:

- rig deployment/recall;
- dock changes;
- technology/cash changes;
- controller busy state;
- navigation;
- cargo decreases such as sale;
- any other non-passive state change.

Only the upward Landing Basin cargo delta waits for the next impact.

No hidden production is discarded. The controller remains ahead until an eligible impact publishes the full accumulated delta.

### 2. Use the existing one-second timer as the site impact clock

Add one transient shell-local counter:

```dart
int _landingBasinImpactSequence = 0;
```

On each existing timer callback:

1. skip when the controller is busy, preserving current behavior;
2. read the currently displayed Landing Basin `storedAmount`;
3. call `MiningController.refresh()` exactly once;
4. read authoritative Landing Basin `storedAmount` and current rig assignment;
5. if Landing Basin is open, at least one rig is currently deployed, and authoritative cargo is greater than displayed cargo, increment `_landingBasinImpactSequence`;
6. publish the complete controller state and the incremented sequence in the same `setState`.

A delayed timer callback may publish several elapsed seconds of production in one strike. Missed foreground strikes are not replayed.

If no rig is currently deployed, no impact is emitted even if the controller is ahead of the displayed snapshot because an earlier action accrued production. That hidden increase remains held while the site is open. Leaving the site synchronizes the normal presentation immediately without fabricating a hit.

The final production update that reaches capacity may emit one impact because cargo increased. Subsequent callbacks have no upward delta and emit no impact.

### 3. Initialization and lifecycle resume bypass strike replay

Initialization and lifecycle resume keep their existing deterministic accrual behavior.

They may publish an upward Landing Basin delta immediately **without** incrementing `_landingBasinImpactSequence`.

Therefore:

- cold launch never replays historical strikes;
- returning from background never replays historical strikes;
- the offline-return sheet stays authoritative;
- entering Landing Basin never fabricates a hit;
- leaving Landing Basin removes the presentation gate and synchronizes the current controller state without an impact.

### 4. Add one authored Landing Basin asset family

Keep the scope local to one concrete site. Add exactly ten new PNGs under one manifest directory:

```text
assets/images/mining/landing_basin/
  robot_t1.png
  robot_t2.png
  robot_t3.png
  robot_t4.png
  robot_t5.png
  deposit_n1.png
  deposit_n2.png
  deposit_n3.png
  deposit_n4.png
  impact.png
```

Asset rules:

- transparent RGBA PNGs;
- consistent orientation: deposits on the left, robot facing/working toward the left-side deposit;
- robot silhouettes form one progression family but differ enough that T1–T5 are recognizable without reading the tier badge;
- higher tiers gain visible machinery mass/tooling rather than only color changes;
- four deposits clearly read as gold-bearing rock from the same Landing Basin environment but differ in silhouette, exposed gold vein/ore shape, and surrounding rock detail;
- all four deposit variants keep a similar bounding footprint so current node geometry remains valid;
- `impact.png` is a small spark/chip/fragment accent that remains readable at current node sizes.

Do not reorganize existing global rig/node assets. Fleet Dock and every non-Landing-Basin site keep their current files.

Extend `MiningVisuals` only with narrow helpers:

```dart
static String landingBasinRobotAsset(RigTier tier) =>
    'assets/images/mining/landing_basin/robot_${tier.name}.png';

static String landingBasinDepositAsset(MiningNodeId nodeId) =>
    'assets/images/mining/landing_basin/deposit_${nodeId.name}.png';

static const landingBasinImpact =
    'assets/images/mining/landing_basin/impact.png';
```

The closed enums plus tests make this deterministic. Do not add string resource IDs, random variants, persisted variant state, or a generic resource visual registry.

Add one `pubspec.yaml` asset entry:

```yaml
- assets/images/mining/landing_basin/
```

### 5. One node-local animation owner synchronizes robot and resource

Use one focused stateful widget rather than separate robot/deposit animation owners:

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

The widget owns one `AnimationController` with a one-second duration. It does not own a timer and never calls the mining controller.

For unlocked Landing Basin nodes:

- `rig == null`: render the deterministic `deposit_nX.png` in the same subdued no-rig treatment as today;
- `rig != null`: render the deposit and tier-specific robot together;
- a new `impactSequence` while a rig is present starts one animation;
- rebuilding with the same sequence does not restart;
- a sequence jump greater than one still plays one strike rather than replaying missed impacts.

Suggested one-second choreography:

```text
0 ms        contact pose; deposit compresses/flashes; impact accent visible
0–140 ms    robot recoils away; deposit settles
140–700 ms  robot recovers and winds up
700–1000 ms robot approaches the deposit
```

Exact easing and transform magnitude are implementation-tunable. The public contract is the sequence behavior and synchronized contact frame.

The widget's external layout size remains stable throughout animation. Transforms happen inside fixed bounds so current tap-target geometry does not move.

Locked nodes continue using `_LockedNode` and never instantiate the gold animation widget.

### 6. Reduced motion keeps contact semantics without spatial motion

`MediaQuery.disableAnimations` remains the sole source of truth and is still propagated from `MiningShell`.

When reduced motion is enabled:

- do not translate, rotate, shake, or continuously animate the robot/deposit;
- render stable robot/deposit poses;
- on a new impact sequence, permit only a brief non-spatial opacity/brightness confirmation and/or the static `impact.png` accent;
- publish cargo/progress on the exact same impact update as normal motion.

Reduced motion changes presentation only, never economy cadence.

### 7. Keep Mine Site geometry and interactions unchanged

Add an `impactSequence` input to `MineSiteScreen`, defaulting to `0` so direct screen fixtures and goldens remain deterministic unless they explicitly exercise an impact.

Pass it through:

```text
MineSiteScreen
  -> _PortraitMineSite / _LandscapeMineSite
  -> _CavernScene
  -> _MineCavern
  -> _MineNodeButton
```

`_MineNodeButton` receives the site ID so it can choose one narrow branch:

- Landing Basin unlocked node: `LandingBasinMiningNodeVisual`;
- every other unlocked site: existing `nodeAsset + MiningVisuals.rigAsset(...)` presentation;
- locked node: existing `_LockedNode`.

Preserve unchanged:

- outer `Semantics`;
- `InkWell` and `mine-site-node-${id.name}` key;
- disabled-reason forwarding;
- tier badge;
- site progress bar;
- deploy/recall callbacks;
- portrait anchors;
- landscape anchors;
- special narrow-landscape N3/N4 containment/overlap behavior;
- Sell control geometry.

No generic widget factory is needed for one special site.

## Data flow

Normal visible impact:

```text
Timer.periodic(1s)
  -> MiningShell reads displayed Landing Basin cargo
  -> MiningController.refresh()
  -> MiningSimulation accrues authoritative elapsed-time production
  -> MiningShell sees authoritative cargo > displayed cargo
  -> impactSequence++
  -> publish authoritative _displayState + new sequence in one setState
  -> MineSiteScreen rebuilds
  -> LandingBasinMiningNodeVisual.didUpdateWidget sees new sequence
  -> robot contact + deposit reaction start at the already-updated cargo frame
```

Controller action between impacts:

```text
user action
  -> MiningController mutation accrues to action timestamp
  -> controller publishes/persists authoritative state
  -> MiningShell refreshes presentation
  -> all changes publish immediately except upward Landing Basin storedAmount
  -> next timer impact publishes the held accumulated cargo + impact sequence
```

Resume:

```text
MiningController.resume()
  -> deterministic elapsed accrual
  -> MiningShell publishes full authoritative state immediately
  -> no impactSequence increment
  -> offline summary may display
```

## Files expected to change

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
lib/mining/presentation/mining_shell.dart
lib/mining/presentation/mine_site_screen.dart
lib/mining/presentation/mining_visuals.dart
pubspec.yaml
test/mining/presentation/mining_shell_test.dart
test/mining/presentation/mine_site_screen_test.dart
test/mining/presentation/mining_visuals_test.dart
test/mining/presentation/visual_parity_golden_test.dart
CLAUDE.md
```

`AGENTS.md` is a repository-relative symlink to `CLAUDE.md`, so do not edit it separately.

Do not modify unless implementation uncovers a contradiction with this design:

```text
lib/mining/mining_content.dart
lib/mining/mining_state.dart
lib/mining/mining_controller.dart
lib/mining/mining_simulation.dart
lib/mining/mining_save_repository.dart
```

## Testing strategy

### Presentation publication

Use the existing injected `TestClock` and repository helpers to prove:

- an eligible Landing Basin timer callback publishes cargo and a new impact sequence together;
- a controller action can advance authoritative Landing Basin cargo without exposing that upward delta before the next timer impact;
- sale/cargo decrease still publishes immediately;
- deploy/recall/dock/busy changes still publish immediately without fabricating an impact;
- delayed multi-second accrual produces one impact with the complete accumulated delta;
- no-rig, unchanged-clock, closed-site, busy, and already-full cases emit no impact;
- leaving Landing Basin synchronizes held authoritative cargo without an impact;
- resume publishes accumulated cargo immediately without an impact replay;
- foreground refresh still does not save every second.

### Asset contract

Extend `mining_visuals_test.dart` to iterate all `RigTier` and `MiningNodeId` values, assert exact Landing Basin paths, and load all ten new PNGs through `rootBundle` in the existing host-only asset bundle test.

### Animation behavior

Widget tests use a fixed initial `impactSequence = 0`, then rebuild with `1` and pump key durations:

- contact frame at sequence change;
- recoil during the first 140 ms;
- stable recovery/end state at one second;
- same sequence does not restart;
- sequence jump produces one animation only;
- `rig == null` remains static;
- reduced motion has no spatial transform;
- tier/node changes resolve the correct assets;
- disposing the widget leaves no active ticker/test exception.

Test behavior and phase boundaries, not pixel-perfect easing.

### Layout/regression

Existing Mine Site tests remain authoritative for interaction and geometry. Add Landing Basin coverage without relaxing current assertions, especially:

- portrait node containment;
- landscape node placement;
- 667×375 occupied N3/N4 tap targets remain disjoint and contained;
- Sell control does not overlap N3;
- semantics, disabled reasons, deploy/recall callbacks, and tier badges remain intact.

Visual-parity goldens render the deterministic resting state (`impactSequence = 0`) rather than a wall-clock animation phase.

## Verification

Run focused tests during development, then the repository gates from `CLAUDE.md`:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

## Non-goals

Do not add in HPA-451:

- literal discrete-hit authoritative economy;
- production rate/capacity/sale/technology/offline-cap changes;
- per-rig production allocation;
- staggered or randomized robot phases;
- finite resources or depletion;
- animations or new assets for coal, stone, Lunar Frontier, Mars Frontier, or any non-gold site;
- generic resource/planet visual registries;
- animation/event frameworks;
- new state-management packages;
- save fields, versioning, migration, or compatibility machinery;
- Flame, Rive, Lottie, physics, audio, or haptics;
- unrelated Mine Site redesign.

## Acceptance criteria

- Landing Basin uses five authored robot-tier images and four deterministic N1–N4 gold-deposit variants plus one hit accent.
- Deployed Landing Basin robots visibly strike their gold deposits.
- The gold deposit itself visibly reacts at contact.
- While Landing Basin is visible, passive upward gold cargo/progress changes are published only on the same presentation update as robot/deposit contact.
- Controller actions may accrue authoritative production between hits without leaking that upward delta into the open Landing Basin presentation.
- Cargo decreases and non-production state changes remain immediate.
- The final filling hit may animate; a full site emits no further impacts.
- Cold-load/offline/resume production remains deterministic and is never replayed as historical strikes.
- Reduced-motion mode preserves contact confirmation without spatial motion.
- Non-gold sites remain on the existing static presentation.
- Existing Mine Site interaction, accessibility, responsive geometry, persistence behavior, and repository verification remain green.

## Delivery boundary

Exactly **one HPA-451 implementation PR**.

The implementation may use several small commits for TDD/reviewability, but do not split assets, pulse plumbing, animation, integration, tests, or documentation into separate Linear tickets or pull requests.