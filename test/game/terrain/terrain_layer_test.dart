import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/terrain/terrain_assets.dart';
import 'package:horologium/game/terrain/terrain_biome.dart';
import 'package:horologium/game/terrain/terrain_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TerrainLayer layer;

  setUp(() {
    layer = TerrainLayer(terrainType: TerrainType.grass);
  });

  group('TerrainAssets.getBaseAssetPath', () {
    test('grass returns grassBase', () {
      expect(
        TerrainAssets.getBaseAssetPath(TerrainType.grass),
        TerrainAssets.grassBase,
      );
    });
    test('dirt returns dirtBase', () {
      expect(
        TerrainAssets.getBaseAssetPath(TerrainType.dirt),
        TerrainAssets.dirtBase,
      );
    });
    test('sand returns sandBase', () {
      expect(
        TerrainAssets.getBaseAssetPath(TerrainType.sand),
        TerrainAssets.sandBase,
      );
    });
    test('rock returns rockBase', () {
      expect(
        TerrainAssets.getBaseAssetPath(TerrainType.rock),
        TerrainAssets.rockBase,
      );
    });
    test('snow returns snowBase', () {
      expect(
        TerrainAssets.getBaseAssetPath(TerrainType.snow),
        TerrainAssets.snowBase,
      );
    });
    test('water returns null', () {
      expect(TerrainAssets.getBaseAssetPath(TerrainType.water), isNull);
    });
  });

  group('TerrainAssets.getFeatureAssetPath', () {
    test('treeOakSmall', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.treeOakSmall),
        TerrainAssets.treeOakSmall,
      );
    });
    test('treeOakLarge', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.treeOakLarge),
        TerrainAssets.treeOakLarge,
      );
    });
    test('treePineSmall', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.treePineSmall),
        TerrainAssets.treePineSmall,
      );
    });
    test('treePineLarge', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.treePineLarge),
        TerrainAssets.treePineLarge,
      );
    });
    test('bushGreen', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.bushGreen),
        TerrainAssets.bushGreen,
      );
    });
    test('bushFlowering', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.bushFlowering),
        TerrainAssets.bushFlowering,
      );
    });
    test('rockSmall', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.rockSmall),
        TerrainAssets.rockSmall,
      );
    });
    test('rockMedium', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.rockMedium),
        TerrainAssets.rockMedium,
      );
    });
    test('rockLarge', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.rockLarge),
        TerrainAssets.rockLarge,
      );
    });
    test('riverHorizontal', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.riverHorizontal),
        TerrainAssets.riverHorizontal,
      );
    });
    test('riverVertical', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.riverVertical),
        TerrainAssets.riverVertical,
      );
    });
    test('riverCornerTL', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.riverCornerTL),
        TerrainAssets.riverCornerTL,
      );
    });
    test('riverCornerTR', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.riverCornerTR),
        TerrainAssets.riverCornerTR,
      );
    });
    test('riverCornerBL', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.riverCornerBL),
        TerrainAssets.riverCornerBL,
      );
    });
    test('riverCornerBR', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.riverCornerBR),
        TerrainAssets.riverCornerBR,
      );
    });
    test('lakeSmall', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.lakeSmall),
        TerrainAssets.lakeSmall,
      );
    });
    test('lakeLarge', () {
      expect(
        TerrainAssets.getFeatureAssetPath(FeatureType.lakeLarge),
        TerrainAssets.lakeLarge,
      );
    });
  });

  group('TerrainAssets.allAssets', () {
    test('contains every non-null path from getBaseAssetPath', () {
      final allAssetsSet = TerrainAssets.allAssets.toSet();
      for (final type in TerrainType.values) {
        final path = TerrainAssets.getBaseAssetPath(type);
        if (path != null) {
          expect(
            allAssetsSet,
            contains(path),
            reason: '$type resolves to "$path" but is missing from allAssets',
          );
        }
      }
    });

    test('contains every non-null path from getFeatureAssetPath', () {
      final allAssetsSet = TerrainAssets.allAssets.toSet();
      for (final feature in FeatureType.values) {
        final path = TerrainAssets.getFeatureAssetPath(feature);
        if (path != null) {
          expect(
            allAssetsSet,
            contains(path),
            reason:
                '$feature resolves to "$path" but is missing from allAssets',
          );
        }
      }
    });

    test('has no duplicate entries', () {
      final allAssets = TerrainAssets.allAssets;
      expect(
        allAssets.toSet().length,
        allAssets.length,
        reason: 'allAssets contains duplicate paths',
      );
    });
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

  group('TerrainLayer lifecycle and rendering', () {
    test('render draws a fallback rectangle when no base sprite is loaded', () {
      layer.size = Vector2(12, 8);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      layer.render(canvas);
      final picture = recorder.endRecording();

      expect(picture.approximateBytesUsed, greaterThan(0));
      picture.dispose();
    });

    test('feature sizing scales oversized sprites to fit the layer', () async {
      layer.size = Vector2(50, 50);
      final sprite = Sprite(await _createImage(width: 100, height: 50));

      expect(layer.getFeatureSizeForTest(sprite), Vector2(40, 20));
    });

    test('feature sizing keeps sprites that already fit', () async {
      layer.size = Vector2(50, 50);
      final sprite = Sprite(await _createImage(width: 20, height: 10));

      expect(layer.getFeatureSizeForTest(sprite), Vector2(20, 10));
    });

    test(
      'feature positioning stays in the central band of the layer',
      () async {
        layer.size = Vector2(100, 80);
        final sprite = Sprite(await _createImage(width: 10, height: 10));

        final position = layer.getFeaturePositionForTest(sprite);

        expect(position.x, greaterThanOrEqualTo(20));
        expect(position.x, lessThanOrEqualTo(80));
        expect(position.y, greaterThanOrEqualTo(16));
        expect(position.y, lessThanOrEqualTo(64));
      },
    );

    test('render draws injected feature sprites', () async {
      layer.size = Vector2(50, 50);
      layer.addFeatureSpriteForTest(
        Sprite(await _createImage(width: 10, height: 10)),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      layer.render(canvas);
      final picture = recorder.endRecording();

      expect(picture.approximateBytesUsed, greaterThan(0));
      picture.dispose();
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

  group('TerrainLayer onLoad', () {
    test('loads sprites from image cache', () async {
      final game = FlameGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
      final testImage = await _createImage(width: 64, height: 64);
      game.images.add(TerrainAssets.grassBase, testImage);
      game.images.add(TerrainAssets.treeOakSmall, testImage);

      final loadedLayer = TerrainLayer(
        terrainType: TerrainType.grass,
        features: [FeatureType.treeOakSmall],
      );
      await game.add(loadedLayer);
      await game.ready();

      loadedLayer.size = Vector2(64, 64);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      loadedLayer.render(canvas);
      final picture = recorder.endRecording();
      expect(picture.approximateBytesUsed, greaterThan(0));
      picture.dispose();
    });

    test('handles missing assets gracefully', () async {
      final game = FlameGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      final loadedLayer = TerrainLayer(
        terrainType: TerrainType.grass,
        features: [FeatureType.treeOakSmall],
      );
      await game.add(loadedLayer);
      await game.ready();

      loadedLayer.size = Vector2(64, 64);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      loadedLayer.render(canvas);
      final picture = recorder.endRecording();
      expect(picture.approximateBytesUsed, greaterThan(0));
      picture.dispose();
    });

    test('skips loading for terrain types with null asset path', () async {
      final game = FlameGame();
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      final loadedLayer = TerrainLayer(terrainType: TerrainType.water);
      await game.add(loadedLayer);
      await game.ready();

      loadedLayer.size = Vector2(64, 64);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      loadedLayer.render(canvas);
      final picture = recorder.endRecording();
      expect(picture.approximateBytesUsed, greaterThan(0));
      picture.dispose();
    });
  });
}

Future<ui.Image> _createImage({required int width, required int height}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );
  return recorder.endRecording().toImage(width, height);
}
