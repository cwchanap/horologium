# HPA-455 — Resource HP and robot hit-feedback implementation plan

## Delivery rule

Implement HPA-455 in this same draft PR. Do not open a second implementation PR.

The slice stays presentation-only: no save migration, controller mutation, simulation formula, resource depletion, new image art, new semantics owner, or new audio subsystem.

## Design reference

- docs/superpowers/specs/2026-09-18-hpa-455-resource-hp-hit-feedback-design.md

## Task 1 — Add and verify pure feedback math

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

Add narrow top-level functions in the existing visual-layer file:

- `landingBasinMaxHp(int size)`
- `landingBasinStrikeDamage(RigTier tier)`
- `landingBasinGroupedDamage(Iterable<MineSiteRigView> rigs)`
- `landingBasinRemainingHpAfterStrike(int remainingHp, int damage)`

Keep them as plain functions: no model class, registry, service, or new file.

Add pure tests that run without asset warming and therefore execute on both normal VM tests and `flutter test --platform chrome`:

1. max HP is 40 / 80 / 120 for 1x1 / 2x2 / 3x3;
2. T1–T5 damage is 10 / 20 / 30 / 40 / 50;
3. T1 + T5 targeting one resource groups to 60;
4. rigs targeting different resources stay in separate groups;
5. remaining HP clamps at zero and overkill is discarded.

Use real `MineSiteRigView.target` values from HPA-454 geometry; do not test via `minerCount`.

Checkpoint: focused test file is green, with no player-visible behavior change yet.

## Task 2 — Add transient HP, reuse the contact latch, and render the HP bar

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart

### HP state

Add one private remaining-HP map keyed by `MiningDepositDefinition`.

Use one sync helper:

- seed currently mined resources from `initState`;
- in `didUpdateWidget`, add newly mined resources at max and prune resources that are no longer mined;
- never initialize/prune from `build()`.

### Existing contact latch only

Rename the existing `_impactSoundFired` bool to `_impactContactHandled` because it now gates both visible feedback and the SFX callback. This is the same single bool, not another latch.

Adjust `_notifyMiningImpact`:

1. if already handled or `t < 0.46`, return;
2. if `t >= 0.62`, return as a late miss without marking handled;
3. mark the existing bool handled;
4. group current rigs and apply HP once;
5. only then apply the existing reduced-motion guard around `onMiningImpact`.

Do not add an impact-sequence flag, second listener, timer, queue, or contact `setState`.

A cold deferred impact continues to park with the contact bool handled. A dropped impact therefore never mutates HP. `_fireImpact` opens the same bool before running a real impact.

### Break backing state

Add one private `Set<MiningDepositDefinition> _brokeOnContact`.

At valid contact:

- if damage leaves HP above zero, store the new HP;
- if it reaches zero, immediately store the target's fresh max HP for the next cycle and add the target to `_brokeOnContact`.

Clear the set in `_fireImpact` before `forward(from: 0)`. Do not add a 0.62 reset mutation.

### HP chrome

For mined resources only, render a sibling `Positioned` HP widget in the animated layer.

Reuse existing conventions:

- call the existing `_depositKey(...)` helper for its key suffix;
- use `ClipRRect + LinearProgressIndicator + MiningTheme`, matching Site Deck's progress idiom;
- show visible `remaining/max` text;
- wrap in `ExcludeSemantics`;
- do not add another `IgnorePointer`: `MiningGridMap` already ignores the whole object layer.

Position the bar relative to the **oversized resource art** using `depositVisualSize(...)`, centered above its visual bounds. Keep it a sibling of `_depositNode`, not a descendant, so existing frame tests still find exactly one Image below each deposit key.

Displayed HP is derived:

- normally: backing remaining HP;
- if the target is in `_brokeOnContact` during `0.46 <= t < 1.0`: display zero;
- at `t = 1.0`: display the already-stored fresh max HP.

Add focused widget tests for:

- mined HP chrome exists; unmined does not;
- one warmed valid T1 contact changes visible `80/80 -> 70/80` exactly once;
- strike once, then update cargo/progress without a new impact: visible HP stays 70;
- cold-cache drop keeps `80/80`;
- warmed late miss at/after 0.62 keeps `80/80`;
- unmount/remount returns to `80/80`.

Any visible-strike test must use `warmGoldFrames(tester)` and `skip: kIsWeb`. The cold-drop test stays cold and cross-platform.

Checkpoint: focused tests and existing HPA-451 frame/sound tests are green.

