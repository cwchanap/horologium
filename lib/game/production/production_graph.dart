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

/// Helper class for edge candidate collection.
class _EdgeCandidate {
  final BuildingNode producer;
  final BuildingNode consumer;
  final ResourcePort input;

  _EdgeCandidate({
    required this.producer,
    required this.consumer,
    required this.input,
  });
}

/// Flow status indicating production vs consumption balance.
enum FlowStatus {
  /// Production exceeds consumption by more than 10%
  surplus,

  /// Production and consumption within 10% tolerance
  balanced,

  /// Consumption exceeds production by more than 10%
  deficit,

  /// Status could not be computed (missing data or calculation error)
  unknown,
}

/// Severity level for detected bottlenecks.
enum BottleneckSeverity {
  /// Up to 25% deficit
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
  final Offset position;
  final bool isSelected;
  final bool isHighlighted;

  BuildingNode({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required List<ResourcePort> inputs,
    required List<ResourcePort> outputs,
    required this.status,
    required this.hasWorkers,
    this.position = Offset.zero,
    this.isSelected = false,
    this.isHighlighted = false,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);

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
  final bool isHighlighted;
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

  BottleneckInsight({
    required this.id,
    required this.resourceType,
    required this.severity,
    required this.description,
    required this.recommendation,
    required List<String> impactedNodeIds,
  }) : impactedNodeIds = List.unmodifiable(impactedNodeIds);
}

/// The complete production graph snapshot.
class ProductionGraph {
  final String id;
  final DateTime generatedAt;
  final List<BuildingNode> nodes;
  final List<ResourceFlowEdge> edges;
  final List<BottleneckInsight> bottlenecks;

  /// Whether this graph should use clustered visualization (>50 nodes).
  bool get isClustered => nodes.length > 50;

  ProductionGraph({
    required this.id,
    required this.generatedAt,
    required List<BuildingNode> nodes,
    required List<ResourceFlowEdge> edges,
    required List<BottleneckInsight> bottlenecks,
  }) : nodes = List.unmodifiable(nodes),
       edges = List.unmodifiable(edges),
       bottlenecks = List.unmodifiable(bottlenecks);

