# Test Coverage +10% Design

**Date:** 2026-04-18
**Goal:** Increase line coverage from 81.8% (5238/6405) to ≥91.8% by covering ~641 additional lines.
**Approach:** Expose pure-logic private methods via `@visibleForTesting` in Flame-based files first (Phase 1), then supplement with widget/unit tests for high-yield pages (Phase 2).

---

## Current State

- Total lines measured: 6405
- Lines covered: 5238 (81.8%)
- All 761 existing tests pass

Lowest-coverage files (≥20 lines):

| File | Coverage | Uncovered lines |
|---|---|---|
| `lib/game/terrain/terrain_layer.dart` | 1.3% | 78 |
| `lib/game/grid.dart` | 43.8% | 86 |
| `lib/game/terrain/parallax_terrain_layer.dart` | 47.9% | 101 |
| `lib/game/scene_widget.dart` | 55.2% | 162 |
| `lib/game/main_game.dart` | 61.2% | 83 |
| `lib/pages/resources_page.dart` | 61.8% | 81 |
| `lib/widgets/game/production_overlay/production_overlay.dart` | 62.9% | 124 |

---

## Key Insight: Two Categories of Uncovered Code

Flame-based files have two kinds of uncovered code:

1. **Pure-logic methods** (switch statements, math helpers, list comparisons) — no game loop or Canvas needed. Testable once exposed via `@visibleForTesting`.
2. **Render/lifecycle methods** (`onLoad`, `render(Canvas)`, event handlers) — require a running Flame game. Not worth the cost; leave uncovered.

The codebase already uses `@visibleForTesting` for five test-hook methods (`setGridForTest`, `replaceTerrainDataForTest`, etc.), so this pattern is established.

---

## Phase 1 — Difficult Flame Files (~86 lines)

### `lib/game/terrain/terrain_layer.dart` (~35 lines)

Add `@visibleForTesting` to four private methods and test every branch:

| Method | What to test | Est. lines |
|---|---|---|
| `_getBaseAssetPath(TerrainType)` | All 6 terrain types; `water` returns null | 7 |
| `_getFeatureAssetPath(FeatureType)` | `treeOakSmall`, `treeOakLarge` return paths; others return null | 17 |
| `_getFallbackColor(TerrainType)` | All 6 color branches return correct `Color` | 7 |
| `_listsEqual(List, List)` | Same content, different content, different lengths, empty | 4 |

New test file: `test/game/terrain/terrain_layer_test.dart`

### `lib/game/terrain/parallax_terrain_layer.dart` (~31 lines)

Add `@visibleForTesting` to four private methods:

| Method | What to test | Est. lines |
|---|---|---|
| `_getFeaturePosition(Rect, FeatureType)` | Deterministic output for known cell coords; stays within cell bounds | 9 |
| `_getLargeFeaturePosition(Rect, FeatureType, Vector2)` | Bottom-aligns within cell; applies deterministic offset | 11 |
| `_getFeatureAnchorOffset(FeatureType, Vector2)` | Large trees return non-zero Y; all other features return zero | 5 |
| `_getFeatureSize(FeatureType)` | Each size tier: large tree, small tree, rock types, lake, default | 6 |

New test file: `test/game/terrain/parallax_terrain_layer_test.dart`

### `lib/game/main_game.dart` (~17 lines)

Add `@visibleForTesting` to two private callback methods:

| Method | What to test | Est. lines |
|---|---|---|
| `_onBuildingPlaced(x, y, building)` | `PlacedBuildingData` added to planet; `onPlanetChanged` fires; `Field`/`Bakery` variant captured; null-planet guard | 13 |
| `_onBuildingRemoved(x, y)` | Building removed from planet; callback fires; null-planet guard | 4 |

Add to: `test/game/main_game_test.dart`

### `lib/game/grid.dart` (~3 lines)

No production code change needed. Add one test case to `test/game/grid_test.dart`:
- Call `getSpriteForBuilding` with a building that has a non-null `assetPath` — cache is empty so returns null, but the truthy branch (line 41) is now covered.

---

## Phase 2 — Supplementary High-Yield Files (~415 lines target)

Phase 2 supplements Phase 1 to reach the 641-line target. No production code changes.

### `lib/game/scene_widget.dart` (162 uncovered → target ~80 lines)

Expand `test/game/scene_widget_test.dart`:
- Building selection sets `buildingToPlace`; second tap triggers placement or cancel
- Delete mode toggle flips state; tapping a building shows deletion confirmation
- Worker assignment callback wires through to `onPlanetChanged`
- Planet-changed callback propagates correctly

### `lib/widgets/game/production_overlay/production_overlay.dart` (124 uncovered → target ~80 lines)

Expand `test/widgets/game/production_overlay_test.dart`:
- Resource filter select/deselect updates visible nodes
- Node tap opens detail panel; second tap closes it
- Empty state renders when no buildings are placed
- Graph rebuilds when building list changes

### `lib/game/services/save_service.dart` (67 uncovered → target ~45 lines)

Expand `test/services/save_service_test.dart`:
- Round-trip save/load for `Field` crop variant and `Bakery` product variant
- Load with missing or malformed SharedPreferences keys returns graceful defaults
- Multi-planet isolation: saving planet A does not affect planet B load

### `lib/pages/resources_page.dart` (81 uncovered → target ~50 lines)

Add/expand `test/pages/resources_page_test.dart`:
- Page renders resource cards for all `ResourceCategory` groups
- Rate display shows `+` prefix for positive rate, `-` for negative
- Zero-rate resources render without a rate badge

---

## Constraints

- No changes to render methods, `onLoad`, or event handler implementations — these require a running Flame game loop and the effort/gain ratio is poor.
- All new tests must pass `flutter analyze --fatal-infos` and `dart format`.
- Follow existing test patterns: `SharedPreferences.setMockInitialValues` in `setUp`, plain `test()` for logic, `testWidgets` for widget tests.
- Test files mirror `lib/` structure under `test/`.

---

## Success Criteria

- `flutter test --coverage` reports ≥91.8% line coverage
- All existing 761 tests continue to pass
- No new `flutter analyze` warnings
