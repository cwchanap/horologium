/// Chain highlighting logic for tracing upstream and downstream dependencies.
library;

import 'package:horologium/game/production/production_graph.dart';

/// Represents a highlighted chain from a selected node.
class ChainHighlight {
  final String rootNodeId;
  final Set<String> upstreamNodeIds;
  final Set<String> downstreamNodeIds;
  final Set<String> edgeIds;

  const ChainHighlight({
    required this.rootNodeId,
    required this.upstreamNodeIds,
    required this.downstreamNodeIds,
    required this.edgeIds,
  });

  /// All node IDs in this chain (including root).
  Set<String> get allNodeIds => {
    rootNodeId,
    ...upstreamNodeIds,
    ...downstreamNodeIds,
  };
}

/// Finds connected chains using BFS traversal.
class ChainHighlighter {
  /// Find the complete connected chain for a selected node.
  ///
  /// Uses BFS to traverse:
  /// - Upstream: nodes that produce resources consumed by this node
  /// - Downstream: nodes that consume resources produced by this node
  static ChainHighlight findConnectedChain(
    String nodeId,
    List<BuildingNode> nodes,
    List<ResourceFlowEdge> edges,
  ) {
    final upstreamNodeIds = <String>{};
    final downstreamNodeIds = <String>{};
    final highlightedEdgeIds = <String>{};

    // Build adjacency maps for efficient lookup
    final incomingEdges = <String, List<ResourceFlowEdge>>{};
    final outgoingEdges = <String, List<ResourceFlowEdge>>{};

    for (final edge in edges) {
      incomingEdges.putIfAbsent(edge.consumerNodeId, () => []).add(edge);
      outgoingEdges.putIfAbsent(edge.producerNodeId, () => []).add(edge);
    }

    // BFS upstream (follow edges backward to producers)
    final upstreamQueue = <String>[nodeId];
    final visitedUpstream = <String>{nodeId};

    while (upstreamQueue.isNotEmpty) {
      final currentId = upstreamQueue.removeAt(0);
      final incoming = incomingEdges[currentId] ?? [];

      for (final edge in incoming) {
        highlightedEdgeIds.add(edge.id);

        if (!visitedUpstream.contains(edge.producerNodeId)) {
          visitedUpstream.add(edge.producerNodeId);
          upstreamNodeIds.add(edge.producerNodeId);
          upstreamQueue.add(edge.producerNodeId);
        }
      }
    }

    // BFS downstream (follow edges forward to consumers)
    final downstreamQueue = <String>[nodeId];
    final visitedDownstream = <String>{nodeId};

    while (downstreamQueue.isNotEmpty) {
      final currentId = downstreamQueue.removeAt(0);
      final outgoing = outgoingEdges[currentId] ?? [];

      for (final edge in outgoing) {
        highlightedEdgeIds.add(edge.id);

        if (!visitedDownstream.contains(edge.consumerNodeId)) {
          visitedDownstream.add(edge.consumerNodeId);
          downstreamNodeIds.add(edge.consumerNodeId);
          downstreamQueue.add(edge.consumerNodeId);
        }
      }
    }

    return ChainHighlight(
      rootNodeId: nodeId,
      upstreamNodeIds: upstreamNodeIds,
      downstreamNodeIds: downstreamNodeIds,
      edgeIds: highlightedEdgeIds,
    );
  }

  /// Apply chain highlight to a production graph.
  ///
  /// Returns a new graph with highlighted nodes and edges.
  static ProductionGraph applyHighlight(
    ProductionGraph graph,
    ChainHighlight highlight,
  ) {
    final highlightedNodes = graph.nodes.map((node) {
      return node.copyWith(
        isHighlighted: highlight.allNodeIds.contains(node.id),
        isSelected: node.id == highlight.rootNodeId,
      );
    }).toList();

    final highlightedEdges = graph.edges.map((edge) {
      return edge.copyWith(isHighlighted: highlight.edgeIds.contains(edge.id));
    }).toList();

    return ProductionGraph(
      id: graph.id,
      generatedAt: graph.generatedAt,
      nodes: highlightedNodes,
      edges: highlightedEdges,
      bottlenecks: graph.bottlenecks,
      isClustered: graph.isClustered,
    );
  }

  /// Clear all highlights from a production graph.
  static ProductionGraph clearHighlight(ProductionGraph graph) {
    final clearedNodes = graph.nodes.map((node) {
      return node.copyWith(isHighlighted: false, isSelected: false);
    }).toList();

    final clearedEdges = graph.edges.map((edge) {
      return edge.copyWith(isHighlighted: false);
    }).toList();

    return ProductionGraph(
      id: graph.id,
      generatedAt: graph.generatedAt,
      nodes: clearedNodes,
      edges: clearedEdges,
      bottlenecks: graph.bottlenecks,
      isClustered: graph.isClustered,
    );
  }
}
