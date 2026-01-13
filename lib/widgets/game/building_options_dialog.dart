import 'package:flutter/material.dart';

import '../../game/building/building.dart';

class BuildingOptionsDialog extends StatelessWidget {
  final Building building;
  final double currentCash;
  final VoidCallback onUpgrade;
  final VoidCallback onDelete;

  const BuildingOptionsDialog({
    super.key,
    required this.building,
    required this.currentCash,
    required this.onUpgrade,
    required this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    required Building building,
    required double currentCash,
    required VoidCallback onUpgrade,
    required VoidCallback onDelete,
  }) {
    return showDialog(
      context: context,
      builder: (context) => BuildingOptionsDialog(
        building: building,
        currentCash: currentCash,
        onUpgrade: onUpgrade,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAffordUpgrade = currentCash >= building.upgradeCost;
    final canUpgrade = building.canUpgrade && canAffordUpgrade;

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Row(
        children: [
          Icon(building.icon, color: building.color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  building.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  building.canUpgrade
                      ? 'Level ${building.level}'
                      : 'Level ${building.level} (Max)',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsSection(),
          if (building.canUpgrade) ...[
            const SizedBox(height: 16),
            _buildUpgradePreview(),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // Delete button
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          label: const Text(
            'Delete',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
        // Right side buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            // Upgrade button
            if (building.canUpgrade)
              ElevatedButton(
                onPressed: canUpgrade
                    ? () {
                        Navigator.pop(context);
                        onUpgrade();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: Text('Upgrade (${building.upgradeCost})'),
              )
            else
              ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.grey[400],
                ),
                child: const Text('Max Level'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((255 * 0.3).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Stats',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (building.generation.isNotEmpty)
            _buildStatRow(
              'Produces',
              building.generation.entries
                  .map((e) => '${e.value.toStringAsFixed(1)} ${e.key}')
                  .join(', '),
              Colors.greenAccent,
            ),
          if (building.consumption.isNotEmpty)
            _buildStatRow(
              'Consumes',
              building.consumption.entries
                  .map((e) => '${e.value.toStringAsFixed(1)} ${e.key}')
                  .join(', '),
              Colors.orangeAccent,
            ),
          if (building.accommodationCapacity > 0)
            _buildStatRow(
              'Houses',
              '${building.accommodationCapacity} people',
              Colors.blueAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildUpgradePreview() {
    final nextLevel = building.level + 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha((255 * 0.3).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.arrow_upward,
                color: Colors.greenAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Level $nextLevel Preview',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (building.baseGeneration.isNotEmpty)
            _buildStatRow(
              'Produces',
              building.baseGeneration.entries
                  .map(
                    (e) =>
                        '${(e.value * nextLevel).toStringAsFixed(1)} ${e.key}',
                  )
                  .join(', '),
              Colors.greenAccent,
            ),
          if (building.baseConsumption.isNotEmpty)
            _buildStatRow(
              'Consumes',
              building.baseConsumption.entries
                  .map(
                    (e) =>
                        '${(e.value * nextLevel).toStringAsFixed(1)} ${e.key}',
                  )
                  .join(', '),
              Colors.orangeAccent,
            ),
          if (building.basePopulation > 0)
            _buildStatRow(
              'Houses',
              '${building.basePopulation * nextLevel} people',
              Colors.blueAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          Text(value, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
