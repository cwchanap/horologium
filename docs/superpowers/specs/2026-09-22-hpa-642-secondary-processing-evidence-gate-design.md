# HPA-642 — Secondary Processing Decision

- Date: 2026-09-22
- Status: Decision — Do not add processing
- Linear: HPA-642 — Future decision: evaluate whether secondary processing is justified
- Baseline: `main` at `035894ca8830aebf833411075dcc0eb2bad23942` after HPA-286 / PR #33

## Decision

**Do not add processing.**

HPA-641 completed the prerequisite multi-planet raw-resource game, but HPA-642 also requires a specific playtest-observed economy or progression problem that simpler existing levers cannot solve. Current repository evidence does not show that problem.

This PR records that decision only. It does not authorize implementation work, and it must remain documentation-only.

After this PR merges, close HPA-642. If later playtesting produces new evidence, evaluate that evidence as new scoped work rather than growing this closed decision PR.

## Evidence gate

Processing is not justified unless a future evaluation records all four items:

1. **Observed problem**
   - exact Homeworld -> Mars progression state;
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

Statements such as "the game needs more depth", "idle games have refineries", "the roadmap reached this ticket", or "processing would be fun" are not evidence.

## Current evidence

### HPA-285 playtest says keep the authored economy

`docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md` records a fresh-to-Mars live run using visible public actions.

Relevant late-game observations:

- Mars mastery ended at cash `33005` after the one-time `25000` mastery reward.
- Late-game progression still used repeated five-minute sell cycles.
- The playtest's explicit balance decision is **KEEP the authored numeric content** because all affordability gates and early/mid/late cadence passed.
- It records **no evidence-required balance change**.

That is negative evidence for introducing a new sink: the accepted live run did not identify an economy defect that processing needs to repair.

### The representative journey still leaves existing Technology spend

`test/integration/merge_mining_journey_test.dart` progresses to Mars mastery by purchasing Surveying through level 5; it does not purchase Extraction or Logistics.

`MiningContentRegistry.technologyCosts` is:

`300, 700, 1500, 4000, 9000`

Each untouched track therefore still has `15500` of authored spend, or `31000` across Extraction and Logistics.

`MiningContentRegistry.technologySiteGates` gates those levels on Landing Basin, Carbon Ridge, Granite Crater, Frozen Basin, and Titanium Highlands. Those sites are already commissioned by the time the representative journey reaches Mars mastery, so the remaining two tracks are still available progression rather than hypothetical locked sinks.

The post-Mars cash snapshot is therefore not evidence that the game has no remaining authored spend decision.

### HPA-641 explicitly rejects a post-Mars sequel tier

`docs/superpowers/specs/2026-08-22-hpa-641-mars-frontier-content-pack-design.md` freezes the Mars mastery reward as:

> a small completion flourish/rebate, not funding for another progression tier.

It also says not to increase that reward merely to create a larger economy spike without play/balance evidence.

HPA-642 must not reinterpret that flourish as a requirement for a new delayed-reward system after Mars mastery. A valid processing problem would need to emerge from the currently shipped Homeworld -> Lunar Frontier -> Mars Frontier loop, not from a desire to invent post-game progression.

## Cheaper levers already exist

`MiningContentRegistry` already owns the primary economy/progression numbers:

- per-site sale values;
- reveal/unlock/build values;
- rig spawn costs;
- production rates;
- capacities;
- Technology costs;
- planet unlock costs;
- mastery reward.

Existing Technology and Stellar Map presentation already own the visible long-term progression surfaces.

If later playtesting finds an actual economy/progression problem, these are the first levers to evaluate before adding durable processing state.

## Why the current cargo model makes processing expensive

The current active model is intentionally simple:

- `SiteProgress.storedAmount` is one scalar per site;
- each `MiningSiteDefinition` has exactly one mined `ResourceType`;
- `MiningSimulation.accrue()` fills that scalar up to site capacity;
- full cargo stops further raw production until storage has headroom;
- `MiningController.sellAllCargo()` sells and clears every active-planet site scalar using that site's `saleValuePerUnit`.

There is no reserved raw input, processed-output bucket, holdback policy, or per-resource inventory.

A "sell raw now or wait for a premium" refinery is therefore not a small presentation feature. If conversion drains `storedAmount`, it also creates mining headroom; without careful economics, waiting can become strictly better than selling and silently replace the cargo-full/sell loop rather than add a meaningful choice.

That interaction is another reason not to implement processing without concrete evidence.

## Historical production-chain guardrail

These old city-era documents are historical only:

- `docs/production_chains.md`
- `docs/production_chain_recommendations.md`
- `docs/superpowers/specs/2026-05-03-production-chain-expansion-design.md`
- `docs/superpowers/plans/2026-05-03-production-chain-expansion.md`

Do not revive their `Building`, `Resources`, recipe, worker, city-tick, recommendation, or graph architecture inside mining.

The active ownership remains:

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> Site Deck / Mine Site / Stellar Map / Technology
```

No second timer, processing service, recipe graph, currency, management screen, or parallel persistence path is justified.

## Save contract

For this decision, the save contract is unchanged.

The strict root remains exactly:

```text
cash, lastAccruedAtUtc, technology, unlockedPlanetIds, activePlanetId, docks, sites
```

`MiningSaveRepository` uses exact-key decoding and recovers incompatible documents by creating a fresh save.

Do not promise compatibility for a hypothetical future refinery. If future scoped work adds persisted processing state, that is a breaking pre-release save-contract change under the current policy unless that future ticket deliberately changes the policy. Do not add optional fallback keys, schema versions, or a migration framework speculatively.

## Non-binding ceiling for any future evaluation

This is a ceiling, not an implementation plan.

If new evidence later justifies revisiting processing, do not exceed this shape without a separate roadmap decision:

```text
one existing raw site's stored cargo
    -> one automatic refinery scalar
    -> one processed scalar
```

Constraints:

- run conversion inside the existing `MiningSimulation.accrue()` pass;
- do not add a new `ResourceType` merely to represent processed output;
- do not add a generic recipe type/registry;
- do not add a second timer/service;
- do not add a new management screen;
- raw and processed selling must remain distinct actions if an experiment needs both;
- reject the experiment if waiting becomes strictly dominant because the premium has no meaningful cash-now tradeoff or because conversion removes the cargo-full pressure that makes Sell relevant;
- any persisted state must follow the strict-save/breaking-change policy above;
- new art or SFX, if ever needed, must be scoped separately from implementation work.

Those constraints are intentionally insufficient to implement a refinery. A future evidence-backed ticket must design the actual interaction from its observed problem rather than inherit speculative numbers or sequencing from HPA-642.

## Verification

This PR should change only:

- `docs/superpowers/specs/2026-09-22-hpa-642-secondary-processing-evidence-gate-design.md`
- `docs/superpowers/plans/2026-09-22-hpa-642-secondary-processing-evidence-gate.md`

No production code, tests, save state, assets, dependencies, or platform files should change.

Run:

```sh
git diff --check
```

Then review the final branch diff and close HPA-642 after merge with **Do not add processing**.

## Assets

No image generation or SFX work is required.
