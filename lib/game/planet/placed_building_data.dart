import '../building/building.dart';

/// Data structure representing a building placed on the planet grid
class PlacedBuildingData {
  final int x;
  final int y;
  final BuildingType type;
  final int level;
  final int assignedWorkers;
  final String? variant; // For future use

  const PlacedBuildingData({
    required this.x,
    required this.y,
    required this.type,
    this.level = 1,
    this.assignedWorkers = 0,
    this.variant,
  });

  /// Convert to string format for persistence (legacy format compatibility)
  /// Format: "x,y,BuildingName"
  String toLegacyString() {
    return '$x,$y,${type.toString().split('.').last}';
  }

  /// Parse from legacy string format
  static PlacedBuildingData? fromLegacyString(String data) {
    final parts = data.split(',');
    if (parts.length < 3) return null;
    
    final x = int.tryParse(parts[0]);
    final y = int.tryParse(parts[1]);
    final typeName = parts[2];
    
    if (x == null || y == null) return null;
    
    // Find matching BuildingType
    BuildingType? type;
    for (final buildingType in BuildingType.values) {
      if (buildingType.toString().split('.').last == typeName) {
        type = buildingType;
        break;
      }
    }
    
    if (type == null) return null;
    
    return PlacedBuildingData(
      x: x,
      y: y,
      type: type,
      level: 1, // Legacy format doesn't include level
      assignedWorkers: 0, // Legacy format doesn't include worker count
    );
  }

  /// Create a Building instance from this placement data
  Building createBuilding() {
    final template = BuildingRegistry.availableBuildings
        .firstWhere((b) => b.type == type);
    
    return Building(
      type: template.type,
      name: template.name,
      description: template.description,
      icon: template.icon,
      assetPath: template.assetPath,
      color: template.color,
      baseCost: template.baseCost,
      baseGeneration: template.baseGeneration,
      baseConsumption: template.baseConsumption,
      basePopulation: template.basePopulation,
      maxLevel: template.maxLevel,
      gridSize: template.gridSize,
      baseBuildingLimit: template.baseBuildingLimit,
      requiredWorkers: template.requiredWorkers,
      category: template.category,
      level: level,
    )..assignedWorkers = assignedWorkers;
  }

  /// Create a copy with modified values
  PlacedBuildingData copyWith({
    int? x,
    int? y,
    BuildingType? type,
    int? level,
    int? assignedWorkers,
    String? variant,
  }) {
    return PlacedBuildingData(
      x: x ?? this.x,
      y: y ?? this.y,
      type: type ?? this.type,
      level: level ?? this.level,
      assignedWorkers: assignedWorkers ?? this.assignedWorkers,
      variant: variant ?? this.variant,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlacedBuildingData &&
        other.x == x &&
        other.y == y &&
        other.type == type &&
        other.level == level &&
        other.assignedWorkers == assignedWorkers &&
        other.variant == variant;
  }

  @override
  int get hashCode {
    return Object.hash(x, y, type, level, assignedWorkers, variant);
  }

  @override
  String toString() {
    return 'PlacedBuildingData(x: $x, y: $y, type: $type, level: $level, assignedWorkers: $assignedWorkers, variant: $variant)';
  }
}
