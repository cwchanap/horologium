# Horologium repository guidance

This file is the authoritative architecture and workflow reference for the
post-cutover Horologium Flutter/Flame mining idle game. `AGENTS.md` resolves to
this file; keep that entrypoint as a symlink and maintain guidance here.

## Product and ownership boundary

Horologium is a casual stellar mining idle game. The playable loop is reveal a
sector, build its mine, accrue resources, sell cargo, and upgrade the mine.
The current ownership boundary is:

```text
MainMenu
  -> MiningScreen
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
      -> MiningGame
          -> ParallaxTerrainComponent
```

- `MainMenu` is the landing screen. It checks mining-save presence and enters
  `MiningScreen`; it does not interpret or migrate the save document.
- `MiningScreen` is the Flutter owner of initialization, presentation state,
  action sheets, lifecycle checkpoints, the one-second presentation refresh,
  accessibility propagation, and the `MiningGame` widget bridge.
- `MiningController` is the one mutation boundary for mining actions. Reveal,
  build, upgrade, sale, checkpoint, and resume operations are queued so each
  action accrues current state and updates the in-memory state in order;
  committing actions and lifecycle checkpoints persist through the repository.
- `MiningSimulation` is deterministic economy logic. It accrues from a supplied
  UTC clock, fills mine storage, reports production, and applies the eight-hour
  offline cap without reading Flutter or device state.
- `MiningSaveRepository` exclusively owns the mining save document's
  SharedPreferences read, write, strict decode, and invalid-save recovery.
- `MiningGame` is the Flame world. It owns terrain, sector components, camera
  movement, selection, and action feedback; it does not own persistence,
  SharedPreferences, or Flutter presentation state.
- `ParallaxTerrainComponent` and its terrain helpers are shared Flame rendering
  consumers under `lib/game/terrain/`. Keep them independent of mining state
  and UI concerns.

Do not add a second state owner, a parallel mutation path, or a speculative
framework around this boundary. When behavior crosses Flutter and Flame, pass
small callbacks or values at the `MiningScreen`/`MiningGame` boundary.

## Mining state and persistence

`MiningSaveRepository.saveKey` is the single mining key:
`horologium.mining.save`. Its JSON document is intentionally strict and
unversioned. The root keys are exactly `cash`, `lastAccruedAtUtc`, and
`sectors`; each authored sector has exactly `revealed` and `mine`, and a mine
has `level` and `storedAmount`.

There is intentionally no version field, migration table, or compatibility
reader. Until a shipped compatibility need exists, preserve this contract:

- Missing data creates the initial save.
- Malformed or incompatible mining data creates a fresh initial save and marks
  the load as recovered so the UI can explain what happened.
- Legacy preference keys are ignored and must not be interpreted as mining
  state.
- Gameplay mutations and lifecycle checkpoints save through
  `MiningController` and `MiningSaveRepository`; do not write the mining
  document directly from widgets or Flame components.

Audio preferences are separate from mining state. `AudioManager` owns the
`audio.musicEnabled` and `audio.musicVolume` preference keys.

## Economy and resource identity

`lib/game/resources/resource_type.dart` defines the complete current resource
identity: `ResourceType.gold`, `ResourceType.coal`, and `ResourceType.stone`.
`MiningContentRegistry` maps each authored sector to one of these enum values.
Use the enum in maps and exhaustive switches; do not introduce string resource
IDs or a generic resource registry without an approved contract change.

The simulation is clock-based, not a device-time economy loop. The one-second
timer in `MiningScreen` refreshes displayed state while the screen is active;
`MiningSimulation.accrue` remains the source of production, including offline
accrual and storage caps. All cash, cargo, sector, and mine transitions pass
through `MiningController`.

## Audio and accessibility ownership

`MiningScreen` constructs or receives the `AudioManager`, loads its preferences
during initialization, forwards user gestures to `maybeStartBgm`, supplies the
settings sheet with the same instance, forwards app lifecycle changes, and
disposes it. This keeps browser autoplay gating, music settings, and lifecycle
pause/resume in one owner. `MiningGame` and mining components must not create or
control audio players.

The Flutter platform setting `MediaQuery.of(context).disableAnimations` is the
source of truth for reduced motion. `MainMenu` uses it for its launch
presentation; `MiningScreen` propagates it to `MiningGame.reducedMotion`, and
Flame reward/camera feedback consumes that value. Do not query platform
accessibility state independently from Flame components. Tests set
`MediaQueryData(disableAnimations: true)` when proving the settled path.

## Assets and presentation

Use the existing `Assets` and `TerrainAssets` constants for Flame asset paths.
Mining sector art uses the authored mine sprites under
`assets/images/building/`; terrain layers use the configured terrain asset
directories in `pubspec.yaml`. Add or update the asset before wiring a new
visual, and preserve development fallback rendering in terrain/presentation
components where an asset is unavailable.

Keep gameplay content data in `lib/mining/mining_content.dart`, state models in
`lib/mining/mining_state.dart`, simulation and persistence in their dedicated
files, Flutter surfaces under `lib/mining/presentation/`, and Flame world code
under `lib/mining/world/`.

## Test, format, and build workflow

Install dependencies with `flutter pub get`. Before handing off a change, run
the narrowest relevant tests first, then the repository gates as appropriate:

```sh
# Focused examples
flutter test test/mining/mining_controller_test.dart
flutter test test/mining/presentation/mining_screen_test.dart
flutter test test/integration/mining_mvp_journey_test.dart

# Repository quality gates
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
flutter test --coverage
flutter test --platform chrome

# CI build targets
flutter build apk --debug
flutter build web
```

Tests use `SharedPreferences.setMockInitialValues()` and injected clocks or
repositories where persistence or time matters. Keep tests deterministic and
independent of a real device, wall clock, network, or existing preference data.

Use `flutter run` for a native development session and `flutter run -d chrome`
for a quick browser session. Keep formatting at two spaces with trailing commas
for multiline Dart literals, and use focused Conventional Commit messages.

Detailed architecture changes belong here. `AGENTS.md` is a symlink to this
file for tool compatibility. Retired agent tooling (Speckit, Copilot
instructions, Windsurf rules) has been removed; this file is the single
authoritative guidance source.
