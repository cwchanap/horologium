# HPA-636 Production Mining Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the validated one-planet mining MVP Horologium's only player-facing product, preserve its save/offline/recovery behavior and mining-relevant settings, and delete the obsolete city runtime instead of leaving a dormant second architecture.

**Architecture:** Keep `MainMenu` as a minimal mining-only landing shell and `lib/mining/` as the gameplay vertical slice. `MiningScreen` owns Flutter lifecycle/settings UI, `MiningController` remains the mutation/persistence boundary, and `MiningGame` remains the Flame world. Reuse only audio, resource identity, assets, and the parallax terrain files with direct mining consumers. Remove accidental terrain/grid and resource-registry dependencies before deleting the city code.

**Tech Stack:** Dart 3.8+, Flutter 3.32.5, Flame 1.30, SharedPreferences 2.5, existing Flutter/Flame test infrastructure.

**Spec:** `docs/superpowers/specs/2026-08-20-hpa-636-production-mining-cutover-design.md`

## Global constraints

- Deliver HPA-636 in **one PR** on `jack65786656/hpa-636-cut-over-to-the-mining-only-product`; implementation continues on the same draft PR as this plan.
- HPA-631's final conclusion is **Proceed to cutover**, but run its requested real-device tier/reward visual pass before the first production cutover code change.
- Preserve the strict unversioned `horologium.mining.save` payload. Do not add a version, migration, camera/selection field, city import, backup, or compatibility branch.
- Legacy city keys are ignored, not migrated or eagerly deleted.
- Do not add Provider, Riverpod, Bloc, a service locator, a new router, a settings service, a feature flag, or a compatibility facade.
- Keep `MiningController`, `MiningSimulation`, and the existing HPA-631 first-planet rules unchanged unless a concrete HPA-636 blocker is demonstrated.
- Reduced motion continues to use `MediaQuery.disableAnimations`; do not add a competing preference.
- Keep unused binary city assets out of scope unless an asset declaration/build failure requires their deletion.
- Delete tests with retired production code instead of retaining production code solely to keep old tests green.

---

## Pre-implementation gate: close the HPA-631 real-device visual note

**Files:** none.

- [ ] **Step 1: Run the validated mining MVP on one supported physical phone in portrait.**

Check at minimum:

- level 1, 3, and 5 mine structures remain visibly distinct;
- reveal/build/upgrade/sale rewards remain legible;
- 360-ish narrow portrait interaction remains usable;
- no product-blocking visual issue appears that invalidates the HPA-631 Proceed decision.

- [ ] **Step 2: Record the result before touching production routing.**

If the result is acceptable, continue HPA-636. If it exposes a product-blocking regression, address/reconsider HPA-631 first rather than burying a redesign inside the cutover.

---

## Task 1: Make startup mining-only and distinguish Start from Continue

**Files:**
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/main_menu.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Rewrite: `test/main_menu_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- `MiningSaveRepository.hasSave()` answers only whether `horologium.mining.save` exists.
- `MainMenu` depends on that query and navigates only to `MiningScreen`.
- `MiningScreen` remains responsible for decoding/creating/recovering state.

- [ ] **Step 1: Add failing save-presence tests.**

Cover:

```text
empty prefs                         -> hasSave == false
legacy city keys only              -> hasSave == false
horologium.mining.save present      -> hasSave == true
```

Do not parse or validate the save in `hasSave()`; malformed-save handling remains `load()`'s responsibility.

- [ ] **Step 2: Implement the smallest `hasSave()` query.**

Keep the save key encapsulated by `MiningSaveRepository` and use `SharedPreferences.getInstance()` exactly as `load()`/`save()` already do.

- [ ] **Step 3: Rewrite the menu tests RED for the mining-only product.**

At 360×640 and 430×932, assert:

- fresh/legacy-only preferences show `START MINING`;
- a mining save shows `CONTINUE MINING`;
- no `START EXPEDITION`, `MINING MVP`, `TRADE`, `STELLAR MAP`, or `RESEARCH LAB` action exists;
- tapping the primary CTA opens the mining screen;
- no overflow/uncaught exception occurs.

Reuse a valid serialized save fixture from mining repository/integration tests rather than hand-inventing a second schema.

- [ ] **Step 4: Rewrite `MainMenu` as the mining landing shell.**

Remove:

```dart
Planet
ActivePlanet
SaveService
MainGameWidget
TradePage
city route helpers
```

Keep only product presentation with a single Start/Continue CTA. Existing starfield/theme helpers may stay if they remain simple and mining-facing; remove city-specific button/title/footer copy.

Do not add a routing abstraction. Use the existing `Navigator` + `MaterialPageRoute` pattern to open `MiningScreen`.

- [ ] **Step 5: Update the app smoke test.**

Keep the global error-handler coverage in `test/widget_test.dart`, but replace city-menu assertions with mining-only landing assertions.

- [ ] **Step 6: Run the focused tests.**

```bash
flutter test test/mining/mining_save_repository_test.dart
flutter test test/main_menu_test.dart test/widget_test.dart
```

Expected: PASS.

---

## Task 2: Move settings/audio reachability into the mining product

**Files:**
- Create: `lib/mining/presentation/mining_settings_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Keep: `lib/game/audio_manager.dart`
- Keep: `lib/game/background_music_player.dart`

