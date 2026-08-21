# HPA-636 Production Mining Cutover Design

## Status

Implementation design for Linear HPA-636, **Cut over to the mining-only product**.

This cutover intentionally lands in **one PR**. Planning is already on PR #15; implementation continues on the same branch after the HPA-631 real-device gate.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the current Horologium mining roadmap.
2. The final HPA-631 conclusion and merged mining MVP contract.
3. Linear HPA-636.
4. This task-specific design.
5. Legacy city documentation only as deletion context.

HPA-631 locked the first mining save to one strict **unversioned** document at `horologium.mining.save`, and HPA-630 was updated to match. HPA-636's older phrase "versioned mining save" does **not** reopen versioning or migration work.

## Start gate

HPA-631 records **Proceed to cutover**, with one explicit contingency: run a quick real-device portrait visual pass over representative mine tiers/reward presentation **before starting cutover**.

That remains the production-code gate. Planning/review work can continue before the pass, but Tasks that modify routing, mining presentation, terrain ownership, or delete city code do not start until the pass is recorded. This preserves the authoritative HPA-631 closeout rather than silently weakening it in HPA-636.

## Goal

Make the validated one-planet mining loop the only player-facing Horologium product:

> Launch → Start Mining or Continue Mining → enter the mining world → reveal, build, accrue, sell, upgrade, pause, resume, and recover without constructing or navigating any city-management system.

The end state should be smaller than `main`: one mining product, one mining save, one mutation boundary, and only shared runtime files that have a concrete mining consumer.

## Current baseline

`main` still has both products wired together:

- `lib/main_menu.dart` eagerly loads `Planet`/`SaveService`/`ActivePlanet`, exposes city routes, and also contains the temporary Mining MVP entry.
- `MainMenu` continuously repeats the starfield animation and, outside debug mode, three floating-particle animations without consulting `MediaQuery.disableAnimations`.
- `lib/game/scene_widget.dart` and `lib/game/main_game.dart` own the city runtime.
- `lib/pages/` and `lib/widgets/` expose city trade/research/resource/quest/building surfaces.
- `lib/mining/` is already an isolated vertical slice and persists only `horologium.mining.save`.
- `MiningScreen` already owns lifecycle forwarding and reduced-motion input, and constructs an `AudioManager`, but never calls `loadPrefs()` or `maybeStartBgm()`.
- `MiningStatusBar` is a three-metric row; the top HUD also contains the horizontally scrolling mining tabs.
- `ParallaxTerrainComponent` imports `grid.dart` only for the 50px cell constants.
- `MiningGame` then overwrites the terrain component size with `MiningContentRegistry.worldExtent`, masking whether the terrain's own cell-size seam is correct.
- `ResourceType` is used by mining, but the same file still contains city-only registry/product types that cannot be removed until city consumers are deleted.
- `offline_return_sheet.dart` has fallback/default switch branches that become unreachable once `ResourceType` is reduced to gold/coal/stone.
- `.specify/memory/constitution.md` still makes the city architecture non-negotiable and therefore must be amended as active governance, not left as history.
- `README.md` is a stock Flutter stub rather than a city architecture document.
- `.github/copilot-instructions.md` and `.windsurf/rules/project.md` duplicate large pieces of `CLAUDE.md` and have already drifted.
- `lib/main.dart` still presents the product title `Horologium - Space Explorer`.

## Options considered

### Option A — Mining-owned shell + delete legacy runtime

Rewrite startup around mining, complete the missing audio/accessibility behavior, sever the terrain/Grid dependency, then delete the city runtime and simplify the resource/dependency surface.

**Selected.** It deletes more code than it adds and leaves one authoritative architecture.

### Option B — Route-only cutover with dormant city code

Rejected. HPA-636 explicitly owns retirement; dormant city models/tests would keep the wrong architecture authoritative.

### Option C — Feature flag / migration / compatibility facade

Rejected as YAGNI. There are no shipped users whose city progress must migrate, and the validated mining save already has its own namespace.

## Selected design

### 1. Mining-only landing shell

