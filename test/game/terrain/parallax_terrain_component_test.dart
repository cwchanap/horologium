import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/terrain/parallax_terrain_component.dart';
import 'package:horologium/game/terrain/parallax_terrain_layer.dart';
import 'package:horologium/game/terrain/terrain_biome.dart';
import 'package:horologium/game/terrain/terrain_depth_manager.dart';

void main() {
  group('ParallaxTerrainComponent', () {
    test('getTerrainAt and isBuildableAt reflect injected terrain state', () {
      final component = ParallaxTerrainComponent(gridSize: 4);

      component.replaceTerrainDataForTest(<String, TerrainCell>{
        '0,0': const TerrainCell(baseType: TerrainType.grass, elevation: 0.4),
        '1,0': const TerrainCell(baseType: TerrainType.water, elevation: 0.1),
        '2,0': const TerrainCell(baseType: TerrainType.grass, elevation: 0.95),
        '3,0': const TerrainCell(
          baseType: TerrainType.grass,
          elevation: 0.4,
          features: <FeatureType>[FeatureType.treeOakLarge],
        ),
      });

      expect(component.getTerrainAt(0, 0)?.baseType, TerrainType.grass);
      expect(component.isBuildableAt(0, 0), isTrue);
      expect(component.isBuildableAt(1, 0), isFalse);
      expect(component.isBuildableAt(2, 0), isFalse);
      expect(component.isBuildableAt(3, 0), isFalse);
      expect(component.getTerrainAt(9, 9), isNull);
      expect(component.isBuildableAt(9, 9), isTrue);
    });

    test(
      'getBiomeDistribution and getTerrainStats compute injected aggregates',
      () {
        final component = ParallaxTerrainComponent(gridSize: 4);

        component
          ..replaceTerrainDataForTest(<String, TerrainCell>{
            '0,0': const TerrainCell(
              baseType: TerrainType.grass,
              elevation: 0.3,
              moisture: 0.4,
              biome: BiomeType.grassland,
            ),
            '1,0': const TerrainCell(
              baseType: TerrainType.grass,
              elevation: 0.7,
              moisture: 0.8,
              biome: BiomeType.forest,
            ),
            '2,0': const TerrainCell(
              baseType: TerrainType.water,
              elevation: 0.1,
              moisture: 0.9,
              biome: BiomeType.wetlands,
            ),
          })
          ..replaceLayersForTest(<TerrainDepth, ParallaxTerrainLayer>{
            TerrainDepth.midBackground: _buildLayer(TerrainDepth.midBackground),
            TerrainDepth.foreground: _buildLayer(TerrainDepth.foreground),
          });

        expect(component.getBiomeDistribution(), <BiomeType, int>{
          BiomeType.grassland: 1,
          BiomeType.forest: 1,
          BiomeType.wetlands: 1,
        });

        final stats = component.getTerrainStats();

        expect(stats['totalCells'], 3);
        expect(stats['biomeDistribution'], <BiomeType, int>{
          BiomeType.grassland: 1,
          BiomeType.forest: 1,
          BiomeType.wetlands: 1,
        });
        expect(stats['parallaxLayers'], 2);
        expect(stats['averageElevation'], closeTo(0.3667, 0.0001));
        expect(stats['averageMoisture'], closeTo(0.7, 0.0001));
        expect(stats['waterPercentage'], closeTo(33.3333, 0.0001));
      },
    );

    test('layer and debug toggles propagate to injected layers', () {
      final farLayer = _buildLayer(TerrainDepth.farBackground);
      final foregroundLayer = _buildLayer(TerrainDepth.foreground);
      final component = ParallaxTerrainComponent(gridSize: 4)
        ..replaceLayersForTest(<TerrainDepth, ParallaxTerrainLayer>{
          TerrainDepth.farBackground: farLayer,
          TerrainDepth.foreground: foregroundLayer,
        });

      component.setParallaxEnabled(false);

      expect(component.parallaxEnabled, isFalse);
      expect(farLayer.enableParallax, isFalse);
      expect(foregroundLayer.enableParallax, isFalse);

      component.setDebugOverlays(true);

      expect(component.showDebug, isTrue);
      expect(farLayer.showDebug, isTrue);
      expect(foregroundLayer.showDebug, isTrue);

      component.setPatchDebugOverlays(showCenters: true);
      component.setPatchDebugOverlays(showEdges: true);
      component.adjustParallaxSpeeds(1.5);

      expect(component.showPatchCentersDebug, isTrue);
      expect(component.showEdgeZonesDebug, isTrue);
      expect(component.getAllLayers(), hasLength(2));
      expect(
        component.getLayer(TerrainDepth.foreground),
        same(foregroundLayer),
      );
    });

    test(
      'updateTerrainParams replaces generator configuration and creates layers',
      () async {
        final component = ParallaxTerrainComponent(gridSize: 6, seed: 7);

        await component.updateTerrainParams(
          patchSizeBase: 12,
          patchJitter: 1,
          primaryWeight: 0.9,
          warpAmplitude: 1.2,
          warpFrequency: 0.2,
          edgeWidth: 1.4,
          edgeGamma: 1.7,
        );

        expect(component.generator.seed, 7);
        expect(component.generator.patchSizeBase, 12);
        expect(component.generator.patchJitter, 1);
        expect(component.generator.primaryWeight, 0.9);
        expect(component.generator.warpAmplitude, 1.2);
        expect(component.generator.warpFrequency, 0.2);
        expect(component.generator.edgeWidth, 1.4);
        expect(component.generator.edgeGamma, 1.7);
        expect(component.getTerrainStats()['totalCells'], greaterThan(0));
        expect(component.getAllLayers(), isNotEmpty);
      },
    );

    test('loadRegion and shuffleSeed rebuild terrain state', () async {
      final component = ParallaxTerrainComponent(gridSize: 6, seed: 10);

      await component.loadRegion(0, 0, 2, 3);

      expect(component.getTerrainStats()['totalCells'], 6);

      final previousSeed = component.generator.seed;
      await component.shuffleSeed();

      expect(component.generator.seed, previousSeed + 1);
      expect(component.getTerrainStats()['totalCells'], greaterThan(0));
      expect(component.getAllLayers(), isNotEmpty);
    });
  });
}

ParallaxTerrainLayer _buildLayer(TerrainDepth depth) {
  return ParallaxTerrainLayer(
    depth: depth,
    terrainData: const <String, TerrainCell>{},
    gridSize: 4,
    cellWidth: 50,
    cellHeight: 50,
  );
}
