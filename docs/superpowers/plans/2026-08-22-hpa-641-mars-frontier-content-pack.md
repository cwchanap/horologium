# HPA-641 Mars Frontier Content Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Mars Frontier as one complete third-planet content pack using the existing Reveal → Build → Mine → Sell → Upgrade loop, with Lunar mastery + Surveying 5 + cash unlock, deterministic three-planet accrual, and a simple Mars mastery cash reward.

**Architecture:** Preserve the HPA-638 single-controller/simulation/repository architecture and flat globally unique sector state. Add Mars as authored catalog data. Widen only seams that now have a second real consumer: planet unlock metadata, planet mastery, Stellar Map planet cards/counts, locked-planet validation, enum-derived initial sector state, and optional content copy/success messaging. There is deliberately **no six-to-nine save converter**; incompatible pre-release HPA-638 saves use the existing clean-reset recovery path.

**Tech Stack:** Dart 3.8, Flutter, Flame 1.30, SharedPreferences 2.5, existing `flutter_test` suites.

**Spec:** `docs/superpowers/specs/2026-08-22-hpa-641-mars-frontier-content-pack-design.md`

## Review disposition

The planning review is incorporated as follows:

- Drop the proposed HPA-638 six-sector → HPA-641 nine-sector compatibility reader.
- Keep exact current decode keyed from `MiningSectorId.values`; old six-key documents recover to a fresh initial save.
- Generate `MiningSave.initial().sectors` from `MiningSectorId.values`; only Landing Basin starts revealed.
- Give `StellarMapPlanetView` separate own-planet and prerequisite-mastery counts.
- Task 1 owns the full enum/save-fixture mechanical retarget and `CLAUDE.md` update so the repository returns to green immediately.
- Task 3 owns per-planet Stellar Map keys and the journey/UI retarget.
- Freeze Mars `mineAsset` paths now rather than selecting them during implementation.
- Name the three concrete implementation risks rather than inventing framework/performance concerns.

## Global constraints

- One branch and one PR for HPA-641; continue implementation on this draft PR.
- Exactly one new planet: Mars Frontier.
- Exactly three Mars sectors and three new raw resources.
- Keep Surveying capped at 5; do not add another technology tier.
- Keep one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `horologium.mining.save`, and active `MiningGame`.
- Keep `MiningSave.sectors` flat and globally keyed by `MiningSectorId`.
- Keep the save strict and unversioned. **No six-key decoder branch, `schemaVersion`, migration registry, or compatibility reader.**
- Old HPA-638 six-sector development documents use `recoveredFromInvalidSave` and start fresh current state.
- No new image/audio files. Mars uses `Assets.woodFactory`, `Assets.riceHuller`, and `Assets.sawmill`.
- No generic requirement/reward engine, processing, logistics, worker, market, retention, or DLC infrastructure.
- Each implementation task ends with `flutter analyze --fatal-infos` and `flutter test` green before commit.

## Frozen Mars values

| Sector | Resource | Facility | `mineAsset` | Surveying | Reveal | Build | Rate/s | Capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Ochre Basin | Iron Ore | Iron Rig | `Assets.woodFactory` | 5 | 0 | 5,000 | 0.75 | 180 | 32 | 7,000 / 14,000 / 28,000 / 56,000 |
| Silica Dunes | Silica | Silica Extractor | `Assets.riceHuller` | 5 | 12,000 | 9,000 | 0.55 | 160 | 55 | 12,000 / 24,000 / 48,000 / 96,000 |
| Cobalt Chasm | Cobalt Ore | Cobalt Drill | `Assets.sawmill` | 5 | 30,000 | 18,000 | 0.35 | 130 | 110 | 24,000 / 48,000 / 96,000 / 192,000 |

Mars Frontier: seed `641`, tint `0xFF2A1512`, unlock after Lunar mastery + Surveying 5 + 20,000 cash, mastery reward 25,000 cash.

## Expected final file map

