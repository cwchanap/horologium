<!--
  ============================================================================
  Sync Impact Report
  ============================================================================
  Date: 2026-08-20
  Version change: 1.0.0 -> 2.0.0 (breaking mining cutover)
  Modified principles:
    - I. Dual-Architecture Separation -> I. Flutter/Flame Ownership Separation
    - II. Registry-Based Entity Management -> II. Mining Content/State Separation
      and One Mutation Boundary
    - III. SharedPreferences Persistence Pattern -> III. Strict Unversioned
      Mining Persistence
    - IV. Test-First with Mocked State -> IV. Deterministic Test-First
      Economy/Persistence Behavior
    - V. Asset-First Development -> V. Asset-Backed Presentation with
      Development Fallbacks
  Added sections:
    - Mining ownership and mutation boundary
    - Unversioned save contract and compatibility rule
    - Current quality-gate and target-verification workflow
  Removed sections:
    - Registry mandates for retired domains
    - Domain-specific preference layouts and economy-loop mandates
    - Placement-world and retired progression requirements
  Retained guidance:
    - Format, analyze, test, and target-build quality gates
    - Deterministic tests and asset discipline
  Templates requiring updates:
    - .specify/templates/plan-template.md - checked; no change required
    - .specify/templates/spec-template.md - checked; no change required
    - .specify/templates/tasks-template.md - checked; no change required
  Follow-up TODOs: None.
  ============================================================================
-->

# Horologium Constitution

## Core Principles

### I. Flutter/Flame Ownership Separation (NON-NEGOTIABLE)

The project MUST keep Flutter presentation and Flame world rendering in
separate ownership boundaries. `MainMenu` and `MiningScreen` own Flutter
navigation, presentation state, lifecycle, accessibility propagation, and
user-facing feedback. `MiningGame` owns Flame world components, camera,
selection, and visual effects. Cross-boundary communication MUST use explicit
callbacks or values; Flame code MUST NOT own persistence or Flutter widgets,
and Flutter presentation MUST NOT reach into Flame internals for game state.

Rationale: A small, explicit bridge keeps UI and rendering independently
testable while preventing a second state owner from forming.

### II. Mining Content/State Separation and One Mutation Boundary (NON-NEGOTIABLE)

Authored mining definitions MUST remain separate from mutable save state.
`MiningContentRegistry` owns sector identity, costs, rates, capacities, sale
values, upgrade data, assets, and world anchors. `MiningSave` owns cash,
timestamps, sector progress, and mine progress. `MiningController` MUST be the
single mutation boundary for reveal, build, upgrade, sale, checkpoint, and
resume operations. `MiningSimulation` MUST remain deterministic and side
effect free; `MiningGame` MUST consume state rather than mutate it.

Rationale: Separate content and state makes balancing safe, keeps economy logic
replayable, and prevents UI or rendering code from bypassing persistence order.

### III. Strict Unversioned Mining Persistence (NON-NEGOTIABLE)

Mining state MUST be stored only as the strict JSON document at the
`horologium.mining.save` SharedPreferences key. Until a shipped compatibility
need exists, the document MUST remain unversioned: no version field, migration
table, or legacy-key interpretation may be added. The repository MUST reject
unknown or missing schema keys, create initial state when data is missing, and
recover to initial state while reporting invalid data to the UI. Mutations and
lifecycle checkpoints MUST write through `MiningSaveRepository`.

Rationale: A narrow contract makes save behavior auditable and avoids silently
mixing unrelated preference data into mining progress.

### IV. Deterministic Test-First Economy/Persistence Behavior (NON-NEGOTIABLE)

Economy and persistence behavior MUST have deterministic unit coverage before
integration. `MiningSimulation` tests MUST use fixed UTC inputs and cover
accrual, storage caps, clock rollback, offline caps, and repeatability.
Repository and controller tests MUST use mocked preferences plus injected
clocks or repositories; widget and journey tests MUST not depend on existing
device state, wall clock, network, or test order. Changes MUST preserve
focused tests and the full repository test pass.

Rationale: Deterministic inputs expose economy and save regressions without
making CI depend on external state.

