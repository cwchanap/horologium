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

The planning review is incorporated with one deliberate simplification beyond it:

- Keep Task 0 as a hard stop. Architecture completeness is not retention evidence.
- Do not create `mining_retention.dart`, `MarsDeepOperationsView`, a second Stellar Map card/section, or another progress model.
- Reuse the existing Mars mastery shape: authored planet content, derived mine progress in `StellarMapPlanetView`, and the existing Mars planet card.
- Do not infer a cash receipt from derived mine levels. UI may show progress/complete; only a controller transition that actually credits cash may show `+cash` copy.
- Remove the proposed second 25,000 cash reward from the default experiment. The visible Level-3 goal is the experiment. If Task 0 specifically proves that a completion payout is required, stop and revise this design/plan before runtime code; any future amount belongs on `MiningPlanetDefinition` next to `masteryRewardCash` and would reuse the existing `buildMine` false -> true reward pattern inside `upgradeMine`.

This keeps the experiment removable by deleting one authored target and the small existing-view branch that displays it.

## Why HPA-640 is next

The core roadmap chain is complete:

```text
HPA-631 -> HPA-636 -> HPA-638 -> HPA-641
```

The remaining roadmap children are optional decisions:

- HPA-640 — lightweight retention experiment;
- HPA-642 — secondary-processing decision.

Retention is the narrower decision and can be evaluated without adding a new economy. Do not jump to processing merely because the core content chain is complete.

## Current evidence and hypothesis

The repository proves that the three-planet architecture is complete, but it does **not** prove a retention problem.

Known facts:

- HPA-631 recorded a manual opening-loop playtest, but that was the one-planet MVP.
- HPA-641 verified three-planet progression, portrait layouts, simulation, offline production, and visual budgets; those are engineering/product checks, not retention evidence.
- `StellarMapPlanetView` already projects each planet's `minesBuilt / mineTotal`, and `StellarMapSheet` renders `Mines x/y` on the existing planet card.
- Mars normal mastery already uses a derived, no-flag, false -> true reward transition in `buildMine`; there is no separate mastery subsystem.
- Mine Level 3 already changes the rendered facility structure through the existing world tier logic.

Therefore the planning hypothesis is only:

> After Mars mastery, the player may still enjoy mining and upgrading but may lack one visible medium-term upgrade goal that makes another short return session feel purposeful.

That hypothesis is insufficient to ship anything.

## Required evidence gate

Before changing runtime Dart code, perform a representative three-planet playtest from a progressed save that has just mastered Mars Frontier.

Record all four items in Linear HPA-640:

1. **Observed gap** — what specifically makes another return session feel unnecessary or directionless.
2. **Simpler alternatives rejected** — why clearer existing copy/reward presentation, balance tuning, or simply another planet is not the right immediate fix.
3. **Selected mechanic** — confirm the existing-card Level-3 Mars goal below, or stop if the observation points elsewhere.
4. **Success/removal criteria** — what would justify keeping or deleting the experiment.

### Stop condition

If the current game already provides a clear and satisfying next action after Mars mastery, record:

> **No retention feature needed.**

Then close HPA-640 without runtime implementation.

If the playtest shows a different problem than "no visible post-Mars upgrade goal," revise this design and plan on the same PR before touching runtime code.

## Approaches considered

### A. No feature

This is the default when the evidence gate is unmet.

Advantages:

- zero code and zero new player surface;
- keeps the core loop focused;
- avoids inventing a problem from architecture alone.

### B. Extend the existing Mars card with a Level-3 goal — conditional recommendation

After normal Mars mastery, the existing Mars card gains one additional progress line:

```text
Mines 3/3
Level 3 mines 1/3
```

When complete:

```text
Mines 3/3
Level 3 mines 3/3 — complete
```

There is no new card, claim action, currency, timer, or reward by default.

Why this is the preferred experiment **if** the gate passes:

- it reinforces the existing Sell -> Upgrade loop rather than adding a parallel system;
- Level 3 already has a visible facility presentation tier;
- it naturally spans multiple short earning/upgrade sessions without a time window;
- completion is derived from irreversible mine levels, so no new save field or claim flag exists;
- it extends the Mars card the player already uses for planet progress/travel;
- it is removable by deleting one content value and one presentation branch.

