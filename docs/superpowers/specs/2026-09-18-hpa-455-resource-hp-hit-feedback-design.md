# HPA-455 — Resource HP and robot hit-feedback design

## Goal

Make foreground mining hits readable and satisfying without turning resource HP into economy state.

This slice builds directly on HPA-451's Landing Basin visible strike timeline and HPA-454's dense resource field / multi-robot target projection. The controller, simulation, save document, production rates, cargo, and offline accrual remain unchanged.

## Current seams to keep

- `MiningShell` owns the one-second foreground refresh and transient Landing Basin `impactSequence`.
- `MineSiteView` already projects each deployed rig's tier and concrete `MiningDepositDefinition target`.
- `LandingBasinGridVisualLayer` already owns the visible robot arm/contact timeline and the one mining-SFX callback.
- The existing impact listener is the authoritative visible-contact seam: contact starts at `0.46`; a first observed frame at or beyond `0.62` is a late miss; a cold first impact may be dropped before either happens.
- `_depositKey(...)` already defines the stable `x-y-size` resource key format. Reuse it for HP keys instead of spelling a second geometry-key formatter.
- `MiningDepositDefinition` already has value equality/hashCode and is safe as a transient HP-map key.
- `MiningGridMap` already wraps the whole object layer in `IgnorePointer`; HPA-455 chrome inherits that and needs no second tap-interception mechanism.
- `MiningGridMap` already owns the single semantics node per resource. HP/damage chrome stays `ExcludeSemantics`.
- Static unmined resources remain behind the retained `RepaintBoundary` / `AnimatedBuilder.child`; only mined resources, rigs, and their small feedback chrome participate in animation rebuilds.
- The existing Site Deck uses `LinearProgressIndicator` with `MiningTheme`; reuse that idiom for the compact HP bar rather than hand-rolling a fractional bar.

Do not add a second timer, second contact/sequence latch, controller field, save field, resource entity ID, event bus, combat/stat registry, generic feedback model, or second resource semantics owner.

## Scope boundary

HPA-455 applies HP and damage feedback only to the existing animated Landing Basin path. Other sites still use the static visual layer and therefore do not fabricate hits without a real visible strike animation.

A directly focused-resource mode is not added. HP bars appear for actively mined resources only, which satisfies the no-clutter requirement without another selection owner or grid-tap behavior.

No image-generation work is required. Reuse existing resource/robot art plus Flutter text, progress, opacity, scale, and transforms. If implementation review proves dedicated break-state art is necessary, create a separate art task rather than expanding this PR.

## Presentation math

Keep the numbers deliberately simple and independent from the economy.

### Resource HP

`maxHp = footprintSize * 40`

| Footprint | Max HP |
| --- | ---: |
| 1x1 | 40 |
| 2x2 | 80 |
| 3x3 | 120 |

### Rig damage

`damage = (tier.index + 1) * 10`

| Tier | Damage |
| --- | ---: |
| T1 | 10 |
| T2 | 20 |
| T3 | 30 |
| T4 | 40 |
| T5 | 50 |

Extraction, site rate, cargo, technology, offline caps, and sale value never read these values.

### Narrow pure helpers

The arithmetic/grouping is the only logic here with real branching, so keep it cheap to verify on both VM and Chrome instead of forcing every case through warmed animation assets.

Define narrow top-level functions in `landing_basin_grid_visual_layer.dart`:

- `landingBasinMaxHp(int size)`;
- `landingBasinStrikeDamage(RigTier tier)`;
- `landingBasinGroupedDamage(Iterable<MineSiteRigView> rigs)`;
- `landingBasinRemainingHpAfterStrike(int remainingHp, int damage)`.

These are functions, not a model, registry, service, or second state owner. Production and tests call the same code. Pure tests pin:

- 40/80/120 HP;
- T1–T5 10/20/30/40/50 damage;
- mixed-tier grouping by `rig.target`;
- clamp-to-zero and overkill discard.

This keeps the math covered by `flutter test --platform chrome` while widget tests focus on the timeline/chrome behavior that actually needs Flutter animation.

## Transient HP ownership

`LandingBasinGridVisualLayer` owns one private map:

- key: `MiningDepositDefinition`;
- value: remaining presentation HP.

Only currently mined resources have entries.

Use one private sync helper:

- call it from `initState` to seed currently mined resources at max HP;
- call it from `didUpdateWidget` to add newly mined resources and prune resources whose `minerCount` returned to zero;
- never initialize/prune HP from `build()`.

Destroying/remounting the Mine Site naturally drops HP history.

