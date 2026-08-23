# HPA-641 Mars Frontier Content Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Mars Frontier as one complete third-planet content pack using the existing Reveal → Build → Mine → Sell → Upgrade loop, with Lunar mastery + Surveying 5 + cash unlock, tested two-planet-save evolution, deterministic three-planet accrual, and a simple Mars mastery cash reward.

**Architecture:** Preserve the HPA-638 single-controller/simulation/repository architecture and flat globally unique sector state. Add Mars as authored catalog data. Widen only the seams that are now proven to have a second consumer: planet unlock metadata, planet mastery, Stellar Map planet cards, locked-planet validation, and additive six-to-nine-sector save evolution.

**Tech Stack:** Dart 3.8, Flutter, Flame 1.30, SharedPreferences 2.5, existing `flutter_test` suites.

**Spec:** `docs/superpowers/specs/2026-08-22-hpa-641-mars-frontier-content-pack-design.md`

## Global constraints

- One branch and one PR for HPA-641; continue implementation on this draft PR.
- Exactly one new planet: Mars Frontier.
- Exactly three Mars sectors and three new raw resources.
- Keep Surveying capped at 5; do not add another technology tier.
- Keep one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `horologium.mining.save`, and active `MiningGame`.
- Keep `MiningSave.sectors` flat.
- Preserve the HPA-638 two-planet save with one narrow six-sector → nine-sector evolution; no `schemaVersion` or migration framework.
- No new image/audio files. Reuse shipped facility images and Material icons.
- No generic requirement/reward engine, processing, logistics, worker, market, retention, or DLC infrastructure.
- Each implementation task ends with `flutter analyze --fatal-infos` and `flutter test` green before commit.

## Frozen Mars values

| Sector | Resource | Facility | Surveying | Reveal | Build | Rate/s | Capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Ochre Basin | Iron Ore | Iron Rig | 5 | 0 | 5,000 | 0.75 | 180 | 32 | 7,000 / 14,000 / 28,000 / 56,000 |
| Silica Dunes | Silica | Silica Extractor | 5 | 12,000 | 9,000 | 0.55 | 160 | 55 | 12,000 / 24,000 / 48,000 / 96,000 |
| Cobalt Chasm | Cobalt Ore | Cobalt Drill | 5 | 30,000 | 18,000 | 0.35 | 130 | 110 | 24,000 / 48,000 / 96,000 / 192,000 |

Mars Frontier: seed `641`, tint `0xFF2A1512`, unlock after Lunar mastery + Surveying 5 + 20,000 cash, mastery reward 25,000 cash.

## Expected final file map

**Core/content**
- `lib/game/resources/resource_type.dart` — add Iron Ore, Silica, Cobalt Ore identities.
- `lib/mining/mining_content.dart` — Mars catalog, unlock metadata, mastery helper, resource silhouettes, optional discovery/facility copy.
- `lib/mining/mining_state.dart` — canonical nine-sector initial state only.
- `lib/mining/mining_save_repository.dart` — strict six-to-nine evolution and generic locked-planet invariant.
- `lib/mining/mining_controller.dart` — data-driven planet unlock and Mars mastery reward through normal build flow.
- `lib/mining/mining_progression_views.dart` — list-based Stellar Map planet projections.
- `lib/mining/mining_sheet_view.dart` — surface authored resource/discovery/facility copy without changing actions.

**Flutter**
- `lib/mining/presentation/stellar_map_sheet.dart` — render authored planet cards and generic unlock/travel callbacks.
- `lib/mining/presentation/mining_screen.dart` — wire generic unlock callback and optional success message.

**Expected no structural change**
- `lib/mining/mining_simulation.dart` — characterization should prove three-planet reuse; modify only for a concrete bug.
- `lib/mining/world/mining_game.dart` — existing planet projection should accept Mars unchanged.
- `lib/mining/presentation/offline_return_sheet.dart` — existing grouped summary should render Mars unchanged.

**Tests**
- `test/mining/mining_content_test.dart`
- `test/mining/mining_state_test.dart`
- `test/mining/mining_save_repository_test.dart`
- `test/mining/mining_controller_test.dart`
- `test/mining/mining_progression_views_test.dart`
- `test/mining/mining_sheet_view_test.dart`
- `test/mining/mining_simulation_test.dart`
- `test/mining/presentation/stellar_map_sheet_test.dart`
- `test/mining/presentation/mining_screen_test.dart`
- existing world/offline-return tests only where needed to pin unchanged reuse

---

## Task 1: Add the Mars catalog and preserve the HPA-638 save

