# HPA-640 Lightweight Retention Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evaluate whether the completed three-planet mining game needs one extra post-Mars return goal and, only if play evidence confirms that exact gap, extend the existing Mars planet card with a Level-3 mine-progress goal.

**Architecture:** Reuse the current planet/mastery/Stellar Map seams instead of adding a retention subsystem. One optional `postMasteryMineLevelTarget` value lives on `MiningPlanetDefinition`; the existing `StellarMapPlanetView` projects the derived count, and the existing Mars card renders one extra progress line after normal Mars mastery. There is no new save state, helper module, view type, second card, controller/economy change, timer, or generic milestone framework.

**Tech Stack:** Dart 3.8, Flutter, Flame 1.30, SharedPreferences 2.5, existing `flutter_test` suites.

**Spec:** `docs/superpowers/specs/2026-08-23-hpa-640-lightweight-retention-experiment-design.md`

## Global constraints

- One branch and one PR for HPA-640.
- **Task 0 is a hard runtime-code gate.** Do not execute Tasks 1–3 unless a real three-planet playtest records the specific missing-post-Mars-goal problem in Linear HPA-640.
- A valid final outcome is **No retention feature needed** with zero runtime changes.
- If implemented, exactly one mechanic ships: after normal Mars mastery, the existing Mars card shows progress toward all three Mars mines reaching Level 3+.
- No additional cash reward is part of this plan.
- If Task 0 specifically proves a completion payout is required, stop and revise the design/plan before runtime code. Do not improvise a reward while executing this plan.
- Keep the current strict mining save shape unchanged; add no persisted milestone state, claim flag, compatibility reader, or second save key.
- Keep one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, save key, and active `MiningGame`.
- Do not create `mining_retention.dart`, `MarsDeepOperationsView`, a second Stellar Map card/section, or another progress model.
- Normal Reveal, Build, Mine, Sell, Upgrade, Technology, Stellar Map unlock/travel, and offline behavior remain unchanged.
- No timer, recurrence, daily reset, streak, contract generation, dynamic market, new currency, server, analytics, notification, or new asset.
- No generic quest/objective/achievement/milestone/reward engine.
- Each implementation task ends with `flutter analyze --fatal-infos` and `flutter test` green before commit.

## Conditional experiment

The runtime work below is authorized only when Task 0 records that the real observed gap is a missing visible post-Mars upgrade goal.

```text
Eligibility: Mars Frontier normal mastery (existing Mines 3/3)
Goal:        all 3 Mars mines at Level 3+
Reward:      no additional cash reward
Surface:     one extra line in the existing Mars Stellar Map card
Persistence: existing mine levels only
```

Current Level-1 -> Level-3 Mars upgrade spend remains unchanged:

```text
Iron Rig          7,000 + 14,000 = 21,000
Silica Extractor 12,000 + 24,000 = 36,000
Cobalt Drill     24,000 + 48,000 = 72,000
Total                              129,000
```

## Expected final file map when the gate passes

**Modify only**

- `lib/mining/mining_content.dart`
- `lib/mining/mining_progression_views.dart`
- `lib/mining/presentation/stellar_map_sheet.dart`
- `test/mining/mining_content_test.dart`
- `test/mining/mining_progression_views_test.dart`
- `test/mining/presentation/stellar_map_sheet_test.dart`
- `test/integration/mining_mvp_journey_test.dart`

Do not modify:

- `lib/mining/mining_controller.dart`
- `lib/mining/mining_state.dart`
- `lib/mining/mining_save_repository.dart`
- `lib/mining/mining_simulation.dart`
- assets or resource identities.

## Main risks

1. **Inventing evidence.** Engineering completeness is not retention playtesting. Task 0 must stop the work when no real gap is observed.
2. **Forking mastery progress.** The experiment must remain fields on the existing planet definition/view and copy on the existing Mars card; no parallel module/view/card.
3. **Implied payout.** Derived mine levels cannot prove that a cash reward was granted. This plan has no second payout and UI must not say `cash earned`.
4. **UI duplication.** Before Mars normal mastery, the card remains the current `Mines x/3` shape. The Level-3 line appears only after `Mines 3/3`.
5. **Sticky experiment code.** The implementation must be removable by deleting one content value, two scalar view fields/counting lines, and one presentation branch.

---

## Task 0: Run and record the HPA-640 evidence gate

**Files:** none.

