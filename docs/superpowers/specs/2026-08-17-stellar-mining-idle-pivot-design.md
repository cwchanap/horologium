# Horologium Stellar Mining Idle Pivot Design

## Status

Approved product direction for the next Horologium roadmap.

This design supersedes `docs/features_prd.md` and
`docs/superpowers/specs/2026-05-03-production-chain-expansion-design.md`
wherever those documents conflict with the mining-idle direction. The older
files remain useful as historical context, but they must not generate new work
unless that work is explicitly re-approved.

The next implementation plan covers **Phase 1 only**: one planet, three
sectors, fixed deposits, mining, upgrading, selling, and offline progress.
Later phases require their own review after the vertical slice is evaluated.

## Purpose

Change Horologium from a space city builder with mining into a casual mobile
idle mining game built around exploration and visual rewards.

The new player fantasy is:

> Explore alien worlds, reveal valuable deposits, build automated mining
> facilities, sell their cargo, and reinvest the profit to reach richer areas.

The pivot intentionally removes operational city-management complexity. The
player should make a few satisfying choices, see strong visual feedback, and
leave knowing that production continues automatically.

## Approved Decisions

The design locks in these decisions:

- keep Horologium in the existing Flutter and Flame application;
- build a clean mining domain rather than extending the existing worker-based
  `Building` production model;
- make the mining experience portrait-first;
- use fixed, authored deposit slots instead of free-form building placement;
- make raw-resource discovery, extraction, upgrading, and selling the primary
  loop;
- remove houses, population, worker assignment, accommodation, happiness,
  demand, food, water, services, and mandatory production chains from the new
  product path;
- keep trading only as simple cargo selling at first;
- keep technology as a small permanent-progression system introduced after the
  core loop is proven;
- defer secondary-resource processing until the raw mining loop has been
  evaluated;
- use a clean, versioned mining save format and do not attempt full legacy city
  save conversion.

## Product Principles

Every new feature must satisfy at least one of these purposes:

1. reveal a new place or resource;
2. improve automated mining;
3. create a rewarding sale or upgrade moment;
4. advance the player toward another sector or planet.

The following constraints are product rules, not temporary implementation
shortcuts:

- no worker assignment;
- no housing, population, happiness, food, water, or demand simulation;
- no power-grid, road, conveyor-routing, maintenance, or breakdown chores;
- no mandatory multistep production chain;
- no more than three primary values visible at once;
- no multiple menus for routine collection, selling, or upgrading;
- no resource depletion in the core idle mode;
- no energy, stamina, or consumable scanner resource in the first release;
- no arbitrary resource buying that bypasses discovery and mining;
- no server dependency for the single-player core loop.

Visual clarity and reward feedback take priority over simulation depth.

## Core Player Loop

The primary loop is:

```text
Accrue cargo -> Sell cargo -> Reveal a sector -> Discover a deposit
-> Build or upgrade a mine -> Accrue more valuable cargo
```

A short returning session should take roughly 30 to 90 seconds:

1. open the game and see an offline-production summary;
2. sell accumulated cargo with one action;
3. purchase one meaningful upgrade or sector reveal;
4. see visible progress toward the next discovery;
5. leave while mines continue operating.

A longer active session should take roughly 5 to 10 minutes and focus on
revealing a sector, watching its scanner animation, inspecting the new deposit,
building its facility, and upgrading several mines.

The first session must allow the player to build a mine in under one minute and
complete a first cargo sale during that session.

## World Structure

### Planets

A planet is a content-authored mining map containing sectors. It owns visual
content and per-planet progress, but it does not own a separate cash wallet or
technology tree.

Global player state contains:

- cash;
- technology levels when technology is introduced;
- unlocked planet IDs;
- discovery collection progress;
- the last application activity timestamp.

Per-planet state contains:

- unlocked sector IDs;
- mine state keyed by deposit ID;
- planet milestone progress.

### Sectors

A planet contains approximately 6 to 12 sectors in the mature product. A sector
has:

- an authored position and visual region;
- an unlock cost or progression requirement;
- one to three fixed deposit definitions;
- a locked, scanning, revealed, or mastered state;
- an optional milestone reward.

