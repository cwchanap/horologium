# HPA-262 Io Frontier Content Pack Design

- Date: 2026-10-22
- Status: Proposed
- Linear: [HPA-262](https://linear.app/cwchanap/issue/HPA-262/mining-content-ship-io-frontier-as-the-fifth-planet-after-ceres) — Ship Io Frontier as the fifth planet after Ceres
- Baseline: `main` at `15fd4c0`, after HPA-403 (Ceres Frontier)
- Depends on: [HPA-87](https://linear.app/cwchanap/issue/HPA-87/mining-art-io-frontier-planet-cavern-and-node-art) — Io planet, cavern, and node art (art only, its own PR)
- Related: [HPA-427](https://linear.app/cwchanap/issue/HPA-427/mining-endgame-relaunch-after-the-final-frontier-for-a-permanent-cash) — Relaunch, whose gate follows the last authored planet
- Precedent: `docs/superpowers/specs/2026-10-16-hpa-403-ceres-frontier-design.md`

## Goal

> Master Ceres Frontier → unlock Io Frontier → commission three new sites → mine Sulfur, Cinnabar, and Osmium → master Io and receive the game's one completion reward.

HPA-403 proved the planet seams are generic: Ceres needed content, three enum values, and one exhaustive switch arm. Io is the same shape again. The player gets one more discovery before the end of a run; the controller, simulation, repository, and views stay as they are.

## Non-goals

This work does not add:

- a technology level above 5, a new technology track, or a new currency;
- a generic content, requirement, or reward engine, or a per-planet rule;
- an animated Io site;
- a sixth planet slot or procedural content;
- a save version, migration, or compatibility reader.

## Content

All numbers below are proposals. The public-action journey measures them during implementation (Task 3 of the plan), and they are scaled together if the Io phase falls outside its band.

### Planet

| Field | Value |
| --- | --- |
| ID | `MiningPlanetId.ioFrontier` |
| Name | `Io Frontier` |
| Unlock | Ceres Frontier mastery + Surveying 5 + 90,000,000 cash |
| Rig spawn cost | 22,500,000 |
| Mastery reward | 90,000,000 (moved from Ceres; see decision 1) |
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

These are Ceres' rates with three times its sale values and prices, the same step Ceres took over Mars. A T1 rig earns 180 / 248 / 315 cash per second, against 60 / 81 / 105 on Ceres, so each Io site out-earns every Ceres site, and deeper sites pay more per unit as on every planet.

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

Art is its own ticket and PR, HPA-87, which holds the briefs and the owner's approval: one 640×640 planet, three 800×1200 caverns (also used as card art), and three 512×512 nodes at the paths in that ticket. `pubspec.yaml` already lists the three folders. This ticket generates no art, and its implementation waits for HPA-87 because the all-content-assets test loads every authored path.

## Design decisions

### 1. The completion reward moves from Ceres to Io

HPA-403 moved the reward from Mars to Ceres so it never funds the next unlock. The same rule moves it again: Ceres `masteryRewardCash` becomes 0, Io gets 90,000,000, about the size of its unlock. The game still grants exactly one mastery reward per run, and the controller and next-goal ladder already handle it generically (`Io mastered — +90.00M cash.`).

### 2. Pacing: the Io phase is one to two Ceres phases

HPA-403's journey measured the Ceres phase (Ceres unlock to mastery) at 22 h with two-hour visits and 66 h with six-hour visits. The Io phase should land between 1.2× and 2× of that: long enough to feel like a new planet, short enough not to stall. The plan measures it on the journey's injected clock and, if it falls outside, scales the Io unlock, site unlocks, spawn cost, and reward by one common factor. Sale values and rates stay, so the per-site earning order stays.

Expected journey bands, to be confirmed by measurement:

| Visits | Ceres mastery (today) | Io mastery band |
| --- | ---: | --- |
| Every 2 hours | 50 h | 70–150 h |
| Every 6 hours | 6 days | 7–14 days |

### 3. Relaunch follows automatically

HPA-427 gates Relaunch on `MiningPlanetId.values.last`. If it has merged, adding `ioFrontier` after `ceresFrontier` moves the gate to Io with no code change; its journey run comparison then runs through Io. If it has not merged, nothing here changes for it.

### 4. Stellar Map and next goal need no new code

The Stellar Map is a scrolling column with progressive disclosure: Io appears as a teaser reading `UNLOCK CERES FIRST` until Ceres is unlocked, then as a locked card with Ceres mastery, Surveying 5, and cash. The next-goal ladder walks Ceres mastery → `Unlock Io Frontier` → its sites → the end of the run.

### 5. Persistence follows the strict contract

The save root does not change. `docks` and `sites` derive their keys from the enums, so a current save gains `ioFrontier` dock bays and three site entries. Older saves are incompatible and clean-reset through the existing recovery path with the recovered-load flag; there is no migration.

## Touch points

- `lib/game/resources/resource_type.dart`: three enum values.
- `lib/mining/mining_content.dart`: `MiningPlanetId.ioFrontier`; three `MiningSiteId` values; `_surveyingProgressionLevels` entries; three silhouettes; the Io definition; Ceres `masteryRewardCash: 0`.
- `lib/mining/presentation/offline_return_sheet.dart`: the three resources join the exhaustive `_resourceIcon` arm that returns `null`.
- `CLAUDE.md`: five planets, fifteen sites, the Io gate, and the single Io reward.

Everything else is expected to work from content. Any other change found necessary is a generic bug and gets its own test.

## Testing

- **Content:** exact Io values; fifteen resources and sites with unique IDs; `requiredSite` ordering over five planets; HPA-401's capacity invariant; only Io has a mastery reward; every new asset path resolves.
- **State and repository:** Io docks empty and sites locked initially; a fifteen-site save round-trips; a twelve-site save clean-resets with the recovered flag; a locked Io with a docked rig or unlocked site is rejected.
- **Controller:** `unlockPlanet(ioFrontier)` guard order (Ceres mastery, Surveying 5, 90,000,000 cash) and success effects; the final Ceres commission grants nothing; the final Io commission grants 90,000,000 once.
- **Simulation:** five unlocked planets accrue in one window; only the active planet sells.
- **Views:** Io teaser before Ceres is unlocked, locked card after; next-goal ladder through Io; Surveying copy `15 of 15`; an Io offline-return section.
- **Widgets:** Io Site Deck, Mine Site, and Stellar Map at 360×640 and 430×932 with no overflow and the new art resolving.
- **Journey:** continues past Ceres mastery (no reward) through Io unlock and mastery with the single reward, then reloads on Io, with the measured Io bands.

## Risks

- **Pacing is a proposal.** The numbers are a scaled copy of Ceres, not a model run. The journey measures them before the PR leaves draft, and decision 2 says how to correct them.
- **Art timing.** Implementation waits for HPA-87; the planning PR simply stays in draft.
- **Stale exhaustive assertions.** Tests that list twelve sites or resources break; search for them as HPA-403 did.
- **Order with HPA-427.** Either order works. Whichever merges second rebases and re-runs the journey.
