# HPA-438 Mining Secondary-Surface UI Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revamp the existing mining Technology, Settings, and Offline Return surfaces to match the five canonical states in the supplied `Horologium Merge Mining (standalone).html` mock without changing mining rules, persistence, economy, or ownership boundaries.

**Architecture:** Keep `MiningShell` as the runtime owner and keep `TechnologySheetView`, `AudioManager`, and `OfflineProductionSummary` authoritative. Technology and Settings use transparent built-in dialogs with one tiny shared chrome widget; Offline Return uses its own non-dismissible full-screen dialog. Reuse `MiningTheme`, `MiningHex`, existing HUD/art primitives, and the current golden harness; add only IBM Plex Mono as a scoped secondary font family.

**Tech Stack:** Flutter / Dart, Material widgets, `showGeneralDialog`, existing Horologium mining presentation primitives, `flutter_test`, SharedPreferences test doubles, golden tests.

**Spec:** `docs/superpowers/specs/2026-09-03-hpa-438-mining-secondary-surface-ui-parity-design.md`

## Global Constraints

- All work stays on `jack65786656/hpa-438-revamp-technology-settings-and-offline-return-for-mining-ui` and PR #24.
- The standalone HTML mock is authoritative for the five canonical compositions; live repository data remains authoritative for values and behavior.
- Canonical states: Technology `402×874`, Technology `874×402`, Settings `402×874`, Offline Return `402×874`, Offline Return `874×402`.
- Measured mock geometry: Technology landscape panel is **528 px** wide at `874×402`; Offline Return landscape summary panel is **470 px** wide.
- Do not modify `MiningController`, `MiningSimulation`, `MiningSave`, `MiningSaveRepository`, `MiningContentRegistry`, or technology/economy/offline rules.
- Do not redesign Site Deck, Mine Site, or Stellar Map.
- Do not add Provider, Riverpod, Bloc, a routing package, modal manager, design-system package, generic toggle, new visual-test framework, persisted UI selection, or reward/retention mechanics.
- Keep `TechnologySheet(view:, onPurchase:)`, `MiningSettingsSheet(audioManager:)`, and `OfflineProductionSummary` as the existing boundaries.
- Use `MiningContentRegistry.maxTechnologyLevel`; do not introduce another literal progression contract.
- Every tappable control, including selectable Technology nodes, is at least `48×48` logical pixels.
- Critical controls remain reachable at `360×640`, `430×932`, `874×402`, and text scale `1.3`.
- `MediaQuery.disableAnimations` remains the reduced-motion source.
- Use `MiningTheme.panel`, `MiningTheme.accent`, `MiningTheme.highlight`, `MiningTheme.warning`, and `MiningTheme.gate`; do not fork equivalent raw colors for core tokens.
- Keep Orbitron as the display family. Add IBM Plex Mono Regular (`400`) and SemiBold (`600`) only for secondary/status copy.
- Missing optional art must never hide the primary action.

---

## File Structure

### Create

- `lib/mining/presentation/mining_modal_chrome.dart`
  - Shared Technology/Settings panel fill, cyan edge, handle, rounded corners, safe-area padding, optional protruding affordances.
  - No routing, business state, titles, actions, or scroll policy.
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
- Consumes: `TechnologySheetView`, `TechnologyTrackView`, `TechnologyTrack`, `MiningContentRegistry.maxTechnologyLevel`, `MiningHex`, `MiningTheme`, `MiningVisuals`.
- Produces: `MiningModalChrome`; unchanged `TechnologySheet(view:, onPurchase:)`; stable panel/node/detail/action keys; transparent Technology dialog from `MiningShell`.

- [ ] **Step 1: Replace the retiring list-UI tests with starter + parity fixtures**

Delete assertions that depend on the current row presentation, including `Extraction · Level 0`, repeated `Gate: ... commissioned` rows, three simultaneous buy controls, and `ElevatedButton` lookups for non-selected tracks.

Keep starter-state coverage with a dedicated fixture:

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

Add the four-state parity fixture:

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

Add a pump helper that accepts viewport and text scale:

```dart
Future<void> _pumpTechnology(
  WidgetTester tester, {
  required Size size,
  required TechnologySheetView view,
  TextScaler textScaler = TextScaler.noScaling,
  ValueChanged<TechnologyTrack>? onPurchase,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: TechnologySheet(
            view: view,
            onPurchase: onPurchase ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
```

- [ ] **Step 2: Add failing node-state, selection, action-size, and dense-layout tests**

Add these expectations for `_parityView()` at `402×874`:

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

Test local selection and inert blocked purchase:

```dart
final purchases = <TechnologyTrack>[];
await _pumpTechnology(
  tester,
  size: const Size(402, 874),
  view: _parityView(),
  onPurchase: purchases.add,
);

expect(find.byKey(const Key('mining-technology-detail-extraction')), findsOneWidget);
await tester.tap(find.byKey(const Key('mining-technology-node-logistics-4')));
await tester.pump();
expect(find.byKey(const Key('mining-technology-detail-logistics')), findsOneWidget);
expect(find.text('Commission the Frozen Basin site first.'), findsOneWidget);
expect(
  tester.getSize(find.byKey(const Key('mining-technology-buy-logistics'))),
  const Size(0, 0),
  reason: 'Replace this exact-size assertion with the enabled-state assertion below if the disabled action remains visible.',
);
```

Do **not** keep that temporary exact-size assertion in the committed test. The committed behavior is:

```dart
final blockedAction = find.byKey(const Key('mining-technology-buy-logistics'));
expect(blockedAction, findsOneWidget);
expect(tester.getSize(blockedAction).height, greaterThanOrEqualTo(48));
await tester.tap(blockedAction);
await tester.pump();
expect(purchases, isEmpty);
```

Starter fixture coverage:

```dart
await _pumpTechnology(
  tester,
  size: const Size(360, 640),
  view: _starterView(),
  onPurchase: purchases.add,
);
final extractionAction = find.byKey(
  const Key('mining-technology-buy-extraction'),
);
await tester.ensureVisible(extractionAction);
expect(tester.getSize(extractionAction).height, greaterThanOrEqualTo(48));
expect(tester.takeException(), isNull);
```

Text-scale coverage at the densest phone size:

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

Landscape coverage:

```dart
await _pumpTechnology(
  tester,
  size: const Size(874, 402),
  view: _parityView(),
);
final panel = find.byKey(const Key('mining-technology-panel-landscape'));
expect(panel, findsOneWidget);
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

- [ ] **Step 3: Run Technology tests and confirm the old list UI fails**

Run:

```bash
flutter test test/mining/presentation/technology_sheet_test.dart
```

Expected: FAIL because the tree keys/semantics, local selection, 528px landscape panel, and small-phone layout are not implemented.

- [ ] **Step 4: Vendor IBM Plex Mono with the license and register two weights**

Copy from the official IBM Plex distribution:

```text
assets/fonts/IBMPlexMono-Regular.ttf
assets/fonts/IBMPlexMono-SemiBold.ttf
assets/fonts/IBMPlexMono-OFL.txt
```

Add to the existing `fonts:` list without changing Orbitron:

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

Expected: dependency resolution succeeds with no new Dart package dependency.

- [ ] **Step 5: Create `MiningModalChrome` using existing theme tokens**

Create `lib/mining/presentation/mining_modal_chrome.dart`:

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
            color: MiningTheme.panel,
            border: Border(
              top: BorderSide(
                color: MiningTheme.accent.withAlpha(102),
              ),
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
          child: Padding(padding: padding, child: child),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 11,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MiningTheme.accent.withAlpha(180),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: const SizedBox(width: 42, height: 4),
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

Do not add route helpers or shared modal state.

- [ ] **Step 6: Convert `TechnologySheet` to local selection only**

Keep the public constructor unchanged. Add:

```dart
enum _TechnologyNodeState { owned, actionable, blocked, future }

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

Initialize selection:

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

Loop levels with:

```dart
for (var level = 1;
    level <= MiningContentRegistry.maxTechnologyLevel;
    level++) {
  // render one node
}
```

Never use a literal `5` to define the loop or max-level label.

- [ ] **Step 7: Render Technology nodes with `MiningHex`**

Create a private node widget in `technology_sheet.dart`. Use `48×48` for all nodes to keep the dense layout simple and guarantee the tap floor:

```dart
Widget _technologyNode({
  required TechnologyTrackView track,
  required int level,
  required _TechnologyNodeState state,
}) {
  final selectable =
      state == _TechnologyNodeState.actionable ||
      state == _TechnologyNodeState.blocked;

  final (fill, border) = switch (state) {
    _TechnologyNodeState.owned => (
      MiningTheme.accent.withAlpha(80),
      MiningTheme.accent,
    ),
    _TechnologyNodeState.actionable => (
      MiningTheme.warning.withAlpha(44),
      MiningTheme.warning,
    ),
    _TechnologyNodeState.blocked => (
      MiningTheme.gate.withAlpha(36),
      MiningTheme.gate,
    ),
    _TechnologyNodeState.future => (
      Colors.white.withAlpha(10),
      Colors.white.withAlpha(45),
    ),
  };

  return SizedBox(
    key: Key('mining-technology-node-${track.track.name}-$level'),
    width: 48,
    height: 48,
    child: MiningHex(
      fill: fill,
      border: border,
      semanticLabel:
          '${track.name} level $level ${state.name}',
      onTap: selectable
          ? () => setState(() => _selectedTrack = track.track)
          : null,
      child: Text('$level'),
    ),
  );
}
```

