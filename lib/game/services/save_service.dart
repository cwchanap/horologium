import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../building/building.dart';
import '../planet/index.dart';
import '../research/research.dart';
import '../resources/resource_type.dart';
import '../resources/resources.dart';

class SaveService {
  static const String _keyCash = 'cash';
  static const String _keyPopulation = 'population';
  static const String _keyAvailableWorkers = 'availableWorkers';
  static const String _keyGold = 'gold';
  static const String _keyWood = 'wood';
  static const String _keyCoal = 'coal';
  static const String _keyElectricity = 'electricity';
  static const String _keyResearch = 'research';
  static const String _keyWater = 'water';
  static const String _keyHappiness = 'happiness';
  static const String _keyCompletedResearch = 'completed_research';
  static const String _keyBuildings = 'buildings';

  // New planet-scoped keys
  static const String _keyActivePlanet = 'active_planet';

  // Planet key conventions
  static String _planetResourceKey(String planetId, String resourceKey) =>
      'planet.$planetId.resources.$resourceKey';
  static String _planetResourcesJsonKey(String planetId) =>
      'planet.$planetId.resources_json';
  static String _planetPopulationKey(String planetId) =>
      'planet.$planetId.population';
  static String _planetAvailableWorkersKey(String planetId) =>
      'planet.$planetId.availableWorkers';
  static String _planetHappinessKey(String planetId) =>
      'planet.$planetId.happiness';
  static String _planetResearchKey(String planetId) =>
      'planet.$planetId.research.completed';
  static String _planetBuildingLimitsKey(String planetId) =>
      'planet.$planetId.buildingLimits';
  static String _planetBuildingsKey(String planetId) =>
      'planet.$planetId.buildings';

