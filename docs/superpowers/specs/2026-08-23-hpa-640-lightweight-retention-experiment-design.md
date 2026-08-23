# HPA-640 Lightweight Retention Experiment Design

## Status

Planning design for Linear HPA-640, **Optional: evaluate one lightweight retention experiment**.

HPA-641 is complete and PR #17 has merged, so Horologium now has the intended three-planet raw-resource game. HPA-640 remains evidence-gated: production code must not start until a real three-planet playtest records a specific return-motivation problem and rejects simpler fixes.

The valid outcome remains **No retention feature needed**.

Planning and any eventual implementation stay on one PR.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630 mining roadmap.
2. Linear HPA-640 evidence gate and product constraints.
3. This design.
4. HPA-641 implementation as the current three-planet architecture baseline.
5. `CLAUDE.md` repository guidance.

## Review disposition

The latest planning review is incorporated with one arithmetic correction:

- Keep Task 0 as a hard stop. Architecture completeness is not retention evidence.
- Keep the no-save/no-claim/no-framework shape.
- Keep post-mastery progress on `MiningPlanetDefinition` + `StellarMapPlanetView`; do not create `mining_retention.dart`, `MarsDeepOperationsView`, or a second card/section.
- Reuse `MiningContentRegistry.isPlanetMastered(...)` as the single mastery spelling inside `StellarMapView._planetView` rather than comparing `minesBuilt == mineTotal`.
- Make the existing Offline Return next-action line the primary return-session surface; keep the existing Mars Stellar Map card as secondary confirmation.
- Explicitly test whether a one-string upgrade-body hint in `mining_sheet_view.dart` is sufficient before authorizing a new goal.
- Pre-register the Task 0 prediction before play so the evidence gate is not purely retrospective.
- Scope widget finders to the Mars card and make the integration save helper accept an explicit mine level.
- Default the two new `StellarMapPlanetView` fields so unrelated const fixtures do not churn.
- Keep the second 25,000 cash payout removed. Derived mine levels may say `complete`; they may never claim a cash receipt.

The review suggested Level 5 as the better terminal target but stated that it costs roughly 301,000 more than Level 3. The current Mars catalog instead makes:

- Level 1 -> Level 3 cost **129,000** total;
- Level 1 -> Level 5 cost **645,000** total;
- therefore Level 3 -> Level 5 adds **516,000**, not ~301,000.

That larger delta strengthens the need to size the target before Task 0 rather than assuming Level 3 spans enough returns.

## Current evidence and hypothesis

The repository proves that the three-planet architecture works, but it does **not** prove a retention problem.

Known facts:

- HPA-631 recorded an opening-loop playtest, not post-Mars retention evidence.
- HPA-641 verified three-planet progression, portrait layouts, simulation, offline production, and visual budgets; those are product/engineering checks rather than evidence that another return goal is needed.
- Once Mars is mastered, there is no future planet unlock objective.
- Mines remain upgradeable through Level 5.
- The renderer already has meaningful structural presentation tiers: Level 3 adds the advanced platform and secondary machinery; Level 5 additionally adds the elite ring.
- The mining action sheet tells the player current mine level, production, capacity, storage, and upgrade cost, but does not explain that Level 3 or Level 5 changes the facility presentation.
- Offline Return already has one keyed next-action sentence (`offline-return-next-action`) shown in the return flow whenever an offline-production summary is presented.
- Stellar Map remains available after Mars mastery, but at that point its unlock/travel purpose is at its weakest.

Planning hypothesis:

> After Mars mastery, the player may still enjoy Sell -> Upgrade progression but may lack a visible terminal goal that makes several more return sessions feel purposeful.

This is a hypothesis only. It cannot authorize runtime work.

## Candidate sizing from the current economy

Target duration is derivable enough to avoid guessing before Task 0.

### Current Level-1 full Mars sweep

At Logistics 0, a completely full Level-1 Mars cargo sweep is:

| Mine | Capacity | Sale/unit | Full value |
| --- | ---: | ---: | ---: |
| Iron Rig | 180 | 32 | 5,760 |
| Silica Extractor | 160 | 55 | 8,800 |
| Cobalt Drill | 130 | 110 | 14,300 |
| **Total** | | | **28,860** |

