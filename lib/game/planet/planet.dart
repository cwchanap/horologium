import '../achievements/achievement.dart';
import '../achievements/achievement_manager.dart';
import '../building/building.dart';
import '../quests/quest_manager.dart';
import '../quests/quest_registry.dart';
import '../research/research.dart';
import '../research/research_type.dart';
import '../resources/resources.dart';
import 'placed_building_data.dart';

/// Represents a planet with all its game state including resources, research, buildings, and limits
class Planet {
  final String id;
  final String name;
  final Resources resources;
  final ResearchManager researchManager;
  final BuildingLimitManager buildingLimitManager;
  final QuestManager questManager;
  final AchievementManager achievementManager;
  final List<PlacedBuildingData> _buildings;

  /// Indicates if building limits JSON failed to parse during load
  final bool buildingLimitsParseError;

  /// Raw JSON that failed to parse, preserved for manual recovery
  final String? buildingLimitsRawJson;

  Planet({
    required this.id,
    required this.name,
    Resources? resources,
    ResearchManager? researchManager,
    BuildingLimitManager? buildingLimitManager,
    QuestManager? questManager,
    AchievementManager? achievementManager,
    List<PlacedBuildingData>? buildings,
    this.buildingLimitsParseError = false,
    this.buildingLimitsRawJson,
  }) : resources = resources ?? Resources(),
       researchManager = researchManager ?? ResearchManager(),
       buildingLimitManager = buildingLimitManager ?? BuildingLimitManager(),
       questManager =
           questManager ?? QuestManager(quests: QuestRegistry.starterQuests),
       achievementManager =
           achievementManager ??
           AchievementManager(achievements: Planet.defaultAchievements()),
       _buildings = buildings ?? [];

  /// Get a copy of all buildings on this planet
  List<PlacedBuildingData> get buildings => List.unmodifiable(_buildings);

  /// Get active Building instances from the placement data
  List<Building> getActiveBuildings() {
    return _buildings.map((data) => data.createBuilding()).nonNulls.toList();
  }

  /// Replace all buildings with a new list
  void setBuildings(List<PlacedBuildingData> buildings) {
    _buildings.clear();
    _buildings.addAll(buildings);
  }

  /// Add a building to the planet
  void addBuilding(PlacedBuildingData building) {
    _buildings.add(building);
  }

  /// Remove a building at specific coordinates
  bool removeBuildingAt(int x, int y) {
    final index = _buildings.indexWhere((b) => b.x == x && b.y == y);
    if (index != -1) {
      _buildings.removeAt(index);
      return true;
    }
    return false;
  }

  /// Find a building at specific coordinates
  PlacedBuildingData? getBuildingAt(int x, int y) {
    try {
      return _buildings.firstWhere((b) => b.x == x && b.y == y);
    } catch (e) {
      return null;
    }
  }

  /// Check if a position is occupied by a building
  bool isPositionOccupied(int x, int y) {
    return getBuildingAt(x, y) != null;
  }

  /// Update a building at specific coordinates
  bool updateBuildingAt(int x, int y, PlacedBuildingData newData) {
    final index = _buildings.indexWhere((b) => b.x == x && b.y == y);
    if (index != -1) {
      _buildings[index] = newData;
      return true;
    }
    return false;
  }

  /// Get count of specific building type
  int getBuildingCount(BuildingType type) {
    return _buildings.where((b) => b.type == type).length;
  }

  /// Create a copy of this planet with modified values
  Planet copyWith({
    String? id,
    String? name,
    Resources? resources,
    ResearchManager? researchManager,
    BuildingLimitManager? buildingLimitManager,
    QuestManager? questManager,
    AchievementManager? achievementManager,
    List<PlacedBuildingData>? buildings,
    bool? buildingLimitsParseError,
    String? buildingLimitsRawJson,
  }) {
    return Planet(
      id: id ?? this.id,
      name: name ?? this.name,
      resources: resources ?? this.resources,
      researchManager: researchManager ?? this.researchManager,
      buildingLimitManager: buildingLimitManager ?? this.buildingLimitManager,
      questManager: questManager ?? this.questManager,
      achievementManager: achievementManager ?? this.achievementManager,
      buildings: buildings ?? List.from(_buildings),
      buildingLimitsParseError:
          buildingLimitsParseError ?? this.buildingLimitsParseError,
      buildingLimitsRawJson:
          buildingLimitsRawJson ?? this.buildingLimitsRawJson,
    );
  }

  @override
  String toString() {
    return 'Planet(id: $id, name: $name, buildings: ${_buildings.length})';
  }

  static List<Achievement> defaultAchievements() {
    return [
      Achievement(
        id: 'ach_first_building',
        name: 'Foundation',
        description: 'Place your first building',
        type: AchievementType.buildingCount,
        targetAmount: 1,
      ),
      Achievement(
        id: 'ach_builder_10',
        name: 'Builder',
        description: 'Place 10 buildings',
        type: AchievementType.buildingCount,
        targetAmount: 10,
      ),
      Achievement(
        id: 'ach_builder_50',
        name: 'Architect',
        description: 'Place 50 buildings',
        type: AchievementType.buildingCount,
        targetAmount: 50,
      ),
      Achievement(
        id: 'ach_population_50',
        name: 'Small Town',
        description: 'Reach 50 population',
        type: AchievementType.populationReached,
        targetAmount: 50,
      ),
      Achievement(
        id: 'ach_population_200',
        name: 'City',
        description: 'Reach 200 population',
        type: AchievementType.populationReached,
        targetAmount: 200,
      ),
      Achievement(
        id: 'ach_rich',
        name: 'Wealthy',
        description: 'Accumulate 10,000 cash',
        type: AchievementType.resourceAccumulated,
        targetAmount: 10000,
        targetId: 'cash',
      ),
      Achievement(
        id: 'ach_all_research',
        name: 'Scholar',
        description: 'Complete all research',
        type: AchievementType.researchCompleted,
        // Dynamic target: tracks the total number of ResearchType enum values.
        // If ResearchType entries are added or removed, update migration logic
        // in SaveService to preserve players' earned achievement state.
        targetAmount: ResearchType.values.length,
      ),
      Achievement(
        id: 'ach_happiness_90',
        name: 'Utopia',
        description: 'Achieve 90+ happiness',
        type: AchievementType.happinessReached,
        targetAmount: 90,
      ),
    ];
  }
}
