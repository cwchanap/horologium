import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/terrain/parallax_terrain_layer.dart';
import 'package:horologium/game/terrain/terrain_biome.dart';
import 'package:horologium/game/terrain/terrain_depth_manager.dart';

void main() {
  late ParallaxTerrainLayer layer;

  setUp(() {
    layer = ParallaxTerrainLayer(
      depth: TerrainDepth.nearBackground,
      terrainData: const <String, TerrainCell>{},
      gridSize: 4,
      cellWidth: 50,
      cellHeight: 50,
    );
  });

  group('ParallaxTerrainLayer.getFeatureSize', () {
    test('large oak and pine trees: 60×75', () {
      expect(layer.getFeatureSize(FeatureType.treeOakLarge), Vector2(60, 75));
      expect(layer.getFeatureSize(FeatureType.treePineLarge), Vector2(60, 75));
    });
    test('small oak and pine trees: 40×50', () {
      expect(layer.getFeatureSize(FeatureType.treeOakSmall), Vector2(40, 50));
      expect(layer.getFeatureSize(FeatureType.treePineSmall), Vector2(40, 50));
    });
    test('large rock: 50×40', () {
      expect(layer.getFeatureSize(FeatureType.rockLarge), Vector2(50, 40));
    });
    test('medium rock: 30×25', () {
      expect(layer.getFeatureSize(FeatureType.rockMedium), Vector2(30, 25));
    });
    test('small rock: 15×12.5', () {
      expect(layer.getFeatureSize(FeatureType.rockSmall), Vector2(15, 12.5));
    });
    test('bushes: 20×15', () {
      expect(layer.getFeatureSize(FeatureType.bushGreen), Vector2(20, 15));
      expect(layer.getFeatureSize(FeatureType.bushFlowering), Vector2(20, 15));
    });
    test('lakeSmall: 100×100', () {
      expect(layer.getFeatureSize(FeatureType.lakeSmall), Vector2(100, 100));
    });
    test('lakeLarge: 150×125', () {
      expect(layer.getFeatureSize(FeatureType.lakeLarge), Vector2(150, 125));
    });
    test('default (river features): 50×50', () {
      expect(
        layer.getFeatureSize(FeatureType.riverHorizontal),
        Vector2(50, 50),
      );
      expect(layer.getFeatureSize(FeatureType.riverVertical), Vector2(50, 50));
    });
  });

  group('ParallaxTerrainLayer.getFeatureAnchorOffset', () {
    test('treeOakLarge returns non-zero Y offset', () {
      final featureSize = Vector2(60, 75);
      final offset = layer.getFeatureAnchorOffset(
        FeatureType.treeOakLarge,
        featureSize,
      );
      expect(offset.x, 0.0);
      expect(offset.y, closeTo(75 * 0.06, 0.001));
    });
    test('treePineLarge returns non-zero Y offset', () {
      final featureSize = Vector2(60, 75);
      final offset = layer.getFeatureAnchorOffset(
        FeatureType.treePineLarge,
        featureSize,
      );
      expect(offset.x, 0.0);
      expect(offset.y, closeTo(75 * 0.06, 0.001));
    });
    test('small tree returns zero vector', () {
      expect(
        layer.getFeatureAnchorOffset(FeatureType.treeOakSmall, Vector2(40, 50)),
        Vector2.zero(),
      );
    });
    test('rock returns zero vector', () {
      expect(
        layer.getFeatureAnchorOffset(FeatureType.rockSmall, Vector2(15, 12.5)),
        Vector2.zero(),
      );
    });
    test('bush returns zero vector', () {
      expect(
        layer.getFeatureAnchorOffset(FeatureType.bushGreen, Vector2(20, 15)),
        Vector2.zero(),
      );
    });
  });

  group('ParallaxTerrainLayer.getFeaturePosition', () {
    test('returns position within the cell interior band', () {
      const cellRect = Rect.fromLTWH(50, 100, 50, 50);
      final pos = layer.getFeaturePosition(cellRect, FeatureType.treeOakSmall);
      expect(pos.x, greaterThanOrEqualTo(cellRect.left + cellRect.width * 0.1));
      expect(pos.x, lessThan(cellRect.right));
      expect(pos.y, greaterThanOrEqualTo(cellRect.top + cellRect.height * 0.1));
      expect(pos.y, lessThan(cellRect.bottom));
    });
    test('is deterministic for the same inputs', () {
      const cellRect = Rect.fromLTWH(0, 0, 50, 50);
      final p1 = layer.getFeaturePosition(cellRect, FeatureType.bushGreen);
      final p2 = layer.getFeaturePosition(cellRect, FeatureType.bushGreen);
      expect(p1.x, p2.x);
      expect(p1.y, p2.y);
    });
    test('produces varied positions across multiple cells', () {
      final positions = <String>{};
      for (final rect in [
        const Rect.fromLTWH(0, 0, 50, 50),
        const Rect.fromLTWH(50, 0, 50, 50),
        const Rect.fromLTWH(100, 0, 50, 50),
        const Rect.fromLTWH(150, 0, 50, 50),
      ]) {
        final pos = layer.getFeaturePosition(rect, FeatureType.rockSmall);
        positions.add(
          '${pos.x.toStringAsFixed(4)},${pos.y.toStringAsFixed(4)}',
        );
      }
      expect(positions.length, greaterThan(1));
    });
  });

  group('ParallaxTerrainLayer.getLargeFeaturePosition', () {
    test('base Y is near cell bottom minus feature height', () {
      const cellRect = Rect.fromLTWH(0, 0, 50, 50);
      final featureSize = Vector2(60, 75);
      final pos = layer.getLargeFeaturePosition(
        cellRect,
        FeatureType.treeOakLarge,
        featureSize,
      );
      // baseY = cellRect.bottom - featureSize.y = 50 - 75 = -25
      // yOffset = -fy * cellRect.height * 0.03, fy ∈ [0,1) → yOffset ∈ [0, -1.5)
      // pos.y = baseY + yOffset ∈ [-26.5, -25.0]
      expect(pos.y, greaterThanOrEqualTo(-26.5));
      expect(pos.y, lessThanOrEqualTo(-25.0));
    });
    test('is deterministic for same inputs', () {
      const cellRect = Rect.fromLTWH(100, 100, 50, 50);
      final featureSize = Vector2(60, 75);
      final p1 = layer.getLargeFeaturePosition(
        cellRect,
        FeatureType.treeOakLarge,
        featureSize,
      );
      final p2 = layer.getLargeFeaturePosition(
        cellRect,
        FeatureType.treeOakLarge,
        featureSize,
      );
      expect(p1.x, p2.x);
      expect(p1.y, p2.y);
    });
  });
}
