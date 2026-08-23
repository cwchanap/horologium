# HPA-641 Mars Frontier Content Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Mars Frontier as one complete third-planet content pack using the existing Reveal → Build → Mine → Sell → Upgrade loop, with Lunar mastery + Surveying 5 + cash unlock, deterministic three-planet accrual, distinct rust-toned world presentation, and a modest one-time Mars mastery cash flourish.

**Architecture:** Preserve the HPA-638 single-controller/simulation/repository architecture and flat globally unique sector state. Add Mars as authored catalog data. Widen only proven seams: planet unlock metadata, planet mastery, enum-derived initial state, generic locked-planet validation, honest unlocked-planet Surveying counts, a list-based Stellar Map, and one renderer-owned tint overlay derived from the existing `planet.tint`. There is deliberately no save converter.

**Tech Stack:** Dart 3.8, Flutter, Flame 1.30, SharedPreferences 2.5, existing `flutter_test` suites.

**Spec:** `docs/superpowers/specs/2026-08-22-hpa-641-mars-frontier-content-pack-design.md`

## Review disposition

This revision incorporates the second planning review as follows:

- Task 2 no longer reshapes `StellarMapView`; the full view-model + sheet + screen retarget moves together in Task 3 so every task can actually end green.
- Task 1 explicitly searches for catalog-wide count strings/exhaustive enum lists and includes `technology_sheet_test.dart`.
- Surveying effect text counts sectors on currently unlocked planets only.
- Mars visual identity is no longer assumed to come from seed/background alone. `MiningGame` reuses the existing `planet.tint` as a world-space `BlendMode.color` overlay above terrain and below sectors; no second tint field is added.
- Stellar Map prerequisite progress is referenced by `requiredMasteryPlanetId` and the prerequisite planet's own view entry rather than duplicated name/count fields.
- The 25,000 mastery reward stays frozen but is explicitly a modest completion flourish/rebate, not a new progression jump.
- Mars is progressively disclosed: hidden on a fresh save, visible once Lunar Frontier is unlocked.

## Global constraints

- One branch and one PR for HPA-641; continue on draft PR #17.
- Exactly one new planet: Mars Frontier.
- Exactly three Mars sectors and three new raw resources.
- Keep Surveying capped at 5.
- Keep one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `horologium.mining.save`, and active `MiningGame`.
- Keep `MiningSave.sectors` flat and globally keyed by `MiningSectorId`.
- Save stays strict/unversioned: no six-key decoder branch, `schemaVersion`, migration registry, or compatibility reader.
- Old HPA-638 six-sector development documents clean-reset through `recoveredFromInvalidSave`.
- No new image/audio files.
- Frozen Mars facility sprites: `Assets.woodFactory`, `Assets.riceHuller`, `Assets.sawmill`.
- Use existing `planet.tint`; do not add a second terrain-tint content field.
- No generic requirement/reward engine, processing, logistics, workers, markets, retention, or DLC infrastructure.
- Each task ends with `flutter analyze --fatal-infos` and `flutter test` green before commit.

## Frozen Mars values

| Sector | Resource | Facility | `mineAsset` | Surveying | Reveal | Build | Rate/s | Capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Ochre Basin | Iron Ore | Iron Rig | `Assets.woodFactory` | 5 | 0 | 5,000 | 0.75 | 180 | 32 | 7,000 / 14,000 / 28,000 / 56,000 |
| Silica Dunes | Silica | Silica Extractor | `Assets.riceHuller` | 5 | 12,000 | 9,000 | 0.55 | 160 | 55 | 12,000 / 24,000 / 48,000 / 96,000 |
| Cobalt Chasm | Cobalt Ore | Cobalt Drill | `Assets.sawmill` | 5 | 30,000 | 18,000 | 0.35 | 130 | 110 | 24,000 / 48,000 / 96,000 / 192,000 |

Mars Frontier:

- seed `641`;
- tint `0xFF2A1512`;
- unlock after Lunar mastery + Surveying 5 + 20,000 cash;
- mastery reward 25,000 cash;
- world overlay uses `planet.tint.withAlpha(96)` + `BlendMode.color`.

## Expected final file map

**Core/content/state**

