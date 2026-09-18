# HPA-452 — Gameplay-only Fleet Management Design

Date: 2026-09-17  
Status: Draft implementation design  
Linear: HPA-452 — [Mining Polish] Make fleet management gameplay-only and streamline merge/deploy  
Baseline: `main` at `844e4a77243ad915a347c14e4c6bbfe696870c1c` after HPA-454 / PR #30

## Problem

Fleet management currently appears on both the Site Deck and the Mine Site. That splits one interaction loop across two surfaces:

1. spawn/select/merge rigs on the Site Deck or Mine Site;
2. enter a Mine Site;
3. select a dock rig again when needed;
4. deploy it onto the grid.

The duplicated Fleet Dock also consumes a meaningful amount of Site Deck space. More importantly, successful spawn and merge actions currently drop the interaction thread:

- spawning a T1 rig leaves the newly created bay unselected;
- merging clears the current selection before persistence finishes, and the upgraded target bay is not selected afterward.

HPA-452 should make fleet manipulation feel local to mining gameplay without creating a second fleet model or changing the economy.

## Goals

- Remove Fleet Dock spawn/select/merge controls from the Site Deck.
- Keep spawn, select, merge, deploy, and recall entirely on the Mine Site.
- Automatically select the newly spawned T1 rig after a successful spawn.
- Keep the upgraded target rig selected after a successful merge.
- Make compatible merge targets visually obvious while a rig is selected.
- Show a compact merge outcome preview such as `T1 + T1 → T2`.
- Explain merge value as stronger output per occupied deployment slot, not as a guaranteed increase over the combined output of the two consumed rigs.
- Preserve the existing controller mutation boundary, save format, economy, deployment rules, audio/haptics, reduced-motion behavior, and four-bay dock.

## Non-goals

This PR does not:

- change `MiningController` spawn/merge/deploy/recall rules;
- add or change save fields;
- change rig prices, rates, capacity, technology multipliers, or merge balance;
- add drag-and-drop or confirmation dialogs;
- add a second dock, inventory, deployment model, or generic action framework;
- change HPA-454 resource geometry;
- add HPA-455 HP/damage feedback;
- add HPA-286 Site Deck selling/cargo-full polish;
- generate new image art.

## Current ownership to preserve

