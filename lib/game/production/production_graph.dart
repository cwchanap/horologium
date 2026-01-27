/// Production graph data structures for visualizing resource flows.
///
/// This file contains all data models for the production chain overlay:
/// - FlowStatus and BottleneckSeverity enums
/// - BuildingNode, ResourceFlowEdge, ResourcePort classes
/// - ProductionGraph as the main container
library;

import 'dart:ui';

import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

/// Flow status indicating production vs consumption balance.
enum FlowStatus {
  /// Production exceeds consumption by more than 10%
  surplus,

  /// Production and consumption within 10% tolerance
  balanced,

  /// Consumption exceeds production by more than 10%
  deficit,
}

/// Severity level for detected bottlenecks.
enum BottleneckSeverity {
  /// 10-25% deficit
  low,

  /// 25-50% deficit
  medium,

  /// More than 50% deficit
  high,
}

/// A resource input or output port with rate and status.
class ResourcePort {
  final ResourceType resourceType;
  final double ratePerSecond;
  final FlowStatus status;

  const ResourcePort({
    required this.resourceType,
    required this.ratePerSecond,
    required this.status,
  });
}

/// A building node in the production graph.
class BuildingNode {
  final String id;
  final String name;
  final BuildingType type;
  final BuildingCategory category;
  final List<ResourcePort> inputs;
  final List<ResourcePort> outputs;
  final FlowStatus status;
  final bool hasWorkers;
  Offset position;
  bool isSelected;
  bool isHighlighted;

  BuildingNode({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.inputs,
    required this.outputs,
    required this.status,
    required this.hasWorkers,
    this.position = Offset.zero,
    this.isSelected = false,
    this.isHighlighted = false,
  });

  /// Create a copy with updated selection/highlight state.
  BuildingNode copyWith({
    Offset? position,
    bool? isSelected,
    bool? isHighlighted,
  }) {
    return BuildingNode(
      id: id,
      name: name,
      type: type,
      category: category,
      inputs: inputs,
      outputs: outputs,
      status: status,
      hasWorkers: hasWorkers,
      position: position ?? this.position,
      isSelected: isSelected ?? this.isSelected,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }
}

/// A directed edge representing resource flow from producer to consumer.
class ResourceFlowEdge {
  final String id;
  final ResourceType resourceType;
  final String producerNodeId;
  final String consumerNodeId;
  final double ratePerSecond;
  final FlowStatus status;
  bool isHighlighted;
  final bool isIncomplete;

  ResourceFlowEdge({
    required this.id,
    required this.resourceType,
    required this.producerNodeId,
    required this.consumerNodeId,
    required this.ratePerSecond,
    required this.status,
    this.isHighlighted = false,
    this.isIncomplete = false,
  });

  /// Create a copy with updated highlight state.
  ResourceFlowEdge copyWith({bool? isHighlighted}) {
    return ResourceFlowEdge(
      id: id,
      resourceType: resourceType,
      producerNodeId: producerNodeId,
      consumerNodeId: consumerNodeId,
      ratePerSecond: ratePerSecond,
      status: status,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      isIncomplete: isIncomplete,
    );
  }
}

/// Detected bottleneck with recommendation.
class BottleneckInsight {
  final String id;
  final ResourceType resourceType;
  final BottleneckSeverity severity;
  final String description;
  final String recommendation;
  final List<String> impactedNodeIds;

  const BottleneckInsight({
    required this.id,
    required this.resourceType,
    required this.severity,
    required this.description,
    required this.recommendation,
    required this.impactedNodeIds,
  });
}

/// The complete production graph snapshot.
class ProductionGraph {
  final String id;
  final DateTime generatedAt;
  final List<BuildingNode> nodes;
  final List<ResourceFlowEdge> edges;
  final List<BottleneckInsight> bottlenecks;
  final bool isClustered;

  const ProductionGraph({
    required this.id,
    required this.generatedAt,
    required this.nodes,
    required this.edges,
    required this.bottlenecks,
    this.isClustered = false,
  });