This state is intentionally lost on:

- leaving/re-entering the site;
- app restart;
- widget/lifecycle recreation;
- save reload.

HP is visual rhythm, not depletion.

## One contact mutation point

Do not react merely because `impactSequence` changed. HPA-451 can defer/drop a first impact and intentionally ignores late frames.

Reuse the existing contact bool rather than adding another sequence flag. Because the bool now means “this impact reached a valid visible contact” rather than literally “sound fired,” rename `_impactSoundFired` to `_impactContactHandled` in the same edit.

The listener becomes:

1. if contact is already handled or `t < 0.46`, return;
2. if `t >= 0.62`, return as a late miss **without** marking contact handled;
3. mark the existing contact bool handled;
4. group current rigs by target and apply presentation damage once;
5. invoke `onMiningImpact` only when reduced motion is off, preserving the existing SFX behavior.

Leaving the bool false on a late miss means the listener may cheaply re-check later frames in that missed animation, but it never mutates HP or emits chrome/SFX. This is preferable to adding a second validity flag.

Reduced motion still performs step 4; only the existing SFX callback is skipped.

A deferred first impact keeps the contact bool handled while parked. If decode exceeds the 200 ms budget, it jumps to rest and never applies HP. If frames become ready in time, `_fireImpact` opens the same existing contact latch and the normal path applies.

No second animation listener, impact-sequence latch, timer, queue, or contact `setState` is required. The current `AnimationController` notification already rebuilds the `AnimatedBuilder`.

## Grouped damage and break state

At a valid contact:

- call `landingBasinGroupedDamage(widget.view.rigs)`;
- subtract each grouped target amount from its current HP through `landingBasinRemainingHpAfterStrike`;
- if the result remains above zero, store it normally;
- if the result reaches zero, immediately store that resource's **next-cycle max HP** in the backing HP map and add the target to one private `_brokeOnContact` set.

The set is not depletion state. It only tells the current animation how to render the just-completed cycle.

Clear `_brokeOnContact` when the next real impact begins in `_fireImpact`, before `forward(from: 0)`. This is slightly safer than waiting for the next contact: a subsequent impact that is later missed cannot resurrect the prior break marker.

There is exactly one HP mutation point: the valid contact. No `0.62` reset mutation exists, so the existing one-shot contact latch remains structurally intact.

For a broken target, displayed HP is derived:

- while the current valid impact is in `0.46 <= t < 1.0`, display `0/max`;
- at the end of the existing controller timeline, display the already-stored fresh max HP.

Overkill is discarded; it never carries into the next cycle.

## Multiple rigs on one resource

All rigs participate in the same one-second foreground impact.

For one shared target:

- tier-specific damage is grouped once against shared HP;
- each rig still renders its own `-N` value;
- mixed tiers remain correct (for example T1 + T5 subtracts 60 total);
- overkill is ignored.

Do not use `minerCount` for damage; it cannot represent mixed tiers.

## HP bar

Render one compact HP bar only for `minerCount > 0` resources.

Reuse the Site Deck progress-bar idiom:

- `ClipRRect`;
- compact `LinearProgressIndicator`;
- existing `MiningTheme` color;
- existing dark background treatment;
- small visible `remaining/max` text.

Use key:

`landing-basin-hp-${_depositKey(deposit.definition)}`

Wrap the HP chrome in `ExcludeSemantics`; `MiningGridMap._depositLabel` remains the resource a11y owner.

### Position against the oversized art

The resource art intentionally overflows its logical footprint through `depositVisualSize(...)`. Positioning a bar “above the footprint” would overlap that art halo.

Compute the bar from the resource center and `depositVisualSize(deposit.definition.size)`, then place it just above the **visual art bounds**.

Render the bar as a sibling `Positioned` in the animated layer, not as a child of `_depositNode`. Existing frame tests expect exactly one `Image` descendant under the deposit key, so feedback chrome must not disturb that subtree.

No local `IgnorePointer` is required; the entire object layer already inherits one from `MiningGridMap`.

## Floating damage feedback

Damage applies only at the valid contact window, but the number should remain readable longer than the 160 ms arm-contact interval.

After a valid contact, render one label per current rig while:

`0.46 <= t < 1.0`

Use key:

`landing-basin-damage-<rig-x>-<rig-y>`

Only render labels when the existing contact bool says the current impact actually reached valid contact. Therefore:

- cold dropped impacts show no labels;
- late misses show no labels;
- normal/reduced-motion valid contacts do.

