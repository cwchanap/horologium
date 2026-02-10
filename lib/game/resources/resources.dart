import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/resources/resource_type.dart';

// Shared happiness thresholds for consistent UI behavior across the app
class HappinessThresholds {
  static const double high = 60.0;
  static const double low = 30.0;
}

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
  int totalAccommodation = 0; // Total housing capacity from all buildings

  // Happiness system (0-100 scale)
  double _happiness = 50.0;
  int _populationGrowthAccumulator = 0; // Counts seconds for 30s growth cycle
  int _lowHappinessStreak = 0; // Counts consecutive low happiness cycles

  /// Happiness value clamped to valid range [0, 100]
  double get happiness => _happiness;
  set happiness(double value) {
    _happiness = value.clamp(0, 100);
  }

  // Track research accumulation (seconds)
  double _researchAccumulator = 0;

  void update(List<Building> buildings) {
    _calculateAccommodation(buildings);
    _updateAvailableWorkers(buildings);
    _processNonConsumingBuildings(buildings);
    final activeResearchLabs = _processConsumingBuildings(buildings);
    _accumulateResearch(activeResearchLabs);
    _updateHappiness(buildings, totalAccommodation);
  }

  void _calculateAccommodation(List<Building> buildings) {
    totalAccommodation = 0;
    for (final building in buildings) {
      if (building.type == BuildingType.house ||
          building.type == BuildingType.largeHouse) {
        totalAccommodation += building.accommodationCapacity;
      }
    }
    unshelteredPopulation = (population - totalAccommodation).clamp(
      0,
      population,
    );
  }

  void _updateAvailableWorkers(List<Building> buildings) {
    int totalAssignedWorkers = 0;
    for (final building in buildings) {
      totalAssignedWorkers += building.assignedWorkers;
    }
    availableWorkers = population - totalAssignedWorkers;
  }

  void _processNonConsumingBuildings(List<Building> buildings) {
    for (final building in buildings) {
      if (building.consumption.isEmpty) {
        if (building.type == BuildingType.house ||
            building.type == BuildingType.largeHouse ||
            building.hasWorkers) {
          building.generation.forEach((resourceType, value) {
            resources.update(
              resourceType,
              (v) => v + value,
              ifAbsent: () => value,
            );
          });
        }
      }
    }
  }

  int _processConsumingBuildings(List<Building> buildings) {
    int activeResearchLabs = 0;
    for (final building in buildings) {
      if (building.consumption.isEmpty) continue;

      bool canProduce = true;
      building.consumption.forEach((resourceType, value) {
        if ((resources[resourceType] ?? 0) < value) {
          canProduce = false;
        }
      });

      if (canProduce && building.hasWorkers) {
        building.consumption.forEach((resourceType, value) {
          resources.update(
            resourceType,
            (v) => v - value,
            ifAbsent: () => -value,
          );
        });

        building.generation.forEach((resourceType, value) {
          if (resourceType == ResourceType.research) {
            activeResearchLabs++;
          } else {
            resources.update(
              resourceType,
              (v) => v + value,
              ifAbsent: () => value,
            );
          }
        });
      }
    }
    return activeResearchLabs;
  }

  void _accumulateResearch(int activeResearchLabs) {
    if (activeResearchLabs > 0) {
      _researchAccumulator += 1.0;
      if (_researchAccumulator >= 10) {
        final pointsToAdd = activeResearchLabs;
        resources.update(
          ResourceType.research,
          (v) => v + pointsToAdd,
          ifAbsent: () => pointsToAdd.toDouble(),
        );
        _researchAccumulator = 0;
      }
    }
  }

  /// Calculates happiness based on housing, food, services, and employment.
  /// Also handles population growth/shrinkage every 30 seconds.
  void _updateHappiness(List<Building> buildings, int totalAccommodation) {
    // Factor weights (must sum to 1.0)
    const double housingWeight = 0.30;
    const double foodWeight = 0.25;
    const double servicesWeight = 0.25;
    const double employmentWeight = 0.20;

    // 1. Housing factor (0-100): ratio of sheltered population
    double housingFactor = 0;
    if (population > 0) {
      final shelteredPop = population - unshelteredPopulation;
      housingFactor = (shelteredPop / population) * 100;
    }

    // 2. Food factor (0-100): based on bread and pastries availability
    // Target: 1 food per 5 population for 100% satisfaction
    double foodFactor = 0;
    if (population > 0) {
      final totalFood = bread + pastries;
      final targetFood = population / 5.0;
      foodFactor = targetFood > 0
          ? ((totalFood / targetFood) * 100).clamp(0, 100)
          : 100;
    }

    // 3. Services factor (0-100): electricity and water per capita
    // Target: 1 electricity + 2 water per 10 population for 100%
    double servicesFactor = 0;
    if (population > 0) {
      final targetElectricity = population / 10.0;
      final targetWater = population / 5.0;
      final electricitySat = targetElectricity > 0
          ? (electricity / targetElectricity).clamp(0, 1)
          : 1;
      final waterSat = targetWater > 0 ? (water / targetWater).clamp(0, 1) : 1;
      servicesFactor = ((electricitySat + waterSat) / 2) * 100;
    }

    // 4. Employment factor (0-100): ratio of employed workers
    double employmentFactor = 0;
    if (population > 0) {
      final employedWorkers = population - availableWorkers;
      employmentFactor = (employedWorkers / population) * 100;
    }

    // Calculate weighted happiness
    final newHappiness =
        (housingFactor * housingWeight) +
        (foodFactor * foodWeight) +
        (servicesFactor * servicesWeight) +
        (employmentFactor * employmentWeight);

    // Smooth transition (gradual change for better UX)
    _happiness = (_happiness * 0.9 + newHappiness * 0.1).clamp(0, 100);

    // Population growth/shrinkage every 30 seconds
    _populationGrowthAccumulator++;
    if (_populationGrowthAccumulator >= 30) {
      _populationGrowthAccumulator = 0;

      if (happiness >= HappinessThresholds.high &&
          totalAccommodation > population) {
        // High happiness + housing available = population growth
        population++;
        availableWorkers++;
        _lowHappinessStreak = 0;
      } else if (happiness <= HappinessThresholds.low) {
        // Low happiness = track streak
        _lowHappinessStreak++;
        // After 2 consecutive low happiness cycles (60s), population shrinks
        if (_lowHappinessStreak >= 2 && population > 1) {
          decreasePopulation(buildings);
        }
      } else {
        // Medium happiness = reset low streak but no growth
        _lowHappinessStreak = 0;
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
  set polishedRice(double value) =>
      resources[ResourceType.polishedRice] = value;
  set maltedBarley(double value) =>
      resources[ResourceType.maltedBarley] = value;
  set bread(double value) => resources[ResourceType.bread] = value;
  set pastries(double value) => resources[ResourceType.pastries] = value;

  double getResource(ResourceType type) => resources[type] ?? 0;
  void setResource(ResourceType type, double value) => resources[type] = value;

  /// Returns true if there is spare housing capacity for population growth
  bool hasSpareHousingCapacity() {
    return totalAccommodation > population;
  }

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

  /// Decreases population by 1, handling worker unassignment if necessary.
  /// Called when happiness is low for an extended period.
  /// This maintains the invariant: population = availableWorkers + assignedWorkers
  void decreasePopulation(List<Building> buildings) {
    if (population <= 1) return;

    // Calculate total assigned workers BEFORE any changes
    int totalAssignedWorkers = 0;
    for (final building in buildings) {
      totalAssignedWorkers += building.assignedWorkers;
    }

    // Decrease population
    population--;

    // Case 1: We have available workers, just decrement them
    if (availableWorkers > 0) {
      availableWorkers--;
    }
    // Case 2: No available workers but some are assigned to buildings
    // Unassign one worker from a building to reduce total assigned count
    else if (totalAssignedWorkers > 0) {
      for (final building in buildings) {
        if (building.assignedWorkers > 0) {
          building.unassignWorker();
          break;
        }
      }
      // availableWorkers stays 0, totalAssignedWorkers decreases by 1
      // invariant maintained: (population - 1) = 0 + (totalAssignedWorkers - 1)
    }

    // Reset the low happiness streak to maintain 60s interval
    _lowHappinessStreak = 0;
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
      resources.update(
        ResourceType.cash,
        (v) => v + gain,
        ifAbsent: () => gain,
      );
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

enum PopulationTrend { growing, stable, shrinking }