The player reveals an adjacent eligible sector by paying its cost. The reveal
is immediate and produces a scanner sweep, environmental animation, deposit
reveal, and reward feedback. There is no reveal timer or scanner energy.

Terrain may remain procedurally decorated, but sector composition and deposit
anchors are authored. This gives artists control over composition, makes the
map readable on a phone, and keeps saves and tests deterministic.

### Deposits

A deposit definition is immutable content. It includes:

- stable ID;
- sector ID;
- resource type;
- authored world anchor;
- richness or rarity presentation;
- base production rate;
- base storage capacity;
- build cost;
- upgrade-cost curve;
- resource sale value;
- facility art identity.

A deposit supports exactly one mining facility. The player taps the deposit,
not an arbitrary empty grid cell. Deposits do not deplete in the initial
product.

### Mines

Building a mine creates level 1. The initial mine model has five levels.
Upgrading performs one simple action that improves both production rate and
local storage capacity.

The player does not separately upgrade speed, capacity, workers, power,
efficiency, or maintenance. The exact numeric curves live in content data so
they can be tuned without changing simulation code. The binding balance
requirements are the session and progression criteria in this document.

Mine visuals use resource-specific facility identities while sharing one domain
model. Facility art changes at levels 1, 3, and 5 so upgrades feel visible
without requiring unique art for every numeric level.

## Phase 1 Content

The first playable vertical slice contains one planet and three authored
sectors:

| Sector | Initial State | Deposit | Purpose |
| --- | --- | --- | --- |
| Landing Basin | Unlocked | Gold | Tutorial build, first production, first sale |
| Carbon Ridge | Locked | Coal | First paid sector reveal |
| Granite Crater | Locked | Stone | Proves a third resource and longer progression |

Phase 1 contains:

- gold, coal, and stone only;
- one deposit per sector;
- five mine levels;
- fixed sale values;
- fixed sector-unlock costs;
- no resource buying;
- no technology screen;
- no processing or refinement;
- no contracts, daily market modifiers, or timed events;
- an eight-hour maximum offline accrual window;
- local storage capacity on each mine.

The initial content is intentionally small. Art quality, readability, reward
feedback, and pacing matter more than the number of resources or maps.

## Economy and Selling

Cash is the only spendable currency in Phase 1.

Each mine stores its own raw-resource cargo. Production stops when that mine's
storage is full. The planet HUD shows total stored cargo value and provides one
primary **Sell All Cargo** action.

Selling:

1. totals the stored amount in every mine on the active planet;
2. converts each amount using its resource's configured sale value;
3. adds the result to global cash;
4. clears the sold cargo atomically;
5. plays the strongest routine reward animation in the game.

The sell animation should include a cargo shuttle or collection effect,
resource movement toward the terminal, and cash feedback toward the wallet.

There is no buy side of the market. Later, trading may gain one lightweight
modifier such as a daily high-demand resource with a percentage sale bonus.
There will be no order book, price chart, shipping-route simulation, or manual
interplanetary logistics in the initial roadmap.

## Technology Direction

Technology is deferred until the mining loop and first product cutover are
validated. When introduced, it uses three short linear tracks:

| Track | Permanent Effect |
| --- | --- |
| Extraction | Global mining-rate improvement |
| Logistics | Storage-capacity and offline-duration improvement |
| Surveying | Sector and planet discovery progression |

Each track has five clear levels. Technology points come from discovery and
milestones rather than from a required Research Lab building or a per-second
research resource.

The system must remain linear and legible. It must not recreate the old
building-unlock dependency tree.

## Portrait-First UX

Portrait is the canonical mining layout and the only layout that Phase 1 must
be specifically composed and acceptance-tested for. A rotating device may use
safe responsive constraints, but Phase 1 will not build a second bespoke
landscape interface.

### Screen Layout

The mining screen has three layers:

1. **Top status bar**
   - global cash;
   - active planet or sector progress;
   - one contextual status such as cargo fullness.
2. **World canvas**
   - illustrated mining environment;
   - sector boundaries and fog or scanner treatment;
   - fixed deposits and animated facilities;
   - camera pan and constrained zoom where needed.
