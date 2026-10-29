# HPA-186 — Carbon Ridge coal deposit frame family: design

- **Status:** Proposed / planning only; no new images have been generated or approved.
- **Linear:** [HPA-186](https://linear.app/cwchanap/issue/HPA-186/mining-art-carbon-ridge-coal-animation-frames)
- **Unblocks:** [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site)
- **Baseline:** `main`, using the static `assets/images/mining/nodes/coal.png` plate and the existing gold / water-ice 15-frame families. `coal.png` is the **authoritative S1 plate**; any project-file reference image is advisory only.
- **Delivery (decided):** One HPA-186 PR containing **this design spec, the implementation plan, and 15 approved coal PNGs**. No runtime changes, scripts, tests, manifests or previews. HPA-266 owns Flutter wiring in its own ticket.

## Player outcome

Carbon Ridge is the second Homeworld site and an early repeat destination after Relaunch. Its static coal deposit should have the same visual progression vocabulary as Landing Basin (gold) and Frozen Basin (water ice): four depletion plates, a subtle idle pulse, a short hit response, and an exhaust finish. This ticket supplies **only art assets as its production output**, alongside the two planning documents. HPA-266 will wire them into the existing Flutter visual layer later.

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

- **Reference hierarchy:** `assets/images/mining/nodes/coal.png` is the only authoritative S1 plate and byte-copy source. Use project-file `hpa-186/reference-s1.png` only if its SHA-256 matches `coal.png`; otherwise ignore it. The prompt pack can guide wording but never override the source plate, names, copy relationships, or this spec.
- **Per-frame editing references:** edit S2–S4, idle 02–04, and hit 01–03 from `coal.png`. Edit exhaust 02–03 from the **owner-approved S3**, so the S3 → exhaust 01 → exhaust 02 transition retains S3's chunk arrangement. No cascading from unapproved generated frames. Preserve each reference's viewpoint, framing, contact shadow, bottom rock edge, contrast, and palette.
- Visually separate coal depletion from coal *damage*: stages reflect accumulated cargo state; hit frames are transient feedback. Do not shrink/reposition the whole node on a hit.
- Slow idle reads as an ember-light flicker and must not make the coal seem to jump. Endpoints that return to S1 and S4 must not pop when the loop changes states.
- Keep alpha genuinely transparent outside the deposit. **Reject and re-edit** frames with a baked checkerboard; never flood-fill or recolor checkerboard-like pixels, which risks erasing grey soot or chipped coal. Inspect over light and dark backgrounds.
- **Measured footprint gate:** measure the alpha > 16 bounding box `(left, top, right, bottom)` for S1 and every delivered frame. The review measured `coal.png` as `(28, 26, 486, 486)`; remeasure the local source before editing. For stage, idle, and exhaust frames, keep **left, right, and bottom within 4 px of S1**; top may recede during depletion. For hit frames, allow the **left** bound to extend for airborne chips/soot while keeping the right and bottom within 4 px, and confirm the stationary rock base by overlay. Record a **15-row bbox table** in the PR description. Re-edit out-of-tolerance frames rather than weakening the check by default.
- Soot/chip overlays can temporarily extend beyond the deposit silhouette but must remain readable beside the real Mine Site HP and damage HUD; verify through a local, uncommitted Carbon Ridge renderer preview rather than a composited mock.
- No new art framework, atlas, runtime renderer, shaders, audio, or extra visual states.

## Review and acceptance

1. Approve the first batch **S2, S3, S4 and Hit 01** against the original coal plate before generating the rest.
2. Review a 15-frame contact sheet at actual in-game scale, an idle/hit loop GIF, and a **screenshot from the actual Carbon Ridge Flutter renderer** with the new assets temporarily wired in locally. Store drafts, reference plates, and previews in the project files, **not** in the game repository.
3. Confirm all 15 names, 512×512 dimensions, RGBA format, transparent edges, the recorded 15-frame bbox table and tolerance, visually stable rock base, and the four byte-identical copy relationships.
4. Verify no additional PNGs, scripts, test changes, runtime changes, or asset-manifest edits are in the art implementation diff.
5. Obtain explicit owner approval on this PR; only then merge. HPA-266 begins implementation once these files are on `main`.

## Risks and mitigations

- **Jitter or jumping between frames:** enforce the alpha > 16 bbox tolerance and inspect aligned overlays, the idle/hit GIF, and the real renderer; re-edit offending frames using their specified references.
- **Unwanted checkerboard baked into alpha:** inspect over light and dark backgrounds; reject and re-edit affected frames instead of attempting color-key or flood-fill repair.
- **Overly dramatic hits hiding resource HP labels:** keep debris small and capture the actual Mine Site with temporary local-only wiring; restore all temporary Dart changes before updating the PR.
- **Scope collision with HPA-266:** retain the existing Flutter layer and its tests untouched; the art ticket produces only sprites.

The [implementation plan](../plans/2026-10-28-hpa-186-coal-animation-art.md) details the generation, copying and validation sequence.
