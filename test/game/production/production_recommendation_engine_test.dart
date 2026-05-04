import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/flow_analyzer.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/production/production_recommendation_engine.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

void main() {
  group('ProductionRecommendationEngine', () {
    test('recommends assigning workers to idle producer first', () {
      final coalMine = _building(
        type: BuildingType.coalMine,
        generation: {ResourceType.coal: 1},
        assignedWorkers: 0,
      );
      final powerPlant = _building(
        type: BuildingType.powerPlant,
        consumption: {ResourceType.coal: 1},
        assignedWorkers: 1,
      );
      final graph = FlowAnalyzer.analyzeGraph(
        ProductionGraph.fromBuildings([coalMine, powerPlant], Resources()),
      );

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: [coalMine, powerPlant],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.coal]!.type,
        RecommendationType.assignWorkers,
      );
      expect(
        recommendations[ResourceType.coal]!.targetBuildingType,
        BuildingType.coalMine,
      );
      expect(recommendations[ResourceType.coal]!.targetBuildingId, coalMine.id);
    });

    test('recommends switching Field crop for crop shortages', () {
      final field = Field(
        type: BuildingType.field,
        name: 'Field',
        description: 'Grows crops',
        icon: Icons.grass,
        color: Colors.green,
        baseCost: 50,
        requiredWorkers: 1,
        category: BuildingCategory.foodResources,
        cropType: CropType.wheat,
      )..assignWorker();
      final grinder = _building(
        type: BuildingType.grinderMill,
        consumption: {ResourceType.corn: 4},
        assignedWorkers: 1,
      );
      final graph = FlowAnalyzer.analyzeGraph(
        ProductionGraph.fromBuildings([field, grinder], Resources()),
      );

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: [field, grinder],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.corn]!.type,
        RecommendationType.switchRecipe,
      );
      expect(
        recommendations[ResourceType.corn]!.targetBuildingType,
        BuildingType.field,
      );
      expect(recommendations[ResourceType.corn]!.targetBuildingId, field.id);
      expect(recommendations[ResourceType.corn]!.message, contains('corn'));
    });

    test(
      'recommends switching Kitchen product for prepared food shortages',
      () {
        final kitchen = Kitchen(
          type: BuildingType.kitchen,
          name: 'Kitchen',
          description: 'Prepares food',
          icon: Icons.restaurant,
          color: Colors.deepOrange,
          baseCost: 180,
          requiredWorkers: 1,
          category: BuildingCategory.refinement,
          productType: KitchenProduct.tortillas,
        )..assignWorker();
        final consumer = _building(
          type: BuildingType.house,
          consumption: {ResourceType.riceMeals: 1},
          assignedWorkers: 0,
          requiredWorkers: 0,
        );
        final currentProductConsumer = _building(
          type: BuildingType.house,
          consumption: {ResourceType.tortillas: 1},
          assignedWorkers: 0,
          requiredWorkers: 0,
        );
        final graph = FlowAnalyzer.analyzeGraph(
          ProductionGraph.fromBuildings([
            kitchen,
            consumer,
            currentProductConsumer,
          ], Resources()),
        );

        final recommendations = ProductionRecommendationEngine.recommend(
          graph: graph,
          buildings: [kitchen, consumer, currentProductConsumer],
          resources: Resources(),
          researchManager: ResearchManager(),
          buildingLimitManager: BuildingLimitManager(),
        );

        expect(
          recommendations[ResourceType.riceMeals]!.type,
          RecommendationType.switchRecipe,
        );
        expect(
          recommendations[ResourceType.riceMeals]!.targetBuildingType,
          BuildingType.kitchen,
        );
        expect(
          recommendations[ResourceType.riceMeals]!.targetBuildingId,
          kitchen.id,
        );
        expect(
          recommendations[ResourceType.riceMeals]!.message,
          contains('riceMeals'),
        );
      },
    );

    test('recommends researching locked producer', () {
      final consumer = _building(
        type: BuildingType.largeHouse,
        consumption: {ResourceType.electricity: 1},
        assignedWorkers: 0,
        requiredWorkers: 0,
      );
      final graph = FlowAnalyzer.analyzeGraph(
        ProductionGraph.fromBuildings([consumer], Resources()),
      );

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: [consumer],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.electricity]!.type,
        RecommendationType.research,
      );
      expect(
        recommendations[ResourceType.electricity]!.researchType,
        ResearchType.electricity,
      );
      expect(
        recommendations[ResourceType.electricity]!.targetBuildingType,
        BuildingType.powerPlant,
      );
      expect(
        recommendations[ResourceType.electricity]!.targetBuildingId,
        isNull,
      );
    });

    test('recommends no producer fallback for unavailableWorkers', () {
      final graph = ProductionGraph(
        id: 'test',
        generatedAt: DateTime.now(),
        nodes: [
          BuildingNode(
            id: 'consumer',
            name: 'Consumer',
            type: BuildingType.house,
            category: BuildingCategory.residential,
            inputs: const [
              ResourcePort(
                resourceType: ResourceType.availableWorkers,
                ratePerSecond: 1,
                status: FlowStatus.deficit,
              ),
            ],
            outputs: const [],
            status: FlowStatus.deficit,
            hasWorkers: true,
          ),
        ],
        edges: [],
        bottlenecks: [
          BottleneckInsight(
            id: 'bottleneck_availableWorkers',
            resourceType: ResourceType.availableWorkers,
            severity: BottleneckSeverity.high,
            description: 'availableWorkers missing',
            recommendation: 'No producer available',
            impactedNodeIds: const ['consumer'],
          ),
        ],
      );

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: const [],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.availableWorkers]!.type,
        RecommendationType.noProducer,
      );
      expect(
        recommendations[ResourceType.availableWorkers]!.targetBuildingId,
        isNull,
      );
    });

    test(
      'recommends building Field when no existing crop recipe can switch',
      () {
        final recommendations = ProductionRecommendationEngine.recommend(
          graph: _graphWithBottleneck(ResourceType.corn),
          buildings: const [],
          resources: Resources(),
          researchManager: ResearchManager(),
          buildingLimitManager: BuildingLimitManager(),
        );

        expect(
          recommendations[ResourceType.corn]!.type,
          RecommendationType.build,
        );
        expect(
          recommendations[ResourceType.corn]!.targetBuildingType,
          BuildingType.field,
        );
        expect(recommendations[ResourceType.corn]!.targetBuildingId, isNull);
      },
    );

    test('recommends actionable prerequisite for locked producer research', () {
      final recommendations = ProductionRecommendationEngine.recommend(
        graph: _graphWithBottleneck(ResourceType.riceMeals),
        buildings: const [],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.riceMeals]!.type,
        RecommendationType.research,
      );
      expect(
        recommendations[ResourceType.riceMeals]!.targetBuildingType,
        BuildingType.kitchen,
      );
      expect(
        recommendations[ResourceType.riceMeals]!.researchType,
        ResearchType.grainProcessing,
      );
    });

    test('prefers a later affordable upgrade over first missing resources', () {
      final expensiveCoalMine = _building(
        type: BuildingType.coalMine,
        generation: {ResourceType.coal: 1},
        assignedWorkers: 1,
      )..level = 2;
      final affordableCoalMine = _building(
        type: BuildingType.coalMine,
        generation: {ResourceType.coal: 1},
        assignedWorkers: 1,
      );
      final resources = Resources()
        ..cash = 250
        ..planks = 2;

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: _graphWithBottleneck(ResourceType.coal),
        buildings: [expensiveCoalMine, affordableCoalMine],
        resources: resources,
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.coal]!.type,
        RecommendationType.upgrade,
      );
      expect(recommendations[ResourceType.coal]!.missingResources, isEmpty);
      expect(
        recommendations[ResourceType.coal]!.targetBuildingId,
        affordableCoalMine.id,
      );
    });

    test('does not recommend assigning workers when none are available', () {
      final coalMine = _building(
        type: BuildingType.coalMine,
        generation: {ResourceType.coal: 1},
        assignedWorkers: 0,
      );
      final resources = Resources()
        ..availableWorkers = 0
        ..cash = 200
        ..planks = 2;

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: _graphWithBottleneck(ResourceType.coal),
        buildings: [coalMine],
        resources: resources,
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.coal]!.type,
        RecommendationType.upgrade,
      );
      expect(recommendations[ResourceType.coal]!.targetBuildingId, coalMine.id);
    });

    test('sets target id for missing-resource upgrade recommendations', () {
      final coalMine = _building(
        type: BuildingType.coalMine,
        generation: {ResourceType.coal: 1},
        assignedWorkers: 1,
      );
      final resources = Resources()
        ..cash = 0
        ..planks = 0;

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: _graphWithBottleneck(ResourceType.coal),
        buildings: [coalMine],
        resources: resources,
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.coal]!.type,
        RecommendationType.missingUpgradeResources,
      );
      expect(recommendations[ResourceType.coal]!.targetBuildingId, coalMine.id);
    });

    test('recommends switching Bakery product for pastry shortages', () {
      final bakery = Bakery(
        type: BuildingType.bakery,
        name: 'Bakery',
        description: 'Bakes food',
        icon: Icons.bakery_dining,
        color: Colors.orange,
        baseCost: 150,
        requiredWorkers: 1,
        category: BuildingCategory.refinement,
        productType: BakeryProduct.bread,
      )..assignWorker();

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: _graphWithBottleneck(ResourceType.pastries),
        buildings: [bakery],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(
        recommendations[ResourceType.pastries]!.type,
        RecommendationType.switchRecipe,
      );
      expect(
        recommendations[ResourceType.pastries]!.targetBuildingType,
        BuildingType.bakery,
      );
      expect(
        recommendations[ResourceType.pastries]!.targetBuildingId,
        bakery.id,
      );
    });

    test(
      'recommends research fallback for pastry producer when no Bakery exists',
      () {
        final recommendations = ProductionRecommendationEngine.recommend(
          graph: _graphWithBottleneck(ResourceType.pastries),
          buildings: const [],
          resources: Resources(),
          researchManager: ResearchManager(),
          buildingLimitManager: BuildingLimitManager(),
        );

        expect(
          recommendations[ResourceType.pastries]!.type,
          RecommendationType.research,
        );
        expect(
          recommendations[ResourceType.pastries]!.targetBuildingType,
          BuildingType.bakery,
        );
        expect(
          recommendations[ResourceType.pastries]!.researchType,
          ResearchType.grainProcessing,
        );
      },
    );

    test('does not recommend upgrading input-starved producer', () {
      // Scenario: Grinder Mill produces cornmeal from corn, but corn is in
      // deficit (no corn producer). The engine should NOT recommend upgrading
      // the Grinder Mill since it can't produce until corn supply is fixed.
      final grinderMill = _building(
        type: BuildingType.grinderMill,
        generation: {ResourceType.cornmeal: 1},
        consumption: {ResourceType.corn: 4},
        assignedWorkers: 1,
      );
      final kitchen = Kitchen(
        type: BuildingType.kitchen,
        name: 'Kitchen',
        description: 'Prepares food',
        icon: Icons.restaurant,
        color: Colors.deepOrange,
        baseCost: 180,
        requiredWorkers: 1,
        category: BuildingCategory.refinement,
        productType: KitchenProduct.tortillas,
      )..assignWorker();

      // Build the graph so FlowAnalyzer detects the corn deficit on
      // the Grinder Mill node.
      final graph = FlowAnalyzer.analyzeGraph(
        ProductionGraph.fromBuildings([grinderMill, kitchen], Resources()),
      );

      final resources = Resources()
        ..cash = 500
        ..planks = 5;

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: [grinderMill, kitchen],
        resources: resources,
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      // Cornmeal should be a bottleneck (Grinder Mill can't produce), but
      // the recommendation must NOT suggest upgrading the Grinder Mill.
      // Instead it falls through to "build" (suggesting another Grinder Mill).
      final cornmealRec = recommendations[ResourceType.cornmeal];
      expect(cornmealRec, isNotNull);
      expect(cornmealRec!.type, isNot(equals(RecommendationType.upgrade)));
      expect(
        cornmealRec.type,
        isNot(equals(RecommendationType.missingUpgradeResources)),
      );
    });
  });
}

ProductionGraph _graphWithBottleneck(ResourceType resourceType) {
  return ProductionGraph(
    id: 'test',
    generatedAt: DateTime.now(),
    nodes: const [],
    edges: const [],
    bottlenecks: [
      BottleneckInsight(
        id: 'bottleneck_${resourceType.name}',
        resourceType: resourceType,
        severity: BottleneckSeverity.high,
        description: '${resourceType.name} missing',
        recommendation: 'Add producer',
        impactedNodeIds: const [],
      ),
    ],
  );
}

Building _building({
  required BuildingType type,
  Map<ResourceType, double> generation = const {},
  Map<ResourceType, double> consumption = const {},
  int assignedWorkers = 0,
  int requiredWorkers = 1,
}) {
  return Building(
    type: type,
    name: type.name,
    description: type.name,
    icon: Icons.factory,
    color: Colors.blue,
    baseCost: 100,
    baseGeneration: generation,
    baseConsumption: consumption,
    requiredWorkers: requiredWorkers,
    category: BuildingCategory.rawMaterials,
  )..assignedWorkers = assignedWorkers;
}
