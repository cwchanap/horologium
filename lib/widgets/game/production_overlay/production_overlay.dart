/// Main production chain overlay widget.
///
/// Provides a full-screen overlay displaying the production graph
/// with nodes, edges, and interactive features.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/chain_highlighter.dart';
import 'package:horologium/game/production/flow_analyzer.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/widgets/game/production_overlay/building_node.dart';
import 'package:horologium/widgets/game/production_overlay/cluster_node.dart';
import 'package:horologium/widgets/game/production_overlay/empty_state.dart';
import 'package:horologium/widgets/game/production_overlay/node_detail_panel.dart';
import 'package:horologium/widgets/game/production_overlay/resource_filter.dart';
import 'package:horologium/widgets/game/production_overlay/resource_flow_edge.dart';
import 'package:horologium/widgets/game/production_overlay/production_theme.dart';

/// Callback to get current buildings.
typedef GetBuildings = List<Building> Function();

/// Callback to get current resources.
typedef GetResources = Resources Function();

/// Production chain overlay displaying resource flows between buildings.
class ProductionOverlay extends StatefulWidget {
  final GetBuildings getBuildings;
  final GetResources getResources;
  final VoidCallback onClose;
  final VoidCallback? onBuildingsChanged;

  const ProductionOverlay({
    super.key,
    required this.getBuildings,
    required this.getResources,
    required this.onClose,
    this.onBuildingsChanged,
  });

  @override
  State<ProductionOverlay> createState() => _ProductionOverlayState();
}

class _ProductionOverlayState extends State<ProductionOverlay> {
  ProductionGraph? _graph;
  BuildingNode? _selectedNode;
  ChainHighlight? _chainHighlight;
  ResourceType? _activeFilter;
  Timer? _refreshDebounce;
  Timer? _autoRefreshTimer;
  int _lastBuildingCount = 0;
  List<NodeCluster> _clusters = [];
  final Set<String> _expandedClusterIds = {};

  // Layout constants
  static const double _horizontalSpacing = 180;
  static const double _verticalSpacing = 100;

