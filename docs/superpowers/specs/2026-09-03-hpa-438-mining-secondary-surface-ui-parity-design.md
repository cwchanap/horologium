# HPA-438 Mining Secondary-Surface UI Parity Design

## Status

Approved design for HPA-438, **Revamp Technology, Settings, and Offline Return for mining UI parity**.

This is a presentation-focused follow-up to completed HPA-285. It keeps the current merge-mining runtime, progression, persistence, audio, lifecycle, and projection seams intact while bringing the three retained secondary surfaces to the supplied standalone mock's visual language.

Planning, implementation, responsive variants, visual evidence, tests, and cleanup stay on **one branch and one pull request**.

The user-supplied `Horologium Merge Mining (standalone).html` is the visual source of truth for hierarchy, composition, panel geometry, typography intent, color, and responsive layout. Repository state and rules remain authoritative where the mock uses sample values such as cash, cargo, elapsed time, technology state, or site production.

## Goal

Revamp exactly these existing surfaces:

1. `TechnologySheet`
2. `MiningSettingsSheet`
3. `OfflineReturnSheet`

The player-visible target is the mock's section **“3A · Tech · Settings · Offline return”**:

- Technology portrait at `402×874`;
- Settings portrait at `402×874`;
- Offline Return portrait at `402×874`;
- Technology landscape at `874×402`;
- Offline Return landscape at `874×402`.

The mock explicitly describes Technology and Settings as sheets that rise from their navigation hexes with no conventional title bar. Cash and cargo remain visible behind those sheets so upgrade costs retain context. Offline Return is different: it is an immersive return result rather than a normal lower sheet.

## Non-goals

Do not change:

- `MiningController`, `MiningSimulation`, or mining economics;
- save schema, migration, or repository rules;
- technology costs, levels, gates, effects, or tracks;
- audio preference keys or `AudioManager` ownership;
- reduced-motion ownership (`MediaQuery.disableAnimations` remains authoritative);
- offline accrual semantics or `OfflineProductionSummary` shape;
- Site Deck, Mine Site, or Stellar Map layouts;
- primary navigation architecture;
- mining lifecycle, haptics, or foreground refresh behavior.

Do not add:

- Provider, Riverpod, Bloc, a service locator, or a command bus;
- a routing package or generic modal manager;
- a design-system package;
- new save fields or persisted UI selection;
- reward claiming, multipliers, ads, streaks, notifications, or retention mechanics;
- new technology tracks or an alternate progression model;
- an asset-generation pipeline.

## Current reusable baseline

The existing boundaries are already the right size:

```text
MiningShell
  -> TechnologySheet
       <- TechnologySheetView
       -> onPurchase(TechnologyTrack)

  -> MiningSettingsSheet
       <-> AudioManager

  -> OfflineReturnSheet
       <- OfflineProductionSummary
       <- MiningContentRegistry
```

Reuse these presentation primitives rather than building replacements:

- `MiningTheme` for the current cyan/yellow/orange/panel palette;
- `MiningVisuals` for technology, cash, cargo, planet/resource, and offline hero assets;
- `MiningHex` for the six-sided visual language;
- `MiningCashChip` and `MiningCargoGauge` for the HUD fragments visible above sheets;
- `MiningNavigationBar` / navigation icon mappings;
- the existing mining widget-test files;
- `visual_parity_golden_test.dart` as the visual-test harness.

`TechnologySheetView` already supplies the state required by the mock: current level/effect, next effect, next cost, gate site, gate satisfaction, affordability, max-level state, and disabled reason. The UI should project node visuals from those fields rather than recalculating eligibility.

`OfflineProductionSummary` already supplies elapsed time, per-planet/resource production, full sites, and cap status. The overlay should render that data directly and obtain any additional visible presentation labels, such as planet site count or current Logistics level, from already-available live state/catalog data passed by `MiningShell`.

## Visual language

The mock and current `MiningTheme` already agree on the core palette:

```text
panel       #0E1828
accent      #53D4E8
highlight   #18FFFF
warning     #FFD54A
gate        #FFAB40
background  #060A10 / #0A1218
```

Do not create a second color token system for HPA-438.

### Typography

Keep the existing declared Orbitron family for display labels, values, and primary controls. The mock uses IBM Plex Mono for small status, explanatory, and metadata copy. Add IBM Plex Mono as one locally declared secondary font family only if needed for parity, with its license, and scope its use to the mining surfaces that require it. Do not replace the application-wide theme or introduce runtime font loading.

### Shared modal chrome

