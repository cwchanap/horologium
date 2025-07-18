import 'package:horologium/game/building.dart';

class Resources {
  Map<String, double> resources = {
    'electricity': 0,
    'money': 1000,
    'gold': 0,
    'wood': 0,
    'coal': 10,
    'research': 0,
    'water': 0,
  };
  int population = 0;
  
  // Track research accumulation (seconds)
  double _researchAccumulator = 0;

  void update(List<Building> buildings) {
    // Count active research labs for time-based generation
    int activeResearchLabs = 0;
    
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
          
          // Generate resources and count research labs
          building.generation.forEach((key, value) {
            if (key == 'research') {
              activeResearchLabs++;
            } else {
              resources.update(key, (v) => v + value, ifAbsent: () => value);
            }
          });
        }
      }
    }

    // Handle research point accumulation (1 point every 10 seconds per active lab)
    if (activeResearchLabs > 0) {
      _researchAccumulator += 1.0; // Add 1 second of time
      if (_researchAccumulator >= 10) {
        int pointsToAdd = activeResearchLabs; // 1 point per lab every 10 seconds
        resources.update('research', (v) => v + pointsToAdd, ifAbsent: () => pointsToAdd.toDouble());
        _researchAccumulator = 0; // Reset accumulator
      }
    }
  }

  double get money => resources['money']!;
  double get electricity => resources['electricity']!;
  double get gold => resources['gold']!;
  double get wood => resources['wood']!;
  double get coal => resources['coal']!;
  double get research => resources['research']!;
  double get water => resources['water']!;

  set money(double value) => resources['money'] = value;
  set electricity(double value) => resources['electricity'] = value;
  set gold(double value) => resources['gold'] = value;
  set wood(double value) => resources['wood'] = value;
  set coal(double value) => resources['coal'] = value;
  set research(double value) => resources['research'] = value;
  set water(double value) => resources['water'] = value;
}
