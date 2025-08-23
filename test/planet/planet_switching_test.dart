import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/game/planet/active_planet.dart';
import 'package:horologium/game/planet/planet.dart';
import 'package:horologium/game/services/save_service.dart';

void main() {
  group('Planet Switching Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ActivePlanet().reset();
    });

    tearDown(() {
      ActivePlanet().reset();
    });

    test('ActivePlanet can switch to same planet (no-op)', () async {
      // Arrange
      final earth = Planet(id: 'earth', name: 'Earth');
      ActivePlanet().initialize(earth);
      
      final initialPlanet = ActivePlanet().value;
      expect(ActivePlanet().activePlanetId, equals('earth'));
      
      // Act - Switch to same planet
      await ActivePlanet().switchToPlanet('earth');
      
      // Assert - No change, same reference
      expect(ActivePlanet().activePlanetId, equals('earth'));
      expect(ActivePlanet().value, equals(initialPlanet));
    });

    test('ActivePlanet can switch to different planet', () async {
      // Arrange
      final earth = Planet(id: 'earth', name: 'Earth');
      ActivePlanet().initialize(earth);
      
      // Ensure mars planet will be created
      await SaveService.savePlanet(Planet(id: 'mars', name: 'Mars'));
      
      expect(ActivePlanet().activePlanetId, equals('earth'));
      
      // Act - Switch to Mars
      await ActivePlanet().switchToPlanet('mars');
      
      // Assert - Now on Mars
      expect(ActivePlanet().activePlanetId, equals('mars'));
      expect(ActivePlanet().value.id, equals('mars'));
      expect(ActivePlanet().value.name, equals('Mars'));
    });

    test('ActivePlanet creates new planet if it does not exist', () async {
      // Arrange
      final earth = Planet(id: 'earth', name: 'Earth');
      ActivePlanet().initialize(earth);
      
      expect(ActivePlanet().activePlanetId, equals('earth'));
      
      // Act - Switch to non-existent planet (should create it)
      await ActivePlanet().switchToPlanet('venus');
      
      // Assert - Now on Venus (newly created)
      expect(ActivePlanet().activePlanetId, equals('venus'));
      expect(ActivePlanet().value.id, equals('venus'));
    });

    test('getAvailablePlanetIds returns earth by default', () {
      // Act
      final planets = ActivePlanet.getAvailablePlanetIds();
      
      // Assert
      expect(planets, equals(['earth']));
    });

    test('getPlanetDisplayName returns proper names', () {
      // Act & Assert
      expect(ActivePlanet.getPlanetDisplayName('earth'), equals('Earth'));
      expect(ActivePlanet.getPlanetDisplayName('mars'), equals('Mars'));
      expect(ActivePlanet.getPlanetDisplayName('moon'), equals('Moon'));
      expect(ActivePlanet.getPlanetDisplayName('unknown'), equals('UNKNOWN'));
    });

    test('planet switching triggers ValueNotifier updates', () async {
      // Arrange
      final earth = Planet(id: 'earth', name: 'Earth');
      ActivePlanet().initialize(earth);
      
      int notificationCount = 0;
      String? lastPlanetId;
      
      ActivePlanet().active.addListener(() {
        notificationCount++;
        lastPlanetId = ActivePlanet().value.id;
      });
      
      // Act - Switch planets
      await ActivePlanet().switchToPlanet('jupiter');
      
      // Assert - Listener was called
      expect(notificationCount, equals(1));
      expect(lastPlanetId, equals('jupiter'));
    });

    test('switching preserves planet state correctly', () async {
      // Arrange
      final earth = Planet(id: 'earth', name: 'Earth');
      earth.resources.cash = 5000;
      ActivePlanet().initialize(earth);
      
      // Save earth with resources
      await SaveService.savePlanet(earth);
      
      // Act - Switch to mars and back to earth
      await ActivePlanet().switchToPlanet('mars');
      await ActivePlanet().switchToPlanet('earth');
      
      // Assert - Earth state restored
      expect(ActivePlanet().value.id, equals('earth'));
      expect(ActivePlanet().value.resources.cash, equals(5000));
    });
  });
}
