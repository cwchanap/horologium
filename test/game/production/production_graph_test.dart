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

      // 1 normal edge (coal) + 1 incomplete producer edge (electricity has no consumer)
      expect(graph.edges.length, equals(2));
      final normalEdges = graph.edges.where((e) => !e.isIncomplete).toList();
      expect(normalEdges.length, equals(1));
      expect(normalEdges[0].resourceType, equals(ResourceType.coal));
    });

    test(
      'fromBuildings uses level-scaled rates for generation and consumption',
      () {
        final producer = _createMockBuilding(
          type: BuildingType.coalMine,
          category: BuildingCategory.rawMaterials,
          generation: {'coal': 1.0},
        )..level = 3;
        final consumer = _createMockBuilding(
          type: BuildingType.powerPlant,
          category: BuildingCategory.processing,
          consumption: {'coal': 0.5},
        )..level = 2;

        final graph = ProductionGraph.fromBuildings([
          producer,
          consumer,
        ], Resources());

        final producerNode = graph.nodes.firstWhere(
          (node) => node.type == BuildingType.coalMine,
        );
        final consumerNode = graph.nodes.firstWhere(
          (node) => node.type == BuildingType.powerPlant,
        );

        expect(producerNode.outputs.first.ratePerSecond, equals(3.0));
        expect(consumerNode.inputs.first.ratePerSecond, equals(1.0));
      },
    );

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

    test('fromBuildings throws ArgumentError for unknown resource type', () {
      final buildings = [
        _createMockBuilding(
          type: BuildingType.house,
          category: BuildingCategory.residential,
          generation: {'unknownResource': 1.0},
        ),
      ];

      expect(
        () => ProductionGraph.fromBuildings(buildings, Resources()),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Unknown resource type "unknownResource"'),
          ),
        ),
      );
    });

    test(
      'fromBuildings creates incomplete edge when consumer has no producer',
      () {
        // Power plant consumes coal but no coal mine exists
        final buildings = [
          _createMockBuilding(
            type: BuildingType.powerPlant,
            category: BuildingCategory.processing,
            generation: {'electricity': 2.0},
            consumption: {'coal': 0.5},
          ),
        ];
        final resources = Resources();

        final graph = ProductionGraph.fromBuildings(buildings, resources);

        expect(graph.nodes.length, equals(1));
        // Should have incomplete edges: coal (no producer, deficit) + electricity (no consumer, surplus)
        final incompleteEdges = graph.edges
            .where((e) => e.isIncomplete)
            .toList();
        expect(incompleteEdges.length, equals(2));
        final coalEdge = incompleteEdges.firstWhere(
          (e) => e.resourceType == ResourceType.coal,
        );
        expect(coalEdge.status, equals(FlowStatus.deficit));
        expect(coalEdge.ratePerSecond, equals(0));
        final elecEdge = incompleteEdges.firstWhere(
          (e) => e.resourceType == ResourceType.electricity,
        );
        expect(elecEdge.status, equals(FlowStatus.surplus));
      },
    );

    test(
      'fromBuildings does not create incomplete edge when producer exists',
      () {
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

        final incompleteEdges = graph.edges
            .where((e) => e.isIncomplete)
            .toList();
        // Coal edge is complete (producer exists), but electricity has no consumer
        expect(
          incompleteEdges.length,
          equals(1),
          reason: 'Only electricity should be incomplete (no consumer)',
        );
        expect(
          incompleteEdges[0].resourceType,
          equals(ResourceType.electricity),
        );
        expect(incompleteEdges[0].status, equals(FlowStatus.surplus));
        // Should have one normal edge for coal
        final normalEdges = graph.edges.where((e) => !e.isIncomplete).toList();
        expect(normalEdges.length, equals(1));
        expect(normalEdges[0].resourceType, equals(ResourceType.coal));
      },
    );

    test(
      'fromBuildings creates incomplete edge for producer-only resource',
      () {
        // Coal mine produces coal but nothing consumes it
        final buildings = [
          _createMockBuilding(
            type: BuildingType.coalMine,
            category: BuildingCategory.rawMaterials,
            generation: {'coal': 1.0},
            consumption: {},
          ),
        ];
        final resources = Resources();

        final graph = ProductionGraph.fromBuildings(buildings, resources);

        expect(graph.nodes.length, equals(1));
        final incompleteEdges = graph.edges
            .where((e) => e.isIncomplete)
            .toList();
        expect(incompleteEdges.length, equals(1));
        expect(incompleteEdges[0].resourceType, equals(ResourceType.coal));
        expect(incompleteEdges[0].status, equals(FlowStatus.surplus));
        expect(incompleteEdges[0].ratePerSecond, equals(1.0));
        expect(incompleteEdges[0].producerNodeId, equals('coalMine_L1_0'));
      },
    );

    test(
      'fromBuildings does not create producer incomplete edge when consumer exists',
      () {
        // Coal mine produces coal, power plant consumes it
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
            generation: {},
            consumption: {'coal': 0.5},
          ),
        ];
        final resources = Resources();

        final graph = ProductionGraph.fromBuildings(buildings, resources);

        // Coal has a consumer, so no incomplete producer edge for coal
        final coalIncomplete = graph.edges.where(
          (e) =>
              e.isIncomplete &&
              e.resourceType == ResourceType.coal &&
              e.status == FlowStatus.surplus,
        );
        expect(coalIncomplete, isEmpty);
      },
    );

    test(
      'fromBuildings throws ArgumentError for unknown consumption resource',
      () {
        final buildings = [
          _createMockBuilding(
            type: BuildingType.powerPlant,
            category: BuildingCategory.processing,
            consumption: {'invalidFuel': 0.5},
          ),
        ];

        expect(
          () => ProductionGraph.fromBuildings(buildings, Resources()),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unknown resource type "invalidFuel"'),
            ),
          ),
        );
      },
    );
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

    test(
      'findConnectedChain handles circular dependencies without infinite loop',
      () {
        final nodes = [
          _createBuildingNode(
            'nodeA',
            'Building A',
            [ResourceType.electricity],
            [ResourceType.coal],
          ),
          _createBuildingNode(
            'nodeB',
            'Building B',
            [ResourceType.coal],
            [ResourceType.electricity],
          ),
        ];

        final edges = [
          ResourceFlowEdge(
            id: 'edge1',
            resourceType: ResourceType.coal,
            producerNodeId: 'nodeA',
            consumerNodeId: 'nodeB',
            ratePerSecond: 1.0,
            status: FlowStatus.balanced,
          ),
          ResourceFlowEdge(
            id: 'edge2',
            resourceType: ResourceType.electricity,
            producerNodeId: 'nodeB',
            consumerNodeId: 'nodeA',
            ratePerSecond: 1.0,
            status: FlowStatus.balanced,
          ),
        ];

        // Should complete without hanging
        final highlight = ChainHighlighter.findConnectedChain(
          'nodeA',
          nodes,
          edges,
        );

        expect(highlight.allNodeIds, containsAll(['nodeA', 'nodeB']));
        expect(highlight.edgeIds, containsAll(['edge1', 'edge2']));
      },
    );

    test('findConnectedChain returns only root node when no edges exist', () {
      final nodes = [
        _createBuildingNode('isolatedNode', 'Isolated', [], [
          ResourceType.population,
        ]),
      ];

      final highlight = ChainHighlighter.findConnectedChain(
        'isolatedNode',
        nodes,
        [],
      );

      expect(highlight.rootNodeId, equals('isolatedNode'));
      expect(highlight.upstreamNodeIds, isEmpty);
      expect(highlight.downstreamNodeIds, isEmpty);
      expect(highlight.edgeIds, isEmpty);
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

  group('ChainHighlighter clear after apply', () {
    test('clearHighlight resets all flags after applyHighlight', () {
      final nodes = [
        _createBuildingNode('node1', 'Node 1', [], [ResourceType.coal]),
        _createBuildingNode(
          'node2',
          'Node 2',
          [ResourceType.coal],
          [ResourceType.electricity],
        ),
        _createBuildingNode('node3', 'Node 3', [ResourceType.electricity], []),
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
        ResourceFlowEdge(
          id: 'edge2',
          resourceType: ResourceType.electricity,
          producerNodeId: 'node2',
          consumerNodeId: 'node3',
          ratePerSecond: 2.0,
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

      // Apply highlight on node1's chain
      final highlight = ChainHighlighter.findConnectedChain(
        'node1',
        nodes,
        edges,
      );
      final highlighted = ChainHighlighter.applyHighlight(graph, highlight);

      // Verify highlight was applied
      expect(
        highlighted.nodes.firstWhere((n) => n.id == 'node1').isSelected,
        isTrue,
      );
      expect(
        highlighted.nodes.firstWhere((n) => n.id == 'node2').isHighlighted,
        isTrue,
      );

      // Clear highlight (simulates single-tap on a different node)
      final cleared = ChainHighlighter.clearHighlight(highlighted);

      // Verify all flags are reset
      for (final node in cleared.nodes) {
        expect(node.isSelected, isFalse, reason: '${node.id} isSelected');
        expect(node.isHighlighted, isFalse, reason: '${node.id} isHighlighted');
      }
      for (final edge in cleared.edges) {
        expect(edge.isHighlighted, isFalse, reason: '${edge.id} isHighlighted');
      }
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
