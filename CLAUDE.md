# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Horologium is a Flutter/Flame-based space city-building game with a 50x50 grid system, real-time resource management, worker assignment mechanics, and research-gated progression.

## Core Architecture

### Dual-Layer Architecture
The game uses a clear separation between Flutter UI and Flame game logic:

- **Flutter UI Layer** (`MainGameWidget`): Manages dialogs, overlays, and state updates via StatefulWidget
- **Flame Game Layer** (`MainGame`): Handles grid rendering, camera controls, and game objects
- **Communication Bridge**: Callbacks connect Flame events to Flutter state updates

```dart
// Pattern: Flame → Flutter via callbacks
_game.onGridCellTapped = _onGridCellTapped;
_game.onPlanetChanged = _onPlanetChanged;
```

### Manager Pattern
Game logic is organized into specialized managers in `lib/game/managers/`:
- `GameStateManager`: Coordinates building limits and research state
- `BuildingPlacementManager`: Handles building placement validation and execution
- `InputHandler`: Processes grid interactions and user input
- `PersistenceManager`: Manages save/load operations

### State Persistence
All game state persists via SharedPreferences using specific key patterns:
- Resources: Individual keys like `'cash'`, `'gold'`, `'coal'`
- Buildings: StringList `'buildings'` with format `'x,y,BuildingName'`
- Research: StringList `'completed_research'` with research IDs
- Planet data: Nested keys like `'planet_<id>_buildings'`

### Resource System
Resources use a Map-based system with string keys matching ResourceType enum names:

```dart
// Buildings define production/consumption with string keys
building.baseGeneration = {'wood': 1, 'cash': 0.5};
building.baseConsumption = {'electricity': 0.5};

// Resource updates happen via Map operations
resources.update(resourceType, (v) => v + value, ifAbsent: () => value);
```

Update cycle runs every second:
1. Check if building has required consumption resources
2. Consume required resources
3. Generate output resources (only if building has workers assigned)

## Key File Locations

### Core Game Files
- `lib/main.dart` - App entry point with MaterialApp setup
- `lib/main_menu.dart` - Main menu screen and planet selection
- `lib/game/main_game.dart` - FlameGame implementation with grid and camera
- `lib/game/scene_widget.dart` - MainGameWidget that bridges Flutter ↔ Flame
- `lib/game/grid.dart` - Grid rendering and building placement visualization

### Game Systems
- `lib/game/building/building.dart` - BuildingType enum, Building class, BuildingRegistry
- `lib/game/resources/resources.dart` - Resources class with update logic
- `lib/game/resources/resource_type.dart` - ResourceType enum
- `lib/game/research/research.dart` - Research system with unlock trees
- `lib/game/planet/planet.dart` - Planet data model with multi-planet support
- `lib/game/services/save_service.dart` - SaveService for planet persistence
- `lib/game/services/resource_service.dart` - ResourceService for resource calculations
- `lib/game/services/building_service.dart` - BuildingService for building operations
- `lib/game/terrain/` - Procedural terrain generation with biomes and parallax

### UI Components
- `lib/widgets/game/building_selection_panel.dart` - Building menu with BuildingCard widgets
- `lib/widgets/game/resource_display.dart` - Resource overlay showing amounts and rates
- `lib/widgets/game/game_controls.dart` - Camera zoom and delete mode controls
- `lib/widgets/game/hamburger_menu.dart` - Settings and audio preferences

### Assets
- `lib/constants/assets_path.dart` - Assets helper with sprite path constants
- `assets/images/building/` - Building sprites (must match Assets constant names)
- `assets/images/terrain/` - Terrain and parallax layer assets
- `assets/audio/` - Music and sound effects

## Common Development Workflows

### Running and Testing
```bash
# Install dependencies
flutter pub get

# Run the game (native)
flutter run

# Run for web (quick testing)
flutter run -d chrome

# Run all tests
flutter test

# Run specific test file
flutter test test/resources/resources_test.dart

# Static analysis (CI uses --fatal-infos)
flutter analyze --fatal-infos

# Format code (CI enforces this)
dart format --output=none --set-exit-if-changed .

# Build release APK
flutter build apk

# Build iOS
flutter build ios
```

### Adding New Buildings
1. Add enum value to `BuildingType` in `lib/game/building/building.dart`
2. Add category to `BuildingCategory` enum if needed
3. Create building definition in `BuildingRegistry.availableBuildings`:
   ```dart
   Building(
     type: BuildingType.myBuilding,
     name: 'My Building',
     description: 'Does something',
     icon: Icons.factory,
     assetPath: Assets.myBuilding,
     color: Colors.blue,
     baseCost: 100,
     baseGeneration: {'wood': 1},
     baseConsumption: {'electricity': 0.5},
     requiredWorkers: 2,
     category: BuildingCategory.production,
   )
   ```
4. Add sprite constant to `lib/constants/assets_path.dart`:
   ```dart
   static const String myBuilding = 'assets/images/building/my_building.png';
   ```