## Task 3 — Add readable damage/break feedback and finish the architecture note

Files:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- test/mining/presentation/landing_basin_grid_visual_layer_test.dart
- CLAUDE.md
- test/mining/presentation/mining_shell_test.dart only if a concrete shell integration gap remains

### Damage labels

After a valid contact, render one label per current rig while:

`0.46 <= t < 1.0`

Only show labels when `_impactContactHandled` is true for the current impact. That keeps cold-drop and late-miss paths empty without a second validity flag.

Use:

- key `landing-basin-damage-<cell.x>-<cell.y>`;
- text from `landingBasinStrikeDamage(rig.placement.tier)`;
- anchor at the rig→target midpoint;
- no extra shared-target offset: rig cells are unique, so their midpoints are already distinct;
- normal motion: upward drift + fade from contact to timeline end;
- reduced motion: fade in place, no translation;
- `ExcludeSemantics`.

Do not create a label history list or overlay framework.

### Break beat

For targets in `_brokeOnContact`:

- visible HP remains zero through the rest of the current impact (`0.46..1.0`);
- normal motion may use a small scale/opacity emphasis;
- reduced motion uses non-positional emphasis only;
- at timeline end the already-stored next-cycle max becomes visible automatically.

There is no post-contact HP mutation, 0.62 reset branch, or second threshold.

Add focused widget tests for:

- one valid multi-rig impact renders one label per rig;
- reduced motion still applies HP and renders the value with no translated label;
- a breaking hit shows visible zero after contact and fresh max at timeline end;
- labels are gone at timeline end;
- cold-drop and late-miss paths still show no labels.

Pure Task 1 tests already cover tier scaling, mixed-tier grouping, clamp, and overkill; do not duplicate those across many warmed widget tests.

### Architecture audit / guidance

Keep:

- static unmined ~100-resource layer inside `RepaintBoundary / AnimatedBuilder.child`;
- no production changes to `MineSiteView`, `MiningGridMap`, `MiningShell`, controller, simulation, save repository, or content;
- one mining SFX per valid visible impact;
- remount resets transient HP;
- lifecycle/offline accrual never replays HP/damage history.

Update `CLAUDE.md` with one concise note that Landing Basin HP/damage is transient visual-layer state driven by the existing valid-contact latch and never feeds persistence or production.

Add a shell test only if implementation proves the focused layer remount test cannot establish disposal/reset behavior.

Checkpoint: focused tests plus existing shell lifecycle tests are green.

## Final visual/repository gate

Manual portrait check at 430x932:

1. T1 rig: compact HP bar clears the oversized deposit art and synchronized `-10` stays readable for the post-contact tail;
2. two rigs on one resource: one shared HP cycle and two readable midpoint labels;
3. higher/mixed tiers: visible labels match the pure damage rules;
4. break shows zero through the rest of the impact and refreshes at timeline end;
5. reduced motion: no label travel/shake, but HP/value feedback remains;
6. pan/zoom: HUD stays limited to mined resources.

No new image asset should be added. If existing art cannot support the break beat, create a separate image-generation task instead of expanding HPA-455.

Then run the repository gate from `CLAUDE.md`:

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

Avoid production edits outside those files unless implementation uncovers a concrete mismatch. In particular, do not preemptively change:

- lib/mining/mine_site_view.dart
- lib/mining/presentation/mining_grid_map.dart
- lib/mining/presentation/mining_shell.dart
- lib/mining/mining_controller.dart
- lib/mining/mining_simulation.dart
- lib/mining/mining_save_repository.dart
- lib/mining/mining_content.dart

## Completion checklist

- pure HP/damage/grouping/clamp helpers are covered on VM and Chrome;
- only the existing contact bool gates strike application;
- cold-drop and late-miss paths cannot alter HP or render labels;
- HP mutates only at valid contact;
- breaking resources store the fresh next-cycle max immediately and use derived `_brokeOnContact` display state;
- label/break feedback remains readable through `0.46..1.0`, not only the 160 ms contact window;
- HP bar reuses `LinearProgressIndicator + MiningTheme`, existing `_depositKey`, and oversized-art geometry;
- HP/damage chrome stays outside deposit image subtrees and `ExcludeSemantics`;
- no unnecessary per-rig offset or local IgnorePointer;
- remount resets transient HP;
- no save/economy/controller/content/view-model changes;
- no new art or audio subsystem;
- implementation remains in this single PR.