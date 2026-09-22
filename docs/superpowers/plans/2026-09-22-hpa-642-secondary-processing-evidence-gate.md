# HPA-642 — Secondary Processing Evidence Gate Implementation Plan

- Date: 2026-09-22
- Linear: HPA-642
- Design: docs/superpowers/specs/2026-09-22-hpa-642-secondary-processing-evidence-gate-design.md

## Delivery rule

One ticket = one PR.

Keep the evidence review, planning, and any justified implementation on this draft PR. Do not open a second implementation PR for HPA-642.

The current expected outcome is documentation-only:

**Do not add processing.**

Do not add production code unless Task 0 becomes green with concrete playtest evidence before this PR merges.

No image-generation or SFX work is included. If a future justified implementation genuinely needs new art or audio, stop and scope that asset work separately rather than mixing generation into this coding ticket.

## Task 0 — Enforce the evidence gate

This is a hard stop, not a planning suggestion.

### Required evidence

Before editing lib/ or test/, HPA-642 must record all four:

1. one specific playtest-observed economy or progression problem;
2. a reproducible progression/save state;
3. rejected simpler alternatives;
4. one success criterion for the processing experiment.

The problem must be narrower than statements such as:

- "the game needs more depth";
- "processing is common in idle games";
- "we reached the end of the roadmap";
- "a refinery would be fun".

Those are feature ideas, not evidence.

### Current baseline audit

Verify against current Linear/repository state:

- HPA-641 is Done.
- HPA-642 has no comments or recorded playtest problem.
- main is 035894ca8830aebf833411075dcc0eb2bad23942 after HPA-286 / PR #33.
- current main has no refinery/recipe/processed-resource runtime in lib/mining.
- MiningContentRegistry already owns the cheaper balance levers.
- MiningSave has no processing state.
- MiningSimulation only accrues raw site cargo.
- CLAUDE.md explicitly warns against a speculative processing/sink/currency layer.

### Current Task 0 result

**RED for implementation.**

The HPA-641 prerequisite is complete, but the required playtest-problem evidence is absent.

Therefore proceed to Task 1 and stop there unless new evidence is added before merge.

## Task 1 — Ship the no-processing decision cleanly

This is the active path for the current PR.

### Planning artifacts

Keep only:

- docs/superpowers/specs/2026-09-22-hpa-642-secondary-processing-evidence-gate-design.md
- docs/superpowers/plans/2026-09-22-hpa-642-secondary-processing-evidence-gate.md

Do not edit:

- lib/mining
- test/mining
- save schema/state
- assets
- pubspec
- platform scaffolding

### Decision record

After planning review, add a concise HPA-642 Linear comment that records:

- HPA-641 is complete;
- no specific processing-worthy economy/progression problem is currently documented;
- recent polish problems were solved without processing;
- simpler levers already exist in MiningContentRegistry and current progression UI;
- conclusion: **Do not add processing**.

Do not invent a playtest complaint in order to keep the issue open.

### Issue completion

After this decision PR merges, close HPA-642 as Done with the no-processing conclusion unless concrete new evidence was recorded while the PR was still open.

The roadmap outcome is successful even though no gameplay code ships.

### Verification

Run:

- git diff --check

Review the branch diff and confirm it contains only the two planning documents.

No Flutter build/test cycle is required for this documentation-only path unless repository automation requires one.

## Conditional Task 2 — Re-open the design only if evidence arrives before merge

Do not start this task from product intuition alone.

If Task 0 later becomes green, first revise the design document before writing code.

The revised design must freeze all of the following from the observed problem:

- the exact existing raw resource;
- the planet/site whose cargo participates;
- the processed output identity;
- why selling raw now versus waiting is a meaningful choice;
- refinery build/unlock cost;
- deterministic conversion rate;
- output capacity;
- input capacity only when needed;
- processed sale premium;
- compact UI location;
- success metric.

Do not use placeholder values.

Do not select a resource merely because it sounds thematically suitable.

### Required simpler-alternative rejection

The revised design must explain why the observed problem cannot be solved adequately by one of:

- sale-value tuning;
- site/rig/technology/planet cost tuning;
- technology payoff/presentation;
- mastery/Stellar Map goal clarity;
- reward presentation;
- another raw-resource/content beat.

If one of those solves the problem more cheaply, update HPA-642 back to Do not add processing and return to Task 1.

## Conditional Task 3 — Add the smallest concrete domain state

Only after the revised design is reviewed.

### Tests first

Add focused unit tests naming the exact chosen resource/refinery/output.

The tests must prove only the single experiment:

- fresh save has the authored refinery state;
- build/unlock is atomic;
- raw input cannot go negative;
- processed output cannot exceed capacity;
- conversion is deterministic from elapsed time;
- processing does not occur before unlock/build;
- raw cargo remains sellable.

### Production constraints

Use the smallest concrete mining-native types needed for one refinery.

Likely owners, only if the reviewed design requires them:

- lib/mining/mining_content.dart for one authored refinery definition and economy numbers;
- lib/mining/mining_state.dart for the minimum persisted refinery progress;
- lib/mining/mining_save_repository.dart for strict decode/validation;
- lib/mining/mining_simulation.dart for deterministic conversion;
- lib/mining/mining_controller.dart for build/sell mutation boundaries.

Do not introduce:

- Recipe;
- RecipeRegistry;
- ProductionGraph;
- FactoryManager;
- ProcessingService;
- route/worker/power abstractions;
- generic inventory containers for hypothetical future outputs.

Do not reuse deleted city Building/Resources architecture or old production-chain plans.

### Save rule

Preserve all existing player progression fields and values.

Do not add a schema-version/migration framework solely for this feature.

If the minimum experiment requires one new persisted object/value, make that change explicit and validate it narrowly.

### Focused gate

Run the focused domain tests plus:

- flutter analyze --fatal-infos

Do not move to presentation while domain behavior is red.

## Conditional Task 4 — Integrate conversion into the existing accrual path

Processing must share the same authoritative elapsed-time path as mining.

### Required behavior

MiningSimulation remains the only economy calculator.

One accrue call must:

1. compute raw mining production;
2. make the chosen raw amount available;
3. convert no more than available raw input;
4. produce no more than remaining processed-output capacity;
5. update the single refinery state;
6. return one coherent resulting state.

Foreground refresh, resume, and cold launch must therefore agree automatically.

Do not add:

- a refinery timer;
- widget timers;
- a background isolate;
- a second offline accrual function;
- a scheduler/event bus.

### Tests

Prove:

- same elapsed interval gives the same result through normal accrue and resume fixture paths;
- offline cap is applied once, not once to mining and again to processing;
- full output capacity stops conversion without losing raw cargo;
- insufficient raw input clamps conversion;
- multi-planet mining continues unchanged.

## Conditional Task 5 — Reuse controller and sale ownership

The player choice must remain understandable and atomic.

### Controller

MiningController remains the only public mutation boundary.

Add only the operation required by the frozen design, such as one build/unlock action.

Do not add a processing controller/service.

### Selling

Raw selling remains available.

The revised design must define exactly what the existing active-planet Sell action does with processed output:

- whether it sells processed output with the same action; or
- whether the compact refinery surface exposes one processed sale action.

Choose one. Do not create global inventory management or per-resource routing.

Whichever route is chosen, sale math and persistence must remain atomic and testable.

### Tests

Prove:

- raw selling still works before and after refinery unlock;
- processed premium is applied exactly once;
- busy-state serialization prevents overlapping build/process/sale writes;
- failed actions do not partially consume raw input or cash.

## Conditional Task 6 — Add one compact presentation surface

Do not add another management screen.

The surface must reuse an existing Horologium pattern and answer:

- what goes in;
- what comes out;
- current input/output amount;
- why waiting pays more;
- whether the refinery is locked/built/full.

Prefer extending an existing Site Deck or Mine Site contextual area over a new route.

Do not add recipe selection, toggles, routing controls, job queues, workers, power, or maintenance.

### Accessibility / responsive checks

Keep:

- portrait-first fit;
- >=48px actions;
- text scale 1.3 safety;
- reduced-motion behavior;
- existing semantic conventions.

### Assets

Reuse current assets.

If the reviewed UI cannot be understandable without new image art or SFX, stop implementation and scope that generation as a separate task.

## Conditional Task 7 — End-to-end decision review

The experiment is not automatically kept just because it works technically.

Run one fresh and one progressed save through:

- raw production;
- optional wait;
- processing;
- raw sale path;
- processed sale path;
- offline return;
- full output capacity;
- reload.

Then record one HPA-642 decision:

- Keep the single refinery;
- Revise once;
- Remove.

Keeping one refinery does not authorize a broader factory system.

## Final repository gates for a justified implementation

Only if Tasks 2–7 occur, run the normal gates from CLAUDE.md:

- dart format --output=none --set-exit-if-changed .
- flutter analyze --fatal-infos
- flutter test
- flutter test --coverage
- flutter test --platform chrome
- flutter build apk --debug
- flutter build web
- flutter build ios --simulator --debug
- git diff --check

## Expected files — current path

Planning only:

- docs/superpowers/specs/2026-09-22-hpa-642-secondary-processing-evidence-gate-design.md
- docs/superpowers/plans/2026-09-22-hpa-642-secondary-processing-evidence-gate.md

No production/test files are expected.

## Expected files — conditional implementation path

Only after a reviewed evidence-backed design, likely a narrow subset of:

- lib/mining/mining_content.dart
- lib/mining/mining_state.dart
- lib/mining/mining_save_repository.dart
- lib/mining/mining_simulation.dart
- lib/mining/mining_controller.dart
- one existing mining read-model/presentation surface
- focused matching tests

The revised design must name the exact files before implementation begins.

## Completion criteria — current path

- HPA-642 evidence gate is explicit.
- Current absence of playtest evidence is recorded.
- Simpler alternatives are named.
- Old city production-chain architecture is explicitly rejected.
- Current decision is Do not add processing.
- Branch remains documentation-only.
- No art/SFX task is needed.
- One ticket remains one PR.

## Scope guardrail

Stop and return to the decision gate if implementation starts requiring any of:

- a second refinery or output;
- recipe selection;
- generic recipe/resource graph types;
- routing/logistics/workers/power;
- another currency;
- another timer or processing service;
- a new management screen;
- mandatory processing for progression;
- save migration/versioning framework;
- old city Building/Resources architecture;
- new generated image art or SFX inside this PR;
- speculative abstractions for a future second consumer.
