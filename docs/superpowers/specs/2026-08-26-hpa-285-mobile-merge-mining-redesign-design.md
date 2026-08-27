# HPA-285 Horologium Mobile Merge-Mining Redesign Design

## Status

Implementation design for Linear HPA-285, **Ship the Horologium mobile merge-mining redesign**.

Planning, implementation, review, cutover, cleanup, and verification stay on **one branch and one pull request**. The prototype ZIP attached manually to HPA-285 is the visual and interaction reference. The repository catalog and this design remain authoritative where the prototype contains placeholder copy or example values.

This revision is grounded on `main` commit `d022ce7a5214e3b13c80759fbd61e70ccc98df70` and incorporates the design review that rejected a duplicate `lib/mining/domain/` stack.

## Review disposition

The review is accepted with the following concrete changes:

- evolve the existing mining catalog/state/simulation/repository/controller **in place** instead of copying them into a second domain;
- keep globally unique site IDs and a flat `sites` save map; add a separate per-planet `docks` map;
- preserve `MiningController.refresh()` and the current best-effort initial persistence for missing/recovered saves;
- extend the existing `TechnologySheetView` / `StellarMapView` in `lib/mining/mining_progression_views.dart` rather than creating a parallel progression file;
- reuse the current controller-test clock and concrete repository subclasses instead of introducing a repository interface or `implements` fake;
- make site capacity explicitly independent of deployed rig count/tier;
- treat the twelve missing Lunar/Mars cavern/node PNGs as a hard external input gate, not an implementation step;
- add risks for the art gap, refresh/persistence regressions, and the faster post-upgrade economy;
- delete or retarget all old flat-domain and presentation tests as part of cutover, including `mining_sheet_view_test.dart` and `mining_progression_views_test.dart`.

The old Flame presentation may be temporarily broken by intermediate in-place domain commits. That is acceptable on this pre-release branch. Focused tests gate those commits; the full Flutter suite becomes mandatory again at the production cutover commit. No dual-stack runtime or duplicate mining catalog is introduced merely to keep every intermediate commit globally green.

## Goal

Replace the current one-mine-per-sector Flame world with a mobile-first merge-mining loop:

```text
Launch
  -> Start / Continue
  -> Site Deck
      -> inspect sites and active-planet totals
      -> spawn and merge planet-local rigs
      -> unlock and enter a site
  -> Mine Site
      -> deploy and recall rigs
      -> accrue deterministic cargo
      -> sell active-planet cargo
      -> rotate portrait/landscape without losing state
  -> Technology / Stellar Map / Settings
  -> unlock Lunar Frontier and Mars Frontier
  -> commission all nine sites and complete Mars mastery
```

The product remains a casual idle mining game. Merge and deployment add one visible progression layer; they do not add workers, crafting, finite deposits, dynamic markets, another currency, prestige, or live-service chores.

## Current reusable baseline

The current production boundary is:

```text
MainMenu
  -> MiningScreen
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
          -> MiningContentRegistry
      -> MiningSheetView / TechnologySheetView / StellarMapView
      -> MiningGame -> ParallaxTerrainComponent
```

The redesign keeps the proven ownership and changes the interaction/state model:

- `MiningContentRegistry` already owns all nine site identities, rates, capacities, sale values, technology tables, offline caps, planet requirements, and Mars reward metadata.
- `MiningSave` / `TechnologyLevels` already provide immutable state values.
- `MiningSaveRepository` already owns strict `hasExactKeys` decoding, generic raw preference reads, invalid-save recovery, and cargo clamping.
- `MiningSimulation` already owns deterministic multi-planet elapsed-time accrual, rollback behavior, offline caps, and per-planet summaries.
- `MiningController` already owns `_enqueueMutation`, save-before-publish semantics, `refresh()`, best-effort initial save persistence, active-planet selling, technology, planet progression, and mastery reward logic.
- `MiningScreen` already owns the one-second timer, `AudioManager`, lifecycle observer, reduced-motion propagation, and read-only test handles.

Do not duplicate these classes under another folder. Modify or rename the existing files in place.

## Selected architecture

### One shell and three logical surfaces

Rename/evolve `MiningScreen` into `MiningShell` and keep it as the single runtime owner.

Implement:

