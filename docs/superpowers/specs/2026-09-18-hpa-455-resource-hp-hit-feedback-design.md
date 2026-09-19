# HPA-455 — Resource HP and robot hit-feedback design

## Goal

Make foreground mining hits readable and satisfying without turning resource HP into economy state.

This slice builds directly on HPA-451's Landing Basin visible strike timeline and HPA-454's dense resource field / multi-robot target projection. The controller, simulation, save document, production rates, cargo, and offline accrual remain unchanged.

## Current seams to keep

- `MiningShell` owns the one-second foreground refresh and the transient Landing Basin `impactSequence`.
- `MineSiteView` already projects each deployed rig's tier and concrete target resource.
- `LandingBasinGridVisualLayer` already owns the visible robot arm/contact timeline and the one mining SFX callback.
- The existing impact listener already has the authoritative visible-contact latch and late-frame window: contact begins at `0.46`, a frame at or beyond `0.62` is too late, deferred cold-cache impacts can be dropped without ever becoming visible.
- Static unmined resources stay behind the retained `RepaintBoundary`; only mined resources and rigs participate in per-frame animation.
- Resource geometry is deterministic and `MiningDepositDefinition` equality is sufficient as transient presentation identity.
- `MiningGridMap` already owns the single semantics region for each resource.

Do not add a second timer, second contact/sequence latch, controller field, save field, resource entity ID, event bus, HP subsystem, or second deposit semantics owner.

## Scope boundary

HPA-455 applies HP and damage feedback to the existing visible Landing Basin strike path first. Other sites still use the static grid visual layer and therefore do not fabricate hit feedback without an actual visible strike animation.

A directly focused-resource mode is not added in this ticket. HP bars appear for actively mined resources, which satisfies the no-clutter requirement without introducing another selection owner or changing grid-tap behavior.

No image-generation work is required. Reuse the existing resource/robot art and Flutter text, opacity, scale, borders, and transforms. If review proves a dedicated break-state asset is necessary, create a separate art ticket rather than expanding this PR.

## Fixed presentation numbers

Keep the numbers deliberately simple and independent from the economy.

### Resource presentation HP

| Footprint | Max HP |
| --- | ---: |
| 1x1 | 40 |
| 2x2 | 80 |
| 3x3 | 120 |

The implementation can remain arithmetic: `maxHp(size) = size * 40`.

### Rig presentation damage

| Tier | Damage per visible strike |
| --- | ---: |
| T1 | 10 |
| T2 | 20 |
| T3 | 30 |
| T4 | 40 |
| T5 | 50 |

`RigTier` is ordered T1 through T5, so the implementation can remain arithmetic: `damage(tier) = (tier.index + 1) * 10`.

These values are presentation-only. Extraction, site rate, cargo, technology, offline caps, and sale value never read them.

Keep these and the grouping/clamp logic as private pure helpers beside `LandingBasinGridVisualLayer`. A generic combat/stat registry or public feedback model would be unnecessary.

## Transient HP ownership

`LandingBasinGridVisualLayer` owns one private map:

- key: `MiningDepositDefinition`
- value: remaining presentation HP

Only currently mined deposits need entries.

Use one private sync helper:

- call it from `initState` to seed currently mined resources at max HP;
- call it from `didUpdateWidget` to add newly mined resources at max HP and prune resources whose `minerCount` returned to zero;
- never initialize or prune HP from `build()`.

Destroying/remounting the Mine Site naturally drops all HP history.

This state is intentionally lost on:

- leaving/re-entering the site;
- app restart;
- widget/lifecycle recreation;
- save reload.

That is the desired contract: HP is visual rhythm, not depletion.

## Hit synchronization: reuse the existing contact latch

Do not react merely because `impactSequence` changed. HPA-451 can defer or drop the first impact while art frames decode, and it intentionally suppresses a frame that arrives after the visible strike window.

