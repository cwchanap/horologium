# HPA-438 Mining Secondary-Surface UI Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revamp Technology, Settings, and Offline Return to the supplied mock's visual parity while preserving mining domain, save, economy, lifecycle, and ownership contracts.

**Architecture:** Keep `MiningShell` as runtime owner. Move Technology node-state projection into `TechnologyTrackView` so widgets render projected state instead of re-deriving rule-shaped logic. Technology/Settings use transparent built-in dialogs plus one tiny shared chrome helper; Offline Return uses a non-dismissible full-screen dialog fed by the existing summary/content plus cash, Logistics level, and shell-owned reduced motion. Structural/behavior tests are the primary automated gate; two cropped Technology panel goldens run as Linux CI regression guards, while five committed source-vs-app captures are the actual parity gate.

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

Extend `test/mining/mining_progression_views_test.dart` with direct tests of the new API.

- [ ] **Step 2: Run the pure projection test and verify RED**

```bash
flutter test test/mining/mining_progression_views_test.dart
```

- [ ] **Step 3: Add `TechnologyNodeState` and remove dead availability fields**

Add `enum TechnologyNodeState { owned, actionable, blocked, future }` and `TechnologyTrackView.stateForLevel(int)`. Remove `nodeAvailability`, `nextNodeAvailability`, `surveyingNodeAvailability`, and `_nodeAvailability(...)` because repository search shows no consumers.

- [ ] **Step 4: Re-run pure projection tests**

```bash
flutter test test/mining/mining_progression_views_test.dart
```

- [ ] **Step 5: Replace retiring Technology list tests with starter + parity fixtures**

Keep a fresh level-0 fixture and a four-state parity fixture. Delete list-layout-specific assertions and direct casts to the retiring `ElevatedButton` rows.

- [ ] **Step 6: Add failing Technology behavior/layout tests**

Cover semantics from `stateForLevel`, local selection, blocked action inertness, 48px action/node floors, `360×640` at text scale `1.3`, and `874×402` using `TechnologySheet.landscapePanelWidth`.

- [ ] **Step 7: Run Technology widget tests and verify RED**

```bash
flutter test test/mining/presentation/technology_sheet_test.dart
```

- [ ] **Step 8: Vendor/register IBM Plex Mono**

Add official Regular, SemiBold, and OFL files; register only weights 400/600. Run `flutter pub get`.

- [ ] **Step 9: Create `MiningModalChrome` using existing theme tokens**

Use only `MiningTheme.panel`, `MiningTheme.accent.withAlpha(...)`, shadow, rounded upper corners, 42×4 handle, padding, and optional protruding affordances. No routing/state/actions.

- [ ] **Step 10: Implement Technology tree with `MiningHex`**

`TechnologySheet` is stateful only for selected track. Use `track.stateForLevel(level)`, `MiningContentRegistry.maxTechnologyLevel`, and 48×48 `MiningHex` nodes.

- [ ] **Step 11: Implement portrait Technology composition**

Use shared chrome, three vertical max→1 tracks, common root, selected detail/action card, and scrollability so 360×640 / 1.3 remains reachable.

- [ ] **Step 12: Implement landscape Technology composition with one shared width constant**

Expose:

```dart
static const double landscapePanelWidth = 528;
```

Right-align it and render three horizontal tracks. Tests assert against the constant rather than a second literal.

- [ ] **Step 13: Present Technology with transparent built-in dialog**

Replace only Technology bottom-sheet presentation with barrier-dismissible `showGeneralDialog<void>`, preserving projection/action ownership and close-then-purchase behavior.

- [ ] **Step 14: Run focused Technology tests, format, commit**

