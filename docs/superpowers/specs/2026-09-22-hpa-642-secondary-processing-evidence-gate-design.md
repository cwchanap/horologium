# HPA-642 — Secondary Processing Evidence Gate Design

- Date: 2026-09-22
- Status: Proposed
- Linear: HPA-642 — Future decision: evaluate whether secondary processing is justified
- Baseline: main at 035894ca8830aebf833411075dcc0eb2bad23942 after HPA-286 / PR #33

## Decision summary

HPA-642 is the next remaining Horologium roadmap child, but its implementation gate is not currently met.

HPA-641 has shipped the third planet and the current product now has three planets, nine raw-resource sites, cash-funded technology, planet mastery, deterministic offline production, active-planet selling, dense resource fields, gameplay-only fleet management, resource-hit feedback, and a Site Deck cargo-full recovery path.

What is not currently documented is the other half of HPA-642's gate: a specific playtest-observed economy or progression problem that requires a new resource sink or a new wait-versus-sell choice.

The current design therefore defaults to:

**Do not add processing.**

This PR is decision-first. It documents the evidence threshold and the smallest legal experiment if future evidence arrives. It must not introduce production code merely because the roadmap has reached this issue.

## Problem

Secondary processing is expensive relative to the current game because it would add a new durable economic state and a second transformation step on top of an intentionally small raw-resource loop.

The active product loop is currently:

Reveal or unlock -> deploy rigs -> accrue raw cargo -> sell for cash -> buy technology / unlock progression -> repeat

The existing architecture is deliberately narrow:

MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> Site Deck / Mine Site / Stellar Map / Technology

MiningSimulation currently only accrues raw site cargo. MiningSave stores cash, technology, unlocked planets, the active planet, docks, and per-site state. MiningController owns all mutations and sellAllCargo remains the only sale mutation.

There is no refinery, recipe, processed-resource, routing, worker, power, or factory runtime in the active mining architecture.

Old city-era production-chain documents still exist under docs, but the city economy was removed by the mining cutover. Those documents are historical reference only and are explicitly not an implementation seam for HPA-642.

## Goals

- Make the HPA-642 evidence gate executable and reviewable.
- Prefer no feature over an unjustified processing subsystem.
- Require one concrete player problem before any production change.
- Reject simpler fixes explicitly before considering processing.
- If processing becomes justified, constrain it to exactly one raw resource, one automatic refinery, and one processed output.
- Preserve the existing single-controller, deterministic elapsed-time architecture.
- Preserve raw selling and normal planet progression.
- Keep one ticket = one PR.
- Require no new image or SFX work inside HPA-642.

## Non-goals

This design does not authorize:

- a generic recipe graph;
- multiple refineries or recipes;
- intermediate chains;
- transport, routing, workers, power, maintenance, or vehicles;
- dynamic markets;
- a second spendable currency;
- mandatory processing for progression;
- another state-management layer;
- revival of the deleted city production system;
- speculative save abstractions for future factories;
- new image generation or SFX work.

If a future justified implementation cannot reuse existing visual/audio material, stop and scope the asset work separately instead of mixing asset generation into this coding PR.

## Current evidence audit

### What the game already provides

Current main already has several ways to create spend and progression pressure without processing:

- three technology tracks with five levels each;
- technology costs of 300, 700, 1,500, 4,000, and 9,000 per level step;
- rig spawn/merge/deploy progression;
- per-site unlock costs and authored sale values;
- Homeworld -> Lunar Frontier -> Mars Frontier mastery gates;
- cash-funded planet unlocks;
- a one-time Mars mastery reward;
- per-site storage capacity and Logistics upgrades;
- active-planet raw selling;
- visible cargo-full recovery directly from Site Deck.

The content registry already owns the balance values that control rates, capacities, sale values, site unlocks, technology costs, planet unlocks, and rewards.

### What the recent polish work proved

Recent Horologium work addressed:

- dense resource fields and multi-rig placement;
- fleet-management friction;
- resource HP / hit readability;
- cargo-full readability and selling access.

Those are interaction and presentation improvements. They do not constitute evidence that the economy needs another resource transformation.

### Missing evidence

There is currently no HPA-642 comment, playtest note, test artifact, or roadmap decision that identifies a concrete problem such as:

- excess cash with no meaningful spend decision;
- raw-resource selling becoming strategically empty;
- a long progression plateau that simpler cost/reward tuning cannot solve;
- lack of an optional delayed-reward choice after Mars mastery.

Without one of those concrete observations, processing is a solution looking for a problem.

## Simpler alternatives that must be rejected first

A processing implementation is allowed only after the recorded problem is checked against these cheaper options.

### 1. Content or sale-value tuning

If the problem is cash inflation or trivial progression, first test content-only tuning in MiningContentRegistry:

- sale values;
- site unlock costs;
- rig spawn costs;
- technology costs;
- planet unlock cost;
- mastery reward.

This keeps simulation, persistence, UI ownership, and player mental model unchanged.

### 2. Existing technology as the spend sink

If players lack a useful cash decision, verify whether current technology pricing, visibility, or payoff is the actual issue before adding another system.

A technology-cost or presentation change is materially cheaper than a new durable resource flow.

### 3. Mastery / Stellar Map goal clarity

If the issue is "I do not know what to work toward", improve the existing mastery and next-planet goal presentation rather than inventing processing.

