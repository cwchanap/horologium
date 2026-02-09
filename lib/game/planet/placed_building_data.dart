import 'package:uuid/uuid.dart';
import '../building/building.dart';

/// Data structure representing a building placed on the planet grid
class PlacedBuildingData {
  final String id;
  final int x;
  final int y;
  final BuildingType type;
  final int level;
  final int assignedWorkers;
  final String? variant; // For future use

  const PlacedBuildingData({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
    this.level = 1,
    this.assignedWorkers = 0,
    this.variant,
  }) : assert(level >= 1, 'level must be at least 1'),
       assert(assignedWorkers >= 0, 'assignedWorkers cannot be negative');

  /// Convert to string format for persistence
  /// Format: "id,x,y,BuildingName,level,assignedWorkers"
  String toLegacyString() {
    return '$id,$x,$y,${type.toString().split('.').last},$level,$assignedWorkers';
  }

  /// Parse from legacy string format
  /// Supports:
  /// - New format: "id,x,y,BuildingName,level,workers"
  /// - Old format: "x,y,BuildingName,level,workers" (generates new ID)
  /// - Very old format: "x,y,BuildingName" (generates new ID, level=1, workers=0)
  static PlacedBuildingData? fromLegacyString(String data) {
    final parts = data.split(',');
    if (parts.isEmpty) return null;

    // Detect format: if first part is not a pure integer and contains a dash or is long,
    // assume it's the ID in new format. Otherwise, it's the old format.
    final firstPart = parts[0];
    final isInteger = int.tryParse(firstPart) != null;
    final looksLikeId =
        !isInteger && (firstPart.contains('-') || firstPart.length > 8);

    String id;
    int xIndex, yIndex, typeIndex;

    if (looksLikeId && parts.length >= 4) {
      // New format: id,x,y,type,...
      id = firstPart;
      xIndex = 1;
      yIndex = 2;
      typeIndex = 3;
    } else if (parts.length >= 3) {
      // Old format without ID: x,y,type,...
      id = const Uuid().v4();
      xIndex = 0;
      yIndex = 1;
      typeIndex = 2;
    } else {
      return null;
    }

    final x = int.tryParse(parts[xIndex]);
    final y = int.tryParse(parts[yIndex]);
    final typeName = parts[typeIndex];

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

    // Parse level and workers based on format
    final levelIndex = typeIndex + 1;
    final workersIndex = typeIndex + 2;

    final parsedLevel = parts.length > levelIndex
        ? int.tryParse(parts[levelIndex])
        : null;
    final level = (parsedLevel == null || parsedLevel < 1) ? 1 : parsedLevel;

    final parsedWorkers = parts.length > workersIndex
        ? int.tryParse(parts[workersIndex])
        : null;
    final assignedWorkers = (parsedWorkers == null || parsedWorkers < 0)
        ? 0
        : parsedWorkers;

    return PlacedBuildingData(
      id: id,
      x: x,
      y: y,
      type: type,
      level: level,
      assignedWorkers: assignedWorkers,
    );
  }

  /// Create a Building instance from this placement data
  Building createBuilding() {
    final template = BuildingRegistry.availableBuildings.firstWhere(
      (b) => b.type == type,
    );

    return Building(
      id: id,
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
    String? id,
    int? x,
    int? y,
    BuildingType? type,
    int? level,
    int? assignedWorkers,
    String? variant,
  }) {
    return PlacedBuildingData(
      id: id ?? this.id,
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
        other.id == id &&
        other.x == x &&
        other.y == y &&
        other.type == type &&
        other.level == level &&
        other.assignedWorkers == assignedWorkers &&
        other.variant == variant;
  }

  @override
  int get hashCode {
    return Object.hash(id, x, y, type, level, assignedWorkers, variant);
  }

  @override
  String toString() {
    return 'PlacedBuildingData(id: $id, x: $x, y: $y, type: $type, level: $level, assignedWorkers: $assignedWorkers, variant: $variant)';
  }
}
