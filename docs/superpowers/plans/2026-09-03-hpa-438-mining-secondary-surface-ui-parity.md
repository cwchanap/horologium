# HPA-438 Mining Secondary-Surface UI Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revamp the existing mining Technology, Settings, and Offline Return surfaces to match the five canonical states in the supplied `Horologium Merge Mining (standalone).html` mock without changing mining rules, persistence, economy, or ownership boundaries.

**Architecture:** Keep `MiningShell` as the runtime owner and keep `TechnologySheetView`, `AudioManager`, and `OfflineProductionSummary` authoritative. Technology and Settings use transparent built-in dialogs with one tiny shared chrome widget; Offline Return uses its own non-dismissible full-screen dialog. Reuse `MiningTheme`, `MiningHex`, current HUD/art primitives, and the existing golden harness; add only IBM Plex Mono as a scoped secondary font family.

**Tech Stack:** Flutter / Dart, Material widgets, `showGeneralDialog`, existing Horologium mining presentation primitives, `flutter_test`, SharedPreferences test doubles, golden tests.

**Spec:** `docs/superpowers/specs/2026-09-03-hpa-438-mining-secondary-surface-ui-parity-design.md`

## Global Constraints

- All work stays on `jack65786656/hpa-438-revamp-technology-settings-and-offline-return-for-mining-ui` and PR #24.
- Canonical states: Technology `402×874`, Technology `874×402`, Settings `402×874`, Offline Return `402×874`, Offline Return `874×402`.
- Measured mock geometry: Technology landscape panel is **528 px** wide; Offline Return landscape summary panel is **470 px** wide.
- Do not modify mining domain/state/repository/simulation/progression files.
- Do not redesign Site Deck, Mine Site, or Stellar Map.
- Do not add Provider/Riverpod/Bloc, routing package, modal manager, design-system package, generic toggle, new visual-test stack, persisted UI selection, or reward/retention mechanics.
- Keep `TechnologySheet(view:, onPurchase:)`, `MiningSettingsSheet(audioManager:)`, and `OfflineProductionSummary` as the existing boundaries.
- Use `MiningContentRegistry.maxTechnologyLevel` for visible Technology level count/labels.
- Every tappable control, including selectable Technology nodes, is at least `48×48` logical pixels.
- Critical controls remain reachable at `360×640`, `430×932`, `874×402`, and text scale `1.3`.
- `MediaQuery.disableAnimations` remains the reduced-motion source.
- Use `MiningTheme` tokens for panel/accent/highlight/warning/gate colors.
- Keep Orbitron as display type. Add IBM Plex Mono Regular (`400`) and SemiBold (`600`) for secondary/status copy.
- Missing optional artwork must never hide the primary action.

---

## File Structure

### Create

- `lib/mining/presentation/mining_modal_chrome.dart`
- `assets/fonts/IBMPlexMono-Regular.ttf`
- `assets/fonts/IBMPlexMono-SemiBold.ttf`
- `assets/fonts/IBMPlexMono-OFL.txt`
- `docs/superpowers/evidence/hpa-438/parity.md`
- `docs/superpowers/evidence/hpa-438/reference/technology-402x874.png`
- `docs/superpowers/evidence/hpa-438/reference/technology-874x402.png`
- `docs/superpowers/evidence/hpa-438/reference/settings-402x874.png`
- `docs/superpowers/evidence/hpa-438/reference/offline-return-402x874.png`
- `docs/superpowers/evidence/hpa-438/reference/offline-return-874x402.png`

### Modify

- `pubspec.yaml`
- `lib/mining/presentation/technology_sheet.dart`
- `lib/mining/presentation/mining_settings_sheet.dart`
- `lib/mining/presentation/offline_return_sheet.dart`
- `lib/mining/presentation/mining_shell.dart`
- `test/mining/presentation/technology_sheet_test.dart`
- `test/mining/presentation/mining_settings_sheet_test.dart`
- `test/mining/presentation/offline_return_sheet_test.dart`
- `test/mining/presentation/mining_shell_test.dart`
- `test/mining/presentation/visual_parity_golden_test.dart`
- `test/mining/presentation/goldens/hpa438_*.png`

