# HPA-438 Mining Secondary-Surface UI Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revamp Technology, Settings, and Offline Return to the supplied mock's visual parity while preserving mining domain, save, economy, lifecycle, and ownership contracts.

**Architecture:** Keep `MiningShell` as runtime owner. Move Technology node-state projection into `TechnologyTrackView` so widgets render projected state instead of re-deriving rule-shaped logic. Technology/Settings use transparent built-in dialogs plus one tiny shared chrome helper; Offline Return uses a non-dismissible full-screen dialog fed by the existing summary/content plus cash, Logistics level, and shell-owned reduced motion. Structural/behavior tests are the primary automated gate; only two Technology panel goldens are added, while five committed source-vs-app captures are the actual parity gate.

**Tech Stack:** Flutter/Dart, Material widgets, `showGeneralDialog`, existing mining projections/theme/hex/HUD primitives, `flutter_test`, SharedPreferences test doubles, existing golden harness.

**Spec:** `docs/superpowers/specs/2026-09-03-hpa-438-mining-secondary-surface-ui-parity-design.md`

## Global Constraints

- All work stays on `jack65786656/hpa-438-revamp-technology-settings-and-offline-return-for-mining-ui` and PR #24.
- Canonical mock states: Technology `402×874`, Technology `874×402`, Settings `402×874`, Offline Return `402×874`, Offline Return `874×402`.
- Measured mock geometry: Technology landscape panel **528 px**; Offline Return landscape summary panel **470 px**.
- Do not change `MiningController`, `MiningSimulation`, `MiningSave`, `MiningSaveRepository`, `MiningContentRegistry` authored data, save schema, technology/economy/offline rules, Site Deck, Mine Site, or Stellar Map production code.
- Additive/simplifying changes to `lib/mining/mining_progression_views.dart` are allowed because it is a pure presentation projection.
- Keep `OfflineProductionSummary` unchanged.
- Do not add Provider/Riverpod/Bloc, routing package, modal manager, design-system package, generic toggle, persisted UI state, reward/retention mechanics, screenshot service, or new visual-test stack.
- Use `MiningContentRegistry.maxTechnologyLevel` for visible Technology levels.
- Every tappable control is at least `48×48` logical pixels.
- Critical actions remain reachable at `360×640`, `430×932`, `874×402`, and text scale `1.3`.
- `MiningShell` remains the reduced-motion owner. Offline Return receives `reducedMotion`; Settings uses no new animation that would require another accessibility query.
- Use `MiningTheme` tokens for core colors.
- Keep Orbitron as display type. Add IBM Plex Mono Regular (`400`) and SemiBold (`600`) with OFL only for secondary/status copy.
- Five source-vs-app evidence rows are the parity acceptance gate. Goldens are regression guards only.

---

## File Structure

### Create

- `lib/mining/presentation/mining_modal_chrome.dart`
- `assets/fonts/IBMPlexMono-Regular.ttf`
- `assets/fonts/IBMPlexMono-SemiBold.ttf`
- `assets/fonts/IBMPlexMono-OFL.txt`
- `docs/superpowers/evidence/hpa-438/reference/...`
- `docs/superpowers/evidence/hpa-438/implementation/...`
- `docs/superpowers/evidence/hpa-438/parity.md`

### Modify

- `lib/mining/mining_progression_views.dart`
- `pubspec.yaml`
- `lib/mining/presentation/technology_sheet.dart`
- `lib/mining/presentation/mining_settings_sheet.dart`
- `lib/mining/presentation/offline_return_sheet.dart`
- `lib/mining/presentation/mining_shell.dart`
- `test/mining/mining_progression_views_test.dart`
- `test/mining/presentation/technology_sheet_test.dart`
- `test/mining/presentation/mining_settings_sheet_test.dart`
- `test/mining/presentation/offline_return_sheet_test.dart`
- `test/mining/presentation/mining_shell_test.dart`
- `test/mining/presentation/visual_parity_golden_test.dart`
- existing golden PNGs only as required by Task 4

### Must not change production files

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

---

### Task 1: Technology Projection, Shared Chrome, Typography, and Responsive Tree

