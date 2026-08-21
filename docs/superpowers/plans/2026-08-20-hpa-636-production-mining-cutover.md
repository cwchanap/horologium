# HPA-636 Production Mining Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the validated one-planet mining MVP Horologium's only player-facing product, preserve its save/offline/audio/accessibility behavior, and delete the obsolete city runtime instead of leaving a dormant second architecture.

**Architecture:** Keep `MainMenu` as a minimal mining-only landing shell and `lib/mining/` as the gameplay vertical slice. `MiningScreen` owns Flutter lifecycle/HUD/settings, `MiningController` remains the mutation/persistence boundary, and `MiningGame` remains the Flame world. Reuse only audio, resource identity, assets, and parallax terrain with concrete mining consumers. Sever the terrain→Grid dependency before deletion; slim `ResourceType` only after city consumers are removed.

**Tech Stack:** Dart 3.8+, Flutter 3.32.5, Flame 1.30, SharedPreferences 2.5, audioplayers 6.x, existing Flutter/Flame test infrastructure.

**Spec:** `docs/superpowers/specs/2026-08-20-hpa-636-production-mining-cutover-design.md`

## Global Constraints

- Deliver HPA-636 in **one PR** on `jack65786656/hpa-636-cut-over-to-the-mining-only-product`; implementation continues on this same draft PR.
- HPA-631's final conclusion is **Proceed to cutover**, but run its requested real-device tier/reward visual pass before the first production routing change.
- Preserve the strict unversioned `horologium.mining.save` payload. Do not add a version, migration, camera/selection field, city import, backup, or compatibility branch.
- Legacy city keys are ignored, not migrated or eagerly deleted.
- Do not add Provider, Riverpod, Bloc, a service locator, a new router, a settings service, a feature flag, a compatibility facade, or a second audio singleton.
- Keep `MiningController`, `MiningSimulation`, and the validated HPA-631 economy unchanged unless a concrete HPA-636 blocker is demonstrated.
- Reduced motion continues to use `MediaQuery.disableAnimations`; do not add a competing preference.
- Keep `MiningStatusBar` metrics-only; Settings is a separate overlay control.
- Keep unused binary city assets out of scope unless an asset declaration/build failure requires deletion.
- Delete tests with retired production code instead of retaining production code solely to keep old tests green.
- `AGENTS.md` follows `CLAUDE.md`; update `CLAUDE.md`, not a separate divergent agent file.
- The current `.specify/memory/constitution.md` is a stale city-specific governance contract. HPA-636 explicitly amends it in Task 6; do not design around the obsolete city mandates.

---

## Risks and Gates

| Risk | Mitigation / proof |
| --- | --- |
| Product cutover starts after an invalid physical-device visual | Mandatory device check before Task 2 |
| Legacy city data affects startup | Presence-only `MiningSaveRepository.hasSave()` + legacy-only launch test |
| Existing mining saves reset | Leave `MiningSave`/decoder schema unchanged |
| City removal silently removes BGM | Load existing prefs in `MiningScreen`; start BGM from existing user gestures; inject real `AudioManager` backed by fake player in tests |
| Settings crowds 360px HUD | Separate `Positioned`/`SafeArea` settings control; status bar stays unchanged |
| `Grid` cannot be deleted | Explicit terrain cell-size constructor removes the only mining-relevant Grid dependency |
| Resource cleanup breaks city code before deletion | No standalone ResourceType slimming task; simplify it only after all city consumers are removed |
| Nested city tests survive path-based deletion | Treat delete lists as seeds; run analyze/search after each group |
| Dead city packages survive | Remove `uuid` and `flame_audio` after their consumers are deleted |
| Speckit regenerates city-first plans | Amend constitution to mining-first governance in Task 6 |

---

## File Map

### Create

```text
lib/mining/presentation/mining_settings_sheet.dart
test/support/fake_background_music_player.dart
```

### Modify

```text
lib/main_menu.dart
lib/mining/mining_save_repository.dart
lib/mining/presentation/mining_screen.dart
lib/mining/world/mining_game.dart
lib/game/terrain/parallax_terrain_component.dart
lib/game/resources/resource_type.dart
pubspec.yaml
pubspec.lock

README.md
CLAUDE.md
.github/copilot-instructions.md
.windsurf/rules/project.md
.specify/memory/constitution.md

test/main_menu_test.dart
test/widget_test.dart
test/mining/mining_save_repository_test.dart
test/mining/presentation/mining_screen_test.dart
test/game/audio_manager_test.dart
test/game/terrain/parallax_terrain_component_test.dart
test/mining/world/mining_game_test.dart
```