Keep `lib/main.dart` pointing at `MainMenu`, but remove all city bootstrap/imports from `MainMenu`.

The landing screen has one primary CTA:

- no `horologium.mining.save` key → **START MINING**;
- mining save key exists → **CONTINUE MINING**.

Both actions open `MiningScreen`. Add `MiningSaveRepository.hasSave()` as a presence-only query using `MiningSaveRepository.saveKey`; it must not parse JSON. Therefore a malformed mining save still displays CONTINUE MINING and then enters the existing recovery path in `MiningScreen`, where decoding already belongs.

Legacy city SharedPreferences keys do not influence the label, do not migrate, and are not eagerly deleted.

The current MVP has one mining world. Revealed sectors, mines, cargo, cash, and accrual time already restore the meaningful location/progress state. Do not add camera position, selected-sector state, planet identity, or save-version fields solely for this ticket.

Remove Start Expedition, Trade, Stellar Map, Research Lab, the temporary Mining MVP label, and city Settings routing. Update the application title/copy in `lib/main.dart` and `MainMenu` to the mining product.

#### Launch-screen reduced motion

`MainMenu` becomes the first screen of the only product, so the system reduced-motion contract must cover it too.

Keep `MediaQuery.disableAnimations` as the single source of truth. Do not add a preference.

When reduced motion is enabled:

- do not repeat the starfield controller;
- render a stable starfield frame;
- do not render/repeat floating particles;
- present title/CTA in their settled state instead of running entrance movement.

When reduced motion is disabled, preserve the existing lightweight starfield/title/button presentation.

Tests should prove the decorative state remains stable across pumps under `disableAnimations: true`, rather than merely asserting no overflow.

### 2. Mining-owned settings and audio

Keep the existing `AudioManager` and `BackgroundMusicPlayer` path. Mining becomes their production consumer after city deletion.

Add one optional dependency to the existing `MiningScreen` test seam:

```dart
MiningScreen(
  content: ...,
  repository: ...,
  nowUtc: ...,
  audioManager: ...,
)
```

Production constructs `AudioManager()` when none is supplied.

During `_initialize()`, call `loadPrefs()` before exposing settings state. Preserve the current lifecycle forwarding and dispose behavior.

Call `maybeStartBgm()` only from existing user gestures:

- sector/tab selection;
- primary mining action;
- opening Settings.

Do not add `onUserInteracted`, a global pointer listener, polling, autoplay at initialization, another audio singleton, or a settings service.

Move the existing rich `FakeBackgroundMusicPlayer` from `test/game/audio_manager_test.dart` into shared test support and reuse it from both audio-manager and mining-screen tests. Tests should inject the **real** `AudioManager(backgroundMusicPlayer: fake)`.

Create one small `MiningSettingsSheet` with:

```text
Audio
  Music [switch]
  Volume [slider]

Accessibility
  Reduced motion follows system setting
```

Lift/reuse the existing switch/slider interaction pattern from the city hamburger menu where useful; do not reuse the city-coupled widget itself. Audio prefs remain in `audio.musicEnabled` / `audio.musicVolume`, not the mining save.

#### Settings placement

Keep `MiningStatusBar` metrics-only, but do **not** place an independently positioned button on top of the existing top HUD. A sibling `Positioned` overlay can visually overlap the status bar or tab strip without causing a Flutter overflow, so an overflow-only test would not protect the layout.

Instead, add the settings control **below the tab strip in the same top HUD layout flow**, aligned to the right so it floats over otherwise free game-world space. Give the tab strip a stable key such as `mining-sector-tabs` and the button `mining-settings-button`.

At both 360×640 and 430×932, assert geometry explicitly:

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

Also keep normal overflow/uncaught-exception checks. The geometry assertion is the proof that can actually fail if placement regresses.

### 3. Preserve the mining save contract

Keep `horologium.mining.save` unchanged:

```text
cash
lastAccruedAtUtc
sectors
```

No version, migration, legacy-city import, compensation, backup rotation, active-camera field, or speculative future keys.

Fresh installs and legacy-only installs both create `MiningSave.initial(...)`; existing mining saves retain the HPA-631 decode/offline/recovery behavior.

