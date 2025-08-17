# GitHub Copilot Instructions for Horologium

## Project Overview

Horologium is a Flutter/Flame-based space city-building game. The core architecture uses Flame's component system with a 50x50 grid for building placement, real-time resource management, and research-gated progression.

## Critical Architecture Patterns

### Dual-Architecture System
- **Flutter UI Layer**: `MainGameWidget` (StatefulWidget) manages UI state and dialogs
- **Flame Game Layer**: `MainGame` (FlameGame) handles grid, camera, and input events
- **Bridge Pattern**: Callback functions connect Flame events to Flutter state updates

```dart
// Key pattern: Flame → Flutter communication via callbacks
_game.onGridCellTapped = _onGridCellTapped;
_game.onGridCellLongTapped = _onGridCellLongTapped;
```

### Resource System Architecture
- **ResourceType enum** defines all resources (cash, gold, wood, etc.)
- **Resources class** manages Map<ResourceType, double> with helper getters/setters
- **Timer-based updates**: 1-second intervals trigger building production/consumption
- **Worker assignment**: Buildings require workers to produce resources

### State Persistence Pattern
All game state uses SharedPreferences with specific key patterns:
- Resources: individual keys like 'cash', 'gold', 'coal'
- Buildings: StringList 'buildings' with format 'x,y,BuildingName'
- Research: StringList 'completed_research' with research IDs

## Essential Development Workflows

### Adding Buildings
1. Add to `BuildingType` enum and `BuildingRegistry.availableBuildings`
2. Define category in `BuildingCategory` enum  
3. Add sprite path to `Assets` class (assets/images/building/name.png)
4. Buildings use baseGeneration/baseConsumption Maps with string keys matching ResourceType names

### Resource Management Flow
```dart
// Production/consumption uses string keys that map to ResourceType enum
building.baseGeneration = {'wood': 1, 'cash': 0.5};
// Update cycle: check consumption → consume → produce
resources.update(resourceType, (v) => v + value, ifAbsent: () => value);
```

### Testing Patterns
Use `SharedPreferences.setMockInitialValues()` for all tests:
```dart
SharedPreferences.setMockInitialValues({
  'cash': 1000.0,
  'population': 20,
  'buildings': ['5,5,House', '10,10,Power Plant']
});
```

## Key Integration Points

### Flame-Flutter Bridge
- Grid interactions trigger callback functions that update Flutter state
- PlacementPreview component shows building validity before placement
- Camera zoom clamped between 1.0x-4.0x with drag controls

### UI Component Patterns
- **BuildingCard**: Shows cost, count limits, uses BuildingLimitManager
- **ResourceCard**: Displays amount + production/consumption rates
- Cards use consistent dark theme with `Colors.withAlpha((255 * 0.8).round())`

### Worker Assignment System
Buildings track `assignedWorkers`/`requiredWorkers`. Resources class provides:
```dart
bool canAssignWorkerTo(Building building)
void assignWorkerTo(Building building)
void unassignWorkerFrom(Building building)
```

## Project-Specific Conventions

### File Organization
- `lib/game/building/building.dart` - Single file contains BuildingType enum, Building class, BuildingRegistry
- `lib/game/resource_type.dart` - ResourceType enum + ResourceRegistry pattern
- `lib/widgets/cards/` - Reusable UI components with consistent styling
- Building assets: `assets/images/building/` with exact filename matching Assets constants

### Research System
Research objects unlock BuildingTypes and can increase building limits:
```dart
Research(id: 'electricity', unlocksBuildings: [BuildingType.powerPlant])
```

Focus on the Map-based resource system, callback-driven Flame integration, and SharedPreferences persistence when making changes.

1. **Scene-Based Architecture**: Clean separation between main menu and game scenes
2. **Component System**: Uses Flame's component-based architecture with `PositionComponent` and `FlameGame`
3. **State Management**: StatefulWidget pattern with SharedPreferences for persistence
4. **Resource System**: Centralized resource management with automatic updates
5. **Building Registry**: Static registry pattern for building definitions and availability
6. **Research Dependencies**: Tree-based technology unlocking system

### Game Systems

#### Building System
- **Grid-based placement**: 50x50 cell grid with collision detection
- **Building types**: Houses, factories, mines, research labs, utilities
- **Sprite rendering**: Asset-based rendering with fallback to colored rectangles  
- **Upgrade system**: Multi-level buildings with increasing costs and efficiency
- **Worker assignment**: Buildings require workers to operate effectively
- **Building limits**: Research-gated building count restrictions