### Delete

Delete city production/tests in Task 5 after the mining entry/audio/terrain seams are green. Exact path lists are discovery seeds, not a whitelist; analysis/search owns the final closure.

---

## Task 1: Close the HPA-631 Physical-Device Gate

**Files:** none.

- [ ] **Step 1: Run the merged mining MVP on one supported physical phone in portrait.**

Check at minimum:

```text
level 1 / 3 / 5 structures are visibly distinct
reveal/build/upgrade/sale rewards remain legible
narrow portrait controls remain usable
no product-blocking visual regression invalidates Proceed to cutover
```

- [ ] **Step 2: Record the result on HPA-636 before changing production routing.**

If the pass is acceptable, continue. If it exposes a product-blocking issue, fix/reconsider the validated MVP instead of hiding a redesign in the cutover.

---

## Task 2: Make Startup Mining-Only and Distinguish Start from Continue

**Files:**
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/main_menu.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Rewrite: `test/main_menu_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Produces: `Future<bool> MiningSaveRepository.hasSave()`.
- `hasSave()` answers only whether `MiningSaveRepository.saveKey` exists.
- `MainMenu` navigates only to `MiningScreen`.
- `MiningScreen` remains responsible for create/decode/recovery/offline accrual.

- [ ] **Step 1: Add RED save-presence tests.**

Add cases equivalent to:

```dart
test('hasSave ignores legacy-only preferences', () async {
  SharedPreferences.setMockInitialValues({
    'cash': 999.0,
    'active_planet_id': 'earth',
  });

  expect(await MiningSaveRepository().hasSave(), isFalse);
});

test('hasSave reports mining save presence without parsing it', () async {
  SharedPreferences.setMockInitialValues({
    MiningSaveRepository.saveKey: '{not-valid-json',
  });

  expect(await MiningSaveRepository().hasSave(), isTrue);
});
```

Run:

```bash
flutter test test/mining/mining_save_repository_test.dart
```

Expected: FAIL because `hasSave()` does not exist.

- [ ] **Step 2: Implement the presence-only query.**

Use the existing repository key:

```dart
Future<bool> hasSave() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(saveKey);
}
```

Do not call `_decode`, `jsonDecode`, or any legacy save API here.

- [ ] **Step 3: Rewrite menu tests RED for the mining-only product.**

At both 360×640 and 430×932 prove:

```text
no mining save / legacy-only keys -> START MINING
mining key present                -> CONTINUE MINING
primary CTA opens MiningScreen
START EXPEDITION absent
MINING MVP absent
TRADE absent
STELLAR MAP absent
RESEARCH LAB absent
no overflow / uncaught exception
```

Reuse a valid mining save fixture for the valid-save case; use malformed mining JSON separately to prove label presence does not parse.

- [ ] **Step 4: Replace city bootstrap in `MainMenu`.**

Remove imports/state/helpers for:

```text
Planet
ActivePlanet
SaveService
MainGameWidget
TradePage
city placeholder routes
```

Keep the existing simple presentation/starfield if useful. Resolve the CTA label from `MiningSaveRepository.hasSave()` and navigate with the existing pattern:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const MiningScreen()),
);
```

Do not add a router abstraction.

- [ ] **Step 5: Update `test/widget_test.dart`.**

Keep global error-handler assertions. Replace city-menu copy assertions with mining landing assertions.

- [ ] **Step 6: Verify GREEN.**

```bash
flutter test test/mining/mining_save_repository_test.dart
flutter test test/main_menu_test.dart test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit the startup cutover.**

```bash
git add lib/main_menu.dart lib/mining/mining_save_repository.dart \
  test/main_menu_test.dart test/widget_test.dart \
  test/mining/mining_save_repository_test.dart
git commit -m "feat: make mining the primary product entry"
```

---

## Task 3: Preserve Audio and Add a Mining-Owned Settings Surface

**Files:**
- Create: `lib/mining/presentation/mining_settings_sheet.dart`
- Create: `test/support/fake_background_music_player.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Modify: `test/game/audio_manager_test.dart`
- Keep unchanged unless a test proves otherwise: `lib/game/audio_manager.dart`
- Keep: `lib/game/background_music_player.dart`
- Keep metrics-only: `lib/mining/presentation/mining_status_bar.dart`

