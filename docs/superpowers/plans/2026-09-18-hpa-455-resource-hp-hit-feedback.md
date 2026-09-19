# HPA-455 — Resource HP and robot hit-feedback implementation plan

## Delivery rule

Implement HPA-455 in this same draft PR. Do not open a second implementation PR.

The slice stays presentation-only: no save migration, controller mutation, simulation formula, resource depletion, new image art, new semantics owner, or new audio subsystem.

## Design reference

- docs/superpowers/specs/2026-09-18-hpa-455-resource-hp-hit-feedback-design.md

## Task 1 — Freeze the presentation contract in focused widget tests

Files:

- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

Add small test helpers that can:

- identify one mined resource by deterministic geometry;
- find a keyed HP widget such as `landing-basin-hp-<x>-<y>-<size>`;
- read visible HP text such as `70/80`;
- find one keyed damage label by rig cell;
- build two legal rigs targeting the same resource from real HPA-454 perimeter geometry.

Do **not** add HP-specific semantics solely to make tests convenient. `MiningGridMap` already owns the resource semantics nodes; HPA-455 chrome is found by deterministic keys and visible text.

Add failing tests for:

1. a mined 2x2 resource starts at `80/80`, while unmined resources have no HP HUD;
2. one warmed T1 visible strike changes `80/80 -> 70/80` and shows one `-10`;
3. one warmed T5 visible strike changes `80/80 -> 30/80` and shows one `-50`;
4. two warmed rigs targeting one resource show one label per rig and subtract grouped damage from one shared HP value;
5. a mixed-tier pair (for example T1 + T5) subtracts 60, proving damage is not `minerCount * constant`;
6. pumping additional frames in the same impact does not apply the strike twice;
7. after one real strike changes `80 -> 70`, changing MineSiteView cargo/progress without a new impact keeps HP at 70;
8. reduced-motion mode still changes HP and displays the damage number, with no translated damage-label transform;
9. a cold-cache first impact dropped by the existing 200 ms deferral budget leaves HP at max and shows no damage;
10. a warmed impact pumped directly past the valid contact window (`t >= 0.62`) is a late miss: HP remains max and no damage appears;
11. unmounting/remounting the layer resets transient HP to max and does not replay the previous strike.

Visible-strike tests must use the existing reliable pattern:

- `await warmGoldFrames(tester)`;
- `skip: kIsWeb`.

That includes the reduced-motion HP test. The existing reduced-motion transform-only test can remain cold because it does not assert a real strike.

The cold-cache drop test intentionally does **not** warm frames and remains runnable on both VM and web.

Checkpoint: the focused file fails only for missing HPA-455 behavior; existing HPA-451 frame/sound tests remain green.

## Task 2 — Add transient HP and reuse the existing visible-contact latch

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

Add private helpers beside the existing visual math:

- `maxHp(size) => size * 40`;
- `damage(tier) => (tier.index + 1) * 10`;
- grouped damage by `MineSiteRigView.target`;
- clamp remaining HP at zero with no overkill carry.

Add one private remaining-HP map keyed by `MiningDepositDefinition`.

Use one private sync helper:

- call from `initState` to seed all currently mined deposits at max HP;
- call from `didUpdateWidget` to add newly mined targets and prune targets whose `minerCount` becomes zero;
- never initialize/prune HP from `build()`.

Reuse the existing `_notifyMiningImpact` listener and its current once-per-visible-impact latch. Do **not** add `_appliedFeedbackSequence`, a second animation listener, a queue, or a timer.

At the existing listener:

1. before `0.46`: do nothing;
2. when the existing latch first trips: mark the contact handled;
3. if the controller is already at or beyond `0.62`: treat the strike as missed/late and do not change HP;
4. otherwise group current rigs by target and subtract their fixed tier damage once;
5. call `onMiningImpact` exactly as today only when reduced motion is off.

The HP mutation must happen **before** the reduced-motion SFX guard so reduced motion still receives HP/damage feedback.

The existing controller notification drives the current `AnimatedBuilder`; do not call `setState` solely for contact.

At `t >= 0.62`, in that same listener, restore any zero-HP mined entry to max. This is an idempotent second threshold on the same timeline, not another sequence latch.

Cold-frame behavior remains authoritative:

- `_deferImpact` parks the controller and keeps the contact latch handled;
- if the 200 ms cap drops the impact, the controller jumps to rest without ever applying HP;
- if frames become ready in time, `_fireImpact` opens the existing latch and the normal `0.46..0.62` path applies.

Checkpoint:

- Task 1 HP math/contact tests pass;
- existing HPA-451 sound, finite-frame, cold-drop, and late-miss tests pass unchanged.

## Task 3 — Render compact keyed HP/damage chrome on the authored timeline

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

### HP bar

For deposits with `minerCount > 0` only:

- position one compact bar above the resource footprint;
- derive a bounded visual width from footprint size;
- show visible `remaining/max` text;
- use a deterministic key: `landing-basin-hp-<x>-<y>-<size>`;
- wrap in `ExcludeSemantics`;
- keep it non-interactive / pointer-transparent.

Do not add a second resource semantics node and do not change `MineSiteView` or `MiningGridMap._depositLabel`.

### Damage labels

Render one label per current rig only while:

`0.46 <= t < 0.62`

- key: `landing-basin-damage-<cell.x>-<cell.y>`;
- text: fixed tier value such as `-10`;
- anchor between the rig and target center;
- use a deterministic small offset for multiple rigs on one target;
- normal motion: upward drift + fade across the existing `0.46..0.62` window;
- reduced motion: fade in place; no positional translation;
- wrap in `ExcludeSemantics`.

No label history list is needed: current rigs + tier damage + `_t` derive the current frame.

### Zero-HP beat / reset

When a valid contact clamps a resource to zero:

- show zero HP during the same `0.46..0.62` contact/recoil window;
- optionally apply a small non-economic visual emphasis to that mined resource;
- reduced motion must avoid positional shake;
- restore to max exactly at the existing `0.62` recoil knot.

Do not introduce `0.70`, another timer, or another animation controller.

Add/complete tests proving:

- zero is observable before `0.62`;
- at `0.62` the cycle is back at max;
- the next warmed strike damages that fresh cycle exactly once;
- labels disappear at `0.62`;
- reduced motion has no translated label;
- only mined resources get HP/damage chrome.

Checkpoint: focused layer tests all pass.

## Task 4 — Preserve dense-field/remount/lifecycle boundaries

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart
- test/mining/presentation/mining_shell_test.dart only if a concrete integration gap remains
- CLAUDE.md

Audit against HPA-451/HPA-454:

- unmined ~100-resource static layer stays in `RepaintBoundary` / `AnimatedBuilder.child`;
- only mined resources, rigs, and their small feedback chrome rebuild per animation frame;
- leaving Mine Site disposes the layer, so remount starts at max HP;
- lifecycle/offline accrual does not synthesize visible HP changes or labels;
- one valid visible impact still emits at most one mining SFX;
- reduced motion still receives HP/value feedback without motion/SFX;
- no new state appears in `MiningSave`, `MiningController`, `MiningSimulation`, `MiningContentRegistry`, or `MineSiteView`.

The focused remount test is the primary HPA-455 ownership proof. Add a `mining_shell_test.dart` case only if implementation shows `_leaveSite` does not actually dispose/remount the visual as the current shell structure implies.

Update `CLAUDE.md` with one concise note:

- Landing Basin resource HP/damage is transient visual-layer state;
- it is applied only by the existing valid visible-contact latch;
- it resets on remount and never feeds production/save state.

Checkpoint: focused presentation tests and existing shell lifecycle tests pass.

## Task 5 — Visual gate and repository verification

Manual portrait gate at 430x932:

1. one T1 rig: compact HP bar and synchronized `-10`;
2. two rigs on one resource: one shared HP cycle and two readable labels;
3. mixed/higher tiers: numbers visibly match fixed tier damage;
4. zero HP holds through contact and refreshes at recoil;
5. reduced motion: no damage-label travel or shake, but HP/value feedback remains;
6. pan/zoom: HUD stays limited to mined resources and does not make the 100-resource field noisy.

No new image asset should be added. If existing art cannot support a readable completion beat, create a separate image-generation task instead of expanding HPA-455.

Run focused checks first, then the repository gate from `CLAUDE.md`:

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test`
- `flutter test --coverage`
- `flutter test --platform chrome`
- `flutter build apk --debug`
- `flutter build web`
- `flutter build ios --simulator --debug`

## Expected production diff

Primary:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- CLAUDE.md

Tests:

- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

Avoid production edits outside those files unless implementation uncovers a concrete mismatch with current main. In particular, do not preemptively change:

- lib/mining/mine_site_view.dart
- lib/mining/presentation/mining_grid_map.dart
- lib/mining/presentation/mining_shell.dart
- lib/mining/mining_controller.dart
- lib/mining/mining_simulation.dart
- lib/mining/mining_save_repository.dart
- lib/mining/mining_content.dart

## Completion checklist

- max HP is private arithmetic: footprint x 40;
- T1-T5 damage is private arithmetic: `(tier.index + 1) * 10`;
- no second contact/sequence latch exists;
- cold-drop and late-miss paths cannot alter HP;
- each valid visible contact applies grouped damage exactly once;
- multi-rig same-resource hits share one HP cycle while keeping per-rig labels;
- zero HP refreshes at the existing `0.62` recoil knot;
- HP/damage chrome uses keys + visible text and `ExcludeSemantics`, not a second deposit semantics node;
- reduced motion preserves readable value/HP feedback;
- remount resets HP to max;
- no save/economy/controller/content/view-model changes;
- no new art or audio subsystem;
- full repository gate and manual portrait gate pass;
- implementation remains in this single PR.