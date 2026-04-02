import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/grid.dart';
import 'package:horologium/game/main_game.dart';
import 'package:horologium/game/planet/index.dart';
import 'package:horologium/game/terrain/parallax_terrain_component.dart';
import 'package:horologium/game/terrain/terrain_biome.dart';

void main() {
  group('MainGame world logic', () {
    test(
      'loadBuildings places planet buildings into the injected grid',
      () async {
        final game = MainGame();
        final grid = _configuredGrid();
        final planet = Planet(
          id: 'load-buildings',
          name: 'Load Buildings',
          buildings: const <PlacedBuildingData>[
            PlacedBuildingData(
              id: 'house-1',
              x: 1,
              y: 2,
              type: BuildingType.house,
            ),
            PlacedBuildingData(
              id: 'power-1',
              x: 4,
              y: 5,
              type: BuildingType.powerPlant,
            ),
          ],
        );

        game.setGridForTest(grid);
        game.setPlanet(planet);

        await game.loadBuildings();

        expect(
          grid.getPlacedBuildingAt(1, 2)?.building.type,
          BuildingType.house,
        );
        expect(
          grid.getPlacedBuildingAt(4, 5)?.building.type,
          BuildingType.powerPlant,
        );
      },
    );

    test(
      'showPlacementPreview marks valid, occupied, blocked, and outside positions',
      () {
        final game = MainGame();
        final grid = _configuredGrid();
        final terrain = ParallaxTerrainComponent(gridSize: grid.gridSize)
          ..replaceTerrainDataForTest(<String, TerrainCell>{
            '3,3': const TerrainCell(baseType: TerrainType.water),
          });
        final building = _createBuilding(BuildingType.house);

        game
          ..setGridForTest(grid)
          ..setTerrainForTest(terrain);

        game.showPlacementPreview(building, _worldPositionForCell(grid, 1, 1));

        expect(game.placementPreview.building, same(building));
        expect(game.placementPreview.isValid, isTrue);
        expect(game.placementPreview.position.x, 50 - grid.size.x / 2);
        expect(game.placementPreview.position.y, 50 - grid.size.y / 2);

        grid.placeBuilding(0, 0, _createBuilding(BuildingType.house));
        game.showPlacementPreview(building, _worldPositionForCell(grid, 0, 0));
        expect(game.placementPreview.isValid, isFalse);

        game.showPlacementPreview(building, _worldPositionForCell(grid, 3, 3));
        expect(game.placementPreview.isValid, isFalse);

        game.showPlacementPreview(building, _outsideWorldPosition(grid));
        expect(game.placementPreview.position.x, -10000);
        expect(game.placementPreview.position.y, -10000);
        expect(game.placementPreview.isValid, isFalse);
      },
    );

    test('clampZoom respects fit zoom, min zoom, and max zoom', () {
      final game = MainGame();

      game.setFitZoomForTest(0.5);
      game.camera.viewfinder.zoom = 0.1;
      game.clampZoom();
      expect(game.camera.viewfinder.zoom, 0.5);

      game.camera.viewfinder.zoom = 10;
      game.clampZoom();
      expect(game.camera.viewfinder.zoom, 4.0);

      game.setFitZoomForTest(null);
      game.camera.viewfinder.zoom = 0.01;
      game.clampZoom();
      expect(game.camera.viewfinder.zoom, closeTo(0.1, 0.000001));
    });

    test(
      'world-position helpers route tap, cancel, long press, and secondary tap callbacks',
      () {
        final game = MainGame();
        final grid = _configuredGrid();
        final building = _createBuilding(BuildingType.house);
        final tapCalls = <List<int>>[];
        final longTapCalls = <List<int>>[];
        final secondaryTapCalls = <List<int>>[];

        game.setGridForTest(grid);
        game.onGridCellTapped = (x, y) {
          tapCalls.add(<int>[x, y]);
        };
        game.onGridCellLongTapped = (x, y) {
          longTapCalls.add(<int>[x, y]);
        };
        game.onGridCellSecondaryTapped = (x, y) {
          secondaryTapCalls.add(<int>[x, y]);
        };

        game.handleTapAtWorldPosition(_worldPositionForCell(grid, 2, 3));
        game.handleLongTapAtWorldPosition(_worldPositionForCell(grid, 4, 5));
        game.handleSecondaryTapAtWorldPosition(
          _worldPositionForCell(grid, 6, 7),
        );

        expect(tapCalls, <List<int>>[
          <int>[2, 3],
        ]);
        expect(longTapCalls, <List<int>>[
          <int>[4, 5],
        ]);
        expect(secondaryTapCalls, <List<int>>[
          <int>[6, 7],
        ]);

        game.buildingToPlace = building;
        game.handleTapAtWorldPosition(_outsideWorldPosition(grid));

        expect(tapCalls, <List<int>>[
          <int>[2, 3],
          <int>[-1, -1],
        ]);
      },
    );
  });
}

Grid _configuredGrid({int gridSize = 50}) {
  return Grid(gridSize: gridSize)
    ..size = Vector2(gridSize * cellWidth, gridSize * cellHeight)
    ..anchor = Anchor.center
    ..position = Vector2.zero();
}

Building _createBuilding(BuildingType type) {
  final building = PlacedBuildingData(
    id: '${type.name}-test',
    x: 0,
    y: 0,
    type: type,
  ).createBuilding();

  if (building == null) {
    throw StateError(
      'PlacedBuildingData.createBuilding returned null for '
      'BuildingType.${type.name} in _createBuilding; expected a Building.',
    );
  }

  return building;
}

Vector2 _worldPositionForCell(Grid grid, int x, int y) {
  return Vector2(
    x * cellWidth - grid.size.x / 2 + cellWidth / 2,
    y * cellHeight - grid.size.y / 2 + cellHeight / 2,
  );
}

Vector2 _outsideWorldPosition(Grid grid) {
  return Vector2(grid.size.x, grid.size.y);
}