**Files:**
- Modify: `lib/mining/mining_progression_views.dart`
- Test: `test/mining/mining_progression_views_test.dart`
- Create: `lib/mining/presentation/mining_modal_chrome.dart`
- Create: `assets/fonts/IBMPlexMono-Regular.ttf`
- Create: `assets/fonts/IBMPlexMono-SemiBold.ttf`
- Create: `assets/fonts/IBMPlexMono-OFL.txt`
- Modify: `pubspec.yaml`
- Modify: `lib/mining/presentation/technology_sheet.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Test: `test/mining/presentation/technology_sheet_test.dart`
- Test: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Consumes: existing `TechnologyTrackView` fields, `TechnologySheetView`, `MiningContentRegistry.maxTechnologyLevel`, `MiningHex`, `MiningTheme`, `MiningVisuals`.
- Produces: public `TechnologyNodeState`, `TechnologyTrackView.stateForLevel(int)`, simplified `TechnologyTrackView`, unchanged `TechnologySheet(view:, onPurchase:)`, `TechnologySheet.landscapePanelWidth == 528`, `MiningModalChrome`, transparent Technology dialog.

- [ ] **Step 1: Write pure failing node-state projection tests**

Extend `test/mining/mining_progression_views_test.dart` with direct tests of the new API:

```dart
final actionable = TechnologyTrackView(
  track: TechnologyTrack.extraction,
  name: 'Extraction',
  level: 2,
  currentEffect: 'Mining rate ×1.25',
  nextEffect: 'Mining rate ×1.45',
  cost: 1500,
  gateSiteName: 'Granite Crater',
  isGateSatisfied: true,
  isAffordable: true,
  isMaxLevel: false,
  disabledReason: null,
);

expect(actionable.stateForLevel(1), TechnologyNodeState.owned);
expect(actionable.stateForLevel(2), TechnologyNodeState.owned);
expect(actionable.stateForLevel(3), TechnologyNodeState.actionable);
expect(actionable.stateForLevel(4), TechnologyNodeState.future);
expect(actionable.stateForLevel(5), TechnologyNodeState.future);
```

Add blocked and max cases:

```dart
expect(blocked.stateForLevel(4), TechnologyNodeState.blocked);
expect(maxed.stateForLevel(5), TechnologyNodeState.owned);
```

- [ ] **Step 2: Run the pure projection test and verify RED**

```bash
flutter test test/mining/mining_progression_views_test.dart
```

Expected: FAIL because `TechnologyNodeState` / `stateForLevel` do not exist.

- [ ] **Step 3: Add `TechnologyNodeState` and remove dead availability fields**

In `mining_progression_views.dart` add:

```dart
enum TechnologyNodeState { owned, actionable, blocked, future }
```

On `TechnologyTrackView` add:

```dart
TechnologyNodeState stateForLevel(int nodeLevel) {
  assert(nodeLevel >= 1);
  assert(nodeLevel <= MiningContentRegistry.maxTechnologyLevel);
  if (nodeLevel <= level) return TechnologyNodeState.owned;
  if (nodeLevel == level + 1 && !isMaxLevel) {
    return canPurchase
        ? TechnologyNodeState.actionable
        : TechnologyNodeState.blocked;
  }
  return TechnologyNodeState.future;
}
```

Remove:

```text
nodeAvailability
nextNodeAvailability
surveyingNodeAvailability
_nodeAvailability(...)
```

and remove the constructor/factory assignments that only supported those unused members.

- [ ] **Step 4: Re-run pure projection tests**

```bash
flutter test test/mining/mining_progression_views_test.dart
```

Expected: PASS.

- [ ] **Step 5: Replace retiring Technology list tests with starter + parity fixtures**

In `technology_sheet_test.dart`, delete row-layout-specific assertions (`Extraction · Level 0`, repeated Gate rows, three simultaneous buy controls, direct `ElevatedButton` casts).

Keep two fixtures:

1. starter: Extraction 0 actionable, Logistics/Surveying 0 blocked;
2. parity: Extraction 2 actionable, Logistics 3 blocked, Surveying 5 max.

Add a pump helper accepting `Size`, `TextScaler`, and callback.

- [ ] **Step 6: Add failing Technology behavior/layout tests**

Assert projection-driven semantics:

```dart
expect(find.bySemanticsLabel('Extraction level 1 owned'), findsOneWidget);
expect(find.bySemanticsLabel('Extraction level 3 actionable'), findsOneWidget);
expect(find.bySemanticsLabel('Logistics level 4 blocked'), findsOneWidget);
expect(find.bySemanticsLabel('Extraction level 5 future'), findsOneWidget);
```

Selection/blocked action:

```dart
await tester.tap(find.byKey(const Key('mining-technology-node-logistics-4')));
await tester.pump();
expect(find.byKey(const Key('mining-technology-detail-logistics')), findsOneWidget);
expect(find.text('Commission the Frozen Basin site first.'), findsOneWidget);
final blockedAction = find.byKey(const Key('mining-technology-buy-logistics'));
expect(tester.getSize(blockedAction).height, greaterThanOrEqualTo(48));
await tester.tap(blockedAction);
await tester.pump();
expect(purchases, isEmpty);
```

Small phone + text scale:

```dart
await _pumpTechnology(
  tester,
  size: const Size(360, 640),
  view: _starterView(),
  textScaler: const TextScaler.linear(1.3),
);
final action = find.byKey(const Key('mining-technology-buy-extraction'));
await tester.ensureVisible(action);
expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
expect(tester.takeException(), isNull);
```

Landscape:

```dart
expect(
  tester.getSize(find.byKey(const Key('mining-technology-panel-landscape'))).width,
  TechnologySheet.landscapePanelWidth,
);
for (final key in const [
  Key('mining-technology-node-extraction-3'),
  Key('mining-technology-node-logistics-4'),
]) {
  final size = tester.getSize(find.byKey(key));
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}
```

- [ ] **Step 7: Run Technology widget tests and verify RED**

```bash
flutter test test/mining/presentation/technology_sheet_test.dart
```

Expected: FAIL on new tree/panel/selection/layout expectations.

- [ ] **Step 8: Vendor/register IBM Plex Mono**

Copy official IBM Plex files:

```text
assets/fonts/IBMPlexMono-Regular.ttf
assets/fonts/IBMPlexMono-SemiBold.ttf
assets/fonts/IBMPlexMono-OFL.txt
```

Register:

```yaml
    - family: IBMPlexMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexMono-SemiBold.ttf
          weight: 600