**Files:**
- Modify: `lib/game/resources/resource_type.dart`
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_state.dart`
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_state_test.dart`
- Modify: `test/mining/mining_save_repository_test.dart`

### Step 1: Add RED Mars catalog tests

- [ ] Assert `MiningPlanetId.values` / registry contain exactly Homeworld, Lunar Frontier, and Mars Frontier in the intended authored order.
- [ ] Assert Mars name, seed `641`, tint `0xFF2A1512`, three sector IDs, fixed anchors, reveal chain, Surveying 5 gates, costs, rates, capacities, sale values, and upgrade curves exactly match the frozen brief.
- [ ] Assert new `ResourceType` values and `ResourceSilhouette` display names/icons/colors exist.
- [ ] Assert `facilityName` and `discoveryText` carry the three Mars authored entries.

Run:

```sh
flutter test test/mining/mining_content_test.dart
```

Expected: RED because Mars identities/catalog values do not exist.

### Step 2: Add RED initial-state and save-evolution tests

- [ ] Change initial-state expectation from six to nine exact sector IDs; all Mars sectors are unrevealed with no mines.
- [ ] Build a raw HPA-638 document with exactly the prior six sector keys and nontrivial state: cash, technology, Lunar unlocked/active, existing mines, and cargo.
- [ ] Load it and assert every existing value survives while the three Mars sectors are appended pristine.
- [ ] Save the evolved state and assert the written `sectors` object has exactly the nine canonical keys.
- [ ] Assert a locked Mars with any revealed sector or mine is rejected through the existing recovery boundary.
- [ ] Keep malformed/unknown-key recovery tests strict.

Run:

```sh
flutter test test/mining/mining_state_test.dart \
  test/mining/mining_save_repository_test.dart
```

Expected: RED until canonical Mars state and six-to-nine evolution exist.

### Step 3: Implement the smallest catalog/state change

- [ ] Add `marsFrontier` to `MiningPlanetId`.
- [ ] Add `ochreBasin`, `silicaDunes`, `cobaltChasm` to `MiningSectorId`.
- [ ] Add `ironOre`, `silica`, `cobaltOre` to `ResourceType`.
- [ ] Add Mars resource silhouettes with Material icons; do not add files under `assets/`.
- [ ] Add optional `facilityName` and `discoveryText` to `MiningSectorDefinition` with defaults that keep existing content source changes minimal.
- [ ] Add these direct unlock/reward fields to `MiningPlanetDefinition`:

```dart
final MiningPlanetId? unlockRequiredMasteryPlanetId;
final int unlockRequiredSurveyingLevel;
final int unlockCashCost;
final int masteryRewardCash;
```

- [ ] Move Lunar's existing Homeworld/Surveying-3/2,500 requirements onto its planet definition.
- [ ] Add Mars with the frozen values and selected already-shipped facility image paths.
- [ ] Extend `MiningSave.initial()` with exactly three pristine Mars records.

Do not change simulation, controller, or UI yet beyond compile-fixing direct constructor requirements.

### Step 4: Implement strict six-to-nine save evolution

- [ ] Keep the root-key contract unchanged.
- [ ] In `_decodeSectors`, recognize only:
  - the old exact six-key set from HPA-638; or
  - the new exact nine-key set.
- [ ] Decode the old six with the same strict mine/cargo rules, then append pristine Mars records in memory.
- [ ] Continue writing only `MiningSave.toJson()`'s canonical nine-sector shape.
- [ ] Replace the Lunar-only locked-sector check with a loop over every authored locked planet.
- [ ] Do not add a migration result flag, schema version, migration registry, or initialization rewrite.

### Step 5: Full GREEN before commit

```sh
flutter analyze --fatal-infos
flutter test
```

Commit:

```sh
git add lib test
git commit -m "feat(mining): add Mars content catalog"
```

---

