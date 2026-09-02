# HPA-451 Hit-Synchronized Gold Mine Animation Design

## Status

Approved implementation design for Linear HPA-451, **Ship hit-synchronized gold mine animation and visual variety**.

Planning, implementation, review, and verification stay on **one branch and one pull request**. The feature remains intentionally limited to one authored resource site: `MiningSiteId.landingBasin`.

This revision is grounded on `main` commit `b00e0bcaa3bc4c77e5ae0ebdb0d6c83e51aeaee3` and incorporates the first two planning reviews of draft PR #22.

## Goal

Make passive foreground production at Landing Basin read as a physical mining event:

```text
one-second foreground refresh
  -> authoritative cargo increases
  -> robot reaches contact
  -> gold deposit reacts
  -> cargo/progress update is visible on that same rebuild
  -> robot recoils, winds up, and approaches the next hit
```

At the same time, increase the visual variety of the gold site with five robot-tier images and four deterministic gold-deposit variants.

The underlying economy remains deterministic elapsed-time production. Animation presents authoritative results; it never owns, delays, or calculates them.

## Current reusable baseline

Keep the established ownership path:

```text
MainMenu
  -> MiningShell
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
      -> Site Deck / Mine Site / Stellar Map
```

Reuse rather than recreate:

- `MiningShell` as the sole owner of the one-second foreground timer, `_displayState`, lifecycle, navigation, and reduced-motion propagation;
- `MiningController.refresh()` as the in-memory foreground accrual seam;
- existing controller mutations, which accrue to their injected-clock timestamp before mutating/persisting;
- `MiningSimulation` as the pure elapsed-time economy source of truth;
- `MineSiteView.from(...)` unchanged as the current authoritative view-model projection;
- `MineSiteScreen` and its existing responsive cavern/node composition;
- `MiningVisuals.rigAsset(...)` as the narrow asset-mapping pattern;
- `MiningNodeId`, `RigTier`, and `MiningSiteId` as closed identities;
- the existing injected `TestClock`, `CountingMiningSaveRepository`, `deployedLandingBasin`, `deployedLandingState`, and `pumpShell` fixtures.

The current Mine Site renders one site-wide `nodeAsset` and one shared rig image per `RigTier`. Landing Basin currently uses `assets/images/mining/nodes/gold.png`, while deployed rigs use `assets/images/mining/rigs/t1.png` through `t5.png`.

`MiningVisuals.mergeBurst` already maps `assets/images/mining/effects/merge_burst.png`. Code search shows that asset is bundle-tested but not rendered anywhere in `lib/`. It is therefore the first reuse candidate for the mining-contact accent.

## Selected architecture

### 1. Add only one new shell state value

Do not add a visible-cargo overlay, projected `MiningSave`, alternate Mine Site cargo field, or mutation-flush classification.

`MiningShell` adds exactly:

```dart
int _landingBasinImpactSequence = 0;
```

`_displayState` remains exactly what it is today: the latest authoritative `_controller.state` published by `_refreshPresentation()`.

This removes the possibility of a frozen cargo number disagreeing with projected sale value, Sell semantics, recall legality, or controller actions.

### 2. Reuse the existing one-second timer as the passive impact clock

Replace only the timer callback body with a focused foreground-production method:

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

The existing timer remains the only clock:

```dart
Timer.periodic(const Duration(seconds: 1), ...)
```

The timer still calls `MiningController.refresh()` exactly once. The authoritative cargo update and the `impactSequence` increment are published in the same shell rebuild, so the animation begins at the already-updated cargo frame.

A delayed callback may accrue several elapsed seconds but still produces one impact sequence increment. Missed foreground strikes are not replayed.

The final callback that reaches capacity may increment once; later callbacks do not because cargo no longer rises.

### 3. Deliberately scope synchronization to passive foreground production

User-initiated controller actions remain unchanged. Spawn, merge, deploy, recall, technology, sale, and other mutations may accrue authoritative production to their action timestamp and publish it with the action response.

Do **not** fabricate an additional mining strike for those mutations and do not delay their state behind animation.

This is the explicit KISS boundary for HPA-451:

> Passive one-second foreground production is synchronized with the robot/deposit hit. User-initiated mutation results remain authoritative and immediate.

Cold-load and lifecycle resume also publish deterministic elapsed-time accrual immediately and do not increment `impactSequence` or replay historical strikes.

### 4. Thread one transient sequence; keep one Landing Basin gate

Add `impactSequence` to `MineSiteScreen`, defaulting to `0` so direct fixtures and goldens are deterministic.

`MiningShell` passes the counter unconditionally:

```dart
impactSequence: _landingBasinImpactSequence,
```

Thread it through the existing private composition the same way `reducedMotion` is already threaded:

```text
MineSiteScreen
  -> _PortraitMineSite / _LandscapeMineSite
  -> _CavernScene
  -> _MineCavern
  -> _MineNodeButton
```