1. `SiteDeckScreen` — active-planet overview, site cards, fleet dock, spawn/merge entry point.
2. `MineSiteScreen` — one responsive screen with portrait and landscape compositions.
3. `StellarMapScreen` — full-screen planet progression, unlock, and travel.

Keep `TechnologySheet`, `MiningSettingsSheet`, and `OfflineReturnSheet` as focused modal surfaces.

```text
MainMenu
  -> MiningShell
      -> MiningController
          -> MiningSimulation
          -> MiningSaveRepository
          -> MiningContentRegistry
      -> FleetDockView / SiteDeckView / MineSiteView
      -> TechnologySheetView / StellarMapView
      -> SiteDeckScreen / MineSiteScreen / StellarMapScreen
      -> TechnologySheet / MiningSettingsSheet / OfflineReturnSheet
```

`MiningShell` owns:

- one controller and current display snapshot;
- one `AudioManager`;
- one lifecycle observer;
- one one-second refresh timer;
- current primary surface and open site;
- selected dock bay;
- offline-return presentation;
- transient action feedback.

`MiningShellHandles` is the renamed successor of the current `MiningScreenHandles` test seam and exposes the same long-lived controller/audio identities.

Do not add Provider, Riverpod, Bloc, `ChangeNotifier`, a service locator, command bus, routing package, generic screen registry, or design-system package. Local navigation is one enum/value in the shell.

### Flutter replaces Flame

Build Mine Site with Flutter `Stack`, `LayoutBuilder`, anchored tap targets, `AnimatedSwitcher`, and short opacity/scale effects. It needs no camera, collision, physics, pathfinding, or frame-authoritative economy.

Delete `MiningGame`, mining Flame components, and the terrain closure only after repository import search proves no surviving consumer. Remove the `flame` dependency only after that closure is gone.

### Final production layout

Keep the small flat mining core because it already exists and has one owner per file:

```text
lib/mining/
  mining_content.dart
  mining_state.dart
  mining_simulation.dart
  mining_save_repository.dart
  mining_controller.dart
  fleet_dock_view.dart
  site_deck_view.dart
  mine_site_view.dart
  mining_progression_views.dart
  presentation/
    mining_shell.dart
    mining_theme.dart
    mining_visuals.dart
    mining_navigation.dart
    mining_hud.dart
    fleet_dock.dart
    site_deck_screen.dart
    mine_site_screen.dart
    stellar_map_screen.dart
    technology_sheet.dart
    mining_settings_sheet.dart
    offline_return_sheet.dart
```

There is one `MiningContentRegistry`, `MiningSave`, `MiningSimulation`, `MiningSaveRepository`, and `MiningController` throughout the branch.

## Closed identity and authored content

Rename the globally unique sector identity to site identity in the existing catalog:

```dart
enum MiningPlanetId { homeworld, lunarFrontier, marsFrontier }

enum MiningSiteId {
  landingBasin,
  carbonRidge,
  graniteCrater,
  frozenBasin,
  titaniumHighlands,
  heliumMare,
  ochreBasin,
  silicaDunes,
  cobaltChasm,
}

enum MiningNodeId { n1, n2, n3, n4 }
enum RigTier { t1, t2, t3, t4, t5 }
enum TechnologyTrack { extraction, logistics, surveying }
```

Node IDs repeat inside each site's `rigByNode` map. No rig UUID or global node ID is needed.

### Catalog changes in place

Evolve `MiningSectorDefinition` into `MiningSiteDefinition` and preserve the current source-of-truth numbers.

Keep:

- resource identity;
- site name;
- unlock/prerequisite chain (`revealCost` becomes site unlock cost);
- `requiredSurveyingLevel`;
- `baseRatePerSecond`;
- `baseCapacity`;
- `saleValuePerUnit`;
- planet unlock requirements and Mars mastery reward;
- technology costs/gates;
- Extraction multipliers;
- Logistics capacity multipliers;
- offline caps.

Remove when their final consumers disappear:

- mine `buildCost`;
- mine `upgradeCosts`;
- `MiningWorldAnchor`;
- `terrainSeed` / `tint` used only by the retired Flame world;
- old mine sprite fields used only by `MiningGame`.

The current `MiningContentRegistry.rateMultipliers` table becomes the rig tier multiplier table; do not author a second copy of `1.00, 1.50, 2.25, 3.25, 4.50`. The old mine-level `capacityMultipliers` table is removed because rig tiers no longer scale storage.

