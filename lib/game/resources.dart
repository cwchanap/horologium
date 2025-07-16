import 'package:horologium/game/building.dart';

class Resources {
  Map<String, double> resources = {
    'electricity': 0,
    'money': 1000,
    'gold': 0,
    'wood': 0,
    'coal': 10,
  };
  int population = 0;

  void update(List<Building> buildings) {
    // First, generate resources from buildings that don't require consumption
    for (final building in buildings) {
      if (building.consumption.isEmpty) {
        // Buildings with no consumption always generate
        building.generation.forEach((key, value) {
          resources.update(key, (v) => v + value, ifAbsent: () => value);
        });
      }
    }

    // Then, handle buildings with consumption requirements
    for (final building in buildings) {
      if (building.consumption.isNotEmpty) {
        bool canProduce = true;
        
        // Check if this building can consume what it needs
        building.consumption.forEach((key, value) {
          if ((resources[key] ?? 0) < value) {
            canProduce = false;
          }
        });

        if (canProduce) {
          // Consume resources
          building.consumption.forEach((key, value) {
            resources.update(key, (v) => v - value, ifAbsent: () => -value);
          });
          
          // Generate resources
          building.generation.forEach((key, value) {
            resources.update(key, (v) => v + value, ifAbsent: () => value);
          });
        }
      }
    }
  }

  double get money => resources['money']!;
  double get electricity => resources['electricity']!;
  double get gold => resources['gold']!;
  double get wood => resources['wood']!;
  double get coal => resources['coal']!;

  set money(double value) => resources['money'] = value;
  set electricity(double value) => resources['electricity'] = value;
  set gold(double value) => resources['gold'] = value;
  set wood(double value) => resources['wood'] = value;
  set coal(double value) => resources['coal'] = value;
}