### 4. Sever the actual pre-deletion blocker: terrain → Grid

`ParallaxTerrainComponent` must accept the cell size it renders instead of importing `grid.dart`.

Make the value required:

```dart
ParallaxTerrainComponent({
  required int gridSize,
  required double cellSize,
  int? seed,
})
```

There is no useful post-cutover default: mining has one production caller and already owns `MiningContentRegistry.terrainCellSize`. Requiring it avoids silently re-embedding the deleted city constant as a fallback.

Use `cellSize` for component size, debug cell rectangles/centers, and child `ParallaxTerrainLayer` width/height.

`MiningGame` passes both:

```dart
gridSize: MiningContentRegistry.terrainGridSize,
cellSize: MiningContentRegistry.terrainCellSize,
```

and removes the current redundant:

```dart
..size = Vector2.all(MiningContentRegistry.worldExtent)
```

The terrain component should own its own rendered extent; `MiningGame`/content tests then verify the contract `terrainGridSize * terrainCellSize == worldExtent` instead of masking a bad cell-size seam.

Do not introduce a terrain config object/framework.

### 5. Delete the city runtime, then simplify resource identity/dependencies

Delete city production code and tests in coherent groups. Path lists are discovery seeds; analysis/search owns closure.

Remove city buildings/grid/managers/planet/save services, pages/widgets, quests/achievements/research/production-chain code, city resource containers, and obsolete non-parallax terrain files.

Only **after** those consumers are gone, simplify:

```dart
enum ResourceType { gold, coal, stone }
```

and remove `Resource`, `ResourceRegistry`, `BakeryProduct`, `KitchenProduct`, `CropType`, `ResourceCategory`, resource costs, and the old city resource container.

In the same pass update `lib/mining/presentation/offline_return_sheet.dart`: remove the two now-unreachable `default:` branches in the resource name/color switches. With an exhaustive enum switch, a future fourth mining resource should become a compile/analyzer obligation instead of silently taking a generic fallback.

After their only consumers disappear, remove `uuid` and `flame_audio` from `pubspec.yaml` and regenerate `pubspec.lock`. Keep `audioplayers` for mining audio.

Unused binary city assets remain out of scope unless a declaration/build failure requires cleanup.

### 6. Active guidance becomes mining-first without four architecture forks

Use distinct files for distinct jobs:

- `README.md` — player/developer-facing project overview, current mining loop, basic commands, local command/symlink note. Replace the stock Flutter stub; do not turn README into a second architecture manual.
- `CLAUDE.md` — authoritative detailed repository architecture/workflow guidance.
- `AGENTS.md` — keep the existing link to `CLAUDE.md`; no separate copy.
- `.windsurf/rules/project.md` — keep only its `always_on` frontmatter plus a short instruction to read/follow `../../CLAUDE.md`; remove the duplicated architecture body.
- `.github/copilot-instructions.md` — reduce to a concise, self-contained compatibility shim with the few repository-wide rules Copilot surfaces need, and point readers to `../CLAUDE.md` for detail. Do **not** rely on an undocumented symlink behavior for this special GitHub path.
- `.specify/memory/constitution.md` — authoritative Speckit governance; amend 1.0.0 → 2.0.0 because the non-negotiable architecture changes.

The constitution keeps useful general principles—Flutter/Flame ownership separation, deterministic tests, asset discipline, quality gates—while replacing mandatory city registries/key layouts/grid/timers with the mining ownership boundary and strict unversioned mining save.

Historical design documents under `docs/` remain historical and are not rewritten.

### 7. Keep generic shared runtime under `lib/game/`

Do **not** mechanically move the surviving audio/resource-identity/parallax-terrain files into `lib/mining/` in HPA-636.

`lib/game/` is a generic runtime namespace, not intrinsically a city namespace. After deletion it contains only shared game infrastructure with concrete mining consumers. Moving those files would add import churn while making reusable audio/terrain infrastructure look mining-owned.

A future move should be driven by a concrete ownership problem, not by the fact that city code once lived nearby.

