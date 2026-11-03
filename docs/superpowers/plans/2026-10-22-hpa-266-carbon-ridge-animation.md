# HPA-266 Carbon Ridge Animated Mining Site Implementation Plan

- Date: 2026-10-22; revalidated 2026-10-31
- Linear: [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site)
- Design: `docs/superpowers/specs/2026-10-22-hpa-266-carbon-ridge-animation-design.md`

## Delivery rule

One ticket = **one PR**. [PR #44](https://github.com/cwchanap/horologium/pull/44) is **open** and carries this plan, the design spec, and the implementation; it was refreshed on `main` at `f0578fb` after HPA-186's art merged in [PR #50](https://github.com/cwchanap/horologium/pull/50). No second planning/implementation PR, no new art or SFX.

The 2026-10-31 plan review identified unnecessary per-site test duplication and a geometry-sensitive static fixture. The revised test plan below reuses the existing animated-site suites and derives site-specific facts from their actual definitions.

## Task 1: Turn Carbon Ridge on

### Tests first

1. `test/mining/presentation/mining_visuals_test.dart`: reuse the existing `MiningDepositFrames.values` path and bundle-decode loops. Make the 15-unique-path assertion cover all enum values, update the exhaustive switch expectation (`carbonRidge => coal`, nine sites still static), rename the stale two-site test, and generalize the host-only water-ice byte-copy test to a **single loop over all animated site IDs** with S1/idle-01, S3/exhaust-01 and S4/exhaust-04 equality checks.
2. `test/mining/presentation/animated_mining_grid_visual_layer_test.dart`: replace Frozen Basin-specific fixture helpers with site-ID-parameterized helpers, then iterate **non-Landing animated sites** from `MiningSiteId.values.where((id) => id != MiningSiteId.landingBasin && MiningVisuals.depositFramesFor(id) != null)`. Derive the correct Surveying level, `firstPlayableCell(site)` from `test/support/mining_grid_fixtures.dart`, mined deposit via `uniqueAdjacentDeposit`, frame family via `depositFramesFor(id)!`, and prefix via `siteKeyPrefix(id)`. Run the existing six Frozen Basin cases for both Frozen Basin and Carbon Ridge; keep Landing Basin's detailed tests intact. **No third suite or copied test bodies.**
3. `test/mining/presentation/mining_grid_map_test.dart`: define `const _staticSite = MiningSiteId.graniteCrater` and move the four existing Carbon Ridge static checks to it. The static layer's deposit key must be built from `view.deposits.first.definition` because Granite Crater's generated coordinates differ from Carbon Ridge's. Iterate the animated IDs to assert each keyed animated layer, absence of the static layer, and absence of all switch-derived animated-layer keys on `_staticSite`. Keep Landing Basin's pinned-geometry interaction test intact.
4. `test/mining/presentation/mine_site_screen_test.dart`: reuse the static-site fixture (`_staticSite = MiningSiteId.graniteCrater`), rename 'keeps non-gold sites...' to 'keeps non-animated sites...', and pick a **legal T1 rig cell** with `firstPlayableCell(_content.site(_staticSite))` rather than the old Carbon Ridge `(5,1)` cell. Derive absent animated layer keys using `MiningSiteId.values` + `depositFramesFor` + `siteKeyPrefix`; retain static image/rig assertions.
5. `test/mining/presentation/mining_shell_test.dart`: parameterize only the existing successful Frozen Basin strike + `audio/mining.wav` test into `(siteId, saveBuilder)` cases for Frozen Basin and Carbon Ridge. Frozen uses its existing Lunar-active save; Carbon uses a Homeworld-active, unlocked/commissioned site with one T1 rig on `_carbonRidgeCell`. Warm each site's frame family first, open by `site-card-${id.name}-enter`, run one foreground tick, and assert the impact and sound. Reuse the existing closed/unrigged/full/resume tests unchanged; **do not duplicate them**.

Keep new helpers private to tests, and refactor only where needed to share assertions. Production animation ownership and time/HP/strike logic must remain unchanged.

### Production

- `lib/mining/presentation/mining_visuals.dart`: add `coal('coal')` to `MiningDepositFrames`; add `MiningSiteId.carbonRidge => MiningDepositFrames.coal` and drop it from the `null` arm.

No other production change is expected. If one is needed, it is a generic bug in the shared layer and gets its own test.

```sh
flutter test test/mining/presentation
```

## Task 2: Docs and gates

- `CLAUDE.md`: replace the hard-coded animated-site name list with an invariant: "A non-null `MiningVisuals.depositFramesFor` result identifies an approved animated mining site; other sites use the static layer."
- `docs/audio-assets.md`: replace the hard-coded site list with "Visible strike on an animated site (as selected by `MiningVisuals.depositFramesFor`) at 46% of the shared impact timeline."
- The design spec moved from `Status: Proposed` to `Status: Implemented` once its implementation and required tests passed.

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

Planning (on PR #44, based on `main` at `f0578fb`):

- `docs/superpowers/specs/2026-10-22-hpa-266-carbon-ridge-animation-design.md`
- `docs/superpowers/plans/2026-10-22-hpa-266-carbon-ridge-animation.md`

Implementation (same PR):

- `lib/mining/presentation/mining_visuals.dart`
- `lib/mining/presentation/animated_mining_grid_visual_layer.dart` — the generic shared-layer fix anticipated above: `errorBuilder` empty-box fallbacks on the deposit and robot images plus an `onError`/`failed` guard in `_precacheFrames`, so missing or undecodable art degrades visually while impacts keep deferring; covered by the layer tests
- `test/mining/presentation/mining_visuals_test.dart`, `animated_mining_grid_visual_layer_test.dart`, `mining_grid_map_test.dart`, `mine_site_screen_test.dart`, `mining_shell_test.dart`
- `CLAUDE.md`, `docs/audio-assets.md`

The `node-coal-…` files are already on `main` through merged HPA-186 / PR #50 and must **not** appear in this PR's diff. Keep exactly one HPA-266 delivery PR and do not introduce new runtime state owners or a visual registry.
