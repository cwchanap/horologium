import '../building/building.dart';
import '../research/research.dart';

class BuildingService {
  /// Set of building types that are gated behind research.
  static final Set<BuildingType> _researchGatedBuildings = {
    for (final research in Research.availableResearch)
      ...research.unlocksBuildings,
  };

  static List<Building> getAvailableBuildings(ResearchManager researchManager) {
    final unlockedBuildings = researchManager.getUnlockedBuildings();
    return BuildingRegistry.availableBuildings.where((building) {
      if (!_researchGatedBuildings.contains(building.type)) return true;
      return unlockedBuildings.contains(building.type);
    }).toList();
  }
}
