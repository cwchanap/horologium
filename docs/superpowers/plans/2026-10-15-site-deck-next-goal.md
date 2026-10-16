# Site Deck Next Goal Implementation Plan

- Date: 2026-10-15
- Linear: not yet filed (free issue limit); roadmap context HPA-630
- Design: `docs/superpowers/specs/2026-10-15-site-deck-next-goal-design.md`

## Delivery rule

One ticket = one PR. Planning lands first on this draft PR; implementation lands on the same PR after plan review. Do not open a second implementation PR.

No image-generation or SFX task is included.

## Task 1: Pure next-goal read model

This task is read-model-only and must finish green before any presentation change.

### Tests first: `test/mining/next_goal_view_test.dart`

Build states with `MiningSave.initial(nowUtc: ...)` plus `copyWith`, in the style of `test/mining/presentation/site_deck_screen_test.dart` (`_stateWith`, `_progress`). Cover:

1. **Fresh save:** `commissionSite`, title `Commission Landing Basin`, detail `Deploy a rig beside a resource.`, target `mineSite(landingBasin)`, `cashCost == null`, `progress == null`.
2. **Empty dock:** Landing Basin commissioned with both starter rigs deployed, Carbon Ridge unlocked and uncommissioned, all Homeworld bays null, cash 10. Detail is `Spawn a rig for 25 cash, then deploy it.`, `cashCost == 25`, `progress == 0.4`.
3. **Unlock site, short of cash:** Landing Basin commissioned, cash 100, `sellableValue` 0. `unlockSite(carbonRidge)`, `cashCost == 250`, `progress == 0.4`, detail `Unlock it on its site card.`, target `none`.
4. **Sell hint:** same as 3 with `sellableValue` 150. Detail `Sell cargo to afford it.`, `sellWouldAfford == true`.
5. **Ready:** same as 3 with cash 250. Detail `Ready: unlock it on its site card.`, `progress == 1`.
6. **Surveying for a site:** Lunar active, Frozen Basin commissioned, Surveying 3. `researchSurveying`, title `Research Surveying 4`, detail `Needed for Titanium Highlands.`, `cashCost == 4000`, target `technology`.
7. **Surveying for a planet:** Homeworld mastered, Surveying 0. Title `Research Surveying 1`, detail `Needed for Lunar Frontier.`, `cashCost == 300`.
8. **Unlock planet:** Homeworld mastered, Surveying 3, cash 1,000. `unlockPlanet(lunarFrontier)`, `cashCost == 2500`, target `stellarMap`, detail `Unlock it from the Stellar Map.`.
9. **Return to frontier:** Lunar unlocked with only Frozen Basin commissioned, active planet Homeworld. `returnToFrontier`, title `Return to Lunar Frontier`, detail `1/3 sites commissioned.`, target `stellarMap`.
10. **Mastery reward:** Mars active, Ochre Basin and Silica Dunes commissioned, Cobalt Chasm unlocked. Detail `Last Mars Frontier site: mastery pays +25,000 cash.`.
11. **Complete with upgrades left:** all nine sites commissioned, all planets unlocked. Both tracks below max: detail `Keep upgrading Extraction and Logistics.`; Logistics at max: `Keep upgrading Extraction.`; Extraction at max: `Keep upgrading Logistics.`. `frontiersMastered`, target `technology`.
12. **Complete:** as 11 with every track at `maxTechnologyLevel`. Detail `Every frontier is mastered.`, target `none`.
13. **Defensive gate fallback:** a hand-built inconsistent state where the Surveying gate site is uncommissioned yields `commissionSite(gate)`. This documents the fallback without implying it is reachable.
14. **Semantics label:** case 3 yields `Next goal: Unlock Carbon Ridge. Unlock it on its site card. 100 of 250 cash.`.

Content invariants, in the same file, against `MiningContentRegistry.stellarMining()`:

- for every site and planet with Surveying requirement `N > 0`, each gate in `technologySiteGates.take(N)` appears earlier in the authored progression order (planets in `MiningPlanetId.values` order, sites in `planet.sites` order) than the site, or belongs to an earlier planet than the planet;
- every site's `requiredSite`, when set, appears earlier in its planet's authored `sites` order (the unlock-site rung relies on this instead of re-checking `requiredSite`);
- each planet's `unlockRequiredMasteryPlanetId` is the immediately preceding `MiningPlanetId`.

### Production: `lib/mining/next_goal_view.dart`