```

Run:

```bash
flutter pub get
```

- [ ] **Step 9: Create `MiningModalChrome` using existing theme tokens**

API:

```dart
const MiningModalChrome({
  super.key,
  required this.child,
  this.leading,
  this.trailing,
  this.padding = const EdgeInsets.fromLTRB(14, 26, 14, 20),
  this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
});
```

Use `MiningTheme.panel` and `MiningTheme.accent.withAlpha(...)` for panel edge/42×4 handle. Keep shadow/padding/rounded upper corners only. No routing/state/actions.

- [ ] **Step 10: Implement Technology tree with `MiningHex`**

`TechnologySheet` is stateful only for selected track.

Use `track.stateForLevel(level)`; do not create `_TechnologyNodeState` or duplicate gate/affordability logic.

Every level is wrapped in `48×48` and rendered through `MiningHex`. `onTap` is non-null only for actionable/blocked next nodes. Semantic label uses `state.name`.

Loops use:

```dart
MiningContentRegistry.maxTechnologyLevel
```

- [ ] **Step 11: Implement portrait Technology composition**

Canonical top:

```dart
final panelTop = math.min(190.0, constraints.maxHeight * .24);
```

Use shared chrome, three vertical max→1 tracks, common root, selected detail/action card, and `SingleChildScrollView` so the 360×640 / 1.3 test passes.

- [ ] **Step 12: Implement landscape Technology composition with one shared width constant**

On `TechnologySheet`:

```dart
static const double landscapePanelWidth = 528;
```

Layout:

```dart
final panelWidth = math.min(
  TechnologySheet.landscapePanelWidth,
  constraints.maxWidth,
);
```

Right-align panel, three horizontal tracks, 48×48 nodes, selected detail/action area. Do not modify Site Deck.

- [ ] **Step 13: Present Technology with transparent built-in dialog**

Replace only Technology's `showModalBottomSheet` with barrier-dismissible `showGeneralDialog<void>`. Keep current `TechnologySheetView.from(...)`, `_purchaseTechnology`, and close-then-purchase behavior. Transition duration is zero when shell `_reducedMotion` is true, otherwise 180ms.

- [ ] **Step 14: Run focused Technology tests, format, commit**

```bash
dart format lib/mining/mining_progression_views.dart lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/mining_progression_views_test.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/mining_progression_views_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
git add pubspec.yaml assets/fonts/IBMPlexMono-Regular.ttf assets/fonts/IBMPlexMono-SemiBold.ttf assets/fonts/IBMPlexMono-OFL.txt lib/mining/mining_progression_views.dart lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/mining_progression_views_test.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_shell_test.dart
git commit -m "feat: revamp mining technology overlay"
```

---

### Task 2: Settings Audio and Accessibility Parity

**Files:**
- Modify: `lib/mining/presentation/mining_settings_sheet.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Test: `test/mining/presentation/mining_settings_sheet_test.dart`
- Test: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Consumes: `MiningModalChrome`, `MiningHex`, `MiningTheme`, injected `AudioManager`.
- Produces: unchanged `MiningSettingsSheet(audioManager:)`, inline Music pill, local `_HexSliderThumbShape`, transparent Settings dialog.

