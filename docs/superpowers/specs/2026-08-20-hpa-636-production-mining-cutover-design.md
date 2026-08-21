# HPA-636 Production Mining Cutover Design

## Status

Implementation design for Linear HPA-636, **Cut over to the mining-only product**.

This design intentionally delivers the player-facing cutover and legacy retirement in **one PR**. The planning documents are the first commits on that PR; implementation continues on the same branch after the pre-code device gate.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the current Horologium mining roadmap.
2. The final HPA-631 conclusion and merged mining MVP contract.
3. Linear HPA-636.
4. This task-specific design.
5. Legacy city documentation only as deletion context.

HPA-631 explicitly locked the first mining save to one strict **unversioned** document at `horologium.mining.save`, and HPA-630 was updated to match. HPA-636's phrase "versioned mining save" is stale wording and does **not** reopen persistence versioning or migration work.

## Start gate

HPA-631 records **Proceed to cutover** for merged PR #14.

Before changing production routing or deleting city code, run the quick real-device portrait visual pass requested by the HPA-631 conclusion, covering representative mine tiers and reward presentation. If that pass exposes a product-blocking problem, fix or reconsider HPA-631 before continuing the cutover. It does not block planning.

## Goal

Make the validated one-planet mining loop the only player-facing Horologium product:

> Launch → Start Mining or Continue Mining → enter the mining world → reveal, build, accrue, sell, upgrade, pause, resume, and recover without constructing or navigating any city-management system.

The cutover should leave a smaller codebase whose production dependencies match the mining product rather than hiding the old product behind unused routes.

## Current baseline

`main` currently has two products wired together:

- `lib/main_menu.dart` eagerly loads `Planet` through `SaveService`, initializes `ActivePlanet`, and exposes Start Expedition, Trade, Stellar Map, Research Lab, Settings, and the temporary Mining MVP route.
- `lib/game/scene_widget.dart` and `lib/game/main_game.dart` still own the old city runtime.
- `lib/pages/` and `lib/widgets/` expose city trade/research/resource/quest/building surfaces.
- `lib/mining/` is already an isolated vertical slice and persists only `horologium.mining.save`.
- `MiningScreen` already owns mining lifecycle handling and reduced-motion input, and already owns an `AudioManager`, but it never calls `loadPrefs()` or `maybeStartBgm()`.
- `ParallaxTerrainComponent` is a concrete mining dependency, but it still imports `lib/game/grid.dart` only for the legacy 50px cell constants. That accidental import is the only shared-runtime dependency that must be severed **before** city deletion.
- `ResourceType` is a concrete mining identity dependency, but its file also contains the obsolete city `Resource`, `ResourceRegistry`, `BakeryProduct`, `KitchenProduct`, and `CropType` types and depends on `ResourceCategory`. Those types are still consumed by live city code, so the file cannot be slimmed safely until those city consumers are deleted.
- `.specify/memory/constitution.md` still marks `MainGameWidget`, `MainGame`, `BuildingRegistry`, `ResourceRegistry`, city SharedPreferences keys, the one-second resource timer, and the 50×50 city grid as mandatory architecture. Speckit uses this as active planning governance, so it must be amended as part of cutover rather than treated as historical documentation.

## Options considered

### Option A — Mining-owned shell + delete legacy runtime

Rewrite the existing landing screen into a mining-only shell, route its single primary action into `MiningScreen`, complete the missing mining audio/settings behavior, sever the terrain/grid dependency, then delete the city runtime and slim shared resource identity in the same deletion pass.

**Pros**

- Produces one clear product and one dependency graph.
- Deletes more code than it adds.
- Keeps the already-validated mining controller/save/simulation unchanged.
- No feature flag, compatibility layer, state adapter, or second routing system.
- Easy to prove with imports, widget tests, and full-suite verification.

**Cons**

- One PR contains a large deletion diff.
- Requires updating stale contributor/governance documentation in the same change.

**Decision:** selected.

### Option B — Route-only cutover and leave city code dormant

Make Mining the default but keep the old pages, managers, models, tests, and menu helpers in the repository.

Rejected because HPA-636 explicitly owns legacy retirement. Dormant city code would keep maintenance/test cost and make future work ambiguous about which architecture is authoritative.

