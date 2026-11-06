# HPA-262 Io Frontier Content Pack Design

- Date: 2026-10-22
- Status: Implemented (2026-11-05); all repository gates passed locally. Previously: Proposed, revised after PR #45 review (2026-11-04)
- Linear: [HPA-262](https://linear.app/cwchanap/issue/HPA-262/mining-content-ship-io-frontier-as-the-fifth-planet-after-ceres) — Ship Io Frontier as the fifth planet after Ceres
- Baseline: current `main` after [HPA-427 / PR #48](https://github.com/cwchanap/horologium/pull/48) (Relaunch) and [HPA-87 / PR #51](https://github.com/cwchanap/horologium/pull/51) (all seven Io images)
- Asset dependency: [HPA-87](https://linear.app/cwchanap/issue/HPA-87/mining-art-io-frontier-planet-cavern-and-node-art) — complete; no art work in HPA-262
- Related: [HPA-427](https://linear.app/cwchanap/issue/HPA-427/mining-endgame-relaunch-after-the-final-frontier-for-a-permanent-cash) — already merged; its public-action journey includes two runs
- Precedent: `docs/superpowers/specs/2026-10-16-hpa-403-ceres-frontier-design.md`

## Goal

> Master Ceres Frontier → unlock Io Frontier → commission three new sites → mine Sulfur, Cinnabar, and Osmium → master Io and receive the game's one completion reward.

HPA-403 proved the planet seams are generic: Ceres needed content, three enum values, and one exhaustive switch arm. Io follows that pattern. `MiningController` already awards mastery from `masteryRewardCash`, `MiningContentRegistry.finalPlanetId` returns `MiningPlanetId.values.last`, and the next-goal ladder walks the authored enum order. Keep those existing state owners and behaviors; the only anticipated production edits are content/enums, the offline-return exhaustive switch, and repository guidance.

## Non-goals

This work does not add:

- a technology level above 5, a new technology track, or a new currency;
- a generic content, requirement, or reward engine, or a per-planet rule;
- an animated Io site;
- a sixth planet slot or procedural content;
- a save version, migration, or compatibility reader.

## Content

All Io amounts below are **final measured values**, not proposals. The public-action journey measured the candidate economy inside its acceptance window at both return cadences, so the shared tuning factor is **1.0** and no cost was rescaled. The pacing phase includes the cash wait to unlock Io. Io's mastery reward always matches its unlock cost rather than being an independent pacing lever.

### Planet

| Field | Value |
| --- | --- |
| ID | `MiningPlanetId.ioFrontier` |
| Name | `Io Frontier` |
| Unlock | Ceres Frontier mastery + Surveying 5 + 90,000,000 cash |
| Rig spawn cost | 22,500,000 |
| Mastery reward | 90,000,000 — equal to the final unlock cost (moved from Ceres; see decision 1) |
| Starter dock / site | Two T1 rigs in bays 1–2; Sulfur Flats unlocked, as `unlockPlanet` does for every planet |
| `planetAsset` | `assets/images/mining/planets/io_frontier.png` |

Visual fantasy: Jupiter's volcanic moon. Sulfur-yellow and orange plains, red-black lava calderas, a faint plume on the limb. Warm and bright, distinct from Mars' rust and Ceres' cool grey-blue.

### Sites

Storage follows HPA-401's rule (`baseCapacity = baseRatePerSecond × 7200`). Every site requires Surveying 5, and each site's four progression resources use `[5, 5, 5, 5]`, as on Mars and Ceres.

| Site | Resource | Facility | Requires | Unlock | Rate/s | Capacity | Sale/unit |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| Sulfur Flats | Sulfur | Sulfur Skimmer | — | 0 | 0.60 | 4,320 | 300 |
| Cinnabar Vents | Cinnabar | Cinnabar Bore | Sulfur Flats | 55,000,000 | 0.45 | 3,240 | 550 |
| Osmium Caldera | Osmium | Osmium Drill | Cinnabar Vents | 135,000,000 | 0.30 | 2,160 | 1,050 |

These are Ceres' rates with **approximately 3× unit sale values and approximately 3× prices** (550 versus 180, and 55M versus 18M, are not exactly 3×). Ceres' sale values were about 3× Mars', but its prices rose only about 1.8–1.9×; the Io pricing step is deliberately steeper, not the same price precedent. A T1 rig earns 180 / 247.5 / 315 cash per second, against 60 / 81 / 105 on Ceres, before any later bonuses.

Discovery copy:

- Sulfur Flats: a yellow sulfur crust steams over a warm floor.
- Cinnabar Vents: red cinnabar veins wrap the cooled lava channels.
- Osmium Caldera: the caldera floor hides the system's densest metal.

### Resources

`ResourceType` gains `sulfur`, `cinnabar`, and `osmium` (15 values). Silhouettes use built-in Material icons:

| Resource | Icon | Color |
| --- | --- | --- |
| Sulfur | `Icons.volcano` | `Colors.yellowAccent` |
| Cinnabar | `Icons.opacity` | `Colors.redAccent` |
| Osmium | `Icons.view_in_ar` | `Color(0xFF9FB4C7)` |

The HPA-87 node art follows these colors.

### Art

All seven HPA-87 images have merged via [PR #51](https://github.com/cwchanap/horologium/pull/51) and the paths were verified on current `main`: `planets/io_frontier.png`, `caverns/{sulfur,cinnabar,osmium}.png`, `nodes/{sulfur,cinnabar,osmium}.png` (all under `assets/images/mining/`). Use each cavern for its site card, as the Ceres content does. `pubspec.yaml` already declares these folders. This ticket does not generate or modify art.

## Design decisions

### 1. The completion reward moves from Ceres to Io

HPA-403 moved the reward from Mars to Ceres so it never funds the next unlock. The same rule moved it again: Ceres `masteryRewardCash` is 0 and Io's is 90,000,000, **equal to its final unlock cost** (the factor-1.0 tuning pass left the candidate unchanged; see decision 2). The game still grants exactly one mastery reward per run, and the controller and next-goal ladder handle it generically (`Io mastered — +90.00M cash.`).

### 2. Pacing: include the whole wait from the previous mastery

The authoritative journey measures a planet's phase as **previous planet mastery → this planet mastery**, not unlock → mastery. On current `main`, the reviewer's passing public-action journey run reported:

| Return cadence | Mars mastery → Ceres unlock | Ceres unlock → mastery | Ceres phase (= sum) |
| --- | ---: | ---: | ---: |
| Every 2 hours | 6 h | 16 h | **22 h** |
| Every 6 hours | 18 h | 48 h | **66 h** |

The new **Io phase = Io mastery time − Ceres mastery time**. It includes the cash grind after Ceres mastery to reach the 90M Io unlock gate; the journey must log this wait explicitly as `CADENCE ... phase=Ceres mastery before Io unlock`. Do **not** use Io unlock → mastery as the tuning numerator or Ceres unlock → mastery as the denominator. Those narrower intervals would omit the dominant new wait and contradict the recorded 22 h / 66 h baseline.

Target run-1 Io phase **1.2× to 2× the measured run-1 Ceres phase** at both cadences. If it misses, scale Io's unlock cost, Cinnabar unlock, Osmium unlock, and rig spawn cost by **one common factor**; keep base rates and sale values unchanged. `masteryRewardCash` equals `unlockCashCost`, but **is not a pacing lever**: it is paid only after the phase ends and does not fund the next planet.

The journey keeps its existing **absolute Mars and Ceres mastery bands** measured from run start and asserts Io absolute bands derived from passing run-1 measurements with margins comparable to those existing bands. Relaunch run 2 is checked **relative to run 1** (at most 80% of run-1 completion at 2-hour visits, faster at 6-hour visits), not against run-1 absolute bands.

#### Measured outcome

The candidate economy landed inside the 1.2×–2× window at both cadences, so **the shared factor is 1.0** and every candidate value shipped unchanged: Io unlock 90,000,000, site costs 0 / 55,000,000 / 135,000,000, rig spawn 22,500,000, `masteryRewardCash` 90,000,000. Rates and sale values were never adjusted.

| Return cadence | Mars mastery | Ceres mastery | Ceres phase | Ceres→Io cash wait | Io mastery | Io phase | Io ÷ Ceres |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Every 2 hours | 28.1 h | 50.0 h | 22.0 h | 14.0 h | 86.0 h | **36.0 h** | **1.64×** |
| Every 6 hours | 78.0 h | 144.1 h | 66.0 h | 42.0 h | 252.1 h | **108.0 h** | **1.64×** |

Final absolute run-1 Io bands asserted by the journey: **72–144 h (3–6 days)** at the 2-hour cadence (observed 86.0 h) and **168–336 h (7–14 days)** at the 6-hour cadence (observed 252.1 h) — margins comparable to the Mars (24–60 h / 2–4 days) and Ceres (40–90 h / 4–8 days) bands.

Run 2 sped up relative to run 1: Io mastery **60.0 h vs 86.0 h = 69.8% ≤ 80%** at the 2-hour cadence and **168.1 h vs 252.1 h = 66.7%, strictly faster** at the 6-hour cadence.

Selected final `MASTERY` / `CADENCE` / `RELAUNCH` log lines (phases are previous-planet mastery → this-planet mastery):

```text
MASTERY planet=Mars step=2h elapsed=28.1h marsPhase=28.1h visits=17 reward=0 cash=6346801->6346801 tech={extraction: 5, logistics: 5, surveying: 5}
MASTERY planet=Ceres step=2h elapsed=50.0h ceresPhase=22.0h visits=28 reward=0 cash=5935678->5935678 tech={extraction: 5, logistics: 5, surveying: 5}
CADENCE step=120m phase=Ceres mastery before Io unlock elapsed=14.0h visits=7 cash=95057032 bought=Iridium Spire +T1,Iridium Spire +T1
MASTERY planet=Io step=2h elapsed=86.0h ioPhase=36.0h visits=46 reward=90000000 cash=7716303->97716303 tech={extraction: 5, logistics: 5, surveying: 5}
RELAUNCH run=2 mastery=60.0h run1=86.0h finalPlanet=Io Frontier
MASTERY planet=Mars step=6h elapsed=78.0h marsPhase=78.0h visits=16 reward=0 cash=5332905->5332905 tech={extraction: 0, logistics: 5, surveying: 5}
MASTERY planet=Ceres step=6h elapsed=144.1h ceresPhase=66.0h visits=27 reward=0 cash=4921785->4921785 tech={extraction: 0, logistics: 5, surveying: 5}
CADENCE step=360m phase=Ceres mastery before Io unlock elapsed=42.0h visits=7 cash=94043145 bought=Iridium Spire +T1,Iridium Spire +T1
MASTERY planet=Io step=6h elapsed=252.1h ioPhase=108.0h visits=45 reward=90000000 cash=6702425->96702425 tech={extraction: 0, logistics: 5, surveying: 5}
RELAUNCH run=2 mastery=168.1h run1=252.1h finalPlanet=Io Frontier
```

### 3. Relaunch is already live and follows Io automatically

HPA-427 has merged. `MiningContentRegistry.finalPlanetId` uses `MiningPlanetId.values.last`, so adding `ioFrontier` last makes Relaunch unavailable until **Io** is mastered without adding controller or screen logic. The existing journey executes `_playRun` twice and checks that run 2 is faster (`<= 80%` of run 1 at 2-hour visits; strictly faster at 6-hour visits). Extend `_playRun` through Io **for both runs**; leave the relative check against final-planet completion in place. Assert Relaunch remains unavailable immediately after Ceres mastery, and the Io mastery reward fires once per run, not on recall/redeploy.

### 4. Stellar Map and next goal need no new code

The Stellar Map is a scrolling column with progressive disclosure: Io appears as a teaser reading `UNLOCK CERES FIRST` until Ceres is unlocked, then as a locked card with Ceres mastery, Surveying 5, and cash. The next-goal ladder walks Ceres mastery → `Unlock Io Frontier` → its sites → `Relaunch`.

### 5. Persistence follows the strict contract

The eight-key save root (`cash`, `lastAccruedAtUtc`, `technology`, `unlockedPlanetIds`, `activePlanetId`, `docks`, `sites`, `relaunchCount`) does not change. Initial state and validation enumerate `MiningPlanetId.values` and `MiningSiteId.values`, so new saves get five dock maps and fifteen sites. An existing twelve-site/four-planet save is intentionally invalid and clean-resets with `recoveredFromInvalidSave`; no migration or backward-compatibility reader. The `relaunchCount` field remains owned by the current save/relaunch logic.

## Touch points

- `lib/game/resources/resource_type.dart`: three enum values.
- `lib/mining/mining_content.dart`: **append** `MiningPlanetId.ioFrontier` and the three `MiningSiteId` values (append preserves the `siteId.index`-seeded resource layouts); add `_surveyingProgressionLevels` entries, three silhouettes, the Io definition, and Ceres `masteryRewardCash: 0`. Append the resources in `lib/game/resources/resource_type.dart`.
- `lib/mining/presentation/offline_return_sheet.dart`: add three resources to the exhaustive `_resourceIcon` arm returning `null`.
- `lib/mining/presentation/mining_visuals.dart`: add three **static Io site IDs** to the exhaustive `MiningVisuals.depositFramesFor` `null` arm (no new animation or behavior).
- `CLAUDE.md`: five planets, fifteen sites, the Io gate, and the single Io reward.

Everything else should work from existing content-driven seams. The two exhaustive switch edits are necessary compile-time coverage, not new behavior. Any **other** production behavior change needs a failing characterization test and justification; do not introduce another state owner or content engine.

## Testing

- **Content:** exact Io values; fifteen resources and sites with unique IDs; `requiredSite` ordering over five planets; HPA-401's capacity invariant; only Io has a mastery reward; every new asset path resolves.
- **State and repository:** Io docks empty and sites locked initially; a fifteen-site save round-trips; a twelve-site save clean-resets with the recovered flag; a locked Io with a docked rig or unlocked site is rejected.
- **Controller:** retain the existing Ceres test covering generic unlock guard order; assert Io's distinct starter state in the journey. Retarget the existing final-planet reward and Relaunch tests: Ceres commission grants nothing, Io mastery awards the final (tuned) unlock amount exactly once, and Relaunch is unavailable before Io mastery.
- **Simulation:** five unlocked planets accrue in one window; only the active planet sells.
- **Views:** Io teaser before Ceres is unlocked, locked card after; next-goal ladder through Io; Surveying copy `15 of 15`; an Io offline-return section.
- **Widgets:** Io Site Deck, Mine Site, and Stellar Map at 360×640 and 430×932 with no overflow and the new art resolving.
- **Journey:** replace the duplicated Mars/Ceres blocks with a **single small `_playFrontier(player, planetId)` helper** also used for Io, reading unlock/site/spawn costs and reward messages from content. It still uses only controller actions. Both full runs proceed through Io, with reload on Io, the 24-hour offline cap, Relaunch, and faster run 2. Measure `ceresPhase = ceresMastery − marsMastery` and `ioPhase = ioMastery − ceresMastery`; include the cash wait before Io unlock, and retain absolute Mars/Ceres and relative run-2 assertions.

## Risks

- **Pacing is verified.** The journey measured the candidate amounts inside the 1.2×–2× window at both cadences, so the shared factor is 1.0 and no rewrite pass was needed (see decision 2's measured outcome).
- **Stale exhaustive assertions and fixtures.** Task 1 only fixed journey-local expectations needed to measure and tune the economy; unit/widget assertions that assumed twelve sites or Ceres as final were handled in **Task 2** after Io values were finalized, including enum-derived `finalPlanetMasteredState()` and `docksFor()` fixtures and one generic Ceres unlock guard-order test rather than a duplicate for Io.
- **Relaunch baseline.** HPA-427 is on `main`; the journey executes both runs through Io, so the second-run acceptance stays verified.