- `lib/game/resources/resource_type.dart`
- `lib/mining/mining_content.dart`
- `lib/mining/mining_state.dart`
- `lib/mining/mining_save_repository.dart`
- `lib/mining/mining_progression_views.dart`
- `lib/mining/mining_controller.dart`
- `lib/mining/mining_sheet_view.dart`

**Flutter/Flame presentation**

- `lib/mining/presentation/stellar_map_sheet.dart`
- `lib/mining/presentation/mining_screen.dart`
- `lib/mining/world/mining_game.dart`

**Repository guidance**

- `CLAUDE.md`

**Primary tests**

- `test/resources/resource_type_test.dart`
- `test/mining/mining_content_test.dart`
- `test/mining/mining_state_test.dart`
- `test/mining/mining_save_repository_test.dart`
- `test/mining/mining_progression_views_test.dart`
- `test/mining/presentation/technology_sheet_test.dart`
- `test/mining/mining_controller_test.dart`
- `test/mining/mining_sheet_view_test.dart`
- `test/mining/presentation/stellar_map_sheet_test.dart`
- `test/mining/presentation/mining_screen_test.dart`
- `test/mining/world/mining_game_test.dart`
- `test/mining/mining_simulation_test.dart`
- `test/integration/mining_mvp_journey_test.dart`

Existing offline/world tests may be extended only where needed to pin unchanged reuse.

## Risks

1. **Intermediate Stellar Map compile break.** `StellarMapView` is consumed directly by `StellarMapSheet`, `MiningScreen`, and widget fixtures. The reshape must land with all those consumers in Task 3, not earlier.
2. **Stale catalog-wide assertions.** Enum growth breaks exact resource lists and technology strings such as `3 of 6` / `6 of 6` even though those tests contain no save helper. Task 1 explicitly searches exhaustive enum lists and catalog-count strings.
3. **Visual promise vs renderer.** A new seed and background tint do not make the playable terrain rust-toned. Task 3 adds the required world-space tint overlay and tests its render ordering.
4. **Stale persisted fixtures.** With no converter, a six-key fixture silently exercises recovery instead of its intended scenario. Task 1 retargets every current-shape raw fixture and keeps only one explicit six-key recovery test.

---

## Task 1: Add Mars catalog/state and establish the strict nine-sector current contract

**Files:**

- Modify: `lib/game/resources/resource_type.dart`
- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_state.dart`
- Modify: `lib/mining/mining_save_repository.dart`
- Modify: `lib/mining/mining_progression_views.dart` **only for Surveying effect counting**
- Modify: `CLAUDE.md`
- Modify: `test/resources/resource_type_test.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_state_test.dart`
- Modify: `test/mining/mining_save_repository_test.dart`
- Modify: `test/mining/mining_progression_views_test.dart` **only for Surveying effect assertions**
- Modify: `test/mining/presentation/technology_sheet_test.dart`
- Mechanically retarget any current raw-save fixtures found in controller/simulation/presentation/integration tests.

**Do not reshape `StellarMapView` in this task.** Keep the existing Lunar-specific projection compiling until Task 3.

### Step 1: Write RED Mars catalog/resource tests

- [ ] Assert `MiningPlanetId.values` / registry authored order is Homeworld, Lunar Frontier, Mars Frontier.
- [ ] Assert Mars name, seed, tint, sector order, anchors, reveal chain, Surveying gates, economy values, and upgrade curves.
- [ ] Assert exact sprite paths:

```dart
expect(content.sector(MiningSectorId.ochreBasin).mineAsset, Assets.woodFactory);
expect(content.sector(MiningSectorId.silicaDunes).mineAsset, Assets.riceHuller);
expect(content.sector(MiningSectorId.cobaltChasm).mineAsset, Assets.sawmill);
```

- [ ] Assert `facilityName` / `discoveryText` values.
- [ ] Extend `ResourceType.values` exact-list/stable-name tests to nine current identities.
- [ ] Assert three distinct Mars `ResourceSilhouette` identities.

Run:

```sh
flutter test test/resources/resource_type_test.dart \
  test/mining/mining_content_test.dart
