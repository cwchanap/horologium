# HPA-636 Production Mining Cutover Implementation Plan

> **For agentic workers:** use the repository's normal test-first workflow and implement this plan task-by-task on the existing HPA-636 branch/PR.

**Goal:** Make the validated one-planet mining MVP Horologium's only player-facing product, preserve save/offline/audio/accessibility behavior, and delete the obsolete city runtime without adding migration or compatibility machinery.

**Architecture:** `MainMenu` becomes a minimal mining-only landing shell. `MiningScreen` owns Flutter lifecycle/HUD/settings, `MiningController` remains the mutation/persistence boundary, and `MiningGame` remains the Flame world. Generic audio/resource-identity/parallax-terrain infrastructure stays under `lib/game/` only where mining has a concrete consumer.

**Spec:** `docs/superpowers/specs/2026-08-20-hpa-636-production-mining-cutover-design.md`

## Global constraints

- One task, one PR: continue on `jack65786656/hpa-636-cut-over-to-the-mining-only-product` / PR #15.
- HPA-631's final Linear conclusion says to run the real-device visual pass **before starting cutover**. Keep that as the production-code gate; do not relax it inside HPA-636.
- Preserve the strict unversioned `horologium.mining.save` payload. No version, migration, city import, backup, camera/selection field, or compatibility branch.
- Legacy city keys are ignored, not migrated or eagerly deleted.
- No new router, Provider/Riverpod/Bloc, service locator, settings service, feature flag, audio singleton, or terrain config framework.
- `MediaQuery.disableAnimations` remains the only reduced-motion source.
- Do not purge binary city assets unless a build/declaration failure requires it.
- Delete tests with retired production code instead of preserving dead behavior.
- `README.md` is a product README, `CLAUDE.md` is detailed repository guidance, and `.specify/memory/constitution.md` is governance; do not make them hand-maintained copies of one another.
- Do not move surviving generic `lib/game/**` infrastructure merely to erase the directory name.

## File map

### Create

```text
lib/mining/presentation/mining_settings_sheet.dart
test/support/fake_background_music_player.dart
```

### Modify

