/// Building node widget for the production overlay.
library;

import 'package:flutter/material.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/widgets/game/production_overlay/production_theme.dart';

/// Widget representing a building node in the production graph.
class BuildingNodeWidget extends StatelessWidget {
  final BuildingNode node;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool isDimmed;

  const BuildingNodeWidget({
    super.key,
    required this.node,
    this.onTap,
    this.onDoubleTap,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDimmed ? 0.3 : 1.0,
        child: Container(
          width: ProductionTheme.nodeWidth,
          height: ProductionTheme.nodeHeight,
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: node.isSelected
                  ? Colors.cyanAccent
                  : node.isHighlighted
                  ? Colors.cyanAccent.withAlpha(128)
                  : ProductionTheme.getStatusColor(node.status).withAlpha(128),
              width: node.isSelected ? 3 : 2,
            ),
            boxShadow: node.isSelected
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withAlpha(64),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ProductionTheme.getCategoryIcon(node.category),
                    const SizedBox(width: 4),
                    _getStatusIndicator(node.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  node.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!node.hasWorkers)
                  const Text(
                    'No workers',
                    style: TextStyle(color: Colors.orange, fontSize: 9),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getStatusIndicator(FlowStatus status) {
    final color = ProductionTheme.getStatusColor(status);
    final icon = ProductionTheme.getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}
