---
trigger: always_on
---

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Horologium is a Flutter-based space city-building game using the Flame game engine. The core architecture uses Flame's component system with a 50x50 grid for building placement, real-time resource management, and research-gated progression.

## Development Commands

- **Install dependencies**: `flutter pub get`
- **Run the application**: `flutter run`
- **Run tests**: `flutter test`
- **Build for Android**: `flutter build apk`
- **Build for iOS**: `flutter build ios`
- **Analyze code**: `flutter analyze`

## Code Architecture

### Dual-Architecture System
- **Flutter UI Layer**: `MainGameWidget` (StatefulWidget) manages UI state and dialogs
- **Flame Game Layer**: `MainGame` (FlameGame) handles grid, camera, and input events
- **Bridge Pattern**: Callback functions connect Flame events to Flutter state updates

Key pattern for Flame → Flutter communication:
```dart
_game.onGridCellTapped = _handleGridCellTapped;
_game.onGridCellLongTapped = _inputHandler.handleGridCellLongTapped;
```

### Core Structure
- `lib/main.dart` - Application entry point with MaterialApp and dark space theme
- `lib/main_menu.dart` - Animated main menu with starfield background and navigation
- `lib/game/scene_widget.dart` - Main game widget integrating Flame with Flutter UI
- `lib/game/main_game.dart` - Flame game with grid system and camera controls
- `lib/game/grid.dart` - 50x50 grid system for building placement
- `lib/game/resources/resources.dart` - Resource management system
- `lib/game/building/building.dart` - Building definitions and registry
- `lib/game/managers/` - Game state, persistence, and input management

### Resource System Architecture
- **ResourceType enum** defines all resources (cash, gold, wood, coal, electricity, water, research, stone, planks)
- **Resources class** manages `Map<ResourceType, double>` with helper getters/setters
- **Timer-based updates**: 1-second intervals trigger building production/consumption
- **Worker assignment**: Buildings require workers to produce resources
- **Population system**: Tracks sheltered/unsheltered population and available workers

### Building System
- **Grid-based placement**: 50x50 cell grid with collision detection
- **Building types**: Houses, factories, mines, research labs, utilities
- **Production chains**: Buildings consume and produce different resources
- **Worker requirements**: Buildings need assigned workers to operate
- **Research gating**: Advanced buildings locked behind technology research

### State Persistence
All game state uses SharedPreferences with specific patterns:
- Resources: individual keys like 'cash', 'gold', 'coal'
- Buildings: StringList 'buildings' with format 'x,y,BuildingName'
- Research: StringList 'completed_research' with research IDs

### Key Integration Points
- Grid interactions trigger callback functions that update Flutter state
- PlacementPreview component shows building validity before placement
- Camera zoom clamped between 1.0x-4.0x with drag controls
- Timer management for resource generation and UI updates

## Development Patterns

### Adding Buildings
1. Add to `BuildingType` enum and `BuildingRegistry.availableBuildings`
2. Define category in `BuildingCategory` enum
3. Add sprite path to `Assets` class (assets/images/building/name.png)
4. Use baseGeneration/baseConsumption Maps with string keys matching ResourceType names

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

### Worker Assignment System
Buildings track `assignedWorkers`/`requiredWorkers`. Resources class provides:
```dart
bool canAssignWorkerTo(Building building)
void assignWorkerTo(Building building)
void unassignWorkerFrom(Building building)
```

## Theme and Styling
- Dark space theme with cyan/purple accent colors (`Colors.cyanAccent`)
- Custom text shadows and glowing effects
- Consistent transparency: `Colors.withAlpha((255 * 0.8).round())`
- Animated starfield with twinkling effects using CustomPainter
- Floating particle effects for visual polish

## Testing
- Widget tests in `test/widget_test.dart` and `test/scene_test.dart`
- Use `flutter test` to run all tests
- Mock SharedPreferences for state-dependent tests

## Platform Support
- Android: Uses Kotlin for platform-specific code
- iOS: Uses Swift for platform-specific code  
- Both platforms configured with standard Flutter project structure