import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/planet/planet.dart';
import 'package:horologium/game/planet/placed_building_data.dart';

void main() {
  group('Planet', () {
    test(
      'initializes cumulative building stats from preloaded buildings when counts are not provided',
      () {
        final buildings = [
          const PlacedBuildingData(
            id: 'house-1',
            x: 0,
            y: 0,
            type: BuildingType.house,
          ),
          const PlacedBuildingData(
            id: 'house-2',
            x: 1,
            y: 0,
            type: BuildingType.house,
          ),
          const PlacedBuildingData(
            id: 'power-1',
            x: 2,
            y: 0,
            type: BuildingType.powerPlant,
          ),
        ];

        final planet = Planet(id: 'earth', name: 'Earth', buildings: buildings);

        expect(planet.getBuildingCount(BuildingType.house), 2);
        expect(planet.getCumulativeBuildingCount(BuildingType.house), 2);
        expect(planet.getCumulativeBuildingCount(BuildingType.powerPlant), 1);
        expect(planet.getTotalBuildingsPlaced(), 3);
      },
    );
  });
}