```text
lib/main.dart
lib/main_menu.dart
lib/mining/mining_save_repository.dart
lib/mining/presentation/mining_screen.dart
lib/mining/presentation/offline_return_sheet.dart
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

Delete city production/tests in Task 5. The lists below are discovery seeds, not an allowlist; static analysis/search owns final closure.

---

## Task 1: Close the HPA-631 physical-device gate

**Files:** none.

- [ ] Run the merged HPA-631 mining MVP on one supported physical phone in portrait.
- [ ] Check at minimum:

```text
level 1 / 3 / 5 mine structures visibly distinct
reveal/build/upgrade/sale feedback legible
narrow portrait controls usable
no product-blocking visual issue invalidates Proceed to cutover
```

- [ ] Record the result on HPA-636 before any production-code task below starts.

If the pass exposes a product-blocking issue, fix/reconsider HPA-631 instead of hiding a redesign inside cutover.

---

## Task 2: Make startup mining-only, distinguish Start/Continue, and honor reduced motion

**Files:**
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/main_menu.dart`
- Modify: `lib/main.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Rewrite: `test/main_menu_test.dart`
- Modify: `test/widget_test.dart`

### Step 1 — RED: save-presence behavior

Add cases for:

```text
empty prefs                         -> hasSave == false
legacy city keys only              -> hasSave == false
valid mining key present           -> hasSave == true
malformed mining key present       -> hasSave == true
```

The malformed case proves menu labeling is presence-only and does not duplicate decoding.

Run:

```bash
flutter test test/mining/mining_save_repository_test.dart
```

Expected RED: `hasSave()` does not exist.

### Step 2 — GREEN: add the smallest presence query

Implement on the existing repository:

```dart
Future<bool> hasSave() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(saveKey);
}
```

Do not call `_decode`, `jsonDecode`, or city save APIs.

### Step 3 — RED: mining-only landing tests at both viewports

Use 360×640 and 430×932 and cover:

```text
fresh / legacy-only -> START MINING
mining key present  -> CONTINUE MINING
primary CTA opens MiningScreen
START EXPEDITION absent
MINING MVP absent
TRADE absent
STELLAR MAP absent
RESEARCH LAB absent
no overflow / uncaught exception
```

Reuse a valid serialized mining fixture for the existing-save case.

### Step 4 — RED: launch-screen reduced motion

Pump `MainMenu` under:

```dart
MediaQueryData(disableAnimations: true)
```

Make the test capable of detecting motion, not merely overflow. Add a stable key to the starfield (for example `main-menu-starfield`) and assert:

- no `FloatingParticle` widgets are rendered when reduced motion is on;
- the starfield painter's animation value remains unchanged across a meaningful pump interval;
- title/CTA are already in their settled presentation state.

Expected RED: current `MainMenu` unconditionally repeats the starfield and does not consult `disableAnimations`.

### Step 5 — replace city bootstrap and animation startup

Remove from `MainMenu`:

```text
Planet
ActivePlanet
SaveService
MainGameWidget
TradePage
city placeholder routes
```

Keep only the mining landing presentation and use existing `Navigator` + `MaterialPageRoute` to open `MiningScreen`.

Do not start continuous/entrance animation blindly in `initState`. Read `MediaQuery.disableAnimations` in a lifecycle point that has inherited widgets available (for example `didChangeDependencies`) and only start decorative animation when allowed.

When reduced motion is true:

```text
starfield = stable frame
floating particles = absent
entrance title/button movement = settled immediately
```

When false, retain the existing lightweight presentation.

Update `lib/main.dart` product title away from `Horologium - Space Explorer` to mining-first product copy.

### Step 6 — update app smoke test

Keep global error-handler coverage in `test/widget_test.dart`, but replace city-menu assertions with mining landing assertions.

### Step 7 — verify Task 2

```bash
flutter test test/mining/mining_save_repository_test.dart
flutter test test/main_menu_test.dart test/widget_test.dart
```

Expected: PASS.

Commit only the Task 2 paths.

---

## Task 3: Preserve audio and add a mining-owned settings surface with honest geometry

**Files:**
- Create: `lib/mining/presentation/mining_settings_sheet.dart`
- Create: `test/support/fake_background_music_player.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Modify: `test/game/audio_manager_test.dart`
- Keep unless tests prove otherwise: `lib/game/audio_manager.dart`
- Keep: `lib/game/background_music_player.dart`
- Keep metrics-only: `lib/mining/presentation/mining_status_bar.dart`

### Step 1 — move, do not rewrite, the existing fake player

Extract `FakeBackgroundMusicPlayer` from `test/game/audio_manager_test.dart` into:

```text
test/support/fake_background_music_player.dart
```

Import it back and run:

```bash
flutter test test/game/audio_manager_test.dart
```

Expected: PASS unchanged.

### Step 2 — RED: audio/settings behavior

Add an optional `AudioManager` test seam to the helper used by `mining_screen_test.dart`, then write cases using the real manager around the shared fake:

```dart
final player = FakeBackgroundMusicPlayer();
final audio = AudioManager(backgroundMusicPlayer: player);
```

Cover:

```text
saved prefs loaded during MiningScreen initialization
initialization alone does not start BGM
sector/tab gesture can start BGM
primary action can start BGM
opening Settings can start BGM
Music/Volume reflect current manager state
switch/slider delegate to AudioManager
reopening sheet reflects changed values
MediaQuery.disableAnimations still controls mining rewards/world behavior
```

Expected RED: injection/settings/load/start wiring do not exist.

### Step 3 — RED: settings placement must not overlap

Give the tab strip a stable key such as:

```dart
const Key('mining-sector-tabs')
```

and the settings button:

```dart
const Key('mining-settings-button')
```

At **both** 360×640 and 430×932 assert:

```dart
final button = tester.getRect(find.byKey(const Key('mining-settings-button')));
expect(
  button.overlaps(tester.getRect(find.byKey(const Key('mining-status-bar')))),
  isFalse,
);
expect(
  button.overlaps(tester.getRect(find.byKey(const Key('mining-sector-tabs')))),
  isFalse,
);
```

Also retain overflow/uncaught-exception checks. The rectangle assertions are required because independently positioned siblings can overlap while Flutter reports no overflow.

### Step 4 — inject the existing AudioManager

Add only:

```dart
final AudioManager? audioManager;
```

to `MiningScreen` alongside its existing optional content/repository/clock seams.

