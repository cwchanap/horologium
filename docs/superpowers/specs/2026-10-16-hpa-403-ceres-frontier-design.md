# HPA-403 Ceres Frontier Content Pack Design

- Date: 2026-10-16
- Status: Draft for review
- Linear: [HPA-403](https://linear.app/cwchanap/issue/HPA-403/ship-a-fourth-planet-content-pack-after-mars) — Ship a fourth planet content pack after Mars
- Baseline: `main` at `0affef0`, which includes HPA-401 (time-away pacing, PR #37)
- Depends on: [HPA-439](https://linear.app/cwchanap/issue/HPA-439/mining-art-ceres-frontier-planet-cavern-and-node-art) — Ceres planet, cavern, and node art (art only, its own PR)
- Precedent: `docs/superpowers/specs/2026-08-22-hpa-641-mars-frontier-content-pack-design.md`

## Goal

> Master Mars Frontier → unlock Ceres Frontier → commission three new sites → mine Nickel Ore, Platinum, and Iridium → master Ceres and receive the game's one completion reward.

Mars added a third planet by widening the few seams that were Lunar-specific. Those seams are now generic: planet unlock metadata, `isPlanetMastered`, enum-derived initial state and save validation, the Stellar Map list, the next-goal ladder, and the controller's starter dock and starter site. Ceres is the test that they really are. The player learns new content, not a new control scheme or economy.

## Non-goals

This work does not add:

- a technology level above 5, a Surveying 6 gate, a new technology track, or a new currency;
- a generic content, requirement, or reward engine, or a per-planet simulation rule;
- a fifth planet slot, procedural sites, or randomized content;
- an animated Ceres site (Landing Basin and Frozen Basin stay the only animated sites);
- a save version, migration, or compatibility reader.

## Content

### Planet

| Field | Value |
| --- | --- |
| ID | `MiningPlanetId.ceresFrontier` |
| Name | `Ceres Frontier` |
| Unlock | Mars Frontier mastery + Surveying 5 + 30,000,000 cash |
| Rig spawn cost | 7,500,000 |
| Mastery reward | 30,000,000 (moved from Mars; see decision 1) |
| Starter dock / site | Two T1 rigs in bays 1–2; Nickel Shoals unlocked, as `unlockPlanet` does for every planet |
| `planetAsset` | `assets/images/mining/planets/ceres_frontier.png` |

Visual fantasy: a dark grey-blue dwarf planet in the asteroid belt, cratered, with bright white salt faculae and a lone ice volcano. Cool palette with white highlights, distinct from Homeworld's green, the Moon's neutral grey, and Mars' rust.

### Sites

Storage follows HPA-401's rule (`baseCapacity = baseRatePerSecond × 7200`). Every site requires Surveying 5, as on Mars, and each site's four progression resources use `[5, 5, 5, 5]`.

| Site | Resource | Facility | Requires | Unlock | Rate/s | Capacity | Sale/unit |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| Nickel Shoals | Nickel Ore | Nickel Dredge | — | 0 | 0.60 | 4,320 | 100 |
| Platinum Rift | Platinum | Platinum Cutter | Nickel Shoals | 18,000,000 | 0.45 | 3,240 | 180 |
| Iridium Spire | Iridium | Iridium Lance | Platinum Rift | 45,000,000 | 0.30 | 2,160 | 350 |

A T1 rig earns 60 / 81 / 105 cash per second at these sites, against 24 / 30 / 39 on Mars, so each Ceres site out-earns every Mars site, and slower deeper sites pay more per unit as on every other planet.

Discovery copy:

- Nickel Shoals: shallow nickel-iron shoals ring the crater floor.
- Platinum Rift: a fractured rift exposes platinum seams under the salt crust.
- Iridium Spire: the ice volcano's flank hides the belt's richest iridium.

### Resources

`ResourceType` gains `nickelOre`, `platinum`, and `iridium` (12 values). Silhouettes use built-in Material icons, as Lunar and Mars do:

| Resource | Icon | Color |
| --- | --- | --- |
| Nickel Ore | `Icons.hexagon` | `Colors.lightGreenAccent` |
| Platinum | `Icons.auto_awesome` | `Color(0xFFE5E4E2)` |
| Iridium | `Icons.flare` | `Colors.purpleAccent` |

### Art

Art is its own task and PR, [HPA-439](https://linear.app/cwchanap/issue/HPA-439/mining-art-ceres-frontier-planet-cavern-and-node-art), which holds the briefs and the owner's approval. It delivers seven 512×512 images that this ticket's content points at:

- `assets/images/mining/planets/ceres_frontier.png`
- `assets/images/mining/caverns/{nickel_ore,platinum,iridium}.png`, also used as card art (as Lunar and Mars do)
- `assets/images/mining/nodes/{nickel_ore,platinum,iridium}.png`

`pubspec.yaml` already lists the three folders. This ticket generates no art, and its implementation starts after HPA-439 merges, because the existing all-content-assets test loads every authored path.

## Design decisions

### 1. The completion reward moves from Mars to Ceres

HPA-641 made the Mars reward "a completion flourish, not funding for another tier". With a fourth planet, a Mars reward would fund the Ceres unlock. So Mars' `masteryRewardCash` becomes 0 and Ceres gets 30,000,000, about the size of its unlock, keeping HPA-641's proportion. The controller and next-goal ladder already handle any planet's reward generically, so the message becomes `Ceres mastered — +30.00M cash.` (HPA-401's compact formatter) with no code change.

The game still grants exactly one mastery reward.

### 2. Pacing extends HPA-401 by about as much again

Using HPA-401's greedy-player model with the content above:

| Scenario | Mars mastery (HPA-401 model) | Ceres unlock | Ceres mastery |
| --- | ---: | ---: | ---: |
| Four visits a day | 66 h (11 visits) | 84.5 h (14) | 128 h, about 5.3 days (21) |
| One visit every 8 hours | 88 h (11) | 112 h (14) | 168 h, about 7 days (21) |
| Active, sells every minute | 17.5 h | 22.8 h | 34.5 h |

Visit counts are return visits after the 15-minute opening session, as in HPA-401. They match HPA-401's 11 visits to Mars mastery.

These rows are model estimates. HPA-401's journey later measured Mars mastery at 78 h with six-hour visits and 28.1 h with two-hour visits, so the real Ceres times will run longer than the table. The implementation re-measures them on the journey clock (plan Task 3).

Ceres adds about two and a half days of four short visits, close to the Lunar-to-Mars span. Larger unlock prices stretch the Iridium Spire wait first: at a 60,000,000 unlock the same player needs 7.3 days, with a two-day gap before Iridium Spire, so 30,000,000 was kept. The highest single amount a player sees is the 45,000,000 Iridium Spire unlock, which HPA-401's compact formatter shows as `45.00M`.

### 3. Progressive Stellar Map disclosure is unchanged

The existing rule shows a planet once its prerequisite is unlocked. Ceres therefore appears as a locked card once Mars is unlocked, showing Mars mastery, Surveying 5, and cash, and a fresh player still sees only Homeworld and Lunar Frontier.

### 4. The duplicated planet asset switch goes away

`site_deck_screen.dart` keeps a private `_planetAsset(MiningPlanetId)` switch that repeats `MiningPlanetDefinition.planetAsset`. Rather than adding a fourth arm, the Site Deck reads `content.planet(id).planetAsset`. The Stellar Map navigation icon keeps its fixed Lunar art.

### 5. Persistence follows the strict contract

The save root does not change. `docks` and `sites` derive their expected keys from `MiningPlanetId.values` and `MiningSiteId.values`, so a current save gains `ceresFrontier` dock bays and three site entries. Every save without them is incompatible and clean-resets through the existing recovery path with the recovered-load flag; there is no migration. This matches HPA-641 and HPA-401's note that pre-release saves reset.

The existing locked-planet validation (no docked rigs and no unlocked, commissioned, rigged, or stocked site on a locked planet) covers Ceres without change.

## Touch points

The implementation should change only these places, plus tests:

- `lib/game/resources/resource_type.dart`: three enum values.
- `lib/mining/mining_content.dart`: `MiningPlanetId.ceresFrontier`; three `MiningSiteId` values; `_surveyingProgressionLevels` entries; three silhouettes; the Ceres planet definition; Mars `masteryRewardCash: 0`.
- `lib/mining/presentation/offline_return_sheet.dart`: the three new resources join the exhaustive `_resourceIcon` switch arm that returns `null`.
- `lib/mining/presentation/site_deck_screen.dart`: decision 4.
- `CLAUDE.md`: four planets, twelve sites, Ceres gate, and the single Ceres reward.

Everything else (controller, simulation, repository, Stellar Map, next-goal ladder, Technology copy, offline return) is expected to work from content. Any other change found necessary during implementation is a generic bug and gets its own test.

## Testing

- **Content:** exact Ceres values; twelve resources and sites with unique IDs; every site's `requiredSite` precedes it on its planet; capacity invariant from HPA-401; only Ceres has a mastery reward; every new asset path resolves.
- **State and repository:** initial state has Ceres docks empty and its sites locked; a current twelve-site save round-trips; a nine-site save without `ceresFrontier` clean-resets with the recovered flag; a locked Ceres with a docked rig or an unlocked site is rejected.
- **Controller:** `unlockPlanet(ceresFrontier)` fails before Mars mastery, below Surveying 5, and below 30,000,000 cash, and on success debits, activates, docks two T1 rigs, unlocks Nickel Shoals, and saves once; Mars mastery grants nothing; the final Ceres commission grants 30,000,000 once with the Ceres message.
- **Simulation:** four unlocked planets accrue in one window; inactive Ceres cargo is kept and only the active planet sells.
- **Views:** Stellar Map shows Ceres only after Mars is unlocked, with Mars as its prerequisite; next-goal ladder walks Mars mastery → Unlock Ceres Frontier → its sites → `All frontiers mastered`, and the last Ceres site shows `+30.00M`; Surveying copy counts twelve sites when all planets are unlocked; the offline-return sheet lists a Ceres section.
- **Widgets:** Ceres Site Deck, Mine Site, and Stellar Map at 360×640 and 430×932 with no overflow and the new art resolving.
- **Journey:** `merge_mining_journey_test.dart` continues past Mars mastery (now no reward) through Ceres unlock and mastery with the single 30,000,000 reward, then reloads on Ceres.

## Risks

- **Order with HPA-401.** All prices assume HPA-401's storage and pricing, which merged unchanged. HPA-401's UX check noted that Mars rigs never pay back before the next target, so Mars progress is funded by older planets; a 7,500,000 Ceres spawn behaves the same way, which the journey will show.
- **Art timing.** The seven images come from HPA-439, and this ticket's implementation waits for it. If the art slips, the planning PR simply stays in draft; no placeholder images are committed.
- **Stale exhaustive assertions.** Tests that list nine sites or nine resources break. Search for exact enum lists and counts, as HPA-641 did.
