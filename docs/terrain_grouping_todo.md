# Terrain Grouped Generation - Phased TODO Plan

This plan introduces realistic, grouped terrain generation while preserving current APIs and integration points under `lib/game/terrain/`.

Goals:
- Coherent patches (about 9x9) so the map has a clear main terrain type per fragment.
- Natural-looking shapes and edges, avoiding chaotic one-cell randomness.
- Maintain determinism via the planet seed across full and regional generation.
- Keep water (rivers/lakes) coherent and primarily noise-driven.

## Phase 0 — Planning (this doc)
- [x] Define approach and phases
- [x] Specify parameters and acceptance criteria

## Phase 1 — Core patch-based grouping (main type per patch)
Implement patch grouping with a Voronoi-like assignment over jittered centers. Produce coherent, non-square patches with crisp edges. No edge blending yet.

Tasks:
- [x] Add patch grouping parameters (patch size 9, jitter 2, primary weight 0.85)
- [x] Deterministic patch center placement from seed and patch indices
- [x] Per-patch main terrain selection based on biome at the center (prefer land: grass/dirt/sand)
- [x] For each cell, assign base type from the nearest patch center
- [x] Keep existing noise maps, biomes, and feature generation unchanged
- [x] Keep rivers/lakes post-pass as features (base override deferred to Phase 3)

Acceptance Criteria:
- [ ] Terrain shows larger coherent fields (grass/dirt/sand) with clear patch identity
- [ ] Shapes are natural (not perfect 9x9 squares) due to jittered centers
- [ ] No crashes; buildability rules unchanged; rendering intact

## Phase 2 — Natural edge blending
Blend edges between neighboring patches to avoid hard seams.

Tasks:
- [x] Domain warp (light) for organic boundaries
- [x] Edge zone detection using nearest/second-nearest distances
- [x] Transition mapping (e.g., grass↔dirt, sand↔dirt, rock↔dirt, snow↔rock, water↔sand)
- [x] Probabilistic replacement of edge cells using transition rules

Acceptance Criteria:
- [ ] Patch borders appear softly mixed, with plausible neighbor materials
- [ ] Shorelines around water appear sandy or otherwise appropriate

## Phase 3 — Water integration & shorelines
Keep water as a coherent overlay while ensuring convincing shorelines.

Tasks:
- [x] Ensure rivers/lakes remain deterministic (noise-driven overlay)
- [ ] Optionally increase river/lake width for better shapes
- [x] Shoreline preference to sand (or biome-appropriate land type)

Acceptance Criteria:
- [ ] Rivers/lakes consistent, do not get “eaten” by patch rules
- [ ] Edges of water bodies look believable

## Phase 4 — Region generation determinism
Make `generateRegion(...)` seam-free and identical to full generation.

Tasks:
- [x] Derive patch centers purely from patch indices so neighboring regions agree
- [x] In `generateRegion`, compute only centers that could influence the requested window
- [x] Use same assignment/edge logic as full generation

Acceptance Criteria:
- [ ] Loading adjacent regions yields no visible seams at boundaries
- [ ] Results match full-map generation when stitched

## Phase 5 — Debug visualization (optional)

Tasks:
- [x] Toggle to draw patch centers
- [x] Optional overlay for edge zones

Acceptance Criteria:
- [ ] Developer can view and tune patches visually during playtesting

## Phase 6 — Tuning, tests, documentation

Tasks:
- [ ] Parameter tuning: patch size, jitter, edge widths, weights
- [ ] Add targeted tests for determinism, edge logic, and biome distribution sanity
- [ ] Update docs (`TERRAIN_IMPLEMENTATION.md`) and add brief design notes

Acceptance Criteria:
- [ ] Stable visuals on multiple seeds
- [ ] Tests pass reliably
- [ ] Documentation reflects new system

---

## Parameters (initial defaults)
- `patchSizeBase`: 9
- `patchJitter`: 2
- `primaryWeight`: 0.85 (favor primary terrain for patch main type)
- Edge blending (Phase 2): `warpAmplitude`, `warpFrequency`, `edgeWidth`, `edgeGamma` (TBD)

## Notes
- Base patch types intentionally prefer land (grass/dirt/sand). Water will remain primarily driven by coherent features (rivers/lakes) for realism.
- All generation remains deterministic using the planet seed.