The value is derived from `landingBasinStrikeDamage(rig.placement.tier)`; there is no history list or queue.

Position each label at the rig→target midpoint. Rig cells are unique by placement legality, so their midpoints are already distinct; do not add an order-dependent extra offset for multiple rigs on one target.

Normal motion:

- drift upward from contact to timeline end;
- fade toward zero opacity at `t = 1.0`.

Reduced motion:

- no positional travel;
- fade in place over the same `0.46..1.0` interval.

Wrap damage chrome in `ExcludeSemantics`.

## Break / refresh beat

For targets in `_brokeOnContact`:

- render visible HP as zero from valid contact through `t < 1.0`;
- use a small scale/opacity emphasis over that same current-impact tail when reduced motion is off;
- reduced motion keeps only non-positional emphasis;
- at `t = 1.0`, the derived break display ends and the HP bar reveals the already-stored fresh max HP.

The next impact's `_fireImpact` clears the old break marker before restarting the controller at zero.

There is no second threshold, no reset timer, no second HP mutation, and no respawn/depletion state.

The resource never disappears and production never pauses.

## SFX

Keep the existing Landing Basin `onMiningImpact` / `AudioManager` path.

One valid visible impact still produces one mining SFX even when several rigs strike. Reduced motion continues to suppress that cue while HP/value feedback still updates.

No new player, sound asset, per-rig sound spam, or audio state.

## Files

Expected production changes stay narrow:

- `lib/mining/presentation/landing_basin_grid_visual_layer.dart`;
- `CLAUDE.md`.

Expected test work:

- `test/mining/presentation/landing_basin_grid_visual_layer_test.dart`;
- `test/mining/presentation/mining_shell_test.dart` only if implementation uncovers an integration gap that cannot be proven by remounting the layer.

No production change is planned for:

- `MineSiteView`;
- `MiningGridMap`;
- `MiningShell`;
- `MiningController`;
- `MiningSimulation`;
- `MiningSaveRepository`;
- `mining_content.dart`;
- save JSON.

## Test strategy

### Pure tests — VM and Chrome

Pin the four top-level helpers without animation or asset warming:

- footprint HP;
- all tier damages;
- same-target mixed-tier grouping;
- separate-target grouping;
- clamp at zero / overkill discard.

### Widget tests — only timeline/chrome behavior

Keep the widget suite focused on behavior that cannot be proven by pure tests:

- mined resources have keyed HP chrome; unmined resources do not;
- one warmed valid strike changes visible HP exactly once;
- strike once, then change cargo/progress without a new impact: HP does not drift;
- cold-cache dropped impact leaves HP unchanged and shows no damage;
- warmed impact pumped directly beyond `0.62` is a late miss: HP unchanged, no label;
- remount resets transient HP to max and does not replay history;
- one multi-rig valid impact renders one label per rig;
- broken target visibly shows zero after contact and reveals fresh max at timeline end;
- reduced motion still changes HP and shows/fades the value with no translation;
- static unmined resources remain outside the per-frame animated subtree.

Any widget test that requires a real visible strike must follow the existing frame-test pattern:

- `await warmGoldFrames(tester)`;
- `skip: kIsWeb`.

The cold-cache drop test intentionally stays cold and remains runnable on both VM and web.

## Manual visual gate

On a 430x932 portrait viewport:

1. one T1 rig: compact HP bar and synchronized `-10`;
2. two rigs on one resource: shared HP plus two readable labels;
3. higher/mixed tiers: visible values match fixed damage;
4. a break shows zero through the remainder of the current impact and refreshes at the timeline end;
5. reduced motion keeps readable values without label travel/shake;
6. pan/zoom confirms only actively mined resources carry HUD chrome and bars clear the oversized resource art.

## Non-goals

- finite resources, depletion, respawn, loot drops, or resource removal;
- persisted HP or damage history;
- economy-rate or balance changes;
- Extraction-dependent damage;
- per-rig independent attack timers;
- generic animation/event/combat frameworks;
- resource focus/selection state;
- a second resource semantics owner;
- new audio system or SFX asset;
- new image art in this coding PR;
- animating other sites before they have a concrete visible strike path.

## Acceptance

HPA-455 is complete when each real foreground Landing Basin contact applies fixed tier damage exactly once through the existing visible-contact latch; pure damage/grouping/clamp logic is covered on VM and Chrome; cold-drop/late-miss/remount paths cannot fabricate history; labels and break feedback remain readable through the existing one-second timeline; multi-rig shared HP works; reduced motion remains readable; and no controller/simulation/save/economy behavior changes.