Logistics 5 doubles capacity, so the same Level-1 full sweep is 57,720 cash. Extraction affects how quickly storage fills, not the value of already-full storage.

The current fill times are only minutes, while the offline cap is 8–24 hours, so a normal meaningful return is generally capacity-bound rather than time-bound once the player stays away longer than a few minutes.

### Level 3 target

Level 1 -> Level 3 costs:

```text
Iron Rig          7,000 + 14,000 = 21,000
Silica Extractor 12,000 + 24,000 = 36,000
Cobalt Drill     24,000 + 48,000 = 72,000
Total                              129,000
```

Mars normal mastery already grants 25,000 cash. With full-return selling and upgrades increasing capacity along the way, Level 3 is roughly a **2–3 return** target from a just-mastered, low-cash state. A player carrying extra cash can finish sooner.

That is too thin for the default retention experiment: it risks measuring whether the copy was noticed rather than whether a medium-term terminal goal improves return motivation.

### Level 5 target

Level 1 -> Level 5 costs:

```text
Iron Rig          7,000 + 14,000 + 28,000 + 56,000   = 105,000
Silica Extractor 12,000 + 24,000 + 48,000 + 96,000   = 180,000
Cobalt Drill     24,000 + 48,000 + 96,000 + 192,000  = 360,000
Total                                                   645,000
```

A simple full-return/cheapest-next-upgrade estimate from the existing 25,000 Mars mastery reward lands around:

- **~9 returns** at Logistics 0;
- **~5 returns** at Logistics 5.

This is an estimate, not play evidence: pre-existing cash, upgrade ordering, and actual return timing can shorten it. It is nevertheless a better-sized hypothesis than Level 3, and Level 5 has a clear semantic/visual meaning: maximum mine level and the renderer's final elite-ring tier.

Therefore the conditional candidate is **Level 5**, not Level 3.

## Required evidence gate

Before changing runtime Dart code, perform a representative three-planet playtest from a progressed save that has just mastered Mars Frontier and still has at least one Mars mine below Level 5.

### Pre-register before playing

Before the first session, add a short pre-registration note to HPA-640 containing:

```text
Predicted Stellar Map opens across two return sessions: <number>
Predicted next action I will want after each return: <action>
Predicted problem, if any: <one sentence>
```

Do not edit those predictions after playing; compare the observed behavior against them in the final gate note.

This does not turn a solo hobby playtest into analytics. It only makes the evidence gate less self-confirming.

### Play the current product without the experiment

Perform at least two short returns using only shipped behavior:

```text
return -> inspect offline production -> sell cargo -> inspect mine upgrades
-> optionally inspect Stellar Map -> leave -> return again
```

Record whether the Stellar Map is actually opened rather than forcing it open because the design mentions it.

### Explicit simpler alternative to test

Before authorizing any post-mastery goal, consider the smallest copy-only fix in `lib/mining/mining_sheet_view.dart`:

> Add one clause to the existing upgrade body that announces the next visible facility tier, e.g. that Level 5 brings the mine to its final/elite facility tier.

Task 0 must explicitly state why that per-mine hint would **not** solve the observed gap. If the problem is merely “I did not know upgrades changed the facility,” the retention gate fails: do not add a post-mastery goal.

Also reject or accept, with observed reasons:

- clearer existing goal/reward copy;
- balance tuning;
- stronger normal Mars mastery presentation;
- another planet as future content rather than a retention mechanic.

### Gate result

Record all four HPA-640 requirements:

1. **Observed gap** — what actually made another return session feel unnecessary or directionless.
2. **Simpler alternatives rejected** — including the concrete `mining_sheet_view.dart` visible-tier hint above.
3. **Selected mechanic** — confirm the conditional Level-5 Mars goal below, or stop/revise if the observation points elsewhere.
4. **Success/removal criteria** — what would justify keeping or deleting it.

If the current loop already gives a clear and satisfying next action, record:

> **Decision: No retention feature needed**

Then close HPA-640 without runtime implementation.

If the problem is real but the Level-5 candidate does not match it, revise this spec and plan **before** touching runtime code.

