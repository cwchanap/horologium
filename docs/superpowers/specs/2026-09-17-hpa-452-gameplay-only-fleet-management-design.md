# HPA-452 — Gameplay-only Fleet Management Design

- Date: 2026-09-17
- Status: Draft implementation design
- Linear: HPA-452 — [Mining Polish] Make fleet management gameplay-only and streamline merge/deploy
- Baseline: `main` at `844e4a77243ad915a347c14e4c6bbfe696870c1c` after HPA-454 / PR #30

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
- Resolve Fleet Dock instructional copy in the pure read model.
- In portrait, show a compact `Tn + Tn = T(n+1) • STRONGER PER SLOT` hint in the existing one-line instruction row.
- Make dock selection Mine-Site-local: leaving Mine Site clears the armed bay selection.
- Preserve controller ownership, save format, economy, deploy/recall legality, audio/haptics, reduced motion, and the four-bay dock.

## Non-goals

This PR does not:

- add a second fleet owner, inventory, deployment subsystem, or state-management layer;
- change spawn/merge/deploy/recall rules;
- add or change save fields;
- change rig prices, rate/capacity multipliers, technology multipliers, or balance;
- add drag-and-drop, confirmation dialogs, tutorial state, or another input framework;
- add another Fleet Dock chrome row or generic footer/layout abstraction;
- add fleet summary/occupancy chrome back to Site Deck;
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

The current Site Deck leaves an 8px gap between Fleet Dock and the 88px navigation bar. After removing Fleet Dock, preserve that visual breathing room:

- site-list bottom reserve becomes `96 + pad.bottom`;
- navigation remains the existing 88px non-compact bar;
- no footer helper or replacement panel is introduced.

Pin the reclaim by asserting the `site-deck-scroll` viewport rect/bottom edge, not only fixed card positions.

#### Landscape

Remove the fixed 320px Fleet Dock column and let the site list use the available width. Do not replace the rail with another panel.

#### Shell cut must be atomic with the constructor cut

The same production step that removes Site Deck fleet fields must also stop `MiningShell.build` from constructing/passing fleet data and callbacks to that surface. This keeps the repository compiling after the step instead of deferring shell wiring to a later task.

Build `FleetDockView` only when a Mine Site is open.

### 2. Selection is Mine-Site-local

Do not persist or move selected bay state into `MiningController`, `MiningSave`, or `FleetDockView`.

`MiningShell._selectedBayId` remains the right transient owner, but its lifetime changes explicitly:

- selection may persist while staying inside the same Mine Site, including modal Technology/Settings overlays;
- `_leaveSite()` clears selection when returning to Site Deck;
- `_showPrimarySurface(...)` clears selection when leaving Mine Site for another primary surface such as Stellar Map;
- active-planet changes continue to clear selection;
- entering another Mine Site always starts unarmed unless the user selects/spawns/merges there.

This prevents a hidden selection made in one Mine Site from silently deploying on the first legal cell tapped in another site.

Pin this behavior through public interaction:

1. enter site A;
2. select a dock rig;
3. Back;
4. enter site B;
5. tap a legal cell;
6. assert no deployment occurred and the normal “Select a rig from the dock.” guidance is shown.

Do not read private `_selectedBayId`.

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

Do not add `MiningSpawnResult` and do not diff dock maps in the shell.

The important precedent is not “sale has a payload”; it is that spawn should remain on the shared `_runSheetAction` path. `MiningSaleResult` requires the separate `_sellCargo()` orchestration because it cannot flow through that runner. Extending `MiningActionResult` avoids creating another hand-rolled mutation path for spawn.

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

Required ordering:

1. await controller mutation + persistence;
2. on success, invoke the callback;
3. apply existing active-planet selection clearing or `_preserveDockSelection()`;
4. refresh presentation;
5. keep existing haptic/audio/snackbar behavior.

The callback may assign `_selectedBayId` directly; the following `_refreshPresentation()` already calls `setState`.

Uses:

- spawn reads `result.dockBayId` and selects it;
- merge closes over its already-known target bay and selects it;
- every other call site omits the callback.

Do not turn this into an event bus, reducer, command object, or generic action pipeline.

### 6. FleetDockView resolves all dock instruction copy

`FleetDockBayView.canMergeWithSelection` remains the only merge-target compatibility signal. Do not add another compatibility model.

Instead of nullable `mergePreview`, add one non-nullable resolved string:

```dart
final String dockHint;
```

`FleetDockView.from(...)` resolves all horizontal instruction states:

- no selection: `TAP A RIG, THEN A NODE`;
- selected T1–T4: e.g. `T1 + T1 = T2 • STRONGER PER SLOT`;
- selected T5: `TAP A NODE TO DEPLOY`.

This follows the existing `spawnHint` and per-bay `hint` convention: widgets render resolved copy instead of rebuilding state logic.

`fleet_dock.dart` renders `Text(view.dockHint)` with no selected/non-selected branch.

### 7. Merge copy uses shipped glyphs and stays in the existing row

Use:

`T1 + T1 = T2 • STRONGER PER SLOT`

Do not use the Unicode arrow `→` or middle dot `·` for this new affordance. The shipped Orbitron font does not map those glyphs consistently, while `=`, `+`, `>` and `•` are available; using `=` plus the existing bullet avoids platform font fallback in the visual center of the hint.

The horizontal Fleet Dock already has one one-line ellipsized instruction beside the FLEET label. Reuse it; add no second row.

