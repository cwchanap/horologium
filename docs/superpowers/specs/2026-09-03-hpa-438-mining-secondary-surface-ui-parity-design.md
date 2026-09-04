# HPA-438 Mining Secondary-Surface UI Parity Design

## Status

Approved design for HPA-438, **Revamp Technology, Settings, and Offline Return for mining UI parity**.

This is a presentation-only follow-up to completed HPA-285. It keeps the current merge-mining runtime, progression, persistence, audio, lifecycle, and projection seams intact while bringing Technology, Settings, and Offline Return to the supplied standalone mock's visual language.

Planning, implementation, responsive variants, visual evidence, tests, and cleanup stay on **one branch and one pull request**.

The user-supplied `Horologium Merge Mining (standalone).html` is authoritative for hierarchy, geometry, typography intent, color, and responsive composition. Repository state and rules remain authoritative where the mock uses sample values.

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

The mock keeps live mining context visible behind Technology and Settings. Offline Return is an immersive full-screen result.

## Non-goals

Do not change:

- `MiningController`, `MiningSimulation`, mining economics, or progression;
- save schema, migration, or repository rules;
- technology costs, levels, gates, effects, or tracks;
- `AudioManager` ownership or preference keys;
- `OfflineProductionSummary` shape or offline accrual semantics;
- Site Deck, Mine Site, or Stellar Map layouts;
- lifecycle, foreground refresh, haptics, or reduced-motion ownership.

Do not add Provider/Riverpod/Bloc, a routing package, generic modal manager, design-system package, persisted UI selection, reward/retention mechanics, or a new visual-test stack.

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

Reuse:

- `MiningTheme` for panel/accent/highlight/warning/gate colors;
- `MiningHex` for technology nodes and hex affordances;
- `MiningVisuals` for technology/offline/resource art;
- `MiningCashChip` and `MiningCargoGauge` where the mock shows HUD context;
- existing mining widget tests;
- `visual_parity_golden_test.dart` as the only golden harness.

`TechnologySheetView` remains the rule projection. Widgets do not recalculate affordability, gates, or effects. `MiningContentRegistry.maxTechnologyLevel` is the visible max-level source.

`OfflineProductionSummary` remains the offline result projection. Offline Return may receive only live rendering scalars already available in `MiningShell`: `cash` and `logisticsLevel`.

## Visual language

Use existing `MiningTheme` tokens directly. Do not fork the palette with raw equivalents for panel or cyan accent.

### Typography

Keep Orbitron as the display family. Bundle IBM Plex Mono Regular (`400`) and SemiBold (`600`) plus OFL and scope it to small status/metadata/explanatory copy on these surfaces.

Golden setup loads **both** IBM Plex Mono files into the same family loader so SemiBold metrics are real rather than faux-bold Regular.

### Shared modal chrome

Technology and Settings may share one narrow `MiningModalChrome` widget. It owns only:

- `MiningTheme.panel` fill;
- `MiningTheme.accent.withAlpha(...)` top edge and 42×4 handle;
- rounded upper corners;
- safe-area-aware padding;
- optional protruding `MiningHex` affordances.

It does not own routing, state, titles, actions, business rules, or scroll policy. Offline Return does not use this chrome and does not get a drag handle.

## Technology

Keep the public boundary:

```dart
TechnologySheet({
  required TechnologySheetView view,
  required ValueChanged<TechnologyTrack> onPurchase,
})
```

The widget becomes stateful only for transient selected-track state. Default selection is first purchasable track, else first non-max track, else first track. Selection is not persisted.

For each level `1..MiningContentRegistry.maxTechnologyLevel`:

- `level <= track.level`: owned;
- `level == track.level + 1 && track.canPurchase`: actionable;
- `level == track.level + 1 && !track.isMaxLevel && !track.canPurchase`: blocked;
- later levels: future.

Render nodes with `MiningHex`. Actionable/blocked next nodes can select a track. Owned/future nodes are informational. Every tappable node is at least `48×48`.

### Portrait — `402×874`

Match:

- live mining backdrop/HUD visible above panel;
- panel begins around `top: 190` on canonical frame and shrinks safely on shorter phones;
- Technology hex left, close hex right, drag handle centered;
- `Technology` + `MAX LV ${MiningContentRegistry.maxTechnologyLevel}`;
- three vertical columns: Extraction, Logistics, Surveying;
- levels descend `max → 1`;
- connectors converge to common root;
- one selected detail/action card at bottom.

