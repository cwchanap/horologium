# HPA-855 Mockup Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the four reviewed presentation discrepancies with the approved mockups while preserving all mining behavior.

**Architecture:** Reuse the existing shell, mastery card, grid overlay, return sheet, and Stellar Map. The only additional data flowing into the mastery card is the already-projected `StellarMapView.nextSaleMultiplier`; no new state owner or persistence is introduced.

**Tech Stack:** Flutter, Dart, `flutter_test`, existing game assets and theme.

**Spec:** `docs/superpowers/specs/2026-11-12-hpa-855-mockup-alignment-design.md`. The previously approved `2026-11-11-hpa-855-milestone-polish-design.md` remains binding except where this spec explicitly supersedes it.

## Global Constraints

- No change to simulation, economy, prices, rewards, save schema, or public-action journey numbers.
- Preserve existing keys, screen-reader semantics, input handling, reduced motion, and navigation/dismissal behavior.
- Use existing assets, Orbitron/IBM Plex Mono, `MiningTheme`, and Flutter widgets; do not add dependencies, assets, or new state owners.
- Verify layouts at 360×640, 390×844, 430×932, and 874×402, including large text and safe-area insets.
- Re-fetch the three HPA-855 mockup images from the Linear issue before visual comparison; signed URLs and previous temporary files may have expired.
- Keep the existing Linux-dependent skipped goldens skipped; do not regenerate or commit them.

## Review Focus

1. A mastery card on a narrow screen or with enlarged text keeps both actions hit-testable without scrolling when opened and preserves screen-reader heading, gate states, and reduced-motion behavior (Task 1).
2. Io after a previous relaunch shows the next run's real sale multiplier and never resets or pays on card display (Task 1).
3. An enlarged top-edge rig chip does not cover adjacent 1×1/3×3 HP chrome or a reduced-motion damage label (Task 2).
4. While a five-planet return report scrolls, no report text can paint under either the cash chip or the footer; safe-area insets do not remove usable actions (Task 3).
5. The travel label and hex form a single tappable, accessible control; active, busy, and locked planets retain correct behavior and minimum-sized tap targets (Task 4).

### Task 1: Art-led mastery cards

**Files:** Modify `lib/mining/presentation/planet_mastered_card.dart`, `lib/mining/presentation/mining_shell.dart`; create `test/mining/presentation/planet_mastered_card_test.dart`; add one integration assertion in `test/mining/presentation/mining_shell_test.dart`.

**Interfaces:** Extend `PlanetMasteredCard` with `required double nextSaleMultiplier`. In `_showPlanetMastered`, build `StellarMapView.from(state: _controller.state, content: _content)` once for every planet, including Io; use that same view for successor requirements and pass its `nextSaleMultiplier`. The card formats it with `formatSaleMultiplier`.

- [ ] In the new focused card test, load the real Orbitron font following `visual_parity_golden_test.dart` and apply the production font theme. Add failing tests for both variants: centered prominent planet art; the filled cyan Open Map / RELAUNCH primary appears above outlined Continue; both buttons are hit-testable immediately after opening, without scrolling, at 360×640, 390×844, 430×932, and 874×402, including text scale 1.3 and safe-area insets. Assert no overflow, heading semantics, gate labels/status, and existing action keys. Test `formatSaleMultiplier` displays `×1.5` and `×2` when passed those projected values. In `mining_shell_test.dart`, add one Io assertion that relaunch count 1 produces `×2` on the actual shell card.
- [ ] Run the focused mastery/shell tests and confirm the new visual/multiplier assertions fail for the intended reason.
- [ ] Implement the centered art-led card using `MiningSheetFrame.pinnedFooter` for the stacked actions; primary on top, Continue below. Preserve card route lifetime, projected gate labels/status, reward ownership, heading semantics, and the shell's route unwinding. The body may scroll; neither action should need scrolling. Use the projected multiplier, not duplicated formula logic.
- [ ] Run `flutter test test/mining/presentation/planet_mastered_card_test.dart test/mining/presentation/mining_shell_test.dart`, `flutter analyze --fatal-infos`, and `flutter test`; confirm success. Commit this task's implementation and tests.

### Task 2: Legible single rig chip

**Files:** Modify `lib/mining/presentation/mining_grid_map.dart` and only if geometry requires it `lib/mining/presentation/animated_mining_grid_visual_layer.dart`; test `test/mining/presentation/mining_grid_map_test.dart`, `test/mining/presentation/animated_mining_grid_visual_layer_test.dart`.

**Interfaces:** Retain `view.upgradeableCells`, one top-anchored `mining-rig-chip-x-y` per rig, one existing semantic target, and `miningRigChipClearance` for the damage-label geometry.