### Must not change

```text
lib/mining/mining_controller.dart
lib/mining/mining_simulation.dart
lib/mining/mining_state.dart
lib/mining/mining_save_repository.dart
lib/mining/mining_content.dart
lib/mining/mining_progression_views.dart
lib/mining/fleet_dock_view.dart
lib/mining/site_deck_view.dart
lib/mining/mine_site_view.dart
lib/mining/presentation/site_deck_screen.dart
```

---

### Task 1: Technology Overlay, Shared Chrome, and Secondary Typography

**Files:**
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
- Consumes: `TechnologySheetView`, `TechnologyTrackView`, `TechnologyTrack`, `MiningContentRegistry.maxTechnologyLevel`, `MiningHex`, `MiningTheme`, `MiningVisuals`.
- Produces: `MiningModalChrome`; unchanged `TechnologySheet(view:, onPurchase:)`; transparent Technology dialog from `MiningShell`.

- [ ] **Step 1: Replace row-UI tests with starter and parity fixtures**

Delete assertions that depend on the current list layout: `Extraction · Level 0`, repeated gate rows, three simultaneous buy controls, and direct `ElevatedButton` casts for Logistics/Surveying.

Keep a starter fixture with Extraction level 0 actionable and Logistics/Surveying blocked by Landing Basin. Keep a parity fixture with Extraction level 2 actionable to level 3, Logistics level 3 blocked at level 4, and Surveying maxed at level 5. Use the exact existing `TechnologyTrackView` fields; do not add a test-only view type.

- [ ] **Step 2: Add failing Technology behavior/layout tests**

For the parity fixture at `402×874` assert:

```dart
expect(find.byKey(const Key('mining-technology-panel-portrait')), findsOneWidget);
expect(find.bySemanticsLabel('Extraction level 1 owned'), findsOneWidget);
expect(find.bySemanticsLabel('Extraction level 3 actionable'), findsOneWidget);
expect(find.bySemanticsLabel('Logistics level 4 blocked'), findsOneWidget);
expect(find.bySemanticsLabel('Extraction level 5 future'), findsOneWidget);
```

Selection/blocked-action behavior:

```dart
final purchases = <TechnologyTrack>[];
await tester.tap(find.byKey(const Key('mining-technology-node-logistics-4')));
await tester.pump();
expect(find.byKey(const Key('mining-technology-detail-logistics')), findsOneWidget);
expect(find.text('Commission the Frozen Basin site first.'), findsOneWidget);
final blockedAction = find.byKey(const Key('mining-technology-buy-logistics'));
expect(blockedAction, findsOneWidget);
expect(tester.getSize(blockedAction).height, greaterThanOrEqualTo(48));
await tester.tap(blockedAction);
await tester.pump();
expect(purchases, isEmpty);
```

Starter small-phone coverage at `360×640` and again with `TextScaler.linear(1.3)`:

```dart
final action = find.byKey(const Key('mining-technology-buy-extraction'));
await tester.ensureVisible(action);
expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
expect(tester.takeException(), isNull);
```

Landscape coverage at `874×402`:

```dart
final panel = find.byKey(const Key('mining-technology-panel-landscape'));
expect(tester.getSize(panel).width, 528);
for (final key in const [
  Key('mining-technology-node-extraction-3'),
  Key('mining-technology-node-logistics-4'),
]) {
  final size = tester.getSize(find.byKey(key));
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}
expect(tester.takeException(), isNull);
```

- [ ] **Step 3: Run Technology tests to verify failure**

```bash
flutter test test/mining/presentation/technology_sheet_test.dart
```

Expected: FAIL on the new tree/panel/node behavior.

- [ ] **Step 4: Vendor/register IBM Plex Mono**

Copy official Regular, SemiBold, and OFL files to the paths listed above. Add:

```yaml
    - family: IBMPlexMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexMono-SemiBold.ttf
          weight: 600
```

Run `flutter pub get` and keep Orbitron unchanged.

- [ ] **Step 5: Create `MiningModalChrome` using `MiningTheme` tokens**

Create a stateless helper with `child`, optional `leading`/`trailing`, padding, border radius, shadow, and a 42×4 handle. Use:

```dart
color: MiningTheme.panel,
border: Border(
  top: BorderSide(color: MiningTheme.accent.withAlpha(102)),
),
```

Use `MiningTheme.accent.withAlpha(180)` for the handle. Do not add routing/state/actions to the helper.

- [ ] **Step 6: Convert `TechnologySheet` to local selection only**

Add:

```dart
enum _TechnologyNodeState { owned, actionable, blocked, future }
```

Projection:

```dart
_TechnologyNodeState _nodeState(TechnologyTrackView track, int level) {
  if (level <= track.level) return _TechnologyNodeState.owned;
  if (level == track.level + 1 && !track.isMaxLevel) {
    return track.canPurchase
        ? _TechnologyNodeState.actionable
        : _TechnologyNodeState.blocked;
  }
  return _TechnologyNodeState.future;
}
```

Initial selection priority: first purchasable track, else first non-max track, else first track. All loops/labels use `MiningContentRegistry.maxTechnologyLevel`.

- [ ] **Step 7: Render Technology nodes with `MiningHex`**

Use a `48×48` wrapper for every node. `MiningHex.onTap` is non-null only for actionable/blocked next nodes. Stable key:

```dart
Key('mining-technology-node-${track.track.name}-$level')
```

Semantic label:

```dart
'${track.name} level $level ${state.name}'
```

Use `MiningTheme.accent`, `warning`, `gate`, and subdued white for states. Do not create another hex painter.

- [ ] **Step 8: Implement portrait Technology composition**

Use transparent full-screen `Material` + `LayoutBuilder`. Panel top:

```dart
final panelTop = math.min(190.0, constraints.maxHeight * .24);
```

Place `MiningModalChrome` from panel top to bottom and make panel content scrollable. Render three vertical columns, max level down to 1, simple connectors, common root, and one selected detail/action card.

Header:

```dart
Text('Technology')
Text('MAX LV ${MiningContentRegistry.maxTechnologyLevel}')
```

Only selected detail card contains `mining-technology-buy-${selected.track.name}`. Disabled selected cards keep a 48px action surface but do not fire `onPurchase`; show `disabledReason`.

- [ ] **Step 9: Implement measured Technology landscape composition**

```dart
const canonicalPanelWidth = 528.0;
final panelWidth = math.min(canonicalPanelWidth, constraints.maxWidth);
```

Right-align a full-height panel keyed `mining-technology-panel-landscape`. Render three horizontal tracks with 48×48 `MiningHex` nodes and one selected detail/action area. Do not change Site Deck on the left.

- [ ] **Step 10: Present Technology with `showGeneralDialog`**

Replace only the Technology bottom-sheet call with a barrier-dismissible transparent `showGeneralDialog<void>` using the existing view projection and `_purchaseTechnology`. Use zero transition duration when `_reducedMotion` is true; otherwise 180ms.

- [ ] **Step 11: Run focused Technology/shell tests and commit**