**Core/content**
- `lib/game/resources/resource_type.dart` — add Iron Ore, Silica, Cobalt Ore identities.
- `lib/mining/mining_content.dart` — Mars catalog, frozen sprite paths, unlock metadata, mastery helper, silhouettes, optional discovery/facility copy.
- `lib/mining/mining_state.dart` — enum-derived current initial sector map.
- `lib/mining/mining_save_repository.dart` — strict exact-current decode and generic locked-planet invariant; no compatibility branch.
- `lib/mining/mining_controller.dart` — data-driven planet unlock and Mars mastery reward through normal build flow.
- `lib/mining/mining_progression_views.dart` — list-based Stellar Map projections with separate own/prerequisite counts.
- `lib/mining/mining_sheet_view.dart` — surface authored resource/discovery/facility copy without changing actions.

**Flutter**
- `lib/mining/presentation/stellar_map_sheet.dart` — render authored planet cards, own/prerequisite mastery progress, per-planet keys, generic unlock/travel callbacks.
- `lib/mining/presentation/mining_screen.dart` — generic unlock callback and optional successful mutation message.

**Repository guidance**
- `CLAUDE.md` — current contract becomes three planets / nine sectors / nine resources while retaining strict unversioned clean-reset semantics and no compatibility reader.

**Expected no structural change**
- `lib/mining/mining_simulation.dart` — characterization should prove three-planet reuse; modify only for a concrete bug.
- `lib/mining/world/mining_game.dart` — existing planet projection should accept Mars unchanged.
- `lib/mining/presentation/offline_return_sheet.dart` — existing grouped summary should render Mars unchanged.

**Primary tests**
- `test/resources/resource_type_test.dart`
- `test/mining/mining_content_test.dart`
- `test/mining/mining_state_test.dart`
- `test/mining/mining_save_repository_test.dart`
- `test/mining/mining_controller_test.dart`
- `test/mining/mining_progression_views_test.dart`
- `test/mining/mining_sheet_view_test.dart`
- `test/mining/mining_simulation_test.dart`
- `test/mining/presentation/stellar_map_sheet_test.dart`
- `test/mining/presentation/mining_screen_test.dart`
- `test/integration/mining_mvp_journey_test.dart`
- existing world/offline-return tests only where needed to pin unchanged reuse.

## Risks

1. **Stellar Map Unlock key/callback collision.** One `mining-stellar-map-unlock` key and Lunar-only callback cannot represent Lunar and Mars being locked simultaneously. Land generic callbacks and per-planet keys together in Task 3.
2. **Own mastery vs prerequisite mastery count overload.** A single `minesBuilt/mineTotal` pair cannot show `Lunar mines 2/3` on locked Mars and later `Mars Mines 2/3` after unlock. Task 2 defines separate fields and pins both meanings before widget work.
3. **Stale six-sector persisted fixtures.** There is intentionally no converter, so any old raw-save helper silently enters recovery instead of its intended scenario. Task 1 searches and retargets every current persisted fixture to nine keys and keeps one explicit old-six-key recovery test.

Balance feel and portrait layout remain verification concerns, not reasons to add architecture.

---

## Task 1: Add the Mars catalog and establish the strict nine-sector current contract

**Files:**
- Modify: `lib/game/resources/resource_type.dart`
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_state.dart`
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `CLAUDE.md`
- Modify: `test/resources/resource_type_test.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_state_test.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Modify mechanically as required: persisted/current-shape helpers in `test/mining/presentation/mining_screen_test.dart`, `test/integration/mining_mvp_journey_test.dart`, controller/view/simulation tests, and any other raw/current save fixtures found by search.

**Interfaces produced:**
- `MiningPlanetId.marsFrontier`
- `MiningSectorId.ochreBasin`, `.silicaDunes`, `.cobaltChasm`
- `ResourceType.ironOre`, `.silica`, `.cobaltOre`
- direct unlock/reward fields on `MiningPlanetDefinition`
- optional `facilityName` / `discoveryText` on `MiningSectorDefinition`
- current `MiningSave.initial()` containing all `MiningSectorId.values`
- repository exact-current decode and generic locked-planet validation.

### Step 1: Write RED Mars catalog/resource tests

- [ ] Assert `MiningPlanetId.values` / registry contain exactly Homeworld, Lunar Frontier, and Mars Frontier in authored order.
- [ ] Assert Mars name, seed `641`, tint `0xFF2A1512`, sector order, anchors, reveal chain, Surveying gates, costs, rates, capacities, sale values, and upgrade curves.
- [ ] Assert exact sprite paths:

```dart
expect(content.sector(MiningSectorId.ochreBasin).mineAsset, Assets.woodFactory);
expect(content.sector(MiningSectorId.silicaDunes).mineAsset, Assets.riceHuller);
expect(content.sector(MiningSectorId.cobaltChasm).mineAsset, Assets.sawmill);
```

- [ ] Assert `facilityName` and `discoveryText` carry the frozen Mars copy.
- [ ] Extend `test/resources/resource_type_test.dart` so `ResourceType.values` and stable names contain exactly nine current identities.
- [ ] Assert Mars `ResourceSilhouette` entries use three distinct Material-icon/color identities.

Run:

```sh
flutter test test/resources/resource_type_test.dart \
  test/mining/mining_content_test.dart
```

Expected: RED because Mars identities/catalog values do not exist.

### Step 2: Write RED current-state/recovery tests

- [ ] Assert `MiningSave.initial()` contains exactly `MiningSectorId.values.toSet()`.
- [ ] Assert only Landing Basin is initially revealed; every other sector is unrevealed with no mine.
- [ ] Assert a valid nine-sector document round-trips unchanged.
- [ ] Seed the exact HPA-638 six-sector document and assert the **existing recovery boundary**, not migration:

```dart
expect(result.recoveredFromInvalidSave, isTrue);
expect(result.wasMissing, isFalse);
expect(result.state, MiningSave.initial(nowUtc: now));
```

- [ ] Assert any locked authored planet with a revealed sector or mine is invalid.
- [ ] Keep unknown/malformed/root-key tests strict.

Run:

```sh
flutter test test/mining/mining_state_test.dart \
  test/mining/mining_save_repository_test.dart
```

Expected: RED until current state/decode follows the nine-sector contract.

### Step 3: Implement the smallest catalog/state/repository change

- [ ] Add Mars planet/sector/resource enum values.
- [ ] Add the three resource silhouettes; no files under `assets/`.
- [ ] Add optional `facilityName` and `discoveryText` with defaults that keep existing content concise.
- [ ] Add these direct fields to `MiningPlanetDefinition`:

```dart
final MiningPlanetId? unlockRequiredMasteryPlanetId;
final int unlockRequiredSurveyingLevel;
final int unlockCashCost;
final int masteryRewardCash;
```

- [ ] Move Lunar's Homeworld/Surveying-3/2,500 requirements onto its planet definition.
- [ ] Add Mars with the frozen values and exact sprite paths.
- [ ] Replace the handwritten initial sector literal with:

```dart
sectors: {
  for (final id in MiningSectorId.values)
    id: SectorProgress(
      revealed: id == MiningSectorId.landingBasin,
    ),
},
```

- [ ] Keep `_decodeSectors` exact-key validation based on `MiningSectorId.values`; **do not** add a six-key branch.
- [ ] Change stale “six authored sectors” error copy to “authored sectors” or equivalent current-neutral wording.
- [ ] Replace Lunar-only pristine validation with:

```text
for each content.planets entry not in unlockedPlanetIds:
  every sector must be unrevealed and have no mine
```

### Step 4: Retarget every existing exact-shape consumer before commit

Search the repository for all old shape assumptions, including:

```text
sixSector
_sixSectorDocuments
MiningSectorId.heliumMare literals near raw save maps
ResourceType.helium3 exact lists
mining save JSON helpers
"six authored"
```

Then:

- [ ] Update `test/mining/mining_save_repository_test.dart` current-sector helper and exact-current assertions to nine keys.
- [ ] Update raw save helpers such as `_sixSectorDocuments` in `test/integration/mining_mvp_journey_test.dart` to a nine-sector current helper with pristine Mars entries.
- [ ] Update `_seededLunarActiveSave()` / `_unlockableLunarSave()` and any raw/persisted fixtures in `test/mining/presentation/mining_screen_test.dart` to current nine-key data.
- [ ] Update controller/simulation/view fixtures that hand-list the flat sector map.
- [ ] Keep the one intentional old-six-key repository test from Step 2 as the recovery characterization.
- [ ] Update `CLAUDE.md`: three planets, nine sector IDs/resources, exact strict-current semantics, and **still no compatibility reader**.
- [ ] Do not yet change Stellar Map widget keys/callback behavior; Task 3 owns that semantic UI retarget.

