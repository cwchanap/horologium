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
}
