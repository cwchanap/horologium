# HPA-640 Lightweight Retention Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evaluate whether the completed three-planet mining game needs one extra post-Mars return goal and, only if play evidence confirms the gap, ship one optional Mars Deep Operations milestone that rewards upgrading all three Mars mines to Level 3.

**Architecture:** Preserve the current mining controller/simulation/repository/save architecture. The experiment is a pure derived milestone over existing irreversible Mars mine levels, projected into one compact Stellar Map section and rewarded inside the existing `upgradeMine` mutation. No save field, timer, generated objective, claim action, or generic milestone framework is added.

**Tech Stack:** Dart 3.8, Flutter, Flame 1.30, SharedPreferences 2.5, existing `flutter_test` suites.

**Spec:** `docs/superpowers/specs/2026-08-23-hpa-640-lightweight-retention-experiment-design.md`

## Global constraints

- One branch and one PR for HPA-640.
- **Task 0 is a hard runtime-code gate.** Do not execute Tasks 1–4 unless a real three-planet playtest records a retention gap in Linear HPA-640.
- A valid final outcome is **No retention feature needed** with zero runtime changes.
- If implemented, exactly one mechanic ships: Mars Deep Operations.
- Eligibility starts only after normal Mars mastery.
- Goal is all three Mars mines at Level 3+.
- Reward is exactly 25,000 cash on the single false -> true completion transition.
- Keep the current strict mining save shape unchanged; add no persisted milestone state or compatibility reader.
- Keep one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, save key, and active `MiningGame`.
- Normal Reveal, Build, Mine, Sell, Upgrade, Technology, Stellar Map unlock/travel, and offline behavior remain available when the experiment is ignored.
- No timer, recurrence, daily reset, streak, contract generation, dynamic market, new currency, server, analytics, notification, or new asset.
- No generic quest/objective/achievement/milestone/reward engine.
- Each implementation task ends with `flutter analyze --fatal-infos` and `flutter test` green before commit.

## Frozen conditional experiment

```text
Eligibility: Mars Frontier normal mastery
Goal:        all 3 Mars mines at Level 3+
Reward:      25,000 cash
Surface:     one read-only card in Stellar Map
Persistence: none beyond existing mine levels/cash
```

Current Level-1 -> Level-3 Mars upgrade spend:

```text
Iron Rig          7,000 + 14,000 = 21,000
Silica Extractor 12,000 + 24,000 = 36,000
Cobalt Drill     24,000 + 48,000 = 72,000
Total                              129,000
```

## Expected final file map when the gate passes

**Create**

- `lib/mining/mining_retention.dart`
- `test/mining/mining_retention_test.dart`

**Modify**

- `lib/mining/mining_progression_views.dart`
- `lib/mining/mining_controller.dart`
- `lib/mining/presentation/stellar_map_sheet.dart`
- `test/mining/mining_progression_views_test.dart`
- `test/mining/mining_controller_test.dart`
- `test/mining/presentation/stellar_map_sheet_test.dart`
- `test/integration/mining_mvp_journey_test.dart`
- `CLAUDE.md` only if it currently enumerates the complete post-Mars progression contract and would otherwise become misleading.

`MiningSave`, `MiningSaveRepository`, `MiningSimulation`, resource identities, planet catalog, and assets should not change.

## Main risks

1. **Inventing evidence.** Engineering verification is not retention playtesting. Task 0 must stop the work when no real gap is observed.
2. **Double reward.** The Level-3 completion reward must be tied to the false -> true transition inside one serialized `upgradeMine` mutation.
3. **Feature-framework creep.** This is one concrete Mars milestone. Do not generalize it into arbitrary objectives or rewards.
4. **UI duplication.** The card should add a post-Mars goal, not repeat normal `Mines 3/3` mastery copy before Mars mastery.
5. **Accidental persistence work.** Mine levels already provide irreversible completion state; a new save field is unnecessary.

---

## Task 0: Run and record the HPA-640 evidence gate

**Files:** none.

**Produces:** one Linear HPA-640 evidence/decision comment that either stops the task or authorizes Mars Deep Operations.

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

Use the current main build from after HPA-641. Do not add debug retention code to create the observation.

- [ ] **Step 2: Play the existing return loop without the experiment**

Perform at least two short return sessions using only current behavior:

```text
return -> review offline production -> sell cargo -> inspect available upgrades
-> inspect Stellar Map -> choose whether another return feels purposeful
```

Check both canonical portrait sizes when practical:

```text
360x640
430x932
```

- [ ] **Step 3: Make the gate decision**

If the existing loop already gives a clear satisfying reason to return, write a Linear comment whose decision line is exactly:

```text
Decision: No retention feature needed
```

Include the observed current behavior that made an extra mechanic unnecessary. Then stop this plan; do not execute Tasks 1–4.

If a real post-Mars return-motivation gap is observed, the Linear comment must explicitly contain all four HPA-640 gate items:

```text
Observed gap
Rejected simpler alternatives
Selected mechanic: Mars Deep Operations
Success and removal criteria
```

The observation text must describe what happened in the playtest rather than restating this plan.

- [ ] **Step 4: Confirm scope before runtime work**

When proceeding, confirm the selected mechanic is still exactly:

```text
Upgrade all three Mars mines to Level 3 -> +25,000 cash once
```

If the playtest points to a different mechanic, stop and revise the design/plan on this same PR before touching runtime code.

---

## Task 1: Add the pure Mars Deep Operations rule and Stellar Map projection

**Files:**

- Create: `lib/mining/mining_retention.dart`
- Create: `test/mining/mining_retention_test.dart`
- Modify: `lib/mining/mining_progression_views.dart`
- Modify: `test/mining/mining_progression_views_test.dart`

**Interfaces:**

- Consumes: `MiningSave`, `MiningContentRegistry`, existing Mars content and normal mastery.
- Produces: `isMarsDeepOperationsEligible`, `marsDeepOperationsMineCount`, `isMarsDeepOperationsComplete`, and optional `StellarMapView.marsDeepOperations`.

### Step 1: Write RED pure-domain tests

- [ ] Create `test/mining/mining_retention_test.dart` with progressed-save helpers and tests proving:

```dart
expect(
  isMarsDeepOperationsEligible(marsMasteredState, content),
  isTrue,
);
expect(
  marsDeepOperationsMineCount(marsWithTwoLevel3Mines, content),
  2,
);
expect(
  isMarsDeepOperationsComplete(marsWithAllLevel3Mines, content),
  isTrue,
);
```

Also pin:

- Mars not mastered -> ineligible even if one/two mine levels are high;
- Level 4/5 counts as satisfying the Level-3 target;
- Homeworld/Lunar levels do not affect progress;
- exactly the three authored Mars sectors form the denominator.

Run:

```sh
flutter test test/mining/mining_retention_test.dart
```

Expected: RED because the file/functions do not exist.

### Step 2: Implement the concrete pure helper

- [ ] Create `lib/mining/mining_retention.dart` with only:

```dart
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

const marsDeepOperationsTargetLevel = 3;
const marsDeepOperationsRewardCash = 25000;

bool isMarsDeepOperationsEligible(
  MiningSave state,
  MiningContentRegistry content,
) {
  final minedSectorIds = state.sectors.entries
      .where((entry) => entry.value.mine != null)
      .map((entry) => entry.key);
  return content.isPlanetMastered(
    MiningPlanetId.marsFrontier,
    minedSectorIds,
  );
}

int marsDeepOperationsMineCount(
  MiningSave state,
  MiningContentRegistry content,
) => content
    .planet(MiningPlanetId.marsFrontier)
    .sectors
    .where(
      (sector) =>
          (state.sectors[sector.id]?.mine?.level ?? 0) >=
          marsDeepOperationsTargetLevel,
    )
    .length;

bool isMarsDeepOperationsComplete(
  MiningSave state,
  MiningContentRegistry content,
) =>
    isMarsDeepOperationsEligible(state, content) &&
    marsDeepOperationsMineCount(state, content) ==
        content.planet(MiningPlanetId.marsFrontier).sectors.length;
```

Do not add a class hierarchy or generic condition/reward representation.

- [ ] Run:

```sh
flutter test test/mining/mining_retention_test.dart
```

Expected: PASS.

### Step 3: Write RED Stellar Map projection tests

- [ ] Extend `test/mining/mining_progression_views_test.dart` so:

```dart
expect(
  StellarMapView.from(state: beforeMarsMastery, content: content)
      .marsDeepOperations,
  isNull,
);

final milestone = StellarMapView.from(
  state: marsMasteredWithTwoLevel3,
  content: content,
).marsDeepOperations!;
expect(milestone.upgradedMines, 2);
expect(milestone.mineTotal, 3);
expect(milestone.targetLevel, 3);
expect(milestone.rewardCash, 25000);
expect(milestone.isComplete, isFalse);
```

Add a completed 3/3 assertion.

Run:

```sh
flutter test test/mining/mining_progression_views_test.dart
```

Expected: RED.

### Step 4: Add one concrete projection type

- [ ] In `mining_progression_views.dart`, add:

```dart
class MarsDeepOperationsView {
  const MarsDeepOperationsView({
    required this.upgradedMines,
    required this.mineTotal,
    required this.targetLevel,
    required this.rewardCash,
    required this.isComplete,
  });

  final int upgradedMines;
  final int mineTotal;
  final int targetLevel;
  final int rewardCash;
  final bool isComplete;
}
```

- [ ] Add `final MarsDeepOperationsView? marsDeepOperations;` to `StellarMapView`.
- [ ] In `StellarMapView.from`, set it to `null` until `isMarsDeepOperationsEligible(...)` is true; otherwise derive all fields from the helper/constants and the Mars planet definition.
- [ ] Keep existing planet-card projection unchanged.

Run:

```sh
flutter test test/mining/mining_retention_test.dart \
  test/mining/mining_progression_views_test.dart
flutter analyze --fatal-infos
flutter test
```

Expected: PASS.

Commit:

```sh
git add lib/mining/mining_retention.dart \
  lib/mining/mining_progression_views.dart \
  test/mining/mining_retention_test.dart \
  test/mining/mining_progression_views_test.dart
git commit -m "feat(mining): add Mars deep operations milestone"
```

---

## Task 2: Award Mars Deep Operations atomically from the existing upgrade mutation

**Files:**

- Modify: `lib/mining/mining_controller.dart`
- Modify: `test/mining/mining_controller_test.dart`

**Interfaces:**

- Consumes: `isMarsDeepOperationsComplete(...)`, `marsDeepOperationsRewardCash`.
- Produces: exactly-once cash reward and existing `MiningActionResult.message` completion copy.

### Step 1: Write RED controller transition tests

- [ ] Add a state with Mars mastered, two Mars mines Level 3, the final Mars mine Level 2, and enough cash for its L3 upgrade.
- [ ] Assert the final upgrade applies both normal cost and reward:

```dart
final beforeCash = controller.state.cash;
final result = await controller.upgradeMine(MiningSectorId.cobaltChasm);

expect(result.isSuccess, isTrue);
expect(
  result.message,
  'Mars Deep Operations complete — +25,000 cash.',
);
expect(controller.state.sectors[MiningSectorId.cobaltChasm]!.mine!.level, 3);
expect(
  controller.state.cash,
  beforeCash - 48000 + marsDeepOperationsRewardCash,
);
```

Use the actual Cobalt L2 -> L3 cost from the current catalog fixture rather than duplicating `48000` if the test helper already exposes the definition.

- [ ] Pin exact-once behavior by upgrading any Mars mine from Level 3 -> 4 after completion and asserting no second 25,000 credit/message.
- [ ] Pin that Homeworld/Lunar upgrades cannot complete/reward the Mars milestone.
- [ ] Pin repository save count remains one for the completing upgrade.
- [ ] Pin failed upgrade paths leave cash/progress unchanged.

Run:

```sh
flutter test test/mining/mining_controller_test.dart
```

Expected: RED.

### Step 2: Integrate the false -> true transition into `upgradeMine`

- [ ] Import `mining_retention.dart`.
- [ ] Immediately after accruing the candidate state, compute:

```dart
final wasDeepOperationsComplete = isMarsDeepOperationsComplete(
  candidate.state,
  content,
);
```

- [ ] Keep every existing upgrade validation unchanged.
- [ ] Build the normal upgraded state first:

```dart
final upgraded = candidate.state.copyWith(
  cash: candidate.state.cash - cost,
  sectors: sectors,
);
```

- [ ] Compute:

```dart
final completedDeepOperations =
    !wasDeepOperationsComplete &&
    isMarsDeepOperationsComplete(upgraded, content);
```

- [ ] Create `next` by adding `marsDeepOperationsRewardCash` only when `completedDeepOperations` is true.
- [ ] Persist `next` once and publish `_state = next` once.
- [ ] Return:

```dart
MiningActionResult.success(
  message: completedDeepOperations
      ? 'Mars Deep Operations complete — +25,000 cash.'
      : null,
)
```

Do not add a reward-claimed flag; mine levels are monotonic and the false -> true transition is sufficient.

### Step 3: GREEN and commit

```sh
flutter test test/mining/mining_controller_test.dart
flutter analyze --fatal-infos
flutter test
```

Expected: PASS.

Commit:

```sh
git add lib/mining/mining_controller.dart test/mining/mining_controller_test.dart
git commit -m "feat(mining): reward Mars deep operations"
```

---

## Task 3: Show one read-only Mars Deep Operations card in Stellar Map

**Files:**

- Modify: `lib/mining/presentation/stellar_map_sheet.dart`
- Modify: `test/mining/presentation/stellar_map_sheet_test.dart`

**Interfaces:**

- Consumes: `StellarMapView.marsDeepOperations`.
- Produces: one optional read-only card; no callbacks or mutation APIs.

### Step 1: Write RED widget tests

- [ ] Before Mars mastery, assert:

```dart
expect(find.byKey(const Key('stellar-map-mars-deep-operations')), findsNothing);
```

- [ ] After Mars mastery with 1/3 Level-3 mines, assert the card shows:

```text
Mars Deep Operations
Level 3 mines 1/3
Reward: 25,000 cash
```

- [ ] At completion, assert:

```text
Mars Deep Operations complete
Level 3 mines 3/3
25,000 cash earned
```

- [ ] Assert the card contains no `ElevatedButton`, `TextButton`, or claim action of its own.
- [ ] Keep existing unlock/travel button tests green.
- [ ] Pump the sheet at 360×640 and 430×932 and assert no overflow exception.

Run:

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart
```

Expected: RED.

### Step 2: Render the compact card

- [ ] After the planet-card loop in `StellarMapSheet`, add the card only when the optional view exists.
- [ ] Use key:

```dart
const Key('stellar-map-mars-deep-operations')
```

- [ ] Reuse the sheet's existing border/text vocabulary. A simple static card is sufficient; do not add animation.
- [ ] Use Material progress/check visuals only. Add no asset.
- [ ] Keep the card inside the existing `SingleChildScrollView`.

Suggested content logic:

```dart
final complete = milestone.isComplete;
Text(complete ? 'Mars Deep Operations complete' : 'Mars Deep Operations');
Text(
  'Level ${milestone.targetLevel} mines '
  '${milestone.upgradedMines}/${milestone.mineTotal}',
);
Text(
  complete
      ? '${_formatCash(milestone.rewardCash)} cash earned'
      : 'Reward: ${_formatCash(milestone.rewardCash)} cash',
);
```

Use a small local formatter or existing presentation formatter; do not move `_formatCash` into a new shared formatting framework solely for this card.

### Step 3: GREEN and commit

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart
flutter analyze --fatal-infos
flutter test
```

Expected: PASS.

Commit:

```sh
git add lib/mining/presentation/stellar_map_sheet.dart \
  test/mining/presentation/stellar_map_sheet_test.dart
git commit -m "feat(mining): show Mars deep operations progress"
```

---

## Task 4: Pin the complete post-Mars journey and record the experiment decision

**Files:**

- Modify: `test/integration/mining_mvp_journey_test.dart`
- Modify: `CLAUDE.md` only if the existing guidance would otherwise omit a shipped player-visible post-Mars milestone.

**Produces:** full repository verification plus one Linear decision: **Keep**, **Revise once**, or **Remove**.

### Step 1: Add one focused end-to-end journey

- [ ] Seed a progressed save where Mars is mastered and all three Mars mines are Level 2 with enough cash to perform the three L3 upgrades.
- [ ] Open Stellar Map and assert `Level 3 mines 0/3`.
- [ ] Upgrade the three Mars mines through the normal mining UI/controller flow.
- [ ] After each of the first two upgrades, reopen Stellar Map and assert 1/3 then 2/3.
- [ ] On the third upgrade, assert the snackbar:

```text
Mars Deep Operations complete — +25,000 cash.
```

- [ ] Reopen Stellar Map and assert the settled 3/3 completion state.
- [ ] Perform one later Level-4 Mars upgrade and assert no second 25,000 reward.

Run:

```sh
flutter test test/integration/mining_mvp_journey_test.dart
```

Expected: PASS.

### Step 2: Verify unchanged persistence/simulation scope

Because the experiment derives from existing mine levels:

- [ ] Confirm `MiningSave.toJson()` root keys are unchanged.
- [ ] Confirm `MiningSaveRepository._decode` is untouched.
- [ ] Confirm `MiningSimulation` is untouched.
- [ ] Confirm no new file exists under `assets/`.
- [ ] Confirm no new timer/date/random code exists under `lib/mining/` for this feature.

Use diff review rather than adding tests for file non-changes.

### Step 3: Full repository gates

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Expected: PASS.

### Step 4: Representative product review

On a representative portrait build, review:

```text
Mars mastered -> card appears -> sell/return -> buy upgrades
-> card progresses -> L3 visual tier appears -> final reward -> card settles
```

Check:

- the card is understandable in seconds;
- it does not obscure normal planet travel/unlock information;
- ignoring it leaves the normal mining action clear;
- the Level-3 visual change feels like the real payoff rather than only the cash;
- there is no streak/time-window/check-in pressure.

### Step 5: Record one Linear decision

Use exactly one of:

```text
Decision: Keep
Decision: Revise once
Decision: Remove
```

A **Revise once** decision may adjust only copy, the 25,000 reward, or the Level-3 presentation. If review indicates the mechanic itself is wrong, use **Remove** rather than expanding scope.

### Step 6: Final commit for journey/docs only when needed

```sh
git add test/integration/mining_mvp_journey_test.dart CLAUDE.md
git commit -m "test(mining): cover post-Mars retention milestone"
```

If `CLAUDE.md` required no change, omit it from `git add`.

---

## Final scope audit

Before marking the PR ready, verify the diff still contains only:

```text
one pure Mars milestone rule
one exact-once upgrade reward
one optional Stellar Map card
focused tests/docs
```

Reject any added:

```text
save field
migration
claim button
timer
random selection
recurrence
daily reset
new currency
new resource
new planet
new asset
objective framework
reward framework
processing/refinery code
```

If Task 0 concluded **No retention feature needed**, none of Tasks 1–4 should appear in the diff; the planning PR remains documentation-only and HPA-640 closes with the no-feature decision.
