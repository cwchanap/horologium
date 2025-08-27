import 'dart:io';
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
        await _loadSpriteWithFallback(assetPath);
      }
    }

    // Load feature sprites
    for (final feature in config.allowedFeatureTypes) {
      final assetPath = _getFeatureAssetPath(feature);
      if (assetPath != null) {
        await _loadSpriteWithFallback(assetPath);
      }
    }
  }

  /// Safely loads a sprite with fallback handling for missing assets
  Future<void> _loadSpriteWithFallback(String assetPath) async {
    // Skip asset loading during Flutter tests to avoid exceptions
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    
    try {
      final image = await game.images.load(assetPath);
      _spriteCache[assetPath] = Sprite(image);
    } catch (e) {
      // Asset not available, silently continue with fallback colors
      // This is expected behavior when assets haven't been generated yet
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final config = TerrainDepthManager.getConfig(depth);
    
    // Render each terrain cell
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        final key = '$x,$y';
        final terrainCell = terrainData[key];
        
        if (terrainCell != null) {
          _renderTerrainCell(canvas, x, y, terrainCell, config);
        }
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
    final cellRect = Rect.fromLTWH(
      x * cellWidth,
      y * cellHeight,
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
        return const Color(0xFF4CAF50);
      case TerrainType.dirt:
        return const Color(0xFF8D6E63);
      case TerrainType.sand:
        return const Color(0xFFFFECB3);
      case TerrainType.rock:
        return const Color(0xFF757575);
      case TerrainType.water:
        return const Color(0xFF2196F3);
      case TerrainType.snow:
        return const Color(0xFFFAFAFA);
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
      case TerrainType.water:
        return TerrainAssets.waterBase;
      case TerrainType.snow:
        return TerrainAssets.snowBase;
    }
  }

  String? _getFeatureAssetPath(FeatureType feature) {
    switch (feature) {
      case FeatureType.treeOakSmall:
        return TerrainAssets.treeOakSmall;
      case FeatureType.treeOakLarge:
        return TerrainAssets.treeOakLarge;
      case FeatureType.treePineSmall:
        return TerrainAssets.treePineSmall;
      case FeatureType.treePineLarge:
        return TerrainAssets.treePineLarge;
      case FeatureType.bushGreen:
        return TerrainAssets.bushGreen;
      case FeatureType.bushFlowering:
        return TerrainAssets.bushFlowering;
      case FeatureType.rockSmall:
        return TerrainAssets.rockSmall;
      case FeatureType.rockMedium:
        return TerrainAssets.rockMedium;
      case FeatureType.rockLarge:
        return TerrainAssets.rockLarge;
      case FeatureType.riverHorizontal:
        return TerrainAssets.riverHorizontal;
      case FeatureType.riverVertical:
        return TerrainAssets.riverVertical;
      case FeatureType.riverCornerTL:
        return TerrainAssets.riverCornerTL;
      case FeatureType.riverCornerTR:
        return TerrainAssets.riverCornerTR;
      case FeatureType.riverCornerBL:
        return TerrainAssets.riverCornerBL;
      case FeatureType.riverCornerBR:
        return TerrainAssets.riverCornerBR;
      case FeatureType.lakeSmall:
        return TerrainAssets.lakeSmall;
      case FeatureType.lakeLarge:
        return TerrainAssets.lakeLarge;
    }
  }
}
