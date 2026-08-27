# Task 11 report: validate the mobile merge-mining economy

## Scope and source

- Validation source/playtest build: `63e3d01ee55a1e8c29d1f1047e9418843af0f9a8`
  (`feat(mining): complete Lunar and Mars visuals`).
- Final commit subject: `test(mining): validate the mobile merge economy`.
- Changed deliverables: `test/integration/merge_mining_journey_test.dart`,
  removal of `test/integration/mining_mvp_journey_test.dart`,
  `docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md`,
  `README.md`, `CLAUDE.md`, and this report.
- No authored economy numbers, simulation constants, new mechanics, sinks,
  currencies, depletion, or processing layers were changed.

## TDD and public-action journey

The replacement journey was written against the public controller API and a
fresh `SharedPreferences` repository with an injected TestClock. It never
mutates controller state or repository state directly, seeds cash/progression,
or bypasses affordability.

- RED: temporarily changed the fresh-save assertion from cash `100` to `101`;
  `rtk flutter test test/integration/merge_mining_journey_test.dart` failed at
  that assertion with `Expected: <101> Actual: <100>`.
- GREEN: restored the contract assertion to `100`; the same command passed with
  `00:00 +1: All tests passed!`.
- The journey starts with the two fresh Homeworld T1 rigs, merges them, and
  deploys T2 to Landing Basin. It then earns and sells through Carbon Ridge and
  Granite Crater, commissions Homeworld, buys Surveying 1/2/3, unlocks Lunar,
  verifies Lunar starter docks/Frozen Basin, merges and deploys Lunar, and
  advances while Lunar is active. It then commissions Titanium Highlands and
  Helium Mare, buys Surveying 5, unlocks Mars, verifies Mars starter
  docks/Ochre Basin, merges and deploys Mars, commissions Silica Dunes and
  Cobalt Chasm, and checks mastery.
- The test asserts inactive Homeworld cargo grows while active planet is Lunar,
  the Mars mastery result is exactly `Mars mastered — +25,000 cash.`, cash
  increases by exactly 25,000, a recall/redeploy does not award it again, and a
  new controller reloads the Mars save with all docks/sites/technology intact.

Exact emitted journey evidence:

```text
SEQUENCE Homeworld merge t1+t1->t2; deploy Landing Basin
CADENCE phase=Homeworld before Carbon Ridge elapsed=300s sales=540 cash=640
CADENCE phase=Homeworld before Granite Crater elapsed=300s sales=900 cash=1265
CADENCE phase=Homeworld mastery and Surveying 3 elapsed=1500s sales=1500/1500/1500/1500/1500 cash=8040
INACTIVE_HOMEWORLD active=Lunar Frontier elapsed=30s cargo=0.0->22.5
SEQUENCE Lunar merge t1+t1->t2; deploy Frozen Basin
CADENCE phase=Lunar before Surveying 4 and Titanium Highlands elapsed=1200s sales=1350/1350/1350/1350 cash=8440
CADENCE phase=Lunar before Surveying 5 and Helium Mare elapsed=1800s sales=3030/3030/3030/3030/3030/3030 cash=19120
CADENCE phase=Lunar mastery before Mars unlock elapsed=1200s sales=6630/6630/6630/6630 cash=28140
SEQUENCE Mars merge t1+t1->t2; deploy Ochre Basin
CADENCE phase=Mars before Silica Dunes elapsed=600s sales=8640/8640 cash=25420
CADENCE phase=Mars before Cobalt Chasm elapsed=600s sales=17440/17440 cash=43300
MASTERY reward=25000 cash=8300->33300
RELOAD active=marsFrontier surveying=5 marsCash=33300 marsSites=3/3 cargo=0.0
```

## Representative playtest

The complete observed session and its limitations are in
`docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md`.

- Environment: Chrome `151.0.7922.174`, macOS Darwin 25.5 arm64, release
  `build/web` served locally. The available iPad Pro 13-inch (M5), iOS 26.5
  simulator was discovered but could not run the app because the iOS build
  was blocked.
- Genuine viewport observations were made at 360x640 portrait, 402x874
  portrait, 430x932 portrait, and 874x402 landscape. The shell/site remained
  usable at all four; the landscape Site Deck lower card/action area is
  obscured by the fixed Fleet Dock.
- Music was disabled through the running Settings UI. Reduced motion was
  enabled with browser `prefers-reduced-motion: reduce` emulation. A genuine
  Flutter text-scale 1.3 setting was unavailable in this browser session and
  is explicitly **BLOCKED**, not inferred from widget tests.
- Early live evidence: fresh UI deployment to Landing Basin showed
  `RATE 0.50/s`, `CARGO 0.8/90`, `SALE +3`; a near-cap read was `89.8/90`.
  Selling showed `Sold 360 cash.`, cash `100->460`, and immediate cargo `1.0/90`.
  Captures 24 seconds apart showed `1.0/90->13.1/90`, consistent with the
  displayed rate. The 180-second one-rig fill interval (`90/0.50`) is a
  readout-derived early estimate, not a timed full-cap observation.
- Mid-game and late-game fill times, live sell/cap cadence beyond the early
  cap, live merge/spawn cycles at both planet transitions, and live
  fresh-to-Mars completion are **BLOCKED**. Waiting for the authored economy
  or injecting cash/clock state was not substituted for observation.
- Balance decision: **KEEP** authored values. The public journey passes every
  affordability gate and the live early rate/cap/sale readings agree; no
  numeric change is evidence-required. Revisit mid/late cadence after a real
  long-form representative run.