## Conditional experiment: Mars fully operational

This section becomes the implementation contract only after Task 0 passes with the specific “missing visible post-Mars terminal upgrade goal” problem.

### Eligibility and goal

Eligibility remains normal Mars mastery, using the existing `MiningContentRegistry.isPlanetMastered(MiningPlanetId.marsFrontier, minedSectorIds)` rule.

Goal:

> Upgrade all three Mars mines to Level 5.

There is no extra claim and no extra reward.

### Authored content

Add one optional field beside the existing planet progression metadata:

```dart
final int? postMasteryMineLevelTarget;
```

Values:

| Planet | Post-mastery mine level target |
| --- | ---: |
| Homeworld | none |
| Lunar Frontier | none |
| Mars Frontier | 5 |

This is content metadata, not a goal engine. Do not add a goal ID, title, reward object, conditions list, registry, or helper module.

## Derived projection on the existing planet view

Extend `StellarMapPlanetView` with defaulted fields:

```dart
class StellarMapPlanetView {
  const StellarMapPlanetView({
    // existing required fields...
    this.postMasteryMineLevelTarget,
    this.minesAtPostMasteryTarget = 0,
  });

  /// The currently visible authored post-mastery target. Null means either
  /// this planet has no authored target or normal mastery has not made it
  /// visible yet; widgets must not recalculate eligibility.
  final int? postMasteryMineLevelTarget;
  final int minesAtPostMasteryTarget;
}
```

Inside `StellarMapView._planetView`:

1. retain the existing `minesBuilt` calculation;
2. compute this planet's normal mastery with the existing `content.isPlanetMastered(definition.id, minedSectorIds)` helper;
3. expose `definition.postMasteryMineLevelTarget` only when normal mastery is true;
4. when visible, count this planet's mines whose existing `MineState.level >= target`;
5. keep the count inline in `_planetView`; do **not** extract a helper for one five-line query.

Homeworld/Lunar remain null. A pre-mastery Mars view remains null even though the Mars content definition is authored with target 5; the planet view field represents **current visibility**, not raw content.

No `MiningSave`, repository, controller, or simulation change is required.

## Primary surface: Offline Return

The experiment must be visible in the flow it is trying to influence.

`OfflineReturnSheet` already renders one keyed next-action sentence. Extend its constructor with one optional presentation-ready string:

```dart
const OfflineReturnSheet({
  super.key,
  required this.summary,
  required this.content,
  this.nextActionText,
});

final String? nextActionText;
```

The existing key remains:

```text
offline-return-next-action
```

When `nextActionText == null`, retain the current copy unchanged:

```text
Next: sell cargo or upgrade a mine to keep the operation moving.
```

`MiningScreen` derives the current `StellarMapView` from controller state before showing Offline Return and, when Mars has a visible Level-5 target, supplies presentation-ready copy from the existing Mars planet view:

```text
Next: fully upgrade Mars mines to Level 5 (x/3).
```

At 3/3, settled copy may say:

```text
Mars fully operational — Level 5 mines 3/3.
```

No cash-earned wording is allowed.

Offline Return appears only when there is an offline-production summary, so it is the **primary return-session surface**, not the only source of truth. If no summary is shown, normal mining UI remains unchanged and the Stellar Map provides the secondary progress surface.

Do not pass `MiningSave` into `OfflineReturnSheet` and do not make the sheet calculate eligibility.

## Secondary surface: existing Mars Stellar Map card

Keep the current planet card. Do not add another card, section, view type, or key.

After normal Mars mastery, `_progressRow` renders its existing:

```text
Mines 3/3
```

and one additional line:

```text
Level 5 mines x/3
```

At 3/3 it may append ` — complete`.

Before Mars mastery, only the existing `Mines x/3` behavior appears.

All widget tests that assert `Mines 3/3` must scope the finder to:

```dart
find.byKey(const Key('stellar-map-planet-marsFrontier'))
```

because multiple mastered planets legitimately render the same text.

## No second payout

The experiment has **no additional cash reward**.

Mars normal mastery already grants 25,000 cash via the existing false -> true transition in `MiningController.buildMine`. Mine levels are derived persisted state and cannot prove that a hypothetical past payout actually occurred, so the Level-5 projection must not say `cash earned`.