```dart
enum MiningGoalKind {
  commissionSite,
  unlockSite,
  researchSurveying,
  unlockPlanet,
  returnToFrontier,
  frontiersMastered,
}

enum MiningGoalTargetKind { mineSite, technology, stellarMap, none }

class MiningGoalTarget {
  const MiningGoalTarget.mineSite(MiningSiteId this.siteId)
    : kind = MiningGoalTargetKind.mineSite;
  const MiningGoalTarget.technology()
    : kind = MiningGoalTargetKind.technology, siteId = null;
  const MiningGoalTarget.stellarMap()
    : kind = MiningGoalTargetKind.stellarMap, siteId = null;
  const MiningGoalTarget.none()
    : kind = MiningGoalTargetKind.none, siteId = null;

  final MiningGoalTargetKind kind;
  final MiningSiteId? siteId;

  bool get isNavigable => kind != MiningGoalTargetKind.none;
}

class MiningNextGoalView {
  // kind, title, detail, target, cash, cashCost (nullable), sellWouldAfford
  double? get progress => cashCost == null
      ? null
      : (cash / cashCost!).clamp(0.0, 1.0).toDouble();
  bool get isReady => cashCost != null && cash >= cashCost!;
  String? get cashLabel; // '1,240 / 2,500', null when not cash-gated
  String get semanticsLabel;

  static MiningNextGoalView from({
    required MiningSave state,
    required MiningContentRegistry content,
    required int sellableValue,
  });
}
```

Implementation notes:

- Walk `MiningPlanetId.values` for planet order and `content.planet(id).sites` for site order. Compute the commissioned-site set once and reuse `content.isPlanetMastered`.
- Keep one private `_cashGoal(...)` helper that applies the detail precedence (ready, then sell hint, then reason) so every cash-gated rung shares it.
- Keep one private `_surveyingGoal(state, content, neededFor)` helper for both the site and the planet Surveying rungs.
- Move the thousands formatter used by `MiningController._formatCash` into a small shared top-level `formatMiningCash(int)` in `lib/mining/mining_content.dart` (the shared leaf both files already import), and make the controller call it, so goal copy and the mastery message format identically. This is the only controller-file change and it is formatting-only; `mining_controller_test.dart` must stay green unchanged.
- No Flutter imports beyond what `mining_content.dart` already pulls in.

Run: `flutter test test/mining/next_goal_view_test.dart test/mining/mining_controller_test.dart`.

## Task 2: Strip widget and Site Deck placement

### Tests first

New `test/mining/presentation/mining_next_goal_strip_test.dart`:

- renders `NEXT GOAL`, the title, and the detail;
- cash-gated goal shows `100 / 250` and a progress fill at 40% of the track width;
- navigable goal shows the chevron, is a semantics button with the design's label, and calls `onSelected` with its target once;
- `none` target shows no chevron, is not a semantics button, and ignores taps;
- the tap target is at least 48 px tall;
- a navigable goal with no `onSelected` shows no chevron and is not a semantics button;
- at text scale 1.5, 2.0, and 3.0 both variants keep their height without overflow, the portrait strip uses one line and drops the inline cash label.

Extend `test/mining/presentation/site_deck_screen_test.dart`:

- with a goal at 402×874: `Key('site-deck-next-goal')` exists; its rect is `left 14`, `right 388`, `bottom 770`, `height 56`; `site-deck-scroll` top stays 164 and bottom is 706 (874 − 96 − 72), 8 px above the strip's top at 714;
- without a goal: the existing geometry assertions (scroll bottom 778) stay untouched and no strip is found;
- landscape 874×402 with a goal: the strip sits between the header row and the card list and nothing overflows;
- 360×640 at text scale 1.3 with the longest copy (the mastery-reward detail on `Cobalt Chasm`): no exception, title and detail ellipsize; the same at 1.5 on the fresh deck;
- a goal without `onGoalSelected` shows no chevron in portrait or landscape.

### Production

- New `lib/mining/presentation/mining_next_goal_strip.dart`: `MiningNextGoalStrip({required MiningNextGoalView goal, required ValueChanged<MiningGoalTarget>? onSelected, bool compact = false})`. `compact` is the 48 px landscape variant. It uses `MiningTheme` colors, a static `FractionallySizedBox` progress fill, `Semantics(button: navigable, label: goal.semanticsLabel, excludeSemantics: true)`, and an `InkWell` only when navigable (a targeted goal with a non-null `onSelected`).
- `SiteDeckScreen` gains optional `MiningNextGoalView? nextGoal` and `ValueChanged<MiningGoalTarget>? onGoalSelected`, passed through to `_PortraitSiteDeck`.
  - Portrait: when `nextGoal != null`, add a `Positioned(left: 14, right: 14, bottom: 96 + 8 + pad.bottom, height: 56)` strip and raise the scroll's `bottom` to `96 + 72 + pad.bottom`.
  - Landscape: insert `Padding(EdgeInsets.fromLTRB(12, 0, 12, 4), MiningNextGoalStrip(compact: true))` between the header `Padding` and the `Expanded` list.
- No change to card widgets, `_PlanetProgress`, `_SiteDeckSellAction`, or `MiningHud`.

Run: `flutter test test/mining/presentation/mining_next_goal_strip_test.dart test/mining/presentation/site_deck_screen_test.dart`.

