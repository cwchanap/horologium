# HPA-451 Hit-Synchronized Gold Mine Animation Design

## Status

Approved implementation design for Linear HPA-451, **Ship hit-synchronized gold mine animation and visual variety**.

Planning, implementation, review, and verification stay on **one branch and one pull request**. This design is intentionally limited to one authored resource site: `MiningSiteId.landingBasin`.

This revision is grounded on `main` commit `b00e0bcaa3bc4c77e5ae0ebdb0d6c83e51aeaee3` and incorporates the first planning review of draft PR #22.

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
- `MineSiteView.from(...)` as the one projection boundary for Mine Site display and interaction state;
- `MineSiteScreen` and its existing responsive cavern/node composition;
- `MiningVisuals` for authored presentation paths;
- `MiningNodeId`, `RigTier`, and `MiningSiteId` as closed identities;
- the existing injected `TestClock`, `CountingMiningSaveRepository`, `deployedLandingBasin`, `deployedLandingState`, and `pumpShell` test fixtures.

The current Mine Site renders one site-wide `nodeAsset` and one shared rig image per `RigTier`. Landing Basin currently points at `assets/images/mining/nodes/gold.png`; deployed rigs use `assets/images/mining/rigs/t1.png` through `t5.png`.

Do not add a second controller, simulation, repository, timer, or persisted animation state.

## Selected architecture

### 1. Keep `_displayState` authoritative; hold only one visible cargo number

The production model does not change.

`MiningController.refresh()` and every existing mutation continue to accrue authoritative state to the supplied UTC clock. Offline, resume, cold-load, action ordering, persistence, rates, capacity, recall legality, sale values, and selling semantics remain unchanged.

The new rule is narrower than a projected/fake `MiningSave`:

> While Landing Basin is open, only the **visible Landing Basin cargo/progress amount** may lag authoritative cargo until an eligible foreground impact pulse.

`MiningShell` keeps:

```dart
MiningSave _displayState;                // authoritative presentation snapshot
int _landingBasinImpactSequence = 0;     // transient animation trigger
double _landingBasinVisibleCargo = 0;    // visual-only cargo/progress overlay
```

`_displayState` continues to copy `_controller.state` on every presentation refresh. Do **not** clone a `MiningSave` with a fake `storedAmount`.

This keeps all interaction/value calculations honest while allowing the gold gauge and node progress bars to wait for contact.

### 2. Use one pure function for the hold/decrease/flush rule

Extract one top-level presentation helper in `mining_shell.dart`:

