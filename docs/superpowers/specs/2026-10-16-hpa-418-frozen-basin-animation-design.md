# HPA-418 Frozen Basin Animated Mining Site Design

- Date: 2026-10-16
- Status: Draft for review
- Linear: [HPA-418](https://linear.app/cwchanap/issue/HPA-418/mining-polish-animate-frozen-basin-as-the-second-mining-site) — Animate Frozen Basin as the second mining site
- Baseline: `main` at `8f0881f` after PR #35

## Problem

Landing Basin is the only site with live mining. HPA-451 gave it an articulated robot arm, staged gold art that tracks cargo fill, and idle / hit / exhaust frames. HPA-455 added transient resource HP bars and damage numbers. The other eight sites render `_StaticMiningGridVisualLayer`: one static node image per resource and one static rig image per placement.

The first time a player reaches a new planet, the Lunar Frontier's Frozen Basin, the Mine Site goes still. The planet transition is the biggest progression beat in the game, and it lands on a less lively screen than the opening one.

`CLAUDE.md` deliberately holds off on a shared animated path "until a concrete second animated site needs it". Frozen Basin is that site.

## Goals

- Frozen Basin plays the same live mining loop as Landing Basin: robot strike, deposit hit reaction, S1 idle loop, S1–S4 stage art driven by cargo fill, the exhaust beat at 90%, transient HP and damage labels, and the strike sound.
- Add a water-ice frame family that matches the gold family's structure, camera, and footprint.
- Turn the Landing Basin layer into one animated layer parameterized by a site's frame family, with Landing Basin behavior and goldens unchanged.
- Keep the animated-site set a closed, explicit switch.

## Non-goals

This work does not:

- change `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `MiningSave`, `MineSiteView`, or any economy value;
- animate any site other than Landing Basin and Frozen Basin;
- add a resource visual registry, data-driven animation format, sprite-sheet loader, Rive, Lottie, Flame, or particle system;
- add new robot art, a new SFX, haptics, or a second audio path;
- change HP or damage values, the impact timeline, stage thresholds, or reduced-motion rules;
- persist or replay any animation state.

## Ownership

```text
MiningShell --(one impact sequence for the open animated site)--> MineSiteScreen
  -> MiningGridMap
       -> AnimatedMiningGridVisualLayer(frames: MiningDepositFrames)   Landing Basin, Frozen Basin
       -> _StaticMiningGridVisualLayer                                 every other site
```

- `MiningVisuals.depositFramesFor(MiningSiteId)` is the closed switch: `gold` for Landing Basin, `waterIce` for Frozen Basin, `null` for the other seven sites.
- `MiningGridMap` picks the animated layer when the switch returns frames.
- `MiningShell` owns one transient `_miningImpactSequence` (renamed from `_landingBasinImpactSequence`) and the existing sound gate. Both now ask the switch instead of comparing against `MiningSiteId.landingBasin`.
- The layer still owns only visuals: impact and idle controllers, frame precache, the stalled-first-impact drop, and transient per-resource HP.

## Design decisions

### 1. A frame family is a small value, not a registry

```dart
class MiningDepositFrames {
  const MiningDepositFrames._(this.slug);

  static const gold = MiningDepositFrames._('gold');
  static const waterIce = MiningDepositFrames._('water-ice');

  final String slug;

  String stage(int stage);   // 1..4  -> assets/images/mining/nodes/node-$slug-s$stage.png
  String idle(int frame);    // 1..4  -> node-$slug-idle-0N.png
  String hit(int frame);     // 1..3  -> node-$slug-hit-0N.png
  String exhaust(int frame); // 1..4  -> node-$slug-exhaust-0N.png
  List<String> get all;      // the 15 paths, in precache order
}
```

Each accessor keeps the existing `RangeError` on an out-of-range index. The gold paths are unchanged, so `goldNodeStageAsset` and friends are replaced by `MiningDepositFrames.gold` and their tests keep the same expected strings. Two named constants and a closed `switch` over `MiningSiteId` keep this a contract, not a lookup table anyone can extend at runtime.

### 2. One animated layer, keyed per site

`LandingBasinGridVisualLayer` becomes `AnimatedMiningGridVisualLayer` in `animated_mining_grid_visual_layer.dart`, with one new required `MiningDepositFrames frames` parameter. Every gold path in `_precacheFrames` and `_depositAsset` reads from `frames`. Timing, thresholds, the contact latch, HP math, damage labels, mirroring, and arm angles are unchanged.

Widget keys keep their current shape with a per-site prefix taken from the site ID (`landing-basin-…`, `frozen-basin-…`). Landing Basin keys are therefore byte-for-byte what they are today, and the existing 900-line layer test keeps its finders.

The HP and damage helpers lose their site prefix because they are not site-specific: `landingBasinMaxHp` becomes `miningResourceMaxHp`, and likewise for strike damage, grouped damage, and remaining HP. Values stay `size × 40` HP and `(tier + 1) × 10` damage.

### 3. Robot art becomes shared

The T1–T5 body and arm images are a generic tracked mining robot, not gold-specific art. They move from `assets/images/mining/landing_basin/` to `assets/images/mining/robots/` unchanged (`git mv`, byte-identical), with helpers renamed to `miningRobotBodyAsset` / `miningRobotArmAsset` and the asset manifest updated. The Landing Basin goldens do not change because the pixels do not change.

### 4. Shell impact sequence follows the open animated site

```dart
final frames = _openSiteId == null ? null : MiningVisuals.depositFramesFor(_openSiteId!);
if (frames != null && site.rigPlacements.isNotEmpty && site.storedAmount > before.storedAmount) {
  _miningImpactSequence++;
}
```

The sequence is still one integer because only the open site receives it. Opening a different site mounts a new layer, which never fires on mount, so switching from Landing Basin to Frozen Basin cannot replay a strike. `_playMiningImpact` plays `GameSound.mining` only when the open site is animated and the route is current, exactly as today for Landing Basin.

### 5. Water-ice frame family

The S1 plate is the existing `assets/images/mining/nodes/water_ice.png`, copied byte-for-byte to `node-water-ice-s1.png` (gold does the same with `gold.png`). As with gold, `idle-01` is a copy of S1, `exhaust-01` a copy of S3, and `exhaust-04` a copy of S4. That leaves **11 generated frames**: S2–S4, idle 02–04, hit 01–03, and exhaust 02–03.

Every frame is a 512×512 transparent PNG in S1's locked camera. The rock base stays registered to S1's opaque footprint, measured at alpha > 16 as `(55, 4, 458, 509)`; depleting stages lower only the top edge, as gold's S3 and S4 do.

| Frame | Brief |
| --- | --- |
| S2 | Tallest crystals snapped to two-thirds height, fresh pale fracture faces, a few loose shards on the rocks. |
| S3 | Only stubs and mid-size crystals remain; glow halved; frost-dusted rubble dominates. |
| S4 | Rock base with frost and a few small shards; faint residual glow in the cracks. |
| Idle 02 | S1 geometry, inner glow 90%, a soft cyan bleed along crystal edges. |
| Idle 03 | S1 geometry, inner glow 100%, one or two tiny frost sparkle motes. |
| Idle 04 | S1 geometry, inner glow 85%, the motes fading. |
| Hit 01 | S1 crystals compressed 4 px at the top, glow 130%, 3–5 ice chips at the upper-left contact point. |
| Hit 02 | S1 at full height, chips flying a short distance outward, a small frost-mist puff kept inside the cell. |
| Hit 03 | S1 settled, chips nearly gone, sparkle fading, a thin frost haze at the base. |
| Exhaust 02 | S3 stubs crack and slump inward, glow dims, one small contained frost puff. |
| Exhaust 03 | Lower slump approaching S4, sparse patchy glow. |

The upper-left contact point matches the robot's default left-facing strike; the layer mirrors the robot, not the deposit. Normalize only edge-connected baked checkerboard pixels to alpha, and commit no generator drafts or cleanup scripts.

This session has no image-generation tool, so the frames are produced where the image-generation skill is available (as for HPA-451's gold frames) and approved by the owner before they are wired.

### 6. Precache only the open site's family

The layer precaches its own 15 paths in `didChangeDependencies`, as today. Landing Basin and Frozen Basin never mount together, so at most one family is resident from this layer. The 200 ms first-impact defer budget still applies per mount.

## Interaction with HPA-401

HPA-401 lengthens storage from minutes to hours. Stage art follows `cargo / capacity`, so with longer storage a site spends longer in each stage, and the S1 idle loop runs for the first quarter of fill. Nothing in this design depends on the fill window, and the two tickets can merge in either order.

## Testing

- **Visuals:** `MiningDepositFrames.gold` returns today's 15 gold paths; `waterIce` returns the 15 `node-water-ice-…` paths; out-of-range indices throw `RangeError`; `depositFramesFor` returns gold, water ice, and `null` for the other seven sites. Host-only bundle test: every water-ice frame decodes at 512×512, and S1 / idle-01 / exhaust-01 / exhaust-04 bytes equal `water_ice.png` / S1 / S3 / S4. Robot helpers return `assets/images/mining/robots/…`, and all ten robot images still decode.
- **Layer:** the existing Landing Basin tests run unchanged apart from renamed symbols. A new Frozen Basin group covers stage selection at the 0.25 / 0.60 / 0.90 boundaries, the idle loop, hit frames, the exhaust beat crossing 90%, HP chrome and damage labels under `frozen-basin-…` keys, the cold-cache drop, and reduced motion showing the static plate with a stationary arm.
- **Grid map:** Frozen Basin hosts `frozen-basin-grid-visual-layer`; Carbon Ridge still hosts the static layer.
- **Shell:** with Frozen Basin open and rigged on an unlocked Lunar Frontier, one foreground tick increments the impact sequence and plays `audio/mining.wav`; closed, unrigged, and full Frozen Basin emit nothing; lifecycle resume replays nothing; opening Frozen Basin straight after Landing Basin fires no strike on mount.
- **Goldens:** `visual_parity_golden_test` passes unchanged.

## Risks

- **Art drift.** Generated frames can change the footprint or camera. Mitigation: register every frame to S1's footprint, prove S2 and Hit 01 in the real Mine Site before generating the rest, and reject frames that need geometry changes.
- **Rename churn.** Renaming the layer, helpers, and robot paths touches many tests. Mitigation: keys and values keep their shape, so test edits are mechanical; the rename lands in its own commit before any Frozen Basin behavior.
- **Memory.** A second 15-frame family adds about 4 MB of PNGs to the bundle; only the open site's family is decoded.

## Assets

Image generation is required: 11 water-ice frames, owner-approved before wiring. No SFX or robot art.
