# HPA-285 Horologium Mobile Merge-Mining Redesign Design

## Status

Implementation design for Linear HPA-285, **Ship the Horologium mobile merge-mining redesign**.

Planning, implementation, review, production cutover, cleanup, and verification stay on **one branch and one pull request**. The prototype ZIP attached manually to HPA-285 is the visual and interaction reference. The repository catalog and this design remain authoritative where the prototype contains placeholder copy or example values.

This design is grounded on `main` commit `d022ce7a5214e3b13c80759fbd61e70ccc98df70`.

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

The product remains a casual idle mining game. Merge and deployment add a visible progression layer; they do not introduce workers, crafting, finite deposits, dynamic markets, or live-service chores.

## Current baseline

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

Preserve these proven ideas:

- one controller, audio manager, lifecycle observer, and one-second presentation refresh owner;
- serialized persistence-backed mutations;
- deterministic elapsed-time production across all unlocked planets;
- save-before-publish controller semantics;
- strict unversioned SharedPreferences persistence;
- presentation-ready view projections;
- per-planet offline summaries;
- active-planet-only selling.

Replace the interaction and rendering model because `SectorProgress` plus one `MineState(level, storedAmount)` cannot honestly represent dock bays, mergeable rigs, node deployment, recall, or commissioned sites.

## Selected architecture

### One shell and three logical surfaces

Implement:

1. `SiteDeckScreen` — active-planet overview, site cards, and fleet management.
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
      -> SiteDeckView / MineSiteView / Progression views
      -> SiteDeckScreen
      -> MineSiteScreen
      -> StellarMapScreen
      -> TechnologySheet / MiningSettingsSheet / OfflineReturnSheet
```

`MiningShell` owns:

- the controller and display snapshot;
- one `AudioManager`;
- lifecycle observation and checkpoints;
- one one-second presentation refresh timer;
- current primary surface and open site;
- selected dock bay;
- offline-return presentation;
- transient action feedback.

Do not add Provider, Riverpod, Bloc, `ChangeNotifier`, a service locator, command bus, routing package, generic screen registry, or design-system package. Local navigation is one enum/value in the shell.

### Flutter replaces Flame

Build Mine Site with Flutter `Stack`, `LayoutBuilder`, anchored tap targets, `AnimatedSwitcher`, and short opacity/scale effects. It needs no camera, collision, physics, pathfinding, or frame-authoritative economy.

After cutover, delete `MiningGame`, mining Flame components, mining-only terrain code/tests/assets, and `flame` when repository search proves no surviving consumer.

### Final ownership

```text
lib/mining/
  domain/
    mining_content.dart
    mining_state.dart
    mining_simulation.dart
    mining_save_repository.dart
    mining_controller.dart
  views/
    fleet_dock_view.dart
    site_deck_view.dart
    mine_site_view.dart
    progression_views.dart
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