Technology and Settings share enough geometry to justify one small presentation-only helper, tentatively `mining_modal_chrome.dart`.

It owns only:

- `#0E1828` / translucent panel fill;
- cyan top edge and glow/shadow;
- rounded upper corners;
- 42×4 drag handle;
- safe-area-aware padding;
- an optional protruding `MiningHex` leading/trailing affordance.

It does **not** own navigation, business actions, state, scroll policy, technology nodes, settings cards, or Offline Return layout. If the helper becomes more complicated than the duplicated chrome it replaces, keep the chrome local instead.

## Technology

### Ownership and behavior

Keep `TechnologySheet` as the render surface for `TechnologySheetView`. Keep purchase forwarding as:

```dart
ValueChanged<TechnologyTrack> onPurchase
```

Do not move technology eligibility into the widget. A successful price action may retain the current close-then-purchase behavior; HPA-438 does not change progression flow.

Add only transient UI-local selection for which track's next level is being inspected. Default to the first actionable next level; if none is actionable, default to the first non-max track, otherwise the first track. Selection is not saved.

### Node-state projection

For each `TechnologyTrackView`, render levels 1–5 from existing projected state:

- levels `<= track.level`: **owned** — solid cyan node;
- `track.level + 1` when gate satisfied and affordable: **actionable** — yellow outlined/glowing node;
- `track.level + 1` when blocked by gate or affordability: **blocked** — orange/locked treatment plus existing gate/disabled copy;
- later levels: **future** — subdued neutral node;
- maxed track: all five nodes owned and no purchase action.

This mapping is presentation only. It does not create a parallel technology model.

### Portrait composition — `402×874`

The mock's canonical portrait geometry is:

- existing/live mining backdrop remains visible;
- cash shard at the upper-left and cargo ring at the upper-right remain visible;
- Technology panel begins around `top: 190` and fills to the bottom;
- leading technology hex protrudes above the panel on the left;
- close hex protrudes above the panel on the right;
- header shows `Technology` and `MAX LV 5`;
- a three-column tree fills the panel body:
  - Extraction;
  - Logistics;
  - Surveying;
- each column displays levels 5 → 1 vertically with connectors;
- the three tracks join to a common root near the bottom;
- the selected track's detail/purchase card sits below the tree.

Do not hard-code the mock's sample technology state. A state such as Extraction 2 → 3 actionable or Logistics 4 blocked must emerge from `TechnologySheetView`.

The detail card renders only existing projection data: current effect, next effect, cost, gate, and disabled reason. Do not invent a new description catalog.

### Landscape composition — `874×402`

Do not stretch or rotate the portrait tree.

The mock uses a dedicated right-side panel roughly `470px` wide over the live mining background. It contains:

- protruding technology hex at the left edge;
- `Technology` header with concise gate/cash helper copy;
- close hex;
- three horizontal technology tracks;
- levels 1 → 5 across each row;
- the selected next node highlighted with the same state mapping;
- one compact selected-track effect/cost row at the bottom.

Use `LayoutBuilder` / available width rather than device-type branching. Portrait and landscape render from the same `TechnologySheetView` and local selection.

## Settings

### Ownership and behavior

Keep `MiningSettingsSheet` stateful only because it reflects/mutates the injected `AudioManager`.

Preserve:

- `musicEnabled`;
- `musicVolume`;
- `setMusicEnabled`;
- `setMusicVolume`;
- existing preference keys;
- existing widget keys `mining-music-switch` and `mining-volume-slider`;
- reduced motion as a system-owned behavior, not a new persisted toggle.

### Portrait composition — `402×874`

The mock keeps the mining backdrop and HUD context visible, then raises Settings from around `top: 392`.

The panel contains:

1. Settings header with a protruding tune hex.
2. Audio card:
   - `AUDIO` eyebrow;
   - Music title + `Cavern ambience` secondary copy;
   - ON/OFF pill with hex thumb;
   - divider;
   - Volume label + percent value;
   - thick 20-step slider with cyan fill and hex thumb;
   - `0`, `20 steps`, `100` metadata.
3. Accessibility card:
   - `ACCESSIBILITY` eyebrow;
   - Reduced motion label;
   - concise explanation;
   - `SYSTEM` badge.

The current product copy `Reduced motion follows system setting` remains semantically authoritative. The visual subtitle can match the mock's intent only if it does not imply a user-controlled preference.

The custom toggle and slider may wrap standard Material controls or use small focused widgets, but semantics/keyboard behavior must remain correct and the existing functional tests must still be able to locate their keys.

### Landscape

The source mock does not provide a dedicated Settings landscape composition. Do not invent a second visual design.

