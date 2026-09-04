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

Keep a starter fixture:

```dart
TechnologySheetView _starterView() => const TechnologySheetView(
  tracks: [
    TechnologyTrackView(
      track: TechnologyTrack.extraction,
      name: 'Extraction',
      level: 0,
      currentEffect: 'Mining rate ×1.00',
      nextEffect: 'Mining rate ×1.10',
      cost: 300,
      gateSiteName: 'Landing Basin',
      isGateSatisfied: true,
      isAffordable: true,
      isMaxLevel: false,
      disabledReason: null,
    ),
    TechnologyTrackView(
      track: TechnologyTrack.logistics,
      name: 'Logistics',
      level: 0,
      currentEffect: 'Mine capacity ×1.00, offline cap 8h',
      nextEffect: 'Mine capacity ×1.15, offline cap 10h',
      cost: 300,
      gateSiteName: 'Landing Basin',
      isGateSatisfied: false,
      isAffordable: true,
      isMaxLevel: false,
      disabledReason: 'Commission the Landing Basin site first.',
    ),
    TechnologyTrackView(
      track: TechnologyTrack.surveying,
      name: 'Surveying',
      level: 0,
      currentEffect: '1 of 9 sites revealable',
      nextEffect: '2 of 9 sites revealable',
      cost: 300,
      gateSiteName: 'Landing Basin',
      isGateSatisfied: false,
      isAffordable: true,
      isMaxLevel: false,
      disabledReason: 'Commission the Landing Basin site first.',
    ),
  ],
);
```

Keep a parity fixture:

```dart
TechnologySheetView _parityView() => const TechnologySheetView(
  tracks: [
    TechnologyTrackView(
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
    ),
    TechnologyTrackView(
      track: TechnologyTrack.logistics,
      name: 'Logistics',
      level: 3,
      currentEffect: 'Mine capacity ×1.50, offline cap 16h',
      nextEffect: 'Mine capacity ×1.75, offline cap 20h',
      cost: 4000,
      gateSiteName: 'Frozen Basin',
      isGateSatisfied: false,
      isAffordable: false,
      isMaxLevel: false,
      disabledReason: 'Commission the Frozen Basin site first.',
    ),
    TechnologyTrackView(
      track: TechnologyTrack.surveying,
      name: 'Surveying',
      level: 5,
      currentEffect: '9 of 9 sites revealable',
      nextEffect: null,
      cost: null,
      gateSiteName: null,
      isGateSatisfied: true,
      isAffordable: true,
      isMaxLevel: true,
      disabledReason: 'Technology is at max level.',
    ),
  ],
);
```

- [ ] **Step 2: Add failing Technology behavior/layout tests**

Add a pump helper accepting `Size` and `TextScaler`.

For `_parityView()` at `402×874` assert:

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

Starter small-phone coverage:

```dart
final action = find.byKey(const Key('mining-technology-buy-extraction'));
await tester.ensureVisible(action);
expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
expect(tester.takeException(), isNull);
```

Repeat at `360×640` with `TextScaler.linear(1.3)`.

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

Expected: FAIL on new tree/panel/node behavior.

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

Run:

```bash
flutter pub get
```

- [ ] **Step 5: Create `MiningModalChrome` using `MiningTheme` tokens**

Create a stateless helper with constructor:

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

Its panel decoration uses:

```dart
color: MiningTheme.panel,
border: Border(
  top: BorderSide(color: MiningTheme.accent.withAlpha(102)),
),
```

Its 42×4 handle uses `MiningTheme.accent.withAlpha(180)`. Keep only `child`, `leading`, `trailing`, padding, border radius, shadow, and handle. No routing/state/actions.

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

Initial selection priority: first purchasable track, else first non-max track, else first track.

All loops use:

```dart
MiningContentRegistry.maxTechnologyLevel
```

- [ ] **Step 7: Render all Technology nodes with `MiningHex`**

Use a `48×48` wrapper for every node. `MiningHex.onTap` is non-null only for actionable/blocked next nodes. Stable key:

```dart
Key('mining-technology-node-${track.track.name}-$level')
```

Stable semantic label:

```dart
'${track.name} level $level ${state.name}'
```

Use `MiningTheme.accent`, `warning`, `gate`, and subdued white for owned/actionable/blocked/future states. Do not create another hex painter.

- [ ] **Step 8: Implement portrait Technology composition**