### Rig ladder and spawn costs

| Tier | Production multiplier | T1 rigs represented |
| --- | ---: | ---: |
| T1 | 1.00 | 1 |
| T2 | 1.50 | 2 |
| T3 | 2.25 | 4 |
| T4 | 3.25 | 8 |
| T5 | 4.50 | 16 |

Two same-tier docked rigs merge into the next tier in the tapped destination bay; the source becomes empty. T5 is terminal. Merging is dock-only.

Each planet has four dock bays and one authored T1 spawn cost:

| Planet | T1 spawn cost | Starter dock when first unlocked |
| --- | ---: | --- |
| Homeworld | 25 | T1, T1, empty, empty |
| Lunar Frontier | 500 | T1, T1, empty, empty |
| Mars Frontier | 5,000 | T1, T1, empty, empty |

Fleets are planet-local and never transfer between planets.

### Planet progression

| Planet | Required mastery | Surveying | Unlock cash | Mastery reward |
| --- | --- | ---: | ---: | ---: |
| Homeworld | none | 0 | 0 | 0 |
| Lunar Frontier | Homeworld | 3 | 2,500 | 0 |
| Mars Frontier | Lunar Frontier | 5 | 20,000 | 25,000 |

Keep the catalog name **Mars Frontier**. `Rust Belt` is prototype placeholder copy.

Unlocking Lunar or Mars seeds its two T1 rigs, unlocks its first site, and makes the planet active in the same saved mutation.

### Sites

The old build and mine-upgrade cash sinks disappear because rigs now own throughput progression. Preserve the nine current site values as the starting balance:

| Site | Resource | Prerequisite | Surveying | Unlock | Base rate/s | Base capacity | Sale/unit |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Landing Basin | Gold | none | 0 | 0 | 0.50 | 90 | 4 |
| Carbon Ridge | Coal | Landing Basin | 0 | 250 | 0.75 | 120 | 3 |
| Granite Crater | Stone | Carbon Ridge | 0 | 700 | 0.60 | 120 | 5 |
| Frozen Basin | Water Ice | none | 3 | 0 | 1.00 | 150 | 6 |
| Titanium Highlands | Titanium Ore | Frozen Basin | 4 | 3,000 | 0.80 | 140 | 12 |
| Helium Mare | Helium-3 | Titanium Highlands | 5 | 8,000 | 0.55 | 120 | 30 |
| Ochre Basin | Iron Ore | none | 5 | 0 | 0.75 | 180 | 32 |
| Silica Dunes | Silica | Ochre Basin | 5 | 12,000 | 0.55 | 160 | 55 |
| Cobalt Chasm | Cobalt Ore | Silica Dunes | 5 | 30,000 | 0.35 | 130 | 110 |

First sites are unlocked with their planet. Later sites require the prerequisite site unlocked, authored Surveying level, and cash.

### Node availability

Every site has four fixed nodes. Node availability is authored, not procedural:

| Site | n1 | n2 | n3 | n4 |
| --- | ---: | ---: | ---: | ---: |
| Landing Basin | 0 | 0 | 1 | 2 |
| Carbon Ridge | 0 | 1 | 2 | 3 |
| Granite Crater | 0 | 1 | 2 | 3 |
| Frozen Basin | 3 | 3 | 4 | 5 |
| Titanium Highlands | 4 | 4 | 5 | 5 |
| Helium Mare | 5 | 5 | 5 | 5 |
| Ochre Basin | 5 | 5 | 5 | 5 |
| Silica Dunes | 5 | 5 | 5 | 5 |
| Cobalt Chasm | 5 | 5 | 5 | 5 |

Technology costs remain `300, 700, 1,500, 4,000, 9,000`. Levels 1-5 are gated by commissioned Landing Basin, Carbon Ridge, Granite Crater, Frozen Basin, and Titanium Highlands respectively.

Keep current Extraction multipliers `1.00, 1.10, 1.25, 1.45, 1.70, 2.00`, Logistics capacity multipliers `1.00, 1.15, 1.30, 1.50, 1.75, 2.00`, and offline caps `8h, 10h, 12h, 16h, 20h, 24h` as starting balance.

## Mutable state: flat sites plus planet docks

Do not nest site progress beneath planet progress. Planet ownership is already authored by `planetForSite` and every `MiningSiteId` is globally unique.