  /// Factory to build a production graph from buildings and resources.
  // TODO(T011): Use resources parameter to calculate actual flow rates based on current resource levels
  factory ProductionGraph.fromBuildings(
    List<Building> buildings,
    Resources resources,
  ) {
    // Implementation will be added in T011
    final nodes = <BuildingNode>[];
    final edges = <ResourceFlowEdge>[];
    final bottlenecks = <BottleneckInsight>[];

    // Build nodes from buildings
    for (var i = 0; i < buildings.length; i++) {
      final building = buildings[i];
      final inputs = <ResourcePort>[];
      final outputs = <ResourcePort>[];

      // Process consumption (inputs)
      for (final entry in building.baseConsumption.entries) {
        final resourceType = ResourceType.values.firstWhere(
          (r) => r.name == entry.key,
          orElse: () => ResourceType.cash,
        );
        inputs.add(
          ResourcePort(
            resourceType: resourceType,
            ratePerSecond: entry.value,
            status: FlowStatus.balanced, // Will be calculated by FlowAnalyzer
          ),
        );
      }

      // Process generation (outputs)
      for (final entry in building.baseGeneration.entries) {
        final resourceType = ResourceType.values.firstWhere(
          (r) => r.name == entry.key,
          orElse: () => ResourceType.cash,
        );
        outputs.add(
          ResourcePort(
            resourceType: resourceType,
            ratePerSecond: entry.value,
            status: FlowStatus.balanced, // Will be calculated by FlowAnalyzer
          ),
        );
      }

      nodes.add(
        BuildingNode(
          id: '${building.type.name}_$i',
          name: building.name,
          type: building.type,
          category: building.category,
          inputs: inputs,
          outputs: outputs,
          status: FlowStatus.balanced, // Will be calculated by FlowAnalyzer
          hasWorkers: building.assignedWorkers >= building.requiredWorkers,
        ),
      );
    }

    // Build edges by matching producers to consumers
    for (final consumer in nodes) {
      for (final input in consumer.inputs) {
        // Find producers of this resource
        for (final producer in nodes) {
          if (producer.id == consumer.id) continue;

          final producesResource = producer.outputs.any(
            (o) => o.resourceType == input.resourceType,
          );

          if (producesResource) {
            edges.add(
              ResourceFlowEdge(
                id: '${producer.id}_to_${consumer.id}_${input.resourceType.name}',
                resourceType: input.resourceType,
                producerNodeId: producer.id,
                consumerNodeId: consumer.id,
                ratePerSecond: input.ratePerSecond,
                status:
                    FlowStatus.balanced, // Will be calculated by FlowAnalyzer
              ),
            );
          }
        }
      }
    }

    return ProductionGraph(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      generatedAt: DateTime.now(),
      nodes: nodes,
      edges: edges,
      bottlenecks: bottlenecks,
      isClustered: nodes.length > 50,
    );
  }

  /// Check if graph is empty (no production buildings).
  bool get isEmpty => nodes.isEmpty;

  /// Apply clustering when node count exceeds threshold.
  /// Groups nodes by BuildingCategory and returns cluster summaries.
  static List<NodeCluster> createClusters(List<BuildingNode> nodes) {
    if (nodes.length <= 50) return [];

    final categoryGroups = <BuildingCategory, List<BuildingNode>>{};
    for (final node in nodes) {
      categoryGroups.putIfAbsent(node.category, () => []).add(node);
    }

    return categoryGroups.entries.map((entry) {
      final category = entry.key;
      final nodesInCategory = entry.value;

      // Determine aggregate status (worst status wins)
      var aggregateStatus = FlowStatus.balanced;
      for (final node in nodesInCategory) {
        if (node.status == FlowStatus.deficit) {
          aggregateStatus = FlowStatus.deficit;
          break;
        } else if (node.status == FlowStatus.surplus &&
            aggregateStatus != FlowStatus.deficit) {
          aggregateStatus = FlowStatus.surplus;
        }
      }

      return NodeCluster(
        id: 'cluster_${category.name}',
        category: category,
        nodeIds: nodesInCategory.map((n) => n.id).toList(),
        nodeCount: nodesInCategory.length,
        aggregateStatus: aggregateStatus,
      );
    }).toList();
  }
}

/// Cluster of buildings grouped by category.
class NodeCluster {
  final String id;
  final BuildingCategory category;
  final List<String> nodeIds;
  final int nodeCount;
  final FlowStatus aggregateStatus;
  Offset position;
  bool isExpanded;

  NodeCluster({
    required this.id,
    required this.category,
    required this.nodeIds,
    required this.nodeCount,
    required this.aggregateStatus,
    this.position = Offset.zero,
    this.isExpanded = false,
  });
}