This is folder organization, not a package split. Temporary coexistence with the old flat domain is allowed only while intermediate commits remain testable on the same PR. No parallel runtime or compatibility facade survives the final diff.

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
enum RigTier { t1, t2, t3, t4, t5 }
enum TechnologyTrack { extraction, logistics, surveying }
```

Node IDs repeat inside each site's nested node map. No global node ID or rig UUID is needed.

## Authored content

### Rig ladder

| Tier | Production multiplier | T1 rigs represented |
| --- | ---: | ---: |
| T1 | 1.00 | 1 |
| T2 | 1.50 | 2 |
| T3 | 2.25 | 4 |
| T4 | 3.25 | 8 |
| T5 | 4.50 | 16 |

Two same-tier docked rigs merge into one next-tier rig in the tapped destination bay; the source becomes empty. T5 is terminal. Merging is dock-only.

Each planet has exactly four dock bays and its own authored T1 spawn cost:

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

Unlocking Lunar or Mars seeds its starter dock, unlocks its first site, and makes the planet active in the same saved mutation.

### Sites

The old build and mine-upgrade costs are removed because rigs now own throughput progression. Preserve resource identity, unlock chain, reveal cash as site unlock cash, base rate, base capacity, and sale value.

| Site | Resource | Prerequisite | Surveying | Unlock | Base rate/s | Capacity | Sale/unit |
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

First sites are unlocked when their planet is unlocked. Later sites require the prerequisite site unlocked, authored Surveying level, and cash.

### Node availability

Every site has four fixed nodes. Availability is authored, not procedural:

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

## Mutable state

```dart
class PlanetMiningProgress {
  final List<RigTier?> dock; // exactly four
  final Map<MiningSiteId, SiteProgress> sites;
}

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
  final Map<MiningPlanetId, PlanetMiningProgress> planets;
}
```

Fresh state:

- 100 cash;
- Homeworld unlocked and active;
- Landing Basin unlocked;
- two Homeworld T1 rigs;
- no commissioned site, cargo, or deployed rig;
- locked planets contain empty docks and pristine locked sites.

`commissioned` flips to true on the first successful deployment and never reverses. Planet mastery means every authored site is commissioned. Recall cannot revoke mastery.

All values are immutable and copied atomically. Selection, current screen, orientation, hints, and animation state are not persisted.

## Deterministic simulation

For every unlocked site with deployed rigs:

```text
siteRate = sum(site.baseRatePerSecond * rigTierMultiplier)
siteRate *= extractionMultiplier
capacity = site.baseCapacity * logisticsCapacityMultiplier
produced = min(siteRate * elapsedSeconds, capacity - storedAmount)
```

Rules:

- docked rigs produce nothing;
- all unlocked planets produce while inactive;
- locked or empty sites produce nothing;
- storage never exceeds effective capacity;
- clock rollback produces zero and never moves the timestamp backward;
- elapsed time is capped by Logistics and then advances the timestamp to `nowUtc`;
- equal state plus equal `nowUtc` yields equal output;
- the one-second UI timer is presentation only.

`OfflineProductionSummary` groups production by planet and resource, exposes a flat set of full site IDs, elapsed used, and cap status.

## Serialized controller

Keep one future-chain mutation queue. Every persistence-backed action:

1. accrues a candidate at the action timestamp;
2. validates against the candidate;
3. builds one complete next state;
4. saves once;
5. publishes only after save succeeds;
6. returns a typed result.

Required actions:

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

- Spawn uses the first empty active-planet bay and fails for full dock, insufficient cash, or busy state.
- Merge requires distinct occupied same-tier bays and rejects T5.
- Deploy requires an active-planet site, unlocked site, available empty node, and occupied source bay; the rig moves atomically.
- Recall requires an occupied node and first empty active-planet bay; full dock is a non-mutating failure.
- Site unlock preserves the authored prerequisite, Surveying, and cash checks.
- Technology gates use commissioned sites, not currently deployed rigs.
- Planet unlock preserves current mastery, Surveying, and cash requirements and seeds its first site/fleet.
- Travel only changes active planet after accrual and save.
- Sell All clears all active-planet site cargo and floors aggregate gross value once.
- Zero cargo fails without mutation; UI disables positive cargo worth less than one cash.
- The 25,000 Mars reward is granted only on the false-to-true commission transition caused by the final first deployment. Recall/redeploy cannot pay again.

Queued duplicate actions and save failures must never copy, lose, or publish a moved rig.

## Persistence

Use one fresh key:

```text
horologium.mergeMining.save
```

Do not read, migrate, convert, or delete `horologium.mining.save`. Main Menu Start/Continue checks only the new key. This is an intentional pre-release breaking redesign, not recovery of the old model.

The strict document contains exactly:

```text
cash
lastAccruedAtUtc
technology { extraction, logistics, surveying }
unlockedPlanetIds
activePlanetId
planets
  each of exactly homeworld, lunarFrontier, marsFrontier
    dock: exactly four nullable tier names
    sites: exactly that planet's three authored site IDs
      unlocked
      commissioned
      storedAmount
      rigByNode: exactly n1, n2, n3, n4