```

Expected: RED.

### Step 2: Write RED initial-state/repository tests

- [ ] `MiningSave.initial().sectors.keys.toSet()` equals `MiningSectorId.values.toSet()`.
- [ ] Only Landing Basin starts revealed; all other sectors are pristine.
- [ ] Valid exact-nine document round-trips.
- [ ] Exact old six-sector HPA-638 document clean-resets:

```dart
expect(result.recoveredFromInvalidSave, isTrue);
expect(result.wasMissing, isFalse);
expect(result.state, MiningSave.initial(nowUtc: now));
```

- [ ] Any locked authored planet containing revealed/mine state is invalid.
- [ ] Unknown/malformed/root-key tests remain strict.

Run:

```sh
flutter test test/mining/mining_state_test.dart \
  test/mining/mining_save_repository_test.dart
```

Expected: RED.

### Step 3: Implement the smallest catalog/state/repository change

- [ ] Add `marsFrontier`.
- [ ] Add `ochreBasin`, `silicaDunes`, `cobaltChasm`.
- [ ] Add `ironOre`, `silica`, `cobaltOre`.
- [ ] Add Mars silhouettes using Material icons; no files under `assets/`.
- [ ] Add optional `facilityName` / `discoveryText` to `MiningSectorDefinition`.
- [ ] Add direct planet unlock/reward fields:

```dart
final MiningPlanetId? unlockRequiredMasteryPlanetId;
final int unlockRequiredSurveyingLevel;
final int unlockCashCost;
final int masteryRewardCash;
```

- [ ] Populate Homeworld/Lunar/Mars values from the frozen design.
- [ ] Keep existing `lunarUnlockCashCost` / `lunarUnlockSurveyingLevel` statics temporarily because `StellarMapView` and its widget tests still consume them. **Do not remove them in Task 1 or Task 2.**
- [ ] Replace handwritten `MiningSave.initial()` sector map with the `MiningSectorId.values` comprehension.
- [ ] Keep `_decodeSectors()` exact-key validation based on `MiningSectorId.values`; no compatibility branch.
- [ ] Replace stale “six authored sectors” copy with current-neutral wording.
- [ ] Generalize locked-planet pristine validation over `content.planets`.

### Step 4: Make Surveying effect text honest for unlocked planets

The effect currently counts all authored sectors. Change numerator and denominator to sectors belonging to `state.unlockedPlanetIds`.

- [ ] Adjust the pure effect calculation to receive the state/unlocked planet set.
- [ ] Fresh save at Surveying 0: `3 of 3 sectors revealable`.
- [ ] Lunar unlocked at Surveying 3: `4 of 6 sectors revealable`.
- [ ] Mars unlocked at Surveying 5: `9 of 9 sectors revealable`.
- [ ] No reveal/controller rules change.

Run:

```sh
flutter test test/mining/mining_progression_views_test.dart \
  test/mining/presentation/technology_sheet_test.dart
```

### Step 5: Retarget every old catalog/current-shape assertion

Search for both **shape helpers** and **catalog-wide assertions**. At minimum:

```text
sixSector
_sixSectorDocuments
"six authored"
"3 of 6"
"4 of 6"
"6 of 6"
"sectors revealable"
ResourceType.values
MiningSectorId.values
helium3 exact lists
raw mining save JSON helpers
```

Rule: find any assertion that embeds a catalog-wide count, exhaustive enum list, or exact current save shape — not only helpers whose names contain “six”.

- [ ] Update `test/mining/mining_save_repository_test.dart` current-sector helper/assertions to nine keys.
- [ ] Update integration `_sixSectorDocuments` helper to a current nine-sector helper with pristine Mars records.
- [ ] Update `_seededLunarActiveSave()` / `_unlockableLunarSave()` and any persisted/raw fixtures in `mining_screen_test.dart`.
- [ ] Update controller/simulation/view fixtures that hand-list full current sector maps.
- [ ] Update `technology_sheet_test.dart` and progression-view catalog count assertions.
- [ ] Keep exactly one intentional old-six repository recovery characterization.
- [ ] Update `CLAUDE.md`: three planets, nine sector/resource identities, strict current save, still no compatibility reader.

### Step 6: Full GREEN before commit

```sh
flutter analyze --fatal-infos
flutter test
```

Expected: PASS. Task 1 must not leave stale enum/count/save-shape failures for later tasks.

Commit:

```sh
git add lib test CLAUDE.md
git commit -m "feat(mining): add Mars content catalog"
```

---

## Task 2: Make unlock/mastery planet-driven and add the Mars mastery reward

**Files:**

- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_controller.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_controller_test.dart`

