# HPA-452 — Gameplay-only Fleet Management Implementation Plan

Date: 2026-09-17  
Linear: HPA-452  
Design: `docs/superpowers/specs/2026-09-17-hpa-452-gameplay-only-fleet-management-design.md`

## Delivery rule

One ticket = one PR.

Keep all implementation for HPA-452 on this branch/PR. Do not split Site Deck cleanup, Fleet Dock feedback, and selection continuity into separate PRs.

No image-generation work is included.

## Baseline

Start from `main` after HPA-454 / PR #30:

- Mine Sites use the deterministic 50×50 / 100-resource grid.
- `MiningShell` owns transient `_selectedBayId`.
- `MiningController` owns spawn/merge/deploy/recall mutations and persistence.
- `FleetDockView` is already a pure read model with `canMergeWithSelection`.
- `SiteDeckScreen` and `MineSiteScreen` both currently render Fleet Dock controls.

The implementation should reduce duplication rather than introduce another fleet abstraction.

## Task 1 — Lock the Site Deck ownership change with tests

### Tests first

Update `test/mining/presentation/site_deck_screen_test.dart` before production code:

- remove Fleet Dock fixture/callback requirements from the Site Deck helper;
- assert `find.byKey(const Key('fleet-dock'))` is absent in portrait;
- add/adjust the landscape case and assert Fleet Dock is absent there too;
- preserve site entry, site unlock, and bottom-navigation callback assertions;
- update the 48px interaction-target test so it checks only Site Deck-owned controls.

Update constructor users in:

- `test/mining/presentation/visual_parity_golden_test.dart`;
- any other tests discovered by analyzer after the constructor change.

### Production change

Edit `lib/mining/presentation/site_deck_screen.dart`:

- remove `fleet_dock_view.dart` and `fleet_dock.dart` imports;
- remove `fleetDock`, `onBayTap`, and `onSpawnRig` from `SiteDeckScreen`;
- remove the same fields from `_PortraitSiteDeck`;
- remove the landscape 320px Fleet Dock column;
- remove the portrait inline Fleet Dock;
- change the portrait site-list bottom inset from the current Fleet-Dock+navigation reservation to navigation-only spacing.

Use the existing `MiningNavigationBar` height contract directly. Do not add a footer layout helper.

### Focused gate

Run:

```sh
flutter test test/mining/presentation/site_deck_screen_test.dart
flutter test test/mining/presentation/visual_parity_golden_test.dart
```

## Task 2 — Make merge intent explicit inside the existing Fleet Dock

### Tests first

Extend `test/mining/fleet_dock_view_test.dart`:

- selected T1 derives `T1 + T1 → T2`;
- selected T4 derives `T4 + T4 → T5`;
- selected T5 derives no merge preview;
- compatible target bays still use `canMergeWithSelection`;
- busy state suppresses compatibility exactly as today.

Add widget assertions in `test/mining/presentation/mine_site_screen_test.dart` for:

- a stable merge-preview key while a non-T5 rig is selected;
- compatible target bays exposing a stable merge-target key or semantics;
- Mine Site still exposes four dock bays and spawn in portrait and landscape.

### Production change

Edit `lib/mining/fleet_dock_view.dart`:

- add one nullable merge-preview field to `FleetDockView`;
- derive it from the selected rig tier in `FleetDockView.from(...)`;
- keep `FleetDockBayView.canMergeWithSelection` as the only target-compatibility flag.

Edit `lib/mining/presentation/fleet_dock.dart`:

- remove `inline` and `_inlineChildren()` because Site Deck no longer uses them;
- keep horizontal and vertical layouts only;
- render the compact `Tn + Tn → T(n+1)` preview near the Fleet label;
- include short copy such as `STRONGER PER SLOT`;
- give compatible bays a stronger visual state than ordinary occupied bays;
- keep the existing rig assets, merge icon, colors, and `MiningHex`.

Do not add an animation framework or new asset.

### Focused gate

Run:

```sh
flutter test test/mining/fleet_dock_view_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
```

## Task 3 — Keep spawn and merge selection continuous in MiningShell

### Tests first

Update `test/mining/presentation/mining_shell_test.dart`.

Replace the current Site Deck fleet-flow test with Mine Site-owned behavior.

#### Spawn continuity test

Arrange a state with one empty dock bay and an unlocked Landing Basin.

