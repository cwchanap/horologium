# HPA-631 One-Planet Mining MVP Design

## Status

Implementation design for Linear HPA-631, **Build and validate the one-planet mining MVP**.

This design is scoped to one implementation PR for HPA-631. It intentionally does not split domain, persistence, sectors, presentation, or testing into separate tickets or PRs.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the authoritative Horologium mining roadmap.
2. Linear HPA-631, the acceptance contract for this MVP.
3. `docs/superpowers/specs/2026-08-17-stellar-mining-idle-pivot-design.md` on commit `40ef643bc99e6686ee99c797e289232b4e45e407` as supporting product rationale.
4. Existing city-simulation documentation only as implementation context.

Two consequences matter for this slice:

- HPA-631 uses a clean mining save with safe reset recovery, but **does not** add rotating backups, forensic recovery keys, or legacy-save conversion.
- HPA-631 stays one-planet and does **not** pre-build technology, multi-planet, generic recipe, or live-operations abstractions.

## Goal

Ship the first complete mining-idle product loop inside the existing Flutter/Flame app without coupling it to the legacy city simulation:

> Identify Landing Basin's gold deposit → build a mine → accrue cargo → sell → upgrade → reveal Carbon Ridge → build coal → reveal Granite Crater → build stone → leave → return to deterministic offline production.

The slice exists to answer a product question, not to create a platform: is simple mining, discovery, selling, upgrading, and strong visual reward feedback compelling enough to become Horologium's default direction?

## Current repository baseline

`main` is still the May 2026 city-building runtime:

- `lib/main_menu.dart` loads a legacy `Planet` and sends **START EXPEDITION** to `MainGameWidget`.
- `lib/game/main_game.dart` is a Flame world centered on the 50×50 city grid and `Building` placement.
- `lib/game/scene_widget.dart` coordinates worker/resource/research/quest state around that city runtime.
- `lib/game/services/save_service.dart` persists the legacy model across many SharedPreferences keys.
- `ParallaxTerrainComponent`, existing terrain art, camera input patterns, `AudioManager`, resource icons, and the `gold_mine.png` / `coal_mine.png` / `quarry.png` building art are already useful presentation assets.

HPA-631 must therefore add a parallel mining vertical slice and a temporary menu entry. HPA-636, not this issue, owns replacing the default Start flow and deleting legacy city code.

## Design choice

### Selected: isolated mining vertical slice inside the existing app

Add a focused `lib/mining/` feature with four responsibilities:

```text
Flutter MiningScreen
    -> MiningController
        -> MiningSimulation
        -> MiningSaveRepository
        -> MiningContentRegistry

Flame MiningGame
    <- read-only MiningSaveV2 + callbacks from MiningScreen
```

The feature reuses existing Flutter, Flame, terrain assets, camera interaction patterns, audio preferences, resource icons, and mining building sprites. It does not inherit the legacy economy model.

This is the smallest boundary that keeps the pivot maintainable: future mining work changes mining code instead of adding mode checks to city classes.

### Rejected: retrofit `MainGame`, `Planet`, `Resources`, `Building`, and `SaveService`

This would save a few files initially but would make every mining rule coexist with workers, happiness, research gates, free-form placement, city resource maps, and legacy persistence. It directly violates the HPA-630 product boundary and makes HPA-636 cleanup harder.

### Rejected: new package/app or generic planet engine

A separate package, router framework, generalized planet platform, event bus, or content DSL is unnecessary for one planet and three deposits. Existing Flutter/Flame application infrastructure is sufficient.

## Feature layout

Use one cohesive feature directory:

```text
lib/mining/
  domain/
    mining_content.dart
    mining_state.dart
    mining_simulation.dart
    mining_controller.dart
  persistence/
    mining_save_repository.dart
  presentation/
    mining_screen.dart
    mining_status_bar.dart
    mining_action_sheet.dart
    offline_return_sheet.dart
  world/
    mining_game.dart
    mining_components.dart
```

Keep small related world components together in `mining_components.dart` for the MVP. Split them later only if the file becomes difficult to understand.

Do not add Provider, Riverpod, Bloc, a service locator, code generation, or a repository/interface hierarchy. `MiningScreen` owns one `MiningController`; tests may inject a repository and clock directly.

## Immutable content

`MiningContentRegistry` is the single source of truth for authored Phase 1 content. Content objects are immutable and contain no player progress.

Representative types:

```dart
enum MiningResourceType { gold, coal, stone }

class MiningWorldAnchor {
  final double x;
  final double y;
}

class MiningDepositDefinition {
  final String id;
  final MiningResourceType resource;
  final int buildCost;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<int> upgradeCosts;
  final MiningWorldAnchor anchor;
}

class MiningSectorDefinition {
  final String id;
  final String name;
  final int revealCost;
  final String? requiredSectorId;
  final MiningDepositDefinition deposit;
}
```

The world anchor is normalized 0–1 content data, not a Flutter `Offset` or Flame `Vector2`, so the domain remains independent of UI libraries.

### Initial Phase 1 balance

These are concrete starting values so implementation and tests do not depend on hidden constants. They may be tuned within HPA-631 after playtesting, but any tuning changes the registry only.

| Sector | Initial state | Resource | Reveal cost | Build cost | Base rate/s | Base capacity | Sale value/unit | Upgrade costs L2→L5 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Landing Basin | revealed | Gold | 0 | 50 | 0.50 | 90 | 4 | 80, 160, 320, 640 |
| Carbon Ridge | locked | Coal | 250 | 100 | 0.75 | 120 | 3 | 150, 300, 600, 1200 |
| Granite Crater | locked | Stone | 700 | 250 | 0.60 | 120 | 5 | 350, 700, 1400, 2800 |

Starting cash is **100**.

Mine multipliers by level:

| Level | Rate multiplier | Capacity multiplier | Visual tier |
| ---: | ---: | ---: | --- |
| 1 | 1.00 | 1.00 | base |
| 2 | 1.50 | 1.50 | base |
| 3 | 2.25 | 2.00 | advanced |
| 4 | 3.25 | 3.00 | advanced |
| 5 | 4.50 | 4.00 | elite |

Carbon Ridge requires Landing Basin to be revealed. Granite Crater requires Carbon Ridge to be revealed. There is no extra mastery, scanner-energy, timer, resource, or technology requirement.

The offline cap is **8 hours**.

## Mutable state

Use a one-planet save shape rather than carrying future technology and planet maps before they exist:

```dart
class MiningSaveV2 {
  static const int schemaVersion = 2;

  final int cash;
  final DateTime lastAccruedAtUtc;
  final Map<String, SectorProgress> sectors;
}

class SectorProgress {
  final bool revealed;
  final MineState? mine;
}

class MineState {
  final String depositId;
  final int level;
  final double storedAmount;
}
```

Initial state reveals Landing Basin, locks Carbon Ridge and Granite Crater, contains no mines, starts with 100 cash, and sets `lastAccruedAtUtc` to initialization time.

A single global accrual timestamp is enough because every active mine advances on the same clock. Building a new mine first accrues all existing mines to `nowUtc`, then creates the new mine with the save timestamp already advanced to that instant. Per-mine timestamps would add state without changing behavior.

All state mutations produce a new value. Widgets and Flame components receive state; they do not own economic state.

## Deterministic simulation

`MiningSimulation` is pure Dart with no Flutter, Flame, SharedPreferences, timers, or wall-clock reads.

For a positive elapsed interval:

```text
usableElapsed = min(nowUtc - lastAccruedAtUtc, 8 hours)
rate = deposit.baseRatePerSecond * rateMultiplier[level]
capacity = deposit.baseCapacity * capacityMultiplier[level]
produced = min(rate * usableElapsedSeconds, capacity - storedAmount)
storedAmount += max(0, produced)
```

Rules:

- If `nowUtc < lastAccruedAtUtc`, production is zero and `lastAccruedAtUtc` does not move backward.
- If elapsed time exceeds 8 hours, only 8 hours can produce and the resulting state's timestamp advances to `nowUtc`, discarding the excess.
- Storage never exceeds the current mine capacity.
- Equal persisted state plus equal `nowUtc` produces the same result for foreground refresh, resume, and cold launch.
- A UI timer may call refresh once per second, but the timer is never the source of production truth.

`MiningSimulation.accrue(...)` returns both the next state and an `OfflineProductionSummary`-compatible delta containing produced amounts by resource, elapsed duration used, and whether the offline cap was reached.

## Controller and atomic actions

`MiningController` is a small `ChangeNotifier` owned by `MiningScreen`. It receives:

- `MiningContentRegistry` content;
- one `MiningSaveRepository`;
- a `DateTime Function()` UTC clock for deterministic tests.

Public operations:

```dart
Future<void> initialize();
void refresh();
Future<MiningActionResult> revealSector(String sectorId);
Future<MiningActionResult> buildMine(String depositId);
Future<MiningActionResult> upgradeMine(String depositId);
Future<MiningSaleResult> sellAllCargo();
Future<void> checkpoint();
OfflineProductionSummary? takePendingReturnSummary();
```

Every explicit action follows the same sequence:

1. calculate an accrued candidate state at `nowUtc` without publishing it;
2. validate the requested action against that candidate;
3. if validation fails, return a failure and leave cash, sectors, levels, cargo, and persisted state unchanged;
4. create the complete next state;
5. publish the state once;
6. save the complete document once.

This preserves HPA-631's failed-action atomicity without inventing transactions or command infrastructure.

### Reveal

Validate that:

- sector exists;
- sector is not already revealed;
- prerequisite sector, if any, is revealed;
- cash covers the reveal cost.

Success deducts cash and marks exactly that sector revealed.

### Build

Validate that:

- deposit exists;
- its sector is revealed;
- no mine exists for the deposit;
- cash covers build cost.

Success deducts cash and creates one level-1 mine with zero cargo.

### Upgrade

Validate that:

- mine exists;
- level is 1–4;
- cash covers the authored next-level cost.

Success deducts cash and increments exactly one level. Existing cargo is retained and remains below the newly increased capacity.

### Sell All Cargo

Accrue a candidate first, then calculate:

```text
revenue = Σ floor(storedAmount * saleValuePerUnit)
```

Success clears cargo on every active mine and adds the summed integer revenue to cash in one new state. There is no per-resource sell button and no market buy side.

A zero-cargo sell returns a non-mutating failure result rather than performing a meaningless save.

## Persistence

Create `MiningSaveRepository` beside the mining feature rather than widening the legacy `SaveService`.

Use exactly one SharedPreferences key:

```text
horologium.mining.save.v2
```

The JSON document contains:

- `schemaVersion: 2`;
- integer `cash`;
- UTC ISO-8601 `lastAccruedAtUtc`;
- sector progress keyed by the three stable sector IDs;
- optional mine data for each sector.

### Load behavior

1. Missing key → return a clean initial state.
2. Valid V2 document → decode and normalize known fields.
3. Missing optional/added-within-MVP fields → use the registry's sensible default.
4. Unknown extra fields → ignore them.
5. Wrong schema version, invalid types, invalid IDs, negative cash, invalid level, invalid cargo, or malformed timestamp → return a clean state with `recoveredFromInvalidSave = true`.
6. Do not read any legacy city keys.

The UI shows one non-blocking recovery `SnackBar` after a reset.

There is no backup key, forensic payload, legacy conversion, cloud save, or migration framework in HPA-631.

### Write behavior

Write after:

- successful Reveal;
- successful Build;
- successful Upgrade;
- successful Sell All Cargo;
- application pause/inactive checkpoint;
- a controlled screen-exit checkpoint.

Do not write on the one-second foreground refresh timer.

## Flutter presentation

`MiningScreen` is a `StatefulWidget` with `WidgetsBindingObserver`. It owns the controller, the Flame `MiningGame`, and the existing `AudioManager`.

The canonical portrait stack is:

```text
SafeArea
  Stack
    MiningGame world
    top MiningStatusBar
    bottom MiningActionSheet
    temporary reward/confirmation overlays
```

### Status bar

Show at most three primary values:

1. cash;
2. revealed sectors (`1/3`, `2/3`, `3/3`);
3. total stored cargo value / capacity status.

Do not surface city resources, workers, happiness, research, quests, or production graphs.

### Contextual action sheet

One sheet changes content based on selection:

- no selection: next objective + **Sell All Cargo**;
- locked sector: name, reveal cost, prerequisite copy, **Reveal Sector**;
- revealed empty deposit: resource, base rate/capacity, build cost, **Build Mine**;
- active mine: level, rate, storage, next upgrade benefit/cost, **Upgrade**.

Primary buttons are at least **56 logical pixels** high, exceeding the required 48 px minimum.

The sheet is capped at roughly 42% of the usable viewport on small phones. The world remains visible above it. When selection changes, `MiningScreen` tells `MiningGame` the selected world anchor and current sheet height so the camera can keep the selected sector/deposit in the visible world region.

Representative widget sizes for automated layout checks:

- narrow portrait: 360×640 logical px;
- tall portrait: 430×932 logical px.