### Option C — Feature flag / migration / compatibility facade

Add a product-mode flag or startup adapter so city and mining can coexist while saves migrate.

Rejected as YAGNI. There are no production users whose city progress must remain compatible, HPA-636 says legacy keys are ignored rather than converted, and the validated mining save already has its own namespace.

## Selected design

### 1. Mining-only landing shell

Keep `lib/main.dart` pointing at `MainMenu`, but rewrite `MainMenu` so it no longer imports or constructs city state.

The landing screen has one primary CTA:

- no `horologium.mining.save` key → **START MINING**;
- mining save key exists → **CONTINUE MINING**.

Both actions open `MiningScreen`; the controller remains responsible for creating fresh progress, restoring valid progress, applying offline accrual, and recovering malformed saves.

Add a small `MiningSaveRepository.hasSave()` query so the landing screen does not duplicate the save key or inspect JSON. This query checks mining-save presence only. Legacy city SharedPreferences keys never influence the label or startup path.

The current one-planet MVP has exactly one mining world. Revealed sectors, mines, cargo, cash, and accrual time are already persisted, so "resume the last active mining location" means re-entering that same mining world with restored location progress. Do not add camera position, selected-sector state, planet identity, or a schema field solely for this ticket.

Remove Start Expedition, Trade, Stellar Map, Research Lab, the temporary Mining MVP label, and placeholder city Settings routing. Product copy becomes mining-focused. Existing starfield/theme presentation may remain when it has no city dependency.

### 2. Mining-owned settings, audio, and accessibility

Keep `AudioManager` and `background_music_player.dart`; mining becomes their concrete production consumer.

The current city path loads audio preferences and starts BGM after the first user gesture. The mining path must preserve both behaviors; a settings sheet alone is insufficient because players who never open Settings would otherwise receive silence.

Add one optional `AudioManager` constructor dependency to `MiningScreen`, alongside the existing optional content/repository/clock seams:

```dart
class MiningScreen extends StatefulWidget {
  const MiningScreen({
    super.key,
    this.content,
    this.repository,
    this.nowUtc,
    this.audioManager,
  });

  final MiningContentRegistry? content;
  final MiningSaveRepository? repository;
  final DateTime Function()? nowUtc;
  final AudioManager? audioManager;
}
```

`_MiningScreenState` uses the injected manager when present and otherwise constructs the existing production `AudioManager`. Do not add another singleton or a settings service.

During `_initialize()`, call `loadPrefs()` before presenting settings state. Keep the existing lifecycle forwarding and dispose behavior.

Call `maybeStartBgm()` only from existing user gestures:

- sector/tab selection (`_selectSector`);
- primary mining action (`_onPrimaryAction`);
- opening Settings.

Do not add an app-wide `onUserInteracted` callback, autoplay timer, global gesture listener, or second audio owner.

For tests, move the existing `FakeBackgroundMusicPlayer` implementation from `test/game/audio_manager_test.dart` into one shared test fixture such as `test/support/fake_background_music_player.dart`. Both `audio_manager_test.dart` and `mining_screen_test.dart` should use that same fake. `MiningScreen` tests instantiate the real `AudioManager(backgroundMusicPlayer: fake)` and inject it, proving the production wiring rather than mocking settings behavior.

Create one small mining presentation sheet for:

```text
Audio
  Music [switch]
  Volume [slider]

Accessibility
  Reduced motion follows system setting
```

The sheet owns presentation only and uses the injected/owned `AudioManager`; audio preferences stay in the existing `audio.musicEnabled` / `audio.musicVolume` SharedPreferences keys and do not enter the mining save.

Reduced motion remains driven by `MediaQuery.disableAnimations`, exactly as validated in HPA-631. Do not add a second reduced-motion preference.

#### Settings placement

Do **not** add the settings icon to `MiningStatusBar`. That bar is already three `Expanded` metrics, and adding another child would consume the narrow 360px width.

Add a separate `Positioned` + `SafeArea` settings control in `MiningScreen` as a sibling overlay to the status area. It opens `showModalBottomSheet`, matching the existing `OfflineReturnSheet` navigation pattern. `MiningStatusBar` remains metrics-only.