```dart
class SiteProgress {
  final bool unlocked;
  final bool commissioned;
  final double storedAmount;
  final Map<MiningNodeId, RigTier?> rigByNode; // exactly n1-n4
}

class MiningSave {
  final int cash;
  final DateTime lastAccruedAtUtc;
  final TechnologyLevels technology;
  final Set<MiningPlanetId> unlockedPlanetIds;
  final MiningPlanetId activePlanetId;
  final Map<MiningPlanetId, List<RigTier?>> docks; // three keys, four bays each
  final Map<MiningSiteId, SiteProgress> sites;     // exactly nine keys
}
```

Fresh state:

- 100 cash;
- Homeworld unlocked and active;
- Landing Basin unlocked;
- Homeworld dock `[T1, T1, null, null]`;
- Lunar/Mars docks empty while locked;
- no commissioned site, cargo, or deployed rig;
- all other sites locked/pristine.

`commissioned` flips to true on the first successful deployment and never reverses. Planet mastery means every authored site for that planet is commissioned. Recall cannot revoke mastery.

All values are immutable and copied atomically. Selection, current screen, orientation, hints, and animation state are not persisted.

## Deterministic simulation and capacity invariant

For every unlocked site with deployed rigs:

```text
siteRate = site.baseRatePerSecond * sum(rateMultipliers[tier])
siteRate *= extractionMultiplier
siteCapacity = site.baseCapacity * logisticsCapacityMultiplier
produced = min(siteRate * elapsedSeconds, siteCapacity - storedAmount)
```

**Capacity invariant:** deployed rig count and rig tier affect throughput only. They never scale site capacity. All four nodes share one site store. Logistics is the only multiplicative capacity progression.

Rules:

- docked rigs produce nothing;
- all unlocked planets produce while inactive;
- locked sites or sites with no deployed rig produce nothing;
- storage never exceeds effective site capacity;
- clock rollback produces zero and never moves the timestamp backward;
- elapsed time is capped by Logistics and then advances the timestamp to `nowUtc`;
- equal state plus equal `nowUtc` yields equal output.

`OfflineProductionSummary` retains the current shape but renames `fullSectors` to `fullSites`.

### Live foreground accrual is required

The one-second timer is presentation infrastructure, but it must still advance in-memory economy state exactly as the current screen does:

```dart
Timer.periodic(const Duration(seconds: 1), (_) {
  if (!_controller.isBusy) {
    _controller.refresh();
    _refreshPresentation();
  }
});
```

`MiningController.refresh()` remains non-persisting. It accrues from `_state` to the injected current UTC and publishes the in-memory result. The timer must not merely re-project `controller.state`, or cargo will appear frozen until another action/checkpoint.

## Serialized controller

Keep the current future-chain queue and existing initialization/refresh semantics.

### Initialization contract

`initialize()` must continue to:

1. load the new save key;
2. preserve `recoveredFromInvalidSave`;
3. accrue to current UTC;
4. queue the resulting offline summary for one-time presentation when production occurred;
5. best-effort persist the newly constructed state when the key was missing or recovery produced a fresh save.

The fifth step is required so a first entry followed by an immediate back-to-menu cannot race `hasSave()` against an unawaited dispose checkpoint.

A failure of this convenience write does not brick initialization; the in-memory fresh/recovered state remains playable and the next mutation/checkpoint retries persistence.

### Required actions

```dart
Future<MiningActionResult> unlockSite(MiningSiteId siteId);
Future<MiningActionResult> spawnRig();
Future<MiningActionResult> mergeDockRigs(int sourceBay, int targetBay);
Future<MiningActionResult> deployRig(
  int sourceBay,
  MiningSiteId siteId,
  MiningNodeId nodeId,
);
Future<MiningActionResult> recallRig(
  MiningSiteId siteId,
  MiningNodeId nodeId,
);
Future<MiningActionResult> purchaseTechnology(TechnologyTrack track);
Future<MiningActionResult> unlockPlanet(MiningPlanetId planetId);
Future<MiningActionResult> switchPlanet(MiningPlanetId planetId);
Future<MiningSaleResult> sellAllCargo();
Future<void> checkpoint({bool accrue = true});
Future<OfflineProductionSummary?> resume();
```

Specific rules:

- Spawn uses the first empty active-planet bay and fails for full dock or insufficient cash.
- Merge requires distinct occupied same-tier bays and rejects T5.
- Deploy requires active-planet ownership, an unlocked site, available empty node, and occupied source bay; the rig moves atomically.
- Recall requires an occupied node and first empty active-planet bay; full dock is a non-mutating failure.
- Site unlock preserves prerequisite, Surveying, and cash checks.
- Technology gates use commissioned sites.
- Planet unlock preserves current mastery, Surveying, and cash requirements and seeds the first site/fleet.
- Travel only changes active planet after accrual and save.
- Sell All clears all active-planet site cargo and floors aggregate gross value once.
- Zero cargo fails without mutation; UI disables positive cargo worth less than one cash.
- The 25,000 Mars reward is granted only when `deployRig` changes Mars mastery false -> true by commissioning the final uncommissioned site. Sticky `commissioned` state makes recall/redeploy ineligible for another reward.

Queued duplicate actions and save failures must never copy, lose, or publish a moved rig.

## Persistence

Use one fresh key:

```text
horologium.mergeMining.save
```

Do not read, migrate, convert, or delete `horologium.mining.save`. Main Menu Start/Continue checks only the new key. This is an intentional pre-release breaking redesign.

The root document is exactly:

```text
cash
lastAccruedAtUtc
technology { extraction, logistics, surveying }
unlockedPlanetIds
activePlanetId
docks
  exactly homeworld, lunarFrontier, marsFrontier
    each exactly four nullable tier names
sites
  exactly the nine MiningSiteId names
    unlocked
    commissioned
    storedAmount
    rigByNode { exactly n1, n2, n3, n4 }
```

This retains the current flat identity model: site ownership stays in the catalog and is not repeated in save nesting.

Structural invalidity resets to fresh state and reports recovery:

- malformed JSON, wrong types, extra/missing keys, unknown/duplicate enum strings;
- negative/non-integer cash or invalid/non-UTC timestamp;
- technology outside 0-5;
- dock length other than four or unknown tier;
- active planet not unlocked or Homeworld not unlocked;
- locked planet with any docked rig or non-pristine site;
- locked site with commission, cargo, or deployed rig;
- commissioned site not unlocked;
- later site unlocked while prerequisite is locked;
- first site locked on an unlocked planet;
- deployed rig on a node above the saved Surveying level;
- negative/non-numeric cargo.

The only tolerant normalization is:

```text
storedAmount = min(storedAmount, effectiveSiteCapacity(site, logistics))
```

Keep the current repository patterns: `hasExactKeys`, generic raw preference read before String cast, clean recovery, and concrete repository type. Add no repository interface.

## Pure projections

Widgets do not derive eligibility, economy totals, or disabled copy.

### New views

Add small flat view files:

- `fleet_dock_view.dart` — exactly four bays, selected/tier state, merge destinations, spawn cost/reason, contextual hint.
- `site_deck_view.dart` — cash, active planet, commissioned progress, active-planet cargo/capacity/value/rate, fleet dock, site cards.
- `mine_site_view.dart` — selected site, four nodes, node Surveying/rig/rate/action/reason, site cargo, planet sale projection, fleet dock.

`MiningSiteCardState` is exactly:

```dart
enum MiningSiteCardState { locked, available, idle, operational }
```

### Existing progression views are extended

Keep `lib/mining/mining_progression_views.dart` and extend its existing `TechnologySheetView` and `StellarMapView`.

- Technology gates read `commissioned` sites rather than mine existence.
- Surveying copy talks about site/node availability as appropriate.
- `StellarMapView._isVisible` keeps the current progressive disclosure: fresh shows Homeworld + Lunar; Mars becomes visible after Lunar is unlocked.
- Planet rows report commissioned sites, active production rate, cargo/capacity/value, site indicators, unlock requirements, and action/busy reason.

Do not create a second progression view module that risks drifting from the current visibility rules.

## Presentation

### Theme reuse

`MiningTheme` lifts current cyan/panel/warning tokens from `MiningStatusBar` and `OfflineReturnSheet`; it does not invent a second palette. Remove undeclared `fontFamily: 'Orbitron'` from `lib/main.dart` and use system typography.

### Site Deck

Full-screen scrollable surface:

- safe-area cash shard;
- active planet + commissioned-site progress;
- aggregate cargo/capacity and rate;
- one card per authored active-planet site;
- horizontal four-bay dock and spawn affordance;
- navigation for Site Deck, Technology, Stellar Map, Settings.

Cards render only projection values.

### Mine Site

One `MineSiteScreen` uses `LayoutBuilder` and shared node anchor constants.

- portrait: HUD top, cavern middle, horizontal dock bottom;
- landscape: cavern left, fixed right fleet rail, compact bottom-left navigation;
- at most one explicit site-specific anchor override is allowed if shared anchors fail a real composition; do not create an anchor framework.

Tap rules:

- occupied bay selects;
- selected bay + same-tier occupied bay merges into tapped destination;
- selected bay + available empty node deploys;
- occupied node recalls;
- cargo/shipping control sells active-planet cargo with no confirmation.

Contextual hints derive from current state and are not persisted.

### Stellar Map

Promote the current sheet projection into a full-screen `StellarMapScreen`. Keep `Mars Frontier`; do not adopt prototype placeholder `Rust Belt`.

### Secondary surfaces

Restyle/adapt Technology, Settings, and Offline Return only as required for the new projections and terminology. Keep `AudioManager` ownership, audio preference keys, first-gesture BGM, lifecycle forwarding, haptics, and `MediaQuery.disableAnimations` as the reduced-motion source.

## Visual asset contract and hard gate

The attached prototype ZIP contains these production inputs:

- Homeworld caverns: gold, coal, stone — `800x1200`;
- Homeworld nodes: gold, coal, stone — `512x512` RGBA;
- Homeworld site cards: basin, ridge, crater — `740x494`;
- planets: Homeworld/Lunar/Mars — `640x640` RGBA;
- workers T1-T5 — `512x512` RGBA;
- cash/cargo/extraction/logistics/merge/surveying icons — `256x256`;
- merge burst — `512x512` RGBA;
- offline hero — `1915x821`.

Map the prototype worker filenames explicitly:

```text
art-worker-t1.png -> mining/rigs/t1.png
art-worker-t2.png -> mining/rigs/t2.png
art-worker-t3.png -> mining/rigs/t3.png
art-worker-t4.png -> mining/rigs/t4.png
art-worker-t5.png -> mining/rigs/t5.png
```

The ZIP does **not** contain Lunar/Mars cavern/node art. The following twelve final PNGs are a hard external input gate:

```text
caverns/water_ice.png      800x1200
nodes/water_ice.png        512x512 RGBA
caverns/titanium_ore.png   800x1200
nodes/titanium_ore.png     512x512 RGBA
caverns/helium_3.png       800x1200
nodes/helium_3.png         512x512 RGBA
caverns/iron_ore.png       800x1200
nodes/iron_ore.png         512x512 RGBA
caverns/silica.png         800x1200
nodes/silica.png           512x512 RGBA
caverns/cobalt_ore.png     800x1200
nodes/cobalt_ore.png       512x512 RGBA
```

These files must be authored outside the Dart implementation loop and committed before Lunar/Mars Mine Site visual completion. The coding task must not generate them, substitute placeholders, or silently fall back to old facility/terrain art. Lunar/Mars Site Deck cards deliberately crop the corresponding final cavern image rather than requiring six additional card files.

Import only the named prototype asset files, not the standalone HTML, duplicate `uploads/` copy, thumbnail, support scripts, or unrelated ZIP content. Use explicit `git add` paths; do not `git add -A` the unpacked ZIP.

## Economy validation

The throughput model is much faster than the old mine-level economy because:

- mine build/upgrade cash sinks are removed;
- four rigs can produce at once;
- T5 affects rate but not capacity.

Example worst case at Landing Basin:

```text
4 x T5, Extraction 5:
rate = 4 * 4.5 * 2.0 * 0.5 = 18 units/s
Logistics 5 capacity = 90 * 2.0 = 180
fill time ~= 10 seconds
```

Do not add a new mechanic to compensate. The representative playtest must record:

- fill time by representative early/mid/late site;
- sell cadence / how often storage caps during normal play;
- number of spawn/merge/sell cycles needed for key unlocks;
- whether Homeworld -> Lunar -> Mars remains reachable without debug state edits.

