# HPA-438 Mining Secondary-Surface UI Parity Design

## Status

Approved and review-resolved design for HPA-438, **Revamp Technology, Settings, and Offline Return for mining UI parity**.

This remains a presentation-focused follow-up to completed HPA-285. Planning, implementation, responsive variants, visual evidence, tests, and cleanup stay on one branch and one pull request.

The user-supplied `Horologium Merge Mining (standalone).html` is the visual source of truth for hierarchy, composition, geometry, typography intent, color, and responsive layout. Repository state/content remain authoritative for real values and gameplay behavior.

## Goal

Revamp exactly these existing surfaces:

1. `TechnologySheet`
2. `MiningSettingsSheet`
3. `OfflineReturnSheet`

Canonical mock states:

- Technology portrait — `402×874`
- Technology landscape — `874×402`
- Settings portrait — `402×874`
- Offline Return portrait — `402×874`
- Offline Return landscape — `874×402`

Measured mock geometry:

- Technology landscape right panel: **528 px** wide at `874×402`
- Offline Return landscape summary panel: **470 px** wide at `874×402`

Technology and Settings remain overlays over live gameplay context. Offline Return is a distinct full-screen result.

## Non-goals

Do not change:

- `MiningController`, `MiningSimulation`, `MiningSave`, or `MiningSaveRepository` behavior;
- `MiningContentRegistry` authored technology/economy/offline-cap tables;
- save schema or migration behavior;
- technology costs, gates, effects, or max level;
- audio preference keys or `AudioManager` ownership;
- offline accrual semantics or `OfflineProductionSummary`;
- Site Deck, Mine Site, Stellar Map, or primary navigation layouts;
- mining lifecycle, haptics, or foreground refresh behavior.

Do not add:

- Provider/Riverpod/Bloc/service locator/command bus;
- routing package or generic modal manager;
- design-system package;
- generic toggle/control framework;
- new reward/claim/retention state;
- persisted UI selection;
- screenshot service or new visual-test stack.

## Existing ownership and reusable seams

Keep these owners:

```text
MiningShell
  owns controller / lifecycle / audio / reducedMotion / modal launch

TechnologySheetView / TechnologyTrackView
  own read projection for Technology presentation

AudioManager
  owns musicEnabled / musicVolume persistence and mutation

OfflineProductionSummary
  owns simulation-produced offline result data

MiningContentRegistry
  owns authored names, assets, and offlineCapFor(logistics)
```

Reuse:

- `MiningTheme`
- `MiningHex`
- `MiningCashChip`
- `MiningCargoGauge`
- `MiningVisuals`
- catalog planet/resource assets and silhouettes
- existing mining widget-test structure
- existing `visual_parity_golden_test.dart` only where a stable in-scope finder can be goldened

## Presentation projection boundary

`lib/mining/mining_progression_views.dart` is a pure read-projection file, not a domain/state owner. HPA-438 may make additive/simplifying changes there when they prevent rule-shaped logic from leaking into widgets.

### Technology node state

Add a public presentation enum beside `TechnologyTrackView`:

```dart
enum TechnologyNodeState { owned, actionable, blocked, future }
```

Add:

```dart
TechnologyNodeState stateForLevel(int nodeLevel)
```

The method projects only from existing `TechnologyTrackView` fields:

- `nodeLevel <= level` → `owned`
- `nodeLevel == level + 1 && !isMaxLevel && canPurchase` → `actionable`
- `nodeLevel == level + 1 && !isMaxLevel && !canPurchase` → `blocked`
- otherwise → `future`

Widgets render `stateForLevel()`; they do not re-derive affordability, gate satisfaction, max-level state, or disabled reasons.

Use `MiningContentRegistry.maxTechnologyLevel` for all node loops and `MAX LV` copy.

The existing `nodeAvailability`, `nextNodeAvailability`, and `surveyingNodeAvailability` projection members are unused by production/tests. Remove them while touching this projection rather than carrying dead fields into the new tree.

No technology mutation rule moves into the projection layer.

## Visual language

Use current `MiningTheme` tokens for core colors. Do not duplicate equivalent raw values in the new chrome or Technology nodes.

Relevant existing tokens:

```text
panel       MiningTheme.panel
accent      MiningTheme.accent
highlight   MiningTheme.highlight
warning     MiningTheme.warning
gate        MiningTheme.gate
```

Keep Orbitron as the application/display family.

