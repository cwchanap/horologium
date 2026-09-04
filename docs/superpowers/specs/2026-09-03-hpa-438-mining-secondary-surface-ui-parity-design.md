# HPA-438 Mining Secondary-Surface UI Parity Design

## Status

Approved design for HPA-438, **Revamp Technology, Settings, and Offline Return for mining UI parity**.

This is a presentation-only follow-up to completed HPA-285. It keeps the current merge-mining runtime, progression, persistence, audio, lifecycle, and projection seams intact while bringing the retained Technology, Settings, and Offline Return surfaces to the supplied standalone mock's visual language.

Planning, implementation, responsive variants, visual evidence, tests, and cleanup stay on **one branch and one pull request**.

The user-supplied `Horologium Merge Mining (standalone).html` is the visual source of truth for hierarchy, geometry, typography intent, color, and responsive composition. Repository state and rules remain authoritative where the mock uses sample values.

## Goal

Revamp exactly these existing surfaces:

1. `TechnologySheet`
2. `MiningSettingsSheet`
3. `OfflineReturnSheet`

Canonical references:

- Technology portrait: `402×874`
- Technology landscape: `874×402`
- Settings portrait: `402×874`
- Offline Return portrait: `402×874`
- Offline Return landscape: `874×402`

The mock keeps live mining context visible behind Technology and Settings. Offline Return is different: it is an immersive full-screen result.

## Non-goals

Do not change:

- `MiningController`, `MiningSimulation`, mining economics, or progression;
- save schema, migration, or repository rules;
- technology costs, levels, gates, effects, or tracks;
- `AudioManager` ownership or preference keys;
- `OfflineProductionSummary` shape or offline accrual semantics;
- Site Deck, Mine Site, or Stellar Map layouts;
- lifecycle, foreground refresh, haptics, or reduced-motion ownership.

Do not add:

- Provider, Riverpod, Bloc, service locator, or command bus;
- routing package or generic modal manager;
- design-system package;
- persisted UI selection;
- reward claims, multipliers, ads, streaks, notifications, or retention mechanics;
- asset-generation or screenshot infrastructure.

## Existing seams to preserve

```text
MiningShell
  -> TechnologySheet
       <- TechnologySheetView / TechnologyTrackView
       -> onPurchase(TechnologyTrack)

  -> MiningSettingsSheet
       <-> AudioManager

  -> OfflineReturnSheet
       <- OfflineProductionSummary
       <- MiningContentRegistry
       <- cash + logisticsLevel presentation scalars
```

Reuse in place:

- `MiningTheme` for panel/accent/highlight/warning/gate colors;
- `MiningHex` for technology nodes, icon affordances, and hex visual language;
- `MiningVisuals` for technology/offline/resource art;
- `MiningCashChip` and `MiningCargoGauge` where the mock shows HUD context;
- the existing mining widget tests;
- `visual_parity_golden_test.dart` as the only golden harness.

`TechnologySheetView` remains the rule projection. Widgets do not recalculate affordability, gates, or effects. `MiningContentRegistry.maxTechnologyLevel` is the source for the maximum visible level; do not introduce a second literal progression contract.

`OfflineProductionSummary` remains the offline result projection. Offline Return may receive only live presentation scalars already available in `MiningShell`, specifically `cash` and `logisticsLevel`.

## Visual language

Use existing `MiningTheme` tokens directly. Do not fork the palette with raw equivalents for panel or cyan accent.

The mock's visual values correspond to the existing mining palette:

```text
panel       #0E1828
accent      #53D4E8
highlight   #18FFFF
warning     #FFD54A
gate        #FFAB40
```

### Typography

Keep Orbitron as the app/display family. Bundle IBM Plex Mono Regular (`400`) and SemiBold (`600`) with the OFL and scope it to small status, metadata, and explanatory copy on these three surfaces.

Golden setup must load **both** IBM Plex Mono files into the same `FontLoader('IBMPlexMono')`; otherwise `w600` copy is rendered as faux-bold Regular and parity evidence is misleading.

### Shared modal chrome

Technology and Settings may share one narrow `MiningModalChrome` widget. It owns only:

- `MiningTheme.panel` fill;
- `MiningTheme.accent.withAlpha(...)` top edge / handle;
- rounded upper corners;
- 42×4 drag handle;
- safe-area-aware padding;
- optional protruding `MiningHex` leading/trailing affordances.

It does **not** own routing, navigation, state, scroll policy, titles, actions, technology nodes, or settings cards. Offline Return does not use this chrome and does not get a drag handle.

## Technology

### Ownership and selection

Keep the public boundary:

```dart
TechnologySheet({
  required TechnologySheetView view,
  required ValueChanged<TechnologyTrack> onPurchase,
})
```

The widget becomes stateful only for transient selected-track state. Default selection is:

1. first `track.canPurchase`;
2. otherwise first non-max track;
3. otherwise first track.

Selection is never persisted.

### Node-state projection

For each level `1..MiningContentRegistry.maxTechnologyLevel`:

- `level <= track.level`: **owned**;
- `level == track.level + 1 && track.canPurchase`: **actionable**;
- `level == track.level + 1 && !track.isMaxLevel && !track.canPurchase`: **blocked**;
- later levels: **future**.

Render technology nodes with `MiningHex`. Actionable/blocked next nodes can select a track. Owned/future nodes are informational only.

Every tappable node is at least `48×48`. Informational owned/future hexes may be visually smaller only when they have no tap/semantic button action.

### Portrait — `402×874`

Match the mock:

- live mining backdrop and HUD remain visible above the panel;
- panel begins at about `top: 190` on the canonical frame and shrinks safely on short phones;
- Technology hex left, close hex right, drag handle centered;
- `Technology` heading plus `MAX LV ${MiningContentRegistry.maxTechnologyLevel}`;
- three vertical columns: Extraction, Logistics, Surveying;
- levels descend `max → 1`;
- connectors converge to a common root;
- one selected-track detail/action card at the bottom.

Only the selected track has a purchase control. The existing key `mining-technology-buy-${track.name}` stays on that visible action. Successful purchase keeps the current close-then-`onPurchase(track)` behavior.

### Landscape — `874×402`

Do not rotate or stretch the portrait tree.

The mock was measured directly: the Technology panel is **528 px wide** at `874×402`. This is the canonical width. Offline Return's landscape panel is a separate **470 px** composition.

Technology landscape contains:

- a right-side full-height `528` px panel;
- protruding Technology hex on its left edge;
- heading/helper copy and close hex;
- three horizontal level tracks;
- levels `1 → max` across each row;
- the same node-state mapping;
- one compact selected-track effect/cost/action area.

All selectable next nodes remain at least `48×48`.

## Settings

Keep `MiningSettingsSheet(audioManager:)` and `AudioManager` as the only preference owner.

Preserve these stable keys:

- `mining-settings-sheet`
- `mining-music-switch`
- `mining-volume-slider`

### Portrait — `402×874`

Match the mock's panel starting around `top: 392`:

1. Settings header with protruding tune hex.
2. Audio card:
   - `AUDIO` eyebrow;
   - Music + `Cavern ambience` copy;
   - inline ON/OFF pill with hex thumb;
   - divider;
   - Volume + percentage;
   - real Material `Slider` with `divisions: 20`;
   - `0 / 20 steps / 100` metadata.
3. Accessibility card:
   - `ACCESSIBILITY` eyebrow;
   - Reduced motion;
   - `SYSTEM` badge;
   - copy that makes system ownership explicit.

Do not create a generic toggle widget. Keep the Music pill local to this file.

Use the real Material `Slider` for drag, keyboard, and semantics. Implement the mock's hex thumb as a small local `SliderComponentShape`; do not zero the stock thumb and place a second `Positioned` hex using manual track math.

### Landscape

There is no canonical Settings landscape mock. Keep the same cards in a bounded, scrollable, safe-area-aware panel at `874×402`. Requirements are reachability, no overflow, correct semantics, and minimum target sizes; do not invent a new visual composition.

## Offline Return

Keep `_showOfflineReturn(OfflineProductionSummary)` owned by `MiningShell`, but present it with Flutter's built-in non-dismissible `showGeneralDialog<void>` instead of a bottom sheet.