## Post-cutover production boundary

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

Any additional `lib/game/**`, `lib/pages/**`, or `lib/widgets/**` production file needs a direct surviving consumer or should be deleted.

## Testing strategy

- Rewrite `test/main_menu_test.dart` around START/CONTINUE, absence of city actions, both portrait sizes, and `MediaQuery.disableAnimations` on the launch presentation.
- Keep global error-handler coverage in `test/widget_test.dart`, but update product assertions.
- Extend `mining_save_repository_test.dart` for presence-only detection and legacy-only isolation.
- Move/reuse the existing fake BGM player and extend `mining_screen_test.dart` for preference load, first-gesture BGM, settings controls, lifecycle, reduced motion, and explicit non-overlap geometry.
- Make terrain cell size required and test both the component seam and the MiningGame integration without a size override.
- Keep mining unit/world/integration journey coverage.
- Delete tests with retired city production code.
- After ResourceType slimming, make offline-return switches exhaustive.
- Run analyze/search after each deletion group and finish with dependency/import greps.

## Risks and mitigations

| Risk | Mitigation / proof |
| --- | --- |
| Cutover starts before the one unresolved HPA-631 visual acceptance item | Keep the explicit HPA-631 pre-code device gate |
| Legacy data changes menu/startup semantics | Presence-only mining key tests; no city import/delete |
| Existing mining saves reset | Save payload/decoder unchanged |
| MainMenu violates the product reduced-motion promise | Gate continuous/decorative launch animation on `MediaQuery.disableAnimations` and test stability |
| Mining loses BGM after city deletion | Load prefs and reuse existing user gestures for `maybeStartBgm()` |
| Settings overlaps HUD while overflow tests stay green | Put the control below tabs in layout flow and assert rectangle non-overlap |
| Terrain still hides a wrong cell size | Require `cellSize` and remove `MiningGame`'s `..size` override |
| Premature ResourceType slimming breaks city consumers | Slim only after deletion |
| Future resource silently uses fallback presentation | Remove unreachable offline-return switch defaults after enum slim |
| Agent guidance drifts again | One detailed CLAUDE source, thin tool-specific shims, separate constitution |
| Unsupported Copilot instruction indirection | Keep `.github/copilot-instructions.md` concise/self-contained rather than depending on symlink behavior |
| Large deletion misses nested files/dependencies | Grouped deletes + analyze/search + final greps/builds |

## Non-goals

- Technology/research or Lunar Frontier work.
- Processing, dynamic trading, retention, monetization, or cloud save.
- City-save migration/compensation.
- Mining save versioning/migration.
- New state-management, router, settings, audio, persistence, or terrain frameworks.
- Asset-library cleanup not required for cutover.
- Moving generic shared runtime files merely to erase the `lib/game/` directory name.
- Rebalancing/redesigning the validated HPA-631 mining economy.

## Acceptance mapping

HPA-636 is complete when:

1. the HPA-631 physical-device visual gate is recorded before production cutover implementation begins;
2. fresh and legacy-only installs show START MINING and enter clean mining progress;
3. an existing mining key shows CONTINUE MINING, including malformed-save presence, with decode/recovery still owned by `MiningScreen`;
4. no normal navigation exposes city gameplay and startup constructs no city state;
5. MainMenu and MiningScreen both honor system reduced motion;
6. mining audio/settings remain reachable and first-gesture BGM works without autoplay machinery;
7. the settings control has tested non-overlap with status/tabs at 360×640 and 430×932;
8. terrain cell size is explicit/required and MiningGame does not override the component's computed size;
9. ResourceType is mining-only after city deletion, offline-return switches are exhaustive, and dead packages are removed;
10. every retained shared runtime file/package has a concrete mining consumer;
11. README is a real mining project overview, CLAUDE is the detailed guidance source, tool-specific instruction files are thin, and Speckit governance is mining-first;
12. obsolete city code/tests are deleted rather than hidden;
13. format, analyze, focused mining tests, full surviving tests, debug APK/web builds, dependency greps, and fresh/legacy/existing/malformed save launches pass.