Only the selected track has a purchase control. Keep key `mining-technology-buy-${track.name}` on that action. Successful purchase keeps current close-then-callback behavior.

### Landscape — `874×402`

Do not rotate/stretch portrait.

The mock was measured directly: the Technology right-side panel is **528 px wide**. This is the canonical Technology landscape width. The previously documented 470px value was incorrect for Technology.

Landscape contains three horizontal level tracks, the same node-state mapping, and one selected detail/action area. All selectable next nodes remain at least `48×48`.

## Settings

Keep `MiningSettingsSheet(audioManager:)` and `AudioManager` as the only preference owner.

Preserve keys:

- `mining-settings-sheet`
- `mining-music-switch`
- `mining-volume-slider`

### Portrait — `402×874`

Match panel around `top: 392` with:

- Audio card;
- inline Music ON/OFF pill with `MiningHex` thumb;
- real Material `Slider(divisions: 20)` with percentage and `0 / 20 steps / 100` labels;
- Accessibility card with Reduced motion + SYSTEM.

Do not create a generic toggle widget.

Use a small local `SliderComponentShape` for the hex thumb so Material Slider retains drag/keyboard/semantics. Do not zero the thumb and position a second hex manually.

### Landscape

No canonical Settings landscape mock exists. Keep the same cards in a bounded scrollable panel at `874×402`; requirements are no overflow, reachability, semantics, and 48px targets.

## Offline Return

Keep `_showOfflineReturn(OfflineProductionSummary)` owned by `MiningShell`, but present it through non-dismissible `showGeneralDialog<void>` instead of a bottom sheet.

`OfflineReturnSheet` remains the class/file name and receives:

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

Match hero + gradient, `MiningCashChip`, FLEET RETURNED status, elapsed/cap text, real planet/resource production, existing silhouettes/full-site warnings, and one Continue action. Multiple producing planets stay scrollable.

### Landscape — `874×402`

The mock's right-side Offline Return summary panel is **470 px wide**. Keep hero/result info left and production/Continue in the right flow.

### Motion

The returned-status dot may pulse when animations are enabled. Follow the existing `MainMenu.didChangeDependencies()` pattern locally: one controller, `MediaQuery.disableAnimations`, static state under reduced motion, repeat only when allowed, dispose with widget.

## Accessibility and responsive contract

Across all surfaces:

- every tappable control >= `48×48`;
- icon-only controls have semantics;
- Technology state is not color-only;
- Material Slider semantics remain intact;
- text scale `1.3` keeps critical controls reachable;
- safe areas are respected;
- reduced motion removes nonessential animation.

Explicit structural coverage:

- `360×640` portrait;
- `430×932` portrait;
- `874×402` landscape;
- text scale `1.3` on Technology, Settings, and Offline Return.

## Testing and parity evidence

Technology tests include:

- starter fixture with Extraction level 0 actionable;
- parity fixture covering owned/actionable/blocked/future/max states;
- local selection and blocked reason;
- callback only from visible selected purchase action;
- `360×640` no-overflow + 1.3 reachability;
- 528px landscape panel and 48px selectable nodes.

Settings tests include AudioManager mutation, real 20-division Slider, SYSTEM presentation, `360×640`, `874×402`, and 1.3 reachability.

Offline tests keep duration/resource/full-site/cap/Continue coverage and add full-screen portrait/landscape route assertions.

Five canonical Linux goldens remain:

```text
Technology      402×874
Technology      874×402
Settings        402×874
Offline Return  402×874
Offline Return  874×402
```

For **Technology landscape**, the full-screen golden is a composition smoke test because the left-side Site Deck landscape UI is explicitly out of HPA-438 scope. Parity review scores the **rightmost 528 px Technology panel only**: panel edge, nodes, typography, and detail/action area. Site Deck landscape differences must not expand this ticket.

Golden setup loads Orbitron plus both IBM Plex Mono weights. Final evidence pairs the five mock captures with the implementation goldens and states the landscape scoring boundary.

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

No mining domain/state/repository/simulation or Site Deck presentation file should change.