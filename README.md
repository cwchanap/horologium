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

## References

`CLAUDE.md` is the authoritative architecture, save-contract, and economy
reference.

Audio sources and playback notes: [docs/audio-assets.md](docs/audio-assets.md).

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
are under `test/mining/`; the public fresh-to-final-frontier journey is
`test/integration/merge_mining_journey_test.dart`.