**Produces:** one Linear HPA-640 evidence/decision comment that either stops the task or authorizes the existing-card Level-3 goal.

- [ ] **Step 1: Use a representative progressed save**

Start from a state with:

```text
Homeworld mastered
Lunar Frontier mastered
Mars Frontier unlocked and mastered
Surveying 5
all three Mars mines built
at least one Mars mine still below Level 3
```

Use the current post-HPA-641 build. Do not add debug retention code to create the observation.

- [ ] **Step 2: Play the current return loop without an experiment**

Perform at least two short return sessions using only shipped behavior:

```text
return -> review offline production -> sell cargo -> inspect upgrades
-> inspect Stellar Map -> decide whether another return feels purposeful
```

Check the canonical portrait sizes when practical:

```text
360x640
430x932
```

- [ ] **Step 3: Record the gate decision**

If the existing loop already gives a clear satisfying reason to return, add a Linear comment containing exactly:

```text
Decision: No retention feature needed
```

Include the observed current behavior that made an extra mechanic unnecessary. Stop; do not execute Tasks 1–3.

If a real missing-goal problem is observed, the Linear comment must contain:

```text
Observed gap: <what the player actually experienced>
Rejected simpler alternatives: <why copy/reward presentation, balance tuning, or another planet is not the immediate fix>
Selected mechanic: existing Mars card Level-3 mine goal
Success criteria: <what would make the goal worth keeping>
Removal criteria: <what would make it redundant/chore-like>
```

- [ ] **Step 4: Re-check the selected shape before code**

Proceed only when the observation is specifically compatible with:

```text
After Mars Mines 3/3, show Level 3 mines x/3 on the same Mars card.
No additional payout.
```

If the playtest points to a different mechanic or says a payout is necessary, stop and revise the design/plan on this PR before touching runtime Dart.

---

## Task 1: Add one Mars content target and project it through the existing planet view

**Files:**

- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_progression_views.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_progression_views_test.dart`

**Interfaces:**

- Consumes: existing `MiningPlanetDefinition`, `MiningSave.sectors`, `StellarMapPlanetView`, and normal Mars `minesBuilt / mineTotal` projection.
- Produces: optional `MiningPlanetDefinition.postMasteryMineLevelTarget`, plus `StellarMapPlanetView.postMasteryMineLevelTarget` and `minesAtPostMasteryTarget` on the same planet record.

### Step 1: Write RED content tests

- [ ] Extend `test/mining/mining_content_test.dart` to pin the single authored target:

```dart
final content = MiningContentRegistry.stellarMining();

expect(
  content.planet(MiningPlanetId.homeworld).postMasteryMineLevelTarget,
  isNull,
);
expect(
  content.planet(MiningPlanetId.lunarFrontier).postMasteryMineLevelTarget,
  isNull,
);
expect(
  content.planet(MiningPlanetId.marsFrontier).postMasteryMineLevelTarget,
  3,
);
```

Run:

```sh
flutter test test/mining/mining_content_test.dart
```

Expected: RED because `postMasteryMineLevelTarget` does not exist.

### Step 2: Add the smallest planet content field

- [ ] Extend `MiningPlanetDefinition` with an optional constructor field:

```dart
class MiningPlanetDefinition {
  const MiningPlanetDefinition({
    required this.id,
    required this.name,
    required this.sectors,
    required this.terrainSeed,
    required this.tint,
    required this.unlockRequiredMasteryPlanetId,
    required this.unlockRequiredSurveyingLevel,
    required this.unlockCashCost,
    required this.masteryRewardCash,
    this.postMasteryMineLevelTarget,
  });

  // existing fields...
  final int? postMasteryMineLevelTarget;
}
```

- [ ] Set only Mars:

```dart
masteryRewardCash: 25000,
postMasteryMineLevelTarget: 3,
```

Homeworld and Lunar use the default `null`.

Do not add a reward amount, milestone ID, name, type, registry, or helper module.

- [ ] Run:

```sh
flutter test test/mining/mining_content_test.dart
```

Expected: PASS.

### Step 3: Write RED projection tests on the existing Mars planet view

- [ ] Extend `test/mining/mining_progression_views_test.dart` with a Mars-mastered state whose mine levels are `3, 2, 4`.

Assert the existing planet record carries the progress:

```dart
final view = StellarMapView.from(state: state, content: content);
final mars = view.planet(MiningPlanetId.marsFrontier);

