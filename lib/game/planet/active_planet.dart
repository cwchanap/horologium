import 'package:flutter/foundation.dart';
import 'planet.dart';
import '../services/save_service.dart';

/// Global singleton to manage the currently active planet
class ActivePlanet {
  static final ActivePlanet _instance = ActivePlanet._internal();
  factory ActivePlanet() => _instance;
  ActivePlanet._internal();

  ValueNotifier<Planet>? _active;
  String _activePlanetId = 'earth';
  bool _disposed = false;

  /// Initialize with a default planet
  void initialize(Planet planet) {
    _active = ValueNotifier(planet);
    _activePlanetId = planet.id;
    _disposed = false;
  }

  /// Get the active planet as a ValueNotifier for UI reactivity
  ValueNotifier<Planet> get active {
    if (_active == null) {
      throw StateError(
        'ActivePlanet not initialized. Call initialize() first.',
      );
    }
    return _active!;
  }

  /// Get the current active planet value
  Planet get value {
    if (_active == null) {
      throw StateError(
        'ActivePlanet not initialized. Call initialize() first.',
      );
    }
    return _active!.value;
  }

  /// Get the current active planet ID
  String get activePlanetId => _activePlanetId;

  /// Set a new active planet
  void setActivePlanet(Planet planet) {
    if (_active == null) {
      initialize(planet);
      return;
    }

    _active!.value = planet;
    _activePlanetId = planet.id;
  }

  /// Update the active planet in place (triggers notifications)
  void updateActivePlanet(Planet planet) {
    if (_active == null) {
      initialize(planet);
      return;
    }

    if (planet.id != _activePlanetId) {
      throw ArgumentError(
        'Cannot update active planet with different ID. '
        'Expected: $_activePlanetId, got: ${planet.id}',
      );
    }

    _active!.value = planet;
  }

  /// Switch to a different planet by ID (loads from storage)
  Future<void> switchToPlanet(String planetId) async {
    if (planetId == _activePlanetId) {
      return; // Already on this planet
    }

    // Load the target planet from storage (use appropriate name)
    final planetName = getPlanetDisplayName(planetId);
    final targetPlanet = await SaveService.loadOrCreatePlanet(
      planetId,
      name: planetName,
    );

    // Switch to the new planet
    setActivePlanet(targetPlanet);
  }

  /// Get list of available planet IDs (stub implementation)
  /// In the future this could come from save data or server
  static List<String> getAvailablePlanetIds() {
    return ['earth']; // Only Earth is available for now
  }

  /// Get a display name for a planet ID
  static String getPlanetDisplayName(String planetId) {
    switch (planetId) {
      case 'earth':
        return 'Earth';
      case 'mars':
        return 'Mars';
      case 'moon':
        return 'Moon';
      default:
        return planetId.toUpperCase();
    }
  }

  /// Check if the ActivePlanet has been initialized
  bool get _isInitialized {
    if (_disposed) return false;
    return _active != null;
  }

  /// Get whether the system has been initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources (mainly for testing)
  void dispose() {
    _disposed = true;
    _active?.dispose();
    _active = null;
  }

  /// Reset for testing purposes
  @visibleForTesting
  void reset() {
    _active?.dispose();
    _active = null;
    _disposed = false;
    _activePlanetId = 'earth';
  }
}
