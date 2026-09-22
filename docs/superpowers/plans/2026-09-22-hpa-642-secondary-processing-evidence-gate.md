# HPA-642 — Secondary Processing Decision Plan

- Date: 2026-09-22
- Linear: HPA-642
- Design: `docs/superpowers/specs/2026-09-22-hpa-642-secondary-processing-evidence-gate-design.md`

## Delivery rule

One ticket = one documentation PR.

This PR records **Do not add processing** and then closes HPA-642 after merge.

Do not add implementation work to this branch, even if new evidence appears while review is open. New evidence should be evaluated as new scoped work so reviewers are not approving a decision-only PR that later grows an economy subsystem.

No image-generation or SFX work is included.

## Task 0 — Verify the evidence gate

Confirm all four implementation prerequisites are absent or incomplete:

1. one specific playtest-observed economy/progression problem;
2. a reproducible progression/save state;
3. rejected cheaper alternatives;
4. one success criterion for processing.

Reject generic motivation such as:

- more depth;
- genre convention;
- roadmap completion;
- thematic interest.

## Task 1 — Record the current negative evidence

The decision document must cite the evidence already present in the repository.

### HPA-285 live playtest

Use `docs/playtests/2026-08-26-hpa-285-three-planet-merge-mining.md`.

Record:

- fresh-to-Mars live progression passed;
- Mars mastery ended at cash `33005`;
- late-game progression still used real five-minute sale cadence;
- explicit balance decision: **KEEP the authored numeric content**;
- no evidence-required balance change was found.

### Existing remaining Technology spend

Use `test/integration/merge_mining_journey_test.dart`, `lib/mining/mining_content.dart`, and `lib/mining/mining_controller.dart`.

Record:

- the representative journey buys Surveying through level 5;
- Extraction and Logistics remain untouched;
- each untouched track still has `15500` of authored Technology spend;
- together they represent `31000`;
- their authored site gates are already commissioned by Mars mastery, so this is available progression rather than unreachable theoretical spend.

Do not claim that the Mars cash snapshot proves an empty economy sink.

### HPA-641 reward contract

Use `docs/superpowers/specs/2026-08-22-hpa-641-mars-frontier-content-pack-design.md`.

Record that the `25000` Mars reward is a completion flourish/rebate, explicitly not funding for another progression tier.

Do not use "optional delayed reward after Mars mastery" as a processing trigger. Any valid problem must emerge inside the shipped Homeworld -> Lunar -> Mars loop.

## Task 2 — Keep the cheaper levers and ownership boundaries explicit

Keep the decision small:

- authored rates/capacities/sale values/costs/rewards remain `MiningContentRegistry` concerns;
- Technology and Stellar Map remain the existing progression surfaces;
- city-era production-chain documents remain historical only;
- `MiningController`, `MiningSimulation`, and `MiningSaveRepository` stay the sole mutation/economy/persistence owners;
- no second timer, processing service, recipe graph, currency, or management screen.

## Task 3 — Keep the save policy honest

For this PR:

- root keys stay exactly `cash, lastAccruedAtUtc, technology, unlockedPlanetIds, activePlanetId, docks, sites`;
- no state/schema change occurs.

Do not promise progression retention for a hypothetical future refinery.

Current exact-key decoding means a future required persisted field is a breaking pre-release save change and incompatible documents recover fresh. Do not plan optional fallback keys, versioning, or migration here.

## Task 4 — Keep only a non-binding future ceiling

Do not include implementation tasks, test sequencing, expected production files, or "continue on this same PR" language.

If a future evaluation needs a recorded ceiling, keep only:

```text
one existing raw site's stored cargo
    -> one automatic refinery scalar
    -> one processed scalar
```

Constraints only:

- same `MiningSimulation.accrue()` pass;
- no new `ResourceType`;
- no generic recipe type;
- no second timer/service;
- no new screen;
- raw and processed selling are distinct actions;
- reject the experiment if waiting is strictly dominant or if conversion removes the cargo-full pressure that gives Sell meaning;
- persisted state follows the current breaking-save policy;
- new art/SFX, if required, is separate scoped work.

This ceiling is intentionally not enough to implement the feature.

## Task 5 — Verification and closure

Confirm the branch changes only the two HPA-642 planning documents.

Run:

```sh
git diff --check
```

Then:

1. merge the documentation PR;
2. record the final Linear conclusion: **Do not add processing**;
3. close HPA-642;
4. do not leave a dormant implementation branch or zombie processing issue.

## Expected files

Only:

- `docs/superpowers/specs/2026-09-22-hpa-642-secondary-processing-evidence-gate-design.md`
- `docs/superpowers/plans/2026-09-22-hpa-642-secondary-processing-evidence-gate.md`

No production/test/asset/save/dependency/platform files.

## Completion criteria

- evidence gate remains hard;
- repository evidence supports the no-processing decision;
- speculative Tasks 2–7 are removed;
- no implementation is allowed on PR #34;
- save compatibility is not promised;
- future ceiling is constraints-only;
- HPA-642 closes after the docs merge;
- no image/SFX work is included.
