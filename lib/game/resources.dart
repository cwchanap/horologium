import 'package:horologium/game/building.dart';

class Resources {
  double electricity = 0;
  int population = 0;
  double money = 1000;
  double gold = 0;

  void update(List<Building> buildings) {
    double electricityGeneration = 0;
    double moneyGeneration = 0;
    double goldGeneration = 0;

    for (final building in buildings) {
      electricityGeneration += building.generation['electricity'] ?? 0;
      moneyGeneration += building.generation['money'] ?? 0;
      goldGeneration += building.generation['gold'] ?? 0;
    }

    electricity += electricityGeneration;
    money += moneyGeneration;
    gold += goldGeneration;
  }
}
