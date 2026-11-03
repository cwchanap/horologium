# HPA-87 — Io Frontier art: design specification

- **Status:** Proposed for review (2026-11-02); art is not generated in the planning commit.
- **Linear:** https://linear.app/cwchanap/issue/HPA-87/mining-art-io-frontier-planet-cavern-and-node-art
- **Unblocks:** https://linear.app/cwchanap/issue/HPA-262/mining-content-ship-io-frontier-as-the-fifth-planet-after-ceres
- **Delivery:** One HPA-87 draft PR, with this spec and its implementation plan first, then seven approved PNGs in **the same PR**. The seven PNGs are the only production assets. No Dart, tests, manifests, scripts or preview files committed.

## Player-facing outcome

After mastering Ceres, the player should encounter a fifth world that is unmistakably **Io**: sulfur-yellow volcanic terrain with orange lava heat and charcoal basalt, not another Mars-like rust planet or Ceres-like grey-blue ice world. Its three sites should remain visually distinguishable both as Site Deck thumbnails and as the native-size tiled Mine Site background; each deposit should be legible above that background.

This is **art only**. HPA-262 wires the images and implements the planet, progression, save contract and integration tests after HPA-87 merges. No animated nodes or new renderer abstractions.

## Existing assets are the design references

| Output family | Reference in current `main` | Required output | Why |
| --- | --- | --- | --- |
| Planet | `assets/images/mining/planets/mars_frontier.png` | 640×640 RGBA PNG | Match camera, planet diameter, rim light and transparent surround. Verified Mars is 640×640; the older Ceres planet file is **512×512**, so do **not** copy Ceres' pixel dimensions. |
| Cavern / Site Deck art | `assets/images/mining/caverns/cobalt_ore.png` | 800×1200 RGB PNG | Reuse the existing floor/walls camera, zoom, composition and lighting. These images tile at native size in the Mine Site. HPA-200 corrected the too-small Ceres caverns; do not repeat 512×512 caverns. |
| Deposit | `assets/images/mining/nodes/cobalt_ore.png` | 512×512 RGBA PNG | Reuse its single-deposit footprint, base/contact shadow, camera and transparent surround. Verified cobalt node is 512×512 RGBA. |

Before generation, inspect the actual reference pixels and confirm the cavern reference still matches the documented 800×1200 family. The Linear ticket's dimensions take precedence if a legacy file differs.

## Exact deliverables

| Path under `assets/images/mining/` | Art direction |
| --- | --- |
| `planets/io_frontier.png` | Full Io-like globe: bright sulfur-yellow/orange plains, dark lava calderas, modest red-black features and a **faint** volcanic plume breaking the limb. Bright warm rim lighting, same scale as Mars, no Jupiter dominating the frame. |
| `caverns/sulfur.png` | **Sulfur Flats:** steaming sulfur crust, yellow mineral deposits and warm ground. Large uncluttered central floor; vents and deposits nearer edges. |
| `caverns/cinnabar.png` | **Cinnabar Vents:** crimson mineral seams framing cooled black lava channels; red accent distinct from Sulfur Flats' yellow. |
| `caverns/osmium.png` | **Osmium Caldera:** dark basalt with dense blue-grey metallic seams; coolest/darkest of the three, but the floor and mining robots remain readable. |
| `nodes/sulfur.png` | One centered sulfur deposit of bright yellow crystals, grounded on a small matching rock base, transparent background. |
| `nodes/cinnabar.png` | One centered blood-red cinnabar crystal deposit with the **same footprint and camera** as sulfur/cobalt, transparent background. |
| `nodes/osmium.png` | One centered blue-grey osmium nugget cluster with a cold metallic sheen; same footprint/camera, transparent background. |

The resource names and output paths align with HPA-262's current content plan. If naming changes, settle it **before** generating images; do not add alias files.

## Consistency and composition rules

- Keep the existing illustrative mining visual language: coherent perspective, controlled highlights, rich material contrast and consistent outline softness. Do not change the camera or invent a second art style.
- Across three caverns, preserve camera height, wall/floor proportion, horizon/orientation, open-center mining space and scale. They will repeat as 800×1200 tiles; avoid tight repetitive checkerboards, tiny rooms and busy grid-like marks.
- Caverns are fully opaque **RGB** scenes (not transparent node plates). Ensure the site-card thumbnail still identifies its resource without relying on UI text.
- Nodes are **single isolated deposits** on genuine alpha, with similar margins, bottom anchor and contact shadow; no scenery, lettering, UI, multiple scattered deposits, shadows in opaque square backgrounds or baked checkerboard.
- The planet is a single isolated globe on alpha; preserve Mars' framing and lighting, with Io's warm volcanic palette. No labels, border, black square or scene backdrop.
- Use the HPA-262 silhouette fallback accents as material guides: sulfur = bright yellow, cinnabar = red, osmium = blue-grey (`0xFF9FB4C7`). These are color-direction anchors, not a demand for flat-colored art.
- Prefer a clean original generation or reference-guided edit over pixel repair. If an image has a baked transparency checkerboard, reject/re-edit it where practical. If cleanup is unavoidable, normalize **only edge-connected baked checkerboard regions**, never all similarly colored interior mineral pixels. Inspect on dark and light backgrounds.

## Acceptance / explicit review gate

1. Seven exact paths, no extras. Each PNG decodes at its target dimensions and mode: planet **640×640 RGBA**, three caverns **800×1200 RGB**, three deposits **512×512 RGBA**.
2. Inspect alpha and edges: clear outer corners, no opaque squares, halos, jagged silhouettes or destroyed light-grey mineral detail. Inspect each node over the actual cavern colors as well as black/white.
3. Review a labeled seven-image contact sheet, plus at least one **native-scale repeat preview** for every cavern and node-on-cavern composites at approximate game scale. Store previews and raw generations in project files, **not** in the repository.
4. Approve style against Mars, cobalt cavern and cobalt node side by side. Confirm distinct material colors and visual readability at mobile scale.
5. **Owner explicitly approves the full seven-image set on this PR before merge.** Do not mark HPA-87 complete before that approval and the asset commit.

## Out of scope

Io content definitions and economics, save or controller changes, Planet/Mining Site view wiring, animated node frame families, new shaders, atlases, image-generation tooling, SFX, and changes to `pubspec.yaml`. The existing manifest already includes `planets/`, `caverns/` and `nodes/`.