Add IBM Plex Mono Regular (`400`) and SemiBold (`600`) with OFL license for small status, metadata, explanatory, and percentage copy on these surfaces only. Do not replace the app-wide theme or load fonts at runtime.

## Shared modal chrome

Create one small `MiningModalChrome` used by Technology and Settings only.

It owns:

- `MiningTheme.panel` fill;
- cyan top edge using `MiningTheme.accent`;
- existing 42×4 cyan handle treatment;
- rounded upper corners;
- shadow;
- safe-area-aware padding;
- optional protruding `MiningHex` leading/trailing affordances.

It does not own:

- routing;
- state;
- titles;
- business actions;
- scroll policy;
- Technology nodes;
- Settings cards;
- Offline Return layout.

Offline Return must not use the drag handle/chrome helper.

## Technology

### Ownership

Keep the public action boundary:

```dart
TechnologySheet(
  view: TechnologySheetView,
  onPurchase: ValueChanged<TechnologyTrack>,
)
```

`TechnologySheet` becomes stateful only for transient selected-track state. Selection is not saved.

Default selection priority:

1. first track where `canPurchase == true`;
2. else first non-max track;
3. else first track.

A selectable next node changes local selected track. Purchase remains delegated through `onPurchase` and retains current close-then-purchase behavior.

### Nodes

Every Technology node uses `MiningHex`.

Selectable/actionable/blocked nodes are at least `48×48`. To keep the layout and semantics simple, render every level node inside a `48×48` box.

Semantic state comes directly from `TechnologyTrackView.stateForLevel(level)`, for example:

```text
Extraction level 3 actionable
Logistics level 4 blocked
```

No second hex painter or private node-state rule exists in the widget.

### Portrait — `402×874`

Match the mock:

- live mining context visible above the panel;
- Technology panel begins around `top: 190` on the canonical viewport;
- protruding Technology hex left;
- close hex right;
- heading `Technology`;
- `MAX LV ${MiningContentRegistry.maxTechnologyLevel}`;
- three vertical columns: Extraction / Logistics / Surveying;
- each column renders max level down to 1;
- colored connectors and common root;
- one selected detail/action card below the tree.

The panel body is scrollable so `360×640` and text scale `1.3` cannot strand the action.

### Landscape — `874×402`

Use a dedicated right-side layout, not a rotated portrait tree.

Expose one presentation constant on the widget:

```dart
static const double landscapePanelWidth = 528;
```

Use the same constant for layout and tests.

Render:

- 528 px right-side full-height panel;
- protruding Technology hex at the left edge;
- heading + helper copy + close hex;
- three horizontal tracks;
- five `48×48` `MiningHex` levels per row;
- selected detail/action area.

Site Deck on the left is out of scope and must not be modified for parity.

## Settings

Keep:

```dart
MiningSettingsSheet(audioManager: ...)
```

and keep `AudioManager` as the only preference owner.

### Portrait — `402×874`

Match:

- panel rises from around `top: 392`;
- Settings/tune hex and shared chrome;
- Audio card;
- Music ON/OFF pill with inline `MiningHex` thumb;
- Volume percentage;
- real Material `Slider(divisions: 20)`;
- local `_HexSliderThumbShape extends SliderComponentShape`;
- `0 / 20 steps / 100` metadata;
- Accessibility card;
- Reduced motion explanation + `SYSTEM` badge.

The Music thumb does not need an animation. Use static `Align` rather than querying `MediaQuery.disableAnimations` inside Settings or adding another reduced-motion parameter.

Do not add a generic toggle component.

### Landscape

The mock has no Settings landscape reference. Provide a bounded, scrollable, safe-area-aware layout only.

Requirements at `874×402`, including text scale `1.3`:

- no overflow;
- Music reachable;
- Volume reachable;
- SYSTEM/Accessibility content reachable;
- interactive targets at least `48×48`.

## Offline Return

### Ownership and constructor

Keep `OfflineProductionSummary` unchanged.

Use the existing summary/content plus the minimum presentation inputs already owned by `MiningShell`:

```dart
OfflineReturnSheet(
  summary: summary,
  content: content,
  cash: cash,
  logisticsLevel: logisticsLevel,
  reducedMotion: reducedMotion,
)
```

Do not create an `OfflineReturnView` solely to wrap these existing values.

`MiningShell` passes its existing `_reducedMotion` value. `OfflineReturnSheet` must not query `MediaQuery.disableAnimations` independently.

