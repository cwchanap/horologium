# HPA-452 — Gameplay-only Fleet Management Implementation Plan

- Date: 2026-09-17
- Linear: HPA-452
- Design: `docs/superpowers/specs/2026-09-17-hpa-452-gameplay-only-fleet-management-design.md`

## Delivery rule

One ticket = one PR.

Keep the complete HPA-452 slice on this branch/PR. Do not split Site Deck cleanup, Fleet Dock feedback, and selection continuity into separate PRs.

No image-generation work is included.

## Task 1 — Cut Fleet Dock ownership from Site Deck and shell together

This task must compile and pass its focused tests before moving on.

### Tests first

Update `test/mining/presentation/site_deck_screen_test.dart`:

- remove Fleet Dock fixtures and fleet callbacks from helpers;
- assert `fleet-dock` is absent in portrait and landscape;
- preserve site entry, unlock, and bottom-navigation callbacks;
- remove Fleet Dock interaction-size assertions;
- pin the reclaimed portrait viewport directly:
  - at 402×874 with zero safe-area inset, `site-deck-scroll` ends at y=778;
  - this corresponds to `bottom: 96`, preserving the existing 8px gap above the 88px navigation bar;
- keep existing card placement/layout assertions where still meaningful.

Update `test/mining/presentation/mining_shell_test.dart` in the same task.

Inventory and move all fleet interactions off Site Deck:

- **renders the Site Deck and active-planet HUD** — expect `fleet-dock` absent;
- **travel clears the selected dock bay before the new planet view** — enter Mine Site, select a bay there, then navigate;
- **planet unlock clears the selected dock bay before activation** — select in Mine Site first;
- **failed persistence rejects the action without success audio** — enter Mine Site before Spawn;
- remove/replace **Site Deck wires bay selection, merge, spawn, and site entry**;
- **tapping an empty dock bay rejects with guidance** — enter Mine Site first;
- **tapping a mismatched dock rig reselects it** — enter Mine Site first;
- **a second stale spawn reports the failure politely** — enter Mine Site first;
- keep existing tests that already enter Mine Site before bay/spawn usage.

Add one behavioral selection-lifetime test:

1. arrange two unlocked sites;
2. enter site A and select a dock rig;
3. Back to Site Deck;
4. enter site B;
5. tap a legal cell without selecting again;
6. assert no rig deployed and `Select a rig from the dock.` is reported.

Do not read `_selectedBayId`.

### Production change

Edit `lib/mining/presentation/site_deck_screen.dart`:

- remove Fleet Dock imports and constructor fields;
- remove portrait inline Fleet Dock;
- remove landscape 320px Fleet Dock column;
- change portrait site-list reserve from `198 + pad.bottom` to `96 + pad.bottom`;
- keep the 88px navigation unchanged.

Edit `lib/mining/presentation/mining_shell.dart` in the same commit:

- stop building/passing `FleetDockView` for Site Deck;
- remove Site Deck `onBayTap` / `onSpawnRig` wiring;
- build `FleetDockView` only for Mine Site;
- clear `_selectedBayId` in `_leaveSite()`;
- clear `_selectedBayId` in `_showPrimarySurface(...)` when leaving Mine Site for another primary surface.

Technology/Settings remain modal overlays over the current Mine Site; do not clear selection merely for opening/dismissing those sheets.

Edit `lib/mining/presentation/fleet_dock.dart`:

- remove `inline` and `_inlineChildren()`.

### Dead golden cleanup

Delete the permanently skipped Site Deck golden block from:

- `test/mining/presentation/visual_parity_golden_test.dart`

Delete:

- `test/mining/presentation/goldens/site_deck_430x932.png`

Leave the unrelated skipped Mine Site/Stellar Map goldens alone.

### Focused gate

Run:

```sh
dart format --output=none --set-exit-if-changed .
flutter test test/mining/presentation/site_deck_screen_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
flutter analyze --fatal-infos
```

The Site Deck widget tests are the layout evidence. The deleted golden is not replaced in this ticket.

## Task 2 — Resolve dock instruction copy in FleetDockView and emphasize merge targets

### Tests first

Extend `test/mining/fleet_dock_view_test.dart` so `dockHint` covers all arms:

- no selection → `TAP A RIG, THEN A NODE`;
- selected T1 → `T1 + T1 = T2 • STRONGER PER SLOT`;
- selected T4 → `T4 + T4 = T5 • STRONGER PER SLOT`;
- selected T5 → `TAP A NODE TO DEPLOY`;
- busy state still disables `canMergeWithSelection`;
- compatible target bays still expose the existing per-bay `Merge with selected bay.` hint.

Extend `test/mining/presentation/mine_site_screen_test.dart`:

- four bays + Spawn remain in portrait and landscape;
- compatible merge target chrome is stronger than normal occupied chrome;
- horizontal Fleet Dock renders the resolved `dockHint`;
- at 360×640, find the stable `fleet-dock-hint` Text and assert its render paragraph does not exceed max lines;
- existing portrait `dock.overlaps(nav) == false` remains green;
- existing 104px landscape right-rail containment remains green;
- landscape adds no second hint row.

### Production change

Edit `lib/mining/fleet_dock_view.dart`:

- add required non-nullable `String dockHint`;
- derive all three instruction states in `FleetDockView.from(...)`;
- keep `canMergeWithSelection` as the sole merge-target signal.

Do **not** add nullable `mergePreview`.

Edit `lib/mining/presentation/fleet_dock.dart`:

- give the existing horizontal hint Text a stable key such as `fleet-dock-hint`;
- render `view.dockHint` directly with no selected/non-selected branch;
- use `canMergeWithSelection` to strengthen target fill/border;
- add no second row;
- leave vertical rail geometry unchanged.

Use exactly the glyph-safe form:

`T1 + T1 = T2 • STRONGER PER SLOT`

Do not use `→` or `·`.

### Focused gate

Run:

```sh
flutter test test/mining/fleet_dock_view_test.dart
flutter test test/mining/presentation/mine_site_screen_test.dart
```

## Task 3 — Report spawn's filled bay and preserve spawn/merge continuity

### Controller tests first

Extend `test/mining/mining_controller_test.dart`:

- successful `spawnRig()` returns the actual filled `DockBayId`;
- returned bay matches the persisted dock mutation;
- failed spawn returns no `dockBayId`;
- existing full-dock, insufficient-cash, serialization, and save-failure behavior remains.

### Production change — shared action result

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

Return `MiningActionResult.success(dockBayId: emptyBay)` from successful `spawnRig()`.

Do not add `MiningSpawnResult`.

Reason: spawn should stay on the existing shared `_runSheetAction` path. `MiningSaleResult` is the cautionary example: its distinct result shape forces `_sellCargo()` to duplicate runner-style orchestration. Do not create another fork.

### Shell tests

Add/replace public-behavior coverage in `test/mining/presentation/mining_shell_test.dart`.

#### Spawn → deploy

1. enter Mine Site;
2. tap Spawn;
3. wait for persistence;
4. do not tap the new bay;
5. tap a legal perimeter cell;
6. assert the new T1 deploys.

#### Merge → deploy

1. enter Mine Site with two T1 rigs;
2. select source;
3. tap compatible target;
4. wait for persistence;
5. assert source empty / target T2;
6. do not tap target again;
7. tap a legal placement cell;
8. assert T2 deploys.

#### Failure/interaction regressions

Keep these authoritative:

- spawn persistence failure → reject audio, no phantom selected bay;
- empty bay → `Select an occupied rig bay.`;
- mismatched tier → tapped rig becomes selected instead of merging;
- stale second spawn → `Not enough cash.`;
- busy node tap → pending-action guidance;
- deploy/recall blocked messages unchanged.

### Production change — MiningShell

Extend `_runSheetAction(...)` with one optional callback receiving the successful `MiningActionResult`.

Ordering is fixed:

1. await persisted action;
2. invoke success callback;
3. apply active-planet clearing or `_preserveDockSelection()`;
4. refresh presentation;
5. play existing haptic/audio and show result.

Do not reorder.

#### Spawn

`_spawnRig()` success callback:

- read `result.dockBayId`;
- assign `_selectedBayId` to that bay.

Do not snapshot/diff docks in the shell.

#### Merge

In `_handleDockBayTap(...)`:

- remove eager selection clearing;
- keep source selected while saving;
- on success, set selection to target bay;
- let `_preserveDockSelection()` validate;
- on failure, source selection remains.

#### Deploy/recall

No deploy change.

Do not auto-select recalled rigs.

### Focused gate

Run:

```sh
flutter test test/mining/mining_controller_test.dart
flutter test test/mining/presentation/mining_shell_test.dart
```

## Task 4 — Final ownership inventory and repository gates

Search the cut surface:

```sh
rg "inline: true|fleetDock:|onBayTap:|onSpawnRig:|fleet-dock-spawn|ValueKey<String>\('b[1-4]'\)"   lib/mining/presentation/site_deck_screen.dart   lib/mining/presentation/mining_shell.dart   test/mining/presentation/site_deck_screen_test.dart   test/mining/presentation/mining_shell_test.dart
```

Review remaining hits:

- Site Deck production/tests contain no Fleet Dock API.
- Mine Site shell tests may contain bay/spawn interactions only after entering Mine Site.
- `FleetDock` construction remains on Mine Site presentation paths only.

Run full gates:

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

## Expected files

Production:

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
- `test/mining/presentation/visual_parity_golden_test.dart` (delete Site Deck block only)
- delete `test/mining/presentation/goldens/site_deck_430x932.png`

No new file is expected.

## Completion criteria

- Site Deck exposes no fleet controls or fleet occupancy summary.
- Portrait Site Deck preserves the 8px gap above navigation and proves the reclaimed scroll viewport.
- Mine Site retains full fleet controls.
- Dock selection is cleared when leaving Mine Site, preventing hidden cross-site deployment.
- Spawn can deploy immediately using the controller-reported bay.
- Merge can deploy immediately using the upgraded target.
- `FleetDockView.dockHint` fully resolves instruction copy.
- Portrait merge copy uses `=` and `•`, is not truncated at 360×640, and claims only stronger per slot.
- Landscape merge affordance remains target emphasis + existing bay semantics; the 104px rail does not grow.
- Existing reject audio and blocked-action messages remain authoritative.
- Save JSON, economy, rate/capacity tables, and deploy/recall legality are unchanged.
- No new image asset is added.

## Accepted product tradeoffs

- Fleet occupancy is no longer visible from Site Deck. This is intentional for HPA-452; do not add compact fleet summary chrome.
- The detailed merge hint is portrait-only. Landscape deliberately relies on target highlighting and the existing `Merge with selected bay.` semantics to protect rail geometry.

## Scope guardrails

Stop and re-evaluate if implementation starts requiring:

- save migration;
- another fleet owner;
- controller rule redesign beyond optional result metadata;
- economy/rate changes;
- drag/drop;
- new state management;
- new animation systems;
- new image generation;
- HPA-455 HP/damage work;
- HPA-286 Site Deck sell/full-cargo work.
