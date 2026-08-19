# HPA-631 One-Planet Mining MVP Design

## Status

Implementation design for Linear HPA-631, **Build and validate the one-planet mining MVP**.

This design is scoped to one implementation PR. It intentionally does not split domain, persistence, sectors, presentation, or testing into separate tickets or PRs.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the authoritative Horologium mining roadmap.
2. Linear HPA-631, the acceptance contract for this MVP.
3. This task-specific design.
4. `docs/superpowers/specs/2026-08-17-stellar-mining-idle-pivot-design.md` on commit `40ef643bc99e6686ee99c797e289232b4e45e407` as supporting rationale only.
5. Existing city-simulation documentation only as implementation context.

The August 18 review deliberately simplifies one part of the earlier pivot design: HPA-631 uses one strict mining JSON save without a schema-version envelope, backup rotation, missing-field defaults, or speculative forward-compatibility behavior. There is no shipped mining save to migrate yet.

## Goal

Ship the first complete mining-idle product loop inside the existing Flutter/Flame app without coupling it to the legacy city simulation:

> Identify Landing Basin's gold deposit → build a mine → accrue cargo → sell → upgrade → reveal Carbon Ridge → build coal → reveal Granite Crater → build stone → leave → return to deterministic offline production.

The slice exists to answer a product question, not to create a platform: is simple mining, discovery, selling, upgrading, and strong visual reward feedback compelling enough to become Horologium's default direction?

## Current repository baseline

`main` is still the May 2026 city-building runtime:

- `lib/main_menu.dart` loads a legacy `Planet` and sends **START EXPEDITION** to `MainGameWidget`.
- `lib/game/main_game.dart` is a Flame world centered on the city grid and `Building` placement.
- `lib/game/scene_widget.dart` coordinates worker/resource/research/quest state around that city runtime.
- `lib/game/services/save_service.dart` persists the legacy model across many SharedPreferences keys.
- City production is driven by a one-second timer in `GameStateManager`; it is not suitable as the authority for offline mining production.
- `ResourceType`, `Assets`, `ParallaxTerrainComponent`, camera interaction patterns, `AudioManager`, `ResourceIcon`, and existing mine sprites are reusable without reusing the city economy.

HPA-631 therefore adds a parallel mining vertical slice and a temporary menu entry. HPA-636, not this issue, owns replacing the default Start flow and deleting obsolete city systems.

## Selected architecture

Add one focused mining feature:

```text
Flutter MiningScreen
    -> plain MiningController
        -> MiningSimulation
        -> MiningSaveRepository
        -> MiningContentRegistry
    -> MiningSheetView.from(...)

Flame MiningGame
    <- read-only MiningSave + callbacks from MiningScreen
```

The feature reuses existing identity and presentation primitives where they are already clean:

- `ResourceType.gold`, `ResourceType.coal`, `ResourceType.stone`;
- `Assets.goldMine`, `Assets.coalMine`, `Assets.quarry`;
- `ResourceIcon` for Flutter resource icons;
- `ParallaxTerrainComponent` for terrain;
- `AudioManager` for existing BGM preferences/lifecycle behavior;
- the minimal fit/pan/zoom logic copied from `MainGame`.

It does **not** reuse `Resources`, `Building`, `BuildingRegistry`, `GameStateManager`, `Planet`, `ActivePlanet`, or `SaveService` for mining state or economics.

This is the smallest boundary that keeps HPA-636 cheap: mining does not inherit workers, population, happiness, research, free-form placement, or city persistence, while identity/constants are not needlessly forked.

### Rejected: retrofit the city economy

Routing mining through `Resources.update()`, `Building`, or `SaveService` would drag worker assignment, happiness/research state, building placement, and many-key persistence into the new loop. That makes offline accrual and later city deletion harder.

### Rejected: generic platform work

Do not add a package split, event bus, command bus, dependency-injection framework, shared camera framework, asset pipeline, generic planet engine, or content DSL for one planet and three fixed deposits.

## Feature layout

Keep the small core flat and reserve subdirectories for actual presentation/world groups:

```text
lib/mining/
  mining_content.dart
  mining_state.dart
  mining_simulation.dart
  mining_save_repository.dart
  mining_controller.dart
  mining_sheet_view.dart
  presentation/
    mining_screen.dart
    mining_status_bar.dart
    mining_action_sheet.dart
    offline_return_sheet.dart
  world/
    mining_game.dart
    mining_components.dart
```