3. **Bottom contextual sheet**
   - no selection: cargo value, Sell All Cargo, and next objective;
   - locked sector: unlock requirement and Reveal action;
   - empty deposit: resource identity, richness, and Build action;
   - built deposit: level, production rate, storage progress, and Upgrade action.

Routine actions stay on this screen. Technology and the Stellar Map may become
separate long-term-progression destinations in later phases.

When a deposit is selected, the camera keeps it visible above the bottom sheet.
Primary actions use at least 48 logical-pixel touch targets and do not depend on
long-press or hover behavior.

### Reward Moments

The art and animation benchmark must cover four moments:

- sector scanner reveal;
- mine construction;
- mine visual-tier upgrade;
- cargo sale and cash collection.

Mines should visibly operate through drills, excavators, dust, ore particles,
lights, carts, or cargo drones. Effects must remain readable rather than filling
the screen with constant particles.

Reduced-motion settings should replace large camera and particle sequences with
short fades and number transitions while preserving action confirmation.

## Technical Architecture

### Boundary Strategy

The mining product is a new vertical slice inside the existing app. It reuses
Flutter, Flame, terrain, camera, asset loading, audio, and platform setup, but it
does not route mining production through the old `Building`, worker,
population, happiness, or production-graph logic.

The intended dependency direction is:

```text
Flutter mining UI
    -> MiningController
        -> MiningSimulation
        -> MiningSaveRepository
        -> MiningContentRegistry

Flame mining world
    <- read-only view state and callbacks from MiningController
```

Flutter owns HUDs, sheets, buttons, return summaries, technology, and planet
navigation. Flame owns terrain, deposits, facility sprites, reveal effects,
camera behavior, and world animation.

### Domain Components

The mining slice should introduce focused components with no dependency on
Flutter widgets or Flame components:

- `MiningContentRegistry`
  - immutable planet, sector, resource, and deposit definitions;
- `MiningSimulation`
  - pure elapsed-time production calculations;
- `MiningController`
  - validates and applies reveal, build, upgrade, sell, and resume actions;
- `MiningSaveRepository`
  - serializes and restores the complete versioned mining save;
- mining state value objects
  - global player state, planet progress, mine state, and action results.

Representative state shape:

```dart
class MiningSaveV2 {
  final int schemaVersion;
  final PlayerProfile player;
  final Map<String, PlanetProgress> planets;
}

class PlayerProfile {
  final double cash;
  final Map<TechnologyTrack, int> technologyLevels;
  final Set<String> unlockedPlanetIds;
  final DateTime lastSeenAtUtc;
}

class PlanetProgress {
  final String planetId;
  final Set<String> unlockedSectorIds;
  final Map<String, MineState> minesByDepositId;
}

class MineState {
  final String depositId;
  final int level;
  final double storedAmount;
  final DateTime lastAccruedAtUtc;
}
```

The exact file layout belongs in the implementation plan. These boundaries are
binding: immutable content is separate from mutable progress, simulation is
pure, and UI components do not calculate economic results.

### Deterministic Production

The economic source of truth is elapsed time, not a chain of one-second tick
mutations.

For each mine:

```text
elapsed = clamp(nowUtc - lastAccruedAtUtc, 0, offlineDurationCap)
produced = elapsedSeconds
  * depositBaseRate
  * mineLevelRateMultiplier
  * extractionTechnologyMultiplier
stored = min(existingStored + produced, mineStorageCapacity)
```

Phase 1 uses an eight-hour offline-duration cap and a technology multiplier of
1.0. After calculation, `lastAccruedAtUtc` advances to the current timestamp so
excess time beyond the cap is discarded rather than repeatedly claimable.

The same calculation runs for foreground refresh, application resume, and cold
launch. A periodic UI timer may update progress bars and animation, but it must
not be the authority for production.

Clock rollback yields zero production. Invalid or extremely large elapsed time
is clamped. Storage capacity is always enforced.

### Action Atomicity

Reveal, build, upgrade, and sell operations validate first and then produce one
new immutable state result. A failed action changes nothing.

