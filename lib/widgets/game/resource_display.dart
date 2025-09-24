import 'package:flutter/material.dart';
import '../../game/resources/resources.dart';

class ResourceDisplay extends StatelessWidget {
  final Resources resources;

  const ResourceDisplay({super.key, required this.resources});

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
          _buildResourceRow(
            icon: Icons.people,
            color: Colors.blue,
            label: 'Population',
            value: resources.population.toDouble(),
          ),
          const SizedBox(height: 4),
          _buildResourceRow(
            icon: Icons.work,
            color: Colors.orange,
            label: 'Workers',
            value: resources.availableWorkers.toDouble(),
            isSubItem: true,
          ),
        ],
      ),
    );
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
