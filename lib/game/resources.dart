import 'package:horologium/game/building.dart';

class Resources {
  Map<String, double> resources = {
    'electricity': 0,
    'money': 1000,
    'gold': 0,
    'wood': 0,
    'coal': 0,
  };
  int population = 0;

  void update(List<Building> buildings) {
    final generation = <String, double>{};
    final consumption = <String, double>{};

    for (final building in buildings) {
      building.generation.forEach((key, value) {
        generation.update(key, (v) => v + value, ifAbsent: () => value);
      });
      building.consumption.forEach((key, value) {
        consumption.update(key, (v) => v + value, ifAbsent: () => value);
      });
    }

    bool canProduce = true;
    consumption.forEach((key, value) {
      if ((resources[key] ?? 0) < value) {
        canProduce = false;
      }
    });

    if (canProduce) {
      consumption.forEach((key, value) {
        resources.update(key, (v) => v - value);
      });

      generation.forEach((key, value) {
        resources.update(key, (v) => v + value, ifAbsent: () => value);
      });
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
