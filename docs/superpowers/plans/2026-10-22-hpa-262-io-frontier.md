# HPA-262 Io Frontier Implementation Plan

- Original date: 2026-10-22; reviewed on 2026-11-04 and 2026-11-05 ([first review](https://github.com/cwchanap/horologium/pull/45#issuecomment-6649527059), [latest review](https://github.com/cwchanap/horologium/pull/45#pullrequestreview-5794275309))
- Linear: [HPA-262](https://linear.app/cwchanap/issue/HPA-262/mining-content-ship-io-frontier-as-the-fifth-planet-after-ceres)
- Design: [Io Frontier design](../specs/2026-10-22-hpa-262-io-frontier-design.md)

## Delivery and boundaries

**One ticket = one PR.** Reuse [draft PR #45](https://github.com/cwchanap/horologium/pull/45). Commit implementation to this PR after reviewing its planning documents; do not open a separate implementation PR.

Keep the branch based on current `main` for implementation (rebase with force-with-lease if it diverges again; no merge commit). [HPA-87 / PR #51](https://github.com/cwchanap/horologium/pull/51) already supplied all seven required Io images. [HPA-427 / PR #48](https://github.com/cwchanap/horologium/pull/48) already supplied Relaunch. No new art, SFX, state owner, migration, generic progression engine, or animated Io site is in scope. **Append enum values** rather than inserting or reordering them; `_denseResourceField` uses `MiningSiteId.index` to seed layout.

**Sequence is intentional:** first bring the content and the **focused public-action journey** to green, and measure/tune pacing before adding or updating hard-coded values in unit/view tests. **Task 1 gates only on the journey test.** The existing full suite is expected to fail temporarily on stale four-planet/twelve-site and Ceres-as-final assertions. Fix those together in Task 2 once the numbers are final, where **the full suite** becomes the gate. Do not leave the PR ready for review or merge with a red full suite.

## Task 1 — Content, full-journey refactor, then pacing measurement

### Content changes

- `lib/game/resources/resource_type.dart`: append `sulfur`, `cinnabar`, `osmium` after `iridium`.
- `lib/mining/mining_content.dart`:
  - append `MiningPlanetId.ioFrontier` and `MiningSiteId.sulfurFlats/cinnabarVents/osmiumCaldera`;
  - add each new site's `_surveyingProgressionLevels` of `[5, 5, 5, 5]` and three Material `resourceSilhouettes`;
  - author Io with Ceres mastery + Surveying 5 + candidate **90M** unlock, **22.5M** rig spawn, two starter T1 bays, and starter Sulfur Flats;
  - author site costs **0 / 55M / 135M**, rates **0.60 / 0.45 / 0.30**, capacities **4320 / 3240 / 2160**, unit sale values **300 / 550 / 1050**, required-site chaining, and each site's `_denseResourceField`;
  - use `assets/images/mining/planets/io_frontier.png`; for each resource, `caverns/<resource>.png` is both cavern and card art, and `nodes/<resource>.png` is the node art (paths relative to `assets/images/mining/`);
  - set Ceres `masteryRewardCash: 0`; Io's candidate reward is **90M** and must **always equal its final unlock cost** after tuning.
- `lib/mining/presentation/offline_return_sheet.dart`: add all three resources to the exhaustive `_resourceIcon` `null` arm.
- `lib/mining/presentation/mining_visuals.dart`: add the three new site IDs to `MiningVisuals.depositFramesFor`'s exhaustive `null` arm. Io uses the static layer; no frame family is authored.

### Refactor and extend the public-action journey **before pinning exact Io amounts**

In `test/integration/merge_mining_journey_test.dart`, keep the Homeworld and Lunar progression steps as-is: they have unique Surveying/active-play rules. Replace only the duplicated **Mars and Ceres frontier blocks** with one small `_playFrontier(player, planetId)` helper, and call it for Mars, Ceres, and Io in both runs.

The helper reads `MiningPlanetDefinition` and `MiningSiteDefinition` instead of restating prices:

1. Name the phase `<previous planet> mastery before <current planet> unlock`, `earnUntil(planet.unlockCashCost)`, then `controller.unlockPlanet(id)`. Assert the active planet, two starter T1 rigs, and first site unlocked.
2. Merge bays b1+b2; deploy the resulting T2 to `planet.sites.first` using `journeyCell`. For each subsequent site: `earnUntil(site.unlockCost + planet.rigSpawnCost)`, unlock it, then spawn and commission via controller. Retain a goal assertion on the last site.
3. Check the before/after cash delta and mastery message from `planet.masteryRewardCash`: no reward/message on Mars and Ceres, a one-time reward on Io. Check the next goal is `Unlock <next planet>` for non-final frontiers or `Relaunch` for `content.finalPlanetId`.
4. Return the **mastery time since run start**; after the final helper call, keep the all-sites-commissioned check and perform the recall/redeploy/no-double-reward check on the final planet's final site.

Keep explicit assertions that Relaunch is **not** available after Ceres mastery. In `_journey`, change the reload assertion from `MiningPlanetId.ceresFrontier` to `MiningPlanetId.ioFrontier` (or `content.finalPlanetId`), and assert `reloaded.state.activePlanetId` is Io. Preserve the 24-hour offline-accrual cap, relaunch reset/increment, and the complete run-2 replay. Do not move gameplay mutations into test fixture state.

Return run milestones `{opening, mars, ceres, io}` instead of `{opening, mars, last}`. In `_journey`, assert `run1.mars` against the **existing Mars bounds** and `run1.ceres` against the **existing Ceres bounds**; do not compare `run1.io` (or a renamed `last`) against `ceresMaximum`. After the first focused run measures the Io milestone, add an `ioMinimum..ioMaximum` from that observed run-1 result and assert `run1.io` against those **new Io bounds** in both cadence records. Preserve the absolute from-run-start nature of all three bands. Define run-1 **Ceres phase = Ceres mastery − Mars mastery** and **Io phase = Io mastery − Ceres mastery**. The Io phase intentionally includes the cash wait between Ceres mastery and Io unlock. Ensure `CADENCE` logs name that cash wait, and print both phases in `MASTERY` logs for 2-hour and 6-hour cadences. The existing review's `main` baseline is **22 h / 66 h** for the full Ceres phase (including its 6 h / 18 h cash wait), not 16 h / 48 h unlock-to-mastery.

Measure Io's run-1 phase against **1.2×–2×** the observed run-1 Ceres phase. If it misses at either cadence, apply **one factor** to Io unlock, both paid site costs, and rig spawn cost; recompute `masteryRewardCash` to equal the final unlock. Do **not** tune the reward independently: it arrives after Io mastery and cannot shorten that phase. Keep rates and sale values constant. Record the factor, the observed timings, and new absolute Io run-1 bounds chosen with margins comparable to existing Mars/Ceres bounds. Keep run 2 relative to run 1: at most 80% at 2-hour cadence; strictly faster at 6-hour cadence.

### Task 1 gate — journey only

Update **journey-local** Ceres final-reward and Relaunch assertions immediately so the extended journey tests the new final planet and two complete runs. Measure, tune, and pin only the journey's new Io bands once. Defer stale exact-value unit/widget assertions and the controller fixture cleanup to Task 2; their temporary failures are expected while numbers remain provisional.

```sh
flutter test test/integration/merge_mining_journey_test.dart
```

Do **not** require full `flutter test` here: it would force the same literal prices to be updated twice.

## Task 2 — Pin measured values and cover behavior, save, and views

Once the Task 1 journey is passing and prices are final, repair all invalidated existing test expectations (including stale final-Ceres assertions) and then add only necessary focused coverage:

- `test/resources/resource_type_test.dart`: all fifteen resource enum members in order.
- `test/mining/mining_content_test.dart`: **single authoritative set of exact Io numbers**, capacity invariant, complete required-site order, fifteen unique site/resource IDs, full asset resolution, and only Io having a mastery reward.
- `test/mining/mining_state_test.dart`, `test/mining/mining_save_repository_test.dart`: five dock maps, fifteen sites, round-trip; retain a four-planet/twelve-site legacy fixture that clean-resets with the recovered flag; a locked Io with rig or unlocked site is rejected; preserve the strict **eight-key** root including `relaunchCount`.
- `test/mining/mining_controller_test.dart`: **reuse the existing Ceres unlock guard-order test** (generic code path) rather than duplicating it for Io; retarget existing final-reward and Relaunch gating tests to Io and Ceres's new no-reward status. Rewrite `finalPlanetMasteredState()` using `MiningPlanetId.values.last` and the authored sites (as `_masteredSave()` already does in `stellar_map_screen_test.dart`) instead of a manual twelve-site list. **Fix the `docksFor()` helper at lines 149–159:** start with every enum planet, e.g. `{for (final id in MiningPlanetId.values) id: dock()}`, then override only the explicitly supplied Homeworld/Lunar/Mars/Ceres dock maps. Do **not** merely add a fifth hardcoded `io` parameter/map entry: the helper should remain valid for later content additions without editing its callers.
- `test/mining/mining_simulation_test.dart`: five unlocked planets accrue in one window; selling clears only active-planet cargo.
- `test/mining/mining_progression_views_test.dart`, `test/mining/next_goal_view_test.dart`: Io teaser/locked card, `15 of 15`, Ceres → Io → Relaunch goal ladder, final-site reward detail and the no-reward Ceres detail. Assertions on displayed currency may use the finalized `formatMiningCash` amount.
- `test/mining/presentation/site_deck_screen_test.dart`, `stellar_map_screen_test.dart`, `mine_site_screen_test.dart`, `offline_return_sheet_test.dart`, `mining_visuals_test.dart`: static Io view and icon/fallback rendering; no overflow at 360×640 and 430×932, no animated frame requirement. Reuse existing widget helpers where possible.
- Search remaining stale fixed lists/counts: `rg -n "iridiumSpire|iridium|ceresFrontier|30000000|30\.00M" test` and update only assertions invalidated by the fifth planet.

```sh
flutter test test/resources test/mining
flutter test
```

**Task 2 is the first full-suite green gate.** Every changed test should pass with the finalized values before moving to Task 3.

## Task 3 — Document the proven outcome and run repository gates

- Update `CLAUDE.md`: five planets / fifteen sites, Io gate, zero Ceres mastery reward, final Io reward, five docks/strict save, Relaunch after Io, and the two-run journey.
- Update the design with **measured final** Io amounts, the shared factor, both cadence-specific Ceres and Io phases, final absolute Io bands, and mark `Status: Implemented` **only after** tests succeed.
- Add the final `CADENCE` / `MASTERY` logs to PR #45; explicitly record the previous-mastery-to-next-mastery phase definition and the run-2 speed-up result.
- Confirm the PR diff includes no art assets or new subsystems. Keep the same PR throughout.

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

## Expected changes (same PR #45)

**Planning phase (docs-only commits, historical):** this plan and `docs/superpowers/specs/2026-10-22-hpa-262-io-frontier-design.md`.

**Implementation (landed on this branch):** `lib/game/resources/resource_type.dart`, `lib/mining/mining_content.dart`, `lib/mining/presentation/offline_return_sheet.dart`, `lib/mining/presentation/mining_visuals.dart`, existing matching tests under `test/resources/`, `test/mining/`, `test/integration/merge_mining_journey_test.dart`, and `CLAUDE.md`.

Io's seven images already exist on `main` via HPA-87 / PR #51 and **must not appear in this PR's diff**. The docs-only review commits ran no Flutter tests or builds; the implementation that followed passed all repository gates locally — see the spec's `Status: Implemented (2026-11-05)` line.
