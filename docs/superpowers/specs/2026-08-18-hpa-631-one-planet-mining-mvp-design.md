# HPA-631 One-Planet Mining MVP Design

## Status

Implementation design for Linear HPA-631, **Build and validate the one-planet mining MVP**.

This design is intentionally one PR and one product-validation slice. It does not split domain, persistence, sectors, presentation, animation, or testing into child tickets or PRs.

## Source priority

When requirements differ, use this order:

1. Linear HPA-630, the Horologium mining roadmap.
2. Linear HPA-631, the MVP acceptance contract.
3. This task-specific design.
4. The earlier stellar-mining pivot design as supporting rationale only.
5. Legacy city documentation as implementation context only.

The current HPA-631 decisions supersede older platform-oriented details: the first mining save is strict and unversioned, the first planet has one deposit per sector, and no migration, backup, multi-planet, or generic content framework is prebuilt.

## Goal

Ship the smallest complete loop that can answer the product question:

> Is revealing fixed deposits, building automated mines, selling cargo, upgrading facilities, and returning to offline production compelling enough to become Horologium's default direction?

The player journey is:

> Landing Basin gold → build → accrue → sell → upgrade → reveal Carbon Ridge → build coal → reveal Granite Crater → build stone → leave → return to deterministic offline cargo.

## Current repository baseline

`main` is still the city-building product:

- `lib/main_menu.dart` initializes a legacy `Planet` and routes **START EXPEDITION** to `MainGameWidget`.
- `lib/game/main_game.dart` is a Flame world centered on the city grid and `Building` placement.
- `lib/game/scene_widget.dart` coordinates workers, resources, research, quests, and city persistence.
- `lib/game/services/save_service.dart` persists city state across many SharedPreferences keys.
- city production is a one-second mutation loop, not elapsed-time offline accrual.

Useful infrastructure already exists and should be reused without inheriting the city economy:

- `ResourceType.gold`, `ResourceType.coal`, `ResourceType.stone`;
- `Assets.goldMine`, `Assets.coalMine`, `Assets.quarry`;
- `ResourceIcon`;
- `ParallaxTerrainComponent`;
- `AudioManager`;
- the camera fit/pan/zoom math in `MainGame`;
- the future-chain serialization idiom in `PlanetSaveDebouncer`;
- the mounted `GameWidget` testing pattern used by the existing widget suite.

HPA-631 adds a parallel mining path. HPA-636, not this task, owns making mining the default and deleting obsolete city code.

## Selected architecture

```text
Flutter MiningScreen
    -> plain MiningController
        -> MiningSimulation
        -> MiningSaveRepository
        -> MiningContentRegistry
    -> MiningSheetView.from(...)

Flame MiningGame
    <- read-only MiningSave snapshots
    -> typed selection callbacks to MiningScreen
```

Reuse clean identity/presentation primitives, but do not route mining economics or persistence through:

- `Resources`;
- `Building` / `BuildingRegistry`;
- `GameStateManager`;
- `Planet` / `ActivePlanet`;
- `SaveService`.

Do not add Provider, Riverpod, Bloc, `ChangeNotifier`, a command bus, service locator, package split, generic planet engine, shared camera framework, or asset-generation pipeline.

## Feature layout

Keep the core flat because it is small:

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

`MiningSimulation`, save decoding, controller logic, and `MiningSheetView` remain free of Flutter widgets and Flame components. `MiningScreen` owns `setState`, lifecycle, selection, and the one-second repaint timer.

## Phase 1 content and identity

Use one closed identity:

```dart
enum MiningSectorId {
  landingBasin,
  carbonRidge,
  graniteCrater,
}
```

Each Phase 1 sector has exactly one fixed deposit, so there is no second deposit ID namespace.

Use the existing resource enum and asset constants:

