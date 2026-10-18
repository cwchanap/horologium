# HPA-401 Time-Away Pacing Design

- Date: 2026-10-16
- Status: Implemented
- Linear: [HPA-401](https://linear.app/cwchanap/issue/HPA-401/mining-pacing-make-time-away-pay-with-hour-long-storage) — Make time away pay with hour-long storage
- Baseline: `main` at `8f0881f` after PR #35

## Problem

### Time away stops paying after minutes

A site's fill window is `baseCapacity / baseRate × (Σ rig capacity multipliers / Σ rig rate multipliers) × (Logistics / Extraction)`. The rig term only ranges from 1.0 (all T1) to 0.89 (all T5), so the window is set almost entirely by the authored base pair and technology. Across every site, rig tier, and technology level, it ranges from **1.1 to 12.4 minutes**. At T1 with no technology:

| Site | Window | Site | Window | Site | Window |
| --- | ---: | --- | ---: | --- | ---: |
| Landing Basin | 3.0 min | Frozen Basin | 2.5 min | Ochre Basin | 4.0 min |
| Carbon Ridge | 2.7 min | Titanium Highlands | 2.9 min | Silica Dunes | 4.8 min |
| Granite Crater | 3.3 min | Helium Mare | 3.6 min | Cobalt Chasm | 6.2 min |

The offline accrual cap is 8–24 hours by Logistics level, so it never binds. A player who returns after a night collects what one who stepped away for 12 minutes collects. Logistics' advertised "offline cap 10h…24h" changes nothing a player can see, and the offline-return sheet's "Mining ran 7h 59m" headline is false: mining stopped minutes in.

The windows were inherited from the MVP's "L1 mine fill time" and preserved through HPA-285 ("one T1 rig ≈ current L1 mine fill time"). Nobody chose them as an away-time design.

### The economy is faster than the last playtest measured

The HPA-285 playtest (2026-08-27) kept the authored numbers after a cautious human run took over two hours to reach Mars. It predates HPA-454, which made four rigs per site placeable from each site's first Surveying level. HPA-454 noted that this "can accelerate" progression and did not re-measure.

Rigs cost a flat 25 / 500 / 5,000 cash per planet and pay for themselves in seconds to minutes (a Landing Basin T1 earns 2 cash/s against a 25 spawn cost). A greedy-player model (see [Evidence](#evidence)) masters Mars in about **20 minutes** of active play under today's numbers.

### Longer storage alone would make the game shorter

If storage alone grew to hours, every return would collect hours of production against prices sized for 5-minute loads. In the model, a player who visits four times a day would master Mars on their second visit after the opening session.

## Goals

- A return pays for the time away, up to a storage window measured in hours.
- Logistics is the "stay away longer" track; Extraction is the "earn faster" track.
- Prices scale with storage, so that each return buys a few meaningful things and Mars mastery takes **about three days of four short visits a day**. This is the default pending the owner's answer to the pacing question in the project thread.
- The opening session (first ~15 minutes) still unlocks Carbon Ridge, Granite Crater, and Surveying 1–3.
- Players can see how long each site has until it is full.

## Non-goals

This work does not:

- change the save shape, add a field, or migrate saves;
- change `MiningSimulation`'s formulas, the accrual algorithm, or controller guard order;
- add a currency, multiplier boost, ad reward, timer, notification, or rising per-purchase price formula;
- change rig tier multipliers, Extraction / Logistics multipliers, the rig cap per site, Surveying gates, or sale values per unit;
- change Homeworld prices or starting cash;
- touch animation timing (Landing Basin stage art keeps following `cargo / capacity`).

## The pacing trade-off

For a player who returns less often than the storage window, each visit collects one window of production. So, roughly:

```text
visits to Mars mastery  ≈  hours of active play to Mars mastery  ÷  storage window in hours
```

With a 2-hour window, "about three days of four visits" (≈ 11 visits) implies roughly a day of continuous active play. This is the shape of an idle game: active play stays possible, but returning is the main loop. The ask-card option "a few hours of active play" cannot coexist with hour-long storage and three days of visits; a shorter target ("about a day") would need about a third of the price increase below.

## Design decisions

### 1. Storage holds two hours of base production on every site

Each site's `baseCapacity` becomes `baseRatePerSecond × 7200`, so every site's T1 / Extraction 0 / Logistics 0 window is exactly **2 hours**. Logistics' existing ×1.0–×2.0 capacity multipliers stretch it to 4 hours; Extraction's ×1.0–×2.0 rate multipliers shorten it. Both multiplier tables are unchanged.

| Site | Rate/s | Capacity (was) | Site | Rate/s | Capacity (was) | Site | Rate/s | Capacity (was) |
| --- | ---: | ---: | --- | ---: | ---: | --- | ---: | ---: |
| Landing Basin | 0.50 | 3,600 (90) | Frozen Basin | 1.00 | 7,200 (150) | Ochre Basin | 0.75 | 5,400 (180) |
| Carbon Ridge | 0.75 | 5,400 (120) | Titanium Highlands | 0.80 | 5,760 (140) | Silica Dunes | 0.55 | 3,960 (160) |
| Granite Crater | 0.60 | 4,320 (120) | Helium Mare | 0.55 | 3,960 (120) | Cobalt Chasm | 0.35 | 2,520 (130) |

A uniform window keeps the player-facing rule one sentence long ("storage holds about two hours") and is pinned by a content-invariant test.

### 2. The offline cap becomes one 24-hour safety net

`offlineCapsByLogistics` (8/10/12/16/20/24 h) becomes a single `offlineAccrualCap = Duration(hours: 24)`; `offlineCapFor(int)` is removed. The longest possible window is 4 hours, so the cap only guards against clock jumps, which is the roadmap's "excessive elapsed time is capped" requirement. The Logistics effect copy drops "offline cap Nh".

### 3. Prices scale per planet; Homeworld stays as the opening

| Price | Today | Proposed |
| --- | ---: | ---: |
| Homeworld rig spawn, Carbon Ridge, Granite Crater | 25, 250, 700 | unchanged |
| Technology levels 1–3 (each track) | 300, 700, 1,500 | unchanged |
| Technology levels 4–5 (each track) | 4,000, 9,000 | 300,000, 750,000 |
| Lunar Frontier unlock | 2,500 | 200,000 |
| Lunar rig spawn | 500 | 40,000 |
| Titanium Highlands, Helium Mare | 3,000, 8,000 | 250,000, 650,000 |
| Mars Frontier unlock | 20,000 | 16,000,000 |
| Mars rig spawn | 5,000 | 4,000,000 |
| Silica Dunes, Cobalt Chasm | 12,000, 30,000 | 10,000,000, 25,000,000 |
| Mars mastery reward | 25,000 | 20,000,000 |

Lunar prices are about ×80 and Mars about ×800, rounded. The Mars reward keeps its HPA-641 role: about the size of the Mars unlock it follows, a completion rebate rather than funding for another tier.

Flat prices were chosen over a rising per-rig price. In the model, rising rig prices only lengthened the post-Mars rig tail and did not change time to mastery, while they would need a controller cost rule and a new spawn-cost display. Flat per-planet prices stay content-only.

### 4. Big numbers get one compact format

Cash now reaches tens of millions. `formatMiningCash` becomes the only formatter for player-visible cash and prices:

- below 1,000,000: thousands separators, as today (`650,000`);
- from 1,000,000: two decimals with `M` (`16.00M`, `1.25M`);
- from 1,000,000,000: two decimals with `B`.

It replaces every raw `$cost`, `$cash`, and `'${…Cost}'` interpolation in the cash chip, Site Deck cards and Sell action, Technology sheet, Stellar Map, Fleet Dock spawn label, sale and mastery messages, and the next-goal strip. Semantics labels use the same text.

Resource amounts on the offline-return sheet reach about 13,000 units per planet, so they get a sibling `formatMiningUnits(double)`: one decimal below 1,000 (unchanged from today), whole units with separators from 1,000, and the same `M`/`B` rule from 1,000,000.

### 5. Time to full on Site Deck cards

`MiningSiteCardView` gains `Duration? timeToFull`: `(capacity − cargo) / rate` for an operational site with `rate > 0` and room left, else `null`. An operational card that is not full shows `FULL IN 1H 52M`: as a second status line on the landscape card, matching its two-line `FULL … / SELL TO RESUME` layout, and after the fill percentage on the portrait card (`50% · FULL IN 2M`), where `FULL · SELL TO RESUME` already sits. The card's semantics label adds `, full in 1h 52m`. Minutes round up, so the line never says `0M` before the site is full. One shared `formatMiningDuration(Duration)` (`1h 52m`, `14m`, `<1m`) replaces the offline-return sheet's private formatter.

### 6. Honest copy

- Offline-return headline: `Mining ran\n{elapsed}` becomes `Away\n{elapsed}`, where `{elapsed}` is the full time away (the summary's new `elapsedAway`), not the capped `elapsedUsed`. The existing `Storage full: {site}.` lines already say which sites stopped.
- The cap note becomes `Capped at 24h 00m.` with no Logistics level, since Logistics no longer changes the cap.
- Logistics effect: `Storage ×1.15 · fills in 2h 18m`, where the window is computed at the player's current Extraction level (`2h × Logistics multiplier ÷ Extraction multiplier`).

### 7. Persistence is unchanged

No save field changes. Existing saves load; their stored cargo is far below the new capacities, so clamping never triggers. Prices are read at action time, so a save's progress is simply valued under the new prices.

## Evidence

The numbers above come from a scratch model of a greedy player over the authored content, not from the game. It mirrors the controller's unlock order, Surveying gates, commissioning, flat spawn costs, merges (a T(k+1) rig costs 2^k T1 spawns), the four-rig site cap, capacity clamping, active-planet selling (the player travels and sells every planet each visit), and the Mars reward. It ignores dock-bay limits, grid placement, and tap time. Its player buys the next progression step when affordable and otherwise the investment with the best payback, when that payback is shorter than the wait for the next step.

| Scenario | Today | Storage only (2 h) | Proposed |
| --- | ---: | ---: | ---: |
| Active, sells every minute: Mars mastery | ~20 min | ~20 min | ~17.5 h |
| Four visits a day after a 15-minute opening: Mars mastery | ~6 h | ~1 visit later | ~2.75 days (11 visits) |
| One visit every 8 hours: Mars mastery | ~15 h | ~3 h | ~3.7 days |
| Purchases per return visit | ~10 | ~30 | ~7 |
| Logistics bought by visit-based players | no | partly | to level 5 |

Proposed phase timeline for four visits a day: the opening session reaches Surveying 3; the first visit the next morning unlocks Lunar Frontier, Titanium Highlands, and Surveying 4; Helium Mare follows that afternoon; Mars Frontier on day two; Silica Dunes the visit after; Cobalt Chasm and Mars mastery on day three.

The implementation re-measures this deterministically with the public-action journey on its injected clock, at a two-hour and a six-hour visit cadence, and asserts the elapsed time to Mars mastery. Tuning after measurement changes only the numbers in sections 1 and 3.

## Testing

- **Content invariants:** every site's `baseCapacity == baseRatePerSecond × 7200`; the price table above; `offlineAccrualCap == 24h`.
- **Simulation:** accrual stops at capacity after 2 h for a T1 site and after 4 h at Logistics 5; elapsed time above 24 h is capped and reported as capped; foreground and resume paths still agree.
- **Formatting:** `formatMiningCash` at 0, 999, 1,000, 999,999, 1,000,000, 1,250,000, 16,000,000, and 1,000,000,000; `formatMiningDuration` at 0, 30 s, 59 s, 61 s, 14 m, 1 h 52 m 01 s, and 24 h; `formatMiningUnits` at 0, 0.5, 90, 999.9, 1,000, 12,960.4, and 1,250,000.
- **Views:** `timeToFull` for idle, operational, full, and zero-rate sites; Logistics copy at Extraction 0 and 5.
- **Widgets:** Site Deck card shows `FULL IN …` and no overflow at 360×640 / text scale 1.3 with a `16.00M` cash chip and Mars-sized prices; offline-return headline `Away`; the cap note; Technology, Stellar Map, Fleet Dock, and Sell labels show compact amounts.
- **Journey:** `merge_mining_journey_test.dart` keeps its public-action route and next-goal checkpoints, waits in storage windows rather than 5-minute steps, buys the extra rigs the route needs, and still reaches Mars mastery and the single 20,000,000 reward. It runs at two-hour and six-hour steps and asserts Mars mastery within 24–60 hours and 2–4 days of clock time respectively; that is the pacing evidence and merge gate.
- **UX check:** one sitting on an emulator or simulator, moving the device clock forward between sessions (no debug clock is added), checking copy, overflow, and feel; recorded under `docs/playtests/`. It is not a pacing measurement and never waits on wall-clock days.

## Risks

- **The model is wrong about humans.** It plays greedily and taps instantly. Mitigation: the journey's two cadence bands are the acceptance evidence, the UX check catches copy and feel problems, and every number lives in `MiningContentRegistry`, so retuning after real play is a numbers-only change.
- **Large numbers overflow chrome.** Mitigation: one compact formatter everywhere and overflow tests at 360×640 / 1.3 with Mars-sized values.
- **Fewer FULL moments in active play.** HPA-286's FULL labels and cargo-full cue now mostly appear on return. The next-goal strip's "Sell cargo to afford it" hint carries active-play selling.
- **Order with HPA-403.** The fourth planet authors its numbers on this pacing and is blocked by this ticket.

## Assets

No image generation or SFX work.
