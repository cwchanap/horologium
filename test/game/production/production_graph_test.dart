import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/chain_highlighter.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ProductionGraph', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('fromBuildings creates nodes for each building', () {
      final buildings = [
        _createMockBuilding(
          type: BuildingType.coalMine,
          category: BuildingCategory.rawMaterials,
          generation: {'coal': 1.0},
          consumption: {},
        ),
        _createMockBuilding(
          type: BuildingType.powerPlant,
          category: BuildingCategory.processing,
          generation: {'electricity': 2.0},
          consumption: {'coal': 0.5},
        ),
      ];
      final resources = Resources();

      final graph = ProductionGraph.fromBuildings(buildings, resources);

      expect(graph.nodes.length, equals(2));
      expect(graph.nodes[0].name, equals('Coal Mine'));
      expect(graph.nodes[1].name, equals('Power Plant'));
    });

    test('fromBuildings creates edges for resource dependencies', () {
      final buildings = [
        _createMockBuilding(
          type: BuildingType.coalMine,
          category: BuildingCategory.rawMaterials,
          generation: {'coal': 1.0},
          consumption: {},
        ),
        _createMockBuilding(
          type: BuildingType.powerPlant,
          category: BuildingCategory.processing,
          generation: {'electricity': 2.0},
          consumption: {'coal': 0.5},
        ),
      ];
      final resources = Resources();

      final graph = ProductionGraph.fromBuildings(buildings, resources);

      expect(graph.edges.length, equals(1));
      expect(graph.edges[0].resourceType, equals(ResourceType.coal));
    });

    test('isEmpty returns true for empty buildings list', () {
      final graph = ProductionGraph.fromBuildings([], Resources());
      expect(graph.isEmpty, isTrue);
    });

    test('isClustered is true when nodes exceed 50', () {
      // Create 51 buildings
      final buildings = List.generate(
        51,
        (i) => _createMockBuilding(
          type: BuildingType.house,
          category: BuildingCategory.residential,
        ),
      );

      final graph = ProductionGraph.fromBuildings(buildings, Resources());

      expect(graph.isClustered, isTrue);
    });
  });

  group('ChainHighlighter', () {
    test('findConnectedChain returns upstream and downstream nodes', () {
      final nodes = [
        _createBuildingNode('producer', 'Coal Mine', [], [ResourceType.coal]),
        _createBuildingNode(
          'consumer',
          'Power Plant',
          [ResourceType.coal],
          [ResourceType.electricity],
        ),
        _createBuildingNode('final', 'Factory', [ResourceType.electricity], []),
      ];

      final edges = [
        ResourceFlowEdge(
          id: 'edge1',
          resourceType: ResourceType.coal,
          producerNodeId: 'producer',
          consumerNodeId: 'consumer',
          ratePerSecond: 1.0,
          status: FlowStatus.balanced,
        ),
        ResourceFlowEdge(
          id: 'edge2',
          resourceType: ResourceType.electricity,
          producerNodeId: 'consumer',
          consumerNodeId: 'final',
          ratePerSecond: 2.0,
          status: FlowStatus.balanced,
        ),
      ];

      final highlight = ChainHighlighter.findConnectedChain(
        'consumer',
        nodes,
        edges,
      );

      expect(highlight.rootNodeId, equals('consumer'));
      expect(highlight.upstreamNodeIds, contains('producer'));
      expect(highlight.downstreamNodeIds, contains('final'));
      expect(highlight.edgeIds.length, equals(2));
    });
  });

  group('NodeCluster', () {
    test('createClusters returns empty list when nodes <= 50', () {
      final nodes = List.generate(
        50,
        (i) => _createBuildingNode('node_$i', 'Node $i', [], []),
      );

      final clusters = ProductionGraph.createClusters(nodes);

      expect(clusters.isEmpty, isTrue);
    });

    test('createClusters groups nodes by category when > 50 nodes', () {
      // Create 51 nodes with different categories
      final nodes = <BuildingNode>[];
      for (var i = 0; i < 30; i++) {
        nodes.add(
          BuildingNode(
            id: 'residential_$i',
            name: 'House $i',
            type: BuildingType.house,
            category: BuildingCategory.residential,
            inputs: [],
            outputs: [],
            status: FlowStatus.balanced,
            hasWorkers: true,
          ),
        );
      }
      for (var i = 0; i < 21; i++) {
        nodes.add(
          BuildingNode(
            id: 'processing_$i',
            name: 'Factory $i',
            type: BuildingType.powerPlant,
            category: BuildingCategory.processing,
            inputs: [],
            outputs: [],
            status: FlowStatus.balanced,
            hasWorkers: true,
          ),
        );
      }

      final clusters = ProductionGraph.createClusters(nodes);

      expect(clusters.length, equals(2));
      final residentialCluster = clusters.firstWhere(
        (c) => c.category == BuildingCategory.residential,
      );
      final processingCluster = clusters.firstWhere(
        (c) => c.category == BuildingCategory.processing,
      );
      expect(residentialCluster.nodeCount, equals(30));
      expect(processingCluster.nodeCount, equals(21));
    });

    test(
      'createClusters calculates aggregate status as deficit if any node has deficit',
      () {
        final nodes = <BuildingNode>[];
        for (var i = 0; i < 51; i++) {
          nodes.add(
            BuildingNode(
              id: 'node_$i',
              name: 'Node $i',
              type: BuildingType.house,
              category: BuildingCategory.residential,
              inputs: [],
              outputs: [],
              status: i == 25 ? FlowStatus.deficit : FlowStatus.balanced,
              hasWorkers: true,
            ),
          );
        }

        final clusters = ProductionGraph.createClusters(nodes);

        expect(clusters.first.aggregateStatus, equals(FlowStatus.deficit));
      },
    );

    test(
      'createClusters calculates aggregate status as surplus if no deficit',
      () {
        final nodes = <BuildingNode>[];
        for (var i = 0; i < 51; i++) {
          nodes.add(
            BuildingNode(
              id: 'node_$i',
              name: 'Node $i',
              type: BuildingType.house,
              category: BuildingCategory.residential,
              inputs: [],
              outputs: [],
              status: i == 25 ? FlowStatus.surplus : FlowStatus.balanced,
              hasWorkers: true,
            ),
          );
        }

        final clusters = ProductionGraph.createClusters(nodes);

        expect(clusters.first.aggregateStatus, equals(FlowStatus.surplus));
      },
    );
  });

  group('ChainHighlighter.applyHighlight', () {
    test('marks root node as selected', () {
      final nodes = [
        _createBuildingNode('node1', 'Node 1', [], [ResourceType.coal]),
        _createBuildingNode('node2', 'Node 2', [ResourceType.coal], []),
      ];
      final edges = [
        ResourceFlowEdge(
          id: 'edge1',
          resourceType: ResourceType.coal,
          producerNodeId: 'node1',
          consumerNodeId: 'node2',
          ratePerSecond: 1.0,
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

      final highlight = ChainHighlight(
        rootNodeId: 'node1',
        upstreamNodeIds: {},
        downstreamNodeIds: {'node2'},
        edgeIds: {'edge1'},
      );

      final highlightedGraph = ChainHighlighter.applyHighlight(
        graph,
        highlight,
      );

      final node1 = highlightedGraph.nodes.firstWhere((n) => n.id == 'node1');
      expect(node1.isSelected, isTrue);
      expect(node1.isHighlighted, isTrue);
    });

    test('marks connected nodes as highlighted', () {
      final nodes = [
        _createBuildingNode('node1', 'Node 1', [], [ResourceType.coal]),
        _createBuildingNode('node2', 'Node 2', [ResourceType.coal], []),
      ];
      final edges = [
        ResourceFlowEdge(
          id: 'edge1',
          resourceType: ResourceType.coal,
          producerNodeId: 'node1',
          consumerNodeId: 'node2',
          ratePerSecond: 1.0,
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

      final highlight = ChainHighlight(
        rootNodeId: 'node1',
        upstreamNodeIds: {},
        downstreamNodeIds: {'node2'},
        edgeIds: {'edge1'},
      );

      final highlightedGraph = ChainHighlighter.applyHighlight(
        graph,
        highlight,
      );

      final node2 = highlightedGraph.nodes.firstWhere((n) => n.id == 'node2');
      expect(node2.isHighlighted, isTrue);
    });

    test('marks connected edges as highlighted', () {
      final nodes = [
        _createBuildingNode('node1', 'Node 1', [], [ResourceType.coal]),
        _createBuildingNode('node2', 'Node 2', [ResourceType.coal], []),
      ];
      final edges = [
        ResourceFlowEdge(
          id: 'edge1',
          resourceType: ResourceType.coal,
          producerNodeId: 'node1',
          consumerNodeId: 'node2',
          ratePerSecond: 1.0,
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

      final highlight = ChainHighlight(
        rootNodeId: 'node1',
        upstreamNodeIds: {},
        downstreamNodeIds: {'node2'},
        edgeIds: {'edge1'},
      );

      final highlightedGraph = ChainHighlighter.applyHighlight(
        graph,
        highlight,
      );

      expect(highlightedGraph.edges.first.isHighlighted, isTrue);
    });
  });

  group('ChainHighlighter.clearHighlight', () {
    test('clears all selection and highlight state', () {
      final nodes = [
        BuildingNode(
          id: 'node1',
          name: 'Node 1',
          type: BuildingType.house,
          category: BuildingCategory.residential,
          inputs: [],
          outputs: [],
          status: FlowStatus.balanced,
          hasWorkers: true,
          isSelected: true,
          isHighlighted: true,
        ),
      ];
      final edges = [
        ResourceFlowEdge(
          id: 'edge1',
          resourceType: ResourceType.coal,
          producerNodeId: 'node1',
          consumerNodeId: 'node1',
          ratePerSecond: 1.0,
          status: FlowStatus.balanced,
          isHighlighted: true,
        ),
      ];
      final graph = ProductionGraph(
        id: 'test',
        generatedAt: DateTime.now(),
        nodes: nodes,
        edges: edges,
        bottlenecks: [],
      );

      final clearedGraph = ChainHighlighter.clearHighlight(graph);

      expect(clearedGraph.nodes.first.isSelected, isFalse);
      expect(clearedGraph.nodes.first.isHighlighted, isFalse);
      expect(clearedGraph.edges.first.isHighlighted, isFalse);
    });
  });

  group('ChainHighlight.allNodeIds', () {
    test('includes root, upstream, and downstream node IDs', () {
      final highlight = ChainHighlight(
        rootNodeId: 'root',
        upstreamNodeIds: {'up1', 'up2'},
        downstreamNodeIds: {'down1'},
        edgeIds: {},
      );

      expect(
        highlight.allNodeIds,
        containsAll(['root', 'up1', 'up2', 'down1']),
      );
      expect(highlight.allNodeIds.length, equals(4));
    });
  });
}

Building _createMockBuilding({
  required BuildingType type,
  required BuildingCategory category,
  Map<String, double> generation = const {},
  Map<String, double> consumption = const {},
}) {
  return Building(
    type: type,
    name: type.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .trim()
        .split(' ')
        .map(
          (w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : '',
        )
        .join(' '),
    description: 'Test building',
    icon: Icons.home,
    assetPath: '',
    color: Colors.blue,
    baseCost: 100,
    baseGeneration: generation,
    baseConsumption: consumption,
    requiredWorkers: 1,
    category: category,
  );
}

BuildingNode _createBuildingNode(
  String id,
  String name,
  List<ResourceType> inputs,
  List<ResourceType> outputs,
) {
  return BuildingNode(
    id: id,
    name: name,
    type: BuildingType.house,
    category: BuildingCategory.residential,
    inputs: inputs
        .map(
          (r) => ResourcePort(
            resourceType: r,
            ratePerSecond: 1.0,
            status: FlowStatus.balanced,
          ),
        )
        .toList(),
    outputs: outputs
        .map(
          (r) => ResourcePort(
            resourceType: r,
            ratePerSecond: 1.0,
            status: FlowStatus.balanced,
          ),
        )
        .toList(),
    status: FlowStatus.balanced,
    hasWorkers: true,
  );
}
