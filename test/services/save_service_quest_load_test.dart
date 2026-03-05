import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horologium/game/services/save_service.dart';

void main() {
  group('SaveService quest loading', () {
    test(
      'loadOrCreatePlanet handles non-string elements in quest list IDs gracefully',
      () async {
        // Simulate corrupted JSON where quest IDs are integers, not strings
        const corruptQuestJson =
            '{"active":[123,456],"completed":[],"claimed":[],"objectiveProgress":{}}';
        SharedPreferences.setMockInitialValues({
          'planet_earth_resources_json': '{}',
          'planet_earth_quests': corruptQuestJson,
        });
        // Should not throw; should return a planet with default quest manager
        final planet = await SaveService.loadOrCreatePlanet('earth');
        expect(planet.questManager, isNotNull);
      },
    );
  });
}
