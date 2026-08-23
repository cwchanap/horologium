# HPA-640 Lightweight Retention Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evaluate whether the completed three-planet mining game has a real post-Mars return-motivation gap and, only if Task 0 confirms that exact problem, add one derived “fully upgrade Mars to Level 5” goal on the existing Offline Return and Mars Stellar Map surfaces.

**Architecture:** Reuse existing planet/mastery/progression seams. Mars gets one optional `postMasteryMineLevelTarget: 5`; `StellarMapPlanetView` projects the currently visible target and count after normal Mars mastery using the existing `MiningContentRegistry.isPlanetMastered` helper. `MiningScreen` turns that projection into one optional string for the existing Offline Return next-action line, while the existing Mars card shows the same progress secondarily. No save state, helper module, new view type, second card, controller/economy change, timer, or generic goal framework is added.

**Tech Stack:** Dart 3.8, Flutter, Flame 1.30, SharedPreferences 2.5, existing `flutter_test` suites.

**Spec:** `docs/superpowers/specs/2026-08-23-hpa-640-lightweight-retention-experiment-design.md`

## Global Constraints

- One branch and one PR for HPA-640.
- **Task 0 is a hard runtime-code gate.** Do not execute Tasks 1–3 unless a real post-Mars playtest records the specific missing-terminal-goal problem in Linear HPA-640.
- A valid terminal outcome is **No retention feature needed** with zero runtime Dart changes.
- Before Task 0 play begins, pre-register predicted Stellar Map opens and predicted next actions; do not rewrite the predictions afterward.
- Task 0 must explicitly evaluate the copy-only `lib/mining/mining_sheet_view.dart` alternative: announce the next visible facility tier in the existing upgrade body. If that would solve the observed problem, do not add a retention goal.
- If implemented, exactly one derived goal ships: after normal Mars mastery, all three Mars mines reach Level 5.
- No additional cash reward is part of this plan.
- If Task 0 says a payout is necessary, stop and revise the spec/plan before runtime code. Do not improvise a reward while executing this plan.
- Keep the strict mining save shape unchanged; add no persisted goal/completion/claim state, compatibility reader, or second save key.
- Keep one `MiningController`, `MiningSimulation`, `MiningSaveRepository`, save key, and active `MiningGame`.
- Do not create `mining_retention.dart`, `MarsDeepOperationsView`, another progress model, or a second Stellar Map card/section.
- Do not modify `MiningController`, `MiningSimulation`, selling, technology, resource identities, mine economics, or assets for the default experiment.
- No timer, recurrence, daily reset, streak, generated contract, dynamic market, new currency, server, analytics, notification, or generic quest/objective/achievement framework.
- Each implementation task ends with `flutter analyze --fatal-infos` and `flutter test` green before commit.

## Frozen Conditional Candidate

Runtime work is authorized only if Task 0 confirms the exact problem this candidate addresses.

```text
Eligibility: Mars Frontier normal mastery (existing Mines 3/3)
Goal:        all 3 Mars mines at Level 5
Reward:      no additional cash reward
Primary UI:  existing Offline Return next-action line
Secondary UI: existing Mars Stellar Map card
Persistence: existing mine levels only
```

### Sizing evidence

Current Level-1 full Mars cargo value at Logistics 0:

```text
Iron Rig        180 ×  32 =  5,760
Silica          160 ×  55 =  8,800
Cobalt          130 × 110 = 14,300
Total                      = 28,860
```

At Logistics 5 the capacity multiplier is 2.0, so the same Level-1 full sweep is 57,720. Extraction changes fill time, not full-storage sale value.

Upgrade spend:

```text
L1 -> L3 total = 129,000
L1 -> L5 total = 645,000
L3 -> L5 delta = 516,000
```

From a just-mastered low-cash Mars state that received the existing 25,000 mastery reward, a simple full-return/cheapest-next-upgrade estimate is approximately:

```text
Level 3: ~2-3 returns
Level 5: ~5 returns at Logistics 5; ~9 at Logistics 0
```

