# HPA-266 Carbon Ridge Animated Mining Site Design

- Date: 2026-10-22
- Status: Proposed
- Linear: [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site) — Animate Carbon Ridge as the third animated site
- Baseline: `main` at `15fd4c0`
- Depends on: [HPA-186](https://linear.app/cwchanap/issue/HPA-186/mining-art-carbon-ridge-coal-animation-frames) — coal frame family (art only, its own PR)
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

The coal family comes from HPA-186 with the same 15 names, 512×512 RGBA size, and locked camera as gold and water ice. As before, S1 and idle-01 are copies of `nodes/coal.png`, exhaust-01 copies S3, and exhaust-04 copies S4.

## Testing

- **Visuals:** `MiningDepositFrames.coal` maps every index to its `node-coal-…` path; `depositFramesFor` returns gold, water ice, coal, and `null` for the other nine sites. Host-only bundle test: every coal frame decodes at 512×512, and the four copies match their sources byte for byte (the same test the water-ice family has).
- **Layer:** a Carbon Ridge group mirroring the Frozen Basin one: stage plate at the 0.25 / 0.60 / 0.90 boundaries, idle loop, hit frames, exhaust beat, HP and damage labels under `carbon-ridge-…` keys, cold-cache drop, and reduced motion.
- **Grid map and Mine Site:** Carbon Ridge hosts `carbon-ridge-grid-visual-layer`. The existing "static site" tests that use Carbon Ridge move to Granite Crater, which stays static.
- **Shell:** with Carbon Ridge open and rigged, one foreground tick increments the impact sequence and plays `audio/mining.wav`; lifecycle resume replays nothing.
- **Goldens:** `visual_parity_golden_test` passes unchanged.

## Risks

- **Art drift.** Generated frames can shift the footprint. HPA-186 registers every frame to S1's footprint and proves S2 and Hit 01 first; this ticket's bundle test catches a wrong size or broken copy.
- **Bundle size.** A third family adds about 4 MB of PNGs; only the open site's family is decoded.

## Assets

None generated here. The 15 coal frames come from HPA-186.
