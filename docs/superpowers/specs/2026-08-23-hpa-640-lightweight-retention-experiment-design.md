# HPA-640 Lightweight Retention Experiment Design

## Status

Planning design for Linear HPA-640, **Optional: evaluate one lightweight retention experiment**.

HPA-641 is complete and PR #17 has merged, so Horologium now has the intended three-planet raw-resource game. HPA-640 is the next optional roadmap decision, but its evidence gate remains authoritative: planning may define the smallest experiment candidate, while production code must not start until a real three-planet playtest records a return-motivation problem and rejects simpler fixes.

The valid outcome remains **No retention feature needed**.

Planning and any eventual implementation stay on one PR.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630 mining roadmap.
2. Linear HPA-640 evidence gate and product constraints.
3. This design.
4. HPA-641 implementation as the current three-planet architecture baseline.
5. `CLAUDE.md` repository guidance.

## Why HPA-640 is next

The core roadmap chain is complete:

```text
HPA-631 -> HPA-636 -> HPA-638 -> HPA-641
```

The remaining roadmap children are optional decisions:

- HPA-640 — lightweight retention experiment;
- HPA-642 — secondary-processing decision.

Retention is the narrower decision and does not introduce a new economy. Evaluate it first. Do not jump to processing merely because the core content chain is complete.

## Current evidence and hypothesis

The repository proves that the three-planet architecture is complete, but it does **not** yet prove a retention problem.

Known facts:

- HPA-631 recorded a manual opening-loop playtest, but that was the one-planet MVP.
- HPA-641 verified three-planet progression, portrait layouts, simulation, offline production, and visual budgets; those are engineering/product checks, not retention evidence.
- `StellarMapView` now exposes Homeworld, Lunar Frontier, and Mars Frontier. Once Mars is unlocked there is no fourth locked planet card or future-world objective.
- Mine upgrades remain available after Mars mastery, including the existing visually distinct level-3 facility tier.

Therefore the planning hypothesis is:

> After Mars mastery, the player may still enjoy mining and upgrading but may lack one visible medium-term goal that makes another short return session feel purposeful.

This is a hypothesis only. It is not sufficient evidence to ship a mechanic.

## Required evidence gate

Before changing runtime Dart code, perform a representative three-planet playtest from a progressed save that has just mastered Mars Frontier.

Record all four items in Linear HPA-640:

1. **Observed gap** — what specifically makes another return session feel unnecessary or directionless.
2. **Simpler alternatives rejected** — why clearer goal copy, reward presentation, balance tuning, or simply another planet is not the right immediate fix.
3. **Selected mechanic** — confirm the conditional Mars Deep Operations milestone below, or stop if the observation points somewhere else.
4. **Success/removal criteria** — what would justify keeping or deleting the experiment.

### Stop condition

If the current game already provides a clear and satisfying next action after Mars mastery, record:

> **No retention feature needed.**

Then close HPA-640 without runtime implementation. Do not execute the remaining implementation-plan tasks.

## Approaches considered

### A. No feature

This is the default when the evidence gate is unmet.

Advantages:

- zero code and zero new player surface;
- keeps the core loop focused;
- avoids inventing a problem from architecture alone.

Disadvantage:

- if playtesting does reveal a real post-Mars motivation gap, it leaves that gap unresolved.

### B. Mars Deep Operations milestone — conditional recommendation

After normal Mars mastery, show one optional milestone:

> Upgrade all three Mars mines to Level 3.

Completing it grants a one-time 25,000 cash reward.

Why this is the preferred experiment **if** the gate passes:

- it reinforces existing Mine → Sell → Upgrade behavior rather than adding a parallel system;
- level 3 already has a visible facility presentation tier;
- it naturally spans multiple short earning/upgrade sessions without a timer or check-in window;
- completion is derivable from irreversible mine levels, so no new save field or claim flag is required;
- it can be presented in one compact Stellar Map section;
- it is removable without touching simulation, offline accrual, resources, or save schema.

### C. Sell contract / high-demand bonus / rare event

Do not select these first.

