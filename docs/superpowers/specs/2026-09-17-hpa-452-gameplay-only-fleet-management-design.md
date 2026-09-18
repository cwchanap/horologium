# HPA-452 — Gameplay-only Fleet Management Design

Date: 2026-09-17  
Status: Draft implementation design  
Linear: HPA-452 — [Mining Polish] Make fleet management gameplay-only and streamline merge/deploy  
Baseline: `main` at `844e4a77243ad915a347c14e4c6bbfe696870c1c` after HPA-454 / PR #30

## Problem

Fleet management currently appears on both the Site Deck and the Mine Site. That splits one interaction loop across two surfaces and makes successful spawn/merge actions drop the player's immediate intent:

- a spawned T1 is not selected;
- a successful merge clears selection instead of leaving the upgraded target ready to place.

HPA-452 should make fleet manipulation local to Mine Site gameplay, remove duplicate Site Deck chrome, and keep spawn/merge → deploy continuous without creating another fleet subsystem.

## Goals

- Remove Fleet Dock spawn/select/merge controls from Site Deck in portrait and landscape.
- Keep spawn, select, merge, deploy, and recall inside Mine Site.
- Automatically select the bay actually filled by a successful T1 spawn.
- Keep the upgraded target bay selected after a successful merge.
- Reuse the existing merge-compatibility projection to emphasize valid target bays.
- Show a compact `Tn + Tn → T(n+1) · STRONGER PER SLOT` preview in the existing horizontal Fleet Dock hint line.
- Preserve controller ownership, save format, economy, deploy/recall legality, audio/haptics, reduced motion, and the four-bay dock.

## Non-goals

This PR does not:

- add a second fleet owner, inventory, deployment subsystem, or state-management layer;
- change spawn/merge/deploy/recall rules;
- add or change save fields;
- change rig prices, rate/capacity multipliers, technology multipliers, or balance;
- add drag-and-drop, confirmation dialogs, tutorial state, or another input framework;
- add another Fleet Dock chrome row or generic footer/layout abstraction;
- change HPA-454 resource geometry;
- add HPA-455 HP/damage feedback;
- add HPA-286 Site Deck selling/cargo-full polish;
- generate new image art.

One narrow controller result change is allowed: successful spawn reports the bay it already chose. That exposes an existing mutation fact; it does not move selection into the controller or change gameplay rules.

## Current ownership to preserve

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> Flutter Site Deck / Mine Site / Stellar Map
```

- `MiningController` remains the sole mutation/persistence boundary.
- `MiningSave.docks` remains authoritative fleet state.
- `MiningShell._selectedBayId` remains transient presentation selection.
- `FleetDockView` remains a pure projection.
- `MineSiteView` remains the deploy/recall legality projection.
- Widgets never mutate save state directly.

No second fleet state owner is needed.

## Design decisions

### 1. Fleet Dock becomes Mine Site-only

Remove Fleet Dock from `SiteDeckScreen` in both orientations.

Delete these Site Deck inputs:

- `FleetDockView fleetDock`;
- `onBayTap`;
- `onSpawnRig`.

The Site Deck retains site cards/status, unlock/entry, cash/cargo/progression display, and bottom navigation only.

Because Site Deck is the only `FleetDock.inline` caller, delete `inline` and `_inlineChildren()` rather than preserving dead presentation code.

#### Portrait

Reclaim the bottom space currently reserved for Fleet Dock + navigation. Reserve only the existing 88px navigation height plus safe-area padding. Do not introduce a footer helper.

#### Landscape

Remove the fixed 320px Fleet Dock column and let the site list use the available width. Do not replace the rail with another panel.

#### Shell cut must be atomic with the constructor cut

The same production step that removes Site Deck fleet fields must also stop `MiningShell.build` from constructing/passing fleet data and callbacks to that surface. This keeps the repository compiling after the step instead of deferring shell wiring to a later task.

Build `FleetDockView` only when a Mine Site is open.

### 2. Keep selection transient in MiningShell

Do not persist or move selected bay state into `MiningController`, `MiningSave`, or `FleetDockView`.

`MiningShell._selectedBayId` already has the correct lifetime. Existing `_preserveDockSelection()` remains the final guard that clears selection when the selected bay is no longer occupied.

Active-planet changes continue to clear selection.

### 3. Successful spawn reports the filled bay; the shell does not reconstruct it

`MiningController.spawnRig()` already:

1. chooses the first empty active-planet bay;
2. writes the T1 there;
3. persists;
4. returns `MiningActionResult.success()`.

Expose the chosen bay directly on the existing action result:

```dart
class MiningActionResult {
  const MiningActionResult.success({
    this.message,
    this.dockBayId,
  }) : isSuccess = true;

