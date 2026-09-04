# HPA-438 Mining Secondary-Surface UI Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revamp the existing mining Technology, Settings, and Offline Return surfaces to match the five canonical states in the supplied `Horologium Merge Mining (standalone).html` mock without changing mining rules, persistence, economy, or ownership boundaries.

**Architecture:** Keep `MiningShell` as the runtime owner and keep the existing `TechnologySheetView`, `AudioManager`, and `OfflineProductionSummary` contracts authoritative. Technology and Settings become full-screen transparent modal overlays whose internal panels position themselves as the mock requires; Offline Return becomes a non-dismissible full-screen modal result. Reuse `MiningTheme`, `MiningHex`, HUD primitives, catalog assets, and the existing golden harness; add only one small shared modal-chrome widget and one locally scoped secondary font family.

**Tech Stack:** Flutter / Dart, Material widgets, `showGeneralDialog`, existing Horologium mining presentation primitives, `flutter_test`, SharedPreferences test doubles, golden tests.

**Spec:** `docs/superpowers/specs/2026-09-03-hpa-438-mining-secondary-surface-ui-parity-design.md`

## Global Constraints

- All HPA-438 work stays on `jack65786656/hpa-438-revamp-technology-settings-and-offline-return-for-mining-ui` and PR #24. Do not create another implementation PR.
- The supplied `Horologium Merge Mining (standalone).html` is authoritative for visual hierarchy, geometry, typography intent, and the five canonical states; live repository data remains authoritative for values and behavior.
- Canonical states are exactly: Technology `402×874`, Technology `874×402`, Settings `402×874`, Offline Return `402×874`, Offline Return `874×402`.
- Do not modify `MiningController`, `MiningSimulation`, `MiningSave`, `MiningSaveRepository`, `MiningContentRegistry`, technology costs/gates/effects, offline accrual rules, audio preference keys, or save schema.
- Do not redesign Site Deck, Mine Site, or Stellar Map.
- Do not add Provider, Riverpod, Bloc, routing packages, a generic modal manager, a design-system package, persisted UI selection, reward-claim state, retention mechanics, or an asset-generation pipeline.
- Keep `TechnologySheet(view:, onPurchase:)` as the technology render/action boundary.
- Keep `MiningSettingsSheet(audioManager:)` as the settings boundary.
- Keep `OfflineProductionSummary` unchanged. Pass only presentation values already available from `MiningShell` when Offline Return visibly needs them.
- Interactive controls are at least `48×48` logical pixels and retain semantic labels/state.
- Critical actions must remain reachable at `360×640`, `430×932`, `874×402`, and text scale `1.3`.
- `MediaQuery.disableAnimations` remains the reduced-motion source.
- Keep Orbitron as the display font. Add IBM Plex Mono Regular (`400`) and SemiBold (`600`) only for the small status/metadata copy used by these three surfaces.
- Missing optional artwork must degrade to existing Material-icon/colored-surface fallbacks and must never hide the primary action.

---

## File Structure

### Create

- `lib/mining/presentation/mining_modal_chrome.dart`
  - One shared Technology/Settings panel shell: fill, cyan edge, rounded top corners, drag handle, safe-area padding, optional protruding `MiningHex` controls.
  - No state, navigation, business actions, or layout-specific content.
- `assets/fonts/IBMPlexMono-Regular.ttf`
- `assets/fonts/IBMPlexMono-SemiBold.ttf`
- `assets/fonts/IBMPlexMono-OFL.txt`
- `docs/superpowers/evidence/hpa-438/parity.md`
  - Final side-by-side source-reference versus Flutter-golden review table.
- `docs/superpowers/evidence/hpa-438/reference/technology-402x874.png`
- `docs/superpowers/evidence/hpa-438/reference/technology-874x402.png`
- `docs/superpowers/evidence/hpa-438/reference/settings-402x874.png`
- `docs/superpowers/evidence/hpa-438/reference/offline-return-402x874.png`
- `docs/superpowers/evidence/hpa-438/reference/offline-return-874x402.png`

### Modify

- `pubspec.yaml`
  - Register IBM Plex Mono weights `400` and `600`.
- `lib/mining/presentation/technology_sheet.dart`
  - Local selected-track state, node-state projection, portrait three-column tree, landscape horizontal tracks, detail/purchase card.
- `lib/mining/presentation/mining_settings_sheet.dart`
  - Audio and Accessibility parity cards, custom Music toggle, styled 20-step slider, responsive panel.
- `lib/mining/presentation/offline_return_sheet.dart`
  - Full-screen responsive hero/result, production cards, cap/full-storage copy, Continue action, reduced-motion-aware return status pulse.
- `lib/mining/presentation/mining_shell.dart`
  - Present Technology and Settings through transparent built-in dialog routes and Offline Return through a non-dismissible full-screen route; keep controller/audio ownership unchanged.
- `test/mining/presentation/technology_sheet_test.dart`
- `test/mining/presentation/mining_settings_sheet_test.dart`
- `test/mining/presentation/offline_return_sheet_test.dart`
- `test/mining/presentation/mining_shell_test.dart`
- `test/mining/presentation/visual_parity_golden_test.dart`
- `test/mining/presentation/goldens/hpa438_technology_402x874.png`
- `test/mining/presentation/goldens/hpa438_technology_874x402.png`
- `test/mining/presentation/goldens/hpa438_settings_402x874.png`
- `test/mining/presentation/goldens/hpa438_offline_return_402x874.png`
- `test/mining/presentation/goldens/hpa438_offline_return_874x402.png`