The existing `_notifyMiningImpact` listener is the authoritative contact seam. Reuse its current once-per-visible-impact latch (currently `_impactSoundFired`; it may be renamed locally for clarity, but do not add another latch).

The listener contract is:

1. before `t = 0.46`, do nothing;
2. when the existing latch first trips, mark the contact handled;
3. if `t >= 0.62`, treat it as a missed/late strike and do **not** change HP, show damage, or play SFX;
4. otherwise apply grouped presentation damage exactly once;
5. reduced motion still performs step 4; only the existing `onMiningImpact` SFX callback remains suppressed for reduced motion;
6. a deferred first impact that exceeds the existing 200 ms decode budget stays dropped and cannot change HP because the visible-contact latch never runs through the valid window.

Do not add `_appliedFeedbackSequence`, another animation listener, a damage queue, or `setState` at contact. The existing `AnimationController` notification drives the `AnimatedBuilder` on the same frame.

## Grouped damage

At a valid visible contact:

- compute each rig's fixed tier damage from `rig.placement.tier`;
- group damage by each rig's concrete `rig.target` `MiningDepositDefinition`;
- subtract the grouped amount from that target's shared remaining HP;
- clamp at zero;
- ignore overkill instead of carrying it into the next HP cycle.

Do not derive damage from `minerCount`: two miners can have different tiers.

Keep the logic private and explicit, in the same style as `_stageForProgress` / `_armAngle`:

- max HP by footprint;
- damage by tier;
- grouped damage by target;
- remaining-after-strike clamp.

Tests still exercise this through the widget boundary; no `@visibleForTesting` model is required.

## Multiple rigs on one resource

All rigs animate from the same one-second foreground impact, so one valid contact is one presentation batch.

For one shared target:

- grouped tier damage changes the shared HP once;
- each rig still renders its own `-N` label;
- mixed tiers remain correct (for example T1 + T5 shows `-10` and `-50`, subtracting 60 total);
- overkill is discarded.

This makes multiple robots visibly contribute to the same HP cycle without inventing per-rig clocks.

## HP bar

Render one compact bar only for deposits with `minerCount > 0`.

The bar:

- is positioned just above the resource footprint;
- uses the existing mining palette;
- displays visible text such as `70/80`;
- has a deterministic key such as `landing-basin-hp-<x>-<y>-<size>`;
- is wrapped in `ExcludeSemantics` so `MiningGridMap` remains the single resource semantics owner;
- does not intercept taps;
- stays inside the animated/mined-resource subtree, so the ~100-resource field does not gain ~100 HUD widgets.

Unmined resources have no HP bar.

Do not change `MineSiteView` or `MiningGridMap._depositLabel` to pipe transient HP into semantics in this ticket.

## Floating damage feedback

Damage labels exist only during the existing contact-to-recoil window:

`0.46 <= t < 0.62`

Render one label per active rig using a deterministic key such as:

`landing-basin-damage-<rig-x>-<rig-y>`

The value is derived directly from the rig tier; there is no damage-history list or label queue.

Position each label between its rig cell and target resource center, with a small deterministic offset when multiple rigs share a target so the labels remain legible.

Normal motion:

- short upward drift across the `0.46..0.62` window;
- fade toward zero opacity at `0.62`.

Reduced motion:

- no positional travel or shake;
- fade in place across the same `0.46..0.62` window.

Wrap damage chrome in `ExcludeSemantics`; tests pin keys and visible text rather than creating a second a11y node.

## Break / refresh beat

When grouped damage takes a resource to zero:

- keep the HP bar at zero through the same contact-to-recoil window;
- give the resource a small scale/opacity emphasis while `0.46 <= t < 0.62` when reduced motion is off;
- reduced motion keeps only non-positional emphasis;
- reset any zero-HP mined resource to its footprint max HP when the existing listener reaches `t >= 0.62`.

`0.62` is intentionally reused as the recovery knot because it is already the authored end of the valid contact/SFX window and the start of recoil. Do not introduce a separate `0.70` timeline constant.