## Architecture/docs and legacy proof

`README.md` and `CLAUDE.md` now document the active boundary:

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> Flutter Site Deck / Mine Site / Stellar Map
```

They describe the current key `horologium.mergeMining.save`, strict root keys,
flat nine-site map plus per-planet four-bay dock map, commissioned mastery,
rate/capacity shares, recall cargo safety, foreground refresh, missing/recovered
initial persistence, separate audio preferences, resolved current asset paths,
and no active Flame runtime.

Required legacy/uniqueness scan 1:

```text
rtk rg "horologium\.mining\.save|MiningGame|MiningSectorId|MineState|SectorProgress|package:flame|ParallaxTerrain" lib test README.md CLAUDE.md pubspec.yaml
test/mining/mining_save_repository_test.dart:      SharedPreferences.setMockInitialValues({'horologium.mining.save': '{}'});
test/mining/mining_save_repository_test.dart:        'horologium.mining.save': 'retired',
test/mining/mining_save_repository_test.dart:        <String>{MiningSaveRepository.saveKey, 'horologium.mining.save'},
test/mining/mining_save_repository_test.dart:      expect(prefs.getString('horologium.mining.save'), 'retired');
```

The only matches are intentional tests proving the retired key is ignored;
there are no active legacy runtime references. Required uniqueness scan 2:

```text
rtk rg "class Mining(ContentRegistry|Save|Simulation|SaveRepository|Controller)" lib/mining
lib/mining/mining_simulation.dart:class MiningSimulation {
lib/mining/mining_save_repository.dart:class MiningSaveRepository {
lib/mining/mining_state.dart:class MiningSave {
lib/mining/mining_controller.dart:class MiningController {
lib/mining/mining_content.dart:class MiningContentRegistry {
```

There is exactly one current declaration for each required class.

## Final gates

| Gate | Result | Evidence |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed .` | PASS (source check) | `Formatted 50 files (0 changed)`. A later wrapper retry hit the local Flutter cache permission guard; the direct Dart SDK check with analytics suppressed still exited 0 with 0 changes. |
| `flutter analyze --fatal-infos` | PASS | `No issues found!` |
| `flutter test` | PASS | `00:05 +204: All tests passed!` |
| `flutter test --coverage` | PASS | `00:07 +204: All tests passed!`; coverage file generated |
| `flutter test --platform chrome` | BLOCKED/HUNG | Full run reached `+151` in `mining_visuals_test.dart`; focused reproduction reached `+2` at `every site cavern node and card resolves` and produced no result for over two minutes. Runner was stopped with SIGINT (exit 130). |
| focused Chrome journey | PASS | `flutter test --platform chrome test/integration/merge_mining_journey_test.dart`: `+1: All tests passed!` |
| `flutter build apk --debug` | BLOCKED | Flutter tool failed before build: `update_engine_version.sh ... cache/engine.stamp.tmp: Operation not permitted` and `cache/engine.realm: Operation not permitted`. |
| `flutter build web` | BLOCKED | Same local Flutter cache permission failure. |
| supporting `flutter build web --release` | PASS | Earlier release build completed with `✓ Built build/web`; this artifact powered the genuine Chrome session. |
| `flutter build ios --simulator --debug` | BLOCKED | Same Flutter cache permission failure. XcodeBuildMCP additionally reported `Module 'audioplayers_darwin' not found (in target 'Runner' from project 'Runner')` at `ios/Runner/GeneratedPluginRegistrant.m:12`; direct xcodebuild could not connect to CoreSimulatorService. |

The cache failures are local tool-environment permissions, not source/test
failures. The Chrome full-suite hang is isolated to the pre-existing asset
byte-load test; host asset tests, release asset loading, and all structural
asset checks pass.

## Self-review checklist

- [x] Fresh save and all progression are driven through public controller
  actions with injected clock/repository seams.
- [x] Affordability is exercised at every unlock, spawn, technology, and planet
  gate; no cash/progression shortcut is used.
- [x] Homeworld inactive production, one-time Mars reward, and reload are
  asserted.
- [x] TDD RED and GREEN evidence is recorded.
- [x] Genuine browser observations, device/commit/session metadata, all four
  viewports, muted audio, reduced motion, and limitations are recorded.
- [x] Keep/numeric-change decision is recorded; no numeric changes were made.
- [x] README/CLAUDE describe the current architecture and persistence/economy/
  asset semantics.
- [x] Exact legacy and uniqueness scans were run and recorded.
- [x] Host format, fatal-info analysis, full tests, and coverage pass.
- [ ] Full representative text-scale 1.3/mid-late/Mars run: blocked by available
  browser/device controls and real-time duration; not faked.
- [ ] Full Chrome suite and APK/iOS exact builds: blocked by the documented
  environment/test-runner conditions; not claimed as passes.
- [x] Generated `.playwright-cli/` browser artifact is removed before commit.

## Concerns for follow-up

1. Provide a representative device/browser harness that can set Flutter text
   scale to 1.3 and wait through the authored mid/late economy for a real
   fresh-to-Mars run.
2. Fix or isolate the Chrome asset byte-load hang in
   `mining_visuals_test.dart` before treating the full browser suite as green.
3. Revisit the observed 874x402 Site Deck/Fleet Dock overlap.
4. Repair the local Flutter/Xcode plugin/CoreSimulator environment before
   relying on APK/iOS build evidence.