At the narrow 360×640 Mine Site size, assert the preview does **not** truncate. Give the Text a stable key such as `fleet-dock-hint` and inspect its rendered paragraph so `didExceedMaxLines == false`.

### 8. Merge-target emphasis reuses canMergeWithSelection

`_BayButton` should use `canMergeWithSelection` for stronger fill/border emphasis. The signal already exists; the button currently ignores it in its selected/empty/occupied color branches.

No additional compatibility state is introduced.

### 9. “Stronger per slot” is the truthful benefit

Authored rig rate multipliers are:

`[1.0, 1.5, 2.25, 3.25, 4.5]`.

Two same-tier lower rigs always have greater combined rate than the merged next-tier rig. Merging pays under the four-slot deployment constraint by concentrating more rate into one slot.

Do not claim “more output”, “double output”, or higher combined DPS.

### 10. Portrait and landscape affordances deliberately differ

Portrait:

- the existing hint row displays `dockHint`;
- compatible bays get stronger merge-target chrome.

Landscape:

- the 104px vertical rail gains **no new hint row**;
- merge affordance is the compatible bay emphasis plus existing per-bay semantics/hint `Merge with selected bay.`.

This is deliberate to protect the current rail geometry.

### 11. Dock occupancy is intentionally invisible outside Mine Site

Removing Fleet Dock from Site Deck also removes at-a-glance idle fleet occupancy from that surface.

That is an accepted product tradeoff of “fleet management is gameplay-only.” Do not re-add a fleet count, idle-rig chip, or compact dock summary in HPA-452.

If later playtesting proves fleet visibility is needed outside Mine Site, scope that separately from fleet management controls.

### 12. Deploy and recall remain unchanged

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
- set portrait scroll reserve to `96 + pad.bottom`;
- retain Site Deck navigation and status/card ownership.

### `lib/mining/presentation/mining_shell.dart`

- cut Site Deck fleet wiring in the same step as its constructor change;
- create/pass `FleetDockView` only for Mine Site;
- clear `_selectedBayId` when leaving Mine Site via Back/primary navigation;
- add the narrow `MiningActionResult` success callback to `_runSheetAction`;
- spawn selects `result.dockBayId`;
- merge keeps source selection during persistence and selects target on success.

### `lib/mining/mining_controller.dart`

- add optional `DockBayId? dockBayId` success metadata to `MiningActionResult`;
- return `emptyBay` from successful `spawnRig()`;
- change no mutation rule, persistence ordering, or economy behavior.

### `lib/mining/fleet_dock_view.dart`

- keep `canMergeWithSelection`;
- add non-nullable resolved `dockHint`.

### `lib/mining/presentation/fleet_dock.dart`

- delete `inline`;
- use `canMergeWithSelection` for target emphasis;
- render `view.dockHint` in the existing horizontal hint Text;
- do not add a second row or vertical hint.

### Test cleanup

Delete the permanently skipped Site Deck golden block from `test/mining/presentation/visual_parity_golden_test.dart` and delete `test/mining/presentation/goldens/site_deck_430x932.png`.

Leave the unrelated skipped Mine Site/Stellar Map goldens alone.

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
- `site-deck-scroll` bottom is pinned to the 96px reserve at the authored test size;
- interaction-size checks cover only Site Deck-owned controls.

Update `test/mining/presentation/mining_shell_test.dart` in the same task:

- Site Deck HUD expects Fleet Dock absence;
- fleet interaction tests enter Mine Site before bays/spawn;
- leaving Mine Site clears armed selection;
- travel/unlock selection-clear tests select in Mine Site first;
- delayed-save spawn, empty-bay reject, mismatched-tier reselect, and stale second spawn stay covered.

### Fleet projection/presentation

Extend `test/mining/fleet_dock_view_test.dart`:

- no selection resolves `TAP A RIG, THEN A NODE`;
- T1/T4 resolve the expected merge hint;
- T5 resolves `TAP A NODE TO DEPLOY`;
- busy state still suppresses compatible targets.

Extend `test/mining/presentation/mine_site_screen_test.dart`:

- four bays and spawn remain in portrait/landscape;
- compatible bays expose existing merge-target semantics and stronger chrome;
- 360×640 hint does not exceed one line;
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

3. **site exit clears selection**
   - enter site A and select a rig;
   - Back;
   - enter site B;
   - tap a legal cell;
   - assert no deployment and normal selection guidance.

4. **failure preservation**
   - spawn persistence failure does not select a phantom bay;
   - merge/reject paths retain existing authoritative messages/audio.

## Acceptance mapping

- **Site Deck no fleet controls**: constructor/shell ownership cut plus portrait/landscape tests.
- **Site Deck reclaim**: 96px reserve + viewport rect assertion preserves the current 8px navigation gap.
- **Spawn immediately placeable**: controller result payload plus spawn→deploy shell test.
- **Merged rig remains ready**: merge→deploy shell test.
- **No hidden cross-screen armed selection**: selection clears on Mine Site exit and is pinned behaviorally.
- **Merge affordance**: pure `dockHint`, existing compatibility flag, portrait hint row, and target emphasis.
- **Landscape merge affordance**: target emphasis + existing bay semantics only; no rail growth.
- **Fleet visibility outside gameplay**: intentionally removed with Site Deck dock; no replacement summary in this ticket.
- **Invalid placement/messages unchanged**: no legality/controller-rule changes.
- **No save/economy changes**: save/simulation contracts untouched.

## Assets

No image generation is required. Reuse the current rig art, merge icon, text, and `MiningHex` styling. If dedicated art is later justified, scope it as a separate task.