```dart
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

The table is deliberately small:

| Situation | Visible cargo result |
| --- | --- |
| Landing Basin open, authoritative cargo rose, ordinary refresh | hold previous visible cargo |
| Landing Basin open, authoritative cargo decreased | publish decrease immediately |
| Landing Basin open, eligible impact | publish authoritative cargo |
| Landing Basin closed / another site open | publish authoritative cargo |
| cold-load / resume explicit flush | publish authoritative cargo |

This helper has no dependency on widget state, timers, repositories, or controller methods. Unit tests prove the table directly; shell widget tests only prove wiring/timing.

### 3. `MineSiteView` separates visual cargo from authoritative interaction state

Extend `MineSiteView.from(...)` with one optional override:

```dart
static MineSiteView from({
  required MiningSave state,
  required MiningContentRegistry content,
  required MiningSiteId siteId,
  required DockBayId? selectedBayId,
  required bool isBusy,
  double? visibleCargo,
})
```

`state` is always authoritative.

Inside the factory:

```dart
final progress = state.sites[siteId]!;
final displayedCargo = visibleCargo ?? progress.storedAmount;
```

Only this field uses `displayedCargo`:

```dart
cargo: displayedCargo,
```

Everything that affects player decisions or monetary value remains derived from authoritative `progress.storedAmount` / authoritative active-planet site progress:

- `projectedSale`;
- `activePlanetCargo`;
- `activePlanetProjectedSale`;
- `canSell`;
- `hasUnsellableCargo` inputs;
- recall capacity comparison;
- `canRecall`;
- node `disabledReason`;
- deploy legality;
- rig assignments;
- capacity/rate/technology state.

Therefore a held visual delta can never make the Sell label disagree with the cash actually paid, and it can never make a recall button appear legal when the controller will reject it.

`MiningShell.build` supplies the override only for Landing Basin:

```dart
MineSiteView.from(
  state: _displayState,
  content: _content,
  siteId: siteId,
  selectedBayId: _selectedBayId,
  isBusy: _controller.isBusy,
  visibleCargo: siteId == MiningSiteId.landingBasin
      ? _landingBasinVisibleCargo
      : null,
)
```

The Site Deck and Stellar Map continue to use authoritative `_displayState` with no overlay.

### 4. Use the existing one-second timer as the impact publication clock

On each existing timer callback:

1. skip when the controller is busy, preserving current behavior;
2. capture `_landingBasinVisibleCargo`;
3. call `MiningController.refresh()` exactly once;
4. read authoritative Landing Basin `storedAmount` and current rig assignment;
5. if Landing Basin is open, at least one rig is deployed, and authoritative cargo is greater than visible cargo, increment `_landingBasinImpactSequence`;
6. refresh presentation with `publishUpwardLandingCargo: true` only for that impact;
7. publish authoritative `_displayState`, the visible cargo flush, and the new sequence in the same `setState`.

A delayed timer callback may publish several elapsed seconds of production in one strike. Missed foreground strikes are not replayed.

The final production update that reaches capacity may emit one impact because cargo increased. Subsequent callbacks have no upward delta and emit no impact.

### 5. Mutation behavior stays explicit

Controller mutations remain authoritative and persist exactly as they do now.

While Landing Basin is open:

- spawn/deploy/technology/unlock and other non-sell/non-recall mutations may accrue production, but an upward cargo delta remains visually held until the next impact;
- a sale publishes the authoritative decrease immediately and does not increment `_landingBasinImpactSequence`;
- a successful recall explicitly flushes `_landingBasinVisibleCargo` to authoritative cargo without incrementing the sequence, so removing the final rig cannot strand hidden cargo indefinitely;
- recall legality, disabled reason, and Sell value are authoritative even while the visible gauge is held.

A narrow optional flag on the existing shell action helper is sufficient for the recall flush. Do not add an event bus or mutation classification framework.

### 6. Initialization, resume, and exit paths flush without strike replay

Initialization and lifecycle resume keep their existing deterministic accrual behavior.

They publish authoritative Landing Basin cargo immediately **without** incrementing `_landingBasinImpactSequence`.

Exiting the Mine Site also flushes the visual overlay without an impact:

- Back to Site Deck;
- bottom navigation to Stellar Map / another primary surface.

Because `_displayState` remains authoritative, Site Deck/Stellar Map totals are always real. The explicit overlay flush keeps the next Landing Basin entry aligned with those totals.

Therefore:

- cold launch never replays historical strikes;
- returning from background never replays historical strikes;
- entering Landing Basin shows current cargo but never fabricates a hit;
- leaving Landing Basin cannot leave stale cargo on another primary surface;
- re-entering starts from the current authoritative amount with the same unchanged impact sequence.

### 7. Add one authored Landing Basin asset family

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
- `impact.png` is a small spark/chip/fragment accent readable at current node sizes.

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

Do not add string resource IDs, random variants, persisted variant state, or a generic resource visual registry.

### 8. One node-local animation owner synchronizes robot and resource

Use one focused stateful widget:

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

The widget owns one `AnimationController` with a one-second duration. It does not own a timer and never calls `MiningController`.

For unlocked Landing Basin nodes:

- `rig == null`: render the deterministic `deposit_nX.png` with the current subdued no-rig treatment;
- `rig != null`: render the deposit and tier-specific robot together;
- a new `impactSequence` starts exactly one animation;
- rebuilding with the same sequence does not restart;
- a sequence jump greater than one still plays one strike rather than replaying missed impacts.

Suggested choreography:

```text
0 ms        contact; deposit compresses/flashes; impact accent visible
0–140 ms    robot recoils; deposit settles
140–700 ms  robot recovers / winds up
700–1000 ms robot approaches the deposit
```

The widget reproduces the current deposit + 2 px gap + robot/tier-badge composition. Transforms occur inside fixed child bounds; width, height, padding, Row/Column size, and the outer tap target never animate.

Locked nodes continue using `_LockedNode`.

### 9. Reduced motion keeps contact semantics without spatial motion

`MediaQuery.disableAnimations` remains the sole source of truth and is still propagated from `MiningShell`.

When reduced motion is enabled:

- do not translate, rotate, shake, or continuously animate robot/deposit;
- render stable robot/deposit poses;
- on a new impact sequence, permit only a brief non-spatial opacity/brightness confirmation and/or the static `impact.png` accent;
- publish cargo/progress on the exact same impact update as normal motion.

Reduced motion changes presentation only, never economy cadence.

### 10. Keep Mine Site geometry and chrome unchanged

Add `impactSequence` to `MineSiteScreen`, defaulting to `0`, and thread it through the existing private composition the same way `reducedMotion` is already threaded.

`_MineNodeButton` chooses one narrow visual branch:

- Landing Basin unlocked node: `LandingBasinMiningNodeVisual`;
- every other unlocked site: existing `nodeAsset + MiningVisuals.rigAsset(...)` presentation;
- locked node: existing `_LockedNode`.

Preserve unchanged:

- outer `Semantics`;
- `InkWell` and `mine-site-node-${id.name}` key;
- disabled-reason forwarding;
- tier badge styling/spacing;
- site progress bar geometry;
- deploy/recall callbacks;
- portrait anchors;
- landscape anchors;
- special 667×375 occupied N3/N4 containment/overlap behavior;
- Sell control geometry.

No generic widget factory is needed for one special site.

## Data flow

### Normal visible impact

```text
Timer.periodic(1s)
  -> MiningShell captures visible Landing Basin cargo
  -> MiningController.refresh()
  -> MiningSimulation accrues authoritative elapsed-time production
  -> authoritative _displayState is refreshed
  -> authoritative cargo > visible cargo + rig deployed + Landing Basin open
  -> impactSequence++
  -> visible cargo flushes to authoritative in the same setState
  -> MineSiteView.from(authoritative state, visibleCargo: flushed value)
  -> gauge/progress jump + robot/deposit contact begin together