**Interfaces:**
- `MiningScreen(..., AudioManager? audioManager)` is the only new production test seam.
- Production constructs `AudioManager()` when no dependency is injected.
- Existing `AudioManager` remains the owner of `audio.musicEnabled` and `audio.musicVolume`.

- [ ] **Step 1: Extract the existing fake player without changing behavior.**

Move the current `FakeBackgroundMusicPlayer implements BackgroundMusicPlayer` from `test/game/audio_manager_test.dart` into:

```text
test/support/fake_background_music_player.dart
```

Import the helper back into `audio_manager_test.dart`. This is test-fixture reuse, not a production abstraction.

Run:

```bash
flutter test test/game/audio_manager_test.dart
```

Expected: PASS unchanged.

- [ ] **Step 2: Add RED MiningScreen audio/settings tests.**

Construct the real manager around the shared fake:

```dart
final player = FakeBackgroundMusicPlayer();
final audio = AudioManager(backgroundMusicPlayer: player);
await tester.pumpWidget(
  MaterialApp(home: MiningScreen(audioManager: audio)),
);
```

Cover:

```text
saved audio prefs are loaded during screen initialization
no BGM starts merely from initialization
first sector/tab selection can call maybeStartBgm once
primary action can trigger the same first-user-gesture path
opening Settings can trigger the same first-user-gesture path
settings shows current Music and Volume values
switch/slider delegate to the same AudioManager
reopening settings reflects updated manager state
MediaQuery.disableAnimations still controls reduced motion
settings/status UI does not overflow at 360×640 or 430×932
```

Run:

```bash
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: FAIL because there is no injection/settings/start wiring.

- [ ] **Step 3: Inject the existing AudioManager.**

Change the widget seam minimally:

```dart
class MiningScreen extends StatefulWidget {
  const MiningScreen({
    super.key,
    this.content,
    this.repository,
    this.nowUtc,
    this.audioManager,
  });

  final AudioManager? audioManager;
}
```

In state:

```dart
late final AudioManager _audioManager;

@override
void initState() {
  super.initState();
  _audioManager = widget.audioManager ?? AudioManager();
  // existing mining setup...
}
```

Do not create another audio singleton or settings service.

- [ ] **Step 4: Load preferences as part of mining initialization.**

Before the screen exposes settings state:

```dart
Future<void> _initialize() async {
  await _audioManager.loadPrefs();
  await _controller.initialize();
  // existing pending-summary / refresh path...
}
```

`AudioManager.loadPrefs()` already handles preference read errors internally; do not add a second recovery system.

- [ ] **Step 5: Reuse existing gestures for web-safe BGM start.**

Call:

```dart
unawaited(_audioManager.maybeStartBgm());
```

from the existing gesture paths only:

```text
_selectSector(...)
_onPrimaryAction()
_openSettings()
```

Do not add `onUserInteracted`, a global pointer listener, polling, or autoplay during initialization.

- [ ] **Step 6: Add the small settings sheet.**

`MiningSettingsSheet` renders only:

```text
Audio
  Music [switch]
  Volume [slider]

Accessibility
  Reduced motion follows system setting
```

Use the same modal pattern already used for offline return:

```dart
return showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => MiningSettingsSheet(...),
);
```

The sheet reads/updates the existing `AudioManager`; do not write audio settings into `MiningSave`.

- [ ] **Step 7: Place Settings outside the metric row.**

In `MiningScreen`'s existing root `Stack`, add a separate `Positioned` + `SafeArea` control as a sibling to the status/tabs overlay. Keep `MiningStatusBar` unchanged and metrics-only.

The button should have a stable key such as:

```dart
const Key('mining-settings-button')
```

and a primary touch target of at least 48 logical px.

- [ ] **Step 8: Verify GREEN.**

```bash
flutter test test/game/audio_manager_test.dart
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: PASS, including first-gesture playback and both portrait sizes.

- [ ] **Step 9: Commit audio/settings.**