These are sizing estimates, not evidence that the mechanic is needed. Pre-existing cash and player behavior can shorten them. Level 5 is selected because it is both better-sized and semantically terminal: it is max mine level and the renderer's final elite-ring tier.

## Expected Final File Map When the Gate Passes

**Modify:**

- `lib/mining/mining_content.dart`
- `lib/mining/mining_progression_views.dart`
- `lib/mining/presentation/offline_return_sheet.dart`
- `lib/mining/presentation/mining_screen.dart`
- `lib/mining/presentation/stellar_map_sheet.dart`
- `test/mining/mining_content_test.dart`
- `test/mining/mining_progression_views_test.dart`
- `test/mining/presentation/offline_return_sheet_test.dart`
- `test/mining/presentation/mining_screen_test.dart`
- `test/mining/presentation/stellar_map_sheet_test.dart`
- `test/integration/mining_mvp_journey_test.dart`

**Do not modify for the frozen candidate:**

- `lib/mining/mining_controller.dart`
- `lib/mining/mining_state.dart`
- `lib/mining/mining_save_repository.dart`
- `lib/mining/mining_simulation.dart`
- `lib/mining/mining_sheet_view.dart` — this is evaluated in Task 0 as the cheaper alternative, not bundled with the selected experiment.
- assets or resource identities.

## Main Risks

1. **Inventing evidence.** Engineering completeness is not retention evidence. Task 0 must stop when no real gap is observed.
2. **Unobservable experiment.** A goal shown only on Stellar Map could fail simply because players do not open the travel/unlock sheet after Mars mastery. The primary surface is therefore the existing Offline Return next-action line, with Stellar Map secondary.
3. **Target too grindy.** Level 5 costs 645,000 from Level 1. Task 0 and final review must reject/remove it if the terminal goal feels like chore work rather than purposeful upgrading.
4. **Ignoring the cheaper explanation.** If the real problem is only that facility tier changes are invisible in `MiningSheetView`, one string is cheaper than a new post-mastery goal. Task 0 must test this explicitly.
5. **Forking mastery logic.** Use `MiningContentRegistry.isPlanetMastered`; do not introduce `minesBuilt == mineTotal` as a second mastery spelling in `_planetView`.
6. **Fixture churn / ambiguous tests.** Default the two new planet-view fields and scope `Mines 3/3` finders to the Mars card because all three planets can render the same text.
7. **Sticky experiment code.** Removal must remain one content value, two optional/defaulted view fields plus inline count, one Offline Return override path, one existing-card line, and tests.

---

## Task 0: Pre-register, play, and record the HPA-640 evidence gate

**Files:** none.

**Produces:** Linear evidence that either closes HPA-640 with no runtime code or authorizes Tasks 1–3.

- [ ] **Step 1: Pre-register the prediction before playing**

Add a Linear HPA-640 comment containing exactly these fields before the first return session:

```text
Pre-registered prediction
- Stellar Map opens across two return sessions: <number>
- Next action I expect to want after each return: <action>
- Problem I expect to notice, if any: <one sentence>
```

Do not edit these values after playing. The later gate note compares observation against prediction.

- [ ] **Step 2: Use a representative just-mastered Mars save**

Start from shipped post-HPA-641 behavior with:

```text
Homeworld mastered
Lunar Frontier mastered
Mars Frontier unlocked and mastered
Surveying 5
all three Mars mines built
at least one Mars mine below Level 5
no retention experiment code
```

Do not manufacture an experiment UI before observing the current game.

- [ ] **Step 3: Play two current return sessions naturally**

Use only shipped behavior:

```text
return
-> read Offline Return
-> sell cargo
-> inspect whichever mine/upgrade UI you naturally use
-> open Stellar Map only if you would naturally do so
-> leave
-> return again
```

Record:

```text
Observed Stellar Map opens: <number>
Observed next action after return 1: <action>
Observed next action after return 2: <action>
Was the existing Offline Return next-action copy useful?: <yes/no + why>
```

