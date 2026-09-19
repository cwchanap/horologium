# HPA-455 — Resource HP and robot hit-feedback implementation plan

## Delivery rule

Implement HPA-455 in this same draft PR. Do not open a second implementation PR.

The slice stays presentation-only: no save migration, controller mutation, simulation formula, resource depletion, new image art, or new audio subsystem.

## Design reference

- docs/superpowers/specs/2026-09-18-hpa-455-resource-hp-hit-feedback-design.md

## Task 1 — Freeze the presentation contract in focused widget tests

Files:

- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

Add test helpers that can:

- identify one mined resource by deterministic geometry;
- read that resource's HP semantics/value;
- find damage labels by rig cell or deterministic key;
- build two rigs targeting the same resource using the real HPA-454 perimeter geometry.

Add failing tests for:

1. one T1 strike changes a 2x2 mined resource from 80 to 70 and shows one -10 label;
2. one T5 strike changes the same resource from 80 to 30 and shows one -50 label;
3. two rigs on the same resource show two per-rig labels and subtract combined damage from one HP value;
4. unmined resources render no HP HUD;
5. pumping additional frames in the same impact sequence does not apply damage twice;
6. changing MineSiteView cargo/progress without a new visible impact leaves HP unchanged;
7. reduced-motion mode still changes HP and displays damage.

Keep these tests at the widget boundary rather than introducing a public feedback model solely for tests.

Checkpoint: focused test file should fail for the missing HPA-455 behavior while existing HPA-451 tests remain green.

## Task 2 — Add transient shared resource HP at the existing strike contact

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

Inside the existing Landing Basin visual layer:

- add private pure max-HP lookup by resource footprint: 40 / 80 / 120;
- add private pure damage lookup by rig tier: 10 / 20 / 30 / 40 / 50;
- keep one private remaining-HP map keyed by MiningDepositDefinition;
- initialize/prune the map from currently mined deposits when the view changes;
- track which impactSequence has already applied feedback;
- apply feedback only when the real running impact crosses the existing contact point;
- group rigs by target resource for the HP subtraction;
- keep one damage value per rig for rendering;
- preserve the current one-per-impact onMiningImpact callback.

The cold-frame path is important: a deferred impact that is dropped by the existing 200 ms safety cap must not change HP, because no visible strike occurred.

Do not change MiningShell, MineSiteView, MiningController, MiningSimulation, or persistence for this task.

Checkpoint:

- focused tests from Task 1 pass;
- existing Landing Basin frame/sound/deferred-impact tests pass.

## Task 3 — Render compact HP, damage numbers, and the zero-HP refresh beat

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

Add mined-resource-only presentation:

### HP bar

- position above each mined resource;
- derive width from its footprint with a small bounded visual width;
- show current/max HP;
- expose a deterministic key and semantics label for regression tests;
- IgnorePointer so grid interactions remain owned by MiningGridMap.

### Damage labels

- derive one label from each current rig and its fixed tier damage;
- anchor between rig cell and target center;
- offset labels deterministically when several rigs share a target;
- normal motion: brief upward drift plus fade;
- reduced motion: fade in place, no translation.

### Break/reset

- when grouped damage reaches zero, keep zero visible briefly;
- use the current impact timeline for the completion emphasis;
- do not add a Timer per resource;
- reset to max around normalized time 0.70 on that same impact;
- ignore overkill rather than carrying it into the next cycle.

Add tests for:

- zero HP is observable before reset;
- the resource returns to max in the same impact timeline;
- a subsequent impact damages the fresh cycle once;
- reduced motion does not apply positional translation to the damage label;
- only mined resources participate in HP/damage overlays.

Checkpoint: focused layer tests all pass.

## Task 4 — Preserve dense-field and lifecycle boundaries

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart
- test/mining/presentation/mining_shell_test.dart only if a concrete regression gap is found
- CLAUDE.md

Audit the implementation against the already-landed HPA-451/HPA-454 constraints:

- unmined ~100-resource static layer remains inside RepaintBoundary / AnimatedBuilder.child;
- only mined resources, rigs, and their compact feedback rebuild per animation frame;
- leaving/re-entering the site naturally resets presentation HP;
- lifecycle resume and offline accrual do not replay HP or labels;
- one impact still emits at most one mining SFX;
- no new state appears in MiningSave or MiningController.

Update CLAUDE.md with one concise architecture note: resource HP/damage is transient Landing Basin presentation state driven by the visible impact sequence and never feeds production.

Do not duplicate existing shell lifecycle tests unless HPA-455 introduces a new behavior they do not cover.

Checkpoint: focused presentation tests plus mining_shell_test.dart pass.

## Task 5 — Visual gate and repository verification

Manual portrait gate at 430x932:

1. one T1 rig: compact HP bar and synchronized -10;
2. two rigs on one resource: shared HP and two readable labels;
3. higher-tier rig: visibly larger fixed number;
4. zero-HP completion/reset beat;
5. reduced motion: no positional travel/shake;
6. pan/zoom: HUD remains limited to mined resources and does not make the 100-resource field noisy.

No new image asset should be added. If existing art cannot support a readable completion beat, stop and create a separate image-generation ticket instead of expanding HPA-455.

Run focused checks first, then the repository gate from CLAUDE.md:

- dart format --output=none --set-exit-if-changed .
- flutter analyze --fatal-infos
- flutter test
- flutter test --coverage
- flutter test --platform chrome
- flutter build apk --debug
- flutter build web
- flutter build ios --simulator --debug

## Expected production diff

Primary:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- CLAUDE.md

Tests:

- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

Avoid production edits outside those files unless implementation uncovers a concrete mismatch with current main. In particular, do not preemptively change:

- lib/mining/mine_site_view.dart
- lib/mining/presentation/mining_shell.dart
- lib/mining/mining_controller.dart
- lib/mining/mining_simulation.dart
- lib/mining/mining_save_repository.dart
- lib/mining/mining_content.dart

## Completion checklist

- fixed footprint HP values are pinned;
- fixed T1-T5 presentation damage is pinned;
- each visible strike updates feedback exactly once;
- multi-rig same-resource hits share one HP cycle while keeping per-rig labels;
- zero HP refreshes without resource removal or production changes;
- reduced motion preserves readable value/HP feedback;
- dropped/deferred historical impacts do not fabricate HP changes;
- no save/economy/controller changes;
- no new art or audio subsystem;
- full repository gate and manual portrait gate pass;
- implementation remains in this single PR.