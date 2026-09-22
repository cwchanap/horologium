# HPA-642 — Secondary Processing Decision

- Date: 2026-09-22
- Status: Decision — Do not add processing
- Linear: HPA-642 — Future decision: evaluate whether secondary processing is justified
- Baseline: `main` at `035894ca8830aebf833411075dcc0eb2bad23942`

## Decision

**Do not add processing. Close HPA-642 after this documentation PR merges.**

HPA-641 completed the multi-planet prerequisite, but HPA-642 also requires a specific playtest-observed economy or progression problem that simpler existing levers cannot solve. Current evidence does not establish that problem.

This PR records the decision only. If future playtesting identifies a concrete problem, evaluate it as new scoped work rather than reopening this branch.

## Evidence gate

Processing is not justified unless a future evaluation records all four items:

1. **Observed problem**
   - exact Homeworld → Mars progression state;
   - what the player did;
   - what felt empty, stalled, or strategically trivial;
   - why it damages the existing mining loop.

2. **Reproduction**
   - a concrete fresh/progressed save state or deterministic fixture;
   - enough detail to reproduce the problem.

3. **Rejected cheaper alternatives**
   - authored economy tuning;
   - existing Technology payoff/presentation;
   - mastery / Stellar Map goal presentation;
   - reward presentation;
   - another raw-resource/content beat when content variety is the actual problem.

4. **Success criterion**
   - one player-facing behavior the experiment should improve;
   - specific enough to review after implementation.

"The game needs more depth", genre convention, roadmap completion, or thematic interest are feature ideas, not evidence.

## Current evidence

### HPA-285 is useful negative evidence, but it is not a current measurement

`docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md` records a live fresh-to-Mars run performed on 2026-08-27.

It found:

- Mars mastery ended at cash `33005` after the one-time `25000` mastery reward;
- late-game progression still used repeated five-minute sell cycles;
- the explicit balance decision was **KEEP the authored numeric content**;
- there was **no evidence-required balance change**.

That run predates the September spatial grid cutover, HPA-454 dense resource fields/multi-robot placement, HPA-452 gameplay-only fleet management, and HPA-455 resource HP/hit feedback. Those changes altered the interaction model and per-site pressure after the live cadence measurement.

Therefore this playtest is historical negative evidence, not proof that the current loop has been freshly measured and found balance-perfect. The HPA-642 decision rests on the narrower claim: **there is still no current observed problem that justifies processing**. Absence of recent evidence is not a measured absence of problems.

### Existing authored spend also weakens the "empty sink" claim

The representative public-action journey in `test/integration/merge_mining_journey_test.dart` purchases Surveying through level 5 but does not purchase Extraction or Logistics.

`MiningContentRegistry.technologyCosts` is:

`300, 700, 1500, 4000, 9000`

Each untouched track therefore still has `15500` of authored spend, or `31000` across Extraction and Logistics.

The five `technologySiteGates` are Landing Basin, Carbon Ridge, Granite Crater, Frozen Basin, and Titanium Highlands. Those sites are necessarily commissioned on the representative route before Mars unlock, so the remaining two tracks are available progression rather than unreachable theoretical spend.

The post-Mars cash snapshot therefore does not establish an empty economy sink.

### HPA-641 explicitly rejects treating Mars mastery as the next progression tier

`docs/superpowers/specs/2026-08-22-hpa-641-mars-frontier-content-pack-design.md` freezes the Mars mastery reward as a small completion flourish/rebate, **not funding for another progression tier**.

HPA-642 must not reinterpret that reward as a requirement for a new post-Mars delayed-reward system. A valid processing problem would need to emerge from the shipped Homeworld → Lunar Frontier → Mars Frontier loop.

## Cheaper levers first

`MiningContentRegistry` already owns the primary economy/progression values: production rates, capacities, sale values, site costs, rig spawn costs, Technology costs/gates, planet unlock costs, and mastery rewards.

Existing Technology and Stellar Map presentation own the visible long-term progression surfaces.

If fresh playtesting later identifies an economy or progression problem, evaluate those existing levers before adding durable processing state.

## Why the current cargo model makes processing expensive

The current active model is intentionally simple:

- `SiteProgress.storedAmount` is one scalar per site;
- each `MiningSiteDefinition` has exactly one mined `ResourceType`;
- `MiningSimulation.accrue()` fills that scalar up to site capacity;
- full cargo stops further raw production until storage has headroom;
- `MiningController.sellAllCargo()` sells and clears every active-planet site scalar using that site's `saleValuePerUnit`.

There is no reserved raw input, processed-output bucket, holdback policy, or per-resource inventory.

A "sell raw now or wait for a premium" refinery is therefore not a small presentation feature. If conversion drains `storedAmount`, it also creates mining headroom; without careful economics, waiting can become strictly better than selling and silently replace the cargo-full/sell loop rather than add a meaningful choice.

That mechanism is a concrete reason not to add processing without evidence: cargo-full pressure is part of what gives Sell meaning today.

## Constraints on any future evaluation

Future evidence does **not** inherit a refinery design from HPA-642. It must design the interaction from the observed problem.

Durable constraints only:

- keep `MiningController`, `MiningSimulation`, and `MiningSaveRepository` as the mutation/economy/persistence owners;
- no new `ResourceType` merely to represent a processed output;
- no generic recipe type/registry, production graph, or second state owner;
- no second timer, scheduler, or processing service;
- no new management screen by default;
- raw and processed selling must remain distinct actions if both exist;
- reject any experiment where waiting becomes strictly dominant because the premium has no meaningful cash-now tradeoff or conversion removes the cargo-full pressure that gives Sell meaning;
- new art or SFX, if ever justified, is separate scoped work.

## Existing repository contracts

Ownership and the ban on speculative processing layers are already authoritative in `CLAUDE.md`; do not restate a parallel architecture here.

The strict, unversioned save contract and clean-reset behavior for incompatible pre-release data are also authoritative in `CLAUDE.md`. A future persisted processing field is a breaking save-contract change unless future scoped work deliberately changes that policy; HPA-642 does not promise compatibility or introduce migration/versioning.

`CLAUDE.md` now also marks the old city-era production-chain documents as historical reference only. Do not revive their `Building`/`Resources`/recipe/worker/city-tick architecture inside mining.

## Verification and closure

This PR is documentation/guidance only.

Expected changed paths:

- `CLAUDE.md`
- `docs/superpowers/specs/2026-09-22-hpa-642-secondary-processing-evidence-gate-design.md`
- `docs/superpowers/plans/2026-09-22-hpa-642-secondary-processing-evidence-gate.md`

Verify:

```sh
git diff --name-only origin/main...HEAD
git diff --check
```

The first command must list exactly the three paths above.

After merge, record **Do not add processing** as the final Linear outcome and close HPA-642.

## Assets

No image generation or SFX work is required.