- [ ] **Step 1: Replace class-specific Settings tests with behavior tests**

Stop casting `mining-music-switch` to `SwitchListTile`.

With prefs `musicEnabled=true`, `musicVolume=.70`, assert:

```text
AUDIO
Music
Cavern ambience
70%
20 steps
ACCESSIBILITY
Reduced motion
SYSTEM
```

Toggle through key `mining-music-switch`; assert 48px height and `AudioManager.musicEnabled` mutation.

Inspect the real Slider:

```dart
final slider = tester.widget<Slider>(
  find.byKey(const Key('mining-volume-slider')),
);
expect(slider.divisions, 20);
expect(slider.value, .70);
```

- [ ] **Step 2: Add failing dense-layout Settings tests**

At `360×640` / 1.3, ensure Music, Volume, and SYSTEM are reachable and no exception occurs.

At `874×402` / 1.3, assert `mining-settings-panel-landscape`, ensure Volume/SYSTEM reachable, and no overflow/exception.

- [ ] **Step 3: Run Settings tests and verify RED**

```bash
flutter test test/mining/presentation/mining_settings_sheet_test.dart
```

- [ ] **Step 4: Rebuild Settings with shared chrome**

Use transparent full-screen Material + `LayoutBuilder`.

Portrait:

```dart
final panelTop = math.min(392.0, constraints.maxHeight * .45);
```

Use scrollable Audio and Accessibility cards and IBM Plex Mono for metadata/status copy.

- [ ] **Step 5: Implement Music pill without a new motion/accessibility seam**

Keep key `mining-music-switch`, `Semantics(toggled: ...)`, `InkWell`, 48px height, and small `MiningHex` thumb.

Use static `Align`, not `AnimatedAlign`. The mock does not require thumb animation, so Settings does not query `MediaQuery.disableAnimations` and does not add a reduced-motion constructor argument.

- [ ] **Step 6: Keep real Slider and add local hex thumb shape**

Create `_HexSliderThumbShape extends SliderComponentShape` in `mining_settings_sheet.dart` and paint a six-point path at the Slider-supplied center.

Use via `SliderTheme.thumbShape`. Keep Material `Slider`, `divisions: 20`, existing key, keyboard/drag/semantics. Do not overlay a second manually positioned thumb.

- [ ] **Step 7: Keep Settings landscape functional only**

Use same cards in a bounded right-side scroll view. No unreferenced pixel-parity landscape design.

- [ ] **Step 8: Present Settings with transparent dialog**

Replace only Settings bottom-sheet presentation with barrier-dismissible `showGeneralDialog<void>`. Keep injected `_audioManager`. Transition duration uses shell `_reducedMotion` only at the route boundary.

- [ ] **Step 9: Update shell Settings regression**

Assert root key, visible percentage, AudioManager state/mutation, and absence of `BottomSheet`; no `SwitchListTile` class assertions.

- [ ] **Step 10: Run focused Settings tests, format, commit**

```bash
dart format lib/mining/presentation/mining_settings_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/mining_settings_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
git add lib/mining/presentation/mining_settings_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/mining_settings_sheet_test.dart test/mining/presentation/mining_shell_test.dart
git commit -m "feat: revamp mining settings overlay"
```

---

### Task 3: Full-Screen Offline Return and Resume-Lock Safety