expect(mars.minesBuilt, 3);
expect(mars.mineTotal, 3);
expect(mars.postMasteryMineLevelTarget, 3);
expect(mars.minesAtPostMasteryTarget, 2);
```

- [ ] Add pre-mastery coverage. With only two Mars mines built:

```dart
expect(mars.minesBuilt, 2);
expect(mars.postMasteryMineLevelTarget, isNull);
expect(mars.minesAtPostMasteryTarget, 0);
```

- [ ] Add `3, 4, 5` coverage:

```dart
expect(mars.minesAtPostMasteryTarget, 3);
```

- [ ] Keep Homeworld/Lunar target fields null even when their mines are high-level.

Run:

```sh
flutter test test/mining/mining_progression_views_test.dart
```

Expected: RED because the two scalar view fields do not exist.

### Step 4: Extend `StellarMapPlanetView` and `_planetView` inline

- [ ] Add only these fields to `StellarMapPlanetView`:

```dart
final int? postMasteryMineLevelTarget;
final int minesAtPostMasteryTarget;
```

- [ ] In `_planetView(...)`, keep the existing `minesBuilt` query and add the target/count beside it:

```dart
final isMastered = minesBuilt == definition.sectors.length;
final postMasteryMineLevelTarget = isMastered
    ? definition.postMasteryMineLevelTarget
    : null;
final minesAtPostMasteryTarget = postMasteryMineLevelTarget == null
    ? 0
    : definition.sectors
          .where(
            (sector) =>
                (state.sectors[sector.id]?.mine?.level ?? 0) >=
                postMasteryMineLevelTarget,
          )
          .length;
```

- [ ] Pass those values into the existing `StellarMapPlanetView` constructor.

Do not extract a helper function or new class for this five-line count.

- [ ] Run focused tests:

```sh
flutter test test/mining/mining_content_test.dart \
  test/mining/mining_progression_views_test.dart
```

Expected: PASS.

### Step 5: Full GREEN before commit

```sh
flutter analyze --fatal-infos
flutter test
```

Expected: PASS.

Commit:

```sh
git add lib/mining/mining_content.dart \
  lib/mining/mining_progression_views.dart \
  test/mining/mining_content_test.dart \
  test/mining/mining_progression_views_test.dart
git commit -m "feat(mining): project Mars level goal"
```

---

## Task 2: Extend the existing Mars card progress row

**Files:**

- Modify: `lib/mining/presentation/stellar_map_sheet.dart`
- Modify: `test/mining/presentation/stellar_map_sheet_test.dart`

**Interfaces:**

- Consumes: the existing `StellarMapPlanetView` plus `postMasteryMineLevelTarget` and `minesAtPostMasteryTarget` from Task 1.
- Produces: no new widget type or callback; only additional copy inside the existing planet card `_progressRow`.

### Step 1: Write RED widget tests for the same card

- [ ] Extend `stellar_map_sheet_test.dart` so a mastered Mars view with Level-3 progress `1/3` still renders one Mars planet card and shows:

```dart
expect(find.text('Mines 3/3'), findsOneWidget);
expect(find.text('Level 3 mines 1/3'), findsOneWidget);
```

- [ ] Before normal Mars mastery, assert the current shape remains:

```dart
expect(find.text('Mines 2/3'), findsOneWidget);
expect(find.textContaining('Level 3 mines'), findsNothing);
```

- [ ] At completion, assert:

```dart
expect(find.text('Level 3 mines 3/3 — complete'), findsOneWidget);
expect(find.textContaining('cash earned'), findsNothing);
expect(find.textContaining('+25,000'), findsNothing);
```

- [ ] Assert the existing Mars card key remains the only Mars card key; do not introduce a second card/section key.

Run:

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart
```

Expected: RED because `_progressRow` renders only `Mines x/y`.

### Step 2: Change `_progressRow` only

- [ ] Replace the single `Text` with a compact column owned by the same card:

```dart
Widget _progressRow(StellarMapPlanetView planet) {
  final target = planet.postMasteryMineLevelTarget;
  final targetCount = planet.minesAtPostMasteryTarget;
  final complete = target != null && targetCount == planet.mineTotal;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Mines ${planet.minesBuilt}/${planet.mineTotal}',
        style: const TextStyle(color: Colors.white70),
      ),
      if (target != null)
        Text(
          'Level $target mines $targetCount/${planet.mineTotal}'
          '${complete ? ' — complete' : ''}',
          style: const TextStyle(color: Colors.white70),
        ),
    ],
  );
}
```

