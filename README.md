# Horologium

Horologium is a casual stellar mining idle game built with Flutter and Flame.
The core loop is:

```text
reveal -> build -> mine -> sell -> upgrade
research -> unlock Lunar Frontier -> travel
```

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
```

Use `flutter run -d chrome` for a quick browser run and
`flutter test --platform chrome` for the browser test pass.

## Mining slice

The playable mining vertical slice lives in `lib/mining/`. `MainMenu` enters
`MiningScreen`, which presents the Homeworld and Lunar Frontier catalogs, three
flat sectors per planet, mine actions, technology tracks, Stellar Map unlock
and travel, active-planet cargo selling, offline progress, and upgrades.
`MiningSimulation` accrues one UTC window across all unlocked planets, while the
`MiningGame` projects one planet and is replaced with a keyed world on travel.
Mining unit, widget, world, and journey tests live under `test/mining/` and
`test/integration/`.

## Save contract

Mining progress uses the strict current document under
`horologium.mining.save`: cash, one `technology` object, unlocked and active
planet IDs, and one flat six-sector map. Pre-release or otherwise incompatible
documents clean-reset to the initial save; there is no migration reader.

## Local agent commands

`.opencode/command` (singular) is a repository-relative symlink to
`.claude/commands` (plural). Inspect the command definitions in
`.claude/commands`; if the symlink is missing, recreate it from the repository
root with:

```sh
ln -s ../.claude/commands .opencode/command
```