**Files:**
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Test: `test/mining/presentation/offline_return_sheet_test.dart`
- Test: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Consumes: unchanged `OfflineProductionSummary`, `MiningContentRegistry`, `MiningVisuals.offlineHero`, `MiningCashChip`, catalog silhouettes, shell cash, shell Logistics level, shell reduced motion.
- Produces: `OfflineReturnSheet(summary:, content:, cash:, logisticsLevel:, reducedMotion:)`, `OfflineReturnSheet.landscapePanelWidth == 470`, full-screen portrait/landscape result, Continue-only dismissal.

- [ ] **Step 1: Update Offline test fixtures for the new presentation inputs**

Pass `cash`, `logisticsLevel`, and `reducedMotion` in every constructor.

Keep existing multi-planet/resource/silhouette/full-site assertions.

- [ ] **Step 2: Add failing cap, dense-layout, dismissal, and asset-failure tests**

Cap test uses the authored table:

```dart
final cap = content.offlineCapFor(2);
final summary = OfflineProductionSummary(
  elapsedUsed: cap,
  produced: const {ResourceType.gold: 1},
  productionByPlanet: const {
    MiningPlanetId.homeworld: {ResourceType.gold: 1},
  },
  fullSites: const {},
  wasOfflineCapped: true,
);
expect(find.text('Capped at 12h — Logistics LV 2'), findsOneWidget);
```

Dense landscape:

```dart
// 874×402, TextScaler.linear(1.3)
expect(
  tester.getSize(find.byKey(const Key('offline-return-summary-landscape'))).width,
  OfflineReturnSheet.landscapePanelWidth,
);
final dismiss = find.byKey(const Key('offline-return-dismiss'));
await tester.ensureVisible(dismiss);
expect(tester.getSize(dismiss).height, greaterThanOrEqualTo(48));
expect(tester.takeException(), isNull);
```

Back-button protection in the shell route test:

```dart
expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
await tester.binding.handlePopRoute();
await tester.pump();
expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
```

Hero failure: wrap the sheet in `DefaultAssetBundle` with a test `CachingAssetBundle` whose `load` throws. Assert the fallback icon appears and Continue remains reachable.

Reduced-motion fixture:

```dart
OfflineReturnSheet(..., reducedMotion: true)
```

assert status dot is static/no repeating animation; false case may animate.

- [ ] **Step 3: Run Offline tests and verify RED**

