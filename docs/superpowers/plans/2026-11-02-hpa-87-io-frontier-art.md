# HPA-87 — Io Frontier art implementation plan

- **Status:** Proposed (2026-11-02); no art has been produced by the planning commit.
- **Ticket:** https://linear.app/cwchanap/issue/HPA-87/mining-art-io-frontier-planet-cavern-and-node-art
- **Design:** [Io Frontier art design](../specs/2026-11-02-hpa-87-io-frontier-art-design.md)
- **Unblocks:** https://linear.app/cwchanap/issue/HPA-262/mining-content-ship-io-frontier-as-the-fifth-planet-after-ceres
- **PR rule:** This is the **single PR for HPA-87**. Review these documents first; generate, review and commit the seven PNGs on the **same branch/PR**. No second implementation PR for this ticket. HPA-262 is a separate, already-existing coding ticket and must wait for these assets to merge.

## Reuse survey / scope

| Existing seam | Decision |
| --- | --- |
| `assets/images/mining/planets/mars_frontier.png` | Use as the authoritative planet camera/lighting/640×640 RGBA reference. Do not use Ceres' 512×512 dimensions. |
| `assets/images/mining/caverns/cobalt_ore.png` | Use its camera, 800×1200 portrait composition, perimeter/walkable-floor balance and lighting. The Ceres cavern size repair in HPA-200 is an explicit warning against smaller tile art. |
| `assets/images/mining/nodes/cobalt_ore.png` | Use as the 512×512 RGBA deposit footprint / shadow reference. |
| `pubspec.yaml` | Already includes all three asset directories. **Do not modify**. |
| `lib/mining/mining_content.dart` | Already uses `planetAsset`, `cavernAsset`, `depositAsset` and `cardAsset` strings. **Do not wire Io here**; HPA-262 owns new content and references. |
| `test/mining/presentation/mining_visuals_test.dart` | Its existing rootBundle test only checks **currently authored** content. Do not claim it validates unreferenced Io paths; HPA-262 will extend the content test coverage. |

Do not introduce an art registry, additional renderer, new Dart code, tests, SFX or scripts. Only the two planning files and seven PNGs should be changed in the final diff. Store raw generators' outputs and review previews outside git.

## Task 1 — Inspect references and lock the art brief

1. Check out this PR's branch on the art-capable environment. Inspect Mars planet, cobalt cavern and cobalt node visually **side by side**, including their camera/scale, background colors, edges and in-game usage. Verify image sizes and channel modes locally.
2. Confirm the HPA-262 names are still `io_frontier`, `sulfur`, `cinnabar` and `osmium`. If content names need to change, settle that before generation; do not create aliases.
3. Lock the seven outputs and sizes from the design. Note especially that **Mars is 640×640 RGBA** and the planet-size target is *not* Ceres' 512×512; caverns target **800×1200 RGB** and nodes **512×512 RGBA**.
4. Prefer reference-guided generation/editing using those images directly. The existing HPA-87 issue suggests the owner's Mac remote-control/Codex workflow; use it if available. No new image-generation infrastructure is part of this PR.

**Gate:** owner accepts the visual brief and exact filenames. No code change.

## Task 2 — Generate a three-image style pilot

Generate and present (off-repository previews):

- `assets/images/mining/planets/io_frontier.png` — isolated volcanic globe with sulfur-yellow/orange ground and faint plume, matched to Mars.
- `assets/images/mining/caverns/sulfur.png` — 800×1200 opaque Sulfur Flats floor / edge walls, matched to cobalt's camera.
- `assets/images/mining/nodes/sulfur.png` — a single bright yellow sulfur deposit, 512×512 RGBA with cobalt's footprint.

Compare the trio against the actual family references: they should share one warm palette, the cavern should tile without looking like many tiny rooms, and the transparent deposit should be readable over its cavern at mobile scale. Reject/re-edit mismatched perspective, transparency checkerboard, overly cluttered floor, illegible highlights or sprite clipping. Obtain a quick owner direction check before generating the other four (avoids seven inconsistent outputs).

**Gate:** the pilot anchors the planet style, cavern composition, deposit geometry and alpha quality.

## Task 3 — Complete four remaining images

Using the approved pilot *and the original family references*, generate:

- `assets/images/mining/caverns/cinnabar.png` — dark cooled lava channels and red mineral seams.
- `assets/images/mining/caverns/osmium.png` — dark basalt, blue-grey dense metal seams, still readable.
- `assets/images/mining/nodes/cinnabar.png` — single red crystal cluster on transparent ground with the same size/anchor as sulfur.
- `assets/images/mining/nodes/osmium.png` — single blue-grey metal deposit on transparent ground with the same size/anchor as sulfur.

Preserve the **identical cavern camera and deposit footprint** across sites. A different palette/material is desired; a different visual system is not. No animated variants. Work with temporary local assets until accepted; commit only final output PNGs.

**Gate:** all seven final images visually coherent, with a labeled contact sheet and side-by-side family comparison outside the repository.

## Task 4 — Local asset checks and real-size previews

Run a throwaway local check (do not commit this script) with Pillow:

```python
from pathlib import Path
from PIL import Image

base = Path("assets/images/mining")
expected = {
    "planets/io_frontier.png": ((640, 640), "RGBA"),
    "caverns/sulfur.png": ((800, 1200), "RGB"),
    "caverns/cinnabar.png": ((800, 1200), "RGB"),
    "caverns/osmium.png": ((800, 1200), "RGB"),
    "nodes/sulfur.png": ((512, 512), "RGBA"),
    "nodes/cinnabar.png": ((512, 512), "RGBA"),
    "nodes/osmium.png": ((512, 512), "RGBA"),
}
for relative, (size, mode) in expected.items():
    with Image.open(base / relative) as image:
        assert image.format == "PNG", relative
        assert image.size == size and image.mode == mode, relative
        if mode == "RGBA":
            assert image.getpixel((0, 0))[3] == 0, relative
print("Seven Io PNG files have the intended sizes/modes.")
```

Then manually verify:

1. Genuine transparent surrounds on planet/nodes against both white and dark UI backgrounds; no black or checkerboard squares or edge halos. If normalization is needed, limit it to **edge-connected checkerboard background** and inspect the preserved sprite; otherwise re-edit.
2. Cavern renders are fully opaque, their center is not overfilled, and an **800×1200 repeated-tile preview** does not form checkerboard seams or dozens of miniature rooms.
3. Compare node-on-cavern composites and each asset at approximate game display size. Distinct yellow / crimson / blue-grey mineral identities, no unreadable dark-on-dark osmium.
4. Create a seven-image contact sheet and at least one repeat preview per cavern. Keep contact sheet, intermediate generations, and composites in project files or review attachments, **not** in the source tree.
5. Confirm only seven expected **production** images were added; no pre-existing reference PNG was overwritten.

The existing `mining_visuals_test.dart` bundle test covers only wired content, **not these seven unreferenced Io files**. As an optional packaging smoke test, run `flutter build web` and inspect the generated web asset directory for all seven files. Leave the repository's normal CI gates green. Do not add a test or wire Io just to validate assets in HPA-87.

## Task 5 — Same-PR review, merge and handoff

1. Commit the seven approved PNG files to **this draft PR**. Keep the design spec and plan alongside them; there is no second art PR.
2. Update the PR body with the image contact sheet/preview references, seven-file dimension check, any repairs performed, and a note that Dart/test/manifest/build configuration is unchanged.
3. Get **explicit owner approval of the complete asset set on the PR**. Until then, leave the PR in draft and HPA-87 in Todo/In Progress.
4. After merging, mark HPA-87 Done and begin HPA-262 from current `main`. HPA-262 separately adds `MiningPlanetId.ioFrontier`, site/resource enums and content, view/tests/journey updates, and handles its already-described Ceres→Io completion reward changes.

## Expected final changed paths

```text
docs/superpowers/specs/2026-11-02-hpa-87-io-frontier-art-design.md
docs/superpowers/plans/2026-11-02-hpa-87-io-frontier-art.md
assets/images/mining/planets/io_frontier.png
assets/images/mining/caverns/sulfur.png
assets/images/mining/caverns/cinnabar.png
assets/images/mining/caverns/osmium.png
assets/images/mining/nodes/sulfur.png
assets/images/mining/nodes/cinnabar.png
assets/images/mining/nodes/osmium.png
```

Exactly **seven new PNGs** and two planning documents. No runtime, art-creation tool, build tooling or unrelated source changes.