# HPA-855 Floating Mastery Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Match the mastery mockup while retaining readable, immediately accessible small-screen actions and accurate gate progress.

**Architecture:** Extend the existing Stellar Map requirement projection with current-value display metadata without changing existing labels or eligibility. Replace only the mastery card's frame with a responsive floating presentation; the shell still owns the route, top inset, and callbacks.

**Tech Stack:** Flutter, Dart, `flutter_test`, existing production fonts and assets.

**Spec:** `docs/superpowers/specs/2026-11-13-mastery-floating-card-design.md`

## Global Constraints

- Preserve save schema, economy, reward, progression, navigation, route unwinding, audio, reduced motion, semantics, and keyboard access; no new state owner or dependency.
- Do not change other sheet layouts or Stellar Map requirement labels, eligibility, or behavior.
- At 360×640, 390×844, 430×932, and 874×402, text scales 1.0 and 1.3 and appropriate safe insets, key content and both actions are visible and hit-testable immediately. Key content includes all Homeworld gates and actual current values, and Io name, reward and full next-run explanation.
- Use the actual real fonts in geometry tests. Do not reduce user text scale, hide or ellipsize key content, or weaken existing coverage.
- Keep work on the existing draft PR #55; do not merge.

## Review Focus

- Cash and Surveying values change independently of thresholds: projection tests must assert exact current values and unchanged labels/statuses.
- Unlocked planets and zero-cost gates: projection tests must preserve existing satisfied logic and not invent a cash gate.
- Long later-planet names and formatted large cash: card tests must verify complete wrapping, no overlap, and access to actions.
- Notched portrait and landscape rotation while open: shell tests must preserve safe-area clearance and route callbacks.
- Final planet/relaunch counts: card/shell tests must preserve the ×1.5/×2 projections and both action semantics.

### Task 1: Project current gate values

**Files:** Modify `lib/mining/mining_progression_views.dart`; test `test/mining/mining_progression_views_test.dart` (or existing progression view tests).

**Interfaces:** Extend `StellarMapRequirementView` with an optional immutable `String? currentValue` (default null). Surveying requirement uses `now LV <actual level>`; cash requirement uses `formatMiningCash(state.cash)`. Existing label and `isSatisfied` contract is unchanged. Other requirements have null currentValue.

- [ ] Write failing projection tests for unmet and met requirements, changed cash/Surveying, unlocked planets and a zero-cost successor; assert exact currentValue plus existing labels/status.
- [ ] Run focused progression tests and confirm the expected RED.
- [ ] Add the minimal projection; do not change displayed Stellar Map labels or persistence.
- [ ] Run focused progression tests, fatal-info analysis and full `flutter test`; commit task.

### Task 2: Floating mastery presentation

**Files:** Modify `lib/mining/presentation/planet_mastered_card.dart`, `lib/mining/presentation/mining_shell.dart` only if needed; test `test/mining/presentation/planet_mastered_card_test.dart`, `test/mining/presentation/mining_shell_test.dart` and other affected tests.

**Interfaces:** Consume Task 1's `currentValue`; retain existing card keys, callbacks, `nextSaleMultiplier`, and live top inset contract. Mockup source: HPA-855's `Planet mastered card, before and after` image.

- [ ] Add failing production-font tests for a centered floating card with overlapping planet and outlined badge at 390×844/1.0, white centered name, mockup action labels and rounded-rectangle shape. Assert real projected progress, all relevant semantic nodes and callbacks.
- [ ] Add first-frame rect and hit-test matrix for both variants, target sizes/scales/safe insets; check heading, gates/current values, Io explanation, body/footer and gauge/close geometry, rotation, later-planet long labels and ×1.5/×2. Preserve all existing tests or update only selectors/copy that intentionally change; do not weaken assertions.
- [ ] Run focused tests and confirm expected RED before implementation.
- [ ] Implement the dedicated card with responsive compact variants; retain state ownership and route behavior.
- [ ] Run focused VM and Chrome tests, fatal-info analysis, format and full `flutter test`; commit task.

### Task 3: Visual and release verification

**Files:** no production changes unless a defect is found.

- [ ] Capture real Flutter rendering with actual assets/fonts for both cards at the four target sizes, including 1.3 and safe-area variants, and compare against the HPA-855 mockup. Report physical-device, pinch and synthetic-harness limits honestly.
- [ ] At 390×844 and 430×932, text 1.0 and 1.3, verify the roomy portrait Homeworld and Io cards place the first action within 32 logical pixels below the last detail when all content fits; use a content-sized floating card rather than expanding the empty body. Preserve the compact/landscape first-frame and interaction matrix.
- [ ] Run format, fatal-info analysis, full VM and Chrome suites, coverage, public-action journey, Android debug, web and iOS simulator debug builds.
- [ ] Review the complete follow-up, push the existing branch and update draft PR #55 with verification and visual limitations.
