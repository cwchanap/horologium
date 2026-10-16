# HPA-403 Ceres Frontier Implementation Plan

- Date: 2026-10-16
- Linear: [HPA-403](https://linear.app/cwchanap/issue/HPA-403/ship-a-fourth-planet-content-pack-after-mars)
- Design: `docs/superpowers/specs/2026-10-16-hpa-403-ceres-frontier-design.md`

## Delivery rule

One ticket = one PR. Planning lands first on this draft PR; implementation lands on the same PR after plan review **and after both HPA-401 and [HPA-439](https://linear.app/cwchanap/issue/HPA-439/mining-art-ceres-frontier-planet-cavern-and-node-art) merge**. Before Task 1, rebase this branch onto `main` (no merge commit; force-push with lease) so the Ceres numbers sit on HPA-401's capacities, prices, compact formatter, and journey, and the seven Ceres images are present.

This ticket generates no art; HPA-439 is the art-only ticket and PR. Implementation waits for it because the existing all-content-assets test in `test/mining/presentation/mining_visuals_test.dart` loads every authored planet, cavern, node, and card path, so pushing Ceres content before the art is on `main` would turn CI red.

## Task 1: Content, resources, and save shape

### Production

- `lib/game/resources/resource_type.dart`: add `nickelOre`, `platinum`, `iridium` after `cobaltOre`.
- `lib/mining/mining_content.dart`:
  - add `ceresFrontier` to `MiningPlanetId` and `nickelShoals`, `platinumRift`, `iridiumSpire` to `MiningSiteId`;
  - add `[5, 5, 5, 5]` for each new site to `_surveyingProgressionLevels`;
  - add three `resourceSilhouettes` entries from the design table;
  - author the Ceres `MiningPlanetDefinition` and its three sites from the design tables, with `_denseResourceField(siteId)`, the new cavern/node/card asset paths, and the facility and discovery copy;
  - set Mars `masteryRewardCash: 0`.
- `lib/mining/presentation/offline_return_sheet.dart`: add the three resources to `_resourceIcon`'s `null` arm.

### Tests

- `test/resources/resource_type_test.dart`: twelve values in order.
- `test/mining/mining_content_test.dart`: Ceres planet and site values, asset paths, silhouettes, the `requiredSite` ordering invariant over four planets, the HPA-401 capacity invariant, and "only Ceres has a mastery reward".
- `test/mining/mining_state_test.dart`: initial Ceres docks are empty and its sites locked.
- `test/mining/mining_save_repository_test.dart`: retarget every current-shape fixture to twelve sites and four dock maps; keep one intentional nine-site fixture that clean-resets with `recoveredFromInvalidSave`; add a locked-Ceres-with-docked-rig rejection.
- Search for stale exhaustive lists before running: `rg -n "cobaltChasm|cobaltOre|marsFrontier" test`, and fix every exact list or count of nine sites, nine resources, or three planets.

```sh
flutter test test/resources test/mining/mining_content_test.dart \
  test/mining/mining_state_test.dart test/mining/mining_save_repository_test.dart
```

## Task 2: Controller, simulation, and views

No production change is expected. Add characterization tests; change code only where a test exposes a generic bug.

- `test/mining/mining_controller_test.dart`: Ceres unlock guard order (Mars mastery, Surveying 5, cash) and success effects; the final Mars commission returns no message and adds no cash; the final Ceres commission adds 30,000,000 once with `Ceres mastered — +30,000,000 cash.`.
- `test/mining/mining_simulation_test.dart`: one window over four unlocked planets; a full Ceres site; a locked Ceres producing nothing.
- `test/mining/mining_progression_views_test.dart`: Stellar Map hides Ceres before Mars is unlocked and shows it locked with Mars as prerequisite afterwards; Surveying copy `12 of 12` with all planets unlocked.
- `test/mining/next_goal_view_test.dart`: Mars last site shows no reward line; ladder goes Mars mastery → `Unlock Ceres Frontier` → Ceres sites → `All frontiers mastered`; last Ceres site shows `+30,000,000`.

```sh
flutter test test/mining
```

## Task 3: Presentation and journey

### Production

- `lib/mining/presentation/site_deck_screen.dart`: delete `_planetAsset` and read `content.planet(id).planetAsset` at its call sites.

### Tests

- `test/mining/presentation/site_deck_screen_test.dart`, `stellar_map_screen_test.dart`, `offline_return_sheet_test.dart`: a Ceres deck, a locked and an unlocked Ceres card, and a Ceres offline section, at 360×640 and 430×932 with no overflow.
- `stellar_map_screen_test.dart`: the locked Ceres card's unlock copy shows the compact amount (`30.00M`), not raw digits. HPA-401 Task 1 already routes `stellar_map_screen.dart:768` through `formatMiningCash`; if this assertion fails, fix that string generically with its own test.
- `test/integration/merge_mining_journey_test.dart`: after Mars, expect no reward and the next goal `Unlock Ceres Frontier`; earn to 30,000,000 with HPA-401's two-hour steps; unlock Ceres and check its starter dock and site; merge, deploy, commission Nickel Shoals, Platinum Rift, and Iridium Spire; expect the single 30,000,000 reward and `All frontiers mastered`; reload on Ceres. Keep the `CADENCE` and `SEQUENCE` lines and update the test name to "through Ceres".

```sh
flutter test test/integration/merge_mining_journey_test.dart test/mining/presentation
```

Record the journey's `CADENCE` totals in the PR. If the Ceres phase takes more than twice the Lunar-to-Mars phase in the journey, lower the three Ceres prices and the reward by the same factor.

## Task 4: Docs and gates

- `CLAUDE.md`:
  - Active ownership boundary and economy sections: three sites on each of Homeworld, Lunar Frontier, Mars Frontier, and Ceres Frontier; Mars mastery plus Surveying 5 plus cash unlocks Ceres; Ceres mastery grants exactly one 30,000,000 reward and Mars grants none.
  - State and save contract: `sites` contains all twelve authored `MiningSiteId` values.
  - Public-action journey: "through Ceres".
- Mark the design `- Status: Implemented`.

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

The Flutter SDK is not installed in the planning container; install it before implementation.