If `MiningHex`'s actual constructor names differ, adapt to its existing `fill`, `border`, `onTap`, and `semanticLabel` contract; do not introduce another hex painter.

- [ ] **Step 8: Implement portrait tree as a scroll-safe canonical composition**

At the root:

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

Portrait panel top:

```dart
final panelTop = math.min(190.0, constraints.maxHeight * .24);
```

Use `Positioned(top: panelTop, left: 0, right: 0, bottom: 0)` with `MiningModalChrome`. Inside, use `SingleChildScrollView` so `360×640` at text scale `1.3` stays reachable rather than forcing a smaller-than-accessible tree.

Header copy:

```dart
Text('Technology')
Text('MAX LV ${MiningContentRegistry.maxTechnologyLevel}')
```

Build three columns from `view.tracks`; each displays levels from `maxTechnologyLevel` down to 1 and uses simple `Container(width: 2, height: connectorHeight)` connectors between `MiningHex` nodes. Connectors are visual only; they do not need a new graph model.

Add a shared root hex beneath the three columns.

The selected detail card key is:

```dart
Key('mining-technology-detail-${selected.track.name}')
```

Only that card contains:

```dart
Key('mining-technology-buy-${selected.track.name}')
```

Render current effect, next effect, gate, cost, and `disabledReason` directly from `TechnologyTrackView`.

Purchase behavior:

```dart
void _purchase(TechnologyTrackView selected) {
  if (!selected.canPurchase) return;
  final navigator = Navigator.of(context);
  if (navigator.canPop()) navigator.pop();
  widget.onPurchase(selected.track);
}
```

- [ ] **Step 9: Implement the measured 528px Technology landscape panel**

At `874×402`, anchor a full-height panel to the right:

```dart
const canonicalPanelWidth = 528.0;
final width = math.min(canonicalPanelWidth, constraints.maxWidth);
```

Set the key on the exact panel box:

```dart
SizedBox(
  key: const Key('mining-technology-panel-landscape'),
  width: width,
  height: constraints.maxHeight,
  child: ...,
)
```

Render three horizontal rows. Each row contains the track label and levels `1..MiningContentRegistry.maxTechnologyLevel`. Use the same `48×48 MiningHex` node widget, so every actionable/blocked next node is at least 48×48.

Keep one selected detail/action area at the bottom. Use a bounded `SingleChildScrollView` only if the available height is smaller than the canonical 402px; do not shrink tappable nodes below 48.

- [ ] **Step 10: Move Technology presentation to transparent `showGeneralDialog`**

In `MiningShell.openTechnology()`, keep `maybeStartBgm()` and the existing `TechnologySheetView.from(...)` projection.

Replace only the bottom-sheet presentation:

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

Do not add a shared route helper.

- [ ] **Step 11: Update shell Technology regression to check the new boundary**

Add/replace the shell test with state-oriented assertions:

```dart
shellHandles(tester).openTechnology();
await tester.pump(const Duration(milliseconds: 200));
expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
expect(find.byKey(const Key('mining-technology-panel-portrait')), findsOneWidget);
expect(find.byType(BottomSheet), findsNothing);
expect(
  shellHandles(tester).controller.state.technology.extraction,
  0,
);
```

- [ ] **Step 12: Run focused tests, format, and commit Task 1**

Run:

```bash
dart format lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

Expected: PASS.

Commit:

```bash
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
- Consumes: `MiningModalChrome`, `MiningHex`, `MiningTheme`, injected `AudioManager`, `MediaQuery.disableAnimations`.
- Produces: unchanged `MiningSettingsSheet(audioManager:)`, stable Music/Volume keys, local `_HexSliderThumbShape`, transparent Settings dialog.

- [ ] **Step 1: Replace `SwitchListTile`-class assertions with behavior/semantics tests**

Keep SharedPreferences setup and add a helper:

```dart
Future<AudioManager> _pumpSettings(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final manager = AudioManager(
    backgroundMusicPlayer: FakeBackgroundMusicPlayer(),
  );
  await manager.loadPrefs();

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: MiningSettingsSheet(audioManager: manager),
        ),
      ),
    ),
  );
  await tester.pump();
  return manager;
}
```

