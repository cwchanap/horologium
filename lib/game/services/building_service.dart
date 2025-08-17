import '../building/building.dart';
import '../research/research.dart';

class BuildingService {
  static List<Building> getAvailableBuildings(ResearchManager researchManager) {
    final unlockedBuildings = researchManager.getUnlockedBuildings();
    return BuildingRegistry.availableBuildings.where((building) {
      // Always allow basic buildings (not behind research)
      if (building.type == BuildingType.researchLab ||
          building.type == BuildingType.house ||
          building.type == BuildingType.largeHouse ||
          building.type == BuildingType.woodFactory ||
          building.type == BuildingType.coalMine ||
          building.type == BuildingType.waterTreatment ||
          building.type == BuildingType.sawmill ||
          building.type == BuildingType.quarry ||
          building.type == BuildingType.field ||
          building.type == BuildingType.bakery ||
          building.type == BuildingType.windMill ||
          building.type == BuildingType.grinderMill ||
          building.type == BuildingType.riceHuller ||
          building.type == BuildingType.maltHouse) {
        return true;
      }
      // Check if building is unlocked by research
      return unlockedBuildings.contains(building.type);
    }).toList();
  }
}
