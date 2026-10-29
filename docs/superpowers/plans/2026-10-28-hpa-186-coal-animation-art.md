# HPA-186 — Carbon Ridge coal animation frames: implementation plan

- **Status:** Planning / not implemented.
- **Ticket:** [HPA-186](https://linear.app/cwchanap/issue/HPA-186/mining-art-carbon-ridge-coal-animation-frames)
- **Design:** [Coal art spec](../specs/2026-10-28-hpa-186-coal-animation-art-design.md)
- **Reference:** `assets/images/mining/nodes/coal.png`, matching the gold and water-ice deposit families.
- **Downstream coding ticket:** [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site)
- **PR policy:** This branch and draft PR are the **only PR for HPA-186**. Add approved sprites to it, not a separate art PR. No Flutter work here.

## Reuse and scope gate

| Existing part | Decision |
| --- | --- |
| `assets/images/mining/nodes/coal.png` | **REUSE** as the unmodified S1 plate and canonical camera/footprint |
| HPA-404 water-ice frame workflow / PR #39 | **REUSE** the reference-edit → owner review → remaining frames → copied endpoints → preview pattern |
| `MiningDepositFrames` file naming and 15-frame sequence | **REUSE**; don't modify the enum until HPA-266 |
| `AnimatedMiningGridVisualLayer`, Mine Site and shell | **LEAVE UNCHANGED**; HPA-266 owns the two-line wiring and tests |
| Prompt pack and reference plate mentioned in Linear (`hpa-186/coal-prompts.md`, `hpa-186/reference-s1.png`) | **VERIFY ACCESS FIRST** in the owner's project files; the connected repo does not establish their contents. Use them if present; avoid rewriting a competing brief. |
| Preview / contact sheet / GIF | **GENERATE LOCALLY**, keep in project files, never commit |
| Dart, tests, manifest, build files, generated tooling | **OUT OF SCOPE** for this art PR |

## Task 1 — Verify reference and prepare edits

1. Obtain `hpa-186/coal-prompts.md` and `hpa-186/reference-s1.png` from the owner's project files as stated in Linear. If unavailable, use the approved spec and `nodes/coal.png` as source instead of inventing pack contents.
2. Inspect `coal.png` and confirm dimensions, alpha, rock-base footprint and palette. Compare the existing water-ice and gold art for sequence conventions.
3. Keep the source image unmodified and work on local temporary files until a frame is accepted. Every generation uses the same image-edit reference; do not cascade unapproved changes between generated frames.
4. Keep final output rooted only at `assets/images/mining/nodes/` with the exact `node-coal-...` naming.

**Gate:** Canonical source, desired scene framing and prompt pack (if available) are understood; no assets committed yet.

## Task 2 — Generate the four-frame approval batch

Create four individually edited 512×512 RGBA PNGs:

- `node-coal-s2.png`: visible cracks and modestly reduced coal mass, stable base.
- `node-coal-s3.png`: a mostly depleted coal seam, enough remaining chunks for the exhaust beat.
- `node-coal-s4.png`: bare/near-bare rock with a faint ember glow, stable base and shadow.
- `node-coal-hit-01.png`: start of impact; small squash/brighten and upper-left soot/chips.

Scale image-edit outputs uniformly to 512×512 without freehand cropping/reframing; preserve transparent regions. Present the four frames beside S1 in a contact sheet and obtain **explicit owner approval** before Task 3. Revise these four in place on the same branch if needed.

**Gate:** Owner approves S2–S4 progression and the first hit. Do not generate the remaining seven before approval.

## Task 3 — Generate the seven remaining edits

Use the same reference plate and approved shapes:

- Idle `node-coal-idle-02.png`, `03.png`, `04.png`: subtle ember pulse, S1 silhouette unchanged.
- Hit `node-coal-hit-02.png`, `03.png`: small flying coal chips/soot, settling and return to S1 without geometric jumps.
- Exhaust `node-coal-exhaust-02.png`, `03.png`: crumble remaining S3 coal toward approved S4; preserve S3/S4 base and camera.

Preview the sequences in order at in-game scale. Re-edit frames that introduce jumps, overblown debris, inconsistent highlights or baked checkerboards.

**Gate:** Exactly 11 **generated** images approved as a coherent sequence.

## Task 4 — Make four exact copies and validate the full set

Copy bytes, do not re-render or re-encode:

```sh
cd assets/images/mining/nodes
cp coal.png node-coal-s1.png
cp coal.png node-coal-idle-01.png
cp node-coal-s3.png node-coal-exhaust-01.png
cp node-coal-s4.png node-coal-exhaust-04.png
```

Validate locally (no validation scripts committed):

1. Exactly 15 `node-coal-*.png` outputs: four stage, four idle, three hit and four exhaust; no hidden extra/draft files.
2. Each image decodes as a 512×512 RGBA PNG, with genuine outside transparency and no baked edge checkerboard. If normalization is needed, restrict it to edge-connected checkerboard artifacts.
3. SHA-256 byte equality for `coal.png` ↔ S1 ↔ idle-01, S3 ↔ exhaust-01, and S4 ↔ exhaust-04.
4. Superimposed S1/S2/S3/S4 plates align at the rock base; idle preserves the S1 silhouette; hit and exhaust transitions do not visibly jump.
5. Show images over both light and dark backgrounds to catch halos, alpha damage and checkerboard remnants.

Helpful read-only spot checks:

```sh
find assets/images/mining/nodes -maxdepth 1 -name 'node-coal-*.png' | sort
shasum -a 256 assets/images/mining/nodes/coal.png \
  assets/images/mining/nodes/node-coal-s1.png \
  assets/images/mining/nodes/node-coal-idle-01.png
shasum -a 256 assets/images/mining/nodes/node-coal-s3.png \
  assets/images/mining/nodes/node-coal-exhaust-01.png
shasum -a 256 assets/images/mining/nodes/node-coal-s4.png \
  assets/images/mining/nodes/node-coal-exhaust-04.png
```

Use any local image inspector to verify dimensions/mode; **do not add** a permanent image-processing pipeline for one art family.

## Task 5 — Review, final PR and unblock HPA-266

1. Produce a project-file contact sheet that shows all 15 frames, plus an idle/hit-loop GIF and a small in-game-style still. Do **not** add previews or drafts to the repository.
2. Append the approved 15 PNGs to **this same draft PR**. Record the validation results and preview locations in the PR description.
3. Get the owner's explicit visual sign-off. Keep the branch art-only apart from this request's design/plan documentation. The Linear ticket originally calls for a PNG-only final PR; if that literal diff rule is retained, move the planning text back to the issue and drop the two docs from this same PR before merge — **do not create a second PR**.
4. Only after merge, start HPA-266 from up-to-date `main` for `MiningDepositFrames.coal`, the closed switch, tests and docs. HPA-266 must **not** generate or modify this art.

## Completion checklist

- [ ] First four edited frames approved by owner
- [ ] Remaining seven edited frames reviewed
- [ ] Four endpoint PNGs copied byte-for-byte
- [ ] Exactly 15 complete 512×512 RGBA files, consistent footprint and alpha
- [ ] Contact sheet, idle/hit GIF and in-game-style preview reviewed
- [ ] No Dart, test, manifest, audio, or extra generated files in art changes
- [ ] Single draft PR updated and explicitly approved; merge unblocks HPA-266

**Do not claim Flutter checks pass in this planning-only PR.** No runtime changes are proposed; HPA-266 owns subsequent automated image-loading and animation tests.
