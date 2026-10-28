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
  merge, deploy, recall, sale, technology, planet unlock/travel,
  and lifecycle checkpoint operations accrue current state, mutate in order, and persist
  through the repository. `relaunch` is the deliberate exception: it gates on
  the current state's commissioned flags and resets immediately without
  accruing, because accrual cannot change mastery and the reset discards
  accrued cargo anyway. `refresh()` accrues and publishes the current state
  in memory for the foreground timer; it does not persist per second.
- `MiningSimulation` is deterministic economy logic. It accrues one supplied
  UTC window over every unlocked planet, applies technology and rig effects,
  fills site cargo to capacity, and reports per-planet production plus flat
  full-site IDs without reading Flutter or device state.
- `MiningSaveRepository` exclusively owns the mining-save SharedPreferences
  key, strict decoding, current-save validation, and missing/invalid
  recovery.
- The active mining presentation is Flutter code: Site Deck, Mine Site, Fleet
  Dock, Stellar Map, Technology, Settings, and offline-return surfaces. There
  is no Flame runtime in this ownership path.

- `MiningNextGoalView` is a stateless Site Deck read model derived from the display state; the strip only navigates through existing shell paths and never mutates, persists, or adds tutorial state.
- Landing Basin and Frozen Basin are the authored animated mining sites, selected by the closed `MiningVisuals.depositFramesFor` switch. Their transient shell-owned `impactSequence` presents passive one-second deterministic production; animation is not an economy clock.
- `MiningController`, `MiningSimulation`, `MineSiteView`, and `_displayState` remain authoritative. User-initiated mutations may publish their accrued state immediately and do not fabricate mining impacts.
- Animated-site robot/deposit animation never calls the controller or persists animation/variant state. Cold-load/resume production is never replayed as historical strikes.
- Animated-site resource HP and strike-damage labels are transient visual-layer state driven by the existing valid-contact latch; they never feed persistence or production.
- Add an animated site only with an approved frame family and a new `depositFramesFor` case; there is no visual registry.

Mine Site is a Flutter InteractiveViewer over a deterministic 50×50 grid.
Each site derives 100 1×1/2×2/3×3 resource bodies from its site ID; resources
are not persisted. Rigs occupy one cell and mine their unique orthogonally
adjacent resource. Free unique perimeter cells are the only resource-level
placement capacity, sites remain capped at four rigs, static perimeter geometry
is cached with content, placement legality stays centralized in mining_grid.dart,
and production remains aggregate/deterministic in MiningSimulation. Animated
sites share one visual layer and only mined resources participate in its
per-frame animation builder. An invalid persisted
placement resets the complete mining save through the existing recovery
boundary; there is no migration.

- old rigByNode saves intentionally recover fresh through the invalid-save boundary
- `_displayNotifier` remains a shell rebuild channel for live modal HUDs, not state ownership
- PR #26 non-grid Mine Site chrome remains the presentation baseline

Do not add a second state owner, direct widget/repository writes, a parallel
mutation path, or a speculative processing/sink/currency layer.
Do not revive the city-era `Building`/`Resources`/recipe/worker/city-tick
architecture in mining; its docs were removed in `768d991` and remain in git
history.

## State and save contract

`MiningSaveRepository.saveKey` is the only mining key:
`horologium.mergeMining.save`. The current JSON document is intentionally strict
and unversioned. Its root keys are exactly:

```text
cash, lastAccruedAtUtc, technology, unlockedPlanetIds, activePlanetId, docks, sites, relaunchCount
```

`technology` has exactly `extraction`, `logistics`, and `surveying`. `sites` is
one flat map containing all twelve authored `MiningSiteId` values. `docks` is a
separate map from each `MiningPlanetId` to four `DockBayId` slots. Each site
tracks unlock/commission state, grid rig placements, and stored cargo; each
dock stores a `RigTier` or null.

- Missing data creates and persists a fresh initial state.
- Malformed, incompatible, and pre-release mining data clean-reset to a fresh
  initial state and set the recovered-load flag; there is no migration table or
  compatibility reader.
- Relaunch replaces the save with a fresh initial state and keeps only
  `relaunchCount`.
- Valid saves clamp decoded cargo to capacity after applying saved Logistics.
- Legacy preference keys are ignored and never interpreted as mining state.
- Gameplay and lifecycle persistence goes through `MiningController` and
  `MiningSaveRepository` only.

## Economy and progression

`MiningContentRegistry` owns all authored numeric content. Three sites exist on
each of Homeworld, Lunar Frontier, Mars Frontier, and Ceres Frontier.
Commissioning every site on a planet is its mastery condition. Homeworld
mastery plus Surveying 3 unlocks Lunar Frontier; Lunar mastery plus Surveying 5
unlocks Mars Frontier; Mars mastery plus Surveying 5 and 30,000,000 cash unlocks
Ceres Frontier. Ceres mastery grants 30,000,000 cash once per run; Mars grants
none. The reward stays on the final authored planet as content evolves (HPA-262
moves it to Io), and mastering the final planet again after Relaunch pays the
reward again. Mastering the final authored planet unlocks Relaunch; each
relaunch adds +50% sale value through `MiningContentRegistry.cargoValue` for
sites and `MiningSave.saleValue` for floored planet totals.
`formatSaleMultiplier` is the display contract for the current run multiplier.
Newly unlocked planets start with their authored starter dock bays and starter
site.

Rig tier and Extraction determine rate. Each site's `baseCapacity` is its base
rate times `MiningContentRegistry.storageWindow` (2 hours), so storage holds
two hours of base production; Logistics extends that window and Extraction
shortens it. Offline accrual is capped at a fixed 24 hours
(`offlineAccrualCap`) as a clock safety net; Logistics no longer changes it.
All player-visible cash goes through `formatMiningCash` (compact `M`/`B` from
one million) and resource amounts through `formatMiningUnits`. Pacing is
proven by the public-action journey on its injected clock, never by a
wall-clock playtest. The simulation stores cargo per flat site, produces
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

`AudioManager` owns music and SFX players plus `audio.musicEnabled`,
`audio.musicVolume`, and `audio.soundEnabled`, and the shell
loads preferences, forwards gestures/lifecycle events, supplies Settings, and
disposes it. Mining code must not create audio players independently.
`StorageAlerts` owns the `notifications.storageFullEnabled` and
`notifications.permissionAsked` preferences; neither belongs to the mining
save. The shell schedules the storage-full alert after a lifecycle checkpoint —
including when initialization itself finishes backgrounded — and cancels
it on initialization and resume; the newest shell owns the single pending
alert, so a superseded shell's late projection drops instead of rearming
the shared notification id. Writes to that id serialize on one shared
`StorageAlerts` chain across shell instances, so a superseded in-flight
write always lands ahead of the newest owner's cancel or fresh
projection. Mining logic never calls the notification plugin directly.
An animated site's visual reports its visible strike through `onMiningImpact`;
the shell decides whether to play it. Cargo-full cues are foreground transitions,
and commissioning/mastery cues follow successful persistence. Taps and mining
must not interrupt action/milestone audio; offline accrual never replays SFX.

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
unlock, travel, reward, and reload through the final authored planet, relaunch,
and replay a faster second run.

`AGENTS.md` is the repository-relative symlink to this guidance file.
