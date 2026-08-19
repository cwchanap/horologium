import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';

enum MiningSectorId { landingBasin, carbonRidge, graniteCrater }

// World-pixel offset from centered 1800×1800 terrain origin.
class MiningWorldAnchor {
  const MiningWorldAnchor(this.x, this.y);
  final double x;
  final double y;
}

class MiningSectorDefinition {
  const MiningSectorDefinition({
    required this.id,
    required this.name,
    required this.resource,
    required this.mineAsset,
    required this.revealCost,
    required this.requiredSector,
    required this.buildCost,
    required this.baseRatePerSecond,
    required this.baseCapacity,
    required this.saleValuePerUnit,
    required this.upgradeCosts,
    required this.anchor,
  });

  final MiningSectorId id;
  final String name;
  final ResourceType resource;
  final String mineAsset;
  final int revealCost;
  final MiningSectorId? requiredSector;
  final int buildCost;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<int> upgradeCosts;
  final MiningWorldAnchor anchor;
}

class MiningContentRegistry {
  const MiningContentRegistry._(this.sectors);

  static const int terrainGridSize = 36;
  static const double terrainCellSize = 50;
  static const double worldExtent = terrainGridSize * terrainCellSize;
  static const double worldHalfExtent = worldExtent / 2;
  static const offlineCap = Duration(hours: 8);
  static const rateMultipliers = <double>[1.0, 1.5, 2.25, 3.25, 4.5];
  static const capacityMultipliers = <double>[1.0, 1.5, 2.0, 3.0, 4.0];

  final List<MiningSectorDefinition> sectors;

  factory MiningContentRegistry.phaseOne() => const MiningContentRegistry._([
    MiningSectorDefinition(
      id: MiningSectorId.landingBasin,
      name: 'Landing Basin',
      resource: ResourceType.gold,
      mineAsset: Assets.goldMine,
      revealCost: 0,
      requiredSector: null,
      buildCost: 50,
      baseRatePerSecond: 0.50,
      baseCapacity: 90,
      saleValuePerUnit: 4,
      upgradeCosts: [80, 160, 320, 640],
      anchor: MiningWorldAnchor(-72, 396),
    ),
    MiningSectorDefinition(
      id: MiningSectorId.carbonRidge,
      name: 'Carbon Ridge',
      resource: ResourceType.coal,
      mineAsset: Assets.coalMine,
      revealCost: 250,
      requiredSector: MiningSectorId.landingBasin,
      buildCost: 100,
      baseRatePerSecond: 0.75,
      baseCapacity: 120,
      saleValuePerUnit: 3,
      upgradeCosts: [150, 300, 600, 1200],
      anchor: MiningWorldAnchor(-396, -72),
    ),
    MiningSectorDefinition(
      id: MiningSectorId.graniteCrater,
      name: 'Granite Crater',
      resource: ResourceType.stone,
      mineAsset: Assets.quarry,
      revealCost: 700,
      requiredSector: MiningSectorId.carbonRidge,
      buildCost: 250,
      baseRatePerSecond: 0.60,
      baseCapacity: 120,
      saleValuePerUnit: 5,
      upgradeCosts: [350, 700, 1400, 2800],
      anchor: MiningWorldAnchor(324, -360),
    ),
  ]);

  MiningSectorDefinition sector(MiningSectorId id) =>
      sectors.singleWhere((sector) => sector.id == id);

  double rateFor(MiningSectorId id, int level) =>
      sector(id).baseRatePerSecond * rateMultipliers[level - 1];

  double capacityFor(MiningSectorId id, int level) =>
      sector(id).baseCapacity * capacityMultipliers[level - 1];
}