```

Structural invalidity resets to fresh state and reports recovery:

- malformed JSON, wrong types, extra/missing keys, unknown/duplicate enum strings;
- negative/non-integer cash or invalid/non-UTC timestamp;
- technology outside 0-5;
- dock length other than four or unknown tier;
- active planet not unlocked or Homeworld not unlocked;
- locked planet with rigs or non-pristine sites;
- locked site with commission, cargo, or rigs;
- commissioned site not unlocked;
- later site unlocked while prerequisite is locked;
- first site locked on an unlocked planet;
- deployed rig above saved Surveying availability;
- negative/non-numeric cargo.

The only tolerant normalization is:

```text
storedAmount = min(storedAmount, effectiveCapacity(site, logistics))
```

No version, migration registry, compatibility reader, backup rotation, or second save key is added.

## Pure projections

Widgets do not derive eligibility, economy totals, or disabled copy.

### Fleet Dock

`FleetDockView` exposes exactly four bays, selected/tier state, merge-eligible destinations, active-planet spawn cost, spawn enabled/disabled reason, and contextual hint.

### Site Deck

```dart
enum MiningSiteCardState { locked, available, idle, operational }
```

`SiteDeckView` exposes cash, active planet, commissioned progress, aggregate active-planet cargo/capacity/value, aggregate production rate, Fleet Dock, and one site card per authored site.

Card states:

- locked — requirement unmet;
- available — unlock enabled;
- idle — unlocked with no deployed rig;
- operational — one or more rigs deployed.

Cards contain presentation-ready resource/status text, deployed tiers, rate, cargo/capacity, action label, enabled state, and disabled reason.

### Mine Site

`MineSiteView` exposes site/resource identity, commissioned state, site rate, site cargo/capacity, active-planet cargo/capacity and projected Sell All revenue, sell state/reason, Fleet Dock, four node views, and current hint.

Node views expose Surveying requirement, availability, deployed tier/rate, deploy/recall state, disabled reason, and semantic label.

### Technology

Keep `TechnologyTrackView` and `TechnologySheetView`. Copy becomes:

- Extraction: `Rig output ×...`;
- Logistics: `Site capacity ×..., offline cap ...h`;
- Surveying: `x of y site nodes available` across unlocked planets.

Gate copy uses `Commission <site> first.`

### Stellar Map

Progressive disclosure remains:

- Homeworld always visible;
- Lunar visible from fresh state;
- Mars visible once Lunar is unlocked.

Each planet view exposes active/unlocked state, commissioned sites, rate, cargo/capacity/value, three site indicators, mastery/Surveying/cash requirements, and direct Unlock/Travel action state with disabled reason.

## Presentation

### Theme and typography

Create one concrete `MiningTheme` file for visor colors, borders, spacing, and text styles. Use platform font defaults and tabular figures for numeric HUD values. Remove undeclared `fontFamily: 'Orbitron'`; add no font package or unlicensed font.

Interactive targets are at least 48x48 logical pixels. Icon-only actions have semantics/tooltips. Primary state is not color-only.

### Visual catalog

Use concrete paths under:

```text
assets/images/mining/
  caverns/
  nodes/
  rigs/
  planets/
  sites/
  icons/
  effects/
  offline/
```

Import supplied Homeworld caverns/nodes/cards, T1-T5 rigs, planet art, icons, merge burst, and offline hero. Produce final cavern and transparent node PNGs for:

```text
Water Ice
Titanium Ore
Helium-3
Iron Ore
Silica
Cobalt Ore
```

Use 800x1200 portrait cavern masters and 512x512 transparent node masters. Lunar/Mars Site Deck cards crop their cavern asset rather than adding six duplicate card masters. No temporary fallback remains at merge time.

Use common node anchors:

```dart
const portraitNodeAnchors = <Alignment>[
  Alignment(-0.56, -0.42),
  Alignment(0.48, -0.22),
  Alignment(-0.18, 0.28),
  Alignment(0.54, 0.58),
];