`MiningController`, `MiningSimulation`, content, state, save decoding, and sheet derivation remain free of Flutter widgets and Flame components. `MiningController` is a plain Dart class; `MiningScreen` owns repainting with `setState`, matching the existing app's StatefulWidget + callback style.

Do not add Provider, Riverpod, Bloc, `ChangeNotifier`, service locators, code generation, or repository interfaces.

## Immutable Phase 1 content

Use the existing `ResourceType` enum and `Assets` constants rather than creating mining-specific copies.

```dart
enum MiningSectorId {
  landingBasin,
  carbonRidge,
  graniteCrater,
}

class MiningWorldAnchor {
  const MiningWorldAnchor(this.x, this.y);
  final double x;
  final double y;
}

class MiningSectorDefinition {
  const MiningSectorDefinition({
    required this.id,
    required this.name,
    required this.resource,
    required this.mineAsset,
    required this.revealCost,
    required this.requiredSector,
    required this.buildCost,
    required this.baseRatePerSecond,
    required this.baseCapacity,
    required this.saleValuePerUnit,
    required this.upgradeCosts,
    required this.anchor,
  });

  final MiningSectorId id;
  final String name;
  final ResourceType resource;
  final String mineAsset;
  final int revealCost;
  final MiningSectorId? requiredSector;
  final int buildCost;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<int> upgradeCosts;
  final MiningWorldAnchor anchor;
}
```

Each Phase 1 sector contains exactly one fixed deposit, so a second deposit ID namespace is unnecessary. The sector ID is the stable identity for content, progress, selection, persistence, and world components.

### Initial balance

| Sector | Initial state | Resource | Mine asset | Reveal | Build | Rate/s | Capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Landing Basin | revealed | Gold | `Assets.goldMine` | 0 | 50 | 0.50 | 90 | 4 | 80, 160, 320, 640 |
| Carbon Ridge | locked | Coal | `Assets.coalMine` | 250 | 100 | 0.75 | 120 | 3 | 150, 300, 600, 1200 |
| Granite Crater | locked | Stone | `Assets.quarry` | 700 | 250 | 0.60 | 120 | 5 | 350, 700, 1400, 2800 |

Starting cash is **100**.

Mine multipliers:

| Level | Rate | Capacity | Visual tier |
| ---: | ---: | ---: | --- |
| 1 | 1.00 | 1.00 | base |
| 2 | 1.50 | 1.50 | base |
| 3 | 2.25 | 2.00 | advanced |
| 4 | 3.25 | 3.00 | advanced |
| 5 | 4.50 | 4.00 | elite |

Carbon Ridge requires Landing Basin revealed. Granite Crater requires Carbon Ridge revealed. There is no scanner energy, reveal timer, mastery currency, resource depletion, or technology requirement.

The offline cap is **8 hours**.

## Mutable state

Use one closed first-planet state shape:

```dart
class MiningSave {
  final int cash;
  final DateTime lastAccruedAtUtc;
  final Map<MiningSectorId, SectorProgress> sectors;
}

class SectorProgress {
  final bool revealed;
  final MineState? mine;
}

class MineState {
  final int level;
  final double storedAmount;
}
```

Initial state:

- cash = 100;
- Landing Basin revealed;
- Carbon Ridge and Granite Crater locked;
- no mines;
- `lastAccruedAtUtc` = initialization UTC time.

A global accrual timestamp is enough because all active mines advance on the same clock. Building a new mine first accrues existing mines to `nowUtc`, then creates the new mine with the save timestamp already advanced to that instant.

All state changes create new values. Widgets and Flame components receive snapshots; they do not own authoritative economics.

## Deterministic simulation

`MiningSimulation` is pure Dart with no Flutter, Flame, SharedPreferences, timers, or wall-clock reads.

For each revealed sector with a mine:

```text
rawElapsed = nowUtc - lastAccruedAtUtc
usableElapsed = clamp(rawElapsed, 0, 8 hours)
rate = sector.baseRatePerSecond * rateMultiplier[level]
capacity = sector.baseCapacity * capacityMultiplier[level]
produced = min(rate * usableElapsedSeconds, capacity - storedAmount)
storedAmount += max(0, produced)
```

Rules:

- clock rollback produces zero and never moves the timestamp backward;
- elapsed time above 8 hours uses only 8 hours, then advances the resulting timestamp to `nowUtc` so excess time cannot be claimed later;
- storage never exceeds current capacity;
- equal persisted state + equal `nowUtc` produces the same result for foreground refresh, resume, and cold launch;
- a one-second UI timer may call refresh, but timers are not the economic source of truth.

`MiningSimulation.accrue(...)` returns the next state plus an `OfflineProductionSummary` containing produced amounts by `ResourceType`, elapsed duration used, full sectors, and whether the offline cap was reached.

## Plain controller and atomic actions

`MiningController` is a plain class. It receives:

- `MiningContentRegistry`;
- `MiningSaveRepository`;
- an injectable `DateTime Function()` UTC clock.

Representative operations:

```dart
Future<void> initialize();
AccrualResult refresh();
Future<MiningActionResult> revealSector(MiningSectorId sectorId);
Future<MiningActionResult> buildMine(MiningSectorId sectorId);
Future<MiningActionResult> upgradeMine(MiningSectorId sectorId);
Future<MiningSaleResult> sellAllCargo();
Future<void> checkpoint();
Future<OfflineProductionSummary?> resume();
OfflineProductionSummary? takePendingReturnSummary();
```

Each explicit mutation follows one sequence:

1. accrue a candidate state at `nowUtc` without publishing it;
2. validate the action against the candidate;
3. if invalid, return failure and keep in-memory + persisted state unchanged;
4. create one complete next state;
5. save that complete state once;
6. publish it as controller state once the save succeeds;
7. return the success result used by presentation effects.

No command bus, transaction framework, or listener framework is needed.

`refresh()` updates controller state in memory only. `MiningScreen` calls `setState()` and `MiningGame.applyState(controller.state)` after refresh/actions. It does not persist one-second refreshes.

### Reveal

Validate sector is known, locked, prerequisite is revealed, and cash covers reveal cost. Success deducts once and reveals exactly that sector.

### Build

Validate sector is known, revealed, has no mine, and cash covers build cost. Success deducts once and creates level 1 with zero cargo.

### Upgrade

Validate a mine exists, level is 1–4, and cash covers the authored next-level cost. Success deducts once and increases exactly one level. Existing cargo remains valid under the larger capacity.

### Sell All Cargo

Accrue first, then calculate:

```text
revenue = Σ floor(storedAmount * sector.saleValuePerUnit)
```

Success clears cargo on all active mines and adds one summed integer revenue to cash. Zero cargo is a non-mutating failure/no-op.

## Persistence: one strict JSON document

Create mining-specific persistence; do not widen `SaveService`.

Use one key:

```text
horologium.mining.save
```

There is no schema version because there is no shipped mining save and no compatibility requirement yet.

The JSON shape is deliberately closed:

```json
{
  "cash": 100,
  "lastAccruedAtUtc": "2026-08-18T12:00:00.000Z",
  "sectors": {
    "landingBasin": {"revealed": true, "mine": null},
    "carbonRidge": {"revealed": false, "mine": null},
    "graniteCrater": {"revealed": false, "mine": null}
  }
}
```

A mine is:

```json
{"level": 1, "storedAmount": 12.5}
```

### Load rules

- missing save key → clean initial state, no warning;
- valid exact document → decode to typed enum-keyed state;
- malformed JSON, wrong types, missing required root fields, missing/duplicate/unknown sector IDs, invalid timestamps, negative cash, mine level outside 1–5, negative cargo, or cargo above configured capacity → clean initial state + `recoveredFromInvalidSave = true`;
- do not default-fill missing sectors;
- do not add/test speculative `futureField` behavior;
- do not read city save keys;
- no backup, forensic recovery, migration layer, or legacy conversion.

The UI shows one non-blocking recovery message after a reset.

### Write rules

Write only after:

- successful Reveal;
- successful Build;
- successful Upgrade;
- successful Sell All Cargo;
- application pause/inactive checkpoint;
- controlled screen-exit checkpoint.

Do not write on one-second foreground refresh.

## Pure contextual sheet model

Do not derive affordability, prerequisite copy, or action state inside `MiningScreen.build()`.

Add one pure model:

```dart
enum MiningSheetAction { sell, reveal, build, upgrade, none }

class MiningSheetView {
  final String title;
  final String body;
  final String primaryLabel;
  final MiningSheetAction action;
  final bool primaryEnabled;
  final String? disabledReason;

  static MiningSheetView from({
    required MiningSave state,
    required MiningContentRegistry content,
    required MiningSectorId? selectedSectorId,
  });
}
```