```dart
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

### World coordinate contract

The mining world deliberately uses the same terrain cell scale as the existing terrain renderer, but it does not import the city grid into the mining domain.

Phase 1 locks:

```text
terrain grid: 36 × 36 cells
terrain cell size: 50 world px
world extent: 1800 × 1800 world px
world origin: center of the terrain
valid world x/y: -900 ... +900
```

`MiningWorldAnchor` values are **world-pixel offsets from the centered terrain origin**, not normalized fractions, Flutter `Offset`s, or grid coordinates.

The authored anchors are:

| Sector | World anchor (x, y) |
| --- | ---: |
| Landing Basin | (-72, 396) |
| Carbon Ridge | (-396, -72) |
| Granite Crater | (324, -360) |

These preserve the earlier composition while making the coordinate units explicit.

### Initial balance

| Sector | Initial | Resource | Mine asset | Reveal | Build | Rate/s | Capacity | Sale/unit | Upgrade L2→L5 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Landing Basin | revealed | Gold | `Assets.goldMine` | 0 | 50 | 0.50 | 90 | 4 | 80, 160, 320, 640 |
| Carbon Ridge | locked | Coal | `Assets.coalMine` | 250 | 100 | 0.75 | 120 | 3 | 150, 300, 600, 1200 |
| Granite Crater | locked | Stone | `Assets.quarry` | 700 | 250 | 0.60 | 120 | 5 | 350, 700, 1400, 2800 |

Starting cash: **100**.

Mine multipliers:

| Level | Rate | Capacity | Visual tier |
| ---: | ---: | ---: | --- |
| 1 | 1.00 | 1.00 | base |
| 2 | 1.50 | 1.50 | base |
| 3 | 2.25 | 2.00 | advanced |
| 4 | 3.25 | 3.00 | advanced |
| 5 | 4.50 | 4.00 | elite |

Carbon Ridge requires Landing Basin revealed. Granite Crater requires Carbon Ridge revealed. There is no scanner energy, reveal timer, depletion, mastery currency, or technology requirement.

The offline cap is **8 hours**.

`MiningContentRegistry` owns pure helpers such as `rateFor(sectorId, level)` and `capacityFor(sectorId, level)` so simulation, persistence normalization, sheet display, and tests use one formula.

## Mutable state

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

One global accrual timestamp is sufficient because every active mine advances on the same clock.

All transitions create new values. Widgets and Flame components receive snapshots only.

## Deterministic simulation

`MiningSimulation` is pure Dart. It has no Flutter, Flame, SharedPreferences, timer, or wall-clock dependency.

```text
rawElapsed = nowUtc - lastAccruedAtUtc
usableElapsed = clamp(rawElapsed, 0, 8 hours)
rate = content.rateFor(sectorId, level)
capacity = content.capacityFor(sectorId, level)
produced = min(rate * usableElapsedSeconds, capacity - storedAmount)
storedAmount += max(0, produced)
```

Rules:

- clock rollback produces zero and does not move the timestamp backward;
- elapsed time above 8 hours uses only 8 hours, then advances the resulting timestamp to `nowUtc` so excess time cannot be reclaimed;
- storage never exceeds current capacity;
- equal state + equal `nowUtc` gives the same result for foreground refresh, resume, and cold launch;
- the one-second timer is repaint only and never authoritative.

`MiningSimulation.accrue(...)` returns the next state plus `OfflineProductionSummary` containing produced amounts by `ResourceType`, elapsed duration used, full sectors, and whether the cap was reached.

## Serialized plain controller

`MiningController` remains a plain Dart class, but every asynchronous state mutation is serialized through one future chain.

It owns:

```dart
Future<void> _mutationChain = Future<void>.value();
int _pendingMutations = 0;