### Must not change

- `lib/mining/mining_controller.dart`
- `lib/mining/mining_simulation.dart`
- `lib/mining/mining_state.dart`
- `lib/mining/mining_save_repository.dart`
- `lib/mining/mining_content.dart`
- `lib/mining/mining_progression_views.dart`
- `lib/mining/fleet_dock_view.dart`
- `lib/mining/site_deck_view.dart`
- `lib/mining/mine_site_view.dart`

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
- Consumes: existing `TechnologySheetView`, `TechnologyTrackView`, `TechnologyTrack`, `MiningHex`, `MiningTheme`, `MiningVisuals`.
- Produces: `MiningModalChrome`, unchanged public `TechnologySheet(view:, onPurchase:)`, stable technology node/panel keys, and `MiningShell.openTechnology()` backed by a transparent `showGeneralDialog<void>` route.
- No domain/view-model signature changes.

- [ ] **Step 1: Replace row-oriented Technology expectations with failing tree-state tests**

In `test/mining/presentation/technology_sheet_test.dart`, keep the current public fixture shape but make the canonical test fixture exercise all four node states:

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

Add expectations for these stable keys/semantics:

```dart
expect(find.byKey(const Key('mining-technology-panel-portrait')), findsOneWidget);
expect(find.byKey(const Key('mining-technology-node-extraction-1')), findsOneWidget);
expect(find.byKey(const Key('mining-technology-node-extraction-3')), findsOneWidget);
expect(find.byKey(const Key('mining-technology-node-logistics-4')), findsOneWidget);
expect(find.byKey(const Key('mining-technology-node-surveying-5')), findsOneWidget);
expect(find.bySemanticsLabel('Extraction level 1 owned'), findsOneWidget);
expect(find.bySemanticsLabel('Extraction level 3 actionable'), findsOneWidget);
expect(find.bySemanticsLabel('Logistics level 4 blocked'), findsOneWidget);
expect(find.bySemanticsLabel('Extraction level 5 future'), findsOneWidget);
```

Add a local-selection test:

```dart
expect(find.byKey(const Key('mining-technology-detail-extraction')), findsOneWidget);
await tester.tap(find.byKey(const Key('mining-technology-node-logistics-4')));
await tester.pump();
expect(find.byKey(const Key('mining-technology-detail-logistics')), findsOneWidget);
expect(find.text('Commission the Frozen Basin site first.'), findsOneWidget);
```

Add a landscape composition test at `Size(874, 402)`:

```dart
expect(find.byKey(const Key('mining-technology-panel-landscape')), findsOneWidget);
expect(find.byKey(const Key('mining-technology-panel-portrait')), findsNothing);
```

Keep the existing purchase callback test, but target the new detail action with the existing key `mining-technology-buy-${track.name}`.

- [ ] **Step 2: Run the focused Technology tests and verify the old list implementation fails**

Run:

```bash
flutter test test/mining/presentation/technology_sheet_test.dart
```

Expected: FAIL because portrait/landscape panel keys, node keys/semantics, and local selection do not exist yet.

- [ ] **Step 3: Vendor IBM Plex Mono and register only the two required weights**

Copy the SIL Open Font License and the Regular/SemiBold TTFs from the official IBM Plex distribution into:

```text
assets/fonts/IBMPlexMono-Regular.ttf
assets/fonts/IBMPlexMono-SemiBold.ttf
assets/fonts/IBMPlexMono-OFL.txt
```

Append this second family to the existing `fonts:` section in `pubspec.yaml`; keep Orbitron unchanged:

```yaml
    - family: IBMPlexMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexMono-SemiBold.ttf
          weight: 600
```

Then run:

```bash
flutter pub get
```

Expected: dependency resolution succeeds without adding a package dependency.

- [ ] **Step 4: Create the small shared `MiningModalChrome` primitive**

Create `lib/mining/presentation/mining_modal_chrome.dart` with a deliberately narrow API:

```dart
import 'package:flutter/material.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';

class MiningModalChrome extends StatelessWidget {
  const MiningModalChrome({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(14, 26, 14, 20),
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
  });

  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xF70E1828),
            border: const Border(
              top: BorderSide(color: Color.fromRGBO(83, 212, 232, .4)),
            ),
            borderRadius: borderRadius,
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, .55),
                blurRadius: 44,
                offset: Offset(0, -18),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 11,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.fromRGBO(83, 212, 232, .7),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              child: SizedBox(width: 42, height: 4),
            ),
          ),
        ),
        if (leading != null) Positioned(left: 26, top: -31, child: leading!),
        if (trailing != null) Positioned(right: 14, top: -31, child: trailing!),
      ],
    );
  }
}
```

Do not add modal routing, scroll policy, actions, titles, or business-state helpers to this file.

- [ ] **Step 5: Convert `TechnologySheet` to local state and add one node-state projection**

Keep the public constructor unchanged and convert the widget to `StatefulWidget` only for transient selected-track state.

Use exactly one private presentation enum:

```dart
enum _TechnologyNodeState { owned, actionable, blocked, future }
```

Use this mapping; do not duplicate eligibility rules:

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

Select the initial track with this deterministic priority:

```dart
TechnologyTrack _initialTrack(TechnologySheetView view) {
  for (final track in view.tracks) {
    if (track.canPurchase) return track.track;
  }
  for (final track in view.tracks) {
    if (!track.isMaxLevel) return track.track;
  }
  return view.tracks.first.track;
}
```