Render the same Settings cards in a bounded, scrollable, safe-area-aware panel that remains usable at `874×402`. The parity requirement for landscape Settings is only:

- no overflow;
- all controls reachable;
- no system-inset collision;
- 48×48 minimum interactive targets.

## Offline Return

### Ownership and presentation boundary

Keep `_showOfflineReturn(OfflineProductionSummary)` on `MiningShell`, but stop presenting Offline Return as a normal bottom sheet.

Use one full-screen modal route via Flutter's built-in dialog/route APIs, preferably `showGeneralDialog<void>` with a non-dismissible barrier. `OfflineReturnSheet` can keep its current class/file name to avoid churn even though its visual shape becomes full-screen.

No routing package or generic overlay abstraction is justified.

`MiningShell` may pass the current `MiningSave`/specific presentation scalars required by the mock, such as:

- cash;
- current Logistics level.

Prefer the smallest parameter list that keeps rule calculations out of the widget. Do not add those fields to `OfflineProductionSummary` merely for rendering.

### Portrait composition — `402×874`

The mock's canonical structure is:

- full-screen dark background;
- `MiningVisuals.offlineHero` fills the upper ~400px with a dark vertical gradient;
- cash shard remains visible at top-left;
- return message begins around `top: 250`:
  - `FLEET RETURNED` status chip;
  - large `Mining ran` + elapsed duration;
  - orange cap/Logistics line when `wasOfflineCapped`;
- production card around the middle/lower area:
  - planet art/name;
  - real site count;
  - one row per positive produced resource;
  - `+amount` in cyan;
  - one orange storage-full warning per full site;
- one concise next-action row;
- full-width `CONTINUE MINING` action plus play hex at the bottom.

All numbers come from live state/summary. Mock values such as `1,840`, `16h 00m`, `+742.5`, and Logistics LV 3 are examples only.

If more than one planet produced offline, render one production card/section per `productionByPlanet` entry using the existing catalog ordering. Keep the layout scrollable when real data exceeds the one-card example.

### Landscape composition — `874×402`

The source mock has a dedicated split layout:

- hero image fills the full background with a horizontal dark gradient;
- cash shard stays on the left;
- return chip, elapsed time, and optional cap line sit bottom-left;
- a right-side `#0E1828` summary panel occupies roughly `470px`;
- production rows and storage warnings live in that panel;
- Continue remains in the right-side flow and reachable without overlap.

Use width/orientation breakpoints only for composition. Data and behavior remain identical to portrait.

### Motion

The mock pulses the `FLEET RETURNED` status dot. Respect `MediaQuery.disableAnimations`: when reduced motion is enabled, render the dot statically. No other new animation is needed for parity.

## Data flow

No new domain or persistence flow is introduced.

```text
Technology
MiningShell state
  -> TechnologySheetView.from(...)
  -> TechnologySheet
  -> local selected track
  -> onPurchase(track)
  -> existing MiningController.purchaseTechnology

Settings
MiningShell AudioManager
  -> MiningSettingsSheet
  -> existing AudioManager setters

Offline Return
MiningController resume/initialize
  -> OfflineProductionSummary
  -> MiningShell._showOfflineReturn(...)
  -> OfflineReturnSheet + catalog/live presentation values
  -> dismiss
```

Widgets must not recompute affordability, gates, production, cargo, offline caps, or technology effects.

## Error and degraded-asset behavior

Keep the existing strategy:

- missing optional image assets fall back to clear Material icons/colored surfaces;
- a missing hero image must not block Continue;
- disabled technology actions render the existing `disabledReason` and do not fire callbacks;
- Settings continues to update local presentation immediately after `AudioManager` mutations;
- Offline Return always exposes Continue even when production is empty or an asset fails to decode.

Do not add retry frameworks or global error state for presentation assets.

## Accessibility

Across all three surfaces:

- interactive targets are at least 48×48 logical pixels;
- icon-only hex controls have semantic labels;
- technology state is not color-only: owned levels show level text, blocked nodes show lock state, actionable nodes remain buttons;
- Settings toggle/slider retain standard control semantics;
- Offline Return status, elapsed time, resource totals, full-storage warning, and Continue read meaningfully in traversal order;
- text scale `1.3` keeps critical actions reachable;
- safe areas and rounded-device insets are respected;
- reduced motion removes the return pulse and other nonessential transforms.

## Testing strategy

Extend existing tests instead of creating another visual-test framework.

### Focused widget tests

`test/mining/presentation/technology_sheet_test.dart`