const landscapeNodeAnchors = <Alignment>[
  Alignment(-0.62, -0.34),
  Alignment(-0.06, -0.08),
  Alignment(0.42, 0.28),
  Alignment(0.58, -0.48),
];
```

One explicit site override is allowed only if final art proves the common anchors unusable. Do not add an anchor framework or asset-generation pipeline.

Register every concrete mining subdirectory in `pubspec.yaml`. Precache shared HUD/rig assets plus only the active planet/site and imminent destination; do not eagerly decode every cavern at launch.

### Navigation

```dart
enum MiningPrimarySurface { siteDeck, stellarMap }
enum MiningNavigationDestination { siteDeck, technology, stellarMap, settings }
```

Site Deck and Stellar Map share four visible destinations. Technology/Settings open their sheets; Site Deck/Stellar Map switch the primary surface. Mine Site uses compact Back and Settings controls.

### Site Deck

Use a safe-area scroll layout with top HUD, site cards, fleet dock, and bottom navigation. It must work at 360x640 and 430x932 with `TextScaler.linear(1.3)` without hiding critical actions.

### Mine Site interaction

- tap occupied bay to select;
- tap selected bay to deselect;
- tap same-tier destination to merge;
- tap an available empty node with a selected rig to deploy;
- tap occupied node to recall;
- tap cargo/shipping control to Sell All with no confirmation;
- show disabled reason without mutating.

Hints derive from state and are not saved:

```text
Tap two matching rigs to merge
Tap an open node to deploy
Merge or deploy a rig to free a bay
Tap cargo to sell
```

Portrait uses top cash/cargo HUD, cavern, horizontal dock, and compact bottom controls. Landscape uses cavern left of a fixed right fleet rail, cargo immediately left of the rail, vertical dock/spawn in the rail, and compact Back/Settings bottom-left. Both render the same view/callbacks.

Rotation preserves controller, open site, assignments, cargo, and still-valid local selection.

### Feedback and reduced motion

Successful merge/deploy/recall/unlock/sale uses concise haptic plus visual feedback. Normal animation is at most 550 ms. `MediaQuery.disableAnimations` changes nonessential movement to at most 200 ms opacity feedback. No feedback state is persisted.

## Lifecycle, audio, and errors

`MiningShell` preserves current ownership:

- load audio preferences before presenting settings;
- start BGM only from existing user gestures;
- pass the same `AudioManager` to Settings;
- forward lifecycle changes;
- checkpoint on pause/inactive/dispose;
- resume deterministic production and show Offline Return;
- dispose audio once.

Controller busy state disables mutation affordances. Failed actions keep current display state and show concise feedback. Invalid new-key saves reset through the repository boundary and show the existing fresh-start recovery explanation. The ignored old key never triggers that warning.

## Offline Return

Retarget the existing summary to sites/rigs and `fullSites`, preserve per-planet/resource production, cap messaging, storage-full warnings, and one clear next action. Use supplied hero art. Do not add claims, ads, multipliers, streaks, or notifications.

## Accessibility and geometry

Automated sizes:

```text
portrait: 360x640, 402x874, 430x932
landscape: 874x402
text scale: 1.3 on smallest portrait
```

Use `SafeArea`. Prove no overlap among HUD, cavern, nodes, dock/rail, navigation, card actions, and system insets. Muted-audio and reduced-motion journeys remain understandable.

Stable keys include:

```text
mining-shell
site-deck-screen
site-deck-fleet-dock
site-card-<siteId>
mine-site-screen
mine-site-cavern
mine-site-cargo-control
mine-site-fleet-dock
mine-site-fleet-rail
mine-site-navigation
mine-node-<nodeId>
fleet-bay-<index>
stellar-map-screen
stellar-map-planet-<planetId>
mining-technology-sheet
mining-settings-sheet
offline-return-sheet
```

## Progression and balance gate

The complete fresh journey must work without debug edits:

```text
Homeworld starter fleet
  -> commission all Homeworld sites
  -> Surveying 3 + 2,500 cash
  -> Lunar starter fleet
  -> commission all Lunar sites
  -> Surveying 5 + 20,000 cash
  -> Mars starter fleet
  -> commission all Mars sites
  -> existing 25,000 Mars mastery reward
