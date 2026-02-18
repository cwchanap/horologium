import '../building/building.dart';
import '../research/research.dart';
import '../resources/resources.dart';
import 'placed_building_data.dart';

/// Represents a planet with all its game state including resources, research, buildings, and limits
class Planet {
  final String id;
  final String name;
  final Resources resources;
  final ResearchManager researchManager;
  final BuildingLimitManager buildingLimitManager;
  final List<PlacedBuildingData> _buildings;

  Planet({
    required this.id,
    required this.name,
    Resources? resources,
    ResearchManager? researchManager,
    BuildingLimitManager? buildingLimitManager,
    List<PlacedBuildingData>? buildings,
  }) : resources = resources ?? Resources(),
       researchManager = researchManager ?? ResearchManager(),
       buildingLimitManager = buildingLimitManager ?? BuildingLimitManager(),
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
    List<PlacedBuildingData>? buildings,
  }) {
    return Planet(
      id: id ?? this.id,
      name: name ?? this.name,
      resources: resources ?? this.resources,
      researchManager: researchManager ?? this.researchManager,
      buildingLimitManager: buildingLimitManager ?? this.buildingLimitManager,
      buildings: buildings ?? List.from(_buildings),
    );
  }

  @override
  String toString() {
    return 'Planet(id: $id, name: $name, buildings: ${_buildings.length})';
  }
}
