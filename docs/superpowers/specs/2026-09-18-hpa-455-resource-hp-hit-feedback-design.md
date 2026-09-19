# HPA-455 — Resource HP and robot hit-feedback design

## Goal

Make foreground mining hits readable and satisfying without turning resource HP into economy state.

This slice builds directly on HPA-451's Landing Basin visible strike timeline and HPA-454's dense resource field / multi-robot target projection. The controller, simulation, save document, production rates, cargo, and offline accrual remain unchanged.

## Current seams to keep

- MiningShell owns the one-second foreground refresh and the transient Landing Basin impactSequence.
- MineSiteView already projects each deployed rig's tier and concrete target resource.
- LandingBasinGridVisualLayer already owns the visible robot arm/contact timeline and the one mining SFX callback.
- Static unmined resources stay behind the retained RepaintBoundary; only mined resources and rigs participate in per-frame animation.
- Resource geometry is deterministic and MiningDepositDefinition equality is sufficient as transient presentation identity.

Do not add a second timer, controller field, save field, resource entity ID, event bus, or HP subsystem.

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

### Rig presentation damage

| Tier | Damage per visible strike |
| --- | ---: |
| T1 | 10 |
| T2 | 20 |
| T3 | 30 |
| T4 | 40 |
| T5 | 50 |

These values are presentation-only. Extraction, site rate, cargo, technology, offline caps, and sale value never read them.

Keep the lookup as private pure helpers beside LandingBasinGridVisualLayer. A generic combat/stat registry would be unnecessary.

## Transient HP ownership

LandingBasinGridVisualLayer owns one private map:

- key: MiningDepositDefinition
- value: remaining presentation HP

Only currently mined deposits need entries. When a resource becomes mined, initialize it to its footprint max HP. When it no longer has miners, remove its entry. Destroying the Mine Site naturally drops all HP history.

This state is intentionally lost on:

- leaving/re-entering the site;
- app restart;
- lifecycle recreation;
- save reload.

That is the desired contract: HP is visual rhythm, not depletion.

## Hit synchronization

Do not react merely because impactSequence changed. HPA-451 can defer or drop the first impact while art frames decode, so HP feedback must follow the actual visible strike timeline.

Use the existing impact AnimationController:

1. impactSequence changes and the existing layer starts or defers the impact exactly as today;
2. once the running impact reaches the current contact point (about 0.46), apply feedback exactly once for that sequence;
3. keep the existing onMiningImpact callback firing once for the visible impact, not once per rig;
4. if the impact is dropped before it visibly runs, do not decrement HP or show damage.

Track one transient applied-feedback sequence so repeated animation-listener callbacks cannot double-apply damage.

## Multiple rigs on one resource

All rigs animate from the same one-second foreground impact, so treat one impactSequence as one presentation batch.

At contact:

- derive each rig's fixed tier damage;
- group rigs by their target MiningDepositDefinition;
- sum grouped damage when updating the target's shared HP;
- render one floating damage label per rig, so two T1 rigs still show two -10 labels;
- clamp the shared resource HP at zero;
- do not carry excess damage into the next cycle.

This makes multiple robots visibly contribute to the same HP cycle without inventing per-rig clocks.

## HP bar

Render one compact bar only for deposits with minerCount greater than zero.

The bar:

- is positioned just above the resource footprint;
- uses the existing mining palette;
- shows remaining/max HP in semantics;
- does not intercept taps;
- stays inside the animated/mined-resource subtree, so the ~100-resource field does not gain ~100 HUD widgets.

Unmined resources have no HP bar.

## Floating damage feedback

During a short window after contact, render one -N label per active rig.

Position the label between that rig cell and its target resource center, with a small deterministic offset when multiple rigs hit the same target so labels remain legible.

Normal motion:

- short upward drift;
- quick fade.

Reduced motion:

- no positional travel or shake;
- keep the value visible briefly and fade it in place.

No damage-history list, timer queue, or overlay manager is needed. The current impactSequence, rig list, fixed damage helper, and animation progress can derive the visible labels for the current strike.

## Break / refresh beat

When grouped damage takes a resource to zero:

- keep the HP bar at zero for a brief contact-to-recovery window;
- give the resource a small scale/opacity emphasis when reduced motion is off;
- reduced motion keeps only the non-positional visual emphasis;
- at roughly 0.70 on the same impact timeline, reset that resource to its footprint max HP.

The resource never disappears and production never pauses. No respawn timer or depletion state is introduced.

## SFX

Keep the existing Landing Basin onMiningImpact callback and AudioManager path unchanged.

One visible foreground impact still produces one mining SFX even when several rigs strike. HPA-455 does not add a player, new sound asset, per-rig sound spam, or audio state.

## Files

Expected production changes stay narrow:

- lib/mining/presentation/landing_basin_grid_visual_layer.dart
- CLAUDE.md

Expected test work:

- test/mining/presentation/landing_basin_grid_visual_layer_test.dart
- existing mining_shell lifecycle/no-replay tests remain regression coverage unless a concrete gap is found.

MineSiteView, MiningShell, MiningController, MiningSimulation, MiningSaveRepository, mining_content.dart, and save JSON should not need production changes.

## Tests

Focused widget tests should pin:

- mined resources show HP bars; unmined resources do not;
- 1x1 / 2x2 / 3x3 max-HP values;
- T1 through T5 produce increasing fixed -N values;
- one impact applies feedback once even across multiple pumped animation frames;
- two rigs targeting one resource show two labels and subtract their combined damage from one shared HP value;
- reaching zero shows the completion state, then resets to max within the same impact timeline;
- reduced motion still updates HP and shows damage with no translated damage label;
- changing cargo/view state without a new visible impact does not mutate presentation HP;
- initial mount / resume do not replay historical HP changes or damage labels;
- static unmined resources remain outside the per-frame rebuild path.

The existing HPA-451 tests continue to pin finite-frame precache, dropped first impact, strike timing, sound timing, and lifecycle no-replay behavior.

## Manual visual gate

On a 430x932 portrait viewport:

1. deploy one T1 rig to a Landing Basin resource and verify the bar is readable without obscuring the field;
2. deploy a second rig to the same resource and verify shared HP plus two damage labels remain legible;
3. use a higher-tier rig and verify the larger number reads clearly;
4. observe one zero-HP completion/reset beat;
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
- new audio system or SFX asset;
- new image art in this coding PR;
- animating the other eight sites before they have a concrete visible strike path.

## Acceptance

HPA-455 is complete when each real foreground Landing Basin strike produces synchronized fixed-tier damage feedback and shared transient resource HP, multi-rig hits combine correctly, zero HP visibly refreshes, reduced motion remains readable, and no controller/simulation/save/economy behavior changes.