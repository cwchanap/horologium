# HPA-636 Production Mining Cutover Design

## Status

Implementation design for Linear HPA-636, **Cut over to the mining-only product**.

This design intentionally delivers the player-facing cutover and legacy retirement in **one PR**. The planning documents are the first commit on that PR; implementation continues on the same branch after the pre-code device gate.

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

Before changing production routing or deleting city code, run the quick real-device portrait visual pass requested by the HPA-631 conclusion, covering the representative mine tiers/reward presentation. If that pass exposes a product-blocking problem, fix or reconsider HPA-631 before continuing the cutover. It does not block planning.

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
- `MiningScreen` already owns mining lifecycle handling and reduced-motion input, but it does not yet expose the existing audio preferences to the player.
- `ParallaxTerrainComponent` is a concrete mining dependency, but it still imports `lib/game/grid.dart` only for the legacy 50px cell constants. That accidental import currently prevents deleting `Grid` and `Building` cleanly.
- `ResourceType` is a concrete mining identity dependency, but its file also contains the obsolete city `ResourceRegistry` and depends on `ResourceCategory`.

## Options considered

### Option A — Mining-owned shell + delete legacy runtime

Rewrite the existing landing screen into a mining-only shell, route its single primary action into `MiningScreen`, add the missing mining settings/audio surface, sever the two accidental shared dependencies, then delete the city runtime and obsolete tests.

**Pros**

- Produces one clear product and one dependency graph.
- Deletes more code than it adds.
- Keeps the already-validated mining controller/save/simulation unchanged.
- No feature flag, compatibility layer, state adapter, or second routing system.
- Easy to prove with imports, widget tests, and full-suite verification.

**Cons**

- One PR contains a large deletion diff.
- Requires updating stale contributor documentation in the same change.

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

Keep `AudioManager` and `background_music_player.dart`; mining is now their concrete production consumer.

`MiningScreen` should:

- load saved audio preferences during initialization;
- expose a portrait-safe Settings affordance;
- show music enabled/disabled and volume controls backed directly by `AudioManager`;
- preserve lifecycle pause/resume behavior;
- allow `AudioManager.maybeStartBgm()` after a user gesture so browser/mobile autoplay constraints remain respected.

Create one small mining presentation widget/sheet for these controls. Do not extract a settings service, provider, or app-wide state framework.

Reduced motion remains driven by `MediaQuery.disableAnimations`, exactly as validated in HPA-631. The settings surface can state that reduced motion follows the system accessibility setting; do not add a second preference that can conflict with the platform setting.

### 3. Preserve the mining save contract

Keep `horologium.mining.save` unchanged:

```text
cash
lastAccruedAtUtc
sectors
```

No version field, migration, legacy-city import, compensation, backup rotation, active-camera field, or speculative future keys.

Fresh installs and installs containing only legacy city keys both receive `MiningSave.initial(...)`. Existing mining saves continue through the HPA-631 decode/recovery behavior.

### 4. Sever accidental legacy dependencies

#### Terrain

`ParallaxTerrainComponent` should own or accept the cell size it renders instead of importing `grid.dart`.

Prefer a constructor value with a 50px default, and have `MiningGame` pass the validated mining terrain cell size. This removes the city `Grid` dependency without creating a new terrain framework.

Retain only the terrain files transitively used by mining:

- `parallax_terrain_component.dart`
- `parallax_terrain_layer.dart`
- `terrain_assets.dart`
- `terrain_biome.dart`
- `terrain_depth_manager.dart`
- `terrain_generator.dart`

Delete the old non-parallax grid/terrain presentation files when no mining import remains.

#### Resource identity

Keep `lib/game/resources/resource_type.dart` as the shared mining resource identity, but simplify it to the enum surface mining actually needs. Remove `Resource`, `ResourceRegistry`, `ResourceCategory`, `Resources`, resource costs, and the old city resource economy after their consumers are deleted.

Do not introduce a second mining resource enum just to move the file.

### 5. Delete the city runtime instead of hiding it

After the entry/settings/terrain seams compile independently, delete production code with no concrete mining consumer, including:

- city buildings, categories, free-form placement, grid, managers, and scene runtime;
- `Planet`, `ActivePlanet`, legacy placed-building persistence, and `SaveService`;
- city resource containers/services and buying/trade behavior;
- research, quests, achievements, production-chain analysis, and their overlays;
- city pages and building/resource/quest cards;
- planet switcher and city dialogs/controls;
- legacy terrain components/layers used only by the city grid.

Do not keep compatibility shims or dead feature flags to make deleted tests compile. Delete or rewrite the tests with the retired production code.

Unused city image assets are **not** part of this cutover unless an asset declaration or build failure requires cleanup. They are not player-facing runtime dependencies, and a large binary-asset purge would add review noise without improving the product cutover.

### 6. Documentation becomes mining-first

Update the active repository guidance that currently describes the city architecture:

- `README.md`
- `CLAUDE.md` (also the source used by the repository agent guidance)
- `.github/copilot-instructions.md`
- `.windsurf/rules/project.md`

Describe `lib/mining/` as the gameplay vertical slice, the Flutter/Flame ownership boundary, strict mining persistence, retained terrain/audio infrastructure, and current commands/testing patterns. Historical design documents remain historical and should not be rewritten.

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

Any additional `lib/game/**`, `lib/pages/**`, or `lib/widgets/**` file must justify itself with a direct mining import before it is retained.

## Testing strategy

Use deletion-oriented tests rather than preserving city coverage:

- rewrite `test/main_menu_test.dart` around START/CONTINUE mining and the absence of city actions;
- keep the global error-handler portion of `test/widget_test.dart`, but change its product smoke assertions to mining copy;
- extend `test/mining/mining_save_repository_test.dart` for save-presence detection and legacy-only preference isolation;
- extend `test/mining/presentation/mining_screen_test.dart` for settings/audio and reduced-motion reachability;
- update parallax terrain tests for the explicit cell-size seam;
- keep the existing mining unit/world/integration journey coverage;
- delete tests whose only subject is retired city code;
- run import/text greps after deletion so the default production path cannot regress to city domains.

The full suite should get substantially smaller; retaining a city test by retaining city production code is not a goal.

## Risks and mitigations

| Risk | Mitigation / proof |
| --- | --- |
| Cutover starts despite a bad real-device MVP visual | Perform the HPA-631 tier/reward visual gate before code changes |
| Legacy city data affects fresh mining startup | `hasSave()` and `load()` inspect only `horologium.mining.save`; dedicated legacy-only test |
| Existing HPA-631 mining saves reset | Do not change the strict save payload or decoder |
| Deletion is blocked by hidden Grid imports | Remove the parallax terrain → `grid.dart` dependency before city deletion |
| Resource cleanup accidentally creates a second domain model | Keep and slim the existing `ResourceType` identity |
| Audio/settings disappear with the legacy hamburger menu | Add one mining-owned settings sheet backed by existing `AudioManager` |
| Accessibility behavior diverges from validated MVP | Keep `MediaQuery.disableAnimations` as the single reduced-motion source |
| Large deletion hides accidental missing imports | Delete in coherent groups, run analyze/tests after each group, finish with dependency greps |

## Non-goals

- Technology or new research.
- Stellar Map or a second planet.
- Processing, dynamic trading, retention systems, monetization, or cloud save.
- Legacy city save conversion or compensation.
- Mining save versioning or migration.
- New state-management, routing, persistence, settings, or camera frameworks.
- Asset-library cleanup that is not required by the production cutover.
- Redesigning or rebalance-tuning the validated HPA-631 first-planet loop.

## Acceptance mapping

HPA-636 is complete when:

1. fresh and legacy-only installs show START MINING and enter clean mining progress;
2. an existing mining save shows CONTINUE MINING and restores the validated state/offline behavior;
3. no normal navigation exposes city gameplay;
4. startup/lifecycle code does not construct `Planet`, `Resources`, `Building`, city managers, or `SaveService`;
5. settings/audio are available inside the mining product and reduced motion still follows the system setting;
6. every retained shared runtime file has a concrete mining consumer;
7. active contributor/product documentation is mining-first;
8. obsolete city code/tests are removed rather than hidden;
9. format, analyze, mining integration coverage, full tests, and representative development builds pass.
