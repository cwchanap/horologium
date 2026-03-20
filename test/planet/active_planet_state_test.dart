import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/planet/active_planet.dart';
import 'package:horologium/game/planet/planet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ActivePlanet state guards', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ActivePlanet().reset();
    });

    tearDown(() {
      ActivePlanet().reset();
    });

    test('throws when active planet is accessed before initialization', () {
      expect(() => ActivePlanet().active, throwsStateError);
      expect(() => ActivePlanet().value, throwsStateError);
      expect(ActivePlanet().isInitialized, isFalse);
    });

    test('setActivePlanet initializes the singleton when needed', () {
      final mars = Planet(id: 'mars', name: 'Mars');

      ActivePlanet().setActivePlanet(mars);

      expect(ActivePlanet().isInitialized, isTrue);
      expect(ActivePlanet().activePlanetId, equals('mars'));
      expect(ActivePlanet().value, same(mars));
    });

    test('updateActivePlanet initializes the singleton when needed', () {
      final earth = Planet(id: 'earth', name: 'Earth');

      ActivePlanet().updateActivePlanet(earth);

      expect(ActivePlanet().isInitialized, isTrue);
      expect(ActivePlanet().activePlanetId, equals('earth'));
      expect(ActivePlanet().value, same(earth));
    });

    test('updateActivePlanet rejects a different planet id', () {
      ActivePlanet().initialize(Planet(id: 'earth', name: 'Earth'));

      expect(
        () =>
            ActivePlanet().updateActivePlanet(Planet(id: 'mars', name: 'Mars')),
        throwsArgumentError,
      );
      expect(ActivePlanet().activePlanetId, equals('earth'));
    });

    test('updateActivePlanet replaces the current value when ids match', () {
      ActivePlanet().initialize(Planet(id: 'earth', name: 'Earth'));
      int notifications = 0;
      ActivePlanet().active.addListener(() {
        notifications++;
      });

      ActivePlanet().updateActivePlanet(Planet(id: 'earth', name: 'Terra'));

      expect(notifications, equals(1));
      expect(ActivePlanet().value.name, equals('Terra'));
    });

    test('dispose clears the active notifier and initialization state', () {
      ActivePlanet().initialize(Planet(id: 'earth', name: 'Earth'));

      ActivePlanet().dispose();

      expect(ActivePlanet().isInitialized, isFalse);
      expect(() => ActivePlanet().active, throwsStateError);
      expect(() => ActivePlanet().value, throwsStateError);
    });
  });
}
