/// Node detail panel showing input/output resources.
library;

import 'package:flutter/material.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/widgets/game/production_overlay/production_theme.dart';

/// Panel displaying detailed information about a selected building node.
class NodeDetailPanel extends StatelessWidget {
  final BuildingNode node;
  final BottleneckInsight? bottleneck;
  final VoidCallback? onClose;

  const NodeDetailPanel({
    super.key,
    required this.node,
    this.bottleneck,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasBottleneck = bottleneck != null && bottleneck!.id.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(
            color: hasBottleneck
                ? _getSeverityColor(bottleneck!.severity)
                : Colors.cyanAccent.withAlpha(128),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _getStatusIcon(node.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: onClose,
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (node.inputs.isNotEmpty) ...[
            const Text(
              'Inputs (Consumption)',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: node.inputs.map(_buildResourceChip).toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (node.outputs.isNotEmpty) ...[
            const Text(
              'Outputs (Production)',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: node.outputs.map(_buildResourceChip).toList(),
            ),
          ],
          if (hasBottleneck) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getSeverityColor(bottleneck!.severity).withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getSeverityColor(bottleneck!.severity).withAlpha(77),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: _getSeverityColor(bottleneck!.severity),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bottleneck!.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bottleneck!.recommendation,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!node.hasWorkers) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'No workers assigned - building idle',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResourceChip(ResourcePort port) {
    final color = ProductionTheme.getStatusColor(port.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getSmallStatusIcon(port.status),
          const SizedBox(width: 4),
          Text(
            port.resourceType.name,
            style: TextStyle(color: color, fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            '${port.ratePerSecond.toStringAsFixed(1)}/s',
            style: TextStyle(
              color: color.withAlpha(179),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStatusIcon(FlowStatus status) {
    final color = ProductionTheme.getStatusColor(status);
    final icon = ProductionTheme.getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _getSmallStatusIcon(FlowStatus status) {
    final icon = ProductionTheme.getStatusIcon(status);
    return Icon(icon, color: ProductionTheme.getStatusColor(status), size: 12);
  }

  Color _getSeverityColor(BottleneckSeverity severity) {
    switch (severity) {
      case BottleneckSeverity.low:
        return Colors.yellow;
      case BottleneckSeverity.medium:
        return Colors.orange;
      case BottleneckSeverity.high:
        return Colors.red;
    }
  }
}