If Task 0 specifically demonstrates that a completion payout is necessary, stop implementation and revise the spec first. Any future amount would belong directly on `MiningPlanetDefinition` beside `masteryRewardCash` and would copy the existing false -> true transition pattern into `upgradeMine`. Do not add a retention module or claim flag.

## Persistence and offline behavior

No persisted shape changes.

Completion/progress derives from existing irreversible mine levels:

```text
cash
lastAccruedAtUtc
technology
unlockedPlanetIds
activePlanetId
sectors
```

Do not add:

- `retentionState`;
- completion/claim flags;
- a second SharedPreferences key;
- a migration/version reader;
- special offline-production logic.

## Non-goals

Do not add:

- a retention/domain helper file;
- a second progress/view class;
- a second Stellar Map card/section;
- daily/weekly missions, streaks, calendars, notifications, or expiring windows;
- generated contracts or cumulative sale counters;
- dynamic prices or demand;
- random timed events;
- processing/refineries;
- another currency;
- server/account/analytics infrastructure;
- new image/audio assets;
- a generic quest/objective/achievement/milestone/reward framework.

## Success and removal criteria

### Keep

Keep the experiment only if representative post-Mars play shows that:

- the player notices the goal on Offline Return without having to remember to open Stellar Map;
- normal Sell -> Upgrade return sessions visibly advance it;
- Level 5 feels like a clear terminal “Mars fully operational” outcome;
- the final Level-5 facility tier provides enough intrinsic visual payoff without a second cash reward;
- the goal remains optional and the normal next mining action stays understandable.

### Revise once

Allow one bounded revision for copy or the target level **only when new play evidence demonstrates the frozen value is wrong**. Target-level revision requires updating the sizing arithmetic and this design before code changes; it is not an implementation-time tuning knob.

Do not use “Revise once” to introduce a different mechanic or payout.

### Remove

Remove the experiment if:

- Level 5 feels grindy or chore-like;
- the player would have upgraded anyway and the named goal adds no return motivation;
- the Offline Return line is ignored or confusing;
- the per-mine `MiningSheetView` copy-only alternative would have been sufficient;
- the goal creates pressure for recurring objectives;
- it merely repeats obvious progress without changing the return decision.

Removal is expected to be cheap: delete one Mars content value, the two optional/defaulted planet-view fields/counting branch, the Offline Return override path, and the extra Mars-card line/tests.

## Verification contract

When implementation occurs, prove:

### Content/projection

- only Mars authors `postMasteryMineLevelTarget: 5`;
- normal mastery uses `MiningContentRegistry.isPlanetMastered`;
- target is hidden before Mars mastery;
- target count includes only Mars mines at Level 5+;
- Homeworld/Lunar remain null;
- existing `StellarMapPlanetView` fixtures compile without adding unrelated arguments.

### Offline Return

- default next-action copy is unchanged when no target text is supplied;
- mastered Mars with 0/3, partial, and 3/3 Level-5 mines uses the existing `offline-return-next-action` key with accurate copy;
- the sheet remains presentation-only;
- 360x640 and 430x932 remain overflow-free.

### Stellar Map

- no new section/card/key exists;
- Mars card shows `Mines 3/3` plus `Level 5 mines x/3` only after normal mastery;
- completed copy says complete, never cash earned;
- widget finders scope `Mines 3/3` to the Mars card.

### Integration

- extend `_mineDocument` with `int level = 1` so progressed saves can seed Level-5 mines without six or twelve UI upgrade taps;
- a return journey shows the primary next-action line and the secondary Mars-card count from the same projected state;
- no save-schema delta or controller/economy mutation occurs.

### Repository gates

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

## Delivery boundary

Use one branch and one PR for HPA-640.

- **Gate fails:** record **No retention feature needed**, close HPA-640, no runtime Dart.
- **Gate passes with the frozen problem:** continue on the same PR with the implementation plan.
- **Evidence points elsewhere:** revise spec/plan before runtime work.

Do not create child tickets for content metadata, view projection, Offline Return copy, Stellar Map copy, tests, or review.