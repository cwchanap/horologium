import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

enum RecommendationType {
  assignWorkers,
  switchRecipe,
  upgrade,
  missingUpgradeResources,
  build,
  research,
  noProducer,
}

class ProductionRecommendation {
  final RecommendationType type;
  final ResourceType resourceType;
  final String message;
  final BuildingType? targetBuildingType;
  final ResearchType? researchType;
  final Map<ResourceType, double> missingResources;

  const ProductionRecommendation({
    required this.type,
    required this.resourceType,
    required this.message,
    this.targetBuildingType,
    this.researchType,
    this.missingResources = const {},
  });
}

class ProductionRecommendationEngine {
  static Map<ResourceType, ProductionRecommendation> recommend({
    required ProductionGraph graph,
    required List<Building> buildings,
    required Resources resources,
    required ResearchManager researchManager,
    required BuildingLimitManager buildingLimitManager,
  }) {
    final result = <ResourceType, ProductionRecommendation>{};

    for (final bottleneck in graph.bottlenecks) {
      result[bottleneck.resourceType] = _recommendForResource(
        bottleneck.resourceType,
        buildings,
        resources,
        researchManager,
        buildingLimitManager,
      );
    }

    return result;
  }

  static ProductionRecommendation _recommendForResource(
    ResourceType resourceType,
    List<Building> buildings,
    Resources resources,
    ResearchManager researchManager,
    BuildingLimitManager buildingLimitManager,
  ) {
    final producers = buildings
        .where((building) => building.generation.containsKey(resourceType))
        .toList();

    final idleProducer = producers
        .where(
          (building) =>
              building.requiredWorkers > 0 &&
              !building.hasWorkers &&
              resources.canAssignWorkerTo(building),
        )
        .firstOrNull;
    if (idleProducer != null) {
      return ProductionRecommendation(
        type: RecommendationType.assignWorkers,
        resourceType: resourceType,
        targetBuildingType: idleProducer.type,
        message: 'Assign workers to ${idleProducer.name}.',
      );
    }

    final switchRecommendation = _switchRecipeRecommendation(
      resourceType,
      buildings,
    );
    if (switchRecommendation != null) return switchRecommendation;

    final upgradeProducers = producers
        .where((building) => building.canUpgrade)
        .toList();
    final affordableUpgradeProducer = upgradeProducers
        .where((building) => building.upgradeCost.canAfford(resources))
        .firstOrNull;
    if (affordableUpgradeProducer != null) {
      return ProductionRecommendation(
        type: RecommendationType.upgrade,
        resourceType: resourceType,
        targetBuildingType: affordableUpgradeProducer.type,
        message: 'Upgrade ${affordableUpgradeProducer.name}.',
      );
    }

    final missingResourceUpgradeProducer = upgradeProducers.firstOrNull;
    if (missingResourceUpgradeProducer != null) {
      final missing = missingResourceUpgradeProducer.upgradeCost
          .missingResources(resources);
      return ProductionRecommendation(
        type: RecommendationType.missingUpgradeResources,
        resourceType: resourceType,
        targetBuildingType: missingResourceUpgradeProducer.type,
        missingResources: missing,
        message:
            'Gather more resources to upgrade ${missingResourceUpgradeProducer.name}.',
      );
    }

    final producerTemplate = _producerTemplateFor(resourceType);
    if (producerTemplate == null) {
      return ProductionRecommendation(
        type: RecommendationType.noProducer,
        resourceType: resourceType,
        message: 'No producer is available for ${resourceType.name}.',
      );
    }

    final requiredResearch = _researchForBuilding(producerTemplate.type);
    if (requiredResearch != null &&
        !researchManager.isResearched(requiredResearch.type)) {
      final actionableResearch =
          _actionableResearchFor(requiredResearch, researchManager) ??
          requiredResearch;
      final message = actionableResearch.type == requiredResearch.type
          ? 'Research ${actionableResearch.id} to unlock ${producerTemplate.name}.'
          : 'Research ${actionableResearch.id} to progress toward unlocking ${producerTemplate.name}.';

      return ProductionRecommendation(
        type: RecommendationType.research,
        resourceType: resourceType,
        targetBuildingType: producerTemplate.type,
        researchType: actionableResearch.type,
        message: message,
      );
    }

    final buildingCount = buildings
        .where((building) => building.type == producerTemplate.type)
        .length;
    final buildingLimit = buildingLimitManager.getBuildingLimit(
      producerTemplate.type,
    );
    final limitMessage = buildingCount >= buildingLimit
        ? ' Building limit reached ($buildingCount/$buildingLimit).'
        : '';

    return ProductionRecommendation(
      type: RecommendationType.build,
      resourceType: resourceType,
      targetBuildingType: producerTemplate.type,
      message: 'Build a ${producerTemplate.name}.$limitMessage',
    );
  }

  static ProductionRecommendation? _switchRecipeRecommendation(
    ResourceType resourceType,
    List<Building> buildings,
  ) {
    final crop = _cropFor(resourceType);
    if (crop != null) {
      final field = buildings
          .whereType<Field>()
          .where((building) => building.cropType != crop)
          .firstOrNull;
      if (field != null) {
        return ProductionRecommendation(
          type: RecommendationType.switchRecipe,
          resourceType: resourceType,
          targetBuildingType: BuildingType.field,
          message: 'Switch a Field to ${crop.name}.',
        );
      }
    }

    final kitchenProduct = _kitchenProductFor(resourceType);
    if (kitchenProduct != null) {
      final kitchen = buildings
          .whereType<Kitchen>()
          .where((building) => building.productType != kitchenProduct)
          .firstOrNull;
      if (kitchen != null) {
        return ProductionRecommendation(
          type: RecommendationType.switchRecipe,
          resourceType: resourceType,
          targetBuildingType: BuildingType.kitchen,
          message: 'Switch a Kitchen to ${kitchenProduct.name}.',
        );
      }
    }

    final bakeryProduct = _bakeryProductFor(resourceType);
    if (bakeryProduct != null) {
      final bakery = buildings
          .whereType<Bakery>()
          .where((building) => building.productType != bakeryProduct)
          .firstOrNull;
      if (bakery != null) {
        return ProductionRecommendation(
          type: RecommendationType.switchRecipe,
          resourceType: resourceType,
          targetBuildingType: BuildingType.bakery,
          message: 'Switch a Bakery to ${bakeryProduct.name}.',
        );
      }
    }

    return null;
  }

  static CropType? _cropFor(ResourceType resourceType) =>
      switch (resourceType) {
        ResourceType.wheat => CropType.wheat,
        ResourceType.corn => CropType.corn,
        ResourceType.rice => CropType.rice,
        ResourceType.barley => CropType.barley,
        _ => null,
      };

  static KitchenProduct? _kitchenProductFor(ResourceType resourceType) =>
      switch (resourceType) {
        ResourceType.tortillas => KitchenProduct.tortillas,
        ResourceType.riceMeals => KitchenProduct.riceMeals,
        ResourceType.maltDrink => KitchenProduct.maltDrink,
        _ => null,
      };

  static BakeryProduct? _bakeryProductFor(ResourceType resourceType) =>
      switch (resourceType) {
        ResourceType.bread => BakeryProduct.bread,
        ResourceType.pastries => BakeryProduct.pastries,
        _ => null,
      };

  static Building? _producerTemplateFor(ResourceType resourceType) {
    final recipeProducerType = _recipeProducerTypeFor(resourceType);
    if (recipeProducerType != null) {
      return BuildingRegistry.availableBuildings
          .where((building) => building.type == recipeProducerType)
          .firstOrNull;
    }

    return BuildingRegistry.availableBuildings
        .where((building) => building.generation.containsKey(resourceType))
        .firstOrNull;
  }

  static BuildingType? _recipeProducerTypeFor(ResourceType resourceType) {
    if (_cropFor(resourceType) != null) return BuildingType.field;
    if (_kitchenProductFor(resourceType) != null) return BuildingType.kitchen;
    if (_bakeryProductFor(resourceType) != null) return BuildingType.bakery;
    return null;
  }

  static Research? _researchForBuilding(BuildingType buildingType) {
    for (final research in Research.availableResearch) {
      if (research.unlocksBuildings.contains(buildingType)) {
        return research;
      }
    }
    return null;
  }

  static Research? _researchByType(ResearchType researchType) {
    for (final research in Research.availableResearch) {
      if (research.type == researchType) return research;
    }
    return null;
  }

  static Research? _actionableResearchFor(
    Research research,
    ResearchManager researchManager,
  ) {
    if (researchManager.isResearched(research.type)) return null;
    if (researchManager.canResearch(research)) return research;

    for (final prerequisiteType in research.prerequisites) {
      final prerequisite = _researchByType(prerequisiteType);
      if (prerequisite == null ||
          researchManager.isResearched(prerequisite.type)) {
        continue;
      }

      final actionable = _actionableResearchFor(prerequisite, researchManager);
      if (actionable != null) return actionable;
    }

    return null;
  }
}