### V. Asset-Backed Presentation with Development Fallbacks (NON-NEGOTIABLE)

Visual mining and terrain presentation MUST use centralized asset constants and
declared Flutter assets. New authored visuals MUST have their asset path and
asset registration defined before use. Renderers MUST retain an intentional
development fallback where an asset is unavailable, so missing art does not
prevent layout, interaction, or deterministic tests from running.

Rationale: Asset discipline protects the authored look while fallbacks keep
engineering and test workflows usable during content iteration.

## Technical Standards

### Technology Stack

| Component | Technology | Version Constraint |
|---|---|---|
| Framework | Flutter | 3.x |
| Game Engine | Flame | 1.x |
| Language | Dart with null safety | SDK constraint in `pubspec.yaml` |
| Mining persistence | SharedPreferences | Current project dependency |
| Background music | audioplayers through `AudioManager` | Current project dependency |

### Current runtime contracts

- Resource identity is the exhaustive enum `gold`, `coal`, and `stone`.
- Simulation time is UTC and offline accrual is capped at eight hours.
- The active-screen refresh is one second; it refreshes presentation and does
  not replace deterministic simulation accrual.
- Reduced motion comes from Flutter's `MediaQuery.disableAnimations` and is
  passed into Flame feedback.
- Audio preferences use `audio.musicEnabled` and `audio.musicVolume`; the
  mining save uses a separate key and schema.

### Code style and assets

- Dart code MUST pass the repository formatter with two-space indentation,
  trailing commas for multiline literals, and lowerCamelCase/PascalCase names.
- Flame components MUST live in appropriately named files under the relevant
  world or terrain directory.
- Asset paths MUST be centralized in `Assets` or `TerrainAssets` and declared
  under the Flutter asset section before use.

## Development Workflow

### Verification commands

Install dependencies with `flutter pub get`. Run focused tests during a change,
then the applicable repository gates:

```sh
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
flutter test --coverage
flutter test --platform chrome
flutter build apk --debug
flutter build web
```

Target verification MUST match the change: run native and browser checks when
touching platform or launch behavior, and run the mining journey tests when
changing state, actions, persistence, or presentation flow.

### Commit standards

Contributors MUST use focused Conventional Commit prefixes:

- `feat:` for gameplay or presentation features
- `fix:` for behavior corrections
- `test:` for test-only changes
- `docs:` for guidance or governance changes
- `chore:` for maintenance and dependency work
- `ci:` for workflow changes

### Quality gates

Before merge, changes MUST pass:

1. `flutter analyze --fatal-infos` with no analyzer issues.
2. `dart format --output=none --set-exit-if-changed .`.
3. Relevant focused tests and the full `flutter test` suite.
4. Browser test/build checks when web-facing behavior changes.
5. Native target build checks when platform-facing behavior changes.
6. Review of save-schema, asset, and accessibility impact for applicable
   changes.

## Governance

This constitution is the source of truth for project-wide engineering
principles. `CLAUDE.md` contains the detailed implementation guidance;
`.github/copilot-instructions.md` is a concise compatibility shim and
`.windsurf/rules/project.md` is an always-on pointer. `AGENTS.md` MUST remain a
symlink to `CLAUDE.md`; do not maintain a second guidance body.

### Amendment procedure

1. Propose the rationale and affected principles in the change.
2. Describe impact on runtime ownership, save compatibility, tests, assets,
   accessibility, and target verification.
3. Update this constitution's Sync Impact Report and date.
4. Check dependent templates and guidance entrypoints for consistency.
5. Obtain maintainer approval through the normal review process.

### Version policy

- **MAJOR**: Breaking removal or redefinition of a principle or governance
  requirement.
- **MINOR**: New principle or materially expanded non-breaking governance.
- **PATCH**: Clarification, typo, or non-semantic wording refinement.

### Compliance

Every implementation plan MUST include a Constitution Check against these
principles. Any justified violation MUST be recorded in that plan's Complexity
Tracking section. Reviewers MUST verify the applicable quality gates and any
save, asset, accessibility, or target-verification implications.

**Version**: 2.0.0 | **Ratified**: 2025-11-30 | **Last Amended**: 2026-08-20
