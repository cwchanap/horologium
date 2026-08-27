# Task 11 report: validate the mobile merge-mining economy

## Scope and source

- Validation source/playtest build: `63e3d01ee55a1e8c29d1f1047e9418843af0f9a8`
  (`feat(mining): complete Lunar and Mars visuals`).
- Original validation commit: `d971b38e611fb3e620c5b75b0a71dd4298613f90`
  (`test(mining): validate the mobile merge economy`).
- This follow-up adds the responsive landscape layout and closes the browser
  suite/build evidence gates. Follow-up commit subject:
  `fix(mining): preserve landscape site actions`.
- Review follow-up: bounded the journey's simulated earning helper with a
  deterministic iteration ceiling and corrected `CLAUDE.md` to describe
  `refresh()` as in-memory publication rather than per-second persistence.
- Changed deliverables: `test/integration/merge_mining_journey_test.dart`,
  removal of `test/integration/mining_mvp_journey_test.dart`,
  `docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md`,
  `README.md`, `CLAUDE.md`, `lib/mining/presentation/site_deck_screen.dart`,
  `test/mining/presentation/site_deck_screen_test.dart`,
  `test/mining/presentation/mining_visuals_test.dart`, and this report.
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
- Review RED: the focused bound-diagnostic test was added before the helper
  bound; the focused command failed to compile with `No named parameter with
  the name 'maxIterations'`.
- Review GREEN: `earnUntil` now defaults to 100 five-minute iterations and
  fails with phase, cash target, current cash, last revenue, and revenue
  history evidence. The focused host and Chrome journey commands pass with
  `00:00 +2: All tests passed!`.
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
  simulator was discovered but no representative iOS gameplay session was
  run; the simulator debug build gate now passes.
- Genuine viewport observations were made at 360x640 portrait, 402x874
  portrait, 430x932 portrait, and 874x402 landscape. The live release capture
  exposed the landscape Site Deck action under the fixed full-width Fleet Dock;
  the follow-up responsive side rail reserves a 248px dock rail beside the
  deck, and the focused 874x402/text-scale-1.3 geometry test proves the action
  stays clear of both dock and navigation.
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
  fresh-to-Mars completion remain **BLOCKED**. Waiting for the authored economy
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
| `dart format --output=none --set-exit-if-changed .` | PASS | Final source check: `Formatted 50 files (0 changed)`. |
| `flutter analyze --fatal-infos` | PASS | Final source analysis recorded after the follow-up edits: `No issues found!`. |
| `flutter test` | PASS | Final host suite before this review follow-up: `00:10 +205: All tests passed!`; review follow-up full host rerun: `00:05 +206: All tests passed!`. |
| `flutter test --coverage` | PASS | Final host coverage suite before this review follow-up: `00:07 +205: All tests passed!`; review follow-up refresh: `00:07 +206: All tests passed!`; coverage file generated. |
| `flutter test --platform chrome` | PASS (`+205 ~1`) | Review follow-up full Chrome suite completed in about 20 seconds with 205 passed and one intentional skip. The only skip is `every site cavern node and card resolves`, skipped only under `kIsWeb` because this runner stalls on the first `rootBundle` byte load; the complete sequential proof remains active in host/full/coverage suites. |
| focused Site Deck presentation | PASS (`+5`) | `flutter test test/mining/presentation/site_deck_screen_test.dart`: existing states/callback/target/portrait checks plus the 874x402/text-scale-1.3 dock/navigation reachability regression. |
| focused Chrome visuals | PASS (`+2 ~1`) | `flutter test --platform chrome test/mining/presentation/mining_visuals_test.dart`: structural/common-asset checks pass; web-only byte-load test is explicitly skipped for the runner limitation. |
| focused Chrome journey | PASS (`+2`) | `flutter test --platform chrome test/integration/merge_mining_journey_test.dart`: `00:00 +2: All tests passed!`. |
| `flutter build apk --debug` | PASS | Exact escalated run completed; artifact `build/app/outputs/flutter-apk/app-debug.apk`. Generated native migration diffs were restored because native scaffold migration is outside this task's scope. |
| `flutter build web` | PASS | Exact escalated run completed: `✓ Built build/web`. |
| supporting `flutter build web --release` | PASS | Release build completed with `✓ Built build/web`; this artifact powered the genuine Chrome session. |
| `flutter build ios --simulator --debug` | PASS | Exact escalated run completed; artifact `build/ios/iphonesimulator/Runner.app`. Generated native migration diffs were restored because native scaffold migration is outside this task's scope. |

The prior cache-permission failures were cleared by the escalated build run.
The remaining representative-playtest limitation is genuine live duration and
browser text-scale control, not a source/test/build failure. The web-only
asset-byte proof is retained and green on host/full/coverage; Chrome's runner
cannot complete that one proof, so it is explicitly skipped rather than
replaced with path-only assertions.

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
- [x] `earnUntil` has a deterministic 100-iteration bound with phase, target,
  current cash, and revenue diagnostics plus a focused regression test.
- [x] `CLAUDE.md` distinguishes in-memory `refresh()` publication from
  persistence performed by committing mutations and lifecycle checkpoints.
- [x] The 874x402 landscape Site Deck action is clear of the dock/navigation
  at text scale 1.3 with all tested controls retaining 48px minimum targets.
- [x] Host format, fatal-info analysis, full tests, and coverage pass.
- [ ] Full representative text-scale 1.3/mid-late/Mars run: blocked by available
  browser/device controls and real-time duration; not faked.
- [x] Full Chrome suite and APK/web/iOS exact builds were run and passed; the
  web-only byte-load proof is explicitly skipped because the Chrome runner
  stalls on its first request, while host/full/coverage keep the proof active.
- [x] Generated `.playwright-cli/` browser artifact is removed before commit.

## Concerns for follow-up

1. Provide a representative device/browser harness that can set Flutter text
  scale to 1.3 and wait through the authored mid/late economy for a real
  fresh-to-Mars run.
2. Investigate the Flutter Chrome test runner's first `rootBundle` byte-load
   stall if browser-side asset-byte coverage becomes a release requirement; the
   host/full/coverage proof remains active and the browser skip is explicit.
