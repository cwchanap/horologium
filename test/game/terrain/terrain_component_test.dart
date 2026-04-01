import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/terrain/terrain_biome.dart';
import 'package:horologium/game/terrain/terrain_component.dart';
import 'package:horologium/game/terrain/terrain_layer.dart';

void main() {
  group('TerrainComponent', () {
    test(
      'getTerrainAt, isBuildableAt, and stats work with injected terrain data',
      () {
        final component = TerrainComponent(gridSize: 4)
          ..replaceTerrainDataForTest(<String, TerrainCell>{
            '0,0': const TerrainCell(
              baseType: TerrainType.grass,
              elevation: 0.3,
              moisture: 0.4,
              biome: BiomeType.grassland,
            ),
            '1,0': const TerrainCell(
              baseType: TerrainType.water,
              elevation: 0.1,
              moisture: 0.9,
              biome: BiomeType.wetlands,
            ),
            '2,0': const TerrainCell(
              baseType: TerrainType.grass,
              elevation: 0.95,
              moisture: 0.7,
              biome: BiomeType.forest,
            ),
            '3,0': const TerrainCell(
              baseType: TerrainType.grass,
              elevation: 0.5,
              moisture: 0.5,
              biome: BiomeType.forest,
              features: <FeatureType>[FeatureType.rockLarge],
            ),
          });

        expect(component.getTerrainAt(0, 0)?.baseType, TerrainType.grass);
        expect(component.isBuildableAt(0, 0), isTrue);
        expect(component.isBuildableAt(1, 0), isFalse);
        expect(component.isBuildableAt(2, 0), isFalse);
        expect(component.isBuildableAt(3, 0), isFalse);
        expect(component.getTerrainAt(9, 9), isNull);
        expect(component.isBuildableAt(9, 9), isTrue);

        expect(component.getBiomeDistribution(), <BiomeType, int>{
          BiomeType.grassland: 1,
          BiomeType.wetlands: 1,
          BiomeType.forest: 2,
        });

        final stats = component.getTerrainStats();
        expect(stats['totalCells'], 4);
        expect(stats['averageElevation'], closeTo(0.4625, 0.0001));
        expect(stats['averageMoisture'], closeTo(0.625, 0.0001));
        expect(stats['waterPercentage'], closeTo(25.0, 0.0001));
      },
    );

    test(
      'updateTerrainAt updates stored terrain and forwards to the existing layer',
      () async {
        final component = TerrainComponent(gridSize: 4);
        final layer = FakeTerrainLayer();
        const newTerrain = TerrainCell(
          baseType: TerrainType.sand,
          features: <FeatureType>[FeatureType.rockSmall],
          elevation: 0.2,
          moisture: 0.3,
          biome: BiomeType.desert,
        );

        component
          ..replaceTerrainDataForTest(<String, TerrainCell>{
            '1,1': const TerrainCell(baseType: TerrainType.grass),
          })
          ..replaceLayersForTest(<String, TerrainLayer>{'1,1': layer});

        await component.updateTerrainAt(1, 1, newTerrain);

        expect(component.getTerrainAt(1, 1), same(newTerrain));
        expect(layer.updateCalls, hasLength(1));
        expect(layer.updateCalls.single.$1, TerrainType.sand);
        expect(layer.updateCalls.single.$2, <FeatureType>[
          FeatureType.rockSmall,
        ]);
        expect(component.getAllLayers(), <TerrainLayer>[layer]);
      },
    );

    test(
      'loadRegion and regenerateTerrain rebuild terrain state after prepareForTest',
      () async {
        final component = TerrainComponent(gridSize: 6)..prepareForTest();

        await component.loadRegion(0, 0, 2, 3);

        expect(component.getTerrainStats()['totalCells'], 6);
        expect(component.getAllLayers(), hasLength(6));

        await component.regenerateTerrain(newSeed: 99);

        expect(component.getTerrainStats()['totalCells'], greaterThan(0));
        expect(component.getAllLayers(), isNotEmpty);
        expect(component.getTerrainAt(0, 0), isNotNull);
      },
    );
  });
}

class FakeTerrainLayer extends TerrainLayer {
  FakeTerrainLayer() : super(terrainType: TerrainType.grass);

  final List<(TerrainType, List<FeatureType>)> updateCalls =
      <(TerrainType, List<FeatureType>)>[];

  @override
  Future<void> updateTerrain(
    TerrainType newType,
    List<FeatureType> newFeatures,
  ) async {
    updateCalls.add((newType, newFeatures));
  }
}