A node may update local selection only when it is the next actionable/blocked node. Owned/future nodes remain informational.

- [ ] **Step 6: Implement the portrait three-column tree without introducing a tree framework**

At the root of `TechnologySheet`, use full-screen `LayoutBuilder` geometry rather than the old constrained bottom-sheet body:

```dart
return Material(
  key: const Key('mining-technology-sheet'),
  type: MaterialType.transparency,
  child: LayoutBuilder(
    builder: (context, constraints) {
      final landscape = constraints.maxWidth > constraints.maxHeight;
      return landscape
          ? _buildLandscape(context, constraints)
          : _buildPortrait(context, constraints);
    },
  ),
);
```

For portrait, match the source geometry at `402×874` while shrinking safely on shorter phones:

```dart
final panelTop = math.min(190.0, constraints.maxHeight * .24);
```

Render:

- `Align(alignment: Alignment.bottomCenter)` / `Positioned(top: panelTop, left: 0, right: 0, bottom: 0)`;
- `MiningModalChrome`;
- protruding technology `MiningHex` at the left and close `MiningHex` at the right;
- `Technology` + `MAX LV 5` header;
- three `Expanded` track columns;
- level order `5, 4, 3, 2, 1`;
- 52×58 normal nodes and 58×65 actionable nodes at the canonical size;
- simple 2px `Container` connector lines between nodes;
- one horizontal connector + compact common root beneath the three columns;
- one selected-track detail card beneath the tree.

Use these node styles:

```text
owned      fill #53D4E8, dark level text
 actionable border/fill #FFD54A + glow, level text #FFD54A
 blocked    border #FFAB40, lock icon, dark panel interior
 future     rgba(255,255,255,.13) border/fill, muted level text
```

Every node gets:

```dart
Key('mining-technology-node-${track.track.name}-$level')
```

and a semantic label:

```dart
'${track.name} level $level ${state.name}'
```

- [ ] **Step 7: Implement the dedicated landscape horizontal-track panel**

At `874×402`, use a right-side panel width of `528` exactly; on narrower landscapes use:

```dart
final panelWidth = math.min(528.0, constraints.maxWidth * .64);
```

Render `MiningModalChrome` with left/right top radii set to zero where the panel touches top/bottom, and position it at `right: 0, top: 0, bottom: 0`.

Each track row is:

```text
icon + track label + level nodes 1 -> 5 + current/next effect summary
```

Use 44×48 normal level nodes and a 52×58 highlighted next node. Keep the same `_TechnologyNodeState` mapping and selected-track detail/purchase action.

Use key:

```dart
const Key('mining-technology-panel-landscape')
```

Portrait uses:

```dart
const Key('mining-technology-panel-portrait')
```

- [ ] **Step 8: Keep purchase behavior and close semantics explicit**

The selected detail card keeps the established action key:

```dart
Key('mining-technology-buy-${track.track.name}')
```

When `track.canPurchase` is true:

```dart
onPressed: () {
  Navigator.of(context).pop();
  widget.onPurchase(track.track);
},
```

When blocked/maxed, the action remains disabled and the existing `disabledReason` is visible. The protruding close hex always calls `Navigator.of(context).pop()` and has semantic label `Close technology`.

- [ ] **Step 9: Change `MiningShell.openTechnology()` to a transparent dialog route**

Replace only the Technology `showModalBottomSheet` call with:

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
        state: _controller.state,
        content: _content,
      ),
      onPurchase: _purchaseTechnology,
    ),
  ),
);
```

Do not create a reusable modal-route helper.

- [ ] **Step 10: Add one shell ownership regression for Technology**

In `mining_shell_test.dart`, add:

```dart
testWidgets('Technology overlay keeps the shell controller identity', (tester) async {
  await pumpShell(tester);
  final before = shellHandles(tester).controller;

  shellHandles(tester).openTechnology();
  await tester.pump(const Duration(milliseconds: 200));

  expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
  expect(shellHandles(tester).controller, same(before));

  await tester.tap(find.bySemanticsLabel('Close technology'));
  await tester.pump(const Duration(milliseconds: 200));
  expect(find.byKey(const Key('mining-technology-sheet')), findsNothing);
});
```

- [ ] **Step 11: Run focused tests, format, and commit Task 1**

Run:

```bash
dart format lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: PASS.

Commit:

```bash
git add pubspec.yaml assets/fonts/ lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_shell_test.dart
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
- Consumes: `MiningModalChrome`, existing `AudioManager.musicEnabled`, `musicVolume`, `setMusicEnabled`, `setMusicVolume`, `MediaQuery.disableAnimations` explanation.
- Produces: unchanged `MiningSettingsSheet(audioManager:)` public API, stable `mining-music-switch` and `mining-volume-slider` keys, portrait lower-sheet parity, and overflow-free landscape.

- [ ] **Step 1: Expand Settings tests before changing the widget**

Replace the current type-coupled `SwitchListTile` assertion with behavior/semantics assertions so the key remains stable while the visual control changes.

Add a helper that pumps exact sizes:

```dart
Future<AudioManager> _pumpSettings(
  WidgetTester tester, {
  required Size size,
  bool musicEnabled = true,
  double volume = .70,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  SharedPreferences.setMockInitialValues({
    'audio.musicEnabled': musicEnabled,
    'audio.musicVolume': volume,
  });
  final manager = AudioManager(
    backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
  );
  await manager.loadPrefs();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MiningSettingsSheet(audioManager: manager)),
    ),
  );
  await tester.pump();
  return manager;
}
```

Add portrait expectations:

```dart
final manager = await _pumpSettings(
  tester,
  size: const Size(402, 874),
  musicEnabled: true,
  volume: .70,
);
expect(find.byKey(const Key('mining-settings-panel-portrait')), findsOneWidget);
expect(find.text('AUDIO'), findsOneWidget);
expect(find.text('Cavern ambience'), findsOneWidget);
expect(find.text('70%'), findsOneWidget);
expect(find.text('20 steps'), findsOneWidget);
expect(find.text('ACCESSIBILITY'), findsOneWidget);
expect(find.text('SYSTEM'), findsOneWidget);
expect(manager.musicEnabled, isTrue);
```

Add interaction assertions:

```dart
await tester.tap(find.byKey(const Key('mining-music-switch')));
await tester.pump();
expect(manager.musicEnabled, isFalse);
```

Keep `mining-volume-slider` as an actual `Slider` so its value/divisions remain directly testable:

```dart
final slider = tester.widget<Slider>(
  find.byKey(const Key('mining-volume-slider')),
);
expect(slider.value, .70);
expect(slider.divisions, 20);
```

Add landscape overflow coverage at `874×402`:

```dart
expect(find.byKey(const Key('mining-settings-panel-landscape')), findsOneWidget);
expect(tester.takeException(), isNull);
await tester.ensureVisible(find.text('SYSTEM'));
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Run Settings tests and verify they fail against the stock controls**

Run:

```bash
flutter test test/mining/presentation/mining_settings_sheet_test.dart
```

Expected: FAIL because new parity copy/panel keys do not exist and the current widget is a `SwitchListTile` + unstyled `Slider`.

- [ ] **Step 3: Rebuild Settings around `MiningModalChrome` while keeping `AudioManager` ownership**

At the root use a full-screen transparent `Material` + `LayoutBuilder`, matching Technology's presentation boundary but not sharing state/routing.

Portrait panel placement:

```dart
final panelTop = math.min(392.0, constraints.maxHeight * .45);
```

Landscape stays the same card stack in a bounded bottom sheet rather than inventing a second design:

```dart
final width = math.min(520.0, constraints.maxWidth - 24);
final height = constraints.maxHeight * .92;
```

Use keys:

```text
mining-settings-sheet
mining-settings-panel-portrait
mining-settings-panel-landscape
```

Portrait content is exactly two cards:

```text
Settings
  AUDIO
    Music
    Cavern ambience
    ON/OFF toggle
    divider
    Volume                     70%
    20-step slider
    0         20 steps        100
  ACCESSIBILITY
    Reduced motion           SYSTEM
    Reduced motion follows system setting
```

Do not add a reduced-motion toggle.

- [ ] **Step 4: Implement the Music pill using existing hex composition, not a new control framework**

Use an `InkWell`/`Semantics` pill with the existing stable key:

```dart
Semantics(
  toggled: audioManager.musicEnabled,
  button: true,
  label: 'Music',
  child: InkWell(
    key: const Key('mining-music-switch'),
    borderRadius: BorderRadius.circular(24),
    onTap: () {
      unawaited(
        audioManager.setMusicEnabled(!audioManager.musicEnabled),
      );
      setState(() {});
    },
    child: SizedBox(
      width: 78,
      height: 48,
      child: Stack(
        children: [
          // ON/OFF text on the inactive side.
          // 32x36 MiningHex thumb aligned left/right.
        ],
      ),
    ),
  ),
)
```

Use `MiningHex` for the thumb and `AnimatedAlign` only when animations are enabled; otherwise use plain `Align`. The whole tap target remains at least 48px high.

- [ ] **Step 5: Keep a real 20-division `Slider` and apply parity styling**

Use `SliderTheme`:

```dart
SliderTheme(
  data: SliderTheme.of(context).copyWith(
    trackHeight: 10,
    activeTrackColor: MiningTheme.highlight,
    inactiveTrackColor: const Color.fromRGBO(255, 255, 255, .10),
    overlayColor: const Color.fromRGBO(24, 255, 255, .12),
    thumbColor: MiningTheme.highlight,
  ),
  child: Slider(
    key: const Key('mining-volume-slider'),
    value: audioManager.musicVolume,
    min: 0,
    max: 1,
    divisions: 20,
    onChanged: audioManager.musicEnabled
        ? (value) {
            audioManager.setMusicVolume(value);
            setState(() {});
          }
        : null,
  ),
)
```

Do not introduce a custom gesture/slider implementation. Keep Material slider keyboard/semantics behavior; the mock's hex language comes from the surrounding panel/toggle and later parity tuning, not from replacing Slider mechanics.

- [ ] **Step 6: Change `MiningShell.openSettings()` to the same transparent built-in route style**

Replace only the Settings bottom-sheet route with:

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

Keep the existing `maybeStartBgm()` call before opening.

- [ ] **Step 7: Update the shell Settings regression to assert state, not widget class**

Replace the `SwitchListTile` lookup in `mining_shell_test.dart` with:

```dart
shellHandles(tester).openSettings();
await tester.pump(const Duration(milliseconds: 200));

expect(find.byKey(const Key('mining-settings-sheet')), findsOneWidget);
expect(find.text('75%'), findsOneWidget);
expect(audioManager.musicEnabled, isFalse);
expect(audioManager.musicVolume, .75);

await tester.tap(find.byKey(const Key('mining-music-switch')));
await tester.pump();
expect(audioManager.musicEnabled, isTrue);
```

- [ ] **Step 8: Run focused tests, format, and commit Task 2**

Run:

```bash
dart format lib/mining/presentation/mining_settings_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/mining_settings_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/mining/presentation/mining_settings_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/mining_settings_sheet_test.dart test/mining/presentation/mining_shell_test.dart
git commit -m "feat: revamp mining settings overlay"
```

---

### Task 3: Full-Screen Offline Return Portrait and Landscape

**Files:**
- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/mining/presentation/mining_shell.dart`
- Test: `test/mining/presentation/offline_return_sheet_test.dart`
- Test: `test/mining/presentation/mining_shell_test.dart`

**Interfaces:**
- Consumes: unchanged `OfflineProductionSummary`, `MiningContentRegistry`, `MiningPlanetDefinition.planetAsset`, `MiningVisuals.offlineHero`, `MiningCashChip`, current `MiningSave.cash`, current `TechnologyLevels.logistics`.
- Produces: `OfflineReturnSheet(summary:, content:, cash:, logisticsLevel:)`, same root/dismiss keys, portrait/landscape responsive compositions, non-dismissible full-screen presentation from `MiningShell`.
- Does not modify `OfflineProductionSummary` or any saved/domain data.

- [ ] **Step 1: Update Offline Return tests for the new presentation inputs and copy**

Update every construction site in `offline_return_sheet_test.dart` to pass explicit presentation scalars:

```dart
OfflineReturnSheet(
  summary: summary,
  content: content,
  cash: 1840,
  logisticsLevel: 2,
)
```

Keep the existing multi-planet fixture. Add these assertions:

```dart
expect(find.text('FLEET RETURNED'), findsOneWidget);
expect(find.textContaining('Mining ran'), findsOneWidget);
expect(find.text('3 SITES'), findsWidgets);
expect(find.text('CONTINUE MINING'), findsOneWidget);
```

For the existing Logistics-2 capped fixture, change the expected presentation copy to:

```dart
expect(find.text('Capped at 12h — Logistics LV 2'), findsOneWidget);
```

Keep catalog-resolved full-site assertions, but use the new warning wording:

```dart
expect(find.text('Storage full: Granite Crater — it stopped early'), findsOneWidget);
```

Add canonical composition tests:

```dart
expect(find.byKey(const Key('offline-return-portrait')), findsOneWidget);
```

at `402×874`, and:

```dart
expect(find.byKey(const Key('offline-return-landscape')), findsOneWidget);
```

at `874×402`.

Keep the `430×932` text-scale `1.3` action reachability test and add:

```dart
await tester.ensureVisible(find.byKey(const Key('offline-return-dismiss')));
expect(tester.getSize(find.byKey(const Key('offline-return-dismiss'))).height, greaterThanOrEqualTo(48));
```

- [ ] **Step 2: Run Offline Return tests and verify failure**

Run:

```bash
flutter test test/mining/presentation/offline_return_sheet_test.dart
```

Expected: FAIL because the constructor, full-screen keys, source-style copy, and responsive compositions do not exist yet.

- [ ] **Step 3: Extend the constructor with only the two required live presentation scalars**

Keep the class/file name and summary/catalog fields. Add:

```dart
class OfflineReturnSheet extends StatefulWidget {
  const OfflineReturnSheet({
    super.key,
    required this.summary,
    required this.content,
    required this.cash,
    required this.logisticsLevel,
  });

  final OfflineProductionSummary summary;
  final MiningContentRegistry content;
  final int cash;
  final int logisticsLevel;
}
```

The widget becomes stateful only to own the small return-status pulse. Do not add claim/dismiss state.

- [ ] **Step 4: Add a reduced-motion-aware status pulse with no external state**

Use one private `AnimationController` in `OfflineReturnSheetState`:

```dart
late final AnimationController _pulse;

@override
void initState() {
  super.initState();
  _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
    lowerBound: .45,
    upperBound: 1,
  );
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (MediaQuery.of(context).disableAnimations) {
    _pulse.stop();
    _pulse.value = 1;
  } else if (!_pulse.isAnimating) {
    _pulse.repeat(reverse: true);
  }
}
```

Use `SingleTickerProviderStateMixin`, dispose the controller, and drive only the small cyan status dot's opacity. Do not animate hero/cards/actions.

- [ ] **Step 5: Implement the portrait full-screen composition as a scroll-safe `Stack`**

Root:

```dart
return Material(
  key: const Key('offline-return-sheet'),
  color: const Color(0xFF060A10),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final landscape = constraints.maxWidth > constraints.maxHeight;
      return landscape
          ? _buildLandscape(context, constraints)
          : _buildPortrait(context, constraints);
    },
  ),
);
```

Portrait uses key `offline-return-portrait` and this structure:

```text
Stack
  hero image top ~400px, BoxFit.cover
  vertical dark gradient over hero
  SafeArea
    SingleChildScrollView
      ConstrainedBox(minHeight: viewport height - safe area)
        Column
          cash chip top-left
          spacer to return message (~250px canonical top)
          FLEET RETURNED chip
          Mining ran / elapsed
          optional cap row
          spacer
          one production card per producing planet
          next-action row
          CONTINUE MINING + play hex
