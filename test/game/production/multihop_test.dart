import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/flow_analyzer.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/resources/resource_type.dart';

/// Create a test node
BuildingNode _createNode(
  String id,
  Map<ResourceType, double> inputs,
  Map<ResourceType, double> outputs, {
  bool hasWorkers = true,
}) {
  return BuildingNode(
    id: id,
    name: id,
    type: BuildingType.house,
    category: BuildingCategory.residential,
    inputs: inputs.entries
        .map(
          (e) => ResourcePort(
            resourceType: e.key,
            ratePerSecond: e.value,
            status: FlowStatus.balanced,
          ),
        )
        .toList(),
    outputs: outputs.entries
        .map(
          (e) => ResourcePort(
            resourceType: e.key,
            ratePerSecond: e.value,
            status: FlowStatus.balanced,
          ),
        )
        .toList(),
    status: FlowStatus.balanced,
    hasWorkers: hasWorkers,
  );
}

void main() {
  test(
    'Multi-hop chain: A->B->C where B lacks inputs should not overstate C\'s production',
    () {
      // A produces wood (no inputs needed)
      // B needs wood to produce electricity
      // C needs electricity to produce planks
      // If B cannot produce electricity, C should not be able to produce planks

      final nodes = [
        // Field: produces 1.0 wood/s, no inputs
        _createNode('field_A', {}, {ResourceType.wood: 1.0}),

        // Windmill: needs 2.0 wood/s to produce 1.0 electricity/s
        // But only 1.0 wood/s is available, so cannot produce
        _createNode(
          'windmill_B',
          {ResourceType.wood: 2.0},
          {ResourceType.electricity: 1.0},
        ),

        // Sawmill: needs 1.0 electricity/s to produce 1.0 planks/s
        // Should not be able to produce since electricity is not available
        _createNode(
          'sawmill_C',
          {ResourceType.electricity: 1.0},
          {ResourceType.planks: 1.0},
        ),
      ];

      final graph = ProductionGraph(
        id: 'test',
        generatedAt: DateTime.now(),
        nodes: nodes,
        edges: [],
        bottlenecks: [],
      );

      final analyzedGraph = FlowAnalyzer.analyzeGraph(graph);

      // Verify wood and electricity are in deficit
      expect(
        analyzedGraph.bottlenecks.any(
          (b) => b.resourceType == ResourceType.wood,
        ),
        isTrue,
      );
      expect(
        analyzedGraph.bottlenecks.any(
          (b) => b.resourceType == ResourceType.electricity,
        ),
        isTrue,
      );

      // Verify sawmill cannot produce
      final sawmill = analyzedGraph.nodes.firstWhere(
        (n) => n.id == 'sawmill_C',
      );
      expect(sawmill.status, equals(FlowStatus.deficit));

      // Verify there is NO planks bottleneck (because no one consumes planks)
      expect(
        analyzedGraph.bottlenecks.any(
          (b) => b.resourceType == ResourceType.planks,
        ),
        isFalse,
      );
    },
  );

  test('Multi-hop chain with actual downstream consumer', () {
    // Similar to above, but add a consumer for planks

    final nodes = [
      // Field: produces 1.0 wood/s, no inputs
      _createNode('field_A', {}, {ResourceType.wood: 1.0}),

      // Windmill: needs 2.0 wood/s to produce 1.0 electricity/s
      // But only 1.0 wood/s is available, so cannot produce
      _createNode(
        'windmill_B',
        {ResourceType.wood: 2.0},
        {ResourceType.electricity: 1.0},
      ),

      // Sawmill: needs 1.0 electricity/s to produce 1.0 planks/s
      // Should not be able to produce since electricity is not available
      _createNode(
        'sawmill_C',
        {ResourceType.electricity: 1.0},
        {ResourceType.planks: 1.0},
      ),

      // Furniture factory: needs 1.0 planks/s
      _createNode('factory_D', {ResourceType.planks: 1.0}, {}),
    ];

    final graph = ProductionGraph(
      id: 'test',
      generatedAt: DateTime.now(),
      nodes: nodes,
      edges: [],
      bottlenecks: [],
    );

    final analyzedGraph = FlowAnalyzer.analyzeGraph(graph);

    // All three resources should be in deficit:
    // - Wood: production=1.0, consumption=2.0 → deficit
    // - Electricity: production=0, consumption=1.0 → deficit
    // - Planks: production=0, consumption=1.0 → deficit

    final woodBottleneck = analyzedGraph.bottlenecks.any(
      (b) => b.resourceType == ResourceType.wood,
    );
    final electricityBottleneck = analyzedGraph.bottlenecks.any(
      (b) => b.resourceType == ResourceType.electricity,
    );
    final planksBottleneck = analyzedGraph.bottlenecks.any(
      (b) => b.resourceType == ResourceType.planks,
    );

    expect(woodBottleneck, isTrue);
    expect(electricityBottleneck, isTrue);

    // This should be true but might be false due to bug
    if (!planksBottleneck) {
      throw Exception('BUG: Planks should be in deficit but is not!');
    }
    expect(
      planksBottleneck,
      isTrue,
      reason: 'Planks should show deficit (production=0, demand=1.0)',
    );

    // Factory should show deficit
    final factory = analyzedGraph.nodes.firstWhere((n) => n.id == 'factory_D');
    expect(factory.status, equals(FlowStatus.deficit));
  });
}
