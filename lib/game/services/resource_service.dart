import '../building/building.dart';
import '../resources/resources.dart';

class ResourceService {
  static void updateResources(Resources resources, List<Building> buildings) {
    resources.update(buildings);
  }

  static bool canAffordBuilding(Resources resources, Building building) {
    return resources.cash >= building.cost;
  }

  static void purchaseBuilding(Resources resources, Building building) {
    if (canAffordBuilding(resources, building)) {
      resources.cash -= building.cost;
      
      // Auto-assign worker if the building requires one and workers are available
      if (building.requiredWorkers > 0) {
        resources.assignWorkerTo(building);
      }
    }
  }

  static void refundBuilding(Resources resources, Building building) {
    resources.cash += building.cost;
    
    // Unassign all workers when a building is removed
    while (building.assignedWorkers > 0) {
      resources.unassignWorkerFrom(building);
    }
  }
}