### 4. Another raw-resource/content beat

If the issue is lack of variety or long-term motivation, another visually distinct raw-resource content beat is cheaper than teaching and persisting a second economy layer.

Do not add another planet automatically; this alternative still requires evidence. The point is that content is a simpler lever than a new processing model.

### 5. Better reward presentation

If players do not feel a payoff after a progression milestone, improve the existing reward feedback before introducing another currency/resource transformation.

## Gate contract

Before production code can be added to this PR, HPA-642 must contain a concise evidence record with all of the following:

1. **Observed problem**
   - exact progression state;
   - what the player did;
   - what felt empty, stalled, or confusing;
   - why this matters to the mining loop.

2. **Reproduction**
   - fresh/progressed save state or deterministic fixture;
   - enough detail to reproduce the problem.

3. **Rejected simpler alternatives**
   - content/value tuning;
   - existing technology;
   - mastery/goal presentation;
   - raw content;
   - reward presentation.

4. **Success criterion**
   - one player-facing behavior that processing should improve;
   - measurable enough to review after implementation.

If any of those are missing, the implementation gate remains closed.

## Current decision

At the 2026-09-22 baseline, the required playtest evidence is absent.

Therefore the current planned shipping outcome is:

**Do not add processing.**

The expected code diff after planning review is zero production files and zero test files.

Merging this decision documentation is enough to record why the roadmap deliberately stopped here. After merge, HPA-642 can be closed with the same conclusion unless new evidence is added before implementation begins.

## Maximum experiment if the gate later becomes valid

If evidence is added and survives the simpler-alternative review before this PR merges, the same PR may be revised to implement exactly:

One existing raw resource -> one automatic refinery -> one processed output

The implementation must remain concrete and local.

### Ownership constraints

- MiningController remains the only mutation/persistence boundary.
- MiningSimulation remains the only elapsed-time economy calculator.
- MiningSaveRepository remains the only save owner.
- The refinery accrual must run in the same foreground/resume/cold-launch accrual pass as mining.
- Raw selling remains available.
- No widget writes state directly.
- No second timer, scheduler, event bus, or processing service is introduced.

### Data constraints

Do not pre-build a generic recipe model.

Only after the evidence identifies the actual resource/problem may the revised design freeze:

- one input resource;
- one output resource;
- one fixed refinery location;
- one build/unlock cost;
- one deterministic conversion rate;
- one output capacity, and input capacity only if the chosen interaction truly needs it;
- one processed sale premium.

Use the smallest concrete state needed for that single refinery. Do not generalize for a second consumer.

### Choice contract

The experiment is only valid if it creates an understandable optional decision:

- sell raw now for immediate cash; or
- leave raw available to the automatic refinery and receive more cash later.

If the implementation cannot make that choice clear in one compact surface, reject processing rather than adding toggles, routes, recipe selection, or another management screen.

## Save contract

Current mining saves are strict and unversioned.

The current root remains:

cash, lastAccruedAtUtc, technology, unlockedPlanetIds, activePlanetId, docks, sites

For the current no-processing outcome, that contract is unchanged.

If the gate later opens, the revised design must name the minimum new persisted refinery state explicitly and prove that cash, mines, technology, planets, cargo, and current progression remain intact. Do not add a versioning or migration framework just for speculative future factories.

## Historical production-chain guardrail

The following old documents are not active architecture:

- docs/production_chains.md
- docs/production_chain_recommendations.md
- docs/superpowers/specs/2026-05-03-production-chain-expansion-design.md
- docs/superpowers/plans/2026-05-03-production-chain-expansion.md

Do not copy their Building, Resources, recipe, worker, city-tick, or recommendation architecture into mining.

The active source of truth is CLAUDE.md plus lib/mining.

## Verification strategy

### Current no-processing outcome

Review should verify:

- HPA-641 is complete;
- HPA-642 has no current playtest evidence;
- no active mining refinery/recipe code exists;
- current cash/progression levers are owned by MiningContentRegistry;
- current save contract has no processing state;
- CLAUDE.md still forbids speculative processing/sink/currency layers;
- this PR changes documentation only.

No Flutter test/build run is required for a documentation-only decision unless repository policy requires it.

Run:

- git diff --check

### If the gate later opens

Before implementation, revise this design with concrete resource/economy numbers and file-level ownership.

Then require focused tests for:

- deterministic conversion;
- clamp to available raw input and output capacity;
- foreground/resume/cold-launch parity;
- atomic build/consume/produce/sell behavior;
- raw selling remaining available;
- persisted refinery state;
- old player progression retained;
- one compact presentation surface;
- no generic recipe/routing abstractions.

Finally run the normal repository gates from CLAUDE.md.

## Acceptance mapping

- Evidence precedes implementation: hard Task 0 gate.
- Simpler alternatives are explicit: five cheaper levers are reviewed first.
- Insufficient evidence has a successful outcome: Do not add processing.
- Any future experiment remains one raw -> one refinery -> one output.
- Raw selling remains part of the game.
- Determinism and persistence stay under existing mining owners.
- No generic production architecture is authorized.
- No new art/SFX work is mixed into HPA-642.

## Assets

No image generation or SFX work is required for the current decision-only outcome.

Any later justified implementation must reuse existing assets unless a separate asset task is deliberately scoped first.
