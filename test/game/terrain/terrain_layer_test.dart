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
    test('returns treePineSmall path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.treePineSmall),
        TerrainAssets.treePineSmall,
      );
    });
    test('returns treePineLarge path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.treePineLarge),
        TerrainAssets.treePineLarge,
      );
    });
    test('returns bushGreen path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.bushGreen),
        TerrainAssets.bushGreen,
      );
    });
    test('returns bushFlowering path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.bushFlowering),
        TerrainAssets.bushFlowering,
      );
    });
    test('returns rockSmall path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.rockSmall),
        TerrainAssets.rockSmall,
      );
    });
    test('returns rockMedium path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.rockMedium),
        TerrainAssets.rockMedium,
      );
    });
    test('returns rockLarge path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.rockLarge),
        TerrainAssets.rockLarge,
      );
    });
    test('returns riverHorizontal path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.riverHorizontal),
        TerrainAssets.riverHorizontal,
      );
    });
    test('returns riverVertical path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.riverVertical),
        TerrainAssets.riverVertical,
      );
    });
    test('returns riverCornerTL path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.riverCornerTL),
        TerrainAssets.riverCornerTL,
      );
    });
    test('returns riverCornerTR path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.riverCornerTR),
        TerrainAssets.riverCornerTR,
      );
    });
    test('returns riverCornerBL path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.riverCornerBL),
        TerrainAssets.riverCornerBL,
      );
    });
    test('returns riverCornerBR path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.riverCornerBR),
        TerrainAssets.riverCornerBR,
      );
    });
    test('returns lakeSmall path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.lakeSmall),
        TerrainAssets.lakeSmall,
      );
    });
    test('returns lakeLarge path', () {
      expect(
        layer.getFeatureAssetPath(FeatureType.lakeLarge),
        TerrainAssets.lakeLarge,
      );
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
        TerrainLayer.listsEqual(
          [FeatureType.treeOakSmall],
          [FeatureType.treeOakSmall],
        ),
        isTrue,
      );
    });
    test('returns false when elements differ', () {
      expect(
        TerrainLayer.listsEqual(
          [FeatureType.treeOakSmall],
          [FeatureType.treeOakLarge],
        ),
        isFalse,
      );
    });
    test('returns false when lengths differ', () {
      expect(TerrainLayer.listsEqual([FeatureType.treeOakSmall], []), isFalse);
    });
    test('returns true for two empty lists', () {
      expect(TerrainLayer.listsEqual([], []), isTrue);
    });
    test('returns true for identical multi-element lists', () {
      expect(
        TerrainLayer.listsEqual(
          [FeatureType.treeOakSmall, FeatureType.rockSmall],
          [FeatureType.treeOakSmall, FeatureType.rockSmall],
        ),
        isTrue,
      );
    });
    test('returns false when only order differs', () {
      expect(
        TerrainLayer.listsEqual(
          [FeatureType.treeOakSmall, FeatureType.rockSmall],
          [FeatureType.rockSmall, FeatureType.treeOakSmall],
        ),
        isFalse,
      );
    });
  });
}