1. Enter Landing Basin.
2. Tap Spawn.
3. Wait for persistence.
4. Do **not** tap the new bay.
5. Tap a legal deployable perimeter cell.
6. Assert that the new T1 rig moved from dock to the site.

This proves the spawned bay was automatically selected.

#### Merge continuity test

Arrange two T1 rigs in the dock.

1. Enter Landing Basin.
2. Select source T1.
3. Tap compatible target T1.
4. Wait for persistence.
5. Assert source is empty and target is T2.
6. Do **not** tap the target bay again.
7. Tap a legal deployment cell.
8. Assert a T2 rig was deployed.

This proves the upgraded target remains selected.

#### Failure behavior

Move the existing delayed-save spawn failure test into a Mine Site flow and keep these assertions:

- failed persistence plays reject audio, not success audio;
- cash/dock state is unchanged;
- no phantom post-success selection is created.

If a merge failure test already covers controller failure messaging, keep it; do not duplicate controller validation tests at widget level.

### Production change

Edit `lib/mining/presentation/mining_shell.dart`.

#### Site Deck wiring

- stop creating/passing `FleetDockView` in the Site Deck branch;
- remove `onBayTap` and `onSpawnRig` Site Deck wiring;
- create `FleetDockView` only when a Mine Site is open.

#### Narrow action success hook

Extend `_runSheetAction(...)` with one optional callback that runs only after a successful persisted action and before the final `_preserveDockSelection()` pass.

Keep this callback private and local to the shell. Do not create a new action type or command abstraction.

#### Spawn

Before calling `spawnRig`:

- snapshot the active planet dock map.

After success:

- compare before/after docks;
- select the bay that changed from empty to occupied.

Do not reproduce the controller's first-empty-bay algorithm in the shell.

#### Merge

In `_handleDockBayTap(...)`:

- do not clear `_selectedBayId` before the merge mutation;
- call `mergeDockRigs(selectedBayId, bayId)`;
- after success, select `bayId`, the authoritative upgraded target;
- then let `_preserveDockSelection()` validate it.

On failure, the original source selection remains available.

#### Deploy

Do not change deploy code.

The existing successful deploy empties the selected dock bay, and `_preserveDockSelection()` will clear the selection as it does now.

#### Recall

Do not auto-select a recalled rig. Recall behavior is out of scope beyond preserving current legality/messages.

### Focused gate

Run:

```sh
flutter test test/mining/presentation/mining_shell_test.dart
```

## Task 4 — Remove dead Fleet Dock assumptions and verify the full slice

Search for the removed Site Deck Fleet Dock API:

```sh
rg "fleetDock:|onBayTap:|onSpawnRig:|inline: true|FleetDock\(" lib test
```

Expected result:

- Fleet Dock construction remains only in Mine Site presentation/tests;
- Site Deck constructor users no longer pass fleet fields;
- no `inline: true` caller remains.

Do not delete `FleetDockView` or rename the Fleet Dock domain vocabulary.

## Task 5 — Regression and quality gates

Run focused tests first, then repository gates:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

For this interaction-only ticket, implementation is complete when:

- Site Deck has no fleet controls in portrait or landscape;
- Mine Site still has the four-bay Fleet Dock and Spawn control;
- spawned T1 is selected automatically;
- merged target remains selected;
- compatible merge targets are visibly distinct;
- merge preview communicates tier outcome and slot efficiency;
- deploy/recall legality and blocked-action copy still come from the existing read-model/controller path;
- save JSON and economy code are untouched;
- no new image asset is added.

## Files expected to change

Primary:

- `lib/mining/fleet_dock_view.dart`
- `lib/mining/presentation/fleet_dock.dart`
- `lib/mining/presentation/site_deck_screen.dart`
- `lib/mining/presentation/mining_shell.dart`
- `test/mining/fleet_dock_view_test.dart`
- `test/mining/presentation/site_deck_screen_test.dart`
- `test/mining/presentation/mine_site_screen_test.dart`
- `test/mining/presentation/mining_shell_test.dart`
- `test/mining/presentation/visual_parity_golden_test.dart`

Only add another file if the compiler or a concrete regression requires it. Do not introduce a new fleet/service layer.

## Scope guardrails

Stop and re-evaluate if implementation starts requiring any of the following:

- save migration;
- controller API redesign;
- economy/rate changes;
- drag/drop;
- a new state-management package;
- a new animation system;
- new image generation;
- HPA-455 resource HP/damage work;
- HPA-286 Site Deck sell/full-cargo work.

Those are not needed to satisfy HPA-452.