### Step 5: Full GREEN before commit

```sh
flutter analyze --fatal-infos
flutter test
```

Expected: both PASS; Task 1 must not leave stale six-key fixtures for later tasks.

Commit:

```sh
git add lib test CLAUDE.md
git commit -m "feat(mining): add Mars content catalog"
```

---

## Task 2: Make unlock/mastery planet-driven and model honest Stellar Map progress

**Files:**
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_controller.dart`
- Modify: `lib/mining/mining_progression_views.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_controller_test.dart`
- Modify: `test/mining/mining_progression_views_test.dart`

**Interfaces produced:**
- `isPlanetMastered(MiningPlanetId, Iterable<MiningSectorId>)`
- data-driven `unlockPlanet(MiningPlanetId)`
- success result may carry an optional message
- `StellarMapView.planets`
- `StellarMapPlanetView` with separate own and prerequisite counts.

### Step 1: Write RED planet-mastery tests

- [ ] Replace Homeworld-only mastery expectations with `isPlanetMastered(planetId, minedSectorIds)`.
- [ ] Prove Homeworld, Lunar, and Mars are mastered only when all three of their own sectors have mines.
- [ ] Prove mines on other planets do not satisfy mastery.

Run:

```sh
flutter test test/mining/mining_content_test.dart
```

### Step 2: Write RED controller unlock tests

- [ ] Lunar still requires Homeworld mastery + Surveying 3 + 2,500 cash.
- [ ] Mars fails without Lunar mastery.
- [ ] Mars fails below Surveying 5.
- [ ] Mars fails below 20,000 cash.
- [ ] Successful Mars unlock accrues first, debits exactly 20,000, adds only Mars, makes it active, and saves once.
- [ ] Homeworld/planets without an unlock prerequisite cannot be passed through the unlock mutation.

Run:

```sh
flutter test test/mining/mining_controller_test.dart
```

### Step 3: Implement data-driven unlock/mastery

- [ ] Replace `isHomeworldMastered` with `isPlanetMastered`.
- [ ] Replace the `id == lunarFrontier` branch with target `MiningPlanetDefinition` metadata.
- [ ] Validate only prerequisite mastery, Surveying, and cash.
- [ ] Accrue once, save once, publish once.
- [ ] Remove Lunar-only static unlock constants after all callers use planet metadata.
- [ ] Do not introduce requirement classes, predicates, or reward objects.

### Step 4: Write RED mastery-reward tests

- [ ] Building Mars mine 1 and 2 grants no completion reward.
- [ ] Building the final missing Mars mine debits its build cost and credits exactly 25,000 cash in the same next state.
- [ ] Successful result carries `Mars mastered — +25000 cash.` or the exact approved equivalent.
- [ ] Homeworld/Lunar builds remain unchanged because their `masteryRewardCash` is zero.
- [ ] Retrying a built sector cannot award again.

### Step 5: Implement reward as the existing build transition

- [ ] Resolve the planet through `content.planetForSector(id)`.
- [ ] Compute `wasMastered` from pre-build mined IDs.
- [ ] Apply the existing build update/cost.
- [ ] Compute post-build mastery.
- [ ] Credit `masteryRewardCash` only on `false -> true`.
- [ ] Widen `MiningActionResult.success` to accept an optional message while preserving current no-message callers.
- [ ] Save the combined build/reward state once.

### Step 6: Write RED Stellar Map view-model tests

Define the intended shape explicitly:

```dart
class StellarMapPlanetView {
  final MiningPlanetId id;
  final String name;
  final bool isUnlocked;
  final bool isActive;

  final int minesBuilt;
  final int mineTotal;

  final String? requiredMasteryPlanetName;
  final int? requiredMinesBuilt;
  final int? requiredMineTotal;
  final bool hasRequiredMastery;

  final int requiredSurveyingLevel;
  final bool hasSurveying;
  final int unlockCashCost;
  final bool hasCash;