- [ ] **Step 1: Add failing MiningScreen settings tests.**

Cover:

- a Settings affordance is reachable at 360×640 and 430×932;
- opening it exposes music enabled/disabled and volume controls;
- toggling/changing controls delegates to `AudioManager` and remains usable in portrait;
- the accessibility section states that reduced motion follows the system setting;
- `MediaQueryData(disableAnimations: true)` still produces the validated reduced-motion behavior;
- closing/reopening the sheet reflects the current audio state.

Prefer injecting or otherwise substituting the existing audio adapter only where the current test seam already supports it. Do not create a settings repository abstraction for the test.

- [ ] **Step 2: Add one small mining-owned settings sheet.**

The sheet owns presentation only. It receives the existing `AudioManager` (or callbacks/getters from `MiningScreen`) and renders:

```text
Audio
  Music [switch]
  Volume [slider]

Accessibility
  Reduced motion follows system setting
```

Do not move audio preferences into mining persistence.

- [ ] **Step 3: Complete MiningScreen audio lifecycle.**

On initialization, load `AudioManager` preferences. Preserve the existing app lifecycle forwarding and dispose path.

After a user gesture, allow `maybeStartBgm()` to run so web/mobile autoplay policies remain respected. Do not add autoplay polling or a global audio singleton.

- [ ] **Step 4: Run the focused screen tests.**

```bash
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: PASS with both normal and reduced-motion media settings.

---

## Task 3: Sever the two accidental city dependencies before deletion

### Task 3A: Terrain no longer imports Grid

**Files:**
- Modify: `lib/game/terrain/parallax_terrain_component.dart`
- Modify: `lib/mining/world/mining_game.dart`
- Modify: `test/game/terrain/parallax_terrain_component_test.dart`
- Modify if needed: `test/mining/world/mining_game_test.dart`

- [ ] **Step 1: Add a failing explicit-cell-size test.**

Construct `ParallaxTerrainComponent` with a non-default test cell size and assert its component/layer extent derives from that value rather than a global Grid constant.

- [ ] **Step 2: Remove `import '../grid.dart'`.**

Add a `cellSize` (or equivalent cell width/height only if genuinely necessary) constructor value with the existing 50px behavior as the default.

Use that value for:

- component size;
- debug cell rectangles/centers;
- created `ParallaxTerrainLayer` sizes.

- [ ] **Step 3: Have `MiningGame` pass `MiningContentRegistry.terrainCellSize`.**

This makes the validated 36×36 × 50 world contract explicit at the mining consumer without introducing a shared camera/terrain framework.

- [ ] **Step 4: Run focused terrain/mining-world tests.**

```bash
flutter test test/game/terrain/parallax_terrain_component_test.dart
flutter test test/mining/world/mining_game_test.dart
```

Expected: PASS and no `parallax_terrain_component.dart` import of `grid.dart`.

### Task 3B: ResourceType becomes identity-only

**Files:**
- Modify: `lib/game/resources/resource_type.dart`
- Modify: `test/resources/resource_type_test.dart`
- Delete later with city cleanup: `lib/game/resources/resource_category.dart`
- Delete later with city cleanup: `lib/game/resources/resource_cost.dart`
- Delete later with city cleanup: `lib/game/resources/resources.dart`

- [ ] **Step 1: Prove the surviving mining usage.**

```bash
rg 'ResourceType\.' lib/mining test/mining test/integration/mining_mvp_journey_test.dart
```

Expected surviving mining identities: gold, coal, stone.

- [ ] **Step 2: Rewrite the resource identity test for the post-cutover contract.**

Test only the enum identities the mining slice consumes. Remove registry/category/economy expectations.

- [ ] **Step 3: Slim `resource_type.dart`.**

Remove `Resource`, `ResourceRegistry`, and the `resource_category.dart` import. Keep only the enum surface with concrete mining consumers. Do not create `MiningResourceType` or move the file in this ticket.

- [ ] **Step 4: Run the focused identity/content tests.**

```bash
flutter test test/resources/resource_type_test.dart test/mining/mining_content_test.dart
```

Expected: PASS.

---

## Task 4: Delete the obsolete city production runtime and its tests

**Files:** delete all files below that have no retained mining consumer after Tasks 1–3.

### Production delete groups

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

Retain only these `lib/game/` files unless an actual mining import proves another concrete consumer:

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

### Test delete groups

Delete tests whose subjects disappear, including the current city suites under:

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

test/integration/planet_grid_integration_test.dart
test/integration/planet_placement_persistence_test.dart

test/scene_test.dart
```