Delete assertions that cast `mining-music-switch` to `SwitchListTile`.

- [ ] **Step 2: Add failing Settings behavior and layout tests**

With mock preferences:

```dart
SharedPreferences.setMockInitialValues({
  'audio.musicEnabled': true,
  'audio.musicVolume': 0.70,
});
```

Assert portrait content:

```dart
final manager = await _pumpSettings(
  tester,
  size: const Size(402, 874),
);
expect(find.byKey(const Key('mining-settings-panel-portrait')), findsOneWidget);
expect(find.text('AUDIO'), findsOneWidget);
expect(find.text('Music'), findsOneWidget);
expect(find.text('Cavern ambience'), findsOneWidget);
expect(find.text('70%'), findsOneWidget);
expect(find.text('20 steps'), findsOneWidget);
expect(find.text('ACCESSIBILITY'), findsOneWidget);
expect(find.text('Reduced motion'), findsOneWidget);
expect(find.text('SYSTEM'), findsOneWidget);
expect(manager.musicEnabled, isTrue);
```

Music behavior:

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

Dense portrait/text-scale coverage:

```dart
await _pumpSettings(
  tester,
  size: const Size(360, 640),
  textScale: 1.3,
);
for (final finder in [
  find.byKey(const Key('mining-music-switch')),
  find.byKey(const Key('mining-volume-slider')),
  find.text('SYSTEM'),
]) {
  await tester.ensureVisible(finder);
}
expect(tester.takeException(), isNull);
```

Landscape reachability:

```dart
await _pumpSettings(
  tester,
  size: const Size(874, 402),
  textScale: 1.3,
);
expect(find.byKey(const Key('mining-settings-panel-landscape')), findsOneWidget);
await tester.ensureVisible(find.byKey(const Key('mining-volume-slider')));
await tester.ensureVisible(find.text('SYSTEM'));
expect(tester.takeException(), isNull);
```

- [ ] **Step 3: Run Settings tests and confirm the stock layout fails**

Run:

```bash
flutter test test/mining/presentation/mining_settings_sheet_test.dart
```

Expected: FAIL on new panel keys/copy and custom visual contract.

- [ ] **Step 4: Implement Settings cards with `MiningModalChrome`**

Keep `MiningSettingsSheet` stateful because it reflects injected `AudioManager` mutations.

Use full-screen transparent Material + `LayoutBuilder`, analogous to Technology. Portrait panel top:

```dart
final panelTop = math.min(392.0, constraints.maxHeight * .45);
```

Use:

```dart
Positioned(
  top: panelTop,
  left: 0,
  right: 0,
  bottom: 0,
  child: MiningModalChrome(...),
)
```

Place Audio and Accessibility cards inside `SingleChildScrollView` so 360×640 / 1.3 remains reachable.

Use `IBMPlexMono` for eyebrows, metadata, secondary copy, percentage, and SYSTEM badge; keep Orbitron for primary labels where inherited from the app theme.

- [ ] **Step 5: Implement the inline Music pill with `MiningHex`**

Do not add a generic toggle component.

Use a 48px-high `InkWell`/`Semantics`:

```dart
Widget _musicToggle(AudioManager audioManager) {
  final enabled = audioManager.musicEnabled;
  final reducedMotion = MediaQuery.of(context).disableAnimations;

  final thumb = SizedBox(
    width: 34,
    height: 38,
    child: MiningHex(
      fill: MiningTheme.highlight,
      border: MiningTheme.highlight,
      child: const SizedBox.shrink(),
    ),
  );

  return Semantics(
    toggled: enabled,
    button: true,
    label: 'Music',
    child: InkWell(
      key: const Key('mining-music-switch'),
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        unawaited(audioManager.setMusicEnabled(!enabled));
        setState(() {});
      },
      child: SizedBox(
        width: 84,
        height: 48,
        child: Stack(
          children: [
            Align(
              alignment: enabled
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  enabled ? 'ON' : 'OFF',
                  style: const TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            AnimatedAlign(
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              alignment: enabled
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: thumb,
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 6: Implement the hex Slider thumb as `SliderComponentShape`**

Keep Material `Slider` as the only drag/keyboard/semantic control. Add one local shape in `mining_settings_sheet.dart`:

```dart
class _HexSliderThumbShape extends SliderComponentShape {
  const _HexSliderThumbShape({this.radius = 15});

  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.square(radius * 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i - math.pi / 2;
      final point = center + Offset(
        math.cos(angle) * radius,
        math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final fill = Paint()
      ..color = sliderTheme.thumbColor ?? MiningTheme.highlight;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = MiningTheme.accent;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }
}
```

Use it through `SliderTheme`:

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

Do not position a second thumb manually.

- [ ] **Step 7: Implement functional Settings landscape without inventing a new design**

For `constraints.maxWidth > constraints.maxHeight`, use a bounded right-side panel with key `mining-settings-panel-landscape` and the same cards in `SingleChildScrollView`. The panel may use a practical width derived from available space; there is no pixel-parity width requirement because the mock does not define one.

Keep all controls reachable at `874×402` / 1.3.

- [ ] **Step 8: Present Settings with transparent `showGeneralDialog`**

In `MiningShell.openSettings()`:

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

Keep the existing BGM-start call before presentation.

- [ ] **Step 9: Update shell Settings regression to assert manager state, not widget class**

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

- [ ] **Step 10: Run focused tests, format, and commit Task 2**

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
- Consumes: unchanged `OfflineProductionSummary`, `MiningContentRegistry`, `MiningVisuals.offlineHero`, `MiningCashChip`, catalog silhouettes, live cash, live Logistics level, `MediaQuery.disableAnimations`.
- Produces: `OfflineReturnSheet(summary:, content:, cash:, logisticsLevel:)`, portrait/landscape full-screen layouts, Continue-only dismissal, reduced-motion-aware returned-status pulse.

- [ ] **Step 1: Update Offline Return tests for presentation scalars and full-screen keys**

Change each constructor call in `offline_return_sheet_test.dart` to provide explicit live presentation values:

```dart
OfflineReturnSheet(
  summary: summary,
  content: MiningContentRegistry.stellarMining(),
  cash: 1840,
  logisticsLevel: 3,
)
```

Keep the existing multi-planet/resource/silhouette/full-site test and its real catalog expectations.

Add portrait key expectations:

```dart
expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
expect(find.byKey(const Key('offline-return-portrait')), findsOneWidget);
expect(find.byKey(const Key('mining-cash-chip')), findsOneWidget);
expect(find.text('FLEET RETURNED'), findsOneWidget);
```

- [ ] **Step 2: Replace old cap wording expectation with the mock-style scalar wording**

For a capped 12-hour fixture and `logisticsLevel: 2`:

```dart
expect(
  find.text('Capped at 12h — Logistics LV 2'),
  findsOneWidget,
);
```

For uncapped summary:

```dart
expect(find.textContaining('Capped at'), findsNothing);
```

Do not call `content.offlineCapFor()` inside the widget.

- [ ] **Step 3: Add landscape, text-scale, empty-summary, and Continue tests**

Landscape:

```dart
tester.view.physicalSize = const Size(874, 402);
// pump sheet
expect(find.byKey(const Key('offline-return-landscape')), findsOneWidget);
final panel = find.byKey(const Key('offline-return-summary-landscape'));
expect(tester.getSize(panel).width, 470);
expect(tester.takeException(), isNull);
```

Keep/extend the existing `430×932` / text scale `1.3` Continue reachability test.

Add `360×640` / `1.3`:

```dart
final dismiss = find.byKey(const Key('offline-return-dismiss'));
await tester.ensureVisible(dismiss);
expect(tester.getSize(dismiss).height, greaterThanOrEqualTo(48));
expect(tester.takeException(), isNull);
```

Add an empty/minimal summary test with no produced resources and assert `offline-return-dismiss` still exists.

- [ ] **Step 4: Run Offline Return tests and verify the old bottom-sheet layout fails**

Run:

```bash
flutter test test/mining/presentation/offline_return_sheet_test.dart
```

Expected: FAIL because `cash`, `logisticsLevel`, full-screen keys, 470px landscape panel, and new cap copy are absent.

- [ ] **Step 5: Convert `OfflineReturnSheet` to a pulse-capable StatefulWidget**

Use:

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

  @override
  State<OfflineReturnSheet> createState() => _OfflineReturnSheetState();
}
```

Use `SingleTickerProviderStateMixin` and follow `MainMenu.didChangeDependencies()` locally:

```dart
late final AnimationController _pulseController;
bool _reducedMotion = false;
bool _motionInitialized = false;

@override
void initState() {
  super.initState();
  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    lowerBound: .55,
    upperBound: 1,
  );
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final reduced = MediaQuery.of(context).disableAnimations;
  if (_motionInitialized && reduced == _reducedMotion) return;
  _reducedMotion = reduced;
  if (reduced) {
    _pulseController
      ..stop()
      ..value = 1;
  } else {
    _pulseController.repeat(reverse: true);
  }
  _motionInitialized = true;
}

@override
void dispose() {
  _pulseController.dispose();
  super.dispose();
}
```

Use `_pulseController` only for the small returned-status dot. No other new animation is required.

- [ ] **Step 6: Extend the existing duration formatter instead of adding parallel formatting helpers**

Keep one formatter:

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

Cap copy:

```dart
if (widget.summary.wasOfflineCapped)
  Text(
    'Capped at ${_formatDuration(widget.summary.elapsedUsed, compact: true)} '
    '— Logistics LV ${widget.logisticsLevel}',
  )
```

- [ ] **Step 7: Implement the portrait full-screen result**

Root:

```dart
return PopScope(
  canPop: false,
  child: Material(
    key: const Key('offline-return-sheet'),
    color: const Color(0xFF060A10),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth > constraints.maxHeight
            ? _buildLandscape(context, constraints)
            : _buildPortrait(context, constraints);
      },
    ),
  ),
);
```

Portrait key:

```dart
const Key('offline-return-portrait')
```

Composition:

- `MiningVisuals.offlineHero` in upper ~400px with image-error fallback;
- vertical dark gradient into the background;
- `MiningCashChip(cash: widget.cash)` top-left;
- FLEET RETURNED chip around the hero/content transition;
- main elapsed copy;
- optional cap line;
- one production section per `summary.productionByPlanet` entry;
- existing catalog silhouette/name/color mapping for resource rows;
- existing full-site resolution by catalog;
- one bottom `offline-return-dismiss` action.

Use `CustomScrollView`/`SingleChildScrollView` so real multi-planet production remains reachable.

- [ ] **Step 8: Implement the measured 470px landscape summary panel**

Landscape key:

```dart
const Key('offline-return-landscape')
```

Keep hero/background full-screen and left-side return information visible. Anchor the summary panel right:

```dart
const panelWidth = 470.0;
SizedBox(
  key: const Key('offline-return-summary-landscape'),
  width: math.min(panelWidth, constraints.maxWidth),
  child: ...,
)
```

Production sections and `CONTINUE MINING` remain in the right-side scroll flow so multiple planets/text scaling cannot overlap system insets.

- [ ] **Step 9: Make Continue the only dismissal path**

The primary button keeps:

```dart
key: const Key('offline-return-dismiss')
```

Action:

```dart
onPressed: () => Navigator.of(context).pop()
```

The outer `PopScope(canPop: false)` blocks system-back dismissal; the shell route uses `barrierDismissible: false`.

- [ ] **Step 10: Promote `_showOfflineReturn()` to non-dismissible `showGeneralDialog`**

In `MiningShell`:

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

Do not alter pending-summary timing, initialization, checkpoint/resume, or controller accrual.

- [ ] **Step 11: Strengthen the shell resume regression**

Extend the existing pause/resume test:

```dart
expect(find.byKey(const Key('offline-return-sheet')), findsOneWidget);
expect(find.byKey(const Key('offline-return-portrait')), findsOneWidget);
expect(find.byType(BottomSheet), findsNothing);
expect(find.textContaining('Gold'), findsWidgets);

await tester.tap(find.byKey(const Key('offline-return-dismiss')));
await tester.pump(const Duration(milliseconds: 200));
expect(find.byKey(const Key('offline-return-sheet')), findsNothing);
```

Keep controller state assertions proving pause/resume accrual is unchanged.

- [ ] **Step 12: Run focused tests, format, and commit Task 3**

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

### Task 4: Canonical Goldens and Source-Reference Evidence

**Files:**
- Modify: `test/mining/presentation/visual_parity_golden_test.dart`
- Create/update: `test/mining/presentation/goldens/hpa438_*.png`
- Create: `docs/superpowers/evidence/hpa-438/reference/*.png`
- Create: `docs/superpowers/evidence/hpa-438/parity.md`

**Interfaces:**
- Consumes: completed Technology/Settings/Offline widgets, existing golden `_pumpSurface`, existing `SiteDeckScreen`, five mock frames.
- Produces: five canonical Linux goldens and explicit side-by-side parity evidence.

- [ ] **Step 1: Load both IBM Plex Mono weights in the golden harness**

Refactor the font helper so one family can receive multiple files:

```dart
Future<void> _loadFonts(
  String family,
  List<String> paths,
) async {
  if (kIsWeb) return;
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) {
      loader.addFont(file.readAsBytes().then(ByteData.sublistView));
    }
  }
  await loader.load();
}
```

Set up:

```dart
setUpAll(() async {
  await _loadFonts(
    'Orbitron',
    ['assets/fonts/Orbitron-Variable.ttf'],
  );
  await _loadFonts(
    'IBMPlexMono',
    [
      'assets/fonts/IBMPlexMono-Regular.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
    ],
  );
});
```

Do not load Regular only.

- [ ] **Step 2: Add deterministic visual fixtures without production constants**

Use the Task 1 parity Technology fixture in `visual_parity_golden_test.dart` and keep mock-like values test-only.

Offline fixture:

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

These sample values remain in tests/evidence only.

- [ ] **Step 3: Extend the existing Site Deck golden composition for Technology/Settings backdrop**

Reuse the current `_pumpSurface` and actual `SiteDeckScreen`; do not create a new screenshot framework.

Build deterministic `MiningSave`/`SiteDeckView`/`FleetDockView` data and compose:

```dart
Stack(
  fit: StackFit.expand,
  children: [
    SiteDeckScreen(
      cash: state.cash,
      view: siteDeckView,
      fleetDock: fleetDockView,
      onEnterSite: (_) {},
      onUnlockSite: (_) {},
      onBayTap: (_) {},
      onSpawnRig: () {},
      onDestinationSelected: (_) {},
    ),
    overlay,
  ],
)
```

Use `cash: 1840` and enough deterministic cargo/deployment to make the HUD non-empty.

- [ ] **Step 4: Add exactly five canonical full-screen golden tests**

Files:

```text
hpa438_technology_402x874.png
hpa438_technology_874x402.png
hpa438_settings_402x874.png
hpa438_offline_return_402x874.png
hpa438_offline_return_874x402.png
```

Use the existing repository skip policy:

```dart
skip: kIsWeb || Platform.isMacOS
```

Technology and Settings goldens use the real Site Deck backdrop. Offline goldens pump `OfflineReturnSheet` directly with `cash: 1840` and `logisticsLevel: 3`.

The Technology `874×402` full-screen golden is a **composition smoke test**, not a parity score for the left-side Site Deck. Do not modify Site Deck to make that left side resemble the mock.

- [ ] **Step 5: Generate the five implementation goldens on Linux**

Run in the repository's Linux CI/container environment:

```bash
flutter test --update-goldens test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: non-skipped goldens PASS.

Verify image dimensions:

```bash
file test/mining/presentation/goldens/hpa438_*.png
```

Expected: canonical files are `402×874` or `874×402` according to their names.

- [ ] **Step 6: Export the five source-reference frames from the standalone mock**

Capture exactly these `data-screen-label` elements without browser chrome:

```text
Technology sheet
Technology landscape
Settings sheet
Offline return
Offline return landscape
```

Write:

```text
docs/superpowers/evidence/hpa-438/reference/technology-402x874.png
docs/superpowers/evidence/hpa-438/reference/technology-874x402.png
docs/superpowers/evidence/hpa-438/reference/settings-402x874.png
docs/superpowers/evidence/hpa-438/reference/offline-return-402x874.png
docs/superpowers/evidence/hpa-438/reference/offline-return-874x402.png
```

Do not commit the ~15 MB HTML bundle.

- [ ] **Step 7: Write evidence that explicitly excludes out-of-scope Site Deck landscape drift**

Create `docs/superpowers/evidence/hpa-438/parity.md`:

```markdown
# HPA-438 Visual Parity Evidence

| Surface | Mock reference | Flutter implementation | Scored scope |
| --- | --- | --- | --- |
| Technology 402×874 | ![](reference/technology-402x874.png) | ![](../../../../test/mining/presentation/goldens/hpa438_technology_402x874.png) | Full Technology sheet + visible HUD context |
| Technology 874×402 | ![](reference/technology-874x402.png) | ![](../../../../test/mining/presentation/goldens/hpa438_technology_874x402.png) | **Rightmost 528 px Technology panel only**; left-side current Site Deck is smoke-test context and out of scope |
| Settings 402×874 | ![](reference/settings-402x874.png) | ![](../../../../test/mining/presentation/goldens/hpa438_settings_402x874.png) | Full Settings sheet + visible HUD context |
| Offline Return 402×874 | ![](reference/offline-return-402x874.png) | ![](../../../../test/mining/presentation/goldens/hpa438_offline_return_402x874.png) | Full screen |
| Offline Return 874×402 | ![](reference/offline-return-874x402.png) | ![](../../../../test/mining/presentation/goldens/hpa438_offline_return_874x402.png) | Full screen |

## Review checklist

- [ ] Technology panel edges/geometry match; landscape panel is 528 px.
- [ ] Technology node order/state/target sizing match.
- [ ] Technology detail/action area matches.
- [ ] Settings Audio/Accessibility hierarchy matches.
- [ ] Offline hero/result/summary hierarchy matches; landscape summary is 470 px.
- [ ] IBM Plex Mono Regular/SemiBold metrics are loaded in goldens.
- [ ] No critical action is clipped at text scale 1.3.
- [ ] No Site Deck layout change was made for HPA-438.
```

- [ ] **Step 8: Run focused visual tests and commit Task 4**

Run:

```bash
dart format test/mining/presentation/visual_parity_golden_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: PASS subject to existing platform skips.

Commit:

```bash
git add test/mining/presentation/visual_parity_golden_test.dart test/mining/presentation/goldens/hpa438_*.png docs/superpowers/evidence/hpa-438/
git commit -m "test: lock mining secondary surface parity"
```

---

### Task 5: Full Regression, Scope Guard, and Review Handoff

**Files:**
- Modify only files already listed above if verification exposes an HPA-438 presentation/test defect.
- Update PR #24 after verification.
- Move Linear HPA-438 to `In Review` only after repository gates pass.

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: green repository gates, no domain drift, final evidence attached to PR #24.

- [ ] **Step 1: Run the exact repository formatting and analysis gates from `AGENTS.md`**

Run:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: both exit `0`.

- [ ] **Step 2: Run the focused HPA-438 suite**

Run:

```bash
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_settings_sheet_test.dart
flutter test test/mining/presentation/offline_return_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run the complete repository verification workflow**

Run:

```bash
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Expected: all supported environment commands exit `0`; any environment-only inability to run an Apple build must be reported explicitly in the PR instead of silently skipped.

- [ ] **Step 4: Prove HPA-438 did not drift into domain/state files**

Run:

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
  lib/mining/mine_site_view.dart
```

Expected: no output.

Also prove Site Deck presentation itself was not modified for landscape parity:

```bash
git diff --name-only main...HEAD -- lib/mining/presentation/site_deck_screen.dart
```

Expected: no output.

- [ ] **Step 5: Review the five parity rows against their explicit scoring boundaries**

Open `docs/superpowers/evidence/hpa-438/parity.md` and check every box.

For Technology landscape, inspect only the rightmost **528 px** panel for pixel-style parity. Treat the left-side current Site Deck as composition context only. Do not expand HPA-438 to fix it.

If a parity issue exists, change only the HPA-438 presentation files, regenerate the affected golden, rerun the focused tests, and update evidence.

- [ ] **Step 6: Commit verification-only documentation if it changed**

If the evidence/PR notes changed during verification:

```bash
git add docs/superpowers/evidence/hpa-438/
git commit -m "docs: finalize HPA-438 parity evidence"
```

If no tracked files changed, do not create an empty commit.

- [ ] **Step 7: Update PR #24 and Linear only after green verification**

PR #24 body must report:

- Technology/Settings/Offline implementation summary;
- exact five canonical golden states;
- measured `528` Technology landscape panel and `470` Offline Return panel;
- `360×640` / `1.3` coverage for Technology and Settings;
- all repository verification commands and results;
- explicit no-domain-drift result;
- link/path to `docs/superpowers/evidence/hpa-438/parity.md`;
- note that Technology landscape left-side Site Deck is out of scope and not parity-scored.

Move HPA-438 to `In Review` and mark PR #24 ready only after those checks are recorded.

---

## Review-Resolved Decisions

- Technology landscape width is **528 px**, measured from the supplied mock; the previous design's 470px value was incorrect. `470 px` applies to Offline Return landscape only.
- Every selectable Technology node is at least `48×48`.
- Technology level loops and `MAX LV` use `MiningContentRegistry.maxTechnologyLevel`.
- Technology nodes reuse `MiningHex`.
- Shared chrome uses `MiningTheme` tokens instead of raw duplicate panel/accent colors.
- Settings keeps a real 20-step Material Slider and uses a local `SliderComponentShape` for the hex thumb; no manually positioned overlay thumb.
- Technology tests replace retiring list assertions and keep both starter-state and parity-state fixtures.
- Technology and Settings both receive `360×640` + text-scale `1.3` coverage.
- `flutter analyze --fatal-infos` is the analysis gate.
- Technology landscape full-screen golden is a composition smoke test; parity scoring is limited to its rightmost 528px panel.
- Golden setup loads both IBM Plex Mono Regular and SemiBold.
- No modal route helper, generic toggle, second color file, or Site Deck work is added.