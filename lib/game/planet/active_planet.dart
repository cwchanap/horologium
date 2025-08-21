import 'package:flutter/foundation.dart';
import 'planet.dart';

/// Global singleton to manage the currently active planet
class ActivePlanet {
  static final ActivePlanet _instance = ActivePlanet._internal();
  factory ActivePlanet() => _instance;
  ActivePlanet._internal();

  late final ValueNotifier<Planet> _active;
  String _activePlanetId = 'earth';

  /// Initialize with a default planet
  void initialize(Planet planet) {
    _active = ValueNotifier(planet);
    _activePlanetId = planet.id;
  }

  /// Get the active planet as a ValueNotifier for UI reactivity
  ValueNotifier<Planet> get active {
    if (!_isInitialized) {
      throw StateError('ActivePlanet not initialized. Call initialize() first.');
    }
    return _active;
  }

  /// Get the current active planet value
  Planet get value {
    if (!_isInitialized) {
      throw StateError('ActivePlanet not initialized. Call initialize() first.');
    }
    return _active.value;
  }

  /// Get the current active planet ID
  String get activePlanetId => _activePlanetId;

  /// Set a new active planet
  void setActivePlanet(Planet planet) {
    if (!_isInitialized) {
      initialize(planet);
      return;
    }
    
    _active.value = planet;
    _activePlanetId = planet.id;
  }

  /// Update the active planet in place (triggers notifications)
  void updateActivePlanet(Planet planet) {
    if (!_isInitialized) {
      initialize(planet);
      return;
    }
    
    if (planet.id != _activePlanetId) {
      throw ArgumentError('Cannot update active planet with different ID. '
          'Expected: $_activePlanetId, got: ${planet.id}');
    }
    
    _active.value = planet;
  }

  /// Check if the ActivePlanet has been initialized
  bool get _isInitialized {
    try {
      _active.value;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get whether the system has been initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources (mainly for testing)
  void dispose() {
    if (_isInitialized) {
      _active.dispose();
    }
  }

  /// Reset for testing purposes
  @visibleForTesting
  void reset() {
    if (_isInitialized) {
      _active.dispose();
    }
    _activePlanetId = 'earth';
  }
}