For `test/resources/**`, keep only coverage for the surviving `ResourceType` identity. For `test/game/terrain/**`, keep only tests for the retained parallax terrain dependency graph.

- [ ] **Step 1: Delete one coherent production group at a time.**

After each group, remove imports/usages rather than adding compatibility placeholders.

- [ ] **Step 2: Delete the corresponding tests immediately.**

Do not spend time porting tests for behavior that no longer exists.

- [ ] **Step 3: Run analysis after the deletion pass.**

```bash
flutter analyze --fatal-infos
```

Fix only real dangling imports/unused references exposed by the deletion. If a supposedly shared file has no mining consumer, delete it too.

- [ ] **Step 4: Prove the production dependency boundary.**

Run targeted greps such as:

```bash
rg 'Planet|ActivePlanet|SaveService|MainGameWidget|MainGame|Building|Grid|GameStateManager|QuestManager|AchievementManager|ResearchManager|TradePage' lib --glob '*.dart'
rg 'package:horologium/(pages|widgets)/|package:horologium/game/(building|planet|production|quests|research|services|managers)/' lib --glob '*.dart'
```

Expected: no production references to retired city domains. Any remaining match must be a deliberate mining-facing name/comment or should be removed.

- [ ] **Step 5: Run the surviving full test suite.**

```bash
flutter test
```

Expected: PASS with a substantially smaller suite.

---

## Task 5: Update active product and contributor documentation

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `.github/copilot-instructions.md`
- Modify: `.windsurf/rules/project.md`

- [ ] **Step 1: Replace city-builder product descriptions.**

Describe Horologium as the current casual stellar mining-idle game and summarize the first-planet loop.

- [ ] **Step 2: Replace obsolete architecture guidance.**

Document the actual surviving ownership boundary:

```text
MainMenu
  -> MiningScreen (Flutter lifecycle + HUD/sheets/settings)
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
      -> MiningGame (Flame terrain + mine presentation)
```

Mention retained audio/parallax terrain as shared infrastructure and `horologium.mining.save` as the authoritative strict unversioned save.

- [ ] **Step 3: Replace obsolete workflow examples.**

Remove instructions for adding city buildings, workers, quests, production chains, old research, or planet persistence. Keep only useful Flutter commands/testing conventions and mining-focused extension points.

- [ ] **Step 4: Leave historical design docs alone.**

Past city design/spec documents are historical records. Do not rewrite them to pretend they were mining designs.

---

## Task 6: Re-run the complete product contract after deletion

**Files:**
- Modify only tests or mining code when this verification demonstrates a real HPA-636 regression.

- [ ] **Step 1: Run formatting and static analysis.**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

Expected: PASS.

- [ ] **Step 2: Run focused entry/recovery/settings coverage.**

```bash
flutter test test/main_menu_test.dart
flutter test test/mining/mining_save_repository_test.dart
flutter test test/mining/presentation/mining_screen_test.dart
flutter test test/integration/mining_mvp_journey_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run the full surviving suite.**

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 4: Build representative supported development targets.**

```bash
flutter build apk --debug
flutter build web
```

Expected: both builds succeed.

- [ ] **Step 5: Manually verify fresh, legacy-only, and existing-mining-save launches.**

Use three clean SharedPreferences/app-data scenarios:

1. no save keys → START MINING → clean Landing Basin;
2. legacy city keys only → START MINING → same clean mining state, no conversion/error;
3. valid mining save → CONTINUE MINING → restored cash/sectors/mines/cargo and offline return.

Also verify app background/resume, malformed mining-save recovery, Settings/audio, reduced motion, and portrait layout.

- [ ] **Step 6: Final deletion/dependency check.**

```bash
rg 'START EXPEDITION|MINING MVP|STELLAR MAP|RESEARCH LAB|space city-building|worker assignment|production chain' lib README.md CLAUDE.md .github/copilot-instructions.md .windsurf/rules/project.md
```

Expected: no active product/contributor wording for the retired city game.

Then inspect the final diff specifically for:

- no new compatibility/versioning framework;
- no accidental mining-save schema change;
- no city runtime retained only because a test/import was easier to keep;
- no unrelated asset purge or product feature expansion.

---

## Expected final file shape

The production Dart surface should converge toward:

```text
lib/
  main.dart
  main_menu.dart
  constants/
    assets_path.dart
  mining/
    ...validated HPA-631 slice...
    presentation/
      mining_settings_sheet.dart
  game/
    audio_manager.dart
    background_music_player.dart
    resources/
      resource_type.dart
    terrain/
      parallax_terrain_component.dart
      parallax_terrain_layer.dart
      terrain_assets.dart
      terrain_biome.dart
      terrain_depth_manager.dart
      terrain_generator.dart
```

This is a target boundary, not a reason to move already-clean mining files or create new packages. If implementation proves one additional shared file has a real mining consumer, retain it and document that concrete dependency in the PR rather than building an abstraction around it.
