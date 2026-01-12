# Parallax Terrain System Implementation Guide

## Overview
The parallax terrain system creates beautiful depth effects using multiple layers that move at different speeds relative to the camera. This creates an immersive 2D anime-style environment with realistic depth perception while maintaining all existing game functionality.

## Parallax Layer Architecture

### Depth Layers (Back to Front)
1. **Far Background** (0.15x speed) - Distant mountains and sky
2. **Mid Background** (0.45x speed) - Main terrain base (grass, dirt, water)
3. **Near Background** (0.75x speed) - Large features (big trees, large rocks)
4. **Foreground** (0.9x speed) - Detail features (small trees, bushes, small rocks)
5. **Interactive** (1.0x speed) - Grid, buildings (no parallax effect)

### Visual Effect
- **Far elements** move slowly, appearing distant
- **Near elements** move faster, appearing closer
- **Interactive elements** move with camera, maintaining gameplay precision
- Creates **depth illusion** as camera pans around the world

## New Components

### 1. ParallaxTerrainComponent
**File:** `lib/game/terrain/parallax_terrain_component.dart`

Main terrain system that manages all parallax layers:
```dart
// Create parallax terrain
final terrain = ParallaxTerrainComponent(
  gridSize: 50,
  seed: planetId.hashCode,
);

// Check buildability (works same as before)
final canBuild = terrain.isBuildableAt(x, y);

// Get terrain statistics
final stats = terrain.getTerrainStats();
```

**Key Features:**
- Manages all depth layers automatically
- Provides same buildability API as original terrain
- Supports terrain regeneration with new seeds
- Includes atmosphere effects and ambient lighting

### 2. ParallaxTerrainLayer
**File:** `lib/game/terrain/parallax_terrain_layer.dart`

Individual parallax layer that renders terrain elements at specific depths:
```dart
// Layers are created automatically by ParallaxTerrainComponent
// Each layer handles its own parallax movement and rendering
```

**Key Features:**
- Automatic parallax movement based on camera position
- Sprite caching and fallback color rendering
- Depth-appropriate feature sizing and positioning
- Optimized rendering for performance

### 3. TerrainDepthManager
**File:** `lib/game/terrain/terrain_depth_manager.dart`

Configuration system for depth layers:
```dart
// Get configuration for a depth layer
final config = TerrainDepthManager.getConfig(TerrainDepth.nearBackground);

// Filter terrain for specific depth
final layerTerrain = TerrainDepthManager.filterTerrainForDepth(
  allTerrain, 
  TerrainDepth.midBackground,
);
```

**Key Features:**
- Defines which terrain elements appear on each layer
- Configures parallax speeds and render order
- Manages terrain filtering and distribution
- Supports special terrain generation for far backgrounds

## Integration Changes

### MainGame Updates
```dart
// Old terrain system
_terrain = TerrainComponent(gridSize: 50, seed: seed);

// New parallax terrain system  
_terrain = ParallaxTerrainComponent(gridSize: 50, seed: seed);
```

### Grid System
- Updated to work with `ParallaxTerrainComponent`
- Same buildability checking interface
- Enhanced visual integration with parallax layers

### Building Placement
- Same placement validation system
- Enhanced visual feedback with depth-aware previews
- Maintains all existing building mechanics

## Depth Layer Distribution

### Far Background (0.15x speed)
- **Terrain**: Rocky mountains, snow-capped peaks
- **Features**: None (pure background)
- **Purpose**: Create distant landscape backdrop

### Mid Background (0.45x speed)  
- **Terrain**: Grass, dirt, sand, water bases
- **Features**: Large water bodies (lakes, rivers)
- **Purpose**: Primary terrain foundation

### Near Background (0.75x speed)
- **Features**: Large trees, large rocks
- **Purpose**: Major landscape features that add depth

### Foreground (0.9x speed)
- **Features**: Small trees, bushes, small rocks
- **Purpose**: Detailed environmental elements

