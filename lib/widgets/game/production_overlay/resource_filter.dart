/// Resource filter widget for the production overlay.
library;

import 'package:flutter/material.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/widgets/game/resource_icon.dart';

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
            // Filter out non-production resource types that aren't meaningful
            // for production chain visualization
            ...ResourceType.values
                .where(
                  (type) =>
                      type != ResourceType.cash &&
                      type != ResourceType.population &&
                      type != ResourceType.availableWorkers,
                )
                .map((type) {
                  return DropdownMenuItem<ResourceType?>(
                    value: type,
                    child: Row(
                      children: [
                        ResourceIcon(resourceType: type, size: 16),
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