- [ ] Add failing tests for the widest label `T4→T5` at text scales 1.0 and 1.3: use `tester.getRect` on the rendered text at the map's initial 1.0× camera, multiply its transformed text-box height by `miningGridMinScale`, and require at least **8 logical pixels**. This measurement includes any `FittedBox` shrink; a `TextStyle.fontSize` assertion alone is insufficient. Assert dark `0xFF04121A` text on `_upgradeGold` fill with contrast ratio ≥4.5 computed using `Color.computeLuminance()`. Assert one chip/one semantic target per rig; plain T1–T5 chips remain distinct and only legal matching rigs get an upgrade state. Test chip/HP rectangles for rigs above 1×1 and 3×3 deposits and chip/damage-label rectangles for a rig below a 1×1 deposit with reduced motion.
- [ ] Run the focused grid/animated tests and verify the new contrast/readability assertion fails before implementation.
- [ ] Give the chip a fixed scene-space height and derive `miningRigChipClearance` from that height plus any needed gap. Improve typography/contrast within the top-edge anchor; preserve gold outlined upgrade target and cyan deploy fill. Adjust shared clearance geometry as needed to keep HP and damage labels unobscured without adding a badge or semantic node.
- [ ] Run both focused files, `flutter analyze --fatal-infos`, and `flutter test`; confirm success. Commit this task's implementation and tests. Manual zoom-limit readability is checked in final verification.

### Task 3: Protect the return report from cash-chip overlap

**Files:** Modify `lib/mining/presentation/offline_return_sheet.dart`; test `test/mining/presentation/offline_return_sheet_test.dart`.

**Interfaces:** Preserve `offline-return-scroll`, `offline-return-footer`, `offline-return-next-action`, `OfflineReturnSheet` callbacks, and the current cash chip.

- [ ] Add a failing five-planet portrait test at 360×640 and 390×844: scroll until report text reaches the top and assert the visible `offline-return-scroll` viewport starts below `mining-cash-chip`; scroll through all five reports and assert `offline-return-footer` remains visible and disjoint. Repeat with nonzero top/bottom safe-area insets. At 874×402, compare `offline-return-planet-*` section rectangles against `mining-cash-chip`; landscape has no portrait scroll/footer keys.
- [ ] Run `flutter test test/mining/presentation/offline_return_sheet_test.dart` and confirm the new geometry test detects the existing overlap.
- [ ] Bound/clip the portrait report scroll viewport below the pinned cash chip using `54 + pad.top + MiningCashChip.height + gap`, reducing the scroll's existing inner top padding by the same amount so the initial composition does not move. Retain hero art, the pinned footer, all five reports, and safe-area behavior. Keep landscape's separate report column unchanged; avoid changing sell or continue callbacks.
- [ ] Run the focused file, `flutter analyze --fatal-infos`, and `flutter test`; confirm success. Commit this task's implementation and tests.

### Task 4: Mockup-aligned Stellar Map travel

**Files:** Modify `lib/mining/presentation/stellar_map_screen.dart`; test `test/mining/presentation/stellar_map_screen_test.dart`.

**Interfaces:** Put `mining-stellar-map-travel-<id>` on the combined label-plus-hex hit target for unlocked non-current planets; preserve `onTravel(view.id)`, `!isActive && !isBusy`, and existing unlock callbacks. The current planet keeps its existing disabled hex and has no `TRAVEL` label.

- [ ] Add failing tests at 360×640 and 390×844 asserting that an unlocked non-current planet shows visible `TRAVEL` **beside** a cyan play-arrow `MiningHex`, not inside it; tapping the label and the hex each invokes the correct planet, and the combined control is one semantic button with an effective tap area of at least 48×48. A busy planet's label and hex do nothing; the current planet's unchanged disabled hex does nothing; locked unlock behavior stays unchanged. Include 874×402 and text scale 1.3 with no overflow.
- [ ] Run `flutter test test/mining/presentation/stellar_map_screen_test.dart` and verify the new label/icon placement assertions fail.
- [ ] Replace the non-current unlocked action's internal target icon/label with an adjacent label and the play-arrow hex used by `OfflineReturnSheet`. The label-plus-hex row owns the tap and its one semantic node; exclude the inner label and hex semantics to prevent duplicate or falsely disabled announcements. Preserve the current hex and locked layouts; do not change card heights or density. The adjacent label supersedes the older inside-hex requirement.
- [ ] Run the focused file, `flutter analyze --fatal-infos`, and `flutter test`; confirm success. Commit this task's implementation and tests.

### Task 5: Final review and delivery

- [ ] Run the public-action journey and all repository gates in `CLAUDE.md`: formatting, analysis, native tests, coverage, Chrome tests, Android debug, web, and iOS simulator debug builds. Record failures and warnings rather than inferring success.
- [ ] Re-fetch all three ticket mockups. Use a temporary Chrome-rendered Flutter harness or a real simulator to capture actual rendered surfaces into a scratch folder, without committing captures or altering user saves. Compare at 360×640, 390×844, 430×932, and 874×402; include both mastery variants, a five-planet return list while scrolled, and rig chips at both zoom endpoints. Record any unverified item honestly.
- [ ] Request an architecture/whole-branch review, fix any confirmed important findings and re-review the fixes. Push only to the existing PR #55 branch and update that draft PR's verification summary; do not merge, close, or create another PR.