They require additional cumulative-sale state, changing sale rewards, time/random eligibility, or recurring content rules. They are justified only if playtesting shows that an upgrade milestone specifically cannot solve the observed problem.

HPA-640 allows only one experiment. This plan does not prepare fallback implementations for these candidates.

## Conditional experiment: Mars Deep Operations

This section becomes the frozen implementation contract only after the evidence gate passes.

### Eligibility

The milestone becomes visible when Mars Frontier has normal mastery: all three Mars mines exist.

Before Mars mastery, no retention card is shown. Core planet progression remains the only objective.

### Goal

All three Mars mines must reach at least Level 3:

- Ochre Basin / Iron Rig — Level 3+
- Silica Dunes / Silica Extractor — Level 3+
- Cobalt Chasm / Cobalt Drill — Level 3+

Progress is displayed as:

```text
Mars Deep Operations
Level 3 mines 0/3
Reward: 25,000 cash
```

After completion:

```text
Mars Deep Operations complete
Level 3 mines 3/3
25,000 cash earned
```

The completed milestone remains visible in the Stellar Map as a settled achievement. There is no claim button.

### Reward

- Reward: **25,000 cash**.
- Grant on the single false -> true transition when an upgrade makes the last remaining Mars mine reach Level 3.
- Credit the reward in the same controller mutation and repository save as that upgrade.
- Return a successful `MiningActionResult.message`:

```text
Mars Deep Operations complete — +25,000 cash.
```

No additional animation system is required; the existing upgrade reward plus snackbar/haptic confirmation is sufficient.

### Why Level 3

Level 3 is already a meaningful visual tier in the mining world. The milestone therefore rewards a change the player can see rather than a hidden numeric threshold.

From the current Mars catalog, moving all three Mars mines from Level 1 to Level 3 costs 129,000 cash in total:

- Iron Rig: 7,000 + 14,000 = 21,000
- Silica Extractor: 12,000 + 24,000 = 36,000
- Cobalt Drill: 24,000 + 48,000 = 72,000

That is large enough to span several normal sell/return loops but does not require maxing every mine to Level 5.

Do not tune the core Mars production rates or upgrade costs as part of this experiment.

## State and persistence

Add **no new persisted state**.

Completion is derived from the existing `MiningSave.sectors` mine levels. Mine levels only increase, so the Level-3-all-mines transition can occur once.

This preserves the current strict save shape:

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
- a reward-claimed flag;
- a milestone-completed flag;
- a new SharedPreferences key;
- a save compatibility reader or migration.

Existing pre-release saves keep their current shape because the shape does not change.

## Domain seam

Add one small domain helper file rather than duplicating the Level-3 rule between controller and view projection:

`lib/mining/mining_retention.dart`

It owns only this concrete experiment:

```dart
const marsDeepOperationsTargetLevel = 3;
const marsDeepOperationsRewardCash = 25000;

bool isMarsDeepOperationsEligible(
  MiningSave state,
  MiningContentRegistry content,
);

int marsDeepOperationsMineCount(
  MiningSave state,
  MiningContentRegistry content,
);

bool isMarsDeepOperationsComplete(
  MiningSave state,
  MiningContentRegistry content,
);
```

Rules:

- eligibility = Mars normal mastery;
- progress = number of Mars mines with `level >= 3`;
- completion = eligible and progress equals the three authored Mars sectors.

This is intentionally concrete. Do not create a generic milestone engine, objective graph, reward registry, or condition DSL.

## Controller integration

Extend only the existing `upgradeMine(id)` mutation.

For every upgrade:

1. accrue once as today;
2. calculate `wasDeepOperationsComplete` from the pre-upgrade candidate state;
3. execute the normal validated upgrade;
4. calculate `isDeepOperationsComplete` from the proposed next state;
5. if `!wasDeepOperationsComplete && isDeepOperationsComplete`, add 25,000 cash;
6. save once;
7. return the completion message when rewarded.

Non-Mars upgrades and Mars upgrades before the final Level-3 transition keep their current result behavior.

