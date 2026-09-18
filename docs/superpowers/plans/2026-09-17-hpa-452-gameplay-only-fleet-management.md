# HPA-452 — Gameplay-only Fleet Management Implementation Plan

Date: 2026-09-17  
Linear: HPA-452  
Design: `docs/superpowers/specs/2026-09-17-hpa-452-gameplay-only-fleet-management-design.md`

## Delivery rule

One ticket = one PR.

Keep the complete HPA-452 slice on this branch/PR. Do not split Site Deck cleanup, Fleet Dock feedback, and selection continuity into separate PRs.

No image-generation work is included.

## Baseline

Start from `main` after HPA-454 / PR #30:

- Mine Sites use the deterministic 50×50 / 100-resource grid.
- `MiningShell` owns transient `_selectedBayId`.
- `MiningController` owns spawn/merge/deploy/recall mutations and persistence.
- `FleetDockView` already projects `canMergeWithSelection`.
- `SiteDeckScreen` and `MineSiteScreen` both currently render Fleet Dock controls.
- `MiningActionResult.success` already carries optional success metadata through `message`; `MiningSaleResult` demonstrates result payloads for presentation needs.

The implementation should delete duplicated ownership and add only the smallest result metadata needed for selection continuity.

## Task 1 — Cut Fleet Dock ownership from Site Deck and shell together

This task must leave the repository compiling and its focused tests green. Do not remove Site Deck constructor fields in one step and defer shell callers to a later task.

### Tests first

Update `test/mining/presentation/site_deck_screen_test.dart`:

- remove Fleet Dock fixtures and fleet callbacks from helpers;
- portrait: assert `fleet-dock` is absent;
- landscape: assert `fleet-dock` is absent;
- preserve site entry, site unlock, and bottom-navigation callback assertions;
- replace Fleet Dock interaction-size checks with Site Deck-owned controls only;
- keep the existing safe-area/overlap checks as the layout gate;
- assert reclaimed content still ends above the existing navigation bar.

Update `test/mining/presentation/mining_shell_test.dart` for the ownership move in the same task.

Inventory and adjust every existing Site Deck fleet assumption:

- **renders the Site Deck and active-planet HUD** — expect `fleet-dock` absent;
- **travel clears the selected dock bay before the new planet view** — enter an unlocked Mine Site, select the bay there, then navigate to Stellar Map;
- **planet unlock clears the selected dock bay before activation** — select in Mine Site first;
- **failed persistence rejects the action without success audio** — enter Mine Site before Spawn;
- **Site Deck wires bay selection, merge, spawn, and site entry** — remove as a Site Deck ownership test; its merge/spawn behavior is covered/replaced in Task 3;
- **tapping an empty dock bay rejects with guidance** — enter Mine Site first;
- **tapping a mismatched dock rig reselects it** — enter Mine Site first;
- **a second stale spawn reports the failure politely** — enter Mine Site first;
- keep **pre-initialization renders no enabled mining actions**; `fleet-dock-spawn` remains absent before initialization and Site Deck still contains no dock after initialization.

Do not read private `_selectedBayId` in tests.

Update `test/mining/presentation/visual_parity_golden_test.dart` only to compile with the slimmer Site Deck constructor. Its relevant goldens are already skipped, so it is not a layout acceptance gate.

### Production change

Edit `lib/mining/presentation/site_deck_screen.dart`:

- remove Fleet Dock imports;
- remove `fleetDock`, `onBayTap`, and `onSpawnRig` from `SiteDeckScreen`;
- remove the same inputs from `_PortraitSiteDeck`;
- remove the landscape 320px Fleet Dock column;
- remove the portrait inline Fleet Dock;
- reserve only the existing 88px navigation height plus safe-area padding at the bottom.

Edit `lib/mining/presentation/mining_shell.dart` in the same change:

- do not build/pass `FleetDockView` for Site Deck;
- remove Site Deck `onBayTap` / `onSpawnRig` wiring;
- build `FleetDockView` only in the Mine Site branch.

Edit `lib/mining/presentation/fleet_dock.dart`:

- remove `inline` and `_inlineChildren()`; no caller remains.