Required invariants include:

- cash never becomes negative;
- a locked or unknown deposit cannot be built;
- a deposit has at most one mine;
- mine level stays within the supported range;
- stored cargo stays between zero and capacity;
- a sale cannot add cash without clearing the corresponding cargo;
- an upgrade cannot deduct cash without increasing exactly one mine level.

## Versioned V2 Persistence

The mining product uses one complete JSON save document in SharedPreferences:

```text
horologium.mining.save.v2
```

A single document is preferred over separate player and planet keys because a
sale updates global cash and planet cargo together. Writing one serialized
state avoids cross-key partial commits.

The document contains:

- `schemaVersion: 2`;
- global player state;
- all unlocked planet progress;
- UTC timestamps encoded in ISO 8601 form.

The repository keeps the previous successful payload at:

```text
horologium.mining.save.v2.backup
```

Before replacing the primary payload, the repository copies the current valid
primary payload to the backup key. On load:

1. decode and validate the primary document;
2. if invalid, attempt the backup document;
3. if both fail, preserve the invalid primary payload under a timestamped
   recovery key, initialize a clean mining save, and show a non-blocking
   recovery message.

Passive foreground production does not write every second. Save after explicit
mutations, application pause, and controlled debounced checkpoints.

### Legacy Save Policy

The mining save does not read or convert city-building keys.

Legacy resources, buildings, workers, research, quests, achievements, and
planet data remain untouched during development so the old mode can be used for
rollback while the vertical slice is isolated. Once mining becomes the default,
the old data remains ignored. Deleting legacy keys is a later cleanup task and
is not part of Phase 1.

There is no founder grant or best-effort conversion in this design. Starting
mining progress is determined solely by the new-player balance configuration.

## Transition Strategy

The pivot uses a temporary parallel path, not a permanent mode split.

1. Build the mining vertical slice behind a development entry point.
2. Keep the existing city path unchanged while the slice is incomplete.
3. Validate the complete mining loop and art benchmark.
4. Make mining the default product path.
5. Hide old city pages and controls.
6. Remove obsolete city systems and tests in focused cleanup changes.

The old `Building` model may remain in the repository during the vertical
slice, but mining code must not add more conditionals to it or depend on its
worker and generation maps.

## Roadmap

### Phase 0: Product Reset

This design is the Phase 0 output. It freezes the new product principles,
supersession policy, vertical-slice boundary, and save strategy.

### Phase 1: One-Planet Vertical Slice

Deliver:

- portrait-first mining screen;
- Landing Basin, Carbon Ridge, and Granite Crater;
- fixed gold, coal, and stone deposits;
- sector reveal;
- build and five-level upgrade actions;
- deterministic production and mine storage;
- Sell All Cargo;
- eight-hour offline progress;
- return summary;
- one benchmark-quality sector and complete reward-animation set;
- versioned v2 persistence;
- tests for core invariants and the end-to-end loop.

No old gameplay system is deleted in this phase.

### Phase 2: Product Cutover

Deliver:

- mining as the default Start action;
- replacement HUD and navigation;
- removal or hiding of houses, workers, population, happiness, food, water,
  services, trade buying, production graphs, and old routine menus;
- retargeting or temporary removal of old quests and achievements;
- focused deletion of obsolete code and tests after the cutover is stable;
- complete visual pass for the first planet.

### Phase 3: Permanent Progression and Second Planet

Deliver:

- Extraction, Logistics, and Surveying technology tracks;
- technology points from discovery and milestones;
- Stellar Map;
- second planet with two or three new raw resources;
- global cash and technology across planets;
- offline summary covering every active planet.

### Phase 4: Lightweight Retention

Candidate additions, introduced selectively:

- one daily high-demand resource;
- simple sell contracts;
- resource discovery collection;
- mining and planet milestones;
- cosmetic facility skins;
- special visually rich deposits.

These systems must reward returning without adding operational chores.

### Phase 5: Content Expansion

Add planets, sector biomes, facility art, rare resources, discovery entries, and
balance changes. Content expansion starts only after the first two planets show
that the loop scales without additional simulation systems.

