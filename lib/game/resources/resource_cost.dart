import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

class ResourceCost {
  final Map<ResourceType, double> resources;

  ResourceCost(Map<ResourceType, double> resources)
    : resources = Map.unmodifiable(
        Map.fromEntries(resources.entries.where((entry) => entry.value > 0)),
      );

  factory ResourceCost.cashOnly(num amount) {
    return ResourceCost({ResourceType.cash: amount.toDouble()});
  }

  static final empty = ResourceCost({});

  bool get isEmpty => resources.isEmpty;

  bool canAfford(Resources available) {
    return missingResources(available).isEmpty;
  }

  Map<ResourceType, double> missingResources(Resources available) {
    final missing = <ResourceType, double>{};
    for (final entry in resources.entries) {
      final current = available.getResource(entry.key);
      if (current < entry.value) {
        missing[entry.key] = entry.value - current;
      }
    }
    return missing;
  }

  bool deductFrom(Resources available) {
    if (!canAfford(available)) return false;

    for (final entry in resources.entries) {
      available.setResource(
        entry.key,
        available.getResource(entry.key) - entry.value,
      );
    }
    return true;
  }

  /// Formats this cost as a human-readable string (e.g. "100 Cash, 5 Wood").
  String toDisplayString() {
    return resources.entries
        .map(
          (entry) => '${_formatAmount(entry.value)} ${_displayName(entry.key)}',
        )
        .join(', ');
  }

  static String _formatAmount(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  static String _displayName(ResourceType type) {
    final resource = ResourceRegistry.find(type);
    if (resource != null) return resource.name;
    final name = type.name;
    return name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';
  }
}