No icon, progress bar, nested card, button, or new key is required for this experiment.

- [ ] Run:

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart
```

Expected: PASS.

### Step 3: Pin portrait layout with the extra line

- [ ] Reuse the existing sheet layout helper/tests and render the mastered Mars card at:

```text
360x640
430x932
```

Assert no overflow exception and that `Level 3 mines 1/3` is reachable in the existing scroll view.

Do not add a screenshot/golden harness.

### Step 4: Full GREEN before commit

```sh
flutter analyze --fatal-infos
flutter test
```

Expected: PASS.

Commit:

```sh
git add lib/mining/presentation/stellar_map_sheet.dart \
  test/mining/presentation/stellar_map_sheet_test.dart
git commit -m "feat(mining): show Mars level goal"
```

---

## Task 3: Prove the progressed journey and record Keep / Revise once / Remove

**Files:**

- Modify: `test/integration/mining_mvp_journey_test.dart`
- Modify: `CLAUDE.md` only when its current progression description would otherwise be factually incomplete.

**Interfaces:**

- Consumes: existing Mars progression, mine upgrades, Stellar Map opening, and the same-card Level-3 projection from Tasks 1–2.
- Produces: one end-to-end regression plus the final HPA-640 experiment decision.

### Step 1: Add the integration journey assertion

- [ ] Extend the existing progressed Mars journey rather than creating another end-to-end harness.

Seed or advance a valid Mars-mastered save with mine levels below the target, open the Stellar Map, and assert:

```dart
expect(find.text('Mines 3/3'), findsOneWidget);
expect(find.text('Level 3 mines 1/3'), findsOneWidget);
```

Then advance/seed the same valid state so all three Mars mines are Level 3+ and reopen/refresh the map:

```dart
expect(find.text('Level 3 mines 3/3 — complete'), findsOneWidget);
expect(find.textContaining('cash earned'), findsNothing);
```

The journey must continue to use the existing mining controller/sell/upgrade behavior; do not add a retention controller API.

Run:

```sh
flutter test test/integration/mining_mvp_journey_test.dart
```

Expected: PASS after Tasks 1–2.

### Step 2: Run repository verification

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Expected: PASS.

Scope audit:

```sh
git diff --name-only main...HEAD
```

Confirm there is no:

```text
lib/mining/mining_retention.dart
new save field
new SharedPreferences key
new controller mutation
new Stellar Map card/section
new image/audio asset
```

### Step 3: Run the post-implementation product review

On a representative mobile/portrait build, review:

- whether the player notices `Level 3 mines x/3` after Mars mastery;
- whether normal Sell -> Upgrade sessions visibly advance it;
- whether the Level-3 facility transformation is satisfying enough to justify the line;
- whether the line feels redundant or chore-like;
- whether the player can still identify the normal next mining action without opening Stellar Map.

### Step 4: Record exactly one Linear decision

Record one of:

```text
Decision: Keep
Decision: Revise once
Decision: Remove
```

Include the observed evidence.

For **Revise once**, restrict changes to copy or target presentation. If the requested revision is a cash payout or different mechanic, revise the design/plan first instead of smuggling the change into implementation.

For **Remove**, delete the Mars target field/value, the two scalar view fields/counting logic, the `_progressRow` branch, and their tests on this same PR. Do not leave dormant experiment infrastructure.

### Step 5: Commit final verification/doc changes

```sh
git add test/integration/mining_mvp_journey_test.dart CLAUDE.md
git commit -m "test(mining): verify Mars level goal"
```

If `CLAUDE.md` did not require a factual update, omit it from `git add`.

---

## Execution stop rules

Stop implementation immediately when any of these is true:

1. Task 0 finds no real retention gap -> close with **No retention feature needed**.
2. Task 0 finds a different gap -> revise design/plan before code.
3. Task 0 says a completion payout is required -> revise design/plan before code; do not add a reward ad hoc.
4. Implementing the Level-3 line appears to require save state, a controller API, a generic objective abstraction, or a second UI surface -> the proposed shape is wrong; stop and re-evaluate.

The expected implementation is deliberately small: one optional planet content field, two scalar values on the existing planet view, one inline count, one existing-card copy branch, and tests.