The 360×640 and 430×932 widget tests must prove the settings control and status metrics coexist without overflow.

### 3. Preserve the mining save contract

Keep `horologium.mining.save` unchanged:

```text
cash
lastAccruedAtUtc
sectors
```

No version field, migration, legacy-city import, compensation, backup rotation, active-camera field, or speculative future keys.

Fresh installs and installs containing only legacy city keys both receive `MiningSave.initial(...)`. Existing mining saves continue through the HPA-631 decode/recovery behavior.

### 4. Sever the actual pre-deletion blocker: terrain → Grid

`ParallaxTerrainComponent` should accept the cell size it renders instead of importing `grid.dart`.

Use one constructor value with the existing 50px behavior as the default, and have `MiningGame` pass `MiningContentRegistry.terrainCellSize`. `ParallaxTerrainLayer` already accepts `cellWidth` and `cellHeight`, so no new terrain abstraction is needed.

Use the explicit cell size for:

- component dimensions;
- debug cell rectangles/centers;
- child `ParallaxTerrainLayer` dimensions.

Retain only terrain files transitively used by mining:

- `parallax_terrain_component.dart`
- `parallax_terrain_layer.dart`
- `terrain_assets.dart`
- `terrain_biome.dart`
- `terrain_depth_manager.dart`
- `terrain_generator.dart`

Delete the old non-parallax grid/terrain presentation files when no mining import remains.

Do **not** slim `ResourceType` in this pre-deletion step. Its city-side companion types are still referenced until the city consumers disappear.

### 5. Delete city runtime, then slim the shared resource identity in the same pass

Delete production code with no concrete mining consumer, including:

- city buildings, categories, free-form placement, grid, managers, and scene runtime;
- `Planet`, `ActivePlanet`, legacy placed-building persistence, and `SaveService`;
- city resource containers/services and buying/trade behavior;
- research, quests, achievements, production-chain analysis, and their overlays;
- city pages and building/resource/quest cards;
- planet switcher and city dialogs/controls;
- legacy terrain components/layers used only by the city grid.

Delete the corresponding tests with each retired production group. Treat path lists as a starting set rather than an exhaustive allowlist: static analysis and searches must also catch nested city suites such as `test/game/quests/**` that do not live under `test/quests/**`.

Only **after** the city consumers are gone, simplify `lib/game/resources/resource_type.dart` to the mining identity surface:

```dart
enum ResourceType { gold, coal, stone }
```

Delete `Resource`, `ResourceRegistry`, `BakeryProduct`, `KitchenProduct`, `CropType`, `resource_category.dart`, `resource_cost.dart`, and `resources.dart` in that same deletion pass. Do not create `MiningResourceType` or move the identity file in HPA-636.

After their only city consumers are deleted, remove these package dependencies from `pubspec.yaml` and regenerate `pubspec.lock`:

- `uuid` — consumed by legacy building/placed-building identity;
- `flame_audio` — consumed by legacy `MainGame`.

Keep `audioplayers`, which backs the retained `AudioManager`/`BackgroundMusicPlayer` path.

Do not keep compatibility shims or dead feature flags to make deleted tests compile.

Unused city image assets are **not** part of this cutover unless an asset declaration or build failure requires cleanup. They are not player-facing runtime dependencies, and a large binary-asset purge would add review noise without improving the product cutover.

### 6. Active guidance and planning governance become mining-first

Update the active repository guidance that currently describes the city architecture:

- `README.md`
- `CLAUDE.md`
- `.github/copilot-instructions.md`
- `.windsurf/rules/project.md`
- `.specify/memory/constitution.md`

`AGENTS.md` is a symlink to `CLAUDE.md`, so changing `CLAUDE.md` is sufficient for that pair; do not create a separate divergent copy.

The Speckit constitution is active governance, not a historical design document. Amend it from the city-specific 1.0.0 contract to a mining-first contract and bump the major version because the non-negotiable architecture principles are intentionally changing. The new constitution should preserve useful general rules—Flutter/Flame separation, deterministic tests, asset discipline, quality gates—while replacing mandatory `MainGameWidget`/`MainGame`, city registries, city key patterns, one-second economy ticks, and 50×50 placement-grid rules with the current mining ownership boundary and strict mining save.

