# Horologium

Horologium is a casual stellar mining idle game built with Flutter and Flame.
The core loop is:

```text
reveal -> build -> mine -> sell -> upgrade
```

## Run, test, and build

From the repository root:

```sh
flutter pub get
flutter run
flutter test
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter build apk --debug
flutter build web
```

Use `flutter run -d chrome` for a quick browser run and
`flutter test --platform chrome` for the browser test pass.

## Mining slice

The playable mining vertical slice lives in `lib/mining/`. `MainMenu` enters
`MiningScreen`, which presents the authored sectors, mine actions, offline
progress, and upgrades. Mining unit, widget, world, and journey tests live
under `test/mining/` and `test/integration/`.

## Local agent commands

`.opencode/command` (singular) is a repository-relative symlink to
`.claude/commands` (plural). Inspect the command definitions in
`.claude/commands`; if the symlink is missing, recreate it from the repository
root with:

```sh
ln -s ../.claude/commands .opencode/command
```