**Do not modify `StellarMapView`, `StellarMapSheet`, or `MiningScreen` here.** The existing Lunar statics remain until Task 3 so this task can end green.

### Step 1: Write RED `isPlanetMastered` tests

- [ ] Homeworld/Lunar/Mars each require all three of their own mines.
- [ ] Mines on another planet do not satisfy mastery.

Run:

```sh
flutter test test/mining/mining_content_test.dart
```

### Step 2: Implement planet mastery

- [ ] Replace `isHomeworldMastered` with `isPlanetMastered(planetId, minedSectorIds)`.
- [ ] Keep content independent of state objects.

### Step 3: Write RED data-driven unlock tests

- [ ] Lunar still requires Homeworld mastery + Surveying 3 + 2,500 cash.
- [ ] Mars fails without Lunar mastery.
- [ ] Mars fails below Surveying 5.
- [ ] Mars fails below 20,000 cash.
- [ ] Mars success accrues first, debits 20,000 exactly, unlocks Mars once, makes Mars active, saves once.
- [ ] Homeworld/non-unlockable targets are rejected.

### Step 4: Implement data-driven `unlockPlanet`

- [ ] Read requirement values from target `MiningPlanetDefinition`.
- [ ] Validate only prerequisite mastery, Surveying, and cash.
- [ ] Accrue once, save once, publish once.
- [ ] No planet-specific controller branches.
- [ ] Leave Lunar static constants in place for the still-old Stellar Map projection; they are removed in Task 3 after all UI consumers move.

### Step 5: Write RED mastery reward tests

- [ ] First/second Mars mine grants no completion reward.
- [ ] Final Mars mine debits normal build cost and credits exactly 25,000 cash in the same next state.
- [ ] Result carries `Mars mastered — +25,000 cash.` or exact approved equivalent.
- [ ] Homeworld/Lunar builds have no reward.
- [ ] Retrying a built sector cannot reward again.

### Step 6: Implement reward through existing build transition

- [ ] Resolve planet via `content.planetForSector(id)`.
- [ ] Compute pre-build mastery.
- [ ] Run existing build update/cost.
- [ ] Compute post-build mastery.
- [ ] Credit `masteryRewardCash` only on false → true.
- [ ] Widen `MiningActionResult.success` to accept optional message; the field already exists.
- [ ] Save combined build/reward once.
- [ ] No reward-claim flag or hierarchy.

### Step 7: Full GREEN before commit

```sh
flutter analyze --fatal-infos
flutter test
```

Expected: PASS with the old Stellar Map UI still compiling.

Commit:

```sh
git add lib test
git commit -m "feat(mining): integrate Mars progression"
```

---

## Task 3: Render Mars, retarget Stellar Map end-to-end, and add world tint

**Files:**

- Modify: `lib/mining/mining_progression_views.dart` **Stellar Map portion only**
- Modify: `lib/mining/mining_sheet_view.dart`
- Modify: `lib/mining/presentation/stellar_map_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `lib/mining/world/mining_game.dart`
- Modify: `lib/mining/mining_content.dart` to remove now-unused Lunar statics after consumers are retargeted
- Modify: `test/mining/mining_progression_views_test.dart` **Stellar Map portion**
- Modify: `test/mining/mining_sheet_view_test.dart`
- Modify: `test/mining/presentation/stellar_map_sheet_test.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Modify: `test/mining/world/mining_game_test.dart`
- Modify: `test/integration/mining_mvp_journey_test.dart`

This task owns the entire breaking Stellar Map interface change in one green commit.

### Step 1: Write RED sector-content presentation tests

- [ ] Revealed Mars sector exposes resource display name and `discoveryText`.
- [ ] Buildable Mars copy uses `facilityName` with the existing build action.
- [ ] Disabled reasons remain governed by current reveal/build/upgrade rules.
- [ ] Existing sectors remain readable with defaults.

Run:

```sh
flutter test test/mining/mining_sheet_view_test.dart
```

### Step 2: Implement content-only sheet copy

