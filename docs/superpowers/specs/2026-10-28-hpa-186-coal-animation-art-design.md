# HPA-186 — Carbon Ridge coal deposit frame family: design

- **Status:** Proposed / planning only; no new images have been generated or approved.
- **Linear:** [HPA-186](https://linear.app/cwchanap/issue/HPA-186/mining-art-carbon-ridge-coal-animation-frames)
- **Unblocks:** [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site)
- **Baseline:** `main`, using the static `assets/images/mining/nodes/coal.png` plate and the existing gold / water-ice 15-frame families.
- **Delivery:** One HPA-186 PR. Planning is recorded here as requested; the actual art generation belongs to this art-only ticket, not the HPA-266 Flutter ticket.

## Player outcome

Carbon Ridge is the second Homeworld site and an early repeat destination after Relaunch. Its static coal deposit should have the same visual progression vocabulary as Landing Basin (gold) and Frozen Basin (water ice): four depletion plates, a subtle idle pulse, a short hit response, and an exhaust finish. This ticket supplies the **assets only**. HPA-266 will wire them into the existing Flutter visual layer later.

## Existing implementation to reuse

- `MiningDepositFrames` in `lib/mining/presentation/mining_visuals.dart` already specifies 4 stage, 4 idle, 3 hit, and 4 exhaust paths using `node-<slug>-...` names; HPA-266 adds the `coal` member and closed-switch case **after art merges**.
- `AnimatedMiningGridVisualLayer` already handles impact timing, stage selection, HP/damage labels, caching and reduced motion. Do not alter those contracts here.
- HPA-404's water-ice art PR (#39) is the useful production precedent: generate by editing a reference plate, preserve a shared footprint, and copy transition endpoints byte-for-byte.
- The existing `pubspec.yaml` already includes `assets/images/mining/nodes/`. No manifest, Dart, tests, tooling, SFX or economy changes are needed in HPA-186.

## Exact deliverables

All files go directly under `assets/images/mining/nodes/`. Each must be a **512×512 RGBA PNG**, composed on the same camera, scale and rock-base footprint as `coal.png`.

| Group | Exact files | Visual contract |
| --- | --- | --- |
| Stages (4) | `node-coal-s1.png` to `node-coal-s4.png` | S1 is a **byte-for-byte copy of `coal.png`**. S2→S4 progressively break the seam down; S4 keeps the fixed bare rock base with a restrained ember glow. |
| Idle (4) | `node-coal-idle-01.png` to `node-coal-idle-04.png` | Idle 01 copies S1 exactly. Idle 02–04 use **S1 geometry**, varying only a restrained ember pulse, not the coal silhouette or rock base. |
| Hit (3) | `node-coal-hit-01.png` to `node-coal-hit-03.png` | On S1 geometry: brief squash/brightening, small upper-left coal chips and soot puff, then settle. No camera motion or large debris field. |
| Exhaust (4) | `node-coal-exhaust-01.png` to `node-coal-exhaust-04.png` | Exhaust 01 copies S3 exactly, exhaust 04 copies S4 exactly. Frames 02–03 crumble the remaining coal into S4, keeping the rock base fixed. |

**11 generated/edit frames:** S2–S4 (3), idle 02–04 (3), hit 01–03 (3), exhaust 02–03 (2).
**4 copied frames:** S1 and idle 01 from `coal.png`; exhaust 01 from S3; exhaust 04 from S4. Total: **15 PNGs**.

## Art direction and invariants

- Respect the original `coal.png` viewpoint, framing, contact shadow, bottom rock edge, contrast and palette; reuse that plate as the image-edit reference, not a fresh loosely matched generation.
- Visually separate coal depletion from coal *damage*: stages reflect accumulated cargo state; hit frames are transient feedback. Do not shrink/reposition the whole node on a hit.
- Slow idle reads as an ember-light flicker and must not make the coal seem to jump. Endpoints that return to S1 and S4 must not pop when the loop changes states.
- Keep alpha genuinely transparent outside the deposit. Normalize **only edge-connected baked checkerboard pixels** if the image editor introduces them; do not erase valid internal pixels, shadows or smoke.
- Soot/chip overlays can temporarily extend beyond the deposit silhouette, but must remain visually readable at Mine Site scale; use the original plate as the footprint anchor rather than enforcing a speculative rigid bounding-box threshold.
- No new art framework, atlas, runtime renderer, shaders, audio, or extra visual states.

## Review and acceptance

1. Approve the first batch **S2, S3, S4 and Hit 01** against the original coal plate before generating the rest.
2. Review a 15-frame contact sheet at actual in-game scale plus an idle/hit loop GIF. Store drafts, reference plates, and previews in the project files, **not** in the game repository.
3. Confirm all 15 names, 512×512 dimensions, RGBA format, transparent edges, visually stable rock footprint, and the four byte-identical copy relationships.
4. Verify no additional PNGs, scripts, test changes, runtime changes, or asset-manifest edits are in the art implementation diff.
5. Obtain explicit owner approval on this PR; only then merge. HPA-266 begins implementation once these files are on `main`.

## Risks and mitigations

- **Jitter or jumping between frames:** compare aligned transparent overlays and an actual idle/hit GIF before approval; re-edit offending frames against the same reference.
- **Unwanted checkerboard baked into alpha:** inspect edges on light and dark backgrounds; remove edge-connected artifacts only.
- **Overly dramatic hits hiding resource HP labels:** keep debris small and test at the actual Mine Site presentation scale.
- **Scope collision with HPA-266:** retain the existing Flutter layer and its tests untouched; the art ticket produces only sprites.

The [implementation plan](../plans/2026-10-28-hpa-186-coal-animation-art.md) details the generation, copying and validation sequence.