- renders owned/actionable/blocked/future/max node states from `TechnologyTrackView`;
- tapping a selectable next node updates only local detail selection;
- purchase callback fires only when `canPurchase`;
- disabled/max state does not fire;
- portrait/landscape compositions expose expected semantic controls;
- phone text scale keeps the purchase action reachable.

`test/mining/presentation/mining_settings_sheet_test.dart`

- injected `AudioManager` state renders correctly;
- Music control toggles the existing manager setting;
- volume retains 20-step behavior and manager mutation;
- disabled volume state follows Music-off behavior if current product behavior requires it;
- Accessibility remains system-owned;
- portrait and landscape avoid overflow at the target sizes.

`test/mining/presentation/offline_return_sheet_test.dart`

- formats elapsed duration;
- renders per-planet/resource positive production;
- renders full-site warnings;
- renders cap/Logistics copy only when capped;
- Continue dismisses;
- empty/minimal summary still exposes Continue;
- portrait/landscape and text-scale cases keep the action reachable.

`test/mining/presentation/mining_shell_test.dart`

- Technology/Settings still open through existing shell handles/navigation;
- Offline Return uses the full-screen presentation boundary after initialize/resume;
- controller/audio identities remain unchanged across opening/dismissing these surfaces.

### Visual parity tests

Extend `test/mining/presentation/visual_parity_golden_test.dart` with deterministic fixtures for exactly the supplied canonical compositions:

```text
Technology      402×874
Technology      874×402
Settings        402×874
Offline Return  402×874
Offline Return  874×402
```

Keep secondary structural checks at:

- `360×640` portrait;
- `430×932` portrait;
- `874×402` Settings landscape;
- text scale `1.3`;
- reduced motion;
- muted audio where relevant.

Golden files are an implementation aid, not the only parity gate. Final PR review must include side-by-side or overlay evidence comparing real Flutter output against the five mock states.

## File-level change map

Expected production files:

```text
lib/mining/presentation/
  mining_modal_chrome.dart       # optional tiny shared Technology/Settings chrome
  technology_sheet.dart          # responsive tech-tree compositions
  mining_settings_sheet.dart     # parity cards/controls
  offline_return_sheet.dart      # full-screen responsive result
  mining_shell.dart              # full-screen Offline Return presentation + minimal args
  mining_theme.dart              # only if an existing token is genuinely missing
```

Expected supporting files only if required:

```text
pubspec.yaml                     # IBM Plex Mono registration if adopted
assets/fonts/...                 # licensed font + license only
```

Expected test files:

```text
test/mining/presentation/technology_sheet_test.dart
test/mining/presentation/mining_settings_sheet_test.dart
test/mining/presentation/offline_return_sheet_test.dart
test/mining/presentation/mining_shell_test.dart
test/mining/presentation/visual_parity_golden_test.dart
test/mining/presentation/goldens/...
```

No domain/state/repository/simulation file should change for HPA-438.

## Delivery sequencing

All work stays on the HPA-438 branch/PR. Within that PR, implementation should proceed in this order:

1. shared parity chrome / typography support only as proven necessary;
2. Technology projection-to-tree rendering and responsive layouts;
3. Settings parity controls/cards;
4. Offline Return full-screen route and portrait/landscape layouts;
5. focused test updates;
6. golden/parity evidence and cleanup.

Do not split those steps into separate PRs.

## Acceptance criteria

- Technology portrait matches the supplied three-column 5→1 tree with live HUD context and existing progression data.
- Technology landscape matches the supplied right-side horizontal-track panel at `874×402`.
- Settings portrait matches the supplied Audio/Accessibility cards while preserving `AudioManager` behavior.
- Settings landscape remains reachable and overflow-free without inventing an unreferenced alternate design.
- Offline Return portrait matches the supplied immersive hero/result composition using real summary/catalog data.
- Offline Return landscape matches the supplied split hero/summary composition.
- No mining simulation, economy, save, progression, technology-rule, lifecycle, haptic, or audio contract changes.
- Existing functional tests remain green and new parity evidence covers all five supplied reference states.
- Critical actions remain usable at `360×640`, `430×932`, `874×402`, and text scale `1.3`.

## Explicit YAGNI decisions

- One tiny chrome helper at most, not a modal framework.
- One local technology selection, not persisted UI state.
- One built-in full-screen modal route for Offline Return, not navigation infrastructure.
- One optional secondary font family for parity, not a typography subsystem.
- Existing projection/domain models remain authoritative; no parallel view-state layer.
- Golden/evidence updates reuse the current test harness; no screenshot service or visual-regression platform.
