import 'package:shared_preferences/shared_preferences.dart';

import '../research/research.dart';
import '../resources/resources.dart';

class SaveService {
  static const String _keyMoney = 'money';
  static const String _keyPopulation = 'population';
  static const String _keyAvailableWorkers = 'availableWorkers';
  static const String _keyGold = 'gold';
  static const String _keyWood = 'wood';
  static const String _keyCoal = 'coal';
  static const String _keyElectricity = 'electricity';
  static const String _keyResearch = 'research';
  static const String _keyWater = 'water';
  static const String _keyCompletedResearch = 'completed_research';
  static const String _keyBuildings = 'buildings';

  static Future<void> saveGameState({
    required Resources resources,
    required ResearchManager researchManager,
    List<String>? buildingData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save resources
    await prefs.setDouble(_keyMoney, resources.money);
    await prefs.setInt(_keyPopulation, resources.population);
    await prefs.setInt(_keyAvailableWorkers, resources.availableWorkers);
    await prefs.setDouble(_keyGold, resources.gold);
    await prefs.setDouble(_keyWood, resources.wood);
    await prefs.setDouble(_keyCoal, resources.coal);
    await prefs.setDouble(_keyElectricity, resources.electricity);
    await prefs.setDouble(_keyResearch, resources.research);
    await prefs.setDouble(_keyWater, resources.water);
    
    // Save research progress
    await prefs.setStringList(_keyCompletedResearch, researchManager.toList());
    
    // Save buildings if provided
    if (buildingData != null) {
      await prefs.setStringList(_keyBuildings, buildingData);
    }
  }

  static Future<void> loadGameState({
    required Resources resources,
    required ResearchManager researchManager,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load resources with defaults
    resources.money = prefs.getDouble(_keyMoney) ?? 1000.0;
    resources.population = prefs.getInt(_keyPopulation) ?? 20;
    resources.availableWorkers = prefs.getInt(_keyAvailableWorkers) ?? resources.population;
    resources.gold = prefs.getDouble(_keyGold) ?? 0.0;
    resources.wood = prefs.getDouble(_keyWood) ?? 0.0;
    resources.coal = prefs.getDouble(_keyCoal) ?? 10.0;
    resources.electricity = prefs.getDouble(_keyElectricity) ?? 0.0;
    resources.research = prefs.getDouble(_keyResearch) ?? 0.0;
    resources.water = prefs.getDouble(_keyWater) ?? 0.0;

    // Load research progress
    final completedResearch = prefs.getStringList(_keyCompletedResearch) ?? [];
    researchManager.loadFromList(completedResearch);
  }

  static Future<List<String>?> loadBuildingData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyBuildings);
  }

  static Future<void> saveBuildingData(List<String> buildingData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBuildings, buildingData);
  }

  static Future<void> clearSaveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}