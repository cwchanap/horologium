# Horologium repository guidance

This file is the active architecture and workflow reference for the Flutter
merge-mining game. Keep it aligned with the implementation; do not reintroduce
the retired Flame mining world or the pre-release sector/save contracts.

## Active ownership boundary

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> Flutter Site Deck / Mine Site / Stellar Map
```

- `MainMenu` starts the mining flow and does not interpret or migrate saves.
- `MiningShell` owns initialization, presentation state, the one-second
  foreground refresh, lifecycle checkpoints, audio, reduced-motion
  propagation, and Flutter navigation/action sheets.
- `MiningController` is the sole public mutation boundary. Unlock, spawn,
  merge, deploy, recall, sale, technology, planet unlock/travel, and lifecycle
  checkpoint operations accrue current state, mutate in order, and persist
  through the repository. `refresh()` accrues and publishes the current state
  in memory for the foreground timer; it does not persist per second.
- `MiningSimulation` is deterministic economy logic. It accrues one supplied
  UTC window over every unlocked planet, applies technology and rig effects,
  fills site cargo to capacity, and reports per-planet production plus flat
  full-site IDs without reading Flutter or device state.
- `MiningSaveRepository` exclusively owns SharedPreferences access, strict
  decoding, current-save validation, and missing/invalid recovery.
- The active mining presentation is Flutter code: Site Deck, Mine Site, Fleet
  Dock, Stellar Map, Technology, Settings, and offline-return surfaces. There
  is no Flame runtime in this ownership path.

- Landing Basin is the first authored animated mining site. Its transient shell-owned `impactSequence` presents passive one-second deterministic production; animation is not an economy clock.
- `MiningController`, `MiningSimulation`, `MineSiteView`, and `_displayState` remain authoritative. User-initiated mutations may publish their accrued state immediately and do not fabricate mining impacts.
- Landing Basin robot/deposit animation never calls the controller or persists animation/variant state. Cold-load/resume production is never replayed as historical strikes.
- Add another site-specific visual path only when a concrete second animated site needs it; do not pre-build a generic resource visual registry.

Do not add a second state owner, direct widget/repository writes, a parallel
mutation path, or a speculative processing/sink/currency layer.

## State and save contract

`MiningSaveRepository.saveKey` is the only mining key:
`horologium.mergeMining.save`. The current JSON document is intentionally strict
and unversioned. Its root keys are exactly:

```text
cash, lastAccruedAtUtc, technology, unlockedPlanetIds, activePlanetId, docks, sites
```

`technology` has exactly `extraction`, `logistics`, and `surveying`. `sites` is
one flat map containing all nine authored `MiningSiteId` values. `docks` is a
separate map from each `MiningPlanetId` to four `DockBayId` slots. Each site
tracks unlock/commission state, node rig assignments, and stored cargo; each
dock stores a `RigTier` or null.

- Missing data creates and persists a fresh initial state.
- Malformed, incompatible, and pre-release mining data clean-reset to a fresh
  initial state and set the recovered-load flag; there is no migration table or
  compatibility reader.
- Valid saves clamp decoded cargo to capacity after applying saved Logistics.
- Legacy preference keys are ignored and never interpreted as mining state.
- Gameplay and lifecycle persistence goes through `MiningController` and
  `MiningSaveRepository` only.

## Economy and progression

`MiningContentRegistry` owns all authored numeric content. Three sites exist on
each of Homeworld, Lunar Frontier, and Mars Frontier. Commissioning every site
on a planet is its mastery condition. Homeworld mastery plus Surveying 3
unlocks Lunar Frontier; Lunar mastery plus Surveying 5 unlocks Mars Frontier;
Mars mastery grants exactly one 25,000 cash reward. Newly unlocked planets
start with their authored starter dock bays and starter site.

Rig tier and Extraction determine rate. Logistics determines site capacity and
the offline accrual cap. The simulation stores cargo per flat site, produces
across all unlocked planets, and selling empties only the active planet's
cargo. A recall with cargo that cannot fit the replacement rig is rejected;
the user must sell before recalling. The shell's foreground timer refreshes
the controller once per second; initialization/lifecycle accrual remains
clock-based and deterministic.

Resource identity is the exhaustive `ResourceType` enum in
`lib/game/resources/resource_type.dart`. Use enum keys and exhaustive switches;
do not add string resource IDs or a generic registry without an approved
contract change.

## Audio, accessibility, and assets

`AudioManager` owns `audio.musicEnabled` and `audio.musicVolume`, and the shell
loads preferences, forwards gestures/lifecycle events, supplies Settings, and
disposes it. Mining code must not create audio players independently.

Flutter's `MediaQuery.disableAnimations` is the reduced-motion source of truth.
The shell propagates it to presentation feedback. Do not query accessibility
state independently from widgets.

Use the existing asset constants and authored paths under
`assets/images/mining/`: planet, cavern, node, site-card, rig, icon, merge
effect, and offline-return art all resolve. Lunar resource silhouettes are
Material icons. Preserve a development fallback when an optional visual is
unavailable and update the asset manifest before wiring a new visual.

## Verification workflow

Use injected clocks, repositories, and `SharedPreferences.setMockInitialValues`
in tests; avoid wall-clock, network, and existing preference state. Run focused
tests first, then the repository gates:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

The public-action journey is
`test/integration/merge_mining_journey_test.dart`; it must initialize a fresh
save and use only controller actions to merge, commission, sell, research,
unlock, travel, reward, and reload through Mars.

`AGENTS.md` is the repository-relative symlink to this guidance file.
