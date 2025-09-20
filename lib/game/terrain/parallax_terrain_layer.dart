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
  
  // Toggle for debug overlays (magenta fill, borders, diagonals, markers)
  bool showDebug = false;
  // Toggle for parallax motion relative to camera
  bool enableParallax = false;
  
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
    
    // Optional parallax effect by adjusting position based on camera movement
    if (enableParallax) {
      final camera = game.camera;
      final cameraPosition = camera.viewfinder.position;
      // Calculate parallax offset (slower movement for background layers)
      position = (size / 2) + cameraPosition * (_parallaxSpeed - 1.0);
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
    if (showDebug) {
      // Background to verify layer visibility and bounds
      final bgPaint = Paint()
        ..color = const Color(0xFFAA33FF).withAlpha(80)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        bgPaint,
      );
      // Layer border for bounds
      final borderPaint = Paint()
        ..color = const Color(0xFFAA33FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        borderPaint,
      );

      // Diagonals across the layer to ensure visibility
      final diagPaint = Paint()
        ..color = const Color(0xFFAA33FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        const Offset(0, 0),
        Offset(size.x, size.y),
        diagPaint,
      );
      canvas.drawLine(
        Offset(size.x, 0),
        Offset(0, size.y),
        diagPaint,
      );
      // Debug: layer origin marker at local (0,0)
      final originPaint = Paint()..color = Colors.pink;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 6, 6), originPaint);
    }
    // (debug logging removed)
    
    if (showDebug) {
      // Debug markers to validate alignment vs parent
      final topLeftPaint = Paint()..color = Colors.pink;   // (0,0)
      final centerPaint = Paint()..color = Colors.blue;    // (size/2,size/2)
      canvas.drawRect(const Rect.fromLTWH(0, 0, 6, 6), topLeftPaint);
      canvas.drawRect(Rect.fromLTWH(size.x / 2 - 3, size.y / 2 - 3, 6, 6), centerPaint);
    }

    final config = TerrainDepthManager.getConfig(depth);
    
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
      }
    }
  }

  void _renderTerrainCell(
    Canvas canvas,
    int x,
    int y,
    TerrainCell terrainCell,
    TerrainDepthConfig config,
  ) {
    // Draw cell from local top-left (0,0)
    final offsetX = x * cellWidth;
    final offsetY = y * cellHeight;
    
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
