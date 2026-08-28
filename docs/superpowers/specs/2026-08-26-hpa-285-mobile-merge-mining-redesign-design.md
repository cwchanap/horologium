# HPA-285 Horologium Mobile Merge-Mining Redesign Design

## Status

Implementation design for Linear HPA-285, **Ship the Horologium mobile merge-mining redesign**.

Planning, implementation, review, production cutover, cleanup, and verification stay on **one branch and one pull request**. The prototype ZIP attached manually to HPA-285 is the visual and interaction reference. Repository behavior and this design remain authoritative where prototype copy or sample numbers differ.

This revision is grounded on `main` commit `d022ce7a5214e3b13c80759fbd61e70ccc98df70`.

## Latest review disposition

The second design review is accepted with one correction to its capacity formula.

Accepted:

- keep one in-place mining domain; no `lib/mining/domain/` fork;
- keep flat globally unique site progress plus per-planet docks;
- use closed `DockBayId` rather than raw `int` bay indices;
- keep the existing `capacityMultipliers` table and make deployed rigs scale storage as well as throughput;
- move per-site visual asset paths onto `MiningSiteDefinition`; keep shared node anchors in presentation constants;
- evolve `mining_status_bar.dart` into `mining_hud.dart` instead of creating a parallel HUD and deleting the old status widget;
- split Homeworld/common asset validation from the missing Lunar/Mars asset gate;
- cut the old Flame/terrain/presentation runtime out early once the remodeled core is coherent, then keep the full repository green while the new screens are built;
- isolate shell ownership, Site Deck, Mine Site, and Stellar Map into separate commits inside the same PR.

Capacity formula correction:

The review proposed dividing summed capacity shares by four. That would make one deployed T1 rig hold only one quarter of the current L1 mine capacity even though the design preserves the current `baseCapacity` numbers. The redesign instead treats each deployed rig as one replacement extraction/storage unit:

```text
siteRate = baseRatePerSecond
         * extractionRateMultiplier
         * Σ rateMultipliers[tier]

siteCapacity = baseCapacity
             * logisticsCapacityMultiplier
             * Σ capacityMultipliers[tier]
```

There is **no `/4` normalization**.

This preserves the current per-unit fill-time curve:

```text
one T1 rig        ~= current L1 mine fill time
four T1 rigs      ~= same fill time, ~4x full cargo
one T5 rig        ~= current L5 mine fill time
four T5 rigs      ~= same fill time, ~4x full cargo
```

For Landing Basin at Extraction 5 / Logistics 5:

```text
4 x T1: rate 4.0/s, capacity 720, fill ~= 180s
4 x T5: rate 18.0/s, capacity 2880, fill ~= 160s
```

That keeps offline/check-in cargo meaningful relative to the current economy and makes merged rigs improve the amount earned per capped return rather than merely shortening an already-short fill window.

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

The current runtime already provides the ownership seams to preserve:

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

Reuse rather than recreate:

- `MiningContentRegistry` as the sole catalog for nine sites, economy tables, technology, planet requirements, and Mars reward;
- `TechnologyLevels` and immutable `MiningSave` conventions;
- `MiningSaveRepository` strict `hasExactKeys`, generic raw read, recovery, and capacity clamp behavior;
- `MiningSimulation` deterministic elapsed-time, rollback, offline-cap, and multi-planet summary behavior;
- `MiningController` `_enqueueMutation`, save-before-publish, `refresh()`, missing/recovered initial persistence, active-planet sale, technology, planet unlock/travel, and mastery reward pattern;
- `MiningProgressionViews` progressive Stellar Map disclosure;
- `MiningScreen` ownership of one controller, one timer, one `AudioManager`, lifecycle, reduced motion, and test handles;
- current HUD/offline cyan/panel/warning presentation tokens.

Do not duplicate any of these classes or tables.

## Selected architecture

### One shell and three logical surfaces

Rename/evolve `MiningScreen` into `MiningShell` and keep it as the single runtime owner.

Final player surfaces:

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

`MiningShell` owns exactly:

- one controller and display snapshot;
- one `AudioManager`;
- one lifecycle observer;
- one one-second foreground refresh timer;
- current primary surface and open site;
- selected dock bay;
- offline-return presentation;
- transient action feedback.

`MiningShellHandles` is the renamed successor of `MiningScreenHandles` and exposes the same long-lived controller/audio identities for tests.