  @override
  void initState() {
    super.initState();
    _lastBuildingCount = widget.getBuildings().length;
    _buildGraph();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Start periodic check for building changes (every 1 second).
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final currentCount = widget.getBuildings().length;
      if (currentCount != _lastBuildingCount) {
        _lastBuildingCount = currentCount;
        _scheduleRefresh();
        // Notify external listeners of building changes
        widget.onBuildingsChanged?.call();
      }
    });
  }

  void _buildGraph() {
    final buildings = widget.getBuildings();
    final resources = widget.getResources();

    var graph = ProductionGraph.fromBuildings(buildings, resources);
    graph = FlowAnalyzer.analyzeGraph(graph);
    graph = _applyLayout(graph);

    if (_activeFilter != null) {
      graph = _applyFilter(graph, _activeFilter!);
    }

    // Create clusters for large graphs
    var clusters = graph.isClustered
        ? ProductionGraph.createClusters(graph.nodes)
        : <NodeCluster>[];

    // Apply layout to clusters
    if (clusters.isNotEmpty) {
      double xOffset = 50;
      clusters = clusters.map((cluster) {
        final positioned = cluster.copyWith(position: Offset(xOffset, 100));
        xOffset += _horizontalSpacing;
        return positioned;
      }).toList();
    }

    setState(() {
      _graph = graph;
      _clusters = clusters;
    });
  }

  /// Apply left-to-right layout grouped by BuildingCategory.
  ProductionGraph _applyLayout(ProductionGraph graph) {
    if (graph.nodes.isEmpty) return graph;

    // Group nodes by category
    final categoryGroups = <BuildingCategory, List<BuildingNode>>{};
    for (final node in graph.nodes) {
      categoryGroups.putIfAbsent(node.category, () => []).add(node);
    }

    // Layout order: raw materials -> primary factory -> processing -> refinement -> food -> residential -> services
    final categoryOrder = [
      BuildingCategory.rawMaterials,
      BuildingCategory.primaryFactory,
      BuildingCategory.processing,
      BuildingCategory.refinement,
      BuildingCategory.foodResources,
      BuildingCategory.residential,
      BuildingCategory.services,
    ];

    // Find categories not in the predefined order
    final remainingCategories = categoryGroups.keys
        .where((c) => !categoryOrder.contains(c))
        .toList();

    final updatedNodes = <BuildingNode>[];
    double xOffset = 50;

    // Layout nodes in predefined category order
    for (final category in categoryOrder) {
      final nodesInCategory = categoryGroups[category] ?? [];
      if (nodesInCategory.isEmpty) continue;

      double yOffset = 50;
      for (final node in nodesInCategory) {
        updatedNodes.add(node.copyWith(position: Offset(xOffset, yOffset)));
        yOffset += _verticalSpacing;
      }

      xOffset += _horizontalSpacing;
    }

    // Layout remaining categories not in predefined order
    for (final category in remainingCategories) {
      final nodesInCategory = categoryGroups[category] ?? [];
      if (nodesInCategory.isEmpty) continue;

      double yOffset = 50;
      for (final node in nodesInCategory) {
        updatedNodes.add(node.copyWith(position: Offset(xOffset, yOffset)));
        yOffset += _verticalSpacing;
      }

      xOffset += _horizontalSpacing;
    }

    return ProductionGraph(
      id: graph.id,
      generatedAt: graph.generatedAt,
      nodes: updatedNodes,
      edges: graph.edges,
      bottlenecks: graph.bottlenecks,
    );
  }

  /// Apply resource filter to show only relevant nodes and edges.
  ProductionGraph _applyFilter(ProductionGraph graph, ResourceType filter) {
    final relevantNodeIds = <String>{};

    // Find nodes that produce or consume the filtered resource
    for (final node in graph.nodes) {
      final producesResource = node.outputs.any(
        (o) => o.resourceType == filter,
      );
      final consumesResource = node.inputs.any((i) => i.resourceType == filter);

      if (producesResource || consumesResource) {
        relevantNodeIds.add(node.id);
      }
    }

    final filteredNodes = graph.nodes
        .where((n) => relevantNodeIds.contains(n.id))
        .toList();

    final filteredEdges = graph.edges
        .where((e) => e.resourceType == filter)
        .toList();

    return ProductionGraph(
      id: graph.id,
      generatedAt: graph.generatedAt,
      nodes: filteredNodes,
      edges: filteredEdges,
      bottlenecks: graph.bottlenecks
          .where((b) => b.resourceType == filter)
          .toList(),
    );
  }

  void _onFilterChanged(ResourceType? filter) {
    setState(() {
      _activeFilter = filter;
      _selectedNode = null;
      _chainHighlight = null;
    });
    _buildGraph();
  }

  void _onNodeTap(BuildingNode node) {
    setState(() {
      _selectedNode = node;
      _chainHighlight = null;
    });
  }

  void _onNodeDoubleTap(BuildingNode node) {
    if (_graph == null) {
      debugPrint('Warning: Double-tap on node ${node.id} but graph is null');
      return;
    }

    final highlight = ChainHighlighter.findConnectedChain(
      node.id,
      _graph!.nodes,
      _graph!.edges,
    );

    setState(() {
      _selectedNode = node;
      _chainHighlight = highlight;
      _graph = ChainHighlighter.applyHighlight(_graph!, highlight);
    });
  }

  void _onBackgroundTap() {
    if (_graph == null) {
      debugPrint('Warning: Background tap but graph is null');
      return;
    }

    setState(() {
      _selectedNode = null;
      _chainHighlight = null;
      _graph = ChainHighlighter.clearHighlight(_graph!);
    });
  }

  void _onClusterTap(NodeCluster cluster) {
    setState(() {
      if (_expandedClusterIds.contains(cluster.id)) {
        _expandedClusterIds.remove(cluster.id);
      } else {
        _expandedClusterIds.add(cluster.id);
      }
    });
  }

  /// Get visible nodes (all nodes if not clustered, or only expanded cluster nodes).
  List<BuildingNode> _getVisibleNodes() {
    if (_clusters.isEmpty || _graph == null) {
      return _graph?.nodes ?? [];
    }

    // If all clusters are collapsed, show no individual nodes
    if (_expandedClusterIds.isEmpty) {
      return [];
    }

    // Show nodes only from expanded clusters
    final expandedNodeIds = <String>{};
    for (final cluster in _clusters) {
      if (_expandedClusterIds.contains(cluster.id)) {
        expandedNodeIds.addAll(cluster.nodeIds);
      }
    }

    return _graph!.nodes
        .where((node) => expandedNodeIds.contains(node.id))
        .toList();
  }

  /// Debounced refresh when buildings change.
  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 1), () {
      _buildGraph();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useListView = screenWidth <= 320;

    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _graph == null || _graph!.isEmpty
                  ? const EmptyStateWidget()
                  : useListView
                  ? _buildListView()
                  : _buildGraphView(),
            ),
            if (_selectedNode != null) _buildDetailPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.cyanAccent.withAlpha(128)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: widget.onClose,
          ),
          const SizedBox(width: 8),
          const Text(
            'Production Chain',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          ResourceFilterWidget(
            selectedFilter: _activeFilter,
            onFilterChanged: _onFilterChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildGraphView() {
    final visibleNodes = _getVisibleNodes();
    final visibleNodeIds = visibleNodes.map((n) => n.id).toSet();

    // Filter edges to only show connections between visible nodes
    final visibleEdges = _graph!.edges
        .where(
          (e) =>
              visibleNodeIds.contains(e.producerNodeId) &&
              visibleNodeIds.contains(e.consumerNodeId),
        )
        .toList();

    return GestureDetector(
      onTap: _onBackgroundTap,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.5,
        maxScale: 3.0,
        child: CustomPaint(
          size: const Size(2000, 2000),
          painter: _ProductionGraphPainter(
            graph: _graph!,
            chainHighlight: _chainHighlight,
          ),
          child: Stack(
            children: [
              // Render clusters (when clustered and not all expanded)
              if (_clusters.isNotEmpty)
                for (final cluster in _clusters)
                  if (!_expandedClusterIds.contains(cluster.id))
                    Positioned(
                      left: cluster.position.dx,
                      top: cluster.position.dy,
                      child: ClusterNodeWidget(
                        cluster: cluster,
                        onTap: () => _onClusterTap(cluster),
                      ),
                    ),
              // Render edges (behind nodes)
              for (final edge in visibleEdges)
                Positioned(
                  left: _getEdgePosition(edge).dx,
                  top: _getEdgePosition(edge).dy,
                  child: ResourceFlowEdgeWidget(
                    edge: edge,
                    startNode: _findNode(edge.producerNodeId),
                    endNode: _findNode(edge.consumerNodeId),
                  ),
                ),
              // Render visible nodes
              for (final node in visibleNodes)
                Positioned(
                  left: node.position.dx,
                  top: node.position.dy,
                  child: BuildingNodeWidget(
                    node: node,
                    onTap: () => _onNodeTap(node),
                    onDoubleTap: () => _onNodeDoubleTap(node),
                    isDimmed:
                        _chainHighlight != null &&
                        !_chainHighlight!.allNodeIds.contains(node.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _graph!.nodes.length,
      itemBuilder: (context, index) {
        final node = _graph!.nodes[index];
        return Card(
          color: Colors.grey[800],
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _getStatusIcon(node.status),
            title: Text(node.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              '${node.inputs.length} inputs, ${node.outputs.length} outputs',
              style: TextStyle(color: Colors.grey[400]),
            ),
            onTap: () => _onNodeTap(node),
          ),
        );
      },
    );
  }

  Widget _buildDetailPanel() {
    // Find actual bottleneck or null if none exists
    final matchingBottleneck = _graph?.bottlenecks
        .where((b) => b.impactedNodeIds.contains(_selectedNode!.id))
        .firstOrNull;

    return NodeDetailPanel(
      node: _selectedNode!,
      bottleneck: matchingBottleneck,
      onClose: _onBackgroundTap,
    );
  }

  BuildingNode? _findNode(String nodeId) {
    if (_graph == null) {
      debugPrint(
        'Warning: _findNode called with null graph for nodeId: $nodeId',
      );
      return null;
    }
    try {
      return _graph!.nodes.firstWhere((n) => n.id == nodeId);
    } on StateError {
      // Expected: node not found in graph (may have been filtered out)
      return null;
    } catch (e, stackTrace) {
      // Unexpected error - log for debugging
      debugPrint('Error finding node $nodeId: $e\n$stackTrace');
      rethrow;
    }
  }

  Offset _getEdgePosition(ResourceFlowEdge edge) {
    final startNode = _findNode(edge.producerNodeId);
    final endNode = _findNode(edge.consumerNodeId);
    if (startNode == null || endNode == null) return Offset.zero;

    final startX = startNode.position.dx + ProductionTheme.nodeWidth;
    final startY = startNode.position.dy + ProductionTheme.nodeHeight / 2;
    final endX = endNode.position.dx;
    final endY = endNode.position.dy + ProductionTheme.nodeHeight / 2;

    final minX = min(startX, endX);
    final minY = min(startY, endY);

    return Offset(
      minX - ProductionTheme.edgePadding / 2,
      minY - ProductionTheme.edgePadding / 2,
    );
  }

  Widget _getStatusIcon(FlowStatus status) {
    final color = ProductionTheme.getStatusColor(status);
    final icon = ProductionTheme.getStatusIcon(status);
    return Icon(icon, color: color);
  }
}

/// Custom painter for drawing edges between nodes.
class _ProductionGraphPainter extends CustomPainter {
  final ProductionGraph graph;
  final ChainHighlight? chainHighlight;

  _ProductionGraphPainter({required this.graph, this.chainHighlight});

  @override
  void paint(Canvas canvas, Size size) {
    // Edge painting is handled by ResourceFlowEdgeWidget
    // This painter can be used for background grid or decorations
  }

  @override
  bool shouldRepaint(covariant _ProductionGraphPainter oldDelegate) {
    return graph != oldDelegate.graph ||
        chainHighlight != oldDelegate.chainHighlight;
  }
}
