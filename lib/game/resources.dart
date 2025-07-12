import 'package:horologium/game/building.dart';

class Resources {
  int electricity = 0;
  int population = 0;
  int money = 1000;

  void update(List<Building> buildings) {
    int electricityGeneration = 0;
    int moneyGeneration = 0;

    for (final building in buildings) {
      electricityGeneration += building.generation['electricity'] ?? 0;
      moneyGeneration += building.generation['money'] ?? 0;
    }

    electricity += electricityGeneration;
    money += moneyGeneration;
  }
}
