<!--
  ============================================================================
  Sync Impact Report
  ============================================================================
  Version change: N/A → 1.0.0 (initial constitution)
  Modified principles: N/A (initial)
  Added sections:
    - Core Principles (5 principles)
    - Technical Standards
    - Development Workflow
    - Governance
  Removed sections: N/A (initial)
  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ (Constitution Check section aligned)
    - .specify/templates/spec-template.md ✅ (no changes needed - technology agnostic)
    - .specify/templates/tasks-template.md ✅ (testing principles aligned)
    - .specify/templates/agent-file-template.md ✅ (no constitution-specific refs)
    - .specify/templates/checklist-template.md ✅ (no constitution-specific refs)
  Follow-up TODOs: None
  ============================================================================
-->

# Horologium Constitution

## Core Principles

### I. Dual-Architecture Separation (NON-NEGOTIABLE)

The project MUST maintain strict separation between Flutter UI and Flame game layers:

- **Flutter UI Layer** (`MainGameWidget`) manages UI state, dialogs, and user interactions
- **Flame Game Layer** (`MainGame`) handles grid rendering, camera controls, and game input events
- **Bridge Pattern** MUST be used for cross-layer communication via callback functions
- UI state changes triggered by game events MUST flow through callbacks, never direct references
- Game logic MUST NOT import Flutter widget classes; UI logic MUST NOT import Flame internals

**Rationale**: This separation enables independent testing, prevents tight coupling, and maintains clear responsibilities between visual rendering and game mechanics.

### II. Registry-Based Entity Management

All game entities (buildings, resources, research) MUST be defined through centralized registries:

- `BuildingRegistry.availableBuildings` defines all building types and their properties
- `ResourceType` enum with `ResourceRegistry` pattern for resource definitions
- `Research.availableResearch` defines the technology tree
- New entities MUST be added to their respective registries before use
- Entity properties (costs, production rates, unlock requirements) MUST be centralized in registry definitions

**Rationale**: Registries provide single sources of truth, simplify balancing, and prevent scattered magic values throughout the codebase.

### III. SharedPreferences Persistence Pattern

All game state persistence MUST use SharedPreferences with consistent key patterns:

- Resources: individual keys matching `ResourceType` names (e.g., 'cash', 'gold', 'coal')
- Buildings: StringList with format 'x,y,BuildingName'
- Research: StringList 'completed_research' with research IDs
- Save/load logic MUST be centralized, not scattered across components
- Format changes MUST include migration documentation

**Rationale**: Consistent persistence patterns enable reliable save/load, simplify debugging, and ensure data integrity across sessions.

### IV. Test-First with Mocked State

Tests MUST use `SharedPreferences.setMockInitialValues()` to seed game state:

- Unit tests MUST cover core game logic (resource calculations, building placement)
- Widget tests MUST cover UI components and user interactions
- New features SHOULD include test coverage before merge
- Tests MUST NOT depend on actual device state or external services

**Rationale**: Mocked state ensures deterministic, reproducible tests that run consistently in CI and locally.

### V. Asset-First Development

All visual assets MUST be defined before implementation:

- Sprites MUST be added to `assets/images/` with exact filenames matching `Assets` class constants
- Building sprites: `assets/images/building/<name>.png`
- Resource icons: `assets/images/resource/<name>.png`
- Terrain assets: `assets/images/terrain/<name>.png`
- Fallback rendering (colored rectangles) MUST exist for missing assets during development

**Rationale**: Asset-first ensures visual consistency, prevents runtime errors from missing files, and enables parallel art/code development.

## Technical Standards

### Technology Stack

| Component | Technology | Version Constraint |
|-----------|------------|-------------------|
| Framework | Flutter | 3.x (latest stable) |
| Game Engine | Flame | Latest stable |
| State Persistence | SharedPreferences | Latest stable |
| Language | Dart | 3.x with null safety |

### Performance Requirements

- Game loop MUST maintain 60 FPS on target devices
- Resource update timer: 1-second intervals
- Camera zoom range: 1.0x to 4.0x
- Grid size: 50x50 cells maximum
- Sprite caching MUST be used for building/terrain rendering

### Code Style

- Dart formatting: `dart format lib test` before commits
- Naming: `lowerCamelCase` for members, `PascalCase` for classes
- Flame components: dedicated files named `<Feature>Component`
- Constants: centralized in `Assets` class or relevant manager
- Trailing commas for multi-line literals

## Development Workflow

### Commit Standards

Conventional Commits format MUST be used:

- `feat:` for new gameplay features
- `fix:` for bug fixes
- `chore:` for maintenance tasks
- `ci:` for CI/CD changes
- `docs:` for documentation updates

### Pull Request Requirements

- Concise summary describing the change
- Testing notes: `flutter test` results, manual device checks
- Screenshots/recordings for UI changes
- Issue/TODO references linked
- Migration notes if save data format changes

### Quality Gates

Before merge, code MUST pass:

1. `flutter analyze` with zero warnings
2. `flutter test` with all tests passing
3. Manual verification on at least one target platform
4. Code review approval

## Governance

This constitution supersedes all other development practices for Horologium. All contributions MUST comply with these principles.

### Amendment Procedure

1. Propose change with rationale in a pull request
2. Document impact on existing code and patterns
3. Update related documentation (AGENTS.md, copilot-instructions.md)
4. Obtain approval from project maintainer
5. Increment constitution version following semantic versioning

### Version Policy

- **MAJOR**: Breaking changes to core principles or architectural patterns
- **MINOR**: New principles added or significant guidance expansions
- **PATCH**: Clarifications, typo fixes, non-breaking refinements

### Compliance

- All PRs MUST include a Constitution Check in plan documents
- Violations MUST be documented with justification in Complexity Tracking
- Use `AGENTS.md` and `.github/copilot-instructions.md` for runtime development guidance

**Version**: 1.0.0 | **Ratified**: 2025-11-30 | **Last Amended**: 2025-11-30
