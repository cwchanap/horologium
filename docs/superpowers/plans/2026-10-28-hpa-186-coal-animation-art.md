# HPA-186 — Carbon Ridge coal animation frames: implementation plan

- **Status:** Planning / not implemented.
- **Ticket:** [HPA-186](https://linear.app/cwchanap/issue/HPA-186/mining-art-carbon-ridge-coal-animation-frames)
- **Design:** [Coal art spec](../specs/2026-10-28-hpa-186-coal-animation-art-design.md)
- **Reference:** `assets/images/mining/nodes/coal.png`, matching the gold and water-ice deposit families.
- **Downstream coding ticket:** [HPA-266](https://linear.app/cwchanap/issue/HPA-266/mining-visuals-animate-carbon-ridge-as-the-third-animated-site)
- **PR policy (decided):** This branch and draft PR are the **only PR for HPA-186**. Keep the design spec and implementation plan in the final diff alongside the 15 approved PNGs. No separate art PR and no Flutter work here.

## Reuse and scope gate

| Existing part | Decision |
| --- | --- |
| `assets/images/mining/nodes/coal.png` | **REUSE** as the **only authoritative S1 plate** and canonical camera/footprint. Recheck its SHA-256 and bbox locally before editing. |
| HPA-404 water-ice frame workflow / PR #39 | **REUSE** the reference-edit → owner review → remaining frames → copied endpoints → preview pattern |
| `MiningDepositFrames` file naming and 15-frame sequence | **REUSE**; don't modify the enum until HPA-266 |
| `AnimatedMiningGridVisualLayer`, Mine Site and shell | **LEAVE UNCHANGED**; HPA-266 owns the two-line wiring and tests |
| Prompt pack and reference plate mentioned in Linear (`hpa-186/coal-prompts.md`, `hpa-186/reference-s1.png`) | **VERIFY ACCESS FIRST** in project files; prompt pack supplies wording only. Use `reference-s1.png` only if SHA-256 **exactly matches** repository `coal.png`; otherwise ignore it. Neither can override the spec or canonical S1. |
| Contact sheet / GIF / real Flutter screenshot / bbox table | **VALIDATE LOCALLY**; store visual previews in project files and put the 15-row bbox table in the PR description. Only temporary, uncommitted visual wiring is permitted for screenshot/asset-load checks. |
| Dart, tests, manifest, build files, generated tooling | **OUT OF SCOPE** for this art PR |

## Task 1 — Verify reference and prepare edits

1. Locate `hpa-186/coal-prompts.md` and `hpa-186/reference-s1.png` in the owner's project files if accessible. **Repository `assets/images/mining/nodes/coal.png` always wins**: check SHA-256 against `reference-s1.png` and use that extra plate only if byte-identical. Prompt text is advice, never authority over source, paths or copy relationships. If project files are unavailable, proceed from this spec and `coal.png` without inventing their contents.
2. Inspect repository `coal.png`: 512×512 RGBA, transparency, palette and rock base. Record its SHA-256 and alpha > 16 bounding box. The review measured `(left=28, top=26, right=486, bottom=486)` (Pillow right/bottom exclusive); **remeasure locally**, rather than assuming these numbers for a changed source. Compare shipped gold/water-ice art for sequence conventions.
3. Leave `coal.png` untouched. Generate S2–S4, idle 02–04 and hit 01–03 using it as the sole S1 edit reference; **exhaust 02–03 use the owner-approved S3 plate**, not S1. Never cascade from *unapproved* generated frames. Work in temporary files until individual assets are accepted.
4. Keep final output rooted only at `assets/images/mining/nodes/` with the exact `node-coal-...` naming.

**Gate:** Canonical source, desired scene framing and prompt pack (if available) are understood; no assets committed yet.

## Task 2 — Generate the four-frame approval batch

Create four individually edited 512×512 RGBA PNGs:

- `node-coal-s2.png`: visible cracks and modestly reduced coal mass, stable base.
- `node-coal-s3.png`: a mostly depleted coal seam, enough remaining chunks for the exhaust beat.
- `node-coal-s4.png`: bare/near-bare rock with a faint ember glow, stable base and shadow.
- `node-coal-hit-01.png`: start of impact; small squash/brighten and upper-left soot/chips.

Edit all four from repository `coal.png`. Scale image-edit outputs uniformly to 512×512 without freehand cropping/reframing; preserve transparent regions. Reject and re-edit baked-checkerboard output rather than repairing grey/white pixels (soot may share those colors). Check the alpha > 16 bbox and rock base: stage S2–S4 left/right/bottom within **4 px of S1**, top may change; Hit 01 can extend left for chips/soot, but right/bottom remain within tolerance and the base must align on overlay. Present the frames beside S1 in a contact sheet and obtain **explicit owner approval** before Task 3.

**Gate:** Owner approves S2–S4 progression and the first hit. Do not generate the remaining seven before approval.

## Task 3 — Generate the seven remaining edits

Edit each sequence from its **specified** source:

- Idle `node-coal-idle-02.png`, `03.png`, `04.png`: edit **`coal.png`**, subtle ember pulse, S1 silhouette unchanged.
- Hit `node-coal-hit-02.png`, `03.png`: edit **`coal.png`**, small flying coal chips/soot, settling and return to S1 without geometric jumps.
- Exhaust `node-coal-exhaust-02.png`, `03.png`: edit the **owner-approved `node-coal-s3.png`**, progressively crumble S3 coal toward approved S4; keep S3's chunk layout and rock base at the start of the beat.

Check the 4 px alpha > 16 bbox tolerance on stage/idle/exhaust left/right/bottom and hit right/bottom (hit left may extend with chips; check stationary base by overlay). Preview in sequence at in-game scale. **Reject and re-edit** frames with jumps, overblown debris, inconsistent highlights, out-of-tolerance base or baked checkerboard. Do not run a checkerboard pixel-repair/flood-fill.

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
2. Each image decodes as a **512×512 RGBA PNG**, with transparent outside pixels. A baked checkerboard **fails review and must be re-edited**, not flood-filled or recolored.
3. SHA-256 byte equality for `coal.png` ↔ S1 ↔ idle-01, S3 ↔ exhaust-01, and S4 ↔ exhaust-04.
4. Generate a **15-row alpha > 16 bounding-box table** (left/top/right/bottom). Anchor to the remeasured S1 bbox (review observed `(28, 26, 486, 486)`). For stage/idle/exhaust, left/right/bottom must each be within **4 px** of S1; top may recede. For hits, left may extend for chips/soot, but right/bottom remain within tolerance and a transparent overlay must prove the stationary rock base aligns. Re-edit any failures. Paste the table into the PR description.
5. Compare superimposed stages and idle/hit/exhaust transitions to catch visual jitter, and inspect all frames on light and dark backgrounds for halos, transparency damage or baked checkerboard.

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

To measure bbox with a **throwaway local Pillow check** (do not commit it):

```python
from pathlib import Path
from PIL import Image

nodes = Path('assets/images/mining/nodes')
for path in [nodes / 'coal.png', *sorted(nodes.glob('node-coal-*.png'))]:
    with Image.open(path) as im:
        assert im.size == (512, 512) and im.mode == 'RGBA', path
        alpha = im.getchannel('A')
        bbox = alpha.point(lambda value: 255 if value > 16 else 0).getbbox()
        print(path.name, bbox)
```

Check the resulting boxes against the remeasured S1 anchor; do not add a committed image-processing pipeline for one art family.

## Task 5 — Review, final PR and unblock HPA-266

1. Produce a 15-frame project-file contact sheet and idle/hit GIF. **Replace the mock in-game still with an actual Flutter screenshot**: only after all 15 PNGs are present, temporarily add `coal('coal')` to `MiningDepositFrames` and `MiningSiteId.carbonRidge => MiningDepositFrames.coal` to `depositFramesFor`, removing `carbonRidge` from its `null` arm in `lib/mining/presentation/mining_visuals.dart`. Keep all Dart changes **uncommitted**, inspect the actual Carbon Ridge Mine Site (including HP/damage-label visibility), and save the screenshot outside the repo.
2. In that local-only preview, run the host asset-decode test:

   ```sh
   flutter test test/mining/presentation/mining_visuals_test.dart --plain-name 'every mining visual resolves with its authored dimensions'
   ```

   **Do not claim the entire test file is green:** its existing closed-switch test still expects Carbon Ridge to be static until HPA-266 updates that assertion. Ensure the temporary Dart edits are the only local source changes before restoring exactly `lib/mining/presentation/mining_visuals.dart` (e.g. `git restore -- lib/mining/presentation/mining_visuals.dart` on a clean source checkout). Do **not** run a broad `git checkout lib/` that could discard unrelated work. Verify the final changed-file list has only the two planning docs and 15 PNGs.
3. Append the approved 15 PNGs to **this same draft PR**. Record SHA-256 copy checks, the **15-row bbox table**, focused test results, and contact-sheet/GIF/real-renderer screenshot locations in the PR description; don't commit previews, local scripts, or temporary Dart edits.
4. Get the owner's explicit visual sign-off. **Keep both planning documents and the 15 approved PNGs in this same PR through merge**; the final diff contains no Dart, tests, scripts, audio, asset-manifest changes or draft art.
5. Only after merge, start HPA-266 from up-to-date `main` for the permanent `MiningDepositFrames.coal` and closed-switch case, tests and docs. **Generalize** `mining_visuals_test.dart`'s current water-ice-only byte-copy check across all animated `MiningSiteId.values.where((id) => MiningVisuals.depositFramesFor(id) != null)` using `content.site(id).depositAsset` as the S1 source; likewise replace the two hard-coded family `hasLength(15)` assertions with a loop over `MiningDepositFrames.values`. HPA-266 must **not** generate or modify this art.

## Completion checklist

- [ ] First four edited frames approved by owner
- [ ] Remaining seven edited frames reviewed
- [ ] Four endpoint PNGs copied byte-for-byte
- [ ] Exactly 15 complete 512×512 RGBA files, 15-row alpha > 16 bbox table with 4 px base tolerance, and transparent edges
- [ ] Contact sheet, idle/hit GIF, and **real Flutter screenshot** reviewed (temporary Dart preview changes restored)
- [ ] No Dart, test, manifest, audio, or extra generated files in art changes
- [ ] Single draft PR updated and explicitly approved; merge unblocks HPA-266

**Do not claim Flutter checks pass in this planning-only PR.** After assets exist, the local-only asset-decode smoke test and real-renderer screenshot are HPA-186 visual acceptance gates, not committed production/test changes. HPA-266 owns permanent wiring, broader animation tests and full repository checks.
