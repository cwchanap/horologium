# HPA-451 Task 3 Report

## Implementation

Created `LandingBasinMiningNodeVisual`, a stateful Flutter component for one
Landing Basin mining node. It owns one `AnimationController` with a one-second
duration and an initial resting value of `1`. A changed `impactSequence` starts
one forward animation; rebuilding with the same sequence does not restart it,
and sequence jumps replay only once. A missing rig stops and resets the
animation and removes robot/contact feedback.

The component renders the fixed-size deposit/robot row contract with the
existing tier badge styling. Robot translation, deposit scale, and contact
opacity use the exact phase values from the brief. Reduced motion fixes the
robot and deposit spatial transforms while retaining the non-spatial contact
fade. The impact uses `MiningVisuals.mergeBurst`; no dedicated impact asset or
integration changes were added.

## Files changed

- `lib/mining/presentation/landing_basin_mining_node_visual.dart`
- `test/mining/presentation/landing_basin_mining_node_visual_test.dart`
- `.superpowers/sdd/2026-09-01-hpa-451-gold-mine-animation/task-3-report.md`

## TDD evidence

RED, before the production component existed:

```text
$ flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
Error when reading 'lib/mining/presentation/landing_basin_mining_node_visual.dart': No such file or directory
Method not found: 'LandingBasinMiningNodeVisual'.
Undefined name 'LandingBasinMiningNodeVisual'.
Compilation failed ... landing_basin_mining_node_visual_test.dart
```

GREEN, after the minimal implementation:

```text
$ flutter test test/mining/presentation/landing_basin_mining_node_visual_test.dart
00:00 +0: renders stable N1/T1 roots and omits rig feedback without a rig
00:00 +1: plays one one-second contact sequence and does not restart same sequence
00:00 +2: reaches the authored robot and deposit phase endpoints
00:00 +3: reduced motion keeps spatial transforms and bounds fixed
00:00 +4: disposes the animation controller when the visual is removed
00:00 +5: All tests passed!
```

Additional verification:

```text
$ dart format --output=none --set-exit-if-changed \
    lib/mining/presentation/landing_basin_mining_node_visual.dart \
    test/mining/presentation/landing_basin_mining_node_visual_test.dart
Formatted 2 files (0 changed) in 0.01 seconds.

$ flutter analyze --fatal-infos
No issues found! (ran in 1.5s)
```

## Self-review

- One controller only; no timer, controller, repository, economy, or save dependency.
- Stable keyed deposit/robot roots and conditional contact feedback are covered.
- Literal 0.14, 0.70, and 1.00 robot phases; 0.14 deposit phase; 0.18 contact fade are covered.
- Reduced-motion matrix and root-size invariants are covered.
- Controller disposal is covered by removing the component during playback.
- Task 4 integration was intentionally left untouched.

## Concerns

The branch currently contains authored Landing Basin art for N1/T1 only. The
component accepts the closed enum types and resolves the existing helper paths,
but Task 4 should keep use of the authored visual to those available assets or
add the separately approved assets/fallback before rendering other combinations.
