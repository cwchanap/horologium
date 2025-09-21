# Terrain & Camera Alignment Guide

This document summarizes the final conventions and lessons learned for aligning the terrain, grid, and camera in Horologium using Flame.

## Final Rendering Conventions

- **Anchor & Position**
  - `Grid` and `ParallaxTerrainComponent` (terrain parent) use `Anchor.center` and `position = Vector2.zero()` (world origin).
  - `ParallaxTerrainLayer` (child layers) use `Anchor.center` and `position = size / 2` so that the layer’s local top-left (0,0) aligns with the parent’s local top-left (0,0). This cancels the anchor shift for children.
- **Local Coordinate System**
  - Inside `render()` for center-anchored components, we draw from the **local top-left (0,0)**.
  - The visual center is therefore at `(size.x/2, size.y/2)`.
- **Borders & Rects**
  - Draw borders/fills with `Rect.fromLTWH(0, 0, size.x, size.y)`.
- **Markers (when debugging)**
  - Top-left: `(0,0)`
  - Center: `(size.x/2, size.y/2)`
  - Bottom-right: `(size.x, size.y)`

## Why This Works

With `Anchor.center`, Flame’s internal transform handles anchor shifting. Drawing from local top-left (0,0) keeps a single convention. For top-level components (`Grid`, terrain parent), `position = Vector2.zero()` places the visual center at the world crosshair. For child layers, set `position = size / 2` so the layer’s local `(0,0)` top-left matches the parent’s local `(0,0)`.

Previously, mixing center-origin drawing (e.g., `Rect.fromLTWH(-size/2, -size/2, ...)`) with `Anchor.center` caused a **double offset**. This manifested as center markers appearing at roughly `(-25, +25)` pixels from the crosshair.

## Input Mapping

- **Screen → World**: `camera.globalToLocal(event.canvasPosition)`
- **World → Component Local**: `component.toLocal(worldPosition)`
- **Local → Grid Indices**: interpret local as top-left based (`x / cellWidth`, `y / cellHeight`).
- **Placement Preview**: When positioning via grid indices:
  - Local top-left = `(gridX * cellWidth, gridY * cellHeight)`
  - World position = `local - (component.size / 2)`

## Files and Key Code Paths

- `lib/game/grid.dart`
  - Renders grid lines and border from `(0,0)`.
  - `getGridPosition()` treats local coords as top-left based.
  - Buildings are drawn from top-left (`x * cellWidth`, `y * cellHeight`).
- `lib/game/terrain/parallax_terrain_component.dart`
  - Parent terrain component, Anchor.center at world origin.
  - Atmosphere and optional overlays draw from `(0,0)` (local top-left).
  - `showDebug` gates parent overlays; propagated to child layers.
  - Creates `ParallaxTerrainLayer` children with `Anchor.center` and `position = size/2`.
- `lib/game/terrain/parallax_terrain_layer.dart`
  - Anchor.center child positioned at `size/2` so its local top-left aligns with parent’s top-left.
  - Renders cells from `(x * cellWidth, y * cellHeight)` (local top-left).
  - `showDebug` gates overlays; `enableParallax` optionally offsets position relative to camera.

## Camera Fit & Clamp (Summary)

- Camera zoom is computed to fit the entire terrain in the viewport (no under-zoom below fit).
- Clamping ensures the camera viewport remains within terrain bounds.
- Centering positions the camera at the world origin.

## Parallax

- Disabled by default (`enableParallax = false`).
- When enabled, layer `position = size/2 + cameraPosition * (parallaxSpeed - 1.0)`.
- Do not change the local drawing convention; still render from `(0,0)` in `render()`.

## Z-Order (Priorities)

- During debugging we temporarily raised the terrain’s priority to visualize its overlays on top.
- For normal gameplay, pick what’s best for UX:
  - Terrain below grid if you want grid lines visible.
  - Terrain above if you prefer a clean look without grid.

## Debug Flags

- Parent: `ParallaxTerrainComponent.showDebug`
- Layers: `ParallaxTerrainLayer.showDebug` (propagated by parent)

These can be toggled at runtime to switch between clean visuals and diagnostic overlays.

## Common Pitfalls

- **Double-offset**: Using `Anchor.center` and also drawing from `(-size/2, -size/2)` shifts content twice.
- **Mixed conventions**: If any component uses a different local origin, orange center markers won’t land on the crosshair.
- **Asset paths**: Ensure asset paths match `pubspec.yaml` directories.

## Asset Paths

- In `TerrainAssets`, use keys like `terrain/base/grass_base.png` (without the `assets/images/` prefix).
- Flame’s `Images` adds the `assets/images/` prefix automatically on load (on web it fetches `assets/<key>`). This avoids double-prefix bugs.
- Ensure `pubspec.yaml` includes these directories under `flutter.assets`:
  - `assets/images/terrain/`
  - `assets/images/terrain/base/`
  - `assets/images/terrain/features/` (and subfolders)
  - etc.
  The final resolved key at runtime becomes `assets/images/terrain/...`.

## Verification Checklist

- Borders: Red (terrain, parent) and Blue (grid) overlap perfectly when `showDebug` is enabled.
- Center markers/axes (when debug is on) line up exactly at the crosshair.
- Camera: Zoom fit and clamping keep the viewport within the terrain.

## Next Steps

- Tune parallax speeds per depth.
- Add more terrain feature sprites.
- Provide a UI toggle for `showDebug`/`enableParallax`.