If storage fills too quickly, tune the existing `baseCapacity` and/or Logistics capacity multipliers first. Other authorized tuning remains spawn cost, site unlock cost, base rate, sale value, and current technology costs/effects. Document any change with observed before/after evidence.

HPA-640 remains canceled. The merge ladder is playtested before any retention work is reconsidered.

## Accessibility and responsive contract

- controls are at least 48x48 logical pixels;
- icon-only actions have semantic labels/tooltips where appropriate;
- state is not color-only;
- critical actions remain reachable at text scale 1.3;
- verify 360x640, 402x874, 430x932 portrait and 874x402 landscape;
- respect safe areas and landscape rail geometry;
- reduced motion removes nonessential translation/scale while retaining feedback;
- muted-audio play remains understandable.

## Testing strategy

### Reuse existing test seams

- Reuse/rename the existing `TestClock` in `test/mining/mining_controller_test.dart` rather than creating a second clock type.
- Continue subclassing concrete `MiningSaveRepository` for delayed/failing/counting behavior. Do not introduce a repository interface or `implements MiningSaveRepository` fake.
- Extend existing controller/simulation/repository tests in place as the domain changes.
- Extend `test/mining/mining_progression_views_test.dart` for new technology/Stellar Map behavior.
- Delete `test/mining/mining_sheet_view_test.dart` when `MiningSheetView` is removed and replacement Site Deck/Mine Site projection tests cover its responsibilities.
- Rename/retarget `test/mining/presentation/mining_screen_test.dart` to shell ownership/lifecycle/refresh coverage rather than constructing a second shell harness from scratch.

### Verification cadence

Because the domain is remodeled in place, focused tests are authoritative before the UI cutover. From the cutover commit onward, the full Flutter suite must pass on every remaining task.

Final verification includes formatting, analyzer, full tests, Chrome tests, APK/web builds, and available iOS simulator build.

## Risks and mitigations

| Risk | Mitigation / proof |
| --- | --- |
| Twelve Lunar/Mars visual files are missing from the ZIP | Hard external-art gate; coding agent never invents or substitutes them; full asset-resolution test blocks completion |
| Shell timer only re-projects state and foreground cargo appears frozen | Preserve `MiningController.refresh()` and assert timer calls refresh before projection |
| Fresh/recovered save is not persisted until dispose, causing Main Menu Continue race | Preserve current `initialize()` best-effort `wasMissing || recoveredFromInvalidSave` save and test immediate enter/back behavior |
| Duplicate catalog/state types drift during cutover | No second domain; modify current files in place and reuse current numeric tables |
| Removing mine-level capacity scaling makes high-tier rigs fill storage in seconds | Capacity invariant is explicit; playtest records fill time/sell cadence and tunes existing capacity/logistics values only |
| In-place domain change temporarily breaks the old Flame route | Accept focused-test-only intermediate commits; restore full-suite green at the single production cutover |
| Flame/terrain cleanup removes a surviving shared consumer | `rg` import closure before deletion and dependency removal |

## Non-goals

Do not add:

- a second mining domain or compatibility facade;
- old-save migration/versioning;
- finite depletion/regeneration/resurvey;
- drag-and-drop;
- rig IDs, equipment stats, rarity, workers, crew, inventory, crafting, processing;
- dynamic prices, contracts, prestige, another currency, retention mechanics;
- server/account/cloud/analytics/remote configuration;
- generic navigation/state-management/design/asset frameworks;
- generated Lunar/Mars production art inside the coding task.

## Acceptance

HPA-285 is ready to merge only when:

- one in-place mining catalog/state/controller/simulation/repository owns the runtime;
- new key persistence is strict, flat, and proven; old key is ignored;
- foreground timer accrual and first-save persistence are covered;
- spawn/merge/deploy/recall/unlock/site commission/technology/planet travel/selling are deterministic and save-backed;
- all nine sites have final cavern/node visual mappings, including the twelve externally authored Lunar/Mars files;
- Site Deck, responsive Mine Site, and full-screen Stellar Map meet geometry/accessibility contracts;
- Technology, Settings, and Offline Return retain their established ownership behavior;
- fresh public-action-only play reaches Mars mastery and the reward occurs once;
- the balance note records fill times and sell cadence, not only reachability;
- old Flame mining/terrain closure and unused dependency are removed after import proof;
- README/CLAUDE describe the final architecture;
- formatting, analysis, tests, and representative builds pass.