bool get isBusy => _pendingMutations > 0;
```

All async mutations use one queue helper. The helper increments `_pendingMutations` synchronously, appends the operation to `_mutationChain`, catches operation errors so the chain remains usable, and completes the caller's typed future when that queued operation finishes.

Serialize:

- Reveal;
- Build;
- Upgrade;
- Sell All Cargo;
- lifecycle checkpoint;
- resume persistence when it writes.

`refresh()` is not queued every second. If `isBusy` is true, refresh skips that tick; the next tick accrues from the newly published state.

This prevents a second tap or timer refresh from computing against stale `_state` while the previous save is in flight.

### Atomic mutation sequence

Inside the serialized operation:

1. accrue a candidate at current UTC;
2. validate against that candidate;
3. on failure, leave memory and persistence unchanged;
4. create one complete next state;
5. save it once;
6. publish it to `_state` only after the save succeeds;
7. return presentation data.

No command bus or transaction framework is needed.

### Reveal / Build / Upgrade

- Reveal: known + locked + prerequisite revealed + enough cash.
- Build: known + revealed + no mine + enough cash.
- Upgrade: mine exists + level 1–4 + enough cash.

A queued duplicate Reveal or Build evaluates after the first mutation publishes, so it becomes a normal non-mutating failure rather than overwriting the first success.

### Sell All Cargo

Do not floor each sector separately.

```text
totalCargo = Σ storedAmount
grossValue = Σ (storedAmount * sector.saleValuePerUnit)
revenue = floor(grossValue)
```

- `totalCargo <= 0` is the controller's no-cargo failure condition.
- For non-zero cargo, one sale clears every active mine and adds `floor(grossValue)` once.
- Normal UI disables Sell All Cargo while projected revenue is below 1 cash, so the player does not discard tiny cargo for zero payout.

This makes rounding independent of how cargo is distributed across resources.

## Persistence: strict structure, tolerant balance normalization

Create mining-specific persistence; do not widen `SaveService`.

Use exactly one key:

```text
horologium.mining.save
```

There is no schema version or migration framework because no mining save has shipped.

The document is closed:

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

Mine JSON:

```json
{"level": 1, "storedAmount": 12.5}
```

### Structural reset rules

Reset to clean state with `recoveredFromInvalidSave = true` for:

- malformed JSON;
- wrong JSON types;
- extra or missing required root keys;
- missing, duplicate, or unknown sector IDs;
- invalid/non-UTC timestamp;
- negative/non-int cash;
- invalid `revealed` type;
- mine keys other than exactly `level` + `storedAmount`;
- mine level outside 1–5;
- negative/non-numeric cargo.

Do not default-fill missing sectors, ignore speculative future fields, migrate legacy data, or clamp structural corruption.

### Tunable balance normalization

Configured capacity is **not** a structural validity rule because capacity and its multipliers are deliberately tuned during HPA-631 playtesting.

If a structurally valid save contains positive cargo above the currently configured capacity for that sector/level:

```text
storedAmount = min(storedAmount, content.capacityFor(sectorId, level))
```

Load succeeds without a recovery warning.

This keeps playtest progress usable when balance numbers shrink between builds while still guaranteeing runtime storage invariants.

### Write rules

Write only after successful explicit mutations and lifecycle/screen-exit checkpoints. Never write from the one-second foreground refresh.

## Pure contextual sheet model

`MiningScreen.build()` does not derive affordability, prerequisite copy, busy state, or sale eligibility.

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
    required bool isBusy,
  });
}
```

Rules:

- when `isBusy`, the primary action is disabled with **Finishing previous action…**;
- no selection derives Sell All Cargo availability from total cargo and projected total revenue;
- cargo == 0 disables with no-cargo copy;
- cargo > 0 but `floor(total gross value) == 0` disables with **Keep mining until cargo is worth at least 1 cash.**;
- locked sector derives prerequisite/cost + Reveal;
- revealed empty sector derives resource/rate/capacity/build cost + Build;
- active mine derives level/storage/rate/upgrade delta + Upgrade/max-level state.

Domain tests cover these choices. `MiningActionSheet` renders the view and callback only.

## Flutter presentation

`MiningScreen` is a `StatefulWidget` with `WidgetsBindingObserver`. It owns:

- one `MiningController`;
- one `MiningGame`;
- one `AudioManager`;
- selected `MiningSectorId?`;
- one-second repaint timer.

Canonical portrait stack:

```text
SafeArea
  Stack
    MiningGame
    MiningStatusBar
    MiningActionSheet
    transient confirmation/reward overlays
```

Status shows only cash, sector progress, and cargo status/value.

Primary actions are at least **56 logical px** high. The action sheet is capped around 42% of usable height. Selection focus keeps the selected sector above the sheet.

Automated layout targets:

- 360×640 logical px;
- 430×932 logical px.

The same two sizes also test the modified `MainMenu`, because adding **MINING MVP** creates a sixth fixed-height menu button in the existing non-scrollable menu column.

Landscape gets safe constraints only; no second layout is authored.

## Flame world and camera contract

`MiningGame` is separate from `MainGame`.

Use `ParallaxTerrainComponent(gridSize: 36, seed: 631)` but do **not** depend on its asynchronous `onLoad()` to establish world size before camera fit.

Before `world.add(terrain)`, explicitly set the same geometry that `MainGame` sets:

```dart
final terrain = ParallaxTerrainComponent(gridSize: 36, seed: 631)
  ..parallaxEnabled = false
  ..size = Vector2(1800, 1800)
  ..anchor = Anchor.center
  ..position = Vector2.zero();
```

Then add the authored sector components and compute fit from the explicit 1800×1800 extent and the actual camera viewport.

The initial camera centers on world origin and uses:

```text
fitZoom = min(viewportWidth / 1800, viewportHeight / 1800)
```

clamped by the copied zoom rules.

World tests prove:

- every authored anchor is within -900…+900 bounds;
- at 360×640 initial fit, all three sector anchors project inside the visible viewport;
- selection focus with bottom obstruction shifts the selected sector upward while remaining inside world bounds.

Copy only the minimum fit/pan/zoom logic from `MainGame`; do not extract a shared camera abstraction.

## Existing art and visual tiers

Use existing mine/resource/terrain assets. No asset pipeline is added.

Facility structure:

- level 1: base mine sprite + operation light;
- level 3: level-1 structure + advanced platform + secondary machinery;
- level 5: level-3 structure + elite ring/glow.

Mounted Flame tests assert the actual structural children after `applyState()` at levels 1, 3, and 5. Manual portrait review remains responsible for judging composition and visual quality.

## Reward moments

After controller success only:

1. scanner reveal;
2. mine construction;
3. level-3/5 tier upgrade pulse;
4. cargo sale/cash feedback.

Effects never gate economic state.

Reduced motion replaces large camera/particle movement with fades, short number transitions, and snapped/short camera repositioning. Visible confirmation remains present with audio off.

## Lifecycle and offline return

- foreground: one-second timer calls `refresh()` only when controller is not busy;
- inactive/paused: stop timer and enqueue one checkpoint;
- resumed: serialize resume accrual/checkpoint as needed, refresh presentation, show one return summary, restart timer;
- cold launch: load persisted state and run the same simulation to current UTC;
- screen exit: enqueue one controlled checkpoint when practical.

A killed process does not need periodic saves: cold launch recomputes from the last persisted `lastAccruedAtUtc`.

## Temporary entry point

Add **MINING MVP** near **START EXPEDITION**.

Do not reroute or rename **START EXPEDITION**, remove legacy menu items, or make mining default. HPA-636 owns cutover after HPA-631 records **Proceed to cutover**.

## Early product gate

The first human product test happens as soon as Task 7 produces the runnable core loop, **before** reward-polish/offline-summary work.

On a real portrait mobile target, perform:

1. enter **MINING MVP**;
2. build the Landing Basin gold mine;
3. wait/advance through a real playable sale;
4. sell cargo;
5. upgrade gold;
6. reveal Carbon Ridge.

Answer one question:

> Is the core reveal → mine → sell → upgrade loop worth finishing?

If **no**, stop HPA-631 implementation and record **Stop/reconsider** rather than spending time on reward layers, reduced-motion polish, and the full journey harness.

If **yes**, continue Tasks 8–10. The final HPA-631 product verdict still occurs after complete acceptance evidence.