### C. Sell contract / high-demand bonus / rare event

Do not select these first.

They require cumulative-sale state, changed sale rewards, time/random eligibility, or recurring content rules. HPA-640 allows one lightweight experiment, so this plan prepares no fallback framework.

## Conditional experiment contract

This section becomes executable only after Task 0 confirms the observed gap is a missing visible post-Mars upgrade goal.

### Eligibility

The extra line is visible only after Mars normal mastery: all three Mars mines exist.

Before Mars mastery, the existing Mars card remains unchanged and shows only normal mine progress/unlock/travel state.

### Goal

All three Mars mines must reach at least Level 3:

- Ochre Basin / Iron Rig — Level 3+
- Silica Dunes / Silica Extractor — Level 3+
- Cobalt Chasm / Cobalt Drill — Level 3+

The denominator remains the existing Mars `mineTotal`; do not create a second total.

### Why Level 3

Level 3 is already a meaningful visual tier in `MiningSectorComponent`: Level 3 adds the advanced platform and secondary machinery structure. The milestone therefore points the player toward an existing visible payoff rather than inventing a hidden numeric threshold.

From the current Mars catalog, moving all three Mars mines from Level 1 to Level 3 costs 129,000 cash in total:

- Iron Rig: 7,000 + 14,000 = 21,000
- Silica Extractor: 12,000 + 24,000 = 36,000
- Cobalt Drill: 24,000 + 48,000 = 72,000

Do not tune production rates, sale values, upgrade costs, or technology as part of this experiment.

## Existing architecture to extend

### Planet content

Extend `MiningPlanetDefinition` directly with one optional authored value:

```dart
final int? postMasteryMineLevelTarget;
```

The constructor default is `null`.

Values:

| Planet | `postMasteryMineLevelTarget` |
| --- | ---: |
| Homeworld | `null` |
| Lunar Frontier | `null` |
| Mars Frontier | `3` |

Do not add a milestone ID, objective type, reward registry, or separate retention model.

If future Task-0 evidence specifically requires a completion cash payout, stop and revise this design before code. That revision may add a direct `postMasteryRewardCash` field beside `masteryRewardCash`; it must not create a retention module or claim state.

### Stellar Map projection

Extend the existing `StellarMapPlanetView` with scalar progress owned by that same planet record:

```dart
final int? postMasteryMineLevelTarget;
final int minesAtPostMasteryTarget;
```

Inside `StellarMapView._planetView(...)`:

1. calculate `minesBuilt` exactly as today;
2. expose the authored target only when `minesBuilt == definition.sectors.length`;
3. when the target is visible, count that planet's mines whose level is `>= target`;
4. keep `mineTotal` as the denominator.

No new view class, helper file, or second collection is introduced.

The count is intentionally a small inline query next to the existing `minesBuilt` query.

### Stellar Map UI

Extend `_progressRow` on the existing planet card.

Always keep:

```text
Mines x/y
```

When `planet.postMasteryMineLevelTarget != null`, add directly below it:

```text
Level {target} mines {count}/{planet.mineTotal}
```

When `count == mineTotal`, append ` — complete`.

Do not:

- add another card or section;
- add another widget key;
- add a button or claim action;
- say `cash earned` or otherwise infer a payout from mine levels.

## State, persistence, simulation, and economy

No changes.

Keep the strict current save shape:

```text
cash
lastAccruedAtUtc
technology
unlockedPlanetIds
activePlanetId
sectors
```

Do not change:

- `MiningSave`;
- `MiningSaveRepository`;
- `MiningSimulation` or offline accrual;
- `MiningController` in the default no-payout experiment;
- selling, reveal, build, technology, or planet-unlock rules;
- resource identities or assets.

Mine levels already persist and only increase, so progress is deterministic and idempotent without any new state.

## Why there is no second cash reward by default

Mars normal mastery already grants 25,000 cash when the third mine is built. Cloning that amount after 129,000 of Level-1 -> Level-3 upgrades is not supported by current play evidence.