```bash
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

- [ ] **Step 4: Extend duration/cap presentation without inferring cap from elapsed**

Keep `_formatDuration` for elapsed copy.

When capped:

```dart
final cap = content.offlineCapFor(logisticsLevel);
```

format that value for:

```text
Capped at <cap> — Logistics LV <level>
```

Do not use `summary.elapsedUsed` as the authored cap.

- [ ] **Step 5: Make Offline Return stateful only for the status pulse**

Constructor:

```dart
const OfflineReturnSheet({
  super.key,
  required this.summary,
  required this.content,
  required this.cash,
  required this.logisticsLevel,
  required this.reducedMotion,
});
```

Own one local `AnimationController`. In `initState`/`didUpdateWidget`, repeat only when `reducedMotion == false`; otherwise stop and set a stable value. Do not call `MediaQuery.disableAnimations` inside the sheet.

- [ ] **Step 6: Implement portrait result**

Use full-screen root with `PopScope(canPop:false)`, hero/fallback + gradient, `MiningCashChip`, FLEET RETURNED, elapsed/cap copy, data-driven planet/resource sections, existing silhouettes/full-site warnings, next action, and one `CONTINUE MINING` button. Keep body scrollable.

- [ ] **Step 7: Implement measured Offline landscape composition**

On `OfflineReturnSheet`:

```dart
static const double landscapePanelWidth = 470;
```

Use the same constant for the right-side summary panel and tests. Keep return/hero left; production + Continue in the right scroll flow.

- [ ] **Step 8: Make Continue the only dismissal path**

Shell route:

```dart
showGeneralDialog<void>(
  barrierDismissible: false,
  ...
)
```

Sheet:

```dart
PopScope(canPop: false, ...)
```

Continue is the sole `Navigator.pop()` action.

- [ ] **Step 9: Pass shell-owned reduced motion and live presentation scalars**

In `_showOfflineReturn(...)` pass:

```dart
cash: _displayState.cash,
logisticsLevel: _displayState.technology.logistics,
reducedMotion: _reducedMotion,
```

Do not change resume/checkpoint/accrual timing.

- [ ] **Step 10: Strengthen shell resume regression**

After resume assert:

- Offline root present;
- no `BottomSheet`;
- controller state preserved;
- system back does not dismiss;
- Continue dismisses normally.

- [ ] **Step 11: Run focused Offline tests, format, commit**

```bash
dart format lib/mining/presentation/offline_return_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/offline_return_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
git add lib/mining/presentation/offline_return_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/offline_return_sheet_test.dart test/mining/presentation/mining_shell_test.dart
git commit -m "feat: revamp offline mining return"
```

---

### Task 4: Rehabilitate Visual Harness, Add Two Scoped Panel Goldens, and Build Five-Frame Evidence

**Files:**
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Modify/delete existing stale golden PNGs only as dictated below
- Create: at most two HPA-438 Technology panel golden PNGs
- Create: `docs/superpowers/evidence/hpa-438/reference/*.png`
- Create: `docs/superpowers/evidence/hpa-438/implementation/*.png`
- Create: `docs/superpowers/evidence/hpa-438/parity.md`

**Interfaces:**
- Consumes: existing `_pumpSurface`, finished Technology widget, existing Linux CI golden behavior.
- Produces: maintainable golden harness with no new background-coupled HPA-438 baselines, two Technology panel regression guards at most, five source-vs-app parity rows.

- [ ] **Step 1: Confirm existing Linux golden behavior before adding HPA-438 baselines**

Run on Linux:

```bash
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected before edits: active Mine Site goldens run; Site Deck/Stellar Map remain skipped because of unconditional `skip:true`.

- [ ] **Step 2: Rehabilitate or remove the two stale unconditional skips**

First remove `skip:true` from Site Deck and Stellar Map and regenerate **only** their current baselines on Linux:

```bash
flutter test --update-goldens test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

If both pass with regenerated PNGs and no production changes, keep the tests unskipped and commit the refreshed PNGs.

If either requires modifying out-of-scope Site Deck/Stellar Map production code merely to satisfy the old screenshot, delete that stale test and its corresponding PNG instead. Do not touch production code for this cleanup.

- [ ] **Step 3: Load both IBM Plex Mono weights in the golden harness**

Use one `FontLoader('IBMPlexMono')`, add both Regular and SemiBold byte futures, then load. Keep existing Orbitron loader.

- [ ] **Step 4: Add only two scoped HPA-438 golden tests**

Add:

```text
hpa438_technology_panel_402x874.png
hpa438_technology_panel_874x402.png
```

Pump the relevant Technology overlay state, but golden the finder rather than the full screen:

```dart
await expectLater(
  find.byKey(const Key('mining-technology-panel-portrait')),
  matchesGoldenFile('goldens/hpa438_technology_panel_402x874.png'),
);
```

and:

```dart
await expectLater(
  find.byKey(const Key('mining-technology-panel-landscape')),
  matchesGoldenFile('goldens/hpa438_technology_panel_874x402.png'),
);
```

Keep the repository's existing platform predicate so CI/Linux executes them. Do not add full-screen Technology/Settings/Offline goldens.

- [ ] **Step 5: Generate and verify the two panel goldens on Linux**

```bash
flutter test --update-goldens test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: all non-skipped goldens PASS on Linux.

- [ ] **Step 6: Capture five mock references and five implementation images**

Create reference captures from the supplied mock:

```text
reference/technology-portrait-panel.png
reference/technology-landscape-panel.png
reference/settings-portrait-panel.png
reference/offline-return-portrait.png
reference/offline-return-landscape.png
```

Create matching app captures under `implementation/`.

Technology and Settings captures are cropped to the in-scope panels. Offline Return captures include the complete result surface.

Do not commit the standalone HTML bundle.

- [ ] **Step 7: Write `parity.md` as the actual visual acceptance gate**

Use a five-row table:

```markdown
| Surface | Mock | Implementation | Result |
| --- | --- | --- | --- |
| Technology portrait panel | ... | ... | [ ] |
| Technology landscape 528px panel | ... | ... | [ ] |
| Settings portrait panel | ... | ... | [ ] |
| Offline Return portrait | ... | ... | [ ] |
| Offline Return landscape | ... | ... | [ ] |
```

Checklist covers:

- 528/470 geometry;
- node hierarchy/state;
- Settings Audio/Accessibility hierarchy;
- Offline hero/result/summary hierarchy;
- Orbitron/IBM Plex Mono hierarchy;
- action placement;
- 1.3 reachability;
- no Site Deck production changes.

PR body must call this evidence document the **parity gate**. Goldens are regression guards only.

- [ ] **Step 8: Run visual suite and commit**

```bash
dart format test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
git add test/mining/presentation/visual_parity_golden_test.dart test/mining/presentation/goldens/ docs/superpowers/evidence/hpa-438/
git commit -m "test: lock mining secondary surface parity evidence"
```

---

### Task 5: Full Regression, Scope Guard, Risks Check, and Handoff

**Files:**
- Modify only files already allowed above if verification exposes an HPA-438 defect.
- Update PR #24 and Linear HPA-438 after green verification.

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: green repository gates, no domain/Site Deck drift, completed visual evidence, In Review handoff.

- [ ] **Step 1: Run repository formatting/analysis gates**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

- [ ] **Step 2: Run focused HPA-438 tests**

```bash
flutter test test/mining/mining_progression_views_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

- [ ] **Step 3: Run full repository gates from `AGENTS.md`**

```bash
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

If the current execution environment cannot run a platform build, record that exact environment limitation in PR #24; do not replace the command with a weaker check silently.

- [ ] **Step 4: Prove no domain/Site Deck/Mine Site/Stellar Map production drift**

```bash
git diff --name-only main...HEAD -- \
  lib/mining/mining_controller.dart \
  lib/mining/mining_simulation.dart \
  lib/mining/mining_state.dart \
  lib/mining/mining_save_repository.dart \
  lib/mining/mining_content.dart \
  lib/mining/fleet_dock_view.dart \
  lib/mining/site_deck_view.dart \
  lib/mining/mine_site_view.dart \
  lib/mining/presentation/site_deck_screen.dart \
  lib/mining/presentation/mine_site_screen.dart \
  lib/mining/presentation/stellar_map_screen.dart
```

Expected: no output.

`lib/mining/mining_progression_views.dart` is intentionally excluded because Task 1 makes the approved pure projection change.

- [ ] **Step 5: Re-run the non-dismissible Offline Return risk checks explicitly**

Run:

```bash
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

Confirm the test names/coverage include:

- `874×402` at text scale `1.3`;
- system back leaves dialog visible;
- failing hero asset still leaves Continue reachable;
- Continue dismisses normally.

- [ ] **Step 6: Complete parity evidence review**

Check all five rows in `docs/superpowers/evidence/hpa-438/parity.md`. Do not mark the PR ready while any row is unresolved.

- [ ] **Step 7: Update PR #24 and Linear**

PR body records:

- five evidence rows and evidence path;
- two Technology panel goldens only;
- result of stale golden rehabilitation/removal;
- 528/470 measured geometry;
- 360×640 / 874×402 / 1.3 structural coverage;
- reduced-motion ownership through shell;
- cap copy from `content.offlineCapFor(logisticsLevel)`;
- non-dismissible/back/asset-failure safety tests;
- full verification commands/results;
- no-domain/no-Site-Deck-drift output.

Move HPA-438 to `In Review` and mark PR #24 ready only after the recorded gates are green.

---

## Review-Resolved Decisions

- Technology landscape width remains **528 px** from the mock; Offline Return landscape is **470 px**.
- `TechnologyNodeState` belongs in the pure `TechnologyTrackView` projection, not the widget.
- Unused `nodeAvailability` projection members are removed during the Technology rewrite.
- Technology nodes reuse `MiningHex` and `MiningContentRegistry.maxTechnologyLevel`.
- `MiningModalChrome` reuses `MiningTheme` tokens.
- Settings keeps the real Material 20-step Slider and uses one local `SliderComponentShape`.
- Settings Music thumb is static; no local reduced-motion query is introduced.
- Offline cap copy uses `content.offlineCapFor(logisticsLevel)`.
- Offline Return receives `reducedMotion` from `MiningShell`.
- The non-dismissible resume dialog gets explicit 874×402/1.3, system-back, hero-failure, and Continue tests.
- No five full-screen HPA-438 golden set is added. At most two Technology panel goldens are committed.
- Existing unconditional stale goldens are rehabilitated on Linux or removed; HPA-438 does not add to a stale-baseline graveyard.
- Five committed source-vs-app captures are the actual visual parity acceptance gate.
- No `OfflineReturnView`, modal manager, generic toggle, second palette, Site Deck redesign, or domain change is added.
