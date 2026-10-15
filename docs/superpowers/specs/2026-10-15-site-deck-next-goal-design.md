# Site Deck Next Goal Design

- Date: 2026-10-15
- Status: Proposed
- Linear: not yet filed (the workspace hit Linear's free issue limit); roadmap context is HPA-630
- Baseline: `main` at `560041a9faf23c60a240427321a57fbfbcaaeb2b` after HPA-642 / PR #34

## Problem

The HPA-630 roadmap promises that a new player can "understand the next goal during the opening session" and that a returning session shows "visible progress toward the next discovery". Every roadmap outcome has shipped, but nothing in the active mining flow names that next goal.

The information exists, spread across three surfaces:

- each Site Deck card shows its own `unlockDisabledReason` (`Requires Surveying 4.`, `Need 3000 cash.`);
- the Technology sheet shows each track's gate site and cost;
- the Stellar Map shows planet requirements (`Homeworld sites 3/3`, `Surveying 3`, `2500 cash`).

A player has to read all three to discover chains such as:

```text
Homeworld mastered -> Surveying 1 (300) -> Surveying 2 (700) -> Surveying 3 (1500) -> 2,500 cash -> Lunar Frontier
```

After Homeworld mastery the Site Deck shows three operational cards and no locked card, so the primary screen gives no hint that Surveying or the Stellar Map is where progress continues. The same gap recurs at Titanium Highlands (Surveying 4), Helium Mare (Surveying 5), and Mars.

HPA-642 also recorded that the representative journey never buys Extraction or Logistics, leaving 31,000 cash of authored spend unused after Mars. Pointing at that spend after the last frontier is a cheap way to keep the post-Mars state from reading as "nothing left to do".

## Goals

- Derive exactly one next progression goal from `MiningSave` and `MiningContentRegistry`, walking the authored progression order.
- Show it in one compact "Next goal" strip on the Site Deck in portrait and landscape.
- Show cash progress for cash-gated goals, and say when selling the active planet's cargo would afford the goal.
- Make the strip a navigation shortcut to the surface that resolves the goal: the Mine Site, the Technology sheet, or the Stellar Map.
- Keep the goal stateless: it is recomputed from the display state on every shell rebuild, so it follows the foreground timer, sales, and purchases without new plumbing.

## Non-goals

This work does not:

- change `MiningController`, `MiningSimulation`, `MiningSaveRepository`, `MiningSave`, or `MiningContentRegistry` values;
- add a save field, tutorial or onboarding state, dismissal flag, quest log, goal reward, or contextual-hint framework;
- perform any mutation from the strip (no one-tap unlock, purchase, or sell);
- add per-deposit Surveying guidance inside a Mine Site;
- add time-to-goal estimates;
- change Mine Site, Stellar Map, the Technology sheet, `MiningHud`, or HPA-286's FULL/Sell presentation;
- add images, SFX, or animation.

## Ownership

```text
MainMenu -> MiningShell -> MiningController -> MiningSimulation / MiningSaveRepository
                         -> SiteDeckView ------------> SiteDeckScreen
                         -> MiningNextGoalView ------> MiningNextGoalStrip (inside SiteDeckScreen)
```

- `MiningNextGoalView` is a pure read model in `lib/mining/next_goal_view.dart`, alongside `site_deck_view.dart` and `mining_progression_views.dart`. It imports content and state only.
- `MiningShell` builds it from `_displayState` in the same `build()` branch that builds `SiteDeckView`, and maps the goal's target to existing navigation methods.
- `SiteDeckScreen` renders the strip only when given a goal; widgets never derive goal legality.

## Design decisions

### 1. One goal from a fixed progression ladder

`MiningNextGoalView.from({state, content, sellableValue})` walks `MiningPlanetId.values` in authored order and returns the first matching rung:

1. **Frontier planet.** The frontier is the first unlocked planet that is not mastered.
   1. If the frontier is not the active planet: **Return to {frontier}**, target Stellar Map.
   2. Take the frontier's first site, in authored order, that is not commissioned.
      - If it is unlocked: **Commission {site}**, target that Mine Site.
      - If it is locked and Surveying is below the site's `requiredSurveyingLevel`: the Surveying rung (below), "needed for {site}".
      - Otherwise: **Unlock {site}**, cash-gated on `unlockCost`, no target (the card with the Unlock button is directly below the strip). The rung does not re-check `requiredSite`: the first-uncommissioned walk has already passed every earlier site, and a content-invariant test pins that each `requiredSite` precedes its site, so the strip cannot say "Unlock X" while the controller would reject with "Unlock the previous site first."
2. **Next planet.** If there is no frontier, take the first locked planet.
   - If Surveying is below its `unlockRequiredSurveyingLevel`: the Surveying rung, "needed for {planet}".
   - Otherwise: **Unlock {planet}**, cash-gated on `unlockCashCost`, target Stellar Map.
3. **All frontiers mastered.** If no planet is locked: **All frontiers mastered**. If Extraction or Logistics is below max level the detail is "Keep upgrading Extraction and Logistics." and the target is Technology; otherwise the detail is "Every frontier is mastered." and there is no target.

**Surveying rung.** With current Surveying level `L`, the gate is `MiningContentRegistry.technologySiteGates[L]` and the cost is `technologyCosts[L]`.

- If the gate site is commissioned: **Research Surveying {L+1}**, cash-gated on that cost, target Technology.
- If not: **Commission {gate site}**, target that Mine Site. Authored content never reaches this branch, because every gate site precedes the site or planet that needs it; a content-invariant test pins that ordering so the branch stays a defensive fallback rather than a live path.

The ladder mirrors the controller's own guard order (`unlockSite`, `purchaseTechnology`, `unlockPlanet`), so the goal never names a step the controller would reject for a reason the goal hides.

### 2. Commissioning accounts for an empty dock

Commissioning means deploying a rig at the site. When the active planet's four dock bays are all empty, the commission goal's detail becomes "Spawn a rig for {rigSpawnCost} cash, then deploy it." and the goal is cash-gated on the spawn cost. Otherwise the detail is "Deploy a rig beside a resource."

When the site is the frontier planet's last uncommissioned site and the planet has a `masteryRewardCash`, the detail adds the reward: "Last {planet} site: mastery pays +25,000 cash." (Mars is the only planet with a reward today.)

### 3. Cash-gated goals carry progress and a sell hint

A cash-gated goal exposes `cashCost`, the current `cash`, `progress = (cash / cashCost).clamp(0, 1)`, and `sellWouldAfford = cash < cashCost && cash + sellableValue >= cashCost`.

`sellableValue` is `SiteDeckView.projectedValue`, the active planet's floored sale value. The shell passes it in, so goal and Sell button can never disagree about what a sale is worth. Selling only affects the active planet, so cargo on other planets is deliberately excluded.

Detail precedence for cash-gated goals:

1. `cash >= cashCost`: a ready line ("Ready: unlock it below.", "Ready on the Stellar Map.", "Ready in Technology.");
2. `sellWouldAfford`: "Sell cargo to afford it.";
3. otherwise the rung's reason ("Needed for Titanium Highlands.") or the default detail.

The strip always shows `{cash} / {cost}` beside the progress bar for cash-gated goals, using the same thousands formatting as the mastery message.

### 4. Navigation only, through existing shell paths

```dart
enum MiningGoalTargetKind { mineSite, technology, stellarMap, none }
```

| Target | Shell call |
| --- | --- |
| `mineSite` | `_enterSite(siteId)` |
| `technology` | `openTechnology()` |
| `stellarMap` | `_handleNavigation(MiningNavigationDestination.stellarMap)` |
| `none` | strip is not tappable and has no chevron |

These calls already play the tap sound, respect `_initialized`, and (for `_enterSite`) ignore taps while the controller is busy. The strip adds no audio of its own.

### 5. Placement

**Portrait.** The strip is pinned directly above the bottom navigation so it stays visible while the card list scrolls: `left: 14`, `right: 14`, `height: 56`, `bottom: 96 + 8 + pad.bottom`. When a goal is present, `site-deck-scroll` keeps `top: 164 + pad.top` and its bottom moves from `96 + pad.bottom` to `96 + 72 + pad.bottom`, leaving an 8 px gap above the strip. At 402×874 that changes the scroll bottom from 778 to 706. When no goal is passed, geometry is unchanged, so existing Site Deck screen tests keep their current assertions.

**Landscape.** The strip is a 48 px row between the HUD/Sell header row and the card `ListView`, padded `12, 0, 12, 4`.

**Content.** A flag icon, a small `NEXT GOAL` label, the title (one line, ellipsized), the detail (one line, ellipsized), a trailing chevron when targeted, and, for cash-gated goals, a 3 px progress bar plus the `{cash} / {cost}` label. Colors come from `MiningTheme`: accent for progress, `warning` for the sell hint, and `panel` for the background. The progress bar is a static fill with no implicit animation, so reduced motion needs no special case.

**Accessibility.** The strip is one `Semantics` node, a button when targeted, labelled `Next goal: {title}. {detail}.` with `{cash} of {cost} cash.` appended for cash-gated goals. The tap target is at least 48 px tall. At 360×640 with text scale 1.3 and at 874×402 nothing overflows.

## Copy

| Rung | Title | Default detail |
| --- | --- | --- |
| Commission | `Commission {site}` | `Deploy a rig beside a resource.` |
| Commission, empty dock | `Commission {site}` | `Spawn a rig for {cost} cash, then deploy it.` |
| Commission, last rewarded site | `Commission {site}` | `Last {planet} site: mastery pays +{reward} cash.` |
| Unlock site | `Unlock {site}` | `Unlock it on its card below.` |
| Surveying | `Research Surveying {n}` | `Needed for {site or planet}.` |
| Unlock planet | `Unlock {planet}` | `Unlock it from the Stellar Map.` |
| Return | `Return to {planet}` | `{commissioned}/{total} sites commissioned.` |
| Complete, upgrades left | `All frontiers mastered` | `Keep upgrading Extraction and Logistics.` |
| Complete | `All frontiers mastered` | `Every frontier is mastered.` |

## Expected sequence on the representative route

| State | Goal |
| --- | --- |
| Fresh save | Commission Landing Basin |
| Landing Basin commissioned, 100 cash | Unlock Carbon Ridge, 100 / 250 |
| Homeworld mastered, Surveying 0 | Research Surveying 1 (needed for Lunar Frontier), 300 |
| Surveying 3 | Unlock Lunar Frontier, 2,500 |
| Lunar unlocked (auto-activated) | Commission Frozen Basin |
| Frozen Basin commissioned, Surveying 3 | Research Surveying 4 (needed for Titanium Highlands) |
| Lunar mastered, Surveying 5 | Unlock Mars Frontier, 20,000 |
| Mars active, Cobalt Chasm last | Commission Cobalt Chasm (mastery pays +25,000) |
| Mars mastered | All frontiers mastered (Extraction and Logistics left) |

## Testing

- **Read model:** table tests over hand-built `MiningSave` states for every rung and every detail-precedence branch, the empty-dock spawn variant, the mastery-reward variant, the return-to-frontier case, and both completion variants.
- **Content invariants:** every site's and planet's Surveying requirement `N` has gate sites `technologySiteGates[0..N-1]` that precede it in authored progression order; every site's `requiredSite` appears earlier in its planet's authored site order; and each planet's `unlockRequiredMasteryPlanetId` is the planet immediately before it.
- **Widget:** strip copy, progress label, chevron presence and absence, tap callback with the target, semantics label and button flag, 48 px target, portrait pinned geometry with scroll bottom 706 at 402×874, landscape placement, and no overflow at 360×640 / text scale 1.3 and 874×402.
- **Shell:** on a fresh save the strip shows `Commission Landing Basin` and tapping it opens the Landing Basin Mine Site; a Homeworld-mastered save's strip opens the Technology sheet; a Surveying-3 save's strip opens the Stellar Map.
- **Journey:** `test/integration/merge_mining_journey_test.dart` asserts the goal kind and title at the checkpoints in the table above, proving every state on the public-action route yields a goal.

## Risks

- **Goal disagrees with a card reason.** Both read the same state and the ladder follows controller guard order; the read-model tests include the card's `unlockDisabledReason` cases side by side.
- **Portrait list loses 72 px.** The card list already scrolls at 360×640; the pinned strip trades list height for a goal that never scrolls away. The widget test fixes the new geometry.
- **Copy drift if content changes.** All names and numbers come from `MiningContentRegistry`; no copy hard-codes a site, planet, or cost.

## Assets

No image generation or SFX work is required.