Do not add Provider, Riverpod, Bloc, `ChangeNotifier`, a service locator, command bus, routing package, generic screen registry, repository interface, or design-system package.

### Flutter replaces Flame

Mine Site uses Flutter `Stack`, `LayoutBuilder`, anchored tap targets, `AnimatedSwitcher`, and short opacity/scale effects. It needs no camera, collision, physics, pathfinding, or frame-authoritative economy.

Once the remodeled core controller compiles, cut `MiningScreen` to a thin `MiningShell` owner and delete the old Flame world/presentation closure early. Repository search already shows `ParallaxTerrainComponent` has one production consumer, `lib/mining/world/mining_game.dart`; after that world is gone, delete the now-orphaned terrain closure and remove `flame` when `rg "package:flame" lib test` is empty.

This restores `flutter analyze` / `flutter test` before the new visual surfaces are complete instead of keeping a red dual-stack branch behind an external art dependency.

## Final production layout

Keep the small flat core:

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
    mining_hud.dart          # renamed/evolved mining_status_bar.dart
    fleet_dock.dart
    site_deck_screen.dart
    mine_site_screen.dart
    stellar_map_screen.dart
    technology_sheet.dart
    mining_settings_sheet.dart
    offline_return_sheet.dart
```

There is one current `MiningContentRegistry`, `MiningSave`, `MiningSimulation`, `MiningSaveRepository`, and `MiningController` throughout the PR.

## Closed identity

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
enum DockBayId { b1, b2, b3, b4 }
enum RigTier { t1, t2, t3, t4, t5 }
enum TechnologyTrack { extraction, logistics, surveying }
```

`DockBayId` and `MiningNodeId` make both fixed four-slot structures closed and exact-key-decodable. Controller/view APIs use these enums instead of unvalidated integers.

No rig UUID or global node identity is needed.

## Authored content in one table

Evolve `MiningSectorDefinition` into `MiningSiteDefinition` in `lib/mining/mining_content.dart`.

```dart
class MiningSiteDefinition {
  const MiningSiteDefinition({
    required this.id,
    required this.name,
    required this.resource,
    required this.unlockCost,
    required this.requiredSite,
    required this.requiredSurveyingLevel,
    required this.baseRatePerSecond,
    required this.baseCapacity,
    required this.saleValuePerUnit,
    required this.nodes,
    required this.cavernAsset,
    required this.nodeAsset,
    required this.cardAsset,
    this.facilityName,
    this.discoveryText,
  });

  final MiningSiteId id;
  final String name;
  final ResourceType resource;
  final int unlockCost;
  final MiningSiteId? requiredSite;
  final int requiredSurveyingLevel;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<MiningNodeDefinition> nodes;
  final String cavernAsset;
  final String nodeAsset;
  final String cardAsset;
  final String? facilityName;
  final String? discoveryText;
}
```

This replaces the old `mineAsset`/world-anchor fields rather than creating a second nine-row visual catalog.

`MiningPlanetDefinition` keeps one row per planet and adds only:

```dart
final int rigSpawnCost;
final String planetAsset;
```

alongside existing unlock/mastery metadata and the list of sites.

Keep `mining_content.dart` as the only per-site/per-planet authored table. It already imports Flutter Material types for silhouettes/colors, so asset-path strings do not create a new layering problem.

### Shared presentation assets

`mining_visuals.dart` owns only cross-site presentation constants:

- one shared portrait four-node `Alignment` list;
- one shared landscape four-node `Alignment` list;
- at most one explicit site anchor override when a real composition proves necessary;
- rig asset mapping `T1..T5` from the prototype `art-worker-t*.png` files;
- cash/cargo/merge/technology/effect/offline shared asset constants.

It does **not** own another `Map<MiningSiteId, MiningSiteVisuals>`.

### Rig ladder and capacity shares

Reuse both current mine-level tables as rig tables:

```text
rateMultipliers     = [1.00, 1.50, 2.25, 3.25, 4.50]
capacityMultipliers = [1.00, 1.50, 2.00, 3.00, 4.00]
```

Two same-tier docked rigs merge into the next tier in the tapped destination bay; the source becomes empty. T5 is terminal. Merging is dock-only.

Each planet has four bays and an authored T1 spawn cost:

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

