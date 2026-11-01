# HPA-266 Carbon Ridge Animated Mining Site Design

- Date: 2026-10-22; revalidated 2026-10-31
- Status: Proposed
- Linear: [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site) — Animate Carbon Ridge as the third animated site
- Baseline: `main` at `f0578fb` (after merged [PR #50](https://github.com/cwchanap/horologium/pull/50))
- Dependency satisfied: [HPA-186](https://linear.app/cwchanap/issue/HPA-186/mining-art-carbon-ridge-coal-animation-frames) — 15 approved coal frames merged via [PR #50](https://github.com/cwchanap/horologium/pull/50)
- Precedent: `docs/superpowers/specs/2026-10-16-hpa-418-frozen-basin-animation-design.md`

## Problem

Landing Basin and Frozen Basin animate; the other ten sites are still. Carbon Ridge is the second site every player opens, a few minutes into the game, and every relaunch (HPA-427) replays it. Right after the opening site comes alive, the next one goes still.

## Goal

Carbon Ridge plays the same live mining loop as the two animated sites: robot strike, deposit hit reaction, S1 idle loop, S1–S4 stage art driven by cargo fill, the exhaust beat at 90%, transient HP and damage labels, and the strike sound.

## Non-goals

This work does not:

- change `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `MiningSave`, `MineSiteView`, or any economy value;
- change the shared animated layer, its timing, thresholds, HP, damage, or reduced-motion rules;
- add a visual registry or a per-site special case;
- generate art (the coal frames are HPA-186) or add a new SFX.

## Design

HPA-418 already did the generalization. Animating a site is now exactly two lines of production code:

```dart
enum MiningDepositFrames {
  gold('gold'),
  waterIce('water-ice'),
  coal('coal');
  ...
}

static MiningDepositFrames? depositFramesFor(MiningSiteId id) => switch (id) {
  MiningSiteId.landingBasin => MiningDepositFrames.gold,
  MiningSiteId.frozenBasin => MiningDepositFrames.waterIce,
  MiningSiteId.carbonRidge => MiningDepositFrames.coal,
  ...
};
```

Everything else follows from the switch: `MiningGridMap` mounts `AnimatedMiningGridVisualLayer` with `carbon-ridge-…` keys, the shell's `_miningImpactSequence` and `mining` sound gate already ask `depositFramesFor`, and the layer precaches only the open site's family.

The coal family is **already on `main`** from HPA-186: 15 `node-coal-…` PNGs, 512×512 RGBA, locked to `nodes/coal.png`'s camera. PR #50 verified byte-identical source relationships: `coal.png` = S1 = idle-01, S3 = exhaust-01, and S4 = exhaust-04. Consume these assets unchanged; no additional artwork, manifests, or sound files.

## Testing

- **Visuals:** The existing per-`MiningDepositFrames.values` path test covers the new coal family automatically. Update the two hard-coded `hasLength(15)` assertions to iterate all families, assert 15 unique paths per family, and update the exhaustive site switch to return coal for Carbon Ridge and `null` for the remaining nine sites. The host-only bundle test must decode the coal frames at 512×512. **Extend** the existing water-ice byte-copy test into one loop over every animated `MiningSiteId` with `content.site(id).depositAsset` as S1 source; check S1/idle-01, S3/exhaust-01, and S4/exhaust-04 without three duplicated test bodies.
- **Layer:** a Carbon Ridge group using the existing Frozen Basin test pattern: stage plate at the 0.25 / 0.60 / 0.90 boundaries, idle loop, hit frames, exhaust beat, HP and damage labels under `carbon-ridge-…` keys, cold-cache drop, and reduced motion. Reuse a small test fixture helper where that prevents test duplication; do not refactor the production layer.
- **Grid map and Mine Site:** Carbon Ridge hosts `carbon-ridge-grid-visual-layer`. The existing "static site" tests that use Carbon Ridge move to Granite Crater, which stays static.
- **Shell:** with Carbon Ridge open and rigged, one foreground tick increments the impact sequence and a *visible, warmed strike* plays `audio/mining.wav`; opening the layer, lifecycle resume, cold-cache misses, full sites, and reduced motion must not replay or invent strikes/SFX.
- **Goldens:** `visual_parity_golden_test` passes unchanged.

## Risks

- **Art continuity.** HPA-186's approved art and frame-copy checks have already passed; the host-only test protects those contracts. Do not edit PNG pixels in the wiring PR.
- **Runtime memory.** The frames are already bundled, and the existing layer precaches only the open site's family. No additional asset loader or cache is needed.
- **Regression surface.** Existing tests use Carbon Ridge as a *static* site; move only those fixtures to Granite Crater (same progression levels) while preserving the static-layer coverage.

## Assets

None generated or modified here. The 15 coal frames were merged in HPA-186 / PR #50. A single existing draft PR [#44](https://github.com/cwchanap/horologium/pull/44) will carry this refreshed design, plan, and later runtime/test changes; no second PR for HPA-266.
