# Task 5 report: MiningShell ownership and Flame retirement

## Result

Implemented the Flame-free `MiningShell` cutover at task base `dde6e08`.
The shell keeps the injected content/repository/clock/audio boundaries,
initialization and recovery persistence, timer refresh, lifecycle checkpoint and
resume/offline-return flow, first-gesture BGM start, reduced-motion ownership,
settings/technology ownership, and active-planet HUD projection. The body is
the requested temporary safe-area placeholder.

## Renamed

- `lib/mining/presentation/mining_screen.dart` -> `lib/mining/presentation/mining_shell.dart`
- `lib/mining/presentation/mining_status_bar.dart` -> `lib/mining/presentation/mining_hud.dart`
- `test/mining/presentation/mining_screen_test.dart` -> `test/mining/presentation/mining_shell_test.dart`

## Modified

- `lib/mining/presentation/mining_shell.dart`: removed Flame/game/action ownership; retained shell lifecycle, audio, timer, persistence, settings, technology, reduced-motion, and offline-return behavior.
- `lib/mining/presentation/mining_hud.dart`: renamed `MiningStatusBar`/sector fields to `MiningHud`/site fields while preserving cyan/panel tokens.
- `lib/mining/presentation/offline_return_sheet.dart`: resolved flat `fullSites` through the current planet/site catalog.
- `lib/main_menu.dart`: routes Start/Continue to `const MiningShell()`.
- `lib/main.dart`: removed Orbitron app typography.
- `pubspec.yaml`/`pubspec.lock`: removed Flame, its `ordered_set` transitive package, and terrain asset declarations.
- `test/mining/presentation/mining_shell_test.dart`: focused owner regression coverage for initialization persistence, timer/no-save refresh, identity, audio, settings, reduced motion, pause, resume, and Offline Return.
- `test/mining/presentation/offline_return_sheet_test.dart`, `test/mining/presentation/technology_sheet_test.dart`, `test/main_menu_test.dart`: retargeted to site terminology and `MiningShell`.
- `test/integration/mining_mvp_journey_test.dart`: retired the obsolete pre-cutover action journey and retained a production menu-to-shell smoke test; Task 7 owns the replacement public-action journey.

## Deleted zero-consumer closure

- `lib/mining/mining_sheet_view.dart`
- `lib/mining/presentation/mining_action_sheet.dart`
- `lib/mining/presentation/stellar_map_sheet.dart`
- `lib/mining/world/**`
- `test/mining/mining_sheet_view_test.dart`
- `test/mining/presentation/stellar_map_sheet_test.dart`
- `test/mining/world/**`
- `lib/game/terrain/**`
- `test/game/terrain/**`
- `assets/images/terrain/**`

## Closure search evidence

Before deletion, the required command was run:

```text
rtk rg "ParallaxTerrain|package:horologium/game/terrain|package:flame" lib test
```

It returned only the old `MiningScreen`, mining-world, terrain, and their test
imports/classes; the sole production `ParallaxTerrainComponent` construction
was in the old `lib/mining/world/mining_game.dart` closure. After the cutover:

```text
rtk rg "ParallaxTerrain|package:horologium/game/terrain|package:flame" lib test
# no matches

rtk rg "package:flame" lib test
# no matches
```

The legacy mining/world/action names and old sector/mine consumers also return
no matches in `lib`, `test`, and `pubspec.yaml`.

## Gates

- `rtk dart format --output=none --set-exit-if-changed .` — passed; 32 files, 0 changed.
- `rtk flutter analyze --fatal-infos` — passed; no issues found.
- `rtk flutter test` — passed; 162 tests.
- `rtk git diff --check` — passed.

## Self-review

- `_startRefreshTimer` calls `controller.refresh()` then `_refreshPresentation()`
  and never persists; the shell test proves cargo advances while
  `CountingMiningSaveRepository.saveCount` is unchanged.
- Initialization still persists missing/recovered saves; pause cancels the
  timer and checkpoints; resume accrues and presents Offline Return.
- Controller/audio identity remains state-owned across rebuild; audio preference
  loading gates gestures, and reduced motion follows `MediaQuery`.
- HUD commissioned-site/cargo totals use the active planet and preserve the
  existing cyan/panel values.
- No Flame imports or legacy world/terrain/action consumers remain.

## Concerns and deliberate scope

- The temporary placeholder is intentionally non-functional and is replaced by
  Site Deck in Task 7. The old full action integration journey was therefore
  retired at this cutover and retained only as a shell-entry smoke.
- Terrain processor scripts/docs and the remaining shared `Assets` constants
  were left untouched because they are not part of the named zero-consumer
  runtime closure; the six deleted-terrain constants were removed in Fix round
  1 as a review follow-up.

## Fix round 1

- Updated `test/mining/presentation/mining_shell_test.dart` so the keyed shell
  identity test rebuilds after changing the test view from portrait 360x640 to
  landscape 640x360, then asserts the same controller and audio manager. A
  `try`/`finally` restores the prior physical size and pumps the view.
- Removed the dead terrain comment and six deleted-terrain constants from
  `lib/constants/assets_path.dart`; the remaining shared `Assets` utility is
  unchanged.
- `rtk flutter test test/mining/presentation/mining_shell_test.dart` — passed;
  10 tests.
- `rtk dart format lib/constants/assets_path.dart
  test/mining/presentation/mining_shell_test.dart` — passed; 2 files formatted,
  1 changed.
- `rtk dart format --output=none --set-exit-if-changed .` — passed; 32 files,
  0 changed.
- `rtk flutter analyze --fatal-infos` — passed; no issues found.
- `rtk flutter test` — passed; 162 tests.
