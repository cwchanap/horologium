/// Building node widget for the production overlay.
library;

import 'package:flutter/material.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/production_graph.dart';

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
          width: 120,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: node.isSelected
                  ? Colors.cyanAccent
                  : node.isHighlighted
                  ? Colors.cyanAccent.withAlpha(128)
                  : _getStatusColor(node.status).withAlpha(128),
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
                    _getCategoryIcon(node.category),
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

  Color _getStatusColor(FlowStatus status) {
    switch (status) {
      case FlowStatus.surplus:
        return const Color(0xFF4CAF50); // Green
      case FlowStatus.balanced:
        return const Color(0xFFFFEB3B); // Yellow
      case FlowStatus.deficit:
        return const Color(0xFFF44336); // Red
    }
  }

  Widget _getCategoryIcon(BuildingCategory category) {
    IconData iconData;
    switch (category) {
      case BuildingCategory.rawMaterials:
        iconData = Icons.terrain;
      case BuildingCategory.processing:
      case BuildingCategory.primaryFactory:
        iconData = Icons.factory;
      case BuildingCategory.refinement:
        iconData = Icons.science;
      case BuildingCategory.residential:
        iconData = Icons.home;
      case BuildingCategory.services:
        iconData = Icons.storefront;
      case BuildingCategory.foodResources:
        iconData = Icons.restaurant;
    }

    return Icon(iconData, size: 16, color: Colors.grey[400]);
  }

  Widget _getStatusIndicator(FlowStatus status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }

  IconData _getStatusIcon(FlowStatus status) {
    switch (status) {
      case FlowStatus.surplus:
        return Icons.check; // Checkmark for surplus
      case FlowStatus.balanced:
        return Icons.remove; // Dash for balanced
      case FlowStatus.deficit:
        return Icons.close; // X for deficit
    }
  }
}