It derives the four Phase 1 sheet states:

- no selection: next objective + **Sell All Cargo**;
- locked sector: reveal cost, prerequisite, **Reveal Sector**;
- revealed sector/no mine: resource/rate/capacity/build cost, **Build Mine**;
- active mine: level/storage/rate/upgrade delta, **Upgrade** or max-level state.

Domain-level tests cover affordance/copy decisions without pumping widgets. `MiningActionSheet` renders the model and callbacks only. Widget tests focus on layout and taps.

## Flutter presentation

`MiningScreen` is a `StatefulWidget` with `WidgetsBindingObserver`. It owns one plain controller, one `MiningGame`, one `AudioManager`, the selected sector ID, and a one-second repaint timer.

Canonical portrait stack:

```text
SafeArea
  Stack
    MiningGame world
    top MiningStatusBar
    bottom MiningActionSheet
    temporary reward/confirmation overlays
```

Status bar shows at most:

1. cash;
2. revealed sectors (`1/3`, `2/3`, `3/3`);
3. stored cargo value/status.

Primary action buttons are at least **56 logical pixels** high. The bottom sheet is capped around 42% of the usable viewport on small phones. Selection changes tell `MiningGame` the selected sector and obscured fraction so the camera keeps it visible above the sheet.

Automated layouts:

- 360×640 logical px;
- 430×932 logical px.

Landscape gets safe constraints, not a second authored layout.

## Flame world

`MiningGame` is separate from `MainGame`. It may reuse `ParallaxTerrainComponent` and copy only the minimal fit/pan/zoom behavior needed from `MainGame`; do not extract a shared camera abstraction.

The world owns three `MiningSectorComponent`s keyed by `MiningSectorId`. World taps return the enum ID to Flutter. `MiningGame.applyState(MiningSave state)` updates presentation only.

### Existing art reuse

Use:

- `Assets.goldMine`;
- `Assets.coalMine`;
- `Assets.quarry`;
- existing `ResourceIcon` / resource asset constants;
- current terrain sprites via `ParallaxTerrainComponent`.

No `mineAssetFor()` string mapping is added because the registry already stores the existing asset constant.

### Structural visual tiers

Levels 1, 3, and 5 must differ in component structure, not only in an enum value:

- level 1: base sprite + operation light;
- level 3: level 1 + advanced platform + secondary machinery + brighter lights;
- level 5: level 3 + elite ring/glow + stronger cargo/particle treatment.

Tests apply progress and assert the corresponding presentation children/flags. A real `GameWidget` harness based on the existing `scene_widget_test.dart` pump pattern verifies the asset-backed mining game loads and owns all three authored sectors. Do not call `MiningGame.onLoad()` naked and then weaken the test if Flame requires a mounted game reference.

Manual portrait smoke still judges art quality, motion, readability, and feel; it is not the only proof that levels 1/3/5 differ.

## Reward moments

All effects start **after** controller success:

1. scanner reveal — fog/cover fade + sweep;
2. mine construction — facility appears with dust/glow + visible confirmation;
3. tier upgrade — level 3/5 structural layers appear with a short pulse;
4. cargo sale — cargo-to-wallet effect + visible cash delta.

Animation completion never gates economic state.

With reduced motion:

- scanner becomes a short fade;
- construction/tier changes use cross-fades;
- cargo motion becomes a number/cash transition;
- camera movement snaps or becomes very short.

Every action also has text/number confirmation, so audio is optional. Haptics are presentation-only and may no-op on unsupported platforms.

## Lifecycle and offline return

The one-second foreground timer calls `controller.refresh()`, then `setState()` and `MiningGame.applyState()`. It never writes persistence.

Lifecycle:

- `inactive` / `paused`: stop refresh and checkpoint once; pass lifecycle to `AudioManager`;
- `resumed`: call `controller.resume()`, repaint/apply state, show one offline summary if production occurred, restart refresh;
- cold launch: `initialize()` loads then accrues through the same simulation function and exposes the same one-shot summary;
- controlled exit: checkpoint once when practical.

The offline summary shows elapsed time used, non-zero resource production, storage-full notes, offline-cap note, and one next-action hint. There is no claim button because cargo is already authoritative state.

## Temporary entry point

Add **MINING MVP** to `lib/main_menu.dart` and navigate directly to `MiningScreen`.

