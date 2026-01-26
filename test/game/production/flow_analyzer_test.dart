import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/flow_analyzer.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FlowAnalyzer.calculateFlowStatus', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'returns surplus when production exceeds consumption by more than 10%',
      () {
        final status = FlowAnalyzer.calculateFlowStatus(2.2, 1.0);
        expect(status, equals(FlowStatus.surplus));
      },
    );

    test('returns surplus when production is 111% of consumption', () {
      final status = FlowAnalyzer.calculateFlowStatus(1.11, 1.0);
      expect(status, equals(FlowStatus.surplus));
    });

    test('returns balanced when production equals consumption', () {
      final status = FlowAnalyzer.calculateFlowStatus(1.0, 1.0);
      expect(status, equals(FlowStatus.balanced));
    });

    test('returns balanced when production is within 10% tolerance', () {
      // 95% of consumption - still balanced
      final status1 = FlowAnalyzer.calculateFlowStatus(0.95, 1.0);
      expect(status1, equals(FlowStatus.balanced));

      // 105% of consumption - still balanced
      final status2 = FlowAnalyzer.calculateFlowStatus(1.05, 1.0);
      expect(status2, equals(FlowStatus.balanced));
    });

    test('returns deficit when production is less than 90% of consumption', () {
      final status = FlowAnalyzer.calculateFlowStatus(0.5, 1.0);
      expect(status, equals(FlowStatus.deficit));
    });

    test('returns deficit at exactly 89% production', () {
      final status = FlowAnalyzer.calculateFlowStatus(0.89, 1.0);
      expect(status, equals(FlowStatus.deficit));
    });

    test('returns surplus when no consumption', () {
      final status = FlowAnalyzer.calculateFlowStatus(1.0, 0.0);
      expect(status, equals(FlowStatus.surplus));
    });

    test('returns balanced when both production and consumption are zero', () {
      final status = FlowAnalyzer.calculateFlowStatus(0.0, 0.0);
      expect(status, equals(FlowStatus.balanced));
    });
  });

  group('FlowAnalyzer.detectBottlenecks', () {
    test('detects deficit resources as bottlenecks', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 0.5}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final edges = <ResourceFlowEdge>[];

      final bottlenecks = FlowAnalyzer.detectBottlenecks(nodes, edges);

      expect(bottlenecks.length, equals(1));
      expect(bottlenecks[0].resourceType, equals(ResourceType.coal));
      expect(
        bottlenecks[0].severity,
        isIn([
          BottleneckSeverity.low,
          BottleneckSeverity.medium,
          BottleneckSeverity.high,
        ]),
      );
    });

    test('severity is high when deficit exceeds 50%', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 0.3}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final edges = <ResourceFlowEdge>[];

      final bottlenecks = FlowAnalyzer.detectBottlenecks(nodes, edges);

      expect(bottlenecks[0].severity, equals(BottleneckSeverity.high));
    });

    test('severity is medium when deficit is 25-50%', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 0.6}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final edges = <ResourceFlowEdge>[];

      final bottlenecks = FlowAnalyzer.detectBottlenecks(nodes, edges);

      expect(bottlenecks[0].severity, equals(BottleneckSeverity.medium));
    });

    test('severity is low when deficit is 10-25%', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 0.8}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final edges = <ResourceFlowEdge>[];

      final bottlenecks = FlowAnalyzer.detectBottlenecks(nodes, edges);

      expect(bottlenecks[0].severity, equals(BottleneckSeverity.low));
    });

    test('no bottlenecks when production meets demand', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 1.0}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final edges = <ResourceFlowEdge>[];

      final bottlenecks = FlowAnalyzer.detectBottlenecks(nodes, edges);

      expect(bottlenecks.isEmpty, isTrue);
    });

    test('generates recommendation for adding producers', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 0.5}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final edges = <ResourceFlowEdge>[];

      final bottlenecks = FlowAnalyzer.detectBottlenecks(nodes, edges);

      expect(bottlenecks[0].recommendation, contains('producer'));
    });

    test('handles multiple resource types independently', () {
      final nodes = [
        _createNode('producer1', {}, {ResourceType.coal: 0.5}),
        _createNode('producer2', {}, {ResourceType.electricity: 2.0}),
        _createNode('consumer', {
          ResourceType.coal: 1.0,
          ResourceType.electricity: 1.0,
        }, {}),
      ];
      final edges = <ResourceFlowEdge>[];

      final bottlenecks = FlowAnalyzer.detectBottlenecks(nodes, edges);

      // Coal has deficit (0.5 vs 1.0), electricity has surplus (2.0 vs 1.0)
      expect(bottlenecks.length, equals(1));
      expect(bottlenecks[0].resourceType, equals(ResourceType.coal));
    });
  });

  group('FlowAnalyzer.analyzeGraph', () {
    test(
      'updates consumer node status to deficit when resource is in deficit',
      () {
        final nodes = [
          _createNode('producer', {}, {ResourceType.coal: 0.5}),
          _createNode('consumer', {ResourceType.coal: 1.0}, {}),
        ];
        final edges = [
          ResourceFlowEdge(
            id: 'edge1',
            resourceType: ResourceType.coal,
            producerNodeId: 'producer',
            consumerNodeId: 'consumer',
            ratePerSecond: 0.5,
            status: FlowStatus.balanced,
          ),
        ];
        final graph = ProductionGraph(
          id: 'test',
          generatedAt: DateTime.now(),
          nodes: nodes,
          edges: edges,
          bottlenecks: [],
        );

        final analyzedGraph = FlowAnalyzer.analyzeGraph(graph);

        // Consumer shows deficit because its input resource (coal) is in deficit
        final consumer = analyzedGraph.nodes.firstWhere(
          (n) => n.id == 'consumer',
        );
        expect(consumer.status, equals(FlowStatus.deficit));
      },
    );

    test('detects and adds bottlenecks to graph', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 0.3}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final graph = ProductionGraph(
        id: 'test',
        generatedAt: DateTime.now(),
        nodes: nodes,
        edges: [],
        bottlenecks: [],
      );

      final analyzedGraph = FlowAnalyzer.analyzeGraph(graph);

      expect(analyzedGraph.bottlenecks.isNotEmpty, isTrue);
      expect(
        analyzedGraph.bottlenecks.first.resourceType,
        equals(ResourceType.coal),
      );
    });

    test('updates edge status based on flow balance', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 0.5}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final edges = [
        ResourceFlowEdge(
          id: 'edge1',
          resourceType: ResourceType.coal,
          producerNodeId: 'producer',
          consumerNodeId: 'consumer',
          ratePerSecond: 0.5,
          status: FlowStatus.balanced,
        ),
      ];
      final graph = ProductionGraph(
        id: 'test',
        generatedAt: DateTime.now(),
        nodes: nodes,
        edges: edges,
        bottlenecks: [],
      );

      final analyzedGraph = FlowAnalyzer.analyzeGraph(graph);

      // Edge should show deficit since production < consumption
      expect(analyzedGraph.edges.first.status, equals(FlowStatus.deficit));
    });

    test('producer node stays balanced when it has no inputs', () {
      final nodes = [
        _createNode('producer', {}, {ResourceType.coal: 2.0}),
        _createNode('consumer', {ResourceType.coal: 1.0}, {}),
      ];
      final graph = ProductionGraph(
        id: 'test',
        generatedAt: DateTime.now(),
        nodes: nodes,
        edges: [],
        bottlenecks: [],
      );

      final analyzedGraph = FlowAnalyzer.analyzeGraph(graph);

      // Producer stays balanced - it has no inputs to evaluate
      final producer = analyzedGraph.nodes.firstWhere(
        (n) => n.id == 'producer',
      );
      expect(producer.status, equals(FlowStatus.balanced));
    });
  });
}

BuildingNode _createNode(
  String id,
  Map<ResourceType, double> inputs,
  Map<ResourceType, double> outputs,
) {
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
    hasWorkers: true,
  );
}