  bool get canUnlock;
}
```

Tests:

- [ ] Homeworld card reports its own mine progress and no prerequisite.
- [ ] Locked Lunar card reports **Homeworld prerequisite** progress independently from Lunar own progress.
- [ ] Locked Mars card reports **Lunar prerequisite** progress independently from Mars own progress.
- [ ] Unlocked Mars card reports Mars `minesBuilt/mineTotal` (for example 2/3) so mastery progress remains visible.
- [ ] Mars requirement values are Surveying 5 and 20,000 cash.
- [ ] `canUnlock` is false until all target requirements are satisfied.

Run:

```sh
flutter test test/mining/mining_progression_views_test.dart
```

### Step 7: Implement list-based pure projection

- [ ] Replace fixed Homeworld/Lunar fields with `List<StellarMapPlanetView> planets` in authored catalog order.
- [ ] Compute own mine counts from each planet's sectors.
- [ ] Compute prerequisite counts from `unlockRequiredMasteryPlanetId` separately.
- [ ] Keep all eligibility in the pure view model; widgets render only.

### Step 8: Full GREEN before commit

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

## Task 3: Render Mars and the generic three-planet Stellar Map

**Files:**
- Modify: `lib/mining/mining_sheet_view.dart`
- Modify: `lib/mining/presentation/stellar_map_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `test/mining/mining_sheet_view_test.dart`
- Modify: `test/mining/presentation/stellar_map_sheet_test.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Modify: `test/integration/mining_mvp_journey_test.dart`

### Step 1: Write RED sector-content presentation tests

- [ ] Revealed Mars sectors include resource display name and authored `discoveryText`.
- [ ] Buildable Mars sector copy uses its `facilityName` while keeping `MiningSheetAction.build`.
- [ ] Reveal/build/upgrade disabled reasons remain governed by existing state/cash/Surveying logic.
- [ ] Existing planets remain readable with default facility/discovery values.

Run:

```sh
flutter test test/mining/mining_sheet_view_test.dart
```

### Step 2: Implement content-only sector copy

- [ ] Surface resource name/discovery text after reveal.
- [ ] Surface facility name in build label/body.
- [ ] Do not create a discovery route, facility action type, or resource-detail screen.

### Step 3: Write RED three-card Stellar Map widget tests

- [ ] Render Homeworld, Lunar Frontier, and Mars Frontier from `view.planets`.
- [ ] Locked Lunar renders prerequisite `Homeworld mines x/3`.
- [ ] Locked Mars renders prerequisite `Lunar Frontier mines x/3`, Surveying 5, and 20,000 cash.
- [ ] Unlocked Mars renders own `Mines 2/3` (or another seeded own-progress value).
- [ ] Unlock callback returns the target planet ID.
- [ ] Use unique keys:

```text
mining-stellar-map-unlock-lunarFrontier
mining-stellar-map-unlock-marsFrontier
mining-stellar-map-travel-homeworld
mining-stellar-map-travel-lunarFrontier
mining-stellar-map-travel-marsFrontier
```

- [ ] Three cards remain reachable in the current scroll view at 360×640.

Run:

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart
```

### Step 4: Implement list-based Stellar Map rendering

- [ ] Replace `homeworldName`, `lunarName`, and `onUnlockLunar` with the pure authored list plus `onUnlock(MiningPlanetId)` and existing `onTravel`.
- [ ] Loop one card per `StellarMapPlanetView`.
- [ ] Locked card: prerequisite mastery / Surveying / cash rows + Unlock.
- [ ] Unlocked card: own `Mines x/y` + Travel/current-location state.
- [ ] Keep current `_requirementRow`, scroll behavior, and 48px action controls.
- [ ] Do not add tabs, paging, or map-card subclasses.

### Step 5: Wire generic unlock and successful result messages in `MiningScreen`

- [ ] Replace `_unlockLunar()` with `_unlockPlanet(MiningPlanetId id)`.
- [ ] Reuse `_runSheetAction` and keyed `MiningGame` replacement after successful unlock.
- [ ] Make `_successMessage` prefer a non-null successful `MiningActionResult.message`; otherwise keep current action-specific copy.
- [ ] Keep current haptics/reward visuals; no completion dialog.

### Step 6: Retarget integration key usage and add the Mars journey

`test/integration/mining_mvp_journey_test.dart` already had its raw save helper updated to nine keys in Task 1. Now retarget semantic Stellar Map behavior:

- [ ] Replace the old single `mining-stellar-map-unlock` finder with the Lunar per-planet key in the existing Lunar journey.
- [ ] Keep existing two-planet assertions that are intentionally about the first/Lunar journey, but update any assertions that intentionally enumerate **all** current planets/resources.
- [ ] Add/extend targeted journey coverage: qualified Lunar state → open map → unlock Mars → reveal free Ochre Basin → build Iron Rig.
- [ ] Prove travel away/back preserves Mars state.
- [ ] Progress an unlocked Mars fixture to `Mines 2/3`, open Stellar Map, and assert own mastery progress is visible.
- [ ] Build final Mars mine and observe reward cash/message through the existing screen path.
- [ ] Repeat the critical Mars unlock/first-mine path with reduced motion.
- [ ] Keep 360×640 and 430×932 overflow checks.

Run:

```sh
flutter test test/mining/presentation/mining_screen_test.dart \
  test/integration/mining_mvp_journey_test.dart
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

## Task 4: Characterize three-planet reuse and close verification

**Files:**
- Modify: `test/mining/mining_simulation_test.dart`
- Modify: existing offline-return/world tests only if a missing assertion is needed.
- Modify: `lib/mining/mining_simulation.dart` only if tests expose a real generic bug.
- Modify: `lib/mining/world/mining_game.dart` only if tests expose a real generic bug.
- Modify: `lib/mining/presentation/offline_return_sheet.dart` only if tests expose a real generic bug.
- Update: draft PR body with reuse/budget/verification evidence.

### Step 1: Add three-planet deterministic simulation characterization

- [ ] Seed one mine on Homeworld, Lunar Frontier, and Mars Frontier.
- [ ] Advance one UTC elapsed window.
- [ ] Assert all three accrue from that same elapsed duration.
- [ ] Assert Extraction applies exactly once to Mars rate.
- [ ] Assert Logistics applies exactly once to Mars capacity/global offline cap.
- [ ] Assert locked Mars remains pristine and produces zero.

Run:

```sh
flutter test test/mining/mining_simulation_test.dart
```

Intended result: GREEN with no production-code change. If RED reveals a generic defect, fix only that defect and keep a narrow regression assertion.

### Step 2: Pin full storage and offline-summary reuse

- [ ] Mars at effective capacity produces no excess and does not disturb other planets.
- [ ] Existing `productionByPlanet` includes Mars totals without a new summary shape.
- [ ] Existing `OfflineReturnSheet` renders the Mars group without planet-specific code.
- [ ] Switching active planet does not change which unlocked planets accrue.
- [ ] Existing `MiningGame(planet: mars, ...)` builds exactly three Mars sector components without world-code changes.

### Step 3: Record art/loading/memory/frame budget evidence

- [ ] Confirm diff adds **zero** image/audio files; asset payload delta = 0 bytes.
- [ ] Confirm Mars uses exactly `Assets.woodFactory`, `Assets.riceHuller`, `Assets.sawmill` plus built-in resource icons.
- [ ] Confirm only one `MiningGame` is mounted and Mars has exactly three sectors over the same 36×36 terrain.
- [ ] Smoke 360×640 and 430×932 with all three planets available.
- [ ] Smoke reduced motion.
- [ ] Record observed loading/frame behavior in the PR; do not create a benchmark framework unless a reproducible regression is found.

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
- [ ] No six-to-nine compatibility reader or schema version.
- [ ] Old six-key HPA-638 development data is intentionally covered by the existing clean-reset recovery path.
- [ ] Current fixtures/documentation all use the exact nine-sector shape.
- [ ] Locked Stellar Map cards show prerequisite counts; unlocked cards show own counts.
- [ ] Existing Homeworld/Lunar behavior remains covered.
- [ ] PR reuse/change ledger matches the design.

Commit final test/documentation-only adjustments:

```sh
git add .
git commit -m "test(mining): verify Mars content pack"
```

## Completion definition

HPA-641 is ready for review when Mars Frontier is playable from unlock through mastery on this same PR, all current saves/tests use the strict nine-sector document, incompatible pre-release six-sector data continues through clean-reset recovery, all three unlocked planets accrue through the existing deterministic simulation, Mars own mastery and unlock-prerequisite mastery are both represented truthfully in the Stellar Map, the 25,000-cash reward is granted exactly once, and verification shows the content pack stayed within the zero-new-asset / one-active-world budget.