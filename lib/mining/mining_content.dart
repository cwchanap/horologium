import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';

enum MiningPlanetId { homeworld, lunarFrontier }

enum MiningSectorId {
  landingBasin,
  carbonRidge,
  graniteCrater,
  frozenBasin,
  titaniumHighlands,
  heliumMare,
}

enum TechnologyTrack { extraction, logistics, surveying }

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
    required this.requiredSurveyingLevel,
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
  final int requiredSurveyingLevel;
  final int buildCost;
  final double baseRatePerSecond;
  final double baseCapacity;
  final int saleValuePerUnit;
  final List<int> upgradeCosts;
  final MiningWorldAnchor anchor;
}

class MiningPlanetDefinition {
  const MiningPlanetDefinition({
    required this.id,
    required this.name,
    required this.sectors,
    required this.terrainSeed,
  });

  final MiningPlanetId id;
  final String name;
  final List<MiningSectorDefinition> sectors;
  final int terrainSeed;
}

class MiningContentRegistry {
  const MiningContentRegistry._(this.planets);

  static const int terrainGridSize = 36;
  static const double terrainCellSize = 50;
  static const double worldExtent = terrainGridSize * terrainCellSize;
  static const double worldHalfExtent = worldExtent / 2;
  static const offlineCapsByLogistics = <Duration>[
    Duration(hours: 8),
    Duration(hours: 10),
    Duration(hours: 12),
    Duration(hours: 16),
    Duration(hours: 20),
    Duration(hours: 24),
  ];
  static const rateMultipliers = <double>[1.0, 1.5, 2.25, 3.25, 4.5];
  static const capacityMultipliers = <double>[1.0, 1.5, 2.0, 3.0, 4.0];
  static const extractionRateMultipliers = <double>[
    1.0,
    1.1,
    1.25,
    1.45,
    1.7,
    2.0,
  ];
  static const logisticsCapacityMultipliers = <double>[
    1.0,
    1.15,
    1.3,
    1.5,
    1.75,
    2.0,
  ];

  final Map<MiningPlanetId, MiningPlanetDefinition> planets;

  factory MiningContentRegistry.stellarMining() =>
      const MiningContentRegistry._({
        MiningPlanetId.homeworld: MiningPlanetDefinition(
          id: MiningPlanetId.homeworld,
          name: 'Homeworld',
          terrainSeed: 631,
          sectors: [
            MiningSectorDefinition(
              id: MiningSectorId.landingBasin,
              name: 'Landing Basin',
              resource: ResourceType.gold,
              mineAsset: Assets.goldMine,
              revealCost: 0,
              requiredSector: null,
              requiredSurveyingLevel: 0,
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
              requiredSurveyingLevel: 0,
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
              requiredSurveyingLevel: 0,
              buildCost: 250,
              baseRatePerSecond: 0.60,
              baseCapacity: 120,
              saleValuePerUnit: 5,
              upgradeCosts: [350, 700, 1400, 2800],
              anchor: MiningWorldAnchor(324, -360),
            ),
          ],
        ),
        MiningPlanetId.lunarFrontier: MiningPlanetDefinition(
          id: MiningPlanetId.lunarFrontier,
          name: 'Lunar Frontier',
          terrainSeed: 638,
          sectors: [
            MiningSectorDefinition(
              id: MiningSectorId.frozenBasin,
              name: 'Frozen Basin',
              resource: ResourceType.waterIce,
              mineAsset: Assets.waterTreatmentPlant,
              revealCost: 0,
              requiredSector: null,
              requiredSurveyingLevel: 3,
              buildCost: 500,
              baseRatePerSecond: 1.00,
              baseCapacity: 150,
              saleValuePerUnit: 6,
              upgradeCosts: [700, 1400, 2800, 5600],
              anchor: MiningWorldAnchor(-420, 320),
            ),
            MiningSectorDefinition(
              id: MiningSectorId.titaniumHighlands,
              name: 'Titanium Highlands',
              resource: ResourceType.titaniumOre,
              mineAsset: Assets.grinderMill,
              revealCost: 3000,
              requiredSector: MiningSectorId.frozenBasin,
              requiredSurveyingLevel: 4,
              buildCost: 1200,
              baseRatePerSecond: 0.80,
              baseCapacity: 140,
              saleValuePerUnit: 12,
              upgradeCosts: [1600, 3200, 6400, 12800],
              anchor: MiningWorldAnchor(120, -80),
            ),
            MiningSectorDefinition(
              id: MiningSectorId.heliumMare,
              name: 'Helium Mare',
              resource: ResourceType.helium3,
              mineAsset: Assets.researchLab,
              revealCost: 8000,
              requiredSector: MiningSectorId.titaniumHighlands,
              requiredSurveyingLevel: 5,
              buildCost: 3000,
              baseRatePerSecond: 0.55,
              baseCapacity: 120,
              saleValuePerUnit: 30,
              upgradeCosts: [4000, 8000, 16000, 32000],
              anchor: MiningWorldAnchor(390, -410),
            ),
          ],
        ),
      });

  MiningPlanetDefinition planet(MiningPlanetId id) => planets[id]!;

  MiningSectorDefinition sector(MiningSectorId id) => planets.values
      .expand((planet) => planet.sectors)
      .singleWhere((sector) => sector.id == id);

  MiningPlanetId planetForSector(MiningSectorId id) => planets.entries
      .singleWhere(
        (entry) => entry.value.sectors.any((sector) => sector.id == id),
      )
      .key;

  double rateFor(MiningSectorId id, int level) =>
      sector(id).baseRatePerSecond * rateMultipliers[level - 1];

  double capacityFor(MiningSectorId id, int level) =>
      sector(id).baseCapacity * capacityMultipliers[level - 1];

  double effectiveRate(MiningSectorId id, int level, int extraction) =>
      rateFor(id, level) * extractionRateMultipliers[extraction];

  double effectiveCapacity(MiningSectorId id, int level, int logistics) =>
      capacityFor(id, level) * logisticsCapacityMultipliers[logistics];

  Duration offlineCapFor(int logistics) => offlineCapsByLogistics[logistics];
}