Use transparent full-screen `Material` + `LayoutBuilder`. Portrait panel:

```dart
final panelTop = math.min(190.0, constraints.maxHeight * .24);
```

Place `MiningModalChrome` from `panelTop` to bottom. Use `SingleChildScrollView` inside the panel so `360×640`/1.3 stays reachable.

Render three vertical columns, max level down to 1, simple visual connectors, common root, and one selected detail/action card.

Header:

```dart
Text('Technology')
Text('MAX LV ${MiningContentRegistry.maxTechnologyLevel}')
```

Only selected detail card contains:

```dart
Key('mining-technology-buy-${selected.track.name}')
```

Disabled selected cards keep a 48px action surface but do not fire `onPurchase`; show `disabledReason`.

- [ ] **Step 9: Implement measured Technology landscape composition**

At landscape:

```dart
const canonicalPanelWidth = 528.0;
final panelWidth = math.min(canonicalPanelWidth, constraints.maxWidth);
```

Right-align a full-height panel keyed `mining-technology-panel-landscape`. Render three horizontal tracks with 48×48 `MiningHex` nodes and one selected detail/action area.

Do not change Site Deck for the left side.

- [ ] **Step 10: Present Technology with `showGeneralDialog`**

Replace only the Technology `showModalBottomSheet` call in `MiningShell`:

```dart
unawaited(
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close technology',
    barrierColor: const Color.fromRGBO(0, 0, 0, .18),
    transitionDuration: _reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => TechnologySheet(
      view: TechnologySheetView.from(
        state: _displayState,
        content: _content,
      ),
      onPurchase: _purchaseTechnology,
    ),
  ),
);
```

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

Stop casting `mining-music-switch` to `SwitchListTile`. With preferences `musicEnabled=true`, `musicVolume=.70`, assert:

```dart
expect(find.text('AUDIO'), findsOneWidget);
expect(find.text('Music'), findsOneWidget);
expect(find.text('Cavern ambience'), findsOneWidget);
expect(find.text('70%'), findsOneWidget);
expect(find.text('20 steps'), findsOneWidget);
expect(find.text('ACCESSIBILITY'), findsOneWidget);
expect(find.text('Reduced motion'), findsOneWidget);
expect(find.text('SYSTEM'), findsOneWidget);
```

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

- [ ] **Step 2: Add failing Settings dense-layout tests**

At `360×640` / 1.3:

```dart
for (final finder in [
  find.byKey(const Key('mining-music-switch')),
  find.byKey(const Key('mining-volume-slider')),
  find.text('SYSTEM'),
]) {
  await tester.ensureVisible(finder);
}
expect(tester.takeException(), isNull);
```

At `874×402` / 1.3, assert `mining-settings-panel-landscape`, ensure Volume and SYSTEM are visible/reachable, and `tester.takeException()` is null.

- [ ] **Step 3: Run Settings tests to verify failure**

```bash
flutter test test/mining/presentation/mining_settings_sheet_test.dart
```

- [ ] **Step 4: Rebuild Settings with `MiningModalChrome`**

Use transparent full-screen `Material` + `LayoutBuilder`.

Portrait panel:

```dart
final panelTop = math.min(392.0, constraints.maxHeight * .45);
```

Use `SingleChildScrollView` inside the panel. Build Audio card and Accessibility card directly in `mining_settings_sheet.dart`; no generic card/toggle framework.

Use `IBMPlexMono` for secondary/status text and percentage metadata.

- [ ] **Step 5: Implement inline Music pill with `MiningHex`**

Keep key `mining-music-switch`, 48px height, `Semantics(toggled: ...)`, and `InkWell`. Use `AnimatedAlign` with duration zero when `MediaQuery.disableAnimations` is true. Thumb is a small `MiningHex` widget.

- [ ] **Step 6: Keep real Slider and add local `SliderComponentShape`**

Create `_HexSliderThumbShape extends SliderComponentShape` in `mining_settings_sheet.dart`. Its `paint` method draws a six-point thumb path centered at the supplied Slider center using `sliderTheme.thumbColor` / `MiningTheme.highlight` and `MiningTheme.accent` border.

Use:

```dart
SliderTheme(
  data: SliderTheme.of(context).copyWith(
    trackHeight: 10,
    activeTrackColor: MiningTheme.highlight,
    inactiveTrackColor: Colors.white.withAlpha(26),
    overlayColor: MiningTheme.highlight.withAlpha(31),
    thumbColor: MiningTheme.highlight,
    thumbShape: const _HexSliderThumbShape(),
  ),
  child: Slider(
    key: const Key('mining-volume-slider'),
    value: audioManager.musicVolume,
    min: 0,
    max: 1,
    divisions: 20,
    onChanged: audioManager.musicEnabled
        ? (value) {
            unawaited(audioManager.setMusicVolume(value));
            setState(() {});
          }
        : null,
  ),
)
```

Do not hide the stock thumb and overlay a second `Positioned` hex.

- [ ] **Step 7: Keep Settings landscape functional only**

Use the same cards in a bounded right-side `SingleChildScrollView`, keyed `mining-settings-panel-landscape`. There is no Settings landscape pixel target.

- [ ] **Step 8: Present Settings with `showGeneralDialog`**

```dart
unawaited(
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close settings',
    barrierColor: const Color.fromRGBO(0, 0, 0, .18),
    transitionDuration: _reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => MiningSettingsSheet(
      audioManager: _audioManager,
    ),
  ),
);
```

- [ ] **Step 9: Update shell Settings regression**

Assert root key, visible `75%`, manager values, toggle mutation, and absence of a `BottomSheet`. Do not assert `SwitchListTile` class.

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

Pass `cash` and `logisticsLevel` to every test constructor. Keep existing multi-planet/resource/silhouette/full-site coverage.

Add:

```dart
expect(find.byKey(const Key('offline-return-portrait')), findsOneWidget);
expect(find.byKey(const Key('mining-cash-chip')), findsOneWidget);
expect(find.text('FLEET RETURNED'), findsOneWidget);
```

Capped fixture:

```dart
expect(find.text('Capped at 12h — Logistics LV 2'), findsOneWidget);
```

Uncapped fixture has no `Capped at` text.

Landscape at `874×402`:

```dart
final panel = find.byKey(const Key('offline-return-summary-landscape'));
expect(tester.getSize(panel).width, 470);
```

Keep/add Continue reachability at `360×640` and `430×932` with text scale `1.3`.

- [ ] **Step 2: Run Offline tests to verify failure**

```bash
flutter test test/mining/presentation/offline_return_sheet_test.dart
```

- [ ] **Step 3: Convert `OfflineReturnSheet` to stateful pulse ownership**

Constructor:

```dart
OfflineReturnSheet({
  required OfflineProductionSummary summary,
  required MiningContentRegistry content,
  required int cash,
  required int logisticsLevel,
})
```

Use `SingleTickerProviderStateMixin`. Follow `MainMenu.didChangeDependencies()` locally: own one pulse `AnimationController`, stop/value=1 when `MediaQuery.disableAnimations` is true, repeat(reverse: true) when false, dispose it. Animate only the FLEET RETURNED status dot.

- [ ] **Step 4: Extend the existing duration formatter**

Use one formatter with `compact` option:

```dart
String _formatDuration(Duration duration, {bool compact = false}) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (compact) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}
```

Cap text:

```dart
'Capped at ${_formatDuration(summary.elapsedUsed, compact: true)} '
'— Logistics LV $logisticsLevel'
```

Do not call `content.offlineCapFor()` in the widget.

- [ ] **Step 5: Implement portrait full-screen result**

Root uses `PopScope(canPop: false)` + full-screen Material. Portrait key `offline-return-portrait`.

Composition: hero + gradient, `MiningCashChip`, FLEET RETURNED chip, elapsed/cap text, data-driven production sections, catalog silhouettes, full-site warnings, one `CONTINUE MINING` button keyed `offline-return-dismiss`.

Use scrolling so real multi-planet production and 1.3 text scale remain reachable.

- [ ] **Step 6: Implement 470px Offline landscape panel**

Landscape key `offline-return-landscape`. Right-side summary panel key `offline-return-summary-landscape` with canonical width 470px. Keep return/hero info left; production + Continue stay in right scroll flow.

- [ ] **Step 7: Make Continue the only dismissal path**

`PopScope(canPop: false)`, shell route `barrierDismissible: false`, and button:

```dart
onPressed: () => Navigator.of(context).pop()
```

- [ ] **Step 8: Promote shell Offline Return to `showGeneralDialog`**