#### Resource Management
- **Core resources**: Cash, gold, wood, coal, electricity, water, research, stone, planks
- **Population system**: Sheltered/unsheltered population with accommodation needs
- **Worker allocation**: Available workers can be assigned to buildings
- **Production chains**: Buildings consume and produce different resources
- **Real-time updates**: Resources update every second based on building production

#### Research System
- **Technology tree**: Hierarchical research with prerequisites
- **Building unlocks**: Research gates access to advanced building types
- **Research points**: Generated by research labs and consumed for upgrades
- **Persistent progress**: Research completion saved between sessions

#### Visual Features
- **Pinch-to-zoom**: Camera controls with 1.0x to 4.0x zoom range
- **Animated starfield**: Procedural twinkling star background with CustomPainter
- **Particle effects**: Floating particles and visual polish
- **Dark space theme**: Cyan accent colors with glowing effects and shadows
- **Building previews**: Visual placement preview with validity indicators

## Technical Guidelines

### Code Style
- Use modern Dart/Flutter patterns and null safety
- Follow the existing naming conventions (camelCase for variables, PascalCase for classes)
- Maintain the space theme aesthetic in UI elements
- Keep the dark color scheme with cyan/purple accents

### Architecture Patterns
- **Separation of concerns**: Keep game logic separate from UI logic
- **Component composition**: Use Flame components for game objects
- **State persistence**: Use SharedPreferences for save data
- **Async/await**: Handle asynchronous operations properly
- **Resource management**: Dispose of controllers and timers in dispose() methods

### Game Development Best Practices
- **Grid coordinates**: Use integer grid positions for building placement
- **Collision detection**: Check building overlap before placement
- **Resource validation**: Ensure sufficient resources before allowing actions
- **Performance**: Cache sprites and reuse components where possible
- **Testing**: Maintain test coverage for core game mechanics

### UI/UX Guidelines
- **Responsive design**: Support different screen sizes and orientations
- **Accessibility**: Use semantic labels and proper contrast
- **Animations**: Use smooth transitions and meaningful motion
- **Feedback**: Provide clear visual/audio feedback for user actions
- **Information hierarchy**: Use consistent spacing and typography

### File Organization
- **Game logic**: Keep in `lib/game/` directory
- **UI components**: Organize in `lib/widgets/` and `lib/pages/`
- **Constants**: Define in `lib/constants/` for reusability
- **Assets**: Store images in `assets/images/building/` with appropriate naming
- **Tests**: Mirror lib structure in test directory

### Dependencies
- **Flame**: Game engine for 2D rendering and input handling
- **SharedPreferences**: Local data persistence
- **Flutter Material**: UI components and theming
- Avoid adding unnecessary dependencies without justification

### Common Patterns in Codebase
- **Building placement**: Check grid availability → validate resources → place building → save state
- **Resource updates**: Timer-based updates with state management
- **UI dialogs**: Use showDialog with custom styling for building interactions
- **Animation controllers**: Multiple controllers for staggered animations
- **Null safety**: Proper null checking and optional chaining throughout

### Performance Considerations
- **Sprite caching**: Load and cache building sprites once
- **Timer management**: Cancel timers in dispose() methods
- **Grid rendering**: Optimize grid line drawing and building rendering
- **Memory management**: Dispose of unused resources and controllers

### Testing Strategy
- **Unit tests**: Core game logic (resource calculations, building placement)
- **Widget tests**: UI components and user interactions
- **Integration tests**: Full game flow and state persistence
- **Mock data**: Use SharedPreferences.setMockInitialValues for testing

## Common Development Tasks

### Adding New Buildings
1. Add building type to `BuildingType` enum
2. Create building definition in `BuildingRegistry.availableBuildings`
3. Add sprite asset to `assets/images/building/` and reference in `Assets` class
4. Update research system if building should be gated
5. Add to building limits if needed
6. Test placement, resource consumption, and production

### Adding New Resources
1. Add resource to `Resources.resources` map with default value
2. Update save/load methods in scene.dart
3. Add UI display in resource overlay
4. Update relevant building production/consumption
5. Test resource flow and persistence

### Adding New Research
1. Create `Research` instance in `Research.availableResearch`
2. Define prerequisites and building unlocks
3. Update research tree UI if needed
4. Test unlock conditions and progression

### UI Modifications
- Follow existing dark space theme with cyan/purple accents
- Use consistent spacing (padding: 16, margins: 8-20)
- Maintain animated transitions and smooth interactions
- Test on different screen sizes and orientations

This document should guide development decisions and maintain consistency across the Horologium codebase while preserving the space exploration theme and game mechanics.
