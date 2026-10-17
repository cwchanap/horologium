# HPA-418 Frozen Basin Animated Mining Site Implementation Plan

- Date: 2026-10-16
- Linear: [HPA-418](https://linear.app/cwchanap/issue/HPA-418/mining-polish-animate-frozen-basin-as-the-second-mining-site)
- Design: `docs/superpowers/specs/2026-10-16-hpa-418-frozen-basin-animation-design.md`

## Delivery rule

One ticket = one PR. Planning lands first on this draft PR; implementation lands on the same PR after plan review. Do not open a second implementation PR.

Task 1 is behavior-preserving and must be green before any Frozen Basin behavior lands.

This ticket generates no art. The water-ice frame family is its own art ticket and PR, [HPA-404](https://linear.app/cwchanap/issue/HPA-404/mining-art-water-ice-deposit-frame-family-for-frozen-basin), which blocks Task 2. Start Task 2 only after HPA-404 merges, by rebasing this branch onto `main` (no merge commit; force-push with lease) so the 15 `node-water-ice-…` files are present.

## Task 1: Generalize the Landing Basin layer without changing behavior

### Production

- `lib/mining/presentation/mining_visuals.dart`
  - Add `MiningDepositFrames` with `gold` and `waterIce` constants, `slug`, `stage(int)`, `idle(int)`, `hit(int)`, `exhaust(int)` (same ranges and `RangeError`s as today), and `all` (stage 1–4, idle 1–4, hit 1–3, exhaust 1–4).
  - Add `static MiningDepositFrames? depositFramesFor(MiningSiteId id)` as an exhaustive `switch`: `landingBasin => MiningDepositFrames.gold`; every other site `=> null` in this task.
  - Remove `goldNodeStageAsset`, `goldNodeIdleAsset`, `goldNodeHitAsset`, and `goldNodeExhaustAsset`.
  - Rename `landingBasinRobotBodyAsset` / `landingBasinRobotArmAsset` to `miningRobotBodyAsset` / `miningRobotArmAsset`, returning `assets/images/mining/robots/robot_${tier.name}_{body,arm}.png`.
- `git mv assets/images/mining/landing_basin assets/images/mining/robots`; in `pubspec.yaml` replace `- assets/images/mining/landing_basin/` with `- assets/images/mining/robots/`.
- `git mv lib/mining/presentation/landing_basin_grid_visual_layer.dart lib/mining/presentation/animated_mining_grid_visual_layer.dart`, then:
  - rename the widget to `AnimatedMiningGridVisualLayer` and add `required MiningDepositFrames frames`;
  - derive `String get _keyPrefix` from `widget.view.siteId.name` in kebab case (`landingBasin` → `landing-basin`) and build every existing key as `'$_keyPrefix-…'`, so Landing Basin keys are unchanged;
  - read every frame path in `_precacheFrames` and `_depositAsset` from `widget.frames`;
  - rename `landingBasinMaxHp`, `landingBasinStrikeDamage`, `landingBasinGroupedDamage`, and `landingBasinRemainingHpAfterStrike` to `miningResourceMaxHp`, `miningStrikeDamage`, `miningGroupedDamage`, and `miningRemainingHpAfterStrike` with identical bodies.
- `lib/mining/presentation/mining_grid_map.dart`: `_objectLayer()` uses `MiningVisuals.depositFramesFor(view.siteId)` and builds `AnimatedMiningGridVisualLayer(key: Key('$prefix-grid-visual-layer'), frames: frames, …)` when non-null, else the static layer.
- `lib/mining/presentation/mining_shell.dart`: rename `_landingBasinImpactSequence` to `_miningImpactSequence`. In `_refreshForegroundProduction`, read the open site (not Landing Basin) and increment only when `depositFramesFor(openSite) != null`, it has a rig, and its `storedAmount` grew. `_playMiningImpact` checks `depositFramesFor(_openSiteId)` instead of `== MiningSiteId.landingBasin`.

### Tests

- `git mv test/mining/presentation/landing_basin_grid_visual_layer_test.dart test/mining/presentation/animated_mining_grid_visual_layer_test.dart`; update symbols only. Every `landing-basin-…` finder stays as is.
- `test/support/mining_visual_frames.dart`: replace `warmGoldFrames(tester)` with `warmDepositFrames(tester, MiningDepositFrames frames)` iterating `frames.all`, and update its callers (layer, Mine Site screen, shell tests) to pass `MiningDepositFrames.gold`. Fold the private `_warmGoldFrames` in `mine_site_screen_test.dart` into the shared helper.
- `test/mining/presentation/mining_visuals_test.dart`: keep the gold path tables, now read from `MiningDepositFrames.gold`; assert `depositFramesFor` returns gold for Landing Basin and `null` for the other eight sites; robot paths resolve under `robots/` and all ten images still decode.
- Run:

```sh
flutter test test/mining/presentation/animated_mining_grid_visual_layer_test.dart \
  test/mining/presentation/mining_visuals_test.dart \
  test/mining/presentation/mining_grid_map_test.dart \
  test/mining/presentation/mine_site_screen_test.dart \
  test/mining/presentation/mining_shell_test.dart \
  test/mining/presentation/visual_parity_golden_test.dart
```

All existing assertions, including goldens, must pass unchanged. Commit this task on its own.

## Task 2: Turn Frozen Basin on

### Tests first

- `mining_visuals_test.dart`
  - `MiningDepositFrames.waterIce` maps every index to its `node-water-ice-…` path; out-of-range indices throw.
  - `depositFramesFor(frozenBasin)` is `waterIce`; the other seven non-animated sites stay `null`.
  - Host-only (skip on web): every water-ice frame decodes at 512×512; S1 and idle-01 bytes equal `water_ice.png`, exhaust-01 equals S3, exhaust-04 equals S4.
- `animated_mining_grid_visual_layer_test.dart`, new `group('Frozen Basin', …)` built from a Frozen Basin `MineSiteView` at Surveying 3 with one T1 rig on a surveyed resource:
  - stage plate is `node-water-ice-s1` / `s2` / `s3` / `s4` at progress 0.24 / 0.25 / 0.60 / 0.90;
  - the S1 idle loop cycles the four water-ice idle frames every 125 ms and stops outside S1;
  - a warmed impact shows hit 01–03 between t = 0.24 and 0.49;
  - crossing 0.90 on a new impact plays exhaust 01–04 and settles on S4;
  - HP chrome and damage labels render under `frozen-basin-hp-…` and `frozen-basin-damage-…` keys, and a valid T1 contact drops HP by 10 exactly once;
  - a cold-cache impact is dropped with full HP and no labels;
  - reduced motion shows the static stage plate and a stationary arm.
- `mining_grid_map_test.dart`: Frozen Basin hosts `frozen-basin-grid-visual-layer` and no static layer; Carbon Ridge is unchanged.
- `mining_shell_test.dart`, with a helper `deployedFrozenBasinState(now)` (Homeworld mastered, Lunar Frontier unlocked and active, Surveying 3, one T1 rig on Frozen Basin):
  - opening Frozen Basin and running one `pumpMiningTick` increments the `MineSiteScreen.impactSequence` by one and plays `audio/mining.wav` after the two taps (warm `MiningDepositFrames.waterIce` first);
  - closed, unrigged, and already-full Frozen Basin emit no impact;
  - lifecycle resume emits no impact;
  - leaving Landing Basin and opening Frozen Basin emits no impact until the next producing tick.

### Production

- `MiningVisuals.depositFramesFor`: `frozenBasin => MiningDepositFrames.waterIce`.
- No other production change is expected; if one is needed, it belongs in Task 1's generalization, not in a Frozen Basin special case.

Run the Task 1 command plus the new tests.

## Task 3: Guidance and gates

- `CLAUDE.md`:
  - replace "Landing Basin is the first authored animated mining site." with "Landing Basin and Frozen Basin are the authored animated mining sites, selected by the closed `MiningVisuals.depositFramesFor` switch."
  - replace the "Landing Basin robot/deposit animation…", "Landing Basin resource HP…", and "Add another site-specific visual path…" bullets with the same rules stated for animated sites, plus: "Add an animated site only with an approved frame family and a new `depositFramesFor` case; there is no visual registry."
  - in the grid paragraph, replace "Landing Basin remains the only site-specific animated visual layer" with "Animated sites share one visual layer".
  - in the audio section, replace "The Landing Basin visual reports its visible strike" with "An animated site's visual reports its visible strike".
- Run the repository gates:

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

- Coverage stays at or above the 90% Codecov gate.
- Scope audit: `git diff --name-only origin/main...HEAD` lists only the paths below.

## Expected changed paths

Planning (this draft PR as opened):

- `docs/superpowers/specs/2026-10-16-hpa-418-frozen-basin-animation-design.md`
- `docs/superpowers/plans/2026-10-16-hpa-418-frozen-basin-animation.md`

Implementation (same PR, after review):

- `lib/mining/presentation/animated_mining_grid_visual_layer.dart` (renamed from `landing_basin_grid_visual_layer.dart`)
- `lib/mining/presentation/mining_visuals.dart`
- `lib/mining/presentation/mining_grid_map.dart`
- `lib/mining/presentation/mining_shell.dart`
- `assets/images/mining/robots/` (renamed from `landing_basin/`, byte-identical)
- `pubspec.yaml` (asset directory rename only)
- `CLAUDE.md`
- `test/mining/presentation/animated_mining_grid_visual_layer_test.dart` (renamed)
- `test/mining/presentation/mining_visuals_test.dart`
- `test/mining/presentation/mining_grid_map_test.dart`
- `test/mining/presentation/mine_site_screen_test.dart`
- `test/mining/presentation/mining_shell_test.dart`
- `test/support/mining_visual_frames.dart`

The `node-water-ice-…` files arrive from `main` through HPA-404 and are not part of this PR's diff.

No change to the controller, simulation, repository, save, content values, Site Deck, Stellar Map, Technology sheet, or goldens.
