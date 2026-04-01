import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/grid.dart';

void main() {
  group('Grid bookkeeping', () {
    test('getGridPosition returns null outside the configured size', () {
      final grid = Grid(gridSize: 2)
        ..size = Vector2(cellWidth * 2, cellHeight * 2);

      expect(grid.getGridPosition(Vector2(-1, 0)), isNull);
      expect(grid.getGridPosition(Vector2(0, -1)), isNull);
      expect(grid.getGridPosition(Vector2(cellWidth * 2, 0)), isNull);
      expect(grid.getGridPosition(Vector2(0, cellHeight * 2)), isNull);

      final inBounds = grid.getGridPosition(
        Vector2(cellWidth * 2 - 1, cellHeight * 2 - 1),
      );

      expect(inBounds, isNotNull);
      expect(inBounds!.x, 1);
      expect(inBounds.y, 1);
    });

    test('placeBuilding marks every occupied cell for a 2x2 building', () {
      final grid = Grid();
      final building = _createTestBuilding();

      grid.placeBuilding(3, 4, building, notifyCallbacks: false);

      for (final cell in const [(3, 4), (3, 5), (4, 4), (4, 5)]) {
        expect(grid.isCellOccupied(cell.$1, cell.$2), isTrue);
        expect(grid.getBuildingAt(cell.$1, cell.$2), same(building));
      }

      expect(grid.isCellOccupied(2, 4), isFalse);
      expect(grid.isCellOccupied(5, 5), isFalse);
      expect(grid.getAllBuildings(), [same(building)]);
    });

    test('countBuildingsOfType counts unique placed buildings by type', () {
      final grid = Grid();
      final houseOne = _createTestBuilding(
        type: BuildingType.house,
        name: 'House One',
      );
      final houseTwo = _createTestBuilding(
        type: BuildingType.house,
        name: 'House Two',
      );
      final powerPlant = _createTestBuilding(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
      );

      grid
        ..placeBuilding(1, 1, houseOne, notifyCallbacks: false)
        ..placeBuilding(5, 5, houseTwo, notifyCallbacks: false)
        ..placeBuilding(9, 9, powerPlant, notifyCallbacks: false);

      expect(grid.countBuildingsOfType(BuildingType.house), 2);
      expect(grid.countBuildingsOfType(BuildingType.powerPlant), 1);
      expect(grid.countBuildingsOfType(BuildingType.coalMine), 0);
    });

    test(
      'removeBuilding clears every occupied cell and invokes the callback once',
      () {
        final removedCoordinates = <String>[];
        final grid = Grid(
          onBuildingRemoved: (x, y) => removedCoordinates.add('$x,$y'),
        );
        final building = _createTestBuilding();

        grid.placeBuilding(3, 4, building, notifyCallbacks: false);

        grid.removeBuilding(4, 5);

        for (final cell in const [(3, 4), (3, 5), (4, 4), (4, 5)]) {
          expect(grid.isCellOccupied(cell.$1, cell.$2), isFalse);
          expect(grid.getBuildingAt(cell.$1, cell.$2), isNull);
        }

        expect(grid.getAllBuildings(), isEmpty);
        expect(removedCoordinates, ['3,4']);
      },
    );
  });
}

Building _createTestBuilding({
  BuildingType type = BuildingType.house,
  String name = 'Test House',
}) {
  return Building(
    type: type,
    name: name,
    description: 'Test building used for grid bookkeeping tests.',
    icon: Icons.home,
    color: Colors.green,
    baseCost: 100,
    category: BuildingCategory.residential,
  );
}