State owns:

```dart
_audioManager = widget.audioManager ?? AudioManager();
```

No settings service or second singleton.

### Step 5 — load prefs and reuse existing gestures

During `_initialize()`:

```dart
await _audioManager.loadPrefs();
await _controller.initialize();
```

Reuse only existing user gesture paths for:

```dart
unawaited(_audioManager.maybeStartBgm());
```

in:

```text
_selectSector(...)
_onPrimaryAction()
_openSettings()
```

Do not add a global user-interaction callback/listener.

### Step 6 — add the small settings sheet

Reuse the switch/slider interaction pattern from the existing city hamburger menu where convenient, but create a mining-owned sheet because the city widget imports quests/research/trade/grid/planet surfaces.

Sheet contents:

```text
Audio
  Music [switch]
  Volume [slider]

Accessibility
  Reduced motion follows system setting
```

Present it with the same `showModalBottomSheet` pattern used by `OfflineReturnSheet`.

### Step 7 — place Settings below the tabs in layout flow

Keep `MiningStatusBar` unchanged and metrics-only.

In the existing top `SafeArea > Column`, place the 48px+ settings control **after** the horizontal tab strip and align it right. This floats it over game-world space while letting the layout system guarantee it is below status/tabs.

Do not use a separate top-right `Positioned` sibling over the same HUD rectangle.

### Step 8 — verify Task 3

```bash
flutter test test/game/audio_manager_test.dart
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: PASS, including explicit non-overlap at both portrait sizes.

Commit only Task 3 paths.

---

## Task 4: Sever terrain from the city Grid with one required source of truth

**Files:**
- Modify: `lib/game/terrain/parallax_terrain_component.dart`
- Modify: `lib/mining/world/mining_game.dart`
- Modify: `test/game/terrain/parallax_terrain_component_test.dart`
- Modify: `test/mining/world/mining_game_test.dart`
- Modify if current invariant coverage belongs there: `test/mining/mining_content_test.dart`

### Step 1 — RED: required explicit cell-size seam

Add a component test with a non-50 value:

```dart
final terrain = ParallaxTerrainComponent(
  gridSize: 4,
  cellSize: 32,
  seed: 1,
);
```

After load, assert component/layer extent is 128×128 and debug geometry uses the same cell size.

Expected RED: constructor does not accept `cellSize`.

### Step 2 — make `cellSize` required and delete the Grid import

Use:

```dart
ParallaxTerrainComponent({
  required this.gridSize,
  required this.cellSize,
  int? seed,
})
```

No `= 50` default. After city deletion there is one production caller and the mining content registry already owns the value.

Remove:

```dart
import '../grid.dart';
```

Use `cellSize` for component size, debug rectangles/centers, and child `ParallaxTerrainLayer` dimensions.

### Step 3 — MiningGame passes the mining contract and stops overriding size

Construct with:

```dart
ParallaxTerrainComponent(
  gridSize: MiningContentRegistry.terrainGridSize,
  cellSize: MiningContentRegistry.terrainCellSize,
  seed: 631,
)
```

Remove:

```dart
..size = Vector2.all(MiningContentRegistry.worldExtent)
```

Keep the existing anchor/position/parallax settings.

### Step 4 — integration proof

Ensure retained mining tests prove:

```text
terrainGridSize * terrainCellSize == worldExtent
mounted MiningGame terrain size == worldExtent
no caller can omit cellSize
```

This prevents a wrong cell size being masked by a later size assignment.

### Step 5 — verify Task 4

```bash
flutter test test/game/terrain/parallax_terrain_component_test.dart
flutter test test/mining/world/mining_game_test.dart
flutter test test/mining/mining_content_test.dart
rg "grid.dart" lib/game/terrain/parallax_terrain_component.dart
```

Expected: tests PASS; grep has no match.

Commit only Task 4 paths.

---

## Task 5: Delete the city runtime, then slim ResourceType and dead dependencies

**Gate:** Task 1 must be recorded before this task; in practice Tasks 2–4 are also behind Task 1 because HPA-631 explicitly gates **starting cutover**, not only deletion.

**Files:**
- Delete obsolete city production/tests.
- Modify after city consumers are gone: `lib/game/resources/resource_type.dart`
- Modify after enum slim: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`

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