```bash
dart format lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
git add pubspec.yaml assets/fonts/IBMPlexMono-Regular.ttf assets/fonts/IBMPlexMono-SemiBold.ttf assets/fonts/IBMPlexMono-OFL.txt lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_shell_test.dart
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
- Produces: unchanged `MiningSettingsSheet(audioManager:)`, local Music pill, local `_HexSliderThumbShape`, transparent Settings dialog.

- [ ] **Step 1: Replace class-specific Settings tests with behavior tests**

Stop casting `mining-music-switch` to `SwitchListTile`. With preferences `musicEnabled=true`, `musicVolume=.70`, assert Audio/Music/Cavern ambience/70%/20 steps/Accessibility/Reduced motion/SYSTEM copy.

Toggle behavior:

```dart
final toggle = find.byKey(const Key('mining-music-switch'));
expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
await tester.tap(toggle);
await tester.pump();
expect(manager.musicEnabled, isFalse);
```

Slider contract:

```dart
final slider = tester.widget<Slider>(
  find.byKey(const Key('mining-volume-slider')),
);
expect(slider.divisions, 20);
expect(slider.value, .70);
```

- [ ] **Step 2: Add failing dense-layout Settings tests**

At `360×640` / 1.3, `ensureVisible` Music, Volume, and SYSTEM and assert no exception. At `874×402` / 1.3, assert `mining-settings-panel-landscape`, ensure Volume and SYSTEM are reachable, and assert no exception.

- [ ] **Step 3: Run Settings tests to verify failure**

```bash
flutter test test/mining/presentation/mining_settings_sheet_test.dart
```

- [ ] **Step 4: Rebuild Settings with `MiningModalChrome`**

Use transparent full-screen `Material` + `LayoutBuilder`. Portrait panel top:

```dart
final panelTop = math.min(392.0, constraints.maxHeight * .45);
```

Use scrollable Audio and Accessibility cards. Use IBM Plex Mono for secondary/status text and percentage metadata.

- [ ] **Step 5: Implement inline Music pill with `MiningHex`**

Keep key `mining-music-switch`, 48px height, `Semantics(toggled: ...)`, and `InkWell`. Use `AnimatedAlign` with zero duration under reduced motion. The thumb is a small `MiningHex`. Do not add a generic toggle widget.

- [ ] **Step 6: Keep real Slider and add local `SliderComponentShape`**

Create `_HexSliderThumbShape extends SliderComponentShape` in `mining_settings_sheet.dart`. Paint a six-point path centered at the Slider-supplied center. Use it through `SliderTheme.thumbShape`; keep Material `Slider` with `divisions: 20`. Do not hide the stock thumb and overlay a second manually positioned hex.

- [ ] **Step 7: Keep Settings landscape functional only**

Use the same cards in a bounded right-side scroll view keyed `mining-settings-panel-landscape`. No pixel-parity landscape design is invented.

- [ ] **Step 8: Present Settings with `showGeneralDialog`**

Replace only the Settings bottom-sheet call with barrier-dismissible transparent `showGeneralDialog<void>` using the injected `_audioManager`; reduced-motion transition is zero, otherwise 180ms.

- [ ] **Step 9: Update shell Settings regression**

Assert root key, visible `75%`, AudioManager values and mutation, plus absence of `BottomSheet`. Do not assert `SwitchListTile` class.

- [ ] **Step 10: Run focused tests and commit**

```bash
dart format lib/mining/presentation/mining_settings_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/mining_settings_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
git add lib/mining/presentation/mining_settings_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/mining_settings_sheet_test.dart test/mining/presentation/mining_shell_test.dart
git commit -m "feat: revamp mining settings overlay"
```

---

### Task 3: Full-Screen Offline Return

**Files:**
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Test: `test/mining/presentation/offline_return_sheet_test.dart`
- Test: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Consumes: unchanged `OfflineProductionSummary`, `MiningContentRegistry`, `MiningVisuals.offlineHero`, `MiningCashChip`, catalog silhouettes, live cash, live Logistics level.
- Produces: `OfflineReturnSheet(summary:, content:, cash:, logisticsLevel:)`, full-screen portrait/landscape layouts, Continue-only dismissal.

- [ ] **Step 1: Update Offline tests for new scalars and keys**

Pass `cash` and `logisticsLevel` to every test constructor. Keep existing multi-planet/resource/silhouette/full-site coverage. Add portrait root/status/cash assertions, capped copy `Capped at 12h — Logistics LV 2`, uncapped absence, 470px landscape panel assertion, and Continue reachability at `360×640` and `430×932` with text scale `1.3`.

- [ ] **Step 2: Run Offline tests to verify failure**

```bash
flutter test test/mining/presentation/offline_return_sheet_test.dart
```

- [ ] **Step 3: Convert `OfflineReturnSheet` to stateful pulse ownership**

Constructor accepts summary, content, cash, logisticsLevel. Use `SingleTickerProviderStateMixin`. Follow `MainMenu.didChangeDependencies()` locally: own one pulse controller, stop/value=1 under `MediaQuery.disableAnimations`, repeat(reverse:true) otherwise, dispose it. Animate only the FLEET RETURNED status dot.

- [ ] **Step 4: Extend the existing duration formatter**

Use one formatter with a `compact` option. Cap text is derived from `summary.elapsedUsed` and `logisticsLevel`; do not call `content.offlineCapFor()` in the widget.

- [ ] **Step 5: Implement portrait full-screen result**

Root uses `PopScope(canPop: false)` + full-screen Material. Composition: hero + gradient, `MiningCashChip`, FLEET RETURNED, elapsed/cap text, data-driven production sections, existing catalog silhouettes/full-site warnings, one `CONTINUE MINING` button keyed `offline-return-dismiss`. Keep content scrollable.

- [ ] **Step 6: Implement 470px Offline landscape panel**

Use `offline-return-landscape` root and `offline-return-summary-landscape` right panel at `470` px. Keep return/hero info left and production + Continue in right scroll flow.

- [ ] **Step 7: Make Continue the only dismissal path**

Use `PopScope(canPop:false)`, shell route `barrierDismissible:false`, and Continue `Navigator.of(context).pop()`.

- [ ] **Step 8: Promote shell Offline Return to `showGeneralDialog`**

Pass unchanged summary/content plus `_displayState.cash` and `_displayState.technology.logistics`; keep resume/accrual timing untouched.

- [ ] **Step 9: Extend shell resume regression**

Assert Offline root/portrait keys, no `BottomSheet`, production text/controller state preserved, then tap Continue and confirm dismissal.

- [ ] **Step 10: Run focused tests and commit**

```bash
dart format lib/mining/presentation/offline_return_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/offline_return_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
git add lib/mining/presentation/offline_return_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/offline_return_sheet_test.dart test/mining/presentation/mining_shell_test.dart
git commit -m "feat: revamp offline mining return"
```

---

### Task 4: Five Canonical Goldens and Parity Evidence

**Files:**
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Create/update: `test/mining/presentation/goldens/hpa438_*.png`
- Create: `docs/superpowers/evidence/hpa-438/reference/*.png`
- Create: `docs/superpowers/evidence/hpa-438/parity.md`

**Interfaces:**
- Consumes: finished widgets, existing `_pumpSurface`, actual `SiteDeckScreen`, five mock frames.
- Produces: five Linux goldens and explicit evidence/scoring boundaries.

- [ ] **Step 1: Load both IBM Plex Mono weights**

Use one `FontLoader('IBMPlexMono')`, add both Regular and SemiBold TTF byte futures, then `await loader.load()`. Keep existing Orbitron loader. Do not load Regular only.

- [ ] **Step 2: Add deterministic parity fixtures**

Use the same Technology parity state as Task 1 and a test-only 16h Offline summary with mock-like Gold/Coal/Stone values. Keep all sample values in tests only.

- [ ] **Step 3: Reuse actual Site Deck as Technology/Settings backdrop**

Extend existing `_pumpSurface` composition with a deterministic real `SiteDeckScreen`, cash `1840`, and non-empty cargo. Stack Technology/Settings overlays above it. Do not modify Site Deck.

- [ ] **Step 4: Add exactly five full-screen canonical goldens**

```text
hpa438_technology_402x874.png
hpa438_technology_874x402.png
hpa438_settings_402x874.png
hpa438_offline_return_402x874.png
hpa438_offline_return_874x402.png
```

Use current `skip: kIsWeb || Platform.isMacOS`. Technology landscape full-screen golden is composition smoke context; left-side Site Deck is not parity-scored.

- [ ] **Step 5: Generate/verify goldens on Linux**

```bash
flutter test --update-goldens test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
file test/mining/presentation/goldens/hpa438_*.png
```

- [ ] **Step 6: Export five source mock frames**

Capture exact `data-screen-label` frames: Technology sheet, Technology landscape, Settings sheet, Offline return, Offline return landscape. Save to the evidence paths. Do not commit the HTML bundle.

- [ ] **Step 7: Write evidence with explicit landscape scoring**

`parity.md` states that Technology landscape scores only the **rightmost 528 px Technology panel**; left-side current Site Deck is out-of-scope smoke context. Other four canonical rows score their full defined surfaces. Include mock and Flutter images plus checklist for 528/470 widths, node hierarchy, Settings hierarchy, Offline hierarchy, both IBM Plex weights, 1.3 reachability, and no Site Deck changes.

- [ ] **Step 8: Run focused visual suite and commit**

```bash
dart format test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
git add test/mining/presentation/visual_parity_golden_test.dart test/mining/presentation/goldens/hpa438_*.png docs/superpowers/evidence/hpa-438/
git commit -m "test: lock mining secondary surface parity"
```

---

### Task 5: Full Regression, Scope Guard, and Handoff

**Files:**
- Modify only HPA-438 presentation/test/evidence files if verification finds a defect.
- Update PR #24 and Linear HPA-438 after verification.

- [ ] **Step 1: Run exact repository formatting/analysis gates**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

- [ ] **Step 2: Run focused HPA-438 tests**

```bash
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

- [ ] **Step 3: Run full repository verification from `AGENTS.md`**

```bash
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Report any environment-only inability to run a platform build explicitly in PR #24.

- [ ] **Step 4: Prove no domain or Site Deck drift**

```bash
git diff --name-only main...HEAD -- \
  lib/mining/mining_controller.dart \
  lib/mining/mining_simulation.dart \
  lib/mining/mining_state.dart \
  lib/mining/mining_save_repository.dart \
  lib/mining/mining_content.dart \
  lib/mining/mining_progression_views.dart \
  lib/mining/fleet_dock_view.dart \
  lib/mining/site_deck_view.dart \
  lib/mining/mine_site_view.dart \
  lib/mining/presentation/site_deck_screen.dart
```

Expected: no output.

- [ ] **Step 5: Complete parity evidence review**

Check every row in `docs/superpowers/evidence/hpa-438/parity.md`. Technology landscape scoring is limited to its rightmost 528px panel. Do not expand scope to Site Deck.

- [ ] **Step 6: Update PR #24 and Linear after green gates**

PR body records five canonical states, 528/470 measured widths, 360×640 + 1.3 Technology/Settings coverage, exact verification results, no-domain-drift output, and evidence path. Move HPA-438 to `In Review` and mark PR #24 ready only after those results are recorded.

---

## Review-Resolved Decisions

- Technology landscape width is **528 px**, verified from the mock; `470 px` applies to Offline Return landscape.
- Every selectable Technology node is at least `48×48`.
- Technology loops/labels use `MiningContentRegistry.maxTechnologyLevel`.
- Technology nodes reuse `MiningHex`.
- `MiningModalChrome` uses `MiningTheme` tokens, not duplicate raw palette constants.
- Settings keeps the real 20-step Material Slider and uses a local `SliderComponentShape` for the hex thumb; no manually positioned overlay thumb.
- Technology tests replace retiring list assertions while preserving starter-state coverage and adding the four-state parity fixture.
- Technology and Settings both test `360×640` and text scale `1.3`.
- Analysis uses `flutter analyze --fatal-infos`.
- Technology landscape full-screen golden is smoke context; parity scoring is limited to the rightmost 528px panel.
- Golden setup loads both IBM Plex Mono Regular and SemiBold.
- No modal helper, generic toggle, second color file, or Site Deck work is added.