  /// Deprecated: Use [savePlanet] instead.
  ///
  /// This method writes individual resource keys which conflicts with the new
  /// JSON-based savePlanet format. Migrate to savePlanet for consolidated
  /// planet persistence.
  @Deprecated(
    'Use savePlanet instead. This method will be removed in a future version.',
  )
  static Future<void> saveGameState({
    required Resources resources,
    required ResearchManager researchManager,
    List<String>? buildingData,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Save resources
    await prefs.setDouble(_keyCash, resources.cash);
    await prefs.setInt(_keyPopulation, resources.population);
    await prefs.setInt(_keyAvailableWorkers, resources.availableWorkers);
    await prefs.setDouble(_keyGold, resources.gold);
    await prefs.setDouble(_keyWood, resources.wood);
    await prefs.setDouble(_keyCoal, resources.coal);
    await prefs.setDouble(_keyElectricity, resources.electricity);
    await prefs.setDouble(_keyResearch, resources.research);
    await prefs.setDouble(_keyWater, resources.water);
    await prefs.setDouble(_keyHappiness, resources.happiness);

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
    resources.cash = prefs.getDouble(_keyCash) ?? 1000.0;
    resources.population = prefs.getInt(_keyPopulation) ?? 20;
    resources.availableWorkers =
        prefs.getInt(_keyAvailableWorkers) ?? resources.population;
    resources.gold = prefs.getDouble(_keyGold) ?? 0.0;
    resources.wood = prefs.getDouble(_keyWood) ?? 0.0;
    resources.coal = prefs.getDouble(_keyCoal) ?? 10.0;
    resources.electricity = prefs.getDouble(_keyElectricity) ?? 0.0;
    resources.research = prefs.getDouble(_keyResearch) ?? 0.0;
    resources.water = prefs.getDouble(_keyWater) ?? 0.0;
    resources.happiness = prefs.getDouble(_keyHappiness) ?? 50.0;

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

  // ============================================================================
  // PLANET-AWARE APIS
  // ============================================================================

  /// Save a planet's complete state to SharedPreferences
  static Future<void> savePlanet(Planet planet) async {
    final prefs = await SharedPreferences.getInstance();
    final planetId = planet.id;

    // Save all resources as a single JSON string
    final resourceJson = jsonEncode(
      planet.resources.resources.map((k, v) => MapEntry(k.name, v)),
    );
    await prefs.setString(_planetResourcesJsonKey(planetId), resourceJson);

    // Save population data
    await prefs.setInt(
      _planetPopulationKey(planetId),
      planet.resources.population,
    );
    await prefs.setInt(
      _planetAvailableWorkersKey(planetId),
      planet.resources.availableWorkers,
    );

    // Save happiness
    await prefs.setDouble(
      _planetHappinessKey(planetId),
      planet.resources.happiness,
    );

    // Save research progress
    await prefs.setStringList(
      _planetResearchKey(planetId),
      planet.researchManager.toList(),
    );

    // Save building limits
    final buildingLimitsJson = jsonEncode(planet.buildingLimitManager.toMap());
    await prefs.setString(
      _planetBuildingLimitsKey(planetId),
      buildingLimitsJson,
    );

    // Save buildings (using legacy format for now)
    final buildingStrings = planet.buildings
        .map((b) => b.toLegacyString())
        .toList();
    await prefs.setStringList(_planetBuildingsKey(planetId), buildingStrings);
  }

  /// Load or create a planet from SharedPreferences
  static Future<Planet> loadOrCreatePlanet(
    String planetId, {
    String name = 'Earth',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Check if planet data exists (new JSON format or old per-resource keys)
    final hasJsonData = prefs.containsKey(_planetResourcesJsonKey(planetId));
    final hasOldData = prefs.containsKey(_planetResourceKey(planetId, 'cash'));

    if (!hasJsonData && !hasOldData) {
      // Check for migration from legacy keys
      final hasLegacyData = prefs.containsKey(_keyCash);
      if (hasLegacyData && planetId == 'earth') {
        return await _migrateLegacyToEarth();
      }

      // Create new planet with defaults
      return Planet(id: planetId, name: name);
    }

    // Load existing planet data
    final resources = Resources();

    if (hasJsonData) {
      // Load from JSON format
      try {
        final json =
            jsonDecode(prefs.getString(_planetResourcesJsonKey(planetId))!)
                as Map<String, dynamic>;
        for (final entry in json.entries) {
          final type = ResourceType.values
              .where((t) => t.name == entry.key)
              .firstOrNull;
          if (type != null) {
            resources.resources[type] = (entry.value as num).toDouble();
          }
        }
      } catch (e, stackTrace) {
        // Log parse errors with context to aid debugging
        final rawJson = prefs.getString(_planetResourcesJsonKey(planetId));
        debugPrint('Failed to parse resources JSON for planet $planetId: $e');
        debugPrint('Stack trace: $stackTrace');
        debugPrint('Raw JSON: $rawJson');

        // Attempt to load from old per-resource keys as fallback
        if (hasOldData) {
          debugPrint('Attempting to load from legacy per-resource keys...');
          resources.cash =
              prefs.getDouble(_planetResourceKey(planetId, 'cash')) ?? 1000.0;
          resources.gold =
              prefs.getDouble(_planetResourceKey(planetId, 'gold')) ?? 0.0;
          resources.wood =
              prefs.getDouble(_planetResourceKey(planetId, 'wood')) ?? 0.0;
          resources.coal =
              prefs.getDouble(_planetResourceKey(planetId, 'coal')) ?? 10.0;
          resources.electricity =
              prefs.getDouble(_planetResourceKey(planetId, 'electricity')) ??
              0.0;
          resources.research =
              prefs.getDouble(_planetResourceKey(planetId, 'research')) ?? 0.0;
          resources.water =
              prefs.getDouble(_planetResourceKey(planetId, 'water')) ?? 0.0;
          resources.planks =
              prefs.getDouble(_planetResourceKey(planetId, 'planks')) ?? 0.0;
          resources.stone =
              prefs.getDouble(_planetResourceKey(planetId, 'stone')) ?? 0.0;
          resources.wheat =
              prefs.getDouble(_planetResourceKey(planetId, 'wheat')) ?? 0.0;
          resources.corn =
              prefs.getDouble(_planetResourceKey(planetId, 'corn')) ?? 0.0;
          resources.rice =
              prefs.getDouble(_planetResourceKey(planetId, 'rice')) ?? 0.0;
          resources.barley =
              prefs.getDouble(_planetResourceKey(planetId, 'barley')) ?? 0.0;
          resources.flour =
              prefs.getDouble(_planetResourceKey(planetId, 'flour')) ?? 0.0;
          resources.cornmeal =
              prefs.getDouble(_planetResourceKey(planetId, 'cornmeal')) ?? 0.0;
          resources.polishedRice =
              prefs.getDouble(_planetResourceKey(planetId, 'polishedRice')) ??
              0.0;
          resources.maltedBarley =
              prefs.getDouble(_planetResourceKey(planetId, 'maltedBarley')) ??
              0.0;
          resources.bread =
              prefs.getDouble(_planetResourceKey(planetId, 'bread')) ?? 0.0;
          resources.pastries =
              prefs.getDouble(_planetResourceKey(planetId, 'pastries')) ?? 0.0;
        }
        // If no old data exists, use defaults (already set in Resources constructor)
      }
    } else {
      // Migrate from old per-resource keys
      resources.cash =
          prefs.getDouble(_planetResourceKey(planetId, 'cash')) ?? 1000.0;
      resources.gold =
          prefs.getDouble(_planetResourceKey(planetId, 'gold')) ?? 0.0;
      resources.wood =
          prefs.getDouble(_planetResourceKey(planetId, 'wood')) ?? 0.0;
      resources.coal =
          prefs.getDouble(_planetResourceKey(planetId, 'coal')) ?? 10.0;
      resources.electricity =
          prefs.getDouble(_planetResourceKey(planetId, 'electricity')) ?? 0.0;
      resources.research =
          prefs.getDouble(_planetResourceKey(planetId, 'research')) ?? 0.0;
      resources.water =
          prefs.getDouble(_planetResourceKey(planetId, 'water')) ?? 0.0;
      resources.planks =
          prefs.getDouble(_planetResourceKey(planetId, 'planks')) ?? 0.0;
      resources.stone =
          prefs.getDouble(_planetResourceKey(planetId, 'stone')) ?? 0.0;
      resources.wheat =
          prefs.getDouble(_planetResourceKey(planetId, 'wheat')) ?? 0.0;
      resources.corn =
          prefs.getDouble(_planetResourceKey(planetId, 'corn')) ?? 0.0;
      resources.rice =
          prefs.getDouble(_planetResourceKey(planetId, 'rice')) ?? 0.0;
      resources.barley =
          prefs.getDouble(_planetResourceKey(planetId, 'barley')) ?? 0.0;
      resources.flour =
          prefs.getDouble(_planetResourceKey(planetId, 'flour')) ?? 0.0;
      resources.cornmeal =
          prefs.getDouble(_planetResourceKey(planetId, 'cornmeal')) ?? 0.0;
      resources.polishedRice =
          prefs.getDouble(_planetResourceKey(planetId, 'polishedRice')) ?? 0.0;
      resources.maltedBarley =
          prefs.getDouble(_planetResourceKey(planetId, 'maltedBarley')) ?? 0.0;
      resources.bread =
          prefs.getDouble(_planetResourceKey(planetId, 'bread')) ?? 0.0;
      resources.pastries =
          prefs.getDouble(_planetResourceKey(planetId, 'pastries')) ?? 0.0;
    }

    resources.population = prefs.getInt(_planetPopulationKey(planetId)) ?? 20;
    resources.availableWorkers =
        prefs.getInt(_planetAvailableWorkersKey(planetId)) ??
        resources.population;
    resources.happiness =
        prefs.getDouble(_planetHappinessKey(planetId)) ?? 50.0;

    // Load research progress
    final researchManager = ResearchManager();
    final completedResearch =
        prefs.getStringList(_planetResearchKey(planetId)) ?? [];
    researchManager.loadFromList(completedResearch);

    // Load building limits
    final buildingLimitManager = BuildingLimitManager();
    final buildingLimitsJson = prefs.getString(
      _planetBuildingLimitsKey(planetId),
    );
    if (buildingLimitsJson != null) {
      try {
        final limitsMap =
            jsonDecode(buildingLimitsJson) as Map<String, dynamic>;
        buildingLimitManager.loadFromMap(limitsMap.cast<String, int>());
      } catch (e) {
        // If parsing fails, use defaults
      }
    }

    // Load buildings
    final buildingStrings =
        prefs.getStringList(_planetBuildingsKey(planetId)) ?? [];
    final buildings = buildingStrings
        .map((s) => PlacedBuildingData.fromLegacyString(s))
        .where((b) => b != null)
        .cast<PlacedBuildingData>()
        .toList();

    return Planet(
      id: planetId,
      name: name,
      resources: resources,
      researchManager: researchManager,
      buildingLimitManager: buildingLimitManager,
      buildings: buildings,
    );
  }

  /// Save the active planet ID
  static Future<void> saveActivePlanetId(String planetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActivePlanet, planetId);
  }

  /// Load the active planet ID
  static Future<String?> loadActivePlanetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActivePlanet);
  }