Retain generic shared runtime only where mining imports it:

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

Do not move these merely because old city files used to share the directory.

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

The lists are not exhaustive. Use analysis/search after each deletion group.

### Step 1 — delete in coherent groups

Suggested sequence:

```text
A. pages/widgets + scene entry code already disconnected by Task 2
B. achievements/quests/research/production
C. building/grid/managers/planet/services/city resources
D. obsolete non-parallax terrain
```

After each group:

```bash
flutter analyze --fatal-infos
```

Delete dangling city-only consumers/tests instead of adding compatibility stubs.

### Step 2 — prove city dependency closure

```bash
rg "Planet|ActivePlanet|SaveService|MainGameWidget|MainGame|BuildingRegistry|GameStateManager|QuestManager|AchievementManager|ResearchManager|TradePage" lib test --glob '*.dart'
rg "package:horologium/(pages|widgets)/|package:horologium/game/(building|planet|production|quests|research|services|managers)/" lib test --glob '*.dart'
```

Investigate every match.

### Step 3 — only now slim ResourceType

Replace the surviving identity file with:

```dart
enum ResourceType { gold, coal, stone }
```

Remove:

```text
Resource
ResourceRegistry
BakeryProduct
KitchenProduct
CropType
resource_category.dart import
```

Rewrite resource identity tests to cover only the mining enum and keep `mining_content_test.dart` as a consumer proof.

### Step 4 — make offline-return resource switches exhaustive

In `lib/mining/presentation/offline_return_sheet.dart`, remove both now-unreachable `default:` branches from:

```text
_resourceName
_resourceColor
```

The three-value enum should be exhaustive so adding a future mining resource requires an explicit presentation decision.

Run:

```bash
flutter test test/resources/resource_type_test.dart test/mining/mining_content_test.dart
flutter test test/mining/presentation/mining_screen_test.dart
```

### Step 5 — remove packages whose only consumers died

Remove from `pubspec.yaml`:

```yaml
flame_audio: ^2.0.6
uuid: ^4.5.1
```

Keep:

```yaml
audioplayers: ^6.0.0
```

Then:

```bash
flutter pub get
rg "package:uuid|package:flame_audio" lib test
```

Expected: no source matches.

### Step 6 — verify deletion pass

```bash
flutter analyze --fatal-infos
flutter test
```

Expected: PASS with a substantially smaller suite.

Commit the retirement as one coherent deletion/resource/dependency commit; stage only the reviewed Task 5 paths.

---

## Task 6: Make product guidance/governance mining-first without maintaining four copies

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `.github/copilot-instructions.md`
- Modify: `.windsurf/rules/project.md`
- Modify: `.specify/memory/constitution.md`
- Do not separately fork: `AGENTS.md`

### Step 1 — replace the stock README with a real product README

`README.md` is currently a Flutter starter stub, so do **not** describe this as replacing city architecture text.

Make it concise and product-facing:

```text
Horologium = casual stellar mining idle
core loop = reveal -> build -> mine -> sell -> upgrade
how to run/test/build
where the mining vertical slice lives
local .opencode/command symlink note
```

Do not duplicate the detailed architecture manual.

### Step 2 — make CLAUDE.md the detailed repository guidance source

Replace city architecture/workflows with the actual post-cutover ownership boundary:

```text
MainMenu
  -> MiningScreen
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
      -> MiningGame
          -> ParallaxTerrainComponent
```

Document strict unversioned save, audio ownership, reduced-motion source, resource identity, and current test/build conventions.

`AGENTS.md` already follows `CLAUDE.md`; do not create another maintained body.

### Step 3 — collapse Windsurf duplication

Reduce `.windsurf/rules/project.md` to its required frontmatter plus a concise instruction to read/follow the authoritative `../../CLAUDE.md`.

Example shape:

```markdown
---
trigger: always_on
---

Follow the repository guidance in `../../CLAUDE.md` as the authoritative architecture and workflow source.
```

### Step 4 — keep Copilot instructions thin and self-contained

Do **not** turn `.github/copilot-instructions.md` into another full architecture copy.

Also do not rely on a symlink for this special GitHub instruction path unless implementation-time tool verification proves all targeted Copilot surfaces resolve it. GitHub documents `.github/copilot-instructions.md` as the repository-wide instruction file, while support for agent instruction files varies by surface.