Only `_MineNodeButton` decides whether it matters:

- Landing Basin unlocked node -> `LandingBasinMiningNodeVisual`;
- every other unlocked site -> existing `nodeAsset + MiningVisuals.rigAsset(...)` Row;
- locked node -> existing `_LockedNode`.

Do not duplicate the `siteId == MiningSiteId.landingBasin` gate in `MiningShell`.

### 5. One node-local animation owner synchronizes robot and resource

Add one focused stateful widget:

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

It owns exactly one `AnimationController` with a one-second duration. It has no timer, controller, repository, or economy dependency.

For unlocked Landing Basin nodes:

- `rig == null`: render the deterministic deposit variant with the existing subdued no-rig treatment;
- `rig != null`: render deposit + tier-specific robot in the existing Row footprint;
- a new sequence starts exactly one animation;
- the same sequence does not restart;
- a jump greater than one still plays one strike, with no replay of missed impacts.

Suggested choreography:

```text
0 ms        contact; deposit compresses/flashes; contact accent visible
0–140 ms    robot recoils; deposit settles
140–700 ms  robot recovers / winds up
700–1000 ms robot approaches the deposit
```

The controller rests at its end value. Transforms occur inside fixed child bounds; width, height, padding, Row/Column size, and outer tap geometry never animate.

### 6. Prototype the art footprint before producing the full family

Do not author the whole asset family before any asset is rendered.

First prove one vertical visual pair:

```text
robot_t1.png
deposit_n1.png
```

Wire that pair through the real Landing Basin node composition and verify the existing 402×874 and 667×375 geometry/tap-target gates.

Before authoring a dedicated `impact.png`, render the existing unused `MiningVisuals.mergeBurst` over the N1 prototype at the intended small contact size. Reuse it if all are true:

- reads as a compact mining contact rather than a merge-specific symbol;
- remains legible at the node's actual rendered size;
- does not obscure the deposit/robot silhouette;
- works in both normal and reduced-motion presentation.

Only create `assets/images/mining/landing_basin/impact.png` if that reuse check fails. Do not create two equivalent contact-effect assets.

After the prototype footprint is proven, author the remaining robot/deposit family:

```text
robot_t2.png ... robot_t5.png
deposit_n2.png ... deposit_n4.png
```

Final robot rules:

- same orientation and ground line;
- one progression family;
- higher tiers gain visible machinery/tooling, not only recolor;
- readable at current `rigSize` values.

Final deposit rules:

- clearly gold-bearing rock from one Landing Basin environment;
- distinct silhouettes/veins;
- similar occupied footprint at current `nodeSize` values.

### 7. Narrow asset mappings only

Use naming helpers, following `rigAsset(...)`:

```dart
static String landingBasinRobotAsset(RigTier tier) =>
    'assets/images/mining/landing_basin/robot_${tier.name}.png';

static String landingBasinDepositAsset(MiningNodeId nodeId) =>
    'assets/images/mining/landing_basin/deposit_${nodeId.name}.png';
```

For the contact accent:

- reuse `MiningVisuals.mergeBurst` when the prototype check passes; or
- add one `landingBasinImpact` constant only when a dedicated asset is required.

Add one manifest directory for the Landing Basin robot/deposit images:

```yaml
- assets/images/mining/landing_basin/
```

No generic resource visual registry, string resource identity, randomized variant, or persisted variant state.

### 8. Reduced motion stays presentation-only

`MediaQuery.disableAnimations` remains the sole source of truth.

With reduced motion:

- no robot/deposit translation, rotation, shake, or continuous spatial motion;
- stable robot/deposit poses;
- a brief non-spatial opacity/brightness/contact-accent confirmation may appear on a new sequence;
- economy and one-second foreground refresh behavior are unchanged.

### 9. Keep Mine Site geometry and chrome unchanged

Preserve the existing outer structure:

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

The Landing Basin widget reproduces the current deposit + 2 px gap + robot/tier-badge layout. Do not restyle the badge or chrome.

Preserve unchanged:

- semantics and disabled-reason forwarding;
- `mine-site-node-${id.name}` keys;
- deploy/recall callbacks;
- progress bar geometry;
- portrait positions;
- landscape positions;
- Sell control geometry;
- special 667×375 occupied N3/N4 containment/overlap behavior.

## Data flow

Passive foreground production:

```text
Timer.periodic(1s)
  -> capture authoritative Landing Basin cargo before refresh
  -> MiningController.refresh()
  -> MiningSimulation accrues deterministic elapsed-time production
  -> if Landing Basin open + rig deployed + cargo rose:
       impactSequence++
  -> _refreshPresentation() publishes authoritative state
  -> MineSiteScreen rebuilds with same sequence update
  -> LandingBasinMiningNodeVisual starts at contact
```

User action between timer ticks:

```text
user action
  -> existing controller mutation accrues/mutates/persists
  -> existing shell presentation refresh publishes authoritative result
  -> no synthetic mining impact is added
```

Resume:

```text
MiningController.resume()
  -> deterministic elapsed accrual
  -> authoritative presentation publishes immediately
  -> impactSequence unchanged
  -> no historical strike replay
```

## Files expected to change

Create:

```text
lib/mining/presentation/landing_basin_mining_node_visual.dart
assets/images/mining/landing_basin/robot_t1.png ... robot_t5.png
assets/images/mining/landing_basin/deposit_n1.png ... deposit_n4.png
test/mining/presentation/landing_basin_mining_node_visual_test.dart
```

Conditionally create only if `mergeBurst` fails the prototype reuse check:

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

## Testing strategy

### Shell sequence wiring

Use sequence **deltas**, not absolute values coupled to `pumpShell`'s timer phase.

Add a small test helper that advances the injected clock and pumps one timer interval. Cover only the behavior that belongs in the shell:

- an open Landing Basin with a deployed rig and a real passive cargo increase increments sequence exactly once and publishes the cargo increase;
- delayed multi-second accrual still increments once for one timer callback;
- closed Landing Basin / no rig / already-full cargo does not increment;
- foreground refresh still does not persist per second;
- lifecycle resume publishes cargo without incrementing sequence.

Do not add sell-while-held, recall-while-held, overlay-flush, or `MineSiteView.visibleCargo` tests because that state layer does not exist.

### Animation component

Test:

- deterministic rest at initial sequence;
- new sequence enters contact/recoil;
- same sequence does not restart;
- sequence jump produces one animation;
- empty node remains static;
- reduced motion has no spatial transform;
- disposing leaves no active ticker/test exception;
- fixed external bounds across animation phases.

### Asset/geometry proof

Before bulk asset generation:

- render T1/N1 in the real node composition;
- evaluate `mergeBurst` reuse at target size;
- run 402×874 Mine Site layout assertions;
- run 667×375 occupied N3/N4 disjoint/contained assertions.

After bulk assets:

- exhaustive path checks for all `RigTier` and `MiningNodeId` values;
- root-bundle loads for all final new files;
- normal Mine Site screen tests;
- Linux Mine Site goldens at deterministic `impactSequence: 0` + reduced motion.

## Risks and mitigations

### Asset footprint drift

New art can change perceived or actual node footprint. Mitigation: prove T1/N1 in the real component before generating the remaining family; reject assets that require geometry changes.

### Golden platform dependence

Mine Site goldens are skipped on macOS. Mitigation: keep structural geometry tests authoritative on all hosts and regenerate intended Mine Site goldens only on Linux.

### Timer-phase brittleness in tests

`pumpShell` consumes fake time during initialization. Mitigation: use a tick helper plus before/after sequence deltas instead of absolute sequence values tied to fractional pumps.

### Existing contact-effect suitability

`mergeBurst` is unused but may visually encode merging rather than impact. Mitigation: render it at the actual contact size before reuse; create one dedicated asset only if it fails the stated criteria.

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

Keep the executable domain/save scope guard:

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

## Non-goals

Do not add in HPA-451:

- literal discrete-hit authoritative economy;
- a second presentation cargo state;
- mutation-specific cargo flush/classification plumbing;
- production rate/capacity/sale/technology/offline-cap changes;
- per-rig production allocation or staggered robot phases;
- finite resources or depletion;
- animated rollout to non-gold sites;
- generic resource/planet visual registries;
- save fields, versioning, migration, or compatibility machinery;
- Flame, Rive, Lottie, physics, audio, or new haptics;
- unrelated Mine Site redesign.

## Acceptance criteria

- Landing Basin uses five authored robot-tier images and four deterministic gold-deposit variants.
- The existing `mergeBurst` is reused for contact if it passes the real-size prototype check; otherwise exactly one dedicated hit asset is added.
- Passive foreground Landing Basin cargo/progress increases and robot/deposit contact are published by the same one-second shell callback.
- Deployed Landing Basin robots visibly strike their gold deposits; the deposit visibly reacts at contact.
- One delayed foreground callback produces one strike, not replayed ticks.
- Final fill may strike once; a full site produces no further impacts.
- Cold-load/resume production remains deterministic and is never replayed as strikes.
- User-initiated mutation results remain authoritative/immediate and do not create synthetic mining impacts.
- Reduced-motion mode preserves contact confirmation without spatial movement.
- Non-gold sites remain on the existing static presentation.
- Existing Mine Site interaction, accessibility, responsive geometry, persistence, and repository verification remain green.

## Delivery boundary

Exactly **one HPA-451 implementation PR**. Use small commits for TDD/reviewability, but do not split assets, pulse wiring, animation, integration, tests, or documentation into separate Linear tickets or pull requests.