  /// Migrate legacy save data to Earth planet format (one-time migration)
  static Future<Planet> _migrateLegacyToEarth() async {
    final prefs = await SharedPreferences.getInstance();

    // Load legacy data
    final resources = Resources();
    resources.cash = prefs.getDouble(_keyCash) ?? 1000.0;
    resources.population = prefs.getInt(_keyPopulation) ?? 20;
    resources.availableWorkers =
        prefs.getInt(_keyAvailableWorkers) ?? resources.population;
    resources.gold = prefs.getDouble(_keyGold) ?? 0.0;
    resources.wood = prefs.getDouble(_keyWood) ?? 0.0;
    resources.coal = prefs.getDouble(_keyCoal) ?? 10.0;
    resources.electricity = prefs.getDouble(_keyElectricity) ?? 0.0;
    resources.research = prefs.getDouble(_keyResearch) ?? 0.0;
    resources.water = prefs.getDouble(_keyWater) ?? 0.0;
    // Use default 50.0 for migrated games (legacy saves didn't have happiness)
    resources.happiness = prefs.getDouble(_keyHappiness) ?? 50.0;

    final researchManager = ResearchManager();
    final completedResearch = prefs.getStringList(_keyCompletedResearch) ?? [];
    researchManager.loadFromList(completedResearch);

    final buildingStrings = prefs.getStringList(_keyBuildings) ?? [];
    final buildings = buildingStrings
        .map((s) => PlacedBuildingData.fromLegacyString(s))
        .where((b) => b != null)
        .cast<PlacedBuildingData>()
        .toList();

    // Create Earth planet with migrated data
    final earth = Planet(
      id: 'earth',
      name: 'Earth',
      resources: resources,
      researchManager: researchManager,
      buildings: buildings,
    );

    // Save to new format
    await savePlanet(earth);
    await saveActivePlanetId('earth');

    // Optionally clear legacy keys after successful migration
    // For safety, we'll keep them for now until we verify the new system works

    return earth;
  }
}
