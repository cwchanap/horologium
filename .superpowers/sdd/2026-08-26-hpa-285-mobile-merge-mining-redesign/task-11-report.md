# Task 11 report: validate the mobile merge-mining economy

## Scope and source

- Validation source/playtest build: `63e3d01ee55a1e8c29d1f1047e9418843af0f9a8`
  (`feat(mining): complete Lunar and Mars visuals`).
- Current-head live validation run: `b7b1c02f6b0793fefa4c0733e15c4484dd705afb`
  (`fix(mining): bound journey earning loop`).
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

The complete current-head observed session is in
`docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md`.

- Environment: Chrome `151.0.7922.174`, macOS Darwin 25.5 arm64, current-head
  release `build/web` served locally. The current-head Flutter simulator build
  was also installed/launched on iPad Pro 13-inch (M5), iOS 26.5.
- The web session used visible public actions from a fresh save with no save
  import, storage edit, clock manipulation, or progression shortcut. Current
  captures cover 360x640 portrait, 402x874 portrait, 430x932 portrait, and
  874x402 landscape. The current landscape side rail kept sell, spawn, four
  bays, back/settings, and nodes on-screen and reachable.
- Music was disabled through the running Settings UI. Reduced motion was
  enabled with browser `prefers-reduced-motion: reduce` emulation. Chrome has
  no direct Flutter text-scale control; the iOS simulator supplied Dynamic
  Type `extra-extra-extra-large` (approximately 1.35, stricter than 1.3),
  where fresh Site Deck, Mine Site, and Technology views were readable and
  reachable without clipping.
- Live cadence evidence: Homeworld reached `3/3` `T2/T2/T1`, `2.48/s`, cap
  `435`; five real 5-minute sales were each `+1680`, cash `695->9095`
  (`02:18:32Z..02:38:38Z`). Lunar starter Frozen T2 reached `1.50/s`, cap
  `225`; three real 5-minute sales were each `+1350`, cash `4095->8145`
  (`02:50:47Z..03:00:50Z`). Lunar expansion recorded six real 5-minute
  combined sales at cap `365`, each `+3030`, cash `645->18825`
  (`03:08:40Z..03:33:49Z`).
- Lunar mastery recorded Surveying 5 cost `9000`, Helium unlock `8000` plus
  T1 `5000`, then `3/3`, `2.85/s`, cap `485`; four real 5-minute sales were
  each `+6630`, cash `1325->27845` (`03:41:44Z..03:56:49Z`). Mars unlock
  visibly cost `20000`; inactive Homeworld and Lunar continued accruing.
  Mars starter Ochre T2 reached `1.13/s`, cap `270`; two real 5-minute sales
  were each `+8640`, cash `7845->25125` at `04:04:42Z` and `04:09:43Z`.
- Mars expansion recorded Silica unlock `12000` plus T1 `5000`, then two real
  5-minute combined sales at cap `430`, each `+17440`, cash `8125->43005`
  at `04:17:01Z` and `04:22:03Z`. Cobalt unlock was `30000` plus T1 `5000`;
  final deployment showed `Mars mastered — +25,000 cash.` and cash
  `8005->33005` at `04:23:45Z`; final Mars was `3/3`, `2.02/s`, cap `560`.
- The run observed fresh Homeworld, Lunar, and Mars merge cycles, both planet
  transitions, inactive-planet production, and fresh-to-Mars completion. It
  exceeded two real hours; the listed progression windows total at least 85
  minutes. Normal reload offered `CONTINUE MINING`, showed a 34-second
  all-planet offline-return modal, and resumed Mars at `3/3`, cash `33005`,
  without a duplicate reward. A later sell/recall correctly showed `Sell cargo
  before recalling this rig.` because resumed accrual had produced cargo.
- Balance decision: **KEEP** authored values. Live early, mid, and late
  cadence and every progression gate were internally consistent; no numeric
  change is evidence-required.

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
The current-head representative run clears the live duration, progression,
transition, and accessibility-scale evidence gates. The web-only asset-byte
proof is retained and green on host/full/coverage; Chrome's runner cannot
complete that one proof, so it is explicitly skipped rather than replaced with
path-only assertions.

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
- [x] Current-head representative text-scale, mid/late cadence, both
  transition merges, fresh-to-Mars completion, and normal reload were observed
  live without save/clock/progression shortcuts.
- [x] Full Chrome suite and APK/web/iOS exact builds were run and passed; the
  web-only byte-load proof is explicitly skipped because the Chrome runner
  stalls on its first request, while host/full/coverage keep the proof active.
- [ ] Existing `.playwright-cli/` live-session artifacts are preserved outside
  this documentation-only commit per the follow-up scope.

## Concerns for follow-up

1. The accessibility run used the iPad Pro simulator rather than physical
  hardware; direct raw Xcode invocation still has the known
  `audioplayers_darwin` module issue, while the Flutter simulator build and
  installed app session pass.
2. Investigate the Flutter Chrome test runner's first `rootBundle` byte-load
  stall if browser-side asset-byte coverage becomes a release requirement; the
  host/full/coverage proof remains active and the browser skip is explicit.