Use 360x640 and 430x932 when practical, but do not confuse layout checking with retention evidence.

- [ ] **Step 4: Explicitly evaluate the cheapest copy-only alternative**

Inspect `lib/mining/mining_sheet_view.dart`'s current upgrade body. The concrete alternative to the retention goal is:

```text
Add one clause announcing the next visible facility tier — e.g. that Level 5 brings the mine to its final/elite facility tier.
```

The gate note must answer:

```text
Would this one-string per-mine hint solve the observed problem? <yes/no + reason>
```

If **yes**, do not execute Tasks 1–3. HPA-640 has no justified retention mechanic.

- [ ] **Step 5: Make the gate decision**

If there is no real return-motivation gap, record:

```text
Decision: No retention feature needed
```

Include observed behavior and stop the plan.

If the specific problem is a missing visible post-Mars terminal upgrade goal, record all required HPA-640 fields:

```text
Observed gap: <what actually happened>
Rejected simpler alternatives:
- mining_sheet_view.dart visible-tier hint: <why insufficient>
- clearer existing goal/reward presentation: <why insufficient>
- balance tuning: <why insufficient>
- another planet: <why not the immediate solution>
Selected mechanic: derived Mars Level-5 goal on Offline Return + existing Mars card
Success criteria: <observable keep criteria>
Removal criteria: <observable removal criteria>
Prediction comparison: <what matched/did not match the pre-registration>
```

- [ ] **Step 6: Re-check candidate fit before runtime code**

Proceed only when the observation matches:

```text
After normal Mars mastery, make “all three Mars mines Level 5” visible on return.
No second payout.
```

If the evidence points to a different target, a payout, or another mechanic, stop and revise both spec and plan on this PR first.

---

## Task 1: Add one Mars content target and project it through the existing planet view

**Files:**

- Modify: `lib/mining/mining_content.dart`
- Modify: `lib/mining/mining_progression_views.dart`
- Modify: `test/mining/mining_content_test.dart`
- Modify: `test/mining/mining_progression_views_test.dart`

**Interfaces:**

- Consumes: `MiningPlanetDefinition`, existing `MiningContentRegistry.isPlanetMastered`, `MiningSave.sectors`, `StellarMapPlanetView`.
- Produces: `MiningPlanetDefinition.postMasteryMineLevelTarget`, `StellarMapPlanetView.postMasteryMineLevelTarget`, and `StellarMapPlanetView.minesAtPostMasteryTarget`.

- [ ] **Step 1: Write RED authored-content tests**

Add to `test/mining/mining_content_test.dart`:

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
  5,
);
```

Run:

```sh
flutter test test/mining/mining_content_test.dart
```

Expected: RED because the field does not exist.

- [ ] **Step 2: Add the smallest optional planet content field**

Extend `MiningPlanetDefinition`:

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

Set only Mars:

```dart
masteryRewardCash: 25000,
postMasteryMineLevelTarget: 5,
```

Homeworld and Lunar inherit `null`.

Do not add title, reward amount, milestone ID, condition list, registry, or helper module.

Run:

```sh
flutter test test/mining/mining_content_test.dart
```

Expected: PASS.

- [ ] **Step 3: Write RED existing-planet-view projection tests**

In `test/mining/mining_progression_views_test.dart`, create a Mars-mastered state with Mars mine levels `5, 4, 5` and assert:

```dart
final view = StellarMapView.from(state: state, content: content);
final mars = view.planet(MiningPlanetId.marsFrontier);

