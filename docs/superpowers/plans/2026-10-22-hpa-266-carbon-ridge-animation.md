# HPA-266 Carbon Ridge Animated Mining Site Implementation Plan

- Date: 2026-10-22
- Linear: [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site)
- Design: `docs/superpowers/specs/2026-10-22-hpa-266-carbon-ridge-animation-design.md`

## Delivery rule

One ticket = one PR. Planning lands first on this draft PR; implementation lands on the same PR after plan review **and after [HPA-186](https://linear.app/cwchanap/issue/HPA-186/mining-art-carbon-ridge-coal-animation-frames) merges**. Before Task 1, rebase onto `main` (no merge commit; force-push with lease) so the 15 `node-coal-…` files are present; the all-content-assets test loads every authored path.

This ticket generates no art.

## Task 1: Turn Carbon Ridge on

### Tests first

- `test/mining/presentation/mining_visuals_test.dart`:
  - `MiningDepositFrames.coal` maps every index to `node-coal-…`; `all` has 15 unique paths;
  - the closed-switch test expects `carbonRidge => MiningDepositFrames.coal`;
  - host-only: every coal frame decodes at 512×512; S1 and idle-01 equal `coal.png`, exhaust-01 equals S3, exhaust-04 equals S4 (copy the water-ice test's shape).
- `test/mining/presentation/animated_mining_grid_visual_layer_test.dart`: `group('Carbon Ridge', …)` mirroring the Frozen Basin group, built from a Carbon Ridge `MineSiteView` at Surveying 0 with one T1 rig on the level-0 resource.
- `test/mining/presentation/mining_grid_map_test.dart`:
  - Carbon Ridge hosts `carbon-ridge-grid-visual-layer` and no static layer;
  - move "renders exactly 100 resource images on a static site", "dims unsurveyed resources…", "hosts the static object layer…", and "tiles the cavern background…" to `MiningSiteId.graniteCrater` (same `[0, 1, 2, 3]` progression levels, so only the site ID and comment change).
- `test/mining/presentation/mine_site_screen_test.dart`: "keeps non-gold sites on the static deposit and rig art" moves to Granite Crater.
- `test/mining/presentation/mining_shell_test.dart`: opening rigged Carbon Ridge and running one `pumpMiningTick` increments `MineSiteScreen.impactSequence` and plays `audio/mining.wav` (warm `MiningDepositFrames.coal` first); resume emits nothing.

### Production

- `lib/mining/presentation/mining_visuals.dart`: add `coal('coal')` to `MiningDepositFrames`; add `MiningSiteId.carbonRidge => MiningDepositFrames.coal` and drop it from the `null` arm.

No other production change is expected. If one is needed, it is a generic bug in the shared layer and gets its own test.

```sh
flutter test test/mining/presentation
```

## Task 2: Docs and gates

- `CLAUDE.md`: "Landing Basin, Frozen Basin, and Carbon Ridge are the authored animated mining sites, selected by the closed `MiningVisuals.depositFramesFor` switch."
- `docs/audio-assets.md`: the mining row becomes "Visible strike on an animated site (Landing Basin, Frozen Basin, Carbon Ridge) at 46% of its animation".
- Mark the design `- Status: Implemented`.

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

## Expected changed paths

Planning (this draft PR as opened):

- `docs/superpowers/specs/2026-10-22-hpa-266-carbon-ridge-animation-design.md`
- `docs/superpowers/plans/2026-10-22-hpa-266-carbon-ridge-animation.md`

Implementation (same PR, after review):

- `lib/mining/presentation/mining_visuals.dart`
- `test/mining/presentation/mining_visuals_test.dart`, `animated_mining_grid_visual_layer_test.dart`, `mining_grid_map_test.dart`, `mine_site_screen_test.dart`, `mining_shell_test.dart`
- `CLAUDE.md`, `docs/audio-assets.md`

The `node-coal-…` files arrive from `main` through HPA-186 and are not part of this PR's diff.