```bash
git add lib/mining/presentation/mining_screen.dart \
  lib/mining/presentation/mining_settings_sheet.dart \
  test/mining/presentation/mining_screen_test.dart \
  test/game/audio_manager_test.dart test/support/fake_background_music_player.dart
git commit -m "feat: preserve mining audio and settings"
```

---

## Task 4: Sever the Terrain → Grid Dependency

**Files:**
- Modify: `lib/game/terrain/parallax_terrain_component.dart`
- Modify: `lib/mining/world/mining_game.dart`
- Modify: `test/game/terrain/parallax_terrain_component_test.dart`
- Modify if needed: `test/mining/world/mining_game_test.dart`

**Interfaces:**
- `ParallaxTerrainComponent({required int gridSize, int? seed, double cellSize = 50})`.
- `MiningGame` passes `MiningContentRegistry.terrainCellSize` explicitly.
- `ParallaxTerrainLayer` remains unchanged and receives width/height from the component.

- [ ] **Step 1: Add RED explicit-cell-size coverage.**

Add a focused test using a non-50 cell size:

```dart
final terrain = ParallaxTerrainComponent(
  gridSize: 4,
  cellSize: 32,
  seed: 1,
);
```

After load, assert the component/layer extent is 128×128 rather than depending on Grid constants.

Run:

```bash
flutter test test/game/terrain/parallax_terrain_component_test.dart
```

Expected: FAIL because `cellSize` is not accepted.

- [ ] **Step 2: Remove the Grid import and use the constructor value.**

Replace:

```dart
import '../grid.dart';
```

with local state:

```dart
final double cellSize;

ParallaxTerrainComponent({
  required this.gridSize,
  int? seed,
  this.cellSize = 50,
}) : generator = TerrainGenerator(gridSize: gridSize, seed: seed ?? 42);
```

Use `cellSize` for:

```text
component size
debug cell rectangles
debug centers
ParallaxTerrainLayer.cellWidth
ParallaxTerrainLayer.cellHeight
child layer size
```

Do not introduce a terrain config object/framework.

- [ ] **Step 3: Make MiningGame pass its existing world contract.**

```dart
ParallaxTerrainComponent(
  gridSize: MiningContentRegistry.terrainGridSize,
  cellSize: MiningContentRegistry.terrainCellSize,
  seed: 631,
)
```

- [ ] **Step 4: Verify terrain/mining world GREEN and no Grid import.**

```bash
flutter test test/game/terrain/parallax_terrain_component_test.dart
flutter test test/mining/world/mining_game_test.dart
rg "grid.dart" lib/game/terrain/parallax_terrain_component.dart
```

Expected: tests PASS; grep returns no match.

- [ ] **Step 5: Commit the deletion blocker fix.**

```bash
git add lib/game/terrain/parallax_terrain_component.dart \
  lib/mining/world/mining_game.dart \
  test/game/terrain/parallax_terrain_component_test.dart \
  test/mining/world/mining_game_test.dart
git commit -m "refactor: decouple mining terrain from city grid"
```

---

## Task 5: Delete the City Runtime, Then Slim Resource Identity and Dependencies

**Files:**
- Delete: obsolete city production/tests discovered below.
- Modify after city consumers are gone: `lib/game/resources/resource_type.dart`
- Modify: `pubspec.yaml`
- Modify generated: `pubspec.lock`
- Keep: `lib/game/audio_manager.dart`
- Keep: `lib/game/background_music_player.dart`
- Keep retained parallax terrain files.

**Important ordering:** There is **no standalone ResourceType slimming task before deletion**. `ResourceRegistry`, the product enums, and extra `ResourceType` values remain temporarily because live city code still imports them. Delete those consumers first; then simplify the identity file in this same task.

### Production deletion seeds

```text
lib/game/achievements/**
lib/game/building/**
lib/game/debug/**
lib/game/managers/**
lib/game/planet/**
lib/game/production/**
lib/game/quests/**
lib/game/research/**
lib/game/services/**

lib/game/grid.dart
lib/game/main_game.dart
lib/game/scene.dart
lib/game/scene_widget.dart

lib/game/resources/resource_category.dart
lib/game/resources/resource_cost.dart
lib/game/resources/resources.dart

lib/game/terrain/index.dart
lib/game/terrain/terrain_component.dart
lib/game/terrain/terrain_layer.dart

lib/pages/**
lib/widgets/**
```

Retain this production boundary unless a direct mining import proves another file is required:

```text
lib/game/audio_manager.dart
lib/game/background_music_player.dart
lib/game/resources/resource_type.dart
lib/game/terrain/parallax_terrain_component.dart
lib/game/terrain/parallax_terrain_layer.dart
lib/game/terrain/terrain_assets.dart
lib/game/terrain/terrain_biome.dart
lib/game/terrain/terrain_depth_manager.dart
lib/game/terrain/terrain_generator.dart
```

### Test deletion seeds

```text
test/achievements/**
test/building/**
test/managers/**
test/pages/**
test/performance/**
test/planet/**
test/quests/**
test/research/**
test/services/**
test/widgets/**

test/game/grid_test.dart
test/game/main_game_test.dart
test/game/scene_widget_test.dart
test/game/production/**
test/game/quests/**

test/integration/planet_grid_integration_test.dart
test/integration/planet_placement_persistence_test.dart

test/scene_test.dart
```

For `test/resources/**`, retain only the post-cutover ResourceType identity coverage. For `test/game/terrain/**`, retain only tests for the parallax terrain dependency graph. Keep `test/game/audio_manager_test.dart`.

- [ ] **Step 1: Delete one coherent city group and its tests at a time.**

Suggested groups:

```text
A. pages/widgets + main scene/menu dependencies already removed by Task 2
B. achievements/quests/research/production
C. building/grid/managers/planet/services/resources
D. obsolete non-parallax terrain files
```

After each group, run:

```bash
flutter analyze --fatal-infos
```

If analysis names another city-only consumer/test, delete it with its owning group instead of adding a compatibility stub.

- [ ] **Step 2: Use search as closure, not only path lists.**

After deletion groups, run:

```bash
rg "Planet|ActivePlanet|SaveService|MainGameWidget|MainGame|BuildingRegistry|GameStateManager|QuestManager|AchievementManager|ResearchManager|TradePage" lib test --glob '*.dart'
rg "package:horologium/(pages|widgets)/|package:horologium/game/(building|planet|production|quests|research|services|managers)/" lib test --glob '*.dart'
```

Investigate each remaining match. Historical planning docs are out of this production/test grep scope.

- [ ] **Step 3: Only now slim `ResourceType`.**

After city consumers are absent, replace `lib/game/resources/resource_type.dart` with the identity-only surface:

```dart
enum ResourceType { gold, coal, stone }
```

Delete from that file:

```text
Resource
ResourceRegistry
BakeryProduct
KitchenProduct
CropType
resource_category.dart import
```

Rewrite `test/resources/resource_type_test.dart` to assert only the surviving enum contract and keep `test/mining/mining_content_test.dart` as the stronger consumer proof.

Run:

```bash
flutter test test/resources/resource_type_test.dart test/mining/mining_content_test.dart
```

Expected: PASS.

- [ ] **Step 4: Remove packages whose only consumers were deleted.**

From `pubspec.yaml`, remove:

```yaml
flame_audio: ^2.0.6
uuid: ^4.5.1
```

Keep:

```yaml
audioplayers: ^6.0.0
```

Then regenerate:

```bash
flutter pub get
```

Confirm no source consumer remains:

```bash
rg "package:uuid|package:flame_audio" lib test
```

Expected: no matches.

- [ ] **Step 5: Run analysis and the surviving full suite.**

```bash
flutter analyze --fatal-infos
flutter test
```

Expected: PASS with a substantially smaller suite.

- [ ] **Step 6: Commit the retirement as one coherent deletion commit.**

```bash
git add -A
git commit -m "refactor: remove obsolete city runtime"
```

---

## Task 6: Make Active Guidance and Speckit Governance Mining-First

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `.github/copilot-instructions.md`
- Modify: `.windsurf/rules/project.md`
- Modify: `.specify/memory/constitution.md`
- Do not separately edit: `AGENTS.md` symlink target relationship.

- [ ] **Step 1: Update product/architecture guidance.**

Replace city-builder descriptions with the actual runtime:

```text
MainMenu
  -> MiningScreen
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
      -> MiningGame
          -> ParallaxTerrainComponent
```

Document:

```text
cash-only mining loop
strict unversioned horologium.mining.save
Flutter owns HUD/sheets/lifecycle
Flame owns world/camera/effects
audio preferences stay in AudioManager SharedPreferences keys
ResourceType is identity only
legacy city keys are ignored
```