- [ ] Surface resource/discovery text after reveal.
- [ ] Surface facility name in build copy.
- [ ] No discovery route, modal, or facility action type.

### Step 3: Write RED Stellar Map projection tests

Use this target shape:

```dart
class StellarMapPlanetView {
  final MiningPlanetId id;
  final String name;
  final bool isUnlocked;
  final bool isActive;
  final int minesBuilt;
  final int mineTotal;
  final MiningPlanetId? requiredMasteryPlanetId;
  final bool hasRequiredMastery;
  final int requiredSurveyingLevel;
  final bool hasSurveying;
  final int unlockCashCost;
  final bool hasCash;

  bool get canUnlock;
}

class StellarMapView {
  final List<StellarMapPlanetView> planets;

  StellarMapPlanetView planet(MiningPlanetId id) =>
      planets.singleWhere((view) => view.id == id);
}
```

Tests:

- [ ] Fresh save contains Homeworld + Lunar but not Mars.
- [ ] Lunar-unlocked state contains all three planets, with locked Mars visible.
- [ ] Each planet's `minesBuilt/mineTotal` reports only its own sectors.
- [ ] Locked Lunar stores `requiredMasteryPlanetId == homeworld` and `hasRequiredMastery`.
- [ ] Locked Mars stores `requiredMasteryPlanetId == lunarFrontier` and `hasRequiredMastery`.
- [ ] There are **no duplicated prerequisite name/mine-count fields** on the target planet view.
- [ ] Mars requirement values are Surveying 5 / 20,000 cash.
- [ ] `canUnlock` is correct.

Run:

```sh
flutter test test/mining/mining_progression_views_test.dart
```

### Step 4: Implement list projection + progressive disclosure

- [ ] Build one own-progress entry per visible planet in authored order.
- [ ] Visible rule:
  - Homeworld always;
  - an unlocked planet always;
  - a locked planet only when its prerequisite planet is unlocked.
- [ ] Keep only `requiredMasteryPlanetId` + `hasRequiredMastery` on the target card.
- [ ] Add `StellarMapView.planet(id)` accessor.
- [ ] Do not introduce polymorphic card/requirement types.

### Step 5: Write RED Stellar Map widget tests

- [ ] Fresh sheet renders two cards: Homeworld + Lunar.
- [ ] Lunar-unlocked sheet renders three cards including locked Mars.
- [ ] Locked card resolves prerequisite name/count from `view.planet(requiredMasteryPlanetId)`.
- [ ] Locked Mars shows `Lunar Frontier mines x/3`, Surveying 5, 20,000 cash.
- [ ] Unlocked Mars shows own `Mines 2/3`.
- [ ] Generic unlock callback returns Mars ID.
- [ ] Generic travel callback returns target ID.
- [ ] Keys are unique:

```text
mining-stellar-map-unlock-${id.name}
mining-stellar-map-travel-${id.name}
```

- [ ] 360×640 remains scrollable/reachable; controls remain ≥48px.

### Step 6: Implement Stellar Map sheet + screen together

- [ ] Replace hard-coded Homeworld/Lunar cards with loop over `view.planets`.
- [ ] Resolve prerequisite view by ID when rendering locked requirement row.
- [ ] Replace `onUnlockLunar` with `onUnlock(MiningPlanetId)`.
- [ ] Keep `onTravel(MiningPlanetId)`.
- [ ] Replace `_unlockLunar()` with `_unlockPlanet(id)` in `MiningScreen`.
- [ ] Make success snackbar prefer `MiningActionResult.message` when provided.
- [ ] After every former UI/test consumer is moved to planet metadata/list projection, remove `lunarUnlockCashCost` and `lunarUnlockSurveyingLevel` statics.

### Step 7: Write RED world-tint tests

The current seed changes generated terrain but does not give Mars a rust palette, and `backgroundColor()` colors only outside the terrain. Pin the new renderer seam.

- [ ] `MiningGame` mounts one world-sized `RectangleComponent` used as terrain tint.
- [ ] Its RGB comes from `planet.tint` with alpha 96.
- [ ] `paint.blendMode == BlendMode.color`.
- [ ] Render priority/order is terrain < tint overlay < sector components.
- [ ] Overlay size equals `worldSize` and is centered.
- [ ] No change under `lib/game/terrain/`.