expect(mars.minesBuilt, 3);
expect(mars.mineTotal, 3);
expect(mars.postMasteryMineLevelTarget, 5);
expect(mars.minesAtPostMasteryTarget, 2);
```

Add pre-mastery coverage with only two Mars mines built:

```dart
expect(mars.minesBuilt, 2);
expect(mars.postMasteryMineLevelTarget, isNull);
expect(mars.minesAtPostMasteryTarget, 0);
```

Add complete coverage with levels `5, 5, 5`:

```dart
expect(mars.minesAtPostMasteryTarget, 3);
```

Keep Homeworld/Lunar target fields null.

Run:

```sh
flutter test test/mining/mining_progression_views_test.dart
```

Expected: RED because the view fields do not exist.

- [ ] **Step 4: Add defaulted view fields and reuse the mastery helper**

Extend the existing constructor without forcing unrelated fixtures to change:

```dart
class StellarMapPlanetView {
  const StellarMapPlanetView({
    required this.id,
    required this.name,
    required this.isUnlocked,
    required this.isActive,
    required this.minesBuilt,
    required this.mineTotal,
    required this.requiredMasteryPlanetId,
    required this.hasRequiredMastery,
    required this.requiredSurveyingLevel,
    required this.hasSurveying,
    required this.unlockCashCost,
    required this.hasCash,
    this.postMasteryMineLevelTarget,
    this.minesAtPostMasteryTarget = 0,
  });

  // existing fields...

  /// Currently visible authored post-mastery target. Null means either no
  /// target is authored or normal mastery has not made it visible yet.
  final int? postMasteryMineLevelTarget;
  final int minesAtPostMasteryTarget;
}
```

Inside `StellarMapView._planetView`, keep the current `minesBuilt` calculation, then add:

```dart
final isMastered = content.isPlanetMastered(definition.id, minedSectorIds);
final postMasteryTarget = isMastered
    ? definition.postMasteryMineLevelTarget
    : null;
final minesAtPostMasteryTarget = postMasteryTarget == null
    ? 0
    : definition.sectors
          .where(
            (sector) =>
                (state.sectors[sector.id]?.mine?.level ?? 0) >=
                postMasteryTarget,
          )
          .length;
```

Populate the existing planet view:

```dart
postMasteryMineLevelTarget: postMasteryTarget,
minesAtPostMasteryTarget: minesAtPostMasteryTarget,
```

Do **not** use `minesBuilt == definition.sectors.length` as a second spelling of mastery. Do **not** extract the five-line target count into a helper.

Run:

```sh
flutter test test/mining/mining_content_test.dart \
  test/mining/mining_progression_views_test.dart
flutter analyze --fatal-infos
flutter test
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```sh
git add lib/mining/mining_content.dart \
  lib/mining/mining_progression_views.dart \
  test/mining/mining_content_test.dart \
  test/mining/mining_progression_views_test.dart
git commit -m "feat(mining): project Mars terminal upgrade goal"
```

---

## Task 2: Put the goal on the existing return flow and existing Mars card

**Files:**

- Modify: `lib/mining/presentation/offline_return_sheet.dart`
- Modify: `lib/mining/presentation/mining_screen.dart`
- Modify: `lib/mining/presentation/stellar_map_sheet.dart`
- Modify: `test/mining/presentation/offline_return_sheet_test.dart`
- Modify: `test/mining/presentation/mining_screen_test.dart`
- Modify: `test/mining/presentation/stellar_map_sheet_test.dart`

**Interfaces:**

- Consumes: existing `StellarMapView` / `StellarMapPlanetView` projection from Task 1.
- Produces: optional `OfflineReturnSheet.nextActionText`, MiningScreen-supplied Mars goal copy, and one additional line in the existing Mars card.

- [ ] **Step 1: Write RED Offline Return tests before changing the widget**

Extend `test/mining/presentation/offline_return_sheet_test.dart`.

Default behavior must remain byte-for-byte meaningful:

```dart
expect(
  find.text('Next: sell cargo or upgrade a mine to keep the operation moving.'),
  findsOneWidget,
);
```

Add an override case:

```dart
await tester.pumpWidget(
  MaterialApp(
    home: OfflineReturnSheet(
      summary: summary,
      content: content,
      nextActionText: 'Next: fully upgrade Mars mines to Level 5 (2/3).',
    ),
  ),
);

expect(
  find.byKey(const Key('offline-return-next-action')),
  findsOneWidget,
);
expect(
  find.text('Next: fully upgrade Mars mines to Level 5 (2/3).'),
  findsOneWidget,
);
```