Historical design documents under `docs/` remain historical and should not be rewritten.

## Post-cutover production boundary

### Keep / modify

```text
lib/main.dart
lib/main_menu.dart
lib/constants/assets_path.dart
lib/mining/**
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

Any additional `lib/game/**`, `lib/pages/**`, or `lib/widgets/**` production file must justify itself with a direct mining consumer before it is retained.

## Testing strategy

Use deletion-oriented tests rather than preserving city coverage:

- rewrite `test/main_menu_test.dart` around START/CONTINUE mining and the absence of city actions;
- keep the global error-handler portion of `test/widget_test.dart`, but change its product smoke assertions to mining copy;
- extend `test/mining/mining_save_repository_test.dart` for save-presence detection and legacy-only preference isolation;
- move the existing fake BGM adapter to a shared test fixture and use it from both retained audio-manager tests and `mining_screen_test.dart`;
- extend `test/mining/presentation/mining_screen_test.dart` to prove preference loading, first-gesture BGM start, settings controls, lifecycle behavior, reduced motion, and the independent settings-overlay layout;
- update parallax terrain tests for the explicit cell-size seam;
- keep the existing mining unit/world/integration journey coverage;
- delete tests whose only subject is retired city code;
- run analysis and import/text searches after each deletion group so nested city tests or dependencies are not missed;
- run final dependency checks after `uuid`/`flame_audio` removal.

The full suite should get substantially smaller; retaining a city test by retaining city production code is not a goal.

## Risks and mitigations

| Risk | Mitigation / proof |
| --- | --- |
| Cutover starts despite a bad real-device MVP visual | Perform the HPA-631 tier/reward visual gate before code changes |
| Legacy city data affects fresh mining startup | `hasSave()` and `load()` inspect only `horologium.mining.save`; dedicated legacy-only test |
| Existing HPA-631 mining saves reset | Do not change the strict save payload or decoder |
| Music silently disappears when the city scene is deleted | Inject the existing `AudioManager`, load prefs in mining initialization, and call `maybeStartBgm()` from existing mining/settings gestures |
| Settings crowds the narrow status row | Keep `MiningStatusBar` metrics-only and use a separate Positioned/SafeArea settings control; test 360×640 |
| Deletion is blocked by hidden Grid imports | Remove only the parallax terrain → `grid.dart` dependency before city deletion |
| Premature ResourceType slimming breaks city consumers | Slim the identity file only inside the city deletion pass after consumers are gone |
| Speckit regenerates city-first plans after cutover | Amend `.specify/memory/constitution.md` in the active guidance pass |
| Unused packages remain after city deletion | Remove `uuid` and `flame_audio`, regenerate lockfile, run analyze/build |
| Large deletion hides accidental missing imports | Delete in coherent groups, run analyze/tests/searches after each group, finish with dependency greps |

## Non-goals

- Technology or new research.
- Stellar Map or a second planet.
- Processing, dynamic trading, retention systems, monetization, or cloud save.
- Legacy city save conversion or compensation.
- Mining save versioning or migration.
- New state-management, routing, persistence, settings, audio, or camera frameworks.
- Asset-library cleanup that is not required by the production cutover.
- Redesigning or rebalance-tuning the validated HPA-631 first-planet loop.

## Acceptance mapping

HPA-636 is complete when:

1. fresh and legacy-only installs show START MINING and enter clean mining progress;
2. an existing mining save shows CONTINUE MINING and restores the validated state/offline behavior;
3. no normal navigation exposes city gameplay;
4. startup/lifecycle code does not construct `Planet`, `Resources`, `Building`, city managers, or `SaveService`;
5. audio preferences load in mining, BGM can start on the first existing user gesture, settings are reachable without crowding the status bar, and reduced motion still follows the system setting;
6. `ParallaxTerrainComponent` has no dependency on city `Grid`;
7. the retained `ResourceType` surface is mining-only after city consumers are removed;
8. every retained shared runtime file and package dependency has a concrete mining consumer;
9. active contributor guidance **and Speckit governance** are mining-first;
10. obsolete city code/tests are removed rather than hidden;
11. format, analyze, mining integration coverage, full tests, debug APK/web builds, and the three save-presence launch scenarios pass.