Unlocking Lunar or Mars seeds its two T1 rigs, unlocks its first site, and makes the planet active in one saved mutation.

### Site starting values

Old build and upgrade costs disappear because rigs now own throughput/storage progression. Preserve current resource, unlock, rate, capacity, and sale values as the initial balance:

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

Every site has four fixed nodes:

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

Keep current Extraction multipliers `1.00, 1.10, 1.25, 1.45, 1.70, 2.00`, Logistics multipliers `1.00, 1.15, 1.30, 1.50, 1.75, 2.00`, and offline caps `8h, 10h, 12h, 16h, 20h, 24h` as starting balance.

## Mutable state: flat sites plus enum-keyed docks

Planet ownership remains authored by `planetForSite`; it is not duplicated by nesting sites under planets.

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
  final Map<MiningPlanetId, Map<DockBayId, RigTier?>> docks;
  final Map<MiningSiteId, SiteProgress> sites;
}
```

Fresh state:

- 100 cash;
- Homeworld unlocked and active;
- Landing Basin unlocked;
- Homeworld dock `{b1:T1, b2:T1, b3:null, b4:null}`;
- Lunar/Mars docks all-null while locked;
- no commissioned site, cargo, or deployed rig;
- all other sites locked/pristine.

`commissioned` flips on the first successful deployment and never reverses. Planet mastery means every authored site for that planet is commissioned. Recall cannot revoke mastery.

Selection, current screen, orientation, hints, and animation state are not persisted.

## Deterministic simulation

For every unlocked site with deployed rigs:

```text
rateShare     = Σ rateMultipliers[tier]
capacityShare = Σ capacityMultipliers[tier]

siteRate = baseRatePerSecond
         * extractionRateMultiplier
         * rateShare

siteCapacity = baseCapacity
             * logisticsCapacityMultiplier
             * capacityShare

