# HPA-266 Carbon Ridge Animated Mining Site Design

- Date: 2026-10-22; revalidated 2026-10-31
- Status: Implemented
- Linear: [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site) — Animate Carbon Ridge as the third animated site
- Baseline: `main` at `f0578fb` (after merged [PR #50](https://github.com/cwchanap/horologium/pull/50))
- Dependency satisfied: [HPA-186](https://linear.app/cwchanap/issue/HPA-186/mining-art-carbon-ridge-coal-animation-frames) — 15 approved coal frames merged via [PR #50](https://github.com/cwchanap/horologium/pull/50)
- Precedent: `docs/superpowers/specs/2026-10-16-hpa-418-frozen-basin-animation-design.md`

## Problem

Landing Basin and Frozen Basin animated; the other ten sites were still. Carbon Ridge is the second site every player opens, a few minutes into the game, and every relaunch (HPA-427) replays it. Right after the opening site came alive, the next one went still.

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

- **Frame paths, assets and switch:** The existing `MiningDepositFrames.values` path test and host-only bundle decode cover coal when the enum value is added. Loop the remaining hard-coded 15-path assertions over every family; keep the exhaustive `depositFramesFor` mapping with Carbon Ridge animated and the other nine sites static. Convert the water-ice-only byte-copy assertion to one loop over *all* animated sites, comparing S1/idle-01 with `content.site(id).depositAsset`, S3 with exhaust-01, and S4 with exhaust-04.
- **Shared layer:** Do **not** copy Frozen Basin's fixture or six-test suite. Parameterize its existing test helpers by `MiningSiteId`, then run those same tests for every non-Landing animated site returned by `depositFramesFor`. Resolve the first legal cell using `firstPlayableCell(site)` (Surveying level from the first progression deposit), its deposit via `uniqueAdjacentDeposit`, its frames via `depositFramesFor`, and its keys via `siteKeyPrefix`. Reuse the stage-boundary, idle, hit, exhaust, HP/damage, cold-cache, and reduced-motion assertions. Keep the more comprehensive Landing Basin suite unchanged.
- **Grid map:** For each animated site, assert its derived `siteKeyPrefix(id)` layer key and absence of the static layer. Move existing static-site checks to one `_staticSite = MiningSiteId.graniteCrater` fixture. Its generated deposit coordinates **differ** from Carbon Ridge's despite the same Surveying progression: construct the tested overlay key from `view.deposits.first.definition` rather than hard-coding `mining-deposit-1-1-2`. Derive the absent animated-layer key set from the switch.
- **Mine Site:** Move the existing static-deposit/rig test to Granite Crater, rename it from 'non-gold' to 'non-animated', and derive the T1 rig's legal perimeter cell with `firstPlayableCell(_content.site(_staticSite))` instead of reusing Carbon Ridge's hard-coded `(5,1)` cell. Check absence of animated keys using the switch-derived site list.
- **Shell:** Turn only the existing Frozen Basin *successful foreground strike + `audio/mining.wav`* test into a two-row test table (Frozen Basin and Carbon Ridge). Supply a per-site save builder so Lunar Frontier is active for Frozen Basin and Homeworld for Carbon Ridge. The existing closed/unrigged/full/resume checks already exercise the shared shell gates; do not clone those negative tests.
- **Documentation:** `CLAUDE.md` and `docs/audio-assets.md` reference the non-null `MiningVisuals.depositFramesFor` source of truth rather than hard-coded site lists.
- **Goldens:** Keep `visual_parity_golden_test` unchanged; it renders Landing Basin only. The spec moved to `Implemented` once production and test changes passed.

## Risks

- **Art continuity.** HPA-186's approved coal frame family is already on `main` and its byte-copy relationships were verified. This PR only consumes the images; do not modify PNGs or generate new art.
- **Test fixture geometry.** The 50×50 deposit field depends on `siteId.index`; Granite Crater is **not** a pure rename of Carbon Ridge for geometry-sensitive checks. Use actual deposit definitions and legal rig cells.
- **Test maintenance.** The reused non-Landing animated-site suite runs against all approved frame families; no new copy of its fixtures or negative shell tests is needed for Carbon Ridge or the next animated site.
- **Runtime memory.** The existing layer precaches only the open site's frame family. No loader or cache changes are required.

## Assets

None generated or modified here. The 15 coal frames were merged in HPA-186 / PR #50. PR [#44](https://github.com/cwchanap/horologium/pull/44) carries this design, plan, and the runtime/test changes; no second PR for HPA-266.
