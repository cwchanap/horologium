# Horologium

Horologium is a casual stellar mining idle game built with Flutter. The
current loop is to commission a mine site, merge and deploy rigs, accrue and
sell cargo, buy technology, and unlock the next frontier:

```text
commission -> merge/deploy -> accrue -> sell -> research -> unlock/travel
```

## Active architecture

The active mining ownership boundary is:

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> Flutter Site Deck / Mine Site / Stellar Map
```

`MainMenu` only starts the mining shell. `MiningShell` owns initialization,
presentation refresh, lifecycle checkpoints, accessibility propagation, audio,
and the Flutter navigation surfaces. `MiningController` is the only mutation
boundary for sites, docks, rigs, sales, technology, planet unlock/travel, and
checkpoints. `MiningSimulation` is deterministic UTC-window economy logic and
accrues all unlocked planets in one call. `MiningSaveRepository` exclusively
reads, strictly decodes, writes, and recovers the mining document.

There is no Flame runtime in the active mining flow. The Site Deck, Mine Site,
Fleet Dock, Stellar Map, Technology, Settings, and return-progress surfaces are
Flutter presentation code under `lib/mining/`.

## State, economy, and persistence

The single mining preference key is `horologium.mergeMining.save`. Its strict,
unversioned JSON root contains exactly `cash`, `lastAccruedAtUtc`,
`technology`, `unlockedPlanetIds`, `activePlanetId`, `docks`, and `sites`.
`technology` has exactly the `extraction`, `logistics`, and `surveying` tracks.
The `sites` map is flat across the nine authored sites; the separate `docks`
map contains four dock bays for each planet. A site records its unlock and
commission status plus per-node rig assignments and cargo.

Commissioning every site on a planet grants mastery. A mastered Homeworld
enables Lunar Frontier after Surveying 3; mastered Lunar Frontier enables Mars
Frontier after Surveying 5. Mars mastery pays its one-time 25,000 cash reward.
Rig tier, extraction, and logistics determine production rate and capacity;
the simulation fills site cargo to its capacity and preserves per-planet
production summaries. Selling empties cargo on the active planet only.

Recall is safe: a deployed rig cannot be recalled while its site has cargo
above the replacement rig's capacity; sell first, then recall or redeploy.
Foreground refresh and the shell's one-second presentation timer call the
controller, while offline initialization accrues one UTC window across all
unlocked planets subject to the logistics cap.

Missing data creates and persists the initial save. Malformed, incompatible,
or pre-release data is clean-reset to a fresh initial save and marked as
recovered; it is not migrated. Legacy preference keys are ignored. Audio is
separate from mining state and is owned by `AudioManager` through
`audio.musicEnabled` and `audio.musicVolume`.

## Assets and resource identity

`MiningContentRegistry` is the source of authored planet, site, node, dock,
rig, technology, unlock, reward, rate, capacity, sale, and asset data.
Resource identity is the exhaustive `ResourceType` enum. Planet, cavern, node,
site-card, rig, icon, effect, and offline-return art resolves through the
existing constants and paths under `assets/images/mining/`; Lunar resource
silhouettes use Material icons and do not add PNG resource paths.

Reduced motion comes from Flutter's `MediaQuery.disableAnimations` and is
propagated by the shell to presentation feedback. Do not create a second state
owner or a parallel persistence/economy path.

## Run, test, and build

From the repository root:

```sh
flutter pub get
flutter run
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

Use `flutter run -d chrome` for a quick browser session. Focused mining tests
are under `test/mining/`; the public fresh-to-Mars journey is
`test/integration/merge_mining_journey_test.dart`.

## Local agent commands

`.opencode/command` (singular) is a repository-relative symlink to
`.claude/commands` (plural). Inspect the command definitions in
`.claude/commands`; if the symlink is missing, recreate it from the repository
root with:

```sh
ln -s ../.claude/commands .opencode/command
```