## Testing strategy

### Core/unit

Prove:

- content identity, balance, and world-anchor bounds;
- level rate/capacity math;
- deterministic elapsed accrual, storage cap, 8-hour cap, and clock rollback;
- strict save structure;
- over-capacity positive cargo clamps without recovery;
- explicit actions validate before mutation;
- queued concurrent/double actions serialize and cannot overwrite earlier success;
- passive refresh does not persist;
- Sell All floors total gross value once;
- `MiningSheetView` handles busy/no-cargo/sub-$1/affordability states.

### World/widget

Prove:

- mounted world loads all three sectors;
- level 1/3/5 structural children differ;
- all anchors are visible at initial 360×640 fit;
- selection focus respects bottom obstruction;
- MiningScreen has no overflow at 360×640 and 430×932;
- MainMenu with six buttons has no overflow at the same sizes;
- primary buttons are ≥56 px;
- recovery/offline summary appears once;
- reduced-motion mode preserves confirmation.

### Integration

Use the real `MiningScreen`, controller, repository, simulation, and world with mocked SharedPreferences and an injected UTC clock. Walk visible controls through first mine, sales/upgrades, all three sectors, mixed cargo sale, checkpoint, dispose, and offline recreate. Do not inject cash or call controller shortcuts.

## Risks and gates

### Risk 1: overlapping async actions lose successful state

Mitigation: serialize every async mutation/checkpoint through one controller future chain, expose `isBusy`, skip refresh while busy, and test with a Completer-backed delayed repository.

### Risk 2: balance tuning invalidates playtest saves

Mitigation: structural corruption resets; positive cargo above newly tuned capacity clamps without warning. Test both classes separately.

### Risk 3: terrain/grid coordinate mismatch produces a blank or badly fitted world

Mitigation: lock 36×36 × 50px world geometry, store anchors in centered world pixels, size terrain explicitly before fit, and test all anchors inside the initial portrait viewport.

### Risk 4: product invalidation arrives after polish cost

Mitigation: mandatory stop/continue portrait playtest immediately after the first runnable Task 7 loop.

### Risk 5: tiny/mixed cargo produces confusing sale values

Mitigation: floor total gross value once; use total cargo for no-cargo detection; disable sub-$1 sales in `MiningSheetView` with explicit copy.

### Risk 6: sixth menu button overflows small portrait screens

Mitigation: run the existing menu at 360×640 and 430×932 in Task 7 tests.

## One-PR delivery

All implementation and review fixes remain on the existing HPA-631 branch and draft PR. Use focused commits for reviewability, not child PRs.

## Explicit non-goals

- product cutover or city deletion;
- technology;
- second planet / multi-planet save;
- processing/refining;
- retention systems;
- dynamic markets or resource buying;
- workers/housing/services/logistics/power/depletion;
- schema migration, backup rotation, forensic recovery, cloud save;
- controller/camera/content frameworks;
- new asset pipeline.

## Acceptance mapping

HPA-631 is complete only when:

- three typed sectors share one mining path;
- gold/coal/stone reuse existing resource identity and one simulation path;
- the first mine and first sale are understandable in the opening session;
- async mutations are serialized and cannot overwrite one another;
- foreground/resume/cold launch share deterministic elapsed-time accrual;
- storage/rollback/8-hour cap are tested;
- the strict save round-trips, ignores city keys, clamps only tunable over-capacity cargo, and resets structural corruption;
- Sell All floors once across total value and clears mixed cargo atomically;
- level 1/3/5 presentation is structurally distinct and visually reviewed;
- scanner/build/upgrade/sale rewards have reduced-motion equivalents;
- MiningScreen and the modified MainMenu fit 360×640 and 430×932;
- the real full journey and offline return pass;
- repository format/analyze/test/web/APK/build gates pass;
- the final HPA-631 comment records build/device observations and exactly one decision: **Proceed to cutover**, **Revise once**, or **Stop/reconsider**.