Keep a concise compatibility shim containing only the critical repo-wide rules, for example:

```text
Horologium is a Flutter/Flame mining-idle game.
Use lib/mining as the gameplay vertical slice.
Preserve strict unversioned horologium.mining.save unless a shipped compatibility need exists.
Do not reintroduce city domains or speculative frameworks.
Run format/analyze/tests for changes.
Detailed architecture/workflow guidance lives in ../CLAUDE.md.
```

This removes the hand-maintained fork while keeping the documented Copilot entrypoint meaningful.

### Step 5 — amend the active Speckit constitution

This is a breaking governance change:

```text
1.0.0 -> 2.0.0
```

Replace city-specific mandates with concise current principles:

```text
I. Flutter/Flame ownership separation
II. Mining content/state separation and one mutation boundary
III. Strict unversioned mining persistence until a shipped compatibility need exists
IV. Deterministic test-first economy/persistence behavior
V. Asset-backed presentation with development fallbacks
```

Remove mandatory references to:

```text
MainGameWidget / MainGame
BuildingRegistry / ResourceRegistry / Research.availableResearch
city SharedPreferences key layout
one-second city economy mutation timer
50×50 placement grid
```

Retain format/analyze/test/target-verification quality gates and update the constitution Sync Impact Report/date.

### Step 6 — search active guidance

```bash
rg "MainGameWidget|BuildingRegistry|ResourceRegistry|worker assignment|50x50|50×50|production chain|SaveService" \
  README.md CLAUDE.md .github/copilot-instructions.md \
  .windsurf/rules/project.md .specify/memory/constitution.md
```

Expected: no stale city requirement. A clearly marked historical/removal sentence is acceptable.

Commit only the guidance/governance paths.

---

## Task 7: Verify the complete cutover contract

Modify production/tests only if this verification exposes a real HPA-636 regression.

### Step 1 — format and analyze

```bash
dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: PASS.

### Step 2 — focused product coverage

```bash
flutter test test/main_menu_test.dart
flutter test test/mining/mining_save_repository_test.dart
flutter test test/game/audio_manager_test.dart
flutter test test/mining/presentation/mining_screen_test.dart
flutter test test/game/terrain/parallax_terrain_component_test.dart
flutter test test/mining/world/mining_game_test.dart
flutter test test/mining/mining_content_test.dart
flutter test test/integration/mining_mvp_journey_test.dart
```

Expected: PASS.

### Step 3 — full surviving suite

```bash
flutter test
```

Expected: PASS.

### Step 4 — retired-domain/package proof

```bash
rg "Planet|ActivePlanet|SaveService|MainGameWidget|BuildingRegistry|GameStateManager|QuestManager|AchievementManager|ResearchManager|TradePage" lib --glob '*.dart'
rg "package:uuid|package:flame_audio" lib test
```

Expected: no retired production/package references.

### Step 5 — representative builds

```bash
flutter build apk --debug
flutter build web
```

Expected: both succeed.

### Step 6 — startup/save scenarios

Verify:

```text
A. no save keys
   -> START MINING
   -> clean Landing Basin

B. legacy city keys only
   -> START MINING
   -> same clean Landing Basin
   -> no migration/recovery caused by city data

C. existing horologium.mining.save
   -> CONTINUE MINING
   -> persisted cash/sectors/mines/cargo restore
   -> offline summary appears when warranted

D. malformed horologium.mining.save
   -> CONTINUE MINING label (presence-only)
   -> existing non-blocking recovery path starts fresh mining state
```

### Step 7 — audio/accessibility/layout target verification

On an interactive supported target verify:

```text
launch respects system reduced motion
first mining/settings gesture starts BGM when enabled
Music switch + Volume slider work
pause/resume lifecycle still affects BGM
settings button does not cover status/tabs
narrow portrait remains usable
```

### Step 8 — record closeout evidence on HPA-636

Record:

```text
reviewed commit
physical target/result for HPA-631 pre-code gate
fresh / legacy-only / existing / malformed launch results
format/analyze/test results
APK/web build results
dependency grep results
confirmation that city keys were ignored rather than migrated
```

HPA-636 is ready to merge only when each acceptance item has evidence.