The proposed retention value is the named visible goal plus the existing Level-3 visual transformation. Adding a second payout would add economy behavior and controller transition tests without evidence that cash is the missing motivation.

Therefore the default experiment has **no additional payout**.

If later Task-0 evidence says the visual/progress goal is useful but needs a completion payout, revise the docs first. Any such payout must:

- live as direct Mars content next to `masteryRewardCash`;
- use a false -> true check inside the existing serialized `upgradeMine` mutation;
- save the upgrade and reward atomically once;
- use `MiningActionResult.message` as the only cash receipt;
- never render `cash earned` from derived state;
- add no claim flag or compatibility work.

## Non-goals

Do not add:

- `mining_retention.dart` or another retention-specific domain module;
- `MarsDeepOperationsView` or another progress model;
- a second Stellar Map card/section;
- daily/weekly missions, streaks, calendars, check-in rewards, notifications, or expiring windows;
- recurring/generated contracts;
- dynamic market prices or demand;
- random rare-deposit scheduling;
- a journal/codex subsystem;
- another planet;
- processing/refineries;
- a new currency;
- server/account/analytics infrastructure;
- new image/audio assets;
- new save fields or migration machinery;
- generic objective, milestone, quest, achievement, or reward frameworks.

## Success and removal criteria

If the evidence gate passes and the experiment is implemented, review fresh and progressed representative mobile builds.

### Keep

Keep the experiment only if:

- after Mars mastery, the player can immediately explain the Level-3 goal from the existing Mars card;
- normal Sell -> Upgrade return sessions visibly advance it;
- reaching Level 3 provides a satisfying visible facility payoff;
- the extra line feels optional rather than mandatory;
- the normal next mining action remains clear when the Stellar Map is not open.

### Revise once

Allow one bounded revision only for copy or target presentation when the existing-card goal is useful but unclear.

A request for a cash payout is a design change: stop and revise the docs before runtime work because it adds controller/economy behavior.

### Remove

Remove the experiment if:

- it feels like grind or a chore;
- it merely repeats an already-obvious upgrade goal;
- it does not affect the actual return decision because players rarely inspect the Stellar Map;
- the Level-3 visual payoff is too weak to matter;
- it creates pressure for recurring objectives.

## Verification contract

### Evidence gate

- A real three-planet post-Mars playtest note exists in HPA-640 before production code.
- The note records the observed problem, rejected simpler alternatives, selected mechanic, and success/removal criteria.
- If the gap is absent, implementation stops with **No retention feature needed**.

### Content/projection

Prove:

- Homeworld/Lunar have no post-mastery target;
- Mars target is exactly Level 3;
- the extra target is hidden before Mars normal mastery;
- after Mars mastery, progress counts only Mars mines at Level 3+;
- Level 4/5 satisfy the Level-3 target;
- `mineTotal` remains the existing denominator;
- Homeworld/Lunar mine levels cannot affect Mars progress.

### Stellar Map

Prove:

- before Mars mastery, the Mars card remains the current `Mines x/3` shape;
- after Mars mastery, the same card shows `Level 3 mines x/3`;
- 3/3 appends `complete` and never says cash was earned;
- no second card, section, action, or widget key is introduced;
- 360x640 and 430x932 remain overflow-free.

### Journey/full repository

When implementation occurs, prove the progressed Mars journey surfaces the existing-card goal and that normal sell/upgrade/gameplay behavior is unchanged.

Run:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

No new asset payload, save-shape delta, or controller/economy change is expected.

## Delivery boundary

Use one branch and one PR for HPA-640.

The PR begins planning-only. After the evidence gate:

- **No gap:** record **No retention feature needed**, close HPA-640, and do not implement the candidate.
- **Gap confirmed as missing post-Mars goal:** continue on the same PR using the accompanying plan, then record **Keep**, **Revise once**, or **Remove** in Linear.
- **Different gap or payout required:** revise this design and plan on the same PR before touching runtime code.

Do not create child tickets for content, view projection, UI, testing, or review.