Remove active instructions for adding city buildings, workers, research trees, quests, production chains, `Planet`, or `SaveService`.

- [ ] **Step 2: Amend the active Speckit constitution instead of calling it historical.**

This is a breaking governance change, so bump:

```text
1.0.0 -> 2.0.0
```

Replace city-specific non-negotiables with concise current principles:

```text
I. Flutter/Flame ownership separation
II. Mining content/state separation and one mining mutation boundary
III. Strict unversioned mining persistence until a shipped compatibility need exists
IV. Deterministic test-first behavior for economy/persistence
V. Asset-backed presentation with graceful development fallbacks
```

Remove mandates for:

```text
MainGameWidget / MainGame
BuildingRegistry / ResourceRegistry / Research.availableResearch
city SharedPreferences key layout
one-second economy mutation timer
50×50 placement grid
```

Retain quality gates (`format`, `analyze`, `test`, target verification) and update the constitution Sync Impact Report/date.

- [ ] **Step 3: Leave historical design docs untouched.**

Do not rewrite old city specs/plans under `docs/`; they are historical records, unlike the active constitution and contributor guidance.

- [ ] **Step 4: Search active guidance for stale city mandates.**

```bash
rg "MainGameWidget|BuildingRegistry|ResourceRegistry|worker assignment|50x50|50×50|production chain|SaveService" \
  README.md CLAUDE.md .github/copilot-instructions.md \
  .windsurf/rules/project.md .specify/memory/constitution.md
```

Expected: no stale city requirement. A historical contrast sentence is acceptable only if clearly marked as removed/legacy.

- [ ] **Step 5: Commit documentation/governance.**

```bash
git add README.md CLAUDE.md .github/copilot-instructions.md \
  .windsurf/rules/project.md .specify/memory/constitution.md
git commit -m "docs: make repository guidance mining-first"
```

---

## Task 7: Verify the Complete Cutover Contract

**Files:** modify only if verification exposes a real HPA-636 regression.

- [ ] **Step 1: Format and analyze.**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: PASS.

- [ ] **Step 2: Run focused startup/save/audio/settings/mining coverage.**

```bash
flutter test test/main_menu_test.dart
flutter test test/mining/mining_save_repository_test.dart
flutter test test/game/audio_manager_test.dart
flutter test test/mining/presentation/mining_screen_test.dart
flutter test test/mining/world/mining_game_test.dart
flutter test test/integration/mining_mvp_journey_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run the full surviving suite.**

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 4: Prove the retired production domains are gone.**

```bash
rg "Planet|ActivePlanet|SaveService|MainGameWidget|BuildingRegistry|GameStateManager|QuestManager|AchievementManager|ResearchManager|TradePage" lib --glob '*.dart'
rg "package:uuid|package:flame_audio" lib test
```

Expected: no retired production/package references. Review any generic word match such as "building" in asset names rather than blindly deleting valid mining assets.

- [ ] **Step 5: Build representative targets.**

```bash
flutter build apk --debug
flutter build web
```

Expected: both succeed.

- [ ] **Step 6: Verify three startup scenarios.**

Run the app with:

```text
A. no save keys
   -> START MINING
   -> clean Landing Basin

B. legacy city keys only
   -> START MINING
   -> same clean Landing Basin
   -> legacy keys do not cause migration/recovery UI

C. existing horologium.mining.save
   -> CONTINUE MINING
   -> persisted cash/sectors/mines/cargo restored
   -> offline summary appears when elapsed time warrants it
```

Also verify one malformed mining save still enters the existing non-blocking recovery path.

- [ ] **Step 7: Verify audio/accessibility on the product path.**

On a supported interactive target:

```text
launch does not violate autoplay policy
first mining/settings gesture starts BGM when enabled
Music switch and Volume slider work
pause/resume lifecycle still affects active BGM
reduced-motion system setting preserves clear action confirmation
settings control and status metrics remain usable in narrow portrait
```

- [ ] **Step 8: Record HPA-636 closeout evidence.**

Record:

```text
reviewed commit
physical target used for pre-code gate
fresh / legacy-only / existing-save launch results
format/analyze/test results
APK/web build results
dependency grep result
confirmation that city keys were ignored rather than migrated
```

HPA-636 is ready to merge only when all acceptance criteria are represented by this evidence.