Do not replace **START EXPEDITION**, remove **TRADE**, alter legacy `Planet` initialization, or route city state into mining. HPA-636 owns cutover only after HPA-631 records **Proceed to cutover**.

## Testing strategy

Keep the existing Flutter/Flame test stack; add no new runtime or mocking framework.

### Core tests

Prove:

- exact three-sector registry and enum IDs;
- reused `ResourceType` + `Assets` mappings;
- level rate/capacity math;
- elapsed accrual, storage cap, 8-hour cap, clock rollback, excess-time discard;
- equal state/time gives equal result;
- all failed actions preserve complete state and persistence;
- successful Reveal/Build/Upgrade deduct exactly once;
- mixed Sell All Cargo sums revenue and clears all active cargo atomically.

### Persistence tests

Using `SharedPreferences.setMockInitialValues()`:

- missing key → clean state;
- strict unversioned round trip;
- malformed JSON/bad types/missing sector/unknown sector/invalid timestamp/negative cash/bad level/bad cargo → reset + recovery flag;
- city keys are ignored;
- only `horologium.mining.save` is written;
- passive refresh does not persist;
- explicit action/checkpoint does persist.

Do not add tests for schema versions, missing-field default-fill, or future unknown fields.

### Sheet tests

Pure `MiningSheetView.from(...)` tests prove locked prerequisite, affordability, build/upgrade/max-level states, Sell All availability, labels, and disabled reasons without widget pumping.

### World/widget tests

Prove:

- mounted `MiningGame` owns all three enum-keyed sectors;
- locked/revealed/mine state maps correctly;
- level 1/3/5 structural children/flags are distinct;
- 360×640 and 430×932 have no overflow and primary actions are ≥56 px;
- sheet renders the pure view model and routes taps to the correct controller action;
- recovery and offline summary appear once;
- reduced-motion actions remain visibly confirmed;
- selected content is focused above the sheet.

### Full journey

`test/integration/mining_mvp_journey_test.dart` pumps the real menu/mining screen with mocked SharedPreferences and an injected clock, then uses visible UI only:

1. enter **MINING MVP**;
2. build gold;
3. advance time and sell;
4. upgrade gold;
5. reveal/build Carbon Ridge;
6. reveal/build Granite Crater;
7. accrue and sell mixed cargo;
8. checkpoint/dispose;
9. advance clock and recreate;
10. verify offline summary and restored deterministic cargo.

No controller shortcuts or test-only economy path.

## One-PR delivery

All work remains on `jack65786656/hpa-631-build-and-validate-the-one-planet-mining-mvp` and draft PR #14. Use focused commits, not child PRs.

Recommended commit sequence:

1. content/state/simulation;
2. strict persistence/plain controller;
3. pure sheet view;
4. Flame world + structural tier tests;
5. Flutter screen + menu entry;
6. offline/reward/accessibility UX;
7. full journey + acceptance fixes.

## Explicit non-goals

HPA-631 does not implement:

- mining as default Start/Continue;
- city deletion/migration;
- technology;
- second planet or generic multi-planet state;
- retention/daily systems;
- processing/refining/recipes;
- dynamic markets, demand, resource buying, or contracts;
- workers, housing, population, services, logistics, power, maintenance, or depletion;
- backup saves, schema-version migration, forensic recovery, cloud save, accounts, or server time;
- generic controller/camera/content/asset frameworks.

## Acceptance mapping

The PR is complete only when it proves:

- three sectors use one typed content/state path;
- Gold/Coal/Stone reuse `ResourceType` and share one simulation/sale path;
- fresh play builds gold in under one minute and sells during opening session;
- Reveal/Build/Upgrade/Sell/refresh/resume/cold launch are deterministic;
- failed actions do not partially mutate state;
- mixed cargo sells atomically;
- rollback/storage/8-hour cap are tested;
- strict single-document persistence round-trips, ignores city keys, avoids refresh writes, and resets invalid data cleanly;
- pure sheet derivation keeps affordance logic out of widget `build()`;
- level 1/3/5 structural presentation is automatically verified and manually judged;
- scanner/build/tier/sale rewards have reduced-motion/no-audio confirmation;
- both portrait layouts work without entering city pages;
- unit/persistence/sheet/world/widget/full-journey coverage passes;
- format, analyze, full tests, web tests, APK build, and web build pass;
- HPA-631 receives one final reviewed-build comment with **Proceed to cutover**, **Revise once**, or **Stop/reconsider**.