Do not modify `MiningSimulation`, offline accrual, selling, technology, reveal, build, or planet-unlock rules.

## Presentation projection

Add a concrete optional view to `mining_progression_views.dart`:

```dart
class MarsDeepOperationsView {
  final int upgradedMines;
  final int mineTotal;
  final int targetLevel;
  final int rewardCash;
  final bool isComplete;
}
```

`StellarMapView` gains:

```dart
final MarsDeepOperationsView? marsDeepOperations;
```

Projection rules:

- `null` before Mars normal mastery;
- non-null after Mars mastery;
- progress and completion derived through `mining_retention.dart`;
- `mineTotal` comes from the Mars planet definition rather than hardcoded `3` in widgets.

No controller state is exposed directly to the widget.

## Stellar Map UI

Render exactly one compact section below the planet cards in `StellarMapSheet` when `view.marsDeepOperations != null`.

The section contains:

- title: `Mars Deep Operations`;
- progress: `Level 3 mines x/3`;
- reward or completion line;
- a progress indicator or checked icon using existing Material widgets.

There is no button. The player completes the objective through normal Mars mine upgrades.

The section must remain readable at 360×640 and 430×932 and inside the existing scrollable sheet. Reduced-motion behavior needs no special animation because the card is static.

## Non-goals

Do not add:

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
- generic objective, milestone, quest, achievement, or reward frameworks;
- special offline-production rules for the milestone.

## Success and removal criteria

If the evidence gate passes and the experiment is implemented, review fresh and progressed representative mobile builds.

### Keep

Keep the milestone only if:

- the post-Mars player can immediately explain the goal;
- normal Sell → Upgrade return sessions visibly advance it;
- reaching Level 3 provides a satisfying visual payoff;
- the objective feels optional rather than mandatory;
- the 25,000 reward is understandable without becoming a new progression tier;
- the normal next mining action remains clear when the card is ignored.

### Revise once

Allow one bounded revision only for copy, reward amount, or target Level 3 presentation when the mechanic is conceptually useful but one frozen value is clearly wrong in playtesting.

Do not turn a revision into a new mechanic.

### Remove

Remove the experiment if:

- players describe it as grind or a chore;
- the card merely repeats an already-obvious upgrade goal;
- it distracts from the mining screen;
- the reward is irrelevant and the goal has no intrinsic visual payoff;
- it creates pressure for recurring objectives.

## Verification contract

### Evidence gate

- A real three-planet post-Mars playtest note exists in HPA-640 before production code.
- The note records the observed problem, rejected simpler alternatives, selected mechanic, and success/removal criteria.
- If the gap is absent, implementation stops with **No retention feature needed**.

### Pure domain

Prove:

- hidden/ineligible before Mars mastery;
- progress counts only Mars mines at Level 3+;
- Level 4/5 still count as complete for that mine;
- completion requires all three Mars mines;
- Homeworld/Lunar levels do not affect the result.

### Controller

Prove:

- ordinary upgrades are unchanged;
- the final Level-3 Mars transition credits exactly 25,000;
- the reward and upgrade cost are applied atomically in one save;
- subsequent Mars upgrades cannot reward again;
- failure paths never change milestone state or cash;
- completion message uses the existing `MiningActionResult.message` path.

### Stellar Map

Prove:

- no card before Mars mastery;
- card appears immediately after Mars mastery;
- progress is accurate for 0/3 through 3/3 Level-3 mines;
- completed state remains visible;
- no new action button is introduced;
- 360×640 and 430×932 layouts remain overflow-free.

### Full repository

When implementation occurs:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

No new asset payload or save-shape delta is expected.

## Delivery boundary

Use one branch and one PR for HPA-640.

The PR begins planning-only. After the evidence gate:

- **No gap:** record **No retention feature needed**, close HPA-640, and do not implement the candidate.
- **Gap confirmed:** continue implementation on the same PR using the accompanying plan, then record **Keep**, **Revise once**, or **Remove** in Linear.

Do not create child tickets for domain logic, Stellar Map UI, reward handling, testing, or review.
