# Horologium Terrain Assets Generation Guide

## Overview
This document provides comprehensive specifications for generating 2D anime-style terrain assets for the Horologium space city-building game. All assets should maintain a consistent anime aesthetic with soft, hand-painted appearances and vibrant but harmonious colors.

## Art Style Guidelines

### General Specifications
- **Style**: 2D anime/manga inspired, hand-painted appearance
- **Color Palette**: Soft, saturated colors with warm lighting
- **Shading**: Subtle gradients, avoid harsh shadows
- **Line Art**: Minimal black outlines, prefer color-based definition
- **Lighting**: Warm, diffused lighting effects
- **Transparency**: Use alpha channels where specified
- **Seamless Tiling**: Base textures must tile seamlessly

### Color Specifications
- **Grass**: Vibrant greens (#4CAF50 to #8BC34A range)
- **Dirt/Soil**: Rich browns (#8D6E63 to #A1887F range)
- **Water**: Clear blues (#2196F3 to #03DAC6 range)
- **Rock**: Gray-browns (#757575 to #8D6E63 range)
- **Sand**: Light beiges (#FFF8E1 to #FFECB3 range)
- **Snow**: Pure whites (#FAFAFA to #F5F5F5 range)

## Required Assets

### 1. Base Terrain Textures (512x512px)

#### Grass Base Terrain
**Filename**: `grass_base.png`
**Size**: 512x512 pixels
**Format**: PNG with alpha channel
**Prompt**:
```
2D anime style top-down grass terrain texture, vibrant green color (#4CAF50), soft hand-drawn appearance with gentle brush strokes, seamless tileable pattern, pastoral anime aesthetic, no harsh edges, dreamy warm lighting, subtle color variations, hand-painted texture style
```

#### Dirt/Soil Base Terrain
**Filename**: `dirt_base.png`
**Size**: 512x512 pixels
**Format**: PNG with alpha channel
**Prompt**:
```
2D anime style top-down soil terrain texture, rich brown earth color (#8D6E63), soft organic patterns with gentle brush strokes, hand-painted appearance, seamless tileable pattern, warm earth tones with subtle highlights and shadows, natural soil texture
```

#### Sand Base Terrain
**Filename**: `sand_base.png`
**Size**: 512x512 pixels
**Format**: PNG with alpha channel
**Prompt**:
```
2D anime style top-down sand terrain texture, light beige color (#FFECB3), soft granular appearance with gentle ripple patterns, hand-painted aesthetic, seamless tileable, warm desert tones, subtle wind-blown texture patterns
```

#### Rock Base Terrain
**Filename**: `rock_base.png`
**Size**: 512x512 pixels
**Format**: PNG with alpha channel
**Prompt**:
```
2D anime style top-down rocky terrain texture, gray-brown stone color (#757575), natural rock formations with soft shadows between stones, hand-painted appearance, seamless tileable pattern, organic stone shapes with moss accents
```

#### Water Base Terrain
**Filename**: `water_base.png`
**Size**: 512x512 pixels
**Format**: PNG with alpha channel
**Prompt**:
```
2D anime style top-down water surface texture, clear blue water (#2196F3) with gentle ripples, soft reflective highlights, peaceful lake aesthetic, seamless tileable pattern, translucent appearance with depth suggestion, anime water shader style
```

#### Snow Base Terrain
**Filename**: `snow_base.png`
**Size**: 512x512 pixels
**Format**: PNG with alpha channel
**Prompt**:
```
2D anime style top-down snow terrain texture, pure white color (#FAFAFA) with subtle blue shadows, soft powdery appearance, hand-painted aesthetic, seamless tileable pattern, gentle undulating snow drifts, winter anime landscape style
```

### 2. Terrain Detail Overlays (256x256px)

#### Grass Flowers Overlay
**Filename**: `grass_flowers.png`
**Size**: 256x256 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style small wildflowers scattered overlay for grass terrain, tiny colorful flowers (pink, yellow, white), hand-painted style, transparent background, delicate petals, pastoral anime aesthetic, suitable for tiling over grass base
```

#### Rock Pebbles Overlay
**Filename**: `rock_pebbles.png`
**Size**: 256x256 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style small stones and pebbles overlay, various sizes of gray-brown pebbles, soft shadows, hand-painted texture, transparent background, natural scattered placement, suitable for rock terrain enhancement
```

#### Sand Dunes Overlay
**Filename**: `sand_dunes.png`
**Size**: 256x256 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style sand ripple patterns overlay, wind-carved dune ridges, light beige color variations, soft gradients, transparent background, natural wave-like patterns, desert anime aesthetic
```

#### Dirt Patches Overlay
**Filename**: `dirt_patches.png`
**Size**: 256x256 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style darker soil patches overlay, rich brown color variations, organic irregular shapes, soft edges, transparent background, natural earth pattern variations, hand-painted style
```

### 3. Natural Features

#### Trees

**Small Oak Tree**
**Filename**: `tree_oak_small.png`
**Size**: 64x80 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style oak tree top-down view, lush green foliage (#4CAF50), brown trunk visible from above, soft hand-drawn aesthetic, pastoral game art style, gentle drop shadow, small size suitable for game grid, transparent background
```

**Large Oak Tree**
**Filename**: `tree_oak_large.png`
**Size**: 96x120 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style large oak tree top-down view, dense green foliage with darker green shadows, thick brown trunk, hand-painted appearance, majestic tree aesthetic, soft shadows, transparent background, suitable for landmark placement
```

**Small Pine Tree**
**Filename**: `tree_pine_small.png`
**Size**: 48x96 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style pine tree top-down view, dark green needle foliage (#2E7D32), conical triangular shape, soft hand-painted appearance, forest game aesthetic, natural shadows, compact vertical design, transparent background
```

**Large Pine Tree**
**Filename**: `tree_pine_large.png`
**Size**: 72x144 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style large pine tree top-down view, layered dark green needle branches, tall conical shape, detailed branch structure, forest giant aesthetic, soft shadows, transparent background, suitable for forest areas
```

#### Bushes and Vegetation

**Green Bush**
**Filename**: `bush_green.png`
**Size**: 32x24 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style decorative green bush top-down view, round fluffy foliage, bright green color (#66BB6A), soft hand-painted appearance, gentle shadows, small decorative element, transparent background
```

**Flowering Bush**
**Filename**: `bush_flowering.png`
**Size**: 32x24 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style flowering bush top-down view, green foliage with small colorful flowers (pink, white, yellow), soft rounded shape, hand-painted aesthetic, cheerful garden element, transparent background
```

#### Rock Formations

**Small Decorative Rock**
**Filename**: `rock_small.png`
**Size**: 24x24 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style small decorative rock top-down view, gray-brown color (#757575), smooth rounded shape, soft shadow underneath, hand-painted texture, simple natural element, transparent background
```

**Medium Rock Formation**
**Filename**: `rock_medium.png`
**Size**: 48x36 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style medium rock formation top-down view, cluster of gray-brown stones, natural grouping, soft shadows between rocks, hand-painted appearance, suitable for terrain decoration, transparent background
```

**Large Rock Outcropping**
**Filename**: `rock_large.png`
**Size**: 72x54 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style large rock outcropping top-down view, impressive stone formation, weathered gray-brown rocks with moss accents, dramatic shadows, natural landmark appearance, hand-painted style, transparent background
```

### 4. Water Features

#### River Segments

**Horizontal River**
**Filename**: `river_horizontal.png`
**Size**: 200x64 pixels (tileable horizontally)
**Format**: PNG with transparency
**Prompt**:
```
2D anime style horizontal river segment top-down view, flowing blue water (#2196F3) with white foam edges, gentle current patterns, soft hand-painted appearance, seamless horizontal tiling, natural water flow direction
```

**Vertical River**
**Filename**: `river_vertical.png`
**Size**: 64x200 pixels (tileable vertically)
**Format**: PNG with transparency
**Prompt**:
```
2D anime style vertical river segment top-down view, flowing blue water with white foam banks, gentle ripples, soft hand-painted appearance, seamless vertical tiling, natural downward flow suggestion
```

**River Corner Top-Left**
**Filename**: `river_corner_tl.png`
**Size**: 64x64 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style river corner piece top-down view, blue water turning from top to left direction, smooth curved flow, white foam on outer bank, soft hand-painted appearance, connects river segments naturally
```

**River Corner Top-Right**
**Filename**: `river_corner_tr.png`
**Size**: 64x64 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style river corner piece top-down view, blue water turning from top to right direction, smooth curved flow, white foam on outer bank, natural water current appearance, hand-painted style
```

**River Corner Bottom-Left**
**Filename**: `river_corner_bl.png`
**Size**: 64x64 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style river corner piece top-down view, blue water turning from bottom to left direction, gentle curved flow, foamy outer edge, soft hand-painted appearance, natural river bend
```

**River Corner Bottom-Right**
**Filename**: `river_corner_br.png`
**Size**: 64x64 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style river corner piece top-down view, blue water turning from bottom to right direction, smooth water curve, white foam on banks, hand-painted river aesthetic, natural flow pattern
```

#### Lakes

**Small Lake**
**Filename**: `lake_small.png`
**Size**: 128x128 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style small circular lake top-down view, calm blue water surface (#42A5F5) with gentle ripples, soft shoreline, peaceful aesthetic, clear water with depth suggestion, hand-painted style, transparent background around water
```

**Large Lake**
**Filename**: `lake_large.png`
**Size**: 256x192 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style large irregular lake top-down view, calm blue water with natural shoreline, gentle surface ripples, deeper blue center suggesting depth, peaceful mountain lake aesthetic, soft edges, transparent background
```

### 5. Path and Road System

#### Dirt Paths

**Dirt Path Straight**
**Filename**: `path_dirt_straight.png`
**Size**: 50x50 pixels (aligned with game grid)
**Format**: PNG with transparency
**Prompt**:
```
2D anime style dirt path top-down view, worn brown earth trail, soft edges blending with grass, hand-painted appearance, fits 50x50 game grid exactly, natural walking path aesthetic, subtle wheel ruts
```

**Dirt Path Corner**
**Filename**: `path_dirt_corner.png`
**Size**: 50x50 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style dirt path corner piece top-down view, curved brown earth trail turning 90 degrees, smooth curve with worn edges, hand-painted style, fits game grid, natural path intersection
```

#### Stone Paths

**Stone Path Straight**
**Filename**: `path_stone_straight.png`
**Size**: 50x50 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style stone path top-down view, fitted stone blocks in light gray (#BDBDBD), mortar between stones, hand-painted appearance, fits 50x50 game grid, medieval path aesthetic, weathered appearance
```

**Stone Path Corner**
**Filename**: `path_stone_corner.png`
**Size**: 50x50 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style stone path corner piece top-down view, fitted stone blocks turning 90 degrees, smooth curve with proper stone fitting, hand-painted style, weathered medieval path corner
```

### 6. Effects and Atmosphere

#### Shadow Effects

**Building Shadow Template**
**Filename**: `building_shadow.png`
**Size**: Variable (100x100 base template)
**Format**: PNG with transparency
**Prompt**:
```
2D anime style building shadow overlay, soft semi-transparent black shadow (#000000 at 30% opacity), organic shadow shape cast by building, soft edges with subtle blur, hand-painted shadow aesthetic
```

**Tree Shadow Template**
**Filename**: `tree_shadow.png`
**Size**: Variable (80x60 base template)
**Format**: PNG with transparency
**Prompt**:
```
2D anime style tree shadow overlay, soft organic shadow shape cast by tree foliage, semi-transparent dark green (#1B5E20 at 40% opacity), natural irregular shadow pattern, soft edges
```

#### Ambient Lighting

**Ambient Light Overlay**
**Filename**: `ambient_light.png`
**Size**: 512x512 pixels
**Format**: PNG with transparency
**Prompt**:
```
2D anime style ambient lighting overlay, soft warm golden light (#FFF9C4 at 20% opacity), gentle radial gradient from center, dreamy lighting effect, hand-painted glow aesthetic, suitable for layering over terrain
```

## File Organization Structure

```
assets/images/terrain/
├── base/
│   ├── grass_base.png
│   ├── dirt_base.png
│   ├── sand_base.png
│   ├── rock_base.png
│   ├── water_base.png
│   └── snow_base.png
├── details/
│   ├── grass_flowers.png
│   ├── rock_pebbles.png
│   ├── sand_dunes.png
│   └── dirt_patches.png
├── features/
│   ├── trees/
│   │   ├── tree_oak_small.png
│   │   ├── tree_oak_large.png
│   │   ├── tree_pine_small.png
│   │   └── tree_pine_large.png
│   ├── bushes/
│   │   ├── bush_green.png
│   │   └── bush_flowering.png
│   ├── rocks/
│   │   ├── rock_small.png
│   │   ├── rock_medium.png
│   │   └── rock_large.png
│   └── water/
│       ├── river_horizontal.png
│       ├── river_vertical.png
│       ├── river_corner_tl.png
│       ├── river_corner_tr.png
│       ├── river_corner_bl.png
│       ├── river_corner_br.png
│       ├── lake_small.png
│       └── lake_large.png
├── paths/
│   ├── dirt/
│   │   ├── path_dirt_straight.png
│   │   └── path_dirt_corner.png
│   └── stone/
│       ├── path_stone_straight.png
│       └── path_stone_corner.png
└── effects/
    ├── shadows/
    │   ├── building_shadow.png
    │   └── tree_shadow.png
    └── lighting/
        └── ambient_light.png
```

## Technical Specifications

### Performance Considerations
- All base textures must be power-of-2 dimensions for optimal GPU performance
- Use texture atlasing where possible to reduce draw calls
- Implement LOD (Level of Detail) for distant terrain elements
- Consider texture compression for mobile deployment

### Animation Requirements
- Water textures should support 2-4 frame animations
- Ambient lighting can use subtle opacity animations
- Tree and bush assets should support gentle swaying animations

### Integration Notes
- All assets must work with Flame engine's sprite system
- Transparency channels are crucial for proper layering
- Assets should maintain visual consistency with existing building sprites
- Color palette should complement the space theme while adding earthly contrast

## Quality Assurance Checklist

### Before Final Export
- [ ] All textures tile seamlessly (base textures)
- [ ] Transparency channels are properly configured
- [ ] Colors match specified hex values
- [ ] File sizes are optimized for game performance
- [ ] Assets maintain consistent anime art style
- [ ] Shadows and lighting appear natural
- [ ] All required sizes are exact per specifications
- [ ] PNG format with appropriate bit depth
