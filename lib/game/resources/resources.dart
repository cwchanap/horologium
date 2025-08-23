import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/resources/resource_type.dart';

class Resources {
  Map<ResourceType, double> resources = {
    ResourceType.electricity: 0,
    ResourceType.cash: 1000,
    ResourceType.gold: 0,
    ResourceType.wood: 0,
    ResourceType.coal: 10,
    ResourceType.research: 0,
    ResourceType.water: 0,
    ResourceType.planks: 0,
    ResourceType.stone: 0,
    ResourceType.wheat: 0,
    ResourceType.corn: 0,
    ResourceType.rice: 0,
    ResourceType.barley: 0,
    ResourceType.flour: 0,
    ResourceType.cornmeal: 0,
    ResourceType.polishedRice: 0,
    ResourceType.maltedBarley: 0,
    ResourceType.bread: 0,
    ResourceType.pastries: 0,
  };
  int population = 20; // Starting population
  int availableWorkers = 20; // Workers not assigned to buildings
  int unshelteredPopulation = 20;

  // Track research accumulation (seconds)
  double _researchAccumulator = 0;

  void update(List<Building> buildings) {
    // Calculate accommodation capacity
    int totalAccommodation = 0;
    for (final building in buildings) {
      if (building.type == BuildingType.house || building.type == BuildingType.largeHouse) {
        totalAccommodation += building.accommodationCapacity;
      }
    }

    // Update unsheltered population
    unshelteredPopulation = population - totalAccommodation;
    if (unshelteredPopulation < 0) {
      unshelteredPopulation = 0;
    }

    // Update available workers (total population minus assigned workers)
    int totalAssignedWorkers = 0;
    for (final building in buildings) {
      totalAssignedWorkers += building.assignedWorkers;
    }
    availableWorkers = population - totalAssignedWorkers;
    // Count active research labs for time-based generation
    int activeResearchLabs = 0;
    
    // First, generate resources from buildings that don't require consumption
    for (final building in buildings) {
      if (building.consumption.isEmpty) {
        // Buildings with no consumption generate if they have workers (except houses)
        if (building.type == BuildingType.house || building.type == BuildingType.largeHouse || building.hasWorkers) {
          building.generation.forEach((key, value) {
            final resourceType = ResourceType.values.firstWhere((e) => e.toString() == 'ResourceType.$key');
            resources.update(resourceType, (v) => v + value, ifAbsent: () => value);
          });
        }
      }
    }

    // Then, handle buildings with consumption requirements
    for (final building in buildings) {
      if (building.consumption.isNotEmpty) {
        bool canProduce = true;
        
        // Check if this building can consume what it needs
        building.consumption.forEach((key, value) {
          final resourceType = ResourceType.values.firstWhere((e) => e.toString() == 'ResourceType.$key');
          if ((resources[resourceType] ?? 0) < value) {
            canProduce = false;
          }
        });

        if (canProduce && building.hasWorkers) {
          // Consume resources
          building.consumption.forEach((key, value) {
            final resourceType = ResourceType.values.firstWhere((e) => e.toString() == 'ResourceType.$key');
            resources.update(resourceType, (v) => v - value, ifAbsent: () => -value);
          });
          
          // Generate resources and count research labs
          building.generation.forEach((key, value) {
            final resourceType = ResourceType.values.firstWhere((e) => e.toString() == 'ResourceType.$key');
            if (key == 'research') {
              activeResearchLabs++;
            } else {
              resources.update(resourceType, (v) => v + value, ifAbsent: () => value);
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
        resources.update(ResourceType.research, (v) => v + pointsToAdd, ifAbsent: () => pointsToAdd.toDouble());
        _researchAccumulator = 0; // Reset accumulator
      }
    }
  }

  double get cash => resources[ResourceType.cash]!;
  double get electricity => resources[ResourceType.electricity]!;
  double get gold => resources[ResourceType.gold]!;
  double get wood => resources[ResourceType.wood]!;
  double get coal => resources[ResourceType.coal]!;
  double get research => resources[ResourceType.research]!;
  double get water => resources[ResourceType.water]!;
  double get planks => resources[ResourceType.planks]!;
  double get stone => resources[ResourceType.stone]!;
  double get wheat => resources[ResourceType.wheat]!;
  double get corn => resources[ResourceType.corn]!;
  double get rice => resources[ResourceType.rice]!;
  double get barley => resources[ResourceType.barley]!;

  double get flour => resources[ResourceType.flour]!;
  double get cornmeal => resources[ResourceType.cornmeal]!;
  double get polishedRice => resources[ResourceType.polishedRice]!;
  double get maltedBarley => resources[ResourceType.maltedBarley]!;
  double get bread => resources[ResourceType.bread]!;
  double get pastries => resources[ResourceType.pastries]!;

  set cash(double value) => resources[ResourceType.cash] = value;
  set electricity(double value) => resources[ResourceType.electricity] = value;
  set gold(double value) => resources[ResourceType.gold] = value;
  set wood(double value) => resources[ResourceType.wood] = value;
  set coal(double value) => resources[ResourceType.coal] = value;
  set research(double value) => resources[ResourceType.research] = value;
  set water(double value) => resources[ResourceType.water] = value;
  set planks(double value) => resources[ResourceType.planks] = value;
  set stone(double value) => resources[ResourceType.stone] = value;
  set wheat(double value) => resources[ResourceType.wheat] = value;
  set corn(double value) => resources[ResourceType.corn] = value;
  set rice(double value) => resources[ResourceType.rice] = value;
  set barley(double value) => resources[ResourceType.barley] = value;

  set flour(double value) => resources[ResourceType.flour] = value;
  set cornmeal(double value) => resources[ResourceType.cornmeal] = value;
  set polishedRice(double value) => resources[ResourceType.polishedRice] = value;
  set maltedBarley(double value) => resources[ResourceType.maltedBarley] = value;
  set bread(double value) => resources[ResourceType.bread] = value;
  set pastries(double value) => resources[ResourceType.pastries] = value;
  
  // Helper methods for worker management
  bool canAssignWorkerTo(Building building) {
    return availableWorkers > 0 && building.canAssignWorker;
  }
  
  void assignWorkerTo(Building building) {
    if (canAssignWorkerTo(building)) {
      building.assignWorker();
      availableWorkers--;
    }
  }
  
  void unassignWorkerFrom(Building building) {
    if (building.assignedWorkers > 0) {
      building.unassignWorker();
      availableWorkers++;
    }
  }

  // Buy resource using cash (cost = resource value * 10)
  bool buyResource(ResourceType resourceType, double amount) {
    final resource = ResourceRegistry.find(resourceType);
    if (resource == null) return false;

    final cost = resource.value * 10 * amount;
    final currentCash = resources[ResourceType.cash] ?? 0;

    if (currentCash >= cost) {
      resources.update(ResourceType.cash, (v) => v - cost);
      resources.update(resourceType, (v) => v + amount, ifAbsent: () => amount);
      return true;
    }
    return false;
  }

  // Sell resource for cash (gain = resource value * 8)
  bool sellResource(ResourceType resourceType, double amount) {
    final resource = ResourceRegistry.find(resourceType);
    if (resource == null) return false;

    final currentAmount = resources[resourceType] ?? 0;
    if (currentAmount >= amount) {
      final gain = resource.value * 8 * amount;
      resources.update(resourceType, (v) => v - amount);
      resources.update(ResourceType.cash, (v) => v + gain, ifAbsent: () => gain);
      return true;
    }
    return false;
  }

  // Legacy trade method - kept for compatibility but should not be used for new cash-based trading
  void trade(ResourceType from, ResourceType to, double amount) {
    final fromResource = ResourceRegistry.find(from);
    final toResource = ResourceRegistry.find(to);

    if (fromResource == null || toResource == null) {
      return;
    }

    final fromValue = fromResource.value;
    final toValue = toResource.value;

    if ((resources[from] ?? 0) >= amount) {
      resources.update(from, (v) => v - amount);
      final amountToAdd = amount * fromValue * 0.8 / toValue;
      resources.update(to, (v) => v + amountToAdd, ifAbsent: () => amountToAdd);
    }
  }
}