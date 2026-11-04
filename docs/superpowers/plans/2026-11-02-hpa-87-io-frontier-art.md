# HPA-87 — Io Frontier art implementation plan

- **Status:** Art delivered — awaiting owner full-set approval; HPA-262 integration deferred (plan proposed 2026-11-02).
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

## Task 1 — Measure reference art (no separate approval gate)

1. Check out this PR's branch in an art-capable environment. Inspect Mars planet, cobalt cavern and cobalt node side by side, measuring their sizes/modes and alpha >16 bounding boxes or cavern edge-wrap (first/last rows and columns). Compare against the ranges in the design; these are the existing visual contracts, not a new renderer.
2. The HPA-262 names and the seven output paths are already agreed in the ticket and this draft PR: `io_frontier`, `sulfur`, `cinnabar`, `osmium`. Do not create aliases. If the ticket changes names, align them before rendering.
3. **Edit the existing reference art by default:** Mars planet → Io globe; cobalt cavern → three Io caverns; cobalt node → three Io nodes. Preserve camera, edge wrap, composition and footprint. Resort to fresh generation only when edits cannot achieve the material. The existing owner-Mac/Codex art workflow can be reused without adding tools to the repo.

No redundant Task 1 owner-approval gate; this plan review already approves the brief. The pilot and full-set art reviews remain separate.

## Task 2 — Generate a three-image style pilot

Generate and present (off-repository previews):

- `assets/images/mining/planets/io_frontier.png` — isolated volcanic globe with sulfur-yellow/orange ground and faint plume, matched to Mars.
- `assets/images/mining/caverns/sulfur.png` — 800×1200 opaque Sulfur Flats floor / edge walls, matched to cobalt's camera.
- `assets/images/mining/nodes/sulfur.png` — a single bright yellow sulfur deposit, 512×512 RGBA with cobalt's footprint.

Use reference-guided **edits**, not independent redraws by default. Compare the trio against the shipped families (especially gold, iron and silica as palette neighbours): sulfur needs steam/crystal habit/charcoal basalt to differ from gold. Ensure sulfur mineral reads on side walls in the y≈400–800 source band used by the center-cropped Site Deck card. Preview the node at **22, 30 (unlocked Stellar Map only), 80, 120 and 168 px**, and the planet at **34 px**; inspect the cavern in the **portrait** Site Deck's first/second/third **216/170/104 px** card crops at both phone widths (including the 104 px third card) and as native-size repeated tiles. Reject/re-edit mismatched perspective, baked checkerboard, cluttered floor, weak edge wrap, illegible highlights or clipped sprites. Obtain a quick owner pilot direction check before generating the other four (avoids seven inconsistent outputs).

**Gate:** the pilot anchors the planet style, cavern composition, deposit geometry and alpha quality.

## Task 3 — Complete four remaining images

Using the approved pilot *and the original family references*, generate:

- `assets/images/mining/caverns/cinnabar.png` — dark cooled lava channels and red mineral seams.
- `assets/images/mining/caverns/osmium.png` — dark basalt, blue-grey dense metal seams, still readable.
- `assets/images/mining/nodes/cinnabar.png` — single red crystal cluster on transparent ground with the same size/anchor as sulfur.
- `assets/images/mining/nodes/osmium.png` — single blue-grey metal deposit on transparent ground with the same size/anchor as sulfur.

Preserve the **identical cavern camera, card-visible middle-band minerals and deposit footprint** across sites. Compare red Cinnabar against existing `iron_ore.png` and the orange `silica.png`; compare sulfur against existing `gold.png`. Make the dark Osmium scene readable at the Site Deck's **0.48 locked opacity**. A different palette/material is desired; a different visual system is not. No animated variants. Work with temporary local assets until accepted; commit only final output PNGs.

**Gate:** all seven final images visually coherent, with a labeled contact sheet and side-by-side family comparison outside the repository.

## Task 4 — Local asset checks and render-path previews

Run this **throwaway** local Pillow check (do not commit the script). The alpha >16 bbox ranges and the ≤12 cavern edge threshold are **targets measured from the newer cobalt-family generation**, not averages of all shipped art — the older `nodes/coal.png`, `nodes/stone.png`, `caverns/iridium.png` (12.32) and `caverns/silica.png` (12.03) fall outside them:

```python
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

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
# (left, top, right, bottom), Pillow right/bottom exclusive.
node_envelope = ((40, 61), (4, 19), (454, 475), (495, 509))
planet_envelope = ((17, 26), (13, 25), (614, 624), (607, 620))

def seam(a, b):
    return sum(ImageStat.Stat(ImageChops.difference(a, b)).mean) / 3

for relative, (size, mode) in expected.items():
    with Image.open(base / relative) as image:
        assert image.format == "PNG", relative
        assert image.size == size and image.mode == mode, relative
        if mode == "RGBA":
            bbox = image.getchannel("A").point(
                lambda a: 255 if a > 16 else 0
            ).getbbox()
            assert bbox is not None, relative
            envelope = planet_envelope if relative.startswith("planets/") else node_envelope
            assert all(lo <= value <= hi for value, (lo, hi) in zip(bbox, envelope)), (relative, bbox)
            print(relative, "alpha>16 bbox", bbox)
        else:
            w, h = image.size
            left = image.crop((0, 0, 1, h))
            right = image.crop((w - 1, 0, w, h))
            top = image.crop((0, 0, w, 1))
            bottom = image.crop((0, h - 1, w, h))
            assert seam(left, right) <= 12, (relative, "horizontal wrap")
            assert seam(top, bottom) <= 12, (relative, "vertical wrap")
print("Seven Io PNGs passed size, mode, footprint and edge-wrap checks.")
```

Then verify visually, using the **actual Flutter render dimensions** from `mining_grid_map.dart`, `site_deck_screen.dart` and `stellar_map_screen.dart`:

1. For planet and nodes, confirm true alpha over white and dark UI backgrounds, no jagged edge halos, baked checkerboard or destroyed mineral highlights. **Reject/re-edit** the planet and osmium node rather than applying checkerboard normalization. For any other eligible image with unavoidable edge-connected cleanup, record the changed-pixel mask/count in the PR and rerun the alpha bbox check; do not flood-fill checkerboard-colored mineral pixels.
2. Repeat each opaque cavern at **native 800×1200** within a 2800×2800 sample, to expose x=800/1600/2400 and y=1200/2400 seams. Check a clear central mining floor and the numerical edge-wrap threshold alongside the tiled image.
3. Use the **active portrait branch**, `_PortraitSiteDeck`, for **360×640 and 430×932**. Its **outer card** widths are **332 and 402 px** (14 px side insets) and heights **216 / 170 / 104 px** regardless of unlock state; the visible art frame is ~1–2 px inside that because the 1–1.5 px `Border.all` draws in-bounds. Use the real `BoxFit.cover` center crop and **all three `_PrototypeSiteCard` art treatments** for each position: **operational** (`.05/.5/.93` gradient), **unlocked but not operational** (the darker `.15/.58/.94` gradient — easy to miss, and darker than operational), and **locked** (**0.48 image opacity** plus flat `0x70060A10` overlay). In particular, check that the **104 px third card** still identifies Osmium after cropping and dark overlay. The y≈400–800 source band is only a composition guide, **not** a hard-coded crop calculation. The **128 / 148 / 196 px** heights are for the separate *landscape* `_SiteCard` branch; do not use them for phone previews.
4. Preview each matching node over its cavern at **22 px** (Site Deck chip), **26 px** (offline-return sheet resource icon), **30 px** (**unlocked** Stellar Map node) and **80/120/168 px** (Mine Site 1×1/2×2/3×3; also at **0.62 unsurveyed opacity**). **Do not preview a 0.45-opacity locked Stellar Map node:** the locked branch shows only a lock and requirement, never the node asset. Preview the Io planet at **all four render sizes**: **34 px** in its deck-header context, **92 px at 0.34 opacity** (locked teaser, `right: -2, top: -2`), **96 px** (unlocked non-active card, `right: -8`), and **172 px** (active card, `right: -27, top: -43` inside `Clip.antiAlias` — the top-right limb is clipped, so the plume must sit on a surviving limb). Also preview each cavern as the **`MiningSheetScene` full-screen `BoxFit.cover` background** at 0.5 opacity (0.42 Settings) behind the Technology/Settings sheets on both portrait sizes — the cover crop drops most of the side walls on phone widths. Look for node margins causing undersized deposits and dark-on-dark osmium disappearing.
5. Prepare a labeled seven-output contact sheet **alongside all 12 existing caverns and their 12 static nodes** as palette comparators; inspect sulfur vs gold, cinnabar vs iron, and orange silica. Keep contact sheet, intermediate generations, composites and the temporary check script in project files/review attachments, **not** the repository.
6. Confirm exactly seven new **production** PNGs, with no pre-existing reference overwritten and no Dart, tests, manifests, scripts or build changes.

The existing `mining_visuals_test.dart` bundle test checks only **wired content**, not these seven unreferenced Io files; HPA-262 handles the actual load proof after wiring. The repository verification gates still apply unchanged, including `flutter build web`; only an additional Io-specific packaging smoke test is unnecessary, since `pubspec.yaml` already bundles the asset directories and that extra build adds no Io-specific evidence. Existing repository CI should remain green. Do not add a test or wire Io just to validate assets in HPA-87.

## Task 5 — Same-PR review, merge and handoff

1. Commit the seven approved PNG files to **this draft PR**. Keep the design spec and plan alongside them; there is no second art PR.
2. Update the PR body with the seven-file dimensions/modes, alpha bboxes and cavern seam measurements, actual-size crop/opacity preview links, palette comparisons, any changed-pixel mask/count for permitted repairs, and a note that Dart/test/manifest/build configuration is unchanged.
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