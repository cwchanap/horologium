/// Resource filter widget for the production overlay.
library;

import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';

/// Dropdown widget for filtering the overlay by resource type.
class ResourceFilterWidget extends StatelessWidget {
  final ResourceType? selectedFilter;
  final ValueChanged<ResourceType?> onFilterChanged;

  const ResourceFilterWidget({
    super.key,
    this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selectedFilter != null
              ? Colors.cyanAccent.withAlpha(128)
              : Colors.grey[700]!,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ResourceType?>(
          value: selectedFilter,
          hint: const Text(
            'All Resources',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          icon: const Icon(Icons.filter_list, color: Colors.grey, size: 18),
          dropdownColor: Colors.grey[800],
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: [
            const DropdownMenuItem<ResourceType?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.clear_all, color: Colors.grey, size: 16),
                  SizedBox(width: 8),
                  Text('All Resources'),
                ],
              ),
            ),
            ...ResourceType.values.map((type) {
              return DropdownMenuItem<ResourceType?>(
                value: type,
                child: Row(
                  children: [
                    _getResourceIcon(type),
                    const SizedBox(width: 8),
                    Text(_formatResourceName(type.name)),
                  ],
                ),
              );
            }),
          ],
          onChanged: onFilterChanged,
        ),
      ),
    );
  }

  Widget _getResourceIcon(ResourceType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case ResourceType.cash:
        iconData = Icons.attach_money;
        iconColor = Colors.green;
        break;
      case ResourceType.gold:
        iconData = Icons.monetization_on;
        iconColor = Colors.amber;
        break;
      case ResourceType.coal:
        iconData = Icons.terrain;
        iconColor = Colors.brown;
        break;
      case ResourceType.electricity:
        iconData = Icons.bolt;
        iconColor = Colors.yellow;
        break;
      case ResourceType.water:
        iconData = Icons.water_drop;
        iconColor = Colors.blue;
        break;
      case ResourceType.wood:
        iconData = Icons.forest;
        iconColor = Colors.green;
        break;
      case ResourceType.stone:
        iconData = Icons.landscape;
        iconColor = Colors.grey;
        break;
      case ResourceType.population:
        iconData = Icons.people;
        iconColor = Colors.purple;
        break;
      case ResourceType.research:
        iconData = Icons.science;
        iconColor = Colors.deepPurple;
        break;
      case ResourceType.planks:
        iconData = Icons.view_column;
        iconColor = Colors.brown;
        break;
      case ResourceType.wheat:
        iconData = Icons.grass;
        iconColor = Colors.amber;
        break;
      case ResourceType.corn:
        iconData = Icons.grain;
        iconColor = Colors.yellow;
        break;
      case ResourceType.rice:
        iconData = Icons.rice_bowl;
        iconColor = Colors.white70;
        break;
      case ResourceType.barley:
        iconData = Icons.spa;
        iconColor = Colors.brown;
        break;
      case ResourceType.flour:
        iconData = Icons.bakery_dining;
        iconColor = Colors.white;
        break;
      case ResourceType.bread:
        iconData = Icons.breakfast_dining;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.category;
        iconColor = Colors.grey;
        break;
    }

    return Icon(iconData, size: 16, color: iconColor);
  }

  String _formatResourceName(String name) {
    // Convert camelCase to Title Case
    return name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim()
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }
}