Landscape receives safe constraints but no separately authored layout in this issue.

## Flame world

`MiningGame` is a separate `FlameGame`; it does not subclass or modify `MainGame`.

It may reuse `ParallaxTerrainComponent` as the illustrated underlay and copy the minimal fit/pan/zoom behavior needed from `MainGame`. Do not extract a shared camera framework during HPA-631.

The world contains three authored `MiningSectorComponent`s at stable normalized anchors. Each owns presentation children for its deposit or mine. The components are updated from `MiningSaveV2` through a method such as:

```dart
void applyState(MiningSaveV2 state);
```

World taps report stable sector/deposit IDs to Flutter. Flame never calls the simulation or persistence layer directly.

### Existing art reuse

Use current repository art for the MVP rather than introducing an asset-production pipeline:

- Gold mine: `assets/images/building/gold_mine.png`
- Coal mine: `assets/images/building/coal_mine.png`
- Stone mine: `assets/images/building/quarry.png`
- Gold/coal/stone icons: existing `assets/images/resource/` images
- Existing terrain/rocks/water/detail sprites through `ParallaxTerrainComponent`

Mine levels 1, 3, and 5 must still read as visibly different. Build that distinction through presentation layers around the base image:

- level 1: base facility + one operation light;
- level 3: larger platform footprint, secondary machinery silhouette, brighter operation lights;
- level 5: additional platform/ring, elite glow, stronger moving cargo/particle treatment.

Levels 2 and 4 update rate/storage numbers and may increase animation intensity without a third/fourth unique facility art state.

This keeps the first implementation visually rich enough to judge while avoiding a new image-generation or asset pipeline before the loop is validated.

## Reward moments

All rewards are presentation triggered **after** the controller reports success:

1. **Scanner reveal** — sector fog/cover fades while a sweep crosses the region; resource icon/deposit appears at the end.
2. **Mine construction** — facility scales/fades in with dust/glow and a visible “Mine online” confirmation.
3. **Tier upgrade** — crossing levels 3 or 5 swaps the visible facility tier and plays a short pulse/burst; other upgrades still show a rate/capacity delta.
4. **Cargo sale** — active mines emit a short cargo-to-wallet effect while Flutter animates the cash delta.

Animation completion never gates a state mutation.

### Reduced motion and no-audio confirmation

Read Flutter's `MediaQueryData.disableAnimations` and pass a `reducedMotion` flag to `MiningGame`.

With reduced motion:

- scanner sweep becomes a short fade;
- construction/tier changes use a brief cross-fade;
- cargo movement becomes a number/cash delta transition;
- camera movement snaps or uses a very short interpolation.

Every successful action also has visible text/number confirmation, so audio is never required to understand success. Reuse `AudioManager` only for existing BGM preference/lifecycle behavior. Haptics may use `HapticFeedback` after successful primary actions and are optional/no-op on unsupported platforms.

## Lifecycle and offline return

`MiningScreen` uses one foreground timer (1 second) only to call `controller.refresh()` and repaint current cargo values.

Lifecycle handling:

- `inactive` / `paused`: cancel or ignore foreground refresh and `await controller.checkpoint()`; pass state to `AudioManager`.
- `resumed`: call `controller.refresh()` at the current UTC time, then show one `OfflineReturnSheet` if new cargo was produced while away; resume foreground refresh.
- cold launch: `initialize()` loads persisted state and accrues to current UTC with the same simulation function; show the same return summary if cargo was produced.
- screen exit: checkpoint once before disposal/navigation completion when practical; persistence correctness still comes from the last saved checkpoint plus deterministic cold-launch accrual if the process dies before that write.

The summary shows elapsed time used, resources produced, storage-full notes where relevant, and a single next-action hint such as **Sell cargo** or **Upgrade a mine**.

## Temporary entry point

Add **MINING MVP** to `lib/main_menu.dart` and navigate directly to `MiningScreen`.

Do not replace **START EXPEDITION**, remove **TRADE**, alter the legacy active `Planet` initialization, or route city state into mining. HPA-636 owns product cutover after HPA-631 records a **Proceed to cutover** decision.

## Testing strategy

Keep the existing Flutter test/CI stack; do not add a new test runtime.

### Domain tests

Prove:

- level rate/capacity math;
- positive elapsed accrual;
- identical result for equal state/time regardless of call path;
- storage cap;
- 8-hour offline cap;
- clock rollback produces zero;
- excess time is discarded after a capped accrual;
- all reveal/build/upgrade failure paths preserve the complete state;
- successful reveal/build/upgrade deduct exactly once;
- mixed-resource Sell All Cargo adds one summed revenue and clears all cargo atomically.

### Persistence tests

Using `SharedPreferences.setMockInitialValues()`:

- clean-state load;
- V2 round trip;
- known missing fields receive defaults;
- unknown fields are ignored;
- malformed JSON, bad schema, invalid timestamp, negative cash, bad IDs/levels/cargo reset cleanly and report recovery;
- legacy city keys are ignored;
- passive `refresh()` does not write the save key;
- explicit action/checkpoint does write it.

### World/widget tests

Prove:

- all three authored sectors render and selection reports stable IDs;
- locked/revealed/mine states map to the right components;
- level 1/3/5 presentation is distinct;
- 360×640 and 430×932 layouts have no overflow and primary controls are ≥56 px;
- contextual sheet changes correctly;
- recovery message and offline summary appear once;
- reduced-motion mode still confirms all primary actions;
- selected content is re-focused above the bottom sheet.

### Targeted end-to-end test

Add `test/integration/mining_mvp_journey_test.dart` using Flutter's existing test runtime. Pump the real `MiningScreen` with mocked SharedPreferences and a deterministic clock, then walk the production journey across the real controller/persistence/UI seams:

1. enter the temporary mining screen;
2. select gold deposit and build;
3. advance clock and refresh;
4. sell;
5. upgrade gold;
6. reveal/build Carbon Ridge;
7. reveal/build Granite Crater;
8. accrue mixed cargo and sell it;
9. checkpoint, dispose, advance clock, recreate the screen;
10. verify offline summary and deterministic restored cargo.

This gives end-to-end application coverage without adding an emulator farm or a second CI runtime. Existing CI already runs `flutter test`, analysis, formatting, Android debug build, and web build.

Manual acceptance adds a real portrait mobile smoke check for touch feel, animation clarity, and the under-one-minute first mine criterion.

## One-PR delivery

All HPA-631 implementation stays on one branch and one pull request. Use focused commits for review checkpoints, but do not create child PRs for domain, persistence, sectors, UI, art, or tests unless the user explicitly revises this policy.

Recommended commit sequence:

1. mining content/state/simulation;
2. mining persistence/controller;
3. Flame mining world and selection;
4. Flutter mining screen and menu entry;
5. offline/reward/accessibility presentation;
6. complete tests and acceptance evidence.

The PR remains draft while the loop is incomplete.

## Explicit non-goals

HPA-631 does not implement:

- mining as the default Start/Continue route;
- city-system deletion or migration;
- technology;
- a second planet or generic multi-planet state;
- retention/daily systems;
- processing/refining/recipes;
- dynamic markets, demand, resource buying, or contracts;
- workers, houses, population, services, logistics, power, maintenance, or depletion;
- backup save rotation, forensic recovery, cloud saves, accounts, or server time;
- a generic controller framework, event bus, dependency-injection framework, camera framework, or asset pipeline.

## Acceptance mapping

The implementation is complete only when the single PR proves all of these:

- Landing Basin, Carbon Ridge, and Granite Crater share one content/domain path.
- Gold, coal, and stone share one mine/sell simulation path.
- A fresh run can build gold in under one minute and sell during the opening session.
- Reveal, Build, Upgrade, Sell, foreground refresh, resume, and cold launch use deterministic state transitions.
- Failed actions do not partially mutate state.
- Mixed cargo sells atomically.
- Clock rollback, storage limits, and the 8-hour cap are tested.
- V2 persistence round-trips, ignores legacy keys, does not save per refresh, and recovers cleanly.
- At least Landing Basin reaches the intended visual benchmark early; all three sectors are coherent before completion.
- Levels 1, 3, and 5 are visibly distinct.
- Scanner reveal, construction, tier upgrade, and sale have clear reward feedback with reduced-motion equivalents.
- 360×640 and 430×932 portrait layouts work without entering legacy city pages.
- Unit, persistence, widget/world, and full-journey integration tests pass.
- `dart format --output=none --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test --coverage`, `flutter build apk --debug`, and `flutter build web` pass.
- HPA-631 receives a conclusion comment recording reviewed build/device observations and exactly one decision: **Proceed to cutover**, **Revise once**, or **Stop/reconsider**.