Also cover settled copy:

```text
Mars fully operational — Level 5 mines 3/3.
```

Run:

```sh
flutter test test/mining/presentation/offline_return_sheet_test.dart
```

Expected: RED because `nextActionText` does not exist.

- [ ] **Step 2: Add one optional presentation-ready Offline Return parameter**

Change only the existing sheet constructor/data:

```dart
class OfflineReturnSheet extends StatelessWidget {
  const OfflineReturnSheet({
    super.key,
    required this.summary,
    required this.content,
    this.nextActionText,
  });

  final OfflineProductionSummary summary;
  final MiningContentRegistry content;
  final String? nextActionText;
}
```

Replace the constant next-action `Text` with:

```dart
Text(
  nextActionText ??
      'Next: sell cargo or upgrade a mine to keep the operation moving.',
  key: const Key('offline-return-next-action'),
  style: const TextStyle(color: Colors.white70),
),
```

Do not pass state/controller into the sheet. Do not add another key or section.

Run:

```sh
flutter test test/mining/presentation/offline_return_sheet_test.dart
```

Expected: PASS.

- [ ] **Step 3: Write RED MiningScreen return-copy tests**

In `test/mining/presentation/mining_screen_test.dart`, reuse the existing repository/clock setup to cover three states that produce an Offline Return summary:

```text
pre-Mars mastery           -> existing generic next-action copy
Mars mastered, Level 5 2/3 -> Next: fully upgrade Mars mines to Level 5 (2/3).
Mars mastered, Level 5 3/3 -> Mars fully operational — Level 5 mines 3/3.
```

Assert by the existing key first, then text:

```dart
final nextAction = find.byKey(const Key('offline-return-next-action'));
expect(nextAction, findsOneWidget);
expect(
  find.descendant(
    of: nextAction,
    matching: find.text('Next: fully upgrade Mars mines to Level 5 (2/3).'),
  ),
  findsOneWidget,
);
```

Run:

```sh
flutter test test/mining/presentation/mining_screen_test.dart
```

Expected: RED because MiningScreen does not supply the override.

- [ ] **Step 4: Derive return copy from the existing Stellar Map projection**

Add one private presentation helper in `_MiningScreenState`; do not repeat mine-level counting:

```dart
String? _offlineReturnNextActionText() {
  final view = StellarMapView.from(
    state: _controller.state,
    content: _content,
  );
  final marsViews = view.planets.where(
    (planet) => planet.id == MiningPlanetId.marsFrontier,
  );
  if (marsViews.isEmpty) return null;

  final mars = marsViews.single;
  final target = mars.postMasteryMineLevelTarget;
  if (target == null) return null;

  if (mars.minesAtPostMasteryTarget >= mars.mineTotal) {
    return 'Mars fully operational — Level $target mines '
        '${mars.minesAtPostMasteryTarget}/${mars.mineTotal}.';
  }
  return 'Next: fully upgrade Mars mines to Level $target '
      '(${mars.minesAtPostMasteryTarget}/${mars.mineTotal}).';
}
```

Pass it through the existing `_showOfflineReturn` builder:

```dart
builder: (_) => OfflineReturnSheet(
  summary: summary,
  content: _content,
  nextActionText: _offlineReturnNextActionText(),
),
```

This deliberately reuses `StellarMapView` as the presentation projection. Do not call `MiningContentRegistry.isPlanetMastered` or recount levels again in MiningScreen.

Run:

```sh
flutter test test/mining/presentation/mining_screen_test.dart \
  test/mining/presentation/offline_return_sheet_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write RED Mars-card tests with card-scoped finders**

In `test/mining/presentation/stellar_map_sheet_test.dart`, do **not** write:

```dart
expect(find.text('Mines 3/3'), findsOneWidget);
```

because multiple mastered planets legitimately render `Mines 3/3`.

Scope all mastery/target assertions to the Mars card:

```dart
final marsCard = find.byKey(
  const Key('stellar-map-planet-marsFrontier'),
);

