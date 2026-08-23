# HPA-638 final review fix report

## Finding 1 — save cross-field invariants

- The strict decoder now requires Homeworld to be unlocked and rejects any
  revealed or mined Lunar sector while Lunar is locked. Decoded
  `unlockedPlanetIds` is now unmodifiable.
- Added invalid-save table cases for a Lunar-only save, a revealed locked-Lunar
  sector, and a mined locked-Lunar sector, plus an immutability test.
- Command: `flutter test test/mining/mining_save_repository_test.dart test/mining/mining_controller_test.dart test/mining/presentation/offline_return_sheet_test.dart`
- Output: `All tests passed!` (87 focused tests).

## Finding 2 — active-planet sector mutations

- Added one shared `_activePlanetSectorFailure` guard and applied it to
  `revealSector`, `buildMine`, and `upgradeMine`.
- Added tests for locked-Lunar reveal rejection and a delayed-save queued
  mutation that attempts to act on the planet left behind after travel.
- Command: `flutter test test/mining/mining_save_repository_test.dart test/mining/mining_controller_test.dart test/mining/presentation/offline_return_sheet_test.dart`
- Output: `All tests passed!` (the controller regression cases pass without
  mutating state).

## Finding 3 — offline cap presentation

- The capped-return message now formats `summary.elapsedUsed`, so it displays
  the effective Logistics-dependent cap instead of always displaying eight
  hours.
- Added a widget test for the Logistics 2, 12-hour cap.
- Command: `flutter test test/mining/mining_save_repository_test.dart test/mining/mining_controller_test.dart test/mining/presentation/offline_return_sheet_test.dart`
- Output: `All tests passed!` (the widget finds `Offline production was capped at 12h 0m.` and not the 8-hour copy).

## Verification

- `dart format --output=none --set-exit-if-changed .` — `Formatted 49 files (0 changed)`.
- `flutter analyze --fatal-infos` — `No issues found!`.
- `flutter test` — `All tests passed!` (258 tests).