```

The authored values are starting hypotheses. Tune only existing numeric values when representative play proves the loop blocked, trivial, or excessively repetitive:

- per-planet spawn cost;
- site unlock cost;
- site rate/capacity/sale value;
- existing technology cost/effect values.

Document observed before/after impact. Do not add currency, processing, dynamic markets, contracts, boosts, prestige, or retention mechanics. HPA-640 remains canceled.

## Testing

### Domain

Cover content tables, initial state, strict save invariants/normalization, deployed-rig production, technology modifiers, inactive planets, clock rollback/offline caps, spawn/merge/T5/deploy/recall, full dock, locked nodes, duplicate queued input, failed saves, commissioned mastery, technology gates, planet unlock starter fleets, active-only selling, and exact-once Mars reward.

### Projections

Cover fleet selection/merge/hints, all four Site Deck card states, Mine Site nodes/cargo/reasons, Technology copy/gates, and Stellar Map disclosure/totals/requirements/actions.

### Widgets

Cover shell identity/lifecycle/audio/recovery, Main Menu new-key behavior, Site Deck semantics/geometry, Mine Site interaction and portrait/landscape rotation, full-screen Stellar Map, secondary sheets, reduced motion, text scaling, and all asset paths.

### Integration

Replace the old journey with one fresh merge-mining journey proving merge/deploy/accrue/sell, Homeworld mastery, technology/Lunar unlock, inactive-planet production, Lunar mastery/Mars unlock, Mars reward, save/reload of fleets/nodes/commission/cargo/technology/active planet, and offline return.

Repository gates:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Run an iOS simulator/debug build where supported and representative visual passes at the specified sizes.

## Production cleanup

Delete the retired flat domain, old action-sheet/status/tab presentation, `MiningGame`, mining world components, corresponding tests, and old save consumers. After import closure is proven, delete mining-only terrain code/tests/assets and remove `flame`. Simplify old asset constants only after search proves zero consumers.

Update `README.md` and `CLAUDE.md` to the final shell/domain/save architecture. Historical design documents remain historical.

Do not keep feature flags, forwarding typedefs, compatibility readers, or adapters to the old runtime.

## Non-goals

- finite depletion, regeneration, resurvey, or exhaustion;
- drag-and-drop, camera pan/zoom, physics, pathfinding, or frame-authoritative economy;
- rig IDs, rarity, equipment, workers, crafting, inventory, or generic merge engine;
- processing, dynamic prices, demand, contracts, prestige, another currency, or fourth planet;
- quests, achievements, retention, leaderboard, notifications, ads, analytics, accounts, cloud save, or server systems;
- old-save migration/versioning/backup/compatibility;
- state-management/routing packages, service locators, event buses, generic requirement/reward engines, theme engines, or asset pipelines;
- separate implementation tickets or PRs.

## Acceptance

HPA-285 is ready to merge only when:

- production uses `MiningShell` and `horologium.mergeMining.save`;
- all controller/save/simulation/projection contracts above are covered;
- Site Deck, responsive Mine Site, and full-screen Stellar Map are complete;
- all nine resources have final cavern/node presentation;
- a fresh save completes Homeworld -> Lunar -> Mars;
- portrait, landscape, text scale, reduced motion, muted audio, lifecycle, and Offline Return are verified;
- no retired Flame mining runtime or compatibility layer remains;
- formatting, analysis, tests, and representative builds pass;
- HPA-285 and this draft PR remain the only implementation ticket/PR for the redesign.