Run:

```sh
flutter test test/mining/world/mining_game_test.dart
```

### Step 8: Implement the renderer-owned tint overlay

In `MiningGame.onLoad()`:

- [ ] Keep current `backgroundColor() => planet.tint`.
- [ ] Add the existing terrain with an explicit lower priority.
- [ ] Add one `RectangleComponent` centered over `worldSize`, using:

```dart
paint
  ..color = planet.tint.withAlpha(96)
  ..blendMode = BlendMode.color;
```

- [ ] Add sectors at a higher priority so icons/facility sprites are not recolored.
- [ ] Reuse the same mechanism for all planets; no Mars-specific branch and no new `terrainTint` field.

### Step 9: Retarget MiningScreen/integration journey

Cover:

- [ ] fresh Stellar Map does not show Mars;
- [ ] qualified Lunar state → unlock Mars card is visible;
- [ ] unlock Mars → Mars active;
- [ ] reveal free Ochre Basin → build Iron Rig through normal action;
- [ ] travel away/back preserves Mars state;
- [ ] build final Mars mine → 25,000 reward + snackbar;
- [ ] reduced-motion path completes;
- [ ] 360×640 and 430×932 do not overflow.

Run:

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart \
  test/mining/presentation/mining_screen_test.dart \
  test/integration/mining_mvp_journey_test.dart
```

### Step 10: Full GREEN before commit

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
- Extend existing offline-return/world tests only if a missing assertion is needed.
- Modify production simulation/offline code only if characterization exposes a concrete generic bug.
- Update draft PR body with verification/budget evidence.

### Step 1: Add deterministic three-planet characterization

- [ ] Seed one mine on Homeworld, Lunar, Mars.
- [ ] Advance one supplied UTC elapsed window.
- [ ] All three accrue from exactly that duration.
- [ ] Extraction applies once to Mars rate.
- [ ] Logistics applies once to Mars capacity/offline cap.
- [ ] Locked Mars stays pristine and produces zero.

Run:

```sh
flutter test test/mining/mining_simulation_test.dart
```

Intended result: GREEN with no structural production change.

### Step 2: Pin full storage/offline grouping reuse

- [ ] Mars at effective capacity produces no excess and does not disturb other planets.
- [ ] Offline summary includes Mars through existing `productionByPlanet` grouping.
- [ ] Switching active planet does not affect which unlocked planets accrue.

### Step 3: Visual/budget smoke

- [ ] Branch adds **zero** image/audio files; asset payload delta = 0 bytes.
- [ ] Mars uses only frozen existing facility sprites + Material resource icons.
- [ ] Exactly one active `MiningGame` is mounted.
- [ ] Each active world has one 36×36 terrain, one tint overlay, and three sector components.
- [ ] Smoke Homeworld/Lunar/Mars at 360×640 and 430×932.
- [ ] Confirm Mars terrain reads as rust-toned inside the playable world, not merely in letterbox/background.
- [ ] Confirm Lunar/Homeworld remain readable under the same overlay mechanism.
- [ ] Smoke reduced motion.
- [ ] Record any observed load/frame regression; do not add a benchmark harness absent a reproducible issue.

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
- [ ] No six→nine compatibility reader.
- [ ] No Mars-specific controller/simulation/repository/save key.
- [ ] No generic requirement/reward engine.
- [ ] No second terrain tint/content field or terrain-generation fork.
- [ ] Fresh map hides Mars; Lunar-unlocked map reveals it.
- [ ] Surveying text counts unlocked planets only.
- [ ] Mars mastery reward remains 25,000 and is treated as a completion flourish.
- [ ] PR reuse/change ledger matches the design.

Commit any final test/documentation-only adjustments:

```sh
git add .
git commit -m "test(mining): verify Mars content pack"
```

## Completion definition

HPA-641 is ready for review when Mars Frontier is playable from reveal through mastery on the same PR; its world is visibly rust-toned using the existing planet tint and zero new assets; current save/test fixtures use the strict nine-sector shape while old six-sector data clean-resets; all three unlocked planets accrue through the existing deterministic simulation; Surveying/Map presentation is honest about currently accessible content; the 25,000 mastery flourish is granted exactly once; and all repository gates pass.