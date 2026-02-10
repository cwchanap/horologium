/// Flow analysis logic for calculating production status and detecting bottlenecks.
library;

import 'package:flutter/foundation.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/resources/resource_type.dart';

/// Analyzes resource flows to determine status and bottlenecks.
class FlowAnalyzer {
  /// Calculate flow status by comparing production vs consumption rates.
  ///
  /// Uses 10% tolerance:
  /// - Surplus: production > consumption * 1.1
  /// - Deficit: production < consumption * 0.9
  /// - Balanced: within 10% tolerance
  static FlowStatus calculateFlowStatus(
    double totalProduction,
    double totalConsumption,
  ) {
    if (totalConsumption == 0) {
      return totalProduction > 0 ? FlowStatus.surplus : FlowStatus.balanced;
    }

    final ratio = totalProduction / totalConsumption;

    if (ratio > 1.1) {
      return FlowStatus.surplus;
    } else if (ratio < 0.9) {
      return FlowStatus.deficit;
    } else {
      return FlowStatus.balanced;
    }
  }

  /// Detect bottlenecks in the production graph.
  ///
  /// Returns a list of [BottleneckInsight] for each resource with deficit.
  /// Only counts production from nodes that can actually produce (have workers
  /// AND sufficient input resources).
  static List<BottleneckInsight> detectBottlenecks(
    List<BuildingNode> nodes, {
    Map<String, bool>? nodeCanProduce,
  }) {
    final bottlenecks = <BottleneckInsight>[];
    final resourceStats = <ResourceType, _ResourceStats>{};

    // Aggregate production and consumption per resource type
    for (final node in nodes) {
      if (!node.hasWorkers) continue;

      // Only count production from nodes that can actually produce
      if (nodeCanProduce == null || (nodeCanProduce[node.id] ?? false)) {
        for (final output in node.outputs) {
          resourceStats
                  .putIfAbsent(output.resourceType, () => _ResourceStats())
                  .totalProduction +=
              output.ratePerSecond;
          resourceStats[output.resourceType]!.producerIds.add(node.id);
        }
      }

      for (final input in node.inputs) {
        resourceStats
                .putIfAbsent(input.resourceType, () => _ResourceStats())
                .totalConsumption +=
            input.ratePerSecond;
        resourceStats[input.resourceType]!.consumerIds.add(node.id);
      }
    }

    // Find deficit resources and create bottleneck insights
    for (final entry in resourceStats.entries) {
      final resourceType = entry.key;
      final stats = entry.value;

      if (stats.totalConsumption > 0 &&
          stats.totalProduction < stats.totalConsumption * 0.9) {
        final deficitRatio =
            1 - (stats.totalProduction / stats.totalConsumption);
        final severity = _calculateSeverity(deficitRatio);
        final deficitAmount = stats.totalConsumption - stats.totalProduction;

        bottlenecks.add(
          BottleneckInsight(
            id: 'bottleneck_${resourceType.name}',
            resourceType: resourceType,
            severity: severity,
            description:
                '${resourceType.name} production ${(deficitRatio * 100).toInt()}% below demand',
            recommendation: _generateRecommendation(
              resourceType,
              deficitAmount,
              stats.producerIds.length,
            ),
            impactedNodeIds: [...stats.producerIds, ...stats.consumerIds],
          ),
        );
      }
    }

    return bottlenecks;
  }

  /// Calculate severity based on deficit ratio.
  static BottleneckSeverity _calculateSeverity(double deficitRatio) {
    if (deficitRatio > 0.5) {
      return BottleneckSeverity.high;
    } else if (deficitRatio > 0.25) {
      return BottleneckSeverity.medium;
    } else {
      return BottleneckSeverity.low;
    }
  }

  /// Generate recommendation for resolving bottleneck.
  static String _generateRecommendation(
    ResourceType resourceType,
    double deficitAmount,
    int currentProducers,
  ) {
    // Find a building that produces this resource
    final producerBuilding = BuildingRegistry.availableBuildings
        .where((b) => b.generation.containsKey(resourceType))
        .firstOrNull;

    if (producerBuilding == null) {
      return 'No producer available for ${resourceType.name}';
    }

    if (currentProducers == 0) {
      return 'Add a ${producerBuilding.name}';
    }

    // Calculate needed producers based on actual production rate
    final ratePerBuilding = producerBuilding.generation[resourceType]!;
    final neededProducers = (deficitAmount / ratePerBuilding).ceil();

    if (neededProducers <= 1) {
      return 'Add 1 more ${producerBuilding.name}';
    }
    return 'Add $neededProducers more ${producerBuilding.name}s';
  }

  /// Analyze the graph and update flow status on all nodes and edges.
  ///
  /// Calculates actual (not theoretical) flows based on steady-state rates.
  /// Only includes production/consumption from buildings that have both
  /// workers AND sufficient input resources.
  ///
  /// Uses an iterative approach to handle multi-hop production chains correctly:
  /// - Nodes with no inputs can always produce if they have workers
  /// - Nodes with inputs can only produce if their input resources are
  ///   actually available from upstream nodes that can produce
  /// - This is resolved iteratively until convergence
  static ProductionGraph analyzeGraph(ProductionGraph graph) {
    final resourceStats = <ResourceType, _ResourceStats>{};

    // Build a map for checking node resource availability using iterative resolution
    final nodeCanProduce = <String, bool>{};
    for (final node in graph.nodes) {
      nodeCanProduce[node.id] = false;
    }

    // Iteratively determine which nodes can produce
    // This handles multi-hop chains correctly by only counting production from
    // nodes that have been confirmed as able to produce
    bool changed;
    do {
      changed = false;

      // First pass: compute total actual production per resource
      // based on nodes that CAN produce (from previous iteration)
      final actualProduction = <ResourceType, double>{};
      for (final node in graph.nodes) {
        if (!node.hasWorkers || !nodeCanProduce[node.id]!) continue;
        for (final output in node.outputs) {
          actualProduction.update(
            output.resourceType,
            (v) => v + output.ratePerSecond,
            ifAbsent: () => output.ratePerSecond,
          );
        }
      }

      // Second pass: compute total demand per resource
      final totalDemand = <ResourceType, double>{};
      for (final node in graph.nodes) {
        if (!node.hasWorkers) continue;
        for (final input in node.inputs) {
          totalDemand.update(
            input.resourceType,
            (v) => v + input.ratePerSecond,
            ifAbsent: () => input.ratePerSecond,
          );
        }
      }

      // Third pass: determine which nodes can produce based on actual availability
      for (final node in graph.nodes) {
        if (!node.hasWorkers) {
          if (nodeCanProduce[node.id]!) {
            nodeCanProduce[node.id] = false;
            changed = true;
          }
          continue;
        }

        // Nodes with no inputs can always produce if they have workers
        if (node.inputs.isEmpty) {
          if (!nodeCanProduce[node.id]!) {
            nodeCanProduce[node.id] = true;
            changed = true;
          }
          continue;
        }

        // Check if all input resources have sufficient actual production
        bool canProduce = true;
        for (final input in node.inputs) {
          final resourceType = input.resourceType;
          final totalDemandForResource = totalDemand[resourceType] ?? 0;
          if (totalDemandForResource == 0) {
            canProduce = false;
            break;
          }
          final actualShare =
              (actualProduction[resourceType] ?? 0) *
              (input.ratePerSecond / totalDemandForResource);
          if (actualShare < input.ratePerSecond) {
            canProduce = false;
            break;
          }
        }

        if (nodeCanProduce[node.id]! != canProduce) {
          nodeCanProduce[node.id] = canProduce;
          changed = true;
        }
      }
    } while (changed);

    // Collect consumption stats from ALL nodes with workers (demand exists
    // even when a building can't operate due to insufficient incoming rate).
    // Collect production stats only from buildings that can actually produce.
    for (final node in graph.nodes) {
      if (!node.hasWorkers) continue;

      for (final input in node.inputs) {
        resourceStats
                .putIfAbsent(input.resourceType, () => _ResourceStats())
                .totalConsumption +=
            input.ratePerSecond;
        resourceStats[input.resourceType]!.consumerIds.add(node.id);
      }

      if (nodeCanProduce[node.id]!) {
        for (final output in node.outputs) {
          resourceStats
                  .putIfAbsent(output.resourceType, () => _ResourceStats())
                  .totalProduction +=
              output.ratePerSecond;
          resourceStats[output.resourceType]!.producerIds.add(node.id);
        }
      }
    }

    // Calculate status per resource
    final resourceStatus = <ResourceType, FlowStatus>{};
    for (final entry in resourceStats.entries) {
      resourceStatus[entry.key] = calculateFlowStatus(
        entry.value.totalProduction,
        entry.value.totalConsumption,
      );
    }

    // Update edges with calculated status
    final updatedEdges = graph.edges.map((edge) {
      final status = resourceStatus[edge.resourceType];
      if (status == null) {
        debugPrint(
          'Warning: No status computed for resource ${edge.resourceType.name} on edge ${edge.id}',
        );
      }
      return ResourceFlowEdge(
        id: edge.id,
        resourceType: edge.resourceType,
        producerNodeId: edge.producerNodeId,
        consumerNodeId: edge.consumerNodeId,
        ratePerSecond: edge.ratePerSecond,
        status: status ?? FlowStatus.unknown,
        isHighlighted: edge.isHighlighted,
        isIncomplete: edge.isIncomplete,
      );
    }).toList();

    // Update nodes with overall status (worst of all their resources)
    final updatedNodes = graph.nodes.map((node) {
      FlowStatus nodeStatus = FlowStatus.balanced;

      FlowStatus resolveStatus(ResourceType resourceType) {
        final status = resourceStatus[resourceType];
        if (status == null) {
          debugPrint(
            'Warning: No status computed for resource ${resourceType.name} on node ${node.id}',
          );
        }
        return status ?? FlowStatus.unknown;
      }

      void updateNodeStatus(FlowStatus actualStatus) {
        if (actualStatus == FlowStatus.deficit) {
          nodeStatus = FlowStatus.deficit;
          return;
        }
        if (actualStatus == FlowStatus.unknown &&
            nodeStatus != FlowStatus.deficit) {
          nodeStatus = FlowStatus.unknown;
        } else if (actualStatus == FlowStatus.surplus &&
            nodeStatus != FlowStatus.deficit &&
            nodeStatus != FlowStatus.unknown) {
          nodeStatus = FlowStatus.surplus;
        }
      }

      for (final input in node.inputs) {
        final actualStatus = resolveStatus(input.resourceType);
        updateNodeStatus(actualStatus);
        if (nodeStatus == FlowStatus.deficit) {
          break;
        }
      }

      if (nodeStatus != FlowStatus.deficit) {
        for (final output in node.outputs) {
          final actualStatus = resolveStatus(output.resourceType);
          updateNodeStatus(actualStatus);
          if (nodeStatus == FlowStatus.deficit) {
            break;
          }
        }
      }

      final updatedInputs = node.inputs
          .map(
            (input) => ResourcePort(
              resourceType: input.resourceType,
              ratePerSecond: input.ratePerSecond,
              status: resolveStatus(input.resourceType),
            ),
          )
          .toList();
      final updatedOutputs = node.outputs
          .map(
            (output) => ResourcePort(
              resourceType: output.resourceType,
              ratePerSecond: output.ratePerSecond,
              status: resolveStatus(output.resourceType),
            ),
          )
          .toList();

      return BuildingNode(
        id: node.id,
        name: node.name,
        type: node.type,
        category: node.category,
        inputs: updatedInputs,
        outputs: updatedOutputs,
        status: nodeStatus,
        hasWorkers: node.hasWorkers,
        position: node.position,
        isSelected: node.isSelected,
        isHighlighted: node.isHighlighted,
      );
    }).toList();

    // Detect bottlenecks (only count actual production, not theoretical)
    final bottlenecks = detectBottlenecks(
      updatedNodes,
      nodeCanProduce: nodeCanProduce,
    );

    return ProductionGraph(
      id: graph.id,
      generatedAt: graph.generatedAt,
      nodes: updatedNodes,
      edges: updatedEdges,
      bottlenecks: bottlenecks,
    );
  }
}

/// Internal helper for aggregating resource statistics.
class _ResourceStats {
  double totalProduction = 0;
  double totalConsumption = 0;
  final Set<String> producerIds = {};
  final Set<String> consumerIds = {};
}