```

Use `MiningCashChip(cash: widget.cash)` rather than rebuilding the cash shard.

Use existing catalog data for each production card:

```dart
final planet = widget.content.planet(planetId);
final siteCount = planet.sites.length;
final planetAsset = planet.planetAsset;
```

Use the existing resource silhouette map for resource icon/name/color.

For each `fullSites` entry belonging to that planet, render:

```text
Storage full: <site name> — it stopped early
```

The source mock's `+742.5`, `+318.0`, and `+96.4` remain test/reference fixture values only.

- [ ] **Step 6: Implement the dedicated `874×402` split composition**

Landscape uses key `offline-return-landscape`.

Match the source geometry:

```dart
final summaryWidth = math.min(470.0, constraints.maxWidth * .54);
```

Structure:

```text
Stack
  full-screen hero, BoxFit.cover, left-biased alignment
  horizontal dark gradient
  MiningCashChip at left/top
  bottom-left result block
  right-side panel width 470 canonical
    scrollable planet production cards/warnings
    Spacer/minimum gap
    CONTINUE MINING + play hex
```

Keep Continue inside the right-side scroll/flow so text scaling or multiple planets cannot place it underneath system insets.

- [ ] **Step 7: Use concise source-style duration/cap formatting only in presentation**

Keep the existing duration formatter for the main elapsed value, but use a compact cap formatter:

```dart
String _formatCap(Duration duration) {
  if (duration.inMinutes.remainder(60) == 0) {
    return '${duration.inHours}h';
  }
  return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
}
```

Render cap copy only when `summary.wasOfflineCapped`:

```dart
'Capped at ${_formatCap(summary.elapsedUsed)} — Logistics LV ${widget.logisticsLevel}'
```

Do not call `content.offlineCapFor()` from the widget; the summary already tells the UI the actual elapsed cap used.

- [ ] **Step 8: Promote `_showOfflineReturn()` in `MiningShell` to a non-dismissible full-screen route**

Replace only Offline Return's `showModalBottomSheet` call:

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

Do not alter initialize/resume timing, pending-summary ownership, checkpoint behavior, or controller accrual.

- [ ] **Step 9: Strengthen the lifecycle shell test to prove the route changed without changing ownership**

Extend the existing pause/resume test:

```dart
expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
expect(find.byKey(const Key('offline-return-portrait')), findsOneWidget);
expect(find.byType(BottomSheet), findsNothing);
expect(shellHandles(tester).controller.state.cash, greaterThanOrEqualTo(100));
```

Then dismiss through the real action:

```dart
await tester.tap(find.byKey(const Key('offline-return-dismiss')));
await tester.pump(const Duration(milliseconds: 200));
expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
```

- [ ] **Step 10: Run focused tests, format, and commit Task 3**

Run:

```bash
dart format lib/mining/presentation/offline_return_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/offline_return_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/mining/presentation/offline_return_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/offline_return_sheet_test.dart test/mining/presentation/mining_shell_test.dart
git commit -m "feat: revamp offline mining return"
```

---

### Task 4: Canonical Golden Tests and Source-Reference Evidence

**Files:**
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Create/Update: `test/mining/presentation/goldens/hpa438_*.png`
- Create: `docs/superpowers/evidence/hpa-438/reference/*.png`
- Create: `docs/superpowers/evidence/hpa-438/parity.md`

**Interfaces:**
- Consumes: finished Technology/Settings/Offline widgets, existing `SiteDeckScreen`/HUD primitives for backdrop composition, supplied mock's five `data-screen-label` states.
- Produces: deterministic goldens for all five canonical states and a committed review document showing source reference beside Flutter output.
- Does not add a new visual-test framework or runtime dependency.

- [ ] **Step 1: Extend the golden font loader for IBM Plex Mono**

Refactor the current `setUpAll` into one helper:

```dart
Future<void> _loadFont(String family, String path) async {
  if (kIsWeb) return;
  final file = File(path);
  if (!file.existsSync()) return;
  final loader = FontLoader(family);
  loader.addFont(file.readAsBytes().then(ByteData.sublistView));
  await loader.load();
}
```

Then:

```dart
setUpAll(() async {
  await _loadFont('Orbitron', 'assets/fonts/Orbitron-Variable.ttf');
  await _loadFont('IBMPlexMono', 'assets/fonts/IBMPlexMono-Regular.ttf');
});
```

The application's declared family handles weight selection; loading Regular is sufficient for deterministic test fallback metrics.

- [ ] **Step 2: Add deterministic HPA-438 fixtures without production constants**

Add a technology fixture matching the source visual-state pattern:

```dart
const _hpa438TechnologyView = TechnologySheetView(
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

Add an Offline Return fixture whose sample numbers intentionally mirror the mock only for visual comparison:

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

These values remain only in `visual_parity_golden_test.dart`.

- [ ] **Step 3: Build a real Site Deck backdrop wrapper for Technology and Settings goldens**

Do not use a colored placeholder. Reuse existing `SiteDeckScreen` from a deterministic `MiningSave` so the visible HUD/art behind the overlays is real gameplay UI.

Create a helper:

```dart
Widget _withSiteDeckBackdrop({
  required MiningSave state,
  required Widget overlay,
}) {
  final view = SiteDeckView.from(
    state: state,
    content: _content,
    isBusy: false,
  );
  final dock = FleetDockView.from(
    state: state,
    content: _content,
    selectedBayId: null,
    isBusy: false,
  );
  return Stack(
    fit: StackFit.expand,
    children: [
      SiteDeckScreen(
        cash: state.cash,
        view: view,
        fleetDock: dock,
        onEnterSite: (_) {},
        onUnlockSite: (_) {},
        onBayTap: (_) {},
        onSpawnRig: () {},
        onDestinationSelected: (_) {},
      ),
      overlay,
    ],
  );
}
```

Create a parity state with `cash: 1840`, enough deployed/cargo state to show a non-empty cargo gauge, and technology matching `_hpa438TechnologyView` where possible. This state exists only in the test.

- [ ] **Step 4: Add exactly five golden tests**

Add:

```text
hpa438_technology_402x874.png
hpa438_technology_874x402.png
hpa438_settings_402x874.png
hpa438_offline_return_402x874.png
hpa438_offline_return_874x402.png
```

Use the existing `_pumpSurface` helper and `matchesGoldenFile`.

Technology portrait/landscape:

```dart
await _pumpSurface(
  tester,
  size: size,
  child: _withSiteDeckBackdrop(
    state: state,
    overlay: TechnologySheet(
      view: _hpa438TechnologyView,
      onPurchase: (_) {},
    ),
  ),
);
```

Settings portrait:

```dart
SharedPreferences.setMockInitialValues({
  'audio.musicEnabled': true,
  'audio.musicVolume': .70,
});
final manager = AudioManager(
  backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
);
await manager.loadPrefs();
```

Then pump `_withSiteDeckBackdrop(..., overlay: MiningSettingsSheet(audioManager: manager))`.

Offline Return:

```dart
OfflineReturnSheet(
  summary: _hpa438OfflineSummary,
  content: _content,
  cash: 1840,
  logisticsLevel: 3,
)
```

Use `skip: kIsWeb || Platform.isMacOS` for the five pixel goldens, matching the repository's current platform-stability policy. Structural widget tests remain cross-platform.

- [ ] **Step 5: Generate the five implementation goldens on Linux**

Run:

```bash
flutter test --update-goldens test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: all non-skipped goldens PASS on the generation platform.

Verify dimensions:

```bash
file test/mining/presentation/goldens/hpa438_*.png
```

Expected: the filenames correspond to `402×874` or `874×402` as declared.

- [ ] **Step 6: Export the five source-reference frames from the supplied standalone mock**

Open the user-supplied `Horologium Merge Mining (standalone).html` in a browser and capture the exact elements identified by these `data-screen-label` values:

```text
Technology sheet
Settings sheet
Offline return
Technology landscape
Offline return landscape
```

Export them without browser chrome at their authored sizes:

```text
docs/superpowers/evidence/hpa-438/reference/technology-402x874.png
docs/superpowers/evidence/hpa-438/reference/settings-402x874.png
docs/superpowers/evidence/hpa-438/reference/offline-return-402x874.png
docs/superpowers/evidence/hpa-438/reference/technology-874x402.png
docs/superpowers/evidence/hpa-438/reference/offline-return-874x402.png
```

Do not commit the ~15 MB standalone HTML bundle.

- [ ] **Step 7: Write the side-by-side parity evidence document**

Create `docs/superpowers/evidence/hpa-438/parity.md`:

```markdown
# HPA-438 Visual Parity Evidence

| Surface | Mock reference | Flutter implementation |
| --- | --- | --- |
| Technology 402×874 | ![](reference/technology-402x874.png) | ![](../../../test/mining/presentation/goldens/hpa438_technology_402x874.png) |
| Technology 874×402 | ![](reference/technology-874x402.png) | ![](../../../test/mining/presentation/goldens/hpa438_technology_874x402.png) |
| Settings 402×874 | ![](reference/settings-402x874.png) | ![](../../../test/mining/presentation/goldens/hpa438_settings_402x874.png) |
| Offline Return 402×874 | ![](reference/offline-return-402x874.png) | ![](../../../test/mining/presentation/goldens/hpa438_offline_return_402x874.png) |
| Offline Return 874×402 | ![](reference/offline-return-874x402.png) | ![](../../../test/mining/presentation/goldens/hpa438_offline_return_874x402.png) |

## Review checklist

- [ ] Panel edge/top/side geometry matches.
- [ ] Cash/cargo context remains visible where the mock shows it.
- [ ] Technology node order/state hierarchy matches.
- [ ] Settings Audio/Accessibility hierarchy matches.
- [ ] Offline hero/result/summary hierarchy matches.
- [ ] Typography hierarchy and secondary mono copy match closely.
- [ ] No critical action is clipped at text scale 1.3.
```

If visual review finds geometry/style drift, tune only the presentation files already in HPA-438 and regenerate the affected golden. Do not change domain/projection values to make screenshots match.

- [ ] **Step 8: Run focused visual tests and commit Task 4**

Run:

```bash
dart format test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: PASS subject to the repository's existing platform skip policy.

Commit:

```bash
git add test/mining/presentation/visual_parity_golden_test.dart test/mining/presentation/goldens/hpa438_*.png docs/superpowers/evidence/hpa-438/
git commit -m "test: lock mining secondary surface parity"
```

---

### Task 5: Full Regression, Scope Guard, and PR Handoff

**Files:**
- Modify only if verification exposes a HPA-438 presentation/test defect: files already listed in Tasks 1–4.
- Update PR #24 body/checklist after verification.
- Update Linear HPA-438 to `In Review` only after all commands below pass.

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: green full repository checks, no domain drift, final parity evidence linked from PR #24.

- [ ] **Step 1: Run formatting and static analysis**

Run:

```bash
dart format --set-exit-if-changed lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_settings_sheet.dart lib/mining/presentation/offline_return_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_settings_sheet_test.dart test/mining/presentation/offline_return_sheet_test.dart test/mining/presentation/mining_shell_test.dart test/mining/presentation/visual_parity_golden_test.dart
flutter analyze
```

Expected: both commands exit `0`.

- [ ] **Step 2: Run the complete HPA-438 focused suite**

Run:

```bash
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run the full repository test suite**

Run:

```bash
flutter test
```

Expected: PASS with only pre-existing explicit skips.

- [ ] **Step 4: Prove the implementation did not drift into mining domain/state files**

Run:

```bash
git diff --name-only main...HEAD | grep -E '^lib/mining/(mining_controller|mining_simulation|mining_state|mining_save_repository|mining_content|mining_progression_views|fleet_dock_view|site_deck_view|mine_site_view)\.dart$' && exit 1 || true
```

Expected: no output and exit `0`.

Also run:

```bash
git diff --check
git status --short
```

Expected: `git diff --check` exits `0`; working tree is clean after intended commits.

- [ ] **Step 5: Review source-versus-golden evidence before declaring parity**

Open `docs/superpowers/evidence/hpa-438/parity.md` and inspect all five rows at 100% scale.

Reject completion if any of these materially diverge from the supplied mock:

```text
Technology portrait: lower panel begins near authored 190px position; 3 columns; 5→1 order; root; detail action.
Technology landscape: right panel near authored 528px width; 3 horizontal tracks; backdrop/navigation context remains visible.
Settings portrait: lower panel begins near authored 392px position; AUDIO and ACCESSIBILITY cards; ON pill; 20-step volume hierarchy.
Offline portrait: hero ~400px; result around authored 250px; production card around authored 434px; bottom Continue.
Offline landscape: left hero/result + right ~470px summary panel + reachable Continue.
```

Fix only presentation/layout/test fixtures, regenerate the affected golden, rerun its focused tests, and amend with a normal follow-up commit rather than rewriting history.

- [ ] **Step 6: Update PR #24 from planning-only to implementation-complete review context**

Update the PR body with:

```markdown
## Implementation status

- [x] Technology portrait + landscape parity
- [x] Settings portrait parity + responsive landscape
- [x] Offline Return portrait + landscape parity
- [x] Existing controller/simulation/save/economy contracts unchanged
- [x] Focused widget tests
- [x] Five canonical goldens
- [x] Source-vs-Flutter evidence: `docs/superpowers/evidence/hpa-438/parity.md`
- [x] `flutter analyze`
- [x] `flutter test`
```

Keep the design and implementation plan links in the PR body. Mark the draft PR ready for review only after the verification commands are green.

- [ ] **Step 7: Move Linear HPA-438 to In Review**

Set HPA-438 to `In Review` and keep PR #24 attached. Do not close the issue until the PR is merged.

- [ ] **Step 8: Final verification commit only if Task 5 changed tracked files**

If Task 5 required parity/test/documentation corrections, commit them:

```bash
git add <only-the-corrected-hpa-438-files>
git commit -m "test: finalize hpa-438 visual parity"
```

If Task 5 changed no tracked files, do not create an empty commit.

---

## Self-Review Against the Spec

### Spec coverage

- Shared visor/modal chrome: Task 1.
- Orbitron + IBM Plex Mono typography intent: Task 1.
- Technology portrait 3-column 5→1 tree, local selection, state mapping, purchase behavior: Task 1.
- Technology dedicated landscape horizontal tracks/right panel: Task 1.
- Settings Audio card, custom Music pill, 20-step Slider, Accessibility SYSTEM card: Task 2.
- Settings landscape reachability/no overflow without a new design: Task 2.
- Offline Return full-screen ownership boundary, hero/result, cap/Logistics copy, per-planet/resource summary, full-site warnings, Continue: Task 3.
- Offline Return dedicated landscape split composition: Task 3.
- Reduced motion: Tasks 1–3 plus existing shell source.
- 48×48 targets, semantics, text scale 1.3, phone/landscape sizes: focused tests in Tasks 1–3 and final regression.
- Five canonical parity states/goldens and side-by-side evidence: Task 4.
- No domain/save/economy/progression changes: Global Constraints + Task 5 scope guard.
- One branch/one PR: Global Constraints + Task 5 handoff.

### Placeholder scan

There are no `TBD`, `TODO`, unspecified “add tests,” or undefined follow-up components in this plan. The only conditional behavior is ordinary verification repair: if a golden comparison exposes presentation drift, adjust only the already-named presentation files and regenerate that golden.

### Type/signature consistency

- `TechnologySheet(view:, onPurchase:)` stays unchanged.
- `MiningSettingsSheet(audioManager:)` stays unchanged.
- `OfflineReturnSheet` adds only `cash` and `logisticsLevel`; every test and `MiningShell` call site is updated in Task 3.
- `OfflineProductionSummary` remains unchanged.
- `MiningModalChrome` is presentation-only and is consumed only by Technology/Settings.
- Stable public test handles remain `mining-technology-sheet`, `mining-music-switch`, `mining-volume-slider`, `offline-return-sheet`, and `offline-return-dismiss`.