### Cap copy

When `summary.wasOfflineCapped` is true, display the authored cap derived from:

```dart
content.offlineCapFor(logisticsLevel)
```

Do not print `summary.elapsedUsed` as though it were the authored cap. `elapsedUsed` remains the elapsed/result value; `offlineCapFor(logisticsLevel)` remains the content rule lookup.

Example:

```text
Capped at 12h — Logistics LV 2
```

### Motion

The only new motion is the `FLEET RETURNED` status-dot pulse.

`OfflineReturnSheet` may own one local `AnimationController`, but its enabled/static behavior is driven solely by the `reducedMotion` constructor parameter. No accessibility query is performed in the sheet.

When reduced motion is true, render a static dot. When false, pulse the dot. No other new animation is required.

### Portrait — `402×874`

Match:

- full-screen dark result;
- `MiningVisuals.offlineHero` + gradient;
- `MiningCashChip` top-left;
- FLEET RETURNED status;
- large elapsed duration;
- cap line only when capped;
- planet/resource production groups;
- existing catalog silhouettes;
- full-site warnings;
- next-action copy;
- one large `CONTINUE MINING` action.

Real multi-planet results stay scrollable.

### Landscape — `874×402`

Expose:

```dart
static const double landscapePanelWidth = 470;
```

Use it for layout and tests.

Match:

- hero/result context left;
- 470 px right-side production panel;
- Continue inside the right-side scroll/flow;
- no overlap at text scale `1.3`.

### Dismissal contract

Offline Return is non-dismissible except through Continue:

- `showGeneralDialog(barrierDismissible: false)`;
- `PopScope(canPop: false)`;
- Continue calls `Navigator.pop()`.

This does not change initialization/resume accrual timing.

## Error/degraded-asset behavior

Keep current fallback strategy.

Critical contract: hero/art failure must never hide or disable Continue.

Tests must force the hero asset error path through a failing `DefaultAssetBundle`/test asset bundle; do not add a production-only asset injection parameter merely for testing.

## Accessibility

Across all three surfaces:

- interactive targets at least `48×48`;
- icon-only controls have semantic labels;
- Technology node state is not communicated by color alone;
- Settings retains Material Slider semantics/keyboard behavior;
- Offline Return traversal exposes status, elapsed value, resource totals, warnings, and Continue;
- safe areas respected;
- text scale `1.3` keeps critical controls reachable;
- reduced-motion ownership remains in `MiningShell`.

## Verification strategy

### Structural and behavior tests are the primary automated gate

Technology:

- pure `TechnologyTrackView.stateForLevel` unit tests;
- starter level-0 fixture;
- owned/actionable/blocked/future/max fixture;
- selected-track behavior;
- only selected detail action exists;
- blocked action does not purchase;
- `360×640` + `1.3` reachability;
- `874×402` 528 px panel and 48×48 selectable nodes.

Settings:

- AudioManager state/mutation;
- real `Slider(divisions: 20)`;
- `360×640` + `1.3` reachability;
- `874×402` + `1.3` reachability.

Offline Return:

- real elapsed/resource/full-site data;
- cap copy from `content.offlineCapFor(logisticsLevel)`;
- reduced-motion true/false status behavior;
- `360×640` + `1.3`;
- `430×932` + `1.3`;
- `874×402` + `1.3`;
- Android/system back route attempt leaves the dialog visible;
- failing hero asset still leaves Continue reachable;
- Continue dismisses.

### Golden strategy

Do **not** add five full-screen HPA-438 goldens.

The existing Linux CI executes non-skipped golden tests through `flutter test --coverage`, so a new non-skipped Linux golden mismatch is a real CI failure. The problem is not that the harness is wholly dead; it is that two pre-existing baselines are permanently `skip:true` and full-screen Technology baselines would couple HPA-438 to out-of-scope Site Deck pixels.

Keep exactly two new automated goldens, both scoped to Technology panel finders:

- Technology portrait panel;
- Technology landscape 528 px panel.

They use the repository's existing macOS/web skip predicate and therefore run in Ubuntu CI. They are regression guards, not the parity acceptance gate.

As part of the same Linux visual-test pass, either:

1. unskip and regenerate the existing stale Site Deck/Stellar Map baselines successfully without production changes; or
2. delete the stale test/baseline pair if it no longer provides maintainable value.

Do not change Site Deck/Stellar Map production code to save an old golden.

### Actual parity gate

