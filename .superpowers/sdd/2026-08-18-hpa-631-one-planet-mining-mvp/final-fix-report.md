# Final whole-branch review fixes

## Finding 1 — Mine tier markers

- Added concrete canvas geometry, size, position, and distinct paints to
  `OperationLightComponent`, `AdvancedPlatformComponent`,
  `SecondaryMachineryComponent`, and `EliteRingComponent`.
- Made level 5 cumulative: light + platform + machinery + elite ring. The
  tier ladder is documented beside the rebuild switch; levels 2 and 4 retain
  their bracket's structure.
- Updated `test/mining/world/mining_game_test.dart` to assert cumulative level
  5 membership and non-zero marker geometry.
- Command: `flutter test test/mining/world/mining_game_test.dart`
- Result: `+5`, all tests passed.

## Finding 2 — Selection focus and initial-fit camera

- Reworked `MiningGame.focusOnSelection` to target the center of the unobscured
  viewport with a positive camera offset, and to raise zoom when world bounds
  would otherwise leave the sector under the sheet. Zoom remains bounded by
  the existing game maximum.
- Updated the screen obstruction estimate to the 44% compact-sheet case.
- Strengthened `test/mining/world/mining_game_test.dart` with projected screen
  assertions at 360x640 and 430x932, including initial fit and bounds clamps.
- Command: `flutter test test/mining/world/mining_game_test.dart`
- Result: `+5`, all tests passed.

## Finding 3 — Rejected persistence writes

- `MiningSaveRepository.save` now throws when `SharedPreferences.setString`
  returns `false`.
- The controller regression uses a failing first save and blocked second save
  to verify the failed action does not publish state, busy clears after the
  queue drains, and the next queued action succeeds.
- Test: `test/mining/mining_controller_test.dart`
- Command: `flutter test test/mining/mining_controller_test.dart`
- Result: `+23`, all tests passed.

## Finding 4 — Quest performance methodology

- `test/performance/quest_perf_test.dart` now stops its stopwatch only after
  awaiting `tester.pumpWidget` frame completion, after a separate warm-up.
- Command: `flutter test test/performance/quest_perf_test.dart`
- Result: `+3`, all tests passed; final measured warm build was 50 ms, below
  the unchanged 500 ms bound.

## Finding 5 — Unmounted context after navigation

- Added mounted checks immediately after the awaited action and at the start
  of the catch path before presentation refresh or snackbar access.
- Added a delayed-action route-pop regression in
  `test/mining/presentation/mining_screen_test.dart`.
- Command: `flutter test test/mining/presentation/mining_screen_test.dart`
- Result: `+12`, all tests passed with no captured exception.

## Finding 6 — Route-exit checkpoint

- `MiningScreen.dispose` now queues one serialized checkpoint after canceling
  the timer. It persists the controller's latest published state without
  double-accruing time already represented by the published state; lifecycle
  and direct controller checkpoints retain their normal accrual behavior.
- Added a route-exit regression that advances a mine, pops the screen, and
  verifies the raw SharedPreferences payload contains the latest stored cargo.
- Test: `test/mining/presentation/mining_screen_test.dart`
- Command: `flutter test test/mining/presentation/mining_screen_test.dart`
- Result: `+12`, all tests passed; persisted landing cargo was `3.0`.

## Final verification

- `dart format --output=none --set-exit-if-changed` on all touched Dart files:
  clean.
- `flutter analyze --fatal-infos`: `No issues found!`.
- `flutter test`: `All tests passed` (`+1063`). Existing unrelated test
  warnings remain non-failing.

The pre-existing uncommitted Flutter migrator edits in
`android/gradle.properties` were not staged.

## Follow-up Finding 4 — Noise-robust QuestLogPage measurement

- Flake evidence: the prior single awaited sample was reported to measure
  68–382 ms typically, with 2 of 6 verification runs exceeding 500 ms under
  scheduler contention. During this follow-up, two additional sustained-load
  attempts also had all five samples inflated (minimums 872 ms and 540 ms),
  confirming why one sample is not a reliable estimate.
- Changed `test/performance/quest_perf_test.dart` to perform five separate
  awaited warm builds, log every wall-clock measurement, and assert the
  minimum remains below the unchanged 500 ms NFR bound. External scheduler
  contention can only inflate wall-clock samples, so the minimum estimates
  true build cost; a genuine regression shifts the whole distribution,
  including its minimum, above the bound.
- Required four-run sequence results: PASS min 51 ms, PASS min 51 ms, PASS
  min 42 ms, PASS min 56 ms.
- `dart format --output=none --set-exit-if-changed test/performance/quest_perf_test.dart`:
  clean. `flutter analyze --fatal-infos`: `No issues found!`.