Do not add replacement Site Deck chrome or a footer abstraction.

### Focused gate

Run:

```sh
dart format --output=none --set-exit-if-changed   lib/mining/presentation/site_deck_screen.dart   lib/mining/presentation/mining_shell.dart   lib/mining/presentation/fleet_dock.dart   test/mining/presentation/site_deck_screen_test.dart   test/mining/presentation/mining_shell_test.dart   test/mining/presentation/visual_parity_golden_test.dart

flutter test test/mining/presentation/site_deck_screen_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

The Site Deck widget tests, not skipped goldens, are the layout gate.

## Task 2 — Add merge preview and target emphasis without adding chrome

### Tests first

Extend `test/mining/fleet_dock_view_test.dart`:

- selected T1 derives `T1 + T1 → T2 · STRONGER PER SLOT`;
- selected T4 derives `T4 + T4 → T5 · STRONGER PER SLOT`;
- T5 derives no preview;
- no selection derives no preview;
- `canMergeWithSelection` remains the only compatible-target flag;
- busy state still disables compatibility.

Extend `test/mining/presentation/mine_site_screen_test.dart`:

- Mine Site still exposes four bays plus Spawn in portrait;
- Mine Site still exposes four bays plus Spawn in landscape;
- compatible targets expose stable merge-target semantics/keying;
- the horizontal dock uses its existing hint line for the preview;
- existing portrait `dock.overlaps(nav) == false` stays green;
- existing 104px landscape rail containment stays green;
- no additional dock row/height is introduced.

### Production change

Edit `lib/mining/fleet_dock_view.dart`:

- add one nullable `mergePreview` field to `FleetDockView`;
- derive it from the selected non-T5 tier;
- do not add another compatibility flag or mutation behavior.

Edit `lib/mining/presentation/fleet_dock.dart`:

- keep horizontal and vertical modes only;
- in the existing horizontal hint Text, use:
  - normal current instruction with no selection;
  - `mergePreview` for selected non-T5;
  - current deploy instruction for T5;
- use `FleetDockBayView.canMergeWithSelection` for stronger target fill/border;
- keep the vertical 104px rail geometry unchanged; no second preview row;
- reuse existing rig art, merge icon, typography, and `MiningHex`.

The copy is deliberately slot-efficiency language. Current rate multipliers are `1.0, 1.5, 2.25, 3.25, 4.5`, so one merged rig is stronger per occupied deployment slot but does not necessarily out-produce the consumed pair.

### Focused gate

Run:

```sh
flutter test test/mining/fleet_dock_view_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
```

## Task 3 — Report spawn's filled bay and preserve spawn/merge selection continuity

### Controller tests first

Extend `test/mining/mining_controller_test.dart`:

- successful `spawnRig()` returns the actual filled `DockBayId`;
- verify the returned bay matches the bay the controller persisted;
- failed spawn returns no `dockBayId`;
- preserve all existing cost/full-dock/serialization/save-failure assertions.

### Shell tests first

Add/replace behavior coverage in `test/mining/presentation/mining_shell_test.dart`.

#### Spawn → deploy continuity

Arrange an unlocked Landing Basin with a known empty dock bay.

1. Enter Landing Basin.
2. Tap Spawn.
3. Wait for persistence.
4. Do **not** tap the newly filled bay.
5. Tap a legal resource-perimeter cell.
6. Assert the T1 moved from dock to the site.

This proves continuity through public behavior, not private selection.

#### Merge → deploy continuity

Arrange two T1 rigs.

1. Enter Landing Basin.
2. Select source T1.
3. Tap compatible target T1.
4. Wait for persistence.
5. Assert source is empty and target is T2.
6. Do **not** tap target again.
7. Tap a legal placement cell.
8. Assert a T2 rig deploys.

#### Failure behavior

Keep/adjust existing shell tests so:

- spawn save failure plays reject audio and does not fabricate a selected result bay;
- empty-bay reject still shows `Select an occupied rig bay.`;
- mismatched-tier tap still reselects the tapped rig rather than merging;
- stale second spawn still reaches the controller and reports `Not enough cash.`;
- busy input and existing blocked deploy/recall messages remain authoritative.

### Production change — MiningActionResult

Edit `lib/mining/mining_controller.dart`:

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

In `spawnRig()`, return:

```dart
return MiningActionResult.success(dockBayId: emptyBay);
```

Do not change the first-empty-bay loop, mutation ordering, save behavior, or add another result type.

### Production change — MiningShell

Extend `_runSheetAction(...)` with one optional post-success callback receiving `MiningActionResult`.

Required ordering:

1. await the existing controller operation/persistence;
2. if successful, invoke the optional callback;
3. perform existing active-planet clearing / `_preserveDockSelection()`;
4. refresh presentation;
5. keep existing haptic/audio/snackbar behavior.

#### Spawn

`_spawnRig()` uses the success callback:

- read `result.dockBayId`;
- assign it to `_selectedBayId`.

Do not snapshot or diff dock maps in the shell and do not duplicate the controller's first-empty-bay algorithm.

#### Merge

In `_handleDockBayTap(...)`:

- remove the eager `_selectedBayId = null`;
- keep source selected while persistence runs;
- after successful `mergeDockRigs(source, target)`, set `_selectedBayId = target`;
- let `_preserveDockSelection()` validate it;
- on failure, keep source selection.

#### Deploy / recall

Do not change deploy.

Successful deploy empties the selected bay, so existing `_preserveDockSelection()` clears selection.

Do not auto-select recall.

### Focused gate

Run:

```sh
flutter test test/mining/mining_controller_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