expect(
  find.descendant(
    of: marsCard,
    matching: find.text('Mines 3/3'),
  ),
  findsOneWidget,
);
expect(
  find.descendant(
    of: marsCard,
    matching: find.text('Level 5 mines 2/3'),
  ),
  findsOneWidget,
);
```

Add coverage:

```text
pre-mastery Mars -> no Level 5 line
mastered 0/3     -> Level 5 mines 0/3
mastered 2/3     -> Level 5 mines 2/3
complete 3/3     -> Level 5 mines 3/3 — complete
```

The existing test fixtures should compile unchanged because Task 1 defaulted both new view fields. Only Mars fixtures that exercise the feature need explicit target/count values.

Run:

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart
```

Expected: RED because `_progressRow` has no target line.

- [ ] **Step 6: Extend only the existing Mars-card progress row**

Keep the same card/key. Change `_progressRow` from one `Text` to a small presentation group such as:

```dart
Widget _progressRow(StellarMapPlanetView planet) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      'Mines ${planet.minesBuilt}/${planet.mineTotal}',
      style: const TextStyle(color: Colors.white70),
    ),
    if (planet.postMasteryMineLevelTarget case final target?) ...[
      const SizedBox(height: 4),
      Text(
        'Level $target mines '
        '${planet.minesAtPostMasteryTarget}/${planet.mineTotal}'
        '${planet.minesAtPostMasteryTarget >= planet.mineTotal ? ' — complete' : ''}',
        style: const TextStyle(color: Colors.white70),
      ),
    ],
  ],
);
```

Do not add a second card, button, section, key, `MarsDeepOperationsView`, or progress indicator.

Run:

```sh
flutter test test/mining/presentation/stellar_map_sheet_test.dart \
  test/mining/presentation/offline_return_sheet_test.dart \
  test/mining/presentation/mining_screen_test.dart
flutter analyze --fatal-infos
flutter test
```

Expected: PASS.

- [ ] **Step 7: Commit Task 2**

```sh
git add lib/mining/presentation/offline_return_sheet.dart \
  lib/mining/presentation/mining_screen.dart \
  lib/mining/presentation/stellar_map_sheet.dart \
  test/mining/presentation/offline_return_sheet_test.dart \
  test/mining/presentation/mining_screen_test.dart \
  test/mining/presentation/stellar_map_sheet_test.dart
git commit -m "feat(mining): surface Mars terminal upgrade goal"
```

---

## Task 3: Pin the return journey, verify the experiment, and record keep/remove

**Files:**

- Modify: `test/integration/mining_mvp_journey_test.dart`
- Modify: `CLAUDE.md` only if it enumerates post-Mars progression in a way that becomes misleading; otherwise leave it untouched.

**Interfaces:**

- Consumes: Task 1 projection and Task 2 existing-surface copy.
- Produces: one integrated progressed-save return characterization and the HPA-640 final Keep / Revise once / Remove decision.

- [ ] **Step 1: Make the existing save helper able to seed mine levels**

The current helper hardcodes Level 1. Change it explicitly rather than inventing another fixture helper:

```dart
Map<String, Object?> _mineDocument({
  int level = 1,
  double storedAmount = 0,
}) => <String, Object?>{
  'level': level,
  'storedAmount': storedAmount,
};
```

Existing callers remain unchanged because `level` defaults to 1.

- [ ] **Step 2: Add a progressed Mars return journey**

Seed the existing strict nine-sector document with:

```text
Homeworld/Lunar/Mars unlocked and mastered
active planet: Mars
Mars mine levels: 5, 4, 5
non-zero/eligible offline production window
```

Use `_mineDocument(level: ...)` for the three Mars mine records.

After pumping the screen and presenting Offline Return, assert:

```dart
expect(
  find.text('Next: fully upgrade Mars mines to Level 5 (2/3).'),
  findsOneWidget,
);
```