Reset is idempotent: only entries at zero are restored. It needs no timer and no impact-sequence ID.

The resource never disappears and production never pauses. No respawn timer or depletion state is introduced.

## SFX

Keep the existing Landing Basin `onMiningImpact` callback and `AudioManager` path unchanged.

One valid visible foreground impact still produces one mining SFX even when several rigs strike. Reduced motion continues to suppress that motion/SFX cue while HP and damage-value feedback still update.

HPA-455 does not add a player, new sound asset, per-rig sound spam, or audio state.

## Files

Expected production changes stay narrow:

- `lib/mining/presentation/landing_basin_grid_visual_layer.dart`
- `CLAUDE.md`

Expected test work:

- `test/mining/presentation/landing_basin_grid_visual_layer_test.dart`
- `test/mining/presentation/mining_shell_test.dart` only if implementation uncovers an integration gap that cannot be pinned by remounting the layer.

`MineSiteView`, `MiningShell`, `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `mining_content.dart`, and save JSON should not need production changes.

## Tests

Focused widget tests must pin:

- mined resources show keyed HP bars; unmined resources do not;
- 1x1 / 2x2 / 3x3 max-HP values;
- T1 through T5 produce increasing fixed `-N` values;
- one valid contact applies feedback once even across multiple pumped animation frames;
- two rigs targeting one resource show two labels and subtract their combined damage from one shared HP value;
- mixed-tier same-resource damage sums tier values rather than miner count;
- reaching zero is observable during `0.46..0.62`, then resets to max at `0.62`;
- reduced motion still updates HP and shows damage with no translated damage label;
- a cold-cache impact dropped by the existing 200 ms budget leaves HP at max and shows no damage;
- a warmed impact advanced directly beyond `0.62` is treated as a late miss and leaves HP at max;
- strike once (for example 80 -> 70), then change cargo/progress without a new impact and HP remains 70;
- unmount/remount returns transient HP to max and does not replay the prior strike;
- static unmined resources remain outside the per-frame rebuild path.

Any test that asserts a **visible** strike, including reduced-motion HP feedback, must follow the existing frame-test pattern:

- call `warmGoldFrames(tester)`;
- use `skip: kIsWeb`.

The cold-cache drop test intentionally stays cold and can run on both VM and web.

The existing HPA-451 tests continue to pin finite-frame precache, frame selection, sound timing, and lifecycle no-replay behavior, but HPA-455 adds explicit HP assertions to the drop/late/remount paths because those are the correctness boundary for the new state.

## Manual visual gate

On a 430x932 portrait viewport:

1. deploy one T1 rig to a Landing Basin resource and verify the bar is readable without obscuring the field;
2. deploy a second rig to the same resource and verify shared HP plus two damage labels remain legible;
3. use a higher-tier rig and verify the larger number reads clearly;
4. observe zero HP through contact and reset at recoil;
5. enable reduced motion and confirm values remain readable with no travel/shake;
6. pan/zoom the dense field and confirm only actively mined resources carry HUD chrome.

## Non-goals

- finite resources, depletion, respawn, loot drops, or resource removal;
- persisted HP or damage history;
- economy-rate or balance changes;
- Extraction-dependent damage;
- per-rig independent attack timers;
- generic animation/event/combat frameworks;
- resource focus/selection state;
- a second deposit semantics owner;
- new audio system or SFX asset;
- new image art in this coding PR;
- animating the other eight sites before they have a concrete visible strike path.

## Acceptance

HPA-455 is complete when each real foreground Landing Basin contact in the existing `0.46..0.62` window produces synchronized fixed-tier damage feedback and shared transient resource HP, multi-rig hits combine correctly, cold/dropped/late/remounted paths do not fabricate history, zero HP refreshes at the existing recoil knot, reduced motion remains readable, and no controller/simulation/save/economy behavior changes.