## Task 2: Make unlock/mastery planet-driven and add the Mars completion reward

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_controller.dart`
- Modify: `lib/mining/mining_progression_views.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_controller_test.dart`
- Modify: `test/mining/mining_progression_views_test.dart`

### Step 1: Add RED planet-mastery tests

- [ ] Replace Homeworld-only mastery expectations with `isPlanetMastered(planetId, minedSectorIds)`.
- [ ] Prove each planet is mastered only when all three of its own sectors have mines.
- [ ] Prove mines on other planets do not satisfy mastery.

Run:

```sh
flutter test test/mining/mining_content_test.dart
```

### Step 2: Add RED controller unlock tests for Mars

- [ ] Mars unlock fails when Lunar is not mastered.
- [ ] Mars unlock fails below Surveying 5.
- [ ] Mars unlock fails below 20,000 cash.
- [ ] Successful Mars unlock accrues first, debits exactly 20,000 cash, adds only Mars, makes Mars active, and saves once.
- [ ] Lunar unlock still uses the same controller method and keeps its HPA-638 requirements.
- [ ] Homeworld cannot be passed through the unlock mutation as an unlockable target.

Run:

```sh
flutter test test/mining/mining_controller_test.dart
```

### Step 3: Implement data-driven `unlockPlanet`

- [ ] Replace the `id == lunarFrontier` branch with target `MiningPlanetDefinition` metadata.
- [ ] Replace `isHomeworldMastered` with `isPlanetMastered`.
- [ ] Validate only the three supported requirement types: prerequisite mastery, Surveying level, cash.
- [ ] Accrue once, save once, publish once.
- [ ] Remove obsolete Lunar-only unlock constants after all callers/tests use planet metadata.

Do not introduce a generic requirement class or predicate list.

### Step 4: Add RED mastery-reward tests

- [ ] Build first and second Mars mines and assert no mastery reward.
- [ ] Build the final missing Mars mine and assert build cost is debited and exactly 25,000 cash is then credited.
- [ ] Assert the result carries the Mars completion success message.
- [ ] Assert normal Homeworld/Lunar build behavior is unchanged because their reward is zero.
- [ ] Assert retrying build on an existing mine cannot award again.

### Step 5: Implement reward as a mastery transition inside `buildMine`

- [ ] Compute the active planet's mastery before and after the normal build state update.
- [ ] Credit `masteryRewardCash` only on `false -> true` transition.
- [ ] Extend `MiningActionResult.success()` with an optional message rather than adding a reward result hierarchy.
- [ ] Keep one save for the combined build + reward state.

### Step 6: Convert Stellar Map projection to authored planet list

Before widget work, make the pure view model generic and test it independently.

- [ ] Add `StellarMapPlanetView` with presentation-ready unlock/mastery/cash/Surveying booleans.
- [ ] Make `StellarMapView` expose `List<StellarMapPlanetView> planets`.
- [ ] Assert Homeworld is unlocked; Lunar and Mars cards derive their requirements from content definitions.
- [ ] Assert Mars shows Lunar mines `x/3`, Surveying 5, and 20,000 cash.
- [ ] Assert `canUnlock` is false until every authored requirement is true.

Run:

```sh
flutter test test/mining/mining_progression_views_test.dart
```

### Step 7: Full GREEN before commit

```sh
flutter analyze --fatal-infos
flutter test
```

Commit:

```sh
git add lib test
git commit -m "feat(mining): integrate Mars progression"
```

---

## Task 3: Render Mars through the existing mining and Stellar Map UI

**Files:**
- Modify: `lib/mining/mining_sheet_view.dart`
- Modify: `lib/mining/presentation/stellar_map_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `test/mining/mining_sheet_view_test.dart`
- Modify: `test/mining/presentation/stellar_map_sheet_test.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`

### Step 1: Add RED sector-content presentation tests

- [ ] A revealed Mars sector includes the `ResourceSilhouette` display name and authored `discoveryText`.
- [ ] A buildable Mars sector uses its `facilityName` in copy while keeping the same `MiningSheetAction.build` contract.
- [ ] Reveal/build/upgrade disabled reasons remain governed by the existing state/cash/Surveying logic.
- [ ] Existing planets remain readable even when they use default facility/discovery values.

Run:

```sh
flutter test test/mining/mining_sheet_view_test.dart
```

### Step 2: Implement content-only sheet copy

- [ ] Surface resource name/discovery text after reveal.
- [ ] Surface facility name in the build label/body.
- [ ] Do not create a discovery route, modal, facility action type, or resource detail screen.

### Step 3: Add RED three-card Stellar Map widget tests

- [ ] Render Homeworld, Lunar Frontier, and Mars Frontier from `view.planets`.
- [ ] Locked Mars shows Lunar mastery, Surveying 5, and 20,000 cash requirements.
- [ ] Unlock callback returns the Mars planet id rather than calling a Mars-specific closure.
- [ ] Unlocked Mars exposes Travel; current Mars exposes disabled/current-location state.
- [ ] Three cards remain reachable in the existing scroll view at 360×640.

