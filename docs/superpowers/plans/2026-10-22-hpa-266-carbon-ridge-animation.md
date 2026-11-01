# HPA-266 Carbon Ridge Animated Mining Site Implementation Plan

- Date: 2026-10-22; revalidated 2026-10-31
- Linear: [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site)
- Design: `docs/superpowers/specs/2026-10-22-hpa-266-carbon-ridge-animation-design.md`

## Delivery rule

**One ticket = one PR.** Reopen the existing closed/unmerged draft [#44](https://github.com/cwchanap/horologium/pull/44) instead of creating a duplicate. Its planning branch is refreshed from `main` at `f0578fb`; HPA-186 already merged the 15 coal frames through [#50](https://github.com/cwchanap/horologium/pull/50). This PR begins with the refreshed design and plan, then receives implementation commits **on the same branch and PR** after review. Recheck/rebase against latest `main` if it advances before implementation. No dedicated planning PR, new art, audio, or manifests.

## Task 1: Turn Carbon Ridge on

### Tests first

- `test/mining/presentation/mining_visuals_test.dart`:
  - the existing `for (final family in MiningDepositFrames.values)` path assertions cover `coal` once added; update both hard-coded family length assertions to loop all values and ensure 15 unique paths each;
  - the exhaustive closed-switch test expects `carbonRidge => MiningDepositFrames.coal`, with exactly the remaining nine sites staying static;
  - the existing host-only asset-decode test automatically verifies coal frames at 512×512 once the enum value exists;
  - extend the water-ice-only byte-copy test into a **single loop over animated site IDs**, checking S1/idle-01 against `content.site(id).depositAsset`, S3/exhaust-01, and S4/exhaust-04 (do not add three duplicate tests).
- `test/mining/presentation/animated_mining_grid_visual_layer_test.dart`: Carbon Ridge group mirroring Frozen Basin's cases (stage boundaries, idle/hit/exhaust, HP/labels, cold cache, reduced motion). Use a legal Surveying-0 Carbon Ridge rig cell and `carbon-ridge-…` keys. Prefer a small test-fixture reuse over another copy of the Frozen Basin fixture; avoid refactoring the production animation layer.
- `test/mining/presentation/mining_grid_map_test.dart`:
  - Carbon Ridge hosts `carbon-ridge-grid-visual-layer` and no static layer;
  - move "renders exactly 100 resource images on a static site", "dims unsurveyed resources…", "hosts the static object layer…", and "tiles the cavern background…" to `MiningSiteId.graniteCrater` (same `[0, 1, 2, 3]` progression levels, so only the site ID and comment change).
- `test/mining/presentation/mine_site_screen_test.dart`: "keeps non-gold sites on the static deposit and rig art" moves to Granite Crater.
- `test/mining/presentation/mining_shell_test.dart`: opening rigged Carbon Ridge and running one `pumpMiningTick` increments `MineSiteScreen.impactSequence`; with warm frames and visible contact, it requests `audio/mining.wav`. Mount/resume must not replay mining sound; full/unrigged or hidden sites must remain silent. Reuse the existing audio spy and timed-tick harness.

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

Planning (already present on this reopened draft PR, refreshed on current `main`):

- `docs/superpowers/specs/2026-10-22-hpa-266-carbon-ridge-animation-design.md`
- `docs/superpowers/plans/2026-10-22-hpa-266-carbon-ridge-animation.md`

Implementation (same PR, after review):

- `lib/mining/presentation/mining_visuals.dart`
- `test/mining/presentation/mining_visuals_test.dart`, `animated_mining_grid_visual_layer_test.dart`, `mining_grid_map_test.dart`, `mine_site_screen_test.dart`, `mining_shell_test.dart`
- `CLAUDE.md`, `docs/audio-assets.md`

The `node-coal-…` files are already on `main` through merged HPA-186 / PR #50 and must **not** appear in this PR's diff. Keep exactly one HPA-266 delivery PR and do not introduce new runtime state owners or a visual registry.