```dart
Future<void> _showOfflineReturn(OfflineProductionSummary summary) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Offline mining return',
    barrierColor: Colors.black,
    transitionDuration: _reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => OfflineReturnSheet(
      summary: summary,
      content: _content,
      cash: _displayState.cash,
      logisticsLevel: _displayState.technology.logistics,
    ),
  );
}
```

Do not alter resume/accrual timing.

- [ ] **Step 9: Extend shell resume regression**

Assert Offline root/portrait keys, no `BottomSheet`, production text, controller state preserved, then tap `offline-return-dismiss` and confirm route closes.

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

Use one loader per family and add both files:

```dart
final mono = FontLoader('IBMPlexMono');
mono.addFont(
  File('assets/fonts/IBMPlexMono-Regular.ttf')
      .readAsBytes()
      .then(ByteData.sublistView),
);
mono.addFont(
  File('assets/fonts/IBMPlexMono-SemiBold.ttf')
      .readAsBytes()
      .then(ByteData.sublistView),
);
await mono.load();
```

Keep existing Orbitron loading. Do not load Regular only.

- [ ] **Step 2: Add deterministic parity fixtures**

Use the same Technology parity state as Task 1 and this test-only Offline summary:

```dart
const _hpa438OfflineSummary = OfflineProductionSummary(
  elapsedUsed: Duration(hours: 16),
  produced: {
    ResourceType.gold: 742.5,
    ResourceType.coal: 318.0,
    ResourceType.stone: 96.4,
  },
  productionByPlanet: {
    MiningPlanetId.homeworld: {
      ResourceType.gold: 742.5,
      ResourceType.coal: 318.0,
      ResourceType.stone: 96.4,
    },
  },
  fullSites: {MiningSiteId.landingBasin},
  wasOfflineCapped: true,
);
```

- [ ] **Step 3: Reuse actual Site Deck as Technology/Settings backdrop**

Extend the existing golden harness using a deterministic `SiteDeckScreen` with `cash: 1840`, non-empty cargo, and existing view factories. Stack the overlay above it. Do not create or modify a separate landscape Site Deck reference implementation.

- [ ] **Step 4: Add exactly five full-screen canonical goldens**

```text
hpa438_technology_402x874.png
hpa438_technology_874x402.png
hpa438_settings_402x874.png
hpa438_offline_return_402x874.png
hpa438_offline_return_874x402.png
```

Use current `skip: kIsWeb || Platform.isMacOS` policy.

Technology landscape full-screen golden is a composition smoke test; the left-side Site Deck is not parity-scored.

- [ ] **Step 5: Generate/verify goldens on Linux**

```bash
flutter test --update-goldens test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
file test/mining/presentation/goldens/hpa438_*.png
```

- [ ] **Step 6: Export five source mock frames**

Capture exact `data-screen-label` frames: Technology sheet, Technology landscape, Settings sheet, Offline return, Offline return landscape. Save them to the evidence paths listed under File Structure. Do not commit the HTML bundle.

- [ ] **Step 7: Write evidence with explicit landscape scoring**

`docs/superpowers/evidence/hpa-438/parity.md` must state:

```markdown
| Surface | Scored scope |
| --- | --- |
| Technology 402×874 | Full Technology sheet + visible HUD context |
| Technology 874×402 | Rightmost **528 px Technology panel only**; left-side current Site Deck is smoke-test context/out of scope |
| Settings 402×874 | Full Settings sheet + visible HUD context |
| Offline Return 402×874 | Full screen |
| Offline Return 874×402 | Full screen |
```

Include the mock/Flutter images and checklist for 528px Technology panel, 470px Offline panel, node hierarchy, Settings hierarchy, Offline hierarchy, IBM Plex Regular/SemiBold, 1.3 reachability, and no Site Deck changes.

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

Check every row in `docs/superpowers/evidence/hpa-438/parity.md`. For Technology landscape, score only the rightmost 528px panel. Do not expand scope to fix the current left-side Site Deck.

- [ ] **Step 6: Update PR #24 and Linear after green gates**

PR body records: five canonical states, 528/470 measured widths, 360×640 + 1.3 Technology/Settings coverage, exact verification results, no-domain-drift output, and evidence path.

Move HPA-438 to `In Review` and mark PR #24 ready only after those results are recorded.

---

## Review-Resolved Decisions

- Technology landscape width is **528 px**, verified from the mock. The old design's 470px value was wrong; 470px applies to Offline Return landscape.
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