  /// Factory to build a production graph from buildings and resources.
  ///
  /// Currently uses base production/consumption rates from building definitions.
  // TODO(T011): Use resources parameter to calculate actual flow rates based on current resource levels
  factory ProductionGraph.fromBuildings(
    List<Building> buildings,
    Resources resources,
  ) {
    final nodes = <BuildingNode>[];
    final edges = <ResourceFlowEdge>[];
    final bottlenecks = <BottleneckInsight>[];

    // Build nodes from buildings
    for (var i = 0; i < buildings.length; i++) {
      final building = buildings[i];
      final inputs = <ResourcePort>[];
      final outputs = <ResourcePort>[];

      // Process consumption (inputs)
      for (final entry in building.consumption.entries) {
        inputs.add(
          ResourcePort(
            resourceType: entry.key,
            ratePerSecond: entry.value,
            status: FlowStatus.balanced, // Will be calculated by FlowAnalyzer
          ),
        );
      }

      // Process generation (outputs)
      for (final entry in building.generation.entries) {
        outputs.add(
          ResourcePort(
            resourceType: entry.key,
            ratePerSecond: entry.value,
            status: FlowStatus.balanced, // Will be calculated by FlowAnalyzer
          ),
        );
      }

      nodes.add(
        BuildingNode(
          // Use the building's stable UUID for consistent identification
          // across graph rebuilds and building list changes.
          id: building.id,
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
    // First, collect all potential producer-consumer pairs
    // Use record keys to avoid fragile string splitting when reconstructing consumer/resource.
    final edgeCandidates =
        <
          (String consumerId, ResourceType resourceType),
          List<_EdgeCandidate>
        >{};

    for (final consumer in nodes) {
      for (final input in consumer.inputs) {
        final key = (consumer.id, input.resourceType);
        edgeCandidates[key] = [];

        // Find all producers of this resource (excluding self)
        for (final producer in nodes) {
          if (producer.id == consumer.id) continue;

          final producesResource = producer.outputs.any(
            (o) => o.resourceType == input.resourceType,
          );

          if (producesResource) {
            edgeCandidates[key]!.add(
              _EdgeCandidate(
                producer: producer,
                consumer: consumer,
                input: input,
              ),
            );
          }
        }
      }
    }

    // Emit incomplete edges for producer-only resources (no consumers)
    for (final producer in nodes) {
      for (final output in producer.outputs) {
        final hasConsumer = nodes.any(
          (consumer) =>
              consumer.id != producer.id &&
              consumer.inputs.any((i) => i.resourceType == output.resourceType),
        );

        if (!hasConsumer) {
          edges.add(
            ResourceFlowEdge(
              id: 'incomplete_producer_${producer.id}_${output.resourceType.name}',
              resourceType: output.resourceType,
              producerNodeId: producer.id,
              consumerNodeId: producer.id,
              ratePerSecond: output.ratePerSecond,
              status: FlowStatus.surplus,
              isIncomplete: true,
            ),
          );
        }
      }
    }

    // Create edges with allocated rates split among producers
    for (final entry in edgeCandidates.entries) {
      final (consumerId, resourceType) = entry.key;
      final candidates = entry.value;

      // When no producer exists for this input, emit an incomplete edge
      if (candidates.isEmpty) {
        edges.add(
          ResourceFlowEdge(
            id: 'incomplete_${consumerId}_${resourceType.name}',
            resourceType: resourceType,
            producerNodeId: consumerId,
            consumerNodeId: consumerId,
            ratePerSecond: 0,
            status: FlowStatus.deficit,
            isIncomplete: true,
          ),
        );
        continue;
      }

      final input = candidates.first.input;
      final consumer = candidates.first.consumer;
      final matchingProducers = candidates.map((c) => c.producer).toList();

      // Split demand evenly among all matching producers
      final allocatedRate = matchingProducers.isEmpty
          ? 0.0
          : input.ratePerSecond / matchingProducers.length;

      for (final producer in matchingProducers) {
        edges.add(
          ResourceFlowEdge(
            id: '${producer.id}_to_${consumer.id}_${input.resourceType.name}',
            resourceType: input.resourceType,
            producerNodeId: producer.id,
            consumerNodeId: consumer.id,
            ratePerSecond: allocatedRate,
            status: FlowStatus.balanced,
          ),
        );
      }
    }

    final now = DateTime.now();
    return ProductionGraph(
      id: now.millisecondsSinceEpoch.toString(),
      generatedAt: now,
      nodes: nodes,
      edges: edges,
      bottlenecks: bottlenecks,
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
      // Priority: deficit > unknown > surplus > balanced
      var aggregateStatus = FlowStatus.balanced;
      for (final node in nodesInCategory) {
        if (node.status == FlowStatus.deficit) {
          aggregateStatus = FlowStatus.deficit;
          break;
        } else if (node.status == FlowStatus.unknown &&
            aggregateStatus != FlowStatus.deficit) {
          aggregateStatus = FlowStatus.unknown;
        } else if (node.status == FlowStatus.surplus &&
            aggregateStatus != FlowStatus.deficit &&
            aggregateStatus != FlowStatus.unknown) {
          aggregateStatus = FlowStatus.surplus;
        }
      }

      return NodeCluster(
        id: 'cluster_${category.name}',
        category: category,
        nodeIds: nodesInCategory.map((n) => n.id).toList(),
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
  final FlowStatus aggregateStatus;
  final Offset position;
  final bool isExpanded;

  /// Count of nodes in this cluster.
  int get nodeCount => nodeIds.length;

  NodeCluster({
    required this.id,
    required this.category,
    required List<String> nodeIds,
    required this.aggregateStatus,
    this.position = Offset.zero,
    this.isExpanded = false,
  }) : nodeIds = List.unmodifiable(nodeIds);

  /// Create a copy with updated position or expansion state.
  NodeCluster copyWith({Offset? position, bool? isExpanded}) {
    return NodeCluster(
      id: id,
      category: category,
      nodeIds: nodeIds,
      aggregateStatus: aggregateStatus,
      position: position ?? this.position,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}