## Task 4 — Final ownership inventory and repository gates

Search for stale Site Deck / inline assumptions:

```sh
rg "inline: true|fleetDock:|onBayTap:|onSpawnRig:|fleet-dock-spawn|ValueKey<String>\('b[1-4]'\)"   lib/mining/presentation/site_deck_screen.dart   lib/mining/presentation/mining_shell.dart   test/mining/presentation/site_deck_screen_test.dart   test/mining/presentation/mining_shell_test.dart   test/mining/presentation/visual_parity_golden_test.dart
```

Review each remaining result rather than requiring zero globally:

- Site Deck files should contain no Fleet Dock fields/callbacks.
- Mine Site shell tests may still contain bay/spawn interactions, but only after entering Mine Site.
- skipped golden constructors should compile but are not acceptance evidence.
- `FleetDock` construction should remain only on Mine Site presentation paths.

Run repository gates:

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

## Expected production files

Primary:

- `lib/mining/mining_controller.dart`
- `lib/mining/fleet_dock_view.dart`
- `lib/mining/presentation/fleet_dock.dart`
- `lib/mining/presentation/site_deck_screen.dart`
- `lib/mining/presentation/mining_shell.dart`

Tests:

- `test/mining/mining_controller_test.dart`
- `test/mining/fleet_dock_view_test.dart`
- `test/mining/presentation/site_deck_screen_test.dart`
- `test/mining/presentation/mine_site_screen_test.dart`
- `test/mining/presentation/mining_shell_test.dart`
- `test/mining/presentation/visual_parity_golden_test.dart`

Only add another file for a concrete compiler/regression need. Do not introduce a new fleet/service layer.

## Completion criteria

Implementation is complete when:

- Site Deck has no fleet controls in either orientation;
- Mine Site retains spawn/select/merge/deploy/recall;
- spawn selects the controller-reported filled bay and can deploy without another bay tap;
- merge keeps the upgraded target selected and can deploy without another bay tap;
- compatible merge targets are visibly distinct;
- preview uses the existing hint line and truthful per-slot copy;
- current Mine Site dock/nav geometry remains green;
- existing reject audio and authoritative blocked-action messages remain green;
- save JSON, economy, rate/capacity tables, and deploy/recall legality are unchanged;
- no new image asset is added.

## Scope guardrails

Stop and re-evaluate if implementation starts requiring:

- save migration;
- another fleet owner;
- controller rule redesign beyond the optional success payload;
- economy/rate changes;
- drag/drop;
- new state management;
- a new animation system;
- new image generation;
- HPA-455 HP/damage work;
- HPA-286 Site Deck sell/full-cargo work.

Those are not needed for HPA-452.