`OfflineReturnSheet` keeps the existing class/file name but becomes full-screen. It receives:

```dart
OfflineReturnSheet(
  summary: summary,
  content: content,
  cash: cash,
  logisticsLevel: logisticsLevel,
)
```

Do not extend `OfflineProductionSummary` for rendering-only values and do not call `content.offlineCapFor()` in the widget.

### Portrait — `402×874`

Match:

- `MiningVisuals.offlineHero` upper hero with dark gradient;
- `MiningCashChip` top-left;
- `FLEET RETURNED` status chip;
- large elapsed duration;
- orange cap/Logistics copy only when capped;
- production grouped by real planet/resource data;
- existing catalog silhouettes and full-site warnings;
- one clear `CONTINUE MINING` action.

Multiple producing planets remain scrollable and data-driven.

### Landscape — `874×402`

The mock's right-side summary panel is **470 px wide**. Keep hero/result information on the left and production/Continue in the right flow.

### Motion

The returned-status dot may pulse when animations are enabled. Follow the existing `MainMenu.didChangeDependencies()` pattern locally:

- own one `AnimationController` in Offline Return;
- inspect `MediaQuery.disableAnimations` in `didChangeDependencies`;
- stop and render statically when reduced motion is true;
- repeat only when animations are allowed;
- dispose the controller with the widget.

Do not add a shared animation service.

## Error/degraded-asset behavior

- optional image failures fall back to existing Material/icon/color treatment;
- disabled technology actions show the existing `disabledReason` and never fire purchase;
- Settings mutates only through `AudioManager`;
- Offline Return always exposes Continue, including empty production or failed optional art.

## Accessibility and responsive contract

Across all three surfaces:

- every tappable control is at least `48×48`;
- icon-only controls have semantic labels;
- technology state is not communicated by color alone;
- Material Slider semantics remain intact;
- text scale `1.3` keeps critical controls reachable;
- safe areas and rounded-device insets are respected;
- reduced motion removes nonessential animation.

Explicit structural sizes:

- `360×640` portrait;
- `430×932` portrait;
- `874×402` landscape;
- text scale `1.3` on Technology, Settings, and Offline Return.

## Testing and parity evidence

Extend existing focused tests and golden harness; do not build a new visual stack.

Technology tests must include:

- a **starter fixture** with Extraction level 0 actionable;
- a **parity fixture** covering owned/actionable/blocked/future/max states;
- local selection and disabled reason;
- callback only from the visible selected purchase action;
- `360×640` no-overflow and text-scale `1.3` `ensureVisible` coverage;
- landscape `528` px panel and `48×48` tappable next nodes.

Settings tests must include:

- AudioManager mutation for Music and Volume;
- real 20-division Slider;
- SYSTEM reduced-motion presentation;
- `360×640`, `874×402`, and text-scale `1.3` reachability/no-overflow.

Offline Return tests keep existing duration/resource/full-site/cap/Continue coverage and add portrait/landscape full-screen route assertions.

Five canonical Linux goldens remain:

```text
Technology      402×874
Technology      874×402
Settings        402×874
Offline Return  402×874
Offline Return  874×402
```

For **Technology landscape**, the full-screen golden is a composition smoke test because the left-side Site Deck landscape UI is explicitly out of HPA-438 scope. Parity review scores the **rightmost 528 px Technology panel only**: panel edge, node geometry/state, typography, and detail/action area. Reviewers must not reject this ticket for current Site Deck landscape differences or expand the ticket to fix them.

Golden setup loads Orbitron plus both IBM Plex Mono font files. Final PR evidence pairs the five mock captures with implementation goldens and states the landscape scoring boundary above.

## Expected file changes

Production:

```text
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

Tests/evidence:

```text
test/mining/presentation/technology_sheet_test.dart
test/mining/presentation/mining_settings_sheet_test.dart
test/mining/presentation/offline_return_sheet_test.dart
test/mining/presentation/mining_shell_test.dart
test/mining/presentation/visual_parity_golden_test.dart
test/mining/presentation/goldens/hpa438_*.png
docs/superpowers/evidence/hpa-438/...
```

No mining domain/state/repository/simulation file should change.