### Interactive (1.0x speed)
- **Elements**: Grid lines, buildings, UI elements
- **Purpose**: Maintain precise gameplay mechanics

## Performance Benefits

### Optimized Rendering
- Each layer only renders relevant terrain elements
- Sprite caching reduces memory usage
- Fallback colors for missing assets
- Viewport culling ready for large worlds

### Smart Asset Loading
- Assets loaded per layer on demand
- Graceful handling of missing assets
- Consistent visual fallbacks

### Memory Efficiency
- Terrain data shared across layers
- Filtered rendering reduces overdraw
- Component-based architecture for easy optimization

## Visual Enhancements

### Atmosphere Effects
- Subtle ambient lighting gradients
- Depth-based atmospheric perspective
- Color variations based on distance

### Realistic Depth
- Natural parallax movement speeds
- Appropriate feature sizing per layer
- Consistent visual hierarchy

### Anime Style Aesthetics
- Soft, hand-painted appearance maintained
- Vibrant color palette preserved
- Depth enhances rather than overwhelms

## Usage Examples

### Basic Usage
```dart
// Terrain is automatically created in MainGame
final terrain = game.terrain;

// Check buildability (same API as before)
if (terrain?.isBuildableAt(x, y) ?? false) {
  // Place building
}

// Get terrain information
final terrainCell = terrain?.getTerrainAt(x, y);
final biome = terrainCell?.biome;
```

### Advanced Features
```dart
// Regenerate terrain with new seed
await terrain?.regenerateTerrain(newSeed: 12345);

// Get all parallax layers
final layers = terrain?.getAllLayers();

// Get specific layer
final backgroundLayer = terrain?.getLayer(TerrainDepth.midBackground);

// Get terrain statistics including parallax info
final stats = terrain?.getTerrainStats();
```

### Performance Controls
```dart
// Enable/disable parallax effect
terrain?.setParallaxEnabled(false); // Disable for low-end devices

// Load terrain regions for large worlds
await terrain?.loadRegion(startX, startY, width, height);
```

## Configuration Options

### Parallax Speeds
Current speeds are optimized for visual appeal:
- Far Background: 0.15x (very slow, distant)
- Mid Background: 0.45x (medium, main terrain)
- Near Background: 0.75x (faster, large features)
- Foreground: 0.9x (almost normal, details)

### Layer Content
Easily configurable in `TerrainDepthManager`:
- Add new terrain types to specific layers
- Adjust feature distribution
- Modify depth assignments

## Migration from Original Terrain

### API Compatibility
The parallax terrain maintains the same public API:
```dart
// These methods work identically
terrain.isBuildableAt(x, y)
terrain.getTerrainAt(x, y)
terrain.regenerateTerrain()
terrain.getBiomeDistribution()
terrain.getTerrainStats()
```

### Enhanced Features
Additional capabilities in parallax version:
- Multiple depth layers with automatic management
- Improved visual depth and atmosphere
- Better performance through layer optimization
- Enhanced debugging and inspection tools

## Troubleshooting

### Performance Issues
- Reduce number of terrain features in generator
- Disable parallax effect on low-end devices
- Implement viewport culling for very large worlds

### Visual Issues
- Check asset loading and fallback colors
- Verify parallax speeds in `TerrainDepthManager`
- Ensure proper layer ordering and render priorities

### Building Placement Problems
- Parallax terrain uses same buildability logic
- Check `isBuildableAt` method behavior
- Verify terrain generation creates buildable areas

## Future Enhancements

### Animation Support
- Water ripple animations
- Tree swaying effects
- Atmospheric particle systems

### Dynamic Weather
- Seasonal terrain variations
- Weather-based visual effects
- Day/night lighting cycles

### Terrain Modification
- Real-time terrain editing tools
- Dynamic feature placement
- Player-customizable landscapes

The parallax terrain system creates a visually stunning anime-style environment that enhances the game's atmosphere while maintaining all existing functionality and performance characteristics.
