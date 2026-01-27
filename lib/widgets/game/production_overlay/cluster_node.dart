/// Cluster node widget for 50+ building colonies.
library;

import 'package:flutter/material.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/production_graph.dart';

/// Widget representing a cluster of buildings in the production graph.
class ClusterNodeWidget extends StatelessWidget {
  final NodeCluster cluster;
  final VoidCallback? onTap;
  final bool isDimmed;

  const ClusterNodeWidget({
    super.key,
    required this.cluster,
    this.onTap,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDimmed ? 0.3 : 1.0,
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStatusColor(cluster.aggregateStatus).withAlpha(128),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _getCategoryIcon(cluster.category),
                  const SizedBox(width: 4),
                  _getStatusIndicator(cluster.aggregateStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getCategoryName(cluster.category),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cluster.nodeCount} buildings',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                cluster.isExpanded ? Icons.unfold_less : Icons.unfold_more,
                color: Colors.cyanAccent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(FlowStatus status) {
    switch (status) {
      case FlowStatus.surplus:
        return const Color(0xFF4CAF50);
      case FlowStatus.balanced:
        return const Color(0xFFFFEB3B);
      case FlowStatus.deficit:
        return const Color(0xFFF44336);
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

    return Icon(iconData, size: 24, color: Colors.grey[400]);
  }

  String _getCategoryName(BuildingCategory category) {
    switch (category) {
      case BuildingCategory.rawMaterials:
        return 'Raw Materials';
      case BuildingCategory.processing:
        return 'Processing';
      case BuildingCategory.primaryFactory:
        return 'Primary Factory';
      case BuildingCategory.refinement:
        return 'Refinement';
      case BuildingCategory.residential:
        return 'Residential';
      case BuildingCategory.services:
        return 'Services';
      case BuildingCategory.foodResources:
        return 'Food Resources';
    }
  }

  Widget _getStatusIndicator(FlowStatus status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  IconData _getStatusIcon(FlowStatus status) {
    switch (status) {
      case FlowStatus.surplus:
        return Icons.check;
      case FlowStatus.balanced:
        return Icons.remove;
      case FlowStatus.deficit:
        return Icons.close;
    }
  }
}
