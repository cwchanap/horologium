import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import 'terrain_assets.dart';
import 'terrain_biome.dart';

class TerrainLayer extends PositionComponent with HasGameReference {
  final TerrainType terrainType;
  final List<FeatureType> features;
  final double opacity;
  final int renderOrder;
  
  Sprite? _baseSprite;
  final List<Sprite> _featureSprites = [];
  final Map<String, Sprite> _spriteCache = {};

  TerrainLayer({
    required this.terrainType,
    this.features = const [],
    this.opacity = 1.0,
    this.renderOrder = 0,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprites();
  }

  Future<void> _loadSprites() async {
    // Load base terrain sprite
    final baseAssetPath = _getBaseAssetPath(terrainType);
    if (baseAssetPath != null) {
      final image = await game.images.load(baseAssetPath);
      _baseSprite = Sprite(image);
    }

    // Load feature sprites
    _featureSprites.clear();
    for (final feature in features) {
      final featureAssetPath = _getFeatureAssetPath(feature);
      if (featureAssetPath != null) {
        if (!_spriteCache.containsKey(featureAssetPath)) {
          final image = await game.images.load(featureAssetPath);
          _spriteCache[featureAssetPath] = Sprite(image);
        }
        _featureSprites.add(_spriteCache[featureAssetPath]!);
      }
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);

    // Render base terrain sprite
    if (_baseSprite != null) {
      _baseSprite!.render(
        canvas,
        position: Vector2.zero(),
        size: size,
        overridePaint: paint,
      );
    } else {
      // Fallback to colored rectangle if no sprite
      final fallbackPaint = Paint()
        ..color = _getFallbackColor(terrainType).withValues(alpha: opacity);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), fallbackPaint);
    }

    // Render features on top
    for (final featureSprite in _featureSprites) {
      // Position features randomly within the cell but consistently
      final featurePosition = _getFeaturePosition(featureSprite);
      final featureSize = _getFeatureSize(featureSprite);
      
      featureSprite.render(
        canvas,
        position: featurePosition,
        size: featureSize,
        overridePaint: paint,
      );
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

  Vector2 _getFeaturePosition(Sprite sprite) {
    // Position features within the cell bounds
    // Use deterministic positioning based on sprite properties
    final hash = sprite.hashCode;
    final x = (hash % 100) / 100.0 * (size.x * 0.6) + (size.x * 0.2);
    final y = ((hash ~/ 100) % 100) / 100.0 * (size.y * 0.6) + (size.y * 0.2);
    return Vector2(x, y);
  }

  Vector2 _getFeatureSize(Sprite sprite) {
    // Return appropriate size based on feature type
    // This should match the original asset dimensions
    final originalSize = sprite.originalSize;
    
    // Scale features to fit within cell if they're too large
    final maxSize = size * 0.8;
    if (originalSize.x > maxSize.x || originalSize.y > maxSize.y) {
      final scale = (maxSize.x / originalSize.x).clamp(0.1, 1.0);
      return originalSize * scale;
    }
    
    return originalSize;
  }

  /// Update terrain type and reload sprites
  Future<void> updateTerrain(TerrainType newType, List<FeatureType> newFeatures) async {
    if (terrainType != newType || !_listsEqual(features, newFeatures)) {
      await _loadSprites();
    }
  }

  bool _listsEqual(List<FeatureType> a, List<FeatureType> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