5. Place sprite at `assets/images/building/my_building.png`
6. Optionally gate behind research in `Research.availableResearch`
7. Test placement, worker assignment, and resource flow

### Adding New Resources
1. Add to `ResourceType` enum in `lib/game/resources/resource_type.dart`
2. Add to `ResourceCategory` enum if it's a new category
3. Initialize in `Resources.resources` map with default value
4. Add sprite constant to `Assets` class (optional)
5. Update UI in `resource_display.dart` if needed for display
6. Update relevant building generation/consumption maps
7. Add persistence handling in `SaveService` if needed
8. Add tests in `test/resources/resources_test.dart`

### Adding New Research
1. Create `Research` instance in `Research.availableResearch` list:
   ```dart
   Research(
     id: 'advanced_tech',
     name: 'Advanced Technology',
     description: 'Unlocks advanced buildings',
     cost: 500,
     unlocksBuildings: [BuildingType.researchLab],
     prerequisites: ['basic_tech'],
   )
   ```
2. Reference research ID in building unlock conditions
3. Test research tree progression and building unlock behavior

### Writing Tests
Use `SharedPreferences.setMockInitialValues()` in test setUp:

```dart
setUp(() {
  SharedPreferences.setMockInitialValues({
    'cash': 1000.0,
    'population': 20,
    'buildings': ['5,5,House', '10,10,Power Plant'],
  });
});
```

Test files should mirror lib structure and use `*_test.dart` naming.

### Adding Terrain Features
1. Add sprite assets to appropriate `assets/images/terrain/` subdirectory
2. Update `TerrainAssets` class with asset paths
3. Configure in `TerrainGenerator` for procedural placement
4. Adjust `TerrainBiome` if adding biome-specific features
5. Use `ParallaxTerrainComponent` for multi-layer parallax effects

## Architecture Patterns

### Worker Assignment Flow
```dart
// Check if workers available
if (resources.canAssignWorkerTo(building)) {
  resources.assignWorkerTo(building);
  building.assignWorker();
}

// Buildings only produce when they have required workers
if (building.hasWorkers) {
  // Generate resources
}
```

### Building Placement Flow
```dart
// 1. Check grid availability (no overlap)
// 2. Validate sufficient resources
// 3. Check building limits (research-gated)
// 4. Place building on grid
// 5. Deduct resources
// 6. Save to SharedPreferences
```

### Camera Controls
- Pinch-to-zoom: 1.0x to 4.0x zoom range
- Pan/drag to navigate grid
- Zoom clamping in `MainGame.onScaleUpdate()`

## UI Conventions

### Dark Space Theme
- Primary accent: `Colors.cyanAccent` with glowing shadows
- Background: Dark with starfield CustomPainter
- Card backgrounds: `Colors.withAlpha((255 * 0.8).round())`
- Consistent spacing: padding 16, margins 8-20

### Common UI Patterns
- **BuildingCard**: Shows building icon, name, cost, and count limits
- **ResourceCard**: Displays resource amount with +/- production rate
- **Delete mode**: Toggle via GameControls, highlights buildings red on tap
- **Dialogs**: Custom styled with dark theme and cyan accents

## Project-Specific Notes

### Multi-Planet System
The game supports multiple planets. Active planet is tracked via `ActivePlanet.instance.currentPlanet`. Each planet has independent:
- Resources
- Buildings
- Research progress
- Grid state

Save/load operations are planet-scoped using planet ID in SharedPreferences keys.

### Audio System
Background music controlled via `AudioPlayer` with web-safe autoplay handling (starts on first user interaction). Preferences stored in SharedPreferences.

### Terrain System
Procedural terrain generation with biome support. Parallax layers create depth. See `docs/` for detailed terrain implementation guides.

### Coding Style
- Follow Flutter defaults: 2-space indentation, trailing commas for multi-line literals, and `lowerCamelCase` for members
- Keep Flame components in dedicated files named `<Feature>Component` to ease discovery
- Run `dart format --output=none --set-exit-if-changed .` before committing; CI enforces these rules
- Centralize constants in the relevant manager or `Assets` class rather than scattering magic values

### Commit Guidelines
- Adopt Conventional Commits (`feat:`, `fix:`, `chore:`, `ci:`) as in the git history
- Keep commits focused: gameplay change, UI tweak, and tooling updates should land separately
- Pull requests need a concise summary, testing notes (`flutter test`, manual device checks), and any relevant screenshots or screen recordings
- Link issues or TODO references, and call out migrations that require data wipes or saved-game resets

## CI/CD

GitHub Actions runs on push/PR to main:
- `flutter analyze --fatal-infos` - must pass with no warnings
- `dart format --output=none --set-exit-if-changed .` - enforces formatting
- `flutter test --coverage` - runs all tests
- Builds debug APK and web artifacts

## Utility Scripts

- `scripts/resize_images.py` - Batch resize sprite assets
- `scripts/process_terrain_assets.py` - Process terrain sprite sheets
- Requirements: `pip install -r scripts/requirements.txt`
