import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import 'terrain_assets.dart';
import 'terrain_biome.dart';
import 'terrain_depth_manager.dart';

class ParallaxTerrainLayer extends PositionComponent with HasGameReference {
  final TerrainDepth depth;
  final Map<String, TerrainCell> terrainData;
  final int gridSize;
  final double cellWidth;
  final double cellHeight;
  
  final Map<String, Sprite> _spriteCache = {};
  late double _parallaxSpeed;

  ParallaxTerrainLayer({
    required this.depth,
    required this.terrainData,
    required this.gridSize,
    required this.cellWidth,
    required this.cellHeight,
  }) {
    final config = TerrainDepthManager.getConfig(depth);
    _parallaxSpeed = config.parallaxSpeed;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprites();
    
    // Set the size to match the total terrain area
    size = Vector2(gridSize * cellWidth, gridSize * cellHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Apply parallax effect by adjusting position based on camera movement
    if (parent?.parent is CameraComponent) {
      final camera = parent!.parent! as CameraComponent;
      final cameraPosition = camera.viewfinder.position;
      
      // Calculate parallax offset (slower movement for background layers)
      final parallaxOffset = cameraPosition * (_parallaxSpeed - 1.0);
      position = parallaxOffset;
    }
  }

  Future<void> _loadSprites() async {
    // Load sprites for terrain types and features that appear on this depth
    final config = TerrainDepthManager.getConfig(depth);
    
    // Load terrain base sprites
    for (final terrainType in config.allowedTerrainTypes) {
      final assetPath = _getBaseAssetPath(terrainType);
      if (assetPath != null) {
        final sprite = await _loadSpriteWithFallback(assetPath);
        if (sprite != null) {
          _spriteCache[assetPath] = sprite;
        }
      }
    }

    // Load feature sprites
    for (final feature in config.allowedFeatureTypes) {
      final assetPath = _getFeatureAssetPath(feature);
      if (assetPath != null) {
        final sprite = await _loadSpriteWithFallback(assetPath);
        if (sprite != null) {
          _spriteCache[assetPath] = sprite;
        }
      }
    }
  }

  /// Safely loads a sprite with fallback handling for missing assets
  Future<Sprite?> _loadSpriteWithFallback(String path) async {
    try {
      // Simple try-catch approach - if asset exists, load it
      // If not, return null and we'll use fallback rendering
      return await Sprite.load(path);
    } catch (e) {
      // Asset doesn't exist or can't be loaded (common in tests)
      // Return null to use fallback rendering
      return null;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final config = TerrainDepthManager.getConfig(depth);
    
    var renderedCells = 0;
    var centerCellsRendered = 0;
    
    // Render each terrain cell that exists in our data
    for (final entry in terrainData.entries) {
      final key = entry.key;
      final terrainCell = entry.value;
      
      // Parse coordinates from key
      final coords = key.split(',');
      if (coords.length != 2) continue;
      
      final x = int.tryParse(coords[0]);
      final y = int.tryParse(coords[1]);
      
      if (x != null && y != null && x >= 0 && y >= 0 && x < gridSize && y < gridSize) {
        _renderTerrainCell(canvas, x, y, terrainCell, config);
        renderedCells++;
        
        // Count center area cells (around 25,25)
        if ((x >= 20 && x <= 30) && (y >= 20 && y <= 30)) {
          centerCellsRendered++;
        }
      }
    }
    
    // Debug rendering info (only once)
    if (depth == TerrainDepth.midBackground && renderedCells != _lastRenderedCount) {
      print('${depth.name}: rendered $renderedCells cells, data has ${terrainData.length} cells');
      print('Center area (20-30,20-30): $centerCellsRendered cells rendered');
      print('Layer size: $size, position: $position, anchor: $anchor');
      _lastRenderedCount = renderedCells;
    }
  }
  
  int _lastRenderedCount = -1;

  void _renderTerrainCell(
    Canvas canvas,
    int x,
    int y,
    TerrainCell terrainCell,
    TerrainDepthConfig config,
  ) {
    // Calculate position relative to the centered anchor
    // Since anchor is center, coordinates need to be offset by half the size
    final offsetX = x * cellWidth - (size.x / 2);
    final offsetY = y * cellHeight - (size.y / 2);
    
    final cellRect = Rect.fromLTWH(
      offsetX,
      offsetY,
      cellWidth,
      cellHeight,
    );

    // Render base terrain if this layer should show it
    if (config.allowedTerrainTypes.contains(terrainCell.baseType)) {
      _renderBaseTerrain(canvas, cellRect, terrainCell.baseType);
    }

    // Render features that belong to this depth layer
    for (final feature in terrainCell.features) {
      if (config.allowedFeatureTypes.contains(feature)) {
        _renderFeature(canvas, cellRect, feature);
      }
    }
  }

  void _renderBaseTerrain(Canvas canvas, Rect cellRect, TerrainType terrainType) {
    final assetPath = _getBaseAssetPath(terrainType);
    final sprite = assetPath != null ? _spriteCache[assetPath] : null;

    if (sprite != null) {
      sprite.render(
        canvas,
        position: cellRect.topLeft.toVector2(),
        size: cellRect.size.toVector2(),
      );
    } else {
      // Fallback to colored rectangle
      final paint = Paint()..color = _getFallbackColor(terrainType);
      canvas.drawRect(cellRect, paint);
    }
  }

  void _renderFeature(Canvas canvas, Rect cellRect, FeatureType feature) {
    final assetPath = _getFeatureAssetPath(feature);
    final sprite = assetPath != null ? _spriteCache[assetPath] : null;

    if (sprite != null) {
      // Position feature within the cell
      final featurePosition = _getFeaturePosition(cellRect, feature);
      final featureSize = _getFeatureSize(feature);

      sprite.render(
        canvas,
        position: featurePosition,
        size: featureSize,
      );
    }
  }

  Vector2 _getFeaturePosition(Rect cellRect, FeatureType feature) {
    // Position features within the cell bounds
    // Use deterministic positioning based on feature type
    final hash = feature.hashCode;
    final x = (hash % 100) / 100.0 * (cellRect.width * 0.6) + (cellRect.width * 0.2);
    final y = ((hash ~/ 100) % 100) / 100.0 * (cellRect.height * 0.6) + (cellRect.height * 0.2);
    return Vector2(cellRect.left + x, cellRect.top + y);
  }

  Vector2 _getFeatureSize(FeatureType feature) {
    // Return appropriate size based on feature type and depth
    switch (feature) {
      case FeatureType.treeOakLarge:
      case FeatureType.treePineLarge:
        return Vector2(cellWidth * 1.2, cellHeight * 1.5);
      case FeatureType.treeOakSmall:
      case FeatureType.treePineSmall:
        return Vector2(cellWidth * 0.8, cellHeight * 1.0);
      case FeatureType.rockLarge:
        return Vector2(cellWidth * 1.0, cellHeight * 0.8);
      case FeatureType.rockMedium:
        return Vector2(cellWidth * 0.6, cellHeight * 0.5);
      case FeatureType.rockSmall:
        return Vector2(cellWidth * 0.3, cellHeight * 0.25);
      case FeatureType.bushGreen:
      case FeatureType.bushFlowering:
        return Vector2(cellWidth * 0.4, cellHeight * 0.3);
      case FeatureType.lakeSmall:
        return Vector2(cellWidth * 2.0, cellHeight * 2.0);
      case FeatureType.lakeLarge:
        return Vector2(cellWidth * 3.0, cellHeight * 2.5);
      default:
        return Vector2(cellWidth, cellHeight);
    }
  }

  Color _getFallbackColor(TerrainType type) {
    switch (type) {
      case TerrainType.grass:
        return const Color(0xFF00FF00); // Bright green for debugging
      case TerrainType.dirt:
        return const Color(0xFFFF6600); // Bright orange for debugging
      case TerrainType.sand:
        return const Color(0xFFFFFF00); // Bright yellow for debugging
      case TerrainType.rock:
        return const Color(0xFF800080); // Bright purple for debugging
      case TerrainType.water:
        return const Color(0xFF0000FF); // Bright blue for debugging
      case TerrainType.snow:
        return const Color(0xFFFFFFFF); // Pure white for debugging
    }
  }

  String? _getBaseAssetPath(TerrainType type) {
    switch (type) {
      case TerrainType.grass:
        return TerrainAssets.grassBase;
      case TerrainType.dirt:
        return TerrainAssets.dirtBase;
      case TerrainType.sand:
        return TerrainAssets.sandBase;
      case TerrainType.rock:
        return TerrainAssets.rockBase;
      case TerrainType.snow:
        return TerrainAssets.snowBase;
      case TerrainType.water:
        // water_base.png not available - will use fallback color
        return null;
    }
  }

  String? _getFeatureAssetPath(FeatureType feature) {
    switch (feature) {
      case FeatureType.treeOakSmall:
        return TerrainAssets.treeOakSmall;
      case FeatureType.treeOakLarge:
        return TerrainAssets.treeOakLarge;
      // Other features not available yet - will use fallback rendering
      case FeatureType.treePineSmall:
      case FeatureType.treePineLarge:
      case FeatureType.bushGreen:
      case FeatureType.bushFlowering:
      case FeatureType.rockSmall:
      case FeatureType.rockMedium:
      case FeatureType.rockLarge:
      case FeatureType.riverHorizontal:
      case FeatureType.riverVertical:
      case FeatureType.riverCornerTL:
      case FeatureType.riverCornerTR:
      case FeatureType.riverCornerBL:
      case FeatureType.riverCornerBR:
      case FeatureType.lakeSmall:
      case FeatureType.lakeLarge:
        return null;
    }
  }
}