```bash
dart format lib/mining/mining_progression_views.dart lib/mining/presentation/mining_modal_chrome.dart lib/mining/presentation/technology_sheet.dart lib/mining/presentation/mining_shell.dart test/mining/mining_progression_views_test.dart test/mining/presentation/technology_sheet_test.dart test/mining/presentation/mining_shell_test.dart
flutter test test/mining/mining_progression_views_test.dart
flutter test test/mining/presentation/technology_sheet_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

---

### Task 2: Settings Audio and Accessibility Parity

- [ ] Replace class-specific Settings tests with behavior tests.
- [ ] Add `360×640` / 1.3 and `874×402` / 1.3 reachability/overflow tests.
- [ ] Verify tests fail before implementation.
- [ ] Rebuild portrait Settings with shared chrome and scrollable Audio/Accessibility cards.
- [ ] Keep inline Music pill with static `MiningHex` thumb; no local reduced-motion query.
- [ ] Keep real Material `Slider(divisions: 20)` and implement local `_HexSliderThumbShape extends SliderComponentShape`.
- [ ] Keep landscape functional only, no unreferenced parity design.
- [ ] Present Settings through barrier-dismissible `showGeneralDialog<void>`; shell owns route transition reduced motion.
- [ ] Update shell regression to assert state/keys rather than `SwitchListTile` class.
- [ ] Run focused Settings + shell tests and commit.

---

### Task 3: Full-Screen Offline Return and Resume-Lock Safety

**Interface:** `OfflineReturnSheet(summary:, content:, cash:, logisticsLevel:, reducedMotion:)`; keep `OfflineProductionSummary` unchanged.

- [ ] Update all tests to pass cash, Logistics level, reducedMotion.
- [ ] Add failing tests for authored cap lookup, `874×402` / 1.3, system back, hero asset failure, reduced motion, and Continue dismissal.
- [ ] Verify tests fail before implementation.
- [ ] Use `content.offlineCapFor(logisticsLevel)` for cap copy; do not infer cap from `summary.elapsedUsed`.
- [ ] Make the sheet stateful only for the FLEET RETURNED pulse and use the passed `reducedMotion`; do not query MediaQuery locally.
- [ ] Implement scrollable portrait result with hero fallback and always-reachable Continue.
- [ ] Expose `static const double landscapePanelWidth = 470` and use it in layout/tests.
- [ ] Use non-dismissible `showGeneralDialog` plus `PopScope(canPop:false)`; Continue is the only exit.
- [ ] Pass `_displayState.cash`, Logistics level, and `_reducedMotion` from `MiningShell`; do not change resume/checkpoint/accrual timing.
- [ ] Strengthen shell resume regression for no BottomSheet, state preservation, back-button rejection, and Continue dismissal.
- [ ] Run focused Offline + shell tests and commit.

---

### Task 4: Rehabilitate Visual Harness, Add Two Scoped Panel Goldens, and Build Five-Frame Evidence

- [ ] Run the existing visual-parity test on Linux to establish current behavior.
- [ ] For the two unconditional stale Site Deck/Stellar Map skips: unskip + regenerate on Linux if they pass without production changes; otherwise delete the stale test + PNG. Never change out-of-scope production to satisfy them.
- [ ] Load both IBM Plex Mono Regular and SemiBold in the golden harness.
- [ ] Add only two HPA-438 goldens, scoped to the Technology portrait/landscape panel finders:
  - `hpa438_technology_panel_402x874.png`
  - `hpa438_technology_panel_874x402.png`
- [ ] Keep `skip: kIsWeb || Platform.isMacOS`; these still run in Ubuntu CI and block on mismatch.
- [ ] Generate/verify them on Linux.
- [ ] Capture five mock references and five matching app images under `docs/superpowers/evidence/hpa-438/`:
  - Technology portrait panel
  - Technology landscape 528px panel
  - Settings portrait panel
  - Offline Return portrait
  - Offline Return landscape
- [ ] Write `parity.md` with a five-row pass/fail table. This document is the actual visual acceptance gate; goldens are regression guards only.
- [ ] Run visual suite and commit.

---

### Task 5: Full Regression, Scope Guard, Risks Check, and Handoff

- [ ] Run `dart format --output=none --set-exit-if-changed .` and `flutter analyze --fatal-infos`.
- [ ] Run all HPA-438 focused tests, including pure projection and visual harness.
- [ ] Run full repository gates from `AGENTS.md`:

```bash
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

- [ ] Prove no controller/simulation/state/repository/content/Site Deck/Mine Site/Stellar Map production drift. `mining_progression_views.dart` is intentionally excluded from this guard.
- [ ] Re-run the non-dismissible Offline Return risk checks: `874×402` @1.3, back remains blocked, failing hero asset leaves Continue, Continue dismisses.
- [ ] Complete all five parity evidence rows.
- [ ] Update PR #24 and move HPA-438 to In Review only after all available gates are green; record any environment-limited platform build explicitly.

---

## Risks

1. **Non-dismissible Offline Return can hard-lock resume.** Mitigate with scrollable layouts, explicit `874×402` at `1.3`, system-back rejection, hero-failure fallback, and Continue-reachability/dismissal tests.
2. **Technology tree density can regress small phones.** Mitigate with 48×48 selectable nodes, scrollability, pure `stateForLevel` tests, and `360×640` at `1.3`.
3. **Visual baselines can couple to out-of-scope surfaces.** Mitigate with panel-scoped Technology goldens only and separate five-frame parity evidence.

## Review-Resolved Decisions

- Technology landscape remains **528 px**; Offline Return landscape remains **470 px**.
- `TechnologyNodeState` lives in the pure `TechnologyTrackView` projection.
- Remove unused availability projection members.
- Reuse `MiningHex`, `MiningTheme`, and `MiningContentRegistry.maxTechnologyLevel`.
- Settings keeps real Material Slider + local SliderComponentShape; Music thumb is static.
- Offline cap copy uses `content.offlineCapFor(logisticsLevel)`.
- Offline Return receives reducedMotion from `MiningShell`.
- Non-dismissible Offline Return gets explicit 874×402/1.3, system-back, hero-failure, and Continue tests.
- Add **two cropped Technology panel goldens**, not five full-screen HPA-438 goldens.
- Rehabilitate/remove existing unconditional stale goldens without production changes.
- Five committed source-vs-app captures are the actual visual parity gate.
- No `OfflineReturnView`, modal manager, generic toggle, second palette, Site Deck redesign, or domain change.