Dismiss Offline Return, open Stellar Map, then scope to the Mars card:

```dart
final marsCard = find.byKey(
  const Key('stellar-map-planet-marsFrontier'),
);

expect(
  find.descendant(
    of: marsCard,
    matching: find.text('Mines 3/3'),
  ),
  findsOneWidget,
);
expect(
  find.descendant(
    of: marsCard,
    matching: find.text('Level 5 mines 2/3'),
  ),
  findsOneWidget,
);
```

Also verify another planet's `Mines 3/3` does not make the Mars-scoped assertion ambiguous.

- [ ] **Step 3: Pin the no-schema/no-economy boundary**

Do not add controller reward tests because the frozen candidate does not change controller cash.

Keep persistence assertions focused on the existing document:

```text
no new root key
no claim/completion field
mine levels remain the source of progress
sell values and upgrade costs unchanged
```

No test should look for `retention`, `goalState`, `claimed`, or another save key.

- [ ] **Step 4: Run focused and full repository gates**

```sh
flutter test test/mining/mining_content_test.dart \
  test/mining/mining_progression_views_test.dart \
  test/mining/presentation/offline_return_sheet_test.dart \
  test/mining/presentation/mining_screen_test.dart \
  test/mining/presentation/stellar_map_sheet_test.dart \
  test/integration/mining_mvp_journey_test.dart

dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Expected: all pass when implementation occurs.

- [ ] **Step 5: Run the representative post-implementation review**

Compare the implemented experiment with the Task 0 pre-registration and observed baseline.

Review at 360x640 and 430x932, including reduced motion, and record:

```text
Did I notice the Level-5 goal on Offline Return without opening Stellar Map?
Did normal Sell -> Upgrade returns visibly advance it?
Did Level 5 feel terminal/satisfying or grindy?
Did the existing Mars card agree with Offline Return progress?
Would I have upgraded anyway without the named goal?
Would the mining_sheet_view.dart one-string hint have been enough?
```

- [ ] **Step 6: Record exactly one HPA-640 decision**

Choose:

```text
Keep
Revise once
Remove
```

Rules:

- **Keep:** goal is noticed on return, advances naturally, and Level 5 feels like a useful optional terminal objective.
- **Revise once:** only bounded copy or target-level evidence is wrong. Any target change requires updating the sizing arithmetic/spec before code.
- **Remove:** goal is ignored, redundant, grindy, or the copy-only alternative would have been sufficient.

If removing, delete the implementation on this same PR before closeout; do not leave dormant experiment code behind.

- [ ] **Step 7: Commit Task 3 when implementation is kept/revised**

```sh
git add test/integration/mining_mvp_journey_test.dart CLAUDE.md
git commit -m "test(mining): verify Mars terminal goal journey"
```

If `CLAUDE.md` did not require a change, omit it from `git add`.

---

## Final Scope Audit

Before making PR #18 ready for review, confirm:

```text
[ ] Task 0 evidence exists and pre-registration predates runtime code.
[ ] The concrete MiningSheetView copy-only alternative was explicitly rejected by observed evidence.
[ ] Exactly one optional target exists: Mars Level 5.
[ ] Offline Return is the primary goal surface; existing Mars card is secondary.
[ ] Normal mastery uses MiningContentRegistry.isPlanetMastered.
[ ] No mining_retention.dart or parallel progress model exists.
[ ] No second card/section/key exists.
[ ] No second cash payout exists.
[ ] No save field/key/version/migration exists.
[ ] MiningController and MiningSimulation are unchanged by the experiment.
[ ] Tests scope repeated Mines 3/3 text to the Mars card.
[ ] Integration _mineDocument has a defaulted level parameter instead of another helper.
[ ] Removal remains cheap and the final Linear Keep/Revise/Remove decision is recorded.
```

If Task 0 fails, none of Tasks 1–3 execute; PR #18 remains planning-only and HPA-640 closes with **No retention feature needed**.