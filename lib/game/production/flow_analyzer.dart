/// Flow analysis logic for calculating production status and detecting bottlenecks.
library;

import 'package:flutter/foundation.dart';
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
  static List<BottleneckInsight> detectBottlenecks(List<BuildingNode> nodes) {
    final bottlenecks = <BottleneckInsight>[];
    final resourceStats = <ResourceType, _ResourceStats>{};

    // Aggregate production and consumption per resource type
    for (final node in nodes) {
      if (!node.hasWorkers) continue;

      for (final output in node.outputs) {
        resourceStats
                .putIfAbsent(output.resourceType, () => _ResourceStats())
                .totalProduction +=
            output.ratePerSecond;
        resourceStats[output.resourceType]!.producerIds.add(node.id);
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
    if (currentProducers == 0) {
      return 'Add a ${resourceType.name} producer';
    }

    // Estimate needed producers (rough heuristic)
    final neededProducers = (deficitAmount / 2).ceil();
    if (neededProducers <= 1) {
      return 'Add 1 more ${resourceType.name} producer';
    }
    return 'Add $neededProducers ${resourceType.name} producers';
  }

  /// Analyze the graph and update flow status on all nodes and edges.
  static ProductionGraph analyzeGraph(ProductionGraph graph) {
    final resourceStats = <ResourceType, _ResourceStats>{};

    // Collect stats
    for (final node in graph.nodes) {
      if (!node.hasWorkers) continue;

      for (final output in node.outputs) {
        resourceStats
                .putIfAbsent(output.resourceType, () => _ResourceStats())
                .totalProduction +=
            output.ratePerSecond;
      }
      for (final input in node.inputs) {
        resourceStats
                .putIfAbsent(input.resourceType, () => _ResourceStats())
                .totalConsumption +=
            input.ratePerSecond;
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

      for (final input in node.inputs) {
        final status = resourceStatus[input.resourceType];
        if (status == null) {
          debugPrint(
            'Warning: No status computed for resource ${input.resourceType.name} on node ${node.id}',
          );
        }
        final actualStatus = status ?? FlowStatus.unknown;
        if (actualStatus == FlowStatus.deficit) {
          nodeStatus = FlowStatus.deficit;
          break;
        } else if (actualStatus == FlowStatus.unknown &&
            nodeStatus == FlowStatus.balanced) {
          nodeStatus = FlowStatus.unknown;
        } else if (actualStatus == FlowStatus.surplus &&
            nodeStatus != FlowStatus.deficit &&
            nodeStatus != FlowStatus.unknown) {
          nodeStatus = FlowStatus.surplus;
        }
      }

      return BuildingNode(
        id: node.id,
        name: node.name,
        type: node.type,
        category: node.category,
        inputs: node.inputs,
        outputs: node.outputs,
        status: nodeStatus,
        hasWorkers: node.hasWorkers,
        position: node.position,
        isSelected: node.isSelected,
        isHighlighted: node.isHighlighted,
      );
    }).toList();

    // Detect bottlenecks
    final bottlenecks = detectBottlenecks(updatedNodes);

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
