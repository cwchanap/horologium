# HPA-262 Io Frontier Implementation Plan

- Date: 2026-10-22
- Linear: [HPA-262](https://linear.app/cwchanap/issue/HPA-262/mining-content-ship-io-frontier-as-the-fifth-planet-after-ceres)
- Design: `docs/superpowers/specs/2026-10-22-hpa-262-io-frontier-design.md`

## Delivery rule

One ticket = one PR. Planning lands first on this draft PR; implementation lands on the same PR after plan review **and after [HPA-87](https://linear.app/cwchanap/issue/HPA-87/mining-art-io-frontier-planet-cavern-and-node-art) merges**. Before Task 1, rebase onto `main` (no merge commit; force-push with lease) so the seven Io images are present. If HPA-427 (Relaunch) has merged by then, its journey second run extends through Io as part of Task 3.

This ticket generates no art.

## Task 1: Content, resources, and save shape

### Production

- `lib/game/resources/resource_type.dart`: add `sulfur`, `cinnabar`, `osmium` after `iridium`.
- `lib/mining/mining_content.dart`:
  - add `ioFrontier` to `MiningPlanetId` after `ceresFrontier`, and `sulfurFlats`, `cinnabarVents`, `osmiumCaldera` to `MiningSiteId`;
  - add `[5, 5, 5, 5]` for each new site to `_surveyingProgressionLevels`;
  - add three `resourceSilhouettes` entries from the design table;
  - author the Io `MiningPlanetDefinition` and its three sites from the design tables, with `_denseResourceField(siteId)`, the new asset paths, and the facility and discovery copy;
  - set Ceres `masteryRewardCash: 0`.
- `lib/mining/presentation/offline_return_sheet.dart`: add the three resources to `_resourceIcon`'s `null` arm.

### Tests

- `test/resources/resource_type_test.dart`: fifteen values in order.
- `test/mining/mining_content_test.dart`: Io values, asset paths, silhouettes, ordering and capacity invariants, "only Io has a mastery reward".
- `test/mining/mining_state_test.dart`: Io docks empty and sites locked initially.
- `test/mining/mining_save_repository_test.dart`: retarget current-shape fixtures to fifteen sites and five dock maps; keep one twelve-site fixture that clean-resets; add a locked-Io rejection.
- Before running, search for stale exhaustive lists: `rg -n "iridiumSpire|iridium|ceresFrontier" test`, and fix every exact list or count of twelve sites, twelve resources, or four planets.

```sh
flutter test test/resources test/mining/mining_content_test.dart \
  test/mining/mining_state_test.dart test/mining/mining_save_repository_test.dart
```

## Task 2: Controller, simulation, and views

No production change is expected; add characterization tests and change code only where a test exposes a generic bug.

- `test/mining/mining_controller_test.dart`: Io unlock guard order and success effects; the final Ceres commission returns no message and adds no cash; the final Io commission adds 90,000,000 once with `Io mastered — +90.00M cash.`.
- `test/mining/mining_simulation_test.dart`: one window over five unlocked planets.
- `test/mining/mining_progression_views_test.dart`: Io teaser and locked card; Surveying copy `15 of 15`.
- `test/mining/next_goal_view_test.dart`: Ceres last site shows no reward line; ladder goes Ceres mastery → `Unlock Io Frontier` → Io sites → the end-of-run step; last Io site shows `+90.00M`.

```sh
flutter test test/mining
```

## Task 3: Presentation, journey, and pacing

### Tests

- `site_deck_screen_test.dart`, `stellar_map_screen_test.dart`, `offline_return_sheet_test.dart`: an Io deck, an Io teaser and locked card (compact `90.00M`), and an Io offline section at 360×640 and 430×932 with no overflow.
- `test/integration/merge_mining_journey_test.dart`: after Ceres, expect no reward and the next goal `Unlock Io Frontier`; earn to the unlock at both cadences; unlock Io and check its starter dock and site; commission all three sites; expect the single reward; reload on Io. Keep the Mars and Ceres bands; add an Io band per cadence. Rename the test to "through Io".

### Pacing check

Print the Io phase (Io unlock to mastery) next to the Ceres phase. If the Io phase is outside 1.2×–2× the Ceres phase at either cadence, multiply the Io unlock, the two site unlocks, the spawn cost, and the reward by one common factor and re-run. Record the final factor and the `CADENCE` / `MASTERY` lines in the PR, then set the Io bands around the measured times as HPA-403 did.

```sh
flutter test test/integration/merge_mining_journey_test.dart test/mining/presentation
```

## Task 4: Docs and gates

- `CLAUDE.md`: three sites on each of five planets; Ceres mastery plus Surveying 5 plus the Io cash cost unlocks Io; Io mastery grants the single reward and Ceres grants none; `sites` contains all fifteen `MiningSiteId` values; the journey runs "through Io".
- Update the design's numbers to the measured ones and mark it `- Status: Implemented`.

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

## Expected changed paths

Planning (this draft PR as opened):

- `docs/superpowers/specs/2026-10-22-hpa-262-io-frontier-design.md`
- `docs/superpowers/plans/2026-10-22-hpa-262-io-frontier.md`

Implementation (same PR, after review):

- `lib/game/resources/resource_type.dart`
- `lib/mining/mining_content.dart`
- `lib/mining/presentation/offline_return_sheet.dart`
- the matching tests under `test/resources/`, `test/mining/`, `test/mining/presentation/`, and `test/integration/merge_mining_journey_test.dart`
- `CLAUDE.md`

The seven Io images arrive from `main` through HPA-87 and are not part of this PR's diff.