The actual parity gate is committed source-vs-app evidence under:

```text
docs/superpowers/evidence/hpa-438/
```

Provide five rows:

- Technology portrait — panel crop;
- Technology landscape — rightmost 528 px panel crop;
- Settings portrait — panel crop;
- Offline Return portrait — full surface;
- Offline Return landscape — full surface.

Each row has the mock reference and implementation capture side by side. Review geometry, hierarchy, typography, color/state treatment, and action placement.

No scoring-boundary prose around an out-of-scope Site Deck backdrop is needed because Technology evidence is cropped to the panel itself.

## Risks

### Risk 1 — Non-dismissible Offline Return can hard-lock the resume flow

Changing the resume result from a bottom sheet to a non-dismissible full-screen dialog means Continue is the only exit. A clipped action or asset/layout error would trap the player.

Mitigations:

- Continue remains inside scrollable flow;
- structural tests cover portrait + landscape at text scale `1.3`;
- system-back attempt is tested and intentionally does not dismiss;
- hero asset failure is tested and Continue remains reachable;
- shell resume regression verifies dismissal through the real action.

### Risk 2 — Technology density on small phones

Five levels × three tracks plus detail/action is the densest layout in this ticket.

Mitigations:

- 48×48 node contract;
- scrollable panel body;
- explicit `360×640` / text scale `1.3` test;
- pure projection tests keep layout tuning separate from state rules.

### Risk 3 — Visual baselines coupled to unrelated surfaces

A full-screen Technology golden would fail when Site Deck changes even though Site Deck is out of scope.

Mitigations:

- panel-only Technology goldens;
- five source-vs-app evidence rows scoped to the actual surfaces;
- Site Deck production file remains under the no-change guard.

## File-level change map

Expected production changes:

```text
lib/mining/mining_progression_views.dart
lib/mining/presentation/mining_modal_chrome.dart
lib/mining/presentation/technology_sheet.dart
lib/mining/presentation/mining_settings_sheet.dart
lib/mining/presentation/offline_return_sheet.dart
lib/mining/presentation/mining_shell.dart
pubspec.yaml
assets/fonts/IBMPlexMono-Regular.ttf
assets/fonts/IBMPlexMono-SemiBold.ttf
assets/fonts/IBMPlexMono-OFL.txt
```

Expected tests/evidence:

```text
test/mining/mining_progression_views_test.dart
test/mining/presentation/technology_sheet_test.dart
test/mining/presentation/mining_settings_sheet_test.dart
test/mining/presentation/offline_return_sheet_test.dart
test/mining/presentation/mining_shell_test.dart
test/mining/presentation/visual_parity_golden_test.dart
test/mining/presentation/goldens/... # two Technology panel goldens + existing baseline maintenance
docs/superpowers/evidence/hpa-438/...
```

Must not change production files:

```text
lib/mining/mining_controller.dart
lib/mining/mining_simulation.dart
lib/mining/mining_state.dart
lib/mining/mining_save_repository.dart
lib/mining/mining_content.dart
lib/mining/fleet_dock_view.dart
lib/mining/site_deck_view.dart
lib/mining/mine_site_view.dart
lib/mining/presentation/site_deck_screen.dart
lib/mining/presentation/mine_site_screen.dart
lib/mining/presentation/stellar_map_screen.dart
```

`mining_progression_views.dart` is intentionally **not** on that list; additive/simplifying presentation projection changes are part of HPA-438.

## Acceptance criteria

- Technology portrait matches the mock's three-column tree and uses projection-provided node states.
- Technology landscape uses the measured 528 px right panel.
- All selectable Technology nodes are at least 48×48.
- Settings matches the supplied Audio/Accessibility composition and preserves AudioManager behavior.
- Offline Return portrait/landscape match the supplied result compositions using real summary/content data.
- Offline cap copy comes from the authored cap table for the displayed Logistics level.
- Offline Return receives reduced-motion state from `MiningShell` and never queries it independently.
- Offline Return cannot be dismissed by barrier/back and always keeps Continue reachable, including under hero asset failure.
- No domain/save/economy/progression mutation behavior changes.
- No Site Deck/Mine Site/Stellar Map production changes.
- Structural tests cover the dense/resume failure modes.
- Exactly two scoped Technology panel goldens are added; pre-existing stale baselines are rehabilitated or removed, not multiplied.
- Five committed source-vs-app evidence rows form the visual parity acceptance gate.