  const MiningActionResult.failure(this.message)
    : isSuccess = false,
      dockBayId = null;

  final bool isSuccess;
  final String? message;
  final DockBayId? dockBayId;
}
```

`spawnRig()` returns `MiningActionResult.success(dockBayId: emptyBay)`.

Do not add a third result type and do not diff dock maps in the shell. `MiningSaleResult` already establishes that mutation results can carry success payloads when the presentation needs a fact produced by the mutation.

On spawn success, the shell sets `_selectedBayId = result.dockBayId`. On failure, prior selection remains unchanged.

### 4. Successful merge selects the known target bay

`_handleDockBayTap(source -> target)` already knows the target `bayId`; no result payload or state diff is needed.

Remove the eager `_selectedBayId = null` before `mergeDockRigs(...)`.

While persistence is in flight, keep the source selection. After success:

- set `_selectedBayId = targetBay`;
- run `_preserveDockSelection()` against authoritative controller state.

On failure, leave the source selection intact so the player can retry or choose another target.

### 5. Reuse the existing action runner with one narrow success hook

Extend `_runSheetAction(...)` with one optional callback receiving the successful `MiningActionResult`.

Invoke it only after persistence has succeeded and before the existing selection-preservation pass.

Uses:

- spawn reads `result.dockBayId` and selects it;
- merge closes over its already-known target bay and selects it;
- every other call site omits the callback.

Do not turn this into an event bus, reducer, command object, or generic action pipeline.

### 6. Reuse FleetDockView's existing compatibility signal

`FleetDockBayView.canMergeWithSelection` is already the only merge-target compatibility signal. Do not add another compatibility model.

Extend `FleetDockView.from(...)` with one optional pure projection such as:

```dart
String? mergePreview; // "T1 + T1 → T2 · STRONGER PER SLOT"
```

Derive it from the selected non-T5 tier. T5 and no-selection keep the current deploy instruction.

`_BayButton` should use `canMergeWithSelection` for stronger fill/border emphasis. The flag currently exists but is not used by the button's selected/empty/occupied color branches.

### 7. Put merge copy in the existing hint line, not new chrome

The horizontal Fleet Dock already has one one-line instruction beside the FLEET label:

- `TAP A RIG, THEN A NODE`;
- `TAP A NODE TO DEPLOY`.

When a non-T5 rig is selected, reuse that Text for:

`T1 + T1 → T2 · STRONGER PER SLOT`

It already uses one line plus ellipsis, so no dock height change or second chrome strip is required.

The 104px landscape rail keeps its existing compact vertical composition. Do not add another row there; compatible-target emphasis/semantics remain visible without changing rail geometry.

### 8. “Stronger per slot” is the truthful benefit

Authored rig rate multipliers are:

`[1.0, 1.5, 2.25, 3.25, 4.5]`.

Two T1 rigs produce more combined rate than one T2, so do not claim that merging always increases total/combined output. The correct player-facing statement is stronger output per occupied deployment slot.

No balance change belongs in HPA-452.

### 9. Deploy and recall remain unchanged

After spawn/merge selects a dock rig:

- `MineSiteView` projects deployable cells as today;
- a legal cell calls `MiningController.deployRig(...)`;
- deploy empties the selected bay;
- `_preserveDockSelection()` clears that now-empty selection.

Recall remains unchanged and does **not** auto-select the returned rig.

## File-level changes

### `lib/mining/presentation/site_deck_screen.dart`

- remove Fleet Dock imports/fields/callbacks;
- remove portrait inline Fleet Dock;
- remove landscape Fleet Dock column;
- reclaim space while preserving existing navigation.

### `lib/mining/presentation/mining_shell.dart`

- cut Site Deck fleet wiring in the same step as its constructor change;
- create/pass `FleetDockView` only for Mine Site;
- add the narrow `MiningActionResult` success callback to `_runSheetAction`;
- spawn selects `result.dockBayId`;
- merge keeps source selection during persistence and selects target on success.

### `lib/mining/mining_controller.dart`

- add optional `DockBayId? dockBayId` success metadata to `MiningActionResult`;
- return `emptyBay` from successful `spawnRig()`;
- change no mutation rule, persistence ordering, or economy behavior.

### `lib/mining/fleet_dock_view.dart`

- keep `canMergeWithSelection`;
- add optional selected-tier `mergePreview`.

### `lib/mining/presentation/fleet_dock.dart`

- delete `inline`;
- use `canMergeWithSelection` for target emphasis;
- reuse the existing horizontal hint Text for merge preview/copy;
- do not add a second row.

No changes are expected in `mining_state.dart`, `mining_simulation.dart`, or `mining_save_repository.dart`.

## Verification strategy

### Controller result payload

Extend `test/mining/mining_controller_test.dart`:

- successful spawn reports the actual filled `DockBayId`;
- failed spawn reports no `dockBayId`;
- existing spawn state/persistence assertions stay authoritative.

### Site Deck and shell ownership cut

Update `test/mining/presentation/site_deck_screen_test.dart`:

- portrait and landscape contain no `fleet-dock`;
- site entry/unlock/navigation callbacks still work;
- reclaimed content does not overlap the 88px navigation bar;
- interaction-size checks cover only Site Deck-owned controls.

Update `test/mining/presentation/mining_shell_test.dart` in the same task:

- Site Deck HUD now expects Fleet Dock absence;
- any fleet interaction test enters a Mine Site before touching bays/spawn;
- travel/unlock selection-clear tests select the rig in Mine Site first;
- delayed-save spawn, empty-bay reject, mismatched-tier reselect, and stale second spawn are moved to Mine Site;
- the old “Site Deck wires bay selection, merge, spawn…” test is replaced by Mine Site continuity coverage.

Update skipped `visual_parity_golden_test.dart` only so constructors compile; it is not a layout gate.

### Fleet projection/presentation

Extend `test/mining/fleet_dock_view_test.dart`:

- T1/T4 previews project the expected next tier;
- T5/no-selection use no preview;
- busy state still suppresses compatible targets.

Extend `test/mining/presentation/mine_site_screen_test.dart`:

- four bays and spawn remain in portrait/landscape;
- compatible bays expose merge-target emphasis/semantics;
- preview uses the existing hint row;
- existing dock-vs-navigation non-overlap and 104px landscape rail geometry remain green.

### Continuity behavior

In `mining_shell_test.dart` prove behavior rather than private selection:

1. **spawn → deploy**
   - enter Mine Site;
   - spawn;
   - do not tap the new bay;
   - tap a legal perimeter cell;
   - assert T1 deploys.

2. **merge → deploy**
   - enter Mine Site;
   - select source T1;
   - tap compatible T1 target;
   - do not reselect target;
   - tap a legal perimeter cell;
   - assert T2 deploys.

3. **failure preservation**
   - spawn persistence failure does not select a phantom bay;
   - merge/reject paths retain existing authoritative messages/audio.

## Acceptance mapping

- **Site Deck no fleet controls**: constructor/shell ownership cut plus portrait/landscape tests.
- **Spawn immediately placeable**: controller result payload plus spawn→deploy shell test.
- **Merged rig remains ready**: merge→deploy shell test.
- **Merge affordance**: pure preview + existing compatibility flag + existing hint line + target emphasis.
- **Invalid placement/messages unchanged**: no legality/controller-rule changes.
- **No save/economy changes**: save/simulation contracts untouched.

## Assets

No image generation is required. Reuse the current rig art, merge icon, text, and `MiningHex` styling. If dedicated art is later justified, scope it as a separate task.
