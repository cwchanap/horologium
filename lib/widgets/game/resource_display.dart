import 'package:flutter/material.dart';
import '../../game/resources/resources.dart';

class ResourceDisplay extends StatelessWidget {
  final Resources resources;
  final VoidCallback? onProductionChainTap;

  const ResourceDisplay({
    super.key,
    required this.resources,
    this.onProductionChainTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((255 * 0.7).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyan.withAlpha((255 * 0.3).round())),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildResourceRow(
            icon: Icons.attach_money,
            color: Colors.green,
            label: 'Cash',
            value: resources.cash,
          ),
          const SizedBox(height: 8),
          _buildResourceRow(
            icon: Icons.science,
            color: Colors.purple,
            label: 'Research',
            value: resources.research,
          ),
          const SizedBox(height: 8),
          _buildHappinessRow(),
          const SizedBox(height: 8),
          _buildPopulationRow(),
          const SizedBox(height: 4),
          _buildResourceRow(
            icon: Icons.work,
            color: Colors.orange,
            label: 'Workers',
            value: resources.availableWorkers.toDouble(),
            isSubItem: true,
          ),
          if (onProductionChainTap != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.grey, height: 1),
            const SizedBox(height: 8),
            _buildProductionChainButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildProductionChainButton() {
    return GestureDetector(
      onTap: onProductionChainTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withAlpha(26),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.cyanAccent.withAlpha(77)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree, color: Colors.cyanAccent, size: 16),
            SizedBox(width: 6),
            Text(
              'Production',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHappinessRow() {
    final happiness = resources.happiness;
    final color = _getHappinessColor(happiness);
    final icon = _getHappinessIcon(happiness);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          '${happiness.toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPopulationRow() {
    final happiness = resources.happiness;
    final hasSpareHousing = resources.hasSpareHousingCapacity();

    // Determine trend based on current happiness and spare housing capacity
    PopulationTrend trend;
    if (happiness >= HappinessThresholds.high && hasSpareHousing) {
      trend = PopulationTrend.growing;
    } else if (happiness <= HappinessThresholds.low) {
      trend = PopulationTrend.shrinking;
    } else {
      trend = PopulationTrend.stable;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.people, color: Colors.blue, size: 18),
        const SizedBox(width: 6),
        Text(
          resources.population.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        _buildTrendIndicator(trend),
      ],
    );
  }

  Widget _buildTrendIndicator(PopulationTrend trend) {
    switch (trend) {
      case PopulationTrend.growing:
        return const Icon(
          Icons.arrow_upward,
          color: Colors.greenAccent,
          size: 14,
        );
      case PopulationTrend.shrinking:
        return const Icon(
          Icons.arrow_downward,
          color: Colors.redAccent,
          size: 14,
        );
      case PopulationTrend.stable:
        return Icon(Icons.remove, color: Colors.grey.shade400, size: 14);
    }
  }

  Color _getHappinessColor(double happiness) {
    if (happiness >= HappinessThresholds.high) {
      return Colors.greenAccent;
    } else if (happiness >= HappinessThresholds.low) {
      return Colors.yellowAccent;
    } else {
      return Colors.redAccent;
    }
  }

  IconData _getHappinessIcon(double happiness) {
    if (happiness >= HappinessThresholds.high) {
      return Icons.sentiment_very_satisfied;
    } else if (happiness >= HappinessThresholds.low) {
      return Icons.sentiment_neutral;
    } else {
      return Icons.sentiment_very_dissatisfied;
    }
  }

  Widget _buildResourceRow({
    required IconData icon,
    required Color color,
    required String label,
    required double value,
    bool isSubItem = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSubItem) const SizedBox(width: 16),
        Icon(icon, color: color, size: isSubItem ? 16 : 18),
        const SizedBox(width: 6),
        Text(
          isSubItem ? value.toInt().toString() : value.toStringAsFixed(0),
          style: TextStyle(
            color: Colors.white,
            fontSize: isSubItem ? 12 : 14,
            fontWeight: isSubItem ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
