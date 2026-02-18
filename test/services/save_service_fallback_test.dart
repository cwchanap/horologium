import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/game/services/save_service.dart';

void main() {
  group('SaveService Fallback Tests', () {
    const testPlanetId = 'test_fallback_planet';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads from old per-resource keys when JSON is corrupted', () async {
      // Set up old per-resource keys with test data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('planet.$testPlanetId.resources.cash', 500.0);
      await prefs.setDouble('planet.$testPlanetId.resources.gold', 200.0);
      await prefs.setDouble('planet.$testPlanetId.resources.wood', 300.0);
      await prefs.setInt('planet.$testPlanetId.population', 15);
      await prefs.setInt('planet.$testPlanetId.availableWorkers', 10);

      // Set corrupted JSON
      await prefs.setString(
        'planet.$testPlanetId.resources_json',
        '{invalid json',
      );

      // Load the planet
      final planet = await SaveService.loadOrCreatePlanet(
        testPlanetId,
        name: 'Test Planet',
      );

      // Verify that old data was loaded as fallback
      expect(planet.resources.cash, 500.0);
      expect(planet.resources.gold, 200.0);
      expect(planet.resources.wood, 300.0);
      expect(planet.resources.population, 15);
      expect(planet.resources.availableWorkers, 10);
    });

    test(
      'uses defaults when JSON is corrupted and no old data exists',
      () async {
        // Set up corrupted JSON without old keys
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'planet.$testPlanetId.resources_json',
          '{invalid json',
        );

        // Load the planet
        final planet = await SaveService.loadOrCreatePlanet(
          testPlanetId,
          name: 'Test Planet',
        );

        // Verify that defaults were used
        expect(planet.resources.cash, 1000.0); // Default from Resources()
        expect(planet.resources.gold, 0.0); // Default from Resources()
        expect(planet.resources.population, 20); // Default if not saved
      },
    );

    test('loads from JSON when it is valid', () async {
      // Set up valid JSON
      final prefs = await SharedPreferences.getInstance();
      final validJson = '{"cash":800.0,"gold":150.0,"wood":250.0}';
      await prefs.setString('planet.$testPlanetId.resources_json', validJson);

      // Load the planet
      final planet = await SaveService.loadOrCreatePlanet(
        testPlanetId,
        name: 'Test Planet',
      );

      // Verify that JSON data was loaded
      expect(planet.resources.cash, 800.0);
      expect(planet.resources.gold, 150.0);
      expect(planet.resources.wood, 250.0);
    });
  });
}