## Task 3: Shell wiring

### Tests first: `test/mining/presentation/mining_shell_test.dart`

- **Fresh save:** the strip reads `Commission Landing Basin`; tapping `site-deck-next-goal` shows the Landing Basin Mine Site, the same finder the existing enter-site tests use.
- **Homeworld mastered, Surveying 0, cash 400:** tapping the strip opens the Technology sheet.
- **Homeworld mastered, Surveying 3, cash 3,000:** tapping the strip shows the Stellar Map surface.
- **Live update:** with `deployedLandingState(_start)` and cash just below 250, advancing the injected clock and calling `pumpMiningTick` until a sale makes 250 affordable changes the detail to the ready line. This proves the goal follows `_displayState` without extra state.

Reuse `pumpShell`, `deployedLandingState`, and `pumpMiningTick`; add one small `homeworldMasteredState(now, {surveying, cash})` helper next to them.

### Production: `lib/mining/presentation/mining_shell.dart`

- In `build()`, where `siteDeck` is built, also build `MiningNextGoalView.from(state: _displayState, content: _content, sellableValue: siteDeck.projectedValue)` and pass it with `onGoalSelected: _openGoal` to `SiteDeckScreen`.
- Add:

```dart
void _openGoal(MiningGoalTarget target) {
  switch (target.kind) {
    case MiningGoalTargetKind.mineSite:
      _enterSite(target.siteId!);
    case MiningGoalTargetKind.technology:
      openTechnology();
    case MiningGoalTargetKind.stellarMap:
      _handleNavigation(MiningNavigationDestination.stellarMap);
    case MiningGoalTargetKind.none:
      return;
  }
}
```

- No new shell fields, timers, notifiers, or audio calls.

Run: `flutter test test/mining/presentation/mining_shell_test.dart`.

## Task 4: Journey checkpoints

In `test/integration/merge_mining_journey_test.dart`, add a local `goal()` helper that builds `MiningNextGoalView` from `controller.state` and `SiteDeckView.from(...).projectedValue`, then assert kind and title at the design's checkpoints:

| Journey point | Expected |
| --- | --- |
| after `initialize()` on a fresh repository | `commissionSite`, `Commission Landing Basin` |
| after Homeworld mastery, before the first Surveying purchase | `researchSurveying`, `Research Surveying 1` |
| after Surveying 3, before `unlockPlanet(lunarFrontier)` | `unlockPlanet`, `Unlock Lunar Frontier` |
| immediately after Lunar unlock | `commissionSite`, `Commission Frozen Basin` |
| after Frozen Basin commission at Surveying 3 | `researchSurveying`, `Research Surveying 4` |
| before `unlockPlanet(marsFrontier)` | `unlockPlanet`, `Unlock Mars Frontier` |
| before the final Cobalt Chasm deploy | `commissionSite`, detail contains `+25,000` |
| after Mars mastery | `frontiersMastered` |

The journey's actions and emitted cadence must not change. Only assertions are added.

Run: `flutter test test/integration/merge_mining_journey_test.dart`.

## Task 5: Guidance and gates

- Add one bullet under "Active ownership boundary" in `CLAUDE.md`: `MiningNextGoalView` is a stateless Site Deck read model derived from the display state; the strip only navigates through existing shell paths and never mutates, persists, or adds tutorial state.
- Run the full repository gates from `CLAUDE.md`:

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

- Coverage must stay at or above the 90% Codecov gate; the new read model should be fully covered by Task 1.
- Scope audit: `git diff --name-only origin/main...HEAD` lists only the spec, the plan, `CLAUDE.md`, the new read model and strip, `site_deck_screen.dart`, `mining_shell.dart`, the formatter move (`mining_controller.dart` plus `mining_content.dart`), and the test files named above. No change to the simulation, repository, save, content values, Stellar Map, Mine Site, Technology sheet, HUD, or assets.

## Expected changed paths

Planning (this draft PR as opened):

- `docs/superpowers/specs/2026-10-15-site-deck-next-goal-design.md`
- `docs/superpowers/plans/2026-10-15-site-deck-next-goal.md`

Implementation (same PR, after review):

- `lib/mining/next_goal_view.dart` (new)
- `lib/mining/presentation/mining_next_goal_strip.dart` (new)
- `lib/mining/presentation/site_deck_screen.dart`
- `lib/mining/presentation/mining_shell.dart`
- `lib/mining/mining_controller.dart` (formatter call only) and `lib/mining/mining_content.dart` (formatter home)
- `CLAUDE.md`
- `test/mining/next_goal_view_test.dart` (new)
- `test/mining/presentation/mining_next_goal_strip_test.dart` (new)
- `test/mining/presentation/site_deck_screen_test.dart`
- `test/mining/presentation/mining_shell_test.dart`
- `test/integration/merge_mining_journey_test.dart`
