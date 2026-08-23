import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';

void main() {
  test('contains exactly the mining resource identities', () {
    expect(
      ResourceType.values,
      equals([
        ResourceType.gold,
        ResourceType.coal,
        ResourceType.stone,
        ResourceType.waterIce,
        ResourceType.titaniumOre,
        ResourceType.helium3,
        ResourceType.ironOre,
        ResourceType.silica,
        ResourceType.cobaltOre,
      ]),
    );
  });

  test('mining resource identities retain their stable names', () {
    expect(ResourceType.gold.name, 'gold');
    expect(ResourceType.coal.name, 'coal');
    expect(ResourceType.stone.name, 'stone');
    expect(ResourceType.waterIce.name, 'waterIce');
    expect(ResourceType.titaniumOre.name, 'titaniumOre');
    expect(ResourceType.helium3.name, 'helium3');
    expect(ResourceType.ironOre.name, 'ironOre');
    expect(ResourceType.silica.name, 'silica');
    expect(ResourceType.cobaltOre.name, 'cobaltOre');
  });
}