The repository guidance remains authoritative:

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> Flutter Site Deck / Mine Site / Stellar Map
```

For HPA-452:

- `MiningController` remains the sole mutation boundary.
- `MiningSave.docks` remains the authoritative four-bay fleet state per planet.
- `MiningShell._selectedBayId` remains transient presentation selection.
- `FleetDockView` remains a pure projection of save state plus transient selection/busy state.
- `MineSiteView` remains responsible for deploy/recall legality and grid tap outcomes.
- Widgets never mutate save state directly.

No new state owner is needed.

## Design decisions

### 1. Fleet Dock becomes Mine Site-only

Remove Fleet Dock from `SiteDeckScreen` in both orientations.

The Site Deck constructor no longer accepts:

- `FleetDockView fleetDock`;
- `onBayTap`;
- `onSpawnRig`.

The Site Deck should continue to own only:

- site status/cards;
- site unlock/entry;
- cash/cargo/progression display;
- bottom navigation.

This also removes the only caller of `FleetDock.inline`. Delete the inline rendering mode instead of keeping dead presentation code.

#### Portrait layout

The Site Deck currently reserves bottom space for both the inline Fleet Dock and the 88px navigation bar. After removing the Fleet Dock, reclaim that space and reserve only enough room for the existing navigation bar plus safe-area padding.

Do not create a generic footer/layout abstraction. Adjust the existing portrait stack directly and cover it with the current layout tests.

#### Landscape layout

Remove the fixed 320px Fleet Dock column. Let the existing site list use the available content width.

No replacement sidebar is required in this ticket.

### 2. Keep selection transient in MiningShell

Do not put selected bay state into `MiningController`, `MiningSave`, or `FleetDockView`.

`MiningShell._selectedBayId` already has the correct lifetime:

- it is UI-only;
- it follows the active planet;
- existing `_preserveDockSelection()` clears it when the selected bay becomes empty;
- active-planet changes already clear it.

HPA-452 only changes what selection becomes after successful spawn and merge actions.

### 3. Successful spawn selects the actual newly filled bay

`MiningController.spawnRig()` intentionally owns which empty bay is filled. The shell should not duplicate the controller's "first empty bay" policy.

Before starting the spawn action, capture the active planet's dock map. After a successful persisted action, compare the before/after dock maps and select the bay that changed from `null` to non-null.

This keeps selection behavior coupled to the actual controller result rather than to duplicated UI assumptions.

If the spawn fails, keep the previous selection unchanged.

### 4. Successful merge selects the upgraded target bay

`MiningController.mergeDockRigs(sourceBay, targetBay)` clears the source bay and upgrades the target bay.

Current shell behavior clears selection before the async mutation starts. Remove that eager clear.

During the mutation, keep the source bay as the transient selection. After successful persistence:

- set `_selectedBayId = targetBay`;
- let `_preserveDockSelection()` validate it against the authoritative state.

If persistence or validation fails, leave the original source selection in place so the player can retry or choose another target.

This preserves the user's interaction thread and avoids false optimistic state.

### 5. Add one small success hook to the existing action runner

Reuse `_runSheetAction` instead of duplicating its persistence/audio/haptic/snackbar orchestration for spawn and merge.

Add one optional success callback, invoked only after the controller action has successfully persisted and before the final selection-preservation pass.

This callback is intentionally narrow:

- spawn uses it to select the newly filled bay;
- merge uses it to select the upgraded target bay;
- all other actions omit it.

Do not turn this into a generalized action pipeline, reducer, event bus, or command framework.

### 6. Reuse FleetDockView's existing merge compatibility signal

`FleetDockBayView.canMergeWithSelection` already identifies a valid same-tier non-T5 merge target. Keep that as the only compatibility signal.

Enhance presentation in two places:

1. compatible target bays get a stronger border/fill or small merge indicator;
2. the dock shows a compact merge preview for the currently selected non-T5 rig.

Add a small pure view property such as:

```dart
String? mergePreview; // e.g. "T1 + T1 → T2"
```

The exact property name may vary, but the value should be derived entirely inside `FleetDockView.from(...)` from the selected rig tier.

For a selected T5 rig, no merge preview is required because it cannot merge.

### 7. Merge copy describes slot efficiency, not combined DPS

The compact preview should pair the tier result with short explanatory copy such as:

> Stronger per deployment slot

Avoid claims such as "double output", "more total output", or "upgrade for higher combined production" because HPA-452 is not changing or re-balancing the rate formula.

The Mine Site already has limited chrome, especially in landscape. Keep this explanation compact and local to the Fleet Dock; do not add a tutorial modal or persistent hint system.

### 8. Deploy and recall behavior stay unchanged

After spawn/merge selects a dock rig, the existing Mine Site flow should work unchanged:

- selected rig projects deployable cells through `MineSiteView`;
- tapping a legal grid cell calls `MiningController.deployRig(...)`;
- deployment empties the selected bay;
- existing `_preserveDockSelection()` clears the now-empty selection.

Recall behavior remains exactly as today:

- tapping an occupied rig cell recalls through the controller;
- the controller chooses an empty dock bay;
- the recalled bay is not auto-selected in this ticket.

That keeps HPA-452 focused on the two explicitly requested continuity improvements.

## File-level changes

### `lib/mining/presentation/site_deck_screen.dart`

- remove Fleet Dock imports and constructor fields;
- remove portrait inline Fleet Dock;
- remove landscape Fleet Dock column;
- reclaim the vacated layout space;
- retain Site Deck navigation and site-card callbacks.

### `lib/mining/presentation/fleet_dock.dart`

- remove the unused `inline` mode;
- retain horizontal and vertical Mine Site layouts;
- visually distinguish `canMergeWithSelection` bays;
- render the compact merge preview and slot-efficiency copy.

### `lib/mining/fleet_dock_view.dart`

- keep existing bay compatibility projection;
- add the small selected-tier merge preview projection;
- do not add mutation behavior.

### `lib/mining/presentation/mining_shell.dart`

- only build/pass `FleetDockView` for Mine Site;
- stop wiring fleet callbacks into Site Deck;
- add the narrow post-success callback to `_runSheetAction`;
- derive/select the actual newly spawned bay after success;
- retain source selection while merge is in flight;
- select the merge target after success.

No production changes are expected in `mining_controller.dart`, `mining_state.dart`, `mining_simulation.dart`, or `mining_save_repository.dart`.

## Verification strategy

### Pure projection coverage

Extend `test/mining/fleet_dock_view_test.dart` to cover:

- selected T1 projects `T1 + T1 → T2`;
- compatible same-tier bays remain marked as merge targets;
- T5 has no merge preview;
- busy state still disables merge targets.

### Site Deck coverage

Update `test/mining/presentation/site_deck_screen_test.dart` and constructor users to prove:

- portrait Site Deck contains no `fleet-dock`;
- landscape Site Deck contains no `fleet-dock`;
- site entry/unlock and navigation callbacks still work;
- reclaimed portrait/landscape space does not overlap the navigation bar.

Update `visual_parity_golden_test.dart` fixtures for the slimmer constructor and Site Deck ownership change.

### Mine Site / shell behavior

Update `test/mining/presentation/mining_shell_test.dart` so fleet operations are performed after entering a Mine Site.

Add explicit flows:

1. **spawn continuity**
   - enter Mine Site;
   - spawn a T1;
   - without tapping its bay, tap a legal resource perimeter cell;
   - verify that the newly spawned rig deploys.

2. **merge continuity**
   - enter Mine Site;
   - select one T1 and tap a compatible T1 target;
   - verify the target becomes T2;
   - without reselecting the target bay, tap a legal placement cell;
   - verify T2 deploys.

3. **failure preservation**
   - failed spawn/merge persistence does not invent a new selection;
   - existing reject audio/message behavior remains.

Keep the existing controller tests for mutation legality unchanged unless a regression requires only fixture updates.

## Acceptance mapping

- **Site Deck no longer exposes fleet controls**: constructor/layout removal plus portrait/landscape widget tests.
- **Spawn then place with no extra bay tap**: shell spawn-continuity test.
- **Merge leaves upgraded rig selected and deployable**: shell merge-continuity test.
- **Invalid placement/blocked actions remain authoritative**: no controller/view legality changes; existing Mine Site tests retained.
- **No save/economy changes**: no changes to save/controller/simulation contracts.

## Assets

No image generation is required.

Reuse the existing rig art, merge icon, Flutter typography, borders, and color emphasis. If a later visual review concludes that a dedicated merge-effect asset is needed, that should be a separate art task rather than added to HPA-452.