### Phase 6: Optional Processing Experiment

Secondary processing is not part of the committed roadmap until the raw mining
loop demonstrates a need for another sink or decision layer.

The smallest acceptable experiment is:

- one refinery;
- one input and one output;
- automatic operation;
- a predictable sale-value premium;
- no worker, power, routing, recipe selection, or chain graph.

A successful experiment may justify later expansion. It must not restore the
previous multistep economy by default.

## Testing Strategy

### Domain Unit Tests

Cover:

- online and offline accrual equivalence;
- zero production for clock rollback;
- eight-hour cap enforcement;
- storage-capacity clamping;
- level multiplier application;
- reveal eligibility and cost deduction;
- build validation;
- upgrade validation and atomic deduction;
- sell valuation and atomic cargo clearing;
- unknown planet, sector, and deposit rejection.

### Persistence Tests

Cover:

- v2 JSON round-trip;
- timestamp round-trip in UTC;
- primary-to-backup recovery;
- corrupt-primary recovery;
- clean initialization when both documents fail;
- old city keys are ignored;
- saves do not occur on every display tick.

### Widget and Integration Tests

Cover:

- select the tutorial gold deposit and build the first mine;
- accrue and sell first cargo;
- reveal Carbon Ridge;
- upgrade a mine;
- resume and claim offline progress;
- bottom sheet keeps the selected deposit visible;
- routine actions require no old city-management page.

### Visual and Performance Checks

Verify:

- canonical portrait layouts at representative narrow and tall phone sizes;
- safe-area handling;
- readable resource and action states;
- visible level 1, 3, and 5 facility differences;
- reduced-motion behavior;
- smooth rendering with the intended maximum visible facilities and effects;
- assets are preloaded before scanner and upgrade animations begin.

## Phase 1 Success Criteria

Phase 1 is ready for product cutover consideration when all of these are true:

- a new player can build the first mine in under one minute;
- the first cargo sale occurs during the opening session;
- a player can reveal a new sector, build its mine, upgrade it, leave, return,
  and receive offline cargo without entering an old city-management page;
- the loop is understandable without worker, housing, demand, power, food, or
  production-chain explanations;
- online and offline production return the same economic result for the same
  elapsed time;
- a failed build, upgrade, reveal, or sale never partially mutates state;
- fixed deposit anchors produce a visually composed map and eliminate invalid
  placement states from the player experience;
- the gold-sector art and all four reward moments meet the visual benchmark;
- the v2 save recovers from a corrupt primary payload using its backup;
- Flutter analysis, formatting, tests, and existing CI checks remain green.

## Risks and Mitigations

### Old-domain leakage

Risk: mining becomes another set of conditionals inside the city `Building` and
resource systems.

Mitigation: enforce the new domain boundary and review dependencies before any
UI work is merged.

### Weak visual differentiation

Risk: the loop is mechanically simple but feels like a reskinned spreadsheet.

Mitigation: treat one benchmark-quality sector and the four reward moments as
Phase 1 acceptance requirements, not post-launch polish.

### Overexpansion before validation

Risk: planets, technology, contracts, and processing are built before the core
loop is proven.

Mitigation: the next implementation plan is Phase 1 only. Later phases require
fresh approval.

### Save reset surprise

Risk: existing players expect city progress to convert.

Mitigation: document the clean v2 policy in release notes when cutover occurs.
Legacy data remains untouched during the transition, but it is not converted.

### Idle-clock manipulation

Risk: device-time changes create invalid rewards.

Mitigation: clamp negative elapsed time to zero, cap elapsed time at eight
hours, and keep all calculations deterministic and testable.

## Explicitly Deferred Decisions

These are out of scope rather than unresolved requirements:

- monetization and advertisements;
- accounts, cloud saves, and cross-device sync;
- leaderboards, PvP, and social systems;
- procedural deposit placement;
- resource depletion;
- finite expeditions or events;
- secondary processing beyond the Phase 6 experiment;
- interplanetary shipping logistics;
- desktop-first or separate landscape composition;
- migration of legacy city progress.

Any of these requires a separate product decision after the Phase 1 loop is
reviewed.