produced = min(siteRate * elapsedSeconds, siteCapacity - storedAmount)
```

Rules:

- no deployed rig means zero production and zero effective capacity;
- docked rigs produce and store nothing for that site;
- all unlocked planets accrue while inactive;
- locked sites or sites with no deployed rig produce nothing;
- storage never exceeds the capacity implied by the currently deployed rigs;
- clock rollback produces zero and never moves the timestamp backward;
- elapsed time is capped by Logistics and then advances the timestamp to `nowUtc`;
- equal state plus equal `nowUtc` yields equal output;
- `OfflineProductionSummary.fullSectors` is renamed `fullSites`.

### Recall capacity safety

Because deployed rigs now contribute storage capacity, recall must never silently destroy cargo.

Before recalling a rig:

```text
postRecallCapacity = capacity from the rigs that would remain deployed
```

Reject recall when:

```text
storedAmount > postRecallCapacity
```

with presentation-ready copy equivalent to **Sell cargo before recalling this rig.**

This keeps the persisted invariant `storedAmount <= effectiveSiteCapacity` true without adding a `maxCapacitySeen` field or a cargo-loss normalization path. After selling, the player can recall freely. Recalling the last rig is therefore allowed when site cargo is zero.

### Live foreground accrual remains required

The one-second timer is presentation infrastructure, but it must still call the existing non-persisting `MiningController.refresh()` before projection:

```dart
Timer.periodic(const Duration(seconds: 1), (_) {
  if (!_controller.isBusy) {
    _controller.refresh();
    _refreshPresentation();
  }
});
```

A timer that only re-reads `controller.state` is incorrect because cargo would appear frozen until another action/checkpoint.

## Serialized controller

Keep the current future-chain mutation queue and initialization semantics.

### Initialization contract

`initialize()` continues to:

1. load the new key;
2. preserve `recoveredFromInvalidSave`;
3. accrue to current UTC;
4. expose one pending offline summary when production occurred;
5. best-effort persist the new initial/recovered state when `wasMissing || recoveredFromInvalidSave`.

That last write preserves the current Main Menu race fix: entering a fresh game and immediately backing out must still make Continue visible even if dispose checkpoint has not finished.

### Controller actions

```dart
Future<MiningActionResult> unlockSite(MiningSiteId siteId);
Future<MiningActionResult> spawnRig();
Future<MiningActionResult> mergeDockRigs(
  DockBayId sourceBay,
  DockBayId targetBay,
);
Future<MiningActionResult> deployRig(
  DockBayId sourceBay,
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

- Spawn uses `DockBayId.values.firstWhere` for the first empty active-planet bay.
- Merge requires distinct occupied same-tier bays and rejects T5.
- Deploy requires active-planet ownership, unlocked site, available empty node, and occupied source bay; the rig moves atomically.
- First deployment makes the site commissioned.
- Recall uses the first empty active dock bay and applies the post-recall capacity safety rule before saving.
- Site unlock preserves prerequisite, Surveying, and cash checks.
- Technology gates use commissioned sites.
- Planet unlock preserves current mastery/Surveying/cash requirements, seeds its dock/first site, and makes it active.
- Travel accrues, saves, then changes active planet.
- Sell All clears all active-planet site cargo and floors aggregate gross value once.
- Zero cargo fails without mutation; UI disables positive cargo worth less than one cash.
- The 25,000 Mars reward moves from `buildMine` to the false-to-true mastery transition caused by the final first commission. Recall/redeploy never pays again.

Queued duplicate actions and failed saves must never copy, lose, or publish a moved rig.

## Persistence

Use one fresh key:

```text
horologium.mergeMining.save
```

Do not read, migrate, convert, or delete `horologium.mining.save`.

The root keys are exactly:

```text
cash
lastAccruedAtUtc
technology
unlockedPlanetIds
activePlanetId
docks
sites
```

`docks` contains exactly three planet keys. Each planet value is an object with exactly `b1`, `b2`, `b3`, `b4`, each nullable or a valid rig tier.

`sites` contains exactly all nine globally unique site keys. Each site value has exactly:

```text
unlocked
commissioned
storedAmount
rigByNode
```

and `rigByNode` has exactly `n1`, `n2`, `n3`, `n4`.

Both four-slot maps reuse `hasExactKeys`; there is no separate length-index validation path.

Structural invalidity resets to fresh state and reports recovery:

- malformed JSON, wrong types, extra/missing keys, unknown enum strings;
- negative/non-integer cash or invalid/non-UTC timestamp;
- technology outside 0-5;
- active planet not unlocked or Homeworld not unlocked;
- locked planet with any rig or non-pristine site;
- locked site with commission/cargo/rigs;
- commissioned site not unlocked;
- later site unlocked while prerequisite is locked;
- first site locked on an unlocked planet;
- deployed rig above saved Surveying availability;
- negative/non-numeric cargo;
- cargo above current effective capacity after normalization rules are applied.

As today, structurally valid over-capacity cargo caused by balance tuning may clamp to current effective capacity without marking recovery. Normal controller actions must never create that condition.

No version, migration registry, compatibility reader, backup rotation, or second save key is added.

## Pure projections

Widgets do not derive economy formulas, eligibility, or disabled reasons.

### Fleet Dock

`FleetDockView` exposes exactly four enum-keyed bays, selection/tier state, merge-eligible destinations, active-planet spawn cost, spawn state/reason, and contextual hint.

### Site Deck

```dart
enum MiningSiteCardState { locked, available, idle, operational }
```

`SiteDeckView` exposes cash, active planet, commissioned progress, aggregate active-planet cargo/capacity/value, aggregate rate, Fleet Dock, and one site card per authored site.

### Mine Site

`MineSiteView` exposes the selected site, four node views, deployed tiers/rates, site cargo/capacity, active-planet projected sale, Fleet Dock, and contextual hint. It also exposes recall disabled copy from the post-recall capacity rule.

### Technology and Stellar Map

Extend the existing `lib/mining/mining_progression_views.dart` in place.

Technology:

- current effects remain Extraction rate / Logistics capacity+offline cap / Surveying availability;
- gates become commissioned sites;
- Surveying copy counts currently unlocked site nodes honestly.

Stellar Map keeps `_isVisible` progressive disclosure:

```text
fresh: Homeworld + Lunar visible
Lunar unlocked: Homeworld + Lunar + Mars visible
```

Planet projections add commissioned-site progress, aggregate rate/cargo/capacity/value, three site indicators, requirements, action, busy state, and `Mars Frontier` copy.

## Visual and responsive presentation

### Site visual ownership

Per-site `cavernAsset`, `nodeAsset`, and `cardAsset` live on `MiningSiteDefinition`.

For Lunar/Mars cards, `cardAsset` may equal the cavern asset and `SiteDeckScreen` crops it with `BoxFit.cover`.

### Shared node anchors

Keep one portrait and one landscape `List<Alignment>` in `mining_visuals.dart`. Allow at most one explicit site override only when real final art proves shared anchors fail. Do not create an anchor framework or nine-row anchor table.

### HUD evolution

Rename/evolve:

```text
mining_status_bar.dart -> mining_hud.dart
MiningStatusBar        -> MiningHud
revealedSectors        -> commissionedSites
totalSectors           -> totalSites
```

Lift its current cyan/panel tokens plus existing offline warning color into `MiningTheme`. Do not invent a parallel palette.

### Mine Site orientation

One public `MineSiteScreen` chooses private layouts with `LayoutBuilder`.

Portrait:

- cash/planet HUD top;
- cargo/rate top-right;
- cavern middle;
- horizontal dock bottom;
- compact navigation below/adjacent.

Landscape:

- cavern uses space left of a fixed right rail;
- cargo immediately left of rail or at its top;
- vertical dock/spawn in rail;
- compact back/settings at bottom-left.

Rotation changes layout only; it does not recreate controller/audio or persisted state.

## Asset input contract

The prototype ZIP provides:

- Homeworld gold/coal/stone caverns;
- Homeworld gold/coal/stone nodes;
- three Homeworld site cards;
- `art-worker-t1.png` through `art-worker-t5.png`;
- three planet images;
- cash/cargo/merge/technology icons;
- merge burst;
- offline hero.

Map worker files explicitly:

```text
art-worker-t1.png -> rigs/t1.png
art-worker-t2.png -> rigs/t2.png
art-worker-t3.png -> rigs/t3.png
art-worker-t4.png -> rigs/t4.png
art-worker-t5.png -> rigs/t5.png
```

It does **not** contain the six Lunar/Mars cavern images or six Lunar/Mars node images.

Required external art before final visual completion:

```text
caverns/water_ice.png      nodes/water_ice.png
caverns/titanium_ore.png   nodes/titanium_ore.png
caverns/helium_3.png       nodes/helium_3.png
caverns/iron_ore.png       nodes/iron_ore.png
caverns/silica.png         nodes/silica.png
caverns/cobalt_ore.png     nodes/cobalt_ore.png
```

Caverns: 800x1200 PNG. Nodes: 512x512 transparent RGBA PNG.

### Art gate scope

The missing twelve files block **only final Lunar/Mars visual completion and merge readiness**.

Before they arrive:

- the in-place domain can be completed;
- the old Flame runtime can be removed;
- `MiningShell`, projections, and all Homeworld UI can be built and tested;
- structural visual tests can assert every site declares asset paths and all supplied Homeworld/common/rig/planet assets resolve.

Do not make an all-nine `rootBundle.load` test part of the Homeworld/common asset task. The final art task adds the all-nine bundle-resolution test and is the hard merge gate.

Do not generate missing art in Dart, use legacy mine sprites as fallback, or commit placeholders.

## Technology, settings, offline return

Keep the existing ownership:

- Technology retains the three tracks and current cost/effect model, retargeted to commissioned site gates.
- Settings keeps the same `AudioManager`, `audio.musicEnabled`, `audio.musicVolume`, and system reduced-motion message.
- Offline Return keeps deterministic per-planet/resource summary, cap messaging, full-site warnings, and one next action; terminology changes to sites/rigs and the supplied hero may be used.

No claims, ads, streaks, notifications, boosts, or new settings service.

## Economy validation

Removing build/upgrade costs changes cash sinks while multi-rig sites increase full-check-in revenue. Treat this as numeric balance risk, not justification for another mechanic.

Required fresh journey:

```text
commission all Homeworld sites
  + Surveying 3
  + required cash
-> Lunar Frontier

commission all Lunar sites
  + Surveying 5
  + required cash
-> Mars Frontier

commission all Mars sites
-> existing 25,000 Mars mastery reward
```

The journey test uses public controller actions and clock advancement only after initialization; it cannot edit state to bypass affordability.

The representative playtest records:

- early/mid/late site fill times;
- sell cadence / cap frequency;
- spawn/merge/sell cycles for Homeworld -> Lunar and Lunar -> Mars;
- fresh-to-Mars completion;
- portrait/landscape sizes;
- text scale 1.3;
- reduced motion;
- muted audio.

Allowed tuning when evidence requires:

- spawn costs;
- site unlock costs;
- base rate;
- base capacity;
- sale value;
- existing technology costs/effects;
- rate/capacity multiplier tables.

Do not add a new sink/mechanic merely to solve balance.

## Accessibility

- interactive targets >=48x48 logical pixels;
- icon-only controls have semantic labels/tooltips where applicable;
- primary state is not color-only;
- prototype micro-labels are increased to readable phone sizes;
- text scale 1.3 keeps critical actions reachable;
- safe areas and landscape rail avoid overlap;
- reduced motion removes nonessential transforms while retaining state feedback;
- muted audio journey remains understandable.

Use system typography. Remove undeclared `fontFamily: 'Orbitron'` from `lib/main.dart`.

## Implementation sequencing contract

The implementation plan follows this dependency shape:

```text
1. remodel catalog/state
2. retarget repository
3. retarget simulation/accrual
4. retarget controller/progression
5. isolate MiningScreen -> MiningShell ownership; remove old Flame/terrain/action runtime; restore full-suite green
6. add projections + supplied Homeworld/common visuals
7. ship Site Deck
8. ship Mine Site
9. ship Stellar Map + secondary surfaces
10. satisfy final Lunar/Mars art gate
11. economy validation, playtest, and final gates
```

Tasks 5-9 land as independently green, reviewable commits. The external art dependency gates Task 10 rather than blocking shell/UI development.

## Risks and mitigations

| Risk | Mitigation / proof |
| --- | --- |
| Merge throughput outgrows storage and makes capped returns equal | Keep existing capacity multipliers per deployed rig; test fill-time curve and full-cargo growth |
| Dynamic capacity makes recall destructive | Reject recall when post-recall capacity is below stored cargo; sell first |
| Missing Lunar/Mars art blocks implementation | Split structural/Homeworld resolution from final all-nine bundle gate |
| Branch remains red while waiting for art | Cut thin `MiningShell`, old Flame/presentation, terrain closure, and dependency after core remodel; resume full-suite gate before visual work |
| Shell rename drops live accrual | Regression-test timer -> `controller.refresh()` -> projection |
| Shell rename drops initial save persistence | Keep current missing/recovered best-effort write tests |
| Duplicate catalog/visual tables drift | One `MiningContentRegistry`; per-site asset paths live on `MiningSiteDefinition`; shared anchors are constants |
| Raw bay indices leak invalid values | `DockBayId` at save/controller/view boundaries |
| New cash sinks/revenue cadence are off | Public-action journey + observed fill/sell cadence; numeric tuning only |
| Large UI cutover is hard to review | Shell ownership, Site Deck, Mine Site, Stellar Map/secondary surfaces are separate commits in one PR |

## Non-goals

Do not add:

- finite deposits, regeneration, resurvey, exhaustion;
- drag-and-drop;
- rig identity, rarity, workers, crew, equipment, crafting;
- processing/refineries or dynamic markets;
- another currency, prestige, contracts, missions, retention systems;
- server/account/cloud/analytics/remote configuration;
- old-save migration/versioning/compatibility;
- state-management/routing/repository abstractions;
- generic content, asset, anchor, objective, or animation frameworks;
- a fourth planet or Mars rename.

## Final acceptance

The PR cannot merge until:

- one current mining catalog/state/simulation/repository/controller remains;
- fresh save uses enum-keyed four-bay Homeworld dock with two T1 rigs;
- spawn, merge, deploy, recall, recall-capacity rejection, unlock, sale, technology, travel, and mastery reward are deterministic and save-backed;
- foreground timer visibly advances cargo without per-second writes;
- missing/recovered initial state is best-effort persisted;
- site capacity scales with deployed rig capacity shares and Logistics;
- Site Deck, portrait/landscape Mine Site, and full-screen Stellar Map pass geometry/accessibility tests;
- all nine final cavern/node assets resolve with no fallback;
- fresh public-action journey reaches Mars mastery and reloads;
- playtest records fill time and sell cadence;
- old key is ignored;
- old action sheet/Flame world/unused terrain closure/flame dependency are gone;
- README and CLAUDE describe the final shell architecture;
- formatting, analysis, test suites, coverage, Chrome, APK, web, and available iOS build gates pass.