```

### Controller action between impacts

```text
user action
  -> controller mutation accrues/persists authoritative state
  -> MiningShell copies authoritative state immediately
  -> MineSiteView interaction/value fields use authoritative state
  -> visible cargo overlay holds only an upward Landing Basin delta
  -> next timer impact publishes that visible cargo delta
```

### Sell while cargo is held

```text
authoritative cargo > visible cargo
  -> Sell label/canSell use authoritative activePlanetProjectedSale
  -> controller sells authoritative cargo
  -> visible cargo immediately decreases to 0
  -> snackbar revenue matches the pre-tap Sell value
  -> no impactSequence increment
```

### Recall while cargo is held

```text
authoritative cargo > visible cargo
  -> canRecall/disabledReason use authoritative cargo
  -> UI legality matches controller legality
  -> successful recall flushes visible cargo without a mining impact
```

### Exit / resume

```text
Back / Stellar Map / resume
  -> authoritative state remains unchanged
  -> visible Landing Basin cargo flushes to authoritative
  -> impactSequence stays unchanged
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
lib/mining/mine_site_view.dart
lib/mining/presentation/mining_shell.dart
lib/mining/presentation/mine_site_screen.dart
lib/mining/presentation/mining_visuals.dart
pubspec.yaml
test/mining/mine_site_view_test.dart
test/mining/presentation/mining_shell_test.dart
test/mining/presentation/mine_site_screen_test.dart
test/mining/presentation/mining_visuals_test.dart
test/mining/presentation/visual_parity_golden_test.dart
CLAUDE.md
```

`AGENTS.md` is a repository-relative symlink to `CLAUDE.md`; do not edit it separately.

Do not modify unless implementation uncovers a contradiction with this design:

```text
lib/mining/mining_content.dart
lib/mining/mining_state.dart
lib/mining/mining_controller.dart
lib/mining/mining_simulation.dart
lib/mining/mining_save_repository.dart
```

## Testing strategy

### Pure visible-cargo projection

Unit-test `projectLandingBasinVisibleCargo(...)` without pumping the shell:

- hold an upward delta while Landing Basin is open;
- publish a decrease immediately;
- publish authoritative cargo on an impact flush;
- publish authoritative cargo when Landing Basin is closed / another site is open.

### View-model separation

Extend `mine_site_view_test.dart` to prove that `visibleCargo` affects only `view.cargo` while:

- `activePlanetProjectedSale` remains authoritative;
- `canSell` remains authoritative;
- `projectedSale` remains authoritative;
- `canRecall` and recall `disabledReason` remain authoritative.

### Shell integration

Use the existing injected fixtures to prove:

- an eligible timer callback publishes visible cargo and a new impact sequence together;
- a controller action advances authoritative cargo without moving visible cargo before the impact;
- **sell while held:** displayed Sell value equals the eventual `Sold N cash.` result;
- **recall while held near post-recall capacity:** the visible enabled/disabled state matches the tap/controller result;
- successful recall flushes held cargo without a mining impact;
- delayed multi-second accrual produces one impact with the complete accumulated delta;
- no-rig, unchanged-clock, busy, and already-full cases emit no impact;
- Back to Site Deck flushes held cargo without an impact;
- bottom navigation to Stellar Map flushes held cargo without an impact;
- resume publishes accumulated cargo immediately without replaying an impact;
- foreground refresh still does not save every second.

### Animation behavior

Widget tests use a fixed initial `impactSequence = 0`, then rebuild with `1` and pump key durations:

- contact frame at sequence change;
- recoil during the first 140 ms;
- stable end state at one second;
- same sequence does not restart;
- sequence jump produces one animation only;
- `rig == null` remains static;
- reduced motion has no spatial transform;
- tier/node changes resolve the correct assets;
- disposal leaves no active ticker/test exception.

Test behavior and phase boundaries, not pixel-perfect easing.

### Layout/regression

Existing Mine Site tests remain authoritative. Add Landing Basin coverage without relaxing current assertions, especially:

- portrait node containment;
- landscape node placement;
- 667×375 occupied N3/N4 tap targets remain disjoint and contained;
- Sell control does not overlap N3;
- semantics, disabled reasons, deploy/recall callbacks, and tier badge spacing remain intact.

Visual-parity goldens render `impactSequence = 0` / reduced motion so they capture a deterministic resting pose.

## Risks and mitigations

### Display / interaction desynchronization

**Risk:** visible cargo intentionally lags authoritative cargo, so using the visible number for Sell value or recall legality would create contradictory UI/controller behavior.

**Mitigation:** `_displayState` stays authoritative; `MineSiteView.visibleCargo` overrides only `cargo`. Explicit unit and shell tests cover sell-while-held and recall-while-held.

### Golden platform behavior

**Risk:** Mine Site goldens run on Linux but are skipped on macOS; authored image changes may require intentional Linux golden updates.

**Mitigation:** keep direct golden fixtures at `impactSequence = 0` and reduced motion; regenerate only the two Mine Site goldens on Linux and reject geometry drift.

### New PNG footprint/style consistency

**Risk:** ten new images can change effective node width/visual balance even when widget dimensions are unchanged.

**Mitigation:** use consistent 512×512 transparent canvases, camera/lighting/facing direction, central subject bounds, and similar deposit footprint; run existing 402×874 and 667×375 geometry tests before accepting goldens.

### Timer-alignment test fragility

**Risk:** `pumpShell` advances fake time during initialization, making exact timer wiring tests sensitive to pump duration.

**Mitigation:** prove the hold/flush/decrease truth table with the pure function and use shell tests only for impact sequencing and concrete action/navigation wiring.

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
- staggered/randomized robot phases;
- finite resources/depletion;
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
- `_displayState`, Sell value, Sell legality, recall legality, and disabled reasons remain authoritative while visible cargo is held.
- Sell-while-held pays exactly the amount displayed before the tap.
- Recall-while-held exposes the same legality/reason as the controller action.
- Successful recall, Back, Stellar Map navigation, cold-load, and resume can flush visible cargo without fabricating a mining impact.
- The final filling hit may animate; a full site emits no further impacts.
- Reduced-motion mode preserves contact confirmation without spatial motion.
- Non-gold sites remain on the existing static presentation.
- Existing Mine Site interaction, accessibility, responsive geometry, persistence behavior, and repository verification remain green.

## Delivery boundary

Exactly **one HPA-451 implementation PR**.

The implementation may use several small commits for TDD/reviewability, but do not split assets, pulse plumbing, animation, integration, tests, or documentation into separate Linear tickets or pull requests.