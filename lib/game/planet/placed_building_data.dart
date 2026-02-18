import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../building/building.dart';
import '../resources/resource_type.dart';

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
  /// Format: "id,x,y,BuildingName,level,assignedWorkers,variant"
  /// Note: variant is percent-encoded to safely handle commas
  String toLegacyString() {
    final base =
        '$id,$x,$y,${type.toString().split('.').last},$level,$assignedWorkers';
    if (variant != null) {
      // Percent-encode variant to prevent comma injection
      return '$base,${Uri.encodeComponent(variant!)}';
    }
    return base;
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

    // Parse optional variant field (percent-decoded for safety)
    final variantIndex = typeIndex + 3;
    String? variant;
    if (parts.length > variantIndex) {
      try {
        variant = Uri.decodeComponent(parts[variantIndex]);
      } catch (e) {
        // If decoding fails, use raw value for backward compatibility
        variant = parts[variantIndex];
        debugPrint('Failed to decode variant: $e, using raw value');
      }
    }

    return PlacedBuildingData(
      id: id,
      x: x,
      y: y,
      type: type,
      level: level,
      assignedWorkers: assignedWorkers,
      variant: variant,
    );
  }

  /// Create a Building instance from this placement data.
  /// Restores Field/Bakery subtypes using the variant field.
  /// Returns null if the building type is no longer in the registry.
  Building? createBuilding() {
    final template = BuildingRegistry.availableBuildings
        .where((b) => b.type == type)
        .firstOrNull;

    if (template == null) {
      debugPrint(
        'Warning: No template found for building type $type at ($x,$y). '
        'Skipping building creation.',
      );
      return null;
    }

    if (template is Field) {
      CropType cropType = CropType.wheat;
      if (variant != null) {
        final matched = CropType.values
            .where((e) => e.name == variant)
            .firstOrNull;
        if (matched != null) {
          cropType = matched;
        } else {
          debugPrint(
            'Warning: Unknown crop variant "$variant" for Field at ($x,$y). '
            'Falling back to wheat.',
          );
        }
      }
      return Field(
        id: id,
        type: template.type,
        name: template.name,
        description: template.description,
        icon: template.icon,
        assetPath: template.assetPath,
        color: template.color,
        baseCost: template.baseCost,
        basePopulation: template.basePopulation,
        maxLevel: template.maxLevel,
        gridSize: template.gridSize,
        baseBuildingLimit: template.baseBuildingLimit,
        requiredWorkers: template.requiredWorkers,
        category: template.category,
        level: level,
        cropType: cropType,
      )..assignedWorkers = assignedWorkers;
    }

    if (template is Bakery) {
      BakeryProduct productType = BakeryProduct.bread;
      if (variant != null) {
        final matched = BakeryProduct.values
            .where((e) => e.name == variant)
            .firstOrNull;
        if (matched != null) {
          productType = matched;
        } else {
          debugPrint(
            'Warning: Unknown bakery variant "$variant" for Bakery at ($x,$y). '
            'Falling back to bread.',
          );
        }
      }
      return Bakery(
        id: id,
        type: template.type,
        name: template.name,
        description: template.description,
        icon: template.icon,
        assetPath: template.assetPath,
        color: template.color,
        baseCost: template.baseCost,
        basePopulation: template.basePopulation,
        maxLevel: template.maxLevel,
        gridSize: template.gridSize,
        baseBuildingLimit: template.baseBuildingLimit,
        requiredWorkers: template.requiredWorkers,
        category: template.category,
        level: level,
        productType: productType,
      )..assignedWorkers = assignedWorkers;
    }

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

  // Sentinel value to distinguish between "not provided" and "explicitly null"
  static const _sentinelVariant = Object();

  /// Create a copy with modified values.
  /// Use [variant] = null to explicitly clear the variant to null.
  PlacedBuildingData copyWith({
    String? id,
    int? x,
    int? y,
    BuildingType? type,
    int? level,
    int? assignedWorkers,
    Object? variant = _sentinelVariant,
  }) {
    return PlacedBuildingData(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      type: type ?? this.type,
      level: level ?? this.level,
      assignedWorkers: assignedWorkers ?? this.assignedWorkers,
      variant: variant == _sentinelVariant ? this.variant : variant as String?,
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