Run:

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart
```

### Step 4: Implement list-based Stellar Map rendering

- [ ] Replace `homeworldName`, `lunarName`, and `onUnlockLunar` parameters with the view's authored planet list plus `onUnlock(MiningPlanetId)` and existing `onTravel`.
- [ ] Loop one card per `StellarMapPlanetView`.
- [ ] Keep exactly the current requirement row types and 48-pixel action controls.
- [ ] Keep the sheet scrollable; do not add tabs, paging, or another map screen.

### Step 5: Wire generic unlock and success messaging in `MiningScreen`

- [ ] Replace `_unlockLunar()` with `_unlockPlanet(MiningPlanetId id)`.
- [ ] Reuse `_runSheetAction` and existing keyed `MiningGame` replacement after successful unlock.
- [ ] Make `_successMessage` prefer `MiningActionResult.message` on successful Mars mastery so the 25,000-cash reward is visible.
- [ ] Keep current haptic/reward behavior; no completion dialog.

### Step 6: Add targeted `MiningScreen` journey coverage

Using existing test seams/fixtures, cover at least:

- [ ] qualified Lunar state → open Stellar Map → unlock Mars;
- [ ] Mars becomes active and its three sector tabs/world definitions are projected;
- [ ] reveal free Ochre Basin → build Iron Rig through the normal primary action;
- [ ] travel away and back without losing Mars state;
- [ ] progress to final Mars mine and observe the mastery snackbar/reward cash;
- [ ] reduced-motion MediaQuery still completes the same actions;
- [ ] 360×640 and 430×932 layouts do not overflow.

Run:

```sh
flutter test test/mining/presentation/mining_screen_test.dart
```

### Step 7: Full GREEN before commit

```sh
flutter analyze --fatal-infos
flutter test
```

Commit:

```sh
git add lib test
git commit -m "feat(mining): present Mars Frontier journey"
```

---

## Task 4: Prove three-planet reuse, offline behavior, and budgets

**Files:**
- Modify: `test/mining/mining_simulation_test.dart`
- Modify: existing offline-return/world tests only if a missing assertion is needed
- Modify: `lib/mining/mining_simulation.dart` only if tests expose a real bug
- Modify: `lib/mining/world/mining_game.dart` only if tests expose a real bug
- Modify: `lib/mining/presentation/offline_return_sheet.dart` only if tests expose a real bug
- Update: draft PR body with measured reuse/budget evidence

### Step 1: Add three-planet deterministic simulation characterization

- [ ] Seed one mine on Homeworld, Lunar Frontier, and Mars Frontier.
- [ ] Advance one UTC elapsed window.
- [ ] Assert all three accrue from that same elapsed duration.
- [ ] Assert Extraction applies exactly once to Mars rate.
- [ ] Assert Logistics applies exactly once to Mars capacity and the global offline cap.
- [ ] Assert locked Mars remains pristine and produces zero.

Run:

```sh
flutter test test/mining/mining_simulation_test.dart
```

The intended result is GREEN with little or no production-code change. If RED identifies a real generic bug, fix only that bug and add the narrow regression assertion.

### Step 2: Pin full storage and offline summary reuse

- [ ] Mars at effective capacity produces no excess and does not disturb other planets.
- [ ] Offline summary contains a Mars section/resource totals through the existing `productionByPlanet` map.
- [ ] Switching active planet does not change which unlocked planets accrue.

Use existing tests rather than creating a second offline/simulation harness.

### Step 3: Record art/loading/memory/frame budget evidence

- [ ] Confirm the branch adds **zero** image/audio files and record the asset payload delta as 0 bytes.
- [ ] Confirm Mars uses three already-shipped facility image paths and built-in Material resource icons.
- [ ] Confirm only one `MiningGame` is mounted and Mars still has exactly three `MiningSectorComponent`s over the same 36×36 terrain.
- [ ] Smoke 360×640 and 430×932 portrait flows with all three planets available.
- [ ] Smoke reduced motion.
- [ ] Record observed load/frame behavior in the PR; do not create a benchmark framework unless an actual regression is reproducible.

### Step 4: Run final repository gates

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Expected: all pass.

### Step 5: Final scope audit

- [ ] One new planet only.
- [ ] Three Mars sectors / three resources only.
- [ ] No Surveying 6 or new technology system.
- [ ] No new currency.
- [ ] No new image/audio files.
- [ ] No Mars-specific controller, simulation branch, repository, or save key.
- [ ] No generic requirement/reward engine.
- [ ] HPA-638 six-sector saves preserve prior state.
- [ ] Existing Homeworld/Lunar behavior remains covered.
- [ ] PR reuse/change ledger matches the design.

Commit any final test/documentation-only adjustments:

```sh
git add .
git commit -m "test(mining): verify Mars content pack"
```

## Completion definition

HPA-641 is ready for review when Mars Frontier is playable from unlock through mastery on the same PR, old two-planet saves evolve without losing progress, all three unlocked planets accrue through the existing deterministic simulation, the 25,000-cash completion reward is granted exactly once, and verification shows the content pack stayed within the zero-new-asset / one-active-world budget.
