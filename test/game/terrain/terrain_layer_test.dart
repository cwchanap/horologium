import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/terrain/terrain_assets.dart';
import 'package:horologium/game/terrain/terrain_biome.dart';
import 'package:horologium/game/terrain/terrain_layer.dart';

void main() {
  late TerrainLayer layer;

  setUp(() {
    layer = TerrainLayer(terrainType: TerrainType.grass);
  });

  group('TerrainLayer.getBaseAssetPath', () {
    test('returns grass path for grass', () {
      expect(
        layer.getBaseAssetPath(TerrainType.grass),
        TerrainAssets.grassBase,
      );
    });
    test('returns dirt path for dirt', () {
      expect(layer.getBaseAssetPath(TerrainType.dirt), TerrainAssets.dirtBase);
    });
    test('returns sand path for sand', () {
      expect(layer.getBaseAssetPath(TerrainType.sand), TerrainAssets.sandBase);
    });
    test('returns rock path for rock', () {
      expect(layer.getBaseAssetPath(TerrainType.rock), TerrainAssets.rockBase);
    });
    test('returns snow path for snow', () {
      expect(layer.getBaseAssetPath(TerrainType.snow), TerrainAssets.snowBase);
    });
    test('returns null for water (asset unavailable)', () {
      expect(layer.getBaseAssetPath(TerrainType.water), isNull);
    });
  });

  group('TerrainLayer.getFeatureAssetPath', () {
    test('returns treeOakSmall path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.treeOakSmall),
        TerrainAssets.treeOakSmall,
      );
    });
    test('returns treeOakLarge path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.treeOakLarge),
        TerrainAssets.treeOakLarge,
      );
    });
    test('returns null for treePineSmall', () {
      expect(layer.getFeatureAssetPath(FeatureType.treePineSmall), isNull);
    });
    test('returns null for treePineLarge', () {
      expect(layer.getFeatureAssetPath(FeatureType.treePineLarge), isNull);
    });
    test('returns null for bushGreen', () {
      expect(layer.getFeatureAssetPath(FeatureType.bushGreen), isNull);
    });
    test('returns null for bushFlowering', () {
      expect(layer.getFeatureAssetPath(FeatureType.bushFlowering), isNull);
    });
    test('returns null for rockSmall', () {
      expect(layer.getFeatureAssetPath(FeatureType.rockSmall), isNull);
    });
    test('returns null for rockMedium', () {
      expect(layer.getFeatureAssetPath(FeatureType.rockMedium), isNull);
    });
    test('returns null for rockLarge', () {
      expect(layer.getFeatureAssetPath(FeatureType.rockLarge), isNull);
    });
    test('returns null for riverHorizontal', () {
      expect(layer.getFeatureAssetPath(FeatureType.riverHorizontal), isNull);
    });
    test('returns null for riverVertical', () {
      expect(layer.getFeatureAssetPath(FeatureType.riverVertical), isNull);
    });
    test('returns null for riverCornerTL', () {
      expect(layer.getFeatureAssetPath(FeatureType.riverCornerTL), isNull);
    });
    test('returns null for riverCornerTR', () {
      expect(layer.getFeatureAssetPath(FeatureType.riverCornerTR), isNull);
    });
    test('returns null for riverCornerBL', () {
      expect(layer.getFeatureAssetPath(FeatureType.riverCornerBL), isNull);
    });
    test('returns null for riverCornerBR', () {
      expect(layer.getFeatureAssetPath(FeatureType.riverCornerBR), isNull);
    });
    test('returns null for lakeSmall', () {
      expect(layer.getFeatureAssetPath(FeatureType.lakeSmall), isNull);
    });
    test('returns null for lakeLarge', () {
      expect(layer.getFeatureAssetPath(FeatureType.lakeLarge), isNull);
    });
  });

  group('TerrainLayer.getFallbackColor', () {
    test('grass returns 0xFF4CAF50', () {
      expect(
        layer.getFallbackColor(TerrainType.grass),
        const Color(0xFF4CAF50),
      );
    });
    test('dirt returns 0xFF8D6E63', () {
      expect(layer.getFallbackColor(TerrainType.dirt), const Color(0xFF8D6E63));
    });
    test('sand returns 0xFFFFECB3', () {
      expect(layer.getFallbackColor(TerrainType.sand), const Color(0xFFFFECB3));
    });
    test('rock returns 0xFF757575', () {
      expect(layer.getFallbackColor(TerrainType.rock), const Color(0xFF757575));
    });
    test('water returns 0xFF2196F3', () {
      expect(
        layer.getFallbackColor(TerrainType.water),
        const Color(0xFF2196F3),
      );
    });
    test('snow returns 0xFFFAFAFA', () {
      expect(layer.getFallbackColor(TerrainType.snow), const Color(0xFFFAFAFA));
    });
  });

  group('TerrainLayer.listsEqual', () {
    test('returns true for two identical single-element lists', () {
      expect(
        layer.listsEqual(
          [FeatureType.treeOakSmall],
          [FeatureType.treeOakSmall],
        ),
        isTrue,
      );
    });
    test('returns false when elements differ', () {
      expect(
        layer.listsEqual(
          [FeatureType.treeOakSmall],
          [FeatureType.treeOakLarge],
        ),
        isFalse,
      );
    });
    test('returns false when lengths differ', () {
      expect(layer.listsEqual([FeatureType.treeOakSmall], []), isFalse);
    });
    test('returns true for two empty lists', () {
      expect(layer.listsEqual([], []), isTrue);
    });
    test('returns true for identical multi-element lists', () {
      expect(
        layer.listsEqual(
          [FeatureType.treeOakSmall, FeatureType.rockSmall],
          [FeatureType.treeOakSmall, FeatureType.rockSmall],
        ),
        isTrue,
      );
    });
    test('returns false when only order differs', () {
      expect(
        layer.listsEqual(
          [FeatureType.treeOakSmall, FeatureType.rockSmall],
          [FeatureType.rockSmall, FeatureType.treeOakSmall],
        ),
        isFalse,
      